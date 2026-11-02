# occurrentdevelopment.com

Source for the site. `SPEC.md` is the build brief; `BACKLOG.md` lists what is deliberately not built.

## Building

Needs Racket with the `pollen` package; Python 3 with `fonttools`, `brotli` and Pillow (`pip install -r tools/requirements.txt`); `avifenc` (libavif) for figures; and pandoc for `make refresh`.

| Command | Does |
|---|---|
| `make` | Runs the tests, subsets the fonts, writes the link graph, renders every page and assembles `public/`. Works offline. |
| `make test` | Typography rules and the root pass (`typography-test.rkt`, `pollen-test.rkt`), and the covers step of `make refresh` (`tools/refs_test.py`). |
| `make test-browser` | The interactive layer in headless Chrome against the built site (`tools/browser_test.py`, `tests/browser/`); part of `make`, skipped without Chrome. `--browser firefox` or `--browser safari` runs it elsewhere by hand; `--shots DIR` saves the specimen screenshots. |
| `make serve` | Pollen's project server on http://localhost:8080 (pages at `/pages/<name>.html`, a work's page at `/build/references/<key>.html`). Previews drafts with their own backlinks and citations (below). |
| `make refresh` | Copies the cited entries from your Zotero export into `refs/refs.bib`, has pandoc format them into `data/cite-cache.json`, copies each cited work's cover (a `cover.jpg` attached to the item in Zotero) to `refs/covers/`, classifies new figures for dark mode into `data/invert.json`, and asks the Wayback Machine to keep a copy of each new external URL (`data/link-meta.json`). Run it after adding a citation, a cover, a figure or a link; commit the changed files. |
| `make refresh-cites` | The citation part of `make refresh` alone (entries, notes, covers): pandoc and local files, no network. `C-c o p` in Emacs runs it for you when a page cites a work at a locator not yet in the cache, then restarts the server. |
| `make clean` | Removes everything generated. |

### The link graph, and why `make serve` can be stale

Backlinks, a work's page (its Quoted and Cited in), the glossary's Used in, the bibliography's counts and `/changelog` are all built from one file, `data/links.json`, which `tools/validate.rkt` writes by walking every published post before anything is rendered (SPEC VAL-4, BIB-6). Every page therefore depends on every other. `make` handles this: the graph is in Pollen's cache watchlist, so when it changes every page is rendered again, and `make` is always as good as a full rebuild (BUILD-4). CI always builds from scratch.

The project server renders a page when you ask for it, from the graph as `make serve` found it when it started. It can show stale Backlinks, Used in and Cited in lists until you run `make`, or restart `make serve`.

Drafts contribute nothing to `data/links.json`, exactly as their citations stay out of the committed cache (CITE-5a): their links, citations and quotations go to `data/links.local.json` (gitignored). `make` never reads that file, so nothing a draft says can reach a published page. `make serve` sets `OD_PREVIEW=1`, and then the graph, the citation caches and the covers all merge their drafts' halves: a draft previews with its own backlinks from other drafts, and the pages of the works it cites show it under Cited in and Quoted. Pollen keeps the two kinds of build in separate caches.

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
- `pages/index.html.pm`: the front page, a paragraph and `◊recent[3]`, the newest essays and blog entries built from the posts' metas.
- `essays/<slug>/<slug>.html.pm`: one folder per essay, each listed in `index.ptree` (the build fails otherwise) and served at `/<slug>`. Tags are a meta line, `◊define-meta[tags]{philosophy, site}`; `C-c o T` in Emacs picks from the tags already in use.
- `blog/<slug>/<slug>.html.pm`: blog entries, the second kind of post, the same shape as an essay's folder and served at `/blog/<slug>`.
- `pages/`: about, the essay and blog indexes, the glossary, the bibliography, the changelog, correspondence and the specimen. `/specimen` is the test bed for every CSS change. A page that should have no end matter sets `◊define-meta[endmatter]{none}` (the glossary and the front page).
- `assets/`: CSS; `js/site.js` (popups, margin, reading bar, theme and text size) and `js/tables.js` (sorting, pinned headers), both plain ES modules; icons; the Libertinus fonts (OFL; see `assets/fonts/README.md`).
- `lib/`: citations, glossary, lists, tables, figures and marks.
- `glossary/`: one file per term; never a page.
- `refs/`: the generated `refs.bib` and the Chicago notes CSL style (CC BY-SA 3.0).
- `tests/`: fixtures rendered by the tests (`tests/refs/` for the covers step).
- `references/<key>.pm`: optional commentary on a cited work, set on its page (SPEC BIB-3). The page itself, `/references/<key>`, is generated for every cited work.
- `lib/walk.rkt`, `lib/graph.rkt`: the one walk that makes the link graph, and its reader.
- `tools/`: font subsetting, image variants, the citation refresh (entries and covers), dark-mode classification, Wayback snapshots (`wayback.py`) and the monthly dead-link check (`linkcheck.py`, run by `.github/workflows/links.yml`, which opens an issue and never fails a build), and site-wide validation, which runs before rendering: it writes the link graph, the work pages' sources in `build/references/`, the cross-page fragments and reference cards in `build/_x/`, the Atom feed and the publish list.
