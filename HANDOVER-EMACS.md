# Handover to Claude Code — Emacs

Status: draft 1.2 · Owner: Ryan · 2026-10-15 (revised the same day for IMG-7: figure and table ids, titles and `◊ref`; and again for the per-essay `support/` folder)

Read `SPEC.md` §3 (authoring format), §6 (glossary), §13 (revisions), §16 (Emacs) and `emacs/occurrent.el` first. This file specifies two things on top of what exists: a **major mode** for the site's Pollen dialect, with syntax highlighting that catches build errors before `make` does, and **publishing from Emacs with Magit**. Requirements carry IDs so commits and tests can reference them. **MUST** = required; **SHOULD** = expected, may slip; **MAY** = optional.

When this is built, fold the new IDs into `SPEC.md` §16 and point it here for detail; do not duplicate the text.

---

## 1. What already exists

| Thing | State |
|---|---|
| `emacs/occurrent.el` | A **minor mode**, `occurrent-mode`, meant to sit on top of some major mode for `.pm` files. Pickers for cites, terms, links, sections, tags and (since 2026-10-15) figure/table references (`od-insert-ref`, `C-c o r`, reading `#:id`/`#:title` from `◊figure`, `◊table` and `◊table-csv` in the buffer); `imenu`; `outline-minor-mode`; three font-lock rules that dim `◊name`, `#:keyword` and brackets; `fill-paragraph` protection for `◊define-meta` lines (SRC-4); `od-preview` via `make serve`; the macOS Option-key fix (EMACS-1). Keys under `C-c o`, lozenge on `C-c ;`. |
| Major mode | None of ours. The comment in `occurrent.el` assumes `pollen-mode` from MELPA (`lijunsong/pollen-mode`, v1.0, LGPL). |
| Build | `make` (tests, fonts, render, validate, assemble `public/`), offline. `make refresh` is the only networked step (Zotero export → `refs/refs.bib`, pandoc → `data/cite-cache.json`, InvertOrNot → `data/invert.json`). |
| Deploy | Push to `main` on `github.com/occurrent-development/site` → GitHub Actions builds and deploys to the Cloudflare Worker. Other branches build but do not deploy. Nothing generated is committed. |
| Drafts | SPEC DRAFT-1 says: private repo or a never-pushed branch. A private `drafts` repo exists on GitHub but has **no local clone**; the current draft material lives outside git in `../Essays/` as Markdown, LaTeX and Word files. DRAFT-2 (the build publishes only `status` ≠ `draft`) is built and tested. |
| Commit identity | Per-repo `Ryan Lucas <ryan@occurrentdevelopment.com>`. Never commit another address (HANDOVER §7). |
| Tags actually provided by `pollen.rkt` | `section subsection subsubsection summary em strong sc code blockquote epigraph br anchor break link cite term aside margin more list table table-csv sort-key figure ref essay-index header-sample` plus `define-meta` (Pollen's own). `essay-index` belongs only on the home page and `header-sample` only on the specimen (both added to VOCAB-1 with an `:only` file kind; MODE-3 gained the kinds `home` and `specimen`). **`embed` and `changelog` are in SPEC §3.3 but not yet built**; using them is a build error today. |
| Figures and tables (IMG-7, IMG-2, 2026-10-15) | `◊figure`, `◊table` and `◊table-csv` **require `#:id` and `#:title`**; the build numbers them (Figure 1, Table 1) and `◊ref[id]` prints the label as a same-page link. **`#:width` is a build error** (every figure and table is column width; the reader has an Expand button). The exhibit frame lives in `lib/exhibits.rkt`. |
| Error format | `build error: <path relative to root>: <message>` on stderr (`lib/util.rkt`); no line numbers. `tools/validate.rkt` prints the same prefix for site-wide checks. |

---

## 2. The decision: a major mode of our own, not a layer on `pollen-mode`

**MODE-1 (MUST)** `occurrent-mode` becomes a **major mode** derived from `text-mode`, replacing the minor mode. Every existing command, key, the `imenu` and `outline` setup, the fill protection and the Option-key fix carry over unchanged. `auto-mode-alist` maps `\.pm\'` to it.

**MODE-2 (MUST)** `pollen-mode` is **not** a dependency and is not derived from. Reasons, so the choice isn't revisited: it derives from `fundamental-mode` (so no `text-mode` filling, sentence commands or `text-mode-hook`); its font-lock is three rules and knows nothing of our vocabulary; its syntax table marks `◊;` comments only, so `forward-sexp` cannot cross a tag body; it binds `@` to insert `◊`, which fights prose (an email address needs `@@`); and its `pollen-minor-mode` re-enables itself in every buffer via `after-change-major-mode-hook`. If `pollen-mode` happens to be installed, our `auto-mode-alist` entry must win (prepend it).

**MODE-3 (MUST)** Glossary files (`glossary/<id>.pm`) use the same mode. The mode knows which kind of file it is in (`od-file-kind`: `essay`, `page`, `glossary`, `fixture`) from the path relative to `od-root`; a few rules below depend on it.

**MODE-4 (SHOULD)** The mode works outside the repository too (a stray `.pm` file): everything that needs `od-root` degrades to a `user-error` when invoked, never at mode activation.

---

## 3. Vocabulary

The highlighter, the completer and the checker all read **one table**, `od-vocabulary`, in `occurrent.el`.

**VOCAB-1 (MUST)** Each entry gives: tag name; whether it takes a **positional argument** in `[...]` (`link`, `cite`, `term`, `anchor`, `ref`, `table-csv`, `figure`, `embed`, `sort-key`, `define-meta`); its allowed **keyword arguments**, marking which are **required**; whether it takes a **body** in `{...}` (`cite`, `anchor`, `ref`, `br`, `break`, `table-csv` do not); and whether it must start a line (**block**: `define-meta`, `section`, `subsection`, `subsubsection`, `summary`, `break`, `list`, `table`, `table-csv`, `figure`, `embed`, `epigraph`, `blockquote`, `changelog`, `more`). Seed it from SPEC §3.3 and the `provide` form in `pollen.rkt`:

| Tag | Positional | Keywords | Body | Block |
|---|---|---|---|---|
| `define-meta` | key | — | value | yes |
| `section` `subsection` `subsubsection` | — | `#:id` (required), `#:short` | title | yes |
| `abstract` `epistemic` | — | — | yes | yes (SRC-4a, added 2026-10-15) |
| `summary` | — | — | yes | yes |
| `link` | target | `#:note` `#:title` `#:author` `#:date` | yes | no |
| `cite` | key | `#:loc` `#:note` | no | no |
| `term` | id | `#:mark` | yes | no |
| `aside` `margin` `sc` `em` `strong` `code` | — | — | yes | no |
| `anchor` | id | — | no | no |
| `ref` | id of a figure or table in this file | — | no | no |
| `br` `break` | — | — | no | `break` yes |
| `blockquote` | — | — | yes | yes |
| `epigraph` | — | `#:source` | yes | yes |
| `list` | — | `#:start` `#:columns` | yes | yes |
| `table` | — | `#:id` (required) `#:title` (required) `#:caption` `#:source` `#:size` `#:sortable` `#:align` `#:row-headers` | yes | yes |
| `table-csv` | path | as `table` | no | yes |
| `sort-key` | value | — | yes | no |
| `figure` | src | `#:id` (required) `#:title` (required) `#:alt` (required) `#:licence` (required) `#:credit` `#:invert` | caption | yes |
| `more` | — | — | yes | yes (glossary only) |
| `embed` | name | `#:alt` `#:fallback` `#:sticky` | caption | yes (**not built**) |
| `changelog` | — | — | yes | yes (**not built**) |

`#:width` is deliberately absent from `figure`, `table`, `table-csv` and `embed`: the build rejects it (IMG-2, 2026-10-15), so the highlighter must too (FL-6).

**VOCAB-2 (MUST)** Each entry carries a `:built` flag. Tags that `pollen.rkt` does not yet provide (`embed`, `changelog`) are in the table for completion and documentation but are highlighted as **errors** (FL-6) until the flag is flipped. The table, not the highlighter, is what changes when a phase lands.

**VOCAB-3 (MUST) Sync test.** `pollen-test.rkt` gains a test that reads `emacs/occurrent.el`, extracts the tag names with `:built t` from `od-vocabulary`, and asserts the set equals the tag functions `pollen.rkt` provides (the `provide` form minus the template helpers and `root`). `make test` therefore fails when the two drift. Keep `od-vocabulary` a plain quoted list with one entry per line so the Racket side can parse it with a regexp.

**VOCAB-4 (MUST)** Meta keys are a second small table, by file kind: essays and pages take `title subtitle status published tags specimen unlisted` (`abstract` and `epistemic` became tags on 2026-10-15, SRC-4a, so as meta keys they are errors); glossary files take `term aliases see-also added`. `status` values are `draft published revised superseded` (`essay-statuses` in `lib/util.rkt`).

---

## 4. Syntax

The aim is that Emacs's own structural commands (`forward-sexp`, `up-list`, `mark-sexp`, `show-paren-mode`, `electric-pair-mode`) understand a tag body, while prose stays prose.

**SYN-1 (MUST)** *As built 2026-10-15: brackets, braces and `"` default to punctuation and the propertize step promotes those a tag owns (the same result as demoting stray ones, but robust while a tag is half-typed); `'` is a word constituent without the prefix flag, so contractions stay one word.* Syntax table: `{` `}` are paired parens; `[` `]` are paired parens; `"` is **punctuation** by default (prose is full of straight quotes); `◊` is punctuation; `'` is punctuation (apostrophes), not an expression prefix; `_` and `-` are word constituents inside tag names only via the propertize step, otherwise punctuation.

**SYN-2 (MUST)** `syntax-propertize-function` refines this per occurrence:
- `"` gets string syntax **only inside a `[...]` argument group** that follows `◊name`. So `◊cite["key" #:loc "p. 42"]` has two strings; a quotation mark in a paragraph has none. Strings may span lines (SPEC §3.2 shows a `#:note` wrapped across a line).
- `◊;` to end of line is a comment; `◊;{` … `}` is a block comment (Scribble's forms), marked with the comment syntax-table property, as `pollen-mode` does.
- A `[` that does **not** immediately follow `◊name` (e.g. "[sic]" in prose) is punctuation, as is its `]`. A `{` that does not follow `◊name`, `◊name[...]` or a bare `◊` is punctuation. Pollen's reader requires braces to balance inside bodies, so braces inside bodies keep paren syntax.
- `parse-sexp-lookup-properties` is `t`.

**SYN-3 (MUST)** With SYN-1/2, `forward-sexp` on the `◊` of `◊aside{…}` lands after the closing brace, and `up-list` from inside an aside lands after it. Test both (TEST-1).

**SYN-4 (SHOULD)** `show-paren-mode` matches the braces of a tag body across lines; `electric-pair-mode`, when the user has it on, pairs `{` `[` and, inside an argument group, `"`.

---

## 5. Highlighting

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

**FL-5 (MUST) Lists and tables.** Inside `◊list{…}`: `- ` and `N. ` markers in `od-list-marker-face`; an item not indented to its parent's text column (two spaces under `- `, three under `1. `, as `lib/lists.rkt` requires; *corrected 2026-10-15: was "a multiple of two spaces"*), or a line that is neither a marker, a continuation (indented) nor blank, takes `od-error-face` (LIST-7). Inside `◊table{…}`: `|` in `od-list-marker-face`.

**FL-6 (MUST) Errors.** `od-error-face` on:
- a `◊name` not in `od-vocabulary`, or in it with `:built nil` (SRC-2: an unknown tag fails the build);
- `◊quote` specifically, with a tooltip saying "use ◊blockquote" (`make test` rejects it), and any Racket syntactic form after `◊` (`define`, `if`, `let`, `lambda`, `require`, `quote`, `unquote`, `set!`)—these do not fail the build, they corrupt the page silently;
- `◊` followed by whitespace, a newline, or `{` with no name (a bare `◊{…}` is legal Scribble but never wanted here);
- a keyword argument not allowed for that tag (`◊cite["k" #:page "3"]`), including `#:width` on a figure, table or embed (IMG-2);
- a required keyword missing: `#:id` or `#:title` on `◊figure`, `◊table`, `◊table-csv`; `#:alt` or `#:licence` on `◊figure` (IMG-3, IMG-6, IMG-7). Highlight the tag name, since there is no argument to point at;
- `◊more` outside a glossary file; `◊define-meta[term]` outside one; a glossary meta key in an essay (VOCAB-4);
- a heading without `#:id`; two elements in the same file with the same id, counting headings, figures, tables and anchors together (SECT-5, IMG-7), highlighting the second;
- `◊p` (SPEC §3.1: paragraphs are never written as tags; it is also unbound, so it already fails the build);
- a `◊link` whose target is `#id` where no heading, figure, table or `◊anchor` in the file has that id, and a `◊ref` whose id is not a figure or table in the file (LINK-2, IMG-7; cross-essay targets are checked by `od-check`, not the highlighter). One function collects the file's ids by kind and serves the highlighter, `od-insert-link-internal` and `od-insert-ref` (replacing `od--exhibit-ids`).

**FL-7 (SHOULD)** `◊break{}` and `#lang pollen` in `od-markup-face`; the `◊epigraph` and `◊blockquote` bodies in `od-aside-face`'s italic without the dimming.

**FL-8 (MAY)** `prettify-symbols-mode` support is **not** wanted: the lozenge stays a lozenge, nothing is hidden. Record this so it isn't added.

---

## 6. Editing

**EDIT-1 (MUST) Filling.** `fill-paragraph` and `auto-fill` treat as paragraph boundaries: a line starting with any block tag (VOCAB-1), a line that is only `}`, and the `#lang` line. Meta lines are never filled (existing SRC-4 behaviour). Inside `◊list{…}`, `adaptive-fill-mode` recognises `- ` and `N. ` with their indentation so a wrapped item keeps its level (two spaces per level, LIST-1). Filling never breaks inside `[...]` argument groups except inside a string (SPEC §3.2 wraps a `#:note`), and never separates a `◊name` from its `[` or `{`.

**EDIT-2 (MUST) Wrapping commands** keep EMACS-2: every insert command wraps the active region. Add `od-unwrap` (`C-c o u`): with point inside a tag body, remove the `◊name[...]{` and its `}` and leave the body. Add `od-up` (`C-c o U`): move point just after the enclosing tag.

**EDIT-3 (MUST) Completion at point.** A `completion-at-point-functions` entry that completes: a tag name after `◊` (from `od-vocabulary`, `:built` tags first); a keyword after `#:` inside an argument group (those allowed for the enclosing tag); a cite key inside `◊cite["` (the Zotero export, via the existing cache); a term id inside `◊term["` (EMACS-3 cache); a section, figure, table or anchor id after `◊link["#`; a figure or table id inside `◊ref["`; a page then section after `◊link["/` (`data/anchors.json`). Plain `completing-read` pickers remain the primary route; CAPF is for when the hands are already typing.

**EDIT-4 (SHOULD) Spelling.** `flyspell-mode` skips tag names, keywords, and strings in argument groups (`flyspell-generic-check-word-predicate`), so keys, ids and URLs are not flagged. Body text, including aside bodies, is checked.

**EDIT-5 (SHOULD) Outline.** Keep `outline-minor-mode` with the three heading levels; add `od-promote` / `od-demote` (BACKLOG §15, cheap once the mode exists), which also rename the tag and leave `#:id` untouched (ids are permanent).

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

**EDIT-8 (MUST) Comments.** `M-;` (`comment-dwim`) works as elsewhere, using Pollen's line comment: with a region it puts `◊; ` at the start of each line, and again removes it; with none it adds an end-of-line comment one space after the text (not at a comment column, and never with tabs). `◊;` hides the rest of the line and its line break, so commented lines vanish cleanly and an end-of-line comment joins the next line on, which in prose reads as the space it would have been. Block comments (`◊;{…}`) are highlighted and parsed (SYN-2) but not produced by `M-;`. *Added 2026-10-15; built into the existing minor mode, to carry into the major mode.*

**EDIT-10 (MUST) Org's table editor.** `orgtbl-mode` is on in the mode (`od-use-orgtbl`), so inside `◊table{…}` TAB aligns, RET adds rows, `M-arrows` move rows and columns, `M-S-arrows` insert and delete them, and `|-` TAB draws the separator; outside a table the keys do what they always do. The build accepts Org's separator `|---+---|` and ignores separator lines after the first (they group rows in the source only); alignment colons are not available in Org's separator, so use `#:align` (numbers align right anyway). `od-insert-table` writes the skeleton in Org's form and aligns it. *Added 2026-10-15.*

**EDIT-9 (MUST) The guide.** `od-guide` (`C-c o I`) opens a read-only org buffer, `*Occurrent guide*`, walking through the three workflows: starting a new essay, publishing it, revising and republishing. Keys in it are read from the keymap; a command not yet defined shows its planned key marked *(not built yet)*, so the guide is never wrong about what works. `q` closes it. When a workflow changes, the guide's text (`od--guide`) changes with it. *Added 2026-10-15 at Ryan's request.*

---

## 7. Checking before publishing

**CHECK-1 (MUST)** `od-check` (`C-c o k`) runs `make test` then `raco pollen render <this file>` and `racket tools/validate.rkt` in a `compilation-mode` buffer from `od-root`. A `compilation-error-regexp-alist` entry matches `build error: \(.+?\): ` and `warning: \(.+?\): ` (file, no line) so `next-error` opens the file. **Do not** add line numbers to `build-error` in Racket to make this nicer unless it is cheap: the highlighter (FL-6) is where line-level feedback lives.

**CHECK-2 (SHOULD)** `od-check` with a prefix argument runs the full `make` (fonts, images, every page, validate), which is what CI runs.

**CHECK-3 (MAY)** A Flymake backend that runs the FL-6 checks plus the LINK-2 same-page check and reports them in the diagnostics list. Only if the font-lock matchers can be reused without duplicating logic; otherwise skip.

---

## 8. Publishing from Emacs with Magit

### 8.1 Feasibility

**Yes, with nothing to add on the server side.** Publishing *is* a push to `main`: the GitHub Actions workflow (`.github/workflows/deploy.yml`) builds the site and deploys it to Cloudflare on every push to `main`, and Magit pushes. What is missing is not the push but the **steps around it** that the spec requires, which are easy to forget and which Magit knows nothing about:

1. the essay must be listed in `index.ptree` (the build fails otherwise);
2. `status` must change from `draft` to `published`, and `published` must be a date;
3. `make refresh` must run so that the entries the essay cites reach `refs/refs.bib` and `data/cite-cache.json` (CITE-9: an unknown key fails the build), and any new figure is classified into `data/invert.json`;
4. new glossary terms must be committed with the essay;
5. `make` must pass locally, because CI running it is the slow way to find out;
6. nothing matching BUILD-3a (`*-Notes.md`, `*.docx`, `*.graffle`, `*.tex`) and no email address other than `ryan@occurrentdevelopment.com` may enter the commit;
7. the commit message convention matters: REV-1 ignores `[typo]` and `[meta]` commits when computing "last revised".

So the deliverable is a command that does 1–6 and then **hands over to Magit for the commit and push**, where Ryan sees the diff of what is about to become public permanently.

### 8.2 Drafts: a decision Ryan must make

The spec's DRAFT-1 options both have a problem for an Emacs workflow. A **separate private repo** cannot be previewed: Pollen needs the essay inside the project that holds `pollen.rkt`, so `make serve` and `od-preview` don't work on a file in another clone. A **never-pushed branch** is one `P p` away from publishing a draft, and Magit makes that keystroke easy.

**DRAFT-E1 (recommended)** Drafts live **inside the site working tree** at their final path, `essays/<slug>/`, and are kept out of git by `.git/info/exclude` (per-clone, never committed): `od-new-essay` appends `essays/<slug>/` to it, and `od-publish` removes that line as its first step. (The essay's `support/` folder is ignored separately and permanently by `.gitignore`, EDIT-6; the exclude line covers the rest of the folder only until publication.) Consequences: the essay renders and previews like any other; Magit never shows it, so it cannot be staged, committed or pushed by accident; DRAFT-2 (`status` guard) remains the second guard; and the essay is invisible to `git` until the moment of publication, which is exactly DRAFT-1's intent. Cost: a draft is not in any git history until it is published, and `support/` never is. If that matters, `od-backup-drafts` (**MAY**) copies every excluded essay, `support/` included, into the existing private `drafts` repo (cloned beside `site/` as `../drafts`) and commits and pushes there.

**DRAFT-E2 (alternative)** Keep the private `drafts` repo as the place drafts are written, and make `od-preview` work there by symlinking `drafts/essays/<slug>` into `site/essays/` while editing. Rejected by default: a symlink inside `site/essays/` is itself something Magit could stage.

Build DRAFT-E1 unless Ryan says otherwise.

### 8.3 Commands

**PUB-1 (MUST)** `od-publish` (`C-c o P`), from an essay buffer in the site repo:
1. Refuse unless `od-file-kind` is `essay`, the buffer is saved, and `git config user.email` is `ryan@occurrentdevelopment.com`.
2. Remove the essay's `.git/info/exclude` line (DRAFT-E1).
3. If `status` is `draft`, set it to `published` after confirming; set `published` to today if absent; refuse if `title` is missing.
4. Add `essays/<slug>/<slug>.html` to `index.ptree` if absent (after the last essay line).
5. Run `make refresh` then `make` in the `od-check` compilation buffer; stop on failure and leave the buffer visible.
6. Stage, with Magit (`magit-stage-files`): the essay folder (`support/` is ignored and cannot be staged), `index.ptree`, `refs/refs.bib`, `data/cite-cache.json`, `data/invert.json`, `data/link-meta.json`, and any new or modified `glossary/*.pm`. Refuse if `git status --porcelain` on the essay folder lists anything matching BUILD-3a (belt and braces over `.gitignore`), or if the staged diff contains `@` followed by a domain other than `occurrentdevelopment.com`.
7. Open `magit-status` with the commit message proposed via `git-commit-setup-hook` for the next commit: `Publish: <title>`. Say in the echo area: *staged; `c c` to commit, `P p` to push and deploy*.

**PUB-2 (MUST)** `od-publish` never pushes on its own. With a prefix argument (`C-u C-c o P`) it commits with the proposed message and pushes to `origin/main` in one step, after a `yes-or-no-p` that quotes the branch and remote. That is the only path that skips the Magit review.

**PUB-3 (MUST)** `od-commit` (`C-c o C`), for a change to an already-published essay: asks **Typo / Meta / Revision**; prefixes the message `[typo]` or `[meta]` for the first two (REV-1 ignores them for "last revised"); for a Revision, checks that the essay's `◊changelog{…}` (once built; until then, warns and continues) has a new line, then stages the essay folder and the caches as in PUB-1 step 6 and opens `magit-status`. Pages (`pages/*.pm`) and glossary files use the same command with the Revision choice.

**PUB-4 (MUST)** Refuse to run `od-publish` or `od-commit` when the current branch is not `main`, or when `main` is behind `origin/main` (fetch first, `magit-git-string "rev-list" "--count" "main..origin/main"`); say which.

**PUB-5 (SHOULD)** `od-deploy-status` (`C-c o d`): opens `https://github.com/occurrent-development/site/actions` in the browser, or, if `gh` is installed, runs `gh run watch` for the latest run in a compilation buffer and then opens the essay's URL on success. `od-publish` with the prefix argument calls it after pushing.

**PUB-6 (MUST)** Unpublishing is **not** a command. Removing an essay means editing `status` to `superseded` and committing; its source stays in history. Say this in the docstring of `od-publish`, so it isn't built later.

**PUB-7 (SHOULD)** `od-publish` prints, before staging, what will change in the index: the new row's title, date and tags, so a wrong `tags` line is caught before it reaches the home page.

---

## 9. Loading and layout

**LOAD-1 (MUST)** Files: `emacs/occurrent.el` (the mode and commands, one file, autoload cookies on every interactive command and on the mode), `emacs/occurrent-test.el` (ERT), and nothing else in `emacs/`. No `package.el` packaging; the file is loaded from the repository.

**LOAD-2 (MUST)** Setup in the user's init, documented at the top of `occurrent.el`:

```elisp
(add-to-list 'load-path "~/Documents/Ryan/Personal/Projects/Occurrent-Development/site/emacs")
(require 'occurrent)   ; adds ("\\.pm\\'" . occurrent-mode) to auto-mode-alist
```

Nothing else. `occurrent-mode-hook` is where Ryan adds `flyspell-mode`, `visual-line-mode` or whatever he likes; the mode does not turn those on itself.

**LOAD-3 (MUST)** Dependencies: Emacs 29+, Magit (soft: the `od-publish` family is defined only when `magit` is loadable, and says so if not), `citar` (soft, as now). No `pollen-mode`, no `company`.

**LOAD-4 (MUST)** Keys: keep every existing binding, including `C-c o r` for `od-insert-ref`. New: `C-c o I` guide (EDIT-9), `C-c o k` check, `C-c o P` publish, `C-c o C` commit, `C-c o d` deploy status, `C-c o N` new essay, `C-c o F` figure, `C-c o B` table, `C-c o u` unwrap, `C-c o U` up. List them all in the `occurrent-mode` docstring.

---

## 10. Tests

**TEST-1 (MUST)** `emacs/occurrent-test.el`, ERT, run by a new target `make test-emacs` (`emacs -Q --batch -L emacs -l occurrent-test.el -f ert-run-tests-batch-and-exit`). Not part of `make`, so CI does not need Emacs; CI **MAY** add it later. Cases, each a small string fontified with `font-lock-ensure` in a temp buffer:
- every tag in the vocabulary fontifies its name as markup and its body (where it has one) in the right face, including a body spanning three lines;
- `◊quote{…}`, `◊embed[…]{…}`, `◊nonsense{…}`, `◊ {`, `◊cite["k" #:page "3"]`, `◊figure["a.png" #:width "wide" …]`, a `◊figure` without `#:id` or `#:title`, a heading without `#:id`, a duplicate id shared by a heading and a figure, a meta value broken across lines, a `◊link["#missing"]`, a `◊ref["missing"]` and a `◊ref` pointing at a heading rather than a figure each take `od-error-face` on the right span and nowhere else;
- a paragraph containing `"quoted words"`, `[sic]`, an email address and an apostrophe has **no** string, paren or error syntax;
- `forward-sexp` and `up-list` behave as SYN-3 says, including across a nested `◊term` inside an `◊aside`;
- `fill-paragraph` on a `◊list{}` item keeps its indentation, and on a paragraph holding a wrapped `#:note` string does not join the heading below it;
- `od-unwrap` removes exactly the markup of the enclosing tag.

**TEST-2 (MUST)** The VOCAB-3 sync test in `pollen-test.rkt`, run by `make test`.

**TEST-3 (SHOULD)** `od-publish` is tested against a throwaway git repo created in a temp directory with a copy of the project: it refuses on the wrong branch, refuses a `*-Notes.md` in the essay folder, writes the `index.ptree` line once, and stages the expected set of files. The `make` step is stubbed.

---

## 11. Decisions for Ryan

| # | Decision | Recommendation |
|---|---|---|
| E1 | Where drafts live (§8.2) | DRAFT-E1: inside `site/essays/`, excluded via `.git/info/exclude` until published |
| E2 | Does `od-publish` ever push on its own? | Only with a prefix argument and a confirmation (PUB-2) |
| E3 | Whether `../Essays/` (Markdown, LaTeX, Word drafts) is migrated into `essays/<slug>/` folders as DRAFT-E1 drafts | Yes, one at a time as each essay is started in Pollen; BUILD-3a already keeps the notes, `.tex` and `.docx` out of the public repo if they are moved alongside |
| E4 | Face colours | Keep to inherited faces; tune after a week of writing, not before |

---

## 12. Where to stop

Stop when: `make test` passes with the VOCAB-3 sync test; `make test-emacs` passes; the specimen page (which now uses `◊figure`, `◊table`, `◊table-csv` and `◊ref` with ids and titles), the placeholder essay, the test fixtures under `tests/` and the three glossary files open in `occurrent-mode` with nothing in `od-error-face`; inserting `◊embed[…]{…}` or `#:width` lights up; and `od-publish` on a copy of the placeholder essay in a scratch clone stages the right files and stops at `magit-status`. Then report:

1. anything in §4–5 that Emacs's font-lock could not do cleanly (multi-line bodies are the likely place), and what you did instead;
2. the keystroke sequence, start to finish, for publishing a new essay;
3. the three things you'd most want decided before this is used for the first real essay.

Do not write any essay. Do not change tag functions in `pollen.rkt` except to add the VOCAB-3 test.

---

## 13. Opening prompt

> Read `SPEC.md` §3, §6, §9 (IMG-2, IMG-7), §13, §16, `emacs/occurrent.el`, and `HANDOVER-EMACS.md` in this repo. Build what `HANDOVER-EMACS.md` specifies: turn `occurrent-mode` into a major mode derived from `text-mode` with the syntax table, highlighting and editing rules in §4–6, keeping every existing command including `od-insert-ref`; add `od-check`; add the Magit publishing commands in §8 using DRAFT-E1 for drafts; add the tests in §10. Show me the vocabulary table and the syntax-propertize rules before writing the font-lock matchers. Stop as described in §12 and report.
