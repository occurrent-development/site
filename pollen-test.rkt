#lang racket/base
;; Tests for the root pass: paragraphs and line breaks (SRC-3), the section
;; tree (SECT-1…6), the table of contents (TOC-1) and the intro paragraph.

(require rackunit
         racket/list
         txexpr
         (except-in "pollen.rkt" list))

(define (fails? thunk) (with-handlers ([exn:fail? (λ (e) #t)]) (thunk) #f))

(define (find-all tx pred)
  (let walk ([x tx])
    (if (txexpr? x)
        (append (if (pred x) (list x) null) (append-map walk (get-elements x)))
        null)))

(define (tag? t) (λ (x) (eq? (get-tag x) t)))

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
  (define refs (find-all doc (λ (x) (and (eq? (get-tag x) 'sup) (equal? (attr-ref x 'class #f) "note-ref")))))
  ;; the hidden inline copies of the asides repeat their numerals without ids
  (check-equal? (remove-duplicates (map text refs)) '("1" "2" "3" "4" "5"))
  (define notes (find-all (by-id doc "notes") (tag? 'li)))
  (check-equal? (length notes) 5)                       ; not double-counted (CITE-2)
  (define (note n) (regexp-replace* #rx"\u00A0" (text (by-id doc (format "note-~a" n))) " "))
  ;; CITE-3: full form first, short form after, each with its own locator
  (check-regexp-match #rx"^Ian Hacking, “Making Up People,” London Review of Books 28, no. 16 \\(2006\\): 23\\." (note 1))
  (check-regexp-match #rx"^Ian Hacking, The Social Construction of What\\? \\(Harvard" (note 2))  ; inside aside i
  (check-regexp-match #rx"^Hacking, “Making Up People,” 24\\." (note 3))                         ; inside aside i
  (check-regexp-match #rx"^Hacking, The Social Construction of What\\?, 31–34\\." (note 4))       ; body
  (check-regexp-match #rx"^Hacking, “Making Up People\\.” With a remark\\." (note 5))
  ;; CITE-4: back-links; a numeral inside an aside resolves to the aside's end copy
  (define backs (find-all (by-id doc "notes") (λ (x) (equal? (attr-ref x 'class #f) "back"))))
  (check-equal? (map (λ (a) (attr-ref a 'href)) backs) '("#nref-1" "#nref-2" "#nref-3" "#nref-4" "#nref-5"))
  (check-not-false (findf (λ (x) (equal? (attr-ref x 'id #f) "nref-2")) (find-all (by-id doc "asides") txexpr?)))
  ;; CITE-7: the definition's citation is unnumbered and reaches the bibliography
  (define terms (by-id doc "terms"))
  (check-not-false (findf (λ (x) (equal? (attr-ref x 'href #f) "#bib-hackingLoopingEffectsHuman1996")) (find-all terms txexpr?)))
  (check-equal? (map (λ (li) (attr-ref li 'id)) (find-all (by-id doc "bibliography") (tag? 'li)))
                '("bib-hackingMakingPeople2006" "bib-hackingLoopingEffectsHuman1996" "bib-hackingSocialConstructionWhat2000"))
  ;; CITE-10: end matter order
  (check-equal? (map (λ (s) (attr-ref s 'id)) (find-all doc (λ (x) (equal? (attr-ref x 'class #f) "endmatter"))))
                '("terms" "asides" "notes" "bibliography")))

(define (classes x) (if (attrs-have-key? x 'class) (attr-ref x 'class) ""))
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
  (check-equal? (length (filter (λ (c) (equal? c "mark m-term")) (marks-in body))) 2)
  (check-not-false (by-id doc "term-occurrent"))
  (check-not-false (by-id doc "term-continuant"))   ; reached through the definition (TERM-7)
  (check-true (fails? (λ () (root (term "no-such-term" "x"))))))

(test-case "MNOTE-3/5: margin notes open a paragraph and hold no annotations"
  (define doc (root (margin "Gloss.") " Text."))
  (check-equal? (car (get-elements (car (get-elements doc)))) '(span ((class "margin-note")) "Gloss."))
  (check-true (fails? (λ () (root "Text " (margin "late")))))
  (check-true (fails? (λ () (root (margin (link "https://example.org" "x")) " Text."))))
  (check-true (fails? (λ () (root "x" (aside "nested " (aside "no")))))))

(test-case "TABLE-1/5/6: semantic tables, wrong cell counts fail"
  (define t (table #:caption "C" "\n" "| a | b |" "\n" "|---|---|" "\n"
                   "| 1 | x |" "\n" "| 2 | y |" "\n" "| 3 | z |" "\n" "| 4 | w |" "\n" "| 5 | v |" "\n"))
  (check-not-false (findf (λ (x) (attrs-have-key? x 'data-sortable)) (find-all t (tag? 'table))))
  (check-equal? (length (find-all t (λ (x) (equal? (attr-ref x 'scope #f) "col")))) 2)
  (check-equal? (classes (car (find-all t (tag? 'td)))) "a-right")
  (check-true (fails? (λ () (table "| a | b |" "\n" "|---|---|" "\n" "| 1 |" "\n")))))

(test-case "IMG-3/6: figures need alt text and a licence"
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:licence "own" "c"))))
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:alt "a" "c"))))
  (check-true (fails? (λ () (figure "pages/img/landscape.jpg" #:alt "a" #:licence "cc-by-4.0" "c")))))
