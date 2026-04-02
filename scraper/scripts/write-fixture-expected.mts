import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { parseDanmurphysProductsFromFixture } from "../src/sites/danmurphys.js";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const html = join(root, "fixtures/danmurphys-beer-all.html");
const out = join(root, "fixtures/danmurphys-beer-all.expected.json");

const products = await parseDanmurphysProductsFromFixture(html);
writeFileSync(out, `${JSON.stringify(products, null, 2)}\n`, "utf8");
console.error(`Wrote ${products.length} products to ${out}`);
