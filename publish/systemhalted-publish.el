;;; systemhalted-publish.el --- Org-first static site publisher -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Palak Mathur

;;; Commentary:

;; Built-in-Emacs publishing support for systemhalted.in.

;;; Code:

(require 'cl-lib)
(require 'format-spec)
(require 'json)
(require 'org)
(require 'ox-html)
(require 'seq)
(require 'subr-x)
(require 'time-date)
(require 'url-util)

(defconst systemhalted-publish-directory
  (file-name-directory (or load-file-name buffer-file-name)))

(define-error 'systemhalted-publish-error "SystemHalted publishing error" 'user-error)

(cl-defstruct systemhalted-record
  source kind title description date categories tags permalink route comments toc
  last-modified featured-image featured-image-alt featured-image-caption draft
  future-p)

(defconst systemhalted--metadata-keys
  '("TITLE" "DESCRIPTION" "DATE" "CATEGORIES" "TAGS" "PERMALINK"
    "COMMENTS" "TOC" "LAST_MODIFIED" "FEATURED_IMAGE"
    "FEATURED_IMAGE_ALT" "FEATURED_IMAGE_CAPTION" "DRAFT"))

(defun systemhalted--source-error (file format-string &rest args)
  "Signal a publishing error for FILE using FORMAT-STRING and ARGS."
  (signal 'systemhalted-publish-error
          (list (format "%s: %s" file (apply #'format format-string args)))))

(defun systemhalted--read-keywords (file)
  "Read supported Org keywords from FILE into an alist."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (keywords)
      (while (re-search-forward
              "^#\\+\\([[:alnum:]_]+\\):[ \t]*\\(.*\\)$" nil t)
        (let ((key (upcase (match-string-no-properties 1)))
              (value (string-trim (match-string-no-properties 2))))
          (when (member key systemhalted--metadata-keys)
            (setf (alist-get key keywords nil nil #'string=) value))))
      keywords)))

(defun systemhalted--keyword (keywords name)
  "Return NAME from KEYWORDS, treating an empty value as absent."
  (let ((value (alist-get name keywords nil nil #'string=)))
    (and value (not (string-empty-p value)) value)))

(defun systemhalted--list-value (value)
  "Turn comma-separated VALUE into a trimmed list."
  (when value
    (mapcar #'string-trim (split-string value "," t "[ \t\n]+"))))

(defun systemhalted--boolean-value (value)
  "Return non-nil when VALUE is an affirmative metadata spelling."
  (and value (member (downcase value) '("true" "yes" "t" "1"))))

(defun systemhalted--filename-parts (file)
  "Return (DATE SLUG) derived from FILE, allowing an undated filename."
  (let ((base (file-name-base file)))
    (if (string-match
         "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)-\\(.+\\)\\'"
         base)
        (list (format "%s-%s-%s"
                      (match-string 1 base)
                      (match-string 2 base)
                      (match-string 3 base))
              (match-string 4 base))
      (list nil base))))

(defun systemhalted--parse-date (file value)
  "Parse date VALUE for FILE into an Emacs time value."
  (unless value
    (systemhalted--source-error file "missing DATE and no date in filename"))
  (let ((clean (string-trim value "[<[]" "[]>]")))
    (condition-case nil
        (if (string-match
             "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
             clean)
            (encode-time 0 0 12
                         (string-to-number (match-string 3 clean))
                         (string-to-number (match-string 2 clean))
                         (string-to-number (match-string 1 clean)))
          (date-to-time clean))
      (error (systemhalted--source-error file "invalid DATE %S" value)))))

(defun systemhalted--normalize-route (file route)
  "Validate and normalize ROUTE claimed by FILE."
  (unless (and route (string-prefix-p "/" route))
    (systemhalted--source-error file "route must start with /: %S" route))
  (when (or (string-match-p "\\(?:^\\|/\\)\\.\\.?\\(?:/\\|$\\)" route)
            (string-match-p "[\\\\?#]" route)
            (string-match-p "//" route))
    (systemhalted--source-error file "unsafe route %S" route))
  (if (or (equal route "/") (string-suffix-p "/" route))
      route
    (concat route "/")))

(defun systemhalted--default-route (file kind date slug)
  "Derive a route for FILE of KIND using DATE and SLUG."
  (pcase kind
    ((or 'post 'draft)
     (format "/%s/%s/"
             (format-time-string "%Y/%m/%d" date)
             slug))
    ('emacs (format "/emacs/%s/" slug))
    ('page (if (equal slug "index") "/" (format "/%s/" slug)))
    (_ (systemhalted--source-error file "unknown content kind %S" kind))))

(defun systemhalted-read-record (file &optional kind now)
  "Read FILE as a normalized content record of KIND.
NOW controls future-post classification and defaults to the current time."
  (let* ((keywords (systemhalted--read-keywords file))
         (title (systemhalted--keyword keywords "TITLE"))
         (description (systemhalted--keyword keywords "DESCRIPTION"))
         (parts (systemhalted--filename-parts file))
         (filename-date (car parts))
         (slug (cadr parts))
         (draft-value (systemhalted--boolean-value
                       (systemhalted--keyword keywords "DRAFT")))
         (kind (or kind (if draft-value 'draft 'post)))
         (draft (or draft-value
                    (eq kind 'draft)
                    (string-match-p "/org/drafts/" (expand-file-name file))))
         (date-required (memq kind '(post draft)))
         (date-value (or (systemhalted--keyword keywords "DATE") filename-date))
         (date (and date-required (systemhalted--parse-date file date-value)))
         (permalink (systemhalted--keyword keywords "PERMALINK"))
         (route (systemhalted--normalize-route
                 file (or permalink
                          (systemhalted--default-route file kind date slug))))
         (now (or now (current-time))))
    (unless title
      (systemhalted--source-error file "missing TITLE"))
    (unless description
      (systemhalted--source-error file "missing DESCRIPTION"))
    (make-systemhalted-record
     :source (expand-file-name file)
     :kind kind
     :title title
     :description description
     :date date
     :categories (systemhalted--list-value
                  (systemhalted--keyword keywords "CATEGORIES"))
     :tags (systemhalted--list-value
            (systemhalted--keyword keywords "TAGS"))
     :permalink permalink
     :route route
     :comments (systemhalted--boolean-value
                (systemhalted--keyword keywords "COMMENTS"))
     :toc (systemhalted--boolean-value
           (systemhalted--keyword keywords "TOC"))
     :last-modified (systemhalted--keyword keywords "LAST_MODIFIED")
     :featured-image (systemhalted--keyword keywords "FEATURED_IMAGE")
     :featured-image-alt (systemhalted--keyword keywords "FEATURED_IMAGE_ALT")
     :featured-image-caption
     (systemhalted--keyword keywords "FEATURED_IMAGE_CAPTION")
     :draft draft
     :future-p (and date (time-less-p now date)))))

(cl-defun systemhalted-load-records (directory &key include-drafts include-future now kind)
  "Load validated Org records below DIRECTORY.
INCLUDE-DRAFTS and INCLUDE-FUTURE control preview visibility. NOW sets the
comparison clock and KIND overrides inferred content kind."
  (let (records)
    (dolist (file (directory-files-recursively directory "\\.org\\'"))
      (let* ((record (systemhalted-read-record file kind now))
             (visible (and (or include-drafts
                               (not (systemhalted-record-draft record)))
                           (or include-future
                               (not (systemhalted-record-future-p record))))))
        (when visible (push record records))))
    (setq records
          (sort records
                (lambda (left right)
                  (let ((left-date (systemhalted-record-date left))
                        (right-date (systemhalted-record-date right)))
                    (cond
                     ((and left-date right-date) (time-less-p right-date left-date))
                     (left-date t)
                     (t nil))))))
    (systemhalted-validate-records records)
    records))

(defun systemhalted-validate-records (records)
  "Validate route uniqueness and safety across RECORDS."
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (record records)
      (let* ((route (systemhalted--normalize-route
                     (systemhalted-record-source record)
                     (systemhalted-record-route record)))
             (previous (gethash route seen)))
        (when previous
          (systemhalted--source-error
           (systemhalted-record-source record)
           "duplicate route %s already claimed by %s" route previous))
        (puthash route (systemhalted-record-source record) seen))))
  records)

;;; Org HTML backend

(defvar systemhalted--export-records nil)
(defvar systemhalted--export-source nil)

(defun systemhalted--escape-html (value &optional attribute)
  "Escape VALUE for HTML, including quotes when ATTRIBUTE is non-nil."
  (let ((escaped (org-html-encode-plain-text (or value ""))))
    (if attribute
        (replace-regexp-in-string "'" "&#39;"
                                  (replace-regexp-in-string "\"" "&quot;" escaped))
      escaped)))

(defun systemhalted-html-src-block (src-block _contents _info)
  "Render SRC-BLOCK with stable language classes and escaped source."
  (let ((language (or (org-element-property :language src-block) "text"))
        (source (org-element-property :value src-block)))
    (format (concat "<div class=\"language-%s highlighter-rouge\">"
                    "<div class=\"highlight\"><pre class=\"highlight\">"
                    "<code class=\"language-%s\" data-lang=\"%s\">%s</code>"
                    "</pre></div></div>")
            (systemhalted--escape-html language t)
            (systemhalted--escape-html language t)
            (systemhalted--escape-html language t)
            (systemhalted--escape-html source))))

(defun systemhalted-html-example-block (example-block _contents _info)
  "Render EXAMPLE-BLOCK as escaped plain text."
  (format "<pre class=\"example\"><code>%s</code></pre>"
          (systemhalted--escape-html
           (org-element-property :value example-block))))

(defun systemhalted--record-for-source (source records)
  "Find SOURCE in RECORDS using canonical filenames."
  (let ((target (file-truename source)))
    (seq-find
     (lambda (record)
       (equal target (file-truename (systemhalted-record-source record))))
     records)))

(defun systemhalted-html-link (link contents info)
  "Render Org LINK, mapping links to Org sources onto their public routes."
  (let ((type (org-element-property :type link))
        (path (org-element-property :path link)))
    (if (and (string= type "file") (string-suffix-p ".org" path t))
        (let* ((target (expand-file-name path
                                         (file-name-directory systemhalted--export-source)))
               (record (systemhalted--record-for-source
                        target systemhalted--export-records)))
          (unless record
            (systemhalted--source-error
             systemhalted--export-source "unresolved Org link %s" path))
          (format "<a href=\"%s\">%s</a>"
                  (systemhalted--escape-html
                   (systemhalted-record-route record) t)
                  (or contents
                      (systemhalted--escape-html
                       (systemhalted-record-title record)))))
      (org-html-link link contents info))))

(org-export-define-derived-backend 'systemhalted-html 'html
  :translate-alist
  '((src-block . systemhalted-html-src-block)
    (example-block . systemhalted-html-example-block)
    (link . systemhalted-html-link)))

(defun systemhalted-export-body (record &optional records)
  "Export RECORD's Org body to HTML with links resolved through RECORDS."
  (let ((systemhalted--export-records (or records (list record)))
        (systemhalted--export-source (systemhalted-record-source record)))
    (with-temp-buffer
      (insert-file-contents (systemhalted-record-source record))
      (setq buffer-file-name (systemhalted-record-source record))
      (org-mode)
      (org-export-as
       'systemhalted-html nil nil t
       '(:with-title nil
         :with-author nil
         :with-date nil
         :with-toc nil
         :section-numbers nil
         :html-toplevel-hlevel 2
         :html-preamble nil
         :html-postamble nil
         :html-html5-fancy t
         :html-doctype "html5")))))

;;; Templates and post relationships

(defun systemhalted--template (name specs)
  "Read template NAME and substitute format SPECS."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "templates/" name) systemhalted-publish-directory))
    (format-spec (buffer-string) specs)))

(defun systemhalted--slugify (value)
  "Return a stable lower-case fragment for VALUE."
  (let ((slug (downcase (string-trim value))))
    (setq slug (replace-regexp-in-string "[^[:alnum:]]+" "-" slug))
    (string-trim slug "-+" "-+")))

(defun systemhalted--toc (body)
  "Build a compact table of contents from headings in BODY."
  (let ((start 0) items)
    (while (string-match
            "<h\\([2-6]\\)[^>]*id=\"\\([^\"]+\\)\"[^>]*>\\(.*?\\)</h[2-6]>"
            body start)
      (push (format "<li><a href=\"#%s\">%s</a></li>"
                    (match-string 2 body) (match-string 3 body))
            items)
      (setq start (match-end 0)))
    (when items
      (format (concat "<details class=\"post-toc\"><summary>Contents</summary>"
                      "<nav aria-label=\"Table of contents\"><ul>%s</ul></nav></details>")
              (string-join (nreverse items) "")))))

(defun systemhalted--post-records (records)
  "Return published post-like RECORDS in reverse chronological order."
  (sort (seq-filter
         (lambda (record) (memq (systemhalted-record-kind record) '(post draft)))
         (copy-sequence records))
        (lambda (left right)
          (time-less-p (systemhalted-record-date right)
                       (systemhalted-record-date left)))))

(defun systemhalted--intersection-count (left right)
  "Count values shared by string lists LEFT and RIGHT."
  (seq-count (lambda (item) (member item right)) left))

(defun systemhalted--related-records (record records)
  "Return up to three related RECORDS for RECORD using current scoring rules."
  (let (scored)
    (dolist (candidate (systemhalted--post-records records))
      (unless (equal (systemhalted-record-route candidate)
                     (systemhalted-record-route record))
        (let ((score (+ (* 3 (systemhalted--intersection-count
                              (systemhalted-record-categories record)
                              (systemhalted-record-categories candidate)))
                        (* 2 (systemhalted--intersection-count
                              (systemhalted-record-tags record)
                              (systemhalted-record-tags candidate))))))
          (when (> score 0) (push (cons score candidate) scored)))))
    (mapcar
     #'cdr
     (seq-take
      (sort scored
            (lambda (left right)
              (if (= (car left) (car right))
                  (time-less-p (systemhalted-record-date (cdr right))
                               (systemhalted-record-date (cdr left)))
                (> (car left) (car right)))))
      3))))

(defun systemhalted--related-html (record records)
  "Render related links for RECORD from RECORDS."
  (let ((related (systemhalted--related-records record records)))
    (when related
      (concat
       "<section class=\"post-more\" aria-labelledby=\"more-writing-heading\">"
       "<h2 id=\"more-writing-heading\" class=\"post-more-heading\">More from SystemHalted</h2>"
       "<ul class=\"related-posts\">"
       (mapconcat
        (lambda (item)
          (format (concat "<li class=\"related-post\"><time class=\"related-post-date\" "
                          "datetime=\"%s\">%s</time><a class=\"related-post-title\" "
                          "href=\"%s\">%s</a><span class=\"related-post-reason\">Related reading</span></li>")
                  (format-time-string "%Y-%m-%d" (systemhalted-record-date item))
                  (format-time-string "%b %d, %Y" (systemhalted-record-date item))
                  (systemhalted--escape-html (systemhalted-record-route item) t)
                  (systemhalted--escape-html (systemhalted-record-title item))))
        related "")
       "</ul></section>"))))

(defun systemhalted--adjacent-html (record records)
  "Render newer and older navigation for RECORD within RECORDS."
  (let* ((posts (systemhalted--post-records records))
         (index (seq-position
                 posts (systemhalted-record-route record)
                 (lambda (item route)
                   (equal (systemhalted-record-route item) route))))
         (newer (and index (> index 0) (nth (1- index) posts)))
         (older (and index (< (1+ index) (length posts)) (nth (1+ index) posts))))
    (when (or newer older)
      (format (concat "<nav class=\"post-nav\" aria-label=\"Newer and older posts\">%s%s</nav>")
              (if newer
                  (format (concat "<a class=\"post-nav-prev\" href=\"%s\">"
                                  "<span class=\"post-nav-label\">← Newer</span>"
                                  "<span class=\"post-nav-title\">%s</span></a>")
                          (systemhalted-record-route newer)
                          (systemhalted--escape-html (systemhalted-record-title newer)))
                "<span></span>")
              (if older
                  (format (concat "<a class=\"post-nav-next\" href=\"%s\">"
                                  "<span class=\"post-nav-label\">Older →</span>"
                                  "<span class=\"post-nav-title\">%s</span></a>")
                          (systemhalted-record-route older)
                          (systemhalted--escape-html (systemhalted-record-title older)))
                "")))))

(defun systemhalted--taxonomy-html (record)
  "Render category links for RECORD."
  (let ((categories (systemhalted-record-categories record)))
    (when categories
      (format "<p class=\"post-taxonomy\">Filed under %s.</p>"
              (mapconcat
               (lambda (category)
                 (format "<a href=\"/categories/#cat-%s\">%s</a>"
                         (systemhalted--slugify category)
                         (systemhalted--escape-html category)))
               categories ", ")))))

(defun systemhalted--featured-html (record)
  "Render featured image markup for RECORD."
  (when (systemhalted-record-featured-image record)
    (format (concat "<figure class=\"post-featured\"><img src=\"%s\" alt=\"%s\">%s</figure>")
            (systemhalted--escape-html (systemhalted-record-featured-image record) t)
            (systemhalted--escape-html
             (or (systemhalted-record-featured-image-alt record) "") t)
            (if (systemhalted-record-featured-image-caption record)
                (format "<figcaption>%s</figcaption>"
                        (systemhalted--escape-html
                         (systemhalted-record-featured-image-caption record)))
              ""))))

(defun systemhalted--comments-html (record)
  "Render Giscus comments for RECORD when enabled."
  (when (systemhalted-record-comments record)
    (concat
     "<details class=\"comments\" id=\"comments\"><summary>Comments</summary><div class=\"comments-body\">"
     "<script src=\"https://giscus.app/client.js\" data-repo=\"systemhalted/systemhalted.github.io\" "
     "data-repo-id=\"MDEwOlJlcG9zaXRvcnk0NjcwNjAxOA==\" data-category=\"Comments\" "
     "data-category-id=\"DIC_kwDOAsitYs4C9Yut\" data-mapping=\"pathname\" data-strict=\"1\" "
     "data-reactions-enabled=\"1\" data-emit-metadata=\"0\" data-input-position=\"top\" "
     "data-theme=\"preferred_color_scheme\" data-lang=\"en\" data-loading=\"lazy\" "
     "crossorigin=\"anonymous\" async></script><noscript>Comments require JavaScript. "
     "<a href=\"mailto:insanethoughts@live.com\">Email me</a> instead.</noscript></div></details>")))

(defun systemhalted--render-post (record records body)
  "Render post RECORD with BODY and relationship data from RECORDS."
  (let* ((words (length (split-string (replace-regexp-in-string "<[^>]+>" " " body)
                                      "[[:space:]]+" t)))
         (minutes (max 1 (/ (+ words 219) 220)))
         (date (systemhalted-record-date record)))
    (systemhalted--template
     "post.html"
     `((?t . ,(systemhalted--escape-html (systemhalted-record-title record)))
       (?i . ,(format-time-string "%Y-%m-%dT%H:%M:%S%z" date))
       (?d . ,(format-time-string "%-d %B %Y" date))
       (?m . ,(format "<span aria-hidden=\"true\">·</span> %d min read" minutes))
       (?T . ,(or (and (systemhalted-record-toc record)
                       (systemhalted--toc body)) ""))
       (?c . ,body)
       (?f . ,(or (systemhalted--featured-html record) ""))
       (?x . ,(or (systemhalted--taxonomy-html record) ""))
       (?r . ,(or (systemhalted--related-html record records) ""))
       (?n . ,(or (systemhalted--adjacent-html record records) ""))
       (?g . ,(or (systemhalted--comments-html record) ""))))))

(defun systemhalted--structured-data (record)
  "Return JSON-LD shared by pages, including article data for RECORD."
  (let ((person (json-serialize
                 '((@context . "https://schema.org")
                   (@type . "Person")
                   (@id . "https://systemhalted.in/#person")
                   (name . "Palak Mathur")
                   (url . "https://systemhalted.in/about/")
                   (image . "https://systemhalted.in/assets/images/avatar.jpeg")
                   (jobTitle . "Director of Software Engineering")))))
    (concat "<script type=\"application/ld+json\">" person "</script>"
            (when (eq (systemhalted-record-kind record) 'post)
              (concat
               "<script type=\"application/ld+json\">"
               (json-serialize
                `((@context . "https://schema.org")
                  (@type . "BlogPosting")
                  (headline . ,(systemhalted-record-title record))
                  (description . ,(systemhalted-record-description record))
                  (url . ,(concat "https://systemhalted.in"
                                  (systemhalted-record-route record)))))
               "</script>")))))

(defun systemhalted-render-page (record &optional records body)
  "Render complete HTML for RECORD, using RECORDS for cross-page relationships."
  (let* ((records (or records (list record)))
         (body (or body (systemhalted-export-body record records)))
         (kind (systemhalted-record-kind record))
         (content
          (cond
           ((memq kind '(post draft)) (systemhalted--render-post record records body))
           ((eq kind 'emacs)
            (format (concat "<article class=\"emacs-note\"><header class=\"emacs-note-header\">"
                            "<p class=\"newsletter-kicker\">Emacs note</p><h1 class=\"newsletter-title\">%s</h1>"
                            "</header><div class=\"post-content\">%s%s</div></article>")
                    (systemhalted--escape-html (systemhalted-record-title record))
                    (or (and (systemhalted-record-toc record)
                             (systemhalted--toc body)) "") body))
           (t (systemhalted--template
               "page.html"
               `((?t . ,(systemhalted--escape-html (systemhalted-record-title record)))
                 (?c . ,body))))))
         (route (systemhalted-record-route record))
         (title (if (equal route "/") "SystemHalted.in"
                  (format "%s · SystemHalted.in" (systemhalted-record-title record))))
         (current " aria-current=\"page\""))
    (systemhalted--template
     "base.html"
     `((?t . ,(systemhalted--escape-html title))
       (?d . ,(systemhalted--escape-html (systemhalted-record-description record) t))
       (?u . ,(concat "https://systemhalted.in" route))
       (?r . "")
       (?s . "org")
       (?p . ,(if (equal route "/projects/")
                  "<link rel=\"stylesheet\" href=\"/assets/css/projects.css?v=org\">" ""))
       (?j . ,(systemhalted--structured-data record))
       (?w . ,(if (equal route "/") current ""))
       (?P . ,(if (equal route "/projects/") current ""))
       (?A . ,(if (equal route "/archives/") current ""))
       (?o . ,(if (equal route "/about/") current ""))
       (?b . ,content)))))

(defun systemhalted--route-output-file (root route)
  "Return filesystem target below ROOT for public ROUTE."
  (let* ((decoded (decode-coding-string (url-unhex-string route) 'utf-8))
         (relative (string-remove-prefix "/" decoded)))
    (if (string-suffix-p "/" route)
        (expand-file-name (concat relative "index.html") root)
      (expand-file-name relative root))))

(defun systemhalted-write-record (record records output-root)
  "Render RECORD with RECORDS and write it below OUTPUT-ROOT."
  (let ((target (systemhalted--route-output-file
                 output-root (systemhalted-record-route record))))
    (make-directory (file-name-directory target) t)
    (with-temp-file target
      (insert (systemhalted-render-page record records)))
    target))

(provide 'systemhalted-publish)
;;; systemhalted-publish.el ends here
