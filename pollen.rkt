#lang racket/base
;; occurrentdevelopment.com — tag functions and the root pass.
;; Requirement IDs refer to SPEC.md.

(require racket/list
         racket/match
         racket/string
         racket/file
         racket/runtime-path
         racket/system
         racket/port
         txexpr
         pollen/decode
         pollen/core
         pollen/setup
         pollen/template
         "typography.rkt")

(provide root
         ;; headings (§8)
         section subsection subsubsection summary
         ;; standard elements (§3.3)
         em strong sc code blockquote epigraph br anchor
         (rename-out [section-break break])
         ;; used by the template
         site-css font-preloads head-script theme-script specimen? specimen-css specimen-script
         page-title essay-header doc-body format-date revised-date)

(module setup racket/base
  (require racket/runtime-path)
  (provide (all-defined-out))
  (define-runtime-path css "assets/css/site.css")
  (define-runtime-path fonts "assets/fonts/fonts.rktd")
  (define-runtime-path typography "typography.rkt")
  (define-runtime-path head-js "assets/js/theme-head.js")
  (define-runtime-path theme-js "assets/js/theme.js")
  (define-runtime-path specimen-css "assets/css/specimen.css")
  (define-runtime-path specimen-js "assets/js/specimen.js")
  ;; SRC-2: an unknown tag is an unbound identifier, so the build fails.
  (define allow-unbound-ids? #f)
  (define block-tags
    '(root address article aside blockquote body div dl dt dd figure figcaption
      footer h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table ul
      od-summary))
  (define cache-watchlist (list css fonts typography head-js theme-js specimen-css specimen-js)))

(require (prefix-in files: (submod "." setup)))

(define (build-error fmt . args)
  (raise-user-error (string-append "build error: " (apply format fmt args))))

;; ---------------------------------------------------------------------------
;; Standard elements

(define (em . xs) (txexpr 'em null xs))
(define (strong . xs) (txexpr 'strong null xs))
(define (code . xs) (txexpr 'code null xs))
(define (sc . xs) (txexpr 'span '((class "sc")) xs)) ; TYPE-11: manual small caps
(define (br) '(br))
(define (anchor id) (txexpr 'span `((id ,(check-id id 'anchor))) null))

;; `◊quote` cannot be a tag: Racket's `quote` would silently swallow it.
(define (blockquote . xs)
  (txexpr 'blockquote null (paragraphs xs)))

(define (epigraph #:source [source #f] . xs)
  (txexpr 'blockquote '((class "epigraph"))
          (append (paragraphs xs)
                  (if source `((footer ,source)) null))))

;; LAYOUT-4: one glyph, drawn by CSS from assets/icons/asterism.svg.
(define (section-break) '(hr ((class "break"))))

;; ---------------------------------------------------------------------------
;; Headings are markers (SECT-2); the root pass wraps them into sections.

(define id-pattern #px"^[a-z0-9]+(-[a-z0-9]+)*$")

(define (check-id id where)
  (unless (and (string? id) (regexp-match? id-pattern id))
    (build-error "~a needs #:id, lowercase and hyphenated (got ~s)" where id))
  id)

(define ((heading-marker level name) #:id [id #f] #:short [short #f] . title)
  (check-id id name)
  (when (null? title) (build-error "~a ~s has no title" name id))
  (txexpr (string->symbol (format "h~a" (add1 level)))
          `((data-level ,(number->string level)) (id ,id)
            ,@(if short `((data-short ,short)) null))
          title))

(define section (heading-marker 1 'section))
(define subsection (heading-marker 2 'subsection))
(define subsubsection (heading-marker 3 'subsubsection))

;; SECT-6: a one-line summary for TOC tooltips (and popups later); not shown.
(define (summary . xs) (txexpr 'od-summary null xs))

(define (heading? x) (and (txexpr? x) (attrs-have-key? x 'data-level)))
(define (heading-level h) (string->number (attr-ref h 'data-level)))

;; ---------------------------------------------------------------------------
;; Paragraphs and line breaks (SRC-3)

;; A single newline inside a paragraph is a space; ◊br{} is the only break.
(define (newline->space elems) (decode-linebreaks elems " "))

(define (paragraphs elems)
  (decode-paragraphs elems #:force? #t #:linebreak-proc newline->space))

;; Any newline left inside inline elements becomes a space too.
(define (newlines->spaces x)
  (cond
    [(and (txexpr? x) (memq (get-tag x) excluded-tags)) x]
    [(txexpr? x)
     (txexpr (get-tag x) (get-attrs x)
             (for/list ([e (in-list (get-elements x))])
               (if (and (string? e) (regexp-match? #px"^\n+$" e)) " " (newlines->spaces e))))]
    [else x]))

;; ---------------------------------------------------------------------------
;; Section tree (SECT-1…7)

(define (text-of x)
  (cond [(string? x) x]
        [(txexpr? x) (string-append* (map text-of (get-elements x)))]
        [else ""]))

;; SECT-7: a § link to the section itself, shown on hover.
(define (self-link id title)
  `(a ((class "self") (href ,(string-append "#" id))
       (aria-label ,(string-append "Link to this section: " (string-append* (map text-of title)))))
      "§"))

(define (summary? x) (and (txexpr? x) (eq? (get-tag x) 'od-summary)))

;; Turn a flat list of blocks into nested <section>s, each running to the
;; next heading of equal or higher rank. Returns the nested content and, in
;; document order, (level id title short summary) for the TOC.
(define (nest-sections elems)
  (define toc '())
  (define (parse elems level)
    (let loop ([elems elems] [acc '()])
      (match elems
        ['() (values (reverse acc) '())]
        [(cons (? heading? h) rest)
         (define l (heading-level h))
         (define id (attr-ref h 'id))
         (cond
           [(<= l level) (values (reverse acc) elems)]
           [(> l (add1 level))
            (build-error "heading ~s skips a level (level ~a under level ~a)" id l level)]
           [else
            ;; SECT-6: an optional ◊summary directly after the heading.
            (define-values (summary rest*)
              (match rest
                [(cons (? summary? s) more) (values (string-trim (text-of s)) more)]
                [_ (values #f rest)]))
            (define title (get-elements h))
            (define short (and (attrs-have-key? h 'data-short) (attr-ref h 'data-short)))
            (set! toc (cons (list l id title short summary) toc))
            (define-values (body after) (parse rest* l))
            (define section
              (txexpr 'section
                      `((id ,id) (class ,(format "level-~a" l))
                        ,@(if short `((data-short ,short)) null))
                      (cons (txexpr (get-tag h) null (append title (list (self-link id title))))
                            body)))
            (loop after (cons section acc))])]
        [(cons (? summary?) _) (build-error "◊summary must directly follow a heading")]
        [(cons x rest) (loop rest (cons x acc))])))
  (define-values (nested _) (parse elems 0))
  (values nested (reverse toc)))

;; TOC-1: levels 1–2, only when there are at least three level-1 sections.
(define (make-toc entries)
  (define (link e)
    (match-define (list _ id title short summary) e)
    `(a ((href ,(string-append "#" id)) ,@(if summary `((title ,summary)) null))
        ,@(if short (list short) title)))
  (define tops (filter (λ (e) (= (first e) 1)) entries))
  (and (>= (length tops) 3)
       `(nav ((class "toc") (aria-label "Contents"))
             (p ((class "toc-title")) "Contents")
             (ul
              ,@(let loop ([es (filter (λ (e) (<= (first e) 2)) entries)])
                  (match es
                    ['() '()]
                    [(cons top rest)
                     (define-values (subs more) (splitf-at rest (λ (e) (= (first e) 2))))
                     (cons `(li ,(link top)
                                ,@(if (null? subs) null `((ul ,@(map (λ (e) `(li ,(link e))) subs)))))
                           (loop more))]))))))

;; ---------------------------------------------------------------------------
;; Validation

(define (check-headings-top-level elems)
  (for ([e (in-list elems)] #:when (txexpr? e))
    (let walk ([x e] [top? #t])
      (when (txexpr? x)
        (when (and (heading? x) (not top?))
          (build-error "heading ~s is inside another element" (attr-ref x 'id)))
        (for ([c (in-list (get-elements x))]) (walk c #f))))))

(define (check-unique-ids tx)
  (define seen (make-hash))
  (let walk ([x tx])
    (when (txexpr? x)
      (when (attrs-have-key? x 'id)
        (define id (attr-ref x 'id))
        (when (hash-ref seen id #f) (build-error "duplicate id ~s" id))
        (hash-set! seen id #t))
      (for-each walk (get-elements x)))))

;; ---------------------------------------------------------------------------
;; The root pass (§12, steps that exist in Phase 0)

(define (mark-intro elems)
  ;; LAYOUT-3: the first paragraph of the essay.
  (let loop ([elems elems])
    (match elems
      ['() '()]
      [(cons (? (λ (x) (and (txexpr? x) (eq? (get-tag x) 'p))) p) rest)
       (cons (attr-set p 'class "intro") rest)]
      [(cons x rest) (cons x (loop rest))])))

(define (root . elems)
  (define flat (paragraphs elems))
  (check-headings-top-level flat)
  (define typeset-flat (get-elements (typeset (newlines->spaces (txexpr 'root null flat)))))
  (define-values (nested toc-entries) (nest-sections (mark-intro typeset-flat)))
  (define toc (make-toc toc-entries))
  ;; TOC-1: after the abstract (in the header) and any epigraph, before the text.
  (define-values (epigraphs body)
    (splitf-at nested (λ (x) (and (txexpr? x) (attrs-have-key? x 'class)
                                   (equal? (attr-ref x 'class) "epigraph")))))
  (define doc (txexpr 'root null (append epigraphs (if toc (list toc) null) body)))
  (check-unique-ids doc)
  doc)

;; ---------------------------------------------------------------------------
;; Template helpers

(define (read-fonts) (file->value files:fonts))

(define (font-url key) (cdr (assq key (read-fonts))))

(define (font-face family key weight style)
  (format "@font-face{font-family:\"~a\";src:url(~a) format(\"woff2\");font-weight:~a;font-style:~a;font-display:swap}\n"
          family (font-url key) weight style))

;; TYPE-8/TYPE-10: faces from the subset manifest, then the stylesheet.
(define (site-css)
  (string-append
   (font-face "Libertinus Serif" 'serif-regular 400 "normal")
   (font-face "Libertinus Serif" 'serif-italic 400 "italic")
   (font-face "Libertinus Serif" 'serif-semibold 600 "normal")
   (font-face "Libertinus Mono" 'mono-regular 400 "normal")
   (file->string files:css)))

(define (font-preloads)
  (string-join
   (for/list ([key '(serif-regular serif-italic)])
     (format "<link rel=\"preload\" href=\"~a\" as=\"font\" type=\"font/woff2\" crossorigin>" (font-url key)))
   "\n"))

(define (head-script) (string-trim (file->string files:head-js)))
(define (theme-script) (string-trim (file->string files:theme-js)))

(define (specimen? metas) (and (select-from-metas 'specimen metas) #t))
(define (specimen-css) (file->string files:specimen-css))
(define (specimen-script) (string-trim (file->string files:specimen-js)))

(define (page-title metas)
  (define title (select-from-metas 'title metas))
  (if title
      (string-append (if (string? title) title (text-of title)) " · Occurrent Development")
      "Occurrent Development"))

(define months
  '#("January" "February" "March" "April" "May" "June" "July"
     "August" "September" "October" "November" "December"))

;; "2026-10-01" → "1 October 2026"
(define (format-date iso)
  (match (regexp-match #px"^(\\d{4})-(\\d{2})-(\\d{2})$" (string-trim iso))
    [(list _ y m d)
     (format "~a ~a ~a" (string->number d) (vector-ref months (sub1 (string->number m))) y)]
    [_ (build-error "bad date ~s (expected YYYY-MM-DD)" iso)]))

;; REV-1: latest commit touching the source, ignoring [typo] and [meta].
(define (revised-date source)
  (define git (find-executable-path "git"))
  (and git source (file-exists? source)
       (let* ([out (with-output-to-string
                     (λ () (parameterize ([current-error-port (open-output-nowhere)])
                             (system* git "-C" (path->string (current-project-root))
                                      "log" "--format=%cs %s" "--" (format "~a" source)))))]
              [line (for/first ([l (in-list (string-split out "\n"))]
                                #:unless (regexp-match? #rx"\\[(typo|meta)\\]" l))
                      l)])
         (and line (substring line 0 10)))))

;; The document's elements, without the root tag.
(define (doc-body doc) (->html (get-elements doc)))

;; LAYOUT-1: title, subtitle, dates, epistemic status, abstract. Meta values
;; go through the same typography as the body.
(define (essay-header metas)
  (define (meta key) (let ([v (select-from-metas key metas)]) (and v (string-trim (if (string? v) v (text-of v))))))
  (define (block tag class text) (and text (typeset (txexpr tag (if class `((class ,class)) null) (list text)))))
  (define published (meta 'published))
  (define revised (revised-date (select-from-metas 'here-path metas)))
  (define dates
    (filter values
            (list (and published (string-append "Published " (format-date published)))
                  (and revised (or (not published) (string>? revised published))
                       (string-append "Revised " (format-date revised))))))
  (txexpr 'header '((class "essay-header"))
          (filter values
                  (list (block 'h1 #f (meta 'title))
                        (block 'p "subtitle" (meta 'subtitle))
                        (and (pair? dates) `(p ((class "dates")) ,(string-join dates " · ")))
                        (block 'p "epistemic" (meta 'epistemic))
                        (block 'p "abstract" (meta 'abstract))))))
