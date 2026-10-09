#lang racket/base
;; The site-wide glossary (§6). One file per term in glossary/, never
;; rendered as a page; essays read definitions from here at build time.

(require racket/list
         racket/string
         racket/path
         racket/match
         txexpr
         pollen/core
         "util.rkt")

(provide term-ref glossary-ids glossary-source?)

(define (glossary-dir) (project-file "glossary"))

(define (glossary-source? path)
  (and path (let-values ([(dir name _) (split-path (simplify-path path))])
              (equal? (simplify-path dir) (simplify-path (path->directory-path (glossary-dir)))))))

(define (meta-string metas key)
  (define v (select-from-metas key metas))
  (and v (string-normalize-spaces (if (string? v) v (text-of v)))))

;; id → hash of term, aliases, see-also, added, definition, more
(define terms #f)

(define (load-all!)
  (define dir (glossary-dir))
  (define files (if (directory-exists? dir)
                    (filter (λ (p) (regexp-match? #rx"\\.pm$" (path->string p))) (directory-list dir))
                    null))
  (define table (make-hash))
  (for ([f (in-list files)])
    (define id (path->string (path-replace-extension f #"")))
    (unless (regexp-match? id-pattern id)
      (build-error "glossary/~a: the filename is the term's id and must be lowercase and hyphenated" f))
    (define path (build-path dir f))
    (define metas (get-metas path))
    (define doc (get-doc path))
    (define term (meta-string metas 'term))
    (define added (meta-string metas 'added))
    (unless term (build-error "glossary/~a needs ◊define-meta[term]" f))
    (unless (and added (regexp-match? #px"^\\d{4}-\\d{2}-\\d{2}$" added))
      (build-error "glossary/~a needs ◊define-meta[added]{YYYY-MM-DD}" f))
    (define-values (mores body) (partition (λ (x) (and (txexpr? x) (eq? (get-tag x) 'od-more))) (get-elements doc)))
    (unless (and (pair? body) (txexpr? (car body)) (eq? (get-tag (car body)) 'p)
                 (positive? (words (car body))))
      (build-error "glossary/~a: the first paragraph (the definition) is empty" f))
    (hash-set! table id
               (hash 'id id 'term term 'added added
                     'aliases (let ([a (meta-string metas 'aliases)])
                                (if a (filter (λ (s) (> (string-length s) 0)) (map string-trim (string-split a ";"))) null))
                     'see-also (let ([s (meta-string metas 'see-also)]) (if s (string-split s) null))
                     'definition (get-elements (car body))
                     'rest (cdr body)
                     'more (if (pair? mores) (get-elements (car mores)) #f))))
  ;; TERM-6: dangling see-also, and aliases claimed twice
  (define claimed (make-hash))
  (for ([(id t) (in-hash table)])
    (for ([s (in-list (hash-ref t 'see-also))])
      (unless (hash-ref table s #f) (build-error "glossary/~a.pm: see-also names unknown term ~s" id s)))
    (for ([name (in-list (cons (hash-ref t 'term) (hash-ref t 'aliases)))])
      (define k (string-downcase name))
      (define other (hash-ref claimed k #f))
      (when (and other (not (equal? other id)))
        (build-error "glossary: ~s is claimed by both ~a and ~a" name other id))
      (hash-set! claimed k id)))
  (set! terms table))

(define (glossary-ids)
  (unless terms (load-all!))
  (sort (hash-keys terms) string<?))

(define (term-ref id)
  (unless terms (load-all!))
  (or (hash-ref terms id #f)
      (build-error "unknown term ~s (no file glossary/~a.pm)" id id)))
