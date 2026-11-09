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
         "util.rkt")

(provide m math-source lift-display-maths math? math-display?)

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
  (unless (boolean? display)
    (build-error "◊m's #:display is #t or #f (got ~s)" display))
  (unless (andmap string? xs)
    (build-error "◊m takes TeX source only, with no tags inside it; for braces that do not balance write ◊m|{ … }| (MATH-1)"))
  (define tex (math-source xs))
  (when (equal? tex "") (build-error "◊m is empty: write the TeX source between the braces (MATH-1)"))
  (define form (if display 'display 'inline))
  (define entry (hash-ref (the-cache) (string->symbol (bytes->hex-string (sha256-bytes (string->bytes/utf-8 tex)))) #f))
  (define r (and entry (equal? (hash-ref entry 'tex #f) tex) (hash-ref entry form #f)))
  (unless r
    (build-error "◊m~a{~a} is not in data/math-cache.json; run `make refresh` (MATH-1)"
                 (if display "[#:display #t]" "") tex))
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

(define (math? x) (and (txexpr? x) (eq? (get-tag x) 'svg) (has-class? x "math")))
(define (math-display? x) (and (txexpr? x) (eq? (get-tag x) 'span) (has-class? x "math-display")))

(define (blank? x) (and (string? x) (regexp-match? #px"^\\s*$" x)))
(define trailing #px"^[.,;:!?…)\\]’”]+")

;; Two passes over the finished page:
;; - a paragraph that holds nothing but one display expression becomes the
;;   expression's own block, so it is spaced as a block, evenly above and
;;   below, rather than as a paragraph holding a block. Inside a paragraph
;;   (text before or after it) it stays a span set as a block (CSS).
;; - punctuation straight after an inline expression stays on its line.
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
                   [(list* (? math? s) (? string? t) rest)
                    #:when (regexp-match? trailing t)
                    (define p (car (regexp-match trailing t)))
                    (define after (substring t (string-length p)))
                    (list* `(span ((class "nw")) ,s ,p)
                           (loop (if (equal? after "") rest (cons after rest))))]
                   [(cons e rest) (cons e (loop rest))]
                   ['() '()])))]
      [else x])))
