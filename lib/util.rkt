#lang racket/base
;; Shared helpers for the build. Requirement IDs refer to SPEC.md.

(require racket/list
         racket/match
         racket/string
         racket/path
         txexpr
         pollen/core
         pollen/setup
         (only-in "../typography.rkt" WJ))

(provide build-error warn text-of words id-pattern check-id
         tag? has-class? source-path source-dir project-file
         WJ visually-hidden essay-statuses essay-source? post-source? post-kind published?
         output->url parse-tags site-value source-urls reserved-slugs check-post-slugs)

(define (build-error fmt . args)
  (raise-user-error (string-append "build error: " (where) (apply format fmt args))))

(define (warn fmt . args)
  (eprintf "warning: ~a~a\n" (where) (apply format fmt args)))

;; Prefix messages with the source file being built, when known.
(define (where)
  (define p (source-path))
  (if p (format "~a: " (find-relative-path (current-project-root) p)) ""))

(define (source-path)
  (define metas (current-metas))
  (define here (and metas (hash-ref metas 'here-path #f)))
  (and here (string->path (format "~a" here))))

(define (source-dir)
  (define p (source-path))
  (if p (let-values ([(dir _name _dir?) (split-path p)]) dir) (current-project-root)))

(define (project-file . parts) (apply build-path (current-project-root) parts))

(define (text-of x)
  (cond [(string? x) x]
        [(txexpr? x) (string-append* (map text-of (get-elements x)))]
        [(list? x) (string-append* (map text-of x))]
        [else ""]))

(define (words x) (length (string-split (text-of x))))

(define id-pattern #px"^[a-z0-9]+(-[a-z0-9]+)*$")

(define (check-id id where)
  (unless (and (string? id) (regexp-match? id-pattern id))
    (build-error "~a needs an id, lowercase and hyphenated (got ~s)" where id))
  id)

(define ((tag? . tags) x) (and (txexpr? x) (memq (get-tag x) tags) #t))

(define (has-class? x class)
  (and (txexpr? x) (attrs-have-key? x 'class)
       (member class (string-split (attr-ref x 'class))) #t))


;; Text for screen readers only.
(define (visually-hidden str) `(span ((class "vh")) ,str))

;; DRAFT-2: essays carry a status; only these are published.
(define essay-statuses '("draft" "published" "revised" "superseded"))

(define (essay-source? path) (regexp-match? #rx"(^|/)essays/" (format "~a" path)))

;; KIND-1: a post is an essay or a notebook entry, and its kind comes from
;; its folder, never from a meta: 'essay, 'entry, or #f for a page.
(define (post-kind path)
  (define s (format "~a" path))
  (cond [(regexp-match? #rx"(^|/)essays/" s) 'essay]
        [(regexp-match? #rx"(^|/)notebook/" s) 'entry]
        [else #f]))
(define (post-source? path) (and (post-kind path) #t))

;; Pages (not posts) are always published; posts only when not drafts (DRAFT-2).
(define (published? path status)
  (or (not (post-source? path))
      (and (member status '("published" "revised" "superseded")) #t)))

;; Rendered file (relative to the project root) → public URL. Pages and
;; essays are flattened to /<slug>, entries to /notebook/<slug> (D14); the
;; About page, pages/index, is / (HOME-1).
(define (output->url out)
  (cond [(member out '("index.html" "pages/index.html")) "/"]
        [(regexp-match #px"^notebook/[^/]+/([a-z0-9-]+)\\.html$" out) => (λ (m) (string-append "/notebook/" (cadr m)))]
        [(regexp-match #px"^(?:pages|essays/[^/]+)/([a-z0-9-]+)\\.html$" out) => (λ (m) (string-append "/" (cadr m)))]
        [else (string-append "/" (regexp-replace #rx"\\.html$" out ""))]))

;; INDEX-3: ◊define-meta[tags]{philosophy, child development}: comma-separated,
;; lowercase words (letters, digits, hyphens, single spaces).
(define (parse-tags v)
  (define tags
    (for/list ([t (in-list (string-split (if (string? v) v (text-of v)) ","))]
               #:unless (equal? (string-trim t) ""))
      (define tag (string-normalize-spaces (string-trim t)))
      (unless (regexp-match? #px"^[a-z0-9]+(?:[ -][a-z0-9]+)*$" tag)
        (build-error "tag ~s: tags are lowercase words, separated by commas" tag))
      tag))
  (remove-duplicates tags))

;; Site-wide facts from data/site.rktd (§2.2): an association list.
(define (site-value key)
  (define f (project-file "data" "site.rktd"))
  (define v (assq key (call-with-input-file f read)))
  (unless (and v (string? (cdr v)) (not (equal? (cdr v) "")))
    (build-error "data/site.rktd needs a ~a" key))
  (cdr v))

;; REV-2: a source file's blob and commits URLs on GitHub, from its path
;; relative to the project root. Nothing is typed in the essay.
(define (source-urls src)
  (define root (simplify-path (path->complete-path (current-project-root))))
  (define file (simplify-path (path->complete-path src root)))
  (define rel (find-relative-path root file))
  (define parts (map (λ (p) (if (path? p) (path->string p) "..")) (explode-path rel)))  ; 'up → ".."
  (when (or (complete-path? rel) (member ".." parts))
    (build-error "~a is not under the project root ~a, so it has no source link (REV-2)" file root))
  (define path (string-join parts "/"))
  (define repo (regexp-replace #rx"/+$" (site-value 'repo) ""))
  (define branch (site-value 'branch))
  (values (format "~a/blob/~a/~a" repo branch path)
          (format "~a/commits/~a/~a" repo branch path)))

;; KIND-1: slugs are unique across essays/ and notebook/, and never one of
;; the site's own paths. SLUGS is a list of (slug . source) pairs, the
;; pages' names among them; returns a list of error messages.
(define reserved-slugs
  '("essays" "notebook" "glossary" "bibliography" "references" "about" "colophon"
    "correspondence" "changelog" "specimen" "data" "widgets" "_x"))
(define (check-post-slugs posts pages)
  (define seen (make-hash))
  (for ([pg (in-list pages)]) (hash-set! seen pg "a page"))
  (for/fold ([errs '()] #:result (reverse errs)) ([p (in-list posts)])
    (match-define (cons slug src) p)
    (cond
      [(member slug reserved-slugs)
       (cons (format "~a: the slug ~s is reserved for the site's own pages (KIND-1)" src slug) errs)]
      [(hash-ref seen slug #f)
       => (λ (other) (cons (format "~a: the slug ~s is already used by ~a; slugs are unique across essays and the notebook (KIND-1)" src slug other) errs))]
      [else (hash-set! seen slug src) errs])))
