#lang racket/base
;; Site-wide checks after rendering (§12). Run from the repository root.
;;
;; - LINK-2: every cross-page link points to a page and section that exist.
;; - VAL-2: writes data/anchors.json (pages → sections, for validation and
;;   Emacs completion) and data/links.json (the internal link graph).
;; - VAL-3: a section id published in the last deploy (data/anchors-deployed.json,
;;   fetched by CI) must not disappear while a page links to it.
;; - TERM-6: warns about glossary terms no page uses.
;; - POP-7: writes build/_x/<slug>/<id>.frag, one fragment per section (and
;;   _page.frag with the title and abstract), fetched by cross-page popups.
;;   Not .html: Cloudflare's HTML handling would redirect those.
;; - DRAFT-2: writes data/publish.txt, the pages `make` copies into public/:
;;   every page, and essays whose status is not draft. A published page may
;;   not link to a draft.

(require racket/list
         racket/string
         racket/match
         racket/path
         racket/file
         json
         txexpr
         pollen/core
         pollen/pagetree
         (only-in pollen/template ->html)
         (only-in "../lib/util.rkt" text-of published? output->url))

(define errors 0)
(define (fail fmt . args) (set! errors (add1 errors)) (eprintf "build error: ~a\n" (apply format fmt args)))
(define (warn fmt . args) (eprintf "warning: ~a\n" (apply format fmt args)))

;; Output path in the pagetree → (values url source)
(define (page-info node)
  (define out (symbol->string node))
  (values (output->url out) (string->path (string-append out ".pm"))))

(define (find-all x pred)
  (if (txexpr? x)
      (append (if (pred x) (list x) null) (append-map (λ (e) (find-all e pred)) (get-elements x)))
      null))

(define (class? x c)
  (and (attrs-have-key? x 'class) (member c (string-split (attr-ref x 'class))) #t))

(define all-pages
  (for/list ([node (in-list (pagetree->list (get-pagetree "index.ptree")))])
    (define-values (url src) (page-info node))
    (define doc (get-doc src))
    (define sections
      (for/list ([s (in-list (find-all doc (λ (x) (and (eq? (get-tag x) 'section) (attrs-have-key? x 'id)
                                                       (not (class? x "endmatter"))))))])
        (define heading (car (get-elements s)))
        (hasheq 'id (attr-ref s 'id)
                'title (string-trim (regexp-replace #rx"§$" (text-of heading) ""))
                'level (string->number (substring (attr-ref s 'class) 6)))))
    (define ids (for/list ([x (in-list (find-all doc (λ (x) (attrs-have-key? x 'id))))]) (attr-ref x 'id)))
    (define xrefs (for/list ([a (in-list (find-all doc (λ (x) (and (eq? (get-tag x) 'a) (class? x "xref")))))])
                    (attr-ref a 'href)))
    (define terms (for/list ([a (in-list (find-all doc (λ (x) (and (eq? (get-tag x) 'div) (class? x "term-entry")))))])
                    (substring (attr-ref a 'id) 5)))
    (define status (let ([s (select-from-metas 'status (get-metas src))]) (and s (string-trim (format "~a" s)))))
    (hasheq 'url url 'src src 'doc doc 'out (symbol->string node) 'title (or (select-from-metas 'title (get-metas src)) "")
            'published (published? src status)
            'sections sections 'ids ids 'xrefs xrefs 'terms terms)))

;; An essay missing from index.ptree would be neither rendered nor listed.
;; A draft is the exception (DRAFT-E1: drafts sit at their final path, kept
;; out of git, and od-publish adds the index.ptree line), so it only warns.
(when (directory-exists? "essays")
  (define listed (for/list ([p (in-list all-pages)]) (path->string (hash-ref p 'src))))
  (for ([f (in-directory "essays" (λ (d) (not (regexp-match? #rx"/support$" (path->string d)))))]
        #:when (regexp-match? #px"^essays/[^/]+/[^/]+\\.html\\.pm$" (path->string f))
        #:unless (member (path->string f) listed))
    (define status
      (let ([m (regexp-match #px"◊define-meta\\[status\\]\\{\\s*([a-z]+)\\s*\\}" (file->string (path->string f)))])
        (and m (cadr m))))
    (if (equal? status "draft")
        (warn "~a is a draft and not in index.ptree, so it is not built (od-publish adds it)" f)
        (fail "~a is not in index.ptree" f))))

(define pages (filter (λ (p) (hash-ref p 'published)) all-pages))
(define drafts (for/hash ([p (in-list all-pages)] #:unless (hash-ref p 'published)) (values (hash-ref p 'url) p)))

(define by-url (for/hash ([p (in-list pages)]) (values (hash-ref p 'url) p)))

;; LINK-2 and the link graph
(define links
  (for*/list ([p (in-list pages)] [href (in-list (hash-ref p 'xrefs))])
    (match-define (list _ path frag) (regexp-match #px"^([^#]*)(?:#(.*))?$" href))
    (define target (hash-ref by-url path #f))
    (cond
      [(hash-ref drafts path #f) (fail "~a: link to ~a, which is a draft and will not be published" (hash-ref p 'src) href)]
      [(not target) (fail "~a: link to ~a, which is not a page" (hash-ref p 'src) href)]
      [(and frag (not (member frag (hash-ref target 'ids))))
       (fail "~a: link to ~a, but ~a has no section #~a" (hash-ref p 'src) href path frag)])
    (hasheq 'from (hash-ref p 'url) 'to path 'id (or frag 'null))))

;; VAL-3
(define deployed-file (build-path "data" "anchors-deployed.json"))
(when (file-exists? deployed-file)
  (define deployed (call-with-input-file deployed-file read-json))
  (for ([(url secs) (in-hash deployed)])
    (define now (hash-ref by-url (symbol->string url) #f))
    (for ([s (in-list (hash-ref secs 'sections null))])
      (define id (hash-ref s 'id))
      (unless (and now (member id (hash-ref now 'ids)))
        (define linked (for/list ([l (in-list links)]
                                  #:when (and (equal? (hash-ref l 'to) (symbol->string url))
                                              (equal? (hash-ref l 'id) id)))
                         (hash-ref l 'from)))
        (if (pair? linked)
            (fail "published anchor ~a#~a has gone, but ~a link to it" url id (string-join linked ", "))
            (warn "published anchor ~a#~a has gone; links to it from elsewhere will break" url id))))))

;; TERM-6: unused terms
(define used (remove-duplicates (append-map (λ (p) (hash-ref p 'terms)) pages)))
(for ([f (in-list (if (directory-exists? "glossary") (directory-list "glossary") null))]
      #:when (regexp-match? #rx"\\.pm$" (path->string f)))
  (define id (path->string (path-replace-extension f #"")))
  (unless (member id used) (warn "glossary term ~s is not used by any page" id)))

(define (write-json-file path v)
  (call-with-output-file path #:exists 'replace (λ (o) (write-json v o #:indent 1) (newline o))))

(make-directory* "data")
(write-json-file (build-path "data" "anchors.json")
                 (for/hasheq ([p (in-list pages)])
                   (values (string->symbol (hash-ref p 'url))
                           (hasheq 'title (hash-ref p 'title) 'sections (hash-ref p 'sections)))))
(write-json-file (build-path "data" "links.json") links)

;; POP-7: section fragments for cross-page popups. Circles, self-links and
;; hidden aside copies are dropped: a fragment is read, not explored.
(define (fragment-clean x)
  (cond
    [(txexpr? x)
     (cond
       [(or (class? x "circle-link") (class? x "circle") (class? x "self") (class? x "vh")
            (attrs-have-key? x 'hidden))
        #f]
       [else (txexpr (get-tag x) (filter (λ (a) (not (eq? (car a) 'id))) (get-attrs x))
                     (filter values (map fragment-clean (get-elements x))))])]
    [else x]))

(define x-dir (build-path "build" "_x"))
(when (directory-exists? x-dir) (delete-directory/files x-dir))
(for ([p (in-list pages)] #:unless (equal? (hash-ref p 'url) "/"))
  (define dir (build-path x-dir (substring (hash-ref p 'url) 1)))
  (make-directory* dir)
  (define metas (get-metas (hash-ref p 'src)))
  (define (meta k) (let ([v (select-from-metas k metas)]) (and v (format "~a" v))))
  ;; the page's popup: title, subtitle, and the abstract from the document's header (SRC-4a)
  (define abstract-ps
    (map fragment-clean (find-all (hash-ref p 'doc) (λ (x) (and (eq? (get-tag x) 'p) (class? x "abstract"))))))
  (call-with-output-file (build-path dir "_page.frag") #:exists 'replace
    (λ (o) (write-string (->html `(div (h1 ,(or (meta 'title) ""))
                                       ,@(if (meta 'subtitle) `((p ((class "subtitle")) ,(meta 'subtitle))) null)
                                       ,@abstract-ps))
                         o)))
  (for ([sec (in-list (find-all (hash-ref p 'doc) (λ (x) (and (eq? (get-tag x) 'section) (attrs-have-key? x 'id)
                                                               (not (class? x "endmatter"))))))])
    (call-with-output-file (build-path dir (string-append (attr-ref sec 'id) ".frag")) #:exists 'replace
      (λ (o) (write-string (->html (fragment-clean sec)) o)))))

;; DRAFT-2: what `make` publishes, as "rendered-file public-name" lines.
(call-with-output-file (build-path "data" "publish.txt") #:exists 'replace
  (λ (o) (for ([p (in-list pages)])
           (fprintf o "~a ~a\n" (hash-ref p 'out)
                    (if (equal? (hash-ref p 'url) "/") "index.html"
                        (string-append (substring (hash-ref p 'url) 1) ".html"))))))

(unless (zero? errors) (exit 1))
(printf "validate: ~a pages published, ~a drafts held back, ~a internal links\n"
        (length pages) (hash-count drafts) (length links))
