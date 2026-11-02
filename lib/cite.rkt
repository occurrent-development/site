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
         cite-facts cite-keys)

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
          'type (or (field 'type) "") 'url (field 'url) 'doi (field 'doi)))

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
