# occurrentdevelopment.com — Backlog

Deferred features, with enough detail to build later. Nothing here is part of v1 (`SPEC.md`); do not build it unless it moves.

Each item says **why it's deferred** — usually because it needs design iteration, more essays before it does anything, or work disproportionate to what it adds.

---

## 1. Running map (left margin)

*Deferred: needs a very wide window to appear at all, and the positioning wants iteration. The section bar (BAR-1) covers navigation in v1.*

A compact outline of the essay, pinned in the left margin, showing where the reader is.

- Sticky outline generated from the section tree, using `#:short` titles; levels 1–2, with the current level-1 section expanded.
- Current section tracked with IntersectionObserver: the last section whose heading has crossed ~25% down the viewport.
- A hairline progress rule beside the current entry shows progress through that section.
- Clicking pushes a history entry (as BAR-2 already does).
- Hovering an entry opens that section's extract popup.
- Quiet: muted, small, no panel; fades further while scrolling, returns on stop; disabled under `prefers-reduced-motion`.
- `<nav aria-label="Essay map">`, JS-only; the top TOC is the no-JS equivalent.
- A full-width figure or table crossing the left margin fades the map out while it passes.
- **Width reality check:** with a 90-character column plus a right margin, the map needs roughly 1,500 px. Many laptops are 1,280–1,440 and would never see it. Decide whether that is worth the complexity before building.

## 2. Nested popups

*Deferred: the stacking, focus and lifetime rules are where a popup system gets expensive. v1 has one level, plus the single `see-also` replacement inside term popups.*

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

*Rejected on legal grounds, recorded so the decision isn't revisited by accident.*

Serving copies of other people's pages from your domain is reproduction and communication to the public. Australia has fair dealing, not US-style fair use, and "archiving for readers" doesn't fit its purposes. You publish as an identifiable professional. v1 links to the Internet Archive's copy instead (CARD-3, CARD-5).

If ever reconsidered, it would need: `noindex` and sitemap exclusion; a takedown address and policy; no paywalled content; credit and a link to the original on every card; storage outside git (e.g. R2), a manifest in the repo, sanitising (no scripts, no third-party requests), and a review step. Get advice first.

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

*Deferred, low value:* gwern.net-style per-site marks (W for Wikipedia, an arXiv glyph, and so on) in place of the generic ↗.

## 10. Cycling section-break glyphs

*Deferred, ornamental:* gwern.net cycles three designs down a page (sun, moon, asterism), with smaller variants on mobile. v1 uses one glyph. If adopted, count breaks down the page modulo the number of designs.

## 11. Automatic small caps for acronyms

*Deferred; manual `◊sc{}` is in v1.* A "splitter" rule (a regex mapped to a function returning an X-expression) could mark runs of 3+ capitals, with an exceptions list. The splitter table in `typography.rkt` is the place for it.

## 12. Text-size control

*Cut in v1: browser zoom does the same job.* If revisited: five steps on one root variable, stored in `localStorage`; the tiers are already container queries (LAYOUT-7), so the layout would follow correctly.

## 13. Glossary term pages

*Cut deliberately (TERM-3): terms are read in popups and are not destinations.* Recorded so the decision isn't reversed by habit. If ever wanted: pages at `/glossary/<id>` with see-also links and backlinks, plus an index page.

## 14. Aside fallback for very crowded margins

*Not needed with one-line stubs (ASIDE-3/4).* The earlier rule — an aside pushed more than a screen from its marker falls back to a popup — is kept here in case dense essays prove otherwise.

## 15. Emacs extras

*Deferred; v1 has the pickers that matter.*

- `od-promote` / `od-demote` for heading levels.
- `od-term-backlinks`: a grep/xref buffer of every use of a term across essays.
- A lint for essays that use a term's headword or alias without marking it up (probably noise; decide by trying it once).

## 16. Miscellaneous ideas parked

- Popup previews of external links for an allow-list of sites that permit framing (nothing to do with archiving; still probably not worth it).
- Per-essay reading time, word counts, or "similar essays" — all easy, all clutter until the site is bigger.
- Full-text search across essays: worth revisiting past ~15 essays; a build-time index plus a small client script.
- A tag or topic index: same threshold.

## 17. Interactive figures: beyond the v1 frame

*v1 gives `◊embed` a frame: lazy loading, a required static fallback, sticky behaviour, theming and accessibility (§9.3). These extensions wait.*

- **Full-screen expansion** of a widget, sharing the image-zoom overlay (item 7), for complex figures on small screens.
- **Per-format rendering**: a PDF or print projection generated from the widget's own data rather than a static screenshot. PDF export is deferred generally, and the required fallback image covers print in the meantime.
- **A shared widget runtime** (common controls, state model, caption/description panel) — worth extracting only once a third widget exists; before that it is speculative abstraction.
- **Deep links into widget states**, so an essay or a reader can link to "the 45° view".
- **A second figure type for reticulate developmental trajectories** (branching, converging, rejoining), noted in the *Autism and Moles* material as a possible closing figure. Specify it when that essay reaches a draft.

## 18. Paid typefaces (parked)

*v1 uses Libertinus Serif (TYPE-7): free, OFL, committed to the repo, no traffic tiers. These two stay here as upgrades if the site ever wants more voice. Swapping is confined to the `@font-face` rules and the measure calibration.*

- **Heldane Text** (Sowersby, Klim) — Renaissance-inspired, literary, sharper. Heldane Display sold separately for the title and level-1 headings. Licence is one-off and perpetual but priced by monthly pageviews, WOFF2 only, subsetting allowed solely to reduce file size.
- **Century Supra** (Butterick, MB Type) — Century Schoolbook revival, "darker and narrower" than the original; plain and scholarly. US$119 once for up to three of your own sites. Comes in grades A and B: if the grades share metrics, the lighter grade is an elegant answer to light-on-dark text reading heavy.
- **Either paid face reinstates the repo constraint**: the files must not be committed, so `assets/fonts/` would be gitignored again and CI would fetch them from a private store with a secret (the old TYPE-9a rule).
