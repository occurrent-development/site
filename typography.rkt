#lang racket/base
;; Typographic rules (SPEC §10.3).
;;
;; `typeset` runs over a decoded document: it merges adjacent strings
;; (TYPE-13), applies smart quotes across the whole tree, then smart dashes
;; and the rules table to every string outside code, pre, script and style
;; (TYPE-12). Adding a rule is one line in `rules`, plus its tests in
;; typography-test.rkt (TYPE-14).

(require racket/list
         racket/match
         txexpr
         pollen/decode
         pollen/unstable/typography)

(provide rules
         apply-rules
         typeset-string
         merge-strings
         typeset
         excluded-tags
         WJ HS NBSP NNBSP)

(define WJ    "\u2060") ; word joiner
(define HS    "\u200A") ; hair space
(define NBSP  "\u00A0") ; no-break space
(define NNBSP "\u202F") ; narrow no-break space

(define excluded-tags '(code pre script style))

(define units
  "kg|g|mg|µg|μg|mcg|ng|km|m|cm|mm|µm|μm|nm|L|mL|ml|dL|s|ms|min|h|hr|Hz|kHz|MHz|kcal|kJ|mmol|mol|IU|bpm|mmHg|°C")

(define locators
  "p|pp|ch|chs|chap|fig|figs|vol|vols|no|nos|No|sec|para|paras|n|nn|l|ll|col|cols|bk|pt|art")

;; Each rule: (name pattern replacement). Rules run in order, after
;; smart quotes and smart dashes have already been applied.
(define rules
  `(;; Em dash: hair spaces either side; the word joiner sits directly
    ;; before the dash so no line can start with it (see HANDOVER report:
    ;; the order in TYPE-15 would allow a break between hair space and dash).
    (em-dash        #px"[ \u00A0]*—[ \u00A0]*"
                    ,(string-append HS WJ "—" HS))
    (ellipsis       #px"\\.\\.\\."
                    "…")
    (number+unit    ,(pregexp (string-append "(?<=\\d) (?=(?:" units ")(?!\\p{L}|\\d))"))
                    ,NNBSP)
    (initials       #px"(?<!\\p{L})(?<!\\.)(\\p{Lu})\\. (?=\\p{Lu})"
                    ,(string-append "\\1." NNBSP))
    (locator        ,(pregexp (string-append "(?<!\\p{L})(" locators ")\\. (?=\\d|[ivxlc]+(?!\\p{L}))"))
                    ,(string-append "\\1." NBSP))
    (multiplication #px"(?<=\\d) x (?=\\d)"
                    " × ")
    (range          #px"(?<![\\d\\-–])(\\d+)-(\\d+)(?![\\d\\-–])"
                    "\\1–\\2")))

(define (apply-rules str)
  (for/fold ([str str]) ([rule (in-list rules)])
    (match-define (list _ pattern replacement) rule)
    (regexp-replace* pattern str replacement)))

(define (typeset-string str)
  (apply-rules (smart-dashes str)))

;; Merge runs of adjacent strings, recursively (TYPE-13), so rules see
;; "10 kg" even where the source wrapped between "10" and "kg".
(define (merge-strings x)
  (cond
    [(txexpr? x)
     (txexpr (get-tag x) (get-attrs x)
             (let loop ([els (map merge-strings (get-elements x))])
               (match els
                 [(list* (? string? a) (? string? b) rest) (loop (cons (string-append a b) rest))]
                 [(cons a rest) (cons a (loop rest))]
                 ['() '()])))]
    [else x]))

;; smart-quotes works on the whole tree so quotes pair across inline tags,
;; but it cannot exclude tags. Run it, then restore excluded subtrees from
;; the original (the tree's shape is unchanged).
(define (smart-quotes/exclude tx)
  (let restore ([orig tx] [quoted (smart-quotes tx)])
    (cond
      [(and (txexpr? orig) (memq (get-tag orig) excluded-tags)) orig]
      [(txexpr? orig)
       (txexpr (get-tag quoted) (get-attrs quoted)
               (map restore (get-elements orig) (get-elements quoted)))]
      [else quoted])))

(define (typeset tx)
  (decode (smart-quotes/exclude (merge-strings tx))
          #:string-proc typeset-string
          #:exclude-tags excluded-tags))
