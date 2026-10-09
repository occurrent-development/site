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
         WJ visually-hidden)

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
