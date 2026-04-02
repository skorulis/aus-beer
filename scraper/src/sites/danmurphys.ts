import type { Page } from "playwright";
import { chromium } from "playwright";

import type { CanonicalProduct, PriceEntry, VesselType } from "../schema.js";

/** First-screen only; "Show more" / full catalog is a future extension. */
const BEER_LIST_URL = "https://www.danmurphys.com.au/beer/all";

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

function asRecord(v: unknown): Record<string, unknown> | null {
  if (v && typeof v === "object" && !Array.isArray(v)) return v as Record<string, unknown>;
  return null;
}

function num(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function inferVessel(text: string): VesselType | null {
  const t = text.toLowerCase();
  if (/\bcan(s)?\b/.test(t) || /\bstubbie?s?\b/.test(t)) return "can";
  if (/\bbottle(s)?\b/.test(t)) return "bottle";
  return null;
}

function extractSizeMl(text: string): number | null {
  const m = text.match(/(\d+)\s*m[lL]\b/);
  if (!m) return null;
  return Number.parseInt(m[1], 10);
}

function parseQuantityFromMessage(message: string): number | null {
  const m = message.match(/\(\s*(\d+)\s*\)/);
  if (m) return Number.parseInt(m[1], 10);
  const caseM = message.match(/case\s*(?:of)?\s*(\d+)/i);
  if (caseM) return Number.parseInt(caseM[1], 10);
  const packM = message.match(/(\d+)\s*pack/i);
  if (packM) return Number.parseInt(packM[1], 10);
  return null;
}

function splitBreweryName(title: string, brandHint: string): { brewery: string; name: string } {
  const t = title.replace(/\s+/g, " ").trim();
  const bh = brandHint.trim();
  if (bh && t.toLowerCase().startsWith(bh.toLowerCase())) {
    const rest = t.slice(bh.length).replace(/^[\s–—-]+/, "").trim();
    return { brewery: bh, name: rest || t };
  }
  const parts = t.split(/\s*[–—-]\s*/);
  if (parts.length >= 2) {
    return { brewery: parts[0].trim(), name: parts.slice(1).join(" - ").trim() };
  }
  return { brewery: "", name: t };
}

function looksLikeProduct(o: Record<string, unknown>): boolean {
  const hasName = Boolean(o.DisplayName ?? o.Name ?? o.Title);
  const hasPriceShape =
    typeof o.Price === "number" ||
    typeof o.caseprice === "object" ||
    typeof o.singleprice === "object" ||
    typeof o.inanysixprice === "object";
  return hasName && hasPriceShape;
}

function collectProductObjects(val: unknown, acc: Record<string, unknown>[]): void {
  const rec = asRecord(val);
  if (!rec) return;
  if (looksLikeProduct(rec)) acc.push(rec);
  for (const k of Object.keys(rec)) collectProductObjects(rec[k], acc);
}

function isMemberFromWoolworthsTag(p: Record<string, unknown>): boolean {
  const check = (tag: unknown): boolean => {
    const t = asRecord(tag);
    if (!t) return false;
    if (t.MemberPriceData != null && t.MemberPriceData !== false) return true;
    if (t.FFPVMemberPriceData != null) return true;
    if (Boolean(t.IsRegisteredRewardCardPromotion)) return true;
    return false;
  };
  return check(p.CentreTag) || check(p.FooterTag) || check(p.HeaderTag);
}

function addLegacySlot(slot: unknown, prices: PriceEntry[]): void {
  const o = asRecord(slot);
  if (!o) return;
  const price = num(o.Value ?? o.Price ?? o.price);
  if (price == null || price <= 0) return;
  const msg = String(o.Message ?? o.CupString ?? "");
  const packType =
    o.PackType != null && typeof o.PackType !== "object" ? String(o.PackType).toLowerCase() : "";
  let quantity =
    parseQuantityFromMessage(msg) ?? (packType === "pack" ? 6 : null) ?? 1;
  const member = Boolean(
    o.IsMemberPrice ?? o.MemberPrice ?? o.isMemberPrice ?? /member/i.test(msg),
  );
  prices.push({ price, quantity, memberOffer: member });
}

function mapLegacyDm(o: Record<string, unknown>): CanonicalProduct | null {
  const title = String(o.Name ?? o.DisplayName ?? o.Title ?? "");
  if (!title) return null;
  const brand = String(o.Brand ?? "");
  const { brewery, name } = splitBreweryName(title, brand);
  const prices: PriceEntry[] = [];
  addLegacySlot(o.caseprice, prices);
  addLegacySlot(o.singleprice, prices);
  addLegacySlot(o.inanysixprice, prices);
  return {
    brewery,
    name,
    vesselType: inferVessel(title),
    sizeMl: extractSizeMl(title),
    prices,
  };
}

function mapWoolworthsStyle(o: Record<string, unknown>): CanonicalProduct | null {
  const displayName = String(o.DisplayName ?? o.Name ?? o.Title ?? "");
  if (!displayName) return null;
  const brand = o.Brand != null ? String(o.Brand) : "";
  const { brewery, name } = splitBreweryName(displayName, brand);
  const prices: PriceEntry[] = [];
  const price = num(o.Price ?? o.InstorePrice);
  if (price != null && price > 0) {
    let quantity = num(o.DisplayQuantity) ?? num(o.MinimumQuantity) ?? 1;
    const pkg = String(o.PackageSize ?? "");
    const packMatch = pkg.match(/(\d+)\s*[Pp][Kk]/);
    if (packMatch) quantity = Number.parseInt(packMatch[1], 10);
    quantity = Math.max(1, Math.round(quantity));
    prices.push({
      price,
      quantity,
      memberOffer: isMemberFromWoolworthsTag(o),
    });
  }
  return {
    brewery,
    name,
    vesselType: inferVessel(displayName),
    sizeMl: extractSizeMl(displayName),
    prices,
  };
}

function mapUnknownProduct(o: Record<string, unknown>): CanonicalProduct | null {
  if (typeof o.caseprice === "object" || typeof o.singleprice === "object") {
    const p = mapLegacyDm(o);
    if (p && p.prices.length > 0) return p;
  }
  const ww = mapWoolworthsStyle(o);
  if (ww && ww.prices.length > 0) return ww;
  return null;
}

function productsFromJsonValue(body: unknown): CanonicalProduct[] {
  const objs: Record<string, unknown>[] = [];
  collectProductObjects(body, objs);
  const products: CanonicalProduct[] = [];
  const seen = new Set<string>();
  for (const o of objs) {
    const p = mapUnknownProduct(o);
    if (!p || p.prices.length === 0) continue;
    const id = `${p.brewery}|${p.name}|${p.sizeMl}|${[...p.prices].map((x) => x.price).join(",")}`;
    if (seen.has(id)) continue;
    seen.add(id);
    products.push(p);
  }
  return products;
}

function mergePriceLists(a: PriceEntry[], b: PriceEntry[]): PriceEntry[] {
  const key = (p: PriceEntry) => `${p.price}|${p.quantity}|${p.memberOffer}`;
  const m = new Map<string, PriceEntry>();
  for (const p of [...a, ...b]) m.set(key(p), p);
  return [...m.values()];
}

function productKey(p: CanonicalProduct): string {
  return [p.brewery.toLowerCase(), p.name.toLowerCase(), String(p.sizeMl), p.vesselType ?? ""].join(
    "|",
  );
}

function mergeProductLists(lists: CanonicalProduct[][]): CanonicalProduct[] {
  const map = new Map<string, CanonicalProduct>();
  for (const list of lists) {
    for (const p of list) {
      const k = productKey(p);
      const existing = map.get(k);
      if (!existing) {
        map.set(k, { ...p, prices: [...p.prices] });
      } else {
        map.set(k, {
          ...existing,
          prices: mergePriceLists(existing.prices, p.prices),
          brewery: existing.brewery || p.brewery,
          vesselType: existing.vesselType ?? p.vesselType,
          sizeMl: existing.sizeMl ?? p.sizeMl,
        });
      }
    }
  }
  return [...map.values()].filter((p) => p.name.length > 0);
}

function dedupePriceEntries(prices: PriceEntry[]): PriceEntry[] {
  return mergePriceLists([], prices);
}

function parsePricesFromCardText(text: string): PriceEntry[] {
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);
  const entries: PriceEntry[] = [];
  for (const line of lines) {
    if (!/\$/.test(line)) continue;
    const memberOffer = /member|my dan|rewards?/i.test(line);
    const m = line.match(/\$\s*(\d+(?:\.\d{2})?)/);
    if (!m) continue;
    const price = Number.parseFloat(m[1]);
    if (!Number.isFinite(price) || price <= 0) continue;
    let quantity = 1;
    const caseM = line.match(/(?:case|pack)\s*\(?\s*(\d+)\s*\)?/i);
    const pkM = line.match(/(\d+)\s*pk\b/i);
    const eachM = line.match(/(\d+)\s*x\s*/i);
    if (caseM) quantity = Number.parseInt(caseM[1], 10);
    else if (pkM) quantity = Number.parseInt(pkM[1], 10);
    else if (eachM) quantity = Number.parseInt(eachM[1], 10);
    entries.push({ price, quantity: quantity || 1, memberOffer });
  }
  return dedupePriceEntries(entries);
}

function titleFromCardText(text: string): string {
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);
  for (const line of lines) {
    if (/\$\s*\d/.test(line)) continue;
    if (/^from\s+\$/i.test(line)) continue;
    if (line.length < 4) continue;
    if (/^add to cart|^view|^compare/i.test(line)) continue;
    return line;
  }
  return lines[0] ?? "";
}

async function extractProductsFromDom(page: Page): Promise<CanonicalProduct[]> {
  const raw = await page.evaluate(() => {
    const links = [
      ...document.querySelectorAll<HTMLAnchorElement>('a[href*="/product/"]'),
    ];
    const byHref = new Map<string, string>();
    for (const a of links) {
      const href = a.getAttribute("href") ?? "";
      if (!href.includes("/product/")) continue;
      const lower = href.toLowerCase();
      if (lower.includes("gift") || lower.includes("egift")) continue;
      const card =
        a.closest("article") ??
        a.closest('[class*="product"]') ??
        a.closest("li") ??
        a.parentElement?.parentElement;
      if (!card) continue;
      const text = (card as HTMLElement).innerText ?? "";
      if (!text || !/\$/.test(text)) continue;
      const full = href.startsWith("http") ? href : `https://www.danmurphys.com.au${href}`;
      if (!byHref.has(full)) byHref.set(full, text);
    }
    return [...byHref.entries()];
  });

  const out: CanonicalProduct[] = [];
  for (const [, text] of raw) {
    const title = titleFromCardText(text);
    if (!title) continue;
    const { brewery, name } = splitBreweryName(title, "");
    const prices = parsePricesFromCardText(text);
    if (prices.length === 0) continue;
    out.push({
      brewery,
      name,
      vesselType: inferVessel(title + " " + text),
      sizeMl: extractSizeMl(title + " " + text),
      prices,
    });
  }
  return out;
}

async function dismissDialogs(page: Page): Promise<void> {
  const locators = [
    page.getByRole("button", { name: /accept all|i accept|agree|got it|allow all/i }),
    page.getByRole("button", { name: /^no,? thanks$|^not now$|continue shopping/i }),
  ];
  for (const loc of locators) {
    try {
      const first = loc.first();
      if (await first.isVisible({ timeout: 1200 })) await first.click({ timeout: 2000 });
    } catch {
      /* ignore */
    }
  }
}

export async function scrapeDanmurphysFirstPage(): Promise<CanonicalProduct[]> {
  const browser = await chromium.launch({ headless: process.env.HEADFUL !== "1" });
  const fromNetwork: CanonicalProduct[] = [];
  const responseTasks: Promise<void>[] = [];

  try {
    const context = await browser.newContext({
      viewport: { width: 1400, height: 900 },
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      locale: "en-AU",
    });
    const page = await context.newPage();

    page.on("response", (response) => {
      responseTasks.push(
        (async () => {
          try {
            const url = response.url();
            if (!url.includes("danmurphys.com.au")) return;
            const ct = response.headers()["content-type"] ?? "";
            if (!ct.includes("application/json")) return;
            const body = await response.json();
            fromNetwork.push(...productsFromJsonValue(body));
          } catch {
            /* not JSON or aborted */
          }
        })(),
      );
    });

    await page.goto(BEER_LIST_URL, { waitUntil: "domcontentloaded", timeout: 120000 });
    await dismissDialogs(page);
    await page
      .waitForSelector('a[href*="/product/"]', { timeout: 90000 })
      .catch(() => undefined);
    await page.waitForLoadState("networkidle", { timeout: 90000 }).catch(() => undefined);
    await delay(1500);
    await dismissDialogs(page);
    await Promise.allSettled(responseTasks);
    await delay(200);

    const fromDom = await extractProductsFromDom(page);
    return mergeProductLists([fromNetwork, fromDom]);
  } finally {
    await browser.close();
  }
}
