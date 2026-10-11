#lang racket/base
;; Marks (§4.1): the arrows after links. An arrow is an inline box exactly
;; filled by its SVG mask (MARK-1), bound to its last word (MARK-3), with
;; visually hidden text naming it (MARK-7). Circles (notes, definitions,
;; asides) are made by the root pass in pollen.rkt.

(require racket/list
         racket/match
         txexpr
         "util.rkt")

(provide mark with-mark mark-kinds split-last-word)

(define mark-kinds
  (hash 'ext  "external link"
        'xref "link to another page"
        'up   "link to an earlier section"
        'down "link to a later section"
        'od-dir "link"))   ; placeholder until the root pass knows up or down

(define (mark kind)
  `(span ((class ,(format "mark m-~a" kind)))
         ,(visually-hidden (string-append " (" (hash-ref mark-kinds kind) ")"))))

;; Split elements into (values everything-before last-word-elements): the
;; final word of a trailing string, or a trailing inline element whole.
(define (split-last-word elems)
  (cond
    [(null? elems) (values null null)]
    [else
     (define l (last elems))
     (define init (drop-right elems 1))
     (cond
       [(string? l)
        (match (regexp-match #px"^(.*?)(\\S+)$" l)
          [(list _ before word) (values (append init (if (equal? before "") null (list before))) (list word))]
          [_ (values elems null)])]
       [else (values init (list l))])]))

;; Attach a mark to the end of some text. The last word and the mark are
;; bound in a no-wrap span (MARK-3): a word joiner alone does not stop
;; Chrome breaking before an empty inline box when a space follows it.
(define (with-mark elems kind)
  (define-values (init word) (split-last-word elems))
  (append init (list `(span ((class "nw")) ,@word ,WJ ,(mark kind)))))
