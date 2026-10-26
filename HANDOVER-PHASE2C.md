# Handover to Claude Code — Phase 2c: layout and popups II

Status: 1.0 · Owner: Ryan · 2026-10-26

Phase 2 passed Ryan's hand checks on desktop Safari, Chrome and Firefox and on iOS on 2026-10-26 (`../site-fixes.org`; Android and the Firefox no-JS check are still his). What he saw while checking became a set of changes, specified in `SPEC.md` draft 1.13 and listed by ID in the **Phase 2c** row of §15. This handover is that row, in build order, with what the spec leaves to you. Do not start Phase 3; it waits for this.

Two jobs. Job A is the site. Job B is a small Emacs job with no dependency on A; do it last, or in a parallel session on its own branch.

## Job A — The site

Read `SPEC.md` in full (it moved on 2026-10-22, 23 and 26; do not work from memory of it), then `COMPAT.md`. The measure and the margins (TYPE-1, LAYOUT-6c) are **unchanged**; Ryan considered widening both and decided against it. If a step below seems to need a wider column, you have misread the step.

Commit the uncommitted doc changes first (`SPEC.md`, `BACKLOG.md`, `HANDOVER-EMACS.md`, this file), as one commit before any code: "Spec 1.13: Phase 2c, Paper, Audio; restored hunks".

### 1. The contents join the text block (TOC-2, LAYOUT-6, 6a, 6c, LAYOUT-1a)

- In tier XL the contents column (11em) and a `--margin-gap` are the leftmost part of the block that `.frame` centres: contents · gap · left margin · gap · column · gap · right margin, centred together. Nothing sits at the window's edge any more. The XL threshold moves accordingly; record the new tier widths on the specimen and in the colophon.
- The list starts on the **subtitle's baseline**, as does the metadata block (LAYOUT-1a revised). The title stands alone above.
- The contents **scroll with the page** and **stick** when their heading reaches the top of the window, below the sticky menu (step 2): `position: sticky` on the list, `top` = the menu's height. The heading reads *Contents* until stuck and the essay **title** (small caps, text face, wrapping) from then on; swap on a sentinel with IntersectionObserver, no animation, and swap back when the reader scrolls up past the point. The "too tall" scrolling, the ellipsis and the current-entry hairline are unchanged.
- The **Scratch** link at the foot of the list (step 5) is part of the sticky block.

### 2. The menu and the bar (NAV-1, BAR-1, BAR-1d)

- XL: the site menu moves from the page header to the **top of the contents column** and is sticky; it never leaves the window. When the bar appears (BAR-1a, unchanged), the menu is the bar's left end and the bar's hairline runs the **full window width**, passing between the menu and the contents. Keep one element: the menu is not duplicated in XL.
- L, M, S: the menu stays in the page header; the bar gains a copy at its left end (on S the chevron and a shortened name; on touch, at the bottom, opening upward). The section name still starts at the column's left edge and the controls still end at its right edge.
- The bar's contents popup is set in the **system sans**, the same component as the contents column (LAYOUT-2a). It was serif on 2026-10-26.
- The `<details>` menu must still work without scripts in every position.

### 3. Definitions become popups (TERM-3, TERM-7, ASIDE-3, POP-6, POP-8, D7)

- Remove the definition stubs from the right margin entirely: a `◊term` opens a popup at every tier (popin on touch), headword as title, short definition as body, **More** expanding `◊more` in place, `see-also` circles replacing the content with Back. The margin now holds aside stubs, figure words and the header block only.
- Hover previews of asides (ASIDE-3, draft 1.12) are still unbuilt: build them here. Same code path as a click; popup delay and grace; a preview is never filled; click pins.
- Update the specimen's own prose about definitions (it describes the stubs) and the Terms no-JS store is unchanged.

### 4. Pinned popups, moving, resizing, the dock (§11.2: POP-1, POP-9, POP-10, POP-11)

- Pointer devices, tiers L and XL only. Click, Enter or **Pin** pins; up to six pinned; the seventh closes the oldest. Last-touched on top. **Esc closes the focused popup only**, returning focus to its mark if visible; no focus, no effect. Each popup has Close. Pinned popups survive scroll, theme and size changes; close on navigation and on dropping to M or S. In M, S and on touch: **no Pin button**, one popup or popin at a time, as now.
- Drag by the title bar (pointer events, clamped to the window). Resize with `resize: both`, min ~14em × 6em. Nothing persists between pages.
- **Dock** (XL only; no button in L): the space under the contents list, spanning the contents column and the left margin. Docked popups stack downward, dock-width, sticky with the contents; they may cover margin notes. Drag out to undock. Beyond the window height, the oldest closes.
- Every pinned popup is a non-modal `role="dialog"`; keep POP-3's keyboard contract for each.

### 5. The scratch pad (POP-12)

- A **Scratch** link with a circle mark at the foot of the contents column and as the last item of the menu; absent without scripts.
- Popup titled *Scratch*, a `<textarea>` in the text face at aside size, **Copy** and **Clear** (confirmed) beneath. One pad site-wide in `localStorage` (try/catch), 64 KB cap. Opens docked in XL, pinned in L, as a popup/popin elsewhere. Nothing leaves the browser.

### 6. Specimen, tests, checks

- THEME-7 lists what the specimen must now show: previewed and pinned asides, a definition popup with More and see-also, two pinned popups with one dragged, a docked popup, the pad with text, the contents scrolling then stuck under the menu with the title as heading, the bar with the menu at its left end.
- `make test` and `make` green. Tests for: the sentinel swap (heading text by scroll position, in a headless browser if the test harness has one; otherwise a documented manual check), Esc closing only the focused popup, the pin cap, the pad surviving a reload (localStorage stub).
- View `/specimen` in Chrome, Safari and Firefox at a **27-inch width (≥ 2,500 px)** and at XL, L, M and S, both themes. The 27-inch view is the one Ryan complained about: there must be no gap between the contents and the margin notes. Fix what you see.

### 7. Stop and report

What you built; anything you could not satisfy as written and what you did instead; the new tier thresholds; and screenshots of `/specimen` at ≥ 2,500 px (top of page, and scrolled with the contents stuck and the title as heading), of the bar at XL with the menu at its left end, of three pinned popups with one docked, and of the scratch pad. Ryan does the phone checks.

Do not touch `emacs/` in this job. Do not begin Phase 3 (backlinks, changelog, glossary page, reference pages, feed, correspondence, Wayback), Phase 4 (print, PDF) or Phase 5 (audio).

## Job B — Emacs docstrings

`emacs/occurrent.el`: every interactive command has a docstring; 31 private `od--` helpers and the constants `od--heading-re`, `od--paragraph-start`, `od--paragraph-separate`, `od-syntax-table` and `occurrent-mode-map` do not. Add one sentence each, saying what the function returns or does and which SPEC or HANDOVER-EMACS ID it serves; run `checkdoc` on the file and fix what it reports; `make test-emacs` green. No behaviour changes. Forward declarations (`(defvar citar-bibliography)` and the like) are left alone.

## Opening prompt

> Read `HANDOVER-PHASE2C.md` in this repo and do Job A as written: read `SPEC.md` (draft 1.13) and `COMPAT.md`; commit the pending doc changes; build the Phase 2c row of SPEC §15 in the order the handover gives (contents into the text block, menu and bar, definitions to popups with aside hover previews, pinned popups with drag, resize and dock, the scratch pad, the specimen); get `make` green; check `/specimen` in three browsers at a 27-inch width and at the four tiers; and stop with the report it asks for. Then, after I have looked, do Job B.
