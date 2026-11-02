#lang pollen

◊define-meta[title]{Citation fixture (CITE-8)}

First claim ◊cite["hackingMakingPeople2006" #:loc "p. 23"]. A digression◊aside{An
aside citing a new work ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"]
and the first again ◊cite["hackingMakingPeople2006" #:loc "p. 24"].} then a body
citation ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"].

A second aside◊aside{With ◊term["looping-effect"]{looping}, whose definition
cites a work no note cites.} and a final note ◊cite["hackingMakingPeople2006"
#:note "With a remark."].

◊; BIB-9: an inline quotation (note 6, the short form) and a block quotation
◊; from a cited work (note 7, short form), each with a locator.
In his words, people are ◊q["hackingMakingPeople2006" #:loc "p. 23"]{made up, with "kinds" of
◊em{people}}. Then a block:

◊blockquote[#:source "Hacking" #:cite "hackingSocialConstructionWhat2000" #:loc "pp. 31-34"]{A
quoted passage, set as a block.}
