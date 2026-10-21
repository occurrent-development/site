;;; occurrent-test.el --- Tests for occurrent.el  -*- lexical-binding: t; -*-

;; Run with `make test-emacs' (TEST-1, TEST-3 in HANDOVER-EMACS.md).

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
            "\n")))

(ert-deftest od-test-every-tag ()
  "Every tag fontifies its name as markup, or as an error when not built."
  (dolist (entry od-vocabulary)
    (let ((name (car entry)))
      (od-test-with (od-test-sample name)
        (setq od-file-kind-override (or (plist-get (cdr entry) :only) 'essay))
        (font-lock-flush) (font-lock-ensure)
        (let ((faces (od-test-faces-at (concat "◊" (symbol-name name)) (if (eq name 'ref) 1 1))))
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
   "◊figure[\"a.png\" #:id \"a\" #:title \"T\" #:alt \"x\" #:licence \"own\" #:width \"wide\"]{c}"
   '("#:width"))
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
  (od-test-with "◊more{Longer text.}"
    (setq od-file-kind-override 'essay) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) '("◊more")))
    (setq od-file-kind-override 'glossary) (font-lock-flush) (font-lock-ensure)
    (should (equal (od-test-errors) nil))))

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
notebook/demo/ when `od-test-kind' is \"entry\")."
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
;;; anchors, the notebook (VOCAB-5, LAYOUT-4c, MNOTE-6, KIND-6)

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
    (dolist (c '(("essays/a/a.html.pm" . essay) ("notebook/a/a.html.pm" . entry)
                 ("notebook/a/support/x.pm" . nil) ("pages/index.html.pm" . home)
                 ("pages/essays.html.pm" . index) ("pages/notebook.html.pm" . index)
                 ("pages/colophon.html.pm" . page) ("glossary/x.pm" . glossary)))
      (should (eq (od-file-kind (expand-file-name (car c) root)) (cdr c))))))

(ert-deftest od-test-new-entry-is-hidden ()
  (let ((od-test-kind "entry"))
    (od-test-with-repo
      (should (string-match-p "/notebook/demo/demo\\.html\\.pm\\'" buffer-file-name))
      (should-not (string-match-p "epistemic" (buffer-string)))
      (should (equal (od-test-git default-directory "status" "--porcelain") ""))
      (should (eq (od-file-kind) 'entry)))))

(ert-deftest od-test-publish-entry ()
  (let ((od-test-kind "entry"))
    (od-test-with-repo
      (od-test-publishing
       (od-publish)
       (let ((staged (split-string (od-test-git (od-root) "diff" "--cached" "--name-only") "\n" t)))
         (should (member "notebook/demo/demo.html.pm" staged))
         (should (member "index.ptree" staged)))
       (with-temp-buffer
         (insert-file-contents (expand-file-name "index.ptree" (od-root)))
         (should (= 1 (how-many "^notebook/demo/demo\\.html$" (point-min) (point-max)))))))))

(ert-deftest od-test-link-groups ()
  (should (equal (mapcar #'od--url-group '("/placeholder" "/notebook/a-day" "/" "/essays" "/specimen"))
                 '("Essays" "Notebook" "Pages" "Pages" "Pages"))))

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
                                '("pages/index.html.pm" "pages/essays.html.pm" "pages/notebook.html.pm"
                                  "pages/specimen.html.pm" "pages/colophon.html.pm"
                                  "essays/placeholder/placeholder.html.pm"
                                  "tests/lists.html.pm" "tests/citations.html.pm" "tests/asides.html.pm"
                                  "tests/notebook/sectioned-entry/sectioned-entry.html.pm"))
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

(provide 'occurrent-test)
;;; occurrent-test.el ends here
