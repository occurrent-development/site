#lang pollen

◊;{Test conversion of STYLE.md to a Pollen page. It is not listed in
index.ptree, so make neither renders nor publishes it; preview it with
make serve at /pages/style.html. STYLE.md is untouched and stays
authoritative until this page replaces it.}

◊define-meta[title]{Manual of Style}
◊define-meta[subtitle]{House style for everything on the site and in its repository}
◊define-meta[unlisted]{yes}

◊;{A page-local helper, not a tag: it prints the lozenge itself, so that
code samples can show Pollen syntax.}
◊(define (loz) "◊")

◊epistemic{Draft 1.2. A living document: when a rule proves wrong or a case is not covered, the rule is changed and the change is recorded in the changelog below.}

◊abstract{This is the house style for everything on the site and in its repository: prose, markup, metadata, files, and the look of the thing.
◊code{SPEC.md} is the build brief and says what the build ◊em{enforces}; this manual says what a writer ◊em{chooses}.
Where a rule here is also a requirement there, the ID follows it in parentheses (◊code{TYPE-16}).}

Owner: Ryan.
Modelled on ◊link["https://gwern.net/style-guide" #:note "The style guide this manual follows in structure."]{the Gwern style guide}.
The AI policy is on ◊link["/policies#ai-policy"]{the policies page}.

◊break{}

◊;{CONFLICT, for Ryan to resolve before this page is published. Three
passages carried over from STYLE.md unchanged disagree with the AI policy at /policies#ai-policy:
the first item of Usage (a Claude Code session that edits prose is a user of
this manual); the third item of Generative media (prose written with a model's
help carries no label); and the whole of Writing with an assistant (models
drafting and editing prose). Each has its own marker comment where it sits.}

◊section[#:id "usage"]{Usage}

◊;{CONFLICT: the first item below lists a Claude Code session that edits prose
among the users of this manual, which the AI policy (/policies#ai-policy) rules out. Ryan to decide.}

◊list{
- ◊em{Who it is for.}
Ryan when writing; anyone else whose essay is hosted here; and any Claude Code session that edits prose, names files, or touches the repository.
Handover documents point here rather than restating style.
- ◊em{Precedence.}
◊code{SPEC.md} (build-enforced, MUST/SHOULD, numbered) → this manual → taste.
A disagreement between the two is a defect: fix one, the same day, and say which.
- ◊em{Seed.}
◊code{SPEC.md} §17 was the first draft of this manual.
New conventions go here; §17 is to be reduced to a pointer at the next SPEC revision.
- ◊em{Errors.}
If a rule here is wrong, contradicts another, or cannot be followed in a case, report it with a suggested fix rather than silently working around it.
}

◊section[#:id "principles"]{Principles over rules}

The site's principles (◊code{SPEC.md} §1), in priority order:

◊list{
1. The reader never loses their place.
2. The source is the essay.
3. Fast.
4. Typography is not decoration.
5. Progressive enhancement.
6. Essays are living documents.
7. No engagement machinery.
8. We publish nothing that isn't ours.
}

When a rule in this manual conflicts with a principle, follow the principle.
Make the smallest change that works, and record the exception where it happens, in a Pollen comment on the line before: ◊code{◊(loz);{STYLE: why this breaks rule lists-and-tables}}.
An exception nobody can find is a precedent nobody can check.

◊section[#:id "condensed-manual"]{Condensed manual}

The whole thing on one screen.
Each line is expanded below.

◊list{
- Australian spelling (◊code{-ise}, ◊code{-our}, ◊code{programme}, ◊code{paediatrics}); metric units; ◊code{YYYY-MM-DD} in metas and filenames, "1 November 2026" in prose.
- Plain, analytical, first person.
Confidence lives in the epistemic line, so the body can speak without hedging.
- Headings in sentence case, naming what the section argues; three levels at most; never numbered.
- Emphasis is italic.
Nothing is ever underlined.
Bold is not typed in prose.
- Type straight quotes and ◊code{---}; the build curls and spaces them.
A straight quote in output fails the build.
- Double quotation marks, single inside.
Logical quotation: punctuation inside the marks only when it is part of what is quoted.
- Numbered Chicago notes, mark after the punctuation; page locators for quotations and specific claims; every quotation from a cited work is a ◊code{◊(loz)cite} with the quoted words as its body.
- Link the noun phrase, never "here"; first mention only; DOI over publisher URL; ◊code{#:note} on any external link a reader might wonder about.
- Iceberg: title → abstract → margin note → paragraph → aside → note → glossary or reference page.
Put each thing at the shallowest level where a reader who skips it loses nothing they need.
- Asides ≤ ~100 words; margin notes ≤ 8 words and read in sequence as an outline; a note cites, an aside comments.
- Define a term when a smart reader outside the field would ◊em{misread} it, not merely when they might not know it.
- Every essay has an abstract and an epistemic status.
An entry has neither and is never amended.
- Every figure has an id, a title, alt text and a licence; third-party diagrams are redrawn and credited "after X (year)".
- Files: ◊code{YYYY[-MM[-DD]]-surname[-tool[-topic[-description]]][-N].ext}, all lowercase, unique basenames, one extension per format.
Pages are slugs, not dated files.
- As few filetypes as possible, chosen for the long term: JPG/PNG/SVG sources, PDF documents, MP3 audio, UTF-8 comma-separated CSV.
- A published URL or anchor is a promise.
Nothing published is renamed without a redirect.
- Typo fixes are silent; anything a returning reader would want to know gets a changelog line.
A claim is never silently reversed.
- Clinical material is composite or altered beyond recognition, and the essay says so once.
}

◊section[#:id "writing"]{Writing}

◊subsection[#:id "register"]{Register}

◊list{
- ◊em{Plain and analytical.}
Short declaratives where the thought allows.
Formality rises with the novelty of the claim: a familiar point can be said lightly; a new one is stated carefully and once.
- ◊em{First person.}
"I" for what the author did, thinks or saw.
"We" only for a group the author belongs to and the reader can name (clinicians, the field, developmental paediatrics), never the editorial ◊em{we}.
"You" for the reader is allowed and often better than the passive.
- ◊em{Unhedged body, hedged header.}
The epistemic line (◊code{◊(loz)epistemic}) states how confident the essay is and on what basis.
That is where "speculative", "argued from theory" and "I have changed my mind about this before" belong.
The body then says things, rather than suggesting that it may perhaps be the case that.
- ◊em{Probability.}
Give the number when there is one.
Otherwise one plain word (unlikely, probably, almost certainly) and what it rests on.
Avoid "may" doing the work of "I don't know".
- ◊em{Statistics.}
◊em{False positive} and ◊em{false negative}, not Type I and II.
◊em{Statistical-significance testing}, not "significance" bare.
Report an effect with its size and interval, not a ◊em{p}-value alone.
Say ◊em{association} unless the design licenses ◊em{effect}.
- ◊em{Clinical material.}
No identifiable patient, ever: vignettes are composites or altered beyond recognition, and the essay says so once, usually in the epistemic line or the first aside that uses one.
Nothing that would let a family recognise themselves.
- ◊em{Names.}
People by surname after the first full mention.
No honorifics or post-nominals in prose; qualifications belong on the About page.
- ◊em{Profanity.}
Not in the author's voice.
Quoted where the quotation needs it, unaltered.
}

◊subsection[#:id "spelling-punctuation-numbers" #:short "Spelling and numbers"]{Spelling, punctuation, numbers}

◊list{
- ◊em{Spelling} is Australian (◊code{TYPE-5}): ◊code{-ise}, ◊code{-our}, ◊code{-re}, ◊code{paediatric}, ◊code{behavioural}, ◊code{programme}, ◊code{practise} (verb) / ◊code{practice} (noun), ◊code{judgement}.
Macquarie where in doubt.
- ◊em{Serial comma.}
Use it only where its absence would misread (the Australian Government Style Manual position).◊aside{Open decision ◊code{D5}: this is the recommendation; record the choice in SPEC when settled.}
- ◊em{Quotation marks.}
Type straight ◊code{"} and ◊code{'}; the build curls them from context (◊code{TYPE-16}).
Double outside, single inside.
Logical quotation: a full stop or comma goes inside the closing mark only when it is part of the quoted text.
- ◊em{Dashes.}
Type ◊code{word---word} for an em dash; the build sets it with hair spaces (◊code{TYPE-15}), so never type spaces around it.
En dash for ranges: type ◊code{1998-2004} between digits and the build converts it; type ◊code{–} by hand between words (◊em{the Sydney–Newcastle line}).
Hyphens for compounds only.
- ◊em{Ellipsis.}
Type ◊code{...}; the build sets ◊code{…}.
- ◊em{Numbers.}
Spell out one to nine; figures from 10, and always with a unit, a percentage or a decimal.
Digit-group comma from 10,000 (◊code{1000}, ◊code{12,000}).
Old-style figures in prose and lining in tables are the build's doing (◊code{TYPE-7}); nothing to type.
Type ◊code{10 kg} with a space; the build makes it non-breaking (◊code{TYPE-15}).
- ◊em{Dates.}
◊code{YYYY-MM-DD} in metas, filenames, tables and anything a machine reads.
In prose, day month year without ordinals: ◊em{1 November 2026}; ◊em{November 2026}; ◊em{the 1990s} (not ◊em{1990's}).
Ranges with an en dash: ◊em{2019-2024}.
- ◊em{Units.}
Metric, SI symbols, space between number and symbol (◊code{5 mg}, ◊code{37.5 °C}).
No full stops after symbols.
- ◊em{Abbreviations.}
No full stops in acronyms (◊code{WHO}, ◊code{NDIS}, ◊code{ADHD}).
Expand at first use unless the acronym is the common name.
Set an acronym in small caps with ◊code{◊(loz)sc{WHO}} (◊code{TYPE-11}; manual, not automatic).
◊em{e.g.}, ◊em{i.e.}, ◊em{cf.} are fine inside parentheses and asides; in running prose prefer ◊em{for example}, ◊em{that is}, ◊em{compare}.
- ◊em{Foreign phrases} italic unless naturalised (◊em{ad hoc}, ◊em{per se} and ◊em{vice versa} are naturalised; ◊em{pluralis auctoris} is not).
- ◊em{Titles of works.}
Italic for books, journals, films and series (◊em{Frasier}); quotation marks for articles, chapters and episodes ("The Show Where Lilith Comes Back").
Title case as the work itself prints it.
}

◊subsection[#:id "emphasis"]{Emphasis}

◊list{
- ◊em{Italic} (◊code{◊(loz)em}) is the only emphasis in prose.
Inside an italic block (an epigraph, an italic quotation) ◊code{◊(loz)em} flips to roman (◊code{LAYOUT-4c}).
- ◊em{Bold} (◊code{◊(loz)strong}) is not typed in running prose.
The build uses semibold for figure and table labels; a reader should be able to assume that bold is apparatus.
The one allowed use is a word the reader must not miss in a list of instructions (◊em{never} commit ◊code{support/}).
- ◊em{Small caps} (◊code{◊(loz)sc}) for acronyms and nothing else.
- ◊em{No underlines}, anywhere, for any purpose.
Links are marked by their arrows and circles, not by decoration (◊code{MARK-1}).
}

◊subsection[#:id "links"]{Links}

◊list{
- Link the noun phrase that names the thing (◊em{the SEP entry on process philosophy}), never ◊em{here}, ◊em{this}, or a bare URL.
- ◊em{First mention only} within a post.
Later mentions are plain text; the reader knows where the link is.
- ◊em{Primary sources.}
Prefer the paper to the press release, the DOI to the publisher URL, the author's page to a mirror.
Prefer a Wikipedia link only for a thing whose Wikipedia article is the best short introduction.
- ◊code{#:note} on any external link a reader might wonder about before clicking: what it is, why it is there, and when it was read if that matters.
One sentence.
(It feeds the link card, ◊code{CARD-1}.)
- ◊em{Internal links} are same-page (◊code{#id}) or cross-essay (◊code{/slug#id}); the build types them and fails on a broken target (◊code{LINK-1}, ◊code{LINK-2}).
Link to the most specific anchor that exists.
- ◊em{Never} copy or archive someone else's page or image (principle 8).
Quote, cite and link.
}

◊subsection[#:id "citations-and-quotations"]{Citations and quotations}

◊list{
- ◊em{Numbered notes}, Chicago notes-bibliography, numbered in source order including inside asides (◊code{CITE-1}).
The number appears in Notes and in print, never as a superscript on screen; the circle is the mark.
- ◊em{Mark after punctuation} (◊code{MARK-3a}): ◊code{…a claim about being.◊(loz)cite["key"]}
- ◊em{Locators} (◊code{#:loc "p. 42"}, ◊code{"pp. 31–34"}, ◊code{"ch. 3"}) for every quotation and every specific claim; a work cited for its general argument needs none.
Type ◊code{p. 42} with the space; the build keeps it together (◊code{TYPE-15}).
- ◊em{Quotations from cited works are marked} (◊code{BIB-9}): ◊code{◊(loz)cite["key" #:loc "…"]{the words}} inline, with ◊code{#:block #t} for a block quotation, whose attribution the build writes from the entry.
◊code{◊(loz)blockquote} and ◊code{◊(loz)epigraph} are for sources not in Zotero.
Quotation marks with a bare ◊code{◊(loz)cite} after them are for phrases too short to be worth listing on the work's page.
- ◊em{Keys} are Better BibTeX keys, pinned in Zotero, case-preserved (◊code{BIB-2}).
Never retype a key; ◊code{od-insert-cite} picks it.
- ◊em{Epigraphs} are italic, block quotations roman (◊code{LAYOUT-4a}, ◊code{4b}).
Flip with ◊code{#:italic} only for a reason (a long epigraph of running prose; a quotation whose own typography depends on italic).
If the flip is frequent, change the default, not each quotation.
- ◊em{No ibid.}, no ◊em{op. cit.}; the build handles full and short forms (◊code{CITE-3}).
- ◊em{Commentary on a work} (◊code{references/<key>.pm}, ◊code{BIB-3}) is rare and deliberate: write one when you have something to say about the work that no essay says.
}

◊subsection[#:id "terminology-and-glossary" #:short "Terminology"]{Terminology and the glossary}

◊list{
- Define a term when a smart reader outside the field would ◊em{misread} it, not merely when they might not know it.
◊em{Continuant} needs a definition; ◊em{neurodevelopmental} does not.
- ◊em{One sense, one term.}
A word used in a different sense is a separate glossary entry (◊code{canalisation}, ◊code{canalisation-waddington}; ◊code{TERM-1}).
- ◊em{Mark the first use} in a post with ◊code{◊(loz)term}; later uses are plain unless a reader arriving by anchor would need the definition again.
- ◊em{The definition} (◊code{glossary/<id>.pm}) opens with one sentence that stands alone in a popup; every paragraph after the first is the More, shown when the reader asks for it (no tag marks it, ◊code{TERM-2}).
Cite inside it freely (unnumbered, ◊code{CITE-7}).
- ◊em{House terms.}
◊em{Essay} and ◊em{entry} (never ◊em{post} in prose, though ◊code{SPEC.md} uses it as the type name); ◊em{Blog} for the second kind; ◊em{aside}, ◊em{margin note}, ◊em{note} (a citation), ◊em{definition}, ◊em{reference page}; ◊em{Edited} for the date git supplies, ◊em{revised} for a changelog line (◊code{REV-1}); ◊em{contents} not ◊em{table of contents}; ◊em{reading bar} not ◊em{toolbar}.
}

◊section[#:id "structure"]{Structure}

◊subsection[#:id "iceberg"]{The iceberg}

Every post has depth, and the reader controls how far down they go.
Place each thing at the shallowest level where a reader who skips it loses nothing they need:

◊list{
1. ◊em{Title and subtitle}: what it is.
2. ◊em{Abstract}: what it argues, in ≤ ~120 words, not what it is about.
If the abstract could be true of a different essay, it is a description, not an abstract.
3. ◊em{Epistemic status}: how confident and on what basis; where the author has changed their mind.
4. ◊em{Margin notes}: ≤ 8 words each, sparing, anchored to a sentence or item (◊code{MNOTE-6}); read in sequence they are a rough outline of the argument.
5. ◊em{Paragraphs}: the argument.
If the argument needs it, it belongs here and nowhere deeper.
6. ◊em{Asides}: ≤ ~100 words; something a reader could skip.
Longer asides fall out of the margin and probably want to be sections.
Use the phrase form (◊code{◊(loz)aside["phrase"]{…}}) when the aside qualifies a specific phrase and a reader would want to know which; the bare circle when it comments on the sentence or the thought.
Keep the phrase to a few words: the longer it is, the more it reads as a link that goes somewhere.
7. ◊em{Notes}: a note cites.
Commentary in a note is a sign it should have been an aside.
8. ◊em{Glossary and reference pages}: site-wide, shared, written once.
}

◊subsection[#:id "sections-and-headings"]{Sections and headings}

◊list{
- ◊em{Sentence case}, naming what the section argues (◊em{Why the labels feel heavy}, not ◊em{Labels}).
Three levels at most; never numbered (◊code{◊(loz)section}, ◊code{◊(loz)subsection}, ◊code{◊(loz)subsubsection}).
- ◊code{#:short} for any heading over ~30 characters, so the contents and the reading bar stay on one line.
- ◊em{Ids} are explicit, permanent, lowercase, hyphenated, descriptive, never numbers (◊code{SRC-1}): ◊code{#:id "canalisation"}, not ◊code{"section-3"}.
A published id is a promise (◊code{VAL-3}): do not change one; if the section goes, leave an anchor behind or add a redirect.
- ◊em{A section is at least two paragraphs.}
A one-paragraph section is a paragraph with ideas above its station: fold it in or give it the room.
- ◊em{Three or more sections} earn a contents list; fewer and the build omits it (◊code{TOC-1}).
Do not add sections to get one.
- ◊em{Section breaks} (◊code{◊(loz)break{}}) mark a change of direction within a section, or stand between an unheaded introduction and the first heading.
Never before a heading that already follows one; never directly after the abstract, which closes itself (◊code{LAYOUT-1c}).
- ◊em{Unfinished sections} are comments (◊code{◊(loz);{…}}), not published stubs.
}

◊subsection[#:id "lists-and-tables"]{Lists and tables}

◊list{
- A list only when the items are truly ◊em{parallel}.
Narrative that happens to have steps is prose.
- ◊em{Order} even an unordered list meaningfully (importance, chronology, the order the text discusses them).
- ◊em{Numbered} when items will be referred to by number or their order is the point; otherwise bullets.
Hierarchical numbering is the build's (◊code{LIST-3}).
- ◊em{Columns} (◊code{#:columns 2|3}) for more than six short items (≤ ~60 characters each).
- ◊em{Enumerations inside a sentence} use (1), (2), (3), never i., ii., iii.
- ◊em{Tables} for data with two dimensions; a one-column table is a list.
Every table has ◊code{#:id} and ◊code{#:title}; ◊code{#:source} where the data is not yours (◊code{IMG-3a}).
Lining figures, right-aligned, in numeric columns; the build does this.
Prefer ◊code{◊(loz)table-csv} for anything over a dozen rows, with the CSV beside the essay.
}

◊subsection[#:id "figures"]{Figures}

◊list{
- Every figure has ◊code{#:id}, ◊code{#:title}, ◊code{#:alt} and ◊code{#:licence} (◊code{IMG-3}, ◊code{IMG-6}, ◊code{IMG-7}); the build fails without them.
- ◊em{Title} is one line, semibold, what the figure shows (◊em{The continuant and the occurrent}).
◊em{Caption} is what to notice.
◊em{Credit} is whose it is.
Keep the three distinct.
- ◊em{Alt text} describes the image for someone who cannot see it, in a sentence; it does not repeat the caption.
◊code{#:alt ""} only for a truly decorative image, which the site has almost none of.
- ◊em{Third-party diagrams are redrawn} by the author and credited "after Surname (year)".
No screenshots of other people's figures.
- ◊em{Refer} with ◊code{◊(loz)ref[id]} ("Figure 2"); never type the number.
- ◊em{Never wider than the column} (◊code{IMG-2}).
A figure that needs more is a figure with too much in it.
Narrower is allowed, ◊code{#:width 0.5} and the like, for a tall image that would otherwise run down the page; the image sits at the left edge, and the words keep their place in the margin.
Use it for shape, not for emphasis.
- ◊em{Several images that make one point are one figure}, a ◊code{◊(loz)panels} with lettered panels (◊code{IMG-9}), never a composite image and never three figures in a row.
The letters are the build's; the caption refers to them (◊em{the lesion outlined in B}) and the text with ◊code{◊(loz)ref[id #:panel "b"]}.
Each panel's body is its caption, set in the margin under the title as ◊em{A. ...}, ◊em{B. ...}: a name or what to notice in that panel; what the panels show together goes in the figure's caption after them, if anything does.
Two to six panels; if the figure wants more, it is two figures.
- ◊em{Interactive figures} (◊code{◊(loz)embed}) carry a static fallback that makes the same point.
}

◊subsection[#:id "essays-and-entries"]{Essays and entries}

An ◊em{essay} is something you will revise; an ◊em{entry} is something you said on a date (◊code{KIND-2}).
If you can imagine amending it next year, it is an essay.
If it would be wrong to amend it, because the point is what you thought at the time, it is an entry.
Breadth and informality are symptoms of the second kind, not the rule for it.

An entry that acquires an epistemic status, a changelog or a contents list has become an essay: move it rather than bending the rules.
Entries may link to and quote essays freely; an essay cites an entry only as it would cite any dated source.

◊subsection[#:id "revisions-and-correspondence" #:short "Revisions"]{Revisions and correspondence}

◊list{
- ◊em{Typo fixes} are silent (a ◊code{[typo]} commit, which ◊code{REV-1} ignores).
- ◊em{Anything a returning reader would want to know} gets a ◊code{◊(loz)changelog} line: a changed claim, a new section, a retraction, a reply to a letter.
Dated, one line, in the past tense: ◊em{2026-11-02: Added the section on canalisation after a letter from J.}
- ◊em{Never silently reverse a claim.}
If the essay now says the opposite, the changelog says so and the old text is in git.
- ◊em{Letters} that change your mind are acknowledged in the changelog, with the correspondent's permission, by initials unless they ask for their name.
}

◊section[#:id "markup"]{Markup (Pollen)}

◊subsection[#:id "source-conventions"]{Source conventions}

◊list{
- ◊em{Ventilated prose: one sentence per source line.}
A newline inside a paragraph is a space (◊code{SRC-3}), so this costs nothing in output and makes every GitHub diff show the sentence that changed (principle 2).
Paragraphs are separated by a blank line; ◊code{◊(loz)p} is never written.◊aside{Recommendation, not yet the practice of the first essay; adopt from the next one.}
- ◊em{Metas stay on one line} (◊code{SRC-4}).
The abstract and epistemic status are body tags and may wrap (◊code{SRC-4a}).
- ◊em{Only the tag vocabulary} in ◊code{SPEC.md} §3.3.
An unknown tag fails the build (◊code{SRC-2}); do not invent one in an essay.
A new tag is a SPEC change first.
- ◊em{Comments} are ◊code{◊(loz);} for a line and ◊code{◊(loz);{…}} for a block.
Use them for exceptions (see ◊link["#principles"]{Principles over rules}), parked text and notes to a future editor; never for anything a reader should see.
- ◊em{The lozenge} is typed with the Emacs key (◊code{EMACS-1}), never pasted.
- ◊em{Marks and punctuation.}
A citation circle goes after the sentence's punctuation.
An aside's circle sits where the aside belongs in the thought, usually at the end of the clause, before any citation.
A margin note goes at the start of the sentence or item it glosses, never at the end of a block (◊code{MNOTE-6}).
}

◊subsection[#:id "metadata"]{Metadata}

Metas in this order, one per line, at the top of the file.
Required and optional mean the same for essays and entries:

◊list{
- ◊code{title} (required).
Title case as a work's title; ≤ ~8 words.
The site name is not part of it.
- ◊code{subtitle} (optional).
Sentence case; says what the title doesn't.
- ◊code{status} (required).
◊code{draft} or ◊code{published} (◊code{DRAFT-2}); nothing else.
- ◊code{published} (required).
◊code{YYYY-MM-DD}; the date of first publication, never moved.
- ◊code{tags} (optional).
Lowercase, comma-separated, from the tags already in use (◊code{C-c o T}); a new tag is a decision, not a typo.
- ◊code{author} (optional).
Only when not the site default (◊code{LAYOUT-1e}).
}

Then, in the body: ◊code{◊(loz)epistemic} (essays only), ◊code{◊(loz)abstract} (essays; optional in entries), ◊code{◊(loz)audio} if any, then the text.
◊code{kind}, ◊code{abstract} and ◊code{epistemic} are never metas (◊code{KIND-1}, ◊code{SRC-4a}).
The Edited date, the source and history links, the PDF link and every number are derived; nothing of that is typed.

◊subsection[#:id "slugs-and-urls"]{Slugs and URLs}

◊list{
- ◊em{A slug is the URL} (◊code{/<slug>} for essays, ◊code{/blog/<slug>} for entries, ◊code{D14}) and is chosen once.
Lowercase ASCII, hyphenated, no stop words the title can spare, no dates (dates belong to ◊link["#files"]{files}): ◊code{the-show-where-lilith-comes-back} is at the long end; ◊code{autism-and-moles} is the shape to aim for.
- ◊em{Unique} across essays, entries, pages and reserved paths (◊code{KIND-1}).
- ◊em{Glossary ids} and ◊em{reference keys} are URLs too (◊code{/glossary#<id>} for now; ◊code{/references/<key>}).
Glossary ids follow slug rules; reference keys are Better BibTeX's, case-preserved, pinned (◊code{BIB-2}).
- ◊em{Anchors} (◊code{#id}) are permanent (◊code{VAL-3}).
Rename nothing that has been deployed without a line in ◊code{_redirects}.
}

◊section[#:id "files"]{Files}

◊subsection[#:id "file-naming"]{File-naming}

Most to least important: ◊em{a filename should autocomplete well.}
Filenames should respect autocompletion and predictability.

The general filename pattern is ◊code{YYYY[-MM[-DD]]-SURNAME1[-SURNAME2...][-TOOL[-TOPIC[-DESCRIPTION]]][-N].EXT}.
(Note: file extensions are mandatory.)
Filenames should be all-lowercase Latin alphanumeric (ie. without whitespace or foreign characters).
If feasible, use romanisation like ß → ss; exotic character sets like Chinese/Japanese should usually be left alone unless there is a well-established romanisation or translation.
This makes it easy to tab-complete and grep filenames.

◊em{Descriptions:} can otherwise be freeform, and may embed short English descriptions of the contents, or additional metadata like the original ID/hash.

◊em{Unique filenames:} the base names of files should ideally be unique.
So if there were two files like ◊code{/doc/psychology/2026-wang.pdf} and ◊code{/doc/biology/2026-wang.pdf}, one of them should nevertheless be renamed to ◊code{2026-wang-2.pdf}.
The incrementing N is zero-padded only as necessary, for uniformity.
(So if there were 10 such Wang PDFs, they would all be renamed to zero-pad them like ◊code{2026-wang-01.pdf} ... ◊code{2026-wang-10.pdf}.)

◊em{Unique file extensions:} where multiple file extensions are in common use, standardise on the majority (ie. ◊code{.jpg}, not ◊code{.jpeg}; ◊code{.png}, not ◊code{.PNG}).

◊em{Renaming:} files should not be moved using ◊code{mv}, but moved using a rename script, which will handle file format conversion special-cases, global search-and-replace, and redirects.
Pollen pages currently cannot be moved with such a script, and must be updated manually.

◊em{Here}, the pattern applies to ◊em{files}, not pages:

◊list{
- ◊em{Pages are slugs} (see ◊link["#slugs-and-urls"]{Slugs and URLs}), never dated.
The pattern governs everything else you name by hand: images in ◊code{essays/<slug>/img/} and ◊code{blog/<slug>/img/}, CSVs beside an essay, shared images in ◊code{img/}, anything in ◊code{support/}, and any document offered for download.
- ◊em{Surname.}
Your own photograph, figure or data: ◊code{lucas}.
A figure redrawn after someone else's: their surname, and the credit says "after" (◊code{IMG-6}).
No identifiable author: the closest entity (◊code{nswhealth}, ◊code{abs}), else ◊code{anonymous}.
- ◊em{Tool and topic.}
◊code{2026-10-14-lucas-omnigraffle-taxonomy-mammals.svg}; ◊code{2026-lucas-photo-retina.jpg}; ◊code{2026-abs-census-table-age.csv}.
A generated image names the model and date (see ◊link["#generative-media"]{Generative media}).
- ◊em{Exceptions to lowercase}, and the only ones: Better BibTeX keys, which are case-preserved and pinned (◊code{BIB-2}) and so name ◊code{refs/covers/<key>.jpg} and ◊code{/references/<key>}; and files the build writes with a content hash (◊code{assets/fonts/*.woff2}, ◊code{assets/img/*}), which are never hand-named and never committed where generated.
Everything a person types is lowercase.
- ◊code{support/} is gitignored (◊code{BUILD-3a}) and may hold files under their original names (a journal's PDF, a ◊code{.docx} draft).
Rename on the way in only if you will want to tab-complete them.
- ◊em{The rename script does not exist yet} (◊code{tools/mv.py}, to write when the first rename is needed).
Until it does: ◊code{git mv}, a global search for the old name, and a line in ◊code{_redirects} for anything that was ever deployed.
An essay or entry is never renamed after publication: the slug is the URL.
}

◊subsection[#:id "filetypes"]{Filetypes}

◊em{Few:} as few as possible.

◊em{Long-term:} emphasis on backwards compatibility.

◊em{>95% browser support:} if relevant, it should have >95% global support on ◊link["https://caniuse.com" #:note "Browser-support tables, used here to check the 95% threshold."]{CanIUse.com}.
(This can include polyfilling.)

◊em{Audio:} MP3, and not OGG Vorbis, must be used for Apple compatibility.

◊em{CSV:} our preferred "spreadsheet" or "tabular format".
CSVs must be UTF-8 and comma-separated, and must read cleanly into LibreOffice and R.

◊em{Here}, the full list.
Anything not on it is a SPEC change.
Each item gives the source (what you commit), what the build serves, and the rule:

◊list{
- ◊em{Prose.}
Source ◊code{.pm} (Pollen) for pages and ◊code{.md} for repository documents; served as ◊code{.html}.
See ◊link["#markup"]{Markup (Pollen)}; ◊code{.org} is not used in the repository (see ◊link["#repository-documents"]{Repository documents}).
- ◊em{Raster image.}
Source ◊code{.jpg} (photographs) or ◊code{.png} (screenshots, line art with flat colour); served as ◊code{.avif}, ◊code{.webp} and the source format, in variants (◊code{IMG-1}).
No WebP or AVIF ◊em{sources}: they are outputs.
No HEIC, TIFF, BMP, GIF (a GIF is a video).
- ◊em{Vector image.}
Source ◊code{.svg}, hand-cleaned, ◊code{currentColor} for strokes; inlined (◊code{IMG-5}).
No ◊code{.pdf} figures; export to SVG.
- ◊em{Document.}
Source ◊code{.pdf}; served as is.
PDF/A where the tool offers it.
Never ◊code{.docx}, ◊code{.doc}, ◊code{.djvu}, ◊code{.epub} for anything published.
- ◊em{Data.}
Source ◊code{.csv}, UTF-8, comma-separated, header row, one table per file; rendered by ◊code{◊(loz)table-csv}.
No ◊code{.xlsx}, ◊code{.tsv}, ◊code{.ods}.
Dates ISO, decimals with a full stop, no thousands separators.
- ◊em{Audio.}
Source ◊code{.mp3}, mono, 64-80 kbps, −19 LUFS / −1 dBTP (◊code{AUDIO-2}); served as is, from R2.
Never committed (◊code{AUDIO-1}).
No ◊code{.m4a}, ◊code{.ogg}, ◊code{.wav} served.
- ◊em{Video.}
Source ◊code{.mp4} (H.264 + AAC); served as is.
Only inside an interactive figure's fallback; no autoplay, no loop.
- ◊em{Fonts.}
Source ◊code{.otf} upstream (◊code{TYPE-9a}); served as ◊code{.woff2} subsets.
No other format served.
- ◊em{Archive.}
◊code{.tar.xz}, served as is.
Rarely; prefer the files.
- ◊em{Code.}
◊code{.rkt}, ◊code{.py}, ◊code{.js}, ◊code{.css}, ◊code{.el}, ◊code{Makefile}; nothing served (see ◊link["#code"]{Code}).
}

◊em{Images} (◊code{IMG-1}, ◊code{IMG-4}): a source is never above ~2 MB and never below the largest variant the build will make of it; the build warns.
Commit the source, never the variants.

◊subsection[#:id "renaming"]{Renaming}

◊list{
- A deployed URL, anchor, figure id or reference key is a ◊em{promise} (◊code{VAL-3}).
The build fails when a linked anchor disappears; everything else is on you.
- ◊em{Nothing deployed is renamed without a redirect} (◊code{_redirects}, one line, commented with the rule it serves, as the existing one is).
- ◊em{Essays and entries are never renamed} after ◊code{status} becomes ◊code{published}.
Change the title freely; the slug stays.
- ◊em{Files} are renamed with the script (see ◊link["#file-naming"]{File-naming}) once it exists; until then by hand, with a global search of the repository for the old name before the commit.
- ◊em{Glossary ids} are renamed only with the old id kept as an alias.
}

◊subsection[#:id "generative-media"]{Generative media}

◊;{CONFLICT: the third item below is carried over from STYLE.md. It says
prose written with a model's help carries no label, which disagrees with
the AI policy at the top of this page. Ryan to decide.}

◊list{
- An image or sound made with a generative model is ◊em{labelled} in its credit (◊em{Generated with <model>, <date>; edited}) and ◊em{named} with the tool as the surname field (◊code{2026-10-14-gpt-image-taxonomy-sketch.png}), so the fact survives the caption.
- It is used only after ◊em{human editing} and only where a drawn or photographed figure would not serve.
Never for a face, a child, or anything that could be taken for a photograph of a real place or person.
- ◊em{Prose} written with a model's help is the author's responsibility and carries no label; the author has read every sentence and would say it.
Text the author has not read is not published.
}

◊section[#:id "code"]{Code}

◊list{
- ◊em{Nothing in the repository is decorative.}
Every byte of JS and every font file earns its place (principle 3).
A library is adopted only when writing the thing would be longer than reading the library.
- ◊em{Racket} (◊code{pollen.rkt}, ◊code{typography.rkt}, ◊code{lib/}): a function per rule; every typography rule has a test with a case where it must not fire (◊code{TYPE-14}); ◊code{make test} is green before any commit that touches them.
- ◊em{JavaScript}: plain ES modules, no build step, no framework, no third-party requests.
Everything works with scripts off (principle 5), so a script only ever ◊em{adds}.
- ◊em{CSS}: custom properties for every colour, size and gap; no colour literal outside the ◊code{:root} blocks; both themes tested on ◊code{/specimen} for every change (◊code{THEME-7}).
- ◊em{Python} (◊code{tools/}): a script per job, ◊code{argparse}, a ◊code{--dry-run} where it writes, idempotent (running twice changes nothing), offline by default (◊code{BUILD-2}).
- ◊em{Emacs Lisp} (◊code{emacs/occurrent.el}): byte-compiles with zero warnings; ◊code{make test-emacs} green.
- ◊em{Shell}: only inside the ◊code{Makefile}; ◊code{set -e} semantics; long flags; nothing a ◊code{make clean} cannot undo.
- ◊em{Commits}: imperative subject ≤ 72 characters, the SPEC or STYLE id in brackets when one applies (◊code{[TYPE-16]}, ◊code{[typo]}, ◊code{[meta]}); a body that says ◊em{why}.
One change per commit.
The ◊code{[typo]} and ◊code{[meta]} prefixes are what keep ◊code{REV-1} honest, so use them only for what they say.
- ◊em{Secrets} never enter the repository, including in ◊code{data/}, ◊code{local.mk}, ◊code{.local.*} files or history.
◊code{support/} is for sources, not credentials.
}

◊section[#:id "repository-documents"]{Repository documents}

◊;{ON ADOPTION: this section assumes the manual is a Markdown file. If this
page replaces STYLE.md, take "this manual" out of the first item and STYLE out
of the second.}

◊list{
- ◊em{Markdown (◊code{.md}) is the format for every document in the repository that is not a page}: ◊code{README.md}, ◊code{SPEC.md}, ◊code{BACKLOG.md}, the handovers, this manual, reports.
GitHub renders it, the claude.ai Project mirrors it, and Claude Code reads it natively.
◊code{.org} is for Ryan's own notes outside the repository; nothing in ◊code{site/} is ◊code{.org}.
- ◊em{One file per subject}, named in capitals at the root (◊code{SPEC}, ◊code{BACKLOG}, ◊code{STYLE}, ◊code{COMPAT}, ◊code{HANDOVERS}, which holds every phase's handover as a section), with a status line under the title: ◊code{Status: … · Owner: … · Last revised: YYYY-MM-DD}.
- ◊em{Rules carry ids} where they are enforced (◊code{SPEC}) and plain headings where they are judgement (here).
Cross-reference by id, never by page or section number, which move.
- ◊em{Revision notes} inline in italics, as ◊code{SPEC.md} does: ◊em{Revised 2026-10-26: ...}.
A document is a living document like an essay; its history is git's.
- ◊em{Markdown style}: ATX headings; one blank line between blocks; a table only when every cell fits in about 40 characters, so a row stays on one line in an editor, and a row whose cell is a sentence is instead a list item with a bold lead-in (the metas in ◊link["#metadata"]{Metadata} are the shape); em dashes without surrounding spaces; code spans for every identifier, path, tag and key; no HTML except where Markdown cannot do it.
}

◊section[#:id "esthetics-and-interface"]{Esthetics and interface}

What the site looks like is specified in ◊code{SPEC.md} §4, §7–§11 and decided on ◊code{/specimen}.
This section is the taste behind those rules, for the next decision.

◊list{
- ◊em{Stance.}
The page is a printed page that happens to be alive.
Every interactive thing is a quieter version of something print already does: a margin note, a footnote, a cross-reference.
If a feature has no print ancestor, it needs a very good reason.
- ◊em{Two marks only}: the arrow (takes you away) and the circle (you stay here).
No third mark, ever (◊code{MARK-1}).
A reader learns the system in one essay.
- ◊em{Typography carries the hierarchy.}
Size, case, weight and space, in that order of preference; colour last; rules sparingly; boxes never.
Nothing is centred except the section-break glyph.
- ◊em{Colour} is for links and the current section, one accent, and the rest of the page is the text colour and its muted step.
If a colour appears in two unrelated places, one of them is wrong.
- ◊em{Dark mode is a first-class theme}, not an inversion: every figure classified (◊code{IMG-4}), every colour a property, every screenshot in the checks taken twice.
- ◊em{Motion} is for state change only (a popup opening, the bar appearing), ≤ 200 ms, and absent under ◊code{prefers-reduced-motion}.
- ◊em{Interface text} is sentence case, short, and in the site's words (see ◊link["#terminology-and-glossary"]{Terminology and the glossary}): ◊em{Expand}, ◊em{Open in new tab}, ◊em{Contents}, ◊em{Notes}, ◊em{Bibliography}, ◊em{Backlinks}, ◊em{Changelog}.
No exclamation marks, no "Click here", no jokes in the chrome.
- ◊em{Accessibility is not a mode.}
Every control has an accessible name, focus is visible and managed, nothing is hover-only on touch, contrast meets AA in both themes, and the no-JS page is the baseline, not a fallback.
- ◊em{Print is a reader}, not an afterthought (◊code{PRINT-1}–◊code{8}): the PDF of a post is the post, with the apparatus as footnotes, and says when it was printed.
- ◊em{Engineering}: static, offline-buildable, no third-party requests, every rule tested, every rendered page validated (◊code{VAL-1}).
A thing that cannot be tested is a thing that will silently break.
- ◊em{Graveyard} (things tried and removed, so they are not tried again): definition stubs in the margin (◊code{D7}, resolved three times: popups only); bordered boxes for expanded asides (replaced by the right rule); a centred header (left-aligned since 2026-10-15); numerals and ≡ as marks (the circle); the right margin going first as the window narrows (reversed 2026-10-19); run-in margin notes on phones (hidden since 2026-10-22).
◊code{BACKLOG.md} lists what is deliberately ◊em{not yet} built, which is different.
}

◊section[#:id "writing-with-an-assistant"]{Writing with an assistant}

For Claude Code sessions and any other model asked to draft, edit or review prose or files here.

◊;{CONFLICT: every item below except the checklist and the files-and-names
item is about a model drafting or editing prose, which the AI policy at the
AI policy (/policies#ai-policy) rules out. Carried over from STYLE.md unchanged. Ryan to
decide whether this section becomes review-only.}

◊list{
- ◊em{The author's voice is the standard}, not a house blend.
Read two published essays before drafting a sentence.
Prefer the author's existing phrasing, images and examples to new ones.
- ◊em{Distinctiveness.}
Avoid the register the models drift to: triplets, "it's not X, it's Y", rhetorical questions as transitions, "delve", "nuanced", "tapestry", "crucial", a summary paragraph that restates the section.
If a sentence could open any essay, it opens none of these.
- ◊em{Draft workflow.}
(1) Outline as margin notes first: if the outline does not read as an argument, stop.
(2) Draft one section.
(3) Mark every claim that needs a citation with ◊code{◊(loz);{CITE?}} rather than inventing a key.
(4) Hand over with the comments in place; the author removes them.
- ◊em{Never invent} a citation key, a quotation, a page number, a date, a correspondent or a clinical detail.
A placeholder in a comment is correct; a plausible fabrication is a defect that may be published.
- ◊em{Edits are minimal and visible.}
Change the sentence that is wrong, not the paragraph around it.
Ventilated prose (see ◊link["#source-conventions"]{Source conventions}) exists so that the diff shows exactly what you did.
- ◊em{Files and names} follow Files exactly; when unsure of a surname or date, ask rather than guess.
- ◊em{Pre-handoff checklist.}
◊code{make test} green; no straight quote in output; every new figure has id, title, alt, licence; every new section has an id and ◊code{#:short} if long; no new tag; no ◊code{.org}, ◊code{.docx}, ◊code{.jpeg} or uppercase filename introduced; metas on one line; nothing in ◊code{support/} referenced by the build; the changelog line written if a claim changed; the SPEC id named in the commit.
}

◊changelog{
2026-11-08: Rewritten as a page of the site. The AI policy lives on the policies page. Section numbers are gone, as this manual requires of the site, and each cross-reference is now a link.
2026-11-03: Version 1.2. The tables in Metadata and Filetypes, whose cells were sentences, became lists; the rule for that is in Repository documents, because no editor wraps text inside a pipe-table cell. Open: the serial comma (◊code{D5}), ventilated prose as practice, the rename script.
2026-11-02: Version 1.1 (afternoon). Panel figures in Figures, with SPEC ◊code{IMG-9}.
2026-11-02: Version 1.0. First draft, from ◊code{SPEC.md} §17 and Gwern's style guide; the file-naming and filetype rules of Files are taken from that guide with local adaptations marked ◊em{Here}.
}
