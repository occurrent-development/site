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
         file/sha1
         txexpr
         "util.rkt"
         "exhibits.rkt")

(provide make-figure make-panels licence-label cover-picture)

;; IMG-2: every figure is column width (rem at the default 16px: 36.5em × 1.25);
;; Expand (IMG-8) shows it larger. A panel (IMG-9) is a column of the grid
;; in tiers M and up, the whole column in tier S, where the panels stack.
(define (sizes [columns 1])
  (if (= columns 1)
      "(min-width: 48.75rem) 45.625rem, calc(100vw - 3.125rem)"
      (format "(min-width: 48.75rem) ~arem, calc(100vw - 3.125rem)"
              (/ (round (* 1000 (/ 45.625 columns))) 1000.0))))

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

;; IMG-4: classifications from `make refresh`, keyed by SHA-256.
(define invert-cache #f)
(define (classified path)
  (unless invert-cache
    (define f (project-file "data" "invert.json"))
    (set! invert-cache (if (file-exists? f) (call-with-input-file f read-json) (hasheq))))
  (define key (string->symbol (bytes->hex-string (call-with-input-file path sha256-bytes))))
  (define entry (hash-ref invert-cache key #f))
  (and entry (if (hash-ref entry 'invert #f) "yes" "no")))

(define manifest #f)
(define (the-manifest)
  (define f (project-file "assets" "img" "images.json"))
  (unless manifest
    (set! manifest (if (file-exists? f) (call-with-input-file f read-json) (hasheq))))
  manifest)

(define (make-figure src caption
                     #:id id #:title title #:alt alt #:licence licence #:credit credit
                     #:width width #:invert invert)
  (unless (string? alt)
    (build-error "figure ~s needs #:alt (use #:alt \"\" for a decorative image)" src))
  (check-licence (format "figure ~s" src) licence)
  (when (and (not (equal? licence "own")) (not credit))
    (build-error "figure ~s needs #:credit (licence ~a)" src licence))
  (when width (build-error "figure ~s: #:width is gone; every figure is column width, and Expand shows it larger (IMG-2)" src))
  (define-values (path entry) (image-entry "figure" src))
  (define label (licence-label licence))
  (define credit-line
    (filter values (list (and credit (if (string? credit) credit (text-of credit)))
                         label)))
  (make-exhibit "figure" id title
                (list (if (hash-ref entry 'svg #f) (inline-svg path alt) (picture entry alt)))
                caption
                (if (null? credit-line) null (list (string-join credit-line " · ")))
                #:class "figure"
                ;; #:invert wins; else the cached classification; else dimmed
                #:attrs `((data-invert ,(case invert [(#t) "yes"] [(#f) "no"]
                                          [else (or (and (not (hash-ref entry 'svg #f)) (classified path)) "auto")])))))

;; IMG-6, BIB-7: `cover` exists for one thing, the photograph of your own
;; copy that the build itself shows on a work's page and card
(define (check-licence what licence)
  (when (equal? licence "cover")
    (build-error "~a: #:licence \"cover\" is only for the cover the build shows on a work's reference page; a figure needs own, public-domain, permission, cc0 or a CC licence (IMG-6, BIB-7)" what))
  (unless (and (string? licence) (regexp-match? licence-rx licence))
    (build-error "~a needs #:licence: own, public-domain, permission, cc0 or a CC licence like cc-by-4.0" what)))

;; The source file and its manifest entry from tools/images.py (IMG-1).
(define (image-entry what src)
  (define path (simplify-path (build-path (source-dir) src)))
  (unless (file-exists? path) (build-error "~a: no file ~a" what src))
  (define key (path->string (find-relative-path (simplify-path (project-file)) path)))
  (define entry (hash-ref (the-manifest) (string->symbol key) #f))
  (unless entry (build-error "~a ~s has no variants; run `make`" what src))
  (values path entry))

;; IMG-9: one exhibit of lettered panels. The ◊panel elements are lifted out
;; of the body in source order and the rest is the caption. Each panel is a
;; picture or an inline SVG with its own alt and its own data-invert, so a
;; photograph and a drawing are classified apart (IMG-4); the letters, and
;; the letters before per-panel credits, are left empty for the root pass
;; to fill (IMG-7's numbering), so the source never carries them.
(define (make-panels body #:id id #:title title #:licence licence #:credit credit #:columns columns)
  (define what (format "◊panels ~s" id))
  (define-values (panels rest) (partition (λ (x) (and (txexpr? x) (eq? (get-tag x) 'od-panel))) body))
  (define n (length panels))
  (when (< n 2)
    (build-error "~a has ~a panel~a; a figure of panels has two to six, and one image is a ◊figure (IMG-9)"
                 what n (if (= n 1) "" "s")))
  (when (> n 6)
    (build-error "~a has ~a panels; six at most: make it two figures (IMG-9)" what n))
  (when (and columns (not (memv columns '(2 3))))
    (build-error "~a: #:columns is 2 or 3 (IMG-9)" what))
  (when (and columns (< n 4))
    (warn "~a: #:columns is for four panels or more; ~a sit in one row" what n))
  (check-licence what licence)
  (define cols (or columns (min n 3)))
  (define (opt p k) (and (attrs-have-key? p k) (attr-ref p k)))
  (define rendered
    (for/list ([p (in-list panels)] [i (in-naturals)])
      (define src (attr-ref p 'src))
      (define alt (attr-ref p 'alt))
      (define lic (or (opt p 'licence) licence))
      (check-licence (format "panel ~s" src) lic)
      (when (and (not (equal? lic "own")) (not (or (opt p 'credit) credit)))
        (build-error "panel ~s needs #:credit, on the panel or on its ◊panels (licence ~a)" src lic))
      (define-values (path entry) (image-entry "panel" src))
      (define svg? (hash-ref entry 'svg #f))
      (define sub (trim-elements (get-elements p)))
      `(div ((class "panel") (role "group") (data-panel ,(number->string i))
             (data-invert ,(or (opt p 'invert) (and (not svg?) (classified path)) "auto")))
            (span ((class "panel-letter")))
            (div ((class "panel-image")) ,(if svg? (inline-svg path alt) (picture entry alt cols)))
            ,@(if (null? sub) null `((span ((class "credit panel-caption")) ,@sub))))))
  (make-exhibit "figure" id title
                (list `(div ((class "panels") (data-columns ,(number->string cols))) ,@rendered))
                (trim-elements rest)
                (panels-credit panels licence credit)
                #:class "figure panel-figure"))

;; IMG-9, IMG-6: one credit line. When no panel gives its own licence or
;; credit it is the figure's, as for ◊figure; otherwise each panel's credit
;; follows its letter, panels that share one grouped (A, C: own · B: after
;; Smith (2004), CC BY 4.0). The letters are spans the root pass fills.
(define (panels-credit panels licence credit)
  (define (opt p k) (and (attrs-have-key? p k) (attr-ref p k)))
  (cond
    [(not (for/or ([p (in-list panels)]) (or (opt p 'licence) (opt p 'credit))))
     (define line (filter values (list credit (licence-label licence))))
     (if (null? line) null (list (string-join line " · ")))]
    [else
     (define groups   ; credit text → panel indices, in order of first use
       (for/fold ([acc null] #:result (reverse acc)) ([p (in-list panels)] [i (in-naturals)])
         (define parts (filter values (list (or (opt p 'credit) credit)
                                            (licence-label (or (opt p 'licence) licence)))))
         (define text (if (null? parts) "own" (string-join parts ", ")))
         (define hit (assoc text acc))
         (if hit
             (map (λ (g) (if (eq? g hit) (cons text (append (cdr g) (list i))) g)) acc)
             (cons (list text i) acc))))
     (add-between
      (for/list ([g (in-list groups)])
        `(span ((class "panel-credit"))
               (span ((class "panel-keys") (data-panels ,(string-join (map number->string (cdr g)) " "))))
               ,(string-append ": " (car g))))
      " · ")]))

;; A body's elements without the whitespace at either end.
(define (trim-elements xs)
  (define (blank? x) (and (string? x) (regexp-match? #px"^\\s*$" x)))
  (define trimmed (reverse (dropf (reverse (dropf xs blank?)) blank?)))
  (cond [(null? trimmed) null]
        [else
         (define a (car trimmed))
         (define t1 (if (string? a) (cons (string-trim a #:right? #f) (cdr trimmed)) trimmed))
         (define z (last t1))
         (if (string? z) (append (drop-right t1 1) (list (string-trim z #:left? #f))) t1)]))

(define (srcset urls) (string-join (for/list ([u (in-list urls)]) (format "~a ~aw" (hash-ref u 'url) (hash-ref u 'w))) ", "))

(define (picture entry alt [columns 1])
  (define srcs (hash-ref entry 'sources))
  (define fallback (string->symbol (hash-ref entry 'fallback)))
  (define fb (hash-ref srcs fallback))
  (define default (or (for/last ([u (in-list fb)] #:when (<= (hash-ref u 'w) 1200)) u) (first fb)))
  (define sz (sizes columns))
  `(picture
    (source ((type "image/avif") (srcset ,(srcset (hash-ref srcs 'avif))) (sizes ,sz)))
    (source ((type "image/webp") (srcset ,(srcset (hash-ref srcs 'webp))) (sizes ,sz)))
    (img ((src ,(hash-ref default 'url)) (srcset ,(srcset fb)) (sizes ,sz)
          (width ,(number->string (hash-ref entry 'width)))
          (height ,(number->string (hash-ref entry 'height)))
          (alt ,alt) (loading "lazy") (decoding "async")))))

;; BIB-7: the cover of a cited work, a photograph of your own copy, from
;; refs/covers/<key>.jpg (refs/covers.local/ for works only drafts cite) via
;; the image manifest; #f when the work has none. Small and lazy: the card
;; requests its bytes only when shown. Licence `cover` (IMG-6); never
;; inverted in dark mode, only dimmed (IMG-4), so no classification.
(define (cover-picture key title)
  (define entry (or (hash-ref (the-manifest) (string->symbol (format "refs/covers/~a.jpg" key)) #f)
                    (hash-ref (the-manifest) (string->symbol (format "refs/covers.local/~a.jpg" key)) #f)))
  (and entry
       (let* ([w (hash-ref entry 'width)] [h (hash-ref entry 'height)]
              ;; about 7em tall at the text size (CSS), so about this wide
              [sz (format "~apx" (ceiling (* 150 (/ w h))))])
         (define srcs (hash-ref entry 'sources))
         (define fb (hash-ref srcs 'jpg))
         `(picture ((class "cover") (data-licence "cover"))
                   (source ((type "image/avif") (srcset ,(srcset (hash-ref srcs 'avif))) (sizes ,sz)))
                   (source ((type "image/webp") (srcset ,(srcset (hash-ref srcs 'webp))) (sizes ,sz)))
                   (img ((src ,(hash-ref (first fb) 'url)) (srcset ,(srcset fb)) (sizes ,sz)
                         (width ,(number->string w)) (height ,(number->string h))
                         (alt ,(string-append "Cover of " title)) (loading "lazy") (decoding "async")))))))

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
