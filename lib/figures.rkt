#lang racket/base
;; Figures (§9.1, IMG-1…6). Raster images become <picture> with AVIF, WebP
;; and a fallback from tools/images.py; SVG is inlined so currentColor
;; follows the theme (IMG-5).

(require racket/list
         racket/string
         racket/path
         racket/file
         json
         xml
         txexpr
         "util.rkt")

(provide make-figure licence-label)

(define widths '("column" "wide" "full"))

;; `sizes` for each width (rem at the default 16px: column 36.5em × 1.25).
(define sizes
  (hash "column" "(min-width: 48.75rem) 45.625rem, calc(100vw - 3.125rem)"
        "wide"   "(min-width: 68.125rem) 65rem, (min-width: 48.75rem) 45.625rem, calc(100vw - 3.125rem)"
        "full"   "calc(100vw - 3.125rem)"))

;; IMG-6
(define licence-rx #px"^(own|public-domain|permission|cc0|cc-by(-sa|-nd|-nc|-nc-sa|-nc-nd)?-\\d\\.\\d)$")

(define (licence-label l)
  (cond
    [(equal? l "own") #f]
    [(equal? l "public-domain") "Public domain"]
    [(equal? l "permission") "Used with permission"]
    [(equal? l "cc0") "CC0"]
    [else (let ([m (regexp-match #px"^cc-(.*)-(\\d\\.\\d)$" l)])
            (string-append "CC " (string-upcase (string-replace (cadr m) "-" " ")) " " (caddr m)))]))

(define manifest #f)
(define (the-manifest)
  (define f (project-file "assets" "img" "images.json"))
  (unless manifest
    (set! manifest (if (file-exists? f) (call-with-input-file f read-json) (hasheq))))
  manifest)

(define (make-figure src caption
                     #:alt alt #:licence licence #:credit credit
                     #:width width #:invert invert)
  (unless (string? alt)
    (build-error "figure ~s needs #:alt (use #:alt \"\" for a decorative image)" src))
  (unless (and (string? licence) (regexp-match? licence-rx licence))
    (build-error "figure ~s needs #:licence: own, public-domain, permission, cc0 or a CC licence like cc-by-4.0" src))
  (when (and (not (equal? licence "own")) (not credit))
    (build-error "figure ~s needs #:credit (licence ~a)" src licence))
  (unless (member width widths) (build-error "figure ~s: #:width must be column, wide or full" src))
  (define path (simplify-path (build-path (source-dir) src)))
  (unless (file-exists? path) (build-error "figure: no file ~a" src))
  (define key (path->string (find-relative-path (simplify-path (project-file)) path)))
  (define entry (hash-ref (the-manifest) (string->symbol key) #f))
  (unless entry (build-error "figure ~s has no variants; run `make`" src))
  (define label (licence-label licence))
  (define credit-line
    (filter values (list (and credit (if (string? credit) credit (text-of credit)))
                         label)))
  `(figure ((class ,(format "figure w-~a" width))
            (data-invert ,(case invert [(#t) "yes"] [(#f) "no"] [else "auto"])))
           ,(if (hash-ref entry 'svg #f)
                (inline-svg path alt)
                (picture entry alt width))
           ,@(if (and (null? caption) (null? credit-line)) null
                 `((figcaption ,@caption
                               ,@(if (null? credit-line) null
                                     `(" " (span ((class "credit")) ,(string-join credit-line " · ")))))))))

(define (srcset urls) (string-join (for/list ([u (in-list urls)]) (format "~a ~aw" (hash-ref u 'url) (hash-ref u 'w))) ", "))

(define (picture entry alt width)
  (define srcs (hash-ref entry 'sources))
  (define fallback (string->symbol (hash-ref entry 'fallback)))
  (define fb (hash-ref srcs fallback))
  (define default (or (for/last ([u (in-list fb)] #:when (<= (hash-ref u 'w) 1200)) u) (first fb)))
  (define sz (hash-ref sizes width))
  `(picture
    (source ((type "image/avif") (srcset ,(srcset (hash-ref srcs 'avif))) (sizes ,sz)))
    (source ((type "image/webp") (srcset ,(srcset (hash-ref srcs 'webp))) (sizes ,sz)))
    (img ((src ,(hash-ref default 'url)) (srcset ,(srcset fb)) (sizes ,sz)
          (width ,(number->string (hash-ref entry 'width)))
          (height ,(number->string (hash-ref entry 'height)))
          (alt ,alt) (loading "lazy") (decoding "async")))))

;; Inline an SVG, labelled by its alt text (or hidden when decorative).
(define (inline-svg path alt)
  (define x (parameterize ([collapse-whitespace #t] [xexpr-drop-empty-attributes #t])
              (xml->xexpr (document-element (read-xml (open-input-string (file->string path)))))))
  (define cleaned
    (let strip ([x x])
      (cond
        [(txexpr? x)
         (txexpr (get-tag x)
                 (filter (λ (a) (not (memq (car a) '(width height xmlns:xlink)))) (get-attrs x))
                 (filter-map (λ (e) (and (not (and (string? e) (regexp-match? #px"^\\s*$" e)))
                                         (not (and (pair? e) (eq? (car e) 'comment)))
                                         (strip e)))
                             (get-elements x)))]
        [else x])))
  (attr-set* cleaned 'class "figure-svg"
             'role "img"
             (if (equal? alt "") 'aria-hidden 'aria-label) (if (equal? alt "") "true" alt)))
