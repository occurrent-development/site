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
            (let ((parts (delq nil (cons pos (mapcar (lambda (k) (format "#:%s \"v\"" k))
                                                    (plist-get (cdr e) :req))))))
              (if parts (concat "[" (string-join parts " ") "]") ""))
            (cond ((not (plist-get (cdr e) :body)) "")
                  ((memq name '(list)) "{\n- one\n  line\n- two\n}")
                  ((eq name 'table) "{\n| a | b |\n|---+---|\n| 1 | 2 |\n}")
                  ((eq name 'define-meta) "{a value on one line}")
                  (t "{some\ntext over\nthree lines}"))
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

(defmacro od-test-with-repo (&rest body)
  "Run BODY in a fresh clone holding a draft essay, essays/demo/."
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
                                (t (or initial ""))))))
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
               ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
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

(provide 'occurrent-test)
;;; occurrent-test.el ends here
