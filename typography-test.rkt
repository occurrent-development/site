#lang racket/base
;; Tests for the typographic rules (TYPE-14). Every rule has at least one
;; case where it fires and one where it must not.

(require rackunit
         racket/list
         racket/string
         "typography.rkt")

(define (t s) (typeset-string s))

;; Every rule in the table has tests below; a new rule without tests fails.
(define tested '(em-dash ellipsis number+unit initials locator multiplication range))
(test-case "every rule is tested"
  (check-equal? (map first rules) tested))

(test-case "em dash"
  (define dash (string-append HS WJ "—" HS))
  (check-equal? (t "word---word") (string-append "word" dash "word"))
  (check-equal? (t "word — word") (string-append "word" dash "word"))
  (check-equal? (t "word—word") (string-append "word" dash "word"))
  ;; must not fire on en dashes or hyphens
  (check-equal? (t "pre-war") "pre-war")
  (check-equal? (t "Monday--Friday") "Monday–Friday"))

(test-case "ellipsis"
  (check-equal? (t "and so...") "and so…")
  (check-equal? (t "a.b") "a.b")
  (check-equal? (t "two.. dots") "two.. dots"))

(test-case "number + unit"
  (check-equal? (t "10 kg") (string-append "10" NNBSP "kg"))
  (check-equal? (t "5 mg daily") (string-append "5" NNBSP "mg daily"))
  (check-equal? (t "for 20 min.") (string-append "for 20" NNBSP "min."))
  (check-equal? (t "37 °C") (string-append "37" NNBSP "°C"))
  ;; must not fire where the "unit" is the start of a word
  (check-equal? (t "10 men") "10 men")
  (check-equal? (t "3 good reasons") "3 good reasons")
  (check-equal? (t "kg 10") "kg 10"))

(test-case "initials"
  (check-equal? (t "C. H. Waddington")
                (string-append "C." NNBSP "H." NNBSP "Waddington"))
  (check-equal? (t "by A. Smith") (string-append "by A." NNBSP "Smith"))
  ;; must not fire after a word, on lowercase, or on abbreviations
  (check-equal? (t "in the USA. Then") "in the USA. Then")
  (check-equal? (t "e. g. this") "e. g. this")
  (check-equal? (t "A. the") "A. the"))

(test-case "locators"
  (check-equal? (t "p. 42") (string-append "p." NBSP "42"))
  (check-equal? (t "pp. 42–44") (string-append "pp." NBSP "42–44"))
  (check-equal? (t "see ch. 3") (string-append "see ch." NBSP "3"))
  (check-equal? (t "p. xii") (string-append "p." NBSP "xii"))
  ;; must not fire inside a word or before a non-number
  (check-equal? (t "the top. 42 more") "the top. 42 more")
  (check-equal? (t "p. In") "p. In")
  (check-equal? (t "ch. ivory") "ch. ivory"))

(test-case "multiplication"
  (check-equal? (t "3 x 4") "3 × 4")
  (check-equal? (t "a 1920 x 1080 screen") "a 1920 × 1080 screen")
  ;; digits must be on both sides
  (check-equal? (t "3 x y") "3 x y")
  (check-equal? (t "x 4") "x 4")
  (check-equal? (t "box 4") "box 4"))

(test-case "ranges"
  (check-equal? (t "1998-2004") "1998–2004")
  (check-equal? (t "pages 3-7") "pages 3–7")
  ;; must not fire on dates, words or chains
  (check-equal? (t "2026-10-01") "2026-10-01")
  (check-equal? (t "COVID-19") "COVID-19")
  (check-equal? (t "pre-1900") "pre-1900"))

(test-case "rules run after smart dashes and quotes"
  (check-equal? (typeset '(p "\"3 x 4\" -- and 1998-2004"))
                '(p "“3 × 4”–and 1998–2004")))

(test-case "TYPE-13: adjacent strings are merged before rules run"
  ;; Pollen hands the root pass a wrapped line as separate strings.
  (check-equal? (typeset '(p "about 10" " " "kg of"))
                `(p ,(string-append "about 10" NNBSP "kg of")))
  (check-equal? (typeset '(p "C." " " "H. Waddington"))
                `(p ,(string-append "C." NNBSP "H." NNBSP "Waddington")))
  (check-equal? (merge-strings '(p "a" "b" (em "c" "d") "e"))
                '(p "ab" (em "cd") "e")))

(test-case "quotes pair across inline tags"
  (check-equal? (typeset '(p "\"" (em "word") "\" and 'so'"))
                '(p "“" (em "word") "” and ‘so’")))

(test-case "code, pre, script and style are left alone"
  (check-equal? (typeset '(p "10 kg " (code "\"10 kg\" x...")))
                `(p ,(string-append "10" NNBSP "kg ") (code "\"10 kg\" x...")))
  (check-equal? (typeset '(pre "a---b \"c\"")) '(pre "a---b \"c\"")))

;; TYPE-16: quotes are curled from their context in the paragraph's text,
;; read across inline tags; an aside's body is not part of that text.
(test-case "TYPE-16: a quote before an aside closes"
  (check-equal? (typeset '(p "finalised \"product\"" (od-aside (od-phrase) "Body.") " provides"))
                '(p "finalised “product”" (od-aside (od-phrase) "Body.") " provides")))

(test-case "TYPE-16: quotes inside an inline tag"
  (check-equal? (typeset '(p "a " (em "\"word\"") " and")) '(p "a " (em "“word”") " and")))

(test-case "TYPE-16: the phrase of a phrase-form aside"
  (check-equal? (typeset '(p "a " (od-aside (od-phrase "finalised \"product\"") "Body \"too\".") ", then"))
                '(p "a " (od-aside (od-phrase "finalised “product”") "Body “too”.") ", then")))

(test-case "TYPE-16: apostrophes"
  (check-equal? (typeset '(p "don't")) '(p "don’t"))
  (check-equal? (typeset '(p "'tis so")) '(p "’tis so"))
  (check-equal? (typeset '(p "the '90s")) '(p "the ’90s"))
  (check-equal? (typeset '(p "the Smiths' house")) '(p "the Smiths’ house"))
  ;; must not fire as an apostrophe on an ordinary opening quote
  (check-equal? (typeset '(p "'tissue' is a word")) '(p "‘tissue’ is a word")))

(test-case "TYPE-16: a quotation inside a quotation"
  (check-equal? (typeset '(p "\"She said 'no' twice.\"")) '(p "“She said ‘no’ twice.”"))
  (check-equal? (typeset '(p "\"'Loops,' he wrote.\"")) '(p "“‘Loops,’ he wrote.”")))

(test-case "TYPE-16: at the start and at the end of a paragraph"
  (check-equal? (typeset '(p "\"Start here")) '(p "“Start here"))
  (check-equal? (typeset '(p "ends here.\"")) '(p "ends here.”"))
  (check-equal? (typeset '(div (p "one.\"") (p "\"two"))) '(div (p "one.”") (p "“two"))))

(test-case "TYPE-16: code is left alone and counts as a word"
  (check-equal? (typeset '(p "the \"" (code "x") "\" tag")) '(p "the “" (code "x") "” tag")))

(test-case "TYPE-16: typographic quotes typed directly are kept"
  (check-equal? (typeset '(p "“already” ‘so’")) '(p "“already” ‘so’")))

(test-case "TYPE-16: a straight quote left in prose is found; code is not prose"
  (check-equal? (straight-quote-in '(p "fine " (em "still \"not"))) "still \"not")
  (check-false (straight-quote-in '(p "fine " (code "\"x\""))))
  (check-false (straight-quote-in (typeset '(p "\"all\" curled, isn't it")))))
