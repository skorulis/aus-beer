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

/** Strip pack/vessel/volume from the end; vessel + sizeMl are stored separately. */
function cleanBeerName(raw: string): string {
  let s = raw.replace(/\s+/g, " ").trim();
  s = s.replace(
    /,?\s*(bottles?|cans?|stubbies?)\s*,?\s*\d+\s*m[lL]?\b/gi,
    "",
  );
  s = s.replace(/\s+\d+\s*m[lL]\b/gi, "");
  s = s.replace(/,?\s*(bottles?|cans?|stubbies?)\s*$/gi, "");
  s = s.replace(/^[,–—-]\s*/, "").replace(/\s*[,–—-]\s*$/, "");
  return s.replace(/\s+/g, " ").trim();
}

function capitalizeWords(s: string): string {
  return s
    .split(/[\s-]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(" ");
}

/** Listing tiles: Sponsored, Member offer, review counts, etc. */
function isUiChromeLine(line: string): boolean {
  const t = line.trim();
  if (t.length === 0 || t.length > 140) return true;
  if (/^\$/.test(t)) return true;
  if (/^sponsored$/i.test(t)) return true;
  if (/^member\s*offer$/i.test(t)) return true;
  if (/^limits?\s*apply$/i.test(t)) return true;
  if (/^save\s+/i.test(t)) return true;
  if (/^was\s+/i.test(t)) return true;
  if (/^each$/i.test(t)) return true;
  if (/^per\s+/i.test(t)) return true;
  if (/^add\s+to\s+cart/i.test(t)) return true;
  if (/^view\s+/i.test(t)) return true;
  if (/^compare$/i.test(t)) return true;
  if (/^online\s+only$/i.test(t)) return true;
  if (/^only\s+at\s+/i.test(t)) return true;
  if (/^\(?\s*\d+\s+reviews?\s*\)?$/i.test(t)) return true;
  if (/^\(\s*\d+\s+reviews?\s*\)$/i.test(t)) return true;
  if (/^\(\s*\d+\s+review\s*\)$/i.test(t)) return true;
  if (/^\d+\s+reviews?$/i.test(t)) return true;
  if (/^\(\s*\d+\s+reviews?\s*\)/i.test(t)) return true;
  return false;
}

/**
 * URL slug often looks like `asahi-super-dry-cans-500ml` — split before bottles/cans/stubbies + optional ml.
 */
function parseBreweryAndNameFromProductHref(href: string): { brewery: string; name: string } | null {
  try {
    const u = new URL(href.startsWith("http") ? href : `https://www.danmurphys.com.au${href}`);
    const parts = u.pathname.split("/").filter(Boolean);
    const slug = parts[parts.length - 1] ?? "";
    if (!slug.includes("-")) return null;
    const tokens = slug.split("-").filter(Boolean);
    const vesselIdx = tokens.findIndex((p) => /^(cans?|bottles?|stubbies?)$/i.test(p));
    if (vesselIdx < 1) return null;
    const before = tokens.slice(0, vesselIdx);
    if (before.length < 2) return null;
    const brewery = capitalizeWords(before[0] ?? "");
    const name = cleanBeerName(capitalizeWords(before.slice(1).join(" ")));
    if (!brewery || !name) return null;
    return { brewery, name };
  } catch {
    return null;
  }
}

function collectProductTitleLines(cardText: string): string[] {
  return cardText
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean)
    .filter((line) => !/\$\s*\d/.test(line))
    .filter((line) => !/^from\s+\$/i.test(line))
    .filter((line) => !isPromotionalMessage(line))
    .filter((line) => !isUiChromeLine(line))
    .filter((line) => !isReviewCountLine(line))
    .filter((line) => line.length >= 2);
}

function parseBreweryAndBeerFromCard(cardText: string, href: string): { brewery: string; name: string } | null {
  const lines = collectProductTitleLines(cardText);
  if (lines.length >= 2) {
    const brewery = lines[0].trim();
    const rawProduct = lines.slice(1).join(" ");
    const name = cleanBeerName(rawProduct);
    if (!name || !isPlausibleProductName(name)) return null;
    return { brewery, name };
  }
  if (lines.length === 1) {
    const slug = parseBreweryAndNameFromProductHref(href);
    if (slug) return { brewery: slug.brewery, name: slug.name };
    const name = cleanBeerName(lines[0]);
    if (!name || !isPlausibleProductName(name)) return null;
    return { brewery: "", name };
  }
  const slugOnly = parseBreweryAndNameFromProductHref(href);
  if (slugOnly && isPlausibleProductName(slugOnly.name)) return slugOnly;
  return null;
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
  const title = String(o.Name ?? o.DisplayName ?? o.Title ?? "").trim();
  if (!title) return null;
  const brand = String(o.Brand ?? "").trim();
  let brewery = "";
  let name = title;
  if (brand) {
    const low = title.toLowerCase();
    const bl = brand.toLowerCase();
    if (low.startsWith(bl)) {
      name = title.slice(brand.length).replace(/^[\s–—-]+/, "").trim();
      brewery = brand;
    } else {
      const s = splitBreweryName(title, brand);
      brewery = s.brewery;
      name = s.name;
    }
  } else {
    const s = splitBreweryName(title, "");
    brewery = s.brewery;
    name = s.name;
  }
  name = cleanBeerName(name);
  if (!name) return null;
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
  const displayName = String(o.DisplayName ?? o.Name ?? o.Title ?? "").trim();
  if (!displayName) return null;
  const brand = o.Brand != null ? String(o.Brand).trim() : "";
  let brewery = "";
  let name = displayName;
  if (brand) {
    const low = displayName.toLowerCase();
    const bl = brand.toLowerCase();
    if (low.startsWith(bl)) {
      name = displayName.slice(brand.length).replace(/^[\s–—-]+/, "").trim();
      brewery = brand;
    } else {
      const s = splitBreweryName(displayName, brand);
      brewery = s.brewery;
      name = s.name;
    }
  } else {
    const s = splitBreweryName(displayName, "");
    brewery = s.brewery;
    name = s.name;
  }
  name = cleanBeerName(name);
  if (!name) return null;
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
    if (p && p.prices.length > 0 && isPlausibleProductName(p.name)) return p;
  }
  const ww = mapWoolworthsStyle(o);
  if (ww && ww.prices.length > 0 && isPlausibleProductName(ww.name)) return ww;
  return null;
}

/** Site banners, modals, and footers sometimes match Name/DisplayName + Price in JSON. */
function isPlausibleProductName(name: string): boolean {
  const t = name.trim();
  if (t.length < 2 || t.length > 180) return false;
  if (isReviewCountLine(t)) return false;
  if (isUiChromeLine(t)) return false;
  const lower = t.toLowerCase();
  if (
    /reminder|our stores are closed|good friday|order now|weekend|subscribe|newsletter|cookie|privacy policy|click here|sign up|terms and conditions|would you like to change your store|change your store|default store|delivery/i.test(
      lower,
    )
  ) {
    return false;
  }
  return true;
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

function isPromotionalMessage(line: string): boolean {
  const t = line.trim().toLowerCase();
  if (t.length > 160) return true;
  return /reminder|our stores are closed|good friday|order now|weekend|subscribe|newsletter|cookie|privacy policy|click here|sign up|terms and conditions|would you like to change your store|change your store|default store|delivery under|same day/i.test(
    t,
  );
}

/** Listing tiles often put star ratings in the link; the real title is elsewhere in the card. */
function isReviewCountLine(line: string): boolean {
  const t = line.trim();
  return (
    /^\d+\s+reviews?$/i.test(t) ||
    /^\(\s*\d+\s+reviews?\s*\)$/i.test(t) ||
    /^\(\s*\d+\s+review\s*\)$/i.test(t) ||
    /^\(\s*\d+\s+reviews?\s*\)/i.test(t)
  );
}

const MAX_PRICE_LINES_PER_PRODUCT = 12;

async function extractProductsFromDom(page: Page): Promise<CanonicalProduct[]> {
  const anchors = page.locator('a[href*="/product/"]');
  const n = await anchors.count();
  const seenHref = new Set<string>();
  const out: CanonicalProduct[] = [];

  for (let i = 0; i < n; i++) {
    const a = anchors.nth(i);
    const href = (await a.getAttribute("href")) ?? "";
    if (!href.includes("/product/")) continue;
    const lower = href.toLowerCase();
    if (lower.includes("gift") || lower.includes("egift")) continue;
    const full = href.startsWith("http") ? href : `https://www.danmurphys.com.au${href}`;
    if (seenHref.has(full)) continue;
    seenHref.add(full);

    // Smallest ancestor with a price that still looks like one tile (avoids banner + whole grid).
    const cardText = await a.evaluate((el) => {
      const MAX_CARD_CHARS = 2000;
      const MAX_CARD_LINES = 35;
      const candidates: HTMLElement[] = [];
      for (let cur = (el as HTMLElement).parentElement; cur && cur !== document.body; cur = cur.parentElement) {
        const t = cur.innerText ?? "";
        if (!t.includes("$")) continue;
        candidates.push(cur);
      }
      if (candidates.length === 0) return "";
      candidates.sort((x, y) => (x.innerText?.length ?? 0) - (y.innerText?.length ?? 0));
      for (const c of candidates) {
        const t = (c.innerText ?? "").trim();
        const lines = t.split(/\n+/).filter(Boolean);
        if (t.length >= 40 && t.length <= MAX_CARD_CHARS && lines.length <= MAX_CARD_LINES) return t;
      }
      return "";
    });

    if (!cardText || !/\$/.test(cardText)) continue;

    const parsed = parseBreweryAndBeerFromCard(cardText, full);
    if (!parsed) continue;
    const { brewery, name } = parsed;
    const prices = parsePricesFromCardText(cardText);
    if (prices.length === 0) continue;
    if (prices.length > MAX_PRICE_LINES_PER_PRODUCT) continue;
    const textForMeta = `${brewery} ${name} ${cardText}`;
    out.push({
      brewery,
      name,
      vesselType: inferVessel(textForMeta),
      sizeMl: extractSizeMl(textForMeta),
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
