#lang racket/base
;; Citations (§5). Formatting is done by pandoc at `make refresh`
;; (tools/refs.py); this module only reads data/cite-cache.json and picks
;; the full or short form for a key and locator (CITE-3, CITE-5).

(require racket/list
         racket/string
         racket/match
         json
         txexpr
         "util.rkt"
         "marks.rkt")

(provide note-form bib-entry bib-order cite-key-known? normalize-loc external-link
         cite-facts cite-keys csl-fields cite-attribution names-text)

(define cache #f)
(define committed-keys #f)
;; The committed cache, merged with the local one that holds the forms only
;; drafts cite (not committed, absent in CI; tools/refs.py).
(define (the-cache)
  (unless cache
    (define (load . parts)
      (define f (apply project-file parts))
      (if (file-exists? f) (call-with-input-file f read-json) (hasheq)))
    (define merged
      (for/fold ([c (load "data" "cite-cache.json")])
                ([(k v) (in-hash (load "data" "cite-cache.local.json"))])
        (define old (hash-ref c k #f))
        (hash-set c k
                  (if old
                      (for/fold ([o old]) ([form (in-list '(full short))])
                        (hash-set o form (for/fold ([h (hash-ref o form)]) ([(loc v2) (in-hash (hash-ref v form))])
                                           (hash-set h loc v2))))
                      v))))
    (set! committed-keys (map symbol->string (hash-keys (load "data" "cite-cache.json"))))
    (set! cache merged))
  cache)

;; The works that get pages and rows (BIB-1, BIB-4): those the committed
;; cache holds, so a work only drafts cite never reaches a published page;
;; the project server's preview (OD_PREVIEW=1) adds the drafts' works.
(define (cite-keys)
  (the-cache)
  (if (equal? (getenv "OD_PREVIEW") "1")
      (map symbol->string (hash-keys (the-cache)))
      committed-keys))

;; The facts /bibliography and a work's page show (BIB-1, BIB-4), written by
;; tools/refs.py; a cache from before Phase 3 lacks them until `make refresh`.
(define (cite-facts key)
  (define e (entry key))
  (define (field k) (let ([v (hash-ref e k #f)]) (and v (not (eq? v 'null)) v)))
  (unless (field 'title)
    (build-error "the citation cache has no title for ~s; run `make refresh`" key))
  (hasheq 'title (field 'title) 'authors (or (field 'authors) null) 'year (or (field 'year) "")
          'type (or (field 'type) "") 'url (field 'url) 'doi (field 'doi)
          'csl (or (field 'csl) (hasheq))))

;; ---------------------------------------------------------------------------
;; BIB-10: a work as facts. The CSL record (tools/refs.py, from pandoc) mapped
;; to labelled fields, fixed by type; nothing else in the record is shown.

;; Given Family, several joined with commas and "and" before the last.
(define (names-text people)
  (define names
    (for/list ([p (in-list people)])
      (or (hash-ref p 'literal #f)
          (string-normalize-spaces (string-append (hash-ref p 'given "") " " (hash-ref p 'family ""))))))
  (match names
    ['() #f]
    [(list a) a]
    [(list a b) (string-append a " and " b)]
    [_ (string-append (string-join (drop-right names 1) ", ") " and " (last names))]))

(define (csl-year csl)
  (define parts (hash-ref (hash-ref csl 'issued (hasheq)) 'date-parts #f))
  (and (pair? parts) (pair? (car parts)) (format "~a" (caar parts))))

;; A URL as its domain and path (BIB-10).
(define (url-text u) (regexp-replace #rx"/$" (regexp-replace #rx"^https?://(www\\.)?" u "") ""))

;; The fields of a work, in BIB-10's order for its type, as
;; (list label elements lining?), empty ones left out.
(define (csl-fields csl)
  (define (v k) (let ([x (hash-ref csl k #f)]) (and x (not (equal? x "")) (if (number? x) (number->string x) x))))
  (define (people k) (let ([ps (hash-ref csl k null)]) (and (pair? ps) (names-text ps))))
  (define (plural k one many) (if (> (length (hash-ref csl k null)) 1) many one))
  (define doi (v 'DOI))
  (define url (v 'URL))
  (define (field label val #:italic [italic? #f] #:lining [lining? #f])
    (and val (list label (list (if italic? `(em ,val) val)) lining?)))
  (define author (field "Author" (people 'author)))
  (define editor (field (plural 'editor "Editor" "Editors") (people 'editor)))
  (define translator (field (plural 'translator "Translator" "Translators") (people 'translator)))
  (define year (field "Year" (csl-year csl) #:lining #t))
  (define place (field "Place" (v 'publisher-place)))
  (define publisher (field "Publisher" (v 'publisher)))
  (define pages (field "Pages" (v 'page) #:lining #t))
  (define doi-f (and doi (list "DOI" (list (external-link (string-append "https://doi.org/" doi) (list doi))) #t)))
  (define url-f (and url (list "URL" (list (external-link url (list (url-text url)))) #f)))
  (filter values
          (case (hash-ref csl 'type "")
            [("book") (list author editor translator (field "Edition" (v 'edition)) publisher place year
                            (field "ISBN" (v 'ISBN) #:lining #t))]
            [("chapter" "entry-encyclopedia" "entry-dictionary" "paper-conference")
             (list author (field "In" (v 'container-title) #:italic #t) editor publisher place year pages doi-f)]
            [("article-journal" "article-magazine" "article-newspaper" "article")
             (list author (field "Journal" (v 'container-title) #:italic #t) (field "Volume" (v 'volume) #:lining #t)
                   (field "Issue" (v 'issue) #:lining #t) pages year doi-f)]
            [("thesis" "report")
             (list author (field "Type" (v 'genre)) (field "Institution" (v 'publisher)) place year url-f)]
            [else (list author (field "Site" (or (v 'container-title) (v 'publisher))) year url-f)])))

;; BIB-9: a block quotation's attribution, written from the entry: Given
;; Family, Title (italic; the short title when there is one), the locator.
(define (cite-attribution key loc)
  ;; BIB-9 (revised 2026-11-04): the author, then on the next line the work's
  ;; title in italic. (Revised 2026-11-02, night: the title alone.) The locator
  ;; is in the circle's card (BIB-8) and the References entry; LOC is kept in
  ;; the signature for that reason. A record with no author, in CSL terms,
  ;; gets the title alone: give the work an Author in Zotero.
  (define csl (hash-ref (cite-facts key) 'csl))
  (define title (or (hash-ref csl 'title-short #f) (hash-ref csl 'title #f) (hash-ref (cite-facts key) 'title)))
  (define who (let ([ps (hash-ref csl 'author null)]) (and (pair? ps) (names-text ps))))
  (append (if who (list who '(br)) null) (list `(em ,title))))

(define (entry key)
  (or (hash-ref (the-cache) (string->symbol key) #f)
      (build-error "unknown citation key ~s; add it in Zotero, then run `make refresh`" key)))

(define (cite-key-known? key) (and (hash-ref (the-cache) (string->symbol key) #f) #t))

(define (normalize-loc loc)
  (if loc (string-normalize-spaces loc) ""))

;; An external link with its mark (MARK-7: interactive text always has one).
(define (external-link href elems)
  `(a ((class "link ext") (href ,href)) ,@(with-mark elems 'ext)))

;; A printed URL may break after a slash (and before a dot or other
;; punctuation), so long DOIs wrap without breaking anywhere else.
(define (breakable-url s)
  (define parts (regexp-match* #px"[^/.?#&=_-]+|//|[/.?#&=_-]" s))
  (for/fold ([out '()] #:result (reverse out)) ([p (in-list parts)])
    (cond
      [(member p '("/" "//")) (list* '(wbr) p out)]
      [(regexp-match? #px"^[.?#&=_-]$" p) (list* p '(wbr) out)]
      [else (cons p out)])))

;; JSON X-expression → txexpr; <a> becomes a marked external link.
(define (->txexpr j)
  (match j
    [(? string? s) s]
    [(list* "a" attrs kids)
     (external-link (hash-ref attrs 'href)
                    (append-map (λ (k) (if (and (string? k) (regexp-match? #rx"^https?://" k)) (breakable-url k) (list (->txexpr k))))
                                kids))]
    [(list* tag attrs kids)
     (txexpr (string->symbol tag)
             (for/list ([(k v) (in-hash attrs)]) (list k v))
             (map ->txexpr kids))]))

;; Elements of the note for `key` at `loc`: the full form if first, else short.
(define (note-form key loc first?)
  (define forms (hash-ref (entry key) (if first? 'full 'short)))
  (define form (hash-ref forms (string->symbol (normalize-loc loc)) #f))
  (unless form
    (build-error "no cached note for ~s with locator ~s; run `make refresh`" key (normalize-loc loc)))
  (map ->txexpr form))

(define (bib-entry key) (map ->txexpr (hash-ref (entry key) 'bib)))
(define (bib-order key) (hash-ref (entry key) 'order))
