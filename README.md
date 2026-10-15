# occurrentdevelopment.com

Source for the site. `SPEC.md` is the build brief; `BACKLOG.md` lists what is deliberately not built.

## Building

Needs Racket with the `pollen` package; Python 3 with `fonttools`, `brotli` and Pillow (`pip install -r tools/requirements.txt`); `avifenc` (libavif) for figures; and pandoc for `make refresh`.

| Command | Does |
|---|---|
| `make` | Runs the tests, subsets the fonts, renders every page and assembles `public/`. Works offline. |
| `make test` | Typography rules and the root pass (`typography-test.rkt`, `pollen-test.rkt`). |
| `make serve` | Pollen's project server on http://localhost:8080 (pages at `/pages/<name>.html`). |
| `make refresh` | Copies the cited entries from your Zotero export into `refs/refs.bib`, has pandoc format them into `data/cite-cache.json`, and classifies new figures for dark mode into `data/invert.json`. Run it after adding a citation or a figure; commit the changed files. |
| `make clean` | Removes everything generated. |

The project server renders on request, so it can show stale cross-page information (backlinks, once they exist) until `make` runs. CI always does a full rebuild.

## Citations and Emacs

References live in Zotero. Keep a Better BibTeX auto-export of the whole library, and name it in an untracked `local.mk` at the repository root:

```make
ZOTERO_BIB = ~/path/to/Zotero-Library.bib
```

`emacs/occurrent.el` is the major mode for writing the site: `.pm` files open in `occurrent-mode`, which dims markup, marks anything the build would refuse, and holds the writing, checking and publishing commands under `C-c o` (`C-c o I` opens a guide to starting, publishing and revising an essay). Set up with:

```elisp
(add-to-list 'load-path "~/Documents/Ryan/Personal/Projects/Occurrent-Development/site/emacs")
(require 'occurrent)
```

`make test-emacs` runs its tests. `HANDOVER-EMACS.md` specifies it. Only cited entries reach the public repository, without abstracts, notes or file paths.

## Deploying

Every push builds on GitHub Actions (`.github/workflows/deploy.yml`). Pushes to `main` also deploy `public/` to the Cloudflare Worker `site` with wrangler. Cloudflare's own Git build is disconnected: its build image has no Racket.

## Layout

- `pollen.rkt`: tag functions, the root pass (paragraphs, section tree, TOC) and template helpers.
- `typography.rkt`: the typographic rules table.
- `template.html.p`: the single page template.
- `index.html.pm`: the home page. Its table of essays is built from every page in `index.ptree` that has a `published` date.
- `essays/<slug>/<slug>.html.pm`: one folder per essay, each listed in `index.ptree` (the build fails otherwise) and served at `/<slug>`. Tags are a meta line, `◊define-meta[tags]{philosophy, site}`; `C-c o T` in Emacs picks from the tags already in use.
- `pages/`: about, specimen, colophon. `/specimen` is the test bed for every CSS change.
- `assets/`: CSS; `js/site.js` (popups, margin, reading bar, theme and text size) and `js/tables.js` (sorting, pinned headers), both plain ES modules; icons; the Libertinus fonts (OFL; see `assets/fonts/README.md`).
- `lib/`: citations, glossary, lists, tables, figures and marks.
- `glossary/`: one file per term; never a page.
- `refs/`: the generated `refs.bib` and the Chicago notes CSL style (CC BY-SA 3.0).
- `tests/`: fixtures rendered by the tests.
- `tools/`: font subsetting, image variants, the citation refresh, dark-mode classification, and site-wide validation (which also writes the cross-page fragments in `build/_x/` and the publish list).
