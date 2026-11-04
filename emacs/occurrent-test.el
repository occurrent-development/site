;;; occurrent-test.el --- Tests for occurrent.el  -*- lexical-binding: t; -*-

;; Run with `make test-emacs' (TEST-1, TEST-3 in HANDOVERS.md, HANDOVER-EMACS).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'occurrent)

(defmacro od-test-with (text &rest body)
  "Fontify TEXT in an `occurrent-mode' buffer, then run BODY there."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (let ((od-use-orgtbl nil)) (occurrent-mode))
     (font-lock-ensure)
     (goto-char (point-min))
     ,@body))

(defun od-test-faces-at (string &optional nth)
  "The faces on the NTH (default 1st) occurrence of STRING."
  (save-excursion
    (goto-char (point-min))
    (dotimes (_ (or nth 1)) (search-forward string))
    (let ((f (get-text-property (match-beginning 0) 'face)))
      (if (listp f) f (list f)))))

(defun od-test-errors ()
  "The texts covered by `od-error-face', in order, adjacent runs merged."
  (let (out (pos (point-min)) start)
    (while (< pos (point-max))
      (let* ((f (get-text-property pos 'face))
             (next (next-single-property-change pos 'face nil (point-max)))
             (err (memq 'od-error-face (if (listp f) f (list f)))))
        (cond ((and err (not start)) (setq start pos))
              ((and (not err) start)
               (push (buffer-substring-no-properties start pos) out) (setq start nil)))
        (setq pos next)))
    (when start (push (buffer-substring-no-properties start (point-max)) out))
    (nreverse out)))

;;; TEST-1: highlighting

(defun od-test-sample (name)
  "A minimal correct use of tag NAME, for the vocabulary test."
  (let* ((e (od--tag name))
         (pos (pcase (plist-get (cdr e) :pos)
                ('nil nil) ('key (if (eq name 'define-meta) "title" "\"k\"")) (_ "\"x\""))))
    (cond
     ((eq name 'sense)
      "A ◊term[\"occurrent\"]{word ◊sense{some text}} here.\n")   ; TERM-9: only inside a term
     ((eq name 'panel)                                            ; IMG-9: only inside ◊panels
      "◊panels[#:id \"x\" #:title \"T\" #:licence \"own\"]{\n◊panel[\"a.png\" #:alt \"a\"]{Sub}\n◊panel[\"b.png\" #:alt \"b\"]{Sub}\nCaption.}\n")
     (t
    (concat (when (eq name 'ref)
              "◊figure[\"a.png\" #:id \"x\" #:title \"T\" #:alt \"a\" #:licence \"own\"]{c}\n\n")
            "◊" (symbol-name name)
            (let ((parts (delq nil (cons pos (mapcar (lambda (k) (if (eq k 'kind) "#:kind \"essay\"" (format "#:%s \"v\"" k)))
                                                    (plist-get (cdr e) :req))))))
              (if parts (concat "[" (string-join parts " ") "]") ""))
            (cond ((not (plist-get (cdr e) :body)) "")
                  ((memq name '(list)) "{\n- one\n  line\n- two\n}")
                  ((eq name 'table) "{\n| a | b |\n|---+---|\n| 1 | 2 |\n}")
                  ((eq name 'define-meta) "{a value on one line}")
                  (t "{some\ntext over\nthree lines}"))
            ;; a margin note must gloss something (MNOTE-6)
            (if (eq name 'margin) "Text it glosses." "")
            "\n")))))

(ert-deftest od-test-every-tag ()
  "Every tag fontifies its name as markup, or as an error when not built."
  (dolist (entry od-vocabulary)
    (let ((name (car entry)))
      (od-test-with (od-test-sample name)
        (setq od-file-kind-override (or (plist-get (cdr entry) :only) 'essay))
        (font-lock-flush) (font-lock-ensure)
        (let ((faces (od-test-faces-at (concat "◊" (symbol-name name)) (if (eq name 'panel) 2 1))))
          (if (plist-get (cdr entry) :built)
              (progn
                (should (memq 'od-markup-face faces))
                (should (equal (od-test-errors) nil)))
            (should (memq 'od-error-face faces))))))))

(ert-deftest od-test-body-faces ()
  "Bodies take their faces across lines (FL-2, FL-3)."
  (od-test-with "◊aside{A digression\nthat runs over\nthree lines.}\n\n◊section[#:id \"s\"]{The title}\n\n◊term[\"t\"]{a term}"
    (should (memq 'od-aside-face (od-test-faces-at "three lines")))
    (should (memq 'od-heading-1-face (od-test-faces-at "The title")))
    (should (memq 'od-markup-face (od-test-faces-at "◊section")))
    (should (memq 'od-id-face (od-test-faces-at "\"s\"")))
    (should (memq 'od-term-face (od-test-faces-at "a term")))
    (should (memq 'od-id-face (od-test-faces-at "\"t\"")))))

(defmacro od-test-errors-are (text expected)
  `(od-test-with ,text
     (setq od-file-kind-override 'essay)
     (font-lock-flush) (font-lock-ensure)
     (should (equal (od-test-errors) ,expected))))

(ert-deftest od-test-errors-unknown-tags ()
  (od-test-errors-are "Text ◊quote{x} end." '("◊quote"))
  (od-test-errors-are "◊embed[\"tax\"]{caption}" '("◊embed"))
  (od-test-errors-are "Some ◊nonsense{x}." '("◊nonsense"))
  (od-test-errors-are "A lone ◊ {here}." '("◊"))
  (od-test-errors-are "No ◊p{paragraph}." '("◊p")))

(ert-deftest od-test-errors-keywords ()
  (od-test-errors-are "See ◊cite[\"k\" #:page \"3\"]." '("#:page"))
  (od-test-errors-are
   "◊figure[\"a.png\" #:id \"a\" #:title \"T\" #:alt \"x\" #:licence \"own\" #:wide #t]{c}"
   '("#:wide"))   ; #:width is a keyword since spec 1.27 (IMG-2); a retired name is not
  (od-test-errors-are "◊figure[\"a.png\" #:alt \"x\" #:licence \"own\"]{c}" '("◊figure"))
  (od-test-errors-are "◊section{No id}" '("◊section")))

(ert-deftest od-test-errors-ids-and-targets ()
  (od-test-errors-are
   "◊section[#:id \"dup\"]{A}\n\n◊figure[\"a.png\" #:id \"dup\" #:title \"T\" #:alt \"x\" #:licence \"own\"]{c}"
   '("\"dup\""))
  (od-test-errors-are "See ◊link[\"#missing\"]{there}." '("\"#missing\""))
  (od-test-errors-are "See ◊ref[\"missing\"]." '("\"missing\""))
  (od-test-errors-are "◊section[#:id \"sec\"]{A}\n\nSee ◊ref[\"sec\"]." '("\"sec\"")))

(ert-deftest od-test-errors-meta ()
  (od-test-errors-are "◊define-meta[subtitle]{A value\nbroken across lines.}\n"
                      '("◊define-meta[subtitle]{A value\nbroken across lines.}"))
  ;; the abstract and epistemic status are tags now (SRC-4a)
  (od-test-errors-are "◊define-meta[abstract]{old}\n" '("abstract"))
  (od-test-errors-are "◊define-meta[status]{finished}\n" '("finished"))
  (od-test-errors-are "◊define-meta[term]{x}\n" '("term")))

(ert-deftest od-test-only-where-allowed ()
  (od-test-with "◊index[#:kind \"essay\"]"
    (setq od-file-kind-override 'essay) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) '("◊index")))
    (setq od-file-kind-override 'index) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) nil))))

(ert-deftest od-test-sense-inside-term ()
  "TERM-9: ◊sense inside ◊term is clean; anywhere else it is an error; ◊more is gone (D18)."
  (od-test-errors-are "A ◊term[\"occurrent\"]{occurrent ◊sense{what it means here}} word." nil)
  (od-test-errors-are "A ◊sense{loose} word." '("◊sense"))
  (od-test-errors-are "◊more{Longer text.}" '("◊more")))

(ert-deftest od-test-insert-panels ()
  "IMG-9: `od-insert-panels' asks how many panels and how they sit, then every image in turn."
  (let ((answers '()))
    (cl-letf (((symbol-function 'read-string)
               (lambda (prompt &rest _)
                 (push prompt answers)
                 (cond ((string-prefix-p "Title" prompt) "Three views")
                       ((string-prefix-p "Id" prompt) "views")
                       ((string-prefix-p "Alt text for" prompt) (format "Alt %s" (substring prompt 13 14)))
                       ((string-prefix-p "Caption for C" prompt) "")
                       ((string-prefix-p "Caption for" prompt) (format "Sub %s" (substring prompt 12 13)))
                       (t ""))))
              ((symbol-function 'read-number) (lambda (&rest _) 3))
              ((symbol-function 'completing-read)
               (lambda (prompt &optional coll &rest _)
                 (push prompt answers)
                 (cond ((string-prefix-p "Licence" prompt) "own")
                       ((string-prefix-p "Columns" prompt) (cadr coll))   ; the second choice: stacked
                       (t ""))))
              ((symbol-function 'read-file-name)
               (lambda (prompt &rest _)
                 (push prompt answers)
                 (format "/tmp/od-panels/img/%s.png" (downcase (substring prompt 16 17))))))
      (with-temp-buffer
        (setq default-directory "/tmp/od-panels/")
        (od-insert-panels)
        (should (equal (buffer-string)
                       (concat "◊panels[#:id \"views\" #:title \"Three views\" #:licence \"own\" #:columns 1]{\n"
                               "◊panel[\"img/a.png\" #:alt \"Alt A\"]{Sub A}\n"
                               "◊panel[\"img/b.png\" #:alt \"Alt B\"]{Sub B}\n"
                               "◊panel[\"img/c.png\" #:alt \"Alt C\"]\n"
                               "}\n")))
        ;; point is on the caption line, before the brace
        (should (looking-at-p "}\n"))
        (should (= (count-lines (point-min) (point)) 4))))
    ;; three images were asked for, in order, and the columns question came before any image
    (let ((asked (reverse answers)))
      (should (equal (cl-remove-if-not (lambda (p) (string-prefix-p "Image for panel" p)) asked)
                     '("Image for panel A (1 of 3): " "Image for panel B (2 of 3): " "Image for panel C (3 of 3): ")))
      (should (< (cl-position-if (lambda (p) (string-prefix-p "Columns" p)) asked)
                 (cl-position-if (lambda (p) (string-prefix-p "Image" p)) asked))))))

(ert-deftest od-test-panel-inside-panels ()
  "IMG-9: ◊panel inside ◊panels is clean, and ◊ref may name the figure; a loose ◊panel is an error."
  (od-test-errors-are (concat "See ◊ref[\"p\" #:panel \"b\"].\n\n"
                              "◊panels[#:id \"p\" #:title \"T\" #:licence \"own\"]{\n"
                              "◊panel[\"a.png\" #:alt \"a\"]{One}\n◊panel[\"b.png\" #:alt \"b\"]{Two}\nCaption.}")
                      nil)
  (od-test-errors-are "Text.\n\n◊panel[\"a.png\" #:alt \"a\"]{One}\n" '("◊panel")))

(ert-deftest od-test-insert-term-sense ()
  "TERM-9: with a prefix, od-insert-term writes ◊sense{} and leaves point in it."
  (od-test-with "A word here."
    (transient-mark-mode 1)
    (search-forward "word") (set-mark (match-beginning 0)) (activate-mark)
    (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "occurrent"))
              ((symbol-function 'od--term-candidates) (lambda () '(("occurrent" . "occurrent")))))
      (od-insert-term t)
      (insert "here")
      (should (equal (buffer-string) "A ◊term[\"occurrent\"]{word ◊sense{here}} here."))
      (goto-char (point-max))
      (should-error (od-insert-term t) :type 'user-error))))

(ert-deftest od-test-lists ()
  (od-test-errors-are "◊list{\n- one\n  - two\n1. three\n   1. four\n}" nil)
  (od-test-errors-are "◊list{\n- one\n   - bad\n}" '("   -")))

;;; TEST-1: syntax

(ert-deftest od-test-prose-is-prose ()
  "Quotes, brackets, an address and an apostrophe stay punctuation (SYN-1/2)."
  (od-test-with "Prose with \"quoted words\", [sic], ryan@occurrentdevelopment.com and don't.\n"
    (goto-char (point-max))
    (let ((ppss (syntax-ppss)))
      (should (= (nth 0 ppss) 0))
      (should-not (nth 3 ppss)))
    (should (equal (od-test-errors) nil))
    (should-not (memq 'od-string-face (od-test-faces-at "quoted")))))

(ert-deftest od-test-sexp-motion ()
  "forward-sexp crosses a tag; up-list leaves a body (SYN-3)."
  (od-test-with "Text ◊aside{A digression with ◊term[\"x\"]{a term}\nacross two lines.} after."
    (search-forward "◊aside") (goto-char (match-beginning 0))
    (forward-sexp)
    (should (looking-at " after"))
    (goto-char (point-min)) (search-forward "a term")
    (up-list)
    (should (looking-at "\nacross"))
    (up-list)
    (should (looking-at " after"))))

;;; TEST-1: editing

(ert-deftest od-test-soft-wrap-joins ()
  "With soft wrap, M-q joins a hard-wrapped paragraph onto one line (EDIT-1a)."
  (od-test-with "One line\nof a hard\nwrapped paragraph.\n\n◊section[#:id \"s\"]{Next}\n"
    (call-interactively #'od-fill-paragraph)
    (should (equal (buffer-string) "One line of a hard wrapped paragraph.\n\n◊section[#:id \"s\"]{Next}\n"))))

(ert-deftest od-test-fill-list-item ()
  (od-test-with "◊list{\n- A first item that is long enough to need wrapping at a narrow fill column.\n}\n"
    (setq-local od-soft-wrap nil)
    (setq fill-column 30)
    (search-forward "first")
    (fill-paragraph)
    (goto-char (point-min)) (forward-line 2)
    (should (looking-at "  [a-z]"))                     ; continues under the text
    (should (string-match-p "\\`◊list{\n- A first" (buffer-string)))))

(ert-deftest od-test-fill-stops-at-heading ()
  (od-test-with "See ◊link[\"https://x.org\" #:note \"A note\nwrapped across lines.\"]{this}\nand more words here.\n◊section[#:id \"s\"]{Next}\n"
    (setq fill-column 70)
    (fill-paragraph)
    (should (string-match-p "\n◊section\\[#:id \"s\"\\]{Next}\n\\'" (buffer-string)))))

(ert-deftest od-test-unwrap ()
  (od-test-with "Text ◊em{some words} end."
    (search-forward "some")
    (od-unwrap)
    (should (equal (buffer-string) "Text some words end."))))

(ert-deftest od-test-comment ()
  (od-test-with "One.\nTwo.\n"
    (transient-mark-mode 1)
    (set-mark (point-min)) (goto-char (point-max)) (activate-mark)
    (comment-dwim nil)
    (should (equal (buffer-string) "◊; One.\n◊; Two.\n"))))

(ert-deftest od-test-insert-aside-phrase ()
  "ASIDE-8: an active region becomes the aside's phrase."
  (od-test-with "The prospect of a finalised \"product\" helps."
    (transient-mark-mode 1)
    (search-forward "finalised") (goto-char (match-beginning 0))
    (set-mark (point)) (search-forward "\"product\"") (activate-mark)
    (od-insert-aside)
    (insert "Body.")
    (should (equal (buffer-string)
                   "The prospect of a ◊aside[\"finalised \\\"product\\\"\"]{Body.} helps.")))
  (od-test-with "Text "
    (goto-char (point-max))
    (od-insert-aside)
    (should (equal (buffer-string) "Text ◊aside{}"))))

(ert-deftest od-test-aside-phrase-not-an-error ()
  (od-test-errors-are "A ◊aside[\"phrase\"]{body} and ◊aside{plain}." nil)
  (od-test-errors-are "A ◊aside[◊em{em} \" phrase\"]{body}." nil))

;;; TEST-3: publishing, against a throwaway repository

(defun od-test-git (dir &rest args)
  (let ((default-directory dir))
    (with-temp-buffer
      (unless (eq 0 (apply #'process-file "git" nil t nil args))
        (error "git %s: %s" args (buffer-string)))
      (string-trim (buffer-string)))))

(defvar od-test-kind "essay" "What the \"Essay or entry?\" prompt answers in a test repository.")

(defmacro od-test-with-repo (&rest body)
  "Run BODY in a fresh clone holding a draft post, essays/demo/ (or
blog/demo/ when `od-test-kind' is \"entry\")."
  (declare (indent 0))
  `(let* ((top (make-temp-file "od-test" t))
          (origin (expand-file-name "origin.git" top))
          (site (file-name-as-directory (expand-file-name "site" top))))
     (unwind-protect
         (progn
           (od-test-git top "init" "-q" "--bare" "-b" "main" origin)
           (od-test-git top "clone" "-q" origin site)
           (od-test-git site "config" "user.email" od-email)
           (od-test-git site "config" "user.name" "Test")
           (with-temp-file (expand-file-name "pollen.rkt" site) (insert "#lang racket/base\n"))
           (with-temp-file (expand-file-name "index.ptree" site) (insert "#lang pollen\nindex.html\n"))
           (od-test-git site "add" ".")
           (od-test-git site "commit" "-q" "-m" "start")
           (od-test-git site "push" "-q" "origin" "main")
           (let ((default-directory site))
             (cl-letf (((symbol-function 'read-string)
                        (lambda (prompt &optional initial &rest _)
                          (cond ((string-prefix-p "Title" prompt) "A demo essay")
                                ((string-prefix-p "Slug" prompt) "demo")
                                (t (or initial "")))))
                       ((symbol-function 'completing-read)
                        (lambda (prompt &rest _) (if (string-prefix-p "Essay or entry" prompt) od-test-kind ""))))
               (find-file (expand-file-name "x.pm" site))   ; od-root from here
               (od-new-essay)))
           ,@body)
       (dolist (b (buffer-list))
         (when (and (buffer-file-name b) (string-prefix-p top (buffer-file-name b)))
           (with-current-buffer b (set-buffer-modified-p nil)) (kill-buffer b)))
       (delete-directory top t))))

(defmacro od-test-publishing (&rest body)
  "Run BODY with make, Magit and questions stubbed out."
  `(let ((od--run-function (lambda (_cmd cb &optional _b) (when cb (funcall cb t))))
         (magit-opened nil))
     (cl-letf (((symbol-function 'od--require-magit) #'ignore)
               ((symbol-function 'magit-status-setup-buffer) (lambda (&rest _) (setq magit-opened t)))
               ((symbol-function 'y-or-n-p) (lambda (&rest _) t))
               ((symbol-function 'completing-read)
                (lambda (prompt &rest _) (if (string-prefix-p "Kind of change" prompt) "Typo" ""))))
       ,@body)))

(ert-deftest od-test-new-essay-is-hidden ()
  (od-test-with-repo
    (should (equal (file-name-nondirectory buffer-file-name) "demo.html.pm"))
    (should (file-exists-p (expand-file-name "support/notes.md" default-directory)))
    (should (equal (od-test-git default-directory "status" "--porcelain") ""))))

(ert-deftest od-test-rename-draft ()
  "REN-1: a draft's title and slug change together; the exclude line, index.ptree
and every ◊link follow; the old folder is gone."
  (od-test-with-repo
    (let ((root (od-root)))
      ;; another post that links to the draft, with and without a fragment
      (make-directory (expand-file-name "essays/other" root) t)
      (with-temp-file (expand-file-name "essays/other/other.html.pm" root)
        (insert "#lang pollen\n◊define-meta[title]{Other}\n\nSee ◊link[\"/demo\"]{it} and ◊link[\"/demo#intro\"]{its start}; not ◊link[\"/demonstration\"]{this}.\n"))
      (cl-letf (((symbol-function 'read-string)
                 (lambda (prompt &optional initial &rest _)
                   (cond ((string-prefix-p "Title" prompt) "A renamed essay")
                         ((string-prefix-p "Slug" prompt) "renamed")
                         (t (or initial "")))))
                ((symbol-function 'od-check) #'ignore))
        (od-rename-post))
      (should (equal (file-name-nondirectory buffer-file-name) "renamed.html.pm"))
      (should (equal (od--meta "title") "A renamed essay"))
      (should (file-directory-p (expand-file-name "essays/renamed/img" root)))
      (should-not (file-exists-p (expand-file-name "essays/demo" root)))
      (should (equal (od-test-git root "status" "--porcelain" "--" "essays/renamed") ""))   ; still hidden
      (with-temp-buffer
        (insert-file-contents (expand-file-name "support/notes.md" default-directory))
        (should (looking-at-p "A renamed essay$")))
      (with-temp-buffer
        (insert-file-contents (od--exclude-file))
        (should (= 1 (how-many "^/essays/renamed/$" (point-min) (point-max))))
        (should (= 0 (how-many "^/essays/demo/$" (point-min) (point-max)))))
      (with-temp-buffer
        (insert-file-contents (expand-file-name "essays/other/other.html.pm" root))
        (should (= 1 (how-many "◊link\\[\"/renamed\"\\]" (point-min) (point-max))))
        (should (= 1 (how-many "◊link\\[\"/renamed#intro\"\\]" (point-min) (point-max))))
        (should (= 1 (how-many "◊link\\[\"/demonstration\"\\]" (point-min) (point-max))))))))

(ert-deftest od-test-rename-published ()
  "REN-1: a published post moves with git mv, gains a redirect, its index.ptree
line follows, and everything is staged with a Meta message."
  (od-test-with-repo
    (od-test-publishing
     (od-publish)
     (od-test-git (od-root) "commit" "-q" "-m" "Publish: A demo essay")
     (od-test-git (od-root) "push" "-q" "origin" "main")
     (setq magit-opened nil)
     (cl-letf (((symbol-function 'read-string)
                (lambda (prompt &optional initial &rest _)
                  (cond ((string-prefix-p "Title" prompt) (or initial ""))
                        ((string-prefix-p "Slug" prompt) "demo-two")
                        (t (or initial "")))))
               ((symbol-function 'yes-or-no-p) (lambda (&rest _) t))
               ((symbol-function 'od-check) #'ignore))
       (od-rename-post))
     (should magit-opened)
     (should (equal (file-name-nondirectory buffer-file-name) "demo-two.html.pm"))
     (should (equal (od--meta "title") "A demo essay"))
     (let ((staged (split-string (od-test-git (od-root) "diff" "--cached" "--name-status") "\n" t)))
       (should (cl-some (lambda (l) (string-match-p "\\`R.*essays/demo/demo\\.html\\.pm\tessays/demo-two/demo-two\\.html\\.pm" l)) staged))
       (should (cl-some (lambda (l) (string-match-p "_redirects\\'" l)) staged))
       (should (cl-some (lambda (l) (string-match-p "index\\.ptree\\'" l)) staged)))
     (with-temp-buffer
       (insert-file-contents (expand-file-name "_redirects" (od-root)))
       (should (= 1 (how-many "^/demo /demo-two 301$" (point-min) (point-max)))))
     (with-temp-buffer
       (insert-file-contents (expand-file-name "index.ptree" (od-root)))
       (should (= 1 (how-many "^essays/demo-two/demo-two\\.html$" (point-min) (point-max))))
       (should (= 0 (how-many "^essays/demo/" (point-min) (point-max))))))))

(ert-deftest od-test-publish-stages-the-essay ()
  (od-test-with-repo
    (with-temp-file (expand-file-name "support/private-notes.pm" default-directory) (insert "secret"))
    (od-test-publishing
     (od-publish)
     (should magit-opened)
     (let ((staged (split-string (od-test-git (od-root) "diff" "--cached" "--name-only") "\n" t)))
       (should (member "essays/demo/demo.html.pm" staged))
       (should (member "index.ptree" staged))
       (should-not (cl-some (lambda (f) (string-match-p "support/" f)) staged)))
     (should (equal (od--meta "status") "published"))
     (od--ptree-add "demo")
     (with-temp-buffer
       (insert-file-contents (expand-file-name "index.ptree" (od-root)))
       (should (= 1 (how-many "^essays/demo/demo\\.html$" (point-min) (point-max))))))))

(ert-deftest od-test-publish-refuses ()
  (od-test-with-repo
    (od-test-publishing
     (with-temp-file (expand-file-name "draft-Notes.md" default-directory) (insert "notes"))
     (should-error (od-publish) :type 'user-error))
    (delete-file (expand-file-name "draft-Notes.md" default-directory))
    (od-test-git (od-root) "checkout" "-q" "-b" "other")
    (od-test-publishing
     (should-error (od-publish) :type 'user-error))))


;;; 2026-10-20 and 2026-10-21: a command for every tag, #:italic, margin
;;; anchors, the blog (VOCAB-5, LAYOUT-4c, MNOTE-6, KIND-6)

(ert-deftest od-test-every-tag-has-a-key ()
  "Every built tag names a command that exists and is bound under C-c o (VOCAB-5)."
  (dolist (entry od-vocabulary)
    (let ((cmd (plist-get (cdr entry) :command)))
      (should cmd)
      (when (plist-get (cdr entry) :built)
        (should (fboundp cmd))
        (should (where-is-internal cmd occurrent-mode-map))
        (should (string-prefix-p "C-c o" (key-description (where-is-internal cmd occurrent-mode-map t))))))))

(ert-deftest od-test-italic-values ()
  (od-test-errors-are "◊blockquote[#:italic \"yes\"]{Quoted.}\n" '("\"yes\""))
  (od-test-errors-are "◊epigraph[#:source \"X\" #:italic #f]{Motto.}\n\n◊blockquote[#:italic #t]{Quoted.}\n" nil)
  (od-test-errors-are "Text ◊latex{} and more.\n" nil))

(ert-deftest od-test-margin-anchors ()
  "MNOTE-6: the four anchors pass; anywhere else, and a note that glosses nothing, fail."
  (od-test-errors-are "◊margin{Para}Opens a paragraph. A sentence. ◊margin{Sent}Opens a sentence.\n" nil)
  (od-test-errors-are "◊list{\n1. ◊margin{Item}Opens an item.\n}\n\n◊blockquote{◊margin{Q}Opens a quotation.}\n" nil)
  (od-test-errors-are "A line◊br{}◊margin{Br}after a break.\n" nil)
  (od-test-errors-are "Some text ◊margin{mid}more.\n" '("◊margin"))
  (od-test-errors-are "◊list{\n1. Getting a thought expressed.◊margin{Why I write}\n2. Next.\n}\n" '("◊margin"))
  (od-test-errors-are "Ends here.◊margin{late}\n" '("◊margin"))
  (od-test-errors-are "x ◊aside{Inside. ◊margin{no}An aside.}\n" '("◊margin")))

(ert-deftest od-test-toggle-italic ()
  (od-test-with "◊epigraph{Motto.}\n"
    (search-forward "Motto") (od-toggle-italic)
    (should (equal (buffer-string) "◊epigraph[#:italic #f]{Motto.}\n"))
    (od-toggle-italic)
    (should (equal (buffer-string) "◊epigraph{Motto.}\n")))
  (od-test-with "◊epigraph[#:source \"X\" #:italic #f]{Motto.}\n"
    (search-forward "Motto") (od-toggle-italic)
    (should (equal (buffer-string) "◊epigraph[#:source \"X\"]{Motto.}\n")))
  (od-test-with "◊blockquote{Quoted.}\n"
    (search-forward "Quoted") (od-toggle-italic)
    (should (equal (buffer-string) "◊blockquote[#:italic #t]{Quoted.}\n")))
  (od-test-with "Plain prose.\n"
    (should-error (od-toggle-italic) :type 'user-error)))

(ert-deftest od-test-insert-margin-at-end-of-item ()
  "EDIT-8: at the end of an item, the note moves to the item's start, after the marker."
  (od-test-with "◊list{\n1. Getting a thought expressed.\n2. Next.\n}\n"
    (search-forward "expressed.")
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
      (od-insert-margin))
    (insert "Why I write")
    (should (equal (buffer-string) "◊list{\n1. ◊margin{Why I write}Getting a thought expressed.\n2. Next.\n}\n"))))

(defmacro od-test-cite-answers (answers &rest body)
  "Run BODY with od-insert-cite's prompts answered from ANSWERS, in order.
The key is picked as \"k\"."
  (declare (indent 1))
  `(let ((queue ,answers))
     (cl-letf (((symbol-function 'od--select-key) (lambda (&rest _) "k"))
               ((symbol-function 'od--offer-reference) #'ignore)   ; the tests must not make files in the repository
               ((symbol-function 'read-string) (lambda (&rest _) (pop queue)))
               ((symbol-function 'completing-read)
                (lambda (_p _c &optional _r _m _i _h def) (let ((a (pop queue))) (if (equal a "") def a)))))
       ,@body)))

(ert-deftest od-test-insert-cite ()
  "§16, BIB-9: the four prompts; Enter skips each."
  ;; a reference, every prompt skipped
  (od-test-with "Text"
    (goto-char (point-max))
    (od-test-cite-answers '("" "" "") (od-insert-cite))
    (should (equal (buffer-string) "Text◊cite[\"k\"]")))
  ;; a quotation of the region, with a locator and a remark
  (od-test-with "He said made up people here."
    (transient-mark-mode 1)
    (search-forward "made") (goto-char (match-beginning 0))
    (set-mark (point)) (search-forward "people") (activate-mark)
    (od-test-cite-answers '("p. 23" "" "A remark.") (od-insert-cite))
    (should (equal (buffer-string) "He said ◊cite[\"k\" #:loc \"p. 23\" #:note \"A remark.\"]{made up people} here.")))
  ;; a quotation with no region leaves point in the braces
  (od-test-with "Text "
    (goto-char (point-max))
    (od-test-cite-answers '("p. 4" "quotation" "") (od-insert-cite))
    (insert "words")
    (should (equal (buffer-string) "Text ◊cite[\"k\" #:loc \"p. 4\"]{words}")))
  ;; a block quotation, italic, on its own lines
  (od-test-with "Before.\nAfter.\n"
    (goto-char (point-min)) (end-of-line)
    (od-test-cite-answers '("p. 9" "block quotation" "" "italic") (od-insert-cite))
    (insert "Quoted.")
    (should (equal (buffer-string) "Before.\n\n◊cite[\"k\" #:block #t #:italic #t #:loc \"p. 9\"]{Quoted.}\n\nAfter.\n"))))

(ert-deftest od-test-reference-stub ()
  "BIB-3: citing a work makes its empty commentary file once, and offers it for review."
  (let* ((root (file-name-as-directory (make-temp-file "od-ref" t)))
         (asked nil) (opened nil))
    (cl-letf (((symbol-function 'od-root) (lambda () root))
              ((symbol-function 'y-or-n-p) (lambda (p) (push p asked) t))
              ((symbol-function 'find-file-other-window) (lambda (f) (push f opened))))
      (od--offer-reference "aWork2001")
      (let ((file (expand-file-name "references/aWork2001.pm" root)))
        (should (file-exists-p file))
        (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string)) od--reference-stub))
        (should (equal opened (list file)))
        (should (= (length asked) 1))
        ;; a second citation of the same work neither asks nor opens
        (od--offer-reference "aWork2001")
        (should (= (length asked) 1))
        ;; and a file the author wrote is never overwritten
        (with-temp-file file (insert "#lang pollen\n\nMine.\n"))
        (od--offer-reference "aWork2001")
        (should (string-match-p "Mine" (with-temp-buffer (insert-file-contents file) (buffer-string))))))))

(ert-deftest od-test-cite-body-not-an-error ()
  "BIB-9: ◊cite with or without a body, and #:block, are clean."
  (od-test-errors-are "A ◊cite[\"k\"] and ◊cite[\"k\" #:loc \"p. 2\"]{words}." nil))

(ert-deftest od-test-insert-commands ()
  (od-test-with "Text\n"
    (goto-char (point-max)) (od-insert-latex)
    (should (equal (buffer-string) "Text\n◊latex{}")))
  (od-test-with "One word here."
    (search-forward "word") (od-wrap "em")
    (should (equal (buffer-string) "One ◊em{word} here.")))
  (od-test-with "Before.\n"
    (goto-char (point-max)) (od-insert-list t) (insert "first")
    (should (equal (buffer-string) "Before.\n\n◊list{\n1. first\n}\n")))
  (od-test-with "Before.\n\n◊section[#:id \"s\"]{Next}\n"
    (goto-char (point-min)) (end-of-line)
    (should-error (od-insert-break) :type 'user-error))
  (od-test-with "◊section[#:id \"s\"]{A heading}\n\nText here.\n"
    (search-forward "Text") (od-insert-summary) (insert "In brief.")
    (should (string-match-p "{A heading}\n◊summary{In brief.}\n" (buffer-string))))
  (od-test-with "Text.\n"
    (setq od-file-kind-override 'entry)
    (should-error (od-insert-changelog) :type 'user-error)))

(ert-deftest od-test-entry-refusals ()
  "KIND-2: no epistemic status or changelog in an entry; index and latest have their pages."
  (od-test-with "◊epistemic{Sure.}\n"
    (setq od-file-kind-override 'entry) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) '("◊epistemic")))
    (setq od-file-kind-override 'essay) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) nil)))
  (od-test-with "◊index[#:kind \"essay\"]\n\n◊latest[3]\n"
    (setq od-file-kind-override 'essay) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) '("◊index" "◊latest"))))
  (od-test-with "◊index[#:kind \"blog\"]\n"
    (setq od-file-kind-override 'index) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) '("\"blog\"")))))

(ert-deftest od-test-file-kinds ()
  (let ((root (expand-file-name ".." (file-name-directory (locate-library "occurrent")))))
    (dolist (c '(("essays/a/a.html.pm" . essay) ("blog/a/a.html.pm" . entry)
                 ("blog/a/support/x.pm" . nil) ("pages/index.html.pm" . home)
                 ("pages/essays.html.pm" . index) ("pages/blog.html.pm" . index)
                 ("pages/colophon.html.pm" . page) ("glossary/x.pm" . glossary)))
      (should (eq (od-file-kind (expand-file-name (car c) root)) (cdr c))))))

(ert-deftest od-test-new-entry-is-hidden ()
  (let ((od-test-kind "entry"))
    (od-test-with-repo
      (should (string-match-p "/blog/demo/demo\\.html\\.pm\\'" buffer-file-name))
      (should-not (string-match-p "epistemic" (buffer-string)))
      (should (equal (od-test-git default-directory "status" "--porcelain") ""))
      (should (eq (od-file-kind) 'entry)))))

(ert-deftest od-test-publish-entry ()
  (let ((od-test-kind "entry"))
    (od-test-with-repo
      (od-test-publishing
       (od-publish)
       (let ((staged (split-string (od-test-git (od-root) "diff" "--cached" "--name-only") "\n" t)))
         (should (member "blog/demo/demo.html.pm" staged))
         (should (member "index.ptree" staged)))
       (with-temp-buffer
         (insert-file-contents (expand-file-name "index.ptree" (od-root)))
         (should (= 1 (how-many "^blog/demo/demo\\.html$" (point-min) (point-max)))))))))

(ert-deftest od-test-link-groups ()
  (should (equal (mapcar #'od--url-group '("/placeholder" "/blog/a-day" "/" "/essays" "/specimen"))
                 '("Essays" "Blog" "Pages" "Pages" "Pages"))))

;;; One key everywhere: C-c o P publishes a draft and commits anything else

(ert-deftest od-test-publish-commits-a-page ()
  "On a page (never a draft), od-publish stages the page and opens Magit."
  (od-test-with-repo
    (let ((page (expand-file-name "pages/about.html.pm" (od-root))))
      (make-directory (file-name-directory page) t)
      (with-temp-file page (insert "#lang pollen\n\n◊define-meta[title]{About}\n\nText.\n"))
      (od-test-git (od-root) "add" "pages/about.html.pm")
      (od-test-git (od-root) "commit" "-q" "-m" "about")
      (od-test-git (od-root) "push" "-q" "origin" "main")
      (find-file page)
      (goto-char (point-max)) (insert "More.\n") (save-buffer)
      (od-test-publishing
       (od-publish)
       (should magit-opened)
       (should (equal (split-string (od-test-git (od-root) "diff" "--cached" "--name-only") "\n" t)
                      '("pages/about.html.pm")))))))

(ert-deftest od-test-publish-commits-a-published-post ()
  "Once a post is in git, od-publish commits its changes instead of publishing again."
  (od-test-with-repo
    (od-test-publishing
     (od-publish)                                  ; the first time: publish
     (od-test-git (od-root) "commit" "-q" "-m" "Publish: demo")
     (od-test-git (od-root) "push" "-q" "origin" "main")
     (goto-char (point-max)) (insert "A later paragraph.\n") (save-buffer)
     (setq magit-opened nil)
     (let ((ptree-before (with-temp-buffer (insert-file-contents (expand-file-name "index.ptree" (od-root))) (buffer-string))))
       (od-publish)                                ; the second time: commit
       (should magit-opened)
       (should (member "essays/demo/demo.html.pm"
                       (split-string (od-test-git (od-root) "diff" "--cached" "--name-only") "\n" t)))
       (should (equal ptree-before
                      (with-temp-buffer (insert-file-contents (expand-file-name "index.ptree" (od-root))) (buffer-string))))))))

;;; §12: the site's own files open with nothing in the error face

(ert-deftest od-test-site-files-are-clean ()
  (let* ((root (expand-file-name ".." (file-name-directory (locate-library "occurrent"))))
         (files (append (mapcar (lambda (f) (expand-file-name f root))
                                '("pages/index.html.pm" "pages/essays.html.pm" "pages/blog.html.pm"
                                  "pages/specimen.html.pm" "pages/glossary.html.pm" "pages/bibliography.html.pm" "pages/changelog.html.pm"
                                  "essays/placeholder/placeholder.html.pm"
                                  "tests/lists.html.pm" "tests/citations.html.pm" "tests/asides.html.pm" "tests/essays/link-a/link-a.html.pm"
                                  "tests/blog/sectioned-entry/sectioned-entry.html.pm"))
                        (directory-files (expand-file-name "glossary" root) t "\\.pm\\'"))))
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (setq buffer-file-name f)
        (let ((od-use-orgtbl nil)) (occurrent-mode))
        (font-lock-ensure)
        (should (equal (cons f (od-test-errors)) (list f)))
        (set-buffer-modified-p nil)
        (setq buffer-file-name nil)))))

;;; 2026-11-03: menus (EMACS-7), the wrap toggle, the changelog line

(ert-deftest od-test-menus ()
  "One key, then a choice: the menu runs the chosen command with the region kept."
  (od-test-with "One word here."
    (search-forward "word") (set-mark (- (point) 4)) (activate-mark)
    (cl-letf (((symbol-function 'completing-read)
               (lambda (prompt &rest _) (if (string-prefix-p "Link to (default" prompt) "this page" "Intro")))
              ((symbol-function 'od--id-candidates) (lambda (&rest _) '(("Intro" . "intro")))))
      (od-insert-link))
    (should (equal (buffer-string) "One ◊link[\"#intro\"]{word} here.")))
  (od-test-with "Text.\n"
    (goto-char (point-max))
    (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "list")))
      (od-insert-block))
    (insert "item")
    (should (equal (buffer-string) "Text.\n\n◊list{\n- item\n}\n")))
  ;; Enter alone repeats the last choice at that prompt
  (let ((od--menu-last nil) (seen nil))
    (cl-letf (((symbol-function 'completing-read)
               (lambda (prompt &rest _) (setq seen prompt) "rule"))
              ((symbol-function 'od-insert-rule) (lambda () (interactive))))
      (od-test-with "" (od-insert-element))
      (should (string-match-p "default section" seen))
      (od-test-with "" (od-insert-element))
      (should (string-match-p "default rule" seen)))))

(ert-deftest od-test-wrap-toggles ()
  "`od-wrap' inside the same tag takes it off; inside another, it nests."
  (od-test-with "One ◊em{word} here."
    (search-forward "wor") (od-wrap "em")
    (should (equal (buffer-string) "One word here.")))
  (od-test-with "One ◊em{word} here."
    (search-forward "wor") (od-wrap "strong")
    (should (equal (buffer-string) "One ◊em{◊strong{word}} here."))))

(ert-deftest od-test-insert-changelog ()
  "A dated line goes at the end of the block, or into a new block at the end."
  (let ((today (format-time-string "%Y-%m-%d")))
    (od-test-with "Text.\n\n◊changelog{\n2026-10-05: First.\n}\n"
      (od-insert-changelog) (insert "Second.")
      (should (equal (buffer-string)
                     (format "Text.\n\n◊changelog{\n2026-10-05: First.\n%s: Second.\n}\n" today))))
    (od-test-with "Text.\n"
      (od-insert-changelog) (insert "First.")
      (should (equal (buffer-string) (format "Text.\n\n◊changelog{\n%s: First.\n}\n" today))))))

(provide 'occurrent-test)
;;; occurrent-test.el ends here
