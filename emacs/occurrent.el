;;; occurrent.el --- Writing occurrentdevelopment.com in Pollen  -*- lexical-binding: t; -*-

;; Commands for SPEC.md §16. Every picker uses plain `completing-read', so
;; it works with Vertico, Ivy, Helm or the default UI.
;;
;; Setup, in your init file:
;;
;;   (load "~/…/site/emacs/occurrent.el")
;;   (add-hook 'pollen-mode-hook #'occurrent-mode)   ; or any mode for .pm
;;
;; Citations come from your whole Zotero library (the Better BibTeX
;; auto-export named by ZOTERO_BIB in the repository's local.mk), through
;; citar when it is installed. `make refresh' then copies only the cited
;; entries into the public repository.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'json)

(defgroup occurrent nil
  "Writing occurrentdevelopment.com."
  :group 'text)

(defcustom od-zotero-bib nil
  "Path to the Zotero (Better BibTeX) export.
When nil, read ZOTERO_BIB from the repository's local.mk."
  :type '(choice (const nil) file))

(defcustom od-preview-port 8080
  "Port of the Pollen project server started by `make serve'."
  :type 'integer)

(defcustom od-set-mac-option-keys t
  "When non-nil, give the right Option key back to macOS (EMACS-1).
Then ⌥⇧V types ◊ everywhere, as it does in other applications."
  :type 'boolean)

(defface od-markup-face '((t :inherit shadow))
  "Face for Pollen tag syntax, dimmed so prose dominates (EMACS-5).")

;;; Project ------------------------------------------------------------------

(defun od-root ()
  "The repository root: the directory holding pollen.rkt."
  (or (locate-dominating-file (or buffer-file-name default-directory) "pollen.rkt")
      (user-error "Not inside the site repository (no pollen.rkt above here)")))

(defun od--file (&rest parts)
  (expand-file-name (string-join parts "/") (od-root)))

(defun od--region-text ()
  (when (use-region-p)
    (buffer-substring-no-properties (region-beginning) (region-end))))

(defun od--wrap (before after &optional default)
  "Wrap the region in BEFORE and AFTER (EMACS-2), or insert DEFAULT between them.
Leave point after AFTER, or inside when there was nothing to wrap."
  (if (use-region-p)
      (let ((beg (region-beginning)) (end (region-end)))
        (goto-char end) (insert after)
        (goto-char beg) (insert before)
        (goto-char (+ end (length before) (length after))))
    (insert before (or default ""))
    (save-excursion (insert after))
    (when default (forward-char (length after)))))

(defun od-slugify (title)
  "Propose a permanent id from TITLE: lowercase, hyphenated."
  (let* ((s (downcase (string-trim title)))
         (s (replace-regexp-in-string "['’]" "" s))
         (s (replace-regexp-in-string "[^a-z0-9]+" "-" s)))
    (string-trim s "-" "-")))

(defun od--valid-id-p (id)
  (string-match-p "\\`[a-z0-9]+\\(-[a-z0-9]+\\)*\\'" id))

;;; The lozenge (EMACS-1) ---------------------------------------------------

(defun od-insert-lozenge ()
  "Insert ◊."
  (interactive)
  (insert "◊"))

(when (and od-set-mac-option-keys (eq system-type 'darwin))
  (setq ns-right-alternate-modifier 'none
        mac-right-option-modifier 'none))

;;; Citations ----------------------------------------------------------------

(defun od--zotero-bib ()
  (or od-zotero-bib
      (let ((mk (od--file "local.mk")))
        (when (file-exists-p mk)
          (with-temp-buffer
            (insert-file-contents mk)
            (when (re-search-forward "^ZOTERO_BIB\\s-*\\??=\\s-*\\(.+?\\)\\s-*$" nil t)
              (expand-file-name (match-string 1))))))
      (user-error "Set ZOTERO_BIB in local.mk, or `od-zotero-bib'")))

(defvar od--bib-cache nil "(FILE MTIME . CANDIDATES) for the Zotero export.")

(defun od--bib-candidates ()
  "Alist of (DISPLAY . KEY) from the Zotero export, cached by modification time."
  (let* ((file (od--zotero-bib))
         (mtime (file-attribute-modification-time (file-attributes file))))
    (if (and od--bib-cache (equal (car od--bib-cache) file) (equal (cadr od--bib-cache) mtime))
        (cddr od--bib-cache)
      (let (cands)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (re-search-forward "^@\\w+{\\([^,\n]+\\)," nil t)
            (let* ((key (match-string 1))
                   (end (save-excursion (if (re-search-forward "^@" nil t) (point) (point-max))))
                   (field (lambda (name)
                            (save-excursion
                              (when (re-search-forward (format "^\\s-*%s = {?\\(.*?\\)}?,?$" name) end t)
                                (replace-regexp-in-string "[{}]" "" (match-string 1)))))))
              (push (cons (format "%-40s %s %s — %s" key
                                  (or (funcall field "author") "")
                                  (or (funcall field "year") "")
                                  (or (funcall field "title") ""))
                          key)
                    cands))))
        (setq cands (nreverse cands))
        (setq od--bib-cache (cons file (cons mtime cands)))
        cands))))

(defvar citar-bibliography)

(defun od--select-key ()
  (if (fboundp 'citar-select-ref)
      (let ((citar-bibliography (list (od--zotero-bib))))
        (citar-select-ref))
    (let* ((cands (od--bib-candidates))
           (choice (completing-read "Cite: " cands nil t)))
      (cdr (assoc choice cands)))))

(defun od-insert-cite ()
  "Insert ◊cite[\"key\"] from the Zotero library, asking for a locator."
  (interactive)
  (let* ((key (od--select-key))
         (loc (string-trim (read-string "Locator (e.g. p. 42; empty for none): "))))
    (insert (format "◊cite[\"%s\"%s]" key
                    (if (string-empty-p loc) "" (format " #:loc \"%s\"" loc))))))

;;; Glossary (EMACS-3: read from glossary/ directly, cached by mtime) --------

(defvar od--terms-cache nil "(DIR-MTIME . TERMS); TERMS is a list of (ID HEADWORD ALIASES).")

(defun od--meta (name)
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "◊define-meta\\[%s\\]{\\([^}]*\\)}" name) nil t)
      (string-trim (match-string 1)))))

(defun od--terms ()
  (let* ((dir (od--file "glossary"))
         (files (and (file-directory-p dir) (directory-files dir t "\\.pm\\'")))
         (stamp (mapcar (lambda (f) (file-attribute-modification-time (file-attributes f))) files)))
    (if (and od--terms-cache (equal (car od--terms-cache) (cons files stamp)))
        (cdr od--terms-cache)
      (let ((terms
             (mapcar (lambda (f)
                       (with-temp-buffer
                         (insert-file-contents f)
                         (list (file-name-base f)
                               (or (od--meta "term") (file-name-base f))
                               (let ((a (od--meta "aliases")))
                                 (and a (mapcar #'string-trim (split-string a ";" t)))))))
                     files)))
        (setq od--terms-cache (cons (cons files stamp) terms))
        terms))))

(defun od--term-candidates ()
  "Alist of (DISPLAY . ID): every headword and alias; aliases resolve to the id."
  (apply #'append
         (mapcar (lambda (term)
                   (cl-destructuring-bind (id headword aliases) term
                     (cons (cons headword id)
                           (mapcar (lambda (a) (cons (format "%s (→ %s)" a headword) id)) aliases))))
                 (od--terms))))

(defun od-new-term (&optional headword)
  "Create glossary/<id>.pm for HEADWORD and open it beside the essay.
Return the id."
  (interactive)
  (let* ((headword (or headword (read-string "New term (headword): ")))
         (id (read-string "Id (permanent): " (od-slugify headword)))
         (file (od--file "glossary" (concat id ".pm"))))
    (unless (od--valid-id-p id) (user-error "Ids are lowercase and hyphenated"))
    (when (file-exists-p file) (user-error "glossary/%s.pm already exists" id))
    (make-directory (file-name-directory file) t)
    (with-temp-file file
      (insert "#lang pollen\n\n"
              (format "◊define-meta[term]{%s}\n" headword)
              "◊define-meta[aliases]{}\n"
              "◊define-meta[see-also]{}\n"
              (format "◊define-meta[added]{%s}\n\n" (format-time-string "%Y-%m-%d"))
              "Definition, one to three sentences.\n"))
    (setq od--terms-cache nil)
    (save-selected-window
      (find-file-other-window file)
      (goto-char (point-max))
      (forward-line -1))
    id))

(defun od-insert-term ()
  "Insert ◊term[\"id\"]{…} around the region, choosing from the glossary."
  (interactive)
  (let* ((new "New term…")
         (cands (od--term-candidates))
         (choice (completing-read "Term: " (cons new (mapcar #'car cands)) nil t))
         (region (od--region-text))
         (id (if (equal choice new)
                 (od-new-term region)
               (cdr (assoc choice cands)))))
    (od--wrap (format "◊term[\"%s\"]{" id) "}"
              (unless region (nth 1 (assoc id (od--terms)))))))

(defun od-find-term ()
  "Open a term's file."
  (interactive)
  (let* ((cands (od--term-candidates))
         (choice (completing-read "Find term: " cands nil t)))
    (find-file-other-window (od--file "glossary" (concat (cdr (assoc choice cands)) ".pm")))))

;;; Sections (§8) and links ---------------------------------------------------

(defconst od--heading-re
  "^◊\\(section\\|subsection\\|subsubsection\\)\\[#:id \"\\([^\"]+\\)\"[^]]*\\]{\\([^}]*\\)}")

(defun od--sections ()
  "(LEVEL ID TITLE POS) for each heading in this buffer."
  (save-excursion
    (goto-char (point-min))
    (let (out)
      (while (re-search-forward od--heading-re nil t)
        (push (list (pcase (match-string 1) ("section" 1) ("subsection" 2) (_ 3))
                    (match-string 2) (match-string 3) (match-beginning 0))
              out))
      (nreverse out))))

(defun od--section-candidates ()
  (mapcar (lambda (s)
            (cons (format "%s%s  #%s" (make-string (* 2 (1- (nth 0 s))) ?\s) (nth 2 s) (nth 1 s)) s))
          (od--sections)))

(defun od-goto-section ()
  "Jump to a section in this file."
  (interactive)
  (let* ((cands (od--section-candidates))
         (choice (completing-read "Section: " cands nil t)))
    (push-mark)
    (goto-char (nth 3 (cdr (assoc choice cands))))))

(defun od-insert-link-internal ()
  "Insert ◊link[\"#id\"]{…} to a section of this file."
  (interactive)
  (let* ((cands (od--section-candidates))
         (choice (completing-read "Link to section: " cands nil t)))
    (od--wrap (format "◊link[\"#%s\"]{" (nth 1 (cdr (assoc choice cands)))) "}")))

(defun od-insert-link-essay ()
  "Insert ◊link[\"/slug#id\"]{…}, choosing from data/anchors.json (built by `make')."
  (interactive)
  (let* ((file (od--file "data" "anchors.json"))
         (_ (unless (file-exists-p file) (user-error "No data/anchors.json yet; run make")))
         (json-object-type 'alist) (json-array-type 'list) (json-key-type 'string)
         (pages (json-read-file file))
         (page (completing-read "Page: " (mapcar (lambda (p) (format "%s  %s" (car p) (alist-get "title" (cdr p) nil nil #'equal))) pages) nil t))
         (url (car (split-string page "  ")))
         (sections (alist-get "sections" (cdr (assoc url pages)) nil nil #'equal))
         (whole "(whole page)")
         (cands (cons (cons whole nil)
                      (mapcar (lambda (s) (cons (format "%s%s  #%s"
                                                        (make-string (* 2 (1- (alist-get "level" s nil nil #'equal))) ?\s)
                                                        (alist-get "title" s nil nil #'equal)
                                                        (alist-get "id" s nil nil #'equal))
                                                (alist-get "id" s nil nil #'equal)))
                              sections)))
         (id (cdr (assoc (completing-read "Section: " cands nil t) cands))))
    (od--wrap (format "◊link[\"%s%s\"]{" url (if id (concat "#" id) "")) "}")))

(defun od--used-urls ()
  (let (urls)
    (dolist (f (directory-files-recursively (od-root) "\\.pm\\'"))
      (with-temp-buffer
        (insert-file-contents f)
        (while (re-search-forward "◊link\\[\"\\(https?://[^\"]+\\)\"" nil t)
          (cl-pushnew (match-string 1) urls :test #'equal))))
    (sort urls #'string<)))

(defun od-insert-link-external ()
  "Insert ◊link[\"url\" #:note \"…\"]{…}, offering URLs used before."
  (interactive)
  (let* ((url (completing-read "URL: " (od--used-urls)))
         (note (string-trim (read-string "Note (why a reader might follow it; empty for none): "))))
    (od--wrap (format "◊link[\"%s\"%s]{" url
                      (if (string-empty-p note) "" (format " #:note \"%s\"" note)))
              "}")))

(defun od--current-level ()
  (let ((here (point)) (level 1))
    (dolist (s (od--sections) level)
      (when (< (nth 3 s) here) (setq level (nth 0 s))))))

(defun od-insert-section ()
  "Insert a heading marker with a proposed, checked id."
  (interactive)
  (let* ((names '(("section" . 1) ("subsection" . 2) ("subsubsection" . 3)))
         (default (car (rassoc (od--current-level) names)))
         (tag (completing-read (format "Level (default %s): " default) (mapcar #'car names) nil t nil nil default))
         (title (read-string "Title: " (od--region-text)))
         (taken (mapcar (lambda (s) (nth 1 s)) (od--sections)))
         (id (read-string "Id (permanent): " (od-slugify title))))
    (unless (od--valid-id-p id) (user-error "Ids are lowercase and hyphenated"))
    (when (member id taken) (user-error "#%s is already used in this file" id))
    (when (use-region-p) (delete-region (region-beginning) (region-end)))
    (insert (format "◊%s[#:id \"%s\"%s]{%s}" tag id
                    (if (> (length title) 30)
                        (format " #:short \"%s\"" (read-string "Short title (for the TOC): "))
                      "")
                    title))))

(defun od-insert-aside () "Insert ◊aside{}." (interactive) (od--wrap "◊aside{" "}"))
(defun od-insert-margin () "Insert ◊margin{}." (interactive) (od--wrap "◊margin{" "}"))

;;; Preview ------------------------------------------------------------------

(defun od-preview ()
  "Render this file on the Pollen project server and open it in a browser."
  (interactive)
  (save-buffer)
  (let* ((root (od-root))
         (rel (file-relative-name (file-name-sans-extension buffer-file-name) root))
         (url (format "http://localhost:%d/%s" od-preview-port rel)))
    (unless (get-buffer-process "*od-serve*")
      (let ((default-directory root))
        (start-process "od-serve" "*od-serve*" "make" "serve")
        (sleep-for 2)))
    (browse-url url)))

;;; Figures and tables (IMG-7) ---------------------------------------------------

(defun od--exhibit-ids ()
  "The ids of the figures and tables in this buffer, as (ID . KIND TITLE)."
  (let (ids)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "◊\\(figure\\|table\\|table-csv\\)\\[" nil t)
        (let* ((kind (if (equal (match-string 1) "figure") "Figure" "Table"))
               (start (point))
               (end (save-excursion (condition-case nil (progn (backward-char) (forward-sexp) (point))
                                      (error (line-end-position 6)))))
               (text (buffer-substring-no-properties start end))
               (id (and (string-match "#:id \"\\([^\"]+\\)\"" text) (match-string 1 text)))
               (title (and (string-match "#:title \"\\([^\"]+\\)\"" text)
                           (replace-regexp-in-string "[ \t\n]+" " " (match-string 1 text)))))
          (when id (push (cons (format "%s  %s: %s" id kind (or title "")) id) ids)))))
    (nreverse ids)))

(defun od-insert-ref ()
  "Insert ◊ref[\"id\"] for a figure or table in this file."
  (interactive)
  (let ((cands (od--exhibit-ids)))
    (unless cands (user-error "No figure or table with an #:id in this file"))
    (insert (format "◊ref[\"%s\"]" (cdr (assoc (completing-read "Figure or table: " cands nil t) cands))))))

;;; Tags (INDEX-3) --------------------------------------------------------------

(defun od--used-tags ()
  "Every tag used in a ◊define-meta[tags] line anywhere in the site."
  (let (tags)
    (dolist (f (directory-files-recursively (od-root) "\\.pm\\'"))
      (with-temp-buffer
        (insert-file-contents f)
        (when (re-search-forward "◊define-meta\\[tags\\]{\\([^}]*\\)}" nil t)
          (dolist (tag (split-string (match-string 1) "," t "[ \t]+"))
            (cl-pushnew tag tags :test #'equal)))))
    (sort tags #'string<)))

(defun od-set-tags ()
  "Set this essay's tags, choosing from those already in use (comma-separated).
Replaces the ◊define-meta[tags] line, or adds one after the other meta lines."
  (interactive)
  (let* ((current (let ((v (od--meta "tags"))) (and v (split-string v "," t "[ \t]+"))))
         (chosen (completing-read-multiple "Tags (comma-separated): " (od--used-tags)
                                           nil nil (and current (string-join current ","))))
         (line (format "◊define-meta[tags]{%s}"
                       (string-join (delete-dups (mapcar (lambda (s) (downcase (string-trim s))) chosen)) ", "))))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^◊define-meta\\[tags\\]{[^}]*}$" nil t)
          (replace-match line t t)
        (goto-char (point-min))
        (while (re-search-forward "^◊define-meta\\[" nil t) (forward-line 1))
        (unless (bolp) (insert "\n"))
        (insert line "\n")))))

;;; Vocabulary (VOCAB-1…4) ----------------------------------------------------

;; One entry per line, so pollen-test.rkt can read it (VOCAB-3). Each entry:
;;   (TAG :pos ARG :kw (KEYWORD…) :req (REQUIRED…) :body B :block B :built B [:only KIND])
;; :pos   the positional argument in [...], or nil
;; :body  t when the tag takes text in {...}; nil when it takes none
;;        (◊br{} and ◊break{} may still be written with empty braces)
;; :block t when the tag must start a line
;; :built nil for tags in SPEC §3.3 that pollen.rkt does not provide yet:
;;        they complete, but highlight as errors (VOCAB-2)
;; :only  the one kind of file where the tag belongs (see `od-file-kind')
(defconst od-vocabulary
  '((define-meta   :pos key    :kw ()                                                    :req ()                    :body t   :block t   :built t)
    (section       :pos nil    :kw (id short)                                            :req (id)                  :body t   :block t   :built t)
    (subsection    :pos nil    :kw (id short)                                            :req (id)                  :body t   :block t   :built t)
    (subsubsection :pos nil    :kw (id short)                                            :req (id)                  :body t   :block t   :built t)
    (summary       :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built t)
    (link          :pos target :kw (note title author date)                              :req ()                    :body t   :block nil :built t)
    (cite          :pos key    :kw (loc note)                                            :req ()                    :body nil :block nil :built t)
    (term          :pos id     :kw (mark)                                                :req ()                    :body t   :block nil :built t)
    (aside         :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (margin        :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (sc            :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (em            :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (strong        :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (code          :pos nil    :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (anchor        :pos id     :kw ()                                                    :req ()                    :body nil :block nil :built t)
    (ref           :pos id     :kw ()                                                    :req ()                    :body nil :block nil :built t)
    (br            :pos nil    :kw ()                                                    :req ()                    :body nil :block nil :built t)
    (break         :pos nil    :kw ()                                                    :req ()                    :body nil :block t   :built t)
    (blockquote    :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built t)
    (epigraph      :pos nil    :kw (source)                                              :req ()                    :body t   :block t   :built t)
    (list          :pos nil    :kw (start columns)                                       :req ()                    :body t   :block t   :built t)
    (table         :pos nil    :kw (id title caption source size sortable align row-headers) :req (id title)        :body t   :block t   :built t)
    (table-csv     :pos path   :kw (id title caption source size sortable align row-headers) :req (id title)        :body nil :block t   :built t)
    (sort-key      :pos value  :kw ()                                                    :req ()                    :body t   :block nil :built t)
    (figure        :pos src    :kw (id title alt licence credit invert)                  :req (id title alt licence) :body t  :block t   :built t)
    (more          :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built t :only glossary)
    (essay-index   :pos nil    :kw ()                                                    :req ()                    :body nil :block t   :built t :only home)
    (header-sample :pos nil    :kw (title subtitle published revised tags epistemic)     :req (title)               :body t   :block t   :built t :only specimen)
    (embed         :pos name   :kw (alt fallback sticky)                                 :req ()                    :body t   :block t   :built nil)
    (changelog     :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built nil))
  "The site's Pollen vocabulary: what the highlighter, completion and checks read.")

(defun od--tag (name)
  "The vocabulary entry for tag NAME (a string or symbol), or nil."
  (assq (if (stringp name) (intern name) name) od-vocabulary))

(defun od--tag-get (name prop)
  (plist-get (cdr (od--tag name)) prop))

;; VOCAB-4: meta keys by kind of file.
(defconst od-meta-keys
  '((essay    . (title subtitle status published epistemic abstract tags specimen unlisted))
    (page     . (title subtitle status published epistemic abstract tags specimen unlisted))
    (glossary . (term aliases see-also added)))
  "Allowed ◊define-meta keys for each kind of file.")

(defconst od-statuses '("draft" "published" "revised" "superseded")
  "Values of ◊define-meta[status] (`essay-statuses' in lib/util.rkt).")

(defun od-file-kind (&optional file)
  "What FILE (default: this buffer's) is, from its repository path (MODE-3).
One of `essay', `page', `home', `specimen', `glossary', `fixture', or nil
outside the repository or in an essay's support/ folder. `home' and
`specimen' are pages with a tag of their own."
  (let* ((file (or file buffer-file-name))
         (root (and file (locate-dominating-file file "pollen.rkt")))
         (rel (and root (file-relative-name file root))))
    (cond ((null rel) nil)
          ((string-match-p "\\`essays/[^/]+/support/" rel) nil)
          ((string-match-p "\\`essays/" rel) 'essay)
          ((string-match-p "\\`glossary/" rel) 'glossary)
          ((string-match-p "\\`tests/" rel) 'fixture)
          ((string= rel "index.html.pm") 'home)
          ((string= rel "pages/specimen.html.pm") 'specimen)
          (t 'page))))

;;; Syntax (SYN-1…4) ------------------------------------------------------------

;; SYN-1: prose first. Brackets, braces and quotes are punctuation; the
;; propertize step below turns them into parens and strings only where they
;; belong to a tag. The apostrophe is a word constituent with no prefix flag,
;; so "don't" is one word and nothing treats it as Lisp quote.
(defvar od-syntax-table
  (let ((st (make-syntax-table text-mode-syntax-table)))
    (dolist (c '(?\{ ?\} ?\[ ?\] ?\" ?◊ ?- ?_)) (modify-syntax-entry c "." st))
    (modify-syntax-entry ?' "w" st)
    st)
  "Syntax table for `occurrent-mode'.")

(defconst od--name-re "◊\\([a-z][a-z0-9-]*\\)"
  "A tag: the lozenge and a name (group 1).")

(defun od--put-syntax (pos syntax)
  (put-text-property pos (1+ pos) 'syntax-table (string-to-syntax syntax)))

(defun od--scan-args (open limit)
  "Mark the argument group whose `[' is at OPEN; return the position after its `]'.
Inside the group, `\"' delimits strings (which may span lines and hold `\\\"')
and `[' `]' nest. Return nil if the group is not closed before LIMIT."
  (save-excursion
    (goto-char (1+ open))
    (let ((depth 1) (in-string nil) close)
      (while (and (not close) (< (point) limit))
        (let ((c (char-after)))
          (cond
           (in-string
            (cond ((eq c ?\\) (od--put-syntax (point) "\\") (forward-char 1))
                  ((eq c ?\") (od--put-syntax (point) "\"") (setq in-string nil))))
           ((eq c ?\") (od--put-syntax (point) "\"") (setq in-string t))
           ((eq c ?\[) (setq depth (1+ depth)) (od--put-syntax (point) "(]"))
           ((eq c ?\])
            (setq depth (1- depth))
            (od--put-syntax (point) ")[")
            (when (= depth 0) (setq close (1+ (point)))))))
        (forward-char 1))
      (when close (od--put-syntax open "(]"))
      close)))

(defun od--scan-body (open limit)
  "Mark the body whose `{' is at OPEN, with every brace inside it, and every tag
inside it; return the position after its `}', or nil if it is not closed
before LIMIT (Pollen requires braces to balance inside bodies)."
  (save-excursion
    (goto-char (1+ open))
    (let ((depth 1) close)
      (while (and (not close) (< (point) limit))
        (cond
         ((looking-at "◊;")                    ; a comment inside a body
          (goto-char (od--scan-comment (point) limit)))
         ((looking-at od--name-re)              ; a nested tag: its arguments too
          (goto-char (od--scan-tag (point) limit)))
         (t
          (let ((c (char-after)))
            (cond ((eq c ?\{) (setq depth (1+ depth)) (od--put-syntax (point) "(}"))
                  ((eq c ?\})
                   (setq depth (1- depth))
                   (od--put-syntax (point) "){")
                   (when (= depth 0) (setq close (1+ (point))))))
            (forward-char 1)))))
      (when close (od--put-syntax open "(}"))
      close)))

(defun od--scan-comment (start limit)
  "Mark the comment at START (`◊;' to end of line, or `◊;{…}'); return its end."
  (save-excursion
    (goto-char start)
    (od--put-syntax start "!")                 ; generic comment fence
    (if (eq (char-after (+ start 2)) ?\{)
        (let ((end (od--scan-body (+ start 2) limit)))
          (if end (progn (od--put-syntax (1- end) "!") end) (line-end-position)))
      (let ((eol (line-end-position)))
        (when (< eol (point-max)) (od--put-syntax eol "!"))
        (min limit (1+ eol))))))

(defun od--scan-tag (start limit)
  "Mark the tag whose lozenge is at START: its name as a symbol, its argument
group, its body. Return the position after the tag."
  (save-excursion
    (goto-char start)
    (looking-at od--name-re)
    (let ((p (match-end 0)))
      ;; the name is one symbol, hyphens included
      (od--put-syntax start "_")
      (cl-loop for i from (match-beginning 1) below p
               when (memq (char-after i) '(?- ?_)) do (od--put-syntax i "_"))
      (when (eq (char-after p) ?\[)
        (setq p (or (od--scan-args p limit) (1+ p))))
      (when (eq (char-after p) ?\{)
        (setq p (or (od--scan-body p limit) (1+ p))))
      p)))

(defun od-syntax-propertize (start end)
  "SYN-2: give brackets, braces and quotes their syntax where a tag owns them.
Anything else (\"quoted words\", [sic], a stray brace) stays punctuation."
  (goto-char start)
  (let ((limit (point-max)))
    (while (re-search-forward "◊" end t)
      (let ((at (1- (point))))
        (cond
         ((eq (char-after (point)) ?\;) (goto-char (od--scan-comment at limit)))
         ((save-excursion (goto-char at) (looking-at od--name-re))
          (goto-char (max (point) (od--scan-tag at limit))))
         ((eq (char-after (point)) ?\{)      ; a bare ◊{…}: legal Scribble, never wanted
          (goto-char (or (od--scan-body (point) limit) (1+ (point))))))))))

(defun od--syntax-extend-region (start end)
  "Start propertizing at the tag enclosing START, so a body that began above is
scanned from its lozenge. Return (START . END) when the region changed."
  (let* ((ppss (save-excursion (syntax-ppss start)))
         (outer (car (nth 9 ppss))))
    (when outer
      (let ((tag (save-excursion
                   (goto-char outer)
                   (when (re-search-backward "◊[a-z][a-z0-9-]*\\=\\|◊[a-z][a-z0-9-]*\\[" (line-beginning-position 0) t)
                     (point)))))
        (when (and tag (< tag start)) (cons tag end))))))

;; SYN-3: forward-sexp over a whole tag from its lozenge.
(defun od-forward-sexp (&optional arg)
  "Move over ARG sexps; from a lozenge, over the whole tag (name, [...], {...})."
  (setq arg (or arg 1))
  (if (< arg 0)
      (let ((forward-sexp-function nil)) (forward-sexp arg)
           (when (looking-back od--name-re (line-beginning-position)) (goto-char (match-beginning 0))))
    (dotimes (_ arg)
      (skip-chars-forward " \t\n")
      (if (looking-at od--name-re)
          (progn
            (goto-char (match-end 0))
            (when (eq (char-after) ?\[) (goto-char (scan-lists (point) 1 0)))
            (when (eq (char-after) ?\{) (goto-char (scan-lists (point) 1 0))))
        (let ((forward-sexp-function nil)) (forward-sexp 1))))))

;;; Mode: keys, imenu and outline (EMACS-4), dimmed markup (EMACS-5) ----------

(defvar occurrent-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "C-c ;") #'od-insert-lozenge)
    (define-key m (kbd "C-c o c") #'od-insert-cite)
    (define-key m (kbd "C-c o t") #'od-insert-term)
    (define-key m (kbd "C-c o n") #'od-new-term)
    (define-key m (kbd "C-c o f") #'od-find-term)
    (define-key m (kbd "C-c o i") #'od-insert-link-internal)
    (define-key m (kbd "C-c o e") #'od-insert-link-essay)
    (define-key m (kbd "C-c o x") #'od-insert-link-external)
    (define-key m (kbd "C-c o s") #'od-insert-section)
    (define-key m (kbd "C-c o g") #'od-goto-section)
    (define-key m (kbd "C-c o a") #'od-insert-aside)
    (define-key m (kbd "C-c o m") #'od-insert-margin)
    (define-key m (kbd "C-c o p") #'od-preview)
    (define-key m (kbd "C-c o T") #'od-set-tags)
    (define-key m (kbd "C-c o r") #'od-insert-ref)
    m)
  "Keys for `occurrent-mode'.")

(defconst od--font-lock
  '(("◊[[:alnum:]-]+" 0 'od-markup-face prepend)
    ("#:[[:alnum:]-]+" 0 'od-markup-face prepend)
    ("[][{}]" 0 'od-markup-face prepend)))

(defun od--outline-level ()
  (save-excursion
    (beginning-of-line)
    (cond ((looking-at "◊section\\[") 1)
          ((looking-at "◊subsection\\[") 2)
          (t 3))))

(defun od--meta-line-p ()
  "Non-nil on a ◊define-meta line: its value must stay on one line."
  (save-excursion (beginning-of-line) (looking-at-p "◊define-meta\\[")))

;;;###autoload
(define-minor-mode occurrent-mode
  "Commands for writing occurrentdevelopment.com essays in Pollen."
  :lighter " ◊"
  :keymap occurrent-mode-map
  (if occurrent-mode
      (progn
        (setq-local imenu-generic-expression
                    `((nil ,(concat od--heading-re) 3)))
        (setq-local outline-regexp "◊\\(sub\\)*section\\[")
        (setq-local outline-level #'od--outline-level)
        (outline-minor-mode 1)
        ;; Pollen reads a wrapped ◊define-meta value as extra key/value pairs,
        ;; so filling never touches meta lines.
        (setq-local paragraph-separate (concat "◊define-meta\\[.*$\\|" paragraph-separate))
        (add-hook 'fill-nobreak-predicate #'od--meta-line-p nil t)
        (font-lock-add-keywords nil od--font-lock 'append))
    (outline-minor-mode -1)
    (remove-hook 'fill-nobreak-predicate #'od--meta-line-p t)
    (font-lock-remove-keywords nil od--font-lock))
  (font-lock-flush))

(provide 'occurrent)
;;; occurrent.el ends here
