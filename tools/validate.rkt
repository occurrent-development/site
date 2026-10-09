#lang racket/base
;; Site-wide checks after rendering (§12). Run from the repository root.
;;
;; - LINK-2: every cross-page link points to a page and section that exist.
;; - VAL-2: writes data/anchors.json (pages → sections, for validation and
;;   Emacs completion) and data/links.json (the internal link graph).
;; - VAL-3: a section id published in the last deploy (data/anchors-deployed.json,
;;   fetched by CI) must not disappear while a page links to it.
;; - TERM-6: warns about glossary terms no page uses.

(require racket/list
         racket/string
         racket/match
         racket/path
         racket/file
         json
         txexpr
         pollen/core
         pollen/pagetree
         (only-in "../lib/util.rkt" text-of))

(define errors 0)
(define (fail fmt . args) (set! errors (add1 errors)) (eprintf "build error: ~a\n" (apply format fmt args)))
(define (warn fmt . args) (eprintf "warning: ~a\n" (apply format fmt args)))

;; Output path in the pagetree → (values url source)
(define (page-info node)
  (define out (symbol->string node))
  (define url
    (match out
      ["index.html" "/"]
      [(regexp #px"^(?:pages|essays/[^/]+)/([a-z0-9-]+)\\.html$" (list _ slug)) (string-append "/" slug)]
      [_ (string-append "/" (regexp-replace #rx"\\.html$" out ""))]))
  (values url (string->path (string-append out ".pm"))))

(define (find-all x pred)
  (if (txexpr? x)
      (append (if (pred x) (list x) null) (append-map (λ (e) (find-all e pred)) (get-elements x)))
      null))

(define (class? x c)
  (and (attrs-have-key? x 'class) (member c (string-split (attr-ref x 'class))) #t))

(define pages
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
    (hasheq 'url url 'src src 'title (or (select-from-metas 'title (get-metas src)) "")
            'sections sections 'ids ids 'xrefs xrefs 'terms terms)))

(define by-url (for/hash ([p (in-list pages)]) (values (hash-ref p 'url) p)))

;; LINK-2 and the link graph
(define links
  (for*/list ([p (in-list pages)] [href (in-list (hash-ref p 'xrefs))])
    (match-define (list _ path frag) (regexp-match #px"^([^#]*)(?:#(.*))?$" href))
    (define target (hash-ref by-url path #f))
    (cond
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

(unless (zero? errors) (exit 1))
(printf "validate: ~a pages, ~a internal links\n" (length pages) (length links))
