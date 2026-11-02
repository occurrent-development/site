#lang pollen

◊define-meta[title]{Citation fixture (CITE-8)}

First claim ◊cite["hackingMakingPeople2006" #:loc "p. 23"]. A digression◊aside{An
aside citing a new work ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"]
and the first again ◊cite["hackingMakingPeople2006" #:loc "p. 24"].} then a body
citation ◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34"].

A second aside◊aside{With ◊term["looping-effect"]{looping}, whose definition
cites a work no note cites.} and a final note ◊cite["hackingMakingPeople2006"
#:note "With a remark."].

◊; BIB-9: a ◊cite with a body, a quotation (note 6, the short form), and one
◊; with #:block #t (note 7, short form), each with a locator.
In his words, people are ◊cite["hackingMakingPeople2006" #:loc "p. 23"]{made up, with "kinds" of
◊em{people}}. Then a block:

◊cite["hackingSocialConstructionWhat2000" #:loc "pp. 31-34" #:block #t]{A
quoted passage, set as a block.}

◊; BIB-9: two bare citations of one work in one paragraph (notes 8 and 9),
◊; listed once in its Cited in.
Twice in one paragraph ◊cite["hackingLoopingEffectsHuman1996"], and again
◊cite["hackingLoopingEffectsHuman1996"].
