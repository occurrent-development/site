;;; occurrent.el --- Writing occurrentdevelopment.com in Pollen  -*- lexical-binding: t; -*-

;; Commands for SPEC.md §16. Every picker uses plain `completing-read', so
;; it works with Vertico, Ivy, Helm or the default UI.
;;
;; Setup, in your init file (LOAD-2):
;;
;;   (add-to-list 'load-path "~/Documents/Ryan/Personal/Projects/Occurrent-Development/site/emacs")
;;   (require 'occurrent)   ; .pm files open in `occurrent-mode'
;;
;; `occurrent-mode-hook' is the place for flyspell, visual-line-mode and the
;; like; the mode turns none of them on. `C-c o I' opens a guide.
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

(defcustom od-site-directory nil
  "The site repository, used when the current buffer is not inside it.
With it set, `C-c o N' and the other global keys work from anywhere,
dired included."
  :type '(choice (const nil) directory))

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
  "The repository root: the directory holding pollen.rkt.
Found above the current file or directory, or else `od-site-directory'."
  (or (locate-dominating-file (or buffer-file-name default-directory) "pollen.rkt")
      (and od-site-directory
           (file-exists-p (expand-file-name "pollen.rkt" od-site-directory))
           (file-name-as-directory (expand-file-name od-site-directory)))
      (user-error "Not inside the site repository, and `od-site-directory' is not set")))

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
  "Insert ◊link[\"#id\"]{…} to a section, figure, table or anchor in this file."
  (interactive)
  (let* ((cands (od--id-candidates))
         (choice (completing-read "Link to: " cands nil t)))
    (od--wrap (format "◊link[\"#%s\"]{" (cdr (assoc choice cands))) "}")))

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

(defun od--site-pm-files ()
  "Every .pm file of the site, skipping support/, public/ and compiled/ (EDIT-6)."
  (cl-remove-if (lambda (f) (string-match-p "/\\(support\\|public\\|compiled\\)/" f))
                (directory-files-recursively (od-root) "\\.pm\\'")))

(defun od--used-urls ()
  (let (urls)
    (dolist (f (od--site-pm-files))
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

(defun od-insert-ref ()
  "Insert ◊ref[\"id\"] for a figure or table in this file."
  (interactive)
  (let ((cands (od--id-candidates '(figure table))))
    (unless cands (user-error "No figure or table with an #:id in this file"))
    (insert (format "◊ref[\"%s\"]" (cdr (assoc (completing-read "Figure or table: " cands nil t) cands))))))

;;; Tags (INDEX-3) --------------------------------------------------------------

(defun od--used-tags ()
  "Every tag used in a ◊define-meta[tags] line anywhere in the site."
  (let (tags)
    (dolist (f (od--site-pm-files))
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

(declare-function orgtbl-mode "org-table")
(declare-function org-table-align "org-table")
(declare-function magit-status-setup-buffer "magit-status")

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
    (abstract      :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built t)
    (epistemic     :pos nil    :kw ()                                                    :req ()                    :body t   :block t   :built t)
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
  '((essay    . (title subtitle status published tags specimen unlisted))
    (page     . (title subtitle status published tags specimen unlisted))
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
    ;; a tag scanned whole may end beyond END: stop there
    (while (and (< (point) end) (re-search-forward "◊" end t))
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

;;; The guide (EDIT-9) -----------------------------------------------------------

(defconst od--guide
  "#+title: Writing occurrentdevelopment.com: the three workflows
Press q to close. TAB on a heading folds it. Keys marked (not built yet)
do nothing for now; the marks go as the commands arrive.

From anywhere in Emacs, dired included: C-c o N starts an essay, C-c o I
opens this guide, C-c o k checks the whole site, C-c o d watches a deploy.
The other keys work inside an essay.

* 1. Starting a new essay

1. {od-new-essay} and give the title. It proposes a slug (the URL,
   /slug, permanent once published) and creates:
   - essays/<slug>/<slug>.html.pm, the essay, opened for you
   - essays/<slug>/img/, for its figures
   - essays/<slug>/support/notes.md, for everything else: notes, sources,
     old drafts in Word or LaTeX. support/ is never published, before or
     after publication.
   The essay is a draft: git cannot see it, so it cannot be committed or
   pushed by accident.

2. Fill in the meta lines at the top: subtitle, and tags with
   {od-set-tags}. Each stays on one line (M-q leaves them alone).
   Below them, write ◊epistemic{…}, one sentence on how sure you are, and
   ◊abstract{…} if the essay has one. These wrap like any paragraph and
   may hold emphasis, citations and terms; the build moves them into the
   header. Left empty, they are left out.

3. Write. Paragraphs are separated by a blank line. Just type: each
   paragraph is one line in the file, shown wrapped on screen, so there is
   nothing to refill. M-q joins an old hard-wrapped paragraph onto one line.
   - ◊ is {od-insert-lozenge}
   - a section heading: {od-insert-section} (its id is permanent: links
     depend on it)
   - a citation: {od-insert-cite}; a defined term: {od-insert-term}
     (a new one: {od-new-term})
   - an aside: {od-insert-aside}; a margin note: {od-insert-margin}
   - links: within the essay {od-insert-link-internal}, to another essay
     {od-insert-link-essay}, to the web {od-insert-link-external}
   - a figure: put the image in img/, then {od-insert-figure}; a table:
     {od-insert-table}; refer to either with {od-insert-ref}
   - a note to yourself: M-; (hidden from the page)
   - jump between sections: {od-goto-section}

4. Look at it: {od-preview} opens it in the browser. Check it: {od-check}
   runs the tests and renders this file; errors open with M-g n. Anything
   highlighted in red in the buffer is an error the build would refuse.

5. Leave it as long as you like. Drafts are not in git, so they are not
   backed up by it: keep the Mac's backup running.

* 2. Publishing an essay

1. {od-check} first, and fix anything it reports.

2. {od-publish}. It:
   - makes the essay visible to git
   - sets status to published (after asking) and the published date to
     today if there is none
   - adds the essay to the site's index
   - runs make refresh (needs the network and your current Zotero export:
     it copies the essay's references into the site) and then make
   - shows the row the home page will gain: check the title, date and tags
   - stages everything and opens Magit
   It never pushes by itself.

3. In Magit, read the diff: this is what becomes public, permanently.
   Then c c to commit (the message Publish: <title> is proposed),
   C-c C-c to confirm, and P p to push. The push is the publication.

4. {od-deploy-status} watches the build on GitHub and opens the essay
   when it is live, at occurrentdevelopment.com/<slug>, about a minute
   later.

Shortcut, once you trust it: C-u {od-publish} does all of the above and
commits and pushes after one confirmation.

To withdraw an essay there is no command: set status to superseded and
commit it as a revision. The source stays in the history.

* 3. Revising a published essay

1. Edit the essay. It is in git now, so Magit shows every change.

2. {od-check}.

3. {od-commit} asks what kind of change it is:
   - Typo: spelling, punctuation. The essay's Revised date stays.
   - Meta: tags, subtitle and the like. The Revised date stays.
   - Revision: anything a reader should know changed. The Revised date
     moves to today (it comes from git), and the essay's changelog should
     gain a line saying what changed.
   It stages the essay and opens Magit.

4. As before: c c, C-c C-c, P p, then {od-deploy-status}.

* When something goes wrong

- The build error names the file but not the line: look for red in the
  buffer, which marks the place.
- make refresh failed: you are offline, or the Zotero export is stale.
  Reconnect, let Better BibTeX update the export, and publish again.
- Magit refused, or this guide's commands say you are not on main or
  are behind origin: in Magit, F p to pull, then try again.
- Pushed something by mistake: tell Claude before doing anything else.
"
  "The text of `od-guide': {command} is replaced by its key.")

(defvar occurrent-mode-map)

(defconst od--planned-keys
  '((od-new-essay . "C-c o N") (od-insert-figure . "C-c o F") (od-insert-table . "C-c o B")
    (od-check . "C-c o k") (od-publish . "C-c o P") (od-commit . "C-c o C")
    (od-deploy-status . "C-c o d") (od-unwrap . "C-c o u") (od-up . "C-c o U"))
  "Keys for commands still to be built (HANDOVER-EMACS LOAD-4), for the guide.")

(defun od--guide-key (cmd)
  "CMD's key, marked when CMD is not built yet."
  (let ((key (where-is-internal cmd occurrent-mode-map t)))
    (concat (cond (key (key-description key))
                  ((alist-get cmd od--planned-keys))
                  (t (format "M-x %s" cmd)))
            (if (fboundp cmd) "" " (not built yet)"))))

;;;###autoload
(defun od-guide ()
  "Open the guide to starting, publishing and revising an essay (EDIT-9)."
  (interactive)
  (let ((buf (get-buffer-create "*Occurrent guide*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (replace-regexp-in-string
                 "{\\([a-z-]+\\)}"
                 (lambda (m) (od--guide-key (intern (match-string 1 m))))
                 od--guide t t))
        (if (fboundp 'org-mode) (org-mode) (text-mode))
        (goto-char (point-min)))
      (view-mode 1)
      (setq-local view-exit-action #'kill-buffer))
    (pop-to-buffer buf)))

;;; Faces (§5) -------------------------------------------------------------------

;; Prose dominates; markup recedes; errors stand out (EMACS-5). Every face
;; inherits from a standard one, so themes work; retune them in your config.
(defface od-string-face '((t :inherit font-lock-string-face))
  "Strings inside argument groups: keys, URLs, notes.")
(defface od-id-face '((t :inherit font-lock-constant-face))
  "Permanent identifiers: #:id values, term ids, cite keys, anchors, ◊ref targets.")
(defface od-heading-1-face '((t :inherit outline-1)) "Level-1 heading titles.")
(defface od-heading-2-face '((t :inherit outline-2)) "Level-2 heading titles.")
(defface od-heading-3-face '((t :inherit outline-3 :slant italic :weight normal))
  "Level-3 (run-in) heading titles.")
(defface od-meta-key-face '((t :inherit font-lock-keyword-face)) "The key of ◊define-meta.")
(defface od-aside-face '((t :inherit shadow :slant italic))
  "The text of ◊aside and ◊margin, so a digression reads as one.")
(defface od-quote-face '((t :slant italic)) "The text of ◊epigraph and ◊blockquote.")
(defface od-term-face '((t :inherit font-lock-type-face :weight normal)) "The text of ◊term.")
(defface od-code-face '((t :inherit fixed-pitch)) "The text of ◊code.")
(defface od-list-marker-face '((t :inherit od-markup-face))
  "List markers (- and 1.) and table pipes.")
(defface od-error-face '((t :inherit font-lock-warning-face :inverse-video t))
  "What the build would refuse, or would get silently wrong (FL-6).")

;;; Reading tags ----------------------------------------------------------------

(defconst od--racket-forms
  '("define" "if" "let" "lambda" "require" "quote" "unquote" "set!" "begin" "when" "unless" "cond")
  "Racket forms that, after ◊, corrupt a page without failing the build.")

(defun od--tag-parse (start)
  "Parse the tag whose lozenge is at START.
Return a plist: :start :name :name-end :args (OPEN . CLOSE-or-nil)
:body (OPEN . CLOSE-or-nil) :end. Relies on `od-syntax-propertize'."
  (save-excursion
    (goto-char start)
    (when (looking-at "◊\\([a-z][a-z0-9!?*-]*\\)")
      (let* ((name (match-string-no-properties 1))
             (name-end (match-end 0))
             (p name-end) args body)
        (when (eq (char-after p) ?\[)
          (let ((e (ignore-errors (scan-lists p 1 0))))
            (setq args (cons p e))
            (when e (setq p e))))
        (when (and (or (null args) (cdr args)) (eq (char-after p) ?\{))
          (let ((e (ignore-errors (scan-lists p 1 0))))
            (setq body (cons p e))
            (when e (setq p e))))
        (list :start start :name name :name-end name-end :args args :body body :end p)))))

(defun od--args (open close)
  "The items in the argument group from OPEN (its `[') to CLOSE (after `]').
Each is (KIND TEXT BEG END), KIND being `string', `keyword' or `token'."
  (save-excursion
    (goto-char (1+ open))
    (let (out (stop (1- close)))
      (while (progn (skip-chars-forward " \t\n" stop) (< (point) stop))
        (let ((b (point)))
          (cond
           ((eq (char-after) ?\")
            (forward-char 1)
            (while (and (< (point) stop) (not (eq (char-after) ?\")))
              (when (eq (char-after) ?\\) (forward-char 1))
              (forward-char 1))
            (forward-char 1)
            (push (list 'string (buffer-substring-no-properties (1+ b) (max (1+ b) (1- (point)))) b (point)) out))
           ((looking-at "#:\\([a-z0-9-]+\\)")
            (goto-char (match-end 0))
            (push (list 'keyword (match-string-no-properties 1) b (point)) out))
           (t (skip-chars-forward "^ \t\n\"" stop)
              (when (= b (point)) (forward-char 1))
              (push (list 'token (buffer-substring-no-properties b (point)) b (point)) out)))))
      (nreverse out))))

(defun od--args-split (items)
  "Split ITEMS into (POSITIONAL . ((KEYWORD-SYMBOL KW-ITEM VALUE-ITEM) …))."
  (let* ((pos (and items (not (eq (caar items) 'keyword)) (pop items)))
         kws)
    (while items
      (let ((it (pop items)))
        (if (eq (car it) 'keyword)
            (push (list (intern (nth 1 it)) it
                        (and items (not (eq (caar items) 'keyword)) (pop items)))
                  kws)
          (push (list nil it nil) kws))))
    (cons pos (nreverse kws))))

(defun od--paren-tag-start (pos)
  "The lozenge of the tag that owns the `[' or `{' at POS, or nil."
  (save-excursion
    (goto-char pos)
    (when (and (eq (char-after) ?\{) (eq (char-before) ?\]))
      (goto-char (or (ignore-errors (scan-lists (point) -1 0)) (point))))
    (skip-chars-backward "a-z0-9-")
    (when (eq (char-before) ?◊) (1- (point)))))

(defun od--enclosing-tag (&optional pos)
  "The parse of the innermost tag whose `[...]' or `{...}' contains POS."
  (let* ((pos (or pos (point)))
         (open (nth 1 (syntax-ppss pos)))
         (start (and open (od--paren-tag-start open))))
    (and start (append (od--tag-parse start) (list :open open)))))

;;; The ids in a file (FL-6, shared with the pickers) ---------------------------------

(defvar-local od--ids-cache nil "(TICK . IDS) for `od--ids'.")

(defun od--ids ()
  "Ids defined in this buffer, in order: a list of (ID KIND POS TITLE).
KIND is `heading', `figure', `table' or `anchor'."
  (if (eq (car od--ids-cache) (buffer-chars-modified-tick))
      (cdr od--ids-cache)
    (let (out)
      (save-excursion
        (save-match-data
          (syntax-propertize (point-max))
          (goto-char (point-min))
          (while (re-search-forward "◊\\(section\\|subsection\\|subsubsection\\|figure\\|table-csv\\|table\\|anchor\\)\\[" nil t)
            (let* ((start (match-beginning 0))
                   (name (match-string-no-properties 1))
                   (tag (od--tag-parse start))
                   (args (plist-get tag :args))
                   (split (and (cdr args) (od--args-split (od--args (car args) (cdr args)))))
                   (kw (lambda (k) (let ((e (assq k (cdr split)))) (and e (nth 2 e) (nth 1 (nth 2 e))))))
                   (kind (pcase name ("figure" 'figure) ((or "table" "table-csv") 'table) ("anchor" 'anchor) (_ 'heading)))
                   (id (if (eq kind 'anchor) (and (car split) (nth 1 (car split))) (funcall kw 'id)))
                   (body (plist-get tag :body))
                   (title (pcase kind
                            ((or 'figure 'table) (funcall kw 'title))
                            ('heading (and body (cdr body)
                                           (buffer-substring-no-properties (1+ (car body)) (1- (cdr body))))))))
              (when id
                (push (list id kind start
                            (and title (replace-regexp-in-string "[ \t\n]+" " " title)))
                      out))
              (goto-char (max (point) (plist-get tag :name-end))))))
        (setq out (nreverse out))
        (setq od--ids-cache (cons (buffer-chars-modified-tick) out))
        out))))

(defun od--id-candidates (&optional kinds)
  "Alist of (DISPLAY . ID) for the ids of KINDS (default: all) in this file."
  (cl-loop for (id kind _pos title) in (od--ids)
           when (or (null kinds) (memq kind kinds))
           collect (cons (format "%-24s %s: %s" id
                                 (pcase kind ('heading "Section") ('figure "Figure") ('table "Table") (_ "Anchor"))
                                 (or title ""))
                         id)))

;;; Highlighting (FL-1…7) ----------------------------------------------------------

(defvar-local od-file-kind-override nil
  "When non-nil, the file kind `od-file-kind' reports (for tests and odd files).")

(defun od--face (beg end face)
  "Put FACE on BEG..END in front of any face already there (markup, errors)."
  (when (< beg end) (font-lock-prepend-text-property beg end 'face face)))

(defun od--face-under (beg end face)
  "Put FACE on BEG..END behind any face already there (the faces of bodies)."
  (when (< beg end) (font-lock-append-text-property beg end 'face face)))

(defun od--error (beg end message)
  "Mark BEG..END as an error, with MESSAGE as its tooltip."
  (when (< beg end)
    (od--face beg end 'od-error-face)
    (put-text-property beg end 'help-echo message)))

(defun od--kind ()
  (or od-file-kind-override (ignore-errors (od-file-kind))))

(defun od--fontify (limit)
  "Font-lock matcher: highlight every tag from point to LIMIT. Returns nil."
  (syntax-propertize (point-max))
  (let ((kind (od--kind)) (ids (od--ids)))
    (while (re-search-forward "◊" limit t)
      (let ((at (match-beginning 0)))
        (cond
         ((nth 4 (save-excursion (syntax-ppss at))) nil)          ; inside a comment
         ((eq (char-after) ?\;) (goto-char (min limit (line-end-position))))
         ((looking-at "[a-z]") (od--fontify-tag at kind ids))
         (t (od--error at (1+ at) "◊ with no tag name after it: write ◊ only before a tag (FL-6)"))))))
  nil)

(defun od--fontify-tag (at kind ids)
  (let* ((tag (od--tag-parse at))
         (name (plist-get tag :name))
         (name-end (plist-get tag :name-end))
         (entry (od--tag name))
         (args (plist-get tag :args))
         (body (plist-get tag :body))
         (end (plist-get tag :end))
         (only (od--tag-get name :only)))
    (put-text-property at (max end name-end) 'font-lock-multiline t)
    ;; FL-1, FL-6: the name
    (cond
     ((equal name "quote")
      (od--error at name-end "◊quote is not a tag: Racket's quote swallows it. Use ◊blockquote"))
     ((member name od--racket-forms)
      (od--error at name-end (format "◊%s is Racket, not a tag: it would corrupt the page silently" name)))
     ((equal name "p")
      (od--error at name-end "Paragraphs are never written as tags: leave a blank line (SPEC §3.1)"))
     ((null entry)
      (od--error at name-end (format "◊%s is not a tag: the build fails (SRC-2)" name)))
     ((not (od--tag-get name :built))
      (od--error at name-end (format "◊%s is in the spec but not built yet: the build fails (VOCAB-2)" name)))
     ((and only kind (not (memq kind (list only 'fixture))))
      (od--error at name-end (format "◊%s belongs only in %s" name
                                     (pcase only ('glossary "a glossary file") ('home "the home page")
                                            ('specimen "the specimen") (_ only)))))
     (t (od--face at name-end 'od-markup-face)))
    (when entry
      (od--fontify-args name at name-end args kind ids)
      (od--fontify-body name at name-end body kind))
    (goto-char name-end)))

(defun od--fontify-args (name at name-end args kind ids)
  (let ((seen '()))
    (when args
      (od--face (car args) (1+ (car args)) 'od-markup-face)
      (if (not (cdr args))
          (od--error (car args) (1+ (car args)) "this [ is never closed")
        (od--face (1- (cdr args)) (cdr args) 'od-markup-face)
        (let* ((split (od--args-split (od--args (car args) (cdr args))))
               (pos (car split))
               (want-pos (od--tag-get name :pos)))
          ;; the positional argument
          (cond
           ((and pos (not want-pos))
            (od--error (nth 2 pos) (nth 3 pos) (format "◊%s takes no value here, only #:keywords" name)))
           ((and want-pos (not pos))
            (od--error at name-end (format "◊%s needs its %s first in [...]" name want-pos))))
          (when pos
            (pcase name
              ((or "term" "cite" "anchor" "ref") (od--face (nth 2 pos) (nth 3 pos) 'od-id-face))
              ("define-meta" (od--fontify-meta-key pos kind)))
            (od--check-target name pos ids))
          ;; keywords
          (dolist (k (cdr split))
            (let ((sym (nth 0 k)) (kw (nth 1 k)) (val (nth 2 k)))
              (cond
               ((null sym) (od--error (nth 2 kw) (nth 3 kw) "a value with no #:keyword before it"))
               ((memq sym (od--tag-get name :kw))
                (push sym seen)
                (od--face (nth 2 kw) (nth 3 kw) 'od-markup-face)
                (unless val (od--error (nth 2 kw) (nth 3 kw) (format "#:%s has no value" sym)))
                (when (and val (eq sym 'id))
                  (od--face (nth 2 val) (nth 3 val) 'od-id-face)
                  (when (cl-some (lambda (e) (and (equal (car e) (nth 1 val)) (< (nth 2 e) at))) ids)
                    (od--error (nth 2 val) (nth 3 val)
                               (format "#%s is already used in this file (SECT-5, IMG-7)" (nth 1 val))))))
               (t (od--error (nth 2 kw) (nth 3 kw)
                             (if (eq sym 'width)
                                 "#:width is gone: every figure and table is column width (IMG-2)"
                               (format "#:%s is not a keyword of ◊%s" sym name))))))))))
    ;; required keywords: mark the name, there being no argument to point at
    (dolist (r (od--tag-get name :req))
      (unless (memq r seen)
        (od--error at name-end (format "◊%s needs #:%s" name r))))))

(defun od--check-target (name pos ids)
  "FL-6: a same-page ◊link to a missing id; a ◊ref to a non-exhibit."
  (let ((v (nth 1 pos)))
    (pcase name
      ("link"
       (when (and (string-prefix-p "#" v)
                  (not (assoc (substring v 1) ids)))
         (od--error (nth 2 pos) (nth 3 pos)
                    (format "nothing in this file has the id %s (LINK-2)" v))))
      ("ref"
       (let ((e (assoc v ids)))
         (cond ((null e) (od--error (nth 2 pos) (nth 3 pos)
                                    (format "no figure or table in this file has the id %s (IMG-7)" v)))
               ((not (memq (nth 1 e) '(figure table)))
                (od--error (nth 2 pos) (nth 3 pos)
                           (format "#%s is a %s: ◊ref is for figures and tables; use ◊link" v (nth 1 e))))))))))

(defun od--fontify-meta-key (pos kind)
  "FL-4: the key of ◊define-meta, checked against the keys of this kind of file."
  (let* ((key (intern (nth 1 pos)))
         (table (pcase kind
                  ('glossary (alist-get 'glossary od-meta-keys))
                  ((or 'essay 'page 'home 'specimen) (alist-get 'essay od-meta-keys)))))
    (if (and table (not (memq key table)))
        (od--error (nth 2 pos) (nth 3 pos)
                   (format "%s is not a meta key in %s (VOCAB-4)" key
                           (if (eq kind 'glossary) "a glossary file" "an essay or page")))
      (od--face (nth 2 pos) (nth 3 pos) 'od-meta-key-face))))

(defun od--fontify-body (name at name-end body _kind)
  (let ((needs (od--tag-get name :body)))
    (cond
     ((null body)
      (when (and needs (not (member name '("figure" "header-sample"))))
        (od--error at name-end (format "◊%s needs its text in {…}" name))))
     ((null (cdr body))
      (od--error (car body) (1+ (car body)) "this { is never closed (braces must balance)"))
     (t
      (let ((ib (1+ (car body))) (ie (1- (cdr body))))
        (od--face (car body) ib 'od-markup-face)
        (od--face ie (cdr body) 'od-markup-face)
        (when (and (not needs) (string-match-p "[^ \t\n]" (buffer-substring-no-properties ib ie)))
          (od--error (car body) (cdr body) (format "◊%s takes no text in {…}" name)))
        (pcase name
          ("section" (od--face-under ib ie 'od-heading-1-face))
          ("subsection" (od--face-under ib ie 'od-heading-2-face))
          ("subsubsection" (od--face-under ib ie 'od-heading-3-face))
          ((or "aside" "margin") (od--face-under ib ie 'od-aside-face))
          ("term" (od--face-under ib ie 'od-term-face))
          ("code" (od--face-under ib ie 'od-code-face))
          ((or "epigraph" "blockquote") (od--face-under ib ie 'od-quote-face))
          ("list" (od--fontify-list ib ie))
          ("table" (od--fontify-pipes ib ie))
          ("define-meta" (od--fontify-meta-value at (car body) (cdr body)))))))))

(defun od--fontify-meta-value (at open close)
  "FL-4: a meta value stays on one line; status is one of `od-statuses'."
  (if (> close (save-excursion (goto-char open) (line-end-position 1)))
      (od--error at close "a ◊define-meta value must stay on one line (SRC-4)")
    (let ((key (save-excursion (goto-char at)
                               (and (looking-at "◊define-meta\\[\\([a-z-]+\\)\\]") (match-string-no-properties 1))))
          (val (string-trim (buffer-substring-no-properties (1+ open) (1- close)))))
      (when (equal key "status")
        (cond ((equal val "draft") (od--face-under (1+ open) (1- close) 'od-aside-face))
              ((not (member val od-statuses))
               (od--error (1+ open) (1- close)
                          (format "status is one of %s" (string-join od-statuses ", ")))))))))

(defun od--fontify-list (ib ie)
  "FL-5, LIST-7: markers, and items indented to their parent's text column."
  (save-excursion
    (goto-char ib)
    (forward-line 1)
    (let ((cols (list 0)) (blank t) (any nil))
      (while (and (< (point) ie) (not (eobp)))
        (let ((lb (line-beginning-position)) (le (min ie (line-end-position))))
          (cond
           ((looking-at "[ \t]*$") (setq blank t))
           ((looking-at "[ \t]*}") nil)
           ((looking-at "\\( *\\)\\(-\\|[0-9]+\\.\\) ")
            (let ((indent (length (match-string 1))) (content (- (match-end 0) lb)))
              (od--face (match-beginning 2) (match-end 2) 'od-list-marker-face)
              (while (and (cdr cols) (< indent (car cols))) (pop cols))
              (if (= indent (car cols))
                  (push content cols)
                (od--error lb (match-end 2)
                           (format "list item indented %d; it should be %d, under its parent's text (LIST-7)"
                                   indent (car cols)))
                (push content cols))
              (setq blank nil any t)))
           ((not any)
            (od--error lb le "text before the first item, or an unknown marker (- and 1. only) (LIST-7)"))
           ((and blank (looking-at "\\( *\\)")
                 (not (memq (length (match-string 1)) (butlast cols))))
            (od--error lb le "a paragraph inside an item is indented to the item's text (LIST-7)"))
           (t (setq blank nil))))
        (forward-line 1)))))

(defun od--fontify-pipes (ib ie)
  "FL-5: the pipes of a table, quiet."
  (save-excursion
    (goto-char ib)
    (while (re-search-forward "|\\|^[ \t]*|?[-+:|]+$" ie t)
      (od--face (match-beginning 0) (match-end 0) 'od-list-marker-face))))

(defvar font-lock-beg)
(defun od--font-lock-extend-region ()
  "FL-2: refontify from the lozenge of a tag whose body encloses the region."
  (let* ((ppss (save-excursion (syntax-ppss font-lock-beg)))
         (outer (car (nth 9 ppss)))
         (start (and outer (od--paren-tag-start outer))))
    (when (and start (< start font-lock-beg))
      (setq font-lock-beg (save-excursion (goto-char start) (line-beginning-position)))
      t)))

(defun od--syntactic-face (state)
  "Strings in argument groups are quiet; comments look like comments."
  (if (nth 3 state) 'od-string-face 'font-lock-comment-face))

(defconst od--font-lock-keywords
  '(("\\`#lang pollen" 0 'od-markup-face)
    (od--fontify))
  "Font-lock keywords for `occurrent-mode'.")

;;; Editing (EDIT-1…7, EDIT-10) ----------------------------------------------------

(defconst od--block-tags-re
  (concat "◊" (regexp-opt (cl-loop for (name . props) in od-vocabulary
                                   when (plist-get props :block) collect (symbol-name name))
                          t)
          "\\_>")
  "A line starting with a block tag (VOCAB-1).")

;; EDIT-1: lines that are paragraphs of their own, and never filled into
;; their neighbours: meta lines, one-line block tags, closing braces, table
;; rows, #lang.
(defconst od--paragraph-separate
  (concat "[ \t\f]*$"
          "\\|◊\\(define-meta\\|section\\|subsection\\|subsubsection\\|summary\\|break\\|table-csv\\|essay-index\\)\\_>.*$"
          "\\|[ \t]*}[ \t]*$"
          "\\|[ \t]*|.*$"
          "\\|#lang .*$"))

(defconst od--paragraph-start
  (concat od--paragraph-separate
          "\\|" od--block-tags-re
          "\\|[ \t]*\\(-\\|[0-9]+\\.\\) "))

(defcustom od-soft-wrap t
  "Non-nil when essays are written one line per paragraph and shown wrapped
\(with `visual-line-mode', and `olivetti-mode' for the width). Then `M-q'
joins a paragraph onto one line instead of breaking it (EDIT-1a)."
  :type 'boolean)

(defun od-fill-paragraph (&optional justify)
  "Fill this paragraph; with `od-soft-wrap', join it onto one line (EDIT-1a).
JUSTIFY is passed on to `fill-paragraph'."
  (interactive (list (and current-prefix-arg 'full)))
  (if od-soft-wrap
      (let ((fill-column most-positive-fixnum)) (fill-paragraph justify t))
    (fill-paragraph justify t)))

(defun od--adaptive-fill ()
  "EDIT-1: a wrapped list item keeps its level: continue under its text."
  (when (looking-at "\\([ \t]*\\(-\\|[0-9]+\\.\\) \\)")
    (make-string (length (match-string 1)) ?\s)))

(defun od--fill-nobreak-p ()
  "EDIT-1: never break a meta line, nor an argument group outside a string."
  (or (od--meta-line-p)
      (let ((ppss (syntax-ppss)))
        (and (nth 1 ppss) (eq (char-after (nth 1 ppss)) ?\[) (not (nth 3 ppss))))))

;; EDIT-2
(defun od--enclosing-body-tag ()
  "The innermost tag whose body {…} holds point, or nil."
  (let ((ppss (syntax-ppss)) found)
    (dolist (open (reverse (nth 9 ppss)))
      (when (and (not found) (eq (char-after open) ?\{))
        (let ((start (od--paren-tag-start open)))
          (when start (setq found (od--tag-parse start))))))
    found))

(defun od-unwrap ()
  "Remove the tag around point, keeping its text (EDIT-2)."
  (interactive)
  (syntax-propertize (point-max))
  (let ((tag (od--enclosing-body-tag)))
    (unless (and tag (cdr (plist-get tag :body))) (user-error "Not inside a tag's text"))
    (let* ((open (car (plist-get tag :body))) (close (cdr (plist-get tag :body)))
           (start (plist-get tag :start)) (here (point-marker)))
      (save-excursion
        (goto-char (1- close)) (delete-char 1)
        (delete-region start (1+ open)))
      (goto-char here))))

(defun od-up ()
  "Move to just after the tag around point (EDIT-2)."
  (interactive)
  (syntax-propertize (point-max))
  (let ((tag (or (od--enclosing-body-tag) (od--enclosing-tag))))
    (unless tag (user-error "Not inside a tag"))
    (goto-char (plist-get tag :end))))

;; EDIT-3: completion at point
(defun od--anchor-candidates ()
  "\"/slug\" and \"/slug#id\" for every page in data/anchors.json."
  (let ((file (ignore-errors (od--file "data" "anchors.json"))))
    (when (and file (file-exists-p file))
      (let* ((json-object-type 'alist) (json-array-type 'list) (json-key-type 'string)
             (pages (json-read-file file)))
        (cl-loop for (url . page) in pages
                 collect url
                 append (mapcar (lambda (sec) (concat url "#" (alist-get "id" sec nil nil #'equal)))
                                (alist-get "sections" page nil nil #'equal)))))))

(defun od-completion-at-point ()
  "Complete tag names, keywords, keys, ids and link targets (EDIT-3)."
  (syntax-propertize (min (point-max) (+ (point) 2000)))
  (let ((ppss (syntax-ppss)))
    (cond
     ;; a string in an argument group: what goes there depends on the tag
     ((nth 3 ppss)
      (let* ((sbeg (1+ (nth 8 ppss)))
             (tag (od--enclosing-tag (nth 8 ppss)))
             (name (plist-get tag :name))
             (first (and tag (string-blank-p (buffer-substring-no-properties
                                              (1+ (plist-get tag :open)) (nth 8 ppss)))))
             (typed (buffer-substring-no-properties sbeg (point))))
        (when first
          (pcase name
            ("cite" (let ((keys (ignore-errors (mapcar #'cdr (od--bib-candidates)))))
                      (and keys (list sbeg (point) keys :exclusive 'no))))
            ("term" (list sbeg (point) (mapcar #'car (ignore-errors (od--terms))) :exclusive 'no))
            ("ref" (list sbeg (point) (mapcar #'cdr (od--id-candidates '(figure table)))))
            ("link"
             (cond ((string-prefix-p "#" typed)
                    (list (1+ sbeg) (point) (mapcar #'cdr (od--id-candidates))))
                   ((string-prefix-p "/" typed)
                    (list sbeg (point) (od--anchor-candidates) :exclusive 'no))))))))
     ;; #:keyword inside an argument group
     ((and (nth 1 ppss) (eq (char-after (nth 1 ppss)) ?\[)
           (looking-back "#:\\([a-z-]*\\)" (line-beginning-position)))
      (let ((tag (od--enclosing-tag)))
        (when tag
          (list (match-beginning 1) (match-end 1)
                (mapcar #'symbol-name (od--tag-get (plist-get tag :name) :kw))))))
     ;; a tag name after ◊
     ((looking-back "◊\\([a-z-]*\\)" (line-beginning-position))
      (list (match-beginning 1) (match-end 1)
            (append (cl-loop for (n . p) in od-vocabulary when (plist-get p :built) collect (symbol-name n))
                    (cl-loop for (n . p) in od-vocabulary unless (plist-get p :built) collect (symbol-name n)))
            :exclusive 'no
            :annotation-function (lambda (c) (if (od--tag-get c :built) "" " (not built)")))))))

;; EDIT-4
(defun od--flyspell-p ()
  "Check a word unless it is markup, a key, an id or a URL (EDIT-4)."
  (let* ((pos (max (point-min) (1- (point))))
         (face (get-text-property pos 'face))
         (faces (if (listp face) face (list face))))
    (not (or (cl-intersection faces '(od-markup-face od-string-face od-id-face od-meta-key-face
                                      od-list-marker-face font-lock-comment-face))
             (let ((ppss (syntax-ppss pos)))
               (and (nth 1 ppss) (eq (char-after (nth 1 ppss)) ?\[)))
             (save-excursion (goto-char pos) (looking-back "◊[a-z-]*" (line-beginning-position)))))))

;; EDIT-5
(defun od--shift-heading (delta)
  (save-excursion
    (beginning-of-line)
    (unless (looking-at "◊\\(\\(?:sub\\)*\\)section\\[") (user-error "Not on a heading line"))
    (let* ((level (1+ (/ (length (match-string 1)) 3)))
           (new (+ level delta)))
      (unless (<= 1 new 3) (user-error "Headings run from section to subsubsection"))
      (replace-match (apply #'concat (make-list (1- new) "sub")) t t nil 1))))

(defun od-promote ()
  "Raise the heading on this line a level; its #:id stays (EDIT-5)."
  (interactive) (od--shift-heading -1))

(defun od-demote ()
  "Lower the heading on this line a level; its #:id stays (EDIT-5)."
  (interactive) (od--shift-heading 1))

;; EDIT-6
(defun od--exclude-file ()
  (expand-file-name (od--git "rev-parse" "--git-path" "info/exclude") (od-root)))

(defun od--exclude-line (slug) (format "/essays/%s/" slug))

(defun od--exclude (slug add)
  "Add (ADD non-nil) or remove essays/SLUG/ in .git/info/exclude (DRAFT-E1)."
  (let ((file (od--exclude-file)) (line (od--exclude-line slug)))
    (with-temp-buffer
      (when (file-exists-p file) (insert-file-contents file))
      (goto-char (point-min))
      (let ((there (re-search-forward (concat "^" (regexp-quote line) "$") nil t)))
        (cond ((and add (not there))
               (goto-char (point-max))
               (unless (bolp) (insert "\n"))
               (insert line "\n"))
              ((and (not add) there)
               (delete-region (line-beginning-position) (min (point-max) (1+ (line-end-position)))))))
      (make-directory (file-name-directory file) t)
      (write-region nil nil file nil 'silent))))

;;;###autoload
(defun od-new-essay ()
  "Start an essay: essays/<slug>/ with the .pm file, img/ and support/ (EDIT-6).
The new essay is a draft and is kept out of git until `od-publish' (DRAFT-E1)."
  (interactive)
  (let* ((title (string-trim (read-string "Title: ")))
         (slug (read-string "Slug (the URL; permanent once published): " (od-slugify title)))
         (dir (od--file "essays" slug))
         (file (expand-file-name (concat slug ".html.pm") dir)))
    (when (string-empty-p title) (user-error "An essay needs a title"))
    (unless (od--valid-id-p slug) (user-error "A slug is lowercase and hyphenated"))
    (when (file-exists-p dir) (user-error "essays/%s already exists" slug))
    (od--exclude slug t)                      ; first, so git never sees it
    (make-directory (expand-file-name "img" dir) t)
    (make-directory (expand-file-name "support" dir) t)
    (with-temp-file (expand-file-name "support/notes.md" dir)
      (insert title "\n"))
    (with-temp-file file
      (insert "#lang pollen\n\n"
              (format "◊define-meta[title]{%s}\n" title)
              "◊define-meta[subtitle]{}\n"
              "◊define-meta[status]{draft}\n"
              (format "◊define-meta[published]{%s}\n" (format-time-string "%Y-%m-%d"))
              "◊define-meta[tags]{}\n\n"
              "◊epistemic{}\n\n"
              "◊abstract{}\n\n"))
    (find-file file)
    (goto-char (point-max))
    (message "Draft essays/%s/ started; git cannot see it until C-c o P" slug)))

;; EDIT-7
(defconst od--licences
  '("own" "public-domain" "permission" "cc0" "cc-by-4.0" "cc-by-sa-4.0" "cc-by-nd-4.0"
    "cc-by-nc-4.0" "cc-by-nc-sa-4.0" "cc-by-nc-nd-4.0")
  "Licences a figure may declare (IMG-6).")

(defun od--new-id (title)
  "Ask for a permanent id, proposed from TITLE and checked against this file."
  (let ((id (read-string "Id (permanent): " (od-slugify title))))
    (unless (od--valid-id-p id) (user-error "Ids are lowercase and hyphenated"))
    (when (assoc id (od--ids)) (user-error "#%s is already used in this file" id))
    id))

(defun od--quote (s) (replace-regexp-in-string "\"" "\\\\\"" s))

(defun od-insert-figure ()
  "Insert a complete ◊figure: image, title, id, alt text and licence (EDIT-7)."
  (interactive)
  (let* ((here (file-name-directory (or buffer-file-name default-directory)))
         (img (expand-file-name "img/" here))
         (path (read-file-name "Image: " (if (file-directory-p img) img here) nil t))
         (rel (file-relative-name path here))
         (title (string-trim (read-string "Title: ")))
         (id (od--new-id title))
         (alt (read-string "Alt text (what the image shows; empty if decorative): "))
         (licence (completing-read "Licence: " od--licences nil nil nil nil "own"))
         (credit (unless (equal licence "own") (read-string "Credit (required): "))))
    (insert (format "◊figure[\"%s\" #:id \"%s\" #:title \"%s\" #:alt \"%s\" #:licence \"%s\"%s]{"
                    rel id (od--quote title) (od--quote alt) licence
                    (if credit (format " #:credit \"%s\"" (od--quote credit)) "")))
    (save-excursion (insert "}"))))

(defun od-insert-table ()
  "Insert a ◊table with title, id and an Org-style skeleton (EDIT-7, EDIT-10)."
  (interactive)
  (let* ((title (string-trim (read-string "Title: ")))
         (id (od--new-id title)))
    (unless (bolp) (insert "\n"))
    (insert (format "◊table[#:id \"%s\" #:title \"%s\"]{\n" id (od--quote title)))
    (let ((first (point)))
      (insert "|  |  |\n|--+--|\n|  |  |\n}\n")
      (goto-char (+ first 2))
      (when (and (require 'org-table nil t) (fboundp 'org-table-align))
        (org-table-align)
        (goto-char (+ first 2))))))

;;; Checking (CHECK-1, CHECK-2) ----------------------------------------------------

(require 'compile)

(add-to-list 'compilation-error-regexp-alist-alist
             '(od-build-error "^build error: \\([^:\n]+\\.\\(?:pm\\|rkt\\|p\\|csv\\)\\): " 1 nil nil 2))
(add-to-list 'compilation-error-regexp-alist-alist
             '(od-warning "^warning: \\([^:\n]+\\.\\(?:pm\\|rkt\\|p\\|csv\\)\\): " 1 nil nil 1))

(define-compilation-mode od-check-mode "od-check"
  "Output of `od-check': build errors name a file, and `next-error' opens it."
  (setq-local compilation-error-regexp-alist '(od-build-error od-warning)))

(defvar od--run-function #'od--run-compile
  "How `od-check' and the publishing commands run a command (a seam for tests).")

(defun od--run-compile (command callback &optional buffer-name)
  "Run COMMAND from the repository root in a compilation buffer.
When it ends, call CALLBACK with t if it succeeded."
  (let* ((default-directory (od-root))
         (buf (compilation-start command 'od-check-mode
                                 (lambda (_) (or buffer-name "*od-check*")))))
    (when callback
      (with-current-buffer buf
        (add-hook 'compilation-finish-functions
                  (lambda (_b msg) (funcall callback (string-prefix-p "finished" msg)))
                  nil t)))
    buf))

(defun od--run (command &optional callback buffer-name)
  (funcall od--run-function command callback buffer-name))

;;;###autoload
(defun od-check (&optional full)
  "Run the tests, render this file and validate the site (CHECK-1).
With a prefix argument FULL, run the whole `make', as CI does (CHECK-2)."
  (interactive "P")
  (let* ((root (od-root))
         (rel (and buffer-file-name (file-relative-name buffer-file-name root))))
    (save-some-buffers (not (called-interactively-p 'any))
                       (lambda () (and buffer-file-name (string-prefix-p (expand-file-name root) buffer-file-name))))
    (od--run (if (or full (not rel) (not (string-suffix-p ".pm" rel)))
                 "make"
               (format "make test && raco pollen render %s && raco make tools/validate.rkt && racket tools/validate.rkt"
                       (shell-quote-argument rel))))))

;;; Publishing (PUB-1…7, DRAFT-E1) --------------------------------------------------

(defconst od-site-url "https://occurrentdevelopment.com/" "Where the site is served.")
(defconst od-actions-url "https://github.com/occurrent-development/site/actions"
  "Where its builds run.")
(defconst od-email "ryan@occurrentdevelopment.com" "The only address commits may carry.")
(defconst od--forbidden-rx "\\(-Notes\\.md\\|\\.docx\\|\\.graffle\\|\\.tex\\)\\'"
  "Files that never enter the public repository (BUILD-3a).")
(defconst od--caches '("refs/refs.bib" "data/cite-cache.json" "data/invert.json" "data/link-meta.json")
  "The committed caches `make refresh' updates (BUILD-3).")

(defun od--git (&rest args)
  "Run git with ARGS at the repository root; return its output, trimmed."
  (let ((default-directory (od-root)))
    (with-temp-buffer
      (let ((status (apply #'process-file "git" nil t nil args)))
        (unless (eq status 0)
          (user-error "git %s failed: %s" (string-join args " ") (string-trim (buffer-string))))
        (string-trim (buffer-string))))))

(defun od--git-ok (&rest args)
  (let ((default-directory (od-root)))
    (eq 0 (apply #'process-file "git" nil nil nil args))))

(defun od--require-magit ()
  (unless (require 'magit nil t)
    (user-error "Publishing works through Magit, which is not installed")))

(defun od--check-identity ()
  (let ((email (od--git "config" "user.email")))
    (unless (equal email od-email)
      (user-error "This repository's git email is %s, not %s" email od-email))))

(defun od--check-branch ()
  "PUB-4: on main, and main not behind origin/main."
  (let ((branch (od--git "rev-parse" "--abbrev-ref" "HEAD")))
    (unless (equal branch "main") (user-error "On branch %s, not main: switch to main first" branch))
    (message "Fetching origin…")
    (unless (od--git-ok "fetch" "-q" "origin")
      (user-error "Could not reach origin (offline?): publishing needs to know main is current"))
    (let ((behind (string-to-number (od--git "rev-list" "--count" "main..origin/main"))))
      (when (> behind 0)
        (user-error "main is %d commit%s behind origin/main: pull first (F p in Magit)"
                    behind (if (= behind 1) "" "s"))))))

(defun od--slug ()
  (file-name-nondirectory (directory-file-name (file-name-directory buffer-file-name))))

(defun od--set-meta (key value)
  "Set ◊define-meta[KEY] to VALUE, adding the line after the others if absent."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward (format "^◊define-meta\\[%s\\]{[^}\n]*}" (regexp-quote key)) nil t)
        (replace-match (format "◊define-meta[%s]{%s}" key value) t t)
      (goto-char (point-min))
      (while (re-search-forward "^◊define-meta\\[" nil t) (forward-line 1))
      (insert (format "◊define-meta[%s]{%s}\n" key value)))))

(defun od--ptree-add (slug)
  "PUB-1 step 4: list essays/SLUG/SLUG.html in index.ptree, after the last essay."
  (let ((file (od--file "index.ptree")) (line (format "essays/%s/%s.html" slug slug)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (unless (re-search-forward (concat "^" (regexp-quote line) "$") nil t)
        (goto-char (point-max))
        (if (re-search-backward "^essays/" nil t) (forward-line 1) (goto-char (point-max)))
        (unless (bolp) (insert "\n"))
        (insert line "\n")
        (write-region nil nil file nil 'silent)))))

(defun od--stage (paths)
  "Stage PATHS that exist (or are tracked), then refuse a foreign email address."
  (let ((root (od-root)))
    ;; support/ never, even where .gitignore is missing or wrong (BUILD-3a)
    (apply #'od--git "add" "--"
           (append (cl-remove-if-not (lambda (p) (file-exists-p (expand-file-name p root))) paths)
                   '(":(exclude)essays/*/support/*" ":(exclude)*~" ":(exclude)*#*")))
    (let ((diff (od--git "diff" "--cached" "-U0")) (start 0))
      (while (string-match "[A-Za-z0-9._%+-]+@\\([A-Za-z0-9-]+\\(\\.[A-Za-z0-9-]+\\)+\\)" diff start)
        (let ((domain (match-string 1 diff)))
          (setq start (match-end 0))
          (unless (equal (downcase domain) "occurrentdevelopment.com")
            (od--git "reset" "-q")
            (user-error "The staged changes contain an address at %s; unstaged everything" domain)))))))

(defun od--propose-message (msg)
  "Put MSG in the next commit message buffer Magit opens."
  (letrec ((fn (lambda ()
                 (remove-hook 'git-commit-setup-hook fn)
                 (when (looking-at-p "[ \t]*$") (insert msg)))))
    (add-hook 'git-commit-setup-hook fn)))

(defun od--index-row ()
  "PUB-7: the row this essay will add to the home page."
  (format "Home page gains: %s  ·  %s  ·  tags: %s"
          (or (od--meta "title") "?") (or (od--meta "published") "?")
          (let ((tags (od--meta "tags"))) (if (and tags (not (string-empty-p tags))) tags "none"))))

;;;###autoload
(defun od-publish (&optional commit-and-push)
  "Publish this essay (PUB-1): it becomes visible to git, its status published,
its date set, its line added to index.ptree; then `make refresh' and `make'
run, and if they pass, the essay and the caches are staged and Magit opens
for you to read the diff, commit (c c) and push (P p). It never pushes by
itself. With a prefix argument COMMIT-AND-PUSH it commits with the proposed
message and pushes after one confirmation (PUB-2).

There is no command to unpublish (PUB-6): to withdraw an essay, set its
status to superseded and commit that as a revision. Its source stays in the
history."
  (interactive "P")
  (od--require-magit)
  (unless (eq (od-file-kind) 'essay) (user-error "Publish works from an essay: essays/<slug>/<slug>.html.pm"))
  (when (buffer-modified-p) (user-error "Save the essay first"))
  (let ((title (od--meta "title")) (slug (od--slug)) (today (format-time-string "%Y-%m-%d")))
    (unless (and title (not (string-empty-p title))) (user-error "The essay has no title"))
    (od--check-identity)
    (od--check-branch)
    (od--exclude slug nil)
    (let ((status (od--meta "status")))
      (when (equal status "draft")
        (unless (y-or-n-p "Status is draft. Set it to published? ") (user-error "Not published"))
        (od--set-meta "status" "published")))
    (let ((pub (od--meta "published")))
      (cond ((or (null pub) (string-empty-p pub)) (od--set-meta "published" today))
            ((and (not (equal pub today))
                  (y-or-n-p (format "The published date is %s (perhaps the day the draft began). Make it today, %s? " pub today)))
             (od--set-meta "published" today))))
    (save-buffer)
    (od--ptree-add slug)
    (let ((buf (current-buffer)))
      (od--run "make refresh && make"
               (lambda (ok)
                 (if (not ok)
                     (message "make failed: see *od-check*. Nothing is staged.")
                   (with-current-buffer buf (od--publish-stage slug title commit-and-push))))))))

(defun od--publish-stage (slug title commit-and-push)
  (let* ((dir (format "essays/%s" slug))
         (listing (od--git "status" "--porcelain" "--untracked-files=all" "--" dir)))
    (dolist (line (split-string listing "\n" t))
      (when (string-match-p od--forbidden-rx line)
        (user-error "Refusing: %s must not be published (BUILD-3a)" (substring line 3))))
    (message "%s" (od--index-row))
    (let ((glossary (cl-loop for line in (split-string (od--git "status" "--porcelain" "--" "glossary") "\n" t)
                             collect (substring line 3))))
      (od--stage (append (list dir "index.ptree") od--caches glossary)))
    (let ((msg (format "Publish: %s" title)))
      (if commit-and-push
          (when (yes-or-no-p (format "Commit \"%s\" and push main to origin, which deploys it? " msg))
            (od--git "commit" "-q" "-m" msg)
            (od--git "push" "-q" "origin" "main")
            (od-deploy-status (concat od-site-url slug)))
        (od--propose-message msg)
        (magit-status-setup-buffer (od-root))
        (message "%s. Staged: c c to commit, P p to push and deploy" (od--index-row))))))

;;;###autoload
(defun od-commit ()
  "Commit a change to a published essay, page or glossary file (PUB-3).
Typo and Meta commits are marked so the essay's Revised date stays (REV-1)."
  (interactive)
  (od--require-magit)
  (let ((kind (od-file-kind)))
    (unless (memq kind '(essay page home specimen glossary)) (user-error "Not a page of the site"))
    (when (buffer-modified-p) (save-buffer))
    (od--check-identity)
    (od--check-branch)
    (let* ((choice (if (eq kind 'essay)
                       (completing-read "Kind of change: " '("Typo" "Meta" "Revision") nil t)
                     "Revision"))
           (prefix (pcase choice ("Typo" "[typo] ") ("Meta" "[meta] ") (_ "")))
           (root (od-root))
           (what (if (eq kind 'essay)
                     (file-relative-name (file-name-directory buffer-file-name) root)
                   (file-relative-name buffer-file-name root))))
      (when (equal choice "Revision")
        (if (od--tag-get 'changelog :built)
            (unless (string-match-p "◊changelog" (buffer-string))
              (user-error "A revision needs a line in ◊changelog{…} saying what changed (REV-3)"))
          (message "◊changelog is not built yet: no changelog line to check")))
      (od--stage (cons what od--caches))
      (od--propose-message (format "%s%s: " prefix (or (od--meta "title") (file-name-base buffer-file-name))))
      (magit-status-setup-buffer root))))

;;;###autoload
(defun od-deploy-status (&optional url)
  "Watch the latest deploy; when it succeeds, open URL (PUB-5)."
  (interactive)
  (if (executable-find "gh")
      (od--run "gh run watch $(gh run list --branch main --limit 1 --json databaseId -q '.[0].databaseId') --exit-status"
               (lambda (ok)
                 (if ok (progn (message "Deployed") (when url (browse-url url)))
                   (message "The deploy failed: see *od-deploy*")))
               "*od-deploy*")
    (browse-url od-actions-url)))

;;; The mode (MODE-1…4, LOAD-1…4) --------------------------------------------------

(defcustom od-use-orgtbl t
  "When non-nil, edit pipe tables with Org's table editor (EDIT-10)."
  :type 'boolean)

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
    (define-key m (kbd "C-c o I") #'od-guide)
    (define-key m (kbd "C-c o F") #'od-insert-figure)
    (define-key m (kbd "C-c o B") #'od-insert-table)
    (define-key m (kbd "C-c o N") #'od-new-essay)
    (define-key m (kbd "C-c o u") #'od-unwrap)
    (define-key m (kbd "C-c o U") #'od-up)
    (define-key m (kbd "C-c o k") #'od-check)
    (define-key m (kbd "C-c o P") #'od-publish)
    (define-key m (kbd "C-c o C") #'od-commit)
    (define-key m (kbd "C-c o d") #'od-deploy-status)
    (define-key m [remap fill-paragraph] #'od-fill-paragraph)
    ;; outline's promote and demote would rewrite ◊section by its regexp
    (define-key m [remap outline-promote] #'od-promote)
    (define-key m [remap outline-demote] #'od-demote)
    m)
  "Keys for `occurrent-mode'.")

;; The commands that make sense anywhere, for a global prefix (LOAD-4a):
;;   (global-set-key (kbd "C-c o") od-global-map)
;; Inside an essay the mode's own keys take precedence over these.
(defvar od-global-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "N") #'od-new-essay)
    (define-key m (kbd "I") #'od-guide)
    (define-key m (kbd "k") #'od-check)
    (define-key m (kbd "d") #'od-deploy-status)
    m)
  "Site commands for anywhere in Emacs, meant for `C-c o'.")
(fset 'od-global-map od-global-map)

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
(define-derived-mode occurrent-mode text-mode "◊"
  "Writing occurrentdevelopment.com in Pollen (SPEC §16, HANDOVER-EMACS).

Prose dominates; markup is dimmed; anything the build would refuse is
highlighted, with the reason in its tooltip. `C-c o I' opens a guide to
starting, publishing and revising an essay. Inside a pipe table, Org's
table keys work (TAB aligns, M-arrows move rows and columns).

\\{occurrent-mode-map}"
  :syntax-table od-syntax-table
  ;; syntax (SYN-1…3)
  (setq-local syntax-propertize-function #'od-syntax-propertize)
  (setq-local parse-sexp-lookup-properties t)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local forward-sexp-function #'od-forward-sexp)
  (add-hook 'syntax-propertize-extend-region-functions #'od--syntax-extend-region nil t)
  ;; highlighting (§5)
  (setq-local font-lock-defaults
              '(od--font-lock-keywords nil nil nil nil
                (font-lock-syntactic-face-function . od--syntactic-face)))
  (setq-local font-lock-multiline t)
  (setq-local font-lock-extra-managed-props '(help-echo))
  (add-hook 'font-lock-extend-region-functions #'od--font-lock-extend-region 'append t)
  ;; comments (EDIT-8): ◊; hides the rest of the line and its line break
  (setq-local comment-start "◊; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "◊;+[ \t]*")
  (setq-local comment-end-skip "[ \t]*$")
  (setq-local comment-padding "")
  (setq-local comment-use-syntax nil)
  (setq-local comment-style 'plain)
  (setq-local comment-column 0)
  ;; filling (EDIT-1)
  (setq-local paragraph-separate od--paragraph-separate)
  (setq-local paragraph-start od--paragraph-start)
  (setq-local adaptive-fill-regexp "[ \t]*")
  (setq-local adaptive-fill-function #'od--adaptive-fill)
  (add-hook 'fill-nobreak-predicate #'od--fill-nobreak-p nil t)
  ;; completion and spelling (EDIT-3, EDIT-4)
  (add-hook 'completion-at-point-functions #'od-completion-at-point nil t)
  (setq-local flyspell-generic-check-word-predicate #'od--flyspell-p)
  ;; structure (EMACS-4, EDIT-5)
  (setq-local imenu-generic-expression `((nil ,od--heading-re 3)))
  (setq-local outline-regexp "◊\\(sub\\)*section\\[")
  (setq-local outline-level #'od--outline-level)
  (outline-minor-mode 1)
  ;; tables (EDIT-10)
  (when (and od-use-orgtbl (require 'org-table nil t)) (orgtbl-mode 1)))

(put 'occurrent-mode 'flyspell-mode-predicate #'od--flyspell-p)

;; MODE-2: ours wins over pollen-mode, if that is installed too.
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.pm\\'" . occurrent-mode))

(provide 'occurrent)
;;; occurrent.el ends here
