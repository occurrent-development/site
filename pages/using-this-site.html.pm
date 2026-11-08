#lang pollen

◊;{DRAFT, reader guide. Not listed in index.ptree, so make neither renders nor
publishes it; preview with make serve at /pages/using-this-site.html. TODO(ryan) comments
mark everything still to write; see SITE-DOCS.md.}

◊define-meta[title]{Using this site}
◊define-meta[unlisted]{yes}

◊;{TODO(ryan): write each section for a reader, in your words. The comments give the facts
and where they come from. Document only what exists: planned features stay in BACKLOG.md.
Lines marked VERIFY are facts I could not confirm shipped.}

◊section[#:id "reading"]{Reading}

◊;{Facts. The contents sit in the left column on wide windows and in the reading bar
otherwise (TOC-2, BAR-1). Text size buttons are in the bar. The theme control offers
Auto, Light and Dark and remembers the choice in the browser (THEME-1).}

◊section[#:id "links-and-marks"]{Links and marks}

◊;{Facts (MARK-1, POP-1, POP-9 to POP-11). Two marks: an arrow takes you away, a circle
opens something where you are. Popups can be pinned on pointer devices in wide windows,
dragged, and docked in the widest tier. Asides sit in the right margin and margin notes in
the left on wide windows; on narrow ones asides open as popups and margin notes are hidden.}

◊section[#:id "linking-to-a-heading"]{Linking to a heading}

◊;{Facts (SECT-7). Each heading shows a section self-link on hover, for copying a deep link.
Heading ids are permanent, so such links keep working (VAL-3).}

◊section[#:id "scratch-pad"]{The scratch pad}

◊;{Facts (POP-12). A Scratch link is docked at the bottom left of the window. One pad for
the whole site, kept in the browser only, capped at 64 KB. Copy and Clear controls. It does
not exist without scripts or on touch devices. Nothing leaves the browser.}

◊section[#:id "source-and-history"]{Source and history}

◊;{Facts (REV-2). Every essay and page links to its source file and its full commit history on
GitHub, in the header and the footer. Substantive revisions are logged at the foot of the
essay and collected on the Changelog page.}

◊section[#:id "printing"]{Printing}

◊;{Facts. A print stylesheet exists (PRINT-1). VERIFY: PRINT-2 specifies a PDF per essay at
/slug.pdf, but data/publish.txt lists no PDFs, so it may not have shipped. Do not describe
PDFs until it has.}

◊section[#:id "feeds"]{Feeds}

◊;{Facts (REV-4). An Atom feed is published at /feed.xml. VERIFY its contents against
build/feed.xml: the spec says new essays, new blog entries and substantive revisions, each
marked with its kind. Say whether there is a separate essays-only feed only if there is.}

◊section[#:id "scripts-and-privacy"]{Scripts and privacy}

◊;{Facts. Every page works with scripts off (SPEC principle 5). A page loads nothing from
outside the site: no analytics, no external fonts or scripts (stated on the current About
page, which this section can link to or replace).}
