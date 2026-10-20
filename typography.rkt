#lang racket/base
;; Typographic rules (SPEC §10.3).
;;
;; `typeset` runs over a decoded document: it merges adjacent strings
;; (TYPE-13), curls quotes from their context across the whole tree
;; (TYPE-16), then applies smart dashes and the rules table to every string
;; outside code, pre, script and style (TYPE-12). Adding a rule is one line
;; in `rules`, plus its tests in typography-test.rkt (TYPE-14).

(require racket/list
         racket/string
         racket/match
         txexpr
         pollen/decode
         pollen/unstable/typography)

(provide rules
         apply-rules
         typeset-string
         merge-strings
         typeset
         curl-quotes
         curl-text
         straight-quote-in
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

(define (typeset-string* str)
  (apply-rules (smart-dashes str)))

;; A string on its own (a citation's remark, a link's note): its quotes are
;; curled from the string alone (TYPE-16).
(define (typeset-string str)
  (typeset-string* (curl-text str)))

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

;; ---------------------------------------------------------------------------
;; Quotation marks (TYPE-16)
;;
;; Each straight quote is curled from the characters either side of it in
;; its paragraph's text, read in document order across inline tags. Pollen's
;; smart-quotes cannot do this: it sees the text after a tag that is not part
;; of the sentence (an aside's body after `"product"◊aside{…}`) as the next
;; character, and the quote turns the wrong way.
;;
;; A context is the running text of one block. Block elements start one of
;; their own; so do the parts of an annotation that are not in the line, an
;; aside's body (its phrase is in the line, ASIDE-8), a margin note and a
;; summary. Code and the other excluded tags are left alone and count as a
;; word in the line around them.

(define block-context-tags
  '(root p li ul ol blockquote footer figure figcaption div section header nav table thead tbody tr th td
    h1 h2 h3 h4 h5 h6 dl dt dd aside article
    od-abstract od-epistemic od-more od-summary od-margin od-aside))

(define (letter? c) (and c (or (char-alphabetic? c) (char-numeric? c))))
(define closing-punct (string->list ".,;:!?)]”’…"))
(define opening-punct (string->list "([“‘"))

;; Words that begin with an elided letter, so their quote is an apostrophe.
(define elisions #px"^(?i:tis|twas|twere|twill|twould|em|n|cause|til)(?!\\p{L})")

;; The curled form of the quote Q at position I of the context text S.
(define (curl s i q)
  (define p (and (> i 0) (string-ref s (sub1 i))))
  (define n (and (< (add1 i) (string-length s)) (string-ref s (add1 i))))
  (define-values (open close) (if (char=? q #\") (values "“" "”") (values "‘" "’")))
  (cond
    ;; between letters, an apostrophe (don't); "'90s", "'tis": elided
    [(and (char=? q #\') (letter? p) (letter? n)) "’"]
    [(and (char=? q #\') (not (letter? p)) n (char-numeric? n)) "’"]
    [(and (char=? q #\') (not (letter? p)) (regexp-match? elisions s (add1 i))) "’"]
    [(or (letter? p) (and p (memv p closing-punct))) close]
    [(or (letter? n) (and n (memv n opening-punct))) open]
    ;; at a word's start, before a dash or a space: open after a space or
    ;; the start of the block, close otherwise
    [(or (not p) (char-whitespace? p)) (if (and n (not (char-whitespace? n))) open close)]
    [else close]))

(define (curl-text s)
  (if (regexp-match? #rx"[\"']" s)
      (let ([out (open-output-string)])
        (for ([c (in-string s)] [i (in-naturals)])
          (if (memv c '(#\" #\')) (write-string (curl s i c) out) (write-char c out)))
        (get-output-string out))
      s))

;; Curl every quote in TX. Strings are boxed into their contexts on the way
;; down, each context's text is curled as a whole, and the pieces are cut
;; back to their own lengths (curling never changes a string's length).
(define (curl-quotes tx)
  (define contexts '())    ; each: a box of the reversed list of string boxes
  (define (new-context) (let ([c (box '())]) (set! contexts (cons c contexts)) c))
  (define (add! ctx b) (set-box! ctx (cons b (unbox ctx))))
  (define (walk x ctx)
    (cond
      [(string? x) (let ([b (box x)]) (add! ctx b) b)]
      [(and (txexpr? x) (memq (get-tag x) excluded-tags))
       (add! ctx (box "x"))    ; a word in the line, not itself changed
       x]
      [(and (txexpr? x) (eq? (get-tag x) 'br)) (add! ctx (box " ")) x]
      [(and (txexpr? x) (eq? (get-tag x) 'od-aside))
       ;; the phrase is in the line; the body is its own text
       (define body-ctx (new-context))
       (list* 'od-aside (get-attrs x)
               (for/list ([e (in-list (get-elements x))])
                 (if (and (txexpr? e) (eq? (get-tag e) 'od-phrase)) (walk e ctx) (walk e body-ctx))))]
      [(txexpr? x)
       (define ctx* (if (memq (get-tag x) block-context-tags) (new-context) ctx))
       (list* (get-tag x) (get-attrs x) (for/list ([e (in-list (get-elements x))]) (walk e ctx*)))]
      [else x]))
  ;; the tree being walked holds boxes, so it is built as plain lists
  ;; (tag attrs . elements) and made a txexpr again below
  (define boxed (walk tx (new-context)))
  (for ([ctx (in-list contexts)])
    (define bs (reverse (unbox ctx)))
    (define curled (curl-text (string-append* (map unbox bs))))
    (for/fold ([at 0]) ([b (in-list bs)])
      (define len (string-length (unbox b)))
      (set-box! b (substring curled at (+ at len)))
      (+ at len)))
  ;; the "x" placeholders were never in the tree
  (let unbox* ([x boxed])
    (cond [(box? x) (unbox x)]
          [(txexpr? x) x]   ; left as it was (code, pre and the like)
          [(and (pair? x) (symbol? (car x)))
           (txexpr (car x) (cadr x) (map unbox* (cddr x)))]
          [else x])))

;; A straight quote left in rendered prose fails the build (TYPE-16), so the
;; defect cannot come back silently. → the first offending text, or #f.
(define (straight-quote-in tx)
  (let find ([x tx])
    (cond [(and (string? x) (regexp-match? #rx"[\"']" x)) x]
          [(and (txexpr? x) (memq (get-tag x) excluded-tags)) #f]
          [(txexpr? x) (ormap find (get-elements x))]
          [else #f])))

(define (typeset tx)
  (decode (curl-quotes (merge-strings tx))
          #:string-proc typeset-string*
          #:exclude-tags excluded-tags))
