#lang pollen

◊define-meta[title]{My Process: How Claude Helps Me Write}
◊define-meta[subtitle]{Idea capture, research, typesetting} ◊; optional
◊define-meta[status]{published} ◊; draft · published · revised · superseded
◊define-meta[published]{2026-11-23} ◊; YYYY-MM-DD
◊define-meta[tags]{workflows} ◊; comma-separated, lowercase
◊define-meta[author]{Ryan Lucas} ◊; the byline
◊; ◊define-meta[description]{} ◊; one sentence for search results, link previews and the feed
◊define-meta[listed]{false} ◊; true · false (false: not in the indexes, the front page or the feed)
◊define-meta[toc]{auto} ◊; auto · always · none (auto: contents from three sections)
◊define-meta[backlinks]{shown} ◊; shown · none
◊define-meta[endmatter]{shown} ◊; shown · none
◊; ◊define-meta[series]{} ◊; the slug of the series' home post, when this post is part of one
◊; ◊define-meta[part]{} ◊; this post's place in its series: 1, 2, 3 …
◊; ◊define-meta[series-label]{} ◊; on a series' home post: the words of the link back to it

I recently wrote a submission to the ◊link["https://www.aph.gov.au/Parliamentary_Business/Committees/House/Health_Aged_Care_and_Disability/Medicalspecialists/Terms_of_Reference"]{parliamentary inquiry into access to and affordability of medical specialists in Australia}.
I was able to pull together a fairly comprehensive submission in less than a week---all thanks to a writing process that I've been developing over several years.
The purpose of this entry is to explain that process.
If you do research or produce long-form pieces of writing at all then you'll hopefully get some helpful tips from what follows.

◊break{}

The main facilitator for my process is Claude, to which I subscribe.
When using ◊sc{AI} for writing I have three rules, which are baked into every step of my process:

◊list{
1. I have the ideas, I structure the document, I write the prose.◊aside{While the em dash (---) is often cited as evidence that writing was done by an ◊sc{LLM}, I've been em-dashing since long before ◊sc{GPT}-3 was born.}
2. I never cite a document I haven't read in its entirety.
3. I never use a number I cannot verify.
}

◊section[#:id "idea-capture"]{Idea capture}
I've always had a fondness for the historian Tony Judt.
The first work of his I read was ◊em{The Memory Chalet},◊cite["judtMemoryChalet2011" #:note "I highly recommend this book; it is wonderful."] and since then I have read ◊ref["judt-books-img"]{everything of his} I've been able to get my hands on.
Judt wrote ◊em{The Memory Chalet} while he was suffering from amyotrophic lateral sclerosis:

◊;{LOC? page number for this quotation, then add #:loc}
◊cite["judtMemoryChalet2011" #:block #t]{The salient quality of this particular neurodegenerative disorder is that it leaves your mind clear to reflect upon past, present, and future, but steadily deprives you of any means of converting those reflections into words.}

Unable to write himself, he would plan and write the next piece of writing at night, "storing" his plans in his recollection of a Swiss chalet from his childhood---the so-called ◊em{method of loci}.
Then, during the day, he would dictate to his assistant everything he had written the night before.

◊figure["img/judt-books.jpg" #:id "judt-books-img" #:title "Books by Tony Judt in my bookcase" #:alt "The spines of Tony Judt's books on a shelf, among them Postwar, Reappraisals and The Memory Chalet." #:licence "own"]{}

I don't have Judt's constraint, nor do I have his facility for the method of loci.
What I am is time poor.
Often my only "free" time is sitting in my car during my commute, or taking my dog for a walk.
◊;{LOC? page number for this quotation, then add #:loc}
Whereas Judt was ◊cite["judtMemoryChalet2011"]{writing whole stories in [his] head in the course of the night}, I was doing that on my way to work.
But how to capture it?

Enter: Claude.

◊subsection[#:id "the-claude-setup"]{The Claude setup}
I created a project in Claude called Essay Sessions.
The Instructions for that project are as follows:

◊codeblock{
PURPOSE
This project is for planning essays. Planning happens here; final drafting and markup happen in Emacs on my Mac. Many sessions will be voice conversations during my commute.

ESSAY FEATURES
All of my essays have:
- Title and subtitle
- Three section levels: heading, subheading, subsubheading
- Margin notes, term definitions, citations and links

THE INDEX DOC
The collection of essays is managed from one Claude Doc, the Index. Its link is at the end of these instructions.
- If there is no link and I ask you to create the index, create it from the Index template below, give me the link, and ask me to paste it into these instructions.
- If there is no link and I start a new essay, tell me the index doesn't exist yet and offer to create it first.
- At the start of any session about an essay, open the Index to find that essay's planning doc. Never create a second doc for an essay already listed.
- Keep the Index current: add new essays, update status and order when I change them, and record reorderings in the change log.

Index template:
# Essay Index
## Essay list
Table: Title | Subtitle | Status (Idea / Planning / In Emacs / Published) | Planning doc (link) | One-line thesis
## Meta notes
Recurring themes, ideas for future essays, notes on the collection as a whole.
## Change log
Dated notes when the order or scope changes.

PLANNING DOCS
Whenever I start discussing a new essay in this project create a Claude Doc for it using the template below, give me the link, and add it to the Index.

Planning doc template:
# [Title]
[Subtitle]
## Purpose
What the essay argues, for whom, and why now. 2–4 sentences.
## Structure
Notes arranged under the planned sections (Heading | Subheading | Subsubheading)
## Parking lot
Unplaced ideas, objections and open questions, with dated session summaries.
## References and reading
Sources to cite or check.

CONVENTIONS INSIDE DOCS
- Plain prose only; no markup.
- [MARGIN: ...] margin note
- [TERM: ...] term needing a definition
- [CITE: ...] citation needed or to check
- [LINK: ...] link to add
- [CHECK: ...] fact to verify

HOW TO WORK WITH ME
- Help me think, not write: When I specifically ask you may push back, test the analogies, name the strongest objection. Don't turn my ideas into prose.
- When I say "note that" or "write this down", capture my words, lightly tidied, in the section I name (or the parking lot if I don't).
- In voice sessions, save to the doc every 10–15 minutes or when I ask, and confirm edits out loud. At the end, add a dated summary to the parking lot: what we settled, what's open, what to read.
}

Now, if I'm driving or walking the dog and I want to work on a piece of writing, I just open Claude on my phone and start a chat in the Essay Sessions project.
I use the ◊ref["using-the-claude-voice-mode"]{Voice Mode} to have a back-and-forth conversation so I don't need to look at my phone whilst driving.
At the end of the session there will be a planning document saved in the Claude app.

◊panels[#:id "using-the-claude-voice-mode" #:title "Voice Mode to planning doc in Claude for iPhone" #:licence "own"]{
◊panel["img/claude-1.jpg" #:alt "An empty chat in the Claude iPhone app."]{Select Voice Mode in the Claude iPhone app}
◊panel["img/claude-2.jpg" #:alt "A voice conversation in the Claude iPhone app, in which I give Claude the title of this entry."]{Conversation about planned piece of writing}
◊panel["img/claude-3.jpg" #:alt "The planning doc in the Claude iPhone app, open at its title, subtitle and Purpose section."]{The planning doc as output}
}

◊subsection[#:id "what-this-does-for-my-writing"]{What this does for my writing}
The planning phase of a piece of writing can sometimes take months, which can then be followed by a break of another couple of months.
It's very helpful to be able to think out aloud and have those thoughts captured somewhere safe, and to then return to those thoughts when I have the mental space to continue.

It's also helpful to be able to have my thoughts read back to me, to be able to reflect, restate, and hear again.
I can also ask Claude to challenge my thinking, which can sometimes pull me out of a solipsistic loop to see that I've gotten my head stuck up my own...

◊section[#:id "research"]{Research}
I also made extensive use of Claude in the research phase of the parliamentary inquiry submission.
One part of that submission was an analysis of schedule fee indexation against both the Consumer Price Index (◊sc{CPI}) and the pay for a medical receptionist.
That analysis produced ◊ref["item-110-award-img"]{the following chart}.
In this section I'd like to briefly walk through how I did that research.

◊figure["img/item-110-vs-award-wide.svg" #:narrow "img/item-110-vs-award-narrow.svg"
#:id "item-110-award-img" #:title "Item 110 against a receptionist's wage since 2011"
#:alt "Line chart from 1 July 2011 to September 2026, each series set to 100 in 2011. The receptionist award hourly rate rose 63 per cent, consumer prices 51 per cent (the last four quarters are derived) and the item 110 schedule fee 26 per cent. The fee did not change from November 2012 to June 2018."
#:licence "own"]{
The Medicare schedule fee for item 110, the minimum award hourly rate for a medical receptionist, and the Consumer Price Index, each shown as an index with 1 July 2011 set to 100.}

◊subsection[#:id "doing-the-research"]{Doing the research}
I started with a fairly clear idea of what I wanted to do: replicate a chart I'd seen before plotting the Medicare schedule fee against the ◊sc{CPI} over a long time to show just how poor the indexation had been.
I wanted to use item 132, but Claude informed me that it didn't exist prior to 2007; item 110 would be better.
That was helpful!
The next step was to find historical schedule fees.
Try as I might I couldn't find this on the Medicare Benefits Schedule (◊sc{MBS}) website, but Claude very quickly directed me to ◊link["https://www.mbsonline.gov.au/internet/mbsonline/publishing.nsf/Content/Prev-Downloads" #:note "MBS Online's page of previous downloads, including historical versions of the MBS Book."]{its page of previous downloads}.
From there I was able to download all historical versions of the ◊sc{MBS} Book as ◊code{.pdf} documents.
Actually, that page had lots of files, most of them irrelevant.
So I used the Chrome Claude extension, and gave it the following prompt:

◊blockquote{Save all of the November files from 1997 onwards. Just the ones like "1997 November ◊sc{MBS}", not the optometrist or cleft lips ones. Save them to my download folder.}

That worked very well.
The years 2011 through 2019 were downloaded from a different page but via the same method.
From 2020 onwards the files were ◊code{.xml} not ◊code{.pdf}, but the downloads went the same.
I put those all in a subfolder within my submission folder, and asked Claude to rename them according to my usual filename convention (◊ref["historical-mbs-data"]).

◊figure["img/mbs-research.jpg" #:id "historical-mbs-data" #:title "The MBS Books, 1997–2026" #:alt "A Finder window showing the folder mbs-books, holding one renamed PDF of the MBS Book for each November from 1997, with the 1997 cover in the preview pane." #:licence "own"]{All November ◊sc{MBS} publications after Claude-assisted download and renaming.}

As for the ◊sc{CPI}, the historical data is published by the ◊link["https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia" #:note "Historical CPI data published by the ABS."]{Australian Bureau of Statistics}.
I navigated to that site and gave the Chrome Claude extension the following prompt:

◊blockquote{Build me a .csv file with all of the June ◊sc{CPI} numbers from 1997 until now.}

That worked fine.
At this point I started thinking about whether the ◊sc{CPI} was, in fact, the best number for showing how poorly ◊sc{MBS} schedule indexation has kept up with the cost of running a practice.
According to the Australian Bureau of Statistics:

◊blockquote[#:source "Australian Bureau of Statistics"]{The Consumer Price Index (◊sc{CPI}) measures household inflation and includes statistics about price change for categories of household expenditure.}

But the biggest cost of running a practice is labour, which isn't included in the ◊sc{CPI}.
Claude suggested using the Wage Price Index (◊sc{WPI}):

◊blockquote[#:source "Australian Bureau of Statistics"]{The ◊sc{WPI} measures changes in the price of labour, unaffected by compositional shifts in the labour force, hours worked or employee characteristics.}

But that really reflects the price of labour across the whole economy.
In a practice you're only employing staff in a couple of roles.
I had the idea of using the relevant award for medical receptionists, which I figured was much more targeted.
I've never had to look up historical award rates before; thankfully, Claude was able to direct me to the ◊link["https://www.fwc.gov.au/" #:note "Fair Work Commission website."]{Fair Work Commission website}.
The relevant award is the ◊em{Health Professionals and Support Services Award, MA000027}, and I chose to use the ◊em{Support Services employee, Level 3} for the analysis.
I couldn't navigate to the right documents, but found my way to a document search.
Searching for "MA000027" returned 197 results, some of which were the historical determinations that I wanted, called "Annual wage review".
The Chrome Claude extension again did a good job at finding and downloading the relevant ◊code{.pdf} files.

◊subsection[#:id "doing-the-analysis"]{Doing the analysis}
At this point I had two folders with the relevant source files, and a ◊code{.csv} file with ◊sc{CPI} data.
I then gave Claude access to those files and instructed it to go through the files and build a ◊code{.csv} file to my specifications.
I knew I'd want each series (the item 110 schedule fee, the award hourly rate and the ◊sc{CPI}) indexed to its own value at the start of the period (1 July 2011 = 100), so that their growth could be compared on a common scale.
You can download ◊download["2026-11-23-lucas-item-110-award-cpi.csv"]{the data behind the chart}.

My intention at this point had been to open that file in Excel and make the chart the way I wanted it... but I thought I'd see what Claude would do with it.
At this point Claude has a good understanding of my design principles (heavily influenced by Edward Tufte◊cite["tufteVisualDisplayQuantitative2001" #:note "This book informs most of my design philosophy."]).
Lo and behold: the chart that ended up in the submission is (more or less) what Claude spat out.◊aside{I later asked Claude to make ◊code{.svg} file versions for this site. That's what you see in ◊ref["item-110-award-img"].}

◊section[#:id "typesetting"]{Typesetting}
This section is about document typesetting in ◊latex{}, which is likely to be helpful for very few people.
I'll therefore keep it short.◊aside{Out of interest, I have a near-identical workflow for typesetting essays for this website.}

◊latex{} is a typesetting system, and it works differently from a word processor.
In Word, you format as you go: select some text, make it a heading, adjust the margins, and repeat whenever something drifts.
In ◊latex{}, all of those decisions (page size, margins, typefaces, how headings and references look) live in one place: a class file.
The document itself is written in plain text (as a ◊code{.tex} file), with some markup that signals how the formatting should be done.
For example, the submission started with an executive summary; in the ◊code{.tex} file that looked like this:

◊codeblock{
\section{Executive Summary}\label{sec:exec}
This submission defends three propositions about specialist care for children, and makes a recommendation that follows from each. The first recommendation is its centrepiece. It applies to every specialty, and I believe that it would be the most significant reform for access to complex specialist care in a generation. The second and third are specific to paediatrics.}

When the document is compiled, the class file's settings are applied to everything at once.
Change the margins in the class file, and every page of every document that uses it changes with it.
Once you get it right it becomes extremely efficient and powerful.
Unfortunately, ◊latex{} has a notoriously rough learning curve.
The basics aren't difficult, but complexity compounds rapidly, and the error messages can be pretty unhelpful.
I discovered that during my PhD.

◊subsection[#:id "the-phd"]{The PhD}
When I was writing my PhD thesis I got the idea of writing it in ◊latex{}.
I found a thesis class online, and decided to modify it for my own use.
Unfortunately, this was in the days before we all had access to powerful ◊sc{AI}.
If you were trying to fix a bug in a class file you'd end up spending hours searching for a similar problem on Stack Overflow.
You were in luck if someone else had posted the exact same problem---and you knew how to interpret the answer.

I had a difficult project: the thesis needed to be built of multiple chapters, each with its own references and bibliography; I also wanted a glossary and an index.
I'd modified the class file so that the text column was towards the spine of the open bound page, with a wide outside margin for margin notes (as I use on this site).
It then all needed to compile together into a unified document.
That was ambitious---and it didn't work.
I think I got about 95% of the way there, but in the end it was the referencing that defeated me.
In the end I wrote my thesis in Word.
I hated every minute of it.

Skip forward a few years and now the problem that I couldn't solve despite hours of work can be identified and fixed by Claude in under a minute!
I built a custom document class for modular clinic letters, and write my letters in Emacs with ◊latex{} markup.

◊subsection[#:id "the-submission"]{The submission}
Over the years I had built my own essay writing class called ◊code{rdl-essay}.
It specified my preferred typography (measure, margins, headers) and worked seamlessly with Zotero and Better BibTeX to manage citations.
It wasn't too complicated, and I'd mostly built it myself, but rarely used it.

When it came time to write the submission to the parliamentary inquiry I created a new class called ◊code{rdl-submission} based on ◊code{rdl-essay}; critically, I gave Claude access to that class file.
As I wrote I would intermittently compile the document to check how it looked.
There were often small issues, like a ◊sc{URL} over-running a column, that are annoying to fix.
All I had to do was pass it to Claude: the class file would be updated and the problem fixed.

That also meant that I could be innovative.
I had a large table with all of the ◊sc{MBS} item numbers that paediatricians can use.
I had Claude build a macro so that the item number in the table linked directly to the relevant page on the ◊sc{MBS} website.
When the item number was used in the body text it linked straight to the table.
That would've been a pain to build, but Claude did it in minutes.

Then, when I was finished writing the submission I had Claude go over the entire document to check that my style was consistent and that all of the internal and external links worked properly.

◊section[#:id "conclusion"]{Conclusion}
What I hope has come through clearly in this entry is that ◊sc{AI} can be an extremely useful tool for things like research and writing of long-form and technical documents.
For me the most important thing is that it can do all of that---and save me a bunch of time---without encroaching on the sanctity of my domain: the ideas, the structure, and the writing.

I hope this entry is helpful to others who have to do this kind of work!
