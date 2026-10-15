#lang racket/base
;; Figures and tables share one frame (IMG-7): a title with its label
;; ("Figure 1", numbered by the root pass), the body, and a caption and
;; credit below. CSS places them: title above and the rest below in narrow
;; tiers, all three in the right margin in tier L.

(require racket/string
         txexpr
         "util.rkt")

(provide make-exhibit)

;; kind: "figure" or "table". title, body, caption, credit: element lists
;; (caption and credit may be empty). attrs: extra attributes for <figure>.
(define (make-exhibit kind id title body caption credit #:class [cls ""] #:attrs [attrs null])
  (check-id id (string->symbol (format "~a #:id" kind)))
  (when (or (not title) (null? title) (equal? (string-trim (text-of title)) ""))
    (build-error "~a ~s needs a #:title" kind id))
  (define title-id (string-append id "-title"))
  `(figure ((class ,(string-trim (string-append "exhibit " cls)))
            (id ,id) (data-kind ,kind) (aria-labelledby ,title-id) ,@attrs)
           (div ((class "exhibit-title") (id ,title-id))
                (span ((class "exhibit-label")) ,(if (equal? kind "table") "Table" "Figure")) " " ,@title)
           (div ((class "exhibit-body")) ,@body)
           ,@(if (and (null? caption) (null? credit)) null
                 `((figcaption ((class "exhibit-meta"))
                               ,@(if (null? caption) null `((span ((class "exhibit-caption")) ,@caption)))
                               ,@(if (null? credit) null `((span ((class "credit")) ,@credit))))))))
