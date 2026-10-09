# occurrentdevelopment.com

Source for the site. `SPEC.md` is the build brief; `BACKLOG.md` lists what is deliberately not built.

## Building

Needs Racket with the `pollen` package; Python 3 with `fonttools`, `brotli` and Pillow (`pip install -r tools/requirements.txt`); `avifenc` (libavif) for figures; and pandoc for `make refresh`.

| Command | Does |
|---|---|
| `make` | Runs the tests, subsets the fonts, renders every page and assembles `public/`. Works offline. |
| `make test` | Typography rules and the root pass (`typography-test.rkt`, `pollen-test.rkt`). |
| `make serve` | Pollen's project server on http://localhost:8080 (pages at `/pages/<name>.html`). |
| `make refresh` | Copies the cited entries from your Zotero export into `refs/refs.bib` and has pandoc format them into `data/cite-cache.json`. Run it after adding a citation; commit both files. |
| `make clean` | Removes everything generated. |

The project server renders on request, so it can show stale cross-page information (backlinks, once they exist) until `make` runs. CI always does a full rebuild.

## Citations and Emacs

References live in Zotero. Keep a Better BibTeX auto-export of the whole library, and name it in an untracked `local.mk` at the repository root:

```make
ZOTERO_BIB = ~/path/to/Zotero-Library.bib
```

`emacs/occurrent.el` provides the writing commands (`C-c o c` cites from the whole library, through citar when installed; `C-c o t` terms; `C-c o s` sections; and so on). Load it and enable `occurrent-mode` for `.pm` files. Only cited entries reach the public repository, without abstracts, notes or file paths.

## Deploying

Every push builds on GitHub Actions (`.github/workflows/deploy.yml`). Pushes to `main` also deploy `public/` to the Cloudflare Worker `site` with wrangler. Cloudflare's own Git build is disconnected: its build image has no Racket.

## Layout

- `pollen.rkt`: tag functions, the root pass (paragraphs, section tree, TOC) and template helpers.
- `typography.rkt`: the typographic rules table.
- `template.html.p`: the single page template.
- `pages/`: specimen, colophon. `/specimen` is the test bed for every CSS change.
- `assets/`: CSS, the theme script, icons, and the Libertinus fonts (OFL; see `assets/fonts/README.md`).
- `lib/`: citations, glossary, lists, tables, figures and marks.
- `glossary/`: one file per term; never a page.
- `refs/`: the generated `refs.bib` and the Chicago notes CSL style (CC BY-SA 3.0).
- `tests/`: fixtures rendered by the tests.
- `tools/`: font subsetting, image variants, the citation refresh, and site-wide validation.
