# occurrentdevelopment.com

Source for the site. `SPEC.md` is the build brief; `BACKLOG.md` lists what is deliberately not built.

## Building

Needs Racket with the `pollen` package, and Python 3 with `fonttools` and `brotli` (`pip install -r tools/requirements.txt`).

| Command | Does |
|---|---|
| `make` | Runs the tests, subsets the fonts, renders every page and assembles `public/`. Works offline. |
| `make test` | Typography rules and the root pass (`typography-test.rkt`, `pollen-test.rkt`). |
| `make serve` | Pollen's project server on http://localhost:8080 (pages at `/pages/<name>.html`). |
| `make refresh` | Updates the committed caches from the network. Nothing to refresh yet. |
| `make clean` | Removes everything generated. |

The project server renders on request, so it can show stale cross-page information (backlinks, once they exist) until `make` runs. CI always does a full rebuild.

## Deploying

Every push builds on GitHub Actions (`.github/workflows/deploy.yml`). Pushes to `main` also deploy `public/` to the Cloudflare Worker `site` with wrangler. Cloudflare's own Git build is disconnected: its build image has no Racket.

## Layout

- `pollen.rkt`: tag functions, the root pass (paragraphs, section tree, TOC) and template helpers.
- `typography.rkt`: the typographic rules table.
- `template.html.p`: the single page template.
- `pages/`: specimen, colophon. `/specimen` is the test bed for every CSS change.
- `assets/`: CSS, the theme script, icons, and the Libertinus fonts (OFL; see `assets/fonts/README.md`).
- `tools/fonts.py`: subsets the fonts to WOFF2.
