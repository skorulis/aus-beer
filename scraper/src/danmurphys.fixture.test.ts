import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath } from "node:url";

import type { CanonicalProduct } from "./schema.js";
import { parseDanmurphysProductsFromFixture } from "./sites/danmurphys.js";

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
