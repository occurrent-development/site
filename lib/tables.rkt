#lang racket/base
;; Tables (§9.2, TABLE-1…6).
;;
;; ◊table{ pipe table } and ◊table-csv["data.csv"]. Booktabs styling is in
;; CSS; this module builds semantic HTML: caption, thead, th scope, and row
;; headers on request. Numeric columns align right unless #:align says
;; otherwise. Tables with five or more body rows are marked sortable for the
;; Phase 2 script (TABLE-5).

(require racket/list
         racket/string
         racket/match
         racket/file
         txexpr
         "util.rkt"
         "exhibits.rkt")

(provide make-table table-element read-csv-table parse-pipe-table)

(define sizes '("normal" "small" "tiny"))

;; ---------------------------------------------------------------------------
;; Pipe tables

;; Split elements into lines, then each line into cells at "|".
(define (pipe-lines elems)
  (define lines '())
  (define cur '())
  (define (flush!) (set! lines (cons (reverse cur) lines)) (set! cur '()))
  (for ([e (in-list elems)])
    (if (string? e)
        (for ([p (in-list (regexp-split #rx"\n" e))] [i (in-naturals)])
          (when (> i 0) (flush!))
          (unless (equal? p "") (set! cur (cons p cur))))
        (set! cur (cons e cur))))
  (flush!)
  (filter (λ (l) (not (andmap (λ (e) (and (string? e) (regexp-match? #px"^\\s*$" e))) l)))
          (map merge-adjacent (reverse lines))))

(define (merge-adjacent line)
  (let loop ([els line])
    (match els
      [(list* (? string? a) (? string? b) rest) (loop (cons (string-append a b) rest))]
      [(cons a rest) (cons a (loop rest))]
      ['() '()])))

(define (split-cells line)
  (define cells '())
  (define cur '())
  (for ([e (in-list line)])
    (if (string? e)
        (for ([p (in-list (regexp-split #rx"\\|" e))] [i (in-naturals)])
          (when (> i 0) (set! cells (cons (reverse cur) cells)) (set! cur '()))
          (unless (equal? p "") (set! cur (cons p cur))))
        (set! cur (cons e cur))))
  (set! cells (reverse (cons (reverse cur) cells)))
  ;; drop the empty cells outside the leading and trailing pipes
  (define (empty-cell? c) (andmap (λ (e) (and (string? e) (regexp-match? #px"^\\s*$" e))) c))
  (let* ([cells (if (and (pair? cells) (empty-cell? (first cells))) (rest cells) cells)]
         [cells (if (and (pair? cells) (empty-cell? (last cells))) (drop-right cells 1) cells)])
    (map trim-cell cells)))

(define (trim-cell c)
  (define c1 (match c [(cons (? string? s) r) (cons (string-trim s #:right? #f) r)] [_ c]))
  (define c2 (match (reverse c1) [(cons (? string? s) r) (reverse (cons (string-trim s #:left? #f) r))] [_ c1]))
  (filter (λ (e) (not (equal? e ""))) c2))

(define separator-rx #px"^\\s*:?-+:?\\s*$")

;; Org's separator line (orgtbl-mode, EDIT-10): |---+---|, read as |---|---|.
(define (org-separator? line)
  (and (= (length line) 1) (string? (car line))
       (regexp-match? #px"^\\s*\\|?\\s*-[-+]*-?\\s*\\|?\\s*$" (car line))
       (regexp-match? #rx"\\+" (car line))))

;; → (values header-cells aligns body-rows)
(define (parse-pipe-table elems)
  (define rows
    (let* ([lines (pipe-lines elems)]
           ;; Org writes |---+---|: one cell to the splitter; make it one per column
           [lines (for/list ([l (in-list lines)])
                    (if (org-separator? l)
                        (let ([n (length (regexp-match* #rx"\\+" (car l)))])
                          (list (string-join (make-list (add1 n) "---") "|")))
                        l))]
           [rows (map split-cells lines)]
           [sep? (λ (r) (and (pair? r) (andmap (λ (c) (and (= (length c) 1) (string? (car c))
                                                           (regexp-match? separator-rx (car c))))
                                               r)))])
      ;; separators after the one under the header only group rows in the source
      (if (>= (length rows) 2)
          (list* (first rows) (second rows) (filter (λ (r) (not (sep? r))) (drop rows 2)))
          rows)))
  (unless (>= (length rows) 2) (build-error "table: needs a header row and a separator row"))
  (define header (first rows))
  (define sep (second rows))
  (unless (andmap (λ (c) (and (= (length c) 1) (string? (car c)) (regexp-match? separator-rx (car c)))) sep)
    (build-error "table: the second row must be the separator, like |---|---:|"))
  (define aligns
    (for/list ([c (in-list sep)])
      (define s (string-trim (car c)))
      (cond [(and (string-prefix? s ":") (string-suffix? s ":")) "center"]
            [(string-suffix? s ":") "right"]
            [(string-prefix? s ":") "left"]
            [else #f])))
  (values header aligns (drop rows 2)))

;; ---------------------------------------------------------------------------
;; CSV (RFC 4180 quoting; cells are plain text)

(define (read-csv-table path)
  (define full (if (absolute-path? path) path (build-path (source-dir) path)))
  (unless (file-exists? full) (build-error "table-csv: no file ~a" path))
  (define rows (parse-csv (file->string full)))
  (when (null? rows) (build-error "table-csv: ~a is empty" path))
  (values (map list (first rows)) (map (λ (_) #f) (first rows))
          (for/list ([r (in-list (rest rows))]) (map list r))))

(define (parse-csv text)
  (define rows '())
  (define row '())
  (define field (open-output-string))
  (define (end-field!) (set! row (cons (get-output-string field) row)) (set! field (open-output-string)))
  (define (end-row!) (end-field!) (set! rows (cons (reverse row) rows)) (set! row '()))
  (let loop ([cs (string->list text)] [quoted? #f])
    (match* (cs quoted?)
      [('() _) (unless (and (null? row) (equal? (get-output-string field) "")) (end-row!))]
      [((list* #\" #\" r) #t) (write-char #\" field) (loop r #t)]
      [((cons #\" r) #t) (loop r #f)]
      [((cons c r) #t) (write-char c field) (loop r #t)]
      [((cons #\" r) #f) (loop r #t)]
      [((cons #\, r) #f) (end-field!) (loop r #f)]
      [((list* #\return #\newline r) #f) (end-row!) (loop r #f)]
      [((cons #\newline r) #f) (end-row!) (loop r #f)]
      [((cons c r) #f) (write-char c field) (loop r #f)]))
  (filter (λ (r) (not (equal? r '("")))) (reverse rows)))

;; ---------------------------------------------------------------------------
;; Rendering

;; Numbers with separators, signs, currency, %, units and ranges.
(define numeric-rx
  #px"^[−–+-]?[$€£¥]?\\s?\\d[\\d,  ]*(\\.\\d+)?(\\s?(%|[a-zA-Zµ°]{1,4}))?(\\s?[–-]\\s?[$€£]?\\d[\\d,]*(\\.\\d+)?\\s?%?)?$")

(define (numeric-cell? c) (regexp-match? numeric-rx (string-trim (text-of c))))

(define (make-table header aligns body
                    #:id [id #f] #:title [title #f] #:caption [caption #f] #:source [source #f]
                    #:size [size "normal"] #:width [width #f]
                    #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f])
  (unless (member size sizes) (build-error "table: #:size must be one of ~a" (string-join sizes ", ")))
  (when width (build-error "table ~s: #:width is gone; every table is column width, and Expand shows it larger (IMG-2)" id))
  (make-exhibit "table" id title
                (list
                 `(div ((class "table-scroll") (tabindex "0") (role "region")
                        (aria-labelledby ,(string-append (or id "") "-title")))
                       ,(table-element header aligns body
                                       #:sortable sortable #:align align #:row-headers row-headers)))
                (or caption null)
                (or source null)
                #:class (format "table-wrap size-~a" size)))

;; The <table> itself, for every table on the site: pipe and CSV tables, and
;; the home page's index (INDEX-1a), so none can drift from the others.
;; HEADER is a list of cells and BODY a list of rows of cells, each cell a
;; list of elements. A row with the wrong number of cells fails the build
;; (TABLE-1). ROW-ATTRS gives each body row its attributes; HEAD-ATTRS and
;; COL-CLASSES give each column's heading extra attributes and each
;; column's cells a class (#f for none).
(define (table-element header aligns body
                       #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f]
                       #:class [cls #f] #:row-attrs [row-attrs #f]
                       #:head-attrs [head-attrs #f] #:col-classes [col-classes #f])
  (define ncols (length header))
  (for ([r (in-list body)] [i (in-naturals 1)])
    (unless (= (length r) ncols)
      (build-error "table: row ~a has ~a cells, the header has ~a: ~s"
                   i (length r) ncols (string-trim (text-of (apply append r))))))
  (when (and align (not (= (string-length align) ncols)))
    (build-error "table: #:align ~s needs one letter (l, c, r) per column" align))
  ;; TABLE-3: numeric columns right-aligned unless overridden
  (define col-aligns
    (for/list ([i (in-range ncols)] [a (in-list aligns)])
      (cond
        [align (case (string-ref align i) [(#\l) "left"] [(#\c) "center"] [(#\r) "right"]
                 [else (build-error "table: #:align letters are l, c and r")])]
        [a a]
        [(and (pair? body) (andmap (λ (r) (let ([c (list-ref r i)]) (or (null? c) (numeric-cell? c)))) body)
              (ormap (λ (r) (pair? (list-ref r i))) body))
         "right"]
        [else #f])))
  (define (cell-attrs i)
    (define classes (filter values (list (let ([a (list-ref col-aligns i)]) (and a (string-append "a-" a)))
                                         (and col-classes (list-ref col-classes i)))))
    (if (null? classes) null `((class ,(string-join classes)))))
  (define sortable? (if (eq? sortable 'auto) (>= (length body) 5) sortable))
  `(table ,(append (if cls `((class ,cls)) null) (if sortable? '((data-sortable "")) null))
          (thead (tr ,@(for/list ([c (in-list header)] [i (in-naturals)])
                         `(th ,(append '((scope "col")) (cell-attrs i)
                                       (if head-attrs (or (list-ref head-attrs i) null) null))
                              ,@c))))
          (tbody ,@(for/list ([r (in-list body)] [j (in-naturals)])
                     `(tr ,(if row-attrs (list-ref row-attrs j) null)
                          ,@(for/list ([c (in-list r)] [i (in-naturals)])
                              (if (and row-headers (= i 0))
                                  `(th ,(append '((scope "row")) (cell-attrs i)) ,@c)
                                  `(td ,(cell-attrs i) ,@c))))))))
