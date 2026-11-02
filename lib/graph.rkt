#lang racket/base
;; The link graph (VAL-2, VAL-4, BIB-6): data/links.json, written by the one
;; pre-pass in tools/validate.rkt before anything is rendered, and read here
;; by everything built from it: Backlinks, a reference page's Quoted and
;; Cited in, the glossary's Used in, /bibliography's counts and /changelog.
;;
;; The shape of links.json:
;;   posts    url → {title, kind ("essay"|"entry"|"page"), published, sections: {id → title}}
;;   links    target url → [{from, section, id, context}]        (Backlinks)
;;   cites    key → [{from, section, mark, note, loc, para, context, text, block}]  (Cited in)
;;            text is the quoted words of a ◊cite with a body (BIB-9), else
;;            null; para numbers the paragraph on its page, for grouping
;;   terms    url → [term id, …]                                (Used in, TERM-8)
;;   changes  [{from, date, text}]                              (/changelog, REV-3)
;; A context is an X-expression in JSON (["p", {…}, …]), as in the citation
;; cache, with the link or the circle marked (class graph-here).
;;
;; Drafts (DRAFT-2) contribute nothing to links.json: their records go to
;; data/links.local.json, gitignored, which is merged in only when the
;; project server previews (OD_PREVIEW=1, set by `make serve`), as the
;; citation caches merge (CITE-5a). `make` never reads it, so a draft's
;; links and citations cannot reach a published page.

(require racket/list
         racket/string
         racket/match
         json
         txexpr
         "util.rkt")

(provide graph current-graph graph-posts post-info backlinks-to cites-of term-users changes
         json->txexpr index-order preview?)

(define (preview?) (equal? (getenv "OD_PREVIEW") "1"))

(define (load . parts)
  (define f (apply project-file parts))
  (define g (and (file-exists? f) (call-with-input-file f read-json)))
  (if (hash? g) g (hasheq)))   ; absent or empty before the first `make`

;; Two graphs into one: maps of lists are appended, maps of maps merged.
(define (merge a b)
  (for/fold ([a a]) ([(k v) (in-hash b)])
    (define old (hash-ref a k #f))
    (hash-set a k (cond [(not old) v]
                        [(and (list? old) (list? v)) (append old v)]
                        [(and (hash? old) (hash? v)) (merge old v)]
                        [else v]))))

(define the-graph #f)
;; The tests set a graph built from fixtures (lib/walk.rkt).
(define current-graph (make-parameter #f))
(define (graph)
  (when (current-graph) (set! the-graph #f))
  (unless (or the-graph (current-graph))
    (set! the-graph (let ([g (load "data" "links.json")])
                      (if (preview?) (merge g (load "data" "links.local.json")) g))))
  (or (current-graph) the-graph))

(define (part key) (hash-ref (graph) key (hasheq)))
(define (graph-posts) (part 'posts))
(define (post-info url) (hash-ref (graph-posts) (string->symbol url) #f))

;; "In the order of the index" (TERM-8, BIB-9): newest first, as /essays
;; and /notebook list them.
(define (index-order urls)
  (sort (remove-duplicates urls) string>?
        #:key (λ (u) (let ([p (post-info u)]) (if p (hash-ref p 'published "") "")))))

(define (backlinks-to url)
  (for/list ([l (in-list (hash-ref (part 'links) (string->symbol url) null))]
             #:unless (equal? (hash-ref l 'from) url))   ; same-page links are not backlinks (VAL-4)
    l))
(define (cites-of key) (hash-ref (part 'cites) (string->symbol key) null))
(define (term-users id)
  (index-order (for/list ([(url ids) (in-hash (part 'terms))] #:when (member id ids)) (symbol->string url))))
(define (changes) (hash-ref (graph) 'changes null))

;; JSON X-expression → txexpr, attributes kept as they were written.
(define (json->txexpr j)
  (match j
    [(? string? s) s]
    [(list* tag attrs kids)
     (txexpr (string->symbol tag)
             (for/list ([(k v) (in-hash attrs)]) (list k v))
             (map json->txexpr kids))]))
