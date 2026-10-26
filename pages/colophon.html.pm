#lang pollen

◊define-meta[title]{Colophon}

This site is written in Pollen markup, built with Racket on GitHub Actions,
and served as static files by Cloudflare. It uses no framework, no
third-party requests and, apart from a few lines that remember your choice of
theme, no JavaScript.

◊section[#:id "type" #:short "Type"]{Type}

The text face is Libertinus Serif, version 7.051, by the Libertinus Project
Authors, released under the SIL Open Font License 1.1 and maintained at
github.com/alerque/libertinus. It descends from Linux Libertine. Code is set
in Libertinus Mono. The fonts are subset to the characters the site uses and
served from this domain.

Body text is set at 20 pixels (at the browser's default size) on a line height
of 1.5. The column is 36.5 em wide, 730 pixels at the default size, which
gives a mean of 88.6 characters a line over twenty full lines of ordinary
prose; the limit is 90.

The layout has four widths, measured in em so that they follow the text size
and the browser's zoom. Below 39 em the column narrows and is set ragged right;
from 39 em it holds the full measure and is justified; from 66.5 em both
margins appear, margin notes on the left (8 to 13 em) and asides and the
words of figures on the right (13 to 20 em), 2.5 em from the column, the
right widening first, to 20 em at 73.5 em, then the left, to 13 em at
78.5 em; and from 80 em a page with contents shows them as the first column
of the text block, 11 em wide and 2.5 em from the left margin, the four
centred together, the margins widening again at 87 and 92 em. At the default
size the tiers begin at 780, 1330 and 1600 pixels.

◊section[#:id "citations" #:short "Citations"]{Citations}

References are kept in Zotero and formatted by pandoc with the Chicago Manual
of Style, eighteenth edition, notes and bibliography style, from the Citation
Style Language project, under a Creative Commons Attribution-ShareAlike 3.0
licence.
