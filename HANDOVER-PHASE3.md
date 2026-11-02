# Handover to Claude Code — Phase 3: around the essays

Status: 1.0 · Owner: Ryan · 2026-11-02

Phase 2c landed and passed Ryan's checks (`reports/2026-10-26-phase2c/`). This handover is the **Phase 3** row of `SPEC.md` §15 (draft 1.16), in build order, with what the spec leaves to you. Phase 3 is the apparatus *around* an essay: the link graph and everything built from it (backlinks, the glossary page, reference pages, the bibliography), the changelog, the feed, the Wayback job, and inline mathematics. Nothing in the text of an essay changes except for two new ways of writing a citation (BIB-9).

Read `SPEC.md` in full first; §5a was rewritten on 2026-11-02 (BIB-1, BIB-5…9), and §3.3, CITE-8, IMG-6, POP-7, §16 and §17 changed with it. Then `COMPAT.md`. Do not work from memory of earlier drafts.

Three jobs. **Job A** is the site and is the bulk of the work. **Job B** is mathematics, independent of A, with a TeX dependency Ryan must install first; do it after A, or in a parallel session on its own branch. **Job C** is Emacs; do it last, after Ryan has looked at A.

Commit the uncommitted doc changes first (`SPEC.md`, `HANDOVER-EMACS.md`, this file), as one commit before any code: "Spec 1.16: Phase 3 handover; covers, reference cards, quotations (BIB-7…9)".

## Before you start (Ryan's part)

Two things only Ryan can do, and the build depends on both:

1. **Pin the keys.** Every key cited by a published post, or by the draft you will test with, is pinned in Zotero (BIB-2). For the test: `pirsigZenArtMotorcycle1991` (his 1991 Vintage copy; the page numbers are that edition's).
2. **One cover in Zotero.** A photograph of the Pirsig copy's cover, attached to the item as a stored file named `cover.jpg` (BIB-7), so that `make refresh` has something to find and the first end-to-end check is real. Confirm the path appears in `~/Documents/Ryan/References/Zotero-Library.bib` under that entry's `file` field; if Better BibTeX's auto-export did not pick up the new attachment, export once by hand.

Tests must not depend on either: fixtures carry their own small cover and their own `.bib`.

## Job A — The site

### 1. The link graph (VAL-2, VAL-4, BIB-6, TERM-8's Used in, KIND-5)

Everything else in this job reads one file, so build it first and build it once.

- `tools/validate.rkt` (or a pre-pass in `pollen.rkt`; your call, but one walk) records, for every published post of both kinds: every internal link with its context; every `◊cite` with its context; every quotation (step 2) with its text, locator, section and mark id; and which pages mark each glossary term. Write `data/links.json` in a shape that carries links per page, cites and quotations per key, and terms per page. `data/anchors.json` as now.
- Context = the containing paragraph, list item or aside, as an X-expression with the link or circle marked, so the Backlinks and Cited in lists can render it with the site's own markup (collapsed to ~2 lines, expandable).
- BUILD-4 holds: `make` is a full rebuild; the project server may show stale lists. Say so in the README if it does not already.
- Drafts (DRAFT-2) contribute nothing to the committed graph, exactly as CITE-5a keeps their citations out of the committed cache. Decide how the local build previews a draft's own backlinks and reference pages (a merged local graph, as the caches merge) and document it.

### 2. Quotations (BIB-9, §3.3, CITE-8)

- `◊q["key" #:loc "…"]{text}`: a `◊cite` with the quoted text attached. Quotation marks from the typography pass (TYPE-16; nested quotation takes single marks), then the circle; MARK-3a puts the closing mark and any punctuation between the last word and the circle. Numbered, formed and back-linked exactly as a `◊cite`. `◊em` and `◊sc` inside; `◊cite`, `◊term`, `◊aside`, `◊link`, `◊margin` and an empty body are build errors with messages that name the rule.
- `#:cite` and `#:loc` on `◊blockquote` and `◊epigraph`: the circle follows the `#:source` line, or stands alone on that line when there is none. `#:loc` without `#:cite` is a build error.
- The walk records each quotation's plain text (markup dropped), locator, post, section and mark id. A quoting citation is also a Cited in context; do not de-duplicate.
- Fixture: extend the CITE-8 essay in `tests/` with one `◊q` and one `◊blockquote` with `#:cite`; assert numbers, forms, back-links and the Quoted list.

### 3. Covers from Zotero (BIB-7, IMG-1, IMG-4, IMG-6)

- `tools/refs.py`, at `make refresh`: for every cited key, read the `file` field of the Zotero export (absolute paths, `;`-separated; the parser is already there), take the image attachment named `cover.*`, or the only image attachment; two or more images with none named `cover` is an error naming them; HEIC is an error asking for a JPEG export. Write `refs/covers/<key>.jpg`, longest side 800 px (Pillow), committed. Delete the copy with a warning when the attachment is gone. The `file` field is still stripped from `refs.bib`.
- `tools/images.py` makes variants at 160, 320, 640 and manifest entries for `refs/covers/*`. Covers are never sent to InvertOrNot; dimmed in dark mode, never inverted (a fixed classification, not a lookup).
- `#:licence cover` is accepted by the figure machinery only where the build itself emits a cover; an author writing `◊figure[… #:licence "cover"]` is a build error (the value exists for one thing).
- Fixture: a 100 × 150 px cover in `tests/` and a fixture `.bib` with a `file` field pointing at it; a test that the refresh step copies and sizes it, and another that an entry with no image attachment yields no cover and no error.

### 4. Reference pages, the card, and the note popup (BIB-1…3, BIB-5, BIB-8, POP-7, CITE-10)

- `/references/<key>` for every key in the cache: entry with the cover at its left (about 7em tall, top-aligned); DOI and URL as external links with ↗ (and the Wayback copy once step 8 records one); the commentary from `references/<key>.pm` when present (BIB-3: paragraphs only, the allowed inline tags, citations unnumbered per CITE-7; anything else a build error; a file whose key is not in the cache a build error); **Quoted** grouped by post in index order, each passage in the text face with its locator muted after it and a → to the mark; **Cited in** as Backlinks are rendered. The page uses the site template (menu, bar, themes, text size); its title is the work's title, its header carries no dates or tags, and its margin block holds only the source links (REV-2) pointing at `references/<key>.pm` when it exists and nothing otherwise. Reference pages are not listed in any index or feed.
- `/_x/references/<key>.frag`: the reference card. Cover, entry, DOI/URL, the first paragraph of the commentary, and the line *Cited in n posts · Reference page →*. One function renders the card for the fragment and for the page's head.
- The note popup: note as now; a hairline; the card, fetched on `pointerenter` and cached as cross-essay fragments are. Under a full-form note the card omits the entry; under a short-form note it shows it. Title bar: the title links to the reference page and Open in new tab goes there (BIB-5). Touch: the popin shows the same card. No script, no change.
- Per-essay Notes and Bibliography: each work links to its page with → (BIB-5). End matter order per CITE-10, now with **Backlinks** (step 5) in its place.
- `references` and `_x` are reserved slugs already (KIND-1); check that `_redirects` and the Worker serve `/references/<key>` with the key's case preserved (BIB-2).

### 5. Backlinks (VAL-4)

Each post ends with **Backlinks** between Bibliography and Changelog: the linking posts and sections, each context collapsed to ~2 lines and expandable, kind marked for entries (KIND-5). Same-page links are not backlinks. The expand control works without scripts (`<details>`), as the menu does.

### 6. The glossary page and the bibliography (TERM-8, BIB-4, NAV-1)

- `/glossary`: every term alphabetically, with aliases, short definition, `◊more`, see-also as same-page links, **Used in** from the graph, anchors `#<id>`. Essays never link here (TERM-3).
- `/bibliography`: one `◊table` through the shared table code (INDEX-1a): Author · Year · Title · Type · Cited in, sorted by author then year, title → the work's page, Cited in a count. No covers here (BIB-7).
- Menu order: Home · Essays · Notebook · Glossary · Bibliography · Scratch, in the one list in `pollen.rkt`.

### 7. Changelog (REV-3, KIND-2, §16)

`◊changelog{…}` renders in the end matter after Backlinks; `/changelog` aggregates every line site-wide, newest first, each with its post. A `◊changelog` in an entry is a build error. Unblock `od-insert-changelog` is Job C's; here, make the tag.

### 8. Feed, Wayback, the dead-link job (REV-4, CARD-3, CARD-5)

- One Atom feed, `/feed.xml`, both kinds, each item marked with its kind; new posts and substantive revisions (a changelog line dated after `published`). An essays-only feed MAY exist; do it only if trivial. `<link rel="alternate" type="application/atom+xml">` on every page. Validate with the W3C feed validator and record the result in the report.
- `make refresh` asks the Wayback Machine to save each external URL not yet in `data/link-meta.json` and records the snapshot URL; cards and reference pages show **Wayback copy** where one exists. Never from `make`; never from the reader's browser.
- A monthly GitHub Actions job re-checks live URLs and opens an issue listing dead ones; it never fails a build. Marking a link dead is a one-field edit in `link-meta.json`.

### 9. Specimen, tests, checks

- The specimen (THEME-7) gains: an inline `◊q`, a block quotation with `#:cite`, a note popup showing a card with a cover (use the Pirsig item once Ryan has attached it; otherwise the fixture cover, and say so), and a Backlinks section with one real entry.
- `make test` and `make` green, with the new tests above and the VOCAB-3 sync test still passing once Job C lands (`q` is a built tag then).
- Budgets (§14) hold: the card adds no page weight; measure the JS delta and report it.

### 10. Stop and report

What you built; anything you could not satisfy as written and what you did instead; the shape of `links.json`; screenshots of `/references/pirsigZenArtMotorcycle1991` (or the fixture work) with cover, Quoted and Cited in, of a note popup with the card in light and dark, of `/bibliography`, `/glossary` and a Backlinks section; the feed validator's result. Write it to `reports/<date>-phase3/REPORT.md` beside the earlier reports. Ryan does the phone checks.

Do not begin Phase 4 (print, PDF) or Phase 5 (audio).

## Job B — Inline mathematics (MATH-1, §16)

Needs LuaLaTeX, `unicode-math`, Libertinus Math and `dvisvgm` on Ryan's Mac (he installs them; say exactly what, in the report, if anything is missing). `◊m{…}`, pre-rendered at `make refresh` to `currentColor` SVG with its baseline offset, cached in `data/math-cache.json` by SHA-256, inlined at build only on pages that use it; a missing cache entry fails the build with "run `make refresh`". `#:display #t` centres on its own line. MARK-2's test applies to an ordinary inline expression. `make` stays TeX-free (BUILD-2). Specimen: one inline expression in body text, one in italic, one display. Stop and report as for Job A.

## Job C — Emacs (§16, HANDOVER-EMACS.md)

After Ryan has looked at Job A. `od-new-reference` (`C-c o R`); `od-insert-q` (`C-c o "`, the region as the body, key picked as `od-insert-cite` with the pinned-key check, then the locator, a warning when none); `od-insert-blockquote` and `od-insert-epigraph` prompting for a key (empty for none) and locator; `od-insert-math` (`C-c o $`) once Job B lands, else a `user-error`; `od-insert-changelog` unblocked; `od-file-kind` gains `reference`; `od-vocabulary` gains `q`, `m`, `changelog` as `:built` when they are, and the new keywords, so the highlighter accepts them (FL-6) and the sync test holds (VOCAB-3). `make test-emacs` green; `checkdoc` clean.

## Opening prompt

> Read `HANDOVER-PHASE3.md` in this repo and do Job A as written: read `SPEC.md` (draft 1.16) and `COMPAT.md`; commit the pending doc changes; build the Phase 3 row of SPEC §15 in the order the handover gives (link graph, quotations, covers, reference pages and the card, backlinks, glossary and bibliography pages, changelog, feed and Wayback, specimen); get `make` green; and stop with the report it asks for. Then, after I have looked, Job B and Job C.
