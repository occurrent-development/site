<!doctype html>
<html lang="en-AU">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>◊(page-title metas)</title>
◊when/splice[(select-from-metas 'unlisted metas)]{<meta name="robots" content="noindex">
}<meta name="color-scheme" content="light dark">
<link rel="icon" href="/assets/brand/logo.svg" type="image/svg+xml">
<link rel="icon" href="/favicon.ico" sizes="16x16 32x32 48x48">
<link rel="apple-touch-icon" href="/assets/brand/apple-touch-icon.png">
<link rel="manifest" href="/assets/brand/site.webmanifest">
<meta name="apple-mobile-web-app-title" content="Occ Dev">
<meta name="theme-color" media="(prefers-color-scheme: light)" content="#EFE7D4">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#121212">
<script>◊(head-script)</script>
◊(font-preloads)
<style>
◊(site-css)◊when/splice[(specimen? metas)]{◊(specimen-css)}</style>
</head>
<body>
<div class="frame has-column">
<div class="◊(page-class metas)">
<div class="menu-rail">◊(site-menu metas)</div>
<header class="site-header">
<button class="theme-toggle" type="button" data-theme-toggle aria-label="Theme" hidden>
<svg class="icon-auto" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.5" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 4.5a7.5 7.5 0 0 0 0 15z" fill="currentColor"/></svg>
<svg class="icon-light" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12h2.5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
<svg class="icon-dark" viewBox="0 0 24 24" aria-hidden="true"><path d="M19.5 14.6A7.5 7.5 0 1 1 9.4 4.5a6 6 0 0 0 10.1 10.1z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>
</button>
</header>
<div class="bar" id="bar" hidden>
◊(site-menu metas #:bar #t)
<button class="bar-section" type="button" aria-haspopup="dialog"><span class="vh">Contents. Current section: </span><span class="bar-title"></span></button>
<div class="bar-controls">
<button class="size-down" type="button" aria-label="Smaller text"><span aria-hidden="true">A</span></button>
<button class="size-up" type="button" aria-label="Larger text"><span aria-hidden="true">A</span></button>
<button class="theme-toggle" type="button" data-theme-toggle aria-label="Theme">
<svg class="icon-auto" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.5" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 4.5a7.5 7.5 0 0 0 0 15z" fill="currentColor"/></svg>
<svg class="icon-light" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12h2.5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
<svg class="icon-dark" viewBox="0 0 24 24" aria-hidden="true"><path d="M19.5 14.6A7.5 7.5 0 1 1 9.4 4.5a6 6 0 0 0 10.1 10.1z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>
</button>
</div>
</div>
<article>
◊(if (select-from-metas 'title metas) "" "<h1 class=\"vh\">Occurrent Development</h1>")
◊(doc-body doc)
</article>
◊when/splice[(specimen? metas)]{<div class="tier" aria-hidden="true"></div>}
</div>
</div>
<script type="module" src="◊(asset-url "assets/js/site.js")" data-tables="◊(asset-url "assets/js/tables.js")"></script>
</body>
</html>
