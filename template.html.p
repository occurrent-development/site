<!doctype html>
<html lang="en-AU">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>◊(page-title metas)</title>
◊when/splice[(select-from-metas 'unlisted metas)]{<meta name="robots" content="noindex">
}<meta name="color-scheme" content="light dark">
<script>◊(head-script)</script>
◊(font-preloads)
<style>
◊(site-css)◊when/splice[(specimen? metas)]{◊(specimen-css)}</style>
</head>
<body>
<div class="page">
<header class="site-header">
<a class="site-name" href="/">Occurrent Development</a>
<button id="theme" class="theme-toggle" type="button" aria-label="Theme" hidden>
<svg class="icon-auto" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.5" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 4.5a7.5 7.5 0 0 0 0 15z" fill="currentColor"/></svg>
<svg class="icon-light" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12h2.5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
<svg class="icon-dark" viewBox="0 0 24 24" aria-hidden="true"><path d="M19.5 14.6A7.5 7.5 0 1 1 9.4 4.5a6 6 0 0 0 10.1 10.1z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>
</button>
</header>
<article>
◊(if (select-from-metas 'title metas) (->html (essay-header metas)) "")
◊(doc-body doc)
</article>
◊when/splice[(specimen? metas)]{<div class="tier" aria-hidden="true"></div>}
</div>
<script>◊(theme-script)</script>
◊when/splice[(specimen? metas)]{<script>◊(specimen-script)</script>}
</body>
</html>
