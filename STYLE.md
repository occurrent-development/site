# occurrentdevelopment.com — Manual of Style

Status: draft 1.2 · Owner: Ryan · Last revised: 2026-11-03 · Modelled on [gwern.net/style-guide](https://gwern.net/style-guide)

This is the house style for everything on the site and in its repository: prose, markup, metadata, files, and the look of the thing. `SPEC.md` is the build brief and says what the build *enforces*; this manual says what a writer *chooses*. Where a rule here is also a requirement there, the ID follows it in parentheses (`TYPE-16`).

---

## 1. Usage

- **Who it is for.** Ryan when writing; anyone else whose essay is hosted here; and any Claude Code session that edits prose, names files, or touches the repository. Handover documents point here rather than restating style.
- **Precedence.** `SPEC.md` (build-enforced, MUST/SHOULD, numbered) → this manual → taste. A disagreement between the two is a defect: fix one, the same day, and say which.
- **Seed.** `SPEC.md` §17 was the first draft of this manual. New conventions go here; §17 is to be reduced to a pointer at the next SPEC revision.
- **Errors.** If a rule here is wrong, contradicts another, or cannot be followed in a case, report it with a suggested fix rather than silently working around it.

## 2. Principles over rules

The site's principles (`SPEC.md` §1), in priority order: the reader never loses their place; the source is the essay; fast; typography is not decoration; progressive enhancement; essays are living documents; no engagement machinery; we publish nothing that isn't ours.

When a rule in this manual conflicts with a principle, follow the principle. Make the smallest change that works, and record the exception where it happens, in a Pollen comment on the line before: `◊;{STYLE: why this breaks rule §5.3}`. An exception nobody can find is a precedent nobody can check.

## 3. Condensed manual

The whole thing on one screen. Each line is expanded below.

- Australian spelling (`-ise`, `-our`, `programme`, `paediatrics`); metric units; `YYYY-MM-DD` in metas and filenames, "1 November 2026" in prose.
- Plain, analytical, first person. Confidence lives in the epistemic line, so the body can speak without hedging.
- Headings in sentence case, naming what the section argues; three levels at most; never numbered.
- Emphasis is italic. Nothing is ever underlined. Bold is not typed in prose.
- Type straight quotes and `---`; the build curls and spaces them. A straight quote in output fails the build.
- Double quotation marks, single inside. Logical quotation: punctuation inside the marks only when it is part of what is quoted.
- Numbered Chicago notes, mark after the punctuation; page locators for quotations and specific claims; every quotation from a cited work is a `◊cite` with the quoted words as its body.
- Link the noun phrase, never "here"; first mention only; DOI over publisher URL; `#:note` on any external link a reader might wonder about.
- Iceberg: title → abstract → margin note → paragraph → aside → note → glossary or reference page. Put each thing at the shallowest level where a reader who skips it loses nothing they need.
- Asides ≤ ~100 words; margin notes ≤ 8 words and read in sequence as an outline; a note cites, an aside comments.
- Define a term when a smart reader outside the field would *misread* it, not merely when they might not know it.
- Every essay has an abstract and an epistemic status. An entry has neither and is never amended.
- Every figure has an id, a title, alt text and a licence; third-party diagrams are redrawn and credited "after X (year)".
- Files: `YYYY[-MM[-DD]]-surname[-tool[-topic[-description]]][-N].ext`, all lowercase, unique basenames, one extension per format. Pages are slugs, not dated files.
- As few filetypes as possible, chosen for the long term: JPG/PNG/SVG sources, PDF documents, MP3 audio, UTF-8 comma-separated CSV.
- A published URL or anchor is a promise. Nothing published is renamed without a redirect.
- Typo fixes are silent; anything a returning reader would want to know gets a changelog line. A claim is never silently reversed.
- Clinical material is composite or altered beyond recognition, and the essay says so once.

---

## 4. Writing

### 4.1 Register

- **Plain and analytical.** Short declaratives where the thought allows. Formality rises with the novelty of the claim: a familiar point can be said lightly; a new one is stated carefully and once.
- **First person.** "I" for what the author did, thinks or saw. "We" only for a group the author belongs to and the reader can name (clinicians, the field, developmental paediatrics), never the editorial *we*. "You" for the reader is allowed and often better than the passive.
- **Unhedged body, hedged header.** The epistemic line (`◊epistemic`) states how confident the essay is and on what basis. That is where "speculative", "argued from theory" and "I have changed my mind about this before" belong. The body then says things, rather than suggesting that it may perhaps be the case that.
- **Probability.** Give the number when there is one. Otherwise one plain word (unlikely, probably, almost certainly) and what it rests on. Avoid "may" doing the work of "I don't know".
- **Statistics.** *False positive* and *false negative*, not Type I and II. *Statistical-significance testing*, not "significance" bare. Report an effect with its size and interval, not a *p*-value alone. Say *association* unless the design licenses *effect*.
- **Clinical material.** No identifiable patient, ever: vignettes are composites or altered beyond recognition, and the essay says so once, usually in the epistemic line or the first aside that uses one. Nothing that would let a family recognise themselves.
- **Names.** People by surname after the first full mention. No honorifics or post-nominals in prose; qualifications belong on the About page.
- **Profanity.** Not in the author's voice. Quoted where the quotation needs it, unaltered.

### 4.2 Spelling, punctuation, numbers

- **Spelling** is Australian (`TYPE-5`): `-ise`, `-our`, `-re`, `paediatric`, `behavioural`, `programme`, `practise` (verb) / `practice` (noun), `judgement`. Macquarie where in doubt.
- **Serial comma.** Use it only where its absence would misread (the Australian Government Style Manual position). *Open decision `D5`: this is the recommendation; record the choice in SPEC when settled.*
- **Quotation marks.** Type straight `"` and `'`; the build curls them from context (`TYPE-16`). Double outside, single inside. Logical quotation: a full stop or comma goes inside the closing mark only when it is part of the quoted text.
- **Dashes.** Type `word---word` for an em dash; the build sets it with hair spaces (`TYPE-15`), so never type spaces around it. En dash for ranges: type `1998-2004` between digits and the build converts it; type `–` by hand between words (*the Sydney–Newcastle line*). Hyphens for compounds only.
- **Ellipsis.** Type `...`; the build sets `…`.
- **Numbers.** Spell out one to nine; figures from 10, and always with a unit, a percentage or a decimal. Digit-group comma from 10,000 (`1000`, `12,000`). Old-style figures in prose and lining in tables are the build's doing (`TYPE-7`); nothing to type. Type `10 kg` with a space; the build makes it non-breaking (`TYPE-15`).
- **Dates.** `YYYY-MM-DD` in metas, filenames, tables and anything a machine reads. In prose, day month year without ordinals: *1 November 2026*; *November 2026*; *the 1990s* (not *1990's*). Ranges with an en dash: *2019–2024*.
- **Units.** Metric, SI symbols, space between number and symbol (`5 mg`, `37.5 °C`). No full stops after symbols.
- **Abbreviations.** No full stops in acronyms (`WHO`, `NDIS`, `ADHD`). Expand at first use unless the acronym is the common name. Set an acronym in small caps with `◊sc{WHO}` (`TYPE-11`; manual, not automatic). *e.g.*, *i.e.*, *cf.* are fine inside parentheses and asides; in running prose prefer *for example*, *that is*, *compare*.
- **Foreign phrases** italic unless naturalised (*ad hoc*, *per se* and *vice versa* are naturalised; *pluralis auctoris* is not).
- **Titles of works.** Italic for books, journals, films and series (*Frasier*); quotation marks for articles, chapters and episodes ("The Show Where Lilith Comes Back"). Title case as the work itself prints it.

### 4.3 Emphasis

- **Italic** (`◊em`) is the only emphasis in prose. Inside an italic block (an epigraph, an italic quotation) `◊em` flips to roman (`LAYOUT-4c`).
- **Bold** (`◊strong`) is not typed in running prose. The build uses semibold for figure and table labels; a reader should be able to assume that bold is apparatus. The one allowed use is a word the reader must not miss in a list of instructions (*never* commit `support/`).
- **Small caps** (`◊sc`) for acronyms and nothing else.
- **No underlines**, anywhere, for any purpose. Links are marked by their arrows and circles, not by decoration (`MARK-1`).

### 4.4 Links

- Link the **noun phrase that names the thing** (*the SEP entry on process philosophy*), never *here*, *this*, or a bare URL.
- **First mention only** within a post. Later mentions are plain text; the reader knows where the link is.
- **Primary sources.** Prefer the paper to the press release, the DOI to the publisher URL, the author's page to a mirror. Prefer a Wikipedia link only for a thing whose Wikipedia article is the best short introduction.
- **`#:note`** on any external link a reader might wonder about before clicking: what it is, why it is there, and when it was read if that matters. One sentence. (It feeds the link card, `CARD-1`.)
- **Internal links** are same-page (`#id`) or cross-essay (`/slug#id`); the build types them and fails on a broken target (`LINK-1`, `LINK-2`). Link to the most specific anchor that exists.
- **Never** copy or archive someone else's page or image (principle 8). Quote, cite and link.

### 4.5 Citations and quotations

- **Numbered notes**, Chicago notes-bibliography, numbered in source order including inside asides (`CITE-1`). The number appears in Notes and in print, never as a superscript on screen; the circle is the mark.
- **Mark after punctuation** (`MARK-3a`): *…a claim about being.◊cite["key"]*
- **Locators** (`#:loc "p. 42"`, `"pp. 31–34"`, `"ch. 3"`) for every quotation and every specific claim; a work cited for its general argument needs none. Type `p. 42` with the space; the build keeps it together (`TYPE-15`).
- **Quotations from cited works are marked** (`BIB-9`): `◊cite["key" #:loc "…"]{the words}` inline, with `#:block #t` for a block quotation, whose attribution the build writes from the entry. `◊blockquote` and `◊epigraph` are for sources not in Zotero. Quotation marks with a bare `◊cite` after them are for phrases too short to be worth listing on the work's page.
- **Keys** are Better BibTeX keys, pinned in Zotero, case-preserved (`BIB-2`). Never retype a key; `od-insert-cite` picks it.
- **Epigraphs** are italic, block quotations roman (`LAYOUT-4a`, `4b`). Flip with `#:italic` only for a reason (a long epigraph of running prose; a quotation whose own typography depends on italic). If the flip is frequent, change the default, not each quotation.
- **No ibid.**, no *op. cit.*; the build handles full and short forms (`CITE-3`).
- **Commentary on a work** (`references/<key>.pm`, `BIB-3`) is rare and deliberate: write one when you have something to say about the work that no essay says.

### 4.6 Terminology and the glossary

- **Define a term when a smart reader outside the field would misread it**, not merely when they might not know it. *Continuant* needs a definition; *neurodevelopmental* does not.
- **One sense, one term.** A word used in a different sense is a separate glossary entry (`canalisation`, `canalisation-waddington`; `TERM-1`).
- **Mark the first use** in a post with `◊term`; later uses are plain unless a reader arriving by anchor would need the definition again.
- **The definition** (`glossary/<id>.pm`) opens with one sentence that stands alone in a popup; every paragraph after the first is the More, shown when the reader asks for it (no tag marks it, `TERM-2`). Cite inside it freely (unnumbered, `CITE-7`).
- **House terms.** *Essay* and *entry* (never *post* in prose, though `SPEC.md` uses it as the type name); *Blog* for the second kind; *aside*, *margin note*, *note* (a citation), *definition*, *reference page*; *Edited* for the date git supplies, *revised* for a changelog line (`REV-1`); *contents* not *table of contents*; *reading bar* not *toolbar*.

---

## 5. Structure

### 5.1 The iceberg

Every post has depth, and the reader controls how far down they go. Place each thing at the shallowest level where a reader who skips it loses nothing they need:

1. **Title and subtitle**: what it is.
2. **Abstract**: what it argues, in ≤ ~120 words, not what it is about. If the abstract could be true of a different essay, it is a description, not an abstract.
3. **Epistemic status**: how confident and on what basis; where the author has changed their mind.
4. **Margin notes**: ≤ 8 words each, sparing, anchored to a sentence or item (`MNOTE-6`); read in sequence they are a rough outline of the argument.
5. **Paragraphs**: the argument. If the argument needs it, it belongs here and nowhere deeper.
6. **Asides**: ≤ ~100 words; something a reader could skip. Longer asides fall out of the margin and probably want to be sections. Use the phrase form (`◊aside["phrase"]{…}`) when the aside qualifies a specific phrase and a reader would want to know which; the bare circle when it comments on the sentence or the thought. Keep the phrase to a few words: the longer it is, the more it reads as a link that goes somewhere.
7. **Notes**: a note cites. Commentary in a note is a sign it should have been an aside.
8. **Glossary and reference pages**: site-wide, shared, written once.

### 5.2 Sections and headings

- **Sentence case**, naming what the section argues (*Why the labels feel heavy*, not *Labels*). Three levels at most; never numbered (`◊section`, `◊subsection`, `◊subsubsection`).
- **`#:short`** for any heading over ~30 characters, so the contents and the reading bar stay on one line.
- **Ids** are explicit, permanent, lowercase, hyphenated, descriptive, never numbers (`SRC-1`): `#:id "canalisation"`, not `"section-3"`. A published id is a promise (`VAL-3`): do not change one; if the section goes, leave an anchor behind or add a redirect.
- **A section is at least two paragraphs.** A one-paragraph section is a paragraph with ideas above its station: fold it in or give it the room.
- **Three or more sections** earn a contents list; fewer and the build omits it (`TOC-1`). Do not add sections to get one.
- **Section breaks** (`◊break{}`) mark a change of direction within a section, or stand between an unheaded introduction and the first heading. Never before a heading that already follows one; never directly after the abstract, which closes itself (`LAYOUT-1c`).
- **Unfinished sections** are comments (`◊;{…}`), not published stubs.

### 5.3 Lists and tables

- A list only when the items are truly **parallel**. Narrative that happens to have steps is prose.
- **Order** even an unordered list meaningfully (importance, chronology, the order the text discusses them).
- **Numbered** when items will be referred to by number or their order is the point; otherwise bullets. Hierarchical numbering is the build's (`LIST-3`).
- **Columns** (`#:columns 2|3`) for more than six short items (≤ ~60 characters each).
- **Enumerations inside a sentence** use (1), (2), (3), never i., ii., iii.
- **Tables** for data with two dimensions; a one-column table is a list. Every table has `#:id` and `#:title`; `#:source` where the data is not yours (`IMG-3a`). Lining figures, right-aligned, in numeric columns; the build does this. Prefer `◊table-csv` for anything over a dozen rows, with the CSV beside the essay.

### 5.4 Figures

- Every figure has `#:id`, `#:title`, `#:alt` and `#:licence` (`IMG-3`, `IMG-6`, `IMG-7`); the build fails without them.
- **Title** is one line, semibold, what the figure shows (*The continuant and the occurrent*). **Caption** is what to notice. **Credit** is whose it is. Keep the three distinct.
- **Alt text** describes the image for someone who cannot see it, in a sentence; it does not repeat the caption. `#:alt ""` only for a truly decorative image, which the site has almost none of.
- **Third-party diagrams are redrawn** by the author and credited "after Surname (year)". No screenshots of other people's figures.
- **Refer** with `◊ref[id]` ("Figure 2"); never type the number.
- **Never wider than the column** (`IMG-2`). A figure that needs more is a figure with too much in it. Narrower is allowed, `#:width 0.5` and the like, for a tall image that would otherwise run down the page; the image sits at the left edge, and the words keep their place in the margin. Use it for shape, not for emphasis.
- **Several images that make one point are one figure**, a `◊panels` with lettered panels (`IMG-9`), never a composite image and never three figures in a row. The letters are the build's; the caption refers to them (*the lesion outlined in B*) and the text with `◊ref[id #:panel "b"]`. Each panel's body is its caption, set in the margin under the title as *A. …*, *B. …*: a name or what to notice in that panel; what the panels show together goes in the figure's caption after them, if anything does. Two to six panels; if the figure wants more, it is two figures.
- **Interactive figures** (`◊embed`) carry a static fallback that makes the same point.

### 5.5 Essays and entries

An **essay** is something you will revise; an **entry** is something you said on a date (`KIND-2`). If you can imagine amending it next year, it is an essay. If it would be wrong to amend it, because the point is what you thought at the time, it is an entry. Breadth and informality are symptoms of the second kind, not the rule for it. An entry that acquires an epistemic status, a changelog or a contents list has become an essay: move it rather than bending the rules. Entries may link to and quote essays freely; an essay cites an entry only as it would cite any dated source.

### 5.6 Revisions and correspondence

- **Typo fixes** are silent (a `[typo]` commit, which `REV-1` ignores).
- **Anything a returning reader would want to know** gets a `◊changelog` line: a changed claim, a new section, a retraction, a reply to a letter. Dated, one line, in the past tense: *2026-11-02: Added the section on canalisation after a letter from J.*
- **Never silently reverse a claim.** If the essay now says the opposite, the changelog says so and the old text is in git.
- **Letters** that change your mind are acknowledged in the changelog, with the correspondent's permission, by initials unless they ask for their name.

---

## 6. Markup (Pollen)

### 6.1 Source conventions

- **Ventilated prose: one sentence per source line.** A newline inside a paragraph is a space (`SRC-3`), so this costs nothing in output and makes every GitHub diff show the sentence that changed (principle 2). Paragraphs are separated by a blank line; `◊p` is never written. *Recommendation, not yet the practice of the first essay; adopt from the next one.*
- **Metas stay on one line** (`SRC-4`). The abstract and epistemic status are body tags and may wrap (`SRC-4a`).
- **Only the tag vocabulary** in `SPEC.md` §3.3. An unknown tag fails the build (`SRC-2`); do not invent one in an essay. A new tag is a SPEC change first.
- **Comments** are `◊;` for a line and `◊;{…}` for a block. Use them for exceptions (§2), parked text and notes to a future editor; never for anything a reader should see.
- **The lozenge** is typed with the Emacs key (`EMACS-1`), never pasted.
- **Marks and punctuation.** A citation circle goes after the sentence's punctuation. An aside's circle sits where the aside belongs in the thought, usually at the end of the clause, before any citation. A margin note goes at the start of the sentence or item it glosses, never at the end of a block (`MNOTE-6`).

### 6.2 Metadata

Metas in this order, one per line, at the top of the file. Required and optional mean the same for essays and entries:

- **`title`** (required). Title case as a work's title; ≤ ~8 words. The site name is not part of it.
- **`subtitle`** (optional). Sentence case; says what the title doesn't.
- **`status`** (required). `draft` or `published` (`DRAFT-2`); nothing else.
- **`published`** (required). `YYYY-MM-DD`; the date of first publication, never moved.
- **`tags`** (optional). Lowercase, comma-separated, from the tags already in use (`C-c o T`); a new tag is a decision, not a typo.
- **`author`** (optional). Only when not the site default (`LAYOUT-1e`).

Then, in the body: `◊epistemic` (essays only), `◊abstract` (essays; optional in entries), `◊audio` if any, then the text. `kind`, `abstract` and `epistemic` are never metas (`KIND-1`, `SRC-4a`). The Edited date, the source and history links, the PDF link and every number are derived; nothing of that is typed.

### 6.3 Slugs and URLs

- **A slug is the URL** (`/<slug>` for essays, `/blog/<slug>` for entries, `D14`) and is chosen once. Lowercase ASCII, hyphenated, no stop words the title can spare, no dates (dates belong to files, §7): `the-show-where-lilith-comes-back` is at the long end; `autism-and-moles` is the shape to aim for.
- **Unique** across essays, entries, pages and reserved paths (`KIND-1`).
- **Glossary ids** and **reference keys** are URLs too (`/glossary#<id>` for now; `/references/<key>`). Glossary ids follow slug rules; reference keys are Better BibTeX's, case-preserved, pinned (`BIB-2`).
- **Anchors** (`#id`) are permanent (`VAL-3`). Rename nothing that has been deployed without a line in `_redirects`.

---

## 7. Files

### 7.1 File-naming

Most to least important: **a filename should autocomplete well.** Filenames should respect autocompletion and predictability.

The general filename pattern is `YYYY[-MM[-DD]]-SURNAME1[-SURNAME2...][-TOOL[-TOPIC[-DESCRIPTION]]][-N].EXT`. (Note: file extensions are mandatory.) Filenames should be all-lowercase Latin alphanumeric (ie. without whitespace or foreign characters). If feasible, use romanisation like ß → ss; exotic character sets like Chinese/Japanese should usually be left alone unless there is a well-established romanisation or translation. This makes it easy to tab-complete and grep filenames.

**Descriptions:** can otherwise be freeform, and may embed short English descriptions of the contents, or additional metadata like the original ID/hash.

**Unique filenames:** the base names of files should ideally be unique. So if there were two files like `/doc/psychology/2026-wang.pdf` and `/doc/biology/2026-wang.pdf`, one of them should nevertheless be renamed to `2026-wang-2.pdf`. The incrementing N is zero-padded only as necessary, for uniformity. (So if there were 10 such Wang PDFs, they would all be renamed to zero-pad them like `2026-wang-01.pdf` … `2026-wang-10.pdf`.)

**Unique file extensions:** where multiple file extensions are in common use, standardise on the majority (ie. `.jpg`, not `.jpeg`; `.png`, not `.PNG`).

**Renaming:** files should not be moved using `mv`, but moved using a rename script, which will handle file format conversion special-cases, global search-and-replace, and redirects. Pollen pages currently cannot be moved with such a script, and must be updated manually.

**Here**, the pattern applies to *files*, not pages:

- **Pages are slugs** (§6.3), never dated. The pattern governs everything else you name by hand: images in `essays/<slug>/img/` and `blog/<slug>/img/`, CSVs beside an essay, shared images in `img/`, anything in `support/`, and any document offered for download.
- **Surname.** Your own photograph, figure or data: `lucas`. A figure redrawn after someone else's: their surname, and the credit says "after" (`IMG-6`). No identifiable author: the closest entity (`nswhealth`, `abs`), else `anonymous`.
- **Tool and topic.** `2026-10-14-lucas-omnigraffle-taxonomy-mammals.svg`; `2026-lucas-photo-retina.jpg`; `2026-abs-census-table-age.csv`. A generated image names the model and date (§7.4).
- **Exceptions to lowercase**, and the only ones: Better BibTeX keys, which are case-preserved and pinned (`BIB-2`) and so name `refs/covers/<key>.jpg` and `/references/<key>`; and files the build writes with a content hash (`assets/fonts/*.woff2`, `assets/img/*`), which are never hand-named and never committed where generated. Everything a person types is lowercase.
- **`support/`** is gitignored (`BUILD-3a`) and may hold files under their original names (a journal's PDF, a `.docx` draft). Rename on the way in only if you will want to tab-complete them.
- **The rename script does not exist yet** (`tools/mv.py`, to write when the first rename is needed). Until it does: `git mv`, a global search for the old name, and a line in `_redirects` for anything that was ever deployed. An essay or entry is never renamed after publication: the slug is the URL.

### 7.2 Filetypes

**Few:** as few as possible.

**Long-term:** emphasis on backwards compatibility.

**>95% browser support:** if relevant, it should have >95% global support on [CanIUse.com](https://caniuse.com). (This can include polyfilling.)

**Audio:** MP3, and not OGG Vorbis, must be used for Apple compatibility.

**CSV:** our preferred "spreadsheet" or "tabular format". CSVs must be UTF-8 and comma-separated, and must read cleanly into LibreOffice and R.

**Here**, the full list. Anything not on it is a SPEC change. Each item gives the source (what you commit), what the build serves, and the rule:

- **Prose.** Source `.pm` (Pollen) for pages and `.md` for repository documents; served as `.html`. §6; `.org` is not used in the repository (§9).
- **Raster image.** Source `.jpg` (photographs) or `.png` (screenshots, line art with flat colour); served as `.avif`, `.webp` and the source format, in variants (`IMG-1`). No WebP or AVIF *sources*: they are outputs. No HEIC, TIFF, BMP, GIF (a GIF is a video).
- **Vector image.** Source `.svg`, hand-cleaned, `currentColor` for strokes; inlined (`IMG-5`). No `.pdf` figures; export to SVG.
- **Document.** Source `.pdf`; served as is. PDF/A where the tool offers it. Never `.docx`, `.doc`, `.djvu`, `.epub` for anything published.
- **Data.** Source `.csv`, UTF-8, comma-separated, header row, one table per file; rendered by `◊table-csv`. No `.xlsx`, `.tsv`, `.ods`. Dates ISO, decimals with a full stop, no thousands separators.
- **Audio.** Source `.mp3`, mono, 64–80 kbps, −19 LUFS / −1 dBTP (`AUDIO-2`); served as is, from R2. Never committed (`AUDIO-1`). No `.m4a`, `.ogg`, `.wav` served.
- **Video.** Source `.mp4` (H.264 + AAC); served as is. Only inside an interactive figure's fallback; no autoplay, no loop.
- **Fonts.** Source `.otf` upstream (`TYPE-9a`); served as `.woff2` subsets. No other format served.
- **Archive.** `.tar.xz`, served as is. Rarely; prefer the files.
- **Code.** `.rkt`, `.py`, `.js`, `.css`, `.el`, `Makefile`; nothing served. §8.

**Images (`IMG-1`, `IMG-4`)**: a source is never above ~2 MB and never below the largest variant the build will make of it; the build warns. Commit the source, never the variants.

### 7.3 Renaming

- A deployed URL, anchor, figure id or reference key is a **promise** (`VAL-3`). The build fails when a linked anchor disappears; everything else is on you.
- **Nothing deployed is renamed without a redirect** (`_redirects`, one line, commented with the rule it serves, as the existing one is).
- **Essays and entries are never renamed** after `status` becomes `published`. Change the title freely; the slug stays.
- **Files** are renamed with the script (§7.1) once it exists; until then by hand, with a global search of the repository for the old name before the commit.
- **Glossary ids** are renamed only with the old id kept as an alias.

### 7.4 Generative media

- An image or sound made with a generative model is **labelled** in its credit (*Generated with <model>, <date>; edited*) and **named** with the tool as the surname field (`2026-10-14-gpt-image-taxonomy-sketch.png`), so the fact survives the caption.
- It is used only after **human editing** and only where a drawn or photographed figure would not serve. Never for a face, a child, or anything that could be taken for a photograph of a real place or person.
- **Prose** written with a model's help is the author's responsibility and carries no label; the author has read every sentence and would say it. Text the author has not read is not published.

---

## 8. Code

- **Nothing in the repository is decorative.** Every byte of JS and every font file earns its place (principle 3). A library is adopted only when writing the thing would be longer than reading the library.
- **Racket** (`pollen.rkt`, `typography.rkt`, `lib/`): a function per rule; every typography rule has a test with a case where it must not fire (`TYPE-14`); `make test` is green before any commit that touches them.
- **JavaScript**: plain ES modules, no build step, no framework, no third-party requests. Everything works with scripts off (principle 5), so a script only ever *adds*.
- **CSS**: custom properties for every colour, size and gap; no colour literal outside the `:root` blocks; both themes tested on `/specimen` for every change (`THEME-7`).
- **Python** (`tools/`): a script per job, `argparse`, a `--dry-run` where it writes, idempotent (running twice changes nothing), offline by default (`BUILD-2`).
- **Emacs Lisp** (`emacs/occurrent.el`): byte-compiles with zero warnings; `make test-emacs` green.
- **Shell**: only inside the `Makefile`; `set -e` semantics; long flags; nothing a `make clean` cannot undo.
- **Commits**: imperative subject ≤ 72 characters, the SPEC or STYLE id in brackets when one applies (`[TYPE-16]`, `[typo]`, `[meta]`); a body that says *why*. One change per commit. The `[typo]` and `[meta]` prefixes are what keep `REV-1` honest, so use them only for what they say.
- **Secrets** never enter the repository, including in `data/`, `local.mk`, `.local.*` files or history. `support/` is for sources, not credentials.

---

## 9. Repository documents

- **Markdown (`.md`) is the format for every document in the repository that is not a page**: `README.md`, `SPEC.md`, `BACKLOG.md`, the handovers, this manual, reports. GitHub renders it, the claude.ai Project mirrors it, and Claude Code reads it natively. `.org` is for Ryan's own notes outside the repository; nothing in `site/` is `.org`.
- **One file per subject**, named in capitals at the root (`SPEC`, `BACKLOG`, `STYLE`, `COMPAT`, `HANDOVERS`, which holds every phase's handover as a section), with a status line under the title: `Status: … · Owner: … · Last revised: YYYY-MM-DD`.
- **Rules carry ids** where they are enforced (`SPEC`) and plain headings where they are judgement (here). Cross-reference by id, never by page or section number, which move.
- **Revision notes** inline in italics, as `SPEC.md` does: *Revised 2026-10-26: …*. A document is a living document like an essay; its history is git's.
- **Markdown style**: ATX headings; one blank line between blocks; a table only when every cell fits in about 40 characters, so a row stays on one line in an editor, and a row whose cell is a sentence is instead a list item with a bold lead-in (the metas in §6.2 are the shape); em dashes without surrounding spaces; code spans for every identifier, path, tag and key; no HTML except where Markdown cannot do it.

---

## 10. Esthetics and interface

What the site looks like is specified in `SPEC.md` §4, §7–§11 and decided on `/specimen`. This section is the taste behind those rules, for the next decision.

- **Stance.** The page is a printed page that happens to be alive. Every interactive thing is a quieter version of something print already does: a margin note, a footnote, a cross-reference. If a feature has no print ancestor, it needs a very good reason.
- **Two marks only**: the arrow (takes you away) and the circle (you stay here). No third mark, ever (`MARK-1`). A reader learns the system in one essay.
- **Typography carries the hierarchy.** Size, case, weight and space, in that order of preference; colour last; rules sparingly; boxes never. Nothing is centred except the section-break glyph.
- **Colour** is for links and the current section, one accent, and the rest of the page is the text colour and its muted step. If a colour appears in two unrelated places, one of them is wrong.
- **Dark mode is a first-class theme**, not an inversion: every figure classified (`IMG-4`), every colour a property, every screenshot in the checks taken twice.
- **Motion** is for state change only (a popup opening, the bar appearing), ≤ 200 ms, and absent under `prefers-reduced-motion`.
- **Interface text** is sentence case, short, and in the site's words (§4.6): *Expand*, *Open in new tab*, *Contents*, *Notes*, *Bibliography*, *Backlinks*, *Changelog*. No exclamation marks, no "Click here", no jokes in the chrome.
- **Accessibility is not a mode.** Every control has an accessible name, focus is visible and managed, nothing is hover-only on touch, contrast meets AA in both themes, and the no-JS page is the baseline, not a fallback.
- **Print is a reader**, not an afterthought (`PRINT-1`–`8`): the PDF of a post is the post, with the apparatus as footnotes, and says when it was printed.
- **Engineering**: static, offline-buildable, no third-party requests, every rule tested, every rendered page validated (`VAL-1`). A thing that cannot be tested is a thing that will silently break.
- **Graveyard** (things tried and removed, so they are not tried again): definition stubs in the margin (`D7`, resolved three times: popups only); bordered boxes for expanded asides (replaced by the right rule); a centred header (left-aligned since 2026-10-15); numerals and ≡ as marks (the circle); the right margin going first as the window narrows (reversed 2026-10-19); run-in margin notes on phones (hidden since 2026-10-22). `BACKLOG.md` lists what is deliberately *not yet* built, which is different.

---

## 11. Writing with an assistant

For Claude Code sessions and any other model asked to draft, edit or review prose or files here.

- **The author's voice is the standard**, not a house blend. Read two published essays before drafting a sentence. Prefer the author's existing phrasing, images and examples to new ones.
- **Distinctiveness.** Avoid the register the models drift to: triplets, "it's not X, it's Y", rhetorical questions as transitions, "delve", "nuanced", "tapestry", "crucial", a summary paragraph that restates the section. If a sentence could open any essay, it opens none of these.
- **Draft workflow.** (1) Outline as margin notes first: if the outline does not read as an argument, stop. (2) Draft one section. (3) Mark every claim that needs a citation with `◊;{CITE?}` rather than inventing a key. (4) Hand over with the comments in place; the author removes them.
- **Never invent** a citation key, a quotation, a page number, a date, a correspondent or a clinical detail. A placeholder in a comment is correct; a plausible fabrication is a defect that may be published.
- **Edits are minimal and visible.** Change the sentence that is wrong, not the paragraph around it. Ventilated prose (§6.1) exists so that the diff shows exactly what you did.
- **Files and names** follow §7 exactly; when unsure of a surname or date, ask rather than guess.
- **Pre-handoff checklist.** `make test` green; no straight quote in output; every new figure has id, title, alt, licence; every new section has an id and `#:short` if long; no new tag; no `.org`, `.docx`, `.jpeg` or uppercase filename introduced; metas on one line; nothing in `support/` referenced by the build; the changelog line written if a claim changed; the SPEC id named in the commit.

---

*Revision notes.* 1.2 (2026-11-03): the tables of §6.2 and §7.2, whose cells were sentences, became lists; the rule for that in §9, because no editor wraps text inside a pipe-table cell. 1.1 (2026-11-02, afternoon): panel figures in §5.4, with SPEC `IMG-9`. 1.0 (2026-11-02): first draft, from `SPEC.md` §17 and gwern.net's style guide; the file-naming and filetype rules of §7.1–7.2 are taken from that guide with local adaptations marked **Here**. Open: the serial comma (`D5`), ventilated prose as practice (§6.1), the rename script (§7.1).
