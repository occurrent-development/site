# Handover to Claude Code — Phase 3b: the reference card, in fields

Status: 1.0 · Owner: Ryan · 2026-11-02 (evening)

Phase 3 Job A landed (`reports/2026-11-02-phase3/`, commits `f994d32` and `c7ca1a3`). Ryan looked at the note popup and the reference page and changed his mind about their shape, and about how a quotation is written. `SPEC.md` draft 1.18 records it: BIB-1, BIB-6…9 rewritten, BIB-10 new, §3.3, CITE-8, POP-7 and §16 revised; `STYLE.md` and `HANDOVER-EMACS.md` follow. This handover is those changes in build order. Nothing in Phase 3 outside §5a is touched.

Read the 1.18 text of §5a, §3.3 (`◊cite`, `◊blockquote`, `◊epigraph`), CITE-8, POP-7 and §16 before starting; do not work from the 1.16 text or from the code as built. Commit the uncommitted docs first, in one commit: `SPEC.md`, `STYLE.md` (new, Ryan's manual of style, which SPEC line 9 already names; §17 moved into it), `HANDOVER-EMACS.md`, this file: "Spec 1.18: cite with a body, the fields head, one Cited in; STYLE.md".

## What changed, in one paragraph

A `◊cite` with a body is a quotation of those words; `#:block #t` makes it a block quotation whose attribution the build writes from the entry. `◊q` and `#:cite`/`#:loc` on `◊blockquote` and `◊epigraph` are withdrawn. The reference page's head and the card are no longer a Chicago entry but the title, the cover at its right at 14em, and labelled fields at one tab stop, from a CSL record that `make refresh` stores. The citation popup is the card alone, with the citation's locator and remark slotted under the title; the Chicago note is only the fetch-failed fallback. Quoted and Cited in are one list.

## Job A — The site

### 1. `◊cite` with a body; the withdrawals (BIB-9, §3.3, CITE-8)

- `◊cite["key" #:loc "…"]{words}`: what `◊q` did, under the citation's own name. Keep the TYPE-16 handling (nested quotation → single marks), MARK-3a, the numbering and the back-link; the build errors for `◊cite`, `◊term`, `◊aside`, `◊link`, `◊margin` inside and for an empty body, now naming BIB-9 in its 1.18 wording.
- `#:block #t`: rendered as `◊blockquote` is (same markup and classes, LAYOUT-4b; `#:italic #t` as there), with an attribution line the build writes: *Given Family, Title, p. n*, author and locator omitted when absent, the circle at the end of the line. `#:source` replaces the generated line. `#:block`, `#:italic` or `#:source` on a `◊cite` with no body is a build error.
- Remove `◊q` and the `#:cite`/`#:loc` keywords from `◊blockquote` and `◊epigraph` entirely (not deprecated: nothing published used them). Update the specimen, the CITE-8 fixture (a body cite as note 6, a block cite as note 7, same numbers as before), `od-vocabulary` and the VOCAB-3 sync test, and the highlighter's keyword table (FL-6).
- The pre-pass records a body cite's text and `block?` on the citation record; drop the separate quotation records and whatever read them.

### 2. The CSL record and the bigger cover (BIB-10, BIB-7)

- `tools/refs.py`: run `pandoc <bib> -t csljson` once over the cited entries (committed and local alike) and store each work's CSL JSON under `csl` in the matching cache. Derive the existing `title`, `authors`, `year`, `type` from it rather than from regexes, so there is one parse.
- Covers: the committed copy's longest side becomes 1200 px; variants 160, 320, 640, 960. Re-run on the Pirsig photograph (it is in `~/Zotero/storage/`, the refresh finds it).

### 3. The head and the card (BIB-10, BIB-7, BIB-8)

- One function, as now, renders the head for the page and the card for `/_x/references/<key>.frag`: title (sans, level-2 size in the card; the page title on the page), cover at the right, 14em tall, top on the title's top; the `<dl>` beneath the title at its left; then the field list.
- Fields per type from the BIB-10 table, mapped from CSL variables; names *Given Family* joined with commas and *and*; plural labels for several editors or translators; DOI and URL as ↗ links, Archive after them. Empty fields omitted. The `<dl>` is a two-column grid, `max-content 1fr`, labels muted, values in the text colour, lining figures where BIB-10 says. One gap token; tune it on the specimen so the tab stop reads as one.
- The card also carries the commentary's first paragraph (keep it; Ryan wants to see it) and the *Cited in n posts · Reference page →* line.
- Remove the Chicago entry from both; `bib-entry` stays for the References list, the per-essay Bibliography and `/bibliography`.

### 4. The popup (BIB-8, POP-7)

- A citation's popup is the card: title bar *Reference n*, then the fetched card with the citation's locator (*Page 325*, *Pages 31–34*, *Chapter 3*; write out the abbreviations `p.`, `pp.`, `ch.`, `§`; anything else verbatim) and its `#:note` remark, italic, inserted under the title before the fields, each omitted when absent. The circle carries `data-loc` and `data-note`. Shared circles (MARK-1c) show one card per item, separated by a hairline as now.
- If the fragment fetch fails, show the References entry as before Phase 3. No hairline, no note text, when the card is present.
- Touch: the popin is the same card. Check that a 14em cover plus fields plus a paragraph fits the popin's 60% cap with scrolling, and that the popup grows to its ~70% cap before scrolling.

### 5. One Cited in (BIB-1, BIB-9)

- Remove Quoted. Cited in: grouped by post in index order, then by position; the section named once at the head of each run of entries in it; each entry the locator (muted) then either the passage in full (a body cite) or the context clamped to ~2 lines with More (a bare cite), and a → to the mark. Entries that share a paragraph are listed once: one context, then each citation's locator and arrow together. This also removes the triple entry the Phase 3 report noted on `/references/hackingMakingPeople2006`.

### 6. Emacs: `od-insert-cite` (§16)

Do this here rather than waiting for Job C, since it is how every citation will be written from now on. `C-c o c`: pick the key (pinned check as now), then prompt in turn, each skipped with Enter: locator; kind (*reference* / *quotation* / *block quotation*, default *quotation* with an active region, *reference* without); remark; for a block, italic or roman. Write `◊cite["key"]`, `◊cite["key" #:loc "…"]{region}` or `◊cite["key" #:block #t #:loc "…"]{region}` on its own lines with blank lines either side; with no region and a quotation kind, leave point inside the braces. Warn in the echo area when a quotation has no locator. `od-insert-blockquote` and `od-insert-epigraph` lose the key prompt Phase 3 gave them. `make test-emacs` green.

### 7. Checks and report

- `make test` and `make` green; the new CITE-8 assertions; a RackUnit test that a book, an article and a chapter from the fixture `.bib` produce exactly the BIB-10 fields in order with the empty ones absent.
- Screenshots: the Pirsig popup in light and dark with the cover, the locator and the commentary paragraph; `/references/pirsigZenArtMotorcycle1991` top of page; the same page's Cited in; a phone-width popin of the same card. Write `reports/2026-11-02-phase3b/REPORT.md`.

Do not begin Job B (maths) or the rest of Job C.

## Opening prompt

> Read `HANDOVER-PHASE3B.md` in this repo and do Job A as written: read the draft 1.18 text of `SPEC.md` §5a, §3.3, CITE-8, POP-7 and §16; commit the pending doc changes including `STYLE.md`; build the seven steps in order (cite with a body and the withdrawals, the CSL record and the 1200 px cover, the fields head and card, the popup as the card, one Cited in, `od-insert-cite`'s prompts, checks); get `make` green; and stop with the report it asks for.
