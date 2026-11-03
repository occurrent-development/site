# occurrentdevelopment.com — Browser support audit

Status: draft 1.1 · 2026-10-16, the matrix made a list 2026-11-03 (`STYLE.md` §9) · generated from caniuse-db (data of 2026-10-13) and MDN browser-compat-data 8.1.6 for the features caniuse does not track (`light-dark()`, `color-scheme`, `text-wrap: pretty`, the hyphenation limits, `size-adjust`/`ascent-override`, `scrollend`, `decoding`). *Added to the repository 2026-11-03; until then it lived only in the Claude project.*

Figures are the share of **tracked** browser traffic (caniuse tracks 97.5% of global traffic; the rest is unidentified and ignored here). "AU" uses caniuse's Australian regional data. "Not supported by" lists browsers carrying ≥ 0.15% of global traffic on versions without the feature; "IE 0.2" is the dead-browser floor on every row and can be read as zero.

## Summary

- Everything the layout and interaction depend on (container queries, custom properties, `position: sticky`, `(hover: none)`, IntersectionObserver, ES modules, `<details>`, masks, `:focus-visible`, WOFF2, WebP/AVIF, `loading="lazy"`) is at **98–100%** of tracked traffic. The site works for essentially everyone the spec intends to serve.
- Below 97% are only **progressive niceties** that the spec already treats as optional or guards: `light-dark()` (93.6%, guarded by THEME-3's `@supports not` block), `text-wrap: balance` (96%) and `pretty` (90%, no Firefox), `scrollend` (93%, with the scroll-listener fallback), `ascent-override` (81%, no Safari).
- **Two spec errors found** (TYPE-4a): `hyphenate-limit-lines` has **no** unprefixed implementation anywhere, and `hyphenate-limit-chars` is Chromium and Firefox 137+ only; Safari needs `-webkit-hyphenate-limit-lines` and `-webkit-hyphenate-limit-before`/`-after` instead. `hanging-punctuation` is Safari-only (17% global, 30% AU) and stays a nicety.

## Features

Each feature, the spec rule that depends on it, the share of tracked global and Australian traffic that supports it, and the browsers that do not (with their global share).

- **Container queries (size)** (LAYOUT-7): global 98.3, AU 98.1; not supported by UC Browser for Android 0.5, Chrome 0.3, Safari on iOS 0.3, IE 0.2.
- **Container query units (cqi etc.)** (LAYOUT-7): global 98.4, AU 98.2; not supported by UC Browser for Android 0.5, Chrome 0.3, Safari on iOS 0.3, IE 0.2.
- **CSS custom properties** (THEME-3): global 99.8, AU 99.6; not supported by IE 0.2.
- **@supports** (THEME-3): global 99.8, AU 100.0; not supported by IE 0.2.
- **position: sticky** (TOC-2, EMBED-3): global 99.6, AU 99.2; not supported by IE 0.2.
- **CSS Grid** (layout): global 99.8, AU 99.4.
- **Flexbox gap** (layout): global 99.6, AU 99.0; not supported by IE 0.2.
- **min()/max()/clamp()** (LAYOUT-6c): global 99.5, AU 99.0; not supported by IE 0.2.
- **Multi-column layout** (LIST-5): global 100.0, AU 100.0.
- **env() safe-area-inset** (BAR-1): global 99.7, AU 99.2; not supported by IE 0.2.
- **(hover: none) media query** (POP-5, BAR-1): global 99.8, AU 99.9; not supported by IE 0.2.
- **Media query range syntax** (tiers): global 98.3, AU 98.0; not supported by UC Browser for Android 0.5, Safari on iOS 0.4, Chrome 0.2, IE 0.2.
- **prefers-color-scheme** (THEME-1): global 99.7, AU 99.1; not supported by IE 0.2.
- **prefers-reduced-motion** (POP-4): global 99.7, AU 99.2; not supported by IE 0.2.
- **color-scheme property** (THEME-3): global 99.0, AU 99.0; not supported by UC Browser for Android 0.5, IE 0.2.
- **light-dark()** (THEME-3): global 93.6, AU 95.7; not supported by Chrome 2.6, Opera Mobile 0.9, Safari on iOS 0.8, UC Browser for Android 0.5, Safari 0.5, Edge 0.3, IE 0.2.
- **localStorage** (THEME-1): global 100.0, AU 100.0.
- **filter: invert()/brightness()** (IMG-4): global 99.8, AU 100.0; not supported by IE 0.2.
- **mix-blend-mode** (IMG-4): global 99.8 (+18.4 partial), AU 99.9; not supported by IE 0.2.
- **hyphens: auto** (TYPE-4): global 99.9, AU 99.2.
- **hyphenate-limit-chars** (TYPE-4a): global 79.5, AU 66.2; not supported by Safari on iOS 14.8, Safari 3.1, Chrome 0.6, Firefox 0.6, UC Browser for Android 0.5, IE 0.2.
- **hyphenate-limit-lines (unprefixed)** (TYPE-4a): global 0.0, AU 0.0; not supported by Chrome for Android 42.8, Chrome 23.8, Safari on iOS 14.8, Edge 5.7, Safari 3.1, Firefox 2.3, Samsung Internet 2.1, Opera Mobile 0.9, Opera 0.8, UC Browser for Android 0.5, Firefox for Android 0.4, IE 0.2.
- **-webkit-hyphenate-limit-lines** (TYPE-4a): global 18.4, AU 32.7; not supported by Chrome for Android 42.8, Chrome 23.8, Edge 5.7, Firefox 2.3, Samsung Internet 2.1, Opera Mobile 0.9, Opera 0.8, UC Browser for Android 0.5, Firefox for Android 0.4, IE 0.2.
- **-webkit-hyphenate-limit-before/after** (TYPE-4a): global 0.0, AU 0.0; not supported by Chrome for Android 42.8, Chrome 23.8, Safari on iOS 14.8, Edge 5.7, Safari 3.1, Firefox 2.3, Samsung Internet 2.1, Opera Mobile 0.9, Opera 0.8, UC Browser for Android 0.5, Firefox for Android 0.4, IE 0.2.
- **text-wrap: balance** (TYPE-6): global 96.0, AU 96.0; not supported by Chrome 1.5, Safari on iOS 0.8, UC Browser for Android 0.5, Safari 0.5, Firefox 0.3, IE 0.2.
- **text-wrap: pretty** (TYPE-6): global 89.9, AU 87.8; not supported by Safari on iOS 3.5, Firefox 2.3, Chrome 1.7, Safari 1.1, UC Browser for Android 0.5, Firefox for Android 0.4, IE 0.2.
- **hanging-punctuation** (TYPE-6): global 17.2 (+1.2 partial), AU 30.3; not supported by Chrome for Android 42.8, Chrome 23.8, Edge 5.7, Firefox 2.3, Samsung Internet 2.1, Opera Mobile 0.9, Opera 0.8, UC Browser for Android 0.5, Firefox for Android 0.4, IE 0.2.
- **font-variant-numeric** (TYPE-7): global 99.8, AU 99.5; not supported by IE 0.2.
- **font-feature-settings** (TYPE-7): global 100.0, AU 100.0.
- **WOFF2** (TYPE-8): global 99.8, AU 100.0; not supported by IE 0.2.
- **unicode-range** (TYPE-8): global 99.8, AU 100.0.
- **@font-face size-adjust** (TYPE-10): global 97.2, AU 97.2; not supported by Opera Mobile 0.9, Safari on iOS 0.7, UC Browser for Android 0.5, Safari 0.3, IE 0.2.
- **@font-face ascent-override** (TYPE-10): global 80.7, AU 66.5; not supported by Safari on iOS 14.8, Safari 3.1, UC Browser for Android 0.5, IE 0.2.
- **text-overflow: ellipsis** (TOC-2): global 100.0, AU 100.0.
- **CSS masks** (MARK-1): global 99.8 (+3.4 partial), AU 100.0; not supported by IE 0.2.
- **Inline SVG** (MARK-1): global 100.0, AU 100.0.
- **currentColor** (MARK-1): global 100.0, AU 100.0.
- **:focus-visible** (MARK-5): global 99.0, AU 98.8; not supported by UC Browser for Android 0.5, IE 0.2.
- **<details>** (NAV-1): global 99.8, AU 100.0; not supported by IE 0.2.
- **<dialog>** (IMG-8 (optional)): global 99.6, AU 99.6; not supported by IE 0.2.
- **:has()** ((if used)): global 98.4, AU 98.6; not supported by UC Browser for Android 0.5, Chrome 0.3, Firefox 0.3, IE 0.2.
- **CSS nesting** ((if used)): global 95.3 (+1.6 partial), AU 96.0; not supported by Chrome 1.4, UC Browser for Android 0.5, Safari on iOS 0.4, IE 0.2.
- **IntersectionObserver** (BAR-1b, EMBED-1): global 99.7, AU 99.3; not supported by IE 0.2.
- **scrollend event** (BAR-1b): global 92.7, AU 90.4; not supported by Safari on iOS 3.6, Chrome 1.5, Safari 1.1, UC Browser for Android 0.5, IE 0.2.
- **ES modules <script type=module>** (§14): global 99.7, AU 99.2; not supported by IE 0.2.
- **dynamic import()** (EMBED-1): global 99.7, AU 99.2; not supported by IE 0.2.
- **modulepreload** (PERF-2): global 98.7, AU 97.3; not supported by Safari on iOS 0.7, Safari 0.3, IE 0.2.
- **history.pushState** (BAR-2): global 100.0, AU 100.0.
- **overscroll-behavior** (POP-5): global 99.3, AU 98.3; not supported by Safari on iOS 0.3.
- **srcset/sizes** (IMG-1): global 99.8 (+7.5 partial), AU 100.0; not supported by IE 0.2.
- **loading="lazy"** (IMG-1): global 98.9 (+0.7 partial), AU 98.0; not supported by IE 0.2.
- **decoding="async"** (IMG-1): global 99.1, AU 99.2; not supported by UC Browser for Android 0.5, IE 0.2.
- **WebP** (IMG-1): global 99.6, AU 99.5; not supported by IE 0.2.
- **AVIF** (IMG-1): global 98.8, AU 98.1; not supported by Safari on iOS 0.3, Edge 0.3, IE 0.2.
- **Canvas** (EMBED-7): global 100.0, AU 100.0.
- **WebGL 1** (EMBED-7): global 100.0, AU 100.0.
- **WebGL 2** (EMBED-7): global 99.6, AU 99.1; not supported by IE 0.2.

## Notes against the spec

- **TYPE-4a** Rewrite as: `-webkit-hyphenate-limit-lines: 2` (Safari; the unprefixed property is Safari Technology Preview only), `hyphenate-limit-chars: 6 3 3` (Chromium, Firefox 137+), and `-webkit-hyphenate-limit-before: 3; -webkit-hyphenate-limit-after: 3` (Safari's equivalent of the last two values; Safari has no equivalent of the six-letter minimum). Without the WebKit pair, iPhones, the tier-S case the rule exists for, get no limits at all.
- **TYPE-6** `text-wrap: pretty` reaches Safari only from 26 (3.5% of global traffic is still on older iOS Safari) and Firefox not at all; `balance` is everywhere that matters. `hanging-punctuation: first` is Safari-only and has been since 2016; keep it as a nicety, never design around it.
- **TYPE-10** `ascent-override` is absent from Safari (preview only), so the metric-matched fallback cannot fully prevent reflow there; `size-adjust` (Safari 17+) does most of the work. Accept, or test the swap on an iPhone with the cache cleared.
- **THEME-3** `light-dark()` is missing on 6% of global traffic, mostly Chrome 109–122 (pinned on Windows 7/8 and old Android) and iOS < 17.5. The `@supports not` block in the spec covers it; make sure it is actually built, because the failure is a page with no background or text colour.
- **BAR-1b** `scrollend` arrived in Safari 26.2; still 7% without it. The passive-scroll-listener path in the spec is the one most readers hit for now.
- **LAYOUT-7** Container queries: 98.3%. The remaining 1.7% is largely UC Browser and pinned old Chrome/iOS; the spec's "tier S everywhere" fallback is the right one.
- **mix-blend-mode** (IMG-4) is 100% in Chrome/Safari/Firefox; caniuse's "partial" is Chromium not blending across stacking contexts in some cases, which does not affect an image blended against the page background.
- **AU vs global** differ by under 2 points on every row except the Safari-only properties, where AU is higher (Safari has about a third of Australian traffic): `hanging-punctuation` 30% AU, `-webkit-hyphenate-limit-lines` 33% AU.

Regenerate: `node score.js` in the scratch folder, after `npm install caniuse-db @mdn/browser-compat-data`.

## Second pass: what the implementation will touch beyond the spec's wording

Checked 2026-10-16 (same data). All ≥ 99% of tracked traffic unless listed: ResizeObserver (ASIDE-4 recalculation), `fetch` and AbortController (POP-7 fragments), pointer events and passive listeners, Web Animations API and CSS transitions, `font-display`, `<link rel="preload">`, `localeCompare`/Intl (TABLE-5), `<picture>`, `<template>`, `:focus-within`, `touch-action` and touch events (97%), `@page` (98%), `widows`/`orphans` (97%, no Firefox).

Avoid, because Safari lacks them:

- `::marker` (81%): draw list bullets with `::before`, as LIST-2 intends.
- `requestIdleCallback` (81%): use `setTimeout` or nothing.
- `<link rel="prefetch">` (82%): POP-7's `fetch` on `pointerenter` is the right mechanism anyway.
- `::selection` (85%, THEME-3's `--selection`): harmless when missing; keep it.

The exhaustive check is mechanical once the CSS and JS exist: run the built stylesheet through `doiuse` and the scripts through `eslint-plugin-compat` against a browserslist of `> 0.2%, not dead`; add it to `make validate`.
