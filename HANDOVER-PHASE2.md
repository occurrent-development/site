# Handover to Claude Code — Finish Phase 2, build the Emacs mode

Status: 1.0 · Owner: Ryan · 2026-10-20

Two jobs, in this order. Do not start Phase 3 (SPEC §15); it waits for both.

## Job A — Finish Phase 2

Phase 2 was built on 2026-10-12 and the spec has moved three times since without a rebuild. The Phase 2 row of SPEC §15 lists exactly what is outstanding, by requirement ID, under the dates 2026-10-15, 2026-10-19 and 2026-10-20. Work from that list, not from memory of the code.

1. Read `SPEC.md` in full, then `COMPAT.md`. Where the two disagree on a CSS property name, `COMPAT.md` is right (TYPE-4a).
2. Diff the code against every ID named in the Phase 2 row for **2026-10-15** and **2026-10-19**. Some of these may already be built; confirm each one on the specimen page rather than assuming either way, and list what was already done in your report.
3. Build every item dated **2026-10-20**. In full:
   - `#:italic` on `◊epigraph` and `◊blockquote`; block quotations roman by default; `◊em` roman inside an italic block (LAYOUT-4a, 4b, 4c; §3.3).
   - The home-page index routed through the shared table code, with the cell-count check and the fixture test (INDEX-1a).
   - A `◊margin` at the end of a paragraph, item or quoted paragraph is a build error (MNOTE-6, VAL-1).
   - Quotation marks curled with their context across inline tags; a straight quote in rendered prose fails the build; the TYPE-14 tests listed under TYPE-16.
   - One baseline for the contents label, the title and the metadata block (LAYOUT-1a); the metadata reordered with source links after the tags and the epistemic line last after a 1em gap, optional (LAYOUT-1); the tags line labelled "Tagged" (LAYOUT-1b); the short rule closing the header (LAYOUT-1c); the reading bar sized to the text block and aligned to the column (BAR-1d).
   - `◊latex{}`, the logo as kerned letters of the text face, with its accessible name (TYPE-17; §3.3).
   - The specimen page updated to show all of this (THEME-7), and its "There is no separate bibliography" sentence corrected (CITE-10).
4. `make test` and `make` pass. Then view `/specimen` in Chrome, Safari and Firefox at tiers XL, L, M and S (resize; a text-size step up is a cheap way to cross a tier, THEME-5) and in both themes. Fix what you see.
5. Stop and report: what from steps 2–3 was already built; what you built; anything in the spec you could not satisfy as written and what you did instead; and screenshots of the specimen header at XL and of the reading bar at L. Ryan does the phone checks.

Do not touch `emacs/` in this job, and do not begin anything from Phase 3 (backlinks, changelog, glossary page, reference pages, feed, correspondence, Wayback, print CSS) even where it would be convenient.

## Job B — The Emacs mode

Everything is specified in `HANDOVER-EMACS.md`. Read it, then follow its §13 opening prompt exactly; stop where its §12 says and report as it asks. This job touches only `emacs/`, `Makefile` (the `test-emacs` target) and one test in `pollen-test.rkt` (VOCAB-3), so it can run after Job A in the same session or in a parallel session on its own branch; if parallel, do not rebase onto Job A's branch until A is merged.

## Opening prompt

> Read `HANDOVER-PHASE2.md` in this repo and do Job A as written: read `SPEC.md` and `COMPAT.md`, check the 2026-10-15 and 2026-10-19 items in the Phase 2 row of SPEC §15 against the code, build every 2026-10-20 item, get `make` green, check the specimen in three browsers at four tiers, and stop with the report it asks for. Then, after I have looked, do Job B.
