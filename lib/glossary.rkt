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

(provide term-ref glossary-ids glossary-source? current-glossary-dir term-draft? draft-term-ids)

;; The tests point this at a folder of fixture terms (tests/glossary/).
(define current-glossary-dir (make-parameter #f))
(define (glossary-dir) (or (current-glossary-dir) (project-file "glossary")))

;; A term file: a .pm in a folder named glossary (the site's, or a fixture's).
(define (glossary-source? path)
  (and path (let-values ([(dir name _) (split-path (simplify-path path))])
              (and (path? dir)
                   (let-values ([(_up folder _d) (split-path dir)])
                     (and (path? folder) (equal? (path->string folder) "glossary")))))))

(define (meta-string metas key)
  (define v (select-from-metas key metas))
  (and v (string-normalize-spaces (if (string? v) v (text-of v)))))

;; TERM-10: a term file with ◊define-meta[status]{draft} is a draft. It is found
;; by reading the file's text, so a draft that does not compile yet cannot break
;; the build (it is skipped with a warning). A draft is loaded leniently (no
;; `added`, an empty definition and a dangling see-also are allowed), can be used
;; by draft pages, is left off the glossary page, and may not be used by a
;; published page (tools/validate.rkt) or named by a published term's see-also.
(define (draft-source? path)
  (regexp-match? #px"(?m:^◊define-meta\\[status\\]\\{\\s*draft\\s*\\})"
                 (call-with-input-file path (λ (in) (let ([s (read-string 100000 in)]) (if (eof-object? s) "" s))))))

(define (term-files dir)
  (if (directory-exists? dir)
      (filter (λ (p) (regexp-match? #rx"\\.pm$" (path->string p))) (directory-list dir))
      null))

;; ids of the draft terms in the site's glossary folder
(define (draft-term-ids)
  (define dir (glossary-dir))
  (for/list ([f (in-list (term-files dir))] #:when (draft-source? (build-path dir f)))
    (path->string (path-replace-extension f #""))))

;; id → hash of term, aliases, see-also, added, draft, definition, more. TERM-2: the
;; first paragraph is the definition and every element after it is the More
;; (D18: no tag marks it; before draft 1.19 a second plain paragraph was read
;; into a field nothing used and dropped).
(define terms #f)
(define terms-dir #f)

(define (load-all!)
  (define dir (glossary-dir))
  (set! terms-dir dir)
  (define files (term-files dir))
  (define table (make-hash))
  (for ([f (in-list files)])
    (define id (path->string (path-replace-extension f #"")))
    (unless (regexp-match? id-pattern id)
      (build-error "glossary/~a: the filename is the term's id and must be lowercase and hyphenated" f))
    (define path (build-path dir f))
    (define draft? (draft-source? path))
    (define (load)
      (define metas (get-metas path))
      (define doc (get-doc path))
      (define status (meta-string metas 'status))
      (unless (or draft? (not status) (equal? status "published"))
        (build-error "glossary/~a: status is draft or published, not ~s" f status))
      (define term (meta-string metas 'term))
      (define added (meta-string metas 'added))
      (unless term (build-error "glossary/~a needs ◊define-meta[term]" f))
      (unless (or draft? (and added (regexp-match? #px"^\\d{4}-\\d{2}-\\d{2}$" added)))
        (build-error "glossary/~a needs ◊define-meta[added]{YYYY-MM-DD}" f))
      (define body (filter txexpr? (get-elements doc)))
      (define defined? (and (pair? body) (eq? (get-tag (car body)) 'p) (positive? (words (car body)))))
      (unless (or draft? defined?)
        (build-error "glossary/~a: the first paragraph (the definition) is empty" f))
      (hash 'id id 'term term 'added (or added "") 'draft draft?
            'aliases (let ([a (meta-string metas 'aliases)])
                       (if a (filter (λ (s) (> (string-length s) 0)) (map string-trim (string-split a ";"))) null))
            'see-also (let ([s (meta-string metas 'see-also)]) (if s (string-split s) null))
            'definition (if defined? (get-elements (car body)) null)
            'more (if (and defined? (pair? (cdr body))) (cdr body) #f)))
    ;; TERM-10: a draft that does not compile is skipped, not fatal
    (cond [draft? (with-handlers ([exn:fail? (λ (e) (eprintf "warning: glossary/~a is a draft and does not build yet, so it is skipped: ~a\n" f (exn-message e)))])
                    (hash-set! table id (load)))]
          [else (hash-set! table id (load))]))
  ;; TERM-6: dangling see-also, and aliases claimed twice. Drafts are exempt
  ;; (a draft's dangling see-also is dropped), but a published term may not
  ;; point at a draft (TERM-10).
  (define claimed (make-hash))
  (for ([id (in-list (hash-keys table))])
    (define t (hash-ref table id))
    (cond
      [(hash-ref t 'draft)
       (hash-set! table id (hash-set t 'see-also (filter (λ (s) (hash-ref table s #f)) (hash-ref t 'see-also))))]
      [else
       (for ([s (in-list (hash-ref t 'see-also))])
         (define other (hash-ref table s #f))
         (unless other (build-error "glossary/~a.pm: see-also names unknown term ~s" id s))
         (when (hash-ref other 'draft) (build-error "glossary/~a.pm: see-also names the draft term ~s (TERM-10)" id s)))
       (for ([name (in-list (cons (hash-ref t 'term) (hash-ref t 'aliases)))])
         (define k (string-downcase name))
         (define other (hash-ref claimed k #f))
         (when (and other (not (equal? other id)))
           (build-error "glossary: ~s is claimed by both ~a and ~a" name other id))
         (hash-set! claimed k id))]))
  (set! terms table))

(define (fresh!) (unless (and terms (equal? terms-dir (glossary-dir))) (load-all!)))

;; The published terms: what the glossary page lists (TERM-8, TERM-10).
(define (glossary-ids)
  (fresh!)
  (sort (for/list ([(id t) (in-hash terms)] #:unless (hash-ref t 'draft)) id) string<?))

(define (term-draft? id)
  (hash-ref (term-ref id) 'draft #f))

(define (term-ref id)
  (fresh!)
  (or (hash-ref terms id #f)
      (build-error "unknown term ~s (no file glossary/~a.pm)" id id)))
