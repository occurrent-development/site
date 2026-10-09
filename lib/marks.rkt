#lang racket/base
;; Marks (§4.1): the small superscript sign after annotated text.
;;
;; Symbol marks are empty inline spans drawn by CSS (mask-image +
;; currentColor, MARK-1); an inline span adds no line-break opportunity, so
;; with the word joiner before it a mark never wraps alone (MARK-3), and it
;; cannot change the line height (MARK-2). Each carries visually hidden text
;; naming it (MARK-7). Numeral marks (notes, asides) are <sup> text.

(require racket/list
         racket/match
         txexpr
         "util.rkt")

(provide mark with-mark numeral-mark mark-kinds split-last-word)

(define mark-kinds
  (hash 'ext  "external link"
        'xref "link to another page"
        'up   "link to an earlier section"
        'down "link to a later section"
        'term "definition"
        'ref  "reference"
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

;; A numbered mark: <sup> holding a link. `label` names it ("note 3").
(define (numeral-mark class href id text label)
  `(sup ((class ,class))
        (a ((href ,href) ,@(if id `((id ,id)) null) (aria-label ,label)) ,text)))
