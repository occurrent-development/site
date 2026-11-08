# occurrentdevelopment.com — Site documents

Status: scaffold · Owner: Ryan · Last revised: 2026-11-08

What the About hub, Me, Policies, Manual of Style and Using this site pages still need before they replace the current About page. Nothing here is published: every draft is in `pages/`, is marked `unlisted`, and is absent from `index.ptree`, so `make` neither renders nor publishes it. The live About page, `STYLE.md` and `pollen.rkt` are untouched.

## Structure

```
/about             hub: what the site is for, links to everything below
/me                who I am
/policies          AI, clinical material, corrections, correspondence, licence
/style             the manual of style
/using-this-site   reader guide to how the site behaves
```

`/changelog`, `/glossary`, `/bibliography` and `/correspondence` stay as they are and are linked from the hub. The menu already lists About, so `pollen.rkt` needs no change.

## Where each draft stands

Each file marks the gaps with `TODO(ryan)` comments, and the comments carry the facts and their SPEC ids. Find them all with `grep -rn "TODO(ryan)" pages/`.

- **`pages/about-hub.html.pm`**: *The Essays* and *The Website* are your existing text, moved unchanged, and *The Website* keeps its `#the-website` anchor. *What this site is for* is empty: essays against blog entries is yours to write. *Site documents* is a bare link list. *Me* is a one-line pointer that keeps the old `#me` anchor.
- **`pages/me.html.pm`**: opens with your existing *Me* text, moved unchanged. *Work*, *Qualifications* and *Affiliations and interests* are empty.
- **`pages/policies.html.pm`**: *AI policy* holds the draft wording moved from the style page. The other four sections are empty, with the facts in comments.
- **`pages/style.html.pm`**: the AI policy section is gone and the intro links to `/policies#ai-policy`. Three passages still contradict the policy (below).
- **`pages/using-this-site.html.pm`**: eight empty sections, each with the facts and SPEC ids in a comment.

## Decide first

1. **Licences (SPEC D4).** Needed before the first essay is published, and the repository is already public. `LICENSE` and `LICENSE-CONTENT` are placeholders. I recommend the spec's proposal: CC BY 4.0 for the essays, MIT for the code. Decide, update both files, then write the policy.
2. **The three style-guide conflicts with the AI policy.** The first item of *Usage* lists a Claude Code session that edits prose. The third item of *Generative media* says model-assisted prose carries no label. All of *Writing with an assistant* is about models drafting. I recommend making that section review-only and deleting the no-label line. Each has a `CONFLICT` comment.
3. **The AI policy wording.** It is Claude's draft from what you said. Rewrite it in your words, since your policy rules out AI-authored text on the site.
4. **The employer statement.** You work for NSW Health. Say on `/me` that these are your own views, and declare any interest a reader would want to know about.

## Tonight, in order

1. Decide the licence, then write the licence section.
2. Rewrite the AI policy and write the other three policy sections.
3. Write *What this site is for* on the hub.
4. Write *Work*, *Qualifications* and the employer statement on `/me`.
5. Write *Using this site*. Check the two lines marked VERIFY first: whether PDFs (PRINT-2) have shipped, since `data/publish.txt` lists none, and what `build/feed.xml` contains.
6. Resolve the style-guide conflicts.

## Going live

1. `grep -rn "TODO(ryan)\|CONFLICT\|ON ADOPTION" pages/` returns nothing.
2. Remove `◊define-meta[unlisted]{yes}` from each draft.
3. Replace `pages/about.html.pm` with `pages/about-hub.html.pm` (rename it to `about.html.pm`, so `/about` and its anchors stay).
4. Add `pages/me.html`, `pages/policies.html`, `pages/style.html` and `pages/using-this-site.html` to `index.ptree`.
5. Run `make test`, then `make serve` and read every page in both themes.
6. Update `README.md` (the `pages/` line) and the `SPEC.md` mentions of About and of `STYLE.md`. Then delete or redirect `STYLE.md`, and fix the *Repository documents* items that say the manual is Markdown (marked `ON ADOPTION`).
7. Commit and push. Only `main` deploys.

## Not verified

- **No page here has been compiled.** There is no Racket in my environment. The first `make serve` is the real test, and the riskiest part is the style page's `◊(loz)` helper.
- **Nothing in `using-this-site` is confirmed live.** The facts come from `SPEC.md` and `site.js`, not from a built site.
- **The anchors.** `/about#me`, `#the-essays` and `#the-website` all survive on the hub. Check `data/anchors-deployed.json` if the site is already public.
