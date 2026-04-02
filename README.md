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

### Debug (visible browser)

If you need to see the page (modals, layout issues):

```bash
HEADFUL=1 npm run scrape -- ../result.json
```

## Scope

The Dan Murphy’s adapter currently scrapes the **first page** of [`/beer/all`](https://www.danmurphys.com.au/beer/all) only. Loading more products (e.g. “Show more”) is planned as a follow-up.
