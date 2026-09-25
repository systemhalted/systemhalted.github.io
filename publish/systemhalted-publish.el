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

(require 'site-config (expand-file-name "site-config" systemhalted-publish-directory))

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
  (if (or (equal route "/")
          (string-suffix-p "/" route)
          (string-match-p "/[^/]+\\.[[:alnum:]]+\\'" route))
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

(defun systemhalted--export-new-reference (references)
  "Return the first unused deterministic reference in REFERENCES."
  (let ((reference 0))
    (while (rassq reference references)
      (setq reference (1+ reference)))
    reference))

(defun systemhalted-export-body (record &optional records)
  "Export RECORD's Org body to HTML with links resolved through RECORDS."
  (let ((systemhalted--export-records (or records (list record)))
        (systemhalted--export-source (systemhalted-record-source record))
        (default-directory
         (file-name-directory (systemhalted-record-source record)))
        ;; The temporary buffer impersonates the source file for Org parsing.
        ;; User kill-buffer hooks may ask before killing it, once per record.
        (kill-buffer-query-functions nil))
    (with-temp-buffer
      (insert-file-contents (systemhalted-record-source record))
      (setq buffer-file-name (systemhalted-record-source record))
      (org-mode)
      (cl-letf (((symbol-function 'org-export-new-reference)
                 #'systemhalted--export-new-reference))
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
           :html-doctype "html5"))))))

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
                            "<p class=\"note-kicker\">Emacs note</p><h1 class=\"emacs-note-title\">%s</h1>"
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
    (let ((coding-system-for-write 'utf-8-unix))
      (with-temp-file target
        (insert (systemhalted-render-page record records))))
    target))

;;; Whole-site generation

(defun systemhalted--write-route (root route contents)
  "Write CONTENTS below ROOT at public ROUTE."
  (let ((target (systemhalted--route-output-file root route)))
    (make-directory (file-name-directory target) t)
    (let ((coding-system-for-write 'utf-8-unix))
      (with-temp-file target
        (insert contents)))
    target))

(defun systemhalted--synthetic-page (title description route)
  "Create a generated page record with TITLE, DESCRIPTION, and ROUTE."
  (make-systemhalted-record
   :source "<generated>" :kind 'page :title title :description description
   :route route :categories nil :tags nil))

(defun systemhalted--render-generated-page (title description route body)
  "Render a generated page from TITLE, DESCRIPTION, ROUTE, and BODY."
  (systemhalted-render-page
   (systemhalted--synthetic-page title description route) nil body))

(defun systemhalted--post-list (posts &optional descriptions)
  "Render POSTS as a dated writing list, including DESCRIPTIONS when non-nil."
  (concat
   "<ol class=\"writing-list\">"
   (mapconcat
    (lambda (post)
      (format (concat "<li class=\"writing-row\"><time datetime=\"%s\">%s</time>"
                      "<div class=\"writing-row-body\"><a href=\"%s\">%s</a>%s</div></li>")
              (format-time-string "%Y-%m-%d" (systemhalted-record-date post))
              (format-time-string (if descriptions "%b %d" "%b %d, %Y")
                                  (systemhalted-record-date post))
              (systemhalted-record-route post)
              (systemhalted--escape-html (systemhalted-record-title post))
              (if descriptions
                  (format "<span class=\"writing-row-desc\">%s</span>"
                          (systemhalted--escape-html
                           (systemhalted-record-description post)))
                "")))
    posts "")
   "</ol>"))

(defun systemhalted--chunks (items size)
  "Split ITEMS into ordered lists of SIZE."
  (let (chunks)
    (while items
      (push (seq-take items size) chunks)
      (setq items (nthcdr (min size (length items)) items)))
    (nreverse chunks)))

(defun systemhalted--generate-home (root posts)
  "Generate home pagination below ROOT for POSTS."
  (let* ((chunks (or (systemhalted--chunks posts systemhalted-page-size)
                     (list nil)))
         (total (length chunks))
         (page 1))
    (dolist (chunk chunks)
      (let* ((route (if (= page 1) "/" (format "/page%d/" page)))
             (body
              (if (= page 1)
                  (concat
                   "<header class=\"home-intro\"><h1><a href=\"https://palakmathur.in\" rel=\"me\">Palak Mathur</a></h1>"
                   "<p>Software engineering, computing systems, leadership, and things I am trying to understand.</p></header>"
                   "<section class=\"home-section\" aria-labelledby=\"recent-writing\"><h2 id=\"recent-writing\">Recent writing</h2>"
                   (systemhalted--post-list chunk t)
                   "<p class=\"section-link\"><a href=\"/archives/\">All writing →</a></p></section>")
                (concat
                 (format "<header class=\"page-header\"><h1>Older writing</h1><p>Page %d of %d.</p></header>"
                         page total)
                 (systemhalted--post-list chunk)
                 (format (concat "<nav class=\"pager\" aria-label=\"Pagination\">%s%s</nav>")
                         (if (> page 1)
                             (format "<a rel=\"prev\" href=\"%s\">← Newer writing</a>"
                                     (if (= page 2) "/" (format "/page%d/" (1- page))))
                           "<span></span>")
                         (if (< page total)
                             (format "<a rel=\"next\" href=\"/page%d/\">Older writing →</a>"
                                     (1+ page)) ""))))))
        (systemhalted--write-route
         root route
         (systemhalted--render-generated-page
          (if (= page 1) "Writing" "Older writing")
          systemhalted-site-description route body)))
      (setq page (1+ page)))))

(defun systemhalted--archive-list (posts)
  "Render POSTS as archive rows."
  (concat
   "<ol class=\"archive-list\">"
   (mapconcat
    (lambda (post)
      (format "<li class=\"archive-row\"><time datetime=\"%s\">%s</time><a href=\"%s\">%s</a></li>"
              (format-time-string "%Y-%m-%d" (systemhalted-record-date post))
              (format-time-string "%b %d, %Y" (systemhalted-record-date post))
              (systemhalted-record-route post)
              (systemhalted--escape-html (systemhalted-record-title post))))
    posts "")
   "</ol>"))

(defconst systemhalted--archive-gateways
  (concat "<nav class=\"archive-gateways\" aria-label=\"Browse writing\">"
          "<a href=\"/archives/\">Archive</a><a href=\"/categories/\">Categories</a>"
          "<a href=\"/tags/\">Tags</a><a href=\"/emacs/\">Emacs</a></nav>"))

(defun systemhalted--generate-archive (root posts)
  "Generate chronological archive below ROOT from POSTS."
  (let ((groups (make-hash-table :test #'equal)))
    (dolist (post posts)
      (push post (gethash (format-time-string "%Y" (systemhalted-record-date post)) groups)))
    (let ((years (sort (hash-table-keys groups) #'string>)))
      (systemhalted--write-route
       root "/archives/"
       (systemhalted--render-generated-page
        "Archive" "A chronological archive of SystemHalted writing." "/archives/"
        (concat
         (format "<p class=\"archive-intro\">%d articles written since %s. Browse chronologically or by subject.</p>"
                 (length posts) (if posts
                                    (format-time-string "%Y" (systemhalted-record-date (car (last posts))))
                                  ""))
         systemhalted--archive-gateways
         "<div id=\"archive-years\">"
         (mapconcat
          (lambda (year)
            (let ((items (nreverse (gethash year groups))))
              (format (concat "<details class=\"archive-year\" data-year=\"%s\" data-count=\"%d\">"
                              "<summary class=\"archive-year-summary\"><span class=\"archive-year-title\">%s</span>"
                              "<span class=\"archive-year-count\">%d articles</span></summary>%s</details>")
                      year (length items) year (length items)
                      (systemhalted--archive-list items))))
          years "")
         "</div>"))))))

(defun systemhalted--group-records (records accessor)
  "Group RECORDS by every value returned by ACCESSOR."
  (let ((groups (make-hash-table :test #'equal)))
    (dolist (record records)
      (dolist (value (funcall accessor record))
        (push record (gethash value groups))))
    groups))

(defun systemhalted--generate-taxonomy (root posts route title description accessor id-prefix)
  "Generate taxonomy TITLE at ROUTE by grouping POSTS with ACCESSOR."
  (let* ((groups (systemhalted--group-records posts accessor))
         (names (sort (hash-table-keys groups) #'string-lessp))
         (body
          (concat systemhalted--archive-gateways
                  "<div class=\"tag-groups\">"
                  (mapconcat
                   (lambda (name)
                     (let ((items (sort (gethash name groups)
                                        (lambda (left right)
                                          (time-less-p
                                           (systemhalted-record-date right)
                                           (systemhalted-record-date left))))))
                       (format (concat "<details id=\"%s%s\" class=\"archive-year taxonomy-group\">"
                                       "<summary class=\"archive-year-summary\"><span class=\"archive-year-title\">%s</span>"
                                       "<span class=\"archive-year-count\">%d articles</span></summary>%s</details>")
                               id-prefix (systemhalted--slugify name)
                               (systemhalted--escape-html name) (length items)
                               (systemhalted--archive-list items))))
                   names "")
                  "</div>")))
    (systemhalted--write-route
     root route (systemhalted--render-generated-page title description route body))))

(defun systemhalted--record-route-present-p (route records)
  "Return non-nil when ROUTE is claimed by RECORDS."
  (seq-find (lambda (record) (equal route (systemhalted-record-route record))) records))

(defun systemhalted--generate-emacs-index (root records)
  "Generate the Emacs-note index below ROOT from RECORDS."
  (let ((notes (sort (seq-filter
                      (lambda (record) (eq (systemhalted-record-kind record) 'emacs))
                      (copy-sequence records))
                     (lambda (left right)
                       (string-lessp (systemhalted-record-title left)
                                     (systemhalted-record-title right))))))
    (systemhalted--write-route
     root "/emacs/"
     (systemhalted--render-generated-page
      "Emacs" "Emacs notes, configurations, and packages." "/emacs/"
      (concat "<p class=\"archive-intro\">A small wiki of Emacs notes, configurations, and packages I keep coming back to.</p>"
              systemhalted--archive-gateways
              "<ul class=\"post-feed\">"
              (mapconcat
               (lambda (note)
                 (format "<li class=\"post-feed-item\"><h2 class=\"post-feed-title\"><a href=\"%s\">%s</a></h2><p class=\"post-feed-excerpt\">%s</p></li>"
                         (systemhalted-record-route note)
                         (systemhalted--escape-html (systemhalted-record-title note))
                         (systemhalted--escape-html (systemhalted-record-description note))))
               notes "")
              "</ul>")))))

(defun systemhalted--generate-default-pages (root records)
  "Generate required landing pages below ROOT when RECORDS do not define them."
  (dolist (definition
           '(("/about/" "About" "About Palak Mathur." "<p>Software engineer and writer.</p>")
             ("/projects/" "Projects" "Projects by Palak Mathur." "<p class=\"projects-intro\">Software, tools, and experiments I build.</p>")
             ("/themes/" "Jekyll Themes" "Open-source themes by Palak Mathur." "<p>Open-source themes and design work.</p>")))
    (unless (systemhalted--record-route-present-p (car definition) records)
      (systemhalted--write-route
       root (car definition)
       (systemhalted--render-generated-page
        (nth 1 definition) (nth 2 definition) (car definition) (nth 3 definition)))))
  (unless (systemhalted--record-route-present-p "/webcmd/" records)
    (systemhalted--write-route
     root "/webcmd/"
     (systemhalted--render-generated-page
      "In the beginning was a command line" "A terminal-style interface to the archive."
      "/webcmd/"
      (concat "<section class=\"webcmd\" aria-labelledby=\"webcmd-title\"><h1 id=\"webcmd-title\">"
              "In the beginning was a command line</h1><form id=\"webcmd-form\"><label class=\"sr-only\" "
              "for=\"line\">Enter a command</label><input id=\"line\" name=\"cmd\" type=\"text\"></form>"
              "<div id=\"error\" role=\"status\"></div><div id=\"output\" role=\"log\"></div>"
              "<button id=\"webcmd-help-toggle\" type=\"button\" aria-controls=\"help\">Show commands</button>"
              "<div id=\"help\"></div></section><script src=\"/assets/js/elasticlunr.min.js\"></script>"
              "<script src=\"/assets/js/webcmd.js\"></script>")))))

(defun systemhalted--xml-escape (value)
  "Escape VALUE for XML text and attributes."
  (systemhalted--escape-html value t))

(defun systemhalted--generate-feed (root posts)
  "Generate RSS feed below ROOT from POSTS."
  (systemhalted--write-route
   root "/feed.xml"
   (concat
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rss version=\"2.0\"><channel>"
    "<title>SystemHalted.in</title><link>https://systemhalted.in/</link><description>"
    (systemhalted--xml-escape systemhalted-site-description) "</description>"
    (mapconcat
     (lambda (post)
       (format (concat "<item><title>%s</title><link>%s%s</link><guid>%s%s</guid>"
                       "<pubDate>%s</pubDate><description>%s</description></item>")
               (systemhalted--xml-escape (systemhalted-record-title post))
               systemhalted-site-url (systemhalted-record-route post)
               systemhalted-site-url (systemhalted-record-route post)
               (format-time-string "%a, %d %b %Y %H:%M:%S %z"
                                   (systemhalted-record-date post))
               (systemhalted--xml-escape (systemhalted-record-description post))))
     (seq-take posts 50) "")
    "</channel></rss>")))

(defun systemhalted--generated-routes (posts records)
  "Return generated routes for POSTS and RECORDS."
  (append '("/" "/archives/" "/categories/" "/tags/" "/emacs/"
            "/about/" "/projects/" "/themes/" "/webcmd/" "/kartavya-path/")
          (let ((pages (length (systemhalted--chunks posts systemhalted-page-size))) routes)
            (dotimes (index (max 0 (1- pages)))
              (push (format "/page%d/" (+ index 2)) routes))
            routes)
          (mapcar #'systemhalted-record-route records)))

(defun systemhalted--generate-sitemap (root routes)
  "Generate sitemap below ROOT for ROUTES."
  (systemhalted--write-route
   root "/sitemap.xml"
   (concat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
           "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
           (mapconcat
            (lambda (route)
              (format "<url><loc>%s%s</loc></url>"
                      systemhalted-site-url (systemhalted--xml-escape route)))
            (sort (delete-dups (copy-sequence routes)) #'string-lessp) "")
           "</urlset>")))

(defun systemhalted--strip-html (html)
  "Return normalized plain text from HTML."
  (string-trim
   (replace-regexp-in-string
    "[[:space:]]+" " "
    (replace-regexp-in-string "<[^>]+>" " " html))))

(defun systemhalted--read-os-history (source-root)
  "Read fortunes and timeline rows from SOURCE-ROOT's Org data."
  (let ((file (expand-file-name "org/data/os-history.org" source-root))
        section fortunes timeline)
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (cond
             ((equal line "* Fortunes") (setq section 'fortunes))
             ((equal line "* Timeline") (setq section 'timeline))
             ((and (eq section 'fortunes) (string-prefix-p "- " line))
              (push (string-remove-prefix "- " line) fortunes))
             ((and (eq section 'timeline)
                   (string-match
                    "^|[ \\t]*\\([0-9]+\\)[ \\t]*|\\([^|]+\\)|[ \\t]*$"
                    line))
              (push `((year . ,(string-to-number (match-string 1 line)))
                      (event . ,(string-trim (match-string 2 line))))
                    timeline))))
          (forward-line 1))))
    (list (nreverse fortunes) (nreverse timeline))))

(defun systemhalted--read-file (file)
  "Return FILE contents as a string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun systemhalted--generate-search (root records source-root)
  "Generate browser search and webcmd data below ROOT from RECORDS.
SOURCE-ROOT supplies the maintained command runtime and OS-history data."
  (let ((documents nil) (id 0))
    (dolist (record records)
      (when (memq (systemhalted-record-kind record) '(post emacs))
        (let* ((text (systemhalted--strip-html
                      (systemhalted-export-body record records)))
               (snippet (substring text 0 (min 140 (length text)))))
          (push `((id . ,id)
                  (title . ,(systemhalted-record-title record))
                  (layout . ,(symbol-name (systemhalted-record-kind record)))
                  (categories . ,(string-join (systemhalted-record-categories record) " "))
                  (tags . ,(string-join (systemhalted-record-tags record) " "))
                  (content . ,text)
                  (link . ,(systemhalted-record-route record))
                  (snippet . ,snippet))
                documents)
          (setq id (1+ id)))))
    (pcase-let ((`(,fortunes ,timeline)
                 (systemhalted--read-os-history source-root)))
      (systemhalted--write-route
       root "/assets/js/webcmd.js"
       (concat
        "/* Generated search data and index compatibility layer. */\n"
        "var siteDocs=" (json-serialize (vconcat (nreverse documents))) ";\n"
        "window.siteDocs=siteDocs;window.siteStore=siteDocs;\n"
        "function ensureSiteIndex(){if(typeof elasticlunr==='undefined')return false;"
        "if(window.siteIndex)return true;var idx=elasticlunr(function(){this.addField('title');"
        "this.addField('layout');this.addField('categories');this.addField('tags');"
        "this.addField('content');this.setRef('id');});for(var i=0;i<siteDocs.length;i++)"
        "idx.addDoc(siteDocs[i]);window.siteIndex=idx;return true;}\n"
        "ensureSiteIndex();\n"
        "var osFortunes=" (json-serialize (vconcat fortunes)) ";\n"
        "var osTimeline=" (json-serialize (vconcat timeline)) ";\n"
        (systemhalted--read-file
         (expand-file-name "templates/webcmd-runtime.js"
                           systemhalted-publish-directory)))))))

(defun systemhalted--copy-static (source-root output-root)
  "Copy configured static inputs from SOURCE-ROOT to OUTPUT-ROOT."
  (dolist (relative systemhalted-static-paths)
    (let ((source (expand-file-name relative source-root))
          (target (expand-file-name relative output-root)))
      (when (file-exists-p source)
        (if (file-directory-p source)
            (copy-directory source target nil t t)
          (make-directory (file-name-directory target) t)
          (copy-file source target t t t)))))
  (with-temp-file (expand-file-name ".nojekyll" output-root)))

(defun systemhalted--generate-jsgames-index (root)
  "Replace any Liquid games index below ROOT with static links."
  (let* ((games-root (expand-file-name "jsgames" root))
         (games (and (file-directory-p games-root)
                     (seq-filter
                      (lambda (name)
                        (and (not (member name '("." "..")))
                             (file-directory-p (expand-file-name name games-root))
                             (file-exists-p (expand-file-name
                                             (concat name "/index.html") games-root))))
                      (directory-files games-root)))))
    (systemhalted--write-route
     root "/jsgames/"
     (systemhalted--render-generated-page
      "JavaScript Games" "Small browser games and experiments." "/jsgames/"
      (concat "<ul class=\"post-feed\">"
              (mapconcat
               (lambda (game)
                 (format "<li><a href=\"/jsgames/%s/\">%s</a></li>"
                         game (systemhalted--escape-html game)))
               games "") "</ul>")))))

(defun systemhalted--redirect-page (target)
  "Return a static redirect page to TARGET."
  (format (concat "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
                  "<meta http-equiv=\"refresh\" content=\"0; url=%s\">"
                  "<link rel=\"canonical\" href=\"%s%s\"><title>Moved</title></head>"
                  "<body><p>This page moved to <a href=\"%s\">%s</a>.</p></body></html>")
          target systemhalted-site-url target target target))

(defun systemhalted--load-content-directories (directories include-drafts include-future now)
  "Load all content DIRECTORIES with visibility controls."
  (let (records)
    (dolist (entry directories)
      (when (file-directory-p (car entry))
        (setq records
              (append records
                      (systemhalted-load-records
                       (car entry) :kind (cdr entry) :now now
                       :include-drafts include-drafts
                       :include-future include-future)))))
    (systemhalted-validate-records records)
    records))

(defun systemhalted--default-content-directories (root)
  "Return standard content directories below ROOT."
  (list (cons (expand-file-name "org/posts" root) 'post)
        (cons (expand-file-name "org/drafts" root) 'draft)
        (cons (expand-file-name "org/emacs" root) 'emacs)
        (cons (expand-file-name "org/pages" root) 'page)))

(defun systemhalted-audit-content (root)
  "Validate the complete maintained Org corpus below ROOT."
  (let* ((directories (systemhalted--default-content-directories root))
         (missing (seq-filter (lambda (entry) (not (file-directory-p (car entry))))
                              directories))
         (org-root (expand-file-name "org" root)))
    (when missing
      (signal 'systemhalted-publish-error
              (list (format "missing Org content directories: %s"
                            (mapconcat #'car missing ", ")))))
    (dolist (file (directory-files-recursively org-root "."))
      (when (and (file-regular-p file)
                 (not (string-suffix-p ".org" file)))
        (systemhalted--source-error file "non-Org publishing input")))
    (dolist (file (directory-files-recursively org-root "\\.org\\'"))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (when (re-search-forward "{[%{]" nil t)
          (systemhalted--source-error file "untranslated Liquid construct"))))
    (systemhalted--load-content-directories directories t t nil)
    t))

(defun systemhalted--generate-site (source-root output-root records)
  "Generate the complete site from RECORDS into OUTPUT-ROOT."
  (make-directory output-root t)
  (systemhalted--copy-static source-root output-root)
  (dolist (record records)
    (systemhalted-write-record record records output-root))
  (let ((posts (systemhalted--post-records
                (seq-remove #'systemhalted-record-draft records))))
    (systemhalted--generate-home output-root posts)
    (systemhalted--generate-archive output-root posts)
    (systemhalted--generate-taxonomy
     output-root posts "/categories/" "Categories"
     "An archive of posts sorted by category."
     #'systemhalted-record-categories "cat-")
    (systemhalted--generate-taxonomy
     output-root posts "/tags/" "Tags" "An archive of posts sorted by tag."
     #'systemhalted-record-tags "")
    (systemhalted--generate-emacs-index output-root records)
    (systemhalted--generate-default-pages output-root records)
    (systemhalted--generate-feed output-root posts)
    (systemhalted--generate-search output-root records source-root)
    (unless (systemhalted--record-route-present-p "/jsgames/" records)
      (systemhalted--generate-jsgames-index output-root))
    (dolist (redirect systemhalted-legacy-redirects)
      (systemhalted--write-route output-root (car redirect)
                                 (systemhalted--redirect-page (cdr redirect))))
    (systemhalted--write-route output-root "/kartavya-path/"
                               (systemhalted--redirect-page "/archives/"))
    (systemhalted--generate-sitemap
     output-root (systemhalted--generated-routes posts records))))

(defun systemhalted--local-target-file (root url)
  "Map local URL below ROOT to its expected output file."
  (let* ((decoded (decode-coding-string (url-unhex-string url) 'utf-8))
         (path (car (split-string decoded "[#?]")))
         (relative (string-remove-prefix "/" path)))
    (cond
     ((or (string-empty-p relative) (string-suffix-p "/" path))
      (expand-file-name (concat relative "index.html") root))
     (t (expand-file-name relative root)))))

(defun systemhalted--validate-internal-links (root)
  "Signal when an HTML file below ROOT references a missing local target."
  (dolist (file (directory-files-recursively root "\\.html\\'"))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward "\\(?:href\\|src\\)=\"\\(/[^\"#?]*\\)" nil t)
        (let* ((url (match-string-no-properties 1))
               (target (systemhalted--local-target-file root url)))
          (unless (file-exists-p target)
            (signal 'systemhalted-publish-error
                    (list (format "%s: broken local target %s" file url)))))))))

(defun systemhalted--validate-xml (file)
  "Signal when FILE is not well-formed XML."
  (condition-case err
      (with-temp-buffer
        (insert-file-contents file)
        (libxml-parse-xml-region (point-min) (point-max)))
    (error
     (signal 'systemhalted-publish-error
             (list (format "%s: malformed XML: %s" file (error-message-string err)))))))

(defun systemhalted-validate-site (root)
  "Validate required XML and every local HTML link below ROOT."
  (dolist (relative '("feed.xml" "sitemap.xml"))
    (let ((file (expand-file-name relative root)))
      (when (file-exists-p file) (systemhalted--validate-xml file))))
  (systemhalted--validate-internal-links root)
  t)

(defun systemhalted-directory-digest (root)
  "Return a deterministic digest of relative paths and bytes below ROOT."
  (secure-hash
   'sha256
   (mapconcat
    (lambda (file)
      (concat (file-relative-name file root) "\0"
              (with-temp-buffer
                (set-buffer-multibyte nil)
                (insert-file-contents-literally file)
                (secure-hash 'sha256 (current-buffer)))))
    (sort (seq-filter #'file-regular-p
                      (directory-files-recursively root "." t))
          #'string-lessp)
    "\0")))

(cl-defun systemhalted-build-site (&key root output content-directories
                                        include-drafts include-future now)
  "Build the site from ROOT into OUTPUT using an atomic staged install."
  (let* ((root (file-name-as-directory (expand-file-name root)))
         (output (directory-file-name (expand-file-name output)))
         (parent (file-name-directory output))
         (stage (make-temp-file (expand-file-name ".systemhalted-stage-" parent) t))
         (backup (concat output ".previous"))
         (directories (or content-directories
                          (systemhalted--default-content-directories root)))
         (records (systemhalted--load-content-directories
                   directories include-drafts include-future now)))
    (condition-case err
        (progn
          (systemhalted--generate-site root stage records)
          (systemhalted-validate-site stage)
          (when (file-exists-p backup) (delete-directory backup t))
          (when (file-exists-p output) (rename-file output backup))
          (condition-case install-error
              (rename-file stage output)
            (error
             (when (and (file-exists-p backup) (not (file-exists-p output)))
               (rename-file backup output))
             (signal (car install-error) (cdr install-error))))
          (when (file-exists-p backup) (delete-directory backup t))
          output)
      (error
       (when (file-exists-p stage) (delete-directory stage t))
       (if (eq (car err) 'systemhalted-publish-error)
           (signal (car err) (cdr err))
         (signal 'systemhalted-publish-error
                 (list (error-message-string err))))))))

(provide 'systemhalted-publish)
;;; systemhalted-publish.el ends here
