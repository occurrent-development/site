#lang pollen

◊define-meta[title]{Specimen}
◊define-meta[subtitle]{Every element the site can render, set as an essay would be}
◊define-meta[specimen]{yes}
◊define-meta[unlisted]{yes}
◊define-meta[epistemic]{A test page. Its claims are about its own typesetting and are checked by looking at it.}
◊define-meta[abstract]{This page exists to be judged rather than read. It shows the column, the face, the headings, the breaks and the two themes at the size and measure the essays will use, so that a change to any of them can be checked in one place. Elements that arrive in later phases are listed at the end.}

◊epigraph[#:source "Heraclitus, as reported by Plato, Cratylus 402a"]{You could
not step twice into the same river.}

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
and its own ◊strong{semibold}} where it needs them.

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
◊summary{Light and dark, and the candidate colours still to be chosen.}

The site follows the reader's system setting for light or dark, and the
control at the top right of the page can fix it to either. The light theme is
black on a dark ivory, warm enough to be easy on the eye over a long essay
without looking like an affectation. The dark theme is a light grey on a
near-black, never pure white, which halates and seems to vibrate when read
for any length of time. The two themes are related by a slight warmth in the
dark background.

The exact colours are still to be chosen, and the small panel at the bottom
right of this page cycles through the candidates for whichever theme is
showing, with the contrast ratio of each pair. Every pair passes the
◊sc{WCAG} AA standard by a wide margin; the choice between them is one of
feel, and should be made by reading this page for a while in each.

◊break{}

Colour in running text is reserved for one thing: the small marks that show
a word is a link, a citation, a definition or an aside. Nothing is
underlined, anywhere. Link text stays in the colour and weight of the text
around it, and the mark after it is the only signal, as on Matthew Butterick's
◊em{Practical Typography}. The marks are shown in the section on
◊link["#marks"]{marks and links} below.

◊section[#:id "furniture" #:short "Furniture"]{Page furniture}
◊summary{Headings, breaks, quotations and the intro paragraph.}

Headings come in three levels and are never numbered. The first level is set
in small capitals, aligned right, with a hairline rule running the width of
the column beneath it; the second is in smaller small capitals, aligned left,
without a rule; the third is italic, at the size of the text, and runs into
its paragraph. Each heading carries a section mark, visible on hover, which
links to the section itself, so a reader can copy a link to any part of an
essay.

◊subsection[#:id "quotations"]{Quotations}

A long quotation is set as a block, indented from the left, at the size of
the text. Darwin's closing sentence to the first edition of the ◊em{Origin}
is the standard example of a long sentence that still holds together:

◊blockquote{There is grandeur in this view of life, with its several powers,
having been originally breathed into a few forms or into one; and that, whilst
this planet has gone cycling on according to the fixed law of gravity, from so
simple a beginning endless forms most beautiful and most wonderful have been,
and are being, evolved.}

The paragraph after a quotation is not indented, because it continues the
paragraph the quotation interrupted. Elsewhere, a new paragraph is marked by
an indent rather than a blank line, which keeps the page continuous and the
paragraphs visibly part of one argument.

◊subsection[#:id "breaks"]{Breaks}

A change of direction within a section is marked by a section break: a single
small glyph, centred, with equal space above and below. It is placed by
hand, never automatically, and there is only one design. An explicit line
break, rarely needed in prose,◊br{}looks like this.

◊subsubsection[#:id "intro"]{The first paragraph.} The first paragraph of an
essay is marked as its introduction. On a phone or a narrow window, its first
line is set in small capitals, a quiet signal that the essay has begun. On a
wide screen, where the margin will carry notes and asides, the first line is
set like any other.

◊section[#:id "marks" #:short "Marks and links"]{Marks and links}
◊summary{The small signs that say a word leads somewhere, and where.}

◊margin{The mark is the only signal.} Every annotation carries a small mark
after its last word, and the mark says what kind of thing it is. A link to
another site, such as ◊link["https://plato.stanford.edu/entries/process-philosophy/"
#:note "Standard overview; good on Whitehead's debt to Bergson."]{the
◊em{Stanford Encyclopedia} entry on process philosophy}, ends in a north-east
arrow. A link to another page of this site, such as the
◊link["/colophon#type"]{colophon's note on type}, ends in a plain arrow. A
link within the page points up or down to its target: back to
◊link["#measure"]{the section on measure}, or on to
◊link["#lists"]{the section on lists}. The text itself keeps the colour of the
words around it, and takes the accent only on hover or focus.

Definitions are marked with three bars. The first time a defined word
appears, such as ◊term["occurrent"]{occurrent} or
◊term["looping-effect"]{looping effects}, it is marked and leads to its
definition; later uses, like this second ◊term["occurrent"]{occurrent}, are
plain text. Once popups arrive, a definition will open where the reader is;
until then, and whenever scripts are off, it is collected under Terms at the
end of the page.

◊section[#:id "notes-asides" #:short "Notes and asides"]{Notes and asides}
◊summary{Numbered notes for sources; roman numerals for digressions.}

Citations become numbered notes, collected at the end. The first note for a
work gives it in full: Hacking's account of how classifications change the
people classified first appeared in the ◊em{London Review of
Books} ◊cite["hackingMakingPeople2006" #:loc "p. 23"] and is developed at
length elsewhere ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"].
Later notes for the same work use the short form, with their own
page ◊cite["hackingMakingPeople2006" #:loc "p. 24"], and a note may carry a
remark of its own ◊cite["hackingMakingPeople2006" #:note "The lecture version
is shorter and sharper."].

◊margin{Asides can be skipped.} An aside is a digression the argument does
not need◊aside{An aside may cite, too: Hacking's essay on
◊term["looping-effect"]{looping} is the fuller version of the
argument ◊cite["hackingLoopingEffectsHuman1996"]. Its note is numbered here, at
its place in the argument.} and is marked with a roman numeral. On a wide
screen it will sit in the right margin, collapsed to its first line until
opened; on a phone it will open over the text. Without scripts, as now, each
aside is collected at the end, with a link back.◊aside{A second aside, to show
the numbering.}

◊section[#:id "lists" #:short "Lists"]{Lists}
◊summary{Bullets by level, and numbers that follow the nesting.}

A list is for items that are truly parallel. Bullets change by level, and
numbers follow the nesting:

◊list{
- A first-level item, marked by a small hollow circle
  - A second-level item, marked by an angle quote
    - A third-level item, marked by an en dash
- Numbers and bullets mix:
  1. a numbered item under a bullet starts at one
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
◊summary{Images at three widths, with captions, credits and both themes.}

A figure sits at the width of the column, of the column and margin together,
or of the page. Line art is drawn as SVG in the text colour, so it follows the
theme without any inversion:

◊figure["img/occurrent-continuant.svg" #:alt "Three identical circles at
three moments, labelled continuant, above a single wavy band stretched across
the same three moments and divided into parts, labelled occurrent."
#:licence "own"]{The ◊term["continuant"]{continuant} and the occurrent,
drawn for this page.}

A photograph or a rendering is served in several sizes and formats, and the
browser picks the smallest that will look sharp. This one is wide:

◊figure["img/landscape.jpg" #:alt "A grey surface sloping away from the
viewer, its single valley dividing into three as it descends." #:licence "own"
#:width "wide" #:invert #t]{A developmental landscape in the manner of
C. H. Waddington's, rendered for this page: one valley that divides as it
descends, so that a ball rolling down it ends in one of three places.}

◊section[#:id "tables" #:short "Tables"]{Tables}
◊summary{Rules above and below, lining figures, numbers aligned right.}

Tables follow the booktabs convention: no vertical rules, a heavier rule above
the header and at the foot, a hairline under the header. Figures are lining
and of equal width, and columns of numbers align right on their own. This one
records the measure calibration, and is long enough to be sortable once the
script for that arrives:

◊table[#:caption "Measure against characters per line, Libertinus Serif at 20
px" #:source "Measured on this page in Chrome, October 2026."]{
| Measure (em) | Width (px) | Mean characters | Longest line |
|---|---|---|---|
| 34.5 | 690 | 83.0 | 89 |
| 35.5 | 710 | 85.1 | 94 |
| 36.0 | 720 | 87.5 | 94 |
| 36.5 | 730 | 88.6 | 94 |
| 37.0 | 740 | 89.8 | 99 |
| 37.5 | 750 | 90.4 | 99 |
}

A table can also come from a file, and be set smaller:

◊table-csv["data/budget.csv" #:caption "The performance budget" #:size
"small"]

◊section[#:id "to-come" #:short "Still to come"]{Still to come}
◊summary{What this page will show once the interactive phase is built.}

Everything above works without scripts. The next phase adds the behaviour:
popups for notes, definitions and links, with the definitions embedded in
the page; asides in the right margin, collapsed to a single line until
opened; margin notes lifted out of the text into the margin; a slim bar at
the top of the screen naming the current section; sortable tables; and
images classified once for dark mode. Each will be checked here as it is
built.
