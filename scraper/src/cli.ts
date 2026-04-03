import { mkdirSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import type { ScrapeOutput } from "./schema.js";
import { scrapeDanmurphysFirstPage } from "./sites/danmurphys.js";

/** Repo root (aus-beer), two levels above this file: scraper/src/cli.ts */
const PROJECT_ROOT = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const TMP_DIR = join(PROJECT_ROOT, "tmp");

function resolveOutputPath(userPath: string): string {
  const fileName = basename(resolve(userPath));
  return join(TMP_DIR, fileName);
}

/** Usage: npm run scrape -- <output-file>  or  --out <output-file>  ;  --html for DOM snapshot */
function parseCli(argv: string[]): { out: string | null; html: boolean; maxPages: number } {
  const args = argv.slice(2);
  let explicit: string | null = null;
  let positional: string | null = null;
  let html = false;
  let maxPages = 1;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--out" || a === "-o") {
      explicit = args[i + 1] ?? null;
      i++;
    } else if (a === "--html" || a === "--emit-html") {
      html = true;
    } else if (a === "--max-pages" || a === "--pages") {
      const raw = args[i + 1] ?? "";
      const n = Number.parseInt(raw, 10);
      if (Number.isFinite(n) && n >= 1) maxPages = n;
      i++;
    } else if (!a.startsWith("-")) {
      positional = a;
    }
  }
  return { out: explicit ?? positional, html, maxPages };
}

async function main(): Promise<void> {
  const { out, html, maxPages } = parseCli(process.argv);
  if (!out) {
    console.error(
      "Usage: npm run scrape -- <output-file>\n       npm run scrape -- --out <output-file>\n       npm run scrape -- --max-pages <n> <output-file>\n       npm run scrape -- --html <output.html>   # live DOM after JS (for test fixtures)\n       npm run scrape -- --html --max-pages <n> <output.html>\n\nOutput is written under <repo>/tmp/ using the basename of <output-file>.",
    );
    process.exitCode = 1;
    return;
  }
  const path = resolveOutputPath(out);
  mkdirSync(TMP_DIR, { recursive: true });

  if (html) {
    const domHtml = await scrapeDanmurphysFirstPage({ mode: "html", pagesToLoad: maxPages });
    writeFileSync(path, domHtml, "utf8");
    console.error(`Wrote DOM HTML (${domHtml.length} chars) to ${path}`);
    return;
  }

  const products = await scrapeDanmurphysFirstPage({ pagesToLoad: maxPages });
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
