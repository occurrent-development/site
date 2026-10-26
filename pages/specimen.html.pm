#lang pollen

◊define-meta[title]{Specimen}
◊define-meta[subtitle]{Every element the site can render, set as an essay would be}
◊define-meta[specimen]{yes}
◊define-meta[published]{2026-10-09}
◊define-meta[tags]{site, typography}
◊define-meta[unlisted]{yes}

◊epistemic{A test page. Its claims are about its own typesetting and are
checked by looking at it.}

◊abstract{This page exists to be judged rather than read. It shows the column,
the face, the headings, the breaks and the two themes at the size and measure
the essays will use, so that a change to any of them can be checked in one
place. Elements that arrive in later phases are listed at the end.}

◊epigraph[#:source "Heraclitus, as reported by Plato, Cratylus 402a"]{You could
not step twice into the ◊em{same} river.}

A page of prose is a machine for being forgotten. When it works, the reader
sees the argument and not the letters; the column is the right width for the
eye to return to the next line without searching, the spacing is even enough
that no word announces itself, and the figures sit among the lowercase rather
than standing above it like fence posts. This page is where those things are
tuned. It is set exactly as an essay would be, with the same face, size,
leading and measure, so that what is decided here holds everywhere else.

◊section[#:id "column" #:short "The column"]{The column and its measure}
◊summary{How wide the text runs, and why it is calibrated by counting.}

The width of a column of text is called its measure. Too narrow, and the
reader's eye is forever jumping back to the left margin, the lines break
awkwardly, and hyphens pile up at the right. Too wide, and the eye loses its
place on the long return sweep and has to hunt for the start of the next line.
The usual advice is somewhere between forty-five and ninety characters a line,
and this site sits deliberately at the generous end: the essays are long, the
sentences are often long, and a wider column lets a complicated sentence hold
together on the page.

◊subsection[#:id "measure"]{Measuring the measure}

A browser offers a unit called the ◊code{ch}, which sounds like exactly the
right thing: one ◊code{ch} is the width of the digit zero, so ninety of them
should be ninety characters. In practice it is not, because a zero is wider
than the average letter of running English, which is full of narrow letters
like i, l, t and r, and of spaces. A column set to ninety ◊code{ch} holds
closer to a hundred and ten characters of prose. So the column here is set in
◊code{em}, relative to the size of the type, and the width was found by
rendering this page and counting the characters on twenty full lines, then
adjusting until the mean came in at or under ninety.

Because the width is in ◊code{em}, it follows the type. If a reader zooms in,
or has set a larger default font, the column widens in proportion and still
holds the same number of characters. The layout breakpoints follow the same
rule, which is why they are written as container queries rather than media
queries: a container query measured in ◊code{em} asks whether the text fits,
not whether the window is a certain number of pixels wide.

There are four widths. Below 39◊code{em} the column narrows and its right
edge is ragged (tier S). From 39◊code{em} it holds the full measure and is
justified (tier M). From 66.5◊code{em} both margins appear (tier L): margin
notes on the left, at least 8◊code{em} wide, and asides and the words of
figures on the right, at least 13◊code{em}, with 2.5◊code{em} between each
margin and the column and 2◊code{em} clear at either side. The right margin
widens first, reaching 20◊code{em} at 73.5◊code{em}; then the left, reaching
13◊code{em} at 78.5◊code{em}. From 80◊code{em}, a page with contents also
shows them as the first column of the block, 11◊code{em} wide and
2.5◊code{em} from the left margin, and the four columns are centred together
(tier XL); the margins then widen in the same order, at 87 and 92◊code{em}.
At the default size, where an ◊code{em} is 20 pixels, the tiers begin at 780,
1330 and 1600 pixels; one size smaller, 718, 1224 and 1472; one larger, 858,
1463 and 1760.

◊subsection[#:id "justification" #:short "Justification"]{Justification and hyphenation}

At full measure the text is justified, and hyphenation is switched on so that
the spaces between words stay close to their natural width. Justification
without hyphenation produces rivers, those channels of white that wander down
a paragraph when several lines in a row have had their spaces stretched to fill
the line. With hyphenation the browser can break a long word such as
◊em{institutionalisation}, ◊em{characteristically} or ◊em{incomprehensibility}
across two lines and keep the spacing even.

◊subsubsection[#:id "narrow"]{On narrow screens.} Below full measure, on a
phone or a narrow window, the text is set ragged right. A short line has too
few spaces to absorb the stretching that justification demands, and the result
is worse than an uneven right edge. Hyphenation stays on, which keeps the rag
from becoming too ragged. Rotating a phone from portrait to landscape can be
enough to cross the threshold, and the setting changes with it.

◊subsubsection[#:id "language"]{Language.} The page declares its language as
Australian English, which matters for hyphenation as well as for screen
readers: the hyphenation dictionaries differ between varieties of English, and
a word like ◊em{programme} or ◊em{colour} should break by the rules of the
spelling it uses.

◊section[#:id "face" #:short "The face"]{The face}
◊summary{Libertinus Serif, its figures, its small caps, and its spacing.}

The text face is Libertinus Serif, a descendant of Linux Libertine, released
under the Open Font License. It has an unusually wide character set, with
Greek, Cyrillic, a great many accented Latin letters and a full set of
mathematical companions, and it has the features that a text face for long
essays needs: true small capitals, old-style figures, and a proper italic
rather than a slanted roman. It is a little lighter and more open than many
screen faces, which is why the body is set at twenty pixels rather than
sixteen.

◊subsection[#:id "figures"]{Figures and small caps}

In running text the figures are old-style: they have ascenders and descenders
like lowercase letters, so a number such as 1859, 2026 or 3,481 sits in the
line instead of shouting over it. Tables, when they come, will use lining
figures of equal width, so that columns of numbers align. Acronyms are set in
small capitals, marked by hand rather than detected, so that ◊sc{WHO},
◊sc{DSM-5} and ◊sc{ICD-11} are no louder than the words around them, while an
ordinary capital at the start of a sentence keeps its full height. ◊strong{Bold
type is used rarely}, and when it is, it is the semibold weight; emphasis is
◊em{italic}, and ◊em{an italic passage keeps its own figures, 1859 and 2026,
and its own ◊strong{semibold}} where it needs them. The ◊latex{} logo is set from
the same letters, kerned as TeX sets it, and follows whatever is around it:
◊em{in italic, ◊latex{}}◊aside{In an aside, too: ◊latex{} at the aside's
size.}, and in an aside.

◊subsection[#:id "spacing"]{Spacing rules}

A short table of rules runs over every string of text after the source is
read, and each rule has a test. Straight quotes become "curly" ones, and
apostrophes in words like it's and the Smiths' turn the right way. A dash
typed as three hyphens---like this---becomes an em dash with hair spaces
either side, held to the preceding word so that no line begins with a dash.
Two hyphens make an en dash, used for ranges such as Monday--Friday; a range
of digits typed with a single hyphen, as in 1998-2004 or pages 112-19, is
corrected to an en dash too. Three dots become an ellipsis...

Other rules tie together what should not be separated at a line break. A
number and its unit are joined by a narrow no-break space, so that 10 kg,
5 mg, 37 °C and 20 min each stay on one line. Initials are joined the same way,
as in C. H. Waddington or J. J. Gibson, and a locator stays with its number, as
in p. 42, pp. 108-11 or ch. 3. Between digits, the letter x becomes a
multiplication sign, so that 3 x 4 and 1920 x 1080 read as they should.
None of this happens inside code, so ◊code{"10 kg" -- 3 x 4...} is left
exactly as typed.

◊section[#:id "themes" #:short "Themes"]{Colour and themes}
◊summary{Light and dark, and how the two are related.}

The site follows the reader's system setting for light or dark, and the
control at the top right of the page can fix it to either. The light theme is
black on a dark ivory, warm enough to be easy on the eye over a long essay
without looking like an affectation. The dark theme is a light grey on a
near-black, never pure white, which halates and seems to vibrate when read
for any length of time. The two themes are related by a slight warmth in the
dark background.

The colours were chosen by reading this page for a while in each theme:
black on #EFE7D4, and #D2D2D0 on #121212. Both pairs pass the ◊sc{WCAG} AA
standard by a wide margin, as does every colour the page uses for marks,
rules and quieter text.

The text size, set from the bar, steps everything in this face together: the
column, the margin, the contents and anything open over the page. Open a
note, step the size, and it steps with the text, while the line at the top of
the window stays where it was.

◊break{}

Colour in running text is reserved for one thing: the small marks that show
a word is a link, a citation, a definition or an aside. Nothing is
underlined, anywhere. Link text stays in the colour and weight of the text
around it, and the mark after it is the only signal, as on Matthew Butterick's
◊em{Practical Typography}. The marks are shown in the section on
◊link["#marks"]{marks and links} below.

◊section[#:id "furniture" #:short "Furniture"]{Page furniture}
◊summary{The header, headings, breaks, quotations and the intro paragraph.}

Headings come in three levels and are never numbered. The first level is set
in small capitals, aligned right, with a hairline rule running the width of
the column beneath it; the second is in a semibold sans, aligned left,
without a rule; the third is in the same sans, at a smaller size, and runs
into its paragraph. Each heading carries a section mark, visible on hover,
which links to the section itself, so a reader can copy a link to any part of
an essay.

◊subsection[#:id "header"]{The header}

Nothing on a page is centred but the section break. The header at the top of
this page shows the full form: title, subtitle and abstract in the column,
closed by a short rule, and, on a wide screen, the facts about the page in the
right margin beside the title, their first line on the subtitle's baseline.
The dates come first, one to a line; then the tags, labelled; then links to
the page's source and to its history; and last, after a gap, the epistemic
status, the one line of prose among them, when there is one. Where the window
is wide enough for the contents beside the left margin, their heading starts
on the same baseline, with the menu above it. On a narrower screen the same
lines fall back between the subtitle and the abstract. An essay without an abstract looks like this,
closed by its rule after the subtitle:

◊header-sample[#:title "A sample header, with a title long enough to need two
lines" #:subtitle "And a subtitle, in italic" #:published "2026-10-01"
#:revised "2026-10-15" #:tags "site, typography" #:epistemic "A sample. Its
block starts on the subtitle's baseline."]

A notebook entry has the same header with less in it: no epistemic status,
so no gap, and no contents however many sections it has. With no subtitle,
its block starts on the line a second line of the title would take. Its tags lead to
the notebook's index rather than the essays':

◊header-sample[#:kind "entry" #:title "A sample entry" #:published
"2026-10-21" #:tags "site"]

The epigraph at the top of the page is set a little in from the left edge, in
italic, with its source on a line of its own at the right; the ◊em{same} in
it is emphasis, set roman because the epigraph is italic. The abstract is
introduced by a small heading of its own, run into its first line.

◊subsection[#:id "quotations"]{Quotations}

A long quotation is set as a block, indented from the left, at the size of
the text and in roman: it is set off from the body by its indent, not by its
style, so emphasis and titles inside it keep their italic. Its source, when it
has one, is on a line of its own at the right, as an epigraph's is. Darwin's
closing sentence to the first edition of the ◊em{Origin} is the standard
example of a long sentence that still holds together:

◊blockquote[#:source "Charles Darwin, On the Origin of Species, 1859; emphasis added"]{◊margin{A note on a quoted paragraph}There is grandeur in this view of life, with its several powers,
having been originally breathed into a few forms or into one; and that, whilst
this planet has gone cycling on according to the fixed law of gravity, from so
simple a beginning ◊em{endless forms most beautiful} and most wonderful have
been, and are being, evolved.}

A quotation whose own typography depends on italic can be set italic, and
emphasis inside it then turns roman, so the stress survives:

◊blockquote[#:italic #t]{An italic block quotation, in which a word is
◊em{emphasised} and so set upright.}

An epigraph does the reverse. It is italic by default, as the one at the top
of this page is, and can be set roman, when emphasis is italic again:

◊epigraph[#:italic #f #:source "A roman epigraph"]{An epigraph set roman, for
a long one of running prose, with ◊em{emphasis} in italic.}

The paragraph after a quotation is not indented, because it continues the
paragraph the quotation interrupted. Elsewhere, a new paragraph is marked by
an indent rather than a blank line, which keeps the page continuous and the
paragraphs visibly part of one argument.

◊subsection[#:id "breaks"]{Breaks}

A change of direction within a section is marked by a section break: a single
small glyph, centred, with equal space above and below. It is placed by
hand, never automatically, and there is only one design. An explicit line
break, rarely needed in prose,◊br{}◊margin{After a line break}looks like this.

◊subsubsection[#:id "intro"]{The first paragraph.} The first paragraph of an
essay is marked as its introduction. On a phone or a narrow window, its first
line is set in small capitals, a quiet signal that the essay has begun. On a
wide screen, where the margin will carry asides and margin notes, the first line is
set like any other.

◊section[#:id "marks" #:short "Marks and links"]{Marks and links}
◊summary{The small signs that say a word leads somewhere, and where.}

◊margin{The mark is the only signal.} Every annotation carries a small mark
after its last word, and there are only two kinds. An arrow takes the reader
away from where they are reading, and points the way it goes: to another
site, such as ◊link["https://plato.stanford.edu/entries/process-philosophy/"
#:note "Standard overview; good on Whitehead's debt to Bergson."]{the
◊em{Stanford Encyclopedia} entry on process philosophy}; to another page of
this site, such as the ◊link["/colophon#type"]{colophon's note on type}; or
within this page, back to ◊link["#measure"]{the section on measure} or on to
◊link["#lists"]{the section on lists}. The text itself keeps the colour of
the words around it, and takes the accent only on hover or focus.

A circle opens something where the reader is, without moving the page: a
definition, a note or an aside. The first time a defined word appears, such
as ◊term["occurrent"]{occurrent} or ◊term["looping-effect"]{looping effects},
it carries a circle; later uses, like this second
◊term["occurrent"]{occurrent}, are plain text. ◊margin{A note at a sentence
inside a paragraph} A definition opens over the
page at every width, as a note does, with the word as its title and the short
definition below it: resting the pointer on the word opens it, and clicking
pins it, its circle filled. More opens the longer discussion in place, and a
defined word inside it, such as those under See also, replaces the definition
with its own, with Back to return. Definitions never sit in the margin, which
is kept for commentary on the passage beside it. Without scripts, a circle is
a link to the end of the page, where definitions are collected under Terms.

◊section[#:id "notes-asides" #:short "Notes and asides"]{Notes and asides}
◊summary{Circles for sources and digressions; the numbers stay with the notes.}

Citations become numbered notes, collected at the end under Notes, but the
number belongs to the note and is never printed in the text. Every work the
page cites is listed again after the notes, in a Bibliography, so that an
essay is complete without the rest of the site. The first note for a work
gives it in full: Hacking's account of how classifications change the people
classified first appeared in the ◊em{London Review of
Books} ◊cite["hackingMakingPeople2006" #:loc "p. 23"] and is developed at
length elsewhere ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"].
Later notes for the same work use the short form, with their own
page ◊cite["hackingMakingPeople2006" #:loc "p. 24"], and its popup adds the
work in full; a note may also carry a remark of its own ◊cite["hackingMakingPeople2006" #:note "The lecture version
is shorter and sharper."]. Two citations at the same point share one
circle◊cite["hackingLoopingEffectsHuman1996"]◊cite["hackingSocialConstructionWhat2000"
#:loc "pp. 31-34"], which opens both. A note opens over the page at
every width, and its circle stays filled for as long as it is pinned open.

◊margin{Asides can be skipped, and this note runs to a second line.} An aside
is a digression. ◊margin{Two notes close together} The argument does not
need it◊aside{An aside may cite, too: Hacking's essay on
◊term["looping-effect"]{looping} is the fuller version of the
argument ◊cite["hackingLoopingEffectsHuman1996"]. Its note is numbered at
its place in the argument.} and is unnumbered. On a wide screen it sits in the
right margin as a single line, cut short; resting the pointer on it lets it
grow downward in place, and clicking pins it there. A short one is shown
whole. Pin the first aside and then open the circle inside it: the note opens over the page, and the aside stays where
it is. On a narrower screen both open over the text. Without scripts each
aside is collected at the end, with a link back.◊aside{A short aside is shown in full.}

On a wide screen with a pointer, several popups can be kept open at once.
Clicking a circle pins its popup, and so does Pin in its title bar; up to
six stay, and a seventh closes the oldest. Each can be dragged by its title
bar, anywhere in the window, and resized from its corner, and the one last
touched is on top. Escape closes the one that has focus and no other; each
has its own close button. Where the contents show beside the margin, Dock
sends a popup to the space beneath them, where it stays in view as the page
scrolls; dragging it out sets it loose again. Pin two notes, drag one, and
dock the definition of ◊term["continuant"]{continuant}
to see all three. Beneath the contents, and at the foot of the menu, the
scratch pad is a place to keep notes while reading: one pad for the whole
site, kept in the browser and never sent anywhere.

An aside that qualifies a particular phrase names it, and then the phrase and
its circle are one link: hover over ◊aside["the phrase form"]{The phrase is
printed in the text, followed by its circle, and the two are one link with
one hit area and one name. On a wide screen the aside waits in the right
margin as a stub, like any other; while it is open the circle is filled and
the phrase keeps the accent, so the reader can see which words it is about.},
and both take the accent. Punctuation after the phrase sits
between its last word and the circle. A phrase may carry
◊aside[◊em{emphasis} " or small caps"]{As in ◊sc{ASIDE-8}.}, and when a
citation follows ◊aside["at the same point"]{The aside opens first, then the
note.} ◊cite["hackingLoopingEffectsHuman1996"] the two share one circle.

◊section[#:id "lists" #:short "Lists"]{Lists}
◊summary{Bullets by level, and numbers that follow the nesting.}

A list is for items that are truly parallel. Bullets change by level, and
numbers follow the nesting:

◊list{
- A first-level item, marked by a small dot
  - A second-level item, marked by an angle quote
    - A third-level item, marked by an en dash
- Numbers and bullets mix:
  1. ◊margin{A note in a numbered item}a numbered item under a bullet starts at one
  2. and its children carry the chain
     1. so this is 2.1
        1. and this is 2.1.1
- An item can run to a second paragraph.

  Indented after a blank line, the paragraph stays in the item.
}

Short items can be set in columns on a wide screen, reading down and then
across:

◊list[#:columns 2]{
1. occurrent
2. continuant
3. process
4. disposition
5. function
6. role
}

◊section[#:id "images" #:short "Figures"]{Figures}
◊summary{Numbered, titled and captioned, at the width of the column.}

A figure sits at the width of the column and never in a margin. Its number
and title, its caption and its credit sit in the right margin on a wide
screen, beside the top of the figure; on a narrower one the title is above it
and the rest below. Each is numbered in order, as tables are, and the text
refers to it by its id, which prints the number: ◊ref["two-kinds"] is line art,
drawn as SVG in the text colour, so it follows the theme without any
inversion.

◊figure["img/occurrent-continuant.svg" #:id "two-kinds" #:title "The
continuant and the occurrent" #:alt "Three identical circles at three
moments, labelled continuant, above a single wavy band stretched across the
same three moments and divided into parts, labelled occurrent."
#:licence "own"]{A ◊term["continuant"]{continuant} is wholly present at each
moment; an occurrent has a different part at each. Drawn for this page.}

A photograph or a rendering is served in several sizes and formats, and the
browser picks the smallest that will look sharp. ◊ref["landscape"] is one;
like every figure and table it has an Expand button at its top right, which
shows it as large as the window allows, over the page.

◊figure["img/landscape.jpg" #:id "landscape" #:title "A developmental
landscape" #:alt "A grey surface sloping away from the viewer, its single
valley dividing into three as it descends." #:licence "own" #:credit "After
C. H. Waddington (1957); rendered for this page."]{One valley that divides as
it descends, so that a ball rolling down it ends in one of three places. The
line below is a credit, set apart from the caption as every credit is, and as
a table's source is.}

◊section[#:id "tables" #:short "Tables"]{Tables}
◊summary{Rules above and below, lining figures, numbers aligned right.}

Tables follow the booktabs convention: no vertical rules, a heavier rule above
the header and at the foot, a hairline under the header. Figures are lining
and of equal width, and columns of numbers align right on their own. This one
records the measure calibration, and like any table of five rows or more it
can be sorted by clicking a column's heading. ◊ref["calibration"] is the
first table, so it is numbered 1 whatever figures come before it:

◊table[#:id "calibration" #:title "Measure against characters per line"
#:caption "Libertinus Serif at 20 px." #:source "Measured on this page in
Chrome, October 2026."]{
| Measure (em) | Width (px) | Mean characters | Longest line |
|---|---|---|---|
| 34.5 | 690 | 83.0 | 89 |
| 35.5 | 710 | 85.1 | 94 |
| 36.0 | 720 | 87.5 | 94 |
| 36.5 | 730 | 88.6 | 94 |
| 37.0 | 740 | 89.8 | 99 |
| 37.5 | 750 | 90.4 | 99 |
}

A long table keeps its header row in view while it passes beneath the top of
the window. These are the twenty full lines counted for the calibration above,
in the order they appear on this page:

◊table[#:id "lines" #:title "The twenty lines counted, at 36.5 em" #:size
"small" #:caption "Mean 88.6 characters. Lines beginning mid-word continue a
hyphenated word."]{
| Line | Opens with | Characters |
|---|---|---|
| 1 | The width of | 88 |
| 2 | forever jumping back | 87 |
| 3 | at the right. | 87 |
| 4 | hunt for the | 89 |
| 5 | ninety characters a | 93 |
| 6 | long, the sentences | 87 |
| 7 | A browser offers | 91 |
| 8 | the width of | 93 |
| 9 | not, because a | 89 |
| 10 | narrow letters like | 93 |
| 11 | hundred and ten | 90 |
| 12 | of the type, | 87 |
| 13 | default font, the | 87 |
| 14 | ters. The layout | 87 |
| 15 | tainer queries rather | 87 |
| 16 | At full measure | 88 |
| 17 | between words stay | 86 |
| 18 | duces rivers, those | 85 |
| 19 | in a row | 87 |
| 20 | can break a | 91 |
}

A table can also come from a file, and be set smaller:

◊table-csv["data/budget.csv" #:id "budget" #:title "The performance budget"
#:size "small"]

◊section[#:id "to-come" #:short "Still to come"]{Still to come}
◊summary{What later phases add to the site, and to this page.}

Everything above works without scripts, and everything interactive is an
addition to it: the circles and stubs, the margin, the pinned popups and
their dock, the scratch pad, the bar that appears when you scroll back up
(at the top of the window, or at the bottom on a touch screen, with the
menu at its left end), the text size and theme controls, and the sortable
tables. On the widest screens the contents scroll with the page until they
reach the menu and then stay; once they stay, their heading becomes the
title of the page. What remains is around the essays rather than in
them: interactive figures, backlinks between essays, a changelog and a feed,
a page for correspondence, and a stylesheet for print. Each will be checked
here as it is built.
