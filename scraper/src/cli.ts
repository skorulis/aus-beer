import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import type { ScrapeOutput } from "./schema.js";
import { scrapeDanmurphysFirstPage } from "./sites/danmurphys.js";

/** Usage: npm run scrape -- <output-file>  or  --out <output-file> */
function parseOutputPath(argv: string[]): string | null {
  const args = argv.slice(2);
  let explicit: string | null = null;
  let positional: string | null = null;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--out" || a === "-o") {
      explicit = args[i + 1] ?? null;
      i++;
    } else if (!a.startsWith("-")) {
      positional = a;
    }
  }
  return explicit ?? positional;
}

async function main(): Promise<void> {
  const out = parseOutputPath(process.argv);
  if (!out) {
    console.error(
      "Usage: npm run scrape -- <output-file>\n       npm run scrape -- --out <output-file>",
    );
    process.exitCode = 1;
    return;
  }
  const path = resolve(out);
  const products = await scrapeDanmurphysFirstPage();
  const payload: ScrapeOutput = {
    source: "danmurphys",
    scrapedAt: new Date().toISOString(),
    products,
  };
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(payload, null, 2), "utf8");
  console.error(`Wrote ${products.length} products to ${path}`);
}

main().catch((err: unknown) => {
  console.error(err);
  process.exitCode = 1;
});
