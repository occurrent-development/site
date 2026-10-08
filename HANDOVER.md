# Handover to Claude Code — Phase 0

Read `SPEC.md` first; it is the build brief. `BACKLOG.md` lists what is deliberately *not* being built. This file covers only what Claude Code needs that the spec doesn't say: what already exists, what to build first, and where to stop.

---

## 1. What already exists

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

## 2. The one infrastructure problem to solve first

**Cloudflare's build image has no Racket**, so Pollen cannot be built there. The current setup works only because the placeholder needs no build.

Fix it before anything else:

1. Move the build to **GitHub Actions** (`Bogdanp/setup-racket`), which renders the site into `public/`.
2. Deploy from the same workflow with `cloudflare/wrangler-action` (`wrangler deploy`), using repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. Turn **off** Cloudflare's own Git-connected build so the two don't fight.
4. Ask Ryan to create the API token (Workers Scripts: Edit) and add both secrets; you cannot.
5. Add `public/` to `.gitignore` once CI generates it (the line is already there, commented).

Prove this works with the placeholder *before* building anything else. A deploy pipeline that can't run Racket is the only thing here that can waste a day.

---

## 3. Phase 0 scope

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

## 4. Things to get right (easily missed)

- **SRC-3**: a single newline inside a paragraph is a space, not `<br>`. Pollen's default is the opposite, and the source is hard-wrapped by `fill-paragraph`.
- **TYPE-13**: merge adjacent strings before the typography rules run, or rules silently fail at line breaks.
- **MARK-2**: a line containing a superscript must be exactly as tall as one without.
- **LAYOUT-7**: width tiers are container queries, not media queries.
- **TYPE-1**: the measure is *calibrated by counting characters*, not set to `90ch`. Put the final value in the colophon.
- **TYPE-9a**: Libertinus is OFL, so the font files are committed, with `OFL.txt` beside them. Subset to WOFF2 in the build.
- Verify `smcp`, `c2sc`, `onum` and `tnum` work in the Libertinus release before building on them. Report if any don't.

---

## 5. Decisions Ryan hasn't made, and what to do meanwhile

| Open | Do this |
|---|---|
| Theme colours (SPEC D1) | Build the specimen page with a control that cycles the three candidate backgrounds and text colours, so he picks by looking |
| Licences (D4) | Leave `LICENSE` and `LICENSE-CONTENT` as TODO stubs; don't invent terms |
| Serial comma (D5) | Irrelevant to the build; ignore |
| Section-break glyph (D6) | Plain asterism; one SVG, easy to swap |

---

## 6. Where to stop

Stop when the specimen page is live at `occurrentdevelopment.com/specimen` and `make test` passes. Then report:

1. the calibrated measure, and the body size and line-height you settled on;
2. anything in the spec that proved wrong or impossible, with what you did instead;
3. the three things you'd most want decided before Phase 1.

Do not start Phase 1. Ryan judges the typography on the specimen page first, and that judgement may change the foundations.

---

## 7. Standing instructions

- **Write the interaction code from scratch** against the behaviour tables in the spec. gwern.net is the behavioural reference, not a codebase to copy; check the licence before consulting any of its code.
- **Ask rather than guess** on anything that affects how the site reads. Guess freely on anything internal.
- **Keep the JS budget** (§14): Phase 0 should ship almost none — the theme script and nothing else.
- **Never commit** font files other than Libertinus, anything matching `*-Notes.md`, `*.docx`, `*.graffle`, `*.tex`, or any email address other than `ryan@occurrentdevelopment.com`.
- **Don't touch DNS.** If something needs a DNS change, say so and stop.

---

## 8. Opening prompt

> Read `SPEC.md`, `BACKLOG.md` and `HANDOVER.md` in this repo. Build Phase 0 only, as defined in HANDOVER §3.
>
> Start with the deploy pipeline problem in HANDOVER §2: Cloudflare's build image has no Racket, so the build must move to GitHub Actions with wrangler deploying to the existing Worker. Prove that works with the current placeholder before building anything else.
>
> Then build the Pollen skeleton, the section tree and table of contents, the typography, the themes and the specimen page. Show me the Makefile and the GitHub Actions workflow before building on top of them.
>
> Stop when the specimen page is live and the typography tests pass, and report as described in HANDOVER §6. Do not start Phase 1.
