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
         file/sha1
         json
         txexpr
         pollen/decode
         pollen/core
         pollen/setup
         pollen/template
         pollen/pagetree
         racket/path
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
         (rename-out [od-list list]) table table-csv sort-key figure ref
         ;; the home page (§13a)
         essay-index
         ;; used by the template
         site-css font-preloads head-script asset-url specimen? specimen-css
         page-title essay-header doc-body format-date revised-date site-menu has-toc?)

(module setup racket/base
  (require racket/runtime-path)
  (provide (all-defined-out))
  (define-runtime-path css "assets/css/site.css")
  (define-runtime-path fonts "assets/fonts/fonts.rktd")
  (define-runtime-path images "assets/img/images.json")
  (define-runtime-path cite-cache "data/cite-cache.json")
  (define-runtime-path link-meta "data/link-meta.json")
  (define-runtime-path invert "data/invert.json")
  (define-runtime-path typography "typography.rkt")
  (define-runtime-path head-js "assets/js/theme-head.js")
  (define-runtime-path site-js "assets/js/site.js")
  (define-runtime-path specimen-css "assets/css/specimen.css")
  (define-runtime-path marks-dir "assets/icons/marks")
  ;; SRC-2: an unknown tag is an unbound identifier, so the build fails.
  (define allow-unbound-ids? #f)
  (define block-tags
    '(root address article aside blockquote body div dl dt dd figure figcaption
      footer h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table ul
      od-summary od-more))
  (define cache-watchlist
    (list css fonts images cite-cache link-meta invert typography head-js site-js specimen-css)))

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

(define (table #:id [id #f] #:title [title #f] #:caption [caption #f] #:source [source #f]
               #:size [size "normal"] #:width [width #f]
               #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f] . xs)
  (define-values (header aligns body) (parse-pipe-table xs))
  (make-table header aligns body
              #:id id #:title (and title (list (norm title)))
              #:caption (and caption (list (norm caption))) #:source (and source (list (norm source)))
              #:size size #:width width #:sortable sortable #:align align #:row-headers row-headers))

(define (table-csv path #:id [id #f] #:title [title #f] #:caption [caption #f] #:source [source #f]
                   #:size [size "normal"] #:width [width #f]
                   #:sortable [sortable 'auto] #:align [align #f] #:row-headers [row-headers #f])
  (define-values (header aligns body) (read-csv-table path))
  (make-table header aligns body
              #:id id #:title (and title (list (norm title)))
              #:caption (and caption (list (norm caption))) #:source (and source (list (norm source)))
              #:size size #:width width #:sortable sortable #:align align #:row-headers row-headers))

;; TABLE-5: the value a cell sorts by, when its text would mislead.
(define (sort-key value . display)
  (unless (string? value) (build-error "◊sort-key needs a value, as in ◊sort-key[\"2004\"]{c. 2004}"))
  (txexpr 'span `((data-sort ,value)) display))

(define (figure src #:id [id #f] #:title [title #f] #:alt [alt #f] #:licence [licence #f] #:credit [credit #f]
                #:width [width #f] #:invert [invert 'auto] . caption)
  (make-figure src caption #:id id #:title (and title (list (norm title)))
               #:alt (norm alt) #:licence licence #:credit (norm credit)
               #:width width #:invert invert))

;; IMG-7: ◊ref[id] prints the label of a figure or table on this page
;; ("Figure 2"), as a same-page link; the root pass fills in the number.
(define (ref id)
  (check-id id 'ref)
  (txexpr 'od-ref `((target ,id)) null))

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
          (div ((class "toc-inner"))   ; stays in view in tier XL (TOC-2)
             (p ((class "toc-title")) "Contents")
             (ul
              ,@(let loop ([es (filter (λ (e) (<= (first e) 2)) entries)])
                  (match es
                    ['() '()]
                    [(cons top rest)
                     (define-values (subs more) (splitf-at rest (λ (e) (= (first e) 2))))
                     (cons `(li ,(link top)
                                ,@(if (null? subs) null `((ul ,@(map (λ (e) `(li ,(link e))) subs)))))
                           (loop more))])))))))

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
                  (define trimmed (string-trim s #:left? #f))
                  (if (equal? trimmed "")
                      (loop (cons r rest))
                      (cons trimmed (loop (cons r rest))))]
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

(define (strip-ids x)
  (if (txexpr? x)
      (txexpr (get-tag x) (filter (λ (a) (not (eq? (car a) 'id))) (get-attrs x)) (map strip-ids (get-elements x)))
      x))

;; CARD-4: card facts entered by hand, keyed by URL.
(define link-meta-cache #f)
(define (link-meta url)
  (unless link-meta-cache
    (define f (project-file "data" "link-meta.json"))
    (set! link-meta-cache (if (file-exists? f) (call-with-input-file f read-json) (hasheq))))
  (define fields '(title author publisher date type doi wayback dead))
  (define m (hash-ref link-meta-cache (string->symbol url) (hasheq)))
  (for/hasheq ([(k v) (in-hash m)])
    (unless (memq k fields)
      (build-error "data/link-meta.json: ~a has unknown field ~a (allowed: ~a)" url k fields))
    (values k v)))

(define (back-link href label) `(a ((class "back") (href ,href) (aria-label ,label)) "↩"))

;; ◊link: external ↗, cross-essay →, same-page ↑/↓ (direction set later).
(define (resolve-link x kids)
  (define href (attr-ref x 'href))
  (define data (filter (λ (a) (regexp-match? #rx"^data-" (symbol->string (car a)))) (get-attrs x)))
  (cond
    [(regexp-match? #rx"^https?://" href)
     ;; CARD-4: facts from data/link-meta.json; attributes in the tag win
     (define meta (for/list ([(k v) (in-hash (link-meta href))]
                             #:unless (assq (string->symbol (format "data-~a" k)) data))
                    (list (string->symbol (format "data-~a" k)) (format "~a" v))))
     `(a ((class "link ext") (href ,href) ,@data ,@meta) ,@(with-mark kids 'ext))]
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
                                         (if commentary (list " " commentary) null))
                               key first?)
                         notes))
       ;; CITE-1: the number belongs to the note; the text gets a circle.
       `(od-ann ((kind "note") (target ,(format "note-~a" n)) (label ,(format "note ~a" n))))]
      [(? (tag? 'od-aside))
       (set! aside-n (add1 aside-n))
       (define i aside-n)
       ;; note numbering continues inside the aside, at its place in the argument
       (define body (map walk (get-elements x)))
       (set! asides (cons (list i body) asides))
       ;; ASIDE-2: unnumbered. ASIDE-1: the inline copy, which the script lifts
       ;; into the margin, travels with the circle.
       `(od-ann ((kind "aside") (target ,(format "aside-~a" i)) (label "aside"))
                (span ((class "aside") (id ,(format "aside-text-~a" i)) (hidden "")) ,@(map strip-ids body)))]
      [(? (tag? 'od-term))
       (define id (attr-ref x 'ref))
       (term-ref id)
       (define first? (not (hash-ref term-seen id #f)))
       (when first? (hash-set! term-seen id #t) (set! term-order (cons id term-order)))
       (define kids (map walk (get-elements x)))
       (if (or first? (attrs-have-key? x 'force))  ; TERM-5
           (term-link id kids)
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
              `(od-ann ((kind "ref") (target ,(string-append "bib-" key)) (label "reference")))]
             [(? (tag? 'od-term))   ; TERM-7
              (define tid (attr-ref x 'ref))
              (term-ref tid)
              (set! more-ids (cons tid more-ids))
              (term-link tid (map def-walk (get-elements x)))]
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
                 (p ((class "definition")) (dfn ,(hash-ref t 'term)) ". " ,@definition)
                 ,@(if more `((div ((class "term-more")) ,@more)) null)
                 ,@(if (null? see) null
                       `((p ((class "see-also")) "See also: "
                            ,@(add-between
                               (for/list ([s (in-list see)])
                                 (term-link s (list (hash-ref (term-ref s) 'term))))
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
                             `(ul ((class "asides"))
                                  ,@(for/list ([a (in-list (reverse asides))])
                                      (match-define (list i elems) a)
                                      `(li ((id ,(format "aside-~a" i)))
                                           ,@elems " "
                                           (od-back ((target ,(format "aside-~a" i)) (label "Back to the aside in the text"))))))))
             (and (pair? notes)
                  (endmatter "notes" "Notes"
                             `(ol ((class "notes"))
                                  ,@(for/list ([nt (in-list (reverse notes))])
                                      (match-define (list n elems key first?) nt)
                                      `(li ((id ,(format "note-~a" n)) (value ,(number->string n))
                                            (data-bib ,(string-append "bib-" key))
                                            (data-form ,(if first? "full" "short")))
                                           ,@elems " "
                                           (od-back ((target ,(format "note-~a" n)) (label ,(format "Back to note ~a in the text" n)))))))))
             (and (positive? (hash-count bib-keys))
                  (endmatter "bibliography" "Bibliography"
                             `(ul ((class "bibliography"))
                                  ,@(for/list ([k (in-list (sort (hash-keys bib-keys) < #:key bib-order))])
                                      `(li ((id ,(string-append "bib-" k))) ,@(bib-entry k)))))))))
  (append body end))

;; A first-use term: its text links to its definition, with a circle.
(define (term-link id kids)
  `(a ((class "term") (href ,(format "#term-~a" id))) ,@kids
      (od-ann ((kind "term") (target ,(format "term-~a" id)) (label "definition")))))

(define (ann? x) ((tag? 'od-ann) x))
(define (term-with-ann? x)
  (and ((tag? 'a) x) (has-class? x "term") (pair? (get-elements x)) (ann? (last (get-elements x)))))
(define (annotation? x) (or (ann? x) (term-with-ann? x)))
(define (blank? x) (and (string? x) (regexp-match? #px"^\\s*$" x)))

;; MARK-1/1b/1c: turn annotation placeholders into circles. Annotations with
;; nothing but whitespace between them share one circle, which names and
;; opens all of them; without JS it links to the first (D8). Each visible
;; circle gets an id, and the ↩ back-links in the end matter point to it
;; (CITE-4). Circles inside the hidden inline copies of asides get no ids.
(define (render-circles doc)
  (define circle-ids (make-hash))   ; target → id of the circle that opens it
  (define counter 0)
  (define (circle-span) '(span ((class "circle"))))
  (define (walk x hidden?)
    (if (txexpr? x)
        (let ([h (or hidden? (attrs-have-key? x 'hidden))])
          (txexpr (get-tag x) (get-attrs x) (process (get-elements x) h)))
        x))
  (define (process els hidden?)
    (let loop ([els els] [out '()])
      (match els
        ['() (reverse out)]
        [(cons (? annotation? a) rest)
         (define-values (members rest*) (collect (list a) rest))
         (loop rest* (append (reverse (render-group members hidden?)) out))]
        [(cons e rest) (loop rest (cons (walk e hidden?) out))])))
  ;; members: annotations, with any whitespace strings between them kept
  (define (collect acc rest)
    (match rest
      [(list* (? blank? b) (? annotation? next) more) (collect (append acc (list b next)) more)]
      [(cons (? annotation? next) more) (collect (append acc (list next)) more)]
      [_ (values acc rest)]))
  (define (ann-of m) (if (ann? m) m (last (get-elements m))))
  (define (register! anns hidden?)
    (cond
      [hidden? #f]
      [else (set! counter (add1 counter))
            (define cid (format "ref-~a" counter))
            (for ([a (in-list anns)]) (hash-ref! circle-ids (attr-ref a 'target) cid))
            cid]))
  (define (render-group members hidden?)
    (define anns (map ann-of (filter annotation? members)))
    (define targets (string-join (map (λ (a) (attr-ref a 'target)) anns)))
    (define label (string-join (map (λ (a) (attr-ref a 'label)) anns) ", "))
    (define kinds (string-join (remove-duplicates (map (λ (a) (attr-ref a 'kind)) anns))))
    (define extras (append-map (λ (a) (map (λ (e) (walk e #t)) (get-elements a))) anns)) ; hidden aside copies
    (define cid (register! anns hidden?))
    (cond
      ;; a lone term: text and circle are one link (MARK-6)
      [(and (= (length members) 1) (term-with-ann? (car members)))
       (define t (car members))
       (define kids (map (λ (e) (walk e hidden?)) (drop-right (get-elements t) 1)))
       (define-values (init word) (split-last-word kids))
       (list (txexpr 'a (append (get-attrs t) `((data-targets ,targets) (data-kinds ,kinds))
                                (if cid `((id ,cid)) null))
                     (append init
                             (list `(span ((class "nw")) ,@word ,WJ ,(circle-span)
                                          ,(visually-hidden " (definition)"))))))]
      [else
       ;; terms keep their text links; one circle follows the group
       (define shown
         (for/list ([m (in-list members)])
           (if (term-with-ann? m)
               (txexpr 'a (get-attrs m) (map (λ (e) (walk e hidden?)) (drop-right (get-elements m) 1)))
               m)))
       (define visible (filter (λ (m) (not (ann? m))) shown))
       (define circle
         `(a ((class "circle-link") (href ,(string-append "#" (attr-ref (car anns) 'target)))
              ,@(if cid `((id ,cid)) null)
              (aria-label ,label) (data-targets ,targets) (data-kinds ,kinds))
             ,(circle-span)))
       (append (drop-right-blank visible) (list (od-bind circle)) extras)]))
  (define (drop-right-blank xs) (if (and (pair? xs) (blank? (last xs))) (drop-right xs 1) xs))
  (define rendered (walk doc #f))
  ;; CITE-4: back-links to the circle that opens each item
  (let fix ([x rendered])
    (cond
      [((tag? 'od-back) x)
       (define target (attr-ref x 'target))
       (back-link (string-append "#" (hash-ref circle-ids target
                                               (λ () (build-error "no circle for ~a" target))))
                  (attr-ref x 'label))]
      [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map fix (get-elements x)))]
      [else x])))

;; A circle to be bound to the word before it.
(define (od-bind circle) `(od-bind () ,circle))

;; MARK-3: bind each circle to the word before it, so it never wraps alone.
(define (bind-circles x)
  (cond
    [(txexpr? x)
     (define els (map bind-circles (get-elements x)))
     (txexpr (get-tag x) (get-attrs x)
             (let loop ([done '()] [rest els])
               (match rest
                 ['() (reverse done)]
                 [(cons (? (tag? 'od-bind) b) more)
                  (define circle (car (get-elements b)))
                  (cond
                    [(and (pair? done) (not (block-txexpr? (car done))) (not (blank? (car done))))
                     (define-values (init word) (split-last-word (list (car done))))
                     (loop (cons `(span ((class "nw")) ,@word ,WJ ,circle) (append (reverse init) (cdr done))) more)]
                    [else (loop (cons circle done) more)])]
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

;; IMG-7: figures and tables are numbered in document order, each kind on
;; its own ("Figure 1", "Table 1"); ◊ref becomes a link carrying the label.
(define (number-exhibits elems)
  (define counts (make-hash))
  (define labels (make-hash))
  (define (fill x label)
    (let walk ([x x])
      (cond [(has-class? x "exhibit-label") (txexpr (get-tag x) (get-attrs x) (list label))]
            [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
            [else x])))
  (define numbered
    (for/list ([e (in-list elems)])
      (let walk ([x e])
        (cond
          [(has-class? x "exhibit")
           (define kind (attr-ref x 'data-kind))
           (define n (add1 (hash-ref counts kind 0)))
           (hash-set! counts kind n)
           (define label (format "~a\u00A0~a" (if (equal? kind "table") "Table" "Figure") n))
           (hash-set! labels (attr-ref x 'id) label)
           (fill x label)]
          [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
          [else x]))))
  (for/list ([e (in-list numbered)])
    (let walk ([x e])
      (cond
        [((tag? 'od-ref) x)
         (define id (attr-ref x 'target))
         (define label (hash-ref labels id (λ () (build-error "◊ref ~s: no figure or table with that id on this page" id))))
         (link (string-append "#" id) `(span ((class "exhibit-ref")) ,label))]
        [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
        [else x]))))

;; IMG-1: the first figure loads eagerly; the rest lazily.
(define (eager-first-image doc)
  (define done #f)
  (let walk ([x doc])
    (cond
      [(and (not done) ((tag? 'img) x)) (set! done #t)
       (txexpr 'img (filter (λ (a) (not (eq? (car a) 'loading))) (get-attrs x)) null)]
      [(txexpr? x) (txexpr (get-tag x) (get-attrs x) (map walk (get-elements x)))]
      [else x])))

;; MARK-3a: punctuation after a mark goes before it ("elsewhere.°", not
;; "elsewhere°."), inside the no-wrap span, so word, punctuation and mark
;; never part. Inside a link the punctuation keeps the text colour (CSS).
(define trailing-punct #px"^[,.;:!?…)\\]’”»]+")

(define (mark-el? x)
  (or (has-class? x "mark") (has-class? x "circle") (has-class? x "circle-link")))

(define (ends-with-mark? x)
  (and (txexpr? x)
       (or (has-class? x "nw")
           (let ([els (get-elements x)]) (and (pair? els) (ends-with-mark? (last els)))))))

;; Put the punctuation into the .nw span that ends x, before its mark.
(define (push-punct x p)
  (define els (get-elements x))
  (cond
    [(has-class? x "nw")
     (define-values (word marks) (splitf-at els (λ (e) (not (mark-el? e)))))
     (define-values (word* wj)
       (match (and (pair? word) (last word))
         [(? string? s) #:when (string-suffix? s WJ)
          (values (append (drop-right word 1)
                          (let ([t (substring s 0 (- (string-length s) (string-length WJ)))])
                            (if (equal? t "") null (list t))))
                  (list WJ))]
         [_ (values word null)]))
     (txexpr (get-tag x) (get-attrs x) (append word* (list `(span ((class "punct")) ,p)) wj marks))]
    [else (txexpr (get-tag x) (get-attrs x) (append (drop-right els 1) (list (push-punct (last els) p))))]))

(define (bind-punctuation doc)
  (let walk ([x doc])
    (if (txexpr? x)
        (txexpr (get-tag x) (get-attrs x)
                (let loop ([els (map walk (get-elements x))])
                  (match els
                    [(list* (? ends-with-mark? m) (? string? s) rest)
                     #:when (regexp-match? trailing-punct s)
                     (define p (car (regexp-match trailing-punct s)))
                     (define after (substring s (string-length p)))
                     (cons (push-punct m p)
                           (loop (if (equal? after "") rest (cons after rest))))]
                    [(cons e rest) (cons e (loop rest))]
                    ['() '()])))
        x)))

(define (check-essay-metas)
  ;; VAL-1: essays need their meta fields.
  (define p (source-path))
  (when (and p (essay-source? p))
    (for ([k '(title status published)])
      (unless (select-from-metas k (current-metas))
        (build-error "missing ◊define-meta[~a]" k)))
    (define status (string-trim (format "~a" (select-from-metas 'status (current-metas)))))
    (unless (member status essay-statuses)
      (build-error "status must be one of ~a (got ~s)" (string-join essay-statuses ", ") status))
    (format-date (format "~a" (select-from-metas 'published (current-metas))))))

(define (glossary-root elems)
  (define flat (prepare elems))
  (check-headings-top-level flat)
  (forbid flat '(od-aside od-margin) "a glossary definition")
  (when (pair? (find-all flat heading?)) (build-error "a glossary definition cannot contain headings"))
  (txexpr 'root null flat))

(define (page-root elems)
  (check-essay-metas)
  (let ([t (and (current-metas) (select-from-metas 'tags (current-metas)))]) (when t (parse-tags t)))
  (define flat (prepare elems))
  (check-headings-top-level flat)
  (forbid flat '(od-more) "an essay")
  (for ([a (in-list (find-all flat (tag? 'od-aside)))])
    (forbid (get-elements a) '(od-aside od-margin) "◊aside"))
  (define lifted (lift-margin-notes flat))
  (when (pair? (find-all lifted (tag? 'od-margin)))
    (build-error "◊margin must open its paragraph"))
  (define-values (nested toc-entries) (nest-sections (mark-intro (number-exhibits lifted))))
  (define toc (make-toc toc-entries))
  ;; TOC-1: after the abstract (in the header) and any epigraph, before the text.
  (define-values (epigraphs body)
    (splitf-at nested (λ (x) (has-class? x "epigraph"))))
  (define annotated (annotate (append epigraphs (if toc (list toc) null) body)))
  (define doc (eager-first-image (bind-punctuation (bind-circles (render-circles (set-directions (txexpr 'root null annotated)))))))
  (check-unique-ids doc)
  doc)

;; ---------------------------------------------------------------------------
;; The home page (§13a): every listed page as a table, newest first.

;; INDEX-1: a page is listed when it has a `published` date and is not a draft.
(define (index-entries ptree)
  (for*/list ([node (in-list (pagetree->list (get-pagetree (project-file ptree))))]
              [out (in-value (symbol->string node))]
              #:unless (equal? out "index.html")
              [src (in-value (project-file (string-append out ".pm")))]
              #:when (file-exists? src)
              [metas (in-value (get-metas src))]
              [published (in-value (select-from-metas 'published metas))]
              #:when published
              #:when (published? src (string-trim (format "~a" (or (select-from-metas 'status metas) "")))))
    (define pub (string-trim (format "~a" published)))
    (define revised (revised-date src))
    (define title (select-from-metas 'title metas))
    (hasheq 'url (output->url out)
            'title (string-trim (if (string? title) title (text-of title)))
            'published pub
            ;; INDEX-2: never revised since publication → the publication date
            'reviewed (if (and revised (string>? revised pub)) revised pub)
            'tags (let ([t (select-from-metas 'tags metas)]) (if t (parse-tags t) null)))))

;; "2026-10-01" → "1 Oct 2026", for table columns; on a phone it may break
;; before the year only
(define (format-date-short iso)
  (define parts (string-split (format-date iso)))
  (format "~a\u00A0~a ~a" (car parts) (substring (cadr parts) 0 3) (caddr parts)))

(define (date-cell iso)
  `(td ((class "date") (data-sort ,iso)) (time ((datetime ,iso)) ,(format-date-short iso))))

;; #:pagetree is for the tests.
(define (essay-index #:pagetree [ptree "index.ptree"])
  (define entries (sort (index-entries ptree) string>? #:key (λ (e) (hash-ref e 'published))))
  `(div ((class "essay-index"))
        (div ((class "table-wrap w-column size-normal"))
             (div ((class "table-scroll") (tabindex "0") (role "region") (aria-label "Essays"))
                  (table ((class "index-table") (data-sortable ""))
                         (thead (tr (th ((scope "col")) "Title")
                                    (th ((scope "col")) "Date published")
                                    (th ((scope "col")) "Last review")
                                    (th ((scope "col") (data-nosort "") (data-tag-filter "")) "Tags")))
                         (tbody
                          ,@(for/list ([e (in-list entries)])
                              `(tr ((data-tags ,(string-join (hash-ref e 'tags) "|")))
                                   (td ((class "title")) (a ((href ,(hash-ref e 'url))) ,(hash-ref e 'title)))
                                   ,(date-cell (hash-ref e 'published))
                                   ,(date-cell (hash-ref e 'reviewed))
                                   (td ((class "tags"))
                                       ,@(add-between (for/list ([t (in-list (hash-ref e 'tags))])
                                                        `(span ((class "tag")) ,t))
                                                      ", "))))))))))

;; NAV-1: the menu at the top left. Items live here, once.
(define menu-items '(("Home" "/") ("About" "/about")))

(define (site-menu metas)
  (define here (select-from-metas 'here-path metas))
  (define url (and here (output->url (path->string (path-replace-extension
                                                    (find-relative-path (current-project-root) (string->path (format "~a" here)))
                                                    #""))))) 
  (->html
   `(details ((class "site-menu"))
             (summary (span ((class "site-name")) "Occurrent Development")
                      (svg ((class "chevron") (viewBox "0 0 12 12") (aria-hidden "true"))
                           (path ((d "M2.5 4.5 6 8l3.5-3.5") (fill "none") (stroke "currentColor")
                                  (stroke-width "1.3") (stroke-linecap "round") (stroke-linejoin "round")))))
             (nav ((aria-label "Site"))
                  (ul ,@(for/list ([item (in-list menu-items)])
                          `(li (a ,(append `((href ,(cadr item)))
                                           (if (equal? url (cadr item)) '((aria-current "page")) null))
                                  ,(car item)))))))))

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
;; PERF-2: scripts are cached for a year, so their URL carries a content hash.
(define (asset-url rel)
  (define f (project-file rel))
  (format "/~a?v=~a" rel (substring (call-with-input-file f sha1) 0 10)))

(define (specimen? metas) (and (select-from-metas 'specimen metas) #t))
(define (specimen-css) (file->string files:specimen-css))

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

;; TOC-2: pages with contents get a left margin for them when wide.
(define (has-toc? doc) (pair? (find-all doc (λ (x) (has-class? x "toc")))))

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
