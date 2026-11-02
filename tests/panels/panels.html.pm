#lang pollen
◊; IMG-9 fixture (pollen-test.rkt): a valid figure of three panels, one with its own credit, and a reference to B.

See ◊ref["p" #:panel "b"] and ◊ref["p"].

◊panels[#:id "p" #:title "Three panels" #:licence "own"]{
◊panel["img/2026-11-02-lucas-pillow-fixture-ball-a.jpg" #:alt "A ball."]{Ball}
◊panel["img/2026-11-02-lucas-pillow-fixture-valleys-b.png" #:alt "Three valleys." #:invert #t #:credit "After Waddington (1957)"]{Valleys}
◊panel["img/2026-11-02-lucas-fixture-branching-c.svg" #:alt "Branching paths."]{Paths}
The caption, which mentions A and C.}
