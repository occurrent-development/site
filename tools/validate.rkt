#lang racket/base
;; Site-wide checks and the link graph (§12). Run from the repository root,
;; before `raco pollen render`: the graph it writes is what Backlinks, the
;; reference pages, the glossary and the bibliography are rendered from.
;;
;; - VAL-2, VAL-4, BIB-6: the one walk. For every published post of both
;;   kinds (and the specimen, a page listed in the essay index by its date):
;;   every internal link with its context, every citation with its context,
;;   every quotation (BIB-9), the terms each page marks (TERM-8) and its
;;   changelog lines (REV-3). Written to data/links.json (shape in
;;   lib/graph.rkt) only when it changes: it is in Pollen's cache
;;   watchlist, so a change re-renders every page. Drafts go to
;;   data/links.local.json, read only by the project server's preview.
;; - LINK-2: every cross-page link points to a page and section that exist.
;; - VAL-2: writes data/anchors.json (pages → sections, for validation and
;;   Emacs completion).
;; - VAL-3: a section id published in the last deploy (data/anchors-deployed.json,
;;   fetched by CI) must not disappear while a page links to it.
;; - TERM-6: warns about glossary terms no page uses.
;; - POP-7: writes build/_x/<slug>/<id>.frag, one fragment per section (and
;;   _page.frag with the title, abstract and the body's opening), fetched by cross-page popups,
;;   and BIB-8's build/_x/references/<key>.frag, the reference card.
;;   Not .html: Cloudflare's HTML handling would redirect those.
;; - BIB-1: writes build/references/<key>.html.pm, one line of source per
;;   work in the citation cache, which `make` then renders.
;; - REV-4: writes build/feed.xml, the Atom feed.
;; - DRAFT-2: writes data/publish.txt, the pages `make` copies into public/:
;;   every page, and essays whose status is not draft. A published page may
;;   not link to a draft.
;;
;; Two runs, two processes: `--graph` walks the posts and writes the graph
;; and the reference sources; the second run, without it, does the rest.
;; Pollen keeps one instance of every page in a process, so pages read after
;; the graph changed, in the process that changed it, would be the stale
;; ones; a new process reads them afresh. `make serve` runs only the first.

(require racket/list
         racket/string
         racket/match
         racket/path
         racket/file
         racket/cmdline
         json
         txexpr
         xml
         pollen/core
         pollen/pagetree
         (only-in pollen/template ->html)
         (only-in "../lib/util.rkt" text-of published? output->url check-post-slugs post-kind site-value)
         "../lib/walk.rkt"
         (only-in "../lib/cite.rkt" cite-keys cite-key-known? cite-facts)
         (only-in "../pollen.rkt" reference-card format-date)
         (only-in "../lib/glossary.rkt" draft-term-ids))

(define graph-only? (make-parameter #f))
(command-line #:once-each [("--graph") "Write the link graph and reference sources only" (graph-only? #t)])

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
  (and (txexpr? x) (attrs-have-key? x 'class) (member c (string-split (attr-ref x 'class))) #t))

(define (meta-text metas k)
  (define v (select-from-metas k metas))
  (and v (string-trim (if (string? v) v (text-of v)))))

(define (write-json-file path v)
  (call-with-output-file path #:exists 'replace (λ (o) (write-json v o #:indent 1) (newline o))))

;; Write only when the contents change: the graph is in Pollen's watchlist.
(define (write-if-changed path s)
  (unless (and (file-exists? path) (equal? (file->string path) s))
    (call-with-output-file path #:exists 'replace (λ (o) (void (write-string s o))))))

;; ---------------------------------------------------------------------------
;; Pages, posts and drafts

(define nodes (pagetree->list (get-pagetree "index.ptree")))

;; Every post's source: essays/<slug>/<slug>.html.pm and blog/<slug>/<slug>.html.pm.
(define post-sources
  (for*/list ([dir (in-list '("essays" "blog"))] #:when (directory-exists? dir)
              [f (in-directory dir (λ (d) (not (regexp-match? #rx"/support$" (path->string d)))))]
              #:when (regexp-match? #px"^(?:essays|blog)/[^/]+/[^/.][^/]*\\.html\\.pm$" (path->string f)))   ; not Emacs's .# lock files
    f))

;; A post's status. A draft that does not build yet (DRAFT-E1: a draft is
;; work in progress) is read from its source text, so it cannot stop `make`.
(define (status-of src)
  (with-handlers ([exn:fail?
                   (λ (e)
                     (define m (regexp-match #px"◊define-meta\\[status\\]\\{\\s*([a-z]+)\\s*\\}" (file->string (path->string src))))
                     (define st (and m (cadr m)))
                     (unless (equal? st "draft") (raise e))
                     st)])
    (let ([s (select-from-metas 'status (get-metas src))]) (and s (string-trim (format "~a" s))))))

;; A page in the graph: a post, or a page listed in the essay index by its date.
(define (graph-source? src)
  (or (post-kind src) (and (select-from-metas 'published (get-metas src)) #t)))

(define (walk-all sources)
  (for/list ([s (in-list sources)])
    (match-define (list url src) s)
    (define-values (post links cites terms changes) (walk-page url src (get-doc src)))
    (list url post links cites terms changes)))

;; The published graph sources (DRAFT-2) and the drafts, in and out of the pagetree.
(define-values (graph-published graph-drafts)
  (let ()
    (define in-tree
      (for/list ([node (in-list nodes)])
        (define-values (url src) (page-info node))
        (list url src)))
    (define srcs (filter (λ (s) (graph-source? (second s))) in-tree))
    (define listed (map (λ (s) (path->string (second s))) in-tree))
    (define loose   ; drafts not yet in index.ptree (DRAFT-E1)
      (for/list ([f (in-list post-sources)]
                 #:unless (member (path->string f) listed)
                 #:when (equal? (status-of f) "draft"))
        (list (output->url (regexp-replace #rx"\\.pm$" (path->string f) "")) f)))
    (partition (λ (s) (published? (second s) (status-of (second s)))) (append srcs loose))))

(define published-graph
  (cond
    [(graph-only?)
     (define g (graph-of (walk-all graph-published)))
     (make-directory* "data")
     (write-if-changed (build-path "data" "links.json") (jsexpr->string g #:indent 1))
     g]
    [else (call-with-input-file (build-path "data" "links.json") read-json)]))
;; a draft that does not build yet keeps nothing from the preview
(when (graph-only?)
  (write-if-changed (build-path "data" "links.local.json")
                    (jsexpr->string
                     (graph-of (filter values (for/list ([d (in-list graph-drafts)])
                                                (with-handlers ([exn:fail? (λ (e) (warn "~a: not in the drafts' graph: ~a" (second d) (exn-message e)) #f)])
                                                  (car (walk-all (list d)))))))
                     #:indent 1)))

;; ---------------------------------------------------------------------------
;; BIB-1, BIB-3: a source per work; a commentary must be for a cited work

(define ref-dir (build-path "build" "references"))
(make-directory* ref-dir)
(define ref-keys (cite-keys))
(define (cite-facts-title key) (hash-ref (cite-facts key) 'title))
(for ([f (in-list (directory-list ref-dir))]
      #:when (regexp-match? #rx"\\.html\\.pm$" (path->string f))
      #:unless (member (regexp-replace #rx"\\.html\\.pm$" (path->string f) "") ref-keys))
  (delete-file (build-path ref-dir f)))
(for ([key (in-list ref-keys)])
  ;; the commentary's text is part of the source, so editing it re-renders the page
  (define com (build-path "references" (string-append key ".pm")))
  (write-if-changed (build-path ref-dir (string-append key ".html.pm"))
                    (format "#lang pollen\n◊; Generated by tools/validate.rkt (BIB-1); not committed.\n◊; commentary: ~a\n◊define-meta[title ~s]\n◊define-meta[reference ~s]\n◊reference-page[~s]\n"
                            (if (file-exists? com) (equal-hash-code (file->string com)) "none")
                            (cite-facts-title key) key key)))
;; Does any essay or entry source, a draft's included, cite KEY?
(define (cited-in-source? key)
  (define needle (string-append "\"" key "\""))
  (for*/or ([dir (in-list '("essays" "blog"))] #:when (directory-exists? dir)
            [sub (in-list (directory-list dir #:build? #t))] #:when (directory-exists? sub)
            [f (in-list (directory-list sub #:build? #t))] #:when (regexp-match? #rx"[.]pm$" (path->string f)))
    (string-contains? (file->string f) needle)))
(when (directory-exists? "references")
  (for ([f (in-list (directory-list "references"))] #:when (regexp-match? #rx"\\.pm$" (path->string f)))
    (define key (regexp-replace #rx"\\.pm$" (path->string f) ""))
    (unless (or (cite-key-known? key) (cited-in-source? key))
      ;; (a work only a draft cites has no page yet and its commentary waits for it)
      ;; an empty stub (made by `make refresh`) for a work no page cites any more is
      ;; harmless; a commentary with text in it is never silently orphaned
      (define empty? (for/and ([l (in-list (file->lines (build-path "references" f)))])
                       (or (regexp-match? #px"^\\s*$" l) (regexp-match? #rx"^#lang " l) (regexp-match? #rx"^◊;" l))))
      (if empty?
          (warn "references/~a: no published page cites ~s now; the empty file can be deleted" f key)
          (fail "references/~a: no published page cites ~s, so it has no page; check the key, or run `make refresh` (BIB-3)" f key)))))
(call-with-output-file (build-path ref-dir "index.ptree") #:exists 'replace
  (λ (o) (fprintf o "#lang pollen\n~a\n" (string-join (map (λ (k) (string-append k ".html")) ref-keys) "\n"))))

(when (graph-only?)
  (unless (zero? errors) (exit 1))
  (printf "validate: the graph, ~a reference sources\n" (length ref-keys))
  (exit 0))

;; ---------------------------------------------------------------------------
;; Every page, rendered now that the graph is written

;; ASIDE-9, VAL-2: every ◊anchor on a page, an empty span whose only attribute
;; is its id. One in an aside is found in the Asides list, the copy that holds
;; the id. Each comes with its block (the paragraph, list item or aside it
;; stands in) for the picker's context and the popup's extract (POP-7).
(define (anchor-span? x)
  (and (txexpr? x) (eq? (get-tag x) 'span) (null? (get-elements x))
       (equal? (map car (get-attrs x)) '(id))))
(define (aside-li? x)
  (and (txexpr? x) (eq? (get-tag x) 'li) (regexp-match? #rx"^aside-[0-9]+$" (attr-ref x 'id ""))))
(define (anchors-of doc)
  (define out '())
  (let walk ([x doc] [anc '()])
    (when (txexpr? x)
      (if (anchor-span? x)
          (let* ([aside (findf aside-li? anc)]
                 [block (or aside (findf (λ (a) (memq (get-tag a) '(li p blockquote figure))) anc))])
            (set! out (cons (hasheq 'id (attr-ref x 'id) 'aside (and aside #t) 'block block) out)))
          (for ([k (in-list (get-elements x))]) (walk k (cons x anc))))))
  (reverse out))
(define (anchor-context block)
  (define t (if block (string-normalize-spaces (text-of block)) ""))
  (if (> (string-length t) 70) (string-append (substring t 0 70) "…") t))

(define all-pages
  (for/list ([node (in-list nodes)])
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
    ;; links in the text: the end matter's Backlinks and reference links are the build's own
    (define body (filter (λ (x) (not (class? x "endmatter"))) (get-elements doc)))
    (define xrefs (for*/list ([e (in-list body)]
                              [a (in-list (find-all e (λ (x) (and (eq? (get-tag x) 'a) (class? x "xref")))))])
                    (attr-ref a 'href)))
    (hasheq 'url url 'src src 'doc doc 'out (symbol->string node) 'title (or (meta-text (get-metas src) 'title) "")
            'published (published? src (status-of src))
            'sections sections 'anchors (anchors-of doc) 'ids ids 'xrefs xrefs)))

;; KIND-1: one slug, one post, across both folders; none of the site's own paths.
(for ([e (in-list (check-post-slugs
                   (for/list ([f (in-list post-sources)])
                     (cons (cadr (regexp-match #px"/([^/]+)\\.html\\.pm$" (path->string f))) (path->string f)))
                   (for/list ([f (in-list (directory-list "pages"))]
                              #:when (regexp-match? #rx"\\.html\\.pm$" (path->string f)))
                     (cadr (regexp-match #px"^([^/]+)\\.html\\.pm$" (path->string f))))))])
  (fail "~a" e))

;; A post missing from index.ptree would be neither rendered nor listed.
;; A draft is the exception (DRAFT-E1: drafts sit at their final path, kept
;; out of git, and od-publish adds the index.ptree line), so it only warns.
(let ()
  (define listed (for/list ([p (in-list all-pages)]) (path->string (hash-ref p 'src))))
  (for ([f (in-list post-sources)]
        #:unless (member (path->string f) listed))
    (if (equal? (status-of f) "draft")
        (warn "~a is a draft and not in index.ptree, so it is not built (od-publish adds it)" f)
        (fail "~a is not in index.ptree" f))))

(define pages (filter (λ (p) (hash-ref p 'published)) all-pages))
(define drafts (for/hash ([p (in-list all-pages)] #:unless (hash-ref p 'published)) (values (hash-ref p 'url) p)))

(define by-url (for/hash ([p (in-list pages)]) (values (hash-ref p 'url) p)))

;; LINK-2: every cross-page link resolves; a work's page exists for every
;; work in the cache (BIB-1)
(define links
  (for*/list ([p (in-list pages)] [href (in-list (hash-ref p 'xrefs))])
    (match-define (list _ path frag) (regexp-match #px"^([^#]*)(?:#(.*))?$" href))
    (define target (hash-ref by-url path #f))
    (define ref (regexp-match #px"^/references/(.+)$" path))
    (cond
      [ref (unless (member (cadr ref) ref-keys)
             (fail "~a: link to ~a, but no published page cites ~s" (hash-ref p 'src) href (cadr ref)))]
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
    ;; an anchor is as permanent as a section (ASIDE-9); deploys before
    ;; 2026-11-09 list none, so only later ones are guarded
    (for ([s (in-list (append (hash-ref secs 'sections null) (hash-ref secs 'anchors null)))])
      (define id (hash-ref s 'id))
      (unless (and now (member id (hash-ref now 'ids)))
        (define linked (for/list ([l (in-list links)]
                                  #:when (and (equal? (hash-ref l 'to) (symbol->string url))
                                              (equal? (hash-ref l 'id) id)))
                         (hash-ref l 'from)))
        (if (pair? linked)
            (fail "published anchor ~a#~a has gone, but ~a link to it" url id (string-join linked ", "))
            (warn "published anchor ~a#~a has gone; links to it from elsewhere will break" url id))))))

;; TERM-10: draft terms. A published page may not mark one; an unused draft is no warning.
(define draft-terms (draft-term-ids))
(for* ([(url us) (in-hash (hash-ref published-graph 'terms))]
       [u (in-list us)]
       #:when (member (hash-ref u 'id) draft-terms))
  (fail "~a uses the draft glossary term ~s (set its status to published, or remove the term)" url (hash-ref u 'id)))

;; TERM-6: unused terms
(define used (remove-duplicates (map (λ (u) (hash-ref u 'id)) (append* (hash-values (hash-ref published-graph 'terms))))))
(for ([f (in-list (if (directory-exists? "glossary") (directory-list "glossary") null))]
      #:when (regexp-match? #rx"\\.pm$" (path->string f)))
  (define id (path->string (path-replace-extension f #"")))
  (unless (or (member id used) (member id draft-terms)) (warn "glossary term ~s is not used by any page" id)))

(write-json-file (build-path "data" "anchors.json")
                 (for/hasheq ([p (in-list pages)])
                   (values (string->symbol (hash-ref p 'url))
                           (hasheq 'title (hash-ref p 'title) 'sections (hash-ref p 'sections)
                                   'anchors (for/list ([a (in-list (hash-ref p 'anchors))])
                                              (hasheq 'id (hash-ref a 'id) 'aside (hash-ref a 'aside)
                                                      'context (anchor-context (hash-ref a 'block #f))))))))

;; ---------------------------------------------------------------------------
;; POP-7, BIB-8: fragments for cross-page popups. Circles, self-links and
;; hidden aside copies are dropped: a fragment is read, not explored.

(define (fragment-clean x)
  (cond
    [(txexpr? x)
     (cond
       [(or (class? x "circle-link") (class? x "circle") (class? x "self") (class? x "vh") (class? x "back")
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
  ;; and the body's opening (2026-11-09): what stands between the header and the first section
  ;; (the intro, an epigraph), or, when the page begins with a section, that section
  (define article (let ([as (find-all (hash-ref p 'doc) (λ (x) (eq? (get-tag x) 'article)))]) (and (pair? as) (car as))))
  (define (lead-part? x)
    (and (txexpr? x) (not (memq (get-tag x) '(header nav section))) (not (class? x "abstract"))))
  (define lead
    (if article
        (let ([before (takef (get-elements article) (λ (x) (not (and (txexpr? x) (eq? (get-tag x) 'section)))))])
          (filter values (map fragment-clean (filter lead-part? before))))
        null))
  (define body-ps
    (cond [(pair? lead) lead]
          [article
           (let ([sec (findf (λ (x) (and (txexpr? x) (eq? (get-tag x) 'section) (not (class? x "endmatter"))))
                             (get-elements article))])
             (if sec (list (fragment-clean sec)) null))]
          [else null]))
  (call-with-output-file (build-path dir "_page.frag") #:exists 'replace
    (λ (o) (write-string (->html `(div (h1 ,(or (meta 'title) ""))
                                       ,@(if (meta 'subtitle) `((p ((class "subtitle")) ,(meta 'subtitle))) null)
                                       ,@abstract-ps
                                       ,@body-ps))
                         o)))
  (for ([sec (in-list (find-all (hash-ref p 'doc) (λ (x) (and (eq? (get-tag x) 'section) (attrs-have-key? x 'id)
                                                               (not (class? x "endmatter"))))))])
    (call-with-output-file (build-path dir (string-append (attr-ref sec 'id) ".frag")) #:exists 'replace
      (λ (o) (write-string (->html (fragment-clean sec)) o))))
  ;; ASIDE-9: an anchor's extract is the block it stands in, or its aside
  (for ([a (in-list (hash-ref p 'anchors))] #:when (hash-ref a 'block #f))
    (call-with-output-file (build-path dir (string-append (hash-ref a 'id) ".frag")) #:exists 'replace
      (λ (o) (write-string (->html (fragment-clean (hash-ref a 'block))) o)))))

;; BIB-8: the reference card, the head of each work's page as a fragment
(make-directory* (build-path x-dir "references"))
(for ([key (in-list ref-keys)])
  (call-with-output-file (build-path x-dir "references" (string-append key ".frag")) #:exists 'replace
    (λ (o) (write-string (->html (fragment-clean (reference-card key))) o))))

;; ---------------------------------------------------------------------------
;; REV-4: the Atom feed: new posts of both kinds, and substantive revisions
;; (a changelog line dated after `published`), each marked with its kind.
;; Pages, the specimen among them, are never in it (THEME-7).

(define site (string-trim (site-value 'url) "/" #:left? #f))
(define (stamp iso) (string-append iso "T00:00:00Z"))
(define feed-posts
  (for/list ([p (in-list pages)] #:when (post-kind (hash-ref p 'src)))
    (define metas (get-metas (hash-ref p 'src)))
    (define abstract
      (string-normalize-spaces
       (string-join (map (λ (a) (regexp-replace #rx"^Abstract" (text-of a) ""))
                         (find-all (hash-ref p 'doc) (λ (x) (and (eq? (get-tag x) 'p) (class? x "abstract")))))
                    " ")))
    (hasheq 'url (hash-ref p 'url) 'title (hash-ref p 'title) 'kind (post-kind (hash-ref p 'src))
            'published (meta-text metas 'published)
            'author (or (meta-text metas 'author) (site-value 'author))
            'abstract abstract)))
(define (kind-category k)
  `(category ((term ,(if (eq? k 'entry) "blog" "essay")) (label ,(if (eq? k 'entry) "Blog entry" "Essay")))))
(define feed-entries
  (append
   (for/list ([p (in-list feed-posts)])
     (define url (string-append site (hash-ref p 'url)))
     (cons (hash-ref p 'published)
           `(entry (title ,(hash-ref p 'title))
                   (link ((rel "alternate") (type "text/html") (href ,url)))
                   (id ,url)
                   (published ,(stamp (hash-ref p 'published)))
                   (updated ,(stamp (hash-ref p 'published)))
                   (author (name ,(hash-ref p 'author)))
                   ,(kind-category (hash-ref p 'kind))
                   ,@(if (equal? (hash-ref p 'abstract) "") null `((summary ((type "text")) ,(hash-ref p 'abstract)))))))
   (for*/list ([c (in-list (hash-ref published-graph 'changes))]
               [p (in-value (findf (λ (p) (equal? (hash-ref p 'url) (hash-ref c 'from))) feed-posts))]
               #:when (and p (string>? (hash-ref c 'date) (hash-ref p 'published))))
     (define url (string-append site (hash-ref p 'url)))
     (cons (hash-ref c 'date)
           `(entry (title ,(string-append "Revised: " (hash-ref p 'title)))
                   (link ((rel "alternate") (type "text/html") (href ,(string-append url "#changelog"))))
                   (id ,(format "~a#changelog-~a" url (hash-ref c 'date)))
                   (published ,(stamp (hash-ref c 'date)))
                   (updated ,(stamp (hash-ref c 'date)))
                   (author (name ,(hash-ref p 'author)))
                   ,(kind-category (hash-ref p 'kind))
                   (summary ((type "text")) ,(string-normalize-spaces (text-of (json->tx (hash-ref c 'text))))))))))
(define (json->tx j) (if (string? j) j (list* (string->symbol (car j)) '() (map json->tx (cddr j)))))
(define sorted-entries (sort feed-entries string>? #:key car))
(make-directory* "build")
(call-with-output-file (build-path "build" "feed.xml") #:exists 'replace
  (λ (o)
    (write-string "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" o)
    (write-string
     (xexpr->string
      `(feed ((xmlns "http://www.w3.org/2005/Atom") (xml:lang "en-AU"))
             (title "Occurrent Development")
             (subtitle "Essays and blog entries")
             (link ((rel "self") (type "application/atom+xml") (href ,(string-append site "/feed.xml"))))
             (link ((rel "alternate") (type "text/html") (href ,(string-append site "/"))))
             (id ,(string-append site "/"))
             (updated ,(stamp (if (pair? sorted-entries) (car (car sorted-entries)) "2026-10-01")))
             (author (name ,(site-value 'author)))
             ,@(map cdr sorted-entries)))
     o)
    (newline o)))

;; DRAFT-2: what `make` publishes, as "rendered-file public-name" lines:
;; the pages, every work's page (BIB-1) and the feed (REV-4).
(call-with-output-file (build-path "data" "publish.txt") #:exists 'replace
  (λ (o) (for ([p (in-list pages)])
           (fprintf o "~a ~a\n" (hash-ref p 'out)
                    (if (equal? (hash-ref p 'url) "/") "index.html"
                        (string-append (substring (hash-ref p 'url) 1) ".html"))))
         (for ([k (in-list ref-keys)])
           (fprintf o "build/references/~a.html references/~a.html\n" k k))
         (fprintf o "build/feed.xml feed.xml\n")))

(unless (zero? errors) (exit 1))
(printf "validate: ~a pages published, ~a drafts held back, ~a internal links, ~a works, ~a feed items\n"
        (length pages) (hash-count drafts) (length links) (length ref-keys) (length sorted-entries))
