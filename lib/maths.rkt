#lang racket/base
;; Mathematics (MATH-1). ◊m{TeX} is set by LuaLaTeX in Libertinus Math at
;; `make refresh` (tools/maths.py), never by `make` (BUILD-2) and never in
;; the reader's browser: the build inlines the cached SVG.
;;
;; The tag returns the SVG itself, so every route a piece of text takes to
;; the reader carries it unchanged: the page, an aside's hidden copy and its
;; entry under Asides, the fragments of cross-page popups, the contexts in
;; data/links.json, glossary definitions and reference cards. The SVG holds
;; plain paths and no ids, so two copies on one page never collide.

(require racket/list
         racket/match
         racket/string
         json
         file/sha1
         txexpr
         "util.rkt"
         "exhibits.rkt")

(provide m make-formula math-source lift-display-maths math? math-display?)

(define cache #f)
(define cache-stamp #f)
;; The committed cache, merged with the one that holds what only drafts use
;; (not committed, absent in CI), as the citation caches are (CITE-5a).
;; Read again when either file changes, so the project server sees what
;; `od-render-math' (make refresh-math) has just added without a restart.
(define (the-cache)
  (define files (list (project-file "data" "math-cache.json") (project-file "data" "math-cache.local.json")))
  (define stamp (for/list ([f (in-list files)]) (and (file-exists? f) (file-or-directory-modify-seconds f))))
  (unless (and cache (equal? stamp cache-stamp))
    (define (load f) (if (file-exists? f) (call-with-input-file f read-json) (hasheq)))
    (set! cache (for/fold ([c (load (car files))])
                          ([(k v) (in-hash (load (cadr files)))])
                  (hash-set c k v)))
    (set! cache-stamp stamp))
  cache)

;; The source as tools/maths.py keys it: runs of white space are one space.
(define (math-source xs)
  (string-normalize-spaces (apply string-append xs) #px"[ \t\r\n]+" " "))

(define (num x) (let ([s (number->string (exact->inexact x))]) (if (regexp-match? #rx"\\.0$" s) (substring s 0 (- (string-length s) 2)) s)))

(define (json->x j)
  (match j
    [(list* tag attrs kids)
     (txexpr (string->symbol tag)
             (for/list ([(k v) (in-hash attrs)]) (list k v))
             (map json->x kids))]
    [(? string? s) s]))

;; ◊m{…} inline; ◊m[#:display #t]{…} on its own line, centred (LAYOUT-1).
;; A body with braces that do not balance is written ◊m|{ … }|.
(define (m #:display [display #f] . xs)
  (math-element xs display "◊m"))

;; The tag's output; WHAT names the tag in a build error (◊m or ◊formula).
(define (math-element xs display what)
  (unless (boolean? display)
    (build-error "~a's #:display is #t or #f (got ~s)" what display))
  (unless (andmap string? xs)
    (build-error "~a takes TeX source only, with no tags inside it; for braces that do not balance write ~a|{ … }| (MATH-1)" what what))
  (define tex (math-source xs))
  (when (equal? tex "") (build-error "~a is empty: write the TeX source between the braces (MATH-1)" what))
  (define form (if display 'display 'inline))
  (define entry (hash-ref (the-cache) (string->symbol (bytes->hex-string (sha256-bytes (string->bytes/utf-8 tex)))) #f))
  (define r (and entry (equal? (hash-ref entry 'tex #f) tex) (hash-ref entry form #f)))
  (unless r
    (build-error "~a~a{~a} is not in data/math-cache.json; run `make refresh` (MATH-1)"
                 what (if display "[#:display #t]" "") tex))
  (define svg
    `(svg ((class "math")
           (viewBox ,(hash-ref r 'viewBox))
           (fill "currentColor")           ; IMG-5: follows the theme
           (role "img")
           (aria-label ,tex)
           (focusable "false")
           ;; sized in em, so it takes the size of the text around it (TYPE-17)
           (style ,(format "width:~aem;height:~aem;vertical-align:~aem"
                           (num (hash-ref r 'width)) (num (hash-ref r 'height)) (num (- (hash-ref r 'depth))))))
          ,@(map json->x (hash-ref r 'body))))
  (if display `(span ((class "math-display")) ,svg) svg))

;; FORMULA-1: ◊formula, a displayed expression as an exhibit, like a figure or
;; a table: "Formula 1", a title, and in the margin an optional comment and
;; source. The expression sits in a box as wide as it is, centred in the
;; column (CSS). TITLE, CAPTION and SOURCE are element lists or #f.
(define (make-formula xs #:id id #:title title #:caption caption #:source source)
  (define expr (math-element xs #t "◊formula"))
  (make-exhibit "formula" id title
                (list `(div ((class "formula-box")) ,expr))
                (or caption null)
                (or source null)
                #:class "formula"))

(define (math? x) (and (txexpr? x) (eq? (get-tag x) 'svg) (has-class? x "math")))
(define (math-display? x) (and (txexpr? x) (eq? (get-tag x) 'span) (has-class? x "math-display")))

(define (blank? x) (and (string? x) (regexp-match? #px"^\\s*$" x)))
(define trailing #px"^[.,;:!?…)\\]’”]+")
;; an opening bracket or quote straight before an inline expression goes with it
(define leading #px"[(\\[“‘«]+$")
;; the punctuation that opens STRS, if any: (values (list "…") the rest)
(define (take-trailing strs)
  (cond
    [(and (pair? strs) (string? (car strs)) (regexp-match? trailing (car strs)))
     (define p (car (regexp-match trailing (car strs))))
     (define after (substring (car strs) (string-length p)))
     (values (list p) (if (equal? after "") (cdr strs) (cons after (cdr strs))))]
    [else (values '() strs)]))

;; Two passes over the finished page:
;; - a paragraph that holds nothing but one display expression becomes the
;;   expression's own block, so it is spaced as a block, evenly above and
;;   below, rather than as a paragraph holding a block. Inside a paragraph
;;   (text before or after it) it stays a span set as a block (CSS).
;; - punctuation straight after an inline expression stays on its line, and so
;;   does an opening bracket straight before it: "(◊m{x})" never breaks.
(define (lift-display-maths doc)
  (let walk ([x doc])
    (cond
      [(and (txexpr? x) (eq? (get-tag x) 'p)
            (match (filter (λ (e) (not (blank? e))) (get-elements x))
              [(list (? math-display?)) #t]
              [_ #f]))
       (define d (findf math-display? (get-elements x)))
       (txexpr 'div (get-attrs d) (get-elements d))]
      [(txexpr? x)
       (txexpr (get-tag x) (get-attrs x)
               (let loop ([els (map walk (get-elements x))])
                 (match els
                   ;; "(", the expression and what closes it never part (MATH-1)
                   [(list* (? string? t) (? math? s) rest)
                    #:when (regexp-match? leading t)
                    (define o (car (regexp-match leading t)))
                    (define before (substring t 0 (- (string-length t) (string-length o))))
                    (define-values (tail rest*) (take-trailing rest))
                    (append (if (equal? before "") '() (list before))
                            (cons `(span ((class "nw")) ,o ,s ,@tail) (loop rest*)))]
                   [(list* (? math? s) rest)
                    #:when (let-values ([(tail r) (take-trailing rest)]) (pair? tail))
                    (define-values (tail rest*) (take-trailing rest))
                    (cons `(span ((class "nw")) ,s ,@tail) (loop rest*))]
                   [(cons e rest) (cons e (loop rest))]
                   ['() '()])))]
      [else x])))
