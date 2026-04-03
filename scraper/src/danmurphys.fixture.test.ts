import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

import { chromium } from "playwright";

import type { CanonicalProduct } from "./schema.js";
import {
  DANMURPHYS_LOAD_MORE_BUTTON_SELECTOR,
  parseDanmurphysProductsFromFixture,
} from "./sites/danmurphys.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixtureHtml = join(__dirname, "../fixtures/danmurphys-beer-all.html");
const fixtureExpected = join(__dirname, "../fixtures/danmurphys-beer-all.expected.json");

function compareKey(p: CanonicalProduct): string {
  const prices = [...p.prices]
    .map((e) => `${e.price}|${e.quantity}|${e.memberOffer}`)
    .sort()
    .join(";");
  return [
    p.brewery.toLowerCase(),
    p.name.toLowerCase(),
    String(p.sizeMl),
    p.vesselType ?? "",
    prices,
  ].join("\0");
}

function sortForCompare(products: CanonicalProduct[]): CanonicalProduct[] {
  return [...products].sort((a, b) => compareKey(a).localeCompare(compareKey(b)));
}

test("parseDanmurphysProductsFromFixture matches expected snapshot", async () => {
  const expectedRaw = readFileSync(fixtureExpected, "utf8");
  const expected = JSON.parse(expectedRaw) as CanonicalProduct[];
  const actual = await parseDanmurphysProductsFromFixture(fixtureHtml);
  assert.deepEqual(sortForCompare(actual), sortForCompare(expected));
});

test("danmurphys fixture exposes the load-more button the scraper targets", async () => {
  const fileUrl = pathToFileURL(resolve(fixtureHtml)).href;
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(fileUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
    const buttons = page.locator(DANMURPHYS_LOAD_MORE_BUTTON_SELECTOR);
    assert.ok(
      (await buttons.count()) >= 1,
      `fixture should include at least one ${DANMURPHYS_LOAD_MORE_BUTTON_SELECTOR}`,
    );
    await buttons.first().waitFor({ state: "visible", timeout: 30000 });
  } finally {
    await browser.close();
  }
});
