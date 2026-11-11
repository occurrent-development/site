# occurrentdevelopment.com — The handovers

Status: archive · Owner: Ryan · Assembled 2026-11-03 from the seven handover files written between 2026-10-08 and 2026-11-02, in the order they were given, each kept as written (its headings one level down). A handover was the brief for one phase of the build: what the spec left to Claude Code, in build order, and where to stop. **They are history, not instruction**: every phase here is built, and `SPEC.md` is the current statement of the site; where the two differ the spec is right. The section names are the old file names, so references such as *HANDOVER-EMACS EDIT-5* or *HANDOVER-PHASE2C §7* in the spec, the code and the tests still resolve here.

Contents: [HANDOVER](#handover) (Phase 0) · [HANDOVER-PHASE2](#handover-phase2) (Phase 2) · [HANDOVER-EMACS](#handover-emacs) (the Emacs mode) · [HANDOVER-PHASE2C](#handover-phase2c) (Phase 2c) · [HANDOVER-PHASE3](#handover-phase3) (Phase 3) · [HANDOVER-PHASE3B](#handover-phase3b) (Phase 3b) · [HANDOVER-PHASE3C](#handover-phase3c) (Phase 3c)

---


## HANDOVER

*Handover to Claude Code — Phase 0* (Phase 0; file `HANDOVER.md`, merged 2026-11-03)

Read `SPEC.md` first; it is the build brief. `BACKLOG.md` lists what is deliberately *not* being built. This file covers only what Claude Code needs that the spec doesn't say: what already exists, what to build first, and where to stop.

---

### 1. What already exists

| Thing | State |
|---|---|
| Domain | `occurrentdevelopment.com`, DNS on Cloudflare |
| Email | `ryan@occurrentdevelopment.com`, mailbox at Hover (MX, SPF, DMARC live in Cloudflare DNS — **never touch these records**) |
| GitHub | org `occurrent-development`; public repo `site`; private repo `drafts` (Issues/Wiki/Projects/Discussions off on `site`) |
| Hosting | Cloudflare Worker named `site`, static assets, connected to the `site` repo |
| Deployed | A placeholder `public/index.html`, live at the domain |
| Repo contents | `public/index.html`, `wrangler.jsonc` (assets directory `./public`), `.gitignore`, `SPEC.md`, `BACKLOG.md`, this file |
| Commit identity | Per-repo: `Ryan Lucas <ryan@occurrentdevelopment.com>`. Do not change it, and never commit any other address |

Local clone: `~/Documents/Ryan/Personal/Projects/Occurrent-Development/site`.

---

### 2. The one infrastructure problem to solve first

**Cloudflare's build image has no Racket**, so Pollen cannot be built there. The current setup works only because the placeholder needs no build.

Fix it before anything else:

1. Move the build to **GitHub Actions** (`Bogdanp/setup-racket`), which renders the site into `public/`.
2. Deploy from the same workflow with `cloudflare/wrangler-action` (`wrangler deploy`), using repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. Turn **off** Cloudflare's own Git-connected build so the two don't fight.
4. Ask Ryan to create the API token (Workers Scripts: Edit) and add both secrets; you cannot.
5. Add `public/` to `.gitignore` once CI generates it (the line is already there, commented).

Prove this works with the placeholder *before* building anything else. A deploy pipeline that can't run Racket is the only thing here that can waste a day.

---

### 3. Phase 0 scope

Build exactly this, from `SPEC.md`:

- Pollen project skeleton: `pollen.rkt`, `typography.rkt`, `typography-test.rkt`, `template.html.p`, `index.ptree`, `Makefile`.
- `make`, `make test`, `make serve`, `make refresh` as named in the spec (`refresh` may be a stub that does nothing yet).
- Section tree and headings (§8: SECT-1…7), table of contents (TOC-1).
- Typography (§10.1–10.3): measure, justification/hyphenation switch, Libertinus Serif, the typography rules table with its tests.
- Themes (§10.4): Auto/Light/Dark, no-flash script, colour tokens.
- Page furniture (§10.5): heading styles, intro paragraph, section-break glyph (a plain asterism for now), width tiers via container queries (LAYOUT-7).
- **The specimen page** (`/specimen`, THEME-7) — the deliverable of this phase.
- Deployed and live.

Nothing else. No popups, asides, citations, glossary, backlinks, figures, tables or embeds. They are Phases 1–3 and will be handed over separately.

---

### 4. Things to get right (easily missed)

- **SRC-3**: a single newline inside a paragraph is a space, not `<br>`. Pollen's default is the opposite, and the source is hard-wrapped by `fill-paragraph`.
- **TYPE-13**: merge adjacent strings before the typography rules run, or rules silently fail at line breaks.
- **MARK-2**: a line containing a superscript must be exactly as tall as one without.
- **LAYOUT-7**: width tiers are container queries, not media queries.
- **TYPE-1**: the measure is *calibrated by counting characters*, not set to `90ch`. Put the final value in the colophon.
- **TYPE-9a**: Libertinus is OFL, so the font files are committed, with `OFL.txt` beside them. Subset to WOFF2 in the build.
- Verify `smcp`, `c2sc`, `onum` and `tnum` work in the Libertinus release before building on them. Report if any don't.

---

### 5. Decisions Ryan hasn't made, and what to do meanwhile

| Open | Do this |
|---|---|
| Theme colours (SPEC D1) | Build the specimen page with a control that cycles the three candidate backgrounds and text colours, so he picks by looking |
| Licences (D4) | Leave `LICENSE` and `LICENSE-CONTENT` as TODO stubs; don't invent terms |
| Serial comma (D5) | Irrelevant to the build; ignore |
| Section-break glyph (D6) | Plain asterism; one SVG, easy to swap |

---

### 6. Where to stop

Stop when the specimen page is live at `occurrentdevelopment.com/specimen` and `make test` passes. Then report:

1. the calibrated measure, and the body size and line-height you settled on;
2. anything in the spec that proved wrong or impossible, with what you did instead;
3. the three things you'd most want decided before Phase 1.

Do not start Phase 1. Ryan judges the typography on the specimen page first, and that judgement may change the foundations.

---

### 7. Standing instructions

- **Write the interaction code from scratch** against the behaviour tables in the spec. gwern.net is the behavioural reference, not a codebase to copy; check the licence before consulting any of its code.
- **Ask rather than guess** on anything that affects how the site reads. Guess freely on anything internal.
- **Keep the JS budget** (§14): Phase 0 should ship almost none — the theme script and nothing else.
- **Never commit** font files other than Libertinus, anything matching `*-Notes.md`, `*.docx`, `*.graffle`, `*.tex`, or any email address other than `ryan@occurrentdevelopment.com`.
- **Don't touch DNS.** If something needs a DNS change, say so and stop.

---

### 8. Opening prompt

> Read `SPEC.md`, `BACKLOG.md` and `HANDOVER.md` in this repo. Build Phase 0 only, as defined in HANDOVER §3.
>
> Start with the deploy pipeline problem in HANDOVER §2: Cloudflare's build image has no Racket, so the build must move to GitHub Actions with wrangler deploying to the existing Worker. Prove that works with the current placeholder before building anything else.
>
> Then build the Pollen skeleton, the section tree and table of contents, the typography, the themes and the specimen page. Show me the Makefile and the GitHub Actions workflow before building on top of them.
>
> Stop when the specimen page is live and the typography tests pass, and report as described in HANDOVER §6. Do not start Phase 1.

---


## HANDOVER-PHASE2

*Handover to Claude Code — Finish Phase 2, build the Emacs mode* (Phase 2; file `HANDOVER-PHASE2.md`, merged 2026-11-03)

Status: 1.1 · Owner: Ryan · 2026-10-21

Two jobs, in this order. Do not start Phase 3 (SPEC §15); it waits for both.

### Job A — Finish Phase 2

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

### Job B — The Emacs mode

Everything is specified in `HANDOVER-EMACS.md`, plus KIND-6 in SPEC §13b (the kind prompt in `od-new-essay`, `entry` in `od-file-kind`, `od-insert-changelog` refusing in an entry, entries in `od-insert-link-essay`, tags from both kinds in `od-set-tags`, and the by-kind refusals in the vocabulary table). Read it, then follow its §13 opening prompt exactly; stop where its §12 says and report as it asks. This job touches only `emacs/`, `Makefile` (the `test-emacs` target) and one test in `pollen-test.rkt` (VOCAB-3), so it can run after Job A in the same session or in a parallel session on its own branch; if parallel, do not rebase onto Job A's branch until A is merged.

### Opening prompt

> Read `HANDOVER-PHASE2.md` in this repo and do Job A as written: read `SPEC.md` and `COMPAT.md`, check the 2026-10-15 and 2026-10-19 items in the Phase 2 row of SPEC §15 against the code, build every 2026-10-20 and 2026-10-21 item, get `make` green, check the pages it names in three browsers at four tiers, and stop with the report it asks for. Then, after I have looked, do Job B.

---


## HANDOVER-EMACS

*Handover to Claude Code — Emacs* (the Emacs mode; file `HANDOVER-EMACS.md`, merged 2026-11-03)

Status: draft 1.4 · Owner: Ryan · 2026-10-22 (EDIT-1a, EDIT-9, LOAD-4a, the SRC-4a changes to VOCAB-4 and EDIT-6, and PUB-3's CITE-5a note, all written 2026-10-15/16 on the Emacs branch and lost from this file at a merge, are restored; `od-preview` gains its Phase 4 prefix). Previously draft 1.3 · 2026-10-15 (revised the same day for IMG-7: figure and table ids, titles and `◊ref`; and again for the per-essay `support/` folder; revised 2026-10-20: `#:italic` on `epigraph` and `blockquote`, a command for every tag (SPEC EMACS-6), the end-of-block `◊margin` check)

Read `SPEC.md` §3 (authoring format), §6 (glossary), §13 (revisions), §16 (Emacs) and `emacs/occurrent.el` first. This file specifies two things on top of what exists: a **major mode** for the site's Pollen dialect, with syntax highlighting that catches build errors before `make` does, and **publishing from Emacs with Magit**. Requirements carry IDs so commits and tests can reference them. **MUST** = required; **SHOULD** = expected, may slip; **MAY** = optional.

When this is built, fold the new IDs into `SPEC.md` §16 and point it here for detail; do not duplicate the text.

---

### 1. What already exists

| Thing | State |
|---|---|
| `emacs/occurrent.el` | A **minor mode**, `occurrent-mode`, meant to sit on top of some major mode for `.pm` files. Pickers for cites, terms, links, sections, tags and (since 2026-10-15) figure/table references (`od-insert-ref`, now `C-c o l`, *figure or table*, reading `#:id`/`#:title` from `◊figure`, `◊table` and `◊table-csv` in the buffer); `imenu`; `outline-minor-mode`; three font-lock rules that dim `◊name`, `#:keyword` and brackets; `fill-paragraph` protection for `◊define-meta` lines (SRC-4); `od-preview` via `make serve`; the macOS Option-key fix (EMACS-1). Keys under `C-c o`, lozenge on `C-c ;`. |
| Major mode | None of ours. The comment in `occurrent.el` assumes `pollen-mode` from MELPA (`lijunsong/pollen-mode`, v1.0, LGPL). |
| Build | `make` (tests, fonts, render, validate, assemble `public/`), offline. `make refresh` is the only networked step (Zotero export → `refs/refs.bib`, pandoc → `data/cite-cache.json`, InvertOrNot → `data/invert.json`). |
| Deploy | Push to `main` on `github.com/occurrent-development/site` → GitHub Actions builds and deploys to the Cloudflare Worker. Other branches build but do not deploy. Nothing generated is committed. |
| Drafts | SPEC DRAFT-1 says: private repo or a never-pushed branch. A private `drafts` repo exists on GitHub but has **no local clone**; the current draft material lives outside git in `../Essays/` as Markdown, LaTeX and Word files. DRAFT-2 (the build publishes only `status` ≠ `draft`) is built and tested. |
| Commit identity | Per-repo `Ryan Lucas <ryan@occurrentdevelopment.com>`. Never commit another address (HANDOVER §7). |
| Tags actually provided by `pollen.rkt` | `section subsection subsubsection summary em strong sc code blockquote epigraph br anchor break link cite term aside margin more list table table-csv sort-key figure ref` plus `define-meta` (Pollen's own), and `latex` once HANDOVER-PHASE2 Job A lands (SPEC TYPE-17). **`embed` and `m` are in SPEC §3.3 but not yet built** (`changelog` landed in Phase 3; `q` was withdrawn in draft 1.18); using them is a build error today. |
| Figures and tables (IMG-7, IMG-2, 2026-10-15) | `◊figure`, `◊table` and `◊table-csv` **require `#:id` and `#:title`**; the build numbers them (Figure 1, Table 1) and `◊ref[id]` prints the label as a same-page link. **`#:width` is a build error** (every figure and table is column width; the reader has an Expand button). The exhibit frame lives in `lib/exhibits.rkt`. |
| Error format | `build error: <path relative to root>: <message>` on stderr (`lib/util.rkt`); no line numbers. `tools/validate.rkt` prints the same prefix for site-wide checks. |

---

### 2. The decision: a major mode of our own, not a layer on `pollen-mode`

**MODE-1 (MUST)** `occurrent-mode` becomes a **major mode** derived from `text-mode`, replacing the minor mode. Every existing command, key, the `imenu` and `outline` setup, the fill protection and the Option-key fix carry over unchanged. `auto-mode-alist` maps `\.pm\'` to it.

**MODE-2 (MUST)** `pollen-mode` is **not** a dependency and is not derived from. Reasons, so the choice isn't revisited: it derives from `fundamental-mode` (so no `text-mode` filling, sentence commands or `text-mode-hook`); its font-lock is three rules and knows nothing of our vocabulary; its syntax table marks `◊;` comments only, so `forward-sexp` cannot cross a tag body; it binds `@` to insert `◊`, which fights prose (an email address needs `@@`); and its `pollen-minor-mode` re-enables itself in every buffer via `after-change-major-mode-hook`. If `pollen-mode` happens to be installed, our `auto-mode-alist` entry must win (prepend it).

**MODE-3 (MUST)** Glossary files (`glossary/<id>.pm`) use the same mode. The mode knows which kind of file it is in (`od-file-kind`: `essay`, `page`, `glossary`, `fixture`; `reference` from Phase 3, SPEC BIB-3) from the path relative to `od-root`; a few rules below depend on it.

**MODE-4 (SHOULD)** The mode works outside the repository too (a stray `.pm` file): everything that needs `od-root` degrades to a `user-error` when invoked, never at mode activation.

---

### 3. Vocabulary

The highlighter, the completer and the checker all read **one table**, `od-vocabulary`, in `occurrent.el`.

**VOCAB-1 (MUST)** Each entry gives: tag name; whether it takes a **positional argument** in `[...]` (`link`, `cite`, `term`, `anchor`, `ref`, `table-csv`, `figure`, `embed`, `sort-key`, `define-meta`); its allowed **keyword arguments**, marking which are **required**; whether it takes a **body** in `{...}` (`cite`, `anchor`, `ref`, `br`, `break`, `table-csv` do not); and whether it must start a line (**block**: `define-meta`, `section`, `subsection`, `subsubsection`, `summary`, `break`, `list`, `table`, `table-csv`, `figure`, `formula`, `embed`, `epigraph`, `blockquote`, `changelog`). Seed it from SPEC §3.3 and the `provide` form in `pollen.rkt`:

| Tag | Positional | Keywords | Body | Block |
|---|---|---|---|---|
| `define-meta` | key | — | value | yes |
| `section` `subsection` `subsubsection` | — | `#:id` (required), `#:short` | title | yes |
| `summary` | — | — | yes | yes |
| `link` | target | `#:note` `#:title` `#:author` `#:date` | yes | no |
| `cite` | key | `#:loc` `#:note`; with a body also `#:block` `#:italic` `#:source` (BIB-9) | optional: the quoted words | no (a `#:block #t` cite: yes) |
| `term` | id | `#:mark` | yes | no |
| `aside` `margin` `sc` `em` `strong` `code` | — | — | yes | no |
| `anchor` | id | — | no | no |
| `ref` | id of a figure or table in this file | — | no | no |
| `br` `break` `latex` | — | — | no | `break` yes |
| `blockquote` | — | `#:source` `#:italic` (LAYOUT-4b) | yes | yes |
| `epigraph` | — | `#:source` `#:italic` (LAYOUT-4a) | yes | yes |
| `list` | — | `#:start` `#:columns` | yes | yes |
| `table` | — | `#:id` (required) `#:title` (required) `#:caption` `#:source` `#:size` `#:sortable` `#:align` `#:row-headers` | yes | yes |
| `table-csv` | path | as `table` | no | yes |
| `sort-key` | value | — | yes | no |
| `figure` | src | `#:id` (required) `#:title` (required) `#:alt` (required) `#:licence` (required) `#:credit` `#:invert` | caption | yes |
| `formula` | — | `#:id` (required) `#:title` `#:caption` `#:source` | TeX source, as `m` | yes |
| `sense` | — | — | yes | no (inside `◊term` only; TERM-9) |
| `index` | — | `#:kind` (required: `"essay"` or `"entry"`) | no | yes (`/essays` and `/blog` only; KIND-4) |
| `latest` | count | — | no | yes (the home page only; HOME-1) |
| `embed` | name | `#:alt` `#:fallback` `#:sticky` | caption | yes (**not built**) |
| `changelog` | — | — | yes | yes (**not built**) |
| `m` | — | `#:display` | TeX source | no (**not built**; Phase 3, SPEC MATH-1) |
| `audio` | file | `#:bytes` `#:duration` `#:recorded` (all required) | description | yes (**not built**; Phase 5, SPEC AUDIO-3) |

`#:width` is deliberately absent from `figure`, `table`, `table-csv` and `embed`: the build rejects it (IMG-2, 2026-10-15), so the highlighter must too (FL-6). `#:italic` takes `#t` or `#f` only; any other value is an error (FL-6). *2026-10-20.*

**VOCAB-2 (MUST)** Each entry carries a `:built` flag. Tags that `pollen.rkt` does not yet provide (`embed`, `changelog`, `m`) are in the table for completion and documentation but are highlighted as **errors** (FL-6) until the flag is flipped. The table, not the highlighter, is what changes when a phase lands.

**VOCAB-3 (MUST) Sync test.** `pollen-test.rkt` gains a test that reads `emacs/occurrent.el`, extracts the tag names with `:built t` from `od-vocabulary`, and asserts the set equals the tag functions `pollen.rkt` provides (the `provide` form minus the template helpers and `root`). `make test` therefore fails when the two drift. Keep `od-vocabulary` a plain quoted list with one entry per line so the Racket side can parse it with a regexp.

**VOCAB-4 (MUST)** Meta keys are a second small table, by file kind: essays and pages take `title subtitle status published tags specimen unlisted` (`abstract` and `epistemic` became tags on 2026-10-15, SPEC SRC-4a, so as meta keys they are errors); glossary files take `term aliases see-also added`. `status` values are `draft published revised superseded` (`essay-statuses` in `lib/util.rkt`).

**VOCAB-5 (MUST) A command for every tag.** Each entry also names its insert command (`:command`), so the vocabulary is the one place that says what `C-c o` can do (SPEC EMACS-6). Every `:built t` entry must name a command that exists; TEST-1 checks it. The unbuilt tags name theirs too, and those commands `user-error` with "not built yet" until the flag flips. *Added 2026-10-20.*

---

### 4. Syntax

The aim is that Emacs's own structural commands (`forward-sexp`, `up-list`, `mark-sexp`, `show-paren-mode`, `electric-pair-mode`) understand a tag body, while prose stays prose.

**SYN-1 (MUST)** Syntax table: `{` `}` are paired parens; `[` `]` are paired parens; `"` is **punctuation** by default (prose is full of straight quotes); `◊` is punctuation; `'` is punctuation (apostrophes), not an expression prefix; `_` and `-` are word constituents inside tag names only via the propertize step, otherwise punctuation.

**SYN-2 (MUST)** `syntax-propertize-function` refines this per occurrence:
- `"` gets string syntax **only inside a `[...]` argument group** that follows `◊name`. So `◊cite["key" #:loc "p. 42"]` has two strings; a quotation mark in a paragraph has none. Strings may span lines (SPEC §3.2 shows a `#:note` wrapped across a line).
- `◊;` to end of line is a comment; `◊;{` … `}` is a block comment (Scribble's forms), marked with the comment syntax-table property, as `pollen-mode` does.
- A `[` that does **not** immediately follow `◊name` (e.g. "[sic]" in prose) is punctuation, as is its `]`. A `{` that does not follow `◊name`, `◊name[...]` or a bare `◊` is punctuation. Pollen's reader requires braces to balance inside bodies, so braces inside bodies keep paren syntax.
- `parse-sexp-lookup-properties` is `t`.

**SYN-3 (MUST)** With SYN-1/2, `forward-sexp` on the `◊` of `◊aside{…}` lands after the closing brace, and `up-list` from inside an aside lands after it. Test both (TEST-1).

**SYN-4 (SHOULD)** `show-paren-mode` matches the braces of a tag body across lines; `electric-pair-mode`, when the user has it on, pairs `{` `[` and, inside an argument group, `"`.

---

### 5. Highlighting

Principle (EMACS-5): **prose dominates; markup recedes; errors stand out.** Nothing in running text is coloured except what is wrong. The faces are `defface`s inheriting from standard faces so themes work; the names are fixed so Ryan can retune them in his config.

| Face | Inherits | Used for |
|---|---|---|
| `od-markup-face` | `shadow` | `◊`, tag names, `[ ] { }`, `#:keyword`, `#lang pollen` |
| `od-string-face` | `font-lock-string-face`, dimmed | strings inside argument groups (keys, URLs, notes) |
| `od-id-face` | `font-lock-constant-face` | the value of `#:id` (headings, figures, tables), a `◊term` id, a `◊cite` key, a `◊anchor` id, a `◊ref` target — permanent identifiers (SRC-1, IMG-7), so slightly more visible than other strings |
| `od-heading-1-face` `od-heading-2-face` `od-heading-3-face` | `outline-1/2/3` | the **title text** of `◊section`, `◊subsection`, `◊subsubsection`; level 3 italic, not bold (LAYOUT-2) |
| `od-meta-key-face` | `font-lock-keyword-face` | the key in `◊define-meta[key]` |
| `od-aside-face` | `italic` + slightly dimmed foreground | the body of `◊aside{…}` and `◊margin{…}`, so a digression reads as one in the buffer |
| `od-term-face` | `font-lock-type-face`, no bold | the body of `◊term[…]{…}` |
| `od-code-face` | `fixed-pitch` | the body of `◊code{…}` |
| `od-list-marker-face` | `od-markup-face` | `- ` and `1. ` markers inside `◊list{…}`; `|` inside `◊table{…}` |
| `od-error-face` | `font-lock-warning-face` (background, not just foreground, so it cannot be missed) | FL-6 |

**FL-1 (MUST) Markup.** `◊name`, its brackets, braces and keywords take `od-markup-face`. Keyword values take `od-string-face`, except those listed under `od-id-face`.

**FL-2 (MUST) Bodies span lines.** Bodies (`aside`, `margin`, `term`, `code`, `sc`, `em`, `strong`, headings) are matched by a function, not a regexp: find `◊name` with optional `[...]`, then `scan-lists` from the `{` to its match, and set match data on the interior. Set `font-lock-multiline` on the match and add an entry to `font-lock-extend-region-functions` that widens the region to enclosing braces, so a body that starts above the refontified window is still fontified whole. An unbalanced brace must not signal an error; the matcher stops at the next blank line.

**FL-3 (MUST) Headings.** The title text takes the heading face for its level; the `◊section[#:id "…"]` prefix stays `od-markup-face`. A heading without `#:id` is an error (SRC-1, FL-6).

**FL-4 (MUST) Meta lines.** Key in `od-meta-key-face`, value plain. The value of `status` is highlighted by state: `draft` in `od-aside-face` (quiet), anything not in `essay-statuses` in `od-error-face`. A meta value that does not close `}` on the same line is an error (SRC-4).

**FL-5 (MUST) Lists and tables.** Inside `◊list{…}`: `- ` and `N. ` markers in `od-list-marker-face`; an item whose indentation is not a multiple of two spaces, or a line that is neither a marker, a continuation (indented) nor blank, takes `od-error-face` (LIST-7). Inside `◊table{…}`: `|` in `od-list-marker-face`.

**FL-6 (MUST) Errors.** `od-error-face` on:
- a `◊name` not in `od-vocabulary`, or in it with `:built nil` (SRC-2: an unknown tag fails the build);
- `◊quote` specifically, with a tooltip saying "use ◊blockquote" (`make test` rejects it), and any Racket syntactic form after `◊` (`define`, `if`, `let`, `lambda`, `require`, `quote`, `unquote`, `set!`)—these do not fail the build, they corrupt the page silently;
- `◊` followed by whitespace, a newline, or `{` with no name (a bare `◊{…}` is legal Scribble but never wanted here);
- a keyword argument not allowed for that tag (`◊cite["k" #:page "3"]`), including `#:width` on a figure, table or embed (IMG-2), and `#:italic` with a value other than `#t` or `#f`;
- a required keyword missing: `#:id` or `#:title` on `◊figure`, `◊table`, `◊table-csv`; `#:alt` or `#:licence` on `◊figure` (IMG-3, IMG-6, IMG-7). Highlight the tag name, since there is no argument to point at;
- `◊sense` outside a `◊term` (TERM-9); `◊define-meta[term]` outside a glossary file; a glossary meta key in an essay (VOCAB-4);
- a heading without `#:id`; two elements in the same file with the same id, counting headings, figures, tables and anchors together (SECT-5, IMG-7), highlighting the second;
- `◊p` (SPEC §3.1: paragraphs are never written as tags; it is also unbound, so it already fails the build);
- a `◊margin` whose anchor MNOTE-6 does not allow, including one followed by nothing but whitespace before the end of its paragraph, list item or quoted paragraph (the "glosses nothing" case, MNOTE-6, 2026-10-20); the check is the same one `od-insert-margin` uses to warn (EDIT-8);
- a `◊link` whose target is `#id` where no heading, figure, table or `◊anchor` in the file has that id, and a `◊ref` whose id is not a figure or table in the file (LINK-2, IMG-7; cross-essay targets are checked by `od-check`, not the highlighter). One function collects the file's ids by kind and serves the highlighter, `od-insert-link-internal` and `od-insert-ref` (replacing `od--exhibit-ids`).

**FL-7 (SHOULD)** `◊break{}` and `#lang pollen` in `od-markup-face`; the `◊epigraph` and `◊blockquote` bodies in `od-aside-face`'s italic without the dimming. The buffer face does not follow `#:italic`: the page's default for each block is what the buffer shows, and the keyword is read in the markup. *Clarified 2026-10-20.*

**FL-8 (MAY)** `prettify-symbols-mode` support is **not** wanted: the lozenge stays a lozenge, nothing is hidden. Record this so it isn't added.

---

### 6. Editing

**EDIT-1 (MUST) Filling.** `fill-paragraph` and `auto-fill` treat as paragraph boundaries: a line starting with any block tag (VOCAB-1), a line that is only `}`, and the `#lang` line. Meta lines are never filled (existing SRC-4 behaviour). Inside `◊list{…}`, `adaptive-fill-mode` recognises `- ` and `N. ` with their indentation so a wrapped item keeps its level (two spaces per level, LIST-1). Filling never breaks inside `[...]` argument groups except inside a string (SPEC §3.2 wraps a `#:note`), and never separates a `◊name` from its `[` or `{`.

**EDIT-1a (MUST) Soft wrap.** *Decided 2026-10-15:* essays are written one line per paragraph and shown wrapped (`visual-line-mode`, with `olivetti-mode` for the width, both from Ryan's config), so nothing needs refilling while typing or revising. `od-soft-wrap` (default `t`) makes `M-q` join a paragraph onto one line rather than break it, which also converts older hard-wrapped paragraphs. `auto-fill-mode` is not used. The cost in diffs, a whole paragraph marked as changed for one word, is met by Magit's word highlighting (`magit-diff-refine-hunk` set to `all` in Ryan's config). The rest of EDIT-1 applies when `od-soft-wrap` is nil.

**EDIT-2 (MUST) Wrapping commands** keep EMACS-2: every insert command wraps the active region. Add `od-unwrap` (`C-c o u`): with point inside a tag body, remove the `◊name[...]{` and its `}` and leave the body. Add `od-up` (`C-c o U`): move point just after the enclosing tag.

**EDIT-3 (MUST) Completion at point.** A `completion-at-point-functions` entry that completes: a tag name after `◊` (from `od-vocabulary`, `:built` tags first); a keyword after `#:` inside an argument group (those allowed for the enclosing tag); a cite key inside `◊cite["` (the Zotero export, via the existing cache); a term id inside `◊term["` (EMACS-3 cache); a section, figure, table or anchor id after `◊link["#`; a figure or table id inside `◊ref["`; a page then section after `◊link["/` (`data/anchors.json`). Plain `completing-read` pickers remain the primary route; CAPF is for when the hands are already typing.

**EDIT-4 (SHOULD) Spelling.** `flyspell-mode` skips tag names, keywords, and strings in argument groups (`flyspell-generic-check-word-predicate`), so keys, ids and URLs are not flagged. Body text, including aside bodies, is checked.

**EDIT-5 (SHOULD) Outline.** Keep `outline-minor-mode` with the three heading levels; add `od-promote` / `od-demote` (BACKLOG §15, cheap once the mode exists), which also rename the tag and leave `#:id` untouched (ids are permanent). Bound to `C-c o <` and `C-c o >` (they were missing from the `C-c o` menu on 2026-10-20).

**EDIT-6 (MUST) Templates.** `od-new-essay` (`C-c o N`): prompts for a title, proposes a slug (checked: lowercase-hyphenated, not already an essay), and creates

```
essays/<slug>/
├── <slug>.html.pm      # the meta block: title, subtitle, status = draft, published = today, tags; then ◊epistemic{} and ◊abstract{} (SRC-4a); point at the end
├── img/                # figures; published with the essay
└── support/            # everything else: notes, sources, drafts in other formats, sketches; never published (BUILD-3a)
    └── notes.md        # created empty, with the title as its first line
```

then applies DRAFT-E1 (§8) and opens the `.pm` file. `support/` is gitignored for every essay by one committed rule, `essays/*/support/`, so it stays private after publication too; the BUILD-3a filename patterns remain as a second guard. The Emacs scans that walk the repository for `.pm` files (`od--used-urls`, `od--used-tags`, and the id collector of FL-6) skip `support/`. When an essay in `../Essays/` is started in Pollen (E3), its existing material moves into that essay's `support/`. `od-new-term` exists; `od-new-page` is not needed.

**EDIT-7 (MUST) Figures and tables.** `od-insert-figure` (`C-c o F`): picks an image from the essay's `img/` folder (or any path), asks for a title, proposes an id from it (checked against the file's ids), asks for alt text and a licence (`own`, `public-domain`, a CC licence, `permission`, completing), and inserts a complete `◊figure` with all four required keywords so the build cannot reject it for a missing one. `od-insert-table` (`C-c o B`): asks for title and id and inserts `◊table[#:id "…" #:title "…"]{` with an empty pipe-table skeleton (header row, rule row, one body row) and point in the first cell. `od-insert-ref` stays as built.

**EDIT-8 (MUST) The rest of the vocabulary.** On 2026-10-20 the `C-c o` menu had no command for `epigraph`, `blockquote`, `break`, `list`, `summary`, `anchor`, `more`, the inline tags, or the two unbuilt tags. SPEC §16 now lists one for each, with its key; SPEC EMACS-6 makes the rule, and VOCAB-5 wires it into the table. Details that the SPEC table leaves to this file:
- `od-insert-epigraph` (`C-c o Q`) prompts for the attribution with `completing-read` over the `#:source` strings already in the file (free entry allowed); an empty answer omits `#:source`. `C-u` adds `#:italic #f`. `od-insert-blockquote` (`C-c o q`) takes `C-u` for `#:italic #t`. Both are block tags: inserted on their own lines, blank line before and after, the region (if any) as the body, point inside.
- `od-toggle-italic` (`C-c o o`) finds the enclosing `◊epigraph` or `◊blockquote` (`user-error` otherwise), reads any `#:italic`, and sets the opposite of the current effective style; when the result equals the tag's default (italic for an epigraph, roman for a block quotation) it removes the keyword rather than writing it. Reports the new state in the echo area.
- `od-wrap` (`C-c o w`) reads one of `em strong sc code` with `completing-read`, defaulting to the last choice, and wraps the region or the word at point. There is no separate key per inline tag; four keys for four two-letter tags would crowd the menu.
- `od-insert-break` (`C-c o b`) inserts `◊break{}` on its own line with a blank line either side, and refuses with a `user-error` when the next non-blank line is a heading that already follows one (§17 "Section breaks").
- `od-insert-list` (`C-c o l`) inserts `◊list{` `- ` `}` with point after the marker; `C-u` makes it `1. `. With a region, each line of the region becomes an item.
- `od-insert-summary` (`C-c o S`) inserts `◊summary{}` on the line after the nearest heading above point, `user-error` if there is none or it already has one.
- `od-insert-anchor` (`C-c o A`) proposes an id from the word at point, checks it against the file's ids (the FL-6 collector), and inserts `◊anchor["id"]`.
- `od-insert-more` (`C-c o M`) is withdrawn (draft 1.19, D18): a term file's paragraphs after the first are its More, with no tag. `od-insert-term` with a prefix argument writes `◊sense{}` after the region and leaves point inside it; it refuses when the buffer already gives that term a sense (SPEC TERM-9).
- `od-insert-latex` (`C-c o L`) inserts `◊latex{}` and leaves point after it; it is an empty-body tag, so a region is not wrapped (SPEC TYPE-17).
- `od-insert-changelog` (`C-c o H`) and `od-insert-embed` (`C-c o W`) exist now and `user-error` with "not built yet (VOCAB-2)" until their flags flip; when built, the first appends a dated line (`YYYY-MM-DD: `) to the essay's `◊changelog{…}`, creating the block at the end of the file if absent, and the second offers the folders in `widgets/` and inserts `◊embed["name" #:alt "" #:fallback ""]{}` with point in `#:alt`.
- `od-insert-margin` (`C-c o m`) gains a check: when point is at the end of a paragraph, list item or quoted paragraph (only whitespace before the block ends), it asks "A margin note here glosses nothing; insert at the start of this item/paragraph instead?" and, on yes, moves point there first (MNOTE-6, 2026-10-20).

---

**EDIT-9 (MUST) The guide.** `od-guide` (`C-c o I`) opens a read-only org buffer, `*Occurrent guide*`, walking through the three workflows: starting a new essay, publishing it, revising and republishing. Keys in it are read from the keymap; a command not yet defined shows its planned key marked *(not built yet)*, so the guide is never wrong about what works. `q` closes it. When a workflow changes, the guide's text (`od--guide`) changes with it. *Added 2026-10-15 at Ryan's request.*

**EDIT-10 (MUST) Org table separators.** Inside `◊table{…}` the build accepts Org's separator lines (`|---+---|` as well as `|---|---|`), so a pipe table can be edited with `org-table` commands and realigned with `C-c C-c`. *Added 2026-10-15 (c906b40).*

### 7. Checking before publishing

**CHECK-1 (MUST)** `od-check` (`C-c o k`) runs `make test` then `raco pollen render <this file>` and `racket tools/validate.rkt` in a `compilation-mode` buffer from `od-root`. A `compilation-error-regexp-alist` entry matches `build error: \(.+?\): ` and `warning: \(.+?\): ` (file, no line) so `next-error` opens the file. **Do not** add line numbers to `build-error` in Racket to make this nicer unless it is cheap: the highlighter (FL-6) is where line-level feedback lives.

**CHECK-2 (SHOULD)** `od-check` with a prefix argument runs the full `make` (fonts, images, every page, validate), which is what CI runs.

**CHECK-3 (MAY)** A Flymake backend that runs the FL-6 checks plus the LINK-2 same-page check and reports them in the diagnostics list. Only if the font-lock matchers can be reused without duplicating logic; otherwise skip.

---

### 8. Publishing from Emacs with Magit

#### 8.1 Feasibility

**Yes, with nothing to add on the server side.** Publishing *is* a push to `main`: the GitHub Actions workflow (`.github/workflows/deploy.yml`) builds the site and deploys it to Cloudflare on every push to `main`, and Magit pushes. What is missing is not the push but the **steps around it** that the spec requires, which are easy to forget and which Magit knows nothing about:

1. the essay must be listed in `index.ptree` (the build fails otherwise);
2. `status` must change from `draft` to `published`, and `published` must be a date;
3. `make refresh` must run so that the entries the essay cites reach `refs/refs.bib` and `data/cite-cache.json` (CITE-9: an unknown key fails the build), and any new figure is classified into `data/invert.json`;
4. new glossary terms must be committed with the essay;
5. `make` must pass locally, because CI running it is the slow way to find out;
6. nothing matching BUILD-3a (`*-Notes.md`, `*.docx`, `*.graffle`, `*.tex`) and no email address other than `ryan@occurrentdevelopment.com` may enter the commit;
7. the commit message convention matters: REV-1 ignores `[typo]` and `[meta]` commits when computing "last revised".

So the deliverable is a command that does 1–6 and then **hands over to Magit for the commit and push**, where Ryan sees the diff of what is about to become public permanently.

#### 8.2 Drafts: a decision Ryan must make

The spec's DRAFT-1 options both have a problem for an Emacs workflow. A **separate private repo** cannot be previewed: Pollen needs the essay inside the project that holds `pollen.rkt`, so `make serve` and `od-preview` don't work on a file in another clone. A **never-pushed branch** is one `P p` away from publishing a draft, and Magit makes that keystroke easy.

**DRAFT-E1 (recommended)** Drafts live **inside the site working tree** at their final path, `essays/<slug>/`, and are kept out of git by `.git/info/exclude` (per-clone, never committed): `od-new-essay` appends `essays/<slug>/` to it, and `od-publish` removes that line as its first step. (The essay's `support/` folder is ignored separately and permanently by `.gitignore`, EDIT-6; the exclude line covers the rest of the folder only until publication.) Consequences: the essay renders and previews like any other; Magit never shows it, so it cannot be staged, committed or pushed by accident; DRAFT-2 (`status` guard) remains the second guard; and the essay is invisible to `git` until the moment of publication, which is exactly DRAFT-1's intent. Cost: a draft is not in any git history until it is published, and `support/` never is. If that matters, `od-backup-drafts` (**MAY**) copies every excluded essay, `support/` included, into the existing private `drafts` repo (cloned beside `site/` as `../drafts`) and commits and pushes there.

**DRAFT-E2 (alternative)** Keep the private `drafts` repo as the place drafts are written, and make `od-preview` work there by symlinking `drafts/essays/<slug>` into `site/essays/` while editing. Rejected by default: a symlink inside `site/essays/` is itself something Magit could stage.

Build DRAFT-E1 unless Ryan says otherwise.

#### 8.3 Commands

**PUB-1 (MUST)** `od-publish` (`C-c o P`), from an essay buffer in the site repo:
1. Refuse unless `od-file-kind` is `essay`, the buffer is saved, and `git config user.email` is `ryan@occurrentdevelopment.com`.
2. Remove the essay's `.git/info/exclude` line (DRAFT-E1).
3. If `status` is `draft`, set it to `published` after confirming; set `published` to today if absent; refuse if `title` is missing.
4. Add `essays/<slug>/<slug>.html` to `index.ptree` if absent (after the last essay line).
5. Run `make refresh` then `make` in the `od-check` compilation buffer; stop on failure and leave the buffer visible.
6. Stage, with Magit (`magit-stage-files`): the essay folder (`support/` is ignored and cannot be staged), `index.ptree`, `refs/refs.bib`, `data/cite-cache.json`, `data/invert.json`, `data/link-meta.json`, and any new or modified `glossary/*.pm`. Refuse if `git status --porcelain` on the essay folder lists anything matching BUILD-3a (belt and braces over `.gitignore`), or if the staged diff contains `@` followed by a domain other than `occurrentdevelopment.com`.
7. Open `magit-status` with the commit message proposed via `git-commit-setup-hook` for the next commit: `Publish: <title>`. Say in the echo area: *staged; `c c` to commit, `P p` to push and deploy*.

**PUB-2 (MUST)** `od-publish` never pushes on its own. With a prefix argument (`C-u C-c o P`) it commits with the proposed message and pushes to `origin/main` in one step, after a `yes-or-no-p` that quotes the branch and remote. That is the only path that skips the Magit review.

**PUB-3 (MUST)** `od-commit` (`C-c o C`), for a change to an already-published essay: asks **Typo / Meta / Revision**; prefixes the message `[typo]` or `[meta]` for the first two (REV-1 ignores them for "last revised"); for a Revision, checks that the essay's `◊changelog{…}` (once built; until then, warns and continues) has a new line, then stages the essay folder and the caches as in PUB-1 step 6 and opens `magit-status`. Pages (`pages/*.pm`) and glossary files use the same command with the Revision choice. *2026-10-16: the caches PUB-3 stages hold only what published pages cite (SPEC CITE-5a), so staging them never carries a draft's references.*

**PUB-4 (MUST)** Refuse to run `od-publish` or `od-commit` when the current branch is not `main`, or when `main` is behind `origin/main` (fetch first, `magit-git-string "rev-list" "--count" "main..origin/main"`); say which.

**PUB-5 (SHOULD)** `od-deploy-status` (`C-c o d`): opens `https://github.com/occurrent-development/site/actions` in the browser, or, if `gh` is installed, runs `gh run watch` for the latest run in a compilation buffer and then opens the essay's URL on success. `od-publish` with the prefix argument calls it after pushing.

**PUB-6 (MUST)** Unpublishing is **not** a command. Removing an essay means editing `status` to `superseded` and committing; its source stays in history. Say this in the docstring of `od-publish`, so it isn't built later.

**PUB-7 (SHOULD)** `od-publish` prints, before staging, what will change in the index: the new row's title, date and tags, so a wrong `tags` line is caught before it reaches the home page.

**REN-1 (MUST)** `od-rename-post` (`C-c o R`), from a post: a new title, a new slug, or both. It does everything a rename touches, since a slug is more than a folder name. For a **draft**: the folder and the `.pm` file are renamed together (the build expects `essays/<slug>/<slug>.html.pm`), the draft's line in `.git/info/exclude` follows it (DRAFT-E1: otherwise the renamed folder is an ordinary untracked directory one `git add -A` away from the public repository), every `◊link` to the old URL, with or without `#id`, is rewritten across essays, blog, pages, glossary and references (never `support/`), the folder's `compiled/` cache is dropped, and the check runs. For a **published** post the same is done with `git mv`, its `index.ptree` line is rewritten, a permanent redirect `/<old> /<new> 301` is appended to `_redirects` (Cloudflare serves it, so the old URL keeps working wherever it was shared), and everything touched is staged with a `[meta]` commit proposed, so the Edited date stays (REV-1); it refuses when the post, `index.ptree` or `_redirects` have uncommitted changes, and asks before moving a published URL. The title alone changes only the meta line (and the first line of `support/notes.md` when it was the old title). `revised-date` in `pollen.rkt` now passes `--follow`, so a renamed post keeps its edit history. *Added 2026-11-03 at Ryan's request; `od-test-rename-draft` and `od-test-rename-published` cover both cases.*

---

### 9. Loading and layout

**LOAD-1 (MUST)** Files: `emacs/occurrent.el` (the mode and commands, one file, autoload cookies on every interactive command and on the mode), `emacs/occurrent-test.el` (ERT), and nothing else in `emacs/`. No `package.el` packaging; the file is loaded from the repository.

**LOAD-2 (MUST)** Setup in the user's init, documented at the top of `occurrent.el`:

```elisp
(add-to-list 'load-path "~/Documents/Ryan/Personal/Projects/Occurrent-Development/site/emacs")
(require 'occurrent)   ; adds ("\\.pm\\'" . occurrent-mode) to auto-mode-alist
```

Nothing else. `occurrent-mode-hook` is where Ryan adds `flyspell-mode`, `visual-line-mode` or whatever he likes; the mode does not turn those on itself.

**LOAD-3 (MUST)** Dependencies: Emacs 29+, Magit (soft: the `od-publish` family is defined only when `magit` is loadable, and says so if not), `citar` (soft, as now). No `pollen-mode`, no `company`.

**LOAD-4 (MUST)** Keys (the table below is current; the history follows): keep every existing binding, including `C-c o r` for `od-insert-ref`. New: `C-c o I` guide (EDIT-9), `C-c o k` check, `C-c o P` publish, `C-c o C` commit, `C-c o d` deploy status, `C-c o N` new essay, `C-c o F` figure, `C-c o B` table, `C-c o u` unwrap, `C-c o U` up. Added 2026-10-20 (EDIT-8): `C-c o Q` epigraph, `C-c o q` blockquote, `C-c o o` toggle italic, `C-c o w` wrap, `C-c o b` break, `C-c o l` list, `C-c o S` summary, `C-c o A` anchor, `C-c o M` more, `C-c o L` latex, `C-c o H` changelog, `C-c o W` embed, `C-c o <` / `C-c o >` promote / demote. Draft 1.18 (2026-11-02, evening) withdrew `od-insert-q` before it was bound; `od-insert-cite` prompts for the quotation instead (SPEC §16, BIB-9). Draft 1.19 (that night) withdrew `od-insert-more` and its key `C-c o M` (D18). The full map, as of 2026-11-02:

| Key | Command (lower case: a menu, then a choice) | Key | Command |
|---|---|---|---|
| `b` | `od-insert-block`: list, block quotation, epigraph | `C` | `od-commit` |
| `c` | `od-insert-cite` | `H` | `od-insert-changelog` |
| `d` | `od-deploy-status` | `I` | `od-guide` |
| `g` | `od-glossary`: insert term, new term, open term | `N` | `od-new-essay` |
| `i` | `od-insert-element`: section, figure, panels, table, summary, aside, margin note, break, rule | `P` | `od-publish` |
| `j` | `od-insert-tag` | `R` | `od-rename-post` |
| `k` | `od-check` | `T` | `od-set-tags` |
| `l` | `od-insert-link`: this page, this site, other site, figure or table, anchor | `U` | `od-up` |
| `o` | `od-toggle-italic` | `<` | `od-promote` |
| `p` | `od-preview` | `>` | `od-demote` |
| | *(`r` removed 2026-11-09: its choices moved into `l`; `od-insert-reference` is gone)* | | |
| `u` | `od-unwrap` | | |
| `w` | `od-wrap`: em, strong, sc, code (a toggle) | | |

Rebuilt 2026-11-03 (SPEC EMACS-7): the one-key-per-command map above it (`a e f m n q s t x A B F L Q S W`) is gone; those commands are reached through the menus, and `od-goto-section`, `od-insert-latex` and `od-insert-embed` have no key (`M-x`, `od-insert-tag` and the unbuilt tag respectively). `od-insert-changelog` is built and keeps `H`. Ryan's own `C-c e` prefix (config-08-text-editing.org) reaches the same inline and block tags in an essay as in every other text mode.

List them all in the `occurrent-mode` docstring. Reserved for Phase 3: `R` for `od-new-reference` (SPEC BIB-3), `$` for `od-insert-math` (SPEC MATH-1), and `od-insert-cite` gains the pinned-key check of SPEC BIB-2 (ask Better BibTeX at `localhost:23119`; refuse an unpinned key; warn and continue when Zotero is not running). Neither is built in this handover. Phase 4: `od-preview` with a prefix argument builds and opens the post's PDF (SPEC PRINT-7); no new key. Reserved for Phase 5: `V` for `od-insert-audio` (SPEC AUDIO-4). Free for later: `h v y z` and `D E G J K O X Y Z` (`j` went to `od-insert-tag` on 2026-10-21, for the tags with no command of their own).

**LOAD-4a (MUST) Keys from anywhere.** `od-global-map` holds the commands that make sense outside an essay: `N` new essay, `I` guide, `k` check (the full `make` when not in an essay), `d` deploy status. The user's config binds it to `C-c o` globally; inside an essay the mode's own `C-c o` keys take precedence. `od-site-directory` names the repository, so `od-root` works from a buffer outside it, dired included. *Added 2026-10-15 at Ryan's request.*

---

### 10. Tests

**TEST-1 (MUST)** `emacs/occurrent-test.el`, ERT, run by a new target `make test-emacs` (`emacs -Q --batch -L emacs -l occurrent-test.el -f ert-run-tests-batch-and-exit`). Not part of `make`, so CI does not need Emacs; CI **MAY** add it later. Cases, each a small string fontified with `font-lock-ensure` in a temp buffer:
- every tag in the vocabulary fontifies its name as markup and its body (where it has one) in the right face, including a body spanning three lines;
- `◊quote{…}`, `◊embed[…]{…}`, `◊nonsense{…}`, `◊ {`, `◊cite["k" #:page "3"]`, `◊figure["a.png" #:width "wide" …]`, `◊blockquote[#:italic "yes"]{…}`, a `◊figure` without `#:id` or `#:title`, a heading without `#:id`, a duplicate id shared by a heading and a figure, a meta value broken across lines, a `◊link["#missing"]`, a `◊ref["missing"]`, a `◊ref` pointing at a heading rather than a figure, and a `◊margin` at the end of a list item each take `od-error-face` on the right span and nowhere else;
- `◊epigraph[#:source "X" #:italic #f]{…}` and `◊blockquote[#:italic #t]{…}` take no error face;
- a paragraph containing `"quoted words"`, `[sic]`, an email address and an apostrophe has **no** string, paren or error syntax;
- `forward-sexp` and `up-list` behave as SYN-3 says, including across a nested `◊term` inside an `◊aside`;
- `fill-paragraph` on a `◊list{}` item keeps its indentation, and on a paragraph holding a wrapped `#:note` string does not join the heading below it;
- `od-unwrap` removes exactly the markup of the enclosing tag;
- every `:built t` entry in `od-vocabulary` names a `:command` that is `fboundp` and bound under `C-c o` (VOCAB-5, SPEC EMACS-6);
- `od-toggle-italic` on a plain `◊epigraph` adds `#:italic #f`, on `◊epigraph[#:italic #f]` removes it, on a plain `◊blockquote` adds `#:italic #t`, and signals outside either tag;
- `od-insert-margin` with point at the end of an item offers to move to its start and inserts after the marker when accepted.

**TEST-2 (MUST)** The VOCAB-3 sync test in `pollen-test.rkt`, run by `make test`.

**TEST-3 (SHOULD)** `od-publish` is tested against a throwaway git repo created in a temp directory with a copy of the project: it refuses on the wrong branch, refuses a `*-Notes.md` in the essay folder, writes the `index.ptree` line once, and stages the expected set of files. The `make` step is stubbed.

---

### 11. Decisions for Ryan

| # | Decision | Recommendation |
|---|---|---|
| E1 | Where drafts live (§8.2) | DRAFT-E1: inside `site/essays/`, excluded via `.git/info/exclude` until published |
| E2 | Does `od-publish` ever push on its own? | Only with a prefix argument and a confirmation (PUB-2) |
| E3 | Whether `../Essays/` (Markdown, LaTeX, Word drafts) is migrated into `essays/<slug>/` folders as DRAFT-E1 drafts | Yes, one at a time as each essay is started in Pollen; BUILD-3a already keeps the notes, `.tex` and `.docx` out of the public repo if they are moved alongside |
| E4 | Face colours | Keep to inherited faces; tune after a week of writing, not before |

---

### 12. Where to stop

Stop when: `make test` passes with the VOCAB-3 sync test; `make test-emacs` passes; the specimen page (which now uses `◊figure`, `◊table`, `◊table-csv` and `◊ref` with ids and titles), the placeholder essay, the test fixtures under `tests/` and the three glossary files open in `occurrent-mode` with nothing in `od-error-face`; inserting `◊embed[…]{…}` or `#:width` lights up; every `:built` tag has a working key under `C-c o`; and `od-publish` on a copy of the placeholder essay in a scratch clone stages the right files and stops at `magit-status`. Then report:

1. anything in §4–5 that Emacs's font-lock could not do cleanly (multi-line bodies are the likely place), and what you did instead;
2. the keystroke sequence, start to finish, for publishing a new essay;
3. the three things you'd most want decided before this is used for the first real essay.

Do not write any essay. Do not change tag functions in `pollen.rkt` except to add the VOCAB-3 test.

---

### 13. Opening prompt

> Read `SPEC.md` §3, §6, §9 (IMG-2, IMG-7), §13, §16, `emacs/occurrent.el`, and `HANDOVER-EMACS.md` in this repo. Build what `HANDOVER-EMACS.md` specifies: turn `occurrent-mode` into a major mode derived from `text-mode` with the syntax table, highlighting and editing rules in §4–6, keeping every existing command including `od-insert-ref`; add `od-check`; add the Magit publishing commands in §8 using DRAFT-E1 for drafts; add the tests in §10. Show me the vocabulary table and the syntax-propertize rules before writing the font-lock matchers. Stop as described in §12 and report.

---


## HANDOVER-PHASE2C

*Handover to Claude Code — Phase 2c: layout and popups II* (Phase 2c; file `HANDOVER-PHASE2C.md`, merged 2026-11-03)

Status: 1.0 · Owner: Ryan · 2026-10-26

Phase 2 passed Ryan's hand checks on desktop Safari, Chrome and Firefox and on iOS on 2026-10-26 (`../site-fixes.org`; Android and the Firefox no-JS check are still his). What he saw while checking became a set of changes, specified in `SPEC.md` draft 1.13 and listed by ID in the **Phase 2c** row of §15. This handover is that row, in build order, with what the spec leaves to you. Do not start Phase 3; it waits for this.

Two jobs. Job A is the site. Job B is a small Emacs job with no dependency on A; do it last, or in a parallel session on its own branch.

### Job A — The site

Read `SPEC.md` in full (it moved on 2026-10-22, 23 and 26; do not work from memory of it), then `COMPAT.md`. The measure and the margins (TYPE-1, LAYOUT-6c) are **unchanged**; Ryan considered widening both and decided against it. If a step below seems to need a wider column, you have misread the step.

Commit the uncommitted doc changes first (`SPEC.md`, `BACKLOG.md`, `HANDOVER-EMACS.md`, this file), as one commit before any code: "Spec 1.13: Phase 2c, Paper, Audio; restored hunks".

#### 1. The contents join the text block (TOC-2, LAYOUT-6, 6a, 6c, LAYOUT-1a)

- In tier XL the contents column (11em) and a `--margin-gap` are the leftmost part of the block that `.frame` centres: contents · gap · left margin · gap · column · gap · right margin, centred together. Nothing sits at the window's edge any more. The XL threshold moves accordingly; record the new tier widths on the specimen and in the colophon.
- The list starts on the **subtitle's baseline**, as does the metadata block (LAYOUT-1a revised). The title stands alone above.
- The contents **scroll with the page** and **stick** when their heading reaches the top of the window, below the sticky menu (step 2): `position: sticky` on the list, `top` = the menu's height. The heading reads *Contents* until stuck and the essay **title** (small caps, text face, wrapping) from then on; swap on a sentinel with IntersectionObserver, no animation, and swap back when the reader scrolls up past the point. The "too tall" scrolling, the ellipsis and the current-entry hairline are unchanged.
- The **Scratch** link at the foot of the list (step 5) is part of the sticky block.

#### 2. The menu and the bar (NAV-1, BAR-1, BAR-1d)

- XL: the site menu moves from the page header to the **top of the contents column** and is sticky; it never leaves the window. When the bar appears (BAR-1a, unchanged), the menu is the bar's left end and the bar's hairline runs the **full window width**, passing between the menu and the contents. Keep one element: the menu is not duplicated in XL.
- L, M, S: the menu stays in the page header; the bar gains a copy at its left end (on S the chevron and a shortened name; on touch, at the bottom, opening upward). The section name still starts at the column's left edge and the controls still end at its right edge.
- The bar's contents popup is set in the **system sans**, the same component as the contents column (LAYOUT-2a). It was serif on 2026-10-26.
- The `<details>` menu must still work without scripts in every position.

#### 3. Definitions become popups (TERM-3, TERM-7, ASIDE-3, POP-6, POP-8, D7)

- Remove the definition stubs from the right margin entirely: a `◊term` opens a popup at every tier (popin on touch), headword as title, short definition as body, **More** expanding `◊more` in place, `see-also` circles replacing the content with Back. The margin now holds aside stubs, figure words and the header block only.
- Hover previews of asides (ASIDE-3, draft 1.12) are still unbuilt: build them here. Same code path as a click; popup delay and grace; a preview is never filled; click pins.
- Update the specimen's own prose about definitions (it describes the stubs) and the Terms no-JS store is unchanged.

#### 4. Pinned popups, moving, resizing, the dock (§11.2: POP-1, POP-9, POP-10, POP-11)

- Pointer devices, tiers L and XL only. Click, Enter or **Pin** pins; up to six pinned; the seventh closes the oldest. Last-touched on top. **Esc closes the focused popup only**, returning focus to its mark if visible; no focus, no effect. Each popup has Close. Pinned popups survive scroll, theme and size changes; close on navigation and on dropping to M or S. In M, S and on touch: **no Pin button**, one popup or popin at a time, as now.
- Drag by the title bar (pointer events, clamped to the window). Resize with `resize: both`, min ~14em × 6em. Nothing persists between pages.
- **Dock** (XL only; no button in L): the space under the contents list, spanning the contents column and the left margin. Docked popups stack downward, dock-width, sticky with the contents; they may cover margin notes. Drag out to undock. Beyond the window height, the oldest closes.
- Every pinned popup is a non-modal `role="dialog"`; keep POP-3's keyboard contract for each.

#### 5. The scratch pad (POP-12)

- A **Scratch** link with a circle mark at the foot of the contents column and as the last item of the menu; absent without scripts.
- Popup titled *Scratch*, a `<textarea>` in the text face at aside size, **Copy** and **Clear** (confirmed) beneath. One pad site-wide in `localStorage` (try/catch), 64 KB cap. Opens docked in XL, pinned in L, as a popup/popin elsewhere. Nothing leaves the browser.

#### 6. Specimen, tests, checks

- THEME-7 lists what the specimen must now show: previewed and pinned asides, a definition popup with More and see-also, two pinned popups with one dragged, a docked popup, the pad with text, the contents scrolling then stuck under the menu with the title as heading, the bar with the menu at its left end.
- `make test` and `make` green. Tests for: the sentinel swap (heading text by scroll position, in a headless browser if the test harness has one; otherwise a documented manual check), Esc closing only the focused popup, the pin cap, the pad surviving a reload (localStorage stub).
- View `/specimen` in Chrome, Safari and Firefox at a **27-inch width (≥ 2,500 px)** and at XL, L, M and S, both themes. The 27-inch view is the one Ryan complained about: there must be no gap between the contents and the margin notes. Fix what you see.

#### 7. Stop and report

What you built; anything you could not satisfy as written and what you did instead; the new tier thresholds; and screenshots of `/specimen` at ≥ 2,500 px (top of page, and scrolled with the contents stuck and the title as heading), of the bar at XL with the menu at its left end, of three pinned popups with one docked, and of the scratch pad. Ryan does the phone checks.

Do not touch `emacs/` in this job. Do not begin Phase 3 (backlinks, changelog, glossary page, reference pages, feed, correspondence, Wayback), Phase 4 (print, PDF) or Phase 5 (audio).

### Job B — Emacs docstrings

`emacs/occurrent.el`: every interactive command has a docstring; 31 private `od--` helpers and the constants `od--heading-re`, `od--paragraph-start`, `od--paragraph-separate`, `od-syntax-table` and `occurrent-mode-map` do not. Add one sentence each, saying what the function returns or does and which SPEC or HANDOVER-EMACS ID it serves; run `checkdoc` on the file and fix what it reports; `make test-emacs` green. No behaviour changes. Forward declarations (`(defvar citar-bibliography)` and the like) are left alone.

### Opening prompt

> Read `HANDOVER-PHASE2C.md` in this repo and do Job A as written: read `SPEC.md` (draft 1.13) and `COMPAT.md`; commit the pending doc changes; build the Phase 2c row of SPEC §15 in the order the handover gives (contents into the text block, menu and bar, definitions to popups with aside hover previews, pinned popups with drag, resize and dock, the scratch pad, the specimen); get `make` green; check `/specimen` in three browsers at a 27-inch width and at the four tiers; and stop with the report it asks for. Then, after I have looked, do Job B.

---


## HANDOVER-PHASE3

*Handover to Claude Code — Phase 3: around the essays* (Phase 3; file `HANDOVER-PHASE3.md`, merged 2026-11-03)

Status: 1.0 · Owner: Ryan · 2026-11-02

Phase 2c landed and passed Ryan's checks (`reports/2026-10-26-phase2c/`). This handover is the **Phase 3** row of `SPEC.md` §15 (draft 1.16), in build order, with what the spec leaves to you. Phase 3 is the apparatus *around* an essay: the link graph and everything built from it (backlinks, the glossary page, reference pages, the bibliography), the changelog, the feed, the Wayback job, and inline mathematics. Nothing in the text of an essay changes except for two new ways of writing a citation (BIB-9).

Read `SPEC.md` in full first; §5a was rewritten on 2026-11-02 (BIB-1, BIB-5…9), and §3.3, CITE-8, IMG-6, POP-7, §16 and §17 changed with it. Then `COMPAT.md`. Do not work from memory of earlier drafts.

Three jobs. **Job A** is the site and is the bulk of the work. **Job B** is mathematics, independent of A, with a TeX dependency Ryan must install first; do it after A, or in a parallel session on its own branch. **Job C** is Emacs; do it last, after Ryan has looked at A. **Job D**, panel figures (IMG-9), was added on the afternoon of 2026-11-02 with spec draft 1.20: independent of A and B, after A.

Commit the uncommitted doc changes first (`SPEC.md`, `HANDOVER-EMACS.md`, this file), as one commit before any code: "Spec 1.16: Phase 3 handover; covers, reference cards, quotations (BIB-7…9)".

### Before you start (Ryan's part)

Two things only Ryan can do, and the build depends on both:

1. **Pin the keys.** Every key cited by a published post, or by the draft you will test with, is pinned in Zotero (BIB-2). For the test: `pirsigZenArtMotorcycle1991` (his 1991 Vintage copy; the page numbers are that edition's).
2. **One cover in Zotero.** A photograph of the Pirsig copy's cover, attached to the item as a stored file named `cover.jpg` (BIB-7), so that `make refresh` has something to find and the first end-to-end check is real. Confirm the path appears in `~/Documents/Ryan/References/Zotero-Library.bib` under that entry's `file` field; if Better BibTeX's auto-export did not pick up the new attachment, export once by hand.

Tests must not depend on either: fixtures carry their own small cover and their own `.bib`.

### Job A — The site

#### 1. The link graph (VAL-2, VAL-4, BIB-6, TERM-8's Used in, KIND-5)

Everything else in this job reads one file, so build it first and build it once.

- `tools/validate.rkt` (or a pre-pass in `pollen.rkt`; your call, but one walk) records, for every published post of both kinds: every internal link with its context; every `◊cite` with its context; every quotation (step 2) with its text, locator, section and mark id; and which pages mark each glossary term. Write `data/links.json` in a shape that carries links per page, cites and quotations per key, and terms per page. `data/anchors.json` as now.
- Context = the containing paragraph, list item or aside, as an X-expression with the link or circle marked, so the Backlinks and Cited in lists can render it with the site's own markup (collapsed to ~2 lines, expandable).
- BUILD-4 holds: `make` is a full rebuild; the project server may show stale lists. Say so in the README if it does not already.
- Drafts (DRAFT-2) contribute nothing to the committed graph, exactly as CITE-5a keeps their citations out of the committed cache. Decide how the local build previews a draft's own backlinks and reference pages (a merged local graph, as the caches merge) and document it.

#### 2. Quotations (BIB-9, §3.3, CITE-8)

- `◊q["key" #:loc "…"]{text}`: a `◊cite` with the quoted text attached. Quotation marks from the typography pass (TYPE-16; nested quotation takes single marks), then the circle; MARK-3a puts the closing mark and any punctuation between the last word and the circle. Numbered, formed and back-linked exactly as a `◊cite`. `◊em` and `◊sc` inside; `◊cite`, `◊term`, `◊aside`, `◊link`, `◊margin` and an empty body are build errors with messages that name the rule.
- `#:cite` and `#:loc` on `◊blockquote` and `◊epigraph`: the circle follows the `#:source` line, or stands alone on that line when there is none. `#:loc` without `#:cite` is a build error.
- The walk records each quotation's plain text (markup dropped), locator, post, section and mark id. A quoting citation is also a Cited in context; do not de-duplicate.
- Fixture: extend the CITE-8 essay in `tests/` with one `◊q` and one `◊blockquote` with `#:cite`; assert numbers, forms, back-links and the Quoted list.

#### 3. Covers from Zotero (BIB-7, IMG-1, IMG-4, IMG-6)

- `tools/refs.py`, at `make refresh`: for every cited key, read the `file` field of the Zotero export (absolute paths, `;`-separated; the parser is already there), take the image attachment named `cover.*`, or the only image attachment; two or more images with none named `cover` is an error naming them; HEIC is an error asking for a JPEG export. Write `refs/covers/<key>.jpg`, longest side 800 px (Pillow), committed. Delete the copy with a warning when the attachment is gone. The `file` field is still stripped from `refs.bib`.
- `tools/images.py` makes variants at 160, 320, 640 and manifest entries for `refs/covers/*`. Covers are never sent to InvertOrNot; dimmed in dark mode, never inverted (a fixed classification, not a lookup).
- `#:licence cover` is accepted by the figure machinery only where the build itself emits a cover; an author writing `◊figure[… #:licence "cover"]` is a build error (the value exists for one thing).
- Fixture: a 100 × 150 px cover in `tests/` and a fixture `.bib` with a `file` field pointing at it; a test that the refresh step copies and sizes it, and another that an entry with no image attachment yields no cover and no error.

#### 4. Reference pages, the card, and the note popup (BIB-1…3, BIB-5, BIB-8, POP-7, CITE-10)

- `/references/<key>` for every key in the cache: entry with the cover at its left (about 7em tall, top-aligned); DOI and URL as external links with ↗ (and the Wayback copy once step 8 records one); the commentary from `references/<key>.pm` when present (BIB-3: paragraphs only, the allowed inline tags, citations unnumbered per CITE-7; anything else a build error; a file whose key is not in the cache a build error); **Quoted** grouped by post in index order, each passage in the text face with its locator muted after it and a → to the mark; **Cited in** as Backlinks are rendered. The page uses the site template (menu, bar, themes, text size); its title is the work's title, its header carries no dates or tags, and its margin block holds only the source links (REV-2) pointing at `references/<key>.pm` when it exists and nothing otherwise. Reference pages are not listed in any index or feed.
- `/_x/references/<key>.frag`: the reference card. Cover, entry, DOI/URL, the first paragraph of the commentary, and the line *Cited in n posts · Reference page →*. One function renders the card for the fragment and for the page's head.
- The note popup: note as now; a hairline; the card, fetched on `pointerenter` and cached as cross-essay fragments are. Under a full-form note the card omits the entry; under a short-form note it shows it. Title bar: the title links to the reference page and Open in new tab goes there (BIB-5). Touch: the popin shows the same card. No script, no change.
- Per-essay Notes and Bibliography: each work links to its page with → (BIB-5). End matter order per CITE-10, now with **Backlinks** (step 5) in its place.
- `references` and `_x` are reserved slugs already (KIND-1); check that `_redirects` and the Worker serve `/references/<key>` with the key's case preserved (BIB-2).

#### 5. Backlinks (VAL-4)

Each post ends with **Backlinks** between Bibliography and Changelog: the linking posts and sections, each context collapsed to ~2 lines and expandable, kind marked for entries (KIND-5). Same-page links are not backlinks. The expand control works without scripts (`<details>`), as the menu does.

#### 6. The glossary page and the bibliography (TERM-8, BIB-4, NAV-1)

- `/glossary`: every term alphabetically, with aliases, short definition, `◊more`, see-also as same-page links, **Used in** from the graph, anchors `#<id>`. Essays never link here (TERM-3).
- `/bibliography`: one `◊table` through the shared table code (INDEX-1a): Author · Year · Title · Type · Cited in, sorted by author then year, title → the work's page, Cited in a count. No covers here (BIB-7).
- Menu order: Home · Essays · Notebook · Glossary · Bibliography · Scratch, in the one list in `pollen.rkt`.

#### 7. Changelog (REV-3, KIND-2, §16)

`◊changelog{…}` renders in the end matter after Backlinks; `/changelog` aggregates every line site-wide, newest first, each with its post. A `◊changelog` in an entry is a build error. Unblock `od-insert-changelog` is Job C's; here, make the tag.

#### 8. Feed, Wayback, the dead-link job (REV-4, CARD-3, CARD-5)

- One Atom feed, `/feed.xml`, both kinds, each item marked with its kind; new posts and substantive revisions (a changelog line dated after `published`). An essays-only feed MAY exist; do it only if trivial. `<link rel="alternate" type="application/atom+xml">` on every page. Validate with the W3C feed validator and record the result in the report.
- `make refresh` asks the Wayback Machine to save each external URL not yet in `data/link-meta.json` and records the snapshot URL; cards and reference pages show **Wayback copy** where one exists. Never from `make`; never from the reader's browser.
- A monthly GitHub Actions job re-checks live URLs and opens an issue listing dead ones; it never fails a build. Marking a link dead is a one-field edit in `link-meta.json`.

#### 9. Specimen, tests, checks

- The specimen (THEME-7) gains: an inline `◊q`, a block quotation with `#:cite`, a note popup showing a card with a cover (use the Pirsig item once Ryan has attached it; otherwise the fixture cover, and say so), and a Backlinks section with one real entry.
- `make test` and `make` green, with the new tests above and the VOCAB-3 sync test still passing once Job C lands (`q` is a built tag then).
- Budgets (§14) hold: the card adds no page weight; measure the JS delta and report it.

#### 10. Stop and report

What you built; anything you could not satisfy as written and what you did instead; the shape of `links.json`; screenshots of `/references/pirsigZenArtMotorcycle1991` (or the fixture work) with cover, Quoted and Cited in, of a note popup with the card in light and dark, of `/bibliography`, `/glossary` and a Backlinks section; the feed validator's result. Write it to `reports/<date>-phase3/REPORT.md` beside the earlier reports. Ryan does the phone checks.

Do not begin Phase 4 (print, PDF) or Phase 5 (audio).

### Job B — Inline mathematics (MATH-1, §16)

Needs LuaLaTeX, `unicode-math`, Libertinus Math and `dvisvgm` on Ryan's Mac (he installs them; say exactly what, in the report, if anything is missing). `◊m{…}`, pre-rendered at `make refresh` to `currentColor` SVG with its baseline offset, cached in `data/math-cache.json` by SHA-256, inlined at build only on pages that use it; a missing cache entry fails the build with "run `make refresh`". `#:display #t` centres on its own line. MARK-2's test applies to an ordinary inline expression. `make` stays TeX-free (BUILD-2). Specimen: one inline expression in body text, one in italic, one display. Stop and report as for Job A.

### Job D — Panel figures (IMG-9, §3.3, VAL-1, §16)

*Added 2026-11-02 (afternoon), spec draft 1.20; revised that evening, draft 1.21: `#:columns` takes 1, 2 or 3, and 1 is a vertical stack.* Independent of A and B; do it after A, on its own branch if in parallel. `◊panels{…}` and `◊panel[src]{…}` in `pollen.rkt`, with a `make-panels` beside `make-figure` in `lib/figures.rkt` that lifts the panels from the body, reuses `picture` and `inline-svg` per panel, puts `data-invert` on each panel, and hands `make-exhibit` one body; letters A–F by the root pass's numbering, never in the source; `◊ref`'s `#:panel`; the build errors VAL-1 lists; the grid, the letters above the top-left corners and the stacking below tier M in `site.css`; one line in the lightbox so the grid keeps its width on the stage; `tools/images.py` scanning `◊panel` sources. Specimen: one `◊panels` of a photograph, a PNG line drawing and an SVG, with a `◊ref` to B in the text, checked in both themes and at tiers L and S. Then `od-insert-ref` offering `id#b` (Job C, if it has not run). What the spec leaves to you: the gap between panels and the letter's exact size and offset, both settled on the specimen and recorded in the CSS comment.

### Job C — Emacs (§16, HANDOVER-EMACS.md)

After Ryan has looked at Job A. `od-new-reference` (`C-c o R`); `od-insert-q` (`C-c o "`, the region as the body, key picked as `od-insert-cite` with the pinned-key check, then the locator, a warning when none); `od-insert-blockquote` and `od-insert-epigraph` prompting for a key (empty for none) and locator; `od-insert-math` (`C-c o $`) once Job B lands, else a `user-error`; `od-insert-changelog` unblocked; `od-file-kind` gains `reference`; `od-vocabulary` gains `q`, `m`, `changelog` as `:built` when they are, and the new keywords, so the highlighter accepts them (FL-6) and the sync test holds (VOCAB-3). `make test-emacs` green; `checkdoc` clean.

### Opening prompt

> Read `HANDOVER-PHASE3.md` in this repo and do Job A as written: read `SPEC.md` (draft 1.16) and `COMPAT.md`; commit the pending doc changes; build the Phase 3 row of SPEC §15 in the order the handover gives (link graph, quotations, covers, reference pages and the card, backlinks, glossary and bibliography pages, changelog, feed and Wayback, specimen); get `make` green; and stop with the report it asks for. Then, after I have looked, Job B and Job C.

---


## HANDOVER-PHASE3B

*Handover to Claude Code — Phase 3b: the reference card, in fields* (Phase 3b; file `HANDOVER-PHASE3B.md`, merged 2026-11-03)

Status: 1.0 · Owner: Ryan · 2026-11-02 (evening)

Phase 3 Job A landed (`reports/2026-11-02-phase3/`, commits `f994d32` and `c7ca1a3`). Ryan looked at the note popup and the reference page and changed his mind about their shape, and about how a quotation is written. `SPEC.md` draft 1.18 records it: BIB-1, BIB-6…9 rewritten, BIB-10 new, §3.3, CITE-8, POP-7 and §16 revised; `STYLE.md` and `HANDOVER-EMACS.md` follow. This handover is those changes in build order. Nothing in Phase 3 outside §5a is touched.

Read the 1.18 text of §5a, §3.3 (`◊cite`, `◊blockquote`, `◊epigraph`), CITE-8, POP-7 and §16 before starting; do not work from the 1.16 text or from the code as built. Commit the uncommitted docs first, in one commit: `SPEC.md`, `STYLE.md` (new, Ryan's manual of style, which SPEC line 9 already names; §17 moved into it), `HANDOVER-EMACS.md`, this file: "Spec 1.18: cite with a body, the fields head, one Cited in; STYLE.md".

### What changed, in one paragraph

A `◊cite` with a body is a quotation of those words; `#:block #t` makes it a block quotation whose attribution the build writes from the entry. `◊q` and `#:cite`/`#:loc` on `◊blockquote` and `◊epigraph` are withdrawn. The reference page's head and the card are no longer a Chicago entry but the title, the cover at its right at 14em, and labelled fields at one tab stop, from a CSL record that `make refresh` stores. The citation popup is the card alone, with the citation's locator and remark slotted under the title; the Chicago note is only the fetch-failed fallback. Quoted and Cited in are one list.

### Job A — The site

#### 1. `◊cite` with a body; the withdrawals (BIB-9, §3.3, CITE-8)

- `◊cite["key" #:loc "…"]{words}`: what `◊q` did, under the citation's own name. Keep the TYPE-16 handling (nested quotation → single marks), MARK-3a, the numbering and the back-link; the build errors for `◊cite`, `◊term`, `◊aside`, `◊link`, `◊margin` inside and for an empty body, now naming BIB-9 in its 1.18 wording.
- `#:block #t`: rendered as `◊blockquote` is (same markup and classes, LAYOUT-4b; `#:italic #t` as there), with an attribution line the build writes: *Given Family, Title, p. n*, author and locator omitted when absent, the circle at the end of the line. `#:source` replaces the generated line. `#:block`, `#:italic` or `#:source` on a `◊cite` with no body is a build error.
- Remove `◊q` and the `#:cite`/`#:loc` keywords from `◊blockquote` and `◊epigraph` entirely (not deprecated: nothing published used them). Update the specimen, the CITE-8 fixture (a body cite as note 6, a block cite as note 7, same numbers as before), `od-vocabulary` and the VOCAB-3 sync test, and the highlighter's keyword table (FL-6).
- The pre-pass records a body cite's text and `block?` on the citation record; drop the separate quotation records and whatever read them.

#### 2. The CSL record and the bigger cover (BIB-10, BIB-7)

- `tools/refs.py`: run `pandoc <bib> -t csljson` once over the cited entries (committed and local alike) and store each work's CSL JSON under `csl` in the matching cache. Derive the existing `title`, `authors`, `year`, `type` from it rather than from regexes, so there is one parse.
- Covers: the committed copy's longest side becomes 1200 px; variants 160, 320, 640, 960. Re-run on the Pirsig photograph (it is in `~/Zotero/storage/`, the refresh finds it).

#### 3. The head and the card (BIB-10, BIB-7, BIB-8)

- One function, as now, renders the head for the page and the card for `/_x/references/<key>.frag`: title (sans, level-2 size in the card; the page title on the page), cover at the right, 14em tall, top on the title's top; the `<dl>` beneath the title at its left; then the field list.
- Fields per type from the BIB-10 table, mapped from CSL variables; names *Given Family* joined with commas and *and*; plural labels for several editors or translators; DOI and URL as ↗ links, Archive after them. Empty fields omitted. The `<dl>` is a two-column grid, `max-content 1fr`, labels muted, values in the text colour, lining figures where BIB-10 says. One gap token; tune it on the specimen so the tab stop reads as one.
- The card also carries the commentary's first paragraph (keep it; Ryan wants to see it) and the *Cited in n posts · Reference page →* line.
- Remove the Chicago entry from both; `bib-entry` stays for the References list, the per-essay Bibliography and `/bibliography`.

#### 4. The popup (BIB-8, POP-7)

- A citation's popup is the card: title bar *Reference n*, then the fetched card with the citation's locator (*Page 325*, *Pages 31–34*, *Chapter 3*; write out the abbreviations `p.`, `pp.`, `ch.`, `§`; anything else verbatim) and its `#:note` remark, italic, inserted under the title before the fields, each omitted when absent. The circle carries `data-loc` and `data-note`. Shared circles (MARK-1c) show one card per item, separated by a hairline as now.
- If the fragment fetch fails, show the References entry as before Phase 3. No hairline, no note text, when the card is present.
- Touch: the popin is the same card. Check that a 14em cover plus fields plus a paragraph fits the popin's 60% cap with scrolling, and that the popup grows to its ~70% cap before scrolling.

#### 5. One Cited in (BIB-1, BIB-9)

- Remove Quoted. Cited in: grouped by post in index order, then by position; the section named once at the head of each run of entries in it; each entry the locator (muted) then either the passage in full (a body cite) or the context clamped to ~2 lines with More (a bare cite), and a → to the mark. Entries that share a paragraph are listed once: one context, then each citation's locator and arrow together. This also removes the triple entry the Phase 3 report noted on `/references/hackingMakingPeople2006`.

#### 6. Emacs: `od-insert-cite` (§16)

Do this here rather than waiting for Job C, since it is how every citation will be written from now on. `C-c o c`: pick the key (pinned check as now), then prompt in turn, each skipped with Enter: locator; kind (*reference* / *quotation* / *block quotation*, default *quotation* with an active region, *reference* without); remark; for a block, italic or roman. Write `◊cite["key"]`, `◊cite["key" #:loc "…"]{region}` or `◊cite["key" #:block #t #:loc "…"]{region}` on its own lines with blank lines either side; with no region and a quotation kind, leave point inside the braces. Warn in the echo area when a quotation has no locator. `od-insert-blockquote` and `od-insert-epigraph` lose the key prompt Phase 3 gave them. `make test-emacs` green.

#### 7. Checks and report

- `make test` and `make` green; the new CITE-8 assertions; a RackUnit test that a book, an article and a chapter from the fixture `.bib` produce exactly the BIB-10 fields in order with the empty ones absent.
- Screenshots: the Pirsig popup in light and dark with the cover, the locator and the commentary paragraph; `/references/pirsigZenArtMotorcycle1991` top of page; the same page's Cited in; a phone-width popin of the same card. Write `reports/2026-11-02-phase3b/REPORT.md`.

Do not begin Job B (maths) or the rest of Job C.

### Opening prompt

> Read `HANDOVER-PHASE3B.md` in this repo and do Job A as written: read the draft 1.18 text of `SPEC.md` §5a, §3.3, CITE-8, POP-7 and §16; commit the pending doc changes including `STYLE.md`; build the seven steps in order (cite with a body and the withdrawals, the CSL record and the 1200 px cover, the fields head and card, the popup as the card, one Cited in, `od-insert-cite`'s prompts, checks); get `make` green; and stop with the report it asks for.

---


## HANDOVER-PHASE3C

*Handover to Claude Code — Phase 3c: the glossary, senses, and the front page* (Phase 3c; file `HANDOVER-PHASE3C.md`, merged 2026-11-03)

Status: 1.0 · Owner: Ryan · 2026-11-02 (night)

Ryan reviewed the built glossary page after Phase 3 and asked for four things on it, then two changes to the site's structure. `SPEC.md` draft 1.19 records them: TERM-2 and TERM-8 rewritten, TERM-9 new, TERM-3, TERM-4, CITE-10, VAL-2, PRINT-3 touched; §13a restructured (HOME-1 rewritten, ABOUT-2 restored, NAV-1); §13b and D13, D14 renamed; D18 new; §16 revised; a Phase 3c row in §15. This handover is those changes in build order. Start only after Phase 3b has landed (`HANDOVER-PHASE3B.md`): both touch `site.js`'s popups and `links.json`.

Read the 1.19 text of §6, §13a, §13b, CITE-10, VAL-2 and §16, and D13, D14 and D18, before starting; do not work from the 1.18 text or from the code as built. Commit `SPEC.md` and this file first, in one commit: "Spec 1.19: senses, the More, Used in as backlinks; Blog; the front page".

### What changed, in one paragraph

A term file is a definition followed by its More, with no tag to mark the More: everything after the first paragraph is it (before this, a second plain paragraph was read into an unused field and silently dropped, D18). A `◊term` may carry a `◊sense{…}`, the page's own gloss on its use of the term, which the popup shows in italic between the definition and More and which the glossary page shows under that post in Used in, so Used in becomes the term's backlinks, as a list. The glossary page loses its Bibliography and gains its place in the menu. The notebook is renamed the blog, folder, URLs, index, menu and docs. The home page becomes a front page, one paragraph and two columns of recent posts, and About goes back to `/about`.

### Job A — The glossary

#### 1. The More is the rest of the file (TERM-2, D18)

- `lib/glossary.rkt`: `'more` is every element of the body after the first paragraph; drop `'rest` and the `od-more` partition. Delete `◊more` from `pollen.rkt` (the tag, its `forbid` in `page-root`, the `"a definition"` branch in the context names), from `od-vocabulary` and the VOCAB-3 sync test, from the highlighter's table (FL-6), and `od-insert-more` with its key from `occurrent.el`, its tests and `HANDOVER-EMACS.md`. Not deprecated: nothing published used it beyond the three term files.
- Unwrap `glossary/occurrent.pm` (the one file with a `◊more`): the paragraph stands on its own after the definition. `continuant.pm` and `looping-effect.pm` are unchanged.
- `glossary-root` already refuses headings and asides; add lists, figures, tables and margin notes, naming TERM-2.
- A RackUnit test: a fixture term with three paragraphs and no tag yields a one-paragraph definition and a two-paragraph More; one with a single paragraph yields no More.

#### 2. `◊sense` (TERM-9)

- `pollen.rkt`: `(define (sense . xs) (txexpr 'od-sense null xs))`. In `term`, partition the children: at most one `od-sense`, the rest the text; the text must not be empty once the sense is lifted; forbid `od-term`, `od-aside`, `od-margin` inside the sense and allow `od-em`, `od-cite`, `od-link`. Keep the sense on the `od-term` as a child under its own tag, not as an attribute (it carries markup). A `◊sense` reaching `root` outside a `◊term` is a build error ("◊sense belongs inside ◊term (TERM-9)"), as is a second sense for the same term on one page, and a sense on an occurrence that is not the page's first use of the term (the one with the circle).
- The walk that builds the Terms section (TERM-4) stores each page's senses by id. The entry gains, after `p.definition` and before `div.term-more`, `<p class="term-sense"><span class="sense-label">In this essay:</span> <em>…</em></p>`, the label by the page's kind (*In this entry:* for a blog entry). Inside the `<em>`, `◊em` flips to roman (LAYOUT-4c already does this for epigraphs; reuse it). A citation inside a sense is numbered and resolved like any other on the page (LAYOUT-1's rule for the abstract).
- `site.js` `termItem()`: append `.term-sense` after the definition and before the More button, so the order is title · definition · sense · More · see-also. CSS: `.popup .term-sense` and `.terms .term-sense` share one rule, the label muted and roman, the text italic, no extra margin above the More button.
- `tools/validate.rkt` / `lib/graph.rkt`: `links.json`'s record of a page marking a term gains the sense as an HTML string, absent when there is none (VAL-2).
- The specimen: give one term a sense (`looping effect` suits: "In this essay, the narrow case of a diagnostic label changing the child it is given to."). Keep the TERM-5 sentence about repeated terms true.
- Emacs (§16): `od-insert-term` with a prefix argument writes `◊term["id"]{region ◊sense{}}` and leaves point inside the sense; `user-error` when the buffer already has a `◊sense` for that id. Add `◊sense` to `od-vocabulary` (allowed inside `◊term` only), the highlighter (FL-6) and the VOCAB-3 test. `make test-emacs` green.
- Browser test (`tests/browser/harness.js`): opening the specimen's sensed term shows the five parts in order; opening a term without a sense shows no `.term-sense`; on a page that marks the same term without a sense (the placeholder essay can mark it) the popup has none.

#### 3. Used in as backlinks; no Bibliography; the menu (TERM-8, CITE-10, NAV-1)

- `glossary-list` in `pollen.rkt`: Used in becomes `<ul class="used-in">`, the label *Used in* as a muted line above it or as the list's first words (choose on the page; the aside-size muted style of the See also line either way); each `<li>` the post's title as a cross-essay link with its → mark, then the kind label, then, when `links.json` has a sense for that post and term, `<span class="sense"><em>…</em></span>` on its own line inside the item, no bullet, no gap (`display: block`), the `◊em` flip as in §2. Order: the index's.
- The glossary page emits no end matter: nothing after the last entry. The simplest route is a page-level switch the glossary and home pages set (`◊define-meta[endmatter]{none}` is one shape; a check in `page-root` on the page's path is another; choose the one the code already leans to). Citations inside definitions keep their circles as CITE-7 says; confirm that without scripts an unnumbered circle links to `/references/<key>` and that with scripts its popup is the reference card (Phase 3b's). Remove the glossary page's `◊break{}` if the end matter's absence leaves it reading as a trailing rule.
- NAV-1: add **Glossary** to the menu list in `pollen.rkt` after Blog (it was in the spec from 2026-10-15 and never built); `aria-current` on `/glossary`.
- Screenshot `/glossary` in both themes at tiers L and S.

### Job B — Blog, the front page, About

#### 4. Notebook → Blog (§13b, D13, D14)

- `git mv pages/notebook.html.pm pages/blog.html.pm`; `index.ptree`; the folder `blog/` (no `notebook/` folder exists yet; create `blog/` with its gitignore rule `blog/*/support/`, and drop `notebook/*/support/`); the Makefile's `find … notebook`; `post-kind` and every path test in `pollen.rkt`, `lib/graph.rkt`, `tools/validate.rkt`, `tools/*.py`, `_x/blog/`, the PDF paths (PRINT-2), the feed; the menu item **Blog**; the kind label a reader sees becomes *blog* (`kind-label`), the internal value stays `entry` and the class `kind-entry` (§13b); the reserved-slug list gains `blog` and keeps `notebook`; `od-new-essay`'s folder, the Blog heading in `od-insert-link-essay`, `od-file-kind`'s path test; the index page's placeholder paragraph says *blog*. Then the docs: `README.md`, `STYLE.md`, `HANDOVER-EMACS.md`, `BACKLOG.md` wherever they say notebook, except in dated history. No redirect: nothing was published under `/notebook`.
- `make test`: the INDEX-1a fixture test for the entry index still passes under the new name.

#### 5. About back to `/about` (ABOUT-2)

- `git mv pages/index.html.pm pages/about.html.pm`; title stays *About*; uncomment and keep the Start-here line at the end (it may name the placeholder until a real opener exists); delete the commented `◊latest[3]`; remove the `/about → /` line from `_redirects` (leave the file's other lines). `index.ptree`. The essays page's "read more about me, and this website ◊link["/"]{here}" becomes `◊link["/about"]`.

#### 6. The front page (HOME-1)

- New `pages/index.html.pm`: `◊define-meta[title]{Occurrent Development}`; one paragraph by hand, which Ryan will rewrite, for now: *Essays and shorter pieces on the philosophy and practice of developmental paediatrics, written by a clinician in Sydney who thinks the field's working paradigm is misaligned with what clinicians claim to do and what families come for. More ◊link["/about"]{about me and this site}.*; `◊break{}`; `◊recent[3]`.
- `◊recent[n]` in `pollen.rkt`, next to `◊index`: reads the same metas (DRAFT-2, `published`), sorts newest first, takes `n` per kind; emits `<div class="recent"><section class="recent-essays"><h2>Essays</h2><ul>…</ul><p class="all"><a …>All essays</a></p></section><section class="recent-blog">…</section></div>`, each `<li>` the title as a cross-essay link (reuse `with-mark … 'xref` and `post-title` as `glossary-list` does) and the short date on the next line in `.date` muted (INDEX-2's `9 Oct 2026`); *Nothing yet* in muted when a kind has no posts. Remove `◊latest`. The `h2`s go through the heading pipeline so they take the site's level-2 style but are **not** contents entries (the page has no contents, TOC-1).
- CSS: `.recent` a grid of two equal columns with the gap token the figure grids use; `@media` at tier S one column, Essays first. The page's title is not shown in the column (the menu's site name is the title); the metadata block holds only the source links; no end matter (§3's switch).
- A RackUnit test renders `◊recent[3]` from fixtures (four essays, no entries) and asserts three essay items newest first, their dates, and the Blog column's *Nothing yet*.

#### 7. Checks and report

- `make test`, `make`, `make test-browser`, `make test-emacs` green.
- Screenshots: the specimen's sensed-term popup in light and dark, and the same on a phone-width popin; `/glossary` at tier L showing Used in with the sense and no Bibliography, and at tier S; `/` at tier L (two columns) and at tier S (stacked); the menu open, reading Home · About · Essays · Blog · Glossary · Bibliography · Scratch; `/about` with its Start-here line.
- Write `reports/2026-11-02-phase3c/REPORT.md`: what was built, what the spec left open and how it was decided (the Used in label's placement, the end-matter switch's shape), anything that reads badly on the page.

Do not begin Job B (maths) of `HANDOVER-PHASE3.md` or the rest of its Job C.

### Opening prompt

> Read `HANDOVER-PHASE3C.md` in this repo and do it as written: read the draft 1.19 text of `SPEC.md` §6, §13a, §13b, CITE-10, VAL-2, §16, D13, D14 and D18; commit the two docs; build the seven steps in order (the More as the rest of the file, `◊sense`, Used in as backlinks with the glossary's end matter suppressed and Glossary in the menu, Notebook → Blog, About back to `/about`, the front page with `◊recent`, checks); get `make` green; and stop with the report it asks for.

---
