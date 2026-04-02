import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

import type { Page } from "playwright";
import { chromium } from "playwright";

import type { CanonicalProduct, PriceEntry, VesselType } from "../schema.js";

/** First-screen only; "Show more" / full catalog is a future extension. */
const BEER_LIST_URL = "https://www.danmurphys.com.au/beer/all";

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

type Logger = {
  enabled: boolean;
  info: (message: string) => void;
  warn: (message: string) => void;
};

function makeLogger(enabled: boolean, startedAtMs: number): Logger {
  const prefix = "[scraper/danmurphys]";
  const elapsed = () => `${Date.now() - startedAtMs}ms`;

  if (!enabled) {
    return {
      enabled: false,
      info: () => undefined,
      warn: () => undefined,
    };
  }

  return {
    enabled: true,
    info: (message) => console.error(`${prefix} +${elapsed()} ${message}`),
    warn: (message) => console.error(`${prefix} +${elapsed()} WARN ${message}`),
  };
}

function withDefaultLogging(options: { logging?: boolean } | undefined): { logging: boolean } {
  return { logging: options?.logging ?? true };
}

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
  if (/^offer$/i.test(t)) return true;
  if (/^special\s+offer$/i.test(t)) return true;
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
  const explicit = o.IsMemberPrice ?? o.MemberPrice ?? o.isMemberPrice;
  const member =
    explicit != null && explicit !== ""
      ? Boolean(explicit)
      : inferMemberOfferFromText(msg);
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

/**
 * Retail tiles label non-member prices with "Non-member" / "Non member". A naive `/member/`
 * regex matches the substring inside "non-member", inverting the flag.
 */
function inferMemberOfferFromText(text: string): boolean {
  const t = text.toLowerCase();
  if (/non[-\s]?member|nonmember/.test(t)) return false;
  if (
    /\bmember\s+price|\bmembers?\s+price|my\s+dan|rewards?\s+card|member\s+offer|dans\s+member/i.test(
      t,
    )
  ) {
    return true;
  }
  if (/\bmembers?\b/.test(t)) return true;
  return false;
}

/** When a tile shows two prices for the same pack size, the lower one is almost always the member price. */
function reconcileMemberOffersForSameQuantity(entries: PriceEntry[]): void {
  const byQty = new Map<number, PriceEntry[]>();
  for (const e of entries) {
    const list = byQty.get(e.quantity) ?? [];
    list.push(e);
    byQty.set(e.quantity, list);
  }
  for (const [, list] of byQty) {
    if (list.length !== 2) continue;
    const [a, b] = list;
    if (a.memberOffer !== b.memberOffer) continue;
    if (a.memberOffer && b.memberOffer) continue;
    if (a.price === b.price) continue;
    const cheaper = a.price < b.price ? a : b;
    const pricier = a.price < b.price ? b : a;
    cheaper.memberOffer = true;
    pricier.memberOffer = false;
  }
}

/** Ignore "non-member" wording so we can detect real member pricing elsewhere on the tile. */
function cardSuggestsMemberPricing(fullCardText: string): boolean {
  const stripped = fullCardText.replace(/non[-\s]?member/gi, " ");
  return inferMemberOfferFromText(stripped);
}

/**
 * Different pack sizes on one tile: if text still flags member somewhere (after stripping non-member),
 * assign memberOffer to the better per-unit price (usual Dan Murphy's pattern).
 */
function reconcileMemberOffersMixedQuantity(entries: PriceEntry[], fullCardText: string): void {
  if (entries.length !== 2) return;
  const a = entries[0];
  const b = entries[1];
  if (a.quantity === b.quantity) return;
  if (a.memberOffer !== b.memberOffer) return;
  if (a.memberOffer && b.memberOffer) return;
  if (!cardSuggestsMemberPricing(fullCardText)) return;
  const perUnit = (e: PriceEntry) => e.price / e.quantity;
  const aPu = perUnit(a);
  const bPu = perUnit(b);
  if (Math.abs(aPu - bPu) < 1e-9) return;
  const better = aPu < bPu ? a : b;
  const worse = aPu < bPu ? b : a;
  better.memberOffer = true;
  worse.memberOffer = false;
}

/**
 * Quantity hints from Dan Murphy's tile copy (grid + carousel). Uses the line and a small
 * window so "for 3 bottles" / "Non-Member: …" on adjacent lines still match.
 */
function parseQuantityFromPriceBlock(price: number, block: string): number {
  const b = block.replace(/\s+/g, " ");
  let m = b.match(/for\s+(\d+)\s+cases?\s*\((\d+)\)/i);
  if (m) return Number.parseInt(m[1], 10) * Number.parseInt(m[2], 10);
  m = b.match(/for\s+(\d+)\s+cases?\b/i);
  if (m) return Number.parseInt(m[1], 10) * 24;
  m = b.match(/per\s+case\s+of\s+(\d+)/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/per\s+pack\s+of\s+(\d+)/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/for\s+(\d+)\s+bottles?/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/block\s*\((\d+)\)/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/case\s*\((\d+)\)/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/pack\s*\((\d+)\)/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/(?:case|pack)\s*\(?\s*(\d+)\s*\)?/i);
  if (m) return Number.parseInt(m[1], 10);
  m = b.match(/(\d+)\s*pk\b/i);
  if (m) return Number.parseInt(m[1], 10);
  /** "3 x $…" pack lines — not decimals like 3.5%. */
  m = b.match(/\b(\d+)\s+x\s+\$/i);
  if (m) return Number.parseInt(m[1], 10);
  if (/\beach\b/i.test(b)) {
    return price < 15 ? 1 : 24;
  }
  return 1;
}

function memberOfferForPriceLine(line: string, wideBlock: string): boolean {
  if (/non[-\s]?member/i.test(line)) return false;
  if (/member\s+offer/i.test(wideBlock) && /\$/.test(line) && !/non[-\s]?member/i.test(line)) return true;
  return inferMemberOfferFromText(wideBlock);
}

/**
 * Quantity for this price: same line if it already names pack/case/each; otherwise join the
 * next line so split tiles like `$17` + `for 3 bottles` still work — but do not append the
 * following *price* row (`$68.95 case (24)`), or `case (24)` wins over `pack (6)`.
 */
function narrowQuantityContext(lines: string[], i: number): string {
  const line = lines[i];
  const next = lines[i + 1] ?? "";
  const lineHasPackaging =
    /\$[\s\S]*\b(pack|case|each|block)\b/i.test(line) ||
    /\$[\s\S]*\bfor\s+\d+\s+(bottles?|cases?)/i.test(line) ||
    /\$[\s\S]*\bper\s+(pack|case)\s+of\b/i.test(line);
  if (lineHasPackaging) return line;
  if (next && !/^\$/.test(next)) return `${line} ${next}`.replace(/\s+/g, " ").trim();
  return line;
}

function parsePricesFromCardText(text: string): PriceEntry[] {
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);
  const entries: PriceEntry[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!/\$/.test(line)) continue;
    const lo = Math.max(0, i - 4);
    const hi = Math.min(lines.length, i + 3);
    const wideBlock = lines.slice(lo, hi).join(" ").replace(/\s+/g, " ").trim();
    const narrowBlock = narrowQuantityContext(lines, i);
    const memberOffer = memberOfferForPriceLine(line, wideBlock);
    const priceMatches = [...line.matchAll(/\$\s*(\d+(?:\.\d{2})?)/g)];
    for (const m of priceMatches) {
      const price = Number.parseFloat(m[1]);
      if (!Number.isFinite(price) || price <= 0) continue;
      const quantity = parseQuantityFromPriceBlock(price, narrowBlock);
      entries.push({ price, quantity: quantity || 1, memberOffer });
    }
  }
  const hasExplicitNonMember = /non[-\s]?member/i.test(text);
  const hasMemberOffer = /member\s+offer/i.test(text);
  if (!hasExplicitNonMember) {
    reconcileMemberOffersForSameQuantity(entries);
    if (hasMemberOffer) {
      reconcileMemberOffersMixedQuantity(entries, text);
    }
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

type DomProductRow = {
  breweryLine: string;
  subtitle: string;
  href: string;
  cardText: string;
};

function resolveBreweryAndName(row: DomProductRow): { brewery: string; name: string } | null {
  let brewery = row.breweryLine.trim();
  let name = cleanBeerName(row.subtitle);
  if (!brewery) return null;
  if (!name) {
    const slug = parseBreweryAndNameFromProductHref(row.href);
    if (slug) {
      brewery = slug.brewery;
      name = slug.name;
    }
  }
  if (name !== "" && !isPlausibleProductName(name)) return null;
  return { brewery, name };
}

async function extractProductsFromDom(page: Page, logger?: Logger): Promise<CanonicalProduct[]> {
  const rows = await page.evaluate(() => {
    const out: DomProductRow[] = [];
    const carousel = document.querySelector("dd-product-carousel");
    if (carousel) {
      for (const root of Array.from(carousel.querySelectorAll(".product--dm"))) {
        const breweryLine =
          root.querySelector(".product__title--primary")?.textContent?.replace(/\s+/g, " ").trim() ?? "";
        const subtitle =
          root.querySelector(".product__title--secondary")?.textContent?.replace(/\s+/g, " ").trim() ?? "";
        const link = root.querySelector('a[href*="/product/"]') as HTMLAnchorElement | null;
        const href = link?.href ?? "";
        if (!href || !breweryLine) continue;
        out.push({
          breweryLine,
          subtitle,
          href,
          cardText: (root as HTMLElement).innerText ?? "",
        });
      }
    }
    for (const card of Array.from(document.querySelectorAll("#results shop-product-card"))) {
      const link = card.querySelector('h2.not-offers a[href*="/product/"]') as HTMLAnchorElement | null;
      if (!link) continue;
      const breweryLine =
        card.querySelector("h2.not-offers span.title")?.textContent?.replace(/\s+/g, " ").trim() ?? "";
      const subtitle =
        card.querySelector("h2.not-offers span.subtitle")?.textContent?.replace(/\s+/g, " ").trim() ?? "";
      const href = link.href;
      if (!href || !breweryLine) continue;
      out.push({
        breweryLine,
        subtitle,
        href,
        cardText: (card as HTMLElement).innerText ?? "",
      });
    }
    return out;
  });

  logger?.info(`DOM: found ${rows.length} product tiles`);

  const seenCanonical = new Set<string>();
  const out: CanonicalProduct[] = [];

  for (const row of rows) {
    const href = row.href;
    if (!href.includes("/product/")) continue;
    const lower = href.toLowerCase();
    if (lower.includes("gift") || lower.includes("egift")) continue;

    let canonical: string;
    try {
      const u = new URL(href);
      canonical = `${u.origin}${u.pathname}`;
    } catch {
      continue;
    }
    if (seenCanonical.has(canonical)) continue;
    seenCanonical.add(canonical);

    if (!/\$/.test(row.cardText)) continue;

    const parsed = resolveBreweryAndName(row);
    if (!parsed) continue;
    const { brewery, name } = parsed;

    const prices = parsePricesFromCardText(row.cardText);
    if (prices.length === 0) continue;
    if (prices.length > MAX_PRICE_LINES_PER_PRODUCT) continue;

    const textForMeta = `${brewery} ${row.subtitle} ${row.cardText}`;
    out.push({
      brewery,
      name,
      vesselType: inferVessel(textForMeta),
      sizeMl: extractSizeMl(textForMeta),
      prices,
    });
  }

  logger?.info(`DOM: parsed ${out.length} canonical products`);
  return out;
}

/**
 * Parse product tiles from a saved listing HTML (e.g. `npm run scrape -- --html …`). Uses the same DOM rules as the live scrape.
 * Fixture is loaded via `file:` URL; no network JSON merge (fixture-only DOM).
 */
export async function parseDanmurphysProductsFromFixture(
  fixturePath: string,
  options?: { logging?: boolean },
): Promise<CanonicalProduct[]> {
  const startedAtMs = Date.now();
  const { logging } = withDefaultLogging(options);
  const logger = makeLogger(logging, startedAtMs);

  logger.info(`fixture: loading ${fixturePath}`);
  const fileUrl = pathToFileURL(resolve(fixturePath)).href;
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({
      viewport: { width: 1400, height: 900 },
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      locale: "en-AU",
    });
    const page = await context.newPage();
    logger.info(`fixture: navigating`);
    await page.goto(fileUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
    logger.info(`fixture: waiting for product links`);
    await page.waitForSelector('a[href*="/product/"]', { timeout: 90000 }).catch(() => undefined);
    await delay(200);
    const products = await extractProductsFromDom(page, logger);
    logger.info(`fixture: extracted ${products.length} products`);
    return products;
  } finally {
    await browser.close();
  }
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

export type ScrapeDanmurphysMode = "products" | "html";

export async function scrapeDanmurphysFirstPage(options: { mode: "html"; logging?: boolean }): Promise<string>;
export async function scrapeDanmurphysFirstPage(options?: {
  mode?: "products";
  logging?: boolean;
}): Promise<CanonicalProduct[]>;
export async function scrapeDanmurphysFirstPage(options?: {
  mode?: ScrapeDanmurphysMode;
  logging?: boolean;
}): Promise<CanonicalProduct[] | string> {
  const mode: ScrapeDanmurphysMode = options?.mode === "html" ? "html" : "products";
  const startedAtMs = Date.now();
  const { logging } = withDefaultLogging(options);
  const logger = makeLogger(logging, startedAtMs);
  logger.info(`start (mode=${mode}, headful=${process.env.HEADFUL === "1"})`);

  const browser = await chromium.launch({ headless: process.env.HEADFUL !== "1" });
  const fromNetwork: CanonicalProduct[] = [];
  const responseTasks: Promise<void>[] = [];
  let jsonResponsesMatched = 0;
  let jsonProductsExtracted = 0;

  try {
    const context = await browser.newContext({
      viewport: { width: 1400, height: 900 },
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      locale: "en-AU",
    });
    const page = await context.newPage();

    if (mode === "products") {
      page.on("response", (response) => {
        responseTasks.push(
          (async () => {
            try {
              const url = response.url();
              if (!url.includes("danmurphys.com.au")) return;
              const ct = response.headers()["content-type"] ?? "";
              if (!ct.includes("application/json")) return;
              jsonResponsesMatched++;
              const body = await response.json();
              const parsed = productsFromJsonValue(body);
              jsonProductsExtracted += parsed.length;
              fromNetwork.push(...parsed);
              if (logger.enabled && jsonResponsesMatched <= 3) {
                logger.info(
                  `network json: parsed ${parsed.length} products (${jsonResponsesMatched} matched responses)`,
                );
              }
            } catch {
              /* not JSON or aborted */
            }
          })(),
        );
      });
    }

    logger.info(`navigate: ${BEER_LIST_URL}`);
    await page.goto(BEER_LIST_URL, { waitUntil: "domcontentloaded", timeout: 120000 });
    logger.info(`page: dismiss dialogs (best effort)`);
    await dismissDialogs(page);
    logger.info(`page: waiting for product links`);
    await page
      .waitForSelector('a[href*="/product/"]', { timeout: 90000 })
      .catch(() => undefined);
    logger.info(`page: wait for network idle`);
    await page.waitForLoadState("networkidle", { timeout: 90000 }).catch(() => undefined);
    await delay(1500);
    logger.info(`page: dismiss dialogs (best effort #2)`);
    await dismissDialogs(page);
    await Promise.allSettled(responseTasks);
    if (mode === "products") {
      logger.info(
        `network json: extracted ${jsonProductsExtracted} products from ${jsonResponsesMatched} matched responses`,
      );
    }
    await delay(200);

    if (mode === "html") {
      /** Full document HTML after JS; suitable for fixture snapshots / DOM parsers. */
      // Must await: bare `return page.content()` lets `finally` close the browser before the promise settles.
      logger.info(`end: returning HTML snapshot`);
      return await page.content();
    }

    logger.info(`dom: extracting canonical products`);
    const fromDom = await extractProductsFromDom(page, logger);
    const merged = mergeProductLists([fromNetwork, fromDom]);
    return merged;
  } finally {
    await browser.close();
  }
}
