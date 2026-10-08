#lang racket/base
;; Tests for the root pass: paragraphs and line breaks (SRC-3), the section
;; tree (SECT-1…6), the table of contents (TOC-1) and the intro paragraph.

(require rackunit
         racket/list
         txexpr
         "pollen.rkt")

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
