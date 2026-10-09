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
