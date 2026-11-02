# Handover to Claude Code — Phase 3c: the glossary, senses, and the front page

Status: 1.0 · Owner: Ryan · 2026-11-02 (night)

Ryan reviewed the built glossary page after Phase 3 and asked for four things on it, then two changes to the site's structure. `SPEC.md` draft 1.19 records them: TERM-2 and TERM-8 rewritten, TERM-9 new, TERM-3, TERM-4, CITE-10, VAL-2, PRINT-3 touched; §13a restructured (HOME-1 rewritten, ABOUT-2 restored, NAV-1); §13b and D13, D14 renamed; D18 new; §16 revised; a Phase 3c row in §15. This handover is those changes in build order. Start only after Phase 3b has landed (`HANDOVER-PHASE3B.md`): both touch `site.js`'s popups and `links.json`.

Read the 1.19 text of §6, §13a, §13b, CITE-10, VAL-2 and §16, and D13, D14 and D18, before starting; do not work from the 1.18 text or from the code as built. Commit `SPEC.md` and this file first, in one commit: "Spec 1.19: senses, the More, Used in as backlinks; Blog; the front page".

## What changed, in one paragraph

A term file is a definition followed by its More, with no tag to mark the More: everything after the first paragraph is it (before this, a second plain paragraph was read into an unused field and silently dropped, D18). A `◊term` may carry a `◊sense{…}`, the page's own gloss on its use of the term, which the popup shows in italic between the definition and More and which the glossary page shows under that post in Used in, so Used in becomes the term's backlinks, as a list. The glossary page loses its Bibliography and gains its place in the menu. The notebook is renamed the blog, folder, URLs, index, menu and docs. The home page becomes a front page, one paragraph and two columns of recent posts, and About goes back to `/about`.

## Job A — The glossary

### 1. The More is the rest of the file (TERM-2, D18)

- `lib/glossary.rkt`: `'more` is every element of the body after the first paragraph; drop `'rest` and the `od-more` partition. Delete `◊more` from `pollen.rkt` (the tag, its `forbid` in `page-root`, the `"a definition"` branch in the context names), from `od-vocabulary` and the VOCAB-3 sync test, from the highlighter's table (FL-6), and `od-insert-more` with its key from `occurrent.el`, its tests and `HANDOVER-EMACS.md`. Not deprecated: nothing published used it beyond the three term files.
- Unwrap `glossary/occurrent.pm` (the one file with a `◊more`): the paragraph stands on its own after the definition. `continuant.pm` and `looping-effect.pm` are unchanged.
- `glossary-root` already refuses headings and asides; add lists, figures, tables and margin notes, naming TERM-2.
- A RackUnit test: a fixture term with three paragraphs and no tag yields a one-paragraph definition and a two-paragraph More; one with a single paragraph yields no More.

### 2. `◊sense` (TERM-9)

- `pollen.rkt`: `(define (sense . xs) (txexpr 'od-sense null xs))`. In `term`, partition the children: at most one `od-sense`, the rest the text; the text must not be empty once the sense is lifted; forbid `od-term`, `od-aside`, `od-margin` inside the sense and allow `od-em`, `od-cite`, `od-link`. Keep the sense on the `od-term` as a child under its own tag, not as an attribute (it carries markup). A `◊sense` reaching `root` outside a `◊term` is a build error ("◊sense belongs inside ◊term (TERM-9)"), as is a second sense for the same term on one page, and a sense on an occurrence that is not the page's first use of the term (the one with the circle).
- The walk that builds the Terms section (TERM-4) stores each page's senses by id. The entry gains, after `p.definition` and before `div.term-more`, `<p class="term-sense"><span class="sense-label">In this essay:</span> <em>…</em></p>`, the label by the page's kind (*In this entry:* for a blog entry). Inside the `<em>`, `◊em` flips to roman (LAYOUT-4c already does this for epigraphs; reuse it). A citation inside a sense is numbered and resolved like any other on the page (LAYOUT-1's rule for the abstract).
- `site.js` `termItem()`: append `.term-sense` after the definition and before the More button, so the order is title · definition · sense · More · see-also. CSS: `.popup .term-sense` and `.terms .term-sense` share one rule, the label muted and roman, the text italic, no extra margin above the More button.
- `tools/validate.rkt` / `lib/graph.rkt`: `links.json`'s record of a page marking a term gains the sense as an HTML string, absent when there is none (VAL-2).
- The specimen: give one term a sense (`looping effect` suits: "In this essay, the narrow case of a diagnostic label changing the child it is given to."). Keep the TERM-5 sentence about repeated terms true.
- Emacs (§16): `od-insert-term` with a prefix argument writes `◊term["id"]{region ◊sense{}}` and leaves point inside the sense; `user-error` when the buffer already has a `◊sense` for that id. Add `◊sense` to `od-vocabulary` (allowed inside `◊term` only), the highlighter (FL-6) and the VOCAB-3 test. `make test-emacs` green.
- Browser test (`tests/browser/harness.js`): opening the specimen's sensed term shows the five parts in order; opening a term without a sense shows no `.term-sense`; on a page that marks the same term without a sense (the placeholder essay can mark it) the popup has none.

### 3. Used in as backlinks; no Bibliography; the menu (TERM-8, CITE-10, NAV-1)

- `glossary-list` in `pollen.rkt`: Used in becomes `<ul class="used-in">`, the label *Used in* as a muted line above it or as the list's first words (choose on the page; the aside-size muted style of the See also line either way); each `<li>` the post's title as a cross-essay link with its → mark, then the kind label, then, when `links.json` has a sense for that post and term, `<span class="sense"><em>…</em></span>` on its own line inside the item, no bullet, no gap (`display: block`), the `◊em` flip as in §2. Order: the index's.
- The glossary page emits no end matter: nothing after the last entry. The simplest route is a page-level switch the glossary and home pages set (`◊define-meta[endmatter]{none}` is one shape; a check in `page-root` on the page's path is another; choose the one the code already leans to). Citations inside definitions keep their circles as CITE-7 says; confirm that without scripts an unnumbered circle links to `/references/<key>` and that with scripts its popup is the reference card (Phase 3b's). Remove the glossary page's `◊break{}` if the end matter's absence leaves it reading as a trailing rule.
- NAV-1: add **Glossary** to the menu list in `pollen.rkt` after Blog (it was in the spec from 2026-10-15 and never built); `aria-current` on `/glossary`.
- Screenshot `/glossary` in both themes at tiers L and S.

## Job B — Blog, the front page, About

### 4. Notebook → Blog (§13b, D13, D14)

- `git mv pages/notebook.html.pm pages/blog.html.pm`; `index.ptree`; the folder `blog/` (no `notebook/` folder exists yet; create `blog/` with its gitignore rule `blog/*/support/`, and drop `notebook/*/support/`); the Makefile's `find … notebook`; `post-kind` and every path test in `pollen.rkt`, `lib/graph.rkt`, `tools/validate.rkt`, `tools/*.py`, `_x/blog/`, the PDF paths (PRINT-2), the feed; the menu item **Blog**; the kind label a reader sees becomes *blog* (`kind-label`), the internal value stays `entry` and the class `kind-entry` (§13b); the reserved-slug list gains `blog` and keeps `notebook`; `od-new-essay`'s folder, the Blog heading in `od-insert-link-essay`, `od-file-kind`'s path test; the index page's placeholder paragraph says *blog*. Then the docs: `README.md`, `STYLE.md`, `HANDOVER-EMACS.md`, `BACKLOG.md` wherever they say notebook, except in dated history. No redirect: nothing was published under `/notebook`.
- `make test`: the INDEX-1a fixture test for the entry index still passes under the new name.

### 5. About back to `/about` (ABOUT-2)

- `git mv pages/index.html.pm pages/about.html.pm`; title stays *About*; uncomment and keep the Start-here line at the end (it may name the placeholder until a real opener exists); delete the commented `◊latest[3]`; remove the `/about → /` line from `_redirects` (leave the file's other lines). `index.ptree`. The essays page's "read more about me, and this website ◊link["/"]{here}" becomes `◊link["/about"]`.

### 6. The front page (HOME-1)

- New `pages/index.html.pm`: `◊define-meta[title]{Occurrent Development}`; one paragraph by hand, which Ryan will rewrite, for now: *Essays and shorter pieces on the philosophy and practice of developmental paediatrics, written by a clinician in Sydney who thinks the field's working paradigm is misaligned with what clinicians claim to do and what families come for. More ◊link["/about"]{about me and this site}.*; `◊break{}`; `◊recent[3]`.
- `◊recent[n]` in `pollen.rkt`, next to `◊index`: reads the same metas (DRAFT-2, `published`), sorts newest first, takes `n` per kind; emits `<div class="recent"><section class="recent-essays"><h2>Essays</h2><ul>…</ul><p class="all"><a …>All essays</a></p></section><section class="recent-blog">…</section></div>`, each `<li>` the title as a cross-essay link (reuse `with-mark … 'xref` and `post-title` as `glossary-list` does) and the short date on the next line in `.date` muted (INDEX-2's `9 Oct 2026`); *Nothing yet* in muted when a kind has no posts. Remove `◊latest`. The `h2`s go through the heading pipeline so they take the site's level-2 style but are **not** contents entries (the page has no contents, TOC-1).
- CSS: `.recent` a grid of two equal columns with the gap token the figure grids use; `@media` at tier S one column, Essays first. The page's title is not shown in the column (the menu's site name is the title); the metadata block holds only the source links; no end matter (§3's switch).
- A RackUnit test renders `◊recent[3]` from fixtures (four essays, no entries) and asserts three essay items newest first, their dates, and the Blog column's *Nothing yet*.

### 7. Checks and report

- `make test`, `make`, `make test-browser`, `make test-emacs` green.
- Screenshots: the specimen's sensed-term popup in light and dark, and the same on a phone-width popin; `/glossary` at tier L showing Used in with the sense and no Bibliography, and at tier S; `/` at tier L (two columns) and at tier S (stacked); the menu open, reading Home · About · Essays · Blog · Glossary · Bibliography · Scratch; `/about` with its Start-here line.
- Write `reports/2026-11-02-phase3c/REPORT.md`: what was built, what the spec left open and how it was decided (the Used in label's placement, the end-matter switch's shape), anything that reads badly on the page.

Do not begin Job B (maths) of `HANDOVER-PHASE3.md` or the rest of its Job C.

## Opening prompt

> Read `HANDOVER-PHASE3C.md` in this repo and do it as written: read the draft 1.19 text of `SPEC.md` §6, §13a, §13b, CITE-10, VAL-2, §16, D13, D14 and D18; commit the two docs; build the seven steps in order (the More as the rest of the file, `◊sense`, Used in as backlinks with the glossary's end matter suppressed and Glossary in the menu, Notebook → Blog, About back to `/about`, the front page with `◊recent`, checks); get `make` green; and stop with the report it asks for.
