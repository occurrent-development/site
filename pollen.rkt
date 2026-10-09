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
         "typography.rkt"
         "lib/util.rkt"
         "lib/marks.rkt"
         "lib/cite.rkt"
         "lib/glossary.rkt"
         "lib/lists.rkt"
         "lib/tables.rkt"
         "lib/figures.rkt")

(provide root
         ;; headings (§8)
         section subsection subsubsection summary
         ;; standard elements (§3.3)
         em strong sc code blockquote epigraph br anchor
         (rename-out [section-break break])
         ;; annotations (§4–7)
         link cite term aside margin more
         ;; lists, tables, figures (§3.4, §9)
         (rename-out [od-list list]) table table-csv figure
         ;; used by the template
         site-css font-preloads head-script theme-script specimen? specimen-css specimen-script
         page-title essay-header doc-body format-date revised-date)

(module setup racket/base
  (require racket/runtime-path)
  (provide (all-defined-out))
  (define-runtime-path css "assets/css/site.css")
  (define-runtime-path fonts "assets/fonts/fonts.rktd")
  (define-runtime-path images "assets/img/images.json")
  (define-runtime-path cite-cache "data/cite-cache.json")
  (define-runtime-path typography "typography.rkt")
  (define-runtime-path head-js "assets/js/theme-head.js")
  (define-runtime-path theme-js "assets/js/theme.js")
  (define-runtime-path specimen-css "assets/css/specimen.css")
  (define-runtime-path specimen-js "assets/js/specimen.js")
  (define-runtime-path marks-dir "assets/icons/marks")
  ;; SRC-2: an unknown tag is an unbound identifier, so the build fails.
  (define allow-unbound-ids? #f)
  (define block-tags
    '(root address article aside blockquote body div dl dt dd figure figcaption
      footer h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table ul
      od-summary od-more))
  (define cache-watchlist
    (list css fonts images cite-cache typography head-js theme-js specimen-css specimen-js)))

(require (prefix-in files: (submod "." setup)))

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
;; Annotations (§4–7). Tags emit markers; the root pass resolves them in one
;; document-order walk.

(define (norm x) (and x (string-normalize-spaces (if (string? x) x (text-of x)))))

;; ◊link[target]{text}: the type is inferred from the target (LINK-1).
(define (link target #:note [note #f] #:title [title #f] #:author [author #f] #:date [date #f] . text)
  (unless (string? target) (build-error "◊link needs a target"))
  (when (null? text) (build-error "◊link ~s has no text" target))
  (txexpr 'od-link
          (filter values (list (list 'href target)
                               (and note (list 'data-note (norm note)))
                               (and title (list 'data-title (norm title)))
                               (and author (list 'data-author (norm author)))
                               (and date (list 'data-date (norm date)))))
          text))

;; ◊cite[key]: a numbered note (§5).
(define (cite key #:loc [loc #f] #:note [note #f])
  (unless (string? key) (build-error "◊cite needs a key"))
  (txexpr 'od-cite (filter values (list (list 'key key)
                                        (and loc (list 'loc (normalize-loc loc)))
                                        (and note (list 'note (norm note)))))
          null))

;; ◊term[id]{text}: a glossary term (§6).
(define (term id #:mark [force #f] . text)
  (check-id id 'term)
  (when (null? text) (build-error "◊term ~s has no text" id))
  (txexpr 'od-term `((ref ,id) ,@(if force '((force "1")) null)) text))

(define (aside . xs) (txexpr 'od-aside null xs))      ; §7.1
(define (margin . xs) (txexpr 'od-margin null xs))    ; §7.2
(define (more . xs) (txexpr 'od-more null (paragraphs xs))) ; glossary only

;; ---------------------------------------------------------------------------
;; Lists, tables, figures (§3.4, §9)

(define (od-list #:start [start #f] #:columns [columns #f] . xs)
  (when (and columns (not (memv columns '(2 3)))) (build-error "◊list #:columns must be 2 or 3"))
  (when (and start (not (exact-positive-integer? start))) (build-error "◊list #:start must be a positive number"))
  (parse-list xs #:start start #:columns columns))

(define (table #:caption [caption #f] #:source [source #f] #:size [size "normal"] #:width [width "column"]
               #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f] . xs)
  (define-values (header aligns body) (parse-pipe-table xs))
  (make-table header aligns body
              #:caption (and caption (list (norm caption))) #:source (and source (list (norm source)))
              #:size size #:width width #:sortable sortable #:align align #:row-headers row-headers))

(define (table-csv path #:caption [caption #f] #:source [source #f] #:size [size "normal"] #:width [width "column"]
                   #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f])
  (define-values (header aligns body) (read-csv-table path))
  (make-table header aligns body
              #:caption (and caption (list (norm caption))) #:source (and source (list (norm source)))
              #:size size #:width width #:sortable sortable #:align align #:row-headers row-headers))

(define (figure src #:alt [alt #f] #:licence [licence #f] #:credit [credit #f]
                #:width [width "column"] #:invert [invert 'auto] . caption)
  (make-figure src caption #:alt (norm alt) #:licence licence #:credit (norm credit)
               #:width width #:invert invert))

;; ---------------------------------------------------------------------------
;; Headings are markers (SECT-2); the root pass wraps them into sections.

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
;; The root pass (§12)

(define (mark-intro elems)
  ;; LAYOUT-3: the first paragraph of the essay.
  (let loop ([elems elems])
    (match elems
      ['() '()]
      [(cons (? (tag? 'p) p) rest) (cons (attr-set p 'class "intro") rest)]
      [(cons x rest) (cons x (loop rest))])))

;; Paragraphs, line breaks, then the typography rules (steps 2–3).
(define (prepare elems)
  (get-elements (close-up-refs (typeset (newlines->spaces (txexpr 'root null (paragraphs elems)))))))

(define (find-all x pred)
  (cond [(txexpr? x) (append (if (pred x) (list x) null)
                             (append-map (λ (e) (find-all e pred)) (get-elements x)))]
        [(list? x) (append-map (λ (e) (find-all e pred)) x)]
        [else null]))

(define (forbid elems tags where)
  (for ([x (in-list (find-all elems (apply tag? tags)))])
    (build-error "~a cannot contain ◊~a" where
                 (case (get-tag x) [(od-aside) "aside"] [(od-margin) "margin"] [(od-more) "more"]
                   [(od-cite) "cite"] [(od-term) "term"] [(od-link) "link"] [else (get-tag x)]))))

;; MARK-3: a note or aside numeral follows its word directly, so the space
;; typed before ◊cite or ◊aside is removed.
(define (close-up-refs x)
  (cond
    [(txexpr? x)
     (txexpr (get-tag x) (get-attrs x)
             (let loop ([els (map close-up-refs (get-elements x))])
               (match els
                 [(list* (? string? s) (? (tag? 'od-cite 'od-aside) r) rest)
                  (cons (string-trim s #:left? #f) (loop (cons r rest)))]
                 [(cons e rest) (cons e (loop rest))]
                 ['() '()])))]
    [else x]))

;; MNOTE-3: a margin note opens its paragraph and is emitted run in.
(define (lift-margin-notes elems)
  (for/list ([x (in-list elems)])
    (match x
      [(txexpr 'p attrs (list* (? (tag? 'od-margin) m) rest))
       (forbid (get-elements m) '(od-link od-cite od-term od-aside od-margin) "◊margin")  ; MNOTE-5
       (when (> (words m) 12) (warn "margin note over 12 words: ~s" (string-trim (text-of m))))
       (txexpr 'p attrs (list* `(span ((class "margin-note")) ,@(get-elements m)) rest))]
      [_ x])))

(define (roman n)
  (let loop ([n n] [pairs '((1000 "m") (900 "cm") (500 "d") (400 "cd") (100 "c") (90 "xc")
                            (50 "l") (40 "xl") (10 "x") (9 "ix") (5 "v") (4 "iv") (1 "i"))])
    (cond [(zero? n) ""]
          [(>= n (caar pairs)) (string-append (cadar pairs) (loop (- n (caar pairs)) pairs))]
          [else (loop n (cdr pairs))])))

(define (strip-ids x)
  (if (txexpr? x)
      (txexpr (get-tag x) (filter (λ (a) (not (eq? (car a) 'id))) (get-attrs x)) (map strip-ids (get-elements x)))
      x))

(define (back-link href label) `(a ((class "back") (href ,href) (aria-label ,label)) "↩"))

;; ◊link: external ↗, cross-essay →, same-page ↑/↓ (direction set later).
(define (resolve-link x kids)
  (define href (attr-ref x 'href))
  (define data (filter (λ (a) (regexp-match? #rx"^data-" (symbol->string (car a)))) (get-attrs x)))
  (cond
    [(regexp-match? #rx"^https?://" href)
     `(a ((class "link ext") (href ,href) ,@data) ,@(with-mark kids 'ext))]
    [(regexp-match? #px"^/[a-z0-9-]*(#[a-z0-9-]+)?$" href)
     `(a ((class "link xref") (href ,href)) ,@(with-mark kids 'xref))]
    [(regexp-match? #px"^#[a-z0-9-]+$" href)
     `(a ((class "link same") (href ,href)) ,@(with-mark kids 'od-dir))]
    [else (build-error "◊link target ~s is not http(s)://…, /slug, /slug#id or #id" href)]))

;; The numbering walk and end matter (steps 4–6, CITE-1/2/10).
(define (annotate doc-elems)
  (define note-n 0)
  (define aside-n 0)
  (define notes '())        ; (n elems)
  (define asides '())       ; (i numeral elems)
  (define seen-keys (make-hash))
  (define bib-keys (make-hash))
  (define term-order '())
  (define term-seen (make-hash))

  (define (walk x)
    (match x
      [(? (tag? 'od-cite))
       (set! note-n (add1 note-n))
       (define n note-n)
       (define key (attr-ref x 'key))
       (define loc (and (attrs-have-key? x 'loc) (attr-ref x 'loc)))
       (define first? (not (hash-ref seen-keys key #f)))
       (hash-set! seen-keys key #t)
       (hash-set! bib-keys key #t)
       (define commentary (and (attrs-have-key? x 'note) (typeset-string (attr-ref x 'note))))
       (set! notes (cons (list n (append (note-form key loc first?)
                                         (if commentary (list " " commentary) null)))
                         notes))
       `(span ((class "ref")) ,WJ
              ,(numeral-mark "note-ref" (format "#note-~a" n) (format "nref-~a" n)
                             (number->string n) (format "note ~a" n)))]
      [(? (tag? 'od-aside))
       (set! aside-n (add1 aside-n))
       (define i aside-n)
       (define numeral (roman i))
       ;; numbering continues inside the aside, at its place in the argument
       (define body (map walk (get-elements x)))
       (set! asides (cons (list i numeral body) asides))
       `(span ((class "ref")) ,WJ
              ,(numeral-mark "aside-ref" (format "#aside-~a" i) (format "aside-ref-~a" i)
                             numeral (format "aside ~a" numeral))
              ;; ASIDE-1: the inline copy, lifted into the margin in Phase 2
              (span ((class "aside") (hidden "")) ,@(map strip-ids body)))]
      [(? (tag? 'od-term))
       (define id (attr-ref x 'ref))
       (term-ref id)
       (define first? (not (hash-ref term-seen id #f)))
       (when first? (hash-set! term-seen id #t) (set! term-order (cons id term-order)))
       (define kids (map walk (get-elements x)))
       (if (or first? (attrs-have-key? x 'force))  ; TERM-5
           `(a ((class "term") (href ,(format "#term-~a" id))) ,@(with-mark kids 'term))
           `(span ((class "term")) ,@kids))]
      [(? (tag? 'od-link)) (resolve-link x (map walk (get-elements x)))]
      [(? txexpr?) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
      [_ x]))

  (define body (map walk doc-elems))

  ;; TERM-4: the Terms section, including terms used inside definitions.
  (define term-entries
    (let loop ([queue (reverse term-order)] [done '()] [entries '()])
      (match queue
        ['() (sort entries string-ci<? #:key car)]
        [(cons id rest)
         #:when (member id done)
         (loop rest done entries)]
        [(cons id rest)
         (define t (term-ref id))
         (define more-ids '())
         (define (def-walk x)
           (match x
             [(? (tag? 'od-cite))   ; CITE-7: unnumbered, to the bibliography
              (define key (attr-ref x 'key))
              (bib-entry key)
              (hash-set! bib-keys key #t)
              `(span ((class "ref")) ,WJ
                     (a ((class "cite-ref") (href ,(string-append "#bib-" key))) ,(mark 'ref)))]
             [(? (tag? 'od-term))   ; TERM-7
              (define tid (attr-ref x 'ref))
              (term-ref tid)
              (set! more-ids (cons tid more-ids))
              `(a ((class "term") (href ,(format "#term-~a" tid))) ,@(with-mark (map def-walk (get-elements x)) 'term))]
             [(? (tag? 'od-link))
              (when (regexp-match? #rx"^#" (attr-ref x 'href))
                (build-error "glossary/~a.pm: a definition cannot link within a page" id))
              (resolve-link x (map def-walk (get-elements x)))]
             [(? txexpr?) (txexpr (get-tag x) (get-attrs x) (map def-walk (get-elements x)))]
             [_ x]))
         (define definition (map def-walk (hash-ref t 'definition)))
         (define more (and (hash-ref t 'more) (map def-walk (hash-ref t 'more))))
         (define see (hash-ref t 'see-also))
         (define entry
           `(div ((class "term-entry") (id ,(string-append "term-" id)))
                 (p (dfn ,(hash-ref t 'term)) ". " ,@definition)
                 ,@(or more null)
                 ,@(if (null? see) null
                       `((p ((class "see-also")) "See also: "
                            ,@(add-between
                               (for/list ([s (in-list see)])
                                 `(a ((class "term") (href ,(format "#term-~a" s)))
                                     ,@(with-mark (list (hash-ref (term-ref s) 'term)) 'term)))
                               ", "))))))
         (loop (append rest (reverse more-ids) see) (cons id done) (cons (cons (hash-ref t 'term) entry) entries))])))

  (define (endmatter id title . content)
    `(section ((class "endmatter") (id ,id)) (h2 ,title) ,@content))

  (define end
    (filter values
            (list
             (and (pair? term-entries)
                  (endmatter "terms" "Terms" `(div ((class "terms")) ,@(map cdr term-entries))))
             (and (pair? asides)
                  (endmatter "asides" "Asides"
                             `(ol ((class "asides"))
                                  ,@(for/list ([a (in-list (reverse asides))])
                                      (match-define (list i numeral elems) a)
                                      `(li ((id ,(format "aside-~a" i)) (value ,(number->string i)))
                                           ,@elems " "
                                           ,(back-link (format "#aside-ref-~a" i) (format "Back to aside ~a in the text" numeral)))))))
             (and (pair? notes)
                  (endmatter "notes" "Notes"
                             `(ol ((class "notes"))
                                  ,@(for/list ([nt (in-list (reverse notes))])
                                      (match-define (list n elems) nt)
                                      `(li ((id ,(format "note-~a" n)) (value ,(number->string n)))
                                           ,@elems " "
                                           ,(back-link (format "#nref-~a" n) (format "Back to note ~a in the text" n)))))))
             (and (positive? (hash-count bib-keys))
                  (endmatter "bibliography" "Bibliography"
                             `(ul ((class "bibliography"))
                                  ,@(for/list ([k (in-list (sort (hash-keys bib-keys) < #:key bib-order))])
                                      `(li ((id ,(string-append "bib-" k))) ,@(bib-entry k)))))))))
  (append body end))

;; MARK-3: bind each note or aside numeral to the word before it.
(define (bind-refs x)
  (cond
    [(txexpr? x)
     (define els (map bind-refs (get-elements x)))
     (txexpr (get-tag x) (get-attrs x)
             (let loop ([done '()] [rest els])
               (match rest
                 ['() (reverse done)]
                 [(cons (? (λ (e) (has-class? e "ref")) r) more)
                  #:when (and (pair? done) (not (block-txexpr? (car done))))
                  (define-values (init word) (split-last-word (list (car done))))
                  (loop (cons `(span ((class "nw")) ,@word ,r) (append (reverse init) (cdr done))) more)]
                 [(cons e more) (loop (cons e done) more)])))]
    [else x]))

;; Same-page links point up or down by document order (LINK-1); a missing
;; target fails the build (LINK-2).
(define (set-directions doc)
  (define order (make-hash))
  (define i 0)
  (let walk ([x doc])
    (when (txexpr? x)
      (set! i (add1 i))
      (when (attrs-have-key? x 'id) (hash-ref! order (attr-ref x 'id) i))
      (for-each walk (get-elements x))))
  (define j 0)
  (let walk ([x doc])
    (cond
      [(txexpr? x)
       (set! j (add1 j))
       (define here j)
       (if (has-class? x "same")
           (let* ([id (substring (attr-ref x 'href) 1)]
                  [target (hash-ref order id (λ () (build-error "◊link target #~a does not exist on this page" id)))]
                  [dir (if (< target here) 'up 'down)])
             (txexpr (get-tag x) (get-attrs x)
                     (let fix ([els (get-elements x)])
                       (for/list ([e (in-list els)])
                         (cond [(has-class? e "m-od-dir") (mark dir)]
                               [(txexpr? e) (txexpr (get-tag e) (get-attrs e) (fix (get-elements e)))]
                               [else e])))))
           (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x))))]
      [else x])))

;; IMG-1: the first figure loads eagerly; the rest lazily.
(define (eager-first-image doc)
  (define done #f)
  (let walk ([x doc])
    (cond
      [(and (not done) ((tag? 'img) x)) (set! done #t)
       (txexpr 'img (filter (λ (a) (not (eq? (car a) 'loading))) (get-attrs x)) null)]
      [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
      [else x])))

(define (check-essay-metas)
  ;; VAL-1: essays need their meta fields.
  (define p (source-path))
  (when (and p (regexp-match? #rx"/essays/" (path->string p)))
    (for ([k '(title status published)])
      (unless (select-from-metas k (current-metas))
        (build-error "missing ◊define-meta[~a]" k)))))

(define (glossary-root elems)
  (define flat (prepare elems))
  (check-headings-top-level flat)
  (forbid flat '(od-aside od-margin) "a glossary definition")
  (when (pair? (find-all flat heading?)) (build-error "a glossary definition cannot contain headings"))
  (txexpr 'root null flat))

(define (page-root elems)
  (check-essay-metas)
  (define flat (prepare elems))
  (check-headings-top-level flat)
  (forbid flat '(od-more) "an essay")
  (for ([a (in-list (find-all flat (tag? 'od-aside)))])
    (forbid (get-elements a) '(od-aside od-margin) "◊aside"))
  (define lifted (lift-margin-notes flat))
  (when (pair? (find-all lifted (tag? 'od-margin)))
    (build-error "◊margin must open its paragraph"))
  (define-values (nested toc-entries) (nest-sections (mark-intro lifted)))
  (define toc (make-toc toc-entries))
  ;; TOC-1: after the abstract (in the header) and any epigraph, before the text.
  (define-values (epigraphs body)
    (splitf-at nested (λ (x) (has-class? x "epigraph"))))
  (define annotated (annotate (append epigraphs (if toc (list toc) null) body)))
  (define doc (eager-first-image (bind-refs (set-directions (txexpr 'root null annotated)))))
  (check-unique-ids doc)
  doc)

(define (root . elems)
  (if (glossary-source? (source-path))
      (glossary-root elems)
      (page-root elems)))

;; ---------------------------------------------------------------------------
;; Template helpers

(define (read-fonts) (file->value files:fonts))

(define (font-url key) (cdr (assq key (read-fonts))))

(define (font-face family key weight style)
  (format "@font-face{font-family:\"~a\";src:url(~a) format(\"woff2\");font-weight:~a;font-style:~a;font-display:swap}\n"
          family (font-url key) weight style))

;; MARK-1: each mark's SVG as a data URI in a custom property, so marks
;; cost no requests and are drawn with mask-image in currentColor.
(define (mark-properties)
  (string-append
   ":root{"
   (string-append*
    (for/list ([f (in-list (sort (directory-list files:marks-dir) string<? #:key path->string))]
               #:when (regexp-match? #rx"\\.svg$" (path->string f)))
      (define svg (string-trim (file->string (build-path files:marks-dir f))))
      (define encoded
        (for/fold ([s svg]) ([pair '(("\"" "'") ("#" "%23") ("<" "%3C") (">" "%3E"))])
          (string-replace s (car pair) (cadr pair))))
      (format "--m-~a:url(\"data:image/svg+xml,~a\");" (path->string (path-replace-extension f #"")) encoded)))
   "}\n"))

;; TYPE-8/TYPE-10: faces from the subset manifest, then the stylesheet.
(define (site-css)
  (string-append
   (font-face "Libertinus Serif" 'serif-regular 400 "normal")
   (font-face "Libertinus Serif" 'serif-italic 400 "italic")
   (font-face "Libertinus Serif" 'serif-semibold 600 "normal")
   (font-face "Libertinus Mono" 'mono-regular 400 "normal")
   (mark-properties)
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
