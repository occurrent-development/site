#lang pollen

◊define-meta[title]{Link A}
◊define-meta[status]{published}
◊define-meta[published]{2026-10-03}

◊; Phase 3 fixture (VAL-4, BIB-1): two essays that link to each other and cite one work.

A links to ◊link["/link-b#second"]{the second section of B}, and cites a work
◊cite["hackingMakingPeople2006" #:loc "p. 24"].

◊section[#:id "later"]{Later}

A links within itself, to ◊link["#later"]{this section}, which is not a backlink.

◊changelog{
2026-10-05: Added the section on what comes later.
}
