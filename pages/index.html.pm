#lang pollen

◊define-meta[title]{About}

◊section[#:id "me"]{Me}
I'm a paediatrician in Sydney, Australia. My clinical work focuses almost exclusively on the kinds of problems conventionally called "developmental" or "behavioural", categories that vastly oversimplify what is actually going on.

That broad critique is the motivation for the essays collected here. My contention is that "developmental paediatrics", as typically practised, is organised around a paradigm that is fundamentally misaligned with both what we as clinicians claim to be doing and what families are really looking for when they seek us out. 

◊section[#:id "the-essays"]{The Essays}
These essays exist because I derive value from writing them. Broadly:

◊list{
1. ◊margin{Why I write}Getting a thought properly expressed outside my head lets me move on to the next of thousands of thoughts vying for limited cognitive resources.
2. Seeing the thought in text helps me to step into a different frame, to better see the weaknesses in my reasoning. Sometimes that takes weeks or months, perhaps for any entanglement with my ego to have softened.
3. Having a documentary record of my thinking helps me to stabilise what would otherwise be a frenetic mess as I try out new modes of analysis. It also preserves the product of my analytic labour for my future self, who may not have thought about the thing for years.
4. It's a creative outlet.
}

So why publish the essays here? A few reasons:

◊list{
1. ◊margin{Why I publish}The prospect of a ◊aside["finalised product"]{Finalised in the sense of being publication ready. That doesn't imply that the essay is finished---quite the opposite: essays will be revised as my thinking evolves. While the essay rendered on the website will always be the most recent version, every essay's full revision history is available as readable source code in a public repository on GitHub, the link to which can be found at the top of each essay.} provides the motivation to actually finish an essay. Often the weaknesses only become apparent when I'm trying to pull the final threads together---so it really matters to see it through.
2. I have the great luxury of not being employed in an academic role and not having to care at all about my ◊link["https://en.wikipedia.org/wiki/H-index" #:note "h-index"]{◊em{h}-index}. I have no real incentive to engage with the likes of Wiley or Elsevier to publish something that almost no-one will ever read---and if no-one reads it, I would rather it were here. These essays aren't peer reviewed, but publishing openly under my own name imposes its own high standard: that I act in good faith; that I do due diligence in research; that I assert my claims clearly and respectfully; that I correct mistakes where readers can see them. I am writing about the ethics and philosophy of helping vulnerable children live good lives. My name is at the top of every essay.
3. For feedback on my thinking. I have no interest in hosting unfiltered commentary on this site, but ◊link["/correspondence"]{I welcome correspondence}.
4. I enjoy the process.
}

◊section[#:id "the-website"]{The Website}
I have a rather obsessive nature. Little things bother me; I often need them to be ◊em{just so}. I'm like that with visual design and ◊aside["typography"]{I write my clinic letters in Emacs using a custom ◊latex{} document class I wrote myself---it's the only way I could make them look how I wanted. While I'm very fond of the system I've created for myself, it's not what you would call rational.}. It's rewarding for me to create something that feels intentional and well-crafted. That's partly aesthetic but mostly functional: I want to use every tool available to me to reduce ambiguity and communicate clearly.

The only way that I could have a website and retain such granular control over visual design was to build it from scratch to my precise specifications. While I was able to teach myself enough ◊latex{} for my clinic letter project, I'm no web designer. Luckily I designed this website in 2026: it was built by Claude Code.

The site is written in bespoke ◊link["https://docs.racket-lang.org/pollen/"]{Pollen} markup, built with Racket on GitHub Actions, and served as static files by Cloudflare. It uses no framework, and a page loads nothing from outside this site: no analytics, no external fonts or scripts. I write the essays in a highly customised ◊link["https://www.gnu.org/software/emacs/"]{GNU Emacs} setup using a custom major mode that handles syntax highlighting, keybindings for Pollen markup, and publishing via Magit.

◊break{}

I take design inspiration from:

◊list{
- ◊link["https://www.edwardtufte.com/"]{Edward Tufte}. My use of margin notes, the design of tables, and my preference for high-data-density charts all come straight from Tufte. His book ◊link["https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information/"]{◊em{The Visual Display of Quantitative Information}} is a masterpiece.
- ◊link["https://matthewbutterick.com/"]{Matthew Butterick}. The minimalism of this site, particularly links, references his web design. See his free typography book ◊link["https://practicaltypography.com/"]{◊em{Practical Typography}}. Butterick also created Pollen, with which the site is built.
- ◊link["https://gwern.net/"]{Gwern Branwen}. The more sophisticated mechanics of this site (informative link marks, pinnable popups, and viewable source code) are all inspired by Gwern's work. His website is a laboratory for web design in support of long-form writing.
}

◊; ◊break{}

◊; Start here: ◊link["/placeholder"]{Placeholder}.

◊; ◊latest[3]
