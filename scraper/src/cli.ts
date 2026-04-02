import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import type { ScrapeOutput } from "./schema.js";
import { scrapeDanmurphysFirstPage } from "./sites/danmurphys.js";

/** Usage: npm run scrape -- <output-file>  or  --out <output-file>  ;  --html for DOM snapshot */
function parseCli(argv: string[]): { out: string | null; html: boolean } {
  const args = argv.slice(2);
  let explicit: string | null = null;
  let positional: string | null = null;
  let html = false;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--out" || a === "-o") {
      explicit = args[i + 1] ?? null;
      i++;
    } else if (a === "--html" || a === "--emit-html") {
      html = true;
    } else if (!a.startsWith("-")) {
      positional = a;
    }
  }
  return { out: explicit ?? positional, html };
}

async function main(): Promise<void> {
  const { out, html } = parseCli(process.argv);
  if (!out) {
    console.error(
      "Usage: npm run scrape -- <output-file>\n       npm run scrape -- --out <output-file>\n       npm run scrape -- --html <output.html>   # live DOM after JS (for test fixtures)",
    );
    process.exitCode = 1;
    return;
  }
  const path = resolve(out);
  mkdirSync(dirname(path), { recursive: true });

  if (html) {
    const domHtml = await scrapeDanmurphysFirstPage({ mode: "html" });
    writeFileSync(path, domHtml, "utf8");
    console.error(`Wrote DOM HTML (${domHtml.length} chars) to ${path}`);
    return;
  }

  const products = await scrapeDanmurphysFirstPage();
  const payload: ScrapeOutput = {
    source: "danmurphys",
    scrapedAt: new Date().toISOString(),
    products,
  };
  writeFileSync(path, JSON.stringify(payload, null, 2), "utf8");
  console.error(`Wrote ${products.length} products to ${path}`);
}

main().catch((err: unknown) => {
  console.error(err);
  process.exitCode = 1;
});
