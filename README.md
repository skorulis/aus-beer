# aus-beer

Beer listing data from Australian retailers. The scraper lives in [`scraper/`](scraper/).

## Prerequisites

- [Node.js](https://nodejs.org/) (current LTS is fine)
- Network access to the target site (Playwright launches Chromium)

## Setup

From the repository root:

```bash
cd scraper
npm install
```

`npm install` runs `playwright install chromium` so the browser binary is available for the first scrape.

## Run the scraper

Still inside `scraper/`, pass the path to the JSON file you want to write:

```bash
npm run scrape -- path/to/output.json
```

Or use the explicit flag:

```bash
npm run scrape -- --out path/to/output.json
```

Example writing to the repo root:

```bash
npm run scrape -- ../result.json
```

### Load more pages

Dan Murphy’s uses a `“Show x more”` button to load more products. You can control how many pages get loaded before parsing:

```bash
npm run scrape -- --max-pages 3 ../result.json
```

This also works with `--html` fixture snapshots:

```bash
npm run scrape -- --html --max-pages 3 ../scraper/fixtures/danmurphys-beer-all.html
```

### Debug (visible browser)

If you need to see the page (modals, layout issues):

```bash
HEADFUL=1 npm run scrape -- ../result.json
```

## Scope

By default, the Dan Murphy’s adapter scrapes the **first page** of [`/beer/all`](https://www.danmurphys.com.au/beer/all). You can load additional pages (clicks the “Show x more” button) by passing `pagesToLoad` to `scrapeDanmurphysFirstPage(...)` / `parseDanmurphysProductsFromFixture(...)`.

## Swift app (`SwiftScraper/`)

Native macOS client and parsers live under [`SwiftScraper/`](SwiftScraper/). You need **Xcode** (matching the project’s deployment target) on macOS.

### Run unit tests from the command line

From the repository root:

```bash
cd SwiftScraper
xcodebuild -scheme SwiftScraper -destination 'platform=macOS' test
```
