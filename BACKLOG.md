# occurrentdevelopment.com — Backlog

Deferred features, with enough detail to build later. Nothing here is part of v1 (`SPEC.md`); do not build it unless it moves.

Each item says **why it's deferred** — usually because it needs design iteration, more essays before it does anything, or work disproportionate to what it adds.

---

## 1. Running map (left margin)

*Retired 2026-10-15: superseded by the contents in the left margin (SPEC TOC-2), which does what this item was for. The one idea taken from it is the hairline beside the current entry. Kept here so the numbering of later items does not shift.*

## 2. Nested popups

*Deferred: the stacking, focus and lifetime rules are where a popup system gets expensive. v1 has one level: a circle inside an open margin item opens one popup, and a circle inside a popup replaces its content (POP-6, revised 2026-10-15). This item is everything beyond that.*

- A link inside a popup opens a child popup; children close with their parent; cap the depth (~4).
- Pinned popups stack with an offset; Esc closes the topmost only.
- This is a large part of what makes gwern.net feel like exploration, so it is the first thing to promote once v1 is comfortable.

## 3. Popup dragging and resizing

*Deferred, probably permanently: fiddly, rarely used on a reading site.*

## 4. Section-level backlinks (← n)

*Deferred: needs a body of cross-referencing essays before it shows anything.*

- Where other pages link to `/slug#id`, that heading carries a **← n** mark in the accent colour, counterpart to the outbound →.
- Hover or tap lists those contexts, so a reader can see discussions of that part of the page elsewhere.
- Links to a subsection count to that subsection, not its parent; whole-page links count only in the page-level list (VAL-4, in v1).

## 5. Automatic link metadata

*Deferred: fetching and cleaning other sites' metadata needs per-site fixes and a review habit. In v1 you type the few fields you want.*

- `tools/link-meta` fetches each new external URL once and extracts **factual** metadata only: title, author, date, site name, type (from `citation_*`, JSON-LD, Open Graph); DOIs resolved through Crossref for the same facts.
- Descriptions and abstracts are never stored (the §11.1 policy stands).
- Hand overrides always win; `make refresh` prints each new card for checking.
- Fetching identifies itself honestly, respects `robots.txt`, and is rate-limited.

## 6. Local archives of external pages

*Removed 2026-10-15: not wanted; nothing to record. Number kept so later items do not shift.*

## 7. Image zoom, slideshows and galleries

*Deferred: zoom, pan and swipe gestures need real iteration on real devices.*

- Click or Enter opens the figure full screen at full resolution over a dimmed page, with its caption; pinch/trackpad zoom, double-tap for 1:1, drag to pan; Esc, backdrop click or swipe-down closes, returning focus.
- The zoom affordance appears only where the full image is > 1.3× its displayed size.
- While zoomed, ← / → and swipes step through the essay's images with a counter; preload only the neighbours.
- `◊gallery{…}` groups figures into a thumbnail row that opens its own slideshow.
- Same inversion rules as the page (IMG-4).
- Also: click-to-zoom for `column`-width tables that overflow.

## 8. Table extras beyond v1

*v1 has pipe and CSV tables, three sizes, three widths, sorting, sticky headers and overflow. Nothing further is planned.* If needed later: column filtering, footnote rows, per-column number formats.

## 9. Domain link icons

*Removed 2026-10-15: not wanted. Number kept so later items do not shift.*

## 10. Cycling section-break glyphs

*Removed 2026-10-15: not wanted; one glyph stays. Number kept so later items do not shift.*

## 11. Automatic small caps for acronyms

*Deferred; manual `◊sc{}` is in v1.* A "splitter" rule (a regex mapped to a function returning an X-expression) could mark runs of 3+ capitals, with an exceptions list. The splitter table in `typography.rkt` is the place for it.

## 12. Text-size control

*Moved into v1 on 2026-10-12: see SPEC THEME-5 and BAR-1.* Kept here so the numbering of later items does not shift.

## 13. Glossary term pages

*Moved to v1 on 2026-10-15, as a single `/glossary` page built from the glossary files: see SPEC TERM-8. Per-term pages stay cut, and `◊term` still never navigates (TERM-3). Kept here so the numbering of later items does not shift.*

## 14. Aside fallback for very crowded margins

*Not needed with one-line stubs (ASIDE-3/4).* The earlier rule — an aside pushed more than a screen from its marker falls back to a popup — is kept here in case dense essays prove otherwise.

## 15. Emacs extras

*Deferred; v1 has the pickers that matter.*

- ~~`od-promote` / `od-demote` for heading levels.~~ *Moved to v1 2026-10-15 (HANDOVER-EMACS.md, EDIT-5).*
- `od-term-backlinks`: a grep/xref buffer of every use of a term across essays.
- A lint for essays that use a term's headword or alias without marking it up (probably noise; decide by trying it once).

## 16. Miscellaneous ideas parked

- Popup previews of external links for an allow-list of sites that permit framing (nothing to do with archiving; still probably not worth it).
- Per-essay reading time, word counts, or "similar essays" — all easy, all clutter until the site is bigger.
- Full-text search across essays: worth revisiting past ~15 essays; a build-time index plus a small client script.
- A tag or topic index: *partly built 2026-10-14*, as the tag filter on the home page (INDEX-3). Separate pages per tag, with descriptions, wait for the same threshold.
- Mathematics: **decided 2026-10-20, not parked.** The LaTeX logo is a Phase 2 tag (SPEC TYPE-17); inline maths is Phase 3, pre-rendered in Libertinus Math by LuaLaTeX at `make refresh` (SPEC MATH-1). KaTeX and MathJax were considered and rejected because they set maths in their own faces beside the text face. Recorded here so the choice is not reopened.

## 17. Interactive figures: beyond the v1 frame

*v1 gives `◊embed` a frame: lazy loading, a required static fallback, sticky behaviour, theming and accessibility (§9.3). These extensions wait.*

- **Full-screen expansion** of a widget, sharing the image-zoom overlay (item 7), for complex figures on small screens.
- **Per-format rendering**: a PDF or print projection generated from the widget's own data rather than a static screenshot. PDF export is deferred generally, and the required fallback image covers print in the meantime.
- **A shared widget runtime** (common controls, state model, caption/description panel) — worth extracting only once a third widget exists; before that it is speculative abstraction.
- **Deep links into widget states**, so an essay or a reader can link to "the 45° view".
- **A second figure type for reticulate developmental trajectories** (branching, converging, rejoining), noted in the *Autism and Moles* material as a possible closing figure. Specify it when that essay reaches a draft.

## 18. Paid typefaces (parked)

*Removed 2026-10-15: Libertinus Serif is the typeface (TYPE-7). Number kept so later items do not shift.*
