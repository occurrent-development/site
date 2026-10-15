# occurrentdevelopment.com — Specification (v1)

Status: draft 1.6 · Owner: Ryan · Last revised: 2026-10-15 (evening)

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
│   ├── img/                   # images belonging to that essay
│   └── support/               # notes, sources, drafts in other formats; gitignored, never published
├── glossary/<id>.pm           # one file per term; never rendered as a page
├── widgets/<name>/            # source of an interactive figure (§9.3); built by CI
├── pages/                     # about, colophon, specimen; later correspondence, changelog
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
- **BUILD-3a (MUST)** Each essay is a **folder**, holding the `.pm` file, its own images in `img/`, and a `support/` folder for everything else: notes, sources, sketches, drafts in other formats. `support/` is gitignored for every essay by one rule (`essays/*/support/`), so it never reaches the public repo, before or after publication; the build never reads it. As a second guard, nothing whose filename matches `*-Notes.md`, `*.graffle`, `*.docx` or `*.tex` is ever copied into the public repo either (gitignored, and the build refuses to publish them). Published essays keep the same folder shape. `od-new-essay` creates the three (HANDOVER-EMACS.md, EDIT-6). *Revised 2026-10-15 (evening): `support/` added.*
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
- **SRC-4 (MUST)** A `◊define-meta` value stays on **one line**: Pollen reads further lines as extra key/value pairs and the build fails. `occurrent.el` keeps meta lines out of `fill-paragraph`.
- **SRC-4a (MUST) Header text in the body.** The abstract and the epistemic status are tags, `◊abstract{…}` and `◊epistemic{…}`, written at the top of the source after the meta lines and before the first paragraph or heading, once each. They wrap like any paragraph and may hold markup (emphasis, citations, terms, `◊ref`); the root pass takes them out of the body and sets them in the header (LAYOUT-1), so a citation in the abstract is numbered first. Empty, they count as absent. `◊define-meta[abstract]` and `◊define-meta[epistemic]` are build errors that name the new form. *Changed 2026-10-15: they were one-line meta values.*

### 3.2 Example

```
◊define-meta[title]{Occurrent development}
◊define-meta[status]{published}
◊define-meta[published]{2026-10-01}
◊define-meta[tags]{philosophy, child development}

◊epistemic{Speculative; argued from theory rather than data.}

◊abstract{Why development is better described as a process than a sequence
of states.}

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
| `◊abstract{…}` / `◊epistemic{…}` | The header's abstract and epistemic status, written in the body (SRC-4a) | body | — |
| `◊more{…}` | Long text of a glossary definition (§6); glossary files only | body | — |
| `◊list{…}` | Lists (§3.4) | body | `#:start`, `#:columns` |
| `◊table{…}` / `◊table-csv[path]` | Tables (§9.2) | body / path, `#:id`, `#:title` | `#:caption`, `#:source`, `#:size`, `#:sortable`, `#:align`, `#:row-headers` |
| `◊sort-key[value]{text}` | The value a table cell sorts by (TABLE-5) | value | — |
| `◊figure[src]{caption}` | Image (§9.1) | src, `#:id`, `#:title`, `#:alt`, `#:licence` | `#:invert`, `#:credit` |
| `◊ref[id]` | "Figure 2", "Table 1": a link to a figure or table on the page (IMG-7) | id | |
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
- **MARK-3a (MUST)** When punctuation (`, . ; : ! ? … ) ] ’ ” »`) follows a link, note, definition or aside, the mark goes **after the punctuation**: *elsewhere.°*, *philosophy;↗*, never *elsewhere°.* The build moves the punctuation into the no-wrap span, between the word and the mark, so word, punctuation and mark never part across lines. Inside a link the punctuation keeps the text colour. *Revised 2026-10-14 (first version kept the mark before the punctuation).*
- **MARK-3b (MUST)** When the word before a mark ends an inline phrase (`◊em{London Review of Books}`), only the phrase's last word is bound to the mark, so the rest of the phrase can still wrap. *Added 2026-10-14.*
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

## 5. Citations and references

*Renamed 2026-10-16: what this section called notes are **references**, to keep them apart from asides; and there is no bibliography section. Where older text below says "note" of a citation, read "reference". (`#:note`, a remark attached to a link or citation, and margin notes keep their names.)*

Citations are **numbered references**, collected in a **References** section at the foot of the essay. The number belongs to the reference, not to the text: in the text a citation is a circle (§4.1), and no numeral is printed there. With JS, opening the circle shows the reference, headed with its number ("Reference 3"), in a popup at every tier (§11; notes never occupy the margin, POP-8); without JS the circle is a link to the note.

- **CITE-1 (MUST)** References are numbered per essay in **source reading order**, including citations inside asides. An aside sits in the source right after its circle, so its citations are numbered at that point in the argument. The number appears in the Notes list, in the opened note's heading and in print (LAYOUT-5); never as a superscript on screen.
- **CITE-2 (MUST)** Numbering happens **once**, in a single document-order walk in the `root` pass, **before** asides are duplicated for the no-JS endnote copies. The copies reuse their numbers. Getting this wrong double-counts asides; CITE-8 tests it.
- **CITE-3 (MUST)** Each `◊cite` gets its own number. The first note for a work gives the full reference; later notes the short form. No *ibid.*
- **CITE-4 (MUST)** Each note has a ↩ back-link to its mark. If the mark is inside an aside, the back-link scrolls to the aside (expanding it on wide screens, opening its popup on narrow ones).
- **CITE-5 (MUST)** Formatting is not done in Racket. `tools/refs.py` (`make refresh`) runs `pandoc --citeproc` with a *note* CSL style and stores, for every key **and every locator the sources use with it**, the full and short note, plus the bibliography entry and DOI/URL, in `data/cite-cache.json`. Racket only picks first vs later. Letting pandoc place the locator gets Chicago punctuation right (`“Making Up People,” 23.`, `What?, 31–34.`); a new locator therefore needs a `make refresh`, and the build says so. No abstracts are stored or shown (§11.1 policy); `refs.bib` never carries abstracts, notes, keywords or file paths.
- **CITE-6 (SHOULD)** Style: **Chicago notes and bibliography**.
- **CITE-7 (MUST)** Citations outside the essay's own sequence — inside glossary definitions or cross-essay extracts — are **unnumbered**. They carry the same circle and open the work's full entry (kept, hidden, in the page); without scripts the entry is printed under the definition in the Terms section; they have no entry in the essay's Notes.
- **CITE-8 (MUST)** Test fixture: an essay with citations in body text, in several asides, repeats of one work, and a term whose definition cites something. Expected numbering, forms and back-links are asserted.
- **CITE-9 (MUST)** An unknown key, or a key and locator missing from the cache, fails the build with a message to run `make refresh`.
- **CITE-10 (MUST)** End matter order: **Terms** (no-JS only) · **Asides** (no-JS only) · **References** · **Backlinks** · **Changelog**. There is **no bibliography section** (*removed 2026-10-16*): a work's first reference is already in full (CITE-3). Each cited work's full entry is still emitted, in a hidden store, so a short-form reference's popup can show it (POP-7) and an unnumbered citation can open it (CITE-7).

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

- **TERM-3 (MUST) From an essay, popups only.** A `◊term` never navigates: it is never a link to a page, including the glossary page (TERM-8). There are no per-term pages. On wide tiers a definition sits in the right margin as a **collapsed stub exactly like an aside's** (ASIDE-3): the headword, then the opening words of the definition, cut with an ellipsis, with the hairline rule on the right; opening it expands the stub in place to the headword and short definition (aside size, ragged right), with **More** expanding `◊more` in place below, growing to ~70% of the viewport and then scrolling. `see-also` terms appear at the foot; opening one opens a popup over the page (POP-6). On narrow tiers a `◊term` opens a popup or popin (POP-8). *Revised 2026-10-15: definitions get stubs.* Definitions used by an essay are embedded in that essay's HTML at build, so popups need no network request: the no-JS Terms section is that store, hidden when scripts run.
- **TERM-4 (MUST)** No-JS: an essay that uses terms ends with a **Terms** section giving each used term in full; first uses link to it.
- **TERM-5 (SHOULD)** Only the **first** occurrence in an essay carries the circle and is interactive; later ones are plain text unless `#:mark #t`.
- **TERM-6 (MUST)** Validation: unknown id, bad filename, missing `term`/`added`, empty definition, dangling `see-also`, or an alias claimed by two terms all fail the build. Unused terms warn.
- **TERM-7 (MUST)** A `◊term` inside a definition keeps its circle. In the margin it opens a popup over the page, leaving the definition open; inside a popup it replaces the popup's content, with a Back control (POP-6). *Revised 2026-10-15.*
- **TERM-8 (MUST) The glossary page.** One page, `/glossary` (`pages/glossary.html.pm`), in the site menu beside Home and About (NAV-1), built from `glossary/` at render, so nothing is written twice. Every term, alphabetical by headword: headword, aliases, the short definition, `◊more` in full, `see-also` as links within the page, and a **Used in** line naming the essays that mark the term, in the order of the index. Each entry has an anchor `#<id>` so the page can cross-reference itself and an entry can be pointed to from outside; essays never link there (TERM-3). Citations inside definitions keep their circles (CITE-7). The build records which pages mark each term (VAL-2) and, as for the home page, rebuilds the glossary whenever anything is rebuilt; the project server may show a stale Used in until `make` runs (BUILD-4). Not listed on the home page. No per-term pages and no further index. Phase 3. *Added 2026-10-15; replaces BACKLOG §13.*

---

## 7. Asides and margin notes

### 7.1 Asides

| Tier | Rendering |
|---|---|
| Wide (XL, L) | **Collapsed stub** in the right margin, always visible, top-aligned with the line holding its circle; click to expand in place (ASIDE-3) |
| Narrow (M, S) | The circle opens the aside as a popup/popin |
| No JS | Asides are collected in an **Asides** list at the end, in source order, each with a ↩ return link; the circle links to its entry |

- **ASIDE-1 (MUST)** Source position is canonical: the build emits each aside inline, right after its circle (hidden until JS lifts it into the margin), and a separate no-JS copy in the Asides list, hidden when JS runs.
- **ASIDE-2 (MUST)** Asides are **not numbered**: no roman numerals, in the text, the stub or the popup. An aside is tied to its circle by position (the stub sits on the circle's line); when either is hovered or focused both take the accent; and **while the aside is open its circle is filled**, whatever the pointer does, until it closes. The same holds for definitions and for a circle whose popup is pinned. *Revised 2026-10-15: the fill no longer follows hover.*
- **ASIDE-3 (MUST) Stubs that expand in place.** In wide tiers an aside starts as one margin line: its opening words, cut with an ellipsis, with a **hairline vertical rule** (`--rule`) on the right edge of the margin, one line tall. Definitions have the same stub (TERM-3); the margin holds nothing else but margin notes. The margin is a fixed width, so every rule falls on the same vertical line down the page. *Revised 2026-10-15: replaces the boxed overlay; definitions now have stubs too.*
  - Clicking the circle or the stub, or Enter on either, **expands the stub itself**: the same text grows downward in place and the rule grows with it. No box, no background, no horizontal rules (they would clash with the rules under headings). Whatever is below in the margin, stubs and margin notes alike, **moves down** to make room and returns when the item closes; the column never moves. Click again, Esc, or opening another collapses it. One margin item is open at a time.
  - **Hover never opens a margin item**: opening reflows the margin, and a pointer crossing circles would make it jump. Hover only pairs circle and stub by colour (ASIDE-2). Popups keep their hover behaviour (§11).
  - An aside or definition that fits in two margin lines is shown in full and never collapses; its rule is two lines tall.
  - Circles and stubs are focusable; `aria-expanded` is set.
- **ASIDE-4 (MUST)** Collisions: stubs are one line, so overlap is rare. When two would overlap, the later moves down just enough to clear; an open item pushes everything below it (ASIDE-3). Recalculate on resize, after fonts load, and whenever an item opens or closes.
- **ASIDE-5 (MUST)** Asides use the **right margin only**; the left margin is reserved (BACKLOG: running map).
- **ASIDE-6 (SHOULD)** Aside size ≈ 0.85 × body, ragged right, never justified.
- **ASIDE-7 (MUST)** Asides may contain links, citations and terms, which behave normally.

### 7.2 Margin notes

A margin note is a short unnumbered gloss on a whole paragraph — a signpost for a skimming reader — written at the start of that paragraph.

- **MNOTE-1 (MUST)** No marker, not interactive, so no mark.
- **MNOTE-2 (MUST)** Wide tiers: right margin, top-aligned with the paragraph's first line, italic, aside size, ragged right; not repeated in the text.
- **MNOTE-3 (MUST)** Narrow tiers and no-JS: inline italic run-in at the start of the paragraph. The build emits the inline form; CSS/JS lifts it into the margin when wide.
- **MNOTE-4 (MUST)** Margin notes hold their position relative to their paragraph; stubs move around them. An open margin item above pushes them down like everything else and they return when it closes (ASIDE-3). *Revised 2026-10-15.*
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
- **TOC-1 (MUST)** A table of contents is generated for any essay with ≥ 3 sections, placed after the abstract (and after an opening epigraph), before the first paragraph. Levels 1–2, plain HTML, works without JS, no bullets or underlines, set smaller in the text face. *Revised 2026-10-14: it shows in the text only without scripts; see TOC-2.*
- **TOC-2 (MUST) Where the contents show.** With scripts, the contents are never in the text. When the window has room, they sit in a **left margin** (11em, with a 2.5em gap), top-aligned with the essay header and **staying in view** as the reader scrolls (sticky). Set compactly in the system sans, smaller, with every entry in the muted colour except the **current section and subsection**, in the text colour. Otherwise they open only from the section name in the reading bar (BAR-1).
  - **Order of loss.** As the window narrows, the **right margin goes first**, then the left: both margins at ≥ 68.5em; contents and column, with asides and notes as popups in place (tier M), from 53.75em; below that, the column alone. Built with an outer container (`.frame`) that decides whether the left margin fits and narrows `.page` by it, so the tiers of LAYOUT-6 see only the width left over. Pages without contents keep LAYOUT-6 unchanged.
  - **Too tall:** the list scrolls on its own (the "Contents" label stays), and when the current section changes it scrolls so that section is at its top, with what is left to read below; near the end it stops at the bottom of the list. The reader can scroll it back to see what they have read.
  - **Too wide:** an entry longer than the margin ends in an ellipsis; hovering or focusing it shows the whole title over the gap.
  - **Current entry (SHOULD).** Colour alone does not make the current entry findable at a glance (seen 2026-10-15), so a short hairline in the gutter to the left of the current entry marks it: `--rule`, one line tall, about 1em long, beside the deepest current entry (the subsection when the reader is in one, otherwise the section), moving with it as the reader scrolls; under `prefers-reduced-motion` it jumps rather than slides. Nothing else changes: no accent colour, no change of weight, no reflow.
  *Revised 2026-10-14; current-entry mark added 2026-10-15.*
- **BAR-1 (MUST)** **Reading bar**: a slim bar fixed to the top of the viewport on pointer devices, and to the **bottom on touch devices** (`hover: none`, the test POP-5 uses), whatever the tier, so rotating a phone never moves it; at the bottom it sits above the home-indicator inset. *Revised 2026-10-15: was tied to tier S.* It overlays the page (it never pushes content, so no layout shift). It holds, left to right: the **current top-level section** (`#:short`; the essay title before the first section), truncated with an ellipsis when narrow; the **text-size control** (THEME-5); the **theme control** (THEME-6), as a button in the bar, not inside a menu. Tapping the section name opens the full TOC as a popup/popin with the current section marked.
- **BAR-1a (MUST) When it shows.** The bar appears when the reader **scrolls up**, once the site header has left the viewport, and hides again on **scrolling down** or after **2 seconds without scrolling**. Scrolling down never summons it, so it does not flicker while someone reads down a page. *Revised 2026-10-14: scrolling down now hides it at once.* It stays while the pointer is over it, while keyboard focus is inside it, and while its TOC is open; the 2 seconds start when those end. Tabbing into it reveals it, so it is reachable without scrolling. Under `prefers-reduced-motion` it appears and disappears without animation.
- **BAR-1b (MUST) Mechanics.** The current section is tracked with IntersectionObserver. Showing and hiding needs scroll direction and an idle timer: one passive scroll listener (or `scrollend` where supported) that toggles a class and restarts a timer, and does nothing else — no layout reads, no per-frame work.
- **BAR-1c (MUST)** Without JS there is no bar; the header's controls need JS as well, and the page follows the system theme and the browser's own zoom.
- **BAR-2 (MUST)** Navigating from the TOC or bar pushes a history entry, so Back returns the reader to where they were.

---

## 9. Figures and tables

### 9.1 Figures

- **IMG-1 (MUST)** Build pipeline (`tools/images.py`: Pillow for resizing, WebP and the JPEG/PNG fallback; `avifenc` for AVIF): variants at 480–2400 px, never above the source, with `srcset`/`sizes` and explicit `width`/`height` (no layout shift). The first figure loads eagerly; the rest use `loading="lazy"` and `decoding="async"`. Sources in `img/`; variants not committed; warn above ~2 MB. SVG sources are inlined (IMG-5).
- **IMG-2 (MUST)** Every figure and table is **column width**; nothing but its words enters a margin. `#:width` is a build error. A reader who wants one larger uses Expand (IMG-8). *Revised 2026-10-15: `wide` and `full` are retired.*
- **IMG-3 (MUST)** Every figure and table has a **label and title** ("Figure 1  The continuant and the occurrent": label and title together in semibold, so they stand apart from the caption, the label with an ordinary capital and lining figures (as in `◊ref` and in a popup's title, which for figures and tables is not in small caps), one line, wrapping as needed; revised 2026-10-15), an optional **caption** and a **credit** where there is one, all at aside size, ragged right. Where they go depends on the tier: in **tier L** all three sit in the **right margin**, top-aligned with the figure, title first, then caption, then credit; the caption takes no height in the column, so a long one runs on down the margin, and margin items fit around these words as around margin notes (ASIDE-4, MNOTE-4). In **narrower tiers** the label and title sit above the figure, the caption and credit below. Captions may contain cites, links and terms; a term there opens a popup (it is already in the margin). *Revised 2026-10-15, from Ryan's sketches.* `#:alt` is required; a missing alt fails the build; `#:alt ""` marks a decorative image.
- **IMG-3a (MUST) One caption style, one credit style.** Every caption, of a figure, table or embed, is set identically: text colour, aside size, ragged right. Every **credit line**, a figure's `#:credit` or a table's `#:source`, is set identically too: `--text-muted`, italic, smaller than the caption, below the element. A reader must be able to tell a credit line from a caption at a glance (seen 2026-10-15, when a table's source note read as a caption). *Added 2026-10-15.*
- **IMG-7 (MUST) Numbers, ids and references.** Every figure and table needs `#:id` (permanent, lowercase, hyphenated; it is the element's id) and `#:title`; a missing one fails the build. They are numbered in document order, each kind on its own, as LaTeX does: Figure 1, 2…; Table 1, 2…. `◊ref[id]` prints the label with a non-breaking space ("Figure 2") as a same-page link, with its arrow and its popup (the figure or table, titled by its label); an unknown id fails the build. The number is never typed. Emacs: `od-insert-ref` (`C-c o r`) offers the ids in the file. *Added 2026-10-15.*
- **IMG-8 (MUST) Expand.** Every figure and table has an **Expand** button at its top right (over an image's corner; above a table's top rule), drawn, with an accessible name ("Expand Figure 2"). It opens the figure or table as large as the window allows, with the essay shaded behind: on pointer devices a panel almost the size of the window, the label and title at the top and the caption and credit below; on touch devices (`hover: none`) the whole screen, the figure alone, the words shown over it on a tap and hidden on the next. Images load the variant the window needs; tables keep their rules, at body size, and scroll inside the view if large. Close, Esc or a click on the shade closes it and returns focus to the button; focus stays inside while it is open. Without scripts there is no button. *Added 2026-10-15.*
- **IMG-4 (MUST)** Dark mode: images are classified once at `make refresh` by [InvertOrNot](https://invertornot.com/), cached in `data/invert.json` by SHA-256. Invertible images get `filter: invert(1) hue-rotate(180deg)` in dark mode; others are dimmed (`brightness(.9)`). Invertible images are also blended (`multiply` in light, `screen` once inverted in dark), so a white ground becomes the page background in both themes. `#:invert #t|#f` overrides. Never called from the reader's browser. `tools/invert.py` asks by SHA-1 first (no upload); InvertOrNot may keep uploaded images, so it uploads only figures that are `own`, public domain or CC-licensed, never `permission`. SVG is never classified: it follows the theme in `currentColor`. The model is open source, so it can be run locally if the service goes away.
- **IMG-5 (SHOULD)** Prefer SVG for line art, with `currentColor` strokes, so it follows the theme without inversion.
- **IMG-6 (MUST) Rights.** Every figure declares `#:licence` (`own`, `public-domain`, a CC licence, or `permission`) and `#:credit` where not your own. A missing licence fails the build. Third-party diagrams are redrawn by you and credited "after X (year)". Quoting text in essays for criticism and review, with attribution, is normal fair dealing and is unaffected.

### 9.2 Tables

- **TABLE-1 (MUST)** Two sources: pipe tables inside `◊table{…}` (parsed like lists) and `◊table-csv[path]`. Cells may contain inline tags. A wrong cell count fails the build.
- **TABLE-2 (MUST)** Sizes (`#:size`): `normal`, `small` (≈ aside size), `tiny` (≥ 12 px). Always column width (IMG-2). `#:title` and `#:id` as IMG-7; `#:caption` is the optional caption, `#:source` the credit.
- **TABLE-3 (MUST)** Booktabs typography: no vertical rules; heavier rule above the header and at the foot, hairline under the header; no zebra striping, subtle hover highlight; lining tabular figures; numeric columns right-aligned automatically (override with `#:align`); caption above, source note (`#:source`) below as a credit line (IMG-3a).
- **TABLE-4 (MUST)** Overflow scrolls inside the table's own container with an edge fade; the page never scrolls sideways. Header row sticky on long tables: CSS cannot pin a header to the viewport from inside a sideways-scrolling container, so this is Phase 2 script.
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
- **EMBED-2 (MUST)** Column width, with title, caption and credit placed as for figures (IMG-2, IMG-3). *Revised 2026-10-15.*
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
- **TYPE-4a (SHOULD) Hyphenation limits.** At most two consecutive hyphenated lines (`hyphenate-limit-lines: 2`, with the `-webkit-` form for Safari), and no hyphen in a word under six letters or leaving fewer than three letters either side of the break (`hyphenate-limit-chars: 6 3 3`). Firefox ignores these and falls back to its defaults, which is accepted. They matter most in tier S, where a ragged column at ~40 characters depends on hyphenation (TYPE-6) and a run of three hyphens in four lines was seen once it was working. *Added 2026-10-15 (evening).*
- **TYPE-5 (MUST — verify)** Spelling is Australian. `lang="en-AU"` is correct semantically, but test hyphenation in Chrome, Safari and Firefox; if any fails, use `en-GB` on the body container and document it. *Status 2026-10-12: passes in Chrome, Safari 26.6 and Firefox (104 and 157); Safari hyphenates ragged text more sparingly but has an `en-AU` dictionary. No `en-GB` fallback needed. Later found to be `text-wrap: pretty` suppressing hyphens, not the dictionary: see TYPE-6; verified on iOS 26 on 2026-10-15, hyphens returned the moment `pretty` was removed from tier S.*
- **TYPE-6 (SHOULD)** `text-wrap: pretty` for paragraphs **in the justified tiers only** (M and L), `balance` for headings; `hanging-punctuation: first` where supported. In tier S paragraphs use plain wrapping (`text-wrap: wrap`) with `hyphens: auto`: Safari 26 and iOS 26 implement `pretty` as whole-paragraph line breaking that trades hyphens for shorter lines, and on a 40-character ragged measure that suppressed hyphenation altogether and left a rag varying by a third of the line (seen on a phone, 2026-10-15; the "hyphenates ragged text more sparingly" note under TYPE-5 was this). A ragged narrow column is only as good as its hyphenation; `pretty` is never to be re-added there as a nicety. Verified on a phone the same evening: with `pretty` off, five hyphens on a screen and a rag varying by a word. *Revised 2026-10-15 (evening).*

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
- **THEME-5a (MUST) Keeping the place.** Changing the text size never moves the reader: the first line wholly visible at the top of the window (below the bar when it shows at the top) stays exactly where it was. The character starting that line is found before the change and scrolled back to the same height after, and again after the margin is rebuilt if the size change crosses a width tier. The adjusting scroll does not hide the bar. *Added 2026-10-14.*
- **THEME-5b (MUST) Everything scales.** The step applies to everything set in the text face: popups and popins, margin stubs and open items, the left-margin contents and the reading bar's contents list scale with the body and keep their ratio to it (aside and popup text stay ≈ 0.85×). Popups are therefore mounted inside the scaled wrapper, or the step is set on the root. Specimen check: open a popup, step the size, the popup text steps too. *Added 2026-10-15: popups did not scale.*
- **THEME-6 (MUST)** The theme control sits quietly at the top right of the header and is repeated in the reading bar (BAR-1), so it is within reach anywhere in an essay: an icon button with an accessible name, keyboard operable. The two stay in step.
- **THEME-7 (MUST) Specimen page** `/specimen`, excluded from feeds and indexes: every element the site can render — body text, intro paragraph, all heading levels, every mark (including a shared circle), the header in its margin and inline forms, with and without an abstract, an epigraph, asides and definitions (stub and expanded in place), margin notes, a note popup, a popup opened from inside a margin item, lists, breaks, quotes, figures, tables, TOC, and the reading bar. It is the test bed for colours, type size and grade, and the page to check after any CSS change. *Status 2026-10-14: listed on the home page for now (it has a `published` date and tags), so the table has rows to sort; delete its `published` line to unlist it. It stays out of search engines (`noindex`).*

### 10.5 Page furniture

- **LAYOUT-1 (MUST) Essay header.** Title, subtitle, dates (§13), tags, epistemic status, optional abstract. **Left-aligned and ragged right**, every line starting at the column's left edge; nothing on the page is centred except the section-break glyph (LAYOUT-4). The same holds for pages and the home page. *Revised 2026-10-15 (evening): was centred.* The header has two parts:
  - **In the column:** title, subtitle, abstract, the essay in reading order.
  - **In the right margin on tier L**, set as a margin note (MNOTE-2: aside size, ragged right) and **top-aligned with the first line of the abstract**, never with the title: the published date and the revised date, one per line; the tags; the epistemic status, italic. Nothing sits to the right of the title or subtitle; they have the page to themselves. When there is no abstract the block aligns with the first body paragraph instead. The margin's one job here is metadata about the essay. On narrower tiers the block falls back inline, as margin notes do (MNOTE-3), in the order title, subtitle, dates, tags, epistemic status, abstract; the build emits the inline form and CSS lifts it when wide. Stubs and figure words below are pushed clear of it (ASIDE-4). Pages have no dates or tags, so their margin block is empty.
  - **Dates** never break internally (no-wrap spans). In the margin they are one per line. Inline, a line may break only at the separator, and on tier S they are always on separate lines with no separator (seen breaking mid-date on a phone, 2026-10-15).
  - **Tags** are muted, separated by middle dots, each a link to the home page filtered by that tag (`/?tags=<tag>`, INDEX-3) with its → mark; no tags line when there are none.
  - **Epistemic status** keeps its one-sentence limit (§13): four or five margin lines at most.
  - **Space before the body.** Between the last line of the column header (the abstract, or the subtitle when there is none) and whatever follows (epigraph, no-JS contents, first paragraph) there are about three line-heights. *Open: whether the section-break glyph also sits there. Recommendation: space only, keeping LAYOUT-4's glyph author-placed; try the glyph on the specimen if the space alone feels thin.*
- **LAYOUT-2 (MUST) Headings.** Essay title: the text face, regular, **about 1.6em**, `text-wrap: balance`, so that a 60-character title fits in two lines at the measure (titles are often long, and left-aligned a large wrapping title looks worse than a centred one; set on 2026-10-15 evening, after the same day's rise to 2.6em, which is reversed). Subtitle: italic, about 1.15em. Level 1: the text face, right-aligned small caps with a full-width hairline rule beneath. Level 2: left-aligned, in the sans (LAYOUT-2a), semibold, smaller. Level 3: run in at the start of its paragraph, in the sans, semibold (was italic). *Revised 2026-10-15.*
- **LAYOUT-2a (MUST) Sans for the apparatus.** The system sans (`system-ui` and its fallbacks; no font file is served) sets level-2 and level-3 headings, figure and table titles (label and title, IMG-3), table column headings, popup and expanded-view titles, the bar's section name and the left-margin contents (TOC-2): semibold (column headings and the bar medium), ordinary case, lining figures. Everything else, including the essay title, level-1 headings, captions, credits, asides and notes, stays in Libertinus Serif. Chosen on the specimen from a trial, 2026-10-15. Where the system sans differs (San Francisco on Apple devices, Segoe UI on Windows, Roboto on Android), so does the look; that is accepted.
- **LAYOUT-3 (MUST) Intro paragraph.** The first paragraph after the abstract is marked `.intro`; its first line is small caps (`::first-line`) **in narrow tiers only**. With TYPE-3, rotating a phone changes both the small caps and the justification, as on gwern.net.
- **LAYOUT-4 (MUST) Section break.** `◊break{}` renders a centred glyph (SVG, `currentColor`, smaller variant when narrow), `role="separator"`, generous equal space above and below. Author-placed, never automatic. One glyph; no cycling.
- **LAYOUT-4a (MUST) Epigraph.** The whole epigraph is indented 1em from the column's left edge, left-aligned, ragged right, with **no first-line indent** inside it (the body's paragraph indent does not apply). The attribution (`#:source`) is right-aligned on its own line, as now. Italic text, roman attribution with its dash, as now. *Added 2026-10-15 (evening).*
- **LAYOUT-5 (SHOULD)** Print stylesheet: asides and notes become footnotes, and each note's **numeral is printed in the text** in place of its circle (paper has nothing to open); asides, being unnumbered, need a printed key of their own (symbols such as * † ‡, to settle with the print CSS in Phase 3); external URLs printed after their link text; arrows, circles for definitions, the bar and popups hidden.
- **LAYOUT-6 (MUST) Width tiers** (container queries, §10.6):

  | Tier | Condition | Margin | Column |
  |---|---|---|---|
  | XL / L | column + right margin fit | aside stubs + margin notes; opened notes and definitions | justified |
  | M | column fits at full measure | none; circles open popups | justified |
  | S | below full measure | none; circles open popins | ragged right |

- **LAYOUT-6b (MUST) Width alone decides the tier.** No media query for phones, pointer type or orientation may force a tier (LAYOUT-7). A phone in landscape at the default size has room for the full measure and is therefore tier M: justified, with popups; rotated back it is tier S again. Touch (`hover: none`) decides only what POP-5 and BAR-1 say it does. *Added 2026-10-15: landscape phones were being held at tier S.*
- **LAYOUT-6c (MUST) The right margin widens.** In tier L the margin is at least 13em and grows into spare room up to **20em**, keeping 3em clear at either side of the page; the column stays at the measure, and column and margins stay centred together. Stubs, margin notes and figure titles all take the margin's width. *Added 2026-10-15.*
- **LAYOUT-6a (MUST) Placement of the text block.** In tier L the column and its right margin are centred **together**, so the text sits left of the window's centre. This is intended and settled (2026-10-12): do not re-centre the column.

### 10.6 Layout mechanics

- **LAYOUT-7 (MUST)** Implement tiers as **container queries** on the page wrapper, not media queries: relative units in container queries resolve against the container's computed font size, so the layout stays right if the reader zooms or sets a larger default font. Verify in Safari, Chrome and Firefox. *Status 2026-10-12: verified in Chrome, Safari 26.6 and Firefox 157, tiers L and S in each. Firefox before 110 has no container queries and shows tier S at every width, which is an acceptable fallback.*

---

## 11. Popups

One popup component serves same-page links, cross-essay extracts, external link cards and **citation notes** at every width, and terms and asides on narrow tiers. On wide tiers asides and definitions open in the right margin instead (POP-8). To the reader a circle always does the same thing: it shows its content beside or over the text without moving the page.

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
- **POP-5 (MUST)** Touch devices (`(hover: none)`): tap opens a **popin** — a sheet anchored to the bottom, capped at ~60% of the viewport, with the same title bar; the page doesn't scroll behind it; swipe down or Close dismisses. On touch devices every control in the title bar (Close, Back, Open in new tab) has a hit area of at least 44 × 44 px, and the × is drawn at about 1.25em so it reads as tappable; desktop popups keep their smaller controls. *Target size added 2026-10-15.*
- **POP-6 (MUST)** Nesting is **out of scope in v1** (BACKLOG §2), with two exceptions. On wide tiers a circle inside an **open margin item** (a citation or term inside an aside; a term or a `see-also` inside a definition) opens a **popup** over the page, and the margin item stays open. Inside a popup or popin, a circle **replaces** the popup's content, with a Back control. *Revised 2026-10-15: margin items no longer replace their content.*
- **POP-7 (MUST)** Content by type: same-page link → the target section cloned from the DOM; cross-essay link → a build-time fragment `/_x/<slug>/<id>.frag` fetched on demand (not `.html`, which Cloudflare's HTML handling redirects) (prefetched on `pointerenter`); citation (a popup at every tier, including XL/L) → the reference, headed "Reference *n*" (no heading where unnumbered, CITE-7); under a short-form reference, also the work's full entry (a full reference already is complete, and repeating it reads as duplication); term → §6; aside → its text; external link → the card (§11.1 below). A shared circle (MARK-1c) shows its items in source order, separated by a hairline.
- **POP-8 (MUST) What opens where.** In tiers XL and L, **asides and definitions** live in the right margin as stubs that expand in place (ASIDE-3, TERM-3); **citations**, links and cards open as popups at every tier. In tiers M and S, asides and definitions open as popups or popins (POP-5) as well. A circle therefore always means "you stay here"; whether the content appears in the margin or over the page is told by the stub on the line, not by the mark (MARK-1b). The inputs in the table above govern popups; margin items open on click or Enter only (ASIDE-3). One margin item and one pinned popup may be open at the same time. *Revised 2026-10-15: notes no longer open in the margin, and margin items expand in place rather than overlaying; this supersedes the 2026-10-12 resolution of D7.*

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
4. Emit the end matter (CITE-10): Terms (following terms inside definitions), Asides, References, and the hidden store of full entries; the copies reuse the assigned numbers.
5. Resolve links and marks; compute ↑/↓.
6. Emit section extract fragments for cross-essay popups.

Glossary files take a shorter pass: paragraphs and typography only.

Site-wide:

- **VAL-1 (MUST)** The build fails on: unknown tag, unknown cite key, unknown term, broken internal link, duplicate id, missing required meta field, missing figure alt or licence, malformed list or table.
- **VAL-2 (MUST)** `tools/validate.rkt`, run after rendering, emits `data/anchors.json` (pages → sections) for validation and Emacs completion, and `data/links.json` (the internal link graph, and which pages mark each glossary term, for TERM-8) for backlinks, and checks every cross-page link (LINK-2).
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
| `◊epistemic{…}` (a tag, SRC-4a) | SHOULD | One sentence on confidence and what it rests on |
| `◊abstract{…}` (a tag, SRC-4a) | SHOULD | Header, cross-essay popups, feed |
| `tags` | MAY | Comma-separated lowercase words, on one line: `◊define-meta[tags]{philosophy, child development}` (INDEX-3); shown in the header (LAYOUT-1) |

- **REV-1 (MUST)** "Last revised" comes from the git log (latest commit touching the file, ignoring `[typo]`/`[meta]` commits), never typed by hand.
- **REV-2 (MUST)** Each essay's footer links to its source file and its history on GitHub.
- **REV-3 (MUST)** `◊changelog{…}` holds one line per substantive revision; `/changelog` aggregates them site-wide.
- **REV-4 (MUST)** RSS/Atom feed of new essays and substantive revisions.
- **MAIL-1 (MUST)** No comment system, contact form, newsletter or third-party embed of any kind.
- **ABOUT-1 (SHOULD)** The About page describes you as a **clinician-theoretician**, in deliberate contrast to clinician-researcher or clinician-academic, and says in a sentence or two why that distinction matters to the essays. The same phrase, not variations of it, is used wherever the site describes you.
- **MAIL-2 (MUST)** A `/correspondence` page gives the postal address and says what to expect: whether letters are read, whether replies are sent, whether letters may be quoted.
- **MAIL-3 (MUST)** The address lives once, in `data/site.rktd`, rendered from there; it is text, not an image.
- **MAIL-4 (SHOULD)** Each essay's footer ends with one line — *"Responses by post: see Correspondence"* — linking to that page, without printing the address.

### 13a. Home page and navigation

*Added 2026-10-14.*

- **INDEX-1 (MUST)** The root (`/`) is the index of essays: a short explanatory paragraph, a section break (LAYOUT-4), then a table with the columns **Title · Date published · Last review · Tags**, newest first. A page is listed when it has a `published` date and is not a draft, so essays always are and pages such as About and the colophon never are. Built from the pages' metas at render; `make` rebuilds the home page every time.
- **INDEX-2 (MUST)** "Last review" is the REV-1 date (git), or the publication date when the essay has not been revised since. Dates in the table are short (`9 Oct 2026`); on phones they may break before the year.
- **INDEX-3 (MUST)** The table sorts by its first three columns (TABLE-5's sorting, at any number of rows); Tags does not sort. Instead, clicking the **Tags heading** opens a drop-down of every tag (with its count) to tick any number of. The chosen tags form a **set**, shown above the table as chips that each remove their tag (with "clear" once there are two or more). A row shows when it has **every** tag in the set, so each tag narrows the list; when none has them all, a line says so. A tag inside a row adds itself to the set, or removes itself if already there. The set is kept in the address (`/?tags=philosophy,site`) so a filtered list can be linked to. Without scripts the heading is plain text and every essay shows. Tags are validated at build (lowercase words; a bad tag fails the build); `od-set-tags` (§16) offers the tags already in use. *Revised 2026-10-14: replaces a row of single-choice tags above the table.*
- **NAV-1 (MUST)** Every page has a menu at the top left: the site name with a drawn chevron opens a drop-down of **Home**, **About** and **Glossary** (TERM-8; the list lives once, in `pollen.rkt`). It is a `<details>` element, so it works without scripts; with them it also closes on Escape and on a click elsewhere. The current page is marked `aria-current`.
- **ABOUT-2 (MUST)** `/about` exists from 2026-10-14 with placeholder text, to be replaced (ABOUT-1).

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
| **2 — Interaction** | *Built 2026-10-12; awaiting the hand checks in "done when". Revised 2026-10-15 (margin items expand in place with a right rule, definitions get stubs, notes are popups at every tier, open circles stay filled: ASIDE-2…4, TERM-3, TERM-7, MNOTE-4, POP-5…8; plus THEME-5b, LAYOUT-6b, BAR-1, IMG-3a, TOC-2's current-entry mark; and, from the evening, the left-aligned header with its margin block, the smaller title, the epigraph, `text-wrap: pretty` confined to the justified tiers and the hyphenation limits: LAYOUT-1, LAYOUT-2, LAYOUT-4a, TYPE-6, TYPE-4a), to be rebuilt before the checks.* Carried over from Phase 1: the publish guard for `status` (DRAFT-2) and the essay meta checks, proved on a first test essay in `essays/`. Popup component; term, note, same-page, cross-essay and card popups; circles opening in the margin (POP-8); aside stubs and expansion; margin notes; reading bar with section, text size and theme (BAR-1, THEME-5); table sorting; image inversion. Opens with the **mark rework** left over from Phase 1: circles replace numerals and ≡, arrows enlarged, marks rebuilt so Safari draws them (MARK-1…1c), build walk and tests updated | The behaviour tables in §7, §11 pass by hand on desktop Safari/Chrome/Firefox and on iOS and Android |
| **2b — Interactive figures** | `◊embed` frame: lazy loading, fallback, sticky behaviour, theming, accessibility contract (§9.3); the first widget (mammal taxonomy) built in its own folder | The taxonomy figure loads lazily in an essay, falls back to its static image with JS off, and follows both themes |
| **3 — Around the essays** | Backlinks; changelog and `/changelog`; the glossary page (TERM-8); feed; correspondence page; Wayback saving and dead-link job; print CSS | Two essays that link to each other show correct backlinks; the feed validates |

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
| `od-set-tags` (`C-c o T`) | tags already used anywhere in the site (several, comma-separated) | Replaces or adds the `◊define-meta[tags]` line |
| `od-insert-ref` (`C-c o r`) | the figures and tables in the file, with their titles | `◊ref["id"]` (IMG-7) |

- **EMACS-1 (MUST)** A key inserts `◊` (`C-c ;`; the other commands are under `C-c o`). Also set one Option key back to macOS (`ns-right-alternate-modifier`/`mac-right-option-modifier` to `none`) so ⌥⇧V works everywhere.
- **EMACS-2 (MUST)** Commands wrap the active region when there is one.
- **EMACS-3 (MUST)** Glossary candidates are read **directly from `glossary/`** (not a build output), cached per session and invalidated by modification time, so a term created a minute ago is immediately available.
- **EMACS-4 (MUST)** `imenu` support for Pollen headings and an `outline-minor-mode` regexp, so sections fold and move like Org headings.
- **EMACS-5 (SHOULD)** Font-lock dims tag syntax (◊, brackets, keyword arguments) so prose dominates the buffer.
- **EMACS-6 (MUST) The major mode.** Since 2026-10-15 `occurrent-mode` is a major mode derived from `text-mode`, not a minor mode on `pollen-mode`. Its vocabulary, syntax, highlighting (errors the build would refuse are marked, with the reason in a tooltip), editing (filling, completion at point, unwrap, comments with `M-;`, Org's table editor inside `◊table`), the guide (`C-c o I`), checking (`C-c o k`) and publishing through Magit (`C-c o P`, `C-c o C`, `C-c o d`, with drafts kept out of git by `.git/info/exclude`) are specified in `HANDOVER-EMACS.md` under the IDs MODE, VOCAB, SYN, FL, EDIT, CHECK, PUB, DRAFT-E1, LOAD and TEST; that file is the detail, not repeated here. Tests: `make test-emacs` (ERT), and the VOCAB-3 sync test in `make test`.

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
| D7 | ~~Term popup placement~~ | **Resolved, revised 2026-10-15:** definitions and asides open in the right margin on wide tiers, as popups on narrow ones; notes are popups everywhere (POP-8) | n/a |
| D8 | ~~A shared circle without JS~~ | **Resolved:** it links to its first item; a term in the group keeps its own text linked to Terms (MARK-1c) | n/a |
| D9 | ~~Level-1 list bullet~~ | **Resolved:** a small solid dot, so a circle only ever means "opens something" (LIST-2) | n/a |
| D10 | ~~Cross-browser checks~~ | **Resolved:** the builder views Safari and Firefox on this Mac (read-only) and judges screenshots; real iOS and Android checks stay with Ryan | n/a |

Resolved already: Pollen markup over Markdown; sections never numbered; glossary site-wide, popup-only; numbered citation notes in Chicago style, with the number kept out of the running text; right margin only; no comments; no archived copies; Libertinus Serif as the typeface; two marks only, arrow and circle; a text-size control in the reading bar (reversing the earlier cut); the bar shows on scroll-up and hides after 2 s idle; the text block stays where it is (LAYOUT-6a).
