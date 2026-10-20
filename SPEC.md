# occurrentdevelopment.com — Specification (v1)

Status: draft 1.8 · Owner: Ryan · Last revised: 2026-10-20

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
├── references/<key>.pm        # optional commentary on a cited work (BIB-3); the page itself is generated
├── widgets/<name>/            # source of an interactive figure (§9.3); built by CI
├── pages/                     # about, colophon, specimen; later correspondence, changelog
├── refs/
│   ├── refs.bib               # cited entries only, written by `make refresh`; committed
│   └── chicago-notes-bibliography.csl   # CSL style (CC BY-SA 3.0); committed
├── data/
│   ├── cite-cache.json        # pandoc output, committed
│   ├── link-meta.json         # external link cards, committed
│   ├── invert.json            # dark-mode image classification, committed
│   ├── site.rktd              # postal address, repository URL and branch, site metadata
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
◊cite["oyama2000" #:loc "p. 42"]. ◊margin{Where canalisation comes in} I return to this in
◊link["#canalisation"]{the section on canalisation}, and it extends
◊link["/kawasaki-genealogy#referents"]{an earlier essay}. See also
◊link["https://plato.stanford.edu/entries/process-philosophy/" #:note "Standard
overview; good on Whitehead's debt to Bergson."]{the SEP entry}. The prospect of a
◊aside["finalised product"]{Not an immutable one: I may return to an essay with
revisions.} is what gets an essay finished.

◊break{}

◊section[#:id "canalisation" #:short "Canalisation"]{Canalisation and its limits}
```

Citation keys are Better BibTeX keys from Zotero (`hackingMakingPeople2006`); the short keys above are illustrative. The second `◊margin` shows a note anchored to a sentence inside a paragraph (MNOTE-6). The second `◊aside` shows the phrase form (ASIDE-8): the phrase is a string in the brackets, so a phrase containing quotation marks is written `◊aside["finalised \"product\""]{…}` or with typographic quotes typed directly; bare words in the brackets are read as Racket and fail the build.

### 3.3 Tag vocabulary

| Tag | Purpose | Required | Optional |
|---|---|---|---|
| `◊link[target]{text}` | Any link; type inferred (§4.2) | target | `#:note`, `#:title`, `#:author`, `#:date` |
| `◊cite[key]` | Citation → numbered note (§5) | BibTeX key | `#:loc`, `#:note` |
| `◊term[id]{text}` | Glossary term (§6) | glossary id | `#:mark` |
| `◊aside{…}` / `◊aside[phrase]{…}` | Aside (§7.1); with a phrase, the phrase and the circle are the link (ASIDE-8) | body | phrase (a string) |
| `◊margin{…}` | Margin note, left margin (§7.2) | body | — |
| `◊section` `◊subsection` `◊subsubsection` `[#:id]{title}` | Heading markers (§8) | title, id | `#:short` |
| `◊summary{…}` | One-line section summary for popups | body | — |
| `◊more{…}` | Long text of a glossary definition (§6); glossary files only | body | — |
| `◊list{…}` | Lists (§3.4) | body | `#:start`, `#:columns` |
| `◊table{…}` / `◊table-csv[path]` | Tables (§9.2) | body / path, `#:id`, `#:title` | `#:caption`, `#:source`, `#:size`, `#:sortable`, `#:align`, `#:row-headers` |
| `◊sort-key[value]{text}` | The value a table cell sorts by (TABLE-5) | value | — |
| `◊figure[src]{caption}` | Image (§9.1) | src, `#:id`, `#:title`, `#:alt`, `#:licence` | `#:invert`, `#:credit` |
| `◊ref[id]` | "Figure 2", "Table 1": a link to a figure or table on the page (IMG-7) | id | |
| `◊embed[name]{caption}` | Interactive figure (§9.3) | name, `#:alt`, `#:fallback` | `#:width`, `#:sticky` |
| `◊break{}` | Section-break glyph (§10.5) | — | — |
| `◊sc{…}` | Small caps (acronyms) | body | — |
| `◊latex{}` | The LaTeX logo, set in the text face (TYPE-17) | — | — |
| `◊m{…}` | Inline mathematics, pre-rendered at refresh (MATH-1); **Phase 3** | TeX source | `#:display` |
| `◊epigraph{…}` | Epigraph, italic by default (LAYOUT-4a) | body | `#:source`, `#:italic` |
| `◊blockquote{…}` | Block quotation, roman by default (LAYOUT-4b) | body | `#:italic` |
| `◊anchor[id]`, `◊em`, `◊strong`, `◊code`, `◊br{}` | Standard elements | | |
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
- **LIST-7 (MUST)** Inline tags work inside items, `◊margin` at the start of an item included (MNOTE-6); lists expand before the numbering walk (§12). List text is ragged right even where body text is justified. Bad indentation or an unknown marker is a build error.

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
- **MARK-3b (MUST)** When the word before a mark ends an inline phrase (`◊em{London Review of Books}`), only the phrase's last word is bound to the mark, so the rest of the phrase can still wrap. The same holds for the phrase of a phrase-form aside (ASIDE-8). *Added 2026-10-14; aside phrases 2026-10-19.*
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

Citations are **numbered notes**, collected in a **Notes** section at the foot of the essay. The number belongs to the note, not to the text: in the text a citation is a circle (§4.1), and no numeral is printed there. With JS, opening the circle shows the note, headed with its number ("Note 3"), in a popup at every tier (§11; notes never occupy the margin, POP-8); without JS the circle is a link to the note.

- **CITE-1 (MUST)** Notes are numbered per essay in **source reading order**, including citations inside asides. An aside sits in the source right after its circle, so its citations are numbered at that point in the argument. The number appears in the Notes list, in the opened note's heading and in print (LAYOUT-5); never as a superscript on screen.
- **CITE-2 (MUST)** Numbering happens **once**, in a single document-order walk in the `root` pass, **before** asides are duplicated for the no-JS endnote copies. The copies reuse their numbers. Getting this wrong double-counts asides; CITE-8 tests it.
- **CITE-3 (MUST)** Each `◊cite` gets its own number. The first note for a work gives the full reference; later notes the short form. No *ibid.*
- **CITE-4 (MUST)** Each note has a ↩ back-link to its mark. If the mark is inside an aside, the back-link scrolls to the aside (expanding it on wide screens, opening its popup on narrow ones).
- **CITE-5 (MUST)** Formatting is not done in Racket. `tools/refs.py` (`make refresh`) runs `pandoc --citeproc` with a *note* CSL style and stores, for every key **and every locator the sources use with it**, the full and short note, plus the bibliography entry and DOI/URL, in `data/cite-cache.json`. Racket only picks first vs later. Letting pandoc place the locator gets Chicago punctuation right (`“Making Up People,” 23.`, `What?, 31–34.`); a new locator therefore needs a `make refresh`, and the build says so. No abstracts are stored or shown (§11.1 policy); `refs.bib` never carries abstracts, notes, keywords or file paths.
- **CITE-6 (SHOULD)** Style: **Chicago notes and bibliography**.
- **CITE-7 (MUST)** Citations outside the essay's own sequence — inside glossary definitions or cross-essay extracts — are **unnumbered**. They carry the same circle and open the reference; they have no entry in the essay's Notes.
- **CITE-8 (MUST)** Test fixture: an essay with citations in body text, in several asides, repeats of one work, and a term whose definition cites something. Expected numbering, forms and back-links are asserted.
- **CITE-9 (MUST)** An unknown key, or a key and locator missing from the cache, fails the build with a message to run `make refresh`.
- **CITE-10 (MUST)** End matter order: **Terms** (no-JS only) · **Asides** (no-JS only) · **Notes** · **Bibliography** · **Backlinks** · **Changelog**. The per-essay Bibliography stays once the site-wide one exists (BIB-4): an essay is complete without the rest of the site. The specimen's sentence "There is no separate bibliography" contradicts this and is to be corrected.

### 5a. Reference pages

*Added 2026-10-20. Phase 3.* Every cited work gets a page of its own, as glossary terms have an entry; unlike a definition, a reference page can be visited. It is generated, not written: the bibliographic data is already in the cache (CITE-5), and the citing contexts come from the same pre-pass as backlinks (VAL-4). A commentary file is optional and rare.

- **BIB-1 (MUST) A page per work.** `/references/<key>`, generated at render for every key in `data/cite-cache.json`, so for every work a published page cites. It holds, in order: the full bibliography entry (Chicago, from the cache); the DOI and URL as external links with their ↗ marks, and the Wayback copy where one is recorded (CARD-3); **Cited in**, listing each citing essay and section with the citing sentence as context, collapsed to ~2 lines and expandable, exactly as Backlinks are (VAL-4); and the commentary (BIB-3) when there is one. No abstracts and no publisher text (§11.1); facts only, plus your own words.
- **BIB-2 (MUST) The key is the URL.** The Better BibTeX key, verbatim and case-preserved (`/references/hackingMakingPeople2006`). A published reference page is a promise like a section anchor (VAL-3), so every cited key is **pinned** in Zotero (right-click → Better BibTeX → Pin BibTeX key, which writes `Citation Key:` into Extra) and never regenerated. The `.bib` export cannot show whether a key is pinned, so the check lives in Emacs: `od-insert-cite` asks Better BibTeX over its JSON-RPC endpoint (`localhost:23119`) when Zotero is running and refuses an unpinned key with a one-line message; when it cannot ask, it warns and continues. CITE-9 and VAL-3 remain the guards at build time: a key that vanishes from the cache, or a page that vanishes while anything links to it, fails the build.
- **BIB-3 (MAY) Commentary.** `references/<key>.pm`: Pollen, no `.html` in the name, the same shape as a glossary file. Paragraphs only; `◊term`, `◊link`, `◊em`, `◊sc` and `◊cite` are allowed (citations here are unnumbered, CITE-7); headings, figures, tables, asides and margin notes are a build error. A file whose key is not in the cache fails the build. Most works never get one. Emacs: `od-new-reference` (`C-c o R`) creates the file for the key at point or a picked key, and `od-file-kind` gains `reference`.
- **BIB-4 (MUST) The bibliography page.** `/bibliography`, in the site menu beside Glossary (NAV-1), built at render from the cache and the link graph: one sortable `◊table` through the shared table code (INDEX-1a), columns **Author · Year · Title · Type · Cited in**, sorted by author then year by default, the title linking to the work's page, Cited in a count. Not listed on the home page. Like the glossary page, it is rebuilt whenever anything is rebuilt; the project server may show it stale until `make` runs (BUILD-4).
- **BIB-5 (MUST) Nothing changes in the text.** A `◊cite` circle still opens its note where the reader is (MARK-1b); it never navigates. The note popup's title becomes a link to the reference page, and its **Open in new tab** (POP-1) goes there rather than to the publisher. In the per-essay Notes and Bibliography each work links to its page with a → mark; without JS those links are how the page is reached.
- **BIB-6 (MUST) One pre-pass.** The VAL-4 walk records every `◊cite` with its context alongside every internal link, and `data/links.json` carries cites per key as it carries links per page. Reference pages, Cited in, Backlinks and the glossary's Used in all read that one file; nothing walks the essays twice.

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

Two margins, two jobs. The **right margin** holds the apparatus that opens: aside and definition stubs, with figure words and the header's metadata block. The **left margin** holds margin notes, the signposts, right-aligned against the column. Beyond the left margin, at the window's edge, sit the contents (TOC-2). *Settled 2026-10-19.*

### 7.1 Asides

| Tier | Rendering |
|---|---|
| Wide (XL, L) | **Collapsed stub** in the right margin, always visible, top-aligned with the line holding its circle; click to expand in place (ASIDE-3) |
| Narrow (M, S) | The circle opens the aside as a popup/popin |
| No JS | Asides are collected in an **Asides** list at the end, in source order, each with a ↩ return link; the circle links to its entry |

- **ASIDE-1 (MUST)** Source position is canonical: the build emits each aside inline, right after its circle (hidden until JS lifts it into the margin), and a separate no-JS copy in the Asides list, hidden when JS runs.
- **ASIDE-2 (MUST)** Asides are **not numbered**: no roman numerals, in the text, the stub or the popup. An aside is tied to its circle by position (the stub sits on the circle's line); when either is hovered or focused both take the accent; and **while the aside is open its circle is filled**, whatever the pointer does, until it closes. The same holds for definitions and for a circle whose popup is pinned. *Revised 2026-10-15: the fill no longer follows hover.*
- **ASIDE-3 (MUST) Stubs that expand in place.** In wide tiers an aside starts as one margin line: its opening words, cut with an ellipsis, with a **hairline vertical rule** (`--rule`) on the right edge of the margin, one line tall. Definitions have the same stub (TERM-3); the right margin holds nothing else but figure words (IMG-3) and the header's metadata block (LAYOUT-1). The margin is a fixed width, so every rule falls on the same vertical line down the page. *Revised 2026-10-15: replaces the boxed overlay; definitions now have stubs too. 2026-10-19: margin notes moved to the left margin (§7.2).*
  - Clicking the circle or the stub, or Enter on either, **expands the stub itself**: the same text grows downward in place and the rule grows with it. No box, no background, no horizontal rules (they would clash with the rules under headings). Whatever is below in the right margin, stubs and figure words alike, **moves down** to make room and returns when the item closes; the column never moves, and neither does the left margin. Click again, Esc, or opening another collapses it. One margin item is open at a time.
  - **Hover never opens a margin item**: opening reflows the margin, and a pointer crossing circles would make it jump. Hover only pairs circle and stub by colour (ASIDE-2). Popups keep their hover behaviour (§11).
  - An aside or definition that fits in two margin lines is shown in full and never collapses; its rule is two lines tall.
  - Circles and stubs are focusable; `aria-expanded` is set.
- **ASIDE-4 (MUST)** Collisions: stubs are one line, so overlap is rare. When two would overlap, the later moves down just enough to clear; an open item pushes everything below it (ASIDE-3). Right-margin items collide only with each other; the left margin reflows on its own (MNOTE-4). Recalculate on resize, after fonts load, and whenever an item opens or closes.
- **ASIDE-5 (MUST)** Asides use the **right margin only**. The left margin holds margin notes (§7.2); the contents lie beyond it, at the window's edge (TOC-2). *Revised 2026-10-19: the left margin was reserved.*
- **ASIDE-6 (SHOULD)** Aside size ≈ 0.85 × body, ragged right, never justified.
- **ASIDE-7 (MUST)** Asides may contain links, citations and terms, which behave normally.
- **ASIDE-8 (MUST) The phrase form.** `◊aside` takes an optional positional string, the phrase the aside comments on: `◊aside["finalised product"]{…}`. The phrase is printed in the text where the tag stands, followed by its circle, and **phrase and circle together are one link**, exactly as a link's text and arrow are (MARK-6): one hit area, both taking the accent on hover or focus, both filled or highlighted while the aside is open (ASIDE-2), one accessible name. Without a phrase the tag prints only the circle, as before, and the two forms are otherwise identical: same stub, same popup, same no-JS entry, same numbering walk for any citations inside. The phrase is plain text in the body colour and weight, never underlined or coloured at rest (MARK-4, MARK-5); it may carry `◊em` and `◊sc` but no links, cites, terms or nested asides, which is a build error. MARK-3a and MARK-3b apply: trailing punctuation moves between the phrase's last word and the circle, and only that last word is bound to the mark. The phrase form exists because a circle alone says "there is an aside here" but not what it is about; it is for asides that qualify a specific phrase, and the style guide (§17) says when to use it. *Added 2026-10-19.*

### 7.2 Margin notes

A margin note is a short unnumbered gloss — a signpost for a skimming reader — on the passage beside it. It is written where it belongs, so it can be placed precisely: at the start of a paragraph, of a list item, of a quoted paragraph, or of a sentence inside a paragraph (MNOTE-6). *Revised 2026-10-19: was a gloss on a whole paragraph, written only at its start, and sat in the right margin.*

- **MNOTE-1 (MUST)** No marker, not interactive, so no mark.
- **MNOTE-2 (MUST)** Wide tiers (L, XL): the **left margin**, **right-aligned** so the words sit close to the column, ragged left; its right edge `--margin-gap` from the column's left edge, the same gap the stubs keep on the right (LAYOUT-6c). Italic, aside size, no rule, no marker; hyphenation off (`hyphens: manual`; the notes are too short to hyphenate well); not repeated in the text. Top-aligned with the **line holding its anchor**: the first line of the paragraph, item or quoted paragraph it opens, or the line on which the sentence it opens begins. *Revised 2026-10-19.*
- **MNOTE-3 (MUST)** Narrow tiers (M, S) and no-JS: an inline italic run-in **at the anchor**, exactly where it was written, followed by one space; inside a list item it comes after the marker. The build emits the inline form as an inline element at the anchor and never lifts it to the paragraph's start; JS lifts it into the margin when wide, positioning it from the anchor's line box in the same pass that places stubs from their circles (ASIDE-3). CSS alone cannot place it: which line a sentence starts on is only known at layout. *Revised 2026-10-19.*
- **MNOTE-4 (MUST)** The left margin is its own column: margin notes collide only with each other. Nothing in the right margin pushes them, and opening an aside or a definition never moves them. When two notes would overlap, the later moves down just enough to clear. Recalculate on resize, after fonts load, and on a text-size change. *Revised 2026-10-19.*
- **MNOTE-5 (SHOULD)** ≤ ~8 words; warn above 12. Inline emphasis only: no links, cites, terms or asides.
- **MNOTE-6 (MUST) Anchors.** `◊margin` may stand in four places: (a) first in a paragraph; (b) first in a list item at any depth, after the marker; (c) first in a paragraph of a `◊blockquote` or `◊epigraph`; (d) anywhere inside a paragraph or item where a **sentence begins**: the previous non-whitespace character is `.`, `!`, `?` or `…`, or a closing quote or bracket that follows one of those, or the previous element is `◊br{}`. Anywhere else is a build error: `◊margin must open a paragraph, a list item or a sentence`. The old check, `◊margin must open its paragraph`, is replaced; it rejected (b) because lists expand before the `root` pass and an item is not a paragraph (seen 2026-10-19 in `pages/about.html.pm`). The build normalises the whitespace around a note: none before the run-in form at a block start, one space before it at a sentence start, one after. Never inside an aside, a definition, a caption, a heading, a table or `◊summary`; two notes at one anchor is an error. *Added 2026-10-19.*
  - **A note must gloss something.** A `◊margin` followed by nothing but whitespace before its paragraph, item or quoted paragraph ends is a build error: `◊margin glosses nothing: move it to the start of the item or sentence`. Rule (d) as written admits it (the previous character is a full stop), but no sentence begins there, and the note then aligns with the block's **last** line rather than its first. Seen 2026-10-20: `…cognitive resources.◊margin{Inexhaustive list of why I write}` at the end of item 1 of a numbered list, which sat beside the item's second line; the author wanted the first line, which is anchor (b): `1. ◊margin{…}Getting a thought…`. The highlighter flags the misplacement (FL-6) and `od-insert-margin` warns when point is at the end of a block. *Added 2026-10-20.*

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
- **TOC-2 (MUST) Where the contents show.** With scripts, the contents are never in the text. When the window has room (tier XL), they sit at the **far left of the window, flush with its edge**: a column 11em wide with a 1.5em gutter from the edge, outside the text block and no part of its centring, its "Contents" label on the title's first baseline (LAYOUT-1a) and **staying in view** as the reader scrolls (sticky). Set compactly in the system sans, smaller, with every entry in the muted colour except the **current section and subsection**, in the text colour. Otherwise they open only from the section name in the reading bar (BAR-1). *Revised 2026-10-19: moved from a left margin beside the column to the window's edge; the left margin now holds margin notes (MNOTE-2). The scrolling, truncation and current-entry mechanics below are unchanged.*
  - **Order of loss.** As the window narrows, the **contents go first**, then both margins together: contents, margins and column (tier XL); both margins and the column (tier L); the column alone at full measure, with asides, definitions and notes as popups and margin notes inline (tier M); below the measure, tier S. The thresholds follow from the widths in LAYOUT-6c; the builder records them on the specimen page and in the colophon. *Reversed 2026-10-19 (the right margin used to go first): the contents have a good fallback in the bar; the margins have only the inline one.* Built with an outer container (`.frame`) that decides whether the contents fit, reserves their width at the window's left edge, and centres the text block in what remains, so the tiers of LAYOUT-6 see only the width left over. Pages without contents keep LAYOUT-6 unchanged.
  - **Too tall:** the list scrolls on its own (the "Contents" label stays), and when the current section changes it scrolls so that section is at its top, with what is left to read below; near the end it stops at the bottom of the list. The reader can scroll it back to see what they have read.
  - **Too wide:** an entry longer than the column ends in an ellipsis; hovering or focusing it shows the whole title over the gap.
  - **Current entry (SHOULD).** Colour alone does not make the current entry findable at a glance (seen 2026-10-15), so a short hairline in the gutter to the left of the current entry marks it: `--rule`, one line tall, about 1em long, beside the deepest current entry (the subsection when the reader is in one, otherwise the section), moving with it as the reader scrolls; under `prefers-reduced-motion` it jumps rather than slides. Nothing else changes: no accent colour, no change of weight, no reflow.
  *Revised 2026-10-14; current-entry mark added 2026-10-15; placement revised 2026-10-19.*
- **BAR-1 (MUST)** **Reading bar**: a slim bar fixed to the top of the viewport on pointer devices, and to the **bottom on touch devices** (`hover: none`, the test POP-5 uses), whatever the tier, so rotating a phone never moves it; at the bottom it sits above the home-indicator inset. *Revised 2026-10-15: was tied to tier S.* It overlays the page (it never pushes content, so no layout shift). It holds, left to right: the **current top-level section** (`#:short`; the essay title before the first section), truncated with an ellipsis when narrow; the **text-size control** (THEME-5); the **theme control** (THEME-6), as a button in the bar, not inside a menu. Tapping the section name opens the full TOC as a popup/popin with the current section marked.
- **BAR-1a (MUST) When it shows.** The bar appears when the reader **scrolls up**, once the site header has left the viewport, and hides again on **scrolling down** or after **2 seconds without scrolling**. Scrolling down never summons it, so it does not flicker while someone reads down a page. *Revised 2026-10-14: scrolling down now hides it at once.* It stays while the pointer is over it, while keyboard focus is inside it, and while its TOC is open; the 2 seconds start when those end. Tabbing into it reveals it, so it is reachable without scrolling. Under `prefers-reduced-motion` it appears and disappears without animation.
- **BAR-1b (MUST) Mechanics.** The current section is tracked with IntersectionObserver. Showing and hiding needs scroll direction and an idle timer: one passive scroll listener (or `scrollend` where supported) that toggles a class and restarts a timer, and does nothing else — no layout reads, no per-frame work.
- **BAR-1d (MUST) Width and alignment.** The bar is as wide as the **text block** (LAYOUT-6a): left margin, column and right margin in tiers L and XL, the column alone in M and S; it never covers the contents column in XL, which stays readable beside it. Its hairline runs that full width. The section name starts at the **column's left edge** and the controls end at the **column's right edge**, so the bar's contents line up with the text below them and with the right-aligned level-1 headings. Because the bar is fixed to the viewport, its left edge and width are set from the text block's measured position (the `.frame` layout, TOC-2) and recomputed on resize and on a text-size change; CSS alone cannot know where the block landed. Seen 2026-10-20: the rule ran to neither the column's width nor the block's, and the controls sat in the middle of the page. *Added 2026-10-20.*
- **BAR-1c (MUST)** Without JS there is no bar; the header's controls need JS as well, and the page follows the system theme and the browser's own zoom.
- **BAR-2 (MUST)** Navigating from the TOC or bar pushes a history entry, so Back returns the reader to where they were.

---

## 9. Figures and tables

### 9.1 Figures

- **IMG-1 (MUST)** Build pipeline (`tools/images.py`: Pillow for resizing, WebP and the JPEG/PNG fallback; `avifenc` for AVIF): variants at 480–2400 px, never above the source, with `srcset`/`sizes` and explicit `width`/`height` (no layout shift). The first figure loads eagerly; the rest use `loading="lazy"` and `decoding="async"`. Sources in `img/`; variants not committed; warn above ~2 MB. SVG sources are inlined (IMG-5).
- **IMG-2 (MUST)** Every figure and table is **column width**; nothing but its words enters a margin. `#:width` is a build error. A reader who wants one larger uses Expand (IMG-8). *Revised 2026-10-15: `wide` and `full` are retired.*
- **IMG-3 (MUST)** Every figure and table has a **label and title** ("Figure 1  The continuant and the occurrent": label and title together in semibold, so they stand apart from the caption, the label with an ordinary capital and lining figures (as in `◊ref` and in a popup's title, which for figures and tables is not in small caps), one line, wrapping as needed; revised 2026-10-15), an optional **caption** and a **credit** where there is one, all at aside size, ragged right. Where they go depends on the tier: in **tiers L and XL** all three sit in the **right margin**, top-aligned with the figure, title first, then caption, then credit; the caption takes no height in the column, so a long one runs on down the margin, and stubs fit around these words (ASIDE-4). In **narrower tiers** the label and title sit above the figure, the caption and credit below. Captions may contain cites, links and terms; a term there opens a popup (it is already in the margin). *Revised 2026-10-15, from Ryan's sketches.* `#:alt` is required; a missing alt fails the build; `#:alt ""` marks a decorative image.
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
- **TYPE-4a (SHOULD) Hyphenation limits.** At most two consecutive hyphenated lines (`hyphenate-limit-lines: 2`, with the `-webkit-` form for Safari), and no hyphen in a word under six letters or leaving fewer than three letters either side of the break (`hyphenate-limit-chars: 6 3 3`). Firefox ignores these and falls back to its defaults, which is accepted. They matter most in tier S, where a ragged column at ~40 characters depends on hyphenation (TYPE-6) and a run of three hyphens in four lines was seen once it was working. *Added 2026-10-15 (evening).* See `COMPAT.md` for the property names each browser actually needs.
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
- **TYPE-16 (MUST) Quotation marks.** The author types straight quotes; the build curls them, everywhere in prose. The direction of each `"` and `'` is decided from the characters either side of it **in the paragraph's text read in document order, across inline tags**: a quote after a letter, digit or closing punctuation (`. , ; : ! ? ) ] ”`) closes; one before a letter, digit or opening punctuation (`( [ “`) opens; one between letters is an apostrophe; one before a digit at a word start (`'90s`) is an apostrophe. Pollen's `smart-quotes` runs on one string at a time and cannot see past a tag, so `finalised "product"◊aside{…}`, `◊em{"word"}` and the phrase of a phrase-form aside (ASIDE-8) each leave a straight quote at the run's edge (seen 2026-10-20: `finalised “product"`). The build therefore replaces it with a pre-pass in `typography.rkt` that walks the paragraph's text nodes with their neighbours in view, or an equivalent that gives each quote its context; the rule runs on the phrase of `◊aside[…]` and the `#:source` of `◊epigraph` as well as on bodies. A straight `"` or `'` surviving into rendered prose (outside `code` and `pre`) **fails the build**, so the defect cannot recur silently. Tests (TYPE-14): the three cases above, `don't`, `'tis`, `'90s`, a quotation inside a quotation, a quote at the start and at the end of a paragraph, and one followed by a `◊cite` whose punctuation MARK-3a has moved. Typographic quotes typed directly are left alone, and the `\"` escaping shown in §3.2 remains for the rare phrase that needs it. *Added 2026-10-20.*
- **TYPE-17 (MUST) The LaTeX logo.** `◊latex{}` prints the logo as letters from the text face, never as an image or a different font: `L`, a raised and reduced small-cap `A`, `T`, a lowered `E`, `X`, with the usual kerning (the `A` tucked under the `L`'s arm, the `E` under the `T`'s), in CSS on a `<span class="latex">` with `aria-label="LaTeX"` so a screen reader says the word. It inherits size, weight and style, so it works in a heading, an aside and italic alike. Empty-body tag (`◊latex{}` like `◊br{}`); a body is a build error. Specimen (THEME-7): once in body text, once in italic, once in an aside. *Added 2026-10-20.*

### 10.3a Mathematics

- **MATH-1 (MUST, Phase 3) Inline mathematics.** `◊m{…}` takes TeX source and prints it **pre-rendered**: no maths engine reaches the reader (principles 3 and 5). The rendering is done at `make refresh` by a real TeX engine so that the maths is set in **Libertinus Math**, the text face's own companion (TYPE-7): LuaLaTeX with `unicode-math` and `dvisvgm`, one small document per distinct source string, the result an SVG in `currentColor` (IMG-5) so it follows the theme, with its baseline offset recorded so it sits on the text line (MARK-2's test applies: a line with maths is no taller than one without, for ordinary inline expressions). Output is cached in `data/math-cache.json` keyed by the SHA-256 of the source, committed, and inlined at build; a source missing from the cache fails the build with a message to run `make refresh` (as CITE-9 does). `#:display #t` sets the expression on its own line, centred, the one case besides the section-break glyph and the header rule where something is centred (LAYOUT-1). The build inlines the SVG only on pages that use `◊m`. KaTeX and MathJax are rejected, for the record: both set maths in their own faces beside Libertinus, and the site's claim is that the type is right. TeX becomes a dependency of `make refresh` only, on your Mac and in the CI job that runs it; `make` itself stays offline and TeX-free (BUILD-2). Emacs: `od-insert-math` (`C-c o $`), wrapping the region. *Added 2026-10-20; the logo alone (TYPE-17) needs none of this and is in Phase 2.*

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
- **THEME-5b (MUST) Everything scales.** The step applies to everything set in the text face: popups and popins, margin stubs and open items, margin notes, the contents column and the reading bar's contents list scale with the body and keep their ratio to it (aside and popup text stay ≈ 0.85×). Popups are therefore mounted inside the scaled wrapper, or the step is set on the root. Specimen check: open a popup, step the size, the popup text steps too. *Added 2026-10-15: popups did not scale.*
- **THEME-6 (MUST)** The theme control sits quietly at the top right of the header and is repeated in the reading bar (BAR-1), so it is within reach anywhere in an essay: an icon button with an accessible name, keyboard operable. The two stay in step.
- **THEME-7 (MUST) Specimen page** `/specimen`, excluded from feeds and indexes: every element the site can render — body text, intro paragraph, all heading levels, every mark (including a shared circle), the header in its margin and inline forms, with and without an abstract, an epigraph and a block quotation in both styles with `◊em` inside each (LAYOUT-4c), asides and definitions (stub and expanded in place), margin notes at every anchor MNOTE-6 allows (a paragraph, a list item, a quoted paragraph, a sentence inside a paragraph, with two close enough to collide), a note popup, a popup opened from inside a margin item, lists, breaks, figures, tables, the contents at the window's edge and in the bar, and the reading bar. It is the test bed for colours, type size and grade, and the page to check after any CSS change. *Status 2026-10-14: listed on the home page for now (it has a `published` date and tags), so the table has rows to sort; delete its `published` line to unlist it. It stays out of search engines (`noindex`).*

### 10.5 Page furniture

- **LAYOUT-1 (MUST) Essay header.** Title, subtitle, dates (§13), tags, epistemic status, optional abstract. **Left-aligned and ragged right**, every line starting at the column's left edge; nothing on the page is centred except the section-break glyph (LAYOUT-4). The same holds for pages and the home page. *Revised 2026-10-15 (evening): was centred.* The header has two parts:
  - **In the column:** title, subtitle, abstract, the essay in reading order.
  - **In the right margin on tiers L and XL**, at aside size, left-aligned and ragged right like figure words (IMG-3), with its first baseline on the **title's first baseline** (LAYOUT-1a), in this order: the published date and the revised date, one per line; the tags (LAYOUT-1b); the source links (REV-2); then, after a **gap of 1em**, the epistemic status, italic, when there is one. The gap is what separates the one line of prose from the lines of facts above it. It stays in the right margin although margin notes have moved to the left (D11). The margin's one job here is metadata about the essay. On narrower tiers the block falls back inline, as margin notes do (MNOTE-3), in the order title, subtitle, dates, tags, source links, epistemic status, abstract; the build emits the inline form and CSS lifts it when wide. Stubs and figure words below are pushed clear of it (ASIDE-4). Pages have no dates or tags, so their margin block holds only the source links. *Revised 2026-10-20: the block was aligned with the abstract, with nothing beside the title, and the epistemic line sat between the tags and the source links.*
  - **Dates** never break internally (no-wrap spans). In the margin they are one per line. Inline, a line may break only at the separator, and on tier S they are always on separate lines with no separator (seen breaking mid-date on a phone, 2026-10-15).
  - **Epistemic status** is **optional** (§13) and keeps its one-sentence limit: four or five margin lines at most. No gap and no line when there is none.
  - **Source links** (REV-2) follow the tags, on one line in the muted colour: **Source** · **History**, each an external link with its ↗ mark, to the essay's `.html.pm` on GitHub and to its commit history. Nothing is typed in the essay: the build derives both from the file's path in the repository and the repository URL, which lives once in `data/site.rktd` beside the postal address (`repo`, the `https://github.com/<owner>/<name>` form, and `branch`, `main`). Pages (About, the colophon) get the same two links; it is the only thing in their margin block. *Added 2026-10-19.*
- **LAYOUT-1a (MUST) One datum across the page.** In tier XL three things start at the top of the page in three columns: the contents (TOC-2), the title, and the metadata block. They share **one baseline, the title's first**: the "Contents" label, the first line of the title and the "Published" line all sit on it, whatever their sizes. Tops of boxes are not aligned, baselines are; aligning tops leaves three different heights, which is what was seen on 2026-10-20 (the contents label, the title and the metadata each began somewhere of their own). In tier L the same holds for the title and the metadata block. *Added 2026-10-20.*
- **LAYOUT-1b (MUST) The tags line is labelled.** Bare tags in the margin read as nothing in particular (seen 2026-10-20: `site · typography` under two dates). The line is **Tagged** site · typography: the label set exactly as "Published" and "Revised" are, the tags muted, separated by middle dots, each a link to the home page filtered by that tag (`/?tags=<tag>`, INDEX-3) with its → mark; no line when there are none. "Tagged" rather than "Tags:" so that the three lines read alike, as participles without colons; if the dates ever gain colons, so does this. *Added 2026-10-20.*
- **LAYOUT-1c (MUST) The end of the header.** The column header is closed by a **short hairline rule**: `--rule`, about 4em long (tune on the specimen), flush with the column's left edge, emitted by the build after the abstract (or after the subtitle when there is no abstract) and before whatever follows (epigraph, no-JS contents, first paragraph). The three line-heights of space that were there already are split evenly around it. A rule, not a glyph, because rules are already the sign that a section opens (LAYOUT-2's level-1 rule) and the section-break glyph already means "a pause in the argument"; a second glyph would be a second thing for readers to learn, and the one centred thing on the page besides the break (LAYOUT-1). Never authored; `◊break{}` after the abstract is therefore a style error (§17). *Added 2026-10-20; replaces the open item on the space before the body. A header glyph of its own remains possible: D12.*
- **LAYOUT-2 (MUST) Headings.** Essay title: the text face, regular, **about 1.6em**, `text-wrap: balance`, so that a 60-character title fits in two lines at the measure (titles are often long, and left-aligned a large wrapping title looks worse than a centred one; set on 2026-10-15 evening, after the same day's rise to 2.6em, which is reversed). Subtitle: italic, about 1.15em. Level 1: the text face, right-aligned small caps with a full-width hairline rule beneath. Level 2: left-aligned, in the sans (LAYOUT-2a), semibold, smaller. Level 3: run in at the start of its paragraph, in the sans, semibold (was italic). *Revised 2026-10-15.*
- **LAYOUT-2a (MUST) Sans for the apparatus.** The system sans (`system-ui` and its fallbacks; no font file is served) sets level-2 and level-3 headings, figure and table titles (label and title, IMG-3), table column headings, popup and expanded-view titles, the bar's section name and the contents column (TOC-2): semibold (column headings and the bar medium), ordinary case, lining figures. Everything else, including the essay title, level-1 headings, captions, credits, asides, margin notes and notes, stays in Libertinus Serif. Chosen on the specimen from a trial, 2026-10-15. Where the system sans differs (San Francisco on Apple devices, Segoe UI on Windows, Roboto on Android), so does the look; that is accepted.
- **LAYOUT-3 (MUST) Intro paragraph.** The first paragraph after the abstract is marked `.intro`; its first line is small caps (`::first-line`) **in narrow tiers only**. With TYPE-3, rotating a phone changes both the small caps and the justification, as on gwern.net.
- **LAYOUT-4 (MUST) Section break.** `◊break{}` renders a centred glyph (SVG, `currentColor`, smaller variant when narrow), `role="separator"`, generous equal space above and below. Author-placed, never automatic. One glyph; no cycling.
- **LAYOUT-4a (MUST) Epigraph.** The whole epigraph is indented 1em from the column's left edge, left-aligned, ragged right, with **no first-line indent** inside it (the body's paragraph indent does not apply). The attribution (`#:source`) is right-aligned on its own line, roman, with its dash. The text is **italic by default**; `#:italic #f` sets it roman (LAYOUT-4c). *Added 2026-10-15 (evening); `#:italic` added 2026-10-20.*
- **LAYOUT-4b (MUST) Block quotation.** `◊blockquote` is set **roman by default**, set off from the body by its indent, not by its style; `#:italic #t` sets it italic (LAYOUT-4c). The asymmetry with the epigraph is deliberate and follows the usual convention (Bringhurst, Butterick): italic suits a short, detached epigraph; a block quotation of running prose is roman, because italic over several lines tires the eye and leaves emphasis and titles inside the quotation nowhere to go. If `#:italic #t` turns up on block quotations often, the default is wrong, not the toggle. *Added 2026-10-20.*
- **LAYOUT-4c (MUST) The `#:italic` toggle.** `◊epigraph` and `◊blockquote` both take `#:italic #t|#f`, a keyword in the square brackets exactly as `#:source` is. The tag function emits only a class (`roman` on an epigraph, `italic` on a block quotation); CSS sets the style, and nothing else in the build knows about it. Inside any italic block, `◊em` flips to **roman** (`.epigraph em, .quote.italic em { font-style: normal }`), or emphasis inside an epigraph silently disappears; `◊sc` and `◊code` are unaffected. The vocabulary table in `HANDOVER-EMACS.md` §3 lists `#:italic` on both tags, so the highlighter accepts it (FL-6) and the sync test (VOCAB-3) holds. Specimen (THEME-7): an epigraph and a block quotation in each style, each with `◊em` inside. *Added 2026-10-20.*
- **LAYOUT-5 (SHOULD)** Print stylesheet: asides and notes become footnotes, and each note's **numeral is printed in the text** in place of its circle (paper has nothing to open); asides, being unnumbered, need a printed key of their own (symbols such as * † ‡, to settle with the print CSS in Phase 3); external URLs printed after their link text; arrows, circles for definitions, the bar and popups hidden.
- **LAYOUT-6 (MUST) Width tiers** (container queries, §10.6). *Revised 2026-10-19: XL is now a distinct tier (contents at the window's edge) and the left margin carries margin notes.*

  | Tier | Condition | Margins | Column |
  |---|---|---|---|
  | XL | contents column + text block fit (TOC-2) | as L, with the contents at the window's edge | justified |
  | L | left margin + column + right margin fit | left: margin notes; right: aside and definition stubs, figure words, the header's metadata block | justified |
  | M | column fits at full measure | none; margin notes inline; circles open popups | justified |
  | S | below full measure | none; margin notes inline; circles open popins | ragged right |

- **LAYOUT-6b (MUST) Width alone decides the tier.** No media query for phones, pointer type or orientation may force a tier (LAYOUT-7). A phone in landscape at the default size has room for the full measure and is therefore tier M: justified, with popups; rotated back it is tier S again. Touch (`hover: none`) decides only what POP-5 and BAR-1 say it does. *Added 2026-10-15: landscape phones were being held at tier S.*
- **LAYOUT-6c (MUST) The margins widen.** In tiers L and XL the **right margin** is at least 13em and grows into spare room up to **20em**; the **left margin** is at least 8em and grows up to **13em**, the right taking its share first. Each is separated from the column by `--margin-gap` (2.5em; one token, so margin notes sit as close to the column as stubs do). At least 2em (was 3em) is kept clear at either side of the text block, and between the block and the contents column when that shows. The column stays at the measure; left margin, column and right margin stay centred together. Stubs, figure words and margin notes take their margin's width. *Added 2026-10-15; left margin and shared gap added 2026-10-19.*
- **LAYOUT-6a (MUST) Placement of the text block.** In tiers L and XL the **text block** — left margin, column, right margin — is centred **together** in the width left after the contents column (TOC-2). Because the right margin is wider than the left, the column sits a little left of the block's centre; this is intended, as the earlier asymmetry was (settled 2026-10-12, revised 2026-10-19): do not re-centre the column.

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
- **POP-7 (MUST)** Content by type: same-page link → the target section cloned from the DOM; cross-essay link → a build-time fragment `/_x/<slug>/<id>.frag` fetched on demand (not `.html`, which Cloudflare's HTML handling redirects) (prefetched on `pointerenter`); citation (a popup at every tier, including XL/L) → the note, headed "Note *n*" (no heading where unnumbered, CITE-7); under a short-form note, also the bibliography entry (a full note already is the reference, and repeating it reads as duplication); term → §6; aside → its text; external link → the card (§11.1 below). A shared circle (MARK-1c) shows its items in source order, separated by a hairline.
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
2. Check every margin note's anchor and normalise the space around it (MNOTE-6; the note stays where it was written); build the section tree from heading markers; wrap nested `<section>`s; validate; generate TOC markup.
3. **One document-order walk** assigns citation note numbers, descending into asides (asides themselves are unnumbered, ASIDE-2), and merges adjacent marks (MARK-1c); resolve citations from the cache; mark first uses of terms.
4. Emit the end matter (CITE-10): Terms (following terms inside definitions), Asides, Notes, Bibliography; the copies reuse the assigned numbers.
5. Resolve links and marks; compute ↑/↓.
6. Emit section extract fragments for cross-essay popups.

Glossary files take a shorter pass: paragraphs and typography only.

Site-wide:

- **VAL-1 (MUST)** The build fails on: unknown tag, unknown cite key, unknown term, broken internal link, duplicate id, missing required meta field, missing figure alt or licence, malformed list or table, misplaced margin note (MNOTE-6).
- **VAL-2 (MUST)** `tools/validate.rkt`, run after rendering, emits `data/anchors.json` (pages → sections) for validation and Emacs completion, and `data/links.json` (the internal link graph, and which pages mark each glossary term, for TERM-8) for backlinks, and checks every cross-page link (LINK-2).
- **VAL-3 (MUST)** If a section id present in the last deployed `anchors.json` disappears while other pages link to it, the build fails; if nothing links to it, the build warns. Published anchors are a promise. The build publishes `/data/anchors.json`, and CI fetches it before building; a failed fetch skips the check.
- **VAL-4 (MUST) Backlinks.** A pre-pass records every internal link, and every `◊cite` (BIB-6), with its context (the containing paragraph, list item or aside, with the link marked). Each essay ends with a **Backlinks** section listing the linking essays and sections, each context collapsed to ~2 lines and expandable. Links from within the same page are not backlinks; the glossary has no pages, so it contributes none. (Section-level ← marks are in BACKLOG.)
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
| `tags` | MAY | Comma-separated lowercase words, on one line: `◊define-meta[tags]{philosophy, child development}` (INDEX-3); shown in the header (LAYOUT-1) |

- **REV-1 (MUST)** "Last revised" comes from the git log (latest commit touching the file, ignoring `[typo]`/`[meta]` commits), never typed by hand.
- **REV-2 (MUST)** Every essay and page links to its source file and its commit history on GitHub, in the header's metadata block (LAYOUT-1) and again in the footer. Both links are **derived at render** from the file's path in the repository and `repo`/`branch` in `data/site.rktd` (`<repo>/blob/<branch>/<path>` and `<repo>/commits/<branch>/<path>`); nothing is typed in the essay and there is no per-essay flag. An essay whose source does not sit under the repository root fails the build. *Revised 2026-10-19: was footer only, by hand.*
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
- **INDEX-1a (MUST) One table pipeline.** The index (`◊essay-index{}`) is an ordinary `◊table` in every respect: it is built through the same code path as TABLE-1…6, with `#:size normal`, `#:sortable` at any row count (INDEX-3), lining tabular figures, cells aligned to the **baseline**, and the header and body sharing one column grid. Every body row has exactly as many cells as the header, and the build fails if not (the TABLE-1 cell-count check applies here as to any pipe table). Seen 2026-10-20: both dates sat side by side under **Date published**, the tags under **Last review**, **Tags** was empty, and the dates floated above the title's baseline. Whatever the cause (a date cell split or merged, the LAYOUT-1 no-wrap date spans carrying their own line-height, or a bespoke table emitter), the remedy is not a CSS patch to the home page but routing the index through the shared table code so it cannot drift from `◊table` again. A RackUnit test renders the index from two fixture pages and asserts four cells per row, in the order Title · Date published · Last review · Tags. *Added 2026-10-20.*
- **INDEX-2 (MUST)** "Last review" is the REV-1 date (git), or the publication date when the essay has not been revised since. Dates in the table are short (`9 Oct 2026`); on phones they may break before the year.
- **INDEX-3 (MUST)** The table sorts by its first three columns (TABLE-5's sorting, at any number of rows); Tags does not sort. Instead, clicking the **Tags heading** opens a drop-down of every tag (with its count) to tick any number of. The chosen tags form a **set**, shown above the table as chips that each remove their tag (with "clear" once there are two or more). A row shows when it has **every** tag in the set, so each tag narrows the list; when none has them all, a line says so. A tag inside a row adds itself to the set, or removes itself if already there. The set is kept in the address (`/?tags=philosophy,site`) so a filtered list can be linked to. Without scripts the heading is plain text and every essay shows. Tags are validated at build (lowercase words; a bad tag fails the build); `od-set-tags` (§16) offers the tags already in use. *Revised 2026-10-14: replaces a row of single-choice tags above the table.*
- **NAV-1 (MUST)** Every page has a menu at the top left: the site name with a drawn chevron opens a drop-down of **Home**, **About**, **Glossary** (TERM-8) and, from Phase 3, **Bibliography** (BIB-4); the list lives once, in `pollen.rkt`. It is a `<details>` element, so it works without scripts; with them it also closes on Escape and on a click elsewhere. The current page is marked `aria-current`.
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
| **2 — Interaction** | *Built 2026-10-12; awaiting the hand checks in "done when". Revised 2026-10-15 (margin items expand in place with a right rule, definitions get stubs, notes are popups at every tier, open circles stay filled: ASIDE-2…4, TERM-3, TERM-7, MNOTE-4, POP-5…8; plus THEME-5b, LAYOUT-6b, BAR-1, IMG-3a, TOC-2's current-entry mark; and, from the evening, the left-aligned header with its margin block, the smaller title, the epigraph, `text-wrap: pretty` confined to the justified tiers and the hyphenation limits: LAYOUT-1, LAYOUT-2, LAYOUT-4a, TYPE-6, TYPE-4a). Revised again 2026-10-19: margin notes move to the left margin, right-aligned, with precise anchors including list items and sentence starts; the contents move to the window's edge and the order of loss reverses; tier XL; a shared margin gap; and the phrase form of `◊aside` (MNOTE-2…6, TOC-2, LAYOUT-6, 6a, 6c, ASIDE-3…5, ASIDE-8, VAL-1). 2026-10-20: `#:italic` on `◊epigraph` and `◊blockquote`, block quotations roman by default, `◊em` flipping to roman inside italic blocks (LAYOUT-4a…4c); the home-page index routed through the shared table code (INDEX-1a); a `◊margin` at the end of a block is an error (MNOTE-6); a key for every tag (EMACS-6); quotes curled with their context across tags, and a straight quote in output fails the build (TYPE-16). Later the same evening, from the specimen: one baseline for contents, title and metadata; the metadata reordered with the epistemic line last after a gap; a labelled tags line; a short rule closing the header; and the reading bar sized and aligned to the text block (LAYOUT-1a…1c, BAR-1d); and the LaTeX logo tag (TYPE-17). To be rebuilt before the checks.* Carried over from Phase 1: the publish guard for `status` (DRAFT-2) and the essay meta checks, proved on a first test essay in `essays/`. Popup component; term, note, same-page, cross-essay and card popups; circles opening in the margin (POP-8); aside stubs and expansion; margin notes; reading bar with section, text size and theme (BAR-1, THEME-5); table sorting; image inversion. Opens with the **mark rework** left over from Phase 1: circles replace numerals and ≡, arrows enlarged, marks rebuilt so Safari draws them (MARK-1…1c), build walk and tests updated | The behaviour tables in §7, §11 pass by hand on desktop Safari/Chrome/Firefox and on iOS and Android |
| **2b — Interactive figures** | `◊embed` frame: lazy loading, fallback, sticky behaviour, theming, accessibility contract (§9.3); the first widget (mammal taxonomy) built in its own folder | The taxonomy figure loads lazily in an essay, falls back to its static image with JS off, and follows both themes |
| **3 — Around the essays** | Backlinks; changelog and `/changelog`; the glossary page (TERM-8); reference pages and `/bibliography` (§5a); inline mathematics pre-rendered in Libertinus Math (MATH-1); feed; correspondence page; Wayback saving and dead-link job; print CSS. Starts only after Phase 2's rebuild has landed (HANDOVER-PHASE2.md), since both touch the template, the end matter and `validate.rkt` | Two essays that link to each other show correct backlinks; a work cited by both shows both under Cited in; the feed validates |

Phase 1's Emacs work can start during Phase 0; writing the test essay is much easier with the pickers.

**Note for the builder:** write the popup, aside and sorting JS from scratch against this spec. gwern.net is the behavioural reference, not a code base to copy; if any of its code is consulted, check the licence first.

---

## 16. Emacs (`emacs/occurrent.el`)

All pickers use plain `completing-read`, so they work with Vertico, Ivy, Helm or the default UI, with useful annotations beside candidates.

| Command | Candidates | Inserts |
|---|---|---|
| `od-insert-cite` | every key in the Zotero export named by `ZOTERO_BIB` in `local.mk` (delegate to `citar` if present); refuses an unpinned key when Better BibTeX can be asked (BIB-2) | `◊cite["key"]`, prompting for `#:loc` |
| `od-new-reference` (`C-c o R`) | the key at point, or a picked key | Creates `references/<key>.pm` and opens it (BIB-3); Phase 3 |
| `od-insert-math` (`C-c o $`) | — | `◊m{region}` (MATH-1); Phase 3 |
| `od-insert-term` | every headword and alias in `glossary/`, plus "New term…" | `◊term["id"]{region}`; aliases resolve to the id |
| `od-new-term` | prompts for headword, proposes an id | Creates `glossary/<id>.pm` from a template, opens it beside the essay |
| `od-find-term` | terms | Opens the term's file |
| `od-insert-link-internal` | sections in this file | `◊link["#id"]{region}` |
| `od-insert-link-essay` | essays, then sections, from `anchors.json` | `◊link["/slug#id"]{region}` |
| `od-insert-link-external` | URLs already used, plus free entry | `◊link["url" #:note "…"]{region}` |
| `od-insert-section` | level (defaults to current) | `◊section[#:id "slug"]{Title}`, slug proposed and checked |
| `od-goto-section` | sections, indented by level | Jumps |
| `od-insert-aside` / `od-insert-margin` | — | `◊aside{}` / `◊margin{}` with point inside; with an active region, `od-insert-aside` makes it the phrase: `◊aside["region"]{}` (ASIDE-8) |
| `od-preview` | — | Renders and opens the current file in the browser |
| `od-set-tags` (`C-c o T`) | tags already used anywhere in the site (several, comma-separated) | Replaces or adds the `◊define-meta[tags]` line |
| `od-insert-ref` (`C-c o r`) | the figures and tables in the file, with their titles | `◊ref["id"]` (IMG-7) |
| `od-insert-epigraph` (`C-c o Q`) | prompts for the attribution; `C-u` sets `#:italic #f` | `◊epigraph[#:source "…"]{region}` on its own lines (LAYOUT-4a) |
| `od-insert-blockquote` (`C-c o q`) | — ; `C-u` sets `#:italic #t` | `◊blockquote{region}` on its own lines (LAYOUT-4b) |
| `od-toggle-italic` (`C-c o o`) | — | Adds, flips or removes `#:italic` on the enclosing `◊epigraph` or `◊blockquote`; removes it when it would restate the default (LAYOUT-4c) |
| `od-wrap` (`C-c o w`) | the inline tags: `em`, `strong`, `sc`, `code` | `◊em{region}` etc.; the most recent choice is the default |
| `od-insert-break` (`C-c o b`) | — | `◊break{}` on its own line, blank lines either side |
| `od-insert-list` (`C-c o l`) | — ; `C-u` for a numbered list | `◊list{` … `}` with one `- ` or `1. ` item and point after the marker (§3.4) |
| `od-insert-summary` (`C-c o S`) | — | `◊summary{}` on the line after the nearest heading above (SECT-6) |
| `od-insert-anchor` (`C-c o A`) | proposes an id from the word at point, checked against the file's ids | `◊anchor["id"]` |
| `od-insert-more` (`C-c o M`) | glossary files only; `user-error` elsewhere | `◊more{` … `}` after the short definition (§6) |
| `od-insert-changelog` (`C-c o H`) | — | A line in the essay's `◊changelog{…}`, creating the block at the end if absent, dated today (REV-3); `user-error` until the tag is built (VOCAB-2) |
| `od-insert-embed` (`C-c o W`) | widget folders in `widgets/` | `◊embed["name" #:alt "" #:fallback ""]{}` (§9.3); `user-error` until the tag is built |
| `od-promote` / `od-demote` (`C-c o <` / `C-c o >`) | — | Changes the heading level of the heading at point, leaving `#:id` alone (HANDOVER-EMACS EDIT-5) |

- **EMACS-6 (MUST) Every tag has a key.** Every tag in `od-vocabulary` with `:built t` is reachable from `C-c o` by one of the commands above, so the which-key popup is the complete menu of the vocabulary (seen 2026-10-20: epigraph, block quotation, break, list, summary, anchor, `more` and the inline tags had no command). A tag added to the vocabulary without a command fails a test in `occurrent-test.el` (TEST-1) that compares the two sets; the unbuilt tags (`embed`, `changelog`) have their commands already, which refuse until the tag lands. Every insert command wraps the active region (EMACS-2); block tags are inserted on their own lines with a blank line either side, and leave point where the writing continues. *Added 2026-10-20.*
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
- **Aside phrases.** Use the phrase form (ASIDE-8) when the aside qualifies a specific phrase and a reader would want to know which; the bare circle when it comments on the sentence or the thought. Keep the phrase short, a few words, as for a link; the longer it is, the more it reads as a link that goes somewhere.
- **Margin notes.** Sparing, ≤ 8 words, anchored to the sentence or item they gloss (MNOTE-6), and they should read in sequence as a rough outline of the argument.
- **Quotations.** Epigraphs italic, block quotations roman (LAYOUT-4a, 4b). Flip with `#:italic` only for a reason: a long epigraph of running prose, or a quotation whose own typography depends on italic. If the flip is frequent, change the default, not each quotation.
- **Definitions.** Define a term when a smart reader outside the field would misread it, not merely when they might not know it.
- **Citations.** Numbered notes, Chicago notes-bibliography; page locators for quotations and specific claims; the mark goes after punctuation.
- **Headings.** Sentence case; name what the section argues. `#:short` for anything over ~30 characters. Three levels at most; no numbers.
- **Section breaks.** `◊break{}` for a change of direction within a section, or between an unheaded introduction and the first heading. Never before a heading that already follows one, and never directly after the abstract: the header closes itself (LAYOUT-1c).
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
| D11 | Which margin the header's metadata block sits in, now that margin notes are on the left | **Right, as built (LAYOUT-1):** nothing else occupies the right margin beside the abstract, the left margin is narrower, and the block is metadata rather than a signpost. Revisit on the specimen if a left-margin note near an essay's opening makes the two sides look like one apparatus split in half | Phase 2 checks |
| D12 | What closes the header: a short rule (LAYOUT-1c) or a glyph of its own | **The rule.** A header glyph is a reasonable alternative only if it is plainly an ornament of the front matter and not a second kind of pause; if the rule looks thin on the specimen, try a glyph there before deciding | Phase 2 checks |

Resolved already: Pollen markup over Markdown; sections never numbered; glossary site-wide, popup-only; numbered citation notes in Chicago style, with the number kept out of the running text; asides in the right margin, margin notes in the left, contents at the window's edge (2026-10-19); no comments; no archived copies; Libertinus Serif as the typeface; two marks only, arrow and circle; a text-size control in the reading bar (reversing the earlier cut); the bar shows on scroll-up and hides after 2 s idle; the text block stays where it is (LAYOUT-6a); epigraphs italic, block quotations roman, with `#:italic` to flip either (2026-10-20); a generated page per cited work at `/references/<key>`, with keys pinned in Zotero, and a site-wide `/bibliography`, the per-essay Bibliography kept (2026-10-20).
