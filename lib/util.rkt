#lang racket/base
;; Shared helpers for the build. Requirement IDs refer to SPEC.md.

(require racket/list
         racket/string
         racket/path
         txexpr
         pollen/core
         pollen/setup
         (only-in "../typography.rkt" WJ))

(provide build-error warn text-of words id-pattern check-id
         tag? has-class? source-path source-dir project-file
         WJ visually-hidden essay-statuses essay-source? published?
         output->url parse-tags)

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

;; Pages (not essays) are always published; essays only when not drafts.
(define (published? path status)
  (or (not (essay-source? path))
      (and (member status '("published" "revised" "superseded")) #t)))

;; Rendered file (relative to the project root) → public URL. Pages and
;; essays are flattened to /<slug>; the index is /.
(define (output->url out)
  (cond [(equal? out "index.html") "/"]
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
