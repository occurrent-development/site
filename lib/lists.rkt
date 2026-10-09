#lang racket/base
;; Lists (§3.4, LIST-1…7).
;;
;;   - bullet            1. numbered (the digits typed are ignored)
;;
;; An item's children are indented to its content column (two spaces under
;; "- ", three under "1. "). Lines that follow an item without a blank line
;; continue its paragraph; an indented paragraph after a blank line continues
;; the item. Numbering is computed here and printed by CSS from data-n, so
;; the chain 1. / 1.1. / 1.1.1. runs only through consecutive numbered levels
;; (LIST-3). Bad indentation or an unknown marker is a build error (LIST-7).

(require racket/list
         racket/string
         racket/match
         txexpr
         "util.rkt")

(provide parse-list)

;; Split elements into lines: each line is a list of elements.
(define (lines-of elems)
  (define lines '())
  (define cur '())
  (define (flush!) (set! lines (cons (reverse cur) lines)) (set! cur '()))
  (for ([e (in-list elems)])
    (cond
      [(string? e)
       (define parts (regexp-split #rx"\n" e))
       (for ([p (in-list parts)] [i (in-naturals)])
         (when (> i 0) (flush!))
         (unless (equal? p "") (set! cur (cons p cur))))]
      [else (set! cur (cons e cur))]))
  (flush!)
  ;; Pollen's reader passes indentation as its own string: rejoin each line.
  (map merge-adjacent (reverse lines)))

(define (merge-adjacent line)
  (let loop ([els line])
    (match els
      [(list* (? string? a) (? string? b) rest) (loop (cons (string-append a b) rest))]
      [(cons a rest) (cons a (loop rest))]
      ['() '()])))

(define (blank? line) (andmap (λ (e) (and (string? e) (regexp-match? #px"^\\s*$" e))) line))

;; An item under construction.
(struct item (kind indent content-col [paras #:mutable] [children #:mutable]) #:transparent)

(define marker-rx #px"^( *)(-|\\d+\\.) (.*)$")

(define (parse-list elems #:start [start #f] #:columns [columns #f])
  (define root (item 'root -1 0 '() '()))
  ;; stack of open items, innermost first
  (define stack (list root))
  (define prev-blank? #t)
  (define (top) (car stack))
  (define (add-to-para! it line)
    (define paras (item-paras it))
    (if (or (null? paras) prev-blank?)
        (set-item-paras! it (append paras (list line)))
        (set-item-paras! it (append (drop-right paras 1)
                                    (list (append (last paras) (list " ") line))))))
  (for ([line (in-list (lines-of elems))])
    (cond
      [(blank? line) (set! prev-blank? #t)]
      [else
       (define first-elem (car line))
       (define m (and (string? first-elem) (regexp-match marker-rx first-elem)))
       (define indent (if (string? first-elem)
                          (string-length (car (regexp-match #px"^ *" first-elem)))
                          0))
       (cond
         [m
          (match-define (list _ spaces marker rest) m)
          (define kind (if (equal? marker "-") 'bullet 'number))
          (define new (item kind indent (+ indent (string-length marker) 1) '() '()))
          ;; close items until the new one is a sibling or a child
          (let loop ()
            (define t (top))
            (cond
              [(= indent (item-content-col t)) (void)]          ; child of t
              [(eq? t root) (build-error "list: bad indentation before ~s" (string-trim (text-of line)))]
              [(< indent (item-content-col t)) (set! stack (cdr stack)) (loop)]
              [else (build-error "list: bad indentation before ~s (expected ~a spaces)"
                                 (string-trim (text-of line)) (item-content-col t))]))
          (define parent (top))
          (set-item-children! parent (append (item-children parent) (list new)))
          (set! stack (cons new stack))
          (set! prev-blank? #t)
          (add-to-para! new (if (equal? rest "") (cdr line) (cons rest (cdr line))))
          (set! prev-blank? #f)]
         [(eq? (top) root)
          (build-error "list: text before the first item, or an unknown marker: ~s"
                       (string-trim (text-of line)))]
         [prev-blank?
          ;; a continuation paragraph: belongs to the open item whose content
          ;; column matches its indentation
          (let loop ()
            (define t (top))
            (cond
              [(eq? t root) (build-error "list: bad indentation for paragraph ~s" (string-trim (text-of line)))]
              [(= indent (item-content-col t)) (void)]
              [(< indent (item-content-col t)) (set! stack (cdr stack)) (loop)]
              [else (build-error "list: bad indentation for paragraph ~s" (string-trim (text-of line)))]))
          (add-to-para! (top) (strip-indent line))
          (set! prev-blank? #f)]
         [else
          (add-to-para! (top) (strip-indent line))])]))
  (when (null? (item-children root)) (build-error "list: no items"))
  (render (item-children root) 1 #f start columns))

(define (strip-indent line)
  (match line
    [(cons (? string? s) rest) (cons (regexp-replace #px"^ +" s "") rest)]
    [_ line]))

;; Consecutive items of one kind form one list.
(define (group items)
  (if (null? items) '()
      (let-values ([(same rest) (splitf-at items (λ (i) (eq? (item-kind i) (item-kind (car items)))))])
        (cons same (group rest)))))

;; level: nesting depth (bullet style cycles by it); chain: the number of
;; the enclosing numbered item, or #f.
(define (render items level chain start columns)
  (define lists
    (for/list ([g (in-list (group items))] [gi (in-naturals)])
      (define numbered? (eq? (item-kind (car g)) 'number))
      (define first-n (if (and start (= gi 0) numbered?) start 1))
      (txexpr (if numbered? 'ol 'ul)
              (append `((class ,(string-append "list" (if columns (format " cols-~a" columns) "")))
                        (data-depth ,(number->string (add1 (modulo (sub1 level) 3)))))
                      (if numbered? '((role "list")) null))
              (for/list ([it (in-list g)] [i (in-naturals first-n)])
                (define n (and numbered? (if chain (format "~a.~a" chain i) (number->string i))))
                (when (and columns (> (string-length (string-trim (text-of (item-paras it)))) 60))
                  (warn "list item over 60 characters in a column list: ~s" (string-trim (text-of (item-paras it)))))
                (txexpr 'li (if n `((data-n ,(string-append n "."))) null)
                        (append (render-paras (item-paras it))
                                (if (null? (item-children it)) null
                                    (list (render (item-children it) (add1 level) (and numbered? n) #f #f)))))))))
  (if (= (length lists) 1) (car lists) (txexpr 'div '((class "list-group")) lists)))

(define (render-paras paras)
  (if (= (length paras) 1)
      (car paras)
      (for/list ([p (in-list paras)]) (txexpr 'p null p))))
