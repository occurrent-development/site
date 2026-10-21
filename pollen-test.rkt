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
  ;; CITE-1: no numerals in the text; circles open notes 1–5 in reading order
  (check-equal? (filter (λ (t) (regexp-match? #rx"^note-" t)) (remove-duplicates (append-map targets openers)))
                '("note-1" "note-2" "note-3" "note-4" "note-5"))
  (check-equal? (find-all doc (tag? 'sup)) '())
  (define notes (find-all (by-id doc "notes") (tag? 'li)))
  (check-equal? (length notes) 5)                       ; not double-counted (CITE-2)
  (define (note n) (regexp-replace* #rx"\u00A0" (text (by-id doc (format "note-~a" n))) " "))
  ;; CITE-3: full form first, short form after, each with its own locator
  (check-regexp-match #rx"^Ian Hacking, “Making Up People,” London Review of Books 28, no. 16 \\(2006\\): 23\\." (note 1))
  (check-regexp-match #rx"^Ian Hacking, The Social Construction of What\\? \\(Harvard" (note 2))  ; inside the first aside
  (check-regexp-match #rx"^Hacking, “Making Up People,” 24\\." (note 3))                           ; inside the first aside
  (check-regexp-match #rx"^Hacking, The Social Construction of What\\?, 31–34\\." (note 4))         ; body
  (check-regexp-match #rx"^Hacking, “Making Up People\\.” With a remark\\." (note 5))
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
  (check-equal? (attr-ref (car openers) 'aria-label) "note 1, note 2")
  (check-equal? (attr-ref (cadr openers) 'aria-label) "definition, note 3")
  ;; D8: without JS a shared circle links to its first item
  (check-equal? (attr-ref (car openers) 'href) "#note-1")
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
  (define nw (find-all doc (λ (x) (has-class* x "nw"))))
  (check-equal? (length nw) 1)
  (check-equal? (get-tag (car (get-elements (car nw)))) 'em))

(test-case "TABLE-5: ◊sort-key gives a cell the value it sorts by"
  (define t (table #:id "t" #:title "T" "| Year | Event |" "\n" "|---|---|" "\n" "| " (sort-key "2004" "c. 2004") " | x |" "\n"))
  (check-not-false (findf (λ (x) (equal? (attr-ref x 'data-sort #f) "2004")) (find-all t txexpr?))))

(test-case "POP-7: notes say whether they are the full or the short form"
  (define doc (fixture "citations.html.pm"))
  (check-equal? (map (λ (n) (attr-ref (by-id doc (format "note-~a" n)) 'data-form)) '(1 2 3 4 5))
                '("full" "full" "short" "short" "short")))

(test-case "INDEX-3: tags are comma-separated lowercase words"
  (check-equal? (parse-tags "philosophy,  child development , site, site") '("philosophy" "child development" "site"))
  (check-true (fails? (λ () (parse-tags "Philosophy"))))
  (check-true (fails? (λ () (parse-tags "a;b")))))

(test-case "URLs: pages and essays are flattened to /<slug>"
  (check-equal? (output->url "index.html") "/")
  (check-equal? (output->url "pages/about.html") "/about")
  (check-equal? (output->url "essays/placeholder/placeholder.html") "/placeholder")
  ;; HOME-1: the About page is the root; D14: entries live under /notebook
  (check-equal? (output->url "pages/index.html") "/")
  (check-equal? (output->url "pages/essays.html") "/essays")
  (check-equal? (output->url "notebook/a-day/a-day.html") "/notebook/a-day"))

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
      essay-header doc-body format-date revised-date site-menu has-toc? page-class))
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
  (check-equal? (attr-ref (car (find-all header (λ (x) (has-class* x "circle-link")))) 'href) "#note-1")
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
                '("Title" "Date published" "Last review" "Tags"))
  (define body-rows (find-all (car (find-all idx (tag? 'tbody))) (tag? 'tr)))
  (check-equal? (length body-rows) 2)
  (for ([r (in-list body-rows)])
    (define cells (filter txexpr? (get-elements r)))
    (check-equal? (length cells) 4)
    (check-equal? (map get-tag cells) '(td td td td))
    (check-equal? (map classes cells) '("title" "date-col" "date-col" "tags")))
  ;; Title · Date published · Last review · Tags, in that order
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

(test-case "LAYOUT-1, 1b, 1c: the header's block, its labelled tags, and the closing rule"
  (define h (header-sample #:title "T" #:published "2026-10-01" #:revised "2026-10-15"
                           #:tags "site, typography" #:epistemic "A sample."))
  (define block (car (find-all h (λ (x) (has-class* x "header-meta")))))
  ;; dates, tags, then the epistemic status last (no source links in a sample)
  (check-equal? (map classes (get-elements block)) '("dates" "tags" "epistemic"))
  (define tags (cadr (get-elements block)))
  (check-equal? (string-trim (text (car (get-elements tags)))) "Tagged")
  (check-equal? (length (find-all tags (λ (x) (has-class* x "tag-link")))) 2)
  (check-equal? (map (λ (d) (text (car (find-all d (λ (x) (has-class* x "meta-label"))))))
                     (find-all block (λ (x) (has-class* x "date"))))
                '("Published" "Revised"))
  ;; no tags, no line; no epistemic status, no line
  (define bare (header-sample #:title "T" #:published "2026-10-01"))
  (check-equal? (map classes (get-elements (car (find-all bare (λ (x) (has-class* x "header-meta")))))) '("dates"))
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

;; §13b: the notebook. Entries are posts of the second kind, set from the folder.
(define (in-entry thunk)
  (define here (path->string (build-path (current-directory) "tests" "notebook" "x" "x.html.pm")))
  (parameterize ([current-metas (hasheq 'title "T" 'status "published" 'published "2026-10-01" 'here-path here)])
    (thunk)))

(test-case "KIND-1: the kind comes from the folder; a kind meta and a clashing slug fail"
  (check-equal? (post-kind "essays/a/a.html.pm") 'essay)
  (check-equal? (post-kind "notebook/a/a.html.pm") 'entry)
  (check-false (post-kind "pages/colophon.html.pm"))
  (check-exn #rx"kind comes from its folder"
             (λ () (parameterize ([current-metas (hasheq 'title "T" 'kind "entry")]) (root "x"))))
  (check-equal? (check-post-slugs '(("a" . "essays/a") ("b" . "notebook/b")) '("index")) '())
  (check-equal? (length (check-post-slugs '(("a" . "essays/a") ("a" . "notebook/a")) '())) 1)
  (check-equal? (length (check-post-slugs '(("about" . "notebook/about") ("glossary" . "essays/glossary")) '())) 2)
  (check-equal? (length (check-post-slugs '(("essays" . "notebook/essays")) '("essays"))) 1)
  ;; the page wrapper says which kind, and nothing else does
  (check-equal? (page-class (hasheq 'here-path "/x/notebook/a/a.html.pm")) "page kind-entry")
  (check-equal? (page-class (hasheq 'here-path "/x/essays/a/a.html.pm")) "page"))

(test-case "KIND-2: an entry has no epistemic status; an abstract is allowed"
  (check-exn #rx"no epistemic status" (λ () (in-entry (λ () (root (epistemic "Sure.") "\n\n" "Text.")))))
  (define doc (in-entry (λ () (root (abstract "Briefly.") "\n\n" "Text."))))
  (check-not-false (findf (λ (x) (has-class* x "abstract")) (find-all doc txexpr?)))
  ;; DRAFT-2 applies to entries
  (check-false (published? "notebook/x/x.html.pm" "draft"))
  (check-true (published? "notebook/x/x.html.pm" "published")))

(test-case "KIND-3: an entry has no contents at any section count, and the essay header without the epistemic line"
  (define doc (fixture "notebook/sectioned-entry/sectioned-entry.html.pm"))
  (check-equal? (find-all doc (λ (x) (has-class* x "toc"))) '())
  (check-equal? (length (find-all doc (λ (x) (and (eq? (get-tag x) 'section) (has-class* x "level-1"))))) 3)
  (define header (car (get-elements doc)))
  (check-equal? (get-tag header) 'header)
  (define block (car (find-all header (λ (x) (has-class* x "header-meta")))))
  (check-equal? (map classes (get-elements block)) '("dates" "tags" "source"))
  (check-not-false (findf (λ (x) (has-class* x "abstract")) (find-all header txexpr?)))
  (check-not-false (has-class* (last (get-elements header)) "header-rule"))
  ;; LAYOUT-1b, KIND-4: its tags link to the notebook's index
  (check-equal? (attr-ref (car (find-all block (λ (x) (has-class* x "tag-link")))) 'href) "/notebook?tags=site")
  ;; an essay with the same sections has contents, and its tags go to /essays
  (define essay (parameterize ([current-metas (hasheq 'title "T" 'status "published" 'published "2026-10-01" 'tags "site" 'here-path (path->string (build-path (current-directory) "essays" "x" "x.html.pm")))])
                  (root (section #:id "a" "A") "\n\n" "x" "\n\n" (section #:id "b" "B") "\n\n" "y" "\n\n" (section #:id "c" "C") "\n\n" "z")))
  (check-not-false (findf (λ (x) (has-class* x "toc")) (find-all essay txexpr?)))
  (check-equal? (attr-ref (car (find-all essay (λ (x) (has-class* x "tag-link")))) 'href) "/essays?tags=site"))

(test-case "KIND-4, INDEX-1a: the notebook index has three cells in every row: Title · Date · Tags"
  (define idx (index #:kind "entry" #:pagetree "tests/index.ptree"))
  (check-equal? (map (λ (th) (string-trim (text th))) (find-all (car (find-all idx (tag? 'thead))) (tag? 'th)))
                '("Title" "Date" "Tags"))
  (define rows (find-all (car (find-all idx (tag? 'tbody))) (tag? 'tr)))
  (define cells (map (λ (r) (filter txexpr? (get-elements r))) rows))
  (check-equal? (map length cells) '(3 3 3))
  (check-equal? (map (λ (c) (string-trim (text (first c)))) cells) '("Newer entry" "A sectioned entry" "Older entry"))
  (check-equal? (map classes (first cells)) '("title" "date-col" "tags"))
  (check-equal? (attr-ref (car (find-all (second (third cells)) (tag? 'time))) 'datetime) "2026-10-03")
  (check-equal? (string-trim (text (third (third cells)))) "site, notebook")
  ;; (a fixture's URL keeps its tests/ prefix; a real entry's is /notebook/<slug>)
  (check-regexp-match #rx"/notebook/newer-entry/newer-entry$" (attr-ref (car (find-all (first (first cells)) (tag? 'a))) 'href))
  (check-not-false (attrs-have-key? (car (find-all idx (tag? 'table))) 'data-sortable))
  (check-true (fails? (λ () (index #:kind "blog" #:pagetree "tests/index.ptree")))))

(test-case "HOME-1: ◊latest lists the newest posts of both kinds, one line each"
  (define l (latest 3 #:pagetree "tests/index.ptree"))
  (define items (find-all l (tag? 'li)))
  (check-equal? (length items) 3)
  (check-equal? (map (λ (li) (text (car (find-all li (tag? 'od-link))))) items)
                '("Newer entry" "Newer" "A sectioned entry"))
  (check-regexp-match #rx"notebook · 6 October 2026" (text (first items)))
  (check-regexp-match #rx"essay · 5 October 2026" (text (second items))))

(test-case "NAV-1: Home · Essays · Notebook; an essay marks Essays, an entry Notebook"
  (define (menu here) (site-menu (hasheq 'here-path (path->string (build-path (current-directory) here)))))
  (check-regexp-match #rx">Home<.*>Essays<.*>Notebook<" (menu "pages/index.html.pm"))
  (check-regexp-match #rx"href=\"/essays\" aria-current=\"page\"" (menu "essays/placeholder/placeholder.html.pm"))
  (check-regexp-match #rx"href=\"/notebook\" aria-current=\"page\"" (menu "notebook/a/a.html.pm"))
  (check-regexp-match #rx"href=\"/\" aria-current=\"page\"" (menu "pages/index.html.pm")))
