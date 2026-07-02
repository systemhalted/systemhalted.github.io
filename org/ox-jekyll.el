;;; ox-jekyll.el --- Export Org posts to Jekyll Markdown -*- lexical-binding: t; -*-

;; Org export backend for this blog: writes kramdown-flavoured Markdown
;; with YAML front matter into collections/_posts/ (or _drafts/), so the
;; Jekyll build and CI stay unchanged.  Uses only built-in ox-md.
;;
;; Usage:
;;   Interactive:  M-x org-jekyll-export        (from an .org buffer)
;;   Batch:        emacs --batch -l org/ox-jekyll.el -f org-jekyll-export-file FILE.org
;;   Optional:     (org-jekyll-auto-export-mode 1) in a buffer to export on save.
;;
;; Recognised keywords, mirroring the front matter used across existing
;; posts: #+TITLE, #+DATE, #+DESCRIPTION, #+CATEGORIES (comma-separated),
;; #+TAGS (comma-separated), #+JEKYLL_COMMENTS, #+JEKYLL_TOC, #+JEKYLL_LAYOUT.

;;; Code:

(require 'ox-md)
(require 'subr-x)

(org-export-define-derived-backend 'jekyll 'md
  :menu-entry
  '(?j "Export to Jekyll Markdown"
       ((?j "To collections/" (lambda (_a _s _v _b) (org-jekyll-export)))))
  :options-alist
  '((:description "DESCRIPTION" nil nil t)
    (:categories "CATEGORIES" nil nil t)
    (:tags "TAGS" nil nil t)
    (:jekyll-comments "JEKYLL_COMMENTS" nil "true" t)
    (:jekyll-toc "JEKYLL_TOC" nil nil t)
    (:jekyll-layout "JEKYLL_LAYOUT" nil "post" t)
    ;; The post layout supplies the H1, so body sections start at H2.
    (:md-toplevel-hlevel nil nil 2)
    ;; Jekyll/kramdown does ToC, numbering and smart quotes; Org must not.
    (:with-toc nil "toc" nil)
    (:section-numbers nil "num" nil)
    (:with-sub-superscript nil "^" nil))
  :translate-alist
  '((src-block . org-jekyll-src-block)
    (example-block . org-jekyll-example-block)
    (footnote-reference . org-jekyll-footnote-reference)
    (link . org-jekyll-link)
    (inner-template . org-jekyll-inner-template)
    (template . org-jekyll-template)))

;;; Transcoders

(defun org-jekyll-src-block (src-block _contents _info)
  "Emit SRC-BLOCK as a fenced code block with its language."
  (format "```%s\n%s```"
          (or (org-element-property :language src-block) "")
          (org-remove-indentation (org-element-property :value src-block))))

(defun org-jekyll-example-block (example-block _contents _info)
  "Emit EXAMPLE-BLOCK as a fenced code block with the text lexer."
  (format "```text\n%s```"
          (org-remove-indentation (org-element-property :value example-block))))

(defun org-jekyll-footnote-reference (footnote-reference _contents info)
  "Emit FOOTNOTE-REFERENCE as a kramdown footnote marker."
  (format "[^%s]"
          (or (org-element-property :label footnote-reference)
              (org-export-get-footnote-number footnote-reference info))))

(defun org-jekyll-link (link contents info)
  "Emit LINK, passing site-relative paths (\"/YYYY/...\") through as-is.
Everything else falls back to the stock Markdown transcoder."
  (let ((raw (org-element-property :raw-link link)))
    (if (string-prefix-p "/" raw)
        (if (org-string-nw-p contents)
            (format "[%s](%s)" contents raw)
          (format "<%s>" raw))
      (org-md-link link contents info))))

(defun org-jekyll-inner-template (contents info)
  "Append kramdown footnote definitions after CONTENTS."
  (concat contents (org-jekyll--footnote-section info)))

(defun org-jekyll--footnote-section (info)
  "Return kramdown definitions for every footnote used in the document."
  (let ((definitions (org-export-collect-footnote-definitions info)))
    (if (null definitions) ""
      (concat "\n"
              (mapconcat
               (pcase-lambda (`(,number ,label ,definition))
                 (format "[^%s]: %s"
                         (or label number)
                         ;; kramdown continues a definition across
                         ;; paragraphs only when they are indented.
                         (replace-regexp-in-string
                          "\n\n" "\n\n    "
                          (org-trim (org-export-data definition info)))))
               definitions "\n\n")
              "\n"))))

(defun org-jekyll-template (contents info)
  "Prepend YAML front matter to CONTENTS."
  (concat (org-jekyll--front-matter info) contents))

;;; Front matter

(defun org-jekyll--yaml-quote (value)
  (format "\"%s\"" (replace-regexp-in-string "\"" "\\\\\"" value)))

(defun org-jekyll--yaml-list (key value)
  "Render KEY with comma-separated VALUE as a YAML block list, or nil."
  (let ((items (and value (split-string value "," t "[ \t]+"))))
    (when items
      (concat key ":\n" (mapconcat (lambda (item) (concat "- " item)) items "\n") "\n"))))

(defun org-jekyll--date (info)
  "Return #+DATE as a plain string; timestamps become YYYY-MM-DD."
  (let ((date (plist-get info :date)))
    (when date
      (let ((element (car date)))
        (if (eq (org-element-type element) 'timestamp)
            (org-timestamp-format element "%Y-%m-%d")
          (org-trim (org-element-interpret-data date)))))))

(defun org-jekyll--front-matter (info)
  (let ((title (org-export-data (plist-get info :title) info))
        (date (org-jekyll--date info))
        (description (plist-get info :description))
        (comments (plist-get info :jekyll-comments))
        (toc (plist-get info :jekyll-toc)))
    (concat
     "---\n"
     "layout: " (plist-get info :jekyll-layout) "\n"
     "title: " (org-jekyll--yaml-quote title) "\n"
     (when date (concat "date: " date "\n"))
     (org-jekyll--yaml-list "categories" (plist-get info :categories))
     (org-jekyll--yaml-list "tags" (plist-get info :tags))
     (when (org-string-nw-p comments) (concat "comments: " comments "\n"))
     (when (org-string-nw-p toc) (concat "toc: " toc "\n"))
     (when (org-string-nw-p description) (concat "description: " description "\n"))
     (org-jekyll--org-source-line info)
     "---\n")))

(defun org-jekyll--org-source-line (info)
  "Front-matter line recording the .org file this Markdown was generated from."
  (let* ((input (plist-get info :input-file))
         (root (and input (org-jekyll--repo-root input))))
    (when root
      (format "org_source: %s # generated file — edit the .org source\n"
              (file-relative-name input root)))))

;;; Export commands

(defun org-jekyll--repo-root (file)
  (locate-dominating-file file "_config.yml"))

(defun org-jekyll--target-file (org-file)
  "Map org/posts/X.org to collections/_posts/X.md (drafts likewise)."
  (let ((root (or (org-jekyll--repo-root org-file)
                  (user-error "No _config.yml above %s" org-file)))
        (collection (if (string-match-p "/org/drafts/" org-file)
                        "collections/_drafts/"
                      "collections/_posts/")))
    (expand-file-name (concat collection (file-name-base org-file) ".md") root)))

;;;###autoload
(defun org-jekyll-export ()
  "Export the current Org buffer to Jekyll Markdown in collections/."
  (interactive)
  (let ((org-file (buffer-file-name)))
    (unless (and org-file (string-suffix-p ".org" org-file))
      (user-error "Not visiting an .org file"))
    (org-export-to-file 'jekyll (org-jekyll--target-file org-file))))

(defun org-jekyll-export-file (&optional file)
  "Batch entry point: export FILE or every file in `command-line-args-left'."
  (let ((files (if file (list file) command-line-args-left)))
    (setq command-line-args-left nil)
    (dolist (f files)
      (with-current-buffer (find-file-noselect (expand-file-name f))
        (message "Wrote %s" (org-jekyll-export))))))

;;;###autoload
(define-minor-mode org-jekyll-auto-export-mode
  "Export the buffer to Jekyll Markdown after every save."
  :lighter " →Jekyll"
  (if org-jekyll-auto-export-mode
      (add-hook 'after-save-hook #'org-jekyll-export nil t)
    (remove-hook 'after-save-hook #'org-jekyll-export t)))

(provide 'ox-jekyll)
;;; ox-jekyll.el ends here
