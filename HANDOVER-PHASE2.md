# Handover to Claude Code — Finish Phase 2, build the Emacs mode

Status: 1.1 · Owner: Ryan · 2026-10-21

Two jobs, in this order. Do not start Phase 3 (SPEC §15); it waits for both.

## Job A — Finish Phase 2

Phase 2 was built on 2026-10-12 and the spec has moved four times since without a rebuild. The Phase 2 row of SPEC §15 lists exactly what is outstanding, by requirement ID, under the dates 2026-10-15, 2026-10-19, 2026-10-20 and 2026-10-21. Work from that list, not from memory of the code.

1. Read `SPEC.md` in full, then `COMPAT.md`. Where the two disagree on a CSS property name, `COMPAT.md` is right (TYPE-4a).
2. Diff the code against every ID named in the Phase 2 row for **2026-10-15** and **2026-10-19**. Some of these may already be built; confirm each one on the specimen page rather than assuming either way, and list what was already done in your report.
3. Build every item dated **2026-10-20**. In full:
   - `#:italic` on `◊epigraph` and `◊blockquote`; block quotations roman by default; `◊em` roman inside an italic block (LAYOUT-4a, 4b, 4c; §3.3).
   - The index routed through the shared table code, with the cell-count check and the fixture test (INDEX-1a). Build this as the `◊index[#:kind]` function of step 4, not as `◊essay-index{}` first and a rename after.
   - A `◊margin` at the end of a paragraph, item or quoted paragraph is a build error (MNOTE-6, VAL-1).
   - Quotation marks curled with their context across inline tags; a straight quote in rendered prose fails the build; the TYPE-14 tests listed under TYPE-16.
   - One baseline for the contents label, the title and the metadata block (LAYOUT-1a); the metadata reordered with source links after the tags and the epistemic line last after a 1em gap, optional (LAYOUT-1); the tags line labelled "Tagged" (LAYOUT-1b); the short rule closing the header (LAYOUT-1c); the reading bar sized to the text block and aligned to the column (BAR-1d).
   - `◊latex{}`, the logo as kerned letters of the text face, with its accessible name (TYPE-17; §3.3).
   - The specimen page updated to show all of this (THEME-7), and its "There is no separate bibliography" sentence corrected (CITE-10).
4. Build every item dated **2026-10-21**: the restructure (SPEC §13a, §13b). In full:
   - `kind` inferred from the folder (`essays/` → `essay`, `notebook/` → `entry`); `◊define-meta[kind]` a build error; slugs unique across both folders and checked against the reserved list; entries served at `/notebook/<slug>`, essays unchanged at `/<slug>`; a `kind-entry` class on the page wrapper and nothing else kind-specific in CSS or script (KIND-1). `notebook/*/support/` gitignored (BUILD-3a). DRAFT-2 applies to both.
   - The meta rules by kind: `epistemic` and `◊changelog` build errors in an entry, `abstract` optional there (KIND-2; §13 table).
   - Entry chrome: no contents at any section count; the header with the epistemic line and gap left out; the bar unchanged (KIND-3).
   - `◊index[#:kind "essay"|"entry"]` through the shared table code, with four and three columns respectively, both fixture tests, and per-index tag sets with the address at `/essays?tags=` and `/notebook?tags=` (INDEX-1a, INDEX-3, KIND-4). `◊essay-index{}` is retired.
   - `pages/index.html.pm` as the About page with the Start-here line and `◊latest[3]`; `pages/essays.html.pm` and `pages/notebook.html.pm` as the indexes; `/about` redirected to `/` (HOME-1, INDEX-1, ABOUT-2). Carry the existing About text and the old home page's explanatory paragraph to their new homes; do not write new prose.
   - The menu: Home · Essays · Notebook · Glossary, with `aria-current` on Essays for an essay and Notebook for an entry (NAV-1). Tag links in the header go to the post's own index (LAYOUT-1b).
   - Entries in the link graph, fragments, backlinks and `anchors.json` (KIND-5).
   - A fixture entry under `tests/` exercising KIND-2's errors and KIND-3's header; the specimen MAY gain an entry-form header (THEME-7).
   - Emacs (KIND-6) belongs to Job B, not here: do not touch `emacs/`. List what Job B must add in your report.
5. `make test` and `make` pass. Then view `/`, `/essays`, `/notebook`, a fixture entry and `/specimen` in Chrome, Safari and Firefox at tiers XL, L, M and S (resize; a text-size step up is a cheap way to cross a tier, THEME-5) and in both themes. Fix what you see.
6. Stop and report: what from steps 2–4 was already built; what you built; anything in the spec you could not satisfy as written and what you did instead; what Job B must add for KIND-6; and screenshots of the specimen header at XL, of the reading bar at L, of `/` at L, and of an entry's header beside an essay's at L. Ryan does the phone checks.

Do not touch `emacs/` in this job, and do not begin anything from Phase 3 (backlinks, changelog, glossary page, reference pages, feed, correspondence, Wayback, print CSS) even where it would be convenient; KIND-5's hooks into `links.json` and `anchors.json` are Phase 2 because the pre-pass already exists, but the Backlinks section itself stays Phase 3.

## Job B — The Emacs mode

Everything is specified in `HANDOVER-EMACS.md`, plus KIND-6 in SPEC §13b (the kind prompt in `od-new-essay`, `entry` in `od-file-kind`, `od-insert-changelog` refusing in an entry, entries in `od-insert-link-essay`, tags from both kinds in `od-set-tags`, and the by-kind refusals in the vocabulary table). Read it, then follow its §13 opening prompt exactly; stop where its §12 says and report as it asks. This job touches only `emacs/`, `Makefile` (the `test-emacs` target) and one test in `pollen-test.rkt` (VOCAB-3), so it can run after Job A in the same session or in a parallel session on its own branch; if parallel, do not rebase onto Job A's branch until A is merged.

## Opening prompt

> Read `HANDOVER-PHASE2.md` in this repo and do Job A as written: read `SPEC.md` and `COMPAT.md`, check the 2026-10-15 and 2026-10-19 items in the Phase 2 row of SPEC §15 against the code, build every 2026-10-20 and 2026-10-21 item, get `make` green, check the pages it names in three browsers at four tiers, and stop with the report it asks for. Then, after I have looked, do Job B.
