# occurrentdevelopment.com — Specification (v1)

Status: draft 1.3 · Owner: Ryan · Last revised: 2026-10-12

This is the build brief for version 1 of the site: everything needed to write essays, publish them, and be happy with how they look. Requirements carry IDs (e.g. `LINK-3`) so commits and tests can reference them. **MUST** = required; **SHOULD** = expected, may slip; **MAY** = optional.

Deferred features live in `BACKLOG.md`. Do not build them. If a v1 decision would block one of them, say so rather than building it early.

Section 15 records the conventions that will grow into the public style guide.

---

## 1. Principles

In priority order; the higher wins.

1. **The reader never loses their place.** No annotation forces a scroll or a page change unless the reader asks for one.
2. **The source is the essay.** Plain text, readable in a GitHub diff, markup light enough that prose stays legible unrendered.
3. **Fast.** Static pages, no framework, no third-party requests. Every byte of JS and every font file earns its place.
4. **Typography is not decoration.** Measure, leading, justification, hyphenation and superscript alignment are requirements.
5. **Progressive enhancement.** With JS disabled every essay is complete and navigable.
6. **Essays are living documents.** Revisions are expected, visible and dated; anchors are permanent.
7. **No engagement machinery.** No comments, forms or social widgets. Readers write letters (§13).
8. **We publish nothing that isn't ours.** No copies of other people's pages or images (§11.1, IMG-6).

---

## 2. Architecture

### 2.1 Stack

| Layer | Choice |
|---|---|
| Source | Pollen markup (`.html.pm`), Racket |
| Build | `raco pollen render` (parallel), tag functions and the `root` pass in `pollen.rkt` |
| Citations | Zotero (Better BibTeX export) → `make refresh` copies the cited entries into `refs/refs.bib` and pandoc formats them into a committed cache (§5) |
| Client | Vanilla JS (ES modules) and CSS. No framework |
| CI | GitHub Actions (`Bogdanp/setup-racket`): full rebuild, validate, then `wrangler deploy` |
| Hosting | Cloudflare Worker `site`, static assets only (D2). Cloudflare's own Git build stays disconnected: its image has no Racket |
| Interactive figures | Per-figure bundles built with their own toolchain (§9.3) |
| Editor | Emacs: `pollen-mode` + local `occurrent.el` (§16) |

Pollen is settled; the Hugo shortcode approach sketched in earlier essay notes is superseded.

### 2.2 Repository

```
occurrentdevelopment/
├── essays/<slug>/
│   ├── <slug>.html.pm         # the essay
│   └── img/                   # images belonging to that essay
├── glossary/<id>.pm           # one file per term; never rendered as a page
├── widgets/<name>/            # source of an interactive figure (§9.3); built by CI
├── pages/                     # about, colophon, correspondence, changelog
├── refs/
│   ├── refs.bib               # cited entries only, written by `make refresh`; committed
│   └── chicago-notes-bibliography.csl   # CSL style (CC BY-SA 3.0); committed
├── data/
│   ├── cite-cache.json        # pandoc output, committed
│   ├── link-meta.json         # external link cards, committed
│   ├── invert.json            # dark-mode image classification, committed
│   ├── site.rktd              # postal address, site metadata
│   ├── anchors.json           # pages → sections (generated; also published for VAL-3)
│   └── links.json             # internal link graph (generated)
├── img/                       # shared source images (generated variants are not committed)
├── pollen.rkt  typography.rkt  template.html.p
├── lib/                       # citations, glossary, lists, tables, figures, marks (required by pollen.rkt)
├── typography-test.rkt  pollen-test.rkt  tests/   # RackUnit tests; tests/ holds Pollen fixtures
├── assets/css/  assets/js/  assets/icons/
├── assets/fonts/              # Libertinus OTF sources + OFL.txt, committed (TYPE-9a); WOFF2 subsets generated
├── assets/img/                # figure variants, generated
├── tools/                     # fonts.py, images.py, refs.py, validate.rkt; later link-meta, invert, backlinks
├── emacs/occurrent.el
├── index.ptree  Makefile  SPEC.md  BACKLOG.md
└── local.mk                   # machine settings (ZOTERO_BIB); never committed
```

- **BUILD-1 (MUST)** Generated HTML is never committed; CI builds and deploys.
- **BUILD-2 (MUST)** `make` builds offline from committed caches, with no network access.
- **BUILD-3 (MUST)** `make refresh` is the only step that reaches outside the repository: it copies the cited entries from the Zotero export (`ZOTERO_BIB`, set in `local.mk`) into `refs.bib` and runs pandoc over them; later it also classifies new images and saves new external URLs to the Wayback Machine. It updates the committed caches, which you then commit. Network flakiness can never break a deploy.
- **BUILD-3a (MUST)** Each essay is a **folder**, holding the `.pm` file and its own images. Working notes live with the essay while it is private; nothing whose filename matches `*-Notes.md`, `*.graffle`, `*.docx` or `*.tex` is ever copied into the public repo (gitignored, and the build refuses to publish them). Published essays keep the same folder shape.
- **BUILD-4 (MUST)** CI always does a **full rebuild** (backlinks make every page depend on every other). The local Pollen project server may show stale backlinks until `make` runs; say so in the README.

### 2.3 Drafts

Anything pushed to a public repo is public permanently.

- **DRAFT-1 (MUST)** Draft in a private repo (or a local branch that is never pushed); move an essay into the public repo at first publication.
- **DRAFT-2 (MUST)** Essays carry `status`; the build publishes only `published`, as a second guard.

---

## 3. Authoring format

### 3.1 Conventions

- Paragraphs are separated by blank lines; `◊p` is never written.
- The command character is the lozenge `◊` (Emacs binds a key, EMACS-1).
- **SRC-1 (MUST)** Headings require an explicit permanent `#:id`; ids are never derived from heading text.
- **SRC-2 (MUST)** An unrecognised tag is a build error.
- **SRC-3 (MUST)** Source is hard-wrapped freely. A single newline inside a paragraph is a **space**, not a `<br>` (override Pollen's `decode-paragraphs` default via `#:linebreak-proc`). An explicit break is `◊br{}`.
- **SRC-4 (MUST)** A `◊define-meta` value stays on **one line**: Pollen reads further lines as extra key/value pairs and the build fails. `occurrent.el` keeps meta lines out of `fill-paragraph`. (Longer header text, such as the abstract, may later move to body tags; until then, one line.)

### 3.2 Example

```
◊define-meta[title]{Occurrent development}
◊define-meta[status]{published}
◊define-meta[published]{2026-10-01}
◊define-meta[epistemic]{Speculative; argued from theory rather than data.}
◊define-meta[abstract]{Why development is better described as a process than a sequence of states.}

◊margin{Small stuff matters too.} A child is not a sequence of states◊aside{Whitehead
makes the same move against "simple location" ◊cite["whitehead1925"].} but an
◊term["occurrent"]{occurrent}: something that unfolds rather than persists
◊cite["oyama2000" #:loc "p. 42"]. I return to this in
◊link["#canalisation"]{the section on canalisation}, and it extends
◊link["/kawasaki-genealogy#referents"]{an earlier essay}. See also
◊link["https://plato.stanford.edu/entries/process-philosophy/" #:note "Standard
overview; good on Whitehead's debt to Bergson."]{the SEP entry}.

◊break{}

◊section[#:id "canalisation" #:short "Canalisation"]{Canalisation and its limits}
```

Citation keys are Better BibTeX keys from Zotero (`hackingMakingPeople2006`); the short keys above are illustrative.

### 3.3 Tag vocabulary

| Tag | Purpose | Required | Optional |
|---|---|---|---|
| `◊link[target]{text}` | Any link; type inferred (§4.2) | target | `#:note`, `#:title`, `#:author`, `#:date` |
| `◊cite[key]` | Citation → numbered note (§5) | BibTeX key | `#:loc`, `#:note` |
| `◊term[id]{text}` | Glossary term (§6) | glossary id | `#:mark` |
| `◊aside{…}` | Aside (§7.1) | body | — |
| `◊margin{…}` | Paragraph gloss (§7.2) | body | — |
| `◊section` `◊subsection` `◊subsubsection` `[#:id]{title}` | Heading markers (§8) | title, id | `#:short` |
| `◊summary{…}` | One-line section summary for popups | body | — |
| `◊more{…}` | Long text of a glossary definition (§6); glossary files only | body | — |
| `◊list{…}` | Lists (§3.4) | body | `#:start`, `#:columns` |
| `◊table{…}` / `◊table-csv[path]` | Tables (§9.2) | body / path | `#:caption`, `#:source`, `#:size`, `#:width`, `#:sortable`, `#:align`, `#:row-headers` |
| `◊sort-key[value]{text}` | The value a table cell sorts by (TABLE-5) | value | — |
| `◊figure[src]{caption}` | Image (§9.1) | src, `#:alt`, `#:licence` | `#:width`, `#:invert`, `#:credit` |
| `◊embed[name]{caption}` | Interactive figure (§9.3) | name, `#:alt`, `#:fallback` | `#:width`, `#:sticky` |
| `◊break{}` | Section-break glyph (§10.5) | — | — |
| `◊sc{…}` | Small caps (acronyms) | body | — |
| `◊anchor[id]`, `◊em`, `◊strong`, `◊code`, `◊blockquote`, `◊epigraph`, `◊br{}` | Standard elements | | `◊epigraph[#:source "…"]` |
| `◊changelog{…}` | Revision notes (§13) | body | — |

A block quotation is `◊blockquote`, not `◊quote`: Racket's `quote` would swallow the tag silently, so `make test` rejects `◊quote`. Any tag name must avoid Racket's syntactic forms for the same reason; `◊list` is safe.

### 3.4 Lists

```
◊list{
- First-level bullet (small solid dot)
  - Second level (›)
    - Third level (–)
- Numbers and bullets mix:
  1. → 1.
  2. → 2.
     1. → 2.1.
        1. → 2.1.1.
- An item can run to a second paragraph:

  Indent the continuation to stay in the item.
}
```

- **LIST-1 (MUST)** `- ` starts a bullet, `1. ` a numbered item; the digits typed are ignored (numbering is automatic). Two spaces per level of nesting. An indented paragraph after a blank line continues the item.
- **LIST-2 (MUST)** Bullets by level: **1** small solid dot drawn in CSS (~0.25em, centred on the x-height; not a ring, which is the annotation mark, D9); **2** `›` (U+203A) from the text face; **3** en dash; **4+** repeat from level 1. Markers use the text colour, muted; never the accent colour.
- **LIST-3 (MUST)** Numbering is hierarchical — 1. / 1.1. / 1.1.1. The chain runs only through consecutive numbered levels; a numbered list inside a bullet restarts at 1. Numbers use lining tabular figures. The build computes each number (`data-n`) and CSS prints it: nested CSS counters cannot restart a chain inside a bullet.
- **LIST-4 (MUST)** Markers hang in a gutter: bullets centred, numbers right-aligned, the gutter widening with depth so text never jumps.
- **LIST-5 (SHOULD)** `#:columns 2|3` sets short lists in columns on wide tiers, one column when narrow; items never split across columns; numbered items read down then across. Warn if an item exceeds ~60 characters.
- **LIST-6 (SHOULD)** `#:start n` continues numbering after interrupting prose.
- **LIST-7 (MUST)** Inline tags work inside items; lists expand before the numbering walk (§12). List text is ragged right even where body text is justified. Bad indentation or an unknown marker is a build error.

---

## 4. Marks and links

### 4.1 Mark table

Every annotation carries a small superscript mark; the mark is the only signal that text is interactive. There are two kinds, and the kind tells the reader what will happen: an **arrow** takes you away from where you are reading; a **circle** opens something where you are.

| Type | Inferred from | Mark |
|---|---|---|
| External link | `http(s)://` | ↗ |
| Cross-essay link | `/slug` | → |
| Same-page link, target above | `#id` earlier | ↑ |
| Same-page link, target below | `#id` later | ↓ |
| Citation | `◊cite` | ○ (circle) |
| Definition | `◊term` | ○ (circle) |
| Aside | `◊aside` | ○ (circle) |

- **MARK-1 (MUST)** Marks are drawn, not typed: never Unicode glyphs. Arrows are SVG in `currentColor` (inline `<svg>`, or a mask that exactly fills an atomic inline box sized to the glyph). The circle is a small hollow ring in the accent colour, as in Butterick's *Practical Typography*, drawn with a CSS border and no mask. **Never mask an empty non-atomic inline box**: Safari paints the whole box (the Phase 1 defect, seen on iOS and in desktop Safari 26.6). *Status 2026-10-12: the rework draws correctly in Chrome, Safari 26.6 and Firefox 157 on desktop; phones to be checked.* Every mark is checked in Safari, Chrome and Firefox, desktop and phone, before a phase is called done.
- **MARK-1a (MUST)** Arrows are 20% larger than in the Phase 1 build (glyph ≈ 0.58em, from 0.48em), with the stroke thinned in proportion so the weight on the page is unchanged.
- **MARK-1b (MUST)** The circle looks the same for citations, definitions and asides. The types keep separate markup, classes and accessible names (MARK-7), and separate content and no-JS fallbacks; only the sign is shared.
- **MARK-1c (MUST)** Circles never sit side by side. Annotations that fall at the same point in the text (two citations, or a term followed by a citation) share **one** circle, which opens all of them in source order. "The same point" means nothing but whitespace lies between the end of one annotation and the next `◊cite`, `◊aside` or circle-bearing `◊term`; punctuation between them keeps them apart. Without JS a shared circle links to its first item (D8).
- **MARK-2 (MUST)** Marks must not disturb leading: `line-height: 0` on the mark, tuned `vertical-align`. Test that a line with a mark is exactly as tall as one without.
- **MARK-3 (MUST)** A mark never wraps alone: it joins its preceding word with a word joiner, and the last word and the mark are bound in a `white-space: nowrap` span (a word joiner alone does not stop Chrome breaking before an inline box when a space follows). The build removes any space typed before `◊cite` or `◊aside`.
- **MARK-4 (MUST)** **Nothing is underlined**: no links, terms, TOC or map entries, no headings, no emphasis. `text-decoration: none` globally, including `:visited`. Link text stays in the body colour and weight; the mark after it is the signal (Butterick's approach in *Practical Typography*, with our arrows saying where a link leads).
- **MARK-5 (MUST)** Marks are the only colour in running text: one muted accent per theme, not blue. On hover or focus the annotated text takes the accent colour; `:focus-visible` draws an outline around text and mark (a focus ring is not an underline). Visited links get a lighter mark.
- **MARK-6 (MUST)** The text and its mark are one link, with an invisible hit area of at least 24 × 24 px, without changing the visual size or leading.
- **MARK-7 (MUST)** Because nothing else distinguishes link text, a mark is never omitted from interactive text (WCAG 1.4.1). The only non-interactive exception is a repeated term (TERM-5). Every mark has an accessible name that says what it is ("external link", "note 3", "definition", "aside"), never its shape ("north-east arrow", "circle"); a shared circle (MARK-1c) names everything it opens.
- **MARK-8 (MUST)** Rules under headings, break glyphs and table rules are borders, not underlines; MARK-4 does not forbid them.

### 4.2 Link behaviour

- **LINK-1 (MUST)** `◊link` infers its type from the target; ↑/↓ direction is computed at build from document order.
- **LINK-2 (MUST)** A broken same-page or cross-essay target fails the build.
- **LINK-3 (MUST)** `href` is always real, so Cmd/Ctrl-click and middle-click open a new tab natively.

---

## 5. Citations and notes

Citations are **numbered notes**, collected in a **Notes** section at the foot of the essay. The number belongs to the note, not to the text: in the text a citation is a circle (§4.1), and no numeral is printed there. With JS, opening the circle shows the note, headed with its number ("Note 3"), in the margin or a popup (§11); without JS the circle is a link to the note.

- **CITE-1 (MUST)** Notes are numbered per essay in **source reading order**, including citations inside asides. An aside sits in the source right after its circle, so its citations are numbered at that point in the argument. The number appears in the Notes list, in the opened note's heading and in print (LAYOUT-5); never as a superscript on screen.
- **CITE-2 (MUST)** Numbering happens **once**, in a single document-order walk in the `root` pass, **before** asides are duplicated for the no-JS endnote copies. The copies reuse their numbers. Getting this wrong double-counts asides; CITE-8 tests it.
- **CITE-3 (MUST)** Each `◊cite` gets its own number. The first note for a work gives the full reference; later notes the short form. No *ibid.*
- **CITE-4 (MUST)** Each note has a ↩ back-link to its mark. If the mark is inside an aside, the back-link scrolls to the aside (expanding it on wide screens, opening its popup on narrow ones).
- **CITE-5 (MUST)** Formatting is not done in Racket. `tools/refs.py` (`make refresh`) runs `pandoc --citeproc` with a *note* CSL style and stores, for every key **and every locator the sources use with it**, the full and short note, plus the bibliography entry and DOI/URL, in `data/cite-cache.json`. Racket only picks first vs later. Letting pandoc place the locator gets Chicago punctuation right (`“Making Up People,” 23.`, `What?, 31–34.`); a new locator therefore needs a `make refresh`, and the build says so. No abstracts are stored or shown (§11.1 policy); `refs.bib` never carries abstracts, notes, keywords or file paths.
- **CITE-6 (SHOULD)** Style: **Chicago notes and bibliography**.
- **CITE-7 (MUST)** Citations outside the essay's own sequence — inside glossary definitions or cross-essay extracts — are **unnumbered**. They carry the same circle and open the reference; they have no entry in the essay's Notes.
- **CITE-8 (MUST)** Test fixture: an essay with citations in body text, in several asides, repeats of one work, and a term whose definition cites something. Expected numbering, forms and back-links are asserted.
- **CITE-9 (MUST)** An unknown key, or a key and locator missing from the cache, fails the build with a message to run `make refresh`.
- **CITE-10 (MUST)** End matter order: **Terms** (no-JS only) · **Asides** (no-JS only) · **Notes** · **Bibliography** · **Backlinks** · **Changelog**.

---

## 6. Glossary

- **TERM-1 (MUST)** The glossary is **site-wide**: one `glossary/` folder, one file per term, filename = permanent id. Essays cannot redefine terms locally. A word used in a different sense is a separate term (`canalisation`, `canalisation-waddington`).
- **TERM-2 (MUST)** File format: Pollen markup, no `.html` in the name, so Pollen never renders it as a page. The build imports each as a module.

```
◊define-meta[term]{occurrent}
◊define-meta[aliases]{occurrents; occurrent entity}
◊define-meta[see-also]{continuant process}
◊define-meta[added]{2026-09-19}

An entity that unfolds in time and has temporal parts, as opposed to a
◊term["continuant"]{continuant}, which persists whole through time
◊cite["smith2005"].

◊more{
Longer discussion, as long as it needs to be…
}
```

| Field | Required | Notes |
|---|---|---|
| filename | yes | The id; lowercase, hyphenated, permanent |
| `term` | yes | Headword as displayed |
| body (first paragraph) | yes | Short definition, 1–3 sentences; what the popup shows |
| `◊more{…}` | no | Long text, expanded inside the popup |
| `aliases` | no | Semicolon-separated variants; used by Emacs completion |
| `see-also` | no | Space-separated ids, validated |
| `added` | yes | ISO date; "revised" comes from git |

- **TERM-3 (MUST) Popups only. There are no glossary pages and no index.** A term has no URL and is never a destination. `◊term` opens a compact definition set like a margin note (aside size, ragged right) with headword and short definition: in the right margin on wide tiers, as a popup or popin on narrow ones (POP-8). **More** expands `◊more` in place, growing to ~70% of the viewport and then scrolling; `see-also` terms appear at the foot and replace the content (POP-6). Definitions used by an essay are embedded in that essay's HTML at build, so popups need no network request: the no-JS Terms section is that store, hidden when scripts run.
- **TERM-4 (MUST)** No-JS: an essay that uses terms ends with a **Terms** section giving each used term in full; first uses link to it.
- **TERM-5 (SHOULD)** Only the **first** occurrence in an essay carries the circle and is interactive; later ones are plain text unless `#:mark #t`.
- **TERM-6 (MUST)** Validation: unknown id, bad filename, missing `term`/`added`, empty definition, dangling `see-also`, or an alias claimed by two terms all fail the build. Unused terms warn.
- **TERM-7 (MUST)** A `◊term` inside a definition keeps its circle and replaces the definition's content, with a Back control (POP-6).

---

## 7. Asides and margin notes

### 7.1 Asides

| Tier | Rendering |
|---|---|
| Wide (XL, L) | **Collapsed stub** in the right margin, always visible, top-aligned with the line holding its circle; click to expand (ASIDE-3) |
| Narrow (M, S) | The circle opens the aside as a popup/popin |
| No JS | Asides are collected in an **Asides** list at the end, in source order, each with a ↩ return link; the circle links to its entry |

- **ASIDE-1 (MUST)** Source position is canonical: the build emits each aside inline, right after its circle (hidden until JS lifts it into the margin), and a separate no-JS copy in the Asides list, hidden when JS runs.
- **ASIDE-2 (MUST)** Asides are **not numbered**: no roman numerals, in the text, the stub or the popup. An aside is tied to its circle by position (the stub sits on the circle's line) and, when either is hovered or focused, by both taking the accent.
- **ASIDE-3 (MUST) Collapsed stubs.** In wide tiers an aside starts as one margin line: its opening words, cut with an ellipsis (*Whitehead makes the same move…*). Many asides therefore fit, each starting on its reference line. Stubs are what tell a reader on a wide screen that a circle is a skippable digression and not a source: **only asides have stubs**. Notes and definitions occupy the margin only while open (POP-8).
  - Clicking the circle or stub **expands** it in place: anchored at its reference line, growing downward, drawn over the stubs below on the page background with a hairline border, so nothing moves. Click again, Esc, or opening another collapses it. One expanded at a time.
  - An aside that fits in two margin lines is shown in full and never collapses.
  - Circles and stubs are focusable; Enter toggles; `aria-expanded` is set.
- **ASIDE-4 (MUST)** Collisions: stubs are one line, so overlap is rare. When two would overlap, the later moves down just enough to clear. Recalculate on resize and after fonts load.
- **ASIDE-5 (MUST)** Asides use the **right margin only**; the left margin is reserved (BACKLOG: running map).
- **ASIDE-6 (SHOULD)** Aside size ≈ 0.85 × body, ragged right, never justified.
- **ASIDE-7 (MUST)** Asides may contain links, citations and terms, which behave normally.

### 7.2 Margin notes

A margin note is a short unnumbered gloss on a whole paragraph — a signpost for a skimming reader — written at the start of that paragraph.

- **MNOTE-1 (MUST)** No marker, not interactive, so no mark.
- **MNOTE-2 (MUST)** Wide tiers: right margin, top-aligned with the paragraph's first line, italic, aside size, ragged right; not repeated in the text.
- **MNOTE-3 (MUST)** Narrow tiers and no-JS: inline italic run-in at the start of the paragraph. The build emits the inline form; CSS/JS lifts it into the margin when wide.
- **MNOTE-4 (MUST)** Margin notes hold their position; aside stubs move around them. An expanded aside draws over them.
- **MNOTE-5 (SHOULD)** ≤ ~8 words; warn above 12. Inline emphasis only: no links, cites, terms or asides.

---

## 8. Sections, TOC, reading bar

One section tree drives the TOC, the reading bar, cross-essay extracts and the Emacs index.

- **SECT-1 (MUST)** Three levels: `◊section`, `◊subsection`, `◊subsubsection`. The title is level 0 and is never a tag.
- **SECT-2 (MUST)** Headings are *markers*, not wrappers: the `root` pass turns the flat heading sequence into nested `<section id=…>` elements, each running to the next heading of equal or higher rank.
- **SECT-3 (MUST)** `#:id` required and permanent; `#:short` optional, for the TOC and reading bar.
- **SECT-4 (MUST)** **Never numbered** — not in headings, TOC or bar, with no option to turn numbering on. Cross-references name the section.
- **SECT-5 (MUST)** Validation: no skipped levels, unique ids, no headings inside asides.
- **SECT-6 (SHOULD)** `◊summary{…}` after a heading gives a one-line summary used in popups and TOC tooltips, not shown in the body.
- **SECT-7 (SHOULD)** Each heading gets a § self-link, appearing on hover, for copying a deep link.
- **TOC-1 (MUST)** A table of contents is generated for any essay with ≥ 3 sections, placed after the abstract (and after an opening epigraph), before the first paragraph. Levels 1–2, plain HTML, works without JS, no bullets or underlines, set smaller in the text face.
- **BAR-1 (MUST)** **Reading bar**: a slim bar fixed to the top of the viewport, overlaying the page (it never pushes content, so no layout shift). It holds, left to right: the **current top-level section** (`#:short`; the essay title before the first section), truncated with an ellipsis when narrow; the **text-size control** (THEME-5); the **theme control** (THEME-6), as a button in the bar, not inside a menu. Tapping the section name opens the full TOC as a popup/popin with the current section marked.
- **BAR-1a (MUST) When it shows.** The bar appears when the reader **scrolls up**, once the site header has left the viewport, and hides again after **2 seconds without scrolling**. Scrolling down never summons it, so it does not flicker while someone reads down a page. It stays while the pointer is over it, while keyboard focus is inside it, and while its TOC is open; the 2 seconds start when those end. Tabbing into it reveals it, so it is reachable without scrolling. Under `prefers-reduced-motion` it appears and disappears without animation.
- **BAR-1b (MUST) Mechanics.** The current section is tracked with IntersectionObserver. Showing and hiding needs scroll direction and an idle timer: one passive scroll listener (or `scrollend` where supported) that toggles a class and restarts a timer, and does nothing else — no layout reads, no per-frame work.
- **BAR-1c (MUST)** Without JS there is no bar; the header's controls need JS as well, and the page follows the system theme and the browser's own zoom.
- **BAR-2 (MUST)** Navigating from the TOC or bar pushes a history entry, so Back returns the reader to where they were.

---

## 9. Figures and tables

### 9.1 Figures

- **IMG-1 (MUST)** Build pipeline (`tools/images.py`: Pillow for resizing, WebP and the JPEG/PNG fallback; `avifenc` for AVIF): variants at 480–2400 px, never above the source, with `srcset`/`sizes` and explicit `width`/`height` (no layout shift). The first figure loads eagerly; the rest use `loading="lazy"` and `decoding="async"`. Sources in `img/`; variants not committed; warn above ~2 MB. SVG sources are inlined (IMG-5).
- **IMG-2 (MUST)** Widths (`#:width`, shared with tables): `column` (default), `wide` (column + right margin), `full` (viewport minus gutters). In narrow tiers all three are column width. Asides beside a `wide`/`full` element move below it.
- **IMG-3 (MUST)** Captions sit below, at aside size, ragged right, and may contain cites, links and terms. `#:alt` is required; a missing alt fails the build; `#:alt ""` marks a decorative image.
- **IMG-4 (MUST)** Dark mode: images are classified once at `make refresh` by [InvertOrNot](https://invertornot.com/), cached in `data/invert.json` by SHA-256. Invertible images get `filter: invert(1) hue-rotate(180deg)` in dark mode; others are dimmed (`brightness(.9)`). Invertible images are also blended (`multiply` in light, `screen` once inverted in dark), so a white ground becomes the page background in both themes. `#:invert #t|#f` overrides. Never called from the reader's browser. `tools/invert.py` asks by SHA-1 first (no upload); InvertOrNot may keep uploaded images, so it uploads only figures that are `own`, public domain or CC-licensed, never `permission`. SVG is never classified: it follows the theme in `currentColor`. The model is open source, so it can be run locally if the service goes away.
- **IMG-5 (SHOULD)** Prefer SVG for line art, with `currentColor` strokes, so it follows the theme without inversion.
- **IMG-6 (MUST) Rights.** Every figure declares `#:licence` (`own`, `public-domain`, a CC licence, or `permission`) and `#:credit` where not your own. A missing licence fails the build. Third-party diagrams are redrawn by you and credited "after X (year)". Quoting text in essays for criticism and review, with attribution, is normal fair dealing and is unaffected.

### 9.2 Tables

- **TABLE-1 (MUST)** Two sources: pipe tables inside `◊table{…}` (parsed like lists) and `◊table-csv[path]`. Cells may contain inline tags. A wrong cell count fails the build.
- **TABLE-2 (MUST)** Sizes (`#:size`): `normal`, `small` (≈ aside size), `tiny` (≥ 12 px). Widths as IMG-2.
- **TABLE-3 (MUST)** Booktabs typography: no vertical rules; heavier rule above the header and at the foot, hairline under the header; no zebra striping, subtle hover highlight; lining tabular figures; numeric columns right-aligned automatically (override with `#:align`); caption above, source note (`#:source`) below at aside size.
- **TABLE-4 (MUST)** Overflow scrolls inside the table's own container with an edge fade; the page never scrolls sideways; the caption stays in view while the table scrolls. Header row sticky on long tables: CSS cannot pin a header to the viewport from inside a sideways-scrolling container, so this is Phase 2 script.
- **TABLE-5 (MUST)** Sortable when ≥ 5 body rows unless `#:sortable #f`: click cycles ascending → descending → original; ▲/▼ indicator and `aria-sort`; numbers (with separators, %, currency, units, ranges) sort numerically, dates chronologically, else locale text; `◊sort-key["2004"]{c. 2004}` inside a cell overrides its value (a tag, because a pipe-table cell cannot take a keyword). Without JS the table is simply unsorted; the script loads only on pages with a sortable table.
- **TABLE-6 (MUST)** Semantic HTML: `<caption>`, `<thead>`, `<th scope="col">`, and `<th scope="row">` with `#:row-headers #t`.

### 9.3 Interactive figures

Some arguments are better shown than described — the mammal-taxonomy figure planned for *Autism and Moles* is the first. v1 provides the **frame**: a tag, a loading contract, a fallback and an accessibility contract. Each figure itself is a small, self-contained project built separately.

```
◊embed["mammal-taxonomy"
       #:alt "Two trees sharing a column of animal names; rotating the view…"
       #:fallback "img/mammal-taxonomy-45.png"
       #:width "wide" #:sticky #t]{
Morphological taxonomy and molecular phylogeny, sharing one column of taxa.
Rotate to see the second axis. ◊cite["springer2004"]
}
```

- **EMBED-1 (MUST)** One generic tag, `◊embed[name]`, which emits a container, a caption, controls and the fallback, then loads `/widgets/<name>/index.js` **lazily** (IntersectionObserver, when the figure is about to enter the viewport). An essay may define a thin named wrapper (`◊taxonomy-figure`) over it; the wrapper only supplies defaults.
- **EMBED-2 (MUST)** Widths exactly as figures (IMG-2): `column`, `wide`, `full`.
- **EMBED-3 (SHOULD)** `#:sticky #t` keeps the figure in view while the reader scrolls the passage that discusses it: it pins within its own section and releases at the section's end. On narrow tiers it pins to the top of the viewport at reduced height, and the reader can collapse it. This is what makes a figure usable as an argument aid rather than an illustration passed by.
- **EMBED-4 (MUST) Fallback is required**, not optional: `#:fallback` names a static image of the figure's key state, shown when JS is off, WebGL is unavailable, the bundle fails to load, or the page is printed. `#:alt` is required too, and the caption must make sense without the interaction. **The argument survives in prose**; a figure supports it.
- **EMBED-5 (MUST)** Each widget lives in `widgets/<name>/` with its own `package.json` and is built by CI (e.g. Vite) to a single hashed ES module plus CSS at `/widgets/<name>/`. Built bundles are not committed. Data (taxa, memberships, positions, labels) is JSON beside the source, so corrections never mean touching animation code.
- **EMBED-6 (MUST)** Budget: widgets are **excluded from the page JS budget** (§14) because they never load before first paint, but each is capped at **250 KB gzipped**, and the container reserves its final height so nothing shifts. A widget that exceeds the cap needs a lighter library, not a bigger budget.
- **EMBED-7 (MUST)** Libraries are chosen per widget, not site-wide. Use the lightest thing that makes the argument: Canvas or SVG with d3 for plane graphs and networks; **Three.js only where depth carries the argument** (the taxonomy figure needs an orthographic camera, so it qualifies). Record the choice and its reason in the widget's README.
- **EMBED-8 (MUST)** Accessibility and manners: all controls keyboard-operable with ARIA labels; a text description of what the figure shows, available to screen readers and expandable by anyone; `prefers-reduced-motion` turns guided transitions into immediate state changes; the figure never hijacks page scroll, and drag/zoom gestures work on mobile Safari without trapping the page.
- **EMBED-9 (MUST)** Theming: widgets read the site's CSS custom properties (`--bg`, `--text`, `--accent`, …) rather than hard-coded colours, so they follow light and dark mode. Colour carries meaning in some figures, so each widget's palette must also pass contrast in both themes.
- **EMBED-10 (SHOULD)** Guided controls, not free exploration, by default: named reversible transitions ("Reveal evolutionary history" / "Return to descriptive taxonomy"), eased over ~1.5–2.5 s, with free dragging optional.
- **EMBED-11 (MUST)** A widget makes no network requests: its data ships with it. No analytics, no CDN.

---

## 10. Typography, themes, page

### 10.1 Measure and setting

- **TYPE-1 (MUST)** Maximum measure ≈ **90 characters**. CSS `ch` is wider than an average character, so set the column in `em` and **calibrate by measurement**: render ordinary prose, count characters on 20 full lines, adjust until the mean is ≤ 90. Record the value in the colophon.
- **TYPE-2 (SHOULD)** Body ~18–20 px, line-height ~1.5–1.55, tuned to the chosen face on the specimen page.
- **TYPE-3 (MUST)** Justified only at full measure; ragged right below that (phones, narrow windows).
- **TYPE-4 (MUST)** `hyphens: auto` wherever body text is set, with the right `lang`.
- **TYPE-5 (MUST — verify)** Spelling is Australian. `lang="en-AU"` is correct semantically, but test hyphenation in Chrome, Safari and Firefox; if any fails, use `en-GB` on the body container and document it. *Status 2026-10-12: passes in Chrome, Safari 26.6 and Firefox (104 and 157); Safari hyphenates ragged text more sparingly but has an `en-AU` dictionary. No `en-GB` fallback needed.*
- **TYPE-6 (SHOULD)** `text-wrap: pretty` for paragraphs, `balance` for headings; `hanging-punctuation: first` where supported.

### 10.2 Typeface

- **TYPE-7 (MUST) Typeface: Libertinus Serif** (SIL Open Font License 1.1; maintained at [alerque/libertinus](https://github.com/alerque/libertinus), the successor to Linux Libertine). Chosen for the current build: free, very wide glyph coverage, and no licence constraints on the repo or on traffic.
  - **Styles**: Regular, Semibold and Bold, each with italic. Use Regular and its italic for text; Semibold rather than Bold for the rare emphasis, which sits better in a text face.
  - **Companions in the same family**, available if wanted: Libertinus Serif Display (for the essay title and level-1 headings), Serif Initials (outlined capitals, for a drop cap), Sans, Mono and Math. Mono is the face for `◊code`. Math matters later if an essay needs equations.
  - **OpenType features**: verified in 7.051: `smcp`, `c2sc`, `onum`, `lnum`, `pnum` and `tnum` work. The default figures are **lining tabular**, and `onum` alone gives tabular old-style; prose therefore sets `oldstyle-nums proportional-nums`, tables `lining-nums tabular-nums`. Set the figure styles explicitly in CSS rather than trusting defaults.
  - **Known trade-off**: it is less finely fitted on screen than the paid faces. Judge it on the specimen page at the final measure and size, and tune the line-height and letter-spacing there rather than accepting the defaults.
  - **Swapping later is cheap**: the choice is confined to the `@font-face` rules and the calibrated measure (TYPE-1). Heldane Text and Century Supra stay in `BACKLOG.md` as the paid alternatives if you want more voice once the site is running.
- **TYPE-8 (MUST)** Self-hosted, converted to **WOFF2** and subset by the build (`tools/fonts.py`, fonttools) to the characters in the sources plus a fixed base set, keeping only the OpenType features the CSS uses; file names carry a content hash. Regular and italic are preloaded. Libertinus Mono, for `◊code`, is a fourth file, downloaded only by pages that use it. No third-party font service, including no Google Fonts or Fontsource CDN.
- **TYPE-9a (MUST) Licence handling.** The OFL permits bundling, modifying and subsetting, so unlike the paid faces the font files **are committed to the public repo** (the upstream OTFs; the build makes the WOFF2 subsets) and CI needs no secret. Keep `OFL.txt` beside them in `assets/fonts/`, note the version (7.051), and credit the family in `/colophon`. The release's `AUTHORS.txt` and `FONTLOG.txt` are not copied: they carry contributors' email addresses. If a subset or conversion is ever distributed as a font in its own right (rather than served to style this site), check the release's reserved-font-name status before keeping the Libertinus name.
- **TYPE-10 (MUST)** Metric-matched fallback (`size-adjust`, `ascent-override`, based on Georgia) so the font swap causes no reflow.
- **TYPE-11 (MUST)** Small caps for acronyms are **manual**: `◊sc{WHO}`. No automatic detection.

### 10.3 Typographic rules

- **TYPE-12 (MUST)** Replacements live in a **rules table** in `typography.rkt`, applied to every string by the `root` pass (`decode … #:string-proc`), excluding `code`, `pre`, `script`, `style`. Adding a rule is one line. Rules run in order, after `smart-quotes` and `smart-dashes`.
- **TYPE-13 (MUST)** Before the rules run, adjacent strings are merged and source line breaks become spaces (SRC-3). Otherwise a rule such as "number + unit" fails silently wherever `fill-paragraph` wrapped the line. Rules cannot match across inline tags, which is accepted.
- **TYPE-14 (MUST)** Every rule has a RackUnit test in `typography-test.rkt`, including a case where it must not fire. `make` runs the tests before rendering.
- **TYPE-15 (MUST)** v1 rules:

  | Rule | Source | Output |
  |---|---|---|
  | Em dash | `word---word`, `word — word` | hair space + word joiner + — + hair space |
  | Ellipsis | `...` | … |
  | Number + unit | `10 kg`, `5 mg` | narrow no-break space (U+202F) |
  | Initials | `C. H. Waddington` | narrow no-break spaces |
  | Locators | `p. 42`, `ch. 3` | no-break space after the abbreviation |
  | Multiplication | `3 x 4` (digits both sides) | 3 × 4 |
  | Ranges | `1998-2004` (digits both sides) | en dash |

  The word joiner sits directly before the dash, so no line starts with one (the earlier order, joiner before the hair space, allowed a break between hair space and dash); a break after the dash is allowed. Justification does not stretch hair spaces. *Verified:* Libertinus's U+200A is 0.026 em (0.009 em in italic), so the dash reads as nearly closed, which is accepted; a trailing hair space does not hang in Chrome but pulls the justified edge in by only ~0.5 px.

### 10.4 Themes and controls

- **THEME-1 (MUST)** Follow `prefers-color-scheme` by default; the control offers **Auto · Light · Dark**, stored in `localStorage` (try/catch), site-wide. Auto keeps following the system live.
- **THEME-2 (MUST)** No flash: a tiny inline script in `<head>` (< ~500 bytes, the only blocking script) sets `data-theme` and the text-size step before paint.
- **THEME-3 (MUST)** All colours are custom properties defined once per theme (`--bg`, `--text`, `--text-muted`, `--accent`, `--accent-visited`, `--rule`, `--popup-bg`, `--popup-border`, `--selection`). No colour literals elsewhere. Each token is written once as `light-dark(light, dark)`; `color-scheme` on the root picks the half (Auto follows the system; `data-theme` forces one). Browsers without `light-dark()` (Safari < 17.5, Firefox < 120) get the same values through an `@supports not` block, so an old browser falls back to the site's own themes, never to the browser's defaults.
- **THEME-4 (MUST)** Light: dark-ivory background, black text. Dark: near-black background, light grey text. **Chosen** on the specimen page (D1, resolved 2026-10-12):

  | Token | Light | Dark |
  |---|---|---|
  | `--bg` | `#EFE7D4` | `#121212` |
  | `--text` | `#000000` | `#D2D2D0` |

  The other candidates are dropped, and the specimen page's candidate-colours panel is removed. Every pair must pass WCAG AA. The remaining tokens are as built and may be tuned on the specimen page: light `--text-muted #5A5244`, `--accent #8A3A26`, `--accent-visited #8A5344`; dark `#9C9A95`, `#D49A7E`, `#B08C7C` (all ≥ 4.5:1 on their background).
- **THEME-5 (MUST)** Reader controls in v1 are **theme and text size**. Text size has **five steps** on one root variable, the middle step being the calibrated default (TYPE-2); the range runs from roughly 0.85× to 1.2×, tuned on the specimen page. The choice is stored in `localStorage` (try/catch), site-wide, and applied by the no-flash script (THEME-2) before paint. The control is a pair of buttons (smaller, larger) in the reading bar, each with an accessible name, disabled at its end of the range. The step scales the page wrapper's font size, from which the column, gutters and tier queries are all set in `em`; the measure therefore stays at ~90 characters at every step (TYPE-1), and the tiers follow (LAYOUT-7): on a laptop, a step or two up drops the page from tier L to M, and margin content becomes popups. That is accepted. Browser zoom still works and compounds with it.
- **THEME-6 (MUST)** The theme control sits quietly at the top right of the header and is repeated in the reading bar (BAR-1), so it is within reach anywhere in an essay: an icon button with an accessible name, keyboard operable. The two stay in step.
- **THEME-7 (MUST) Specimen page** `/specimen`, excluded from feeds and indexes: every element the site can render — body text, intro paragraph, all heading levels, every mark (including a shared circle), asides (stub and expanded), margin notes, notes, definitions, lists, breaks, quotes, figures, tables, TOC, and the reading bar. It is the test bed for colours, type size and grade, and the page to check after any CSS change.

### 10.5 Page furniture

- **LAYOUT-1 (MUST)** Essay header: title, subtitle, dates (§13), epistemic status, optional abstract.
- **LAYOUT-2 (MUST) Headings.** Level 1: right-aligned small caps with a full-width hairline rule beneath. Level 2: left-aligned small caps, smaller, no rule. Level 3: italic, run in at body size.
- **LAYOUT-3 (MUST) Intro paragraph.** The first paragraph after the abstract is marked `.intro`; its first line is small caps (`::first-line`) **in narrow tiers only**. With TYPE-3, rotating a phone changes both the small caps and the justification, as on gwern.net.
- **LAYOUT-4 (MUST) Section break.** `◊break{}` renders a centred glyph (SVG, `currentColor`, smaller variant when narrow), `role="separator"`, generous equal space above and below. Author-placed, never automatic. One glyph; no cycling.
- **LAYOUT-5 (SHOULD)** Print stylesheet: asides and notes become footnotes, and each note's **numeral is printed in the text** in place of its circle (paper has nothing to open); asides, being unnumbered, need a printed key of their own (symbols such as * † ‡, to settle with the print CSS in Phase 3); external URLs printed after their link text; arrows, circles for definitions, the bar and popups hidden.
- **LAYOUT-6 (MUST) Width tiers** (container queries, §10.6):

  | Tier | Condition | Margin | Column |
  |---|---|---|---|
  | XL / L | column + right margin fit | aside stubs + margin notes; opened notes and definitions | justified |
  | M | column fits at full measure | none; circles open popups | justified |
  | S | below full measure | none; circles open popins | ragged right |

- **LAYOUT-6a (MUST) Placement of the text block.** In tier L the column and its right margin are centred **together**, so the text sits left of the window's centre. This is intended and settled (2026-10-12): do not re-centre the column.

### 10.6 Layout mechanics

- **LAYOUT-7 (MUST)** Implement tiers as **container queries** on the page wrapper, not media queries: relative units in container queries resolve against the container's computed font size, so the layout stays right if the reader zooms or sets a larger default font. Verify in Safari, Chrome and Firefox. *Status 2026-10-12: verified in Chrome, Safari 26.6 and Firefox 157, tiers L and S in each. Firefox before 110 has no container queries and shows tier S at every width, which is an acceptable fallback.*

---

## 11. Popups

One popup component serves same-page links, cross-essay extracts and external link cards at every width, and notes, terms and asides on narrow tiers. On wide tiers the three circle types open in the right margin instead (POP-8). To the reader a circle always does the same thing: it shows its content beside or over the text without moving the page.

| Input | Result |
|---|---|
| Hover (pointer devices) | Popup after ~300 ms |
| Pointer leaves element and popup | Closes after ~250 ms grace |
| Click / tap | Opens and **pins**; does not navigate |
| Cmd/Ctrl-click, middle-click | Native new tab |
| Esc / click outside | Closes |

- **POP-1 (MUST)** Title bar: the target's title, **Open in new tab** (where a URL exists) and **Close**.
- **POP-2 (MUST)** Positioned to stay in the viewport, never covering the element that spawned it.
- **POP-3 (MUST)** Keyboard: annotated elements are focusable; Enter opens and pins, moving focus into the popup; Esc returns focus to the element.
- **POP-4 (MUST)** `role="dialog"` when pinned, `role="tooltip"` on hover; labelled by title. `prefers-reduced-motion` disables animation.
- **POP-5 (MUST)** Touch devices (`(hover: none)`): tap opens a **popin** — a sheet anchored to the bottom, capped at ~60% of the viewport, with the same title bar; the page doesn't scroll behind it; swipe down or Close dismisses.
- **POP-6 (MUST)** Nesting is **out of scope in v1** (BACKLOG), except replacement: a `see-also` term inside a term popup, or any circle inside an open item (a note inside an aside, a term inside a definition), replaces that item's content, with a Back control.
- **POP-7 (MUST)** Content by type: same-page link → the target section cloned from the DOM; cross-essay link → a build-time fragment `/_x/<slug>/<id>.frag` fetched on demand (not `.html`, which Cloudflare's HTML handling redirects) (prefetched on `pointerenter`); citation → the note, headed "Note *n*" (no heading where unnumbered, CITE-7); under a short-form note, also the bibliography entry (a full note already is the reference, and repeating it reads as duplication); term → §6; aside → its text; external link → the card (§11.1 below). A shared circle (MARK-1c) shows its items in source order, separated by a hairline.
- **POP-8 (MUST) Circles on wide tiers open in the margin.** In tiers XL and L, opening a circle shows its content in the right margin, anchored at the circle's line and set like an expanded aside (ASIDE-3: drawn over whatever is below, hairline border, nothing moves). An aside's stub is already there and expands; a note or definition appears only while open and leaves no stub. The inputs are those of the table above (hover, click to pin, Esc), and one margin item is open at a time. In tiers M and S the same content opens as a popup or popin (POP-5). This settles D7.

### 11.1 External link cards

**We publish nothing that isn't ours.** No copies, excerpts, screenshots, images or scraped descriptions of other people's pages. Facts (title, author, date, publisher) are not protected by copyright; prose, abstracts and images are.

- **CARD-1 (MUST)** Fields: title and domain (always), plus author, publisher, date, type and DOI where known; and **your note**, the only prose, written by you as `#:note`.
- **CARD-2 (MUST)** No third-party text or images: no descriptions, abstracts, Open Graph images or favicons (the domain appears as text).
- **CARD-3 (MUST)** Buttons: **Open in new tab**, and **Wayback copy** where a snapshot exists. If the original is known dead, the card says "Original offline since <date>", Wayback becomes the primary button, and the essay's link points there.
- **CARD-4 (MUST)** Card data is committed in `data/link-meta.json` and generated at build; opening a card makes no network request. In v1 the fields are entered by you (in the tag or the JSON); automatic metadata lookup is in BACKLOG.
- **CARD-5 (MUST)** `make refresh` asks the Wayback Machine to save each new URL and records the snapshot URL. A monthly CI job re-checks live URLs and opens an issue listing dead ones; it never fails the build. Marking a link dead is a one-field edit.

---

## 12. Build pipeline and validation

Per essay. `◊list`, `◊table` and `◊figure` expand in their tag functions, before the `root` pass; then:

1. Detect paragraphs (single newlines → spaces); merge adjacent strings; apply smart quotes, smart dashes and the typography rules.
2. Lift margin notes to the start of their paragraphs; build the section tree from heading markers; wrap nested `<section>`s; validate; generate TOC markup.
3. **One document-order walk** assigns citation note numbers, descending into asides (asides themselves are unnumbered, ASIDE-2), and merges adjacent marks (MARK-1c); resolve citations from the cache; mark first uses of terms.
4. Emit the end matter (CITE-10): Terms (following terms inside definitions), Asides, Notes, Bibliography; the copies reuse the assigned numbers.
5. Resolve links and marks; compute ↑/↓.
6. Emit section extract fragments for cross-essay popups.

Glossary files take a shorter pass: paragraphs and typography only.

Site-wide:

- **VAL-1 (MUST)** The build fails on: unknown tag, unknown cite key, unknown term, broken internal link, duplicate id, missing required meta field, missing figure alt or licence, malformed list or table.
- **VAL-2 (MUST)** `tools/validate.rkt`, run after rendering, emits `data/anchors.json` (pages → sections) for validation and Emacs completion, and `data/links.json` (the internal link graph) for backlinks, and checks every cross-page link (LINK-2).
- **VAL-3 (MUST)** If a section id present in the last deployed `anchors.json` disappears while other pages link to it, the build fails; if nothing links to it, the build warns. Published anchors are a promise. The build publishes `/data/anchors.json`, and CI fetches it before building; a failed fetch skips the check.
- **VAL-4 (MUST) Backlinks.** A pre-pass records every internal link with its context (the containing paragraph, list item or aside, with the link marked). Each essay ends with a **Backlinks** section listing the linking essays and sections, each context collapsed to ~2 lines and expandable. Links from within the same page are not backlinks; the glossary has no pages, so it contributes none. (Section-level ← marks are in BACKLOG.)
- **VAL-5 (SHOULD)** CI also runs HTML validation and a Lighthouse budget check (§14).

---

## 13. Revisions, feeds, correspondence

| Meta field | Required | Notes |
|---|---|---|
| `title`, `subtitle` | title | |
| `status` | yes | `draft` / `published` / `revised` / `superseded` |
| `published` | yes | ISO date of first publication |
| `epistemic` | SHOULD | One sentence on confidence and what it rests on |
| `abstract` | SHOULD | Header, cross-essay popups, feed |
| `tags` | MAY | |

- **REV-1 (MUST)** "Last revised" comes from the git log (latest commit touching the file, ignoring `[typo]`/`[meta]` commits), never typed by hand.
- **REV-2 (MUST)** Each essay's footer links to its source file and its history on GitHub.
- **REV-3 (MUST)** `◊changelog{…}` holds one line per substantive revision; `/changelog` aggregates them site-wide.
- **REV-4 (MUST)** RSS/Atom feed of new essays and substantive revisions.
- **MAIL-1 (MUST)** No comment system, contact form, newsletter or third-party embed of any kind.
- **ABOUT-1 (SHOULD)** The About page describes you as a **clinician-theoretician**, in deliberate contrast to clinician-researcher or clinician-academic, and says in a sentence or two why that distinction matters to the essays. The same phrase, not variations of it, is used wherever the site describes you.
- **MAIL-2 (MUST)** A `/correspondence` page gives the postal address and says what to expect: whether letters are read, whether replies are sent, whether letters may be quoted.
- **MAIL-3 (MUST)** The address lives once, in `data/site.rktd`, rendered from there; it is text, not an image.
- **MAIL-4 (SHOULD)** Each essay's footer ends with one line — *"Responses by post: see Correspondence"* — linking to that page, without printing the address.

---

## 14. Performance and accessibility

| Metric | Budget |
|---|---|
| Critical CSS | inlined, ≤ 14 KB gzipped |
| Total CSS | ≤ 25 KB gz |
| JS | ≤ 30 KB gz, ES modules, deferred; nothing blocks first paint except the theme script |
| Fonts | ≤ 3 text files, ≤ 120 KB; regular + italic preloaded (Mono only where `◊code` is used) |
| Third-party requests | **Zero**, including anything Cloudflare could inject: Web Analytics / RUM stays off for the domain |
| LCP | < 1.5 s on throttled 4G |
| CLS | < 0.02 |
| Lighthouse performance | ≥ 98 |

- **PERF-1 (MUST)** All interactive JS loads after first paint and enhances markup already in the HTML.
- **PERF-2 (SHOULD)** Hashed asset filenames with long cache headers; HTML revalidates.
- **A11Y-1 (MUST)** WCAG 2.2 AA contrast in both themes, including marks.
- **A11Y-2 (MUST)** Popups fully keyboard operable (§11); asides in the margin stay in DOM order after their circle; no information conveyed by mark shape alone.

---

## 15. Phases

| Phase | Scope | Done when |
|---|---|---|
| **0 — Skeleton** | Repo, Pollen project, template, section tree, TOC, typography (§10.1–10.3), themes, specimen page, CI deploy | The specimen page renders correctly in both themes and passes the performance budget; measure calibrated |
| **1 — Writing** | All tags; marks; lists; figures; tables; citations + Notes + Bibliography; glossary; no-JS end matter; validation (§12); Emacs commands (§16) | A test essay using every tag builds, validates, and is fully usable with JS disabled. *Done 2026-10-09, with `/specimen` as the test essay; DRAFT-2 carried to Phase 2* |
| **2 — Interaction** | *Built 2026-10-12; awaiting the hand checks in "done when".* Carried over from Phase 1: the publish guard for `status` (DRAFT-2) and the essay meta checks, proved on a first test essay in `essays/`. Popup component; term, note, same-page, cross-essay and card popups; circles opening in the margin (POP-8); aside stubs and expansion; margin notes; reading bar with section, text size and theme (BAR-1, THEME-5); table sorting; image inversion. Opens with the **mark rework** left over from Phase 1: circles replace numerals and ≡, arrows enlarged, marks rebuilt so Safari draws them (MARK-1…1c), build walk and tests updated | The behaviour tables in §7, §11 pass by hand on desktop Safari/Chrome/Firefox and on iOS and Android |
| **2b — Interactive figures** | `◊embed` frame: lazy loading, fallback, sticky behaviour, theming, accessibility contract (§9.3); the first widget (mammal taxonomy) built in its own folder | The taxonomy figure loads lazily in an essay, falls back to its static image with JS off, and follows both themes |
| **3 — Around the essays** | Backlinks; changelog and `/changelog`; feed; correspondence page; Wayback saving and dead-link job; print CSS | Two essays that link to each other show correct backlinks; the feed validates |

Phase 1's Emacs work can start during Phase 0; writing the test essay is much easier with the pickers.

**Note for the builder:** write the popup, aside and sorting JS from scratch against this spec. gwern.net is the behavioural reference, not a code base to copy; if any of its code is consulted, check the licence first.

---

## 16. Emacs (`emacs/occurrent.el`)

All pickers use plain `completing-read`, so they work with Vertico, Ivy, Helm or the default UI, with useful annotations beside candidates.

| Command | Candidates | Inserts |
|---|---|---|
| `od-insert-cite` | every key in the Zotero export named by `ZOTERO_BIB` in `local.mk` (delegate to `citar` if present) | `◊cite["key"]`, prompting for `#:loc` |
| `od-insert-term` | every headword and alias in `glossary/`, plus "New term…" | `◊term["id"]{region}`; aliases resolve to the id |
| `od-new-term` | prompts for headword, proposes an id | Creates `glossary/<id>.pm` from a template, opens it beside the essay |
| `od-find-term` | terms | Opens the term's file |
| `od-insert-link-internal` | sections in this file | `◊link["#id"]{region}` |
| `od-insert-link-essay` | essays, then sections, from `anchors.json` | `◊link["/slug#id"]{region}` |
| `od-insert-link-external` | URLs already used, plus free entry | `◊link["url" #:note "…"]{region}` |
| `od-insert-section` | level (defaults to current) | `◊section[#:id "slug"]{Title}`, slug proposed and checked |
| `od-goto-section` | sections, indented by level | Jumps |
| `od-insert-aside` / `od-insert-margin` | — | `◊aside{}` / `◊margin{}` with point inside |
| `od-preview` | — | Renders and opens the current file in the browser |

- **EMACS-1 (MUST)** A key inserts `◊` (`C-c ;`; the other commands are under `C-c o`). Also set one Option key back to macOS (`ns-right-alternate-modifier`/`mac-right-option-modifier` to `none`) so ⌥⇧V works everywhere.
- **EMACS-2 (MUST)** Commands wrap the active region when there is one.
- **EMACS-3 (MUST)** Glossary candidates are read **directly from `glossary/`** (not a build output), cached per session and invalidated by modification time, so a term created a minute ago is immediately available.
- **EMACS-4 (MUST)** `imenu` support for Pollen headings and an `outline-minor-mode` regexp, so sections fold and move like Org headings.
- **EMACS-5 (SHOULD)** Font-lock dims tag syntax (◊, brackets, keyword arguments) so prose dominates the buffer.

---

## 17. Style guide seed

- **No underlines.** Anywhere, for any purpose. Emphasis is italic.
- **Links.** Link the noun phrase that names the thing, not "here". Link the first mention only. Prefer primary sources; prefer a DOI to a publisher URL. Write a `#:note` for any external link a reader might wonder about.
- **Asides vs body vs notes.** An aside is something a reader could skip; if the argument needs it, it belongs in the text. A note cites; commentary goes in an aside.
- **Aside length.** ≤ ~100 words. Longer asides fall out of the margin and probably want to be sections.
- **Margin notes.** Sparing, ≤ 8 words, and they should read in sequence as a rough outline of the argument.
- **Definitions.** Define a term when a smart reader outside the field would misread it, not merely when they might not know it.
- **Citations.** Numbered notes, Chicago notes-bibliography; page locators for quotations and specific claims; the mark goes after punctuation.
- **Headings.** Sentence case; name what the section argues. `#:short` for anything over ~30 characters. Three levels at most; no numbers.
- **Section breaks.** `◊break{}` for a change of direction within a section, or between an unheaded introduction and the first heading. Never before a heading that already follows one.
- **Lists.** • › – by level; numbering 1. / 1.1. / 1.1.1. Use a list only when items are truly parallel. Columns only for short items. Enumerations inside sentences use (1) (2), never i. ii. iii.
- **Spelling and punctuation.** Australian spelling. Em dashes carry hair spaces (added by the build). En dashes for ranges. Serial comma: *decide (D5)*.
- **Numbers.** Old-style figures in prose, lining in tables. Spell out one to nine.
- **Images.** Every figure carries a licence; third-party diagrams are redrawn and credited.
- **Revisions.** Silent fixes for typos; a changelog line for anything a returning reader would want to know. Never silently reverse a claim.
- **Epistemic status.** Every essay states how confident it is and on what basis.
- **Correspondence.** Letters that change your mind get acknowledged in the changelog, with permission.

---

## 18. Open decisions

| # | Decision | Recommendation | Needed by |
|---|---|---|---|
| D1 | ~~Theme colours~~ | **Resolved:** the first candidate of each pair (THEME-4) | n/a |
| D2 | ~~Host~~ | **Resolved:** Cloudflare Worker with static assets, deployed by wrangler from GitHub Actions | n/a |
| D3 | ~~Typeface~~ | **Resolved:** Libertinus Serif for this build (TYPE-7); paid alternatives parked in the backlog | n/a |
| D4 | Content / code licences | CC BY 4.0 for essays, MIT for code. `LICENSE` and `LICENSE-CONTENT` are TODO stubs; the repository is already public | Before the first essay is published |
| D5 | Serial comma | Your call; record it either way | Phase 1 |
| D6 | Section-break glyph | One custom SVG of your own; a plain asterism is in place (`assets/icons/asterism.svg`) | Before launch |
| D7 | ~~Term popup placement~~ | **Resolved:** definitions, notes and asides all open in the right margin on wide tiers, as popups on narrow ones (POP-8) | n/a |
| D8 | ~~A shared circle without JS~~ | **Resolved:** it links to its first item; a term in the group keeps its own text linked to Terms (MARK-1c) | n/a |
| D9 | ~~Level-1 list bullet~~ | **Resolved:** a small solid dot, so a circle only ever means "opens something" (LIST-2) | n/a |
| D10 | ~~Cross-browser checks~~ | **Resolved:** the builder views Safari and Firefox on this Mac (read-only) and judges screenshots; real iOS and Android checks stay with Ryan | n/a |

Resolved already: Pollen markup over Markdown; sections never numbered; glossary site-wide, popup-only; numbered citation notes in Chicago style, with the number kept out of the running text; right margin only; no comments; no archived copies; Libertinus Serif as the typeface; two marks only, arrow and circle; a text-size control in the reading bar (reversing the earlier cut); the bar shows on scroll-up and hides after 2 s idle; the text block stays where it is (LAYOUT-6a).
