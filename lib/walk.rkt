#lang racket/base
;; The one walk (VAL-2, VAL-4, BIB-6): what a rendered page contributes to
;; the link graph. tools/validate.rkt runs it over every published post
;; before rendering and writes data/links.json (shape in lib/graph.rkt);
;; the tests run it over fixtures.

(require racket/list
         racket/string
         racket/match
         txexpr
         pollen/core
         (only-in pollen/template ->html)
         "util.rkt")

(provide walk-page graph-of)

(define (find-all x pred)
  (if (txexpr? x)
      (append (if (pred x) (list x) null) (append-map (λ (e) (find-all e pred)) (get-elements x)))
      null))

(define (class? x c)
  (and (txexpr? x) (attrs-have-key? x 'class) (member c (string-split (attr-ref x 'class))) #t))

(define (hasheq* . kvs) (apply hasheq kvs))

(define (meta-text metas k)
  (define v (select-from-metas k metas))
  (and v (string-trim (if (string? v) v (text-of v)))))


;; A context: the paragraph, list item, aside or quotation holding the link
;; or circle, cleaned for another page (no ids, no circles but the one
;; marked, no hidden copies or margin notes, same-page links as text) and
;; with the link marked `graph-here`, or the circles that cite the work
;; marked as `graph-circle`s (all of them, so citations sharing a
;; paragraph share one context, BIB-9).
(define (context-root anc)
  (or (for/first ([a (in-list anc)]
                  #:when (or ((λ (x) (and (attrs-have-key? x 'hidden) (class? x "aside"))) a)
                             (memq (get-tag a) '(p li footer td th figcaption dd))))
        (if (eq? (get-tag a) 'footer)
            (or (findf (λ (x) (eq? (get-tag x) 'blockquote)) anc) a)
            a))
      (car anc)))

(define graph-circle '(span ((class "graph-circle") (role "img") (aria-label "cited here"))))

(define (clean x [targets null]) (clean* x (or targets null)))
(define (clean* x targets)
  (define (clean k [t targets]) (clean* k t))
  (cond
    [(not (txexpr? x)) x]
    [(memq x targets)
     (cond [(eq? (get-tag x) 'a)
            (if (or (class? x "circle-link"))
                graph-circle
                (if (or (class? x "term") (class? x "aside-phrase"))
                    `(span ,@(filter values (map (λ (k) (clean k null)) (get-elements x))) ,graph-circle)
                    (txexpr 'a `((class ,(string-append (attr-ref x 'class) " graph-here")) (href ,(attr-ref x 'href)))
                            (filter values (map (λ (k) (clean k null)) (get-elements x))))))]
           [else graph-circle])]
    [(attrs-have-key? x 'hidden) #f]
    [(or (class? x "margin-note") (class? x "self") (class? x "circle-link") (class? x "circle")) #f]
    [(and (eq? (get-tag x) 'span) (class? x "nw") (findf (λ (k) (class? k "circle")) (get-elements x)))
     ;; a word bound to a circle: the word only, without the circle's name
     (txexpr 'span '((class "nw"))
             (filter values (for/list ([k (in-list (get-elements x))] #:unless (class? k "vh")) (clean k))))]
    [(and (eq? (get-tag x) 'a) (or (class? x "term") (class? x "aside-phrase") (class? x "same") (class? x "to-ref")))
     (if (class? x "to-ref")
         #f
         (txexpr 'span null (filter values (for/list ([k (in-list (get-elements x))]
                                                      #:unless (class? k "mark"))
                                             (clean (if (and (txexpr? k) (class? k "nw"))
                                                        (txexpr 'span null (filter (λ (e) (not (class? e "mark"))) (get-elements k)))
                                                        k))))))]
    [else (txexpr (get-tag x)
                  (filter (λ (a) (not (memq (car a) '(id data-targets data-kinds aria-expanded data-quote data-loc data-note data-block)))) (get-attrs x))
                  (filter values (map (λ (k) (clean k)) (get-elements x))))]))

;; The context of a link or circle (ANC its ancestors, innermost first); the
;; targets marked are TARGET, or those PICK finds inside the context's root.
(define (context-of anc target #:pick [pick #f])
  (define r (context-root anc))
  (define targets (if pick (find-all r pick) (list target)))
  (define (clean x t) (clean* x targets))
  (define body
    (cond
      [(eq? (get-tag r) 'blockquote) (list (clean r target))]
      [(eq? (get-tag r) 'li)
       (define kids (filter (λ (k) (not (and (txexpr? k) (memq (get-tag k) '(ul ol))))) (get-elements r)))
       (if (ormap (λ (k) (and (txexpr? k) (eq? (get-tag k) 'p))) kids)
           (filter values (map (λ (k) (clean k target)) (filter txexpr? kids)))
           (list `(p ,@(filter values (map (λ (k) (clean k target)) kids)))))]
      [(class? r "aside") (list `(p ((class "aside-context")) ,@(filter values (map (λ (k) (clean k target)) (get-elements r)))))]
      [else (list `(p ,@(filter values (map (λ (k) (clean k target)) (get-elements r)))))]))
  (txexpr->json `(div ,@body)))

(define (txexpr->json x)
  (cond [(txexpr? x) (list* (symbol->string (get-tag x))
                            (for/hasheq ([a (in-list (get-attrs x))]) (values (car a) (cadr a)))
                            (map txexpr->json (get-elements x)))]
        [(string? x) x]
        [(char? x) (string x)]
        [(symbol? x) (format "&~a;" x)]
        [else (format "~a" x)]))

;; The paragraph (or item, aside, quotation) a record sits in, as a number
;; unique on the page: citations that share one are listed once (BIB-9).
(define (root-id roots anc) (hash-ref! roots (context-root anc) (λ () (hash-count roots))))

(define (section-of anc)
  (for/first ([a (in-list anc)]
              #:when (and (eq? (get-tag a) 'section) (attrs-have-key? a 'id) (not (class? a "endmatter"))))
    (attr-ref a 'id)))

(define (tokens x) (if (attrs-have-key? x 'data-targets) (string-split (attr-ref x 'data-targets)) null))

;; One page's records: (values post links cites terms changes)
(define (walk-page url src doc)
  (define metas (get-metas src))
  (define top (get-elements doc))
  (define body (filter (λ (x) (not (class? x "endmatter"))) top))
  (define (endmatter id) (findf (λ (x) (and (class? x "endmatter") (equal? (attr-ref x 'id #f) id))) top))
  ;; notes: id → (key quote block? loc)
  (define notes
    (for/hash ([li (in-list (let ([s (endmatter "notes")]) (if s (find-all s (λ (x) (eq? (get-tag x) 'li))) null)))]
               #:when (attrs-have-key? li 'data-bib))
      (values (attr-ref li 'id)
              (list (substring (attr-ref li 'data-bib) 4)
                    (and (attrs-have-key? li 'data-quote) (attr-ref li 'data-quote))
                    (attrs-have-key? li 'data-block)
                    (attr-ref li 'data-loc "")))))
  (define (key-of-token t) (let ([nt (hash-ref notes t #f)]) (and nt (car nt))))
  (define roots (make-hasheq))
  ;; the visible circle that opens each aside, for marks inside hidden copies
  (define opener
    (for*/hash ([x (in-list (find-all doc (λ (x) (and (attrs-have-key? x 'id) (attrs-have-key? x 'data-targets)))))]
                [t (in-list (tokens x))])
      (values t (attr-ref x 'id))))
  (define links '()) (define cites '()) (define terms '())
  (for ([e (in-list body)])
    (let walk ([x e] [anc '()])
      (when (txexpr? x)
        (define anc* (cons x anc))
        ;; VAL-4: a link to another page of the site
        (when (and (eq? (get-tag x) 'a) (class? x "xref") (not (class? x "to-ref")))
          (match-define (list _ path frag) (regexp-match #px"^([^#]*)(?:#(.*))?$" (attr-ref x 'href)))
          (unless (or (equal? path url) (regexp-match? #rx"^/references/" path))
            (set! links (cons (cons path (hasheq 'from url 'section (or (section-of anc) 'null) 'id (or frag 'null)
                                                 'context (context-of anc* x)))
                              links))))
        ;; BIB-6: a circle that opens notes; BIB-9: a note that quotes
        (for ([t (in-list (tokens x))])
          (cond
            [(hash-ref notes t #f)
             => (λ (nt)
                  (match-define (list key qtext block? loc) nt)
                  (define hidden (findf (λ (a) (and (attrs-have-key? a 'hidden) (class? a "aside"))) anc))
                  (define mark (if (attrs-have-key? x 'id)
                                   (attr-ref x 'id)
                                   (or (and hidden (hash-ref opener (string-append "aside-" (substring (attr-ref hidden 'id) 11)) #f))
                                       'null)))
                  (define n (string->number (substring t 5)))
                  (define sec (or (section-of anc) 'null))
                  ;; the context marks every circle in it that cites this work
                  (define (cites-key? e) (and (txexpr? e) (ormap (λ (t) (equal? (key-of-token t) key)) (tokens e))))
                  (set! cites (cons (cons key (hasheq* 'from url 'section sec 'mark mark 'note n 'loc loc 'para (root-id roots anc*)
                                                       'context (context-of anc* x #:pick cites-key?)
                                                       'text (or qtext 'null) 'block block?))
                                    cites)))]
            [(regexp-match #rx"^term-(.*)$" t) => (λ (m) (set! terms (cons (cadr m) terms)))]))
        (when (and (eq? (get-tag x) 'a) (class? x "term"))
          (define m (regexp-match #rx"^#term-(.*)$" (attr-ref x 'href "")))
          (when m (set! terms (cons (cadr m) terms))))
        (for ([k (in-list (get-elements x))]) (walk k anc*)))))
  (define sections
    (for/hasheq ([s (in-list (find-all doc (λ (x) (and (eq? (get-tag x) 'section) (attrs-have-key? x 'id)
                                                         (not (class? x "endmatter"))))))])
      (values (string->symbol (attr-ref s 'id))
              (string-trim (regexp-replace #rx"§$" (text-of (car (get-elements s))) "")))))
  (define changes
    (let ([s (endmatter "changelog")])
      (if s
          (for/list ([li (in-list (find-all s (λ (x) (eq? (get-tag x) 'li))))])
            (define t (car (get-elements li)))
            (hasheq 'from url 'date (attr-ref t 'datetime)
                    'text (txexpr->json `(span ,@(filter values (map (λ (k) (clean k #f)) (cddr (get-elements li))))))))
          null)))
  (values (hasheq 'title (or (meta-text metas 'title) url)
                  'kind (symbol->string (or (post-kind src) 'essay))
                  'published (or (meta-text metas 'published) "")
                  'sections sections)
          (reverse links) (reverse cites)
          ;; TERM-8, TERM-9: each term the page marks, with the page's sense of
          ;; it as HTML when it has one (from the Terms store)
          (for/list ([id (in-list (remove-duplicates (reverse terms)))])
            (define entry (let ([s (endmatter "terms")])
                            (and s (findf (λ (x) (equal? (attr-ref x 'id #f) (string-append "term-" id))) (find-all s txexpr?)))))
            (define sense (and entry (findf (λ (x) (class? x "term-sense")) (find-all entry txexpr?))))
            (define em (and sense (findf (λ (x) (and (txexpr? x) (eq? (get-tag x) 'em))) (get-elements sense))))
            (if em
                (hasheq 'id id 'sense (->html (filter values (map (λ (k) (clean k)) (get-elements em)))))
                (hasheq 'id id)))
          changes))

;; Pages' records → the graph's JSON shape (lib/graph.rkt).
(define (graph-of walked)
  (define (group pairs)
    (for/fold ([h (hasheq)]) ([p (in-list pairs)])
      (hash-update h (string->symbol (car p)) (λ (l) (append l (list (cdr p)))) null)))
  (hasheq 'posts (for/hasheq ([w (in-list walked)]) (values (string->symbol (first w)) (second w)))
          'links (group (append-map third walked))
          'cites (group (append-map fourth walked))
          'terms (for/hasheq ([w (in-list walked)]) (values (string->symbol (first w)) (fifth w)))
          'changes (append-map sixth walked)))

