#lang racket/base
;; Tests for the root pass: paragraphs and line breaks (SRC-3), the section
;; tree (SECT-1…6), the table of contents (TOC-1) and the intro paragraph.

(require rackunit
         racket/string
         racket/list
         racket/file
         txexpr
         (except-in "pollen.rkt" list)
         (only-in "pollen.rkt" [list od-list])
         (only-in "lib/util.rkt" parse-tags output->url text-of source-urls post-kind check-post-slugs)
         (only-in "lib/tables.rkt" table-element))

(define (fails? thunk) (with-handlers ([exn:fail? (λ (e) #t)]) (thunk) #f))

(define (find-all tx pred)
  (let walk ([x tx])
    (if (txexpr? x)
        (append (if (pred x) (list x) null) (append-map walk (get-elements x)))
        null)))

(define (tag? t) (λ (x) (eq? (get-tag x) t)))
(define (classes x) (if (attrs-have-key? x 'class) (attr-ref x 'class) ""))
(define (has-class* x c) (member c (string-split (classes x))))

(test-case "SRC-3: a single newline is a space; a blank line is a paragraph"
  (check-equal? (root "one" "\n" "two")
                '(root (p ((class "intro")) "one two")))
  (check-equal? (root "one" "\n\n" "two")
                '(root (p ((class "intro")) "one") (p "two")))
  (check-equal? (root "one" (br) "two")
                '(root (p ((class "intro")) "one" (br) "two")))
  (check-equal? (root (em "wrapped" "\n" "emphasis"))
                '(root (p ((class "intro")) (em "wrapped emphasis")))))

(test-case "TYPE-13: a rule fires across a wrapped line"
  (check-equal? (root "about 10" "\n" "kg")
                '(root (p ((class "intro")) "about 10\u202Fkg"))))

(define three-sections
  (list "Intro." "\n\n"
        (section #:id "a" #:short "A" "Alpha") "\n" (summary "About alpha.") "\n\n"
        "In a." "\n\n"
        (subsection #:id "a-1" "Alpha one") "\n\n" "In a-1." "\n\n"
        (subsubsection #:id "a-1-x" "Deep.") " Run in." "\n\n"
        (section #:id "b" "Beta") "\n\n" "In b." "\n\n"
        (section #:id "c" "Gamma") "\n\n" "In c."))

(test-case "SECT-2: headings become nested sections"
  (define doc (apply root three-sections))
  (define sections (find-all doc (tag? 'section)))
  (check-equal? (map (λ (s) (attr-ref s 'id)) sections) '("a" "a-1" "a-1-x" "b" "c"))
  (check-equal? (map (λ (s) (attr-ref s 'class)) sections)
                '("level-1" "level-2" "level-3" "level-1" "level-1"))
  ;; a-1 is inside a; b is not
  (define a (first sections))
  (check-not-false (member "a-1" (map (λ (s) (attr-ref s 'id)) (find-all a (tag? 'section)))))
  (check-false (member "b" (map (λ (s) (attr-ref s 'id)) (find-all a (tag? 'section)))))
  ;; heading levels: section → h2, subsection → h3, subsubsection → h4
  (check-equal? (map get-tag (map (λ (s) (car (get-elements s))) sections)) '(h2 h3 h4 h2 h2))
  ;; SECT-6: the summary is not in the body
  (check-equal? (find-all doc (tag? 'od-summary)) '()))

(test-case "SECT-7: every heading has a § self-link"
  (define doc (apply root three-sections))
  (define links (find-all doc (λ (x) (and (eq? (get-tag x) 'a) (attrs-have-key? x 'class)
                                          (equal? (attr-ref x 'class) "self")))))
  (check-equal? (map (λ (a) (attr-ref a 'href)) links) '("#a" "#a-1" "#a-1-x" "#b" "#c"))
  (check-equal? (attr-ref (first links) 'aria-label) "Link to this section: Alpha"))

(test-case "TOC-1: levels 1–2, short titles, summaries as tooltips"
  (define doc (apply root three-sections))
  (define nav (first (get-elements doc)))
  (check-equal? (get-tag nav) 'nav)
  (define links (find-all nav (tag? 'a)))
  (check-equal? (map (λ (a) (attr-ref a 'href)) links) '("#a" "#a-1" "#b" "#c"))
  (check-equal? (get-elements (first links)) '("A"))
  (check-equal? (attr-ref (first links) 'title) "About alpha.")
  ;; fewer than three level-1 sections: no TOC
  (check-equal? (find-all (root (section #:id "x" "X") "\n\n" (section #:id "y" "Y")) (tag? 'nav)) '()))

(test-case "LAYOUT-3: only the first paragraph is the intro"
  (define doc (apply root three-sections))
  (define intros (find-all doc (λ (x) (and (attrs-have-key? x 'class) (equal? (attr-ref x 'class) "intro")))))
  (check-equal? intros '((p ((class "intro")) "Intro."))))

(test-case "SECT-1/3/5: validation"
  (check-true (fails? (λ () (section "No id"))))
  (check-true (fails? (λ () (section #:id "Bad Id" "Title"))))
  (check-true (fails? (λ () (root (section #:id "a" "A") "\n\n" (subsubsection #:id "b" "B")))))
  (check-true (fails? (λ () (root (subsection #:id "a" "Starts at level 2")))))
  (check-true (fails? (λ () (root (section #:id "a" "A") "\n\n" (section #:id "a" "Again")))))
  (check-true (fails? (λ () (root (blockquote (section #:id "a" "Inside a quote"))))))
  (check-true (fails? (λ () (root "Text." "\n\n" (summary "Orphan."))))))

(test-case "the TOC follows an epigraph"
  (define doc (apply root (cons (epigraph "Motto.") (cons "\n\n" three-sections))))
  (check-equal? (map get-tag (take (get-elements doc) 2)) '(blockquote nav)))

;; ---------------------------------------------------------------------------
;; Fixtures rendered through Pollen itself (tests/*.html.pm)

(require pollen/core)

(define (fixture name) (get-doc (build-path "tests" name)))
(define (by-id doc id) (findf (λ (x) (and (attrs-have-key? x 'id) (equal? (attr-ref x 'id) id)))
                              (find-all doc txexpr?)))
(define (text x) (cond [(string? x) x] [(txexpr? x) (apply string-append (map text (get-elements x)))] [else ""]))

(test-case "LIST-1…3: nesting, mixed markers, continuation paragraphs"
  (define doc (fixture "lists.html.pm"))
  (define top (car (get-elements doc)))
  (check-equal? (get-tag top) 'ul)
  (check-equal? (map (λ (li) (attr-ref li 'data-n)) (find-all doc (λ (x) (and (eq? (get-tag x) 'li) (attrs-have-key? x 'data-n)))))
                '("1." "2." "2.1."))
  (check-equal? (length (find-all doc (tag? 'p))) 2))

(test-case "CITE-8: notes numbered once, in reading order, asides included"
  (define doc (fixture "citations.html.pm"))
  (define (targets x) (string-split (attr-ref x 'data-targets "")))
  (define openers (find-all doc (λ (x) (attrs-have-key? x 'data-targets))))
  ;; CITE-1: no numerals in the text; circles open notes 1–7 in reading order
  ;; (6 and 7 are the quotations, BIB-9)
  (check-equal? (filter (λ (t) (regexp-match? #rx"^note-" t)) (remove-duplicates (append-map targets openers)))
                '("note-1" "note-2" "note-3" "note-4" "note-5" "note-6" "note-7" "note-8" "note-9"))
  (check-equal? (find-all doc (tag? 'sup)) '())
  (define notes (find-all (by-id doc "notes") (tag? 'li)))
  (check-equal? (length notes) 9)                       ; not double-counted (CITE-2)
  (define (note n) (regexp-replace* #rx"\u00A0" (text (by-id doc (format "note-~a" n))) " "))
  ;; CITE-3: full form first, short form after, each with its own locator
  (check-regexp-match #rx"^Ian Hacking, “Making Up People,” London Review of Books 28, no. 16 \\(2006\\): 23\\." (note 1))
  (check-regexp-match #rx"^Ian Hacking, The Social Construction of What\\? \\(Harvard" (note 2))  ; inside the first aside
  (check-regexp-match #rx"^Hacking, “Making Up People,” 24\\." (note 3))                           ; inside the first aside
  (check-regexp-match #rx"^Hacking, The Social Construction of What\\?, 31–34\\." (note 4))         ; body
  (check-regexp-match #rx"^Hacking, “Making Up People\\.” With a remark\\." (note 5))
  ;; BIB-9: a quotation is a citation in every other respect: short forms here,
  ;; with their own locators
  (check-regexp-match #rx"^Hacking, “Making Up People,” 23\\." (note 6))
  (check-regexp-match #rx"^Hacking, The Social Construction of What\\?, 31–34\\." (note 7))
  ;; CITE-4: each note's ↩ goes to the circle that opens it; for a note inside
  ;; an aside that circle is in the aside's end copy (the inline copy has no ids)
  (define backs (find-all (by-id doc "notes") (λ (x) (equal? (attr-ref x 'class #f) "back"))))
  (for ([b (in-list backs)] [n (in-naturals 1)])
    (define circle (by-id doc (substring (attr-ref b 'href) 1)))
    (check-not-false (member (format "note-~a" n) (targets circle))))
  (define opener-2 (by-id doc (substring (attr-ref (list-ref backs 1) 'href) 1)))
  (check-not-false (memq opener-2 (find-all (by-id doc "asides") txexpr?)))
  ;; ASIDE-2: asides are unnumbered and named "aside"
  (check-true (for/and ([o (in-list openers)] #:when (member "aside-1" (targets o)))
                (regexp-match? #rx"aside" (attr-ref o 'aria-label ""))))
  ;; CITE-7: the definition's citation is unnumbered and opens the work's full entry
  (define terms (by-id doc "terms"))
  (check-not-false (findf (λ (x) (member "bib-hackingLoopingEffectsHuman1996" (targets x)))
                          (find-all terms (λ (x) (attrs-have-key? x 'data-targets)))))
  ;; CITE-10: the Bibliography lists every work the page cites, the one in a
  ;; definition included; the popups read it too (POP-7)
  (define store (by-id doc "bibliography"))
  (check-false (attrs-have-key? store 'hidden))
  (check-equal? (map (λ (li) (attr-ref li 'id)) (find-all store (tag? 'li)))
                '("bib-hackingMakingPeople2006" "bib-hackingLoopingEffectsHuman1996" "bib-hackingSocialConstructionWhat2000"))
  ;; without scripts, the definition shows the work it cites
  (check-not-false (findf (λ (x) (has-class* x "term-refs")) (find-all terms txexpr?)))
  ;; CITE-10: end matter order
  (check-equal? (map (λ (s) (attr-ref s 'id)) (find-all doc (λ (x) (equal? (attr-ref x 'class #f) "endmatter"))))
                '("terms" "asides" "notes" "bibliography")))

(test-case "CITE-10: one visible list; without scripts a circle goes to the Bibliography, whose ↩ leads back"
  (define doc (fixture "citations.html.pm"))
  (define bib (by-id doc "bibliography"))
  ;; every numbered circle links to its work's entry
  (define note-circles
    (find-all doc (λ (x) (and (eq? (get-tag x) 'a) (attrs-have-key? x 'data-targets)
                              (regexp-match? #rx"note-" (attr-ref x 'data-targets))))))
  (check-true (pair? note-circles))
  (for ([c (in-list note-circles)])
    (check-regexp-match #rx"^#bib-" (attr-ref c 'href))
    (check-not-false (by-id bib (substring (attr-ref c 'href) 1))))
  ;; each entry has one ↩ per numbered citation of the work, each reaching a circle that opens one of its notes
  (define (note-key n) (attr-ref (by-id doc (format "note-~a" n)) 'data-bib))
  (for ([li (in-list (find-all bib (tag? 'li)))])
    (define backs (find-all li (λ (x) (equal? (attr-ref x 'class #f) "back"))))
    (define expected (for/list ([n (in-range 1 10)] #:when (equal? (note-key n) (attr-ref li 'id))) n))
    (check-equal? (length backs) (length expected))
    (for ([b (in-list backs)] [n (in-list expected)])
      (define circle (by-id doc (substring (attr-ref b 'href) 1)))
      (check-not-false (member (format "note-~a" n) (string-split (attr-ref circle 'data-targets)))))))

(test-case "MARK-1c: annotations at the same point share one circle"
  (define doc (root "Claim" (cite "hackingMakingPeople2006" #:loc "p. 23")
                    (cite "hackingSocialConstructionWhat2000" #:loc "pp. 31-34") ", then "
                    (term "occurrent" "occurrent") " " (cite "hackingMakingPeople2006" #:loc "p. 24")
                    " and apart" (cite "hackingMakingPeople2006") "."))
  (define body (txexpr 'root null (filter (λ (x) (not (equal? (attr-ref x 'class #f) "endmatter"))) (get-elements doc))))
  (define circles (find-all body (λ (x) (has-class* x "circle"))))
  (check-equal? (length circles) 3)
  (define openers (find-all body (λ (x) (attrs-have-key? x 'data-targets))))
  (check-equal? (map (λ (o) (attr-ref o 'data-targets)) openers)
                '("note-1 note-2" "term-occurrent note-3" "note-4"))
  (check-equal? (attr-ref (car openers) 'aria-label) "reference 1, reference 2")
  (check-equal? (attr-ref (cadr openers) 'aria-label) "definition, reference 3")
  ;; D8: without JS a shared circle links to its first item
  ;; (CITE-10: a numbered circle's href is its work's Bibliography entry)
  (check-equal? (attr-ref (car openers) 'href) "#bib-hackingMakingPeople2006")
  (check-equal? (attr-ref (cadr openers) 'href) "#term-occurrent"))

(define (marks-in doc) (map classes (find-all doc (λ (x) (regexp-match? #rx"^mark " (classes x))))))

(test-case "LINK-1/2: link types, directions and broken targets"
  (define doc (root (section #:id "a" "A") "\n\n"
                    (link "https://example.org" "out") " " (link "/colophon" "across") " "
                    (link "#a" "up") " " (link "#b" "down") "\n\n"
                    (section #:id "b" "B")))
  (check-equal? (marks-in doc) '("mark m-ext" "mark m-xref" "mark m-up" "mark m-down"))
  (check-true (fails? (λ () (root (link "#nowhere" "x")))))
  (check-true (fails? (λ () (root (link "mailto:x@y" "x"))))))

(test-case "MARK-3: the last word and its mark never part"
  (define doc (root (link "https://example.org" "two words")))
  (define nw (car (find-all doc (λ (x) (equal? (classes x) "nw")))))
  (check-equal? (car (get-elements nw)) "words"))

(test-case "TERM-5/6: first use marked, later uses plain, unknown ids fail"
  (define doc (root (term "occurrent" "occurrent") " and " (term "occurrent" "again")
                    " and " (term "occurrent" #:mark #t "forced")))
  (define body (txexpr 'root null (filter (λ (x) (not (equal? (classes x) "endmatter"))) (get-elements doc))))
  (check-equal? (length (find-all body (λ (x) (and (has-class* x "term") (attrs-have-key? x 'data-targets))))) 2)
  (check-not-false (by-id doc "term-occurrent"))
  (check-not-false (by-id doc "term-continuant"))   ; reached through the definition (TERM-7)
  (check-true (fails? (λ () (root (term "no-such-term" "x"))))))

(define (notes-in doc) (find-all doc (λ (x) (has-class* x "margin-note"))))
(define (parent-of doc x) (car (find-all doc (λ (p) (memq x (get-elements p))))))

(test-case "MNOTE-6: the four anchors pass, and the note stays where it was written"
  ;; (a) first in a paragraph: no space before, one after
  (define a (root (margin " Gloss. ") "  Text."))
  (check-equal? (get-elements (car (get-elements a)))
                '((span ((class "margin-note")) "Gloss." " ") "Text."))
  ;; (b) first in a list item, after the marker, at any depth (the about page)
  (define b (root (od-list "\n"
                           "1. " (margin "Inexhaustive list of why I write") "Getting a thought properly expressed outside my head allows my mind to move on." "\n"
                           "2. Seeing the thought in text helps me to step into a different frame." "\n"
                           "   - " (margin "Nested") "A sub-item." "\n")))
  (define lis (find-all b (tag? 'li)))
  (check-equal? (length (notes-in b)) 2)
  (check-equal? (car (get-elements (first lis))) '(span ((class "margin-note")) "Inexhaustive list of why I write" " "))
  (check-equal? (get-tag (parent-of b (second (notes-in b)))) 'li)
  ;; (c) first in a paragraph of a blockquote or epigraph
  (for ([q (list (blockquote (margin "Q") " Quoted.") (epigraph (margin "E") " Motto."))])
    (define d (root q))
    (check-equal? (get-tag (parent-of d (car (notes-in d)))) 'p))
  ;; (d) at a sentence start: after . ! ? …, a closing quote after one, or ◊br{}
  (for ([before (list "One." "Really?" "So it goes…" "He said “stop.”" "(As above.)")])
    (define d (root before (margin "Two") " Second."))
    (define els (get-elements (car (get-elements d))))
    (check-equal? (length (notes-in d)) 1 before)
    (check-regexp-match #px"\\S $" (car els))                    ; one space before
    (check-not-false (has-class* (cadr els) "margin-note") before))
  (check-equal? (length (notes-in (root "A line" (br) (margin "After a break") "next."))) 1)
  ;; a sentence ending in an aside's body is not a sentence end in the text
  (check-equal? (length (notes-in (root "Fine." (aside "Body") " " (margin "M") "Next."))) 1))

(test-case "MNOTE-6: anywhere else fails"
  (check-true (fails? (λ () (root "Some text " (margin "mid-sentence") "more."))))
  (check-true (fails? (λ () (root "Some " (em "text") " " (margin "late") "more."))))
  (check-true (fails? (λ () (root "Ends in an aside" (aside "Which ends.") " " (margin "M") "on."))))
  (check-true (fails? (λ () (root (margin "One") (margin "Two") "Text."))))
  (check-true (fails? (λ () (root (margin "One") " " (margin "Two") "Text."))))
  (check-true (fails? (λ () (root "x" (aside "Inside. " (margin "no") "An aside.")))))
  (check-true (fails? (λ () (root (figure "pages/img/landscape.jpg" #:id "f" #:title "T" #:alt "a" #:licence "own"
                                          (margin "no") "A caption.")))))
  (check-true (fails? (λ () (root (section #:id "h" (margin "no") "A heading")))))
  (check-true (fails? (λ () (root (em (margin "no") "Inside emphasis.")))))
  ;; MNOTE-5: no annotations inside a note
  (check-true (fails? (λ () (root (margin (link "https://example.org" "x")) " Text."))))
  (check-true (fails? (λ () (root "x" (aside "nested " (aside "no")))))))

(test-case "TABLE-1/5/6: semantic tables, wrong cell counts fail"
  (define t (table #:id "t" #:title "T" #:caption "C" "\n" "| a | b |" "\n" "|---|---|" "\n"
                   "| 1 | x |" "\n" "| 2 | y |" "\n" "| 3 | z |" "\n" "| 4 | w |" "\n" "| 5 | v |" "\n"))
  (check-not-false (findf (λ (x) (attrs-have-key? x 'data-sortable)) (find-all t (tag? 'table))))
  (check-equal? (length (find-all t (λ (x) (equal? (attr-ref x 'scope #f) "col")))) 2)
  (check-equal? (classes (car (find-all t (tag? 'td)))) "a-right")
  (check-true (fails? (λ () (table #:id "t" #:title "T" "| a | b |" "\n" "|---|---|" "\n" "| 1 |" "\n")))))

(test-case "IMG-3/6: figures need alt text and a licence"
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:licence "own" "c"))))
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:alt "a" "c"))))
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:alt "a" #:licence "cc-by-4.0" "c")))))

(require (only-in "lib/util.rkt" published?))

(test-case "DRAFT-2: only non-draft essays are published; pages always are"
  (check-true (published? "pages/specimen.html.pm" #f))
  (check-true (published? "essays/x/x.html.pm" "published"))
  (check-true (published? "essays/x/x.html.pm" "revised"))
  (check-true (published? "essays/x/x.html.pm" "superseded"))
  (check-false (published? "essays/x/x.html.pm" "draft"))
  (check-false (published? "essays/x/x.html.pm" #f)))

(test-case "VAL-1: essays need title, a known status and a published date"
  (check-not-false (fixture "essays/draft-essay/draft-essay.html.pm"))
  (check-true (fails? (λ () (fixture "essays/bad-status/bad-status.html.pm"))))
  (check-true (fails? (λ () (fixture "essays/no-date/no-date.html.pm"))))
  ;; a fixture that fails leaves Pollen's current-metas pointing at it
  (current-metas #f))

(test-case "MARK-3: a circle after an inline element is bound to it"
  (define doc (root (em "Books") " " (cite "hackingMakingPeople2006" #:loc "p. 23") " and on."))
  (define body (filter (λ (x) (not (has-class* x "endmatter"))) (get-elements doc)))
  (define nw (find-all (txexpr 'root null body) (λ (x) (has-class* x "nw"))))
  (check-equal? (length nw) 1)
  (check-equal? (get-tag (car (get-elements (car nw)))) 'em))

(test-case "TABLE-5: ◊sort-key gives a cell the value it sorts by"
  (define t (table #:id "t" #:title "T" "| Year | Event |" "\n" "|---|---|" "\n" "| " (sort-key "2004" "c. 2004") " | x |" "\n"))
  (check-not-false (findf (λ (x) (equal? (attr-ref x 'data-sort #f) "2004")) (find-all t txexpr?))))

(test-case "POP-7: notes say whether they are the full or the short form"
  (define doc (fixture "citations.html.pm"))
  (check-equal? (map (λ (n) (attr-ref (by-id doc (format "note-~a" n)) 'data-form)) '(1 2 3 4 5 6 7))
                '("full" "full" "short" "short" "short" "short" "short")))

(test-case "INDEX-3: tags are comma-separated lowercase words"
  (check-equal? (parse-tags "philosophy,  child development , site, site") '("philosophy" "child development" "site"))
  (check-true (fails? (λ () (parse-tags "Philosophy"))))
  (check-true (fails? (λ () (parse-tags "a;b")))))

(test-case "URLs: pages and essays are flattened to /<slug>"
  (check-equal? (output->url "index.html") "/")
  (check-equal? (output->url "pages/about.html") "/about")
  (check-equal? (output->url "essays/placeholder/placeholder.html") "/placeholder")
  ;; HOME-1: the About page is the root; D14: entries live under /blog
  (check-equal? (output->url "pages/index.html") "/")
  (check-equal? (output->url "pages/essays.html") "/essays")
  (check-equal? (output->url "blog/a-day/a-day.html") "/blog/a-day"))

(test-case "INDEX-1: the essay index lists dated essays, newest first, with tags"
  (define idx (index #:kind "essay" #:pagetree "tests/index.ptree"))
  (define rows (find-all idx (tag? 'tr)))
  (define titles (for/list ([r (in-list (cdr rows))]) (string-trim (apply string-append (filter string? (get-elements (car (find-all r (tag? 'a)))))))))
  (check-equal? titles '("Newer" "Listed"))         ; undated pages, drafts and entries are left out
  (check-equal? (attr-ref (caddr rows) 'data-tags) "site|philosophy")
  (check-not-false (findf (λ (th) (attrs-have-key? th 'data-nosort)) (find-all idx (tag? 'th)))))

(test-case "MARK-3a: punctuation after a mark goes before it, in the no-wrap span"
  (define doc (root "See " (link "https://example.org" "the source") ", and " (cite "hackingMakingPeople2006") ". Done."))
  (define nws (find-all doc (λ (x) (has-class* x "nw"))))
  (define (punct-then-mark? nw p)
    (define els (get-elements nw))
    (define i (index-where els (λ (e) (has-class* e "punct"))))
    (and i (equal? (get-elements (list-ref els i)) (list p))
         (findf (λ (e) (or (has-class* e "mark") (has-class* e "circle-link"))) (drop els i))
         #t))
  (check-true (punct-then-mark? (car nws) ","))
  (check-true (punct-then-mark? (cadr nws) "."))
  (check-not-false (member " Done." (get-elements (car (find-all doc (tag? 'p)))))))

(test-case "MARK-3: a mark after an italic phrase binds only its last word"
  (define doc (root "in the " (em "London Review of Books") (cite "hackingMakingPeople2006") " and"))
  (define nw (car (find-all doc (λ (x) (has-class* x "nw")))))
  (check-equal? (car (get-elements nw)) '(em "Books"))
  (check-not-false (member '(em "London Review of ") (find-all doc (tag? 'em)))))

(test-case "IMG-7: figures and tables need an id and a title; widths are gone"
  (define rows (list "| a |" "\n" "|---|" "\n" "| 1 |" "\n"))
  (check-true (fails? (λ () (apply table #:title "T" rows))))
  (check-true (fails? (λ () (apply table #:id "t" rows))))
  (check-true (fails? (λ () (apply table #:id "t" #:title "T" #:width "wide" rows))))
  (check-true (fails? (λ () (apply table #:id "Bad Id" #:title "T" rows)))))

(test-case "IMG-7: numbered in order, each kind on its own; ◊ref prints the label"
  (define (tab id) (table #:id id #:title "T" "| a |" "\n" "|---|" "\n" "| 1 |" "\n"))
  (define doc (root "See " (ref "second") " and " (ref "first") "." "\n\n" (tab "first") "\n\n" (tab "second")))
  (define labels (map (λ (x) (text-of x)) (find-all doc (λ (x) (has-class* x "exhibit-label")))))
  (check-equal? labels '("Table\u00A01" "Table\u00A02"))
  (define links (find-all doc (λ (x) (and ((tag? 'a) x) (has-class* x "same")))))
  (check-equal? (map (λ (a) (attr-ref a 'href)) links) '("#second" "#first"))
  (check-true (and (regexp-match? #rx"Table\u00A02" (text-of (car links))) #t))
  (check-true (fails? (λ () (root "See " (ref "nowhere") ".")))))

;; IMG-9: tests/panels/, read by Pollen itself
(test-case "IMG-9: one exhibit; panels lifted in order, lettered by the build; the rest is the caption"
  (define doc (fixture "panels/panels.html.pm"))
  (check-equal? (length (find-all doc (λ (x) (has-class* x "exhibit")))) 1)
  (define fig (by-id doc "p"))
  (check-equal? (text-of (car (find-all fig (λ (x) (has-class* x "exhibit-label"))))) "Figure 1")
  (define panels (find-all fig (λ (x) (has-class* x "panel"))))
  (check-equal? (map (λ (p) (text-of (car (find-all p (λ (x) (has-class* x "panel-letter")))))) panels)
                '("A" "B" "C"))
  (check-equal? (map (λ (p) (attr-ref p 'aria-labelledby)) panels) '("p-a" "p-b" "p-c"))
  ;; each its own image, alt and data-invert: a photograph, a drawing forced
  ;; to invert, an SVG (never classified, IMG-4); none on the figure itself
  (check-equal? (map (λ (p) (attr-ref p 'data-invert)) panels) '("auto" "yes" "auto"))
  (check-false (attrs-have-key? fig 'data-invert))
  (check-equal? (length (find-all (car panels) (tag? 'picture))) 1)
  (check-equal? (length (find-all (caddr panels) (λ (x) (has-class* x "figure-svg")))) 1)
  (check-equal? (attr-ref (car (find-all (car panels) (tag? 'img))) 'alt) "A ball.")
  (check-equal? (attr-ref (car (find-all (caddr panels) (λ (x) (has-class* x "figure-svg")))) 'aria-label)
                "Branching paths.")
  (check-equal? (map (λ (p) (text-of (car (find-all p (λ (x) (has-class* x "panel-caption")))))) panels)
                '("Ball" "Valleys" "Paths"))
  (check-true (pair? (find-all (car panels) (λ (x) (has-class* x "credit")))))   ; IMG-3a
  ;; the caption is what is left, trimmed; the credit line groups by letter
  (check-equal? (text-of (car (find-all fig (λ (x) (has-class* x "exhibit-caption")))))
                "The caption, which mentions A and C.")
  (check-equal? (text-of (car (find-all fig (λ (x) (and ((tag? 'span) x) (equal? (attr-ref x 'class #f) "credit"))))))
                "A, C: own · B: After Waddington (1957)")
  ;; ◊ref's #:panel: "Figure 1B", one link to the figure
  (define refs (find-all doc (λ (x) (has-class* x "exhibit-ref"))))
  (check-equal? (map text-of refs) '("Figure 1B" "Figure 1"))
  (check-equal? (map (λ (a) (attr-ref a 'href)) (find-all doc (λ (x) (and ((tag? 'a) x) (has-class* x "same")))))
                '("#p" "#p")))

(test-case "IMG-9: the build errors VAL-1 lists, and the rights IMG-6 adds"
  (for ([f (in-list '("outside" "one" "seven" "no-alt" "bad-letter" "no-licence"))])
    (check-true (fails? (λ () (fixture (format "panels/~a.html.pm" f)))) f))
  ;; a #:panel on a figure with no panels; a letter outside a to f
  (check-true (fails? (λ () (root "See " (ref "f" #:panel "a") "." "\n\n"
                                  (figure "pages/img/landscape.jpg" #:id "f" #:title "T" #:alt "a" #:licence "own" "c")))))
  (check-true (fails? (λ () (ref "p" #:panel "g"))))
  (check-true (fails? (λ () (ref "p" #:panel "ab"))))
  ;; a panel under another's licence needs a credit, on itself or the figure;
  ;; a panel may not claim the cover licence (BIB-7)
  (check-true (fails? (λ () (panels #:id "q" #:title "T" #:licence "cc-by-4.0"
                                    (panel "pages/img/landscape.jpg" #:alt "a")
                                    (panel "pages/img/landscape.jpg" #:alt "b")))))
  (check-true (fails? (λ () (panels #:id "q" #:title "T" #:licence "own"
                                    (panel "pages/img/landscape.jpg" #:alt "a" #:licence "cover")
                                    (panel "pages/img/landscape.jpg" #:alt "b")))))
  (for ([c (in-list '(0 4))])
    (check-true (fails? (λ () (panels #:id "q" #:title "T" #:licence "own" #:columns c
                                      (panel "pages/img/landscape.jpg" #:alt "a")
                                      (panel "pages/img/landscape.jpg" #:alt "b")))) (format "#:columns ~a" c))))

(test-case "IMG-9 (1.21): #:columns 1 stacks the panels, each at the column's width, lettered as ever"
  (define doc (fixture "panels/stack.html.pm"))
  (define fig (by-id doc "s"))
  (define grid (car (find-all fig (λ (x) (has-class* x "panels")))))
  (check-equal? (attr-ref grid 'data-columns) "1")
  (define panels (find-all fig (λ (x) (has-class* x "panel"))))
  (check-equal? (map (λ (p) (text-of (car (find-all p (λ (x) (has-class* x "panel-letter")))))) panels)
                '("A" "B"))
  (check-equal? (attr-ref (car (find-all (car panels) (tag? 'img))) 'sizes)
                "(min-width: 48.75rem) 45.625rem, calc(100vw - 3.125rem)")   ; the full column
  (check-equal? (text-of (car (find-all fig (λ (x) (has-class* x "exhibit-caption"))))) "The caption."))

(test-case "EDIT-10: Org's table separators: |---+---| under the header, others ignored"
  (define t (table #:id "o" #:title "T" "| a | b |" "\n" "|---+---|" "\n" "| 1 | 2 |" "\n" "|---+---|" "\n" "| 3 | 4 |" "\n"))
  (check-equal? (length (find-all t (tag? 'th))) 2)
  (check-equal? (length (find-all t (tag? 'tr))) 3)        ; header + two body rows
  (check-true (fails? (λ () (table #:id "o" #:title "T" "| a | b |" "\n" "|---+---|" "\n" "| 1 |" "\n")))))

;; VOCAB-3: the Emacs vocabulary and the tags pollen.rkt provides agree, so
;; the highlighter never calls a working tag an error, nor the reverse.
(test-case "VOCAB-3: od-vocabulary's built tags are exactly the tags pollen.rkt provides"
  (define template-helpers
    '(root site-css font-preloads head-script asset-url specimen? specimen-css page-title
      essay-header doc-body format-date revised-date site-menu page-class
      reference-card locator-label))   ; for tools/validate.rkt and the tests (BIB-8), not tags
  ;; tags with keyword arguments are exported as syntax, so read both lists
  (define-values (vars stx) (module->exports (string->path (path->string (build-path (current-directory) "pollen.rkt")))))
  (define provided
    (for*/list ([phase (in-list (append vars stx))] #:when (eqv? (car phase) 0) [e (in-list (cdr phase))]
                #:unless (memq (car e) template-helpers))
      (car e)))
  (define el (file->string "emacs/occurrent.el"))
  (define built
    (for/list ([m (in-list (regexp-match* #px"(?m:^\\s*\\(([a-z][a-z0-9-]*)\\s+:pos [^\n]*:built t)" el #:match-select cadr))])
      (string->symbol m)))
  (check-not-false (pair? built) "no vocabulary entries found in emacs/occurrent.el")
  ;; define-meta is Pollen's own, not a pollen.rkt export
  (check-equal? (sort (remq 'define-meta built) symbol<?) (sort provided symbol<?)))

;; SRC-4a: ◊abstract and ◊epistemic are written in the body and set in the header.
(define (with-title thunk) (parameterize ([current-metas (hasheq 'title "T")]) (thunk)))

(test-case "SRC-4a: abstract and epistemic move into the header, with their markup"
  (define doc (with-title (λ () (root (epistemic "Fairly " (em "sure") ".") "\n\n"
                                      (abstract "An abstract " (cite "hackingMakingPeople2006") ".") "\n\n"
                                      "The text " (cite "hackingSocialConstructionWhat2000" #:loc "pp. 31-34") "."))))
  (define header (car (get-elements doc)))
  (check-equal? (get-tag header) 'header)
  (check-not-false (findf (λ (x) (has-class* x "abstract")) (find-all header txexpr?)))
  (check-not-false (findf (λ (x) (has-class* x "epistemic")) (find-all header txexpr?)))
  (check-equal? (length (find-all header (tag? 'em))) 1)
  ;; the abstract's citation is note 1, the body's note 2
  (check-equal? (attr-ref (car (find-all header (λ (x) (has-class* x "circle-link")))) 'href) "#bib-hackingMakingPeople2006")
  (check-equal? (map (λ (p) (classes p)) (filter (tag? 'p) (cdr (get-elements doc)))) '("intro")))

(test-case "SRC-4a: once each, at the top level; the old meta lines fail"
  (check-true (fails? (λ () (with-title (λ () (root (abstract "a") "\n\n" (abstract "b")))))))
  (check-true (fails? (λ () (with-title (λ () (root "Text " (abstract "inside a paragraph") "."))))))
  (check-true (fails? (λ () (parameterize ([current-metas (hasheq 'title "T" 'abstract "old")]) (root "x"))))))

(test-case "SRC-4a: an empty ◊abstract{} counts as absent"
  (define doc (with-title (λ () (root (abstract "") "\n\n" "Text."))))
  (check-equal? (attr-ref (car (get-elements doc)) 'class) "essay-header no-abstract"))

;; REV-2: Source · History, derived from the file's path under the root.
(test-case "REV-2: the specimen's source links point at pages/specimen.html.pm"
  ;; the header as the specimen gets it, from its path; rendering the page
  ;; itself would need the image variants `make` builds after the tests
  (define here (path->string (build-path (current-directory) "pages" "specimen.html.pm")))
  (define doc (parameterize ([current-metas (hasheq 'title "Specimen" 'here-path here)])
                (root (epistemic "A test page.") "\n\n" "Text.")))
  (define line (car (find-all doc (λ (x) (has-class* x "source")))))
  (define links (find-all line (λ (x) (and (eq? (get-tag x) 'a) (has-class* x "ext")))))
  (check-equal? (map (λ (a) (attr-ref a 'href)) links)
                '("https://github.com/occurrent-development/site/blob/main/pages/specimen.html.pm"
                  "https://github.com/occurrent-development/site/commits/main/pages/specimen.html.pm"))
  (check-equal? (map (λ (a) (string-replace (string-trim (text a)) "\u2060" "")) links) '("Source (external link)" "History (external link)"))
  ;; LAYOUT-1: after the tags, before the epistemic status, which is last
  (define block (car (find-all doc (λ (x) (has-class* x "header-meta")))))
  (check-equal? (map classes (get-elements block)) '("source" "epistemic")))

(test-case "REV-2: an essay's path is nested; a file outside the root fails"
  (define-values (blob commits) (source-urls (build-path (current-directory) "essays" "some-slug" "some-slug.html.pm")))
  (check-equal? blob "https://github.com/occurrent-development/site/blob/main/essays/some-slug/some-slug.html.pm")
  (check-equal? commits "https://github.com/occurrent-development/site/commits/main/essays/some-slug/some-slug.html.pm")
  (check-exn #rx"^build error: .*not under the project root" (λ () (source-urls (build-path (current-directory) 'up "elsewhere.html.pm"))))
  (check-exn #rx"^build error: .*not under the project root" (λ () (source-urls "/tmp/stray.html.pm"))))

;; ASIDE-8: the phrase form, read by Pollen itself from tests/asides.html.pm,
;; since only its reader tells ◊aside["phrase"]{body} from ◊aside{body}.
(test-case "ASIDE-8: both forms render; phrase and circle are one link"
  (define doc (fixture "asides.html.pm"))
  (define ps (filter (tag? 'p) (get-elements doc)))
  ;; the about page's sentence: the phrase stays in the text, with its space
  (define p1 (first ps))
  (check-equal? (car (get-elements p1)) "The prospect of a ")
  (define a (car (find-all p1 (λ (x) (has-class* x "aside-phrase")))))
  (check-regexp-match #rx"^finalised product" (text a))
  (check-equal? (attr-ref a 'data-targets) "aside-1")
  (check-equal? (attr-ref a 'href) "#aside-1")
  ;; MARK-3b: only the last word is bound to the circle, inside the one link
  (define nw (car (find-all a (λ (x) (has-class* x "nw")))))
  (check-equal? (car (get-elements nw)) "product")
  (check-not-false (findf (λ (x) (has-class* x "circle")) (get-elements nw)))
  (check-equal? (text (car (find-all nw (λ (x) (has-class* x "vh"))))) " (aside)")
  ;; the body is not in the text, only in the hidden copy and the Asides list
  (check-false (regexp-match? #rx"immutable" (text (txexpr 'p null (filter (λ (e) (not (and (txexpr? e) (attrs-have-key? e 'hidden)))) (get-elements p1))))))
  (check-not-false (by-id doc "aside-1"))
  ;; without a phrase: the circle alone, as before
  (define p2 (second ps))
  (check-equal? (find-all p2 (λ (x) (has-class* x "aside-phrase"))) '())
  (check-equal? (attr-ref (car (find-all p2 (λ (x) (has-class* x "circle-link")))) 'data-targets) "aside-2")
  ;; a phrase may carry ◊em
  (check-not-false (findf (tag? 'em) (find-all (third ps) txexpr?))))

(test-case "ASIDE-8/MARK-3a: punctuation after a phrase aside goes before its circle"
  (define doc (fixture "asides.html.pm"))
  (define nw (car (find-all (third (filter (tag? 'p) (get-elements doc))) (λ (x) (has-class* x "nw")))))
  (define els (get-elements nw))
  (define i (index-where els (λ (e) (has-class* e "punct"))))
  (check-equal? (get-elements (list-ref els i)) '(","))
  (check-not-false (findf (λ (e) (has-class* e "circle")) (drop els i))))

(test-case "ASIDE-8/MARK-1c: a phrase followed by ◊cite shares one circle"
  (define doc (fixture "asides.html.pm"))
  (define p4 (fourth (filter (tag? 'p) (get-elements doc))))
  (check-equal? (length (find-all p4 (λ (x) (has-class* x "circle")))) 1)
  (define a (car (find-all p4 (λ (x) (has-class* x "aside-phrase")))))
  (check-equal? (attr-ref a 'data-targets) "aside-4 note-1")
  (check-equal? (car (get-elements (car (find-all a (λ (x) (has-class* x "nw")))))) "point")
  ;; the note's ↩ goes back to that link
  (check-equal? (attr-ref (car (find-all (by-id doc "note-1") (λ (x) (has-class* x "back")))) 'href)
                (string-append "#" (attr-ref a 'id))))

(test-case "ASIDE-8: a phrase holds no annotations"
  (check-true (fails? (λ () (root "A " (aside #:phrase (list "cited " (cite "hackingMakingPeople2006")) "Body.")))))
  (check-true (fails? (λ () (root "A " (aside #:phrase (list (link "https://example.org" "x")) "Body.")))))
  (check-true (fails? (λ () (root "A " (aside #:phrase (list (term "occurrent" "occurrent")) "Body.")))))
  (check-true (fails? (λ () (root "A " (aside #:phrase (list (aside "nested")) "Body.")))))
  (check-true (fails? (λ () (root "A " (aside #:phrase "" "Body."))))))

(test-case "LAYOUT-4a…4c: epigraphs italic, block quotations roman; #:italic flips either"
  (define (class-of x) (attr-ref x 'class))
  (check-equal? (class-of (epigraph "Motto.")) "epigraph")
  (check-equal? (class-of (epigraph #:italic #f "Motto.")) "epigraph roman")
  (check-equal? (class-of (epigraph #:italic #t "Motto.")) "epigraph")
  (check-equal? (class-of (blockquote "Quoted.")) "quote")
  (check-equal? (class-of (blockquote #:italic #t "Quoted.")) "quote italic")
  (check-equal? (class-of (blockquote #:italic #f "Quoted.")) "quote")
  (check-true (fails? (λ () (blockquote #:italic "yes" "Quoted."))))
  ;; the TOC still follows an epigraph set roman
  (check-equal? (get-tag (car (get-elements (root (epigraph #:italic #f "Motto."))))) 'blockquote))

(test-case "INDEX-1a: the index is a table with four cells in every row"
  ;; two fixture pages are listed (tests/essays/listed)
  (define idx (index #:kind "essay" #:pagetree "tests/index.ptree"))
  (define head (car (find-all idx (tag? 'thead))))
  (check-equal? (map (λ (th) (string-trim (text th))) (find-all head (tag? 'th)))
                '("Title" "Published" "Edited" "Tags"))
  (define body-rows (find-all (car (find-all idx (tag? 'tbody))) (tag? 'tr)))
  (check-equal? (length body-rows) 2)
  (for ([r (in-list body-rows)])
    (define cells (filter txexpr? (get-elements r)))
    (check-equal? (length cells) 4)
    (check-equal? (map get-tag cells) '(td td td td))
    (check-equal? (map classes cells) '("title" "date-col published" "date-col edited" "tags")))
  ;; Title · Published · Edited · Tags, in that order
  (define newer (filter txexpr? (get-elements (car body-rows))))
  (check-equal? (string-trim (text (first newer))) "Newer")
  (check-equal? (attr-ref (car (find-all (second newer) (tag? 'time))) 'datetime) "2026-10-05")
  (check-equal? (attr-ref (car (find-all (second newer) (λ (x) (attrs-have-key? x 'data-sort)))) 'data-sort) "2026-10-05")
  (check-not-false (findf (λ (x) (attrs-have-key? x 'datetime)) (find-all (third newer) txexpr?)))
  (check-equal? (string-trim (text (fourth (filter txexpr? (get-elements (cadr body-rows)))))) "site, philosophy")
  ;; sortable at any number of rows (INDEX-3), as ◊table is at five
  (check-not-false (attrs-have-key? (car (find-all idx (tag? 'table))) 'data-sortable))
  ;; the TABLE-1 cell-count check is the same code
  (check-exn #rx"row 1 has 3 cells, the header has 4"
             (λ () (table-element '(("a") ("b") ("c") ("d")) '(#f #f #f #f) '((("1") ("2") ("3")))))))

(test-case "MNOTE-6: a note that glosses nothing fails"
  (define (msg thunk) (with-handlers ([exn:fail? exn-message]) (thunk) #f))
  ;; the end of a paragraph, of a list item (the about page, 2026-10-20) and of a quoted paragraph
  (check-regexp-match #rx"◊margin glosses nothing: move it to the start of the item or sentence"
                      (msg (λ () (root "Text." (margin "Late")))))
  (check-regexp-match #rx"glosses nothing"
                      (msg (λ () (root (od-list "\n" "1. Getting a thought expressed."
                                                (margin "Inexhaustive list of why I write") "\n"
                                                "2. Seeing the thought." "\n")))))
  (check-regexp-match #rx"glosses nothing" (msg (λ () (root (blockquote "Quoted. " (margin "M") "  ")))))
  ;; at the end of an item's own text, before its nested list
  (check-regexp-match #rx"glosses nothing"
                      (msg (λ () (root (od-list "\n" "- Parent." (margin "M") "\n" "  - Child." "\n")))))
  ;; the remedy passes: the note at the start of the item
  (check-equal? (length (notes-in (root (od-list "\n" "1. " (margin "Why I write") "Getting a thought." "\n")))) 1))

(test-case "TYPE-16: quotes in the page are curled, across tags and annotations"
  (define doc (root "The prospect of a finalised \"product\"" (aside "That isn't so.")
                    " is what gets an essay \"finished\"" (cite "hackingMakingPeople2006") ". Next, "
                    (em "\"word\"") "."))
  (define p (car (get-elements doc)))
  (check-regexp-match #rx"finalised “product”" (text p))
  (check-regexp-match #rx"“word”" (text p))
  ;; the quote before the ◊cite closes; MARK-3a moves the stop after the
  ;; cite in between the closing quote and the circle
  (define nw (car (find-all p (λ (x) (and (has-class* x "nw") (pair? (find-all x (λ (y) (has-class* y "punct")))))))))
  (check-regexp-match #rx"^“finished”\\.⁠" (text nw))
  ;; an epigraph's source is curled too
  (check-regexp-match #rx"Plato’s “Cratylus”"
                      (text (car (find-all (root (epigraph #:source "Plato's \"Cratylus\"" "Motto.")) (tag? 'footer))))))

(test-case "LAYOUT-1, 1b, 1c, 1d, 1e: the header's block, its author line, labelled tags, both dates, and the closing rule"
  (define h (header-sample #:title "T" #:published "2026-10-01" #:revised "2026-10-15"
                           #:tags "site, typography" #:epistemic "A sample."))
  (define block (car (find-all h (λ (x) (has-class* x "header-meta")))))
  ;; author, dates, tags, then the epistemic status last (no source links in a sample)
  (check-equal? (map classes (get-elements block)) '("author" "dates" "tags" "epistemic"))
  (define tags (caddr (get-elements block)))
  (check-equal? (string-trim (text (car (get-elements tags)))) "Tagged:")
  (check-equal? (length (find-all tags (λ (x) (has-class* x "tag-link")))) 2)
  (check-equal? (map (λ (d) (text (car (find-all d (λ (x) (has-class* x "meta-label"))))))
                     (find-all block (λ (x) (has-class* x "date"))))
                '("Published:" "Edited:"))
  ;; no tags, no line; no epistemic status, no line
  (define bare (header-sample #:title "T" #:published "2026-10-01"))
  (check-equal? (map classes (get-elements (car (find-all bare (λ (x) (has-class* x "header-meta")))))) '("author" "dates"))
  ;; LAYOUT-1d: never edited → both dates show, and they are the same
  (check-equal? (map (λ (d) (string-trim (text d))) (find-all bare (λ (x) (has-class* x "date"))))
                '("Published: 1 October 2026" "Edited: 1 October 2026"))
  ;; LAYOUT-1e: the author line opens the block and defaults to the site's author
  (define by (λ (h) (string-trim (text (car (find-all h (λ (x) (has-class* x "author"))))))))
  (check-equal? (by bare) "Author: Ryan Lucas")
  (check-equal? (by (header-sample #:title "T" #:published "2026-10-01" #:author "A Guest")) "Author: A Guest")
  ;; LAYOUT-1c: the header ends with its rule, with or without an abstract
  (check-not-false (has-class* (last (get-elements h)) "header-rule"))
  (check-not-false (has-class* (last (get-elements (header-sample #:title "T" "An abstract."))) "header-rule")))

(test-case "TYPE-17: ◊latex{} is the logo in letters, named LaTeX; a body fails"
  (define l (latex))
  (check-equal? (attr-ref l 'class) "latex")
  (check-equal? (attr-ref l 'aria-label) "LaTeX")
  (check-equal? (text l) "LaTEX")                       ; letters of the text face, no image
  (check-true (fails? (λ () (latex "LaTeX"))))
  ;; it sits in running text, in italic and in an aside alike
  (define doc (root "Set in " (latex) ", " (em "and " (latex)) "." (aside "Even " (latex) ".")))
  (check-equal? (length (find-all doc (λ (x) (has-class* x "latex")))) 4))   ; the aside's two copies

;; §13b: the blog. Entries are posts of the second kind, set from the folder.
(define (in-entry thunk)
  (define here (path->string (build-path (current-directory) "tests" "blog" "x" "x.html.pm")))
  (parameterize ([current-metas (hasheq 'title "T" 'status "published" 'published "2026-10-01" 'here-path here)])
    (thunk)))

(test-case "KIND-1: the kind comes from the folder; a kind meta and a clashing slug fail"
  (check-equal? (post-kind "essays/a/a.html.pm") 'essay)
  (check-equal? (post-kind "blog/a/a.html.pm") 'entry)
  (check-false (post-kind "pages/colophon.html.pm"))
  (check-exn #rx"kind comes from its folder"
             (λ () (parameterize ([current-metas (hasheq 'title "T" 'kind "entry")]) (root "x"))))
  (check-equal? (check-post-slugs '(("a" . "essays/a") ("b" . "blog/b")) '("index")) '())
  (check-equal? (length (check-post-slugs '(("a" . "essays/a") ("a" . "blog/a")) '())) 1)
  (check-equal? (length (check-post-slugs '(("about" . "blog/about") ("glossary" . "essays/glossary")) '())) 2)
  (check-equal? (length (check-post-slugs '(("essays" . "blog/essays")) '("essays"))) 1)
  ;; the page wrapper says which kind, and nothing else does
  (check-equal? (page-class (hasheq 'here-path "/x/blog/a/a.html.pm")) "page kind-entry")
  (check-equal? (page-class (hasheq 'here-path "/x/essays/a/a.html.pm")) "page"))

(test-case "KIND-2: an entry has no epistemic status; an abstract is allowed"
  (check-exn #rx"no epistemic status" (λ () (in-entry (λ () (root (epistemic "Sure.") "\n\n" "Text.")))))
  (define doc (in-entry (λ () (root (abstract "Briefly.") "\n\n" "Text."))))
  (check-not-false (findf (λ (x) (has-class* x "abstract")) (find-all doc txexpr?)))
  ;; DRAFT-2 applies to entries
  (check-false (published? "blog/x/x.html.pm" "draft"))
  (check-true (published? "blog/x/x.html.pm" "published")))

(test-case "KIND-3: an entry has no contents at any section count, and the essay header without the epistemic line"
  (define doc (fixture "blog/sectioned-entry/sectioned-entry.html.pm"))
  (check-equal? (find-all doc (λ (x) (has-class* x "toc"))) '())
  (check-equal? (length (find-all doc (λ (x) (and (eq? (get-tag x) 'section) (has-class* x "level-1"))))) 3)
  (define header (car (get-elements doc)))
  (check-equal? (get-tag header) 'header)
  (define block (car (find-all header (λ (x) (has-class* x "header-meta")))))
  ;; KIND-3, LAYOUT-1d, 1e: the author, both dates, tags and source; no epistemic line
  (check-equal? (map classes (get-elements block)) '("author" "dates" "tags" "source"))
  (check-equal? (length (find-all block (λ (x) (has-class* x "date")))) 2)
  (check-not-false (findf (λ (x) (has-class* x "abstract")) (find-all header txexpr?)))
  (check-not-false (has-class* (last (get-elements header)) "header-rule"))
  ;; LAYOUT-1b, KIND-4: its tags link to the blog's index
  (check-equal? (attr-ref (car (find-all block (λ (x) (has-class* x "tag-link")))) 'href) "/blog?tags=site")
  ;; an essay with the same sections has contents, and its tags go to /essays
  (define essay (parameterize ([current-metas (hasheq 'title "T" 'status "published" 'published "2026-10-01" 'tags "site" 'here-path (path->string (build-path (current-directory) "essays" "x" "x.html.pm")))])
                  (root (section #:id "a" "A") "\n\n" "x" "\n\n" (section #:id "b" "B") "\n\n" "y" "\n\n" (section #:id "c" "C") "\n\n" "z")))
  (check-not-false (findf (λ (x) (has-class* x "toc")) (find-all essay txexpr?)))
  (check-equal? (attr-ref (car (find-all essay (λ (x) (has-class* x "tag-link")))) 'href) "/essays?tags=site"))

(test-case "KIND-4, INDEX-1a: the blog index has three cells in every row: Title · Date · Tags"
  (define idx (index #:kind "entry" #:pagetree "tests/index.ptree"))
  (check-equal? (map (λ (th) (string-trim (text th))) (find-all (car (find-all idx (tag? 'thead))) (tag? 'th)))
                '("Title" "Published" "Tags"))
  (define rows (find-all (car (find-all idx (tag? 'tbody))) (tag? 'tr)))
  (define cells (map (λ (r) (filter txexpr? (get-elements r))) rows))
  (check-equal? (map length cells) '(3 3 3))
  (check-equal? (map (λ (c) (string-trim (text (first c)))) cells) '("Newer entry" "A sectioned entry" "Older entry"))
  (check-equal? (map classes (first cells)) '("title" "date-col published" "tags"))
  (check-equal? (attr-ref (car (find-all (second (third cells)) (tag? 'time))) 'datetime) "2026-10-03")
  (check-equal? (string-trim (text (third (third cells)))) "site, blog")
  ;; (a fixture's URL keeps its tests/ prefix; a real entry's is /blog/<slug>)
  (check-regexp-match #rx"/blog/newer-entry/newer-entry$" (attr-ref (car (find-all (first (first cells)) (tag? 'a))) 'href))
  (check-not-false (attrs-have-key? (car (find-all idx (tag? 'table))) 'data-sortable))
  (check-true (fails? (λ () (index #:kind "blog" #:pagetree "tests/index.ptree")))))

(test-case "HOME-2: the home page's title is the masthead, one h1 of two words with a stroke at each outer end"
  (define metas (hasheq 'title "Occurrent Development"
                        'here-path (path->string (build-path (current-directory) "pages/index.html.pm"))))
  (define header (essay-header metas #f #f))
  (define h1 (car (find-all header (tag? 'h1))))
  (check-not-false (has-class* h1 "masthead"))
  (check-equal? (text h1) "Occurrent Development")
  (check-equal? (length (find-all h1 (λ (x) (and (txexpr? x) (has-class* x "swash"))))) 2)
  (check-equal? (map (λ (x) (text x)) (find-all h1 (λ (x) (and (txexpr? x) (has-class* x "masthead-word")))))
                '("Occurrent" "Development"))
  (check-false (findf (λ (x) (and (txexpr? x) (has-class* x "header-rule"))) (get-elements header)))
  ;; any other page, and a one-word or three-word title, keep the plain h1
  (define about (essay-header (hasheq 'title "Occurrent Development"
                                      'here-path (path->string (build-path (current-directory) "pages/about.html.pm"))) #f #f))
  (check-false (has-class* (car (find-all about (tag? 'h1))) "masthead"))
  (define three (essay-header (hasheq 'title "One Two Three"
                                      'here-path (path->string (build-path (current-directory) "pages/index.html.pm"))) #f #f))
  (check-false (has-class* (car (find-all three (tag? 'h1))) "masthead")))

(test-case "HOME-1: ◊recent is two columns, the newest posts of each kind, newest first"
  (define r (recent 3 #:pagetree "tests/recent.ptree"))
  (check-equal? (map (λ (x) (attr-ref x 'class)) (get-elements r)) '("recent-essays" "recent-blog"))
  (define essays (car (get-elements r)))
  (check-equal? (text (car (find-all essays (tag? 'h3)))) "Essays")
  (define items (find-all essays (tag? 'li)))
  (check-equal? (length items) 3)                          ; three of the four; the draft never
  (check-equal? (map (λ (li) (regexp-replace* #rx"⁠| \\(link to another page\\)" (text (car (find-all li (tag? 'a)))) ""))
                     items)
                '("Newer" "Link B" "Link A"))
  (check-equal? (map (λ (li) (regexp-replace* #rx" " (text (car (find-all li (λ (x) (has-class* x "date"))))) " ")) items)
                '("5 Oct 2026" "4 Oct 2026" "3 Oct 2026"))
  (check-not-false (member "/essays" (map (λ (a) (attr-ref a (quote href))) (find-all essays (tag? (quote a))))))
  ;; a kind with nothing published: its heading and Nothing yet
  (define blog (cadr (get-elements r)))
  (check-equal? (text (car (find-all blog (tag? 'h3)))) "Blog")
  (check-equal? (text (findf (λ (x) (has-class* x "empty")) (find-all blog txexpr?))) "Nothing yet"))

(test-case "NAV-1: Home · About · Essays · Blog · Glossary · Bibliography; an essay marks Essays, an entry Blog"
  (define (menu here) (site-menu (hasheq 'here-path (path->string (build-path (current-directory) here)))))
  (check-regexp-match #rx">Home<.*>About<.*>Essays<.*>Blog<.*>Glossary<.*>Bibliography<" (menu "pages/index.html.pm"))
  (check-regexp-match #rx"href=\"/about\" aria-current=\"page\"" (menu "pages/about.html.pm"))
  (check-regexp-match #rx"href=\"/glossary\" aria-current=\"page\"" (menu "pages/glossary.html.pm"))
  (check-regexp-match #rx"href=\"/essays\" aria-current=\"page\"" (menu "essays/placeholder/placeholder.html.pm"))
  (check-regexp-match #rx"href=\"/blog\" aria-current=\"page\"" (menu "blog/a/a.html.pm"))
  (check-regexp-match #rx"href=\"/\" aria-current=\"page\"" (menu "pages/index.html.pm")))

(test-case "NAV-1, POP-12: Scratch is not in the menu (it is docked at the window's foot); the handle is the monogram, never the name"
  (define here (hasheq 'here-path (path->string (build-path (current-directory) "pages/index.html.pm"))))
  (check-false (regexp-match? #rx"Scratch|menu-scratch" (site-menu here)))
  (for ([menu (list (site-menu here) (site-menu here #:bar #t))])
    (check-regexp-match #rx"<summary aria-label=\"Site menu\"><span class=\"menu-icon\" aria-hidden=\"true\"></span><svg class=\"chevron\"" menu)
    (check-false (regexp-match? #rx"site-name|Occurrent" menu))))

;; ---------------------------------------------------------------------------
;; Phase 3: around the essays. The graph is built here from fixtures by the
;; same walk tools/validate.rkt runs (lib/walk.rkt), and handed to the
;; renderers in place of data/links.json.

(require json racket/match
         (only-in "lib/walk.rkt" walk-page graph-of)
         (only-in "lib/graph.rkt" current-graph)
         (only-in "lib/cite.rkt" csl-fields))

(define (message-of thunk) (with-handlers ([exn:fail? exn-message]) (thunk) #f))
(define link-a (build-path "tests" "essays" "link-a" "link-a.html.pm"))
(define link-b (build-path "tests" "essays" "link-b" "link-b.html.pm"))
(define cites-fixture (build-path "tests" "citations.html.pm"))
(define (walked url src)
  (define-values (post links cites terms changes) (walk-page url src (get-doc src)))
  (list url post links cites terms changes))
;; through JSON and back, as validate.rkt writes it and lib/graph.rkt reads it
(define fixture-graph
  (string->jsexpr (jsexpr->string (graph-of (list (walked "/link-a" link-a) (walked "/link-b" link-b)
                                                  (walked "/citations" cites-fixture))))))
(define (in-graph thunk) (parameterize ([current-graph fixture-graph]) (thunk)))
(define (hrefs x) (map (λ (a) (attr-ref a 'href)) (find-all x (λ (e) (and (eq? (get-tag e) 'a) (attrs-have-key? e 'href))))))
(define (by-class x c) (findf (λ (e) (has-class* e c)) (find-all x txexpr?)))

(test-case "BIB-9: a ◊cite with a body is the words in quotation marks, then its circle, the mark after the punctuation"
  (define doc (fixture "citations.html.pm"))
  (define p (findf (λ (x) (regexp-match? #rx"made up" (text x))) (find-all doc (tag? 'p))))
  ;; double marks outside, single inside (TYPE-16); emphasis kept
  (check-regexp-match #rx"“made up, with ‘kinds’ of people”\\." (text p))
  (check-not-false (findf (λ (e) (equal? (get-elements e) '("people"))) (find-all p (tag? 'em))))
  ;; MARK-3a: the closing mark and the full stop sit between the last word and the circle
  (define nw (findf (λ (x) (and (has-class* x "nw") (by-class x "circle"))) (find-all p txexpr?)))
  (check-regexp-match #rx"^”\\." (text nw))
  (check-equal? (attr-ref (by-class nw "circle-link") 'aria-label) "reference 6")
  ;; the note carries the quotation for the graph, and the locator written out for the card
  (define n6 (by-id doc "note-6"))
  (check-equal? (attr-ref n6 'data-quote) "made up, with ‘kinds’ of people")
  (check-regexp-match #px"^Page[  ]23$" (attr-ref n6 'data-loc))
  (check-false (attrs-have-key? n6 'data-block))
  ;; #:block #t: set as ◊blockquote is, the attribution written from the entry, the circle at its end
  (define bq (findf (λ (x) (has-class* x "quote")) (find-all doc (tag? 'blockquote))))
  (define footer (car (find-all bq (tag? 'footer))))
  ;; the author, a line break, then the title (2026-11-04); the locator is in the card (BIB-8)
  (check-regexp-match #px"^Ian Hacking[^\n]*The Social Construction of What\\?" (text footer))
  (check-equal? (length (find-all footer (tag? 'br))) 1)
  (check-false (regexp-match? #rx"31" (text footer)))
  ;; MARK-3 binds the circle to the title's last word, so the em is in two parts
  (check-equal? (apply string-append (map text (find-all footer (tag? 'em)))) "The Social Construction of What?")
  (check-equal? (attr-ref (by-class footer "circle-link") 'aria-label) "reference 7")
  (define n7 (by-id doc "note-7"))
  (check-equal? (attr-ref n7 'data-quote) "A quoted passage, set as a block.")
  (check-true (attrs-have-key? n7 'data-block)))

(test-case "BIB-9: #:source replaces the written attribution; #:italic flips a block as ◊blockquote's does"
  (define doc (root "Before." "\n\n" (cite "hackingMakingPeople2006" #:loc "p. 23" #:block #t #:source "As he put it" #:italic #t "Quoted.")))
  (define bq (car (find-all doc (tag? 'blockquote))))
  (check-equal? (attr-ref bq 'class) "quote italic")
  (check-regexp-match #rx"^As he put it" (text (car (find-all bq (tag? 'footer))))))

(test-case "BIB-9: what a quotation may not hold, and a block's keywords without a body, fail naming the rule"
  (for ([bad (list (λ () (cite "hackingMakingPeople2006" " "))
                   (λ () (cite "hackingMakingPeople2006" "a " (cite "hackingMakingPeople2006")))
                   (λ () (cite "hackingMakingPeople2006" "a " (term "occurrent" "b")))
                   (λ () (cite "hackingMakingPeople2006" "a " (aside "b")))
                   (λ () (cite "hackingMakingPeople2006" "a " (link "/x" "b")))
                   (λ () (cite "hackingMakingPeople2006" "a " (margin "b")))
                   (λ () (cite "hackingMakingPeople2006" #:block #t))
                   (λ () (cite "hackingMakingPeople2006" #:italic #t))
                   (λ () (cite "hackingMakingPeople2006" #:source "S"))
                   (λ () (cite "hackingMakingPeople2006" #:source "S" "inline words")))])
    (check-regexp-match #rx"BIB-9" (or (message-of bad) "did not fail")))
  ;; ◊em and ◊sc are allowed; the withdrawn keywords are gone
  (check-false (message-of (λ () (cite "hackingMakingPeople2006" (em "a") " " (sc "B")))))
  (check-not-false (message-of (λ () (blockquote #:cite "hackingMakingPeople2006" "x")))))

(test-case "BIB-8: the locator as the card prints it"
  (check-equal? (map (λ (l) (regexp-replace* #rx" " (locator-label l) " ")) '("p. 325" "pp. 31-34" "ch. 3" "§ 4" "fol. 2r"))
                '("Page 325" "Pages 31–34" "Chapter 3" "Section 4" "fol. 2r")))

(test-case "VAL-4, BIB-6: one walk records links, citations with their quotations, terms and changes"
  (define (part k) (hash-ref fixture-graph k))
  ;; a link to B's section from A's opening paragraph, its context marked
  (match-define (list l) (hash-ref (part 'links) '/link-b))
  (check-equal? (hash-ref l 'from) "/link-a")
  (check-equal? (hash-ref l 'id) "second")
  (check-equal? (hash-ref l 'section) 'null)
  (check-regexp-match #rx"graph-here" (jsexpr->string (hash-ref l 'context)))
  ;; A's link to its own section is not in the graph
  (check-equal? (map (λ (l) (hash-ref l 'from)) (hash-ref (part 'links) '/link-a)) '("/link-b"))
  (check-equal? (hash-ref (car (hash-ref (part 'links) '/link-a)) 'section) "second")
  ;; every citation, quoting or not, with its context; its circles marked
  (define mp (hash-ref (part 'cites) 'hackingMakingPeople2006))
  (check-equal? (remove-duplicates (map (λ (c) (hash-ref c 'from)) mp)) '("/link-a" "/link-b" "/citations"))
  (check-true (for/and ([c (in-list mp)]) (regexp-match? #rx"graph-circle" (jsexpr->string (hash-ref c 'context)))))
  (check-false (hash-ref fixture-graph 'quotes #f))   ; no separate quotation records
  ;; a quotation is a citation record with its text (BIB-9)
  (define qt (findf (λ (c) (string? (hash-ref c 'text))) mp))
  (check-equal? (hash-ref qt 'text) "made up, with ‘kinds’ of people")
  (check-equal? (hash-ref qt 'note) 6)
  (check-false (hash-ref qt 'block))
  (define doc (fixture "citations.html.pm"))
  (check-not-false (member "note-6" (string-split (attr-ref (by-id doc (hash-ref qt 'mark)) 'data-targets))))
  (define sc (hash-ref (part 'cites) 'hackingSocialConstructionWhat2000))
  (check-equal? (filter string? (map (λ (c) (hash-ref c 'text)) sc)) '("A quoted passage, set as a block."))
  (check-true (hash-ref (findf (λ (c) (string? (hash-ref c 'text))) sc) 'block))
  ;; citations inside asides point at the circle that opens the aside
  (check-true (for/and ([c (in-list sc)]) (string? (hash-ref c 'mark))))
  ;; citations in one paragraph share it
  (define cfix (filter (λ (c) (equal? (hash-ref c 'from) "/citations")) mp))
  (check-true (for/and ([c (in-list cfix)]) (exact-nonnegative-integer? (hash-ref c 'para))))
  ;; TERM-8: the terms a page marks
  (check-not-false (member "looping-effect" (map (λ (u) (hash-ref u 'id)) (hash-ref (part 'terms) '/citations))))
  ;; REV-3
  (check-equal? (map (λ (c) (list (hash-ref c 'from) (hash-ref c 'date))) (part 'changes)) '(("/link-a" "2026-10-05"))))

;; An essay at essays/<slug>/, rendered with the fixture graph.
(define (as-post slug thunk #:kind [kind "essays"])
  (in-graph
   (λ () (parameterize ([current-metas (hasheq 'title "T" 'status "published" 'published "2026-10-03"
                                               'here-path (path->string (build-path (current-directory) kind slug (string-append slug ".html.pm"))))])
           (thunk)))))

(test-case "VAL-4, CITE-10: Backlinks between Bibliography and Changelog; the linking post and section, the context expandable"
  (define doc (as-post "link-a" (λ () (root "Text" (cite "hackingMakingPeople2006" #:loc "p. 24") "." "\n\n"
                                            (changelog "2026-10-05: Added a section.")))))
  (check-equal? (map (λ (s) (attr-ref s 'id)) (find-all doc (λ (x) (equal? (attr-ref x 'class #f) "endmatter"))))
                '("notes" "bibliography" "backlinks" "changelog"))
  (define bl (by-id doc "backlinks"))
  (check-equal? (length (find-all bl (λ (x) (has-class* x "context-entry")))) 1)
  (check-not-false (member "/link-b" (hrefs bl)))
  (check-not-false (member "/link-b#second" (hrefs bl)))
  (check-regexp-match #rx"B answers" (text bl))
  (check-regexp-match #rx"essay" (text (by-class bl "kind")))
  ;; REV-3: the changelog line, dated
  (check-regexp-match #rx"5 October 2026 Added a section\\." (text (by-id doc "changelog")))
  ;; a page nothing links to has no Backlinks
  (define lone (as-post "nowhere" (λ () (root "Text."))))
  (check-false (by-id lone "backlinks")))

(test-case "REV-3: ◊changelog lines start with their date; an entry has none"
  (check-equal? (map (λ (c) (attr-ref c 'date)) (get-elements (changelog "2026-10-05: One." "\n" "2026-11-01: Two.")))
                '("2026-10-05" "2026-11-01"))
  (check-regexp-match #rx"REV-3" (message-of (λ () (changelog "Undated line."))))
  (check-regexp-match #rx"KIND-2"
                      (message-of (λ () (as-post "e" #:kind "blog" (λ () (root "Text." "\n\n" (changelog "2026-10-05: x."))))))))

(test-case "REV-3: /changelog lists every line on the site, newest first, each with its post"
  (define l (in-graph changelog-list))
  (check-equal? (length (find-all l (tag? 'li))) 1)
  (check-not-false (member "/link-a" (hrefs l))))

(test-case "BIB-1, BIB-9: a work's page: the head, then one Cited in, by post in index order, then by position"
  (define page (in-graph (λ () (reference-page "hackingMakingPeople2006"))))
  (check-equal? (map (λ (x) (or (attr-ref x 'id #f) (attr-ref x 'class #f))) (get-elements page))
                '("ref-head" "cited-in"))
  (check-false (by-id page "quoted"))
  (check-false (by-class page "ref-entry"))            ; no Chicago entry on the page
  (define cited (by-id page "cited-in"))
  (check-equal? (map (λ (li) (attr-ref li 'data-post)) (find-all cited (λ (x) (has-class* x "cited-post"))))
                '("/link-b" "/link-a" "/citations"))
  ;; a quotation: its locator, the passage in full, a → to its mark
  (define q (findf (λ (x) (has-class* x "quoted")) (find-all cited txexpr?)))
  (check-regexp-match #px"^Page[  ]23 “made up, with ‘kinds’ of people”" (text q))
  (check-not-false (findf (λ (h) (regexp-match? #rx"^/citations#ref-" h)) (hrefs q)))
  ;; a bare citation: its context, clamped, then one link to its mark, its locator or note as the text
  (check-not-false (findf (λ (x) (and (has-class* x "context-entry") (by-class x "cite-marks"))) (find-all cited txexpr?))))

(test-case "BIB-9: citations sharing a paragraph are one entry; a bare citation has no link of its own, a located one links by its locator"
  (define cited (in-graph (λ () (by-id (reference-page "hackingLoopingEffectsHuman1996") "cited-in"))))
  (define entries (find-all cited (λ (x) (has-class* x "cite-entry"))))
  (define shared (findf (λ (e) (regexp-match? #rx"Twice in one paragraph" (text e))) entries))
  (check-not-false shared)
  (check-equal? (length (filter (λ (e) (regexp-match? #rx"Twice in one paragraph" (text e))) entries)) 1)
  (check-equal? (length (find-all shared (λ (x) (has-class* x "to-mark")))) 0)   ; both bare
  ;; the post is named plain, never a link (its sections are the links)
  (define post (findf (λ (x) (has-class* x "context-from")) (find-all cited txexpr?)))
  (check-equal? (hrefs post) null))

(test-case "BIB-8: one function builds the page's head and the card, both fields, no Chicago entry"
  (define head (in-graph (λ () (car (get-elements (reference-page "hackingMakingPeople2006"))))))
  (define card (in-graph (λ () (reference-card "hackingMakingPeople2006"))))
  (check-not-false (has-class* card "ref-card"))
  (check-equal? (by-class card "ref-fields") (by-class head "ref-fields"))
  (check-false (by-class card "ref-entry"))
  (check-equal? (text (by-class card "ref-title")) "Making Up People")
  (check-regexp-match #rx"Cited in 3 posts" (text (by-class card "ref-cited")))
  (check-not-false (member "/references/hackingMakingPeople2006" (hrefs card)))
  ;; the page's head has no title of its own (the page's is the h1) and no "Cited in" line
  (check-false (by-class head "ref-title"))
  (check-false (by-class head "ref-cited")))

(test-case "BIB-10: a book, an article and a chapter give exactly their fields, in order, the empty ones absent"
  (define csl (string->jsexpr (file->string "tests/refs/fixture-csl.json")))
  (define (fields key)
    (for/list ([f (in-list (csl-fields (hash-ref csl key)))])
      (list (car f) (regexp-replace* #rx"⁠| \\(external link\\)" (text (txexpr 'dd null (cadr f))) ""))))
  (check-equal? (fields 'withCover2001) '(("Author" "Ann Author") ("Publisher" "Press") ("Year" "2001")))
  (check-equal? (fields 'anArticle2010)
                '(("Author" "Wes Writer") ("Journal" "Journal of Things") ("Volume" "12") ("Issue" "3")
                  ("Pages" "100-120") ("Year" "2010") ("DOI" "10.2000/abc")))
  (check-equal? (fields 'aChapter2005)
                '(("Author" "Cal Contributor") ("In" "The Collected Book") ("Editors" "Eda Editor and Sam Second")
                  ("Publisher" "University Press") ("Place" "Oxford") ("Year" "2005") ("Pages" "11-29")
                  ("DOI" "10.1000/xyz123")))
  ;; the container is italic; the DOI links to doi.org
  (check-equal? (get-tag (car (cadr (cadr (csl-fields (hash-ref csl 'aChapter2005)))))) 'em)
  (check-not-false (member "https://doi.org/10.2000/abc"
                           (hrefs (txexpr 'dd null (cadr (last (csl-fields (hash-ref csl 'anArticle2010)))))))))

(test-case "BIB-7: a cover is at the right of the title, lazy, licence cover; covers only there"
  (define card (in-graph (λ () (reference-card "pirsigZenArtMotorcycle1991"))))
  (define pic (by-class card "cover"))
  (check-not-false pic "no cover: run `make refresh` with the Zotero export, then `make`")
  (check-equal? (car (get-elements card)) pic)    ; first, floated right of the title (CSS)
  (define img (car (find-all pic (tag? 'img))))
  (check-regexp-match #rx"^Cover of Zen and the Art of Motorcycle Maintenance" (attr-ref img 'alt))
  (check-equal? (attr-ref img 'loading) "lazy")
  (check-equal? (attr-ref pic 'data-licence) "cover")
  ;; never in the bibliography (BIB-4)
  (check-false (by-class (in-graph bibliography-table) "cover"))
  ;; IMG-6: an author cannot use the licence
  (check-regexp-match #rx"BIB-7" (message-of (λ () (figure "img/x.jpg" #:id "x" #:title "X" #:alt "x" #:licence "cover")))))

(test-case "BIB-5: each note and each Bibliography entry links to the work's page"
  (define doc (fixture "citations.html.pm"))
  (check-not-false (member "/references/hackingMakingPeople2006" (hrefs (by-id doc "note-1"))))
  (check-not-false (member "/references/hackingLoopingEffectsHuman1996" (hrefs (by-id doc "bib-hackingLoopingEffectsHuman1996")))))

(test-case "TERM-8: the glossary page: every term by headword, see-also within the page, Used in"
  (define g (in-graph glossary-list))
  (define entries (find-all g (λ (x) (has-class* x "glossary-entry"))))
  (check-equal? (map (λ (e) (attr-ref e 'id)) entries) '("continuant" "looping-effect" "occurrent"))
  (define looping (by-id g "looping-effect"))
  (check-not-false (member "/citations" (hrefs (by-class looping "used-in"))))
  ;; see-also and terms inside definitions are links within the page
  (check-true (for/and ([l (in-list (find-all g (tag? 'od-link)))]) (regexp-match? #rx"^#" (attr-ref l 'href)))))

(test-case "BIB-4: the bibliography is one table: Author · Year · Title · Type · Cited in"
  (define t (in-graph bibliography-table))
  (check-equal? (map text (find-all (car (find-all t (tag? 'thead))) (tag? 'th))) '("Author" "Year" "Title" "Type" "Cited in"))
  (define rows (find-all (car (find-all t (tag? 'tbody))) (tag? 'tr)))
  (check-true (for/and ([r (in-list rows)]) (= 5 (length (find-all r (tag? 'td))))))
  (define mp (findf (λ (r) (member "/references/hackingMakingPeople2006" (hrefs r))) rows))
  (check-equal? (text (last (find-all mp (tag? 'td)))) "3")
  ;; by author, then year
  (check-equal? (map (λ (r) (text (car (find-all r (tag? 'td))))) rows) (sort (map (λ (r) (text (car (find-all r (tag? 'td))))) rows) string-ci<?)))

(test-case "NAV-1: Glossary and Bibliography join the menu, in order"
  (define here (hasheq 'here-path (path->string (build-path (current-directory) "pages/index.html.pm"))))
  (check-regexp-match #rx">Home<.*>Essays<.*>Blog<.*>Glossary<.*>Bibliography<" (site-menu here)))

(test-case "BIB-3, BIB-8: a commentary: paragraphs on the page, the first in the card; anything else fails"
  (define dir (build-path "references"))
  (define made-dir? (not (directory-exists? dir)))
  (define f (build-path dir "hackingSocialConstructionWhat2000.pm"))
  (dynamic-wind
   (λ () (make-directory* dir)
         (call-with-output-file f #:exists 'replace
           (λ (o) (write-string "#lang pollen\n\nThe first paragraph stands on its own, with ◊em{emphasis} and a\n◊term[\"occurrent\"]{term}.\n\nA second cites ◊cite[\"hackingLoopingEffectsHuman1996\"].\n" o))))
   (λ ()
     (define page (in-graph (λ () (reference-page "hackingSocialConstructionWhat2000"))))
     (define com (by-class page "commentary"))
     (check-equal? (length (find-all com (tag? 'p))) 2)
     ;; CITE-7: its citations are unnumbered
     (check-true (for/and ([c (in-list (find-all com (tag? 'od-cite)))]) (attrs-have-key? c 'unnumbered)))
     ;; the card has the first paragraph only, resolved for a fragment
     (define card (in-graph (λ () (reference-card "hackingSocialConstructionWhat2000"))))
     (check-regexp-match #rx"stands on its own" (text card))
     (check-false (regexp-match? #rx"A second" (text card)))
     (check-equal? (find-all card (λ (x) (memq (get-tag x) '(od-term od-cite od-link)))) '()))
   (λ () (delete-file f) (when made-dir? (delete-directory/files dir))))
  ;; headings (and the rest) are refused, and so is a key no page cites
  (define (as-commentary key thunk)
    (parameterize ([current-metas (hasheq 'here-path (path->string (build-path (current-directory) "references" (string-append key ".pm"))))])
      (thunk)))
  (check-regexp-match #rx"BIB-3" (message-of (λ () (as-commentary "hackingMakingPeople2006" (λ () (root (section #:id "a" "A") "\n\n" "Text."))))))
  (check-regexp-match #rx"BIB-3" (message-of (λ () (as-commentary "noSuchWork1999" (λ () (root "Text.")))))))

;; ---------------------------------------------------------------------------
;; Phase 3c: the glossary

(require (only-in "lib/glossary.rkt" current-glossary-dir term-ref))

(test-case "TERM-2, D18: the first paragraph is the definition, the rest of the file the More"
  (parameterize ([current-glossary-dir (path->complete-path (build-path "tests" "glossary"))])
    (define three (term-ref "three-paragraphs"))
    (check-equal? (text (txexpr 'p null (hash-ref three 'definition))) "The definition, in one paragraph.")
    (check-equal? (map text (hash-ref three 'more))
                  '("The first paragraph of the More." "The second paragraph of the More."))
    (check-false (hash-ref (term-ref "one-paragraph") 'more)))
  ;; the site's own terms are back after the fixture folder
  (check-not-false (term-ref "occurrent"))
  (check-equal? (length (hash-ref (term-ref "occurrent") 'more)) 1)   ; unwrapped from ◊more
  ;; ◊more is gone
  (check-true (fails? (λ () (eval '(more "x") (module->namespace (string->path (path->string (build-path (current-directory) "pollen.rkt")))))))))

(test-case "TERM-2: a definition holds paragraphs only"
  (define (as-term thunk)
    (parameterize ([current-metas (hasheq 'here-path (path->string (build-path (current-directory) "glossary" "x.pm")))])
      (thunk)))
  (for ([bad (list (λ () (root (od-list "- a" "\n" "- b")))
                   (λ () (root "Text" (aside "a") "."))
                   (λ () (root (margin "a") "Text."))
                   (λ () (root (table #:id "t" #:title "T" "| a |" "\n" "|---|" "\n" "| 1 |" "\n"))))])
    (check-regexp-match #rx"TERM-2" (or (message-of (λ () (as-term bad))) "did not fail"))))

(test-case "TERM-9: ◊sense is lifted out of the text into the Terms entry, labelled by kind"
  (define doc (as-post "sensed" (λ () (root "A " (term "occurrent" "occurrent " (sense "here, a " (em "process") " " (cite "hackingMakingPeople2006" #:loc "p. 23"))) " word."))))
  (define p (car (find-all doc (tag? 'p))))
  (check-false (regexp-match? #rx"here, a" (text p)))   ; not in the running text
  (define entry (by-id doc "term-occurrent"))
  (define sn (by-class entry "term-sense"))
  (check-regexp-match #rx"^In this essay: here, a process" (text sn))
  ;; between the definition and the More
  (check-equal? (map (λ (x) (attr-ref x 'class #f)) (filter txexpr? (get-elements entry)))
                '("definition" "term-sense" "term-more" "see-also"))
  ;; a citation in a sense is numbered like any other
  (check-not-false (by-id doc "note-1"))
  (define entry-doc (as-post "e" #:kind "blog" (λ () (root "A " (term "occurrent" "occurrent" (sense "noted")) "."))))
  (check-regexp-match #rx"^In this entry:" (text (by-class (by-id entry-doc "term-occurrent") "term-sense"))))

(test-case "TERM-9: one sense per term per page, at its first use, inside a ◊term only"
  (check-regexp-match #rx"TERM-9" (message-of (λ () (as-post "x" (λ () (root "A " (sense "loose") "."))))))
  (check-regexp-match #rx"TERM-9" (message-of (λ () (as-post "x" (λ () (root "A " (term "occurrent" "o") " and " (term "occurrent" #:mark #t "o" (sense "late")) "."))))))
  (check-regexp-match #rx"TERM-9" (message-of (λ () (term "occurrent" "o" (sense "a") (sense "b")))))
  (check-regexp-match #rx"TERM-9" (message-of (λ () (sense "with " (term "continuant" "a term")))))
  (check-regexp-match #rx"TERM-9" (message-of (λ () (sense "one" "\n" "\n" "two"))))
  ;; a page without a sense renders as before
  (check-false (by-class (as-post "y" (λ () (root "A " (term "occurrent" "occurrent") "."))) "term-sense")))

(test-case "TERM-8, TERM-9: Used in is a list of the term's backlinks, each with the post's sense"
  (define g (in-graph glossary-list))
  (define used (by-class (by-id g "occurrent") "used-in"))
  (check-equal? (get-tag used) 'ul)
  (define a (findf (λ (li) (member "/link-a" (hrefs li))) (find-all used (tag? 'li))))
  (check-not-false a)
  (define sn (by-class a "sense"))
  (check-equal? (text sn) "the fixture’s own sense, with emphasis")
  (check-not-false (findf (λ (e) (equal? (get-elements e) '("emphasis"))) (find-all sn (tag? 'em)))))

(test-case "CITE-10, TERM-8: a page with no end matter; its unnumbered circles go to the work's page"
  (define doc (parameterize ([current-metas (hasheq 'title "Glossary" 'endmatter "none"
                                                    'here-path (path->string (build-path (current-directory) "pages" "glossary.html.pm")))])
                (root (in-graph glossary-list))))
  (check-equal? (find-all doc (λ (x) (has-class* x "endmatter"))) '())
  (define circle (findf (λ (x) (has-class* x "circle-link")) (find-all doc txexpr?)))
  (check-equal? (attr-ref circle 'href) "/references/hackingLoopingEffectsHuman1996"))

(test-case "LAYOUT-4, LAYOUT-4a: ◊break{} is the glyph and ◊rule{} the hairline; text in ◊rule fails"
  (check-equal? (attr-ref (break) 'class) "break")
  (check-equal? (attr-ref (rule) 'class) "break rule")
  (check-equal? (attr-ref (rule "  \n") 'class) "break rule")
  (check-regexp-match #rx"no text" (or (message-of (λ () (rule "words"))) "did not fail")))
