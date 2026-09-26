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
  mermaid last-modified featured-image featured-image-alt featured-image-caption draft
  future-p hide-title quiet-title kartavya-path)

(defconst systemhalted--metadata-keys
  '("TITLE" "DESCRIPTION" "DATE" "CATEGORIES" "TAGS" "PERMALINK"
    "COMMENTS" "TOC" "MERMAID" "LAST_MODIFIED" "FEATURED_IMAGE"
    "FEATURED_IMAGE_ALT" "FEATURED_IMAGE_CAPTION" "DRAFT"
    "HIDE_TITLE" "QUIET_TITLE" "KARTAVYA_PATH"))

(defvar systemhalted--asset-version "0"
  "Deterministic cache-busting token substituted for `?v=' on CSS/JS links.
Bound by `systemhalted--generate-site' to a content digest of assets/css and
assets/js, never the wall clock, so two clean builds stay byte-identical.
Direct calls to `systemhalted-render-page' outside a full build (such as
tests exercising a single record) get this fallback constant instead.")

(defvar systemhalted--footer-year "2026"
  "Year shown in the footer copyright line: the newest post's year.
Bound by `systemhalted--generate-site'. Direct calls to
`systemhalted-render-page' outside a full build get this fallback constant.")

(defvar systemhalted--source-root
  (file-name-directory (directory-file-name systemhalted-publish-directory))
  "Project root used to resolve `org/data/taxonomy.org' for the related-posts
sibling-theme scoring bonus (`systemhalted--related-records'). Bound by
`systemhalted--generate-site' to the real source root. Direct calls to
`systemhalted-render-page' outside a full build (such as tests exercising a
single record) get this fallback constant instead.")

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

(defun systemhalted--split-list-value (value)
  "Split VALUE on commas that fall outside double-quoted spans.
A double-quoted item may therefore contain a literal comma; the quotes
themselves are not included in the returned pieces."
  (let ((items nil)
        (piece nil)
        (in-quotes nil))
    (dotimes (i (length value))
      (let ((char (aref value i)))
        (cond
         ((eq char ?\") (setq in-quotes (not in-quotes)))
         ((and (eq char ?,) (not in-quotes))
          (push (concat (nreverse piece)) items)
          (setq piece nil))
         (t (push char piece)))))
    (push (concat (nreverse piece)) items)
    (nreverse items)))

(defun systemhalted--list-value (value)
  "Turn comma-separated VALUE into a trimmed list.
An item wrapped in double quotes may contain a literal comma, for example
a category named \"Series 2 - Turtle, BASIC, and the Long Road to Taste\"."
  (when value
    (delq nil
          (mapcar (lambda (piece)
                    (let ((trimmed (string-trim piece)))
                      (and (not (string-empty-p trimmed)) trimmed)))
                  (systemhalted--split-list-value value)))))

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
  "Parse date VALUE for FILE into a UTC-anchored Emacs time value.
A bare date means midnight UTC. A date and time with no explicit offset is
treated as already being in UTC, matching Jekyll's UTC build runners. A date
and time with an explicit offset converts to the equivalent UTC instant,
which is how the live site's dated URLs and timestamps were derived."
  (unless value
    (systemhalted--source-error file "missing DATE and no date in filename"))
  (let* ((clean (string-trim value "[<[]" "[]>]"))
         (parsed (condition-case nil (parse-time-string clean) (error nil)))
         (day (nth 3 parsed))
         (month (nth 4 parsed))
         (year (nth 5 parsed)))
    (unless (and day month year)
      (systemhalted--source-error file "invalid DATE %S" value))
    (encode-time (or (nth 0 parsed) 0) (or (nth 1 parsed) 0) (or (nth 2 parsed) 0)
                 day month year (or (nth 8 parsed) t))))

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

(defun systemhalted--iso-datetime (date)
  "Return DATE formatted as a UTC ISO 8601 datetime, e.g. 2026-09-25T00:00:00+00:00."
  (format-time-string "%Y-%m-%dT%H:%M:%S%:z" date t))

(defun systemhalted--default-route (file kind date slug)
  "Derive a route for FILE of KIND using DATE and SLUG."
  (pcase kind
    ((or 'post 'draft)
     (format "/%s/%s/"
             (format-time-string "%Y/%m/%d" date t)
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
     :mermaid (systemhalted--boolean-value
               (systemhalted--keyword keywords "MERMAID"))
     :last-modified (systemhalted--keyword keywords "LAST_MODIFIED")
     :featured-image (systemhalted--keyword keywords "FEATURED_IMAGE")
     :featured-image-alt (systemhalted--keyword keywords "FEATURED_IMAGE_ALT")
     :featured-image-caption
     (systemhalted--keyword keywords "FEATURED_IMAGE_CAPTION")
     :draft draft
     :future-p (and date (time-less-p now date))
     :hide-title (systemhalted--boolean-value
                  (systemhalted--keyword keywords "HIDE_TITLE"))
     :quiet-title (systemhalted--boolean-value
                   (systemhalted--keyword keywords "QUIET_TITLE"))
     :kartavya-path (systemhalted--boolean-value
                     (systemhalted--keyword keywords "KARTAVYA_PATH")))))

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

(defun systemhalted--link-description-text (link)
  "Return LINK's bracketed description as plain text, or nil when absent."
  (let ((contents (org-element-contents link)))
    (when contents
      (org-string-nw-p (org-trim (org-element-interpret-data contents))))))

(defun systemhalted--paragraph-caption-text (paragraph)
  "Return PARAGRAPH's #+CAPTION rendered as plain text, or nil when absent."
  (when paragraph
    (let ((caption (org-export-get-caption paragraph)))
      (when caption
        (org-string-nw-p (org-trim (org-element-interpret-data caption)))))))

(defun systemhalted--paragraph-attr-html-alt (paragraph)
  "Return PARAGRAPH's #+ATTR_HTML :alt value, or nil when absent."
  (when paragraph
    (org-string-nw-p
     (plist-get (org-export-read-attribute :attr_html paragraph) :alt))))

(defun systemhalted--image-alt-text (link)
  "Return alt text for image LINK.
Prefers LINK's own description, then any enclosing paragraph's #+CAPTION
or #+ATTR_HTML :alt. Never falls back to the bare file name."
  (or (systemhalted--link-description-text link)
      (let* ((container (org-element-parent link))
             (paragraph (if (org-element-type-p container 'link)
                            (org-element-parent container)
                          container)))
        (or (systemhalted--paragraph-caption-text paragraph)
            (systemhalted--paragraph-attr-html-alt paragraph)))
      ""))

(defun systemhalted--root-relative-image-p (path info)
  "Non-nil when PATH matches the site's inline image rules for file links."
  (let ((rule (cdr (assoc "file" (plist-get info :html-inline-image-rules))))
        (case-fold-search t))
    (and rule (string-match-p rule path))))

(defun systemhalted-html-link (link contents info)
  "Render Org LINK, mapping links to Org sources onto their public routes."
  (let ((type (org-element-property :type link))
        (path (org-element-property :path link)))
    (cond
     ((and (string= type "file") (string-suffix-p ".org" path t))
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
                     (systemhalted-record-title record))))))
     ;; Root-relative file links (`[[/path/]]`, `[[/assets/x.svg]]`) must
     ;; export as site-relative URLs, never as `file://` URIs.
     ((and (string= type "file") (string-prefix-p "/" path))
      (if (systemhalted--root-relative-image-p path info)
          (format "<img src=\"%s\" alt=\"%s\">"
                  (systemhalted--escape-html path t)
                  (systemhalted--escape-html
                   (systemhalted--image-alt-text link) t))
        (format "<a href=\"%s\">%s</a>"
                (systemhalted--escape-html path t)
                (or contents (systemhalted--escape-html path)))))
     (t (org-html-link link contents info)))))

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
        ;; User mode hooks may install prompts on every temporary Org buffer.
        (org-mode-hook nil)
        (kill-buffer-query-functions nil))
    (with-temp-buffer
      (unwind-protect
          (progn
            (insert-file-contents (systemhalted-record-source record))
            (setq buffer-file-name (systemhalted-record-source record))
            (org-mode)
            ;; Org's parser copies this buffer, including `buffer-file-name'.
            ;; Keep the real path in `systemhalted--export-source' instead, so
            ;; private export copies cannot trigger file-associated save/kill
            ;; prompts in the user's Emacs.
            (setq buffer-file-name nil)
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
                 :html-doctype "html5"))))
        (setq buffer-file-name nil)
        (set-buffer-modified-p nil)))))

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

(defun systemhalted--related-records (record records themes)
  "Return up to three RECORDS related to RECORD using current scoring rules.
Score is +3 per shared category and +2 per shared tag. When a candidate
shares neither, it still earns +1 per sibling category it shares with
RECORD in the same THEMES entry (`systemhalted--read-taxonomy''s :THEMES),
matching `main:_layouts/post.html'. Ties break toward the newer post."
  (let* ((categories (systemhalted-record-categories record))
         (siblings (delete-dups
                    (apply #'append
                           (mapcar (lambda (category)
                                     (systemhalted--taxonomy-category-siblings
                                      themes category))
                                   categories))))
         scored)
    (dolist (candidate (systemhalted--post-records records))
      (unless (equal (systemhalted-record-route candidate)
                     (systemhalted-record-route record))
        (let* ((cat-matches (systemhalted--intersection-count
                             categories
                             (systemhalted-record-categories candidate)))
               (tag-matches (systemhalted--intersection-count
                             (systemhalted-record-tags record)
                             (systemhalted-record-tags candidate)))
               (score (+ (* 3 cat-matches) (* 2 tag-matches))))
          (when (and (= cat-matches 0) (= tag-matches 0) siblings)
            (setq score (systemhalted--intersection-count
                         siblings (systemhalted-record-categories candidate))))
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

(defun systemhalted--category-counts (posts)
  "Return a hash table mapping each category name to how many POSTS carry it,
matching Jekyll's `site.categories[category].size' used to find the
rarest shared category for a related-post reason."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (post posts)
      (dolist (category (systemhalted-record-categories post))
        (puthash category (1+ (gethash category table 0)) table)))
    table))

(defun systemhalted--related-reason (record related category-counts)
  "Return the reason RECORD links to RELATED, matching `main:_layouts/post.html':
1. \"More from <category>\", the category RECORD and RELATED share with the
   fewest posts site-wide (per CATEGORY-COUNTS), ties won by whichever of
   RECORD's own categories comes first.
2. Otherwise \"Also about <tag>\", the last tag shared with RELATED in
   RECORD's own #+TAGS order.
3. Otherwise \"Related reading\"."
  (let ((rarest-count nil) (reason nil))
    (dolist (category (systemhalted-record-categories record))
      (when (member category (systemhalted-record-categories related))
        (let ((count (gethash category category-counts 0)))
          (when (or (null rarest-count) (< count rarest-count))
            (setq rarest-count count
                  reason (format "More from %s" category))))))
    (unless reason
      (dolist (tag (systemhalted-record-tags record))
        (when (member tag (systemhalted-record-tags related))
          (setq reason (format "Also about %s" tag)))))
    (or reason "Related reading")))

(defun systemhalted--related-html (record records themes)
  "Render the related-posts list for RECORD from RECORDS, or nil when there
are none. THEMES is `systemhalted--read-taxonomy''s :THEMES, used for the
sibling-category scoring bonus."
  (let ((related (systemhalted--related-records record records themes)))
    (when related
      (let ((category-counts
             (systemhalted--category-counts (systemhalted--post-records records))))
        (concat
         "<ul class=\"related-posts\">"
         (mapconcat
          (lambda (item)
            (format (concat "<li class=\"related-post\"><time class=\"related-post-date\" "
                            "datetime=\"%s\">%s</time><a class=\"related-post-title\" "
                            "href=\"%s\">%s</a><span class=\"related-post-reason\">%s</span></li>")
                    (systemhalted--iso-datetime (systemhalted-record-date item))
                    (format-time-string "%b %d, %Y" (systemhalted-record-date item) t)
                    (systemhalted--escape-html (systemhalted-record-route item) t)
                    (systemhalted--escape-html (systemhalted-record-title item))
                    (systemhalted--escape-html
                     (systemhalted--related-reason record item category-counts))))
          related "")
         "</ul>")))))

(defun systemhalted--post-more-html (record records themes)
  "Render the \"More from SystemHalted\" section for RECORD: the related-posts
list from `systemhalted--related-html' followed by the newer/older nav from
`systemhalted--adjacent-html', both from RECORDS. THEMES is
`systemhalted--read-taxonomy''s :THEMES. Returns nil when there is neither,
matching `main:_layouts/post.html''s single guard around both."
  (let ((related (systemhalted--related-html record records themes))
        (nav (systemhalted--adjacent-html record records)))
    (when (or related nav)
      (concat
       "<section class=\"post-more\" aria-labelledby=\"more-writing-heading\">"
       "<h2 id=\"more-writing-heading\" class=\"post-more-heading\">More from SystemHalted</h2>"
       (or related "")
       (or nav "")
       "</section>"))))

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
       (?i . ,(systemhalted--iso-datetime date))
       (?d . ,(format-time-string "%-d %B %Y" date t))
       (?m . ,(format "<span aria-hidden=\"true\">·</span> %d min read" minutes))
       (?T . ,(or (and (systemhalted-record-toc record)
                       (systemhalted--toc body)) ""))
       (?c . ,body)
       (?f . ,(or (systemhalted--featured-html record) ""))
       (?x . ,(or (systemhalted--taxonomy-html record) ""))
       (?r . ,(or (systemhalted--post-more-html
                   record records
                   (plist-get (systemhalted--read-taxonomy systemhalted--source-root)
                              :themes))
                  ""))
       (?g . ,(or (systemhalted--comments-html record) ""))))))

(defun systemhalted--mermaid-head-html (record)
  "Return head markup that loads Mermaid when RECORD opts in with #+MERMAID.
Matches main's `_includes/head.html': the same version, SRI, and the script
that turns a kramdown+rouge `.language-mermaid' block into a `.mermaid' div
mermaid.js can render."
  (when (systemhalted-record-mermaid record)
    (concat
     "<script defer src=\"https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js\" "
     "integrity=\"sha384-R63zfMfSwJF4xCR11wXii+QUsbiBIdiDzDbtxia72oGWfkT7WHJfmD/I/eeHPJyT\" "
     "crossorigin=\"anonymous\"></script>"
     "<script>"
     "document.addEventListener('DOMContentLoaded', function () {"
     "if (typeof mermaid === 'undefined') { return; }"
     "document.querySelectorAll('.language-mermaid').forEach(function (el) {"
     "var isCode = el.tagName === 'CODE';"
     "var codeEl = isCode ? el : el.querySelector('code');"
     "if (!codeEl) { return; }"
     "var block = isCode ? (el.closest('pre') || el) : el;"
     "if (!block.parentNode) { return; }"
     "var div = document.createElement('div');"
     "div.className = 'mermaid';"
     "div.textContent = codeEl.textContent;"
     "block.parentNode.replaceChild(div, block);"
     "});"
     "mermaid.initialize({ startOnLoad: false, theme: 'neutral' });"
     "mermaid.run();"
     "});"
     "</script>")))

(defconst systemhalted--website-alternate-names
  '("The System Halted" "System Halted" "The SystemHalted" "systemhalted")
  "Brand-query variants exposed as JSON-LD `alternateName' on the home page,
matching main's `_includes/structured-data.html'.")

(defun systemhalted--page-image-url (record)
  "Return the absolute image URL for RECORD: its featured image, or the avatar."
  (concat systemhalted-site-url
          (or (systemhalted-record-featured-image record)
              "/assets/images/avatar.jpeg")))

(defun systemhalted--structured-data (record)
  "Return JSON-LD shared by pages, including home and article data for RECORD."
  (let* ((route (systemhalted-record-route record))
         (person-id (concat systemhalted-site-url "/#person"))
         (person (json-serialize
                  `((@context . "https://schema.org")
                    (@type . "Person")
                    (@id . ,person-id)
                    (name . ,systemhalted-site-author)
                    (url . ,(concat systemhalted-site-url "/about/"))
                    (image . "https://systemhalted.in/assets/images/avatar.jpeg")
                    (jobTitle . "Director of Software Engineering")
                    (sameAs . ,(vconcat systemhalted-social-links))))))
    (concat "<script type=\"application/ld+json\">" person "</script>"
            (when (equal route "/")
              (concat
               "<script type=\"application/ld+json\">"
               (json-serialize
                `((@context . "https://schema.org")
                  (@type . "WebSite")
                  (@id . ,(concat systemhalted-site-url "/#website"))
                  (name . ,systemhalted-site-title)
                  (alternateName . ,(vconcat systemhalted--website-alternate-names))
                  (url . ,(concat systemhalted-site-url "/"))
                  (description . ,systemhalted-site-description)
                  (inLanguage . "en-US")
                  (publisher . ((@id . ,person-id)))
                  (author . ((@id . ,person-id)))))
               "</script>"))
            (when (memq (systemhalted-record-kind record) '(post draft))
              (concat
               "<script type=\"application/ld+json\">"
               (json-serialize
                `((@context . "https://schema.org")
                  (@type . "BlogPosting")
                  (headline . ,(systemhalted-record-title record))
                  (description . ,(systemhalted-record-description record))
                  (url . ,(concat systemhalted-site-url route))
                  (datePublished . ,(systemhalted--iso-datetime
                                     (systemhalted-record-date record)))
                  (author . ((@id . ,person-id)))
                  (image . ,(systemhalted--page-image-url record))))
               "</script>")))))

(defun systemhalted--analytics-html ()
  "Return the Google Analytics gtag script, matching main's `_includes/head.html'."
  (concat
   "<script async src=\"https://www.googletagmanager.com/gtag/js?id="
   systemhalted-google-analytics-id "\"></script>"
   "<script>"
   "window.dataLayer = window.dataLayer || [];"
   "function gtag(){dataLayer.push(arguments);}"
   "gtag('js', new Date());"
   "gtag('config', '" systemhalted-google-analytics-id "');"
   "</script>"))

(defun systemhalted--paginated-route-p (route)
  "Non-nil when ROUTE is a `/pageN/' route."
  (string-match-p "\\`/page[0-9]+/\\'" route))

(defun systemhalted--bare-main-route-p (route)
  "Non-nil when ROUTE renders straight into base.html's <main>, with no
page.html wrapper: the home page, its `/pageN/' siblings, and `/webcmd/'
(all `layout: default' on main, not `layout: page')."
  (or (equal route "/") (equal route "/webcmd/")
      (systemhalted--paginated-route-p route)))

(defun systemhalted--noindex-route-p (route)
  "Non-nil when ROUTE must carry a noindex robots meta tag, matching live's
`/pageN/' pagination pages and the 404 page."
  (or (systemhalted--paginated-route-p route) (equal route "/404.html")))

(defun systemhalted--large-image-twitter-card-p (route)
  "Non-nil when ROUTE gets `summary_large_image', matching what live emits
for the home page, `/about/', and its `/pageN/' siblings."
  (or (equal route "/") (equal route "/about/")
      (systemhalted--paginated-route-p route)))

(defun systemhalted--seo-meta-html (record route title bare-title is-post)
  "Return the <title> tag and SEO meta tags for RECORD at ROUTE.
TITLE is the full `<title>' text; BARE-TITLE is the unqualified page name used
for `og:title'/`twitter:title', matching jekyll-seo-tag's own distinction
between a page's title and its site-qualified title."
  (let* ((description (systemhalted--escape-html
                       (systemhalted-record-description record) t))
         (canonical (concat systemhalted-site-url route))
         (image (systemhalted--escape-html (systemhalted--page-image-url record) t))
         (bare (systemhalted--escape-html bare-title t)))
    (concat
     "<title>" (systemhalted--escape-html title) "</title>"
     "<meta name=\"generator\" content=\"" systemhalted-generator "\">"
     "<meta property=\"og:title\" content=\"" bare "\">"
     "<meta name=\"author\" content=\"" systemhalted-site-author "\">"
     "<meta property=\"og:locale\" content=\"en_US\">"
     "<meta name=\"description\" content=\"" description "\">"
     "<meta property=\"og:description\" content=\"" description "\">"
     "<link rel=\"canonical\" href=\"" canonical "\">"
     "<meta property=\"og:url\" content=\"" canonical "\">"
     "<meta property=\"og:site_name\" content=\"" systemhalted-site-title "\">"
     "<meta property=\"og:image\" content=\"" image "\">"
     (if is-post
         (concat "<meta property=\"og:type\" content=\"article\">"
                 "<meta property=\"article:published_time\" content=\""
                 (systemhalted--iso-datetime (systemhalted-record-date record)) "\">")
       "<meta property=\"og:type\" content=\"website\">")
     "<meta name=\"twitter:card\" content=\""
     (if (systemhalted--large-image-twitter-card-p route) "summary_large_image" "summary")
     "\">"
     "<meta property=\"twitter:image\" content=\"" image "\">"
     "<meta property=\"twitter:title\" content=\"" bare "\">"
     "<meta name=\"google-site-verification\" content=\""
     systemhalted-google-site-verification "\">")))

(defun systemhalted-render-page (record &optional records body full-title bare-title)
  "Render complete HTML for RECORD, using RECORDS for cross-page relationships.
FULL-TITLE and BARE-TITLE override the computed `<title>' text and the bare
page name used for `og:title'/`twitter:title'. Only the home page and its
`/pageN/' siblings need them, since their title is not simply
\"<page title> | SystemHalted.in\"."
  (let* ((records (or records (list record)))
         (body (or body (systemhalted-export-body record records)))
         (kind (systemhalted-record-kind record))
         (route (systemhalted-record-route record))
         (content
          (cond
           ((memq kind '(post draft)) (systemhalted--render-post record records body))
           ((eq kind 'emacs)
            (format (concat "<article class=\"emacs-note\"><header class=\"emacs-note-header\">"
                            "<p class=\"newsletter-kicker\">Emacs note</p><h1 class=\"newsletter-title\">%s</h1>"
                            "</header><div class=\"post-content\">%s%s</div>%s</article>")
                    (systemhalted--escape-html (systemhalted-record-title record))
                    (or (and (systemhalted-record-toc record)
                             (systemhalted--toc body)) "") body
                    (or (systemhalted--emacs-note-tags-html
                         (systemhalted-record-tags record)
                         (systemhalted--tags-page-ids (systemhalted--post-records records)))
                        "")))
           ;; The home page, its `/pageN/' siblings, and `/webcmd/' render
           ;; straight into base.html's <main>, matching live: no page.html
           ;; wrapper and no stray page-title h1 duplicating their own headers.
           ((systemhalted--bare-main-route-p route) body)
           (t (systemhalted--template
               "page.html"
               `((?h . ,(if (systemhalted-record-hide-title record)
                            ""
                          (format "<h1 class=\"page-title%s\">%s</h1>"
                                  (if (systemhalted-record-quiet-title record)
                                      " page-title-quiet" "")
                                  (systemhalted--escape-html
                                   (systemhalted-record-title record)))))
                 (?c . ,body))))))
         (is-post (memq kind '(post draft)))
         (bare-title (or bare-title (systemhalted-record-title record)))
         (title (or full-title (format "%s | %s" bare-title systemhalted-site-title)))
         (current " aria-current=\"page\""))
    (systemhalted--template
     "base.html"
     `((?r . ,(if (systemhalted--noindex-route-p route)
                  "<meta name=\"robots\" content=\"noindex,follow\">" ""))
       (?s . ,systemhalted--asset-version)
       (?y . ,systemhalted--footer-year)
       (?p . ,(if (equal route "/projects/")
                  (format "<link rel=\"stylesheet\" href=\"/assets/css/projects.css?v=%s\">"
                          systemhalted--asset-version)
                ""))
       (?M . ,(or (systemhalted--mermaid-head-html record) ""))
       (?g . ,(systemhalted--analytics-html))
       (?h . ,(systemhalted--seo-meta-html record route title bare-title is-post))
       (?j . ,(systemhalted--structured-data record))
       (?w . ,(if (equal route "/") current ""))
       (?P . ,(if (equal route "/projects/") current ""))
       (?A . ,(if (equal route "/archives/") current ""))
       (?o . ,(if (equal route "/about/") current ""))
       (?W . ,(if (equal route "/webcmd/")
                  (format (concat "<script src=\"/assets/js/elasticlunr.min.js\"></script>"
                                  "<script src=\"/assets/js/webcmd.js?v=%s\"></script>")
                          systemhalted--asset-version)
                ""))
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

(defun systemhalted--synthetic-page (title description route
                                            &optional quiet-title hide-title)
  "Create a generated page record with TITLE, DESCRIPTION, and ROUTE.
QUIET-TITLE and HIDE-TITLE set the page's title display, the code-side
equivalent of the `#+QUIET_TITLE'/`#+HIDE_TITLE' keywords used by
Org-authored pages."
  (make-systemhalted-record
   :source "<generated>" :kind 'page :title title :description description
   :route route :categories nil :tags nil
   :quiet-title quiet-title :hide-title hide-title))

(defun systemhalted--render-generated-page (title description route body
                                                   &optional full-title bare-title
                                                   quiet-title hide-title)
  "Render a generated page from TITLE, DESCRIPTION, ROUTE, and BODY.
FULL-TITLE and BARE-TITLE are forwarded to `systemhalted-render-page'.
QUIET-TITLE and HIDE-TITLE are forwarded to `systemhalted--synthetic-page'."
  (systemhalted-render-page
   (systemhalted--synthetic-page title description route quiet-title hide-title)
   nil body full-title bare-title))

(defun systemhalted--post-list (posts &optional descriptions)
  "Render POSTS as a dated writing list, including DESCRIPTIONS when non-nil."
  (concat
   "<ol class=\"writing-list\">"
   (mapconcat
    (lambda (post)
      (format (concat "<li class=\"writing-row\"><time datetime=\"%s\">%s</time>"
                      "<div class=\"writing-row-body\"><a href=\"%s\">%s</a>%s</div></li>")
              (systemhalted--iso-datetime (systemhalted-record-date post))
              (format-time-string (if descriptions "%b %d" "%b %d, %Y")
                                  (systemhalted-record-date post) t)
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

(defconst systemhalted--home-recent-posts-marker "<!--RECENT_POSTS-->"
  "Marker inside `org/pages/index.org's exported body where
`systemhalted--home-page-body' splices in the computed \"Recent writing\"
section. This lets the author edit the hand-written intro and Kartavya Path
blurb in Org while the generator keeps ownership of the computed post list.")

(defun systemhalted--home-page-body (records recent-section)
  "Return the home page's page-1 body, with RECENT-SECTION as its computed
\"Recent writing\" section.
When RECORDS include an Org page claiming route \"/\" (`org/pages/index.org'
in production), that page's exported body supplies the hand-written intro and
Kartavya Path sections, and RECENT-SECTION is spliced in at its
`systemhalted--home-recent-posts-marker'. Otherwise (e.g. a test build with no
`org/pages' directory) a built-in intro is used and no Kartavya section is
added."
  (let ((home-record (systemhalted--record-route-present-p "/" records)))
    (if home-record
        (let* ((shell (systemhalted-export-body home-record records))
               (pos (string-search systemhalted--home-recent-posts-marker shell)))
          (unless pos
            (systemhalted--source-error
             (systemhalted-record-source home-record)
             "missing %s marker for the computed recent-posts list"
             systemhalted--home-recent-posts-marker))
          (concat (substring shell 0 pos) recent-section
                  (substring shell (+ pos (length systemhalted--home-recent-posts-marker)))))
      (concat
       "<header class=\"home-intro\"><h1><a href=\"https://palakmathur.in\" rel=\"me\">Palak Mathur</a></h1>"
       "<p>Software engineering, computing systems, leadership, and things I am trying to understand.</p></header>"
       recent-section))))

(defun systemhalted--generate-home (root posts records)
  "Generate home pagination below ROOT for POSTS.
RECORDS locates the Org page claiming route \"/\" for page 1's hand-written
sections; see `systemhalted--home-page-body'."
  (let* ((chunks (or (systemhalted--chunks posts systemhalted-page-size)
                     (list nil)))
         (total (length chunks))
         (home-title (format "%s | %s" systemhalted-site-title systemhalted-site-description))
         (page 1))
    (dolist (chunk chunks)
      (let* ((route (if (= page 1) "/" (format "/page%d/" page)))
             (full-title (if (= page 1) home-title
                           (format "Page %d of %d for %s" page total home-title)))
             (body
              (if (= page 1)
                  (systemhalted--home-page-body
                   records
                   (concat
                    "<section class=\"home-section\" aria-labelledby=\"recent-writing\"><h2 id=\"recent-writing\">Recent writing</h2>"
                    (systemhalted--post-list chunk t)
                    "<p class=\"section-link\"><a href=\"/archives/\">All writing →</a></p></section>"))
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
          systemhalted-site-description route body
          full-title systemhalted-site-title)))
      (setq page (1+ page)))))

(defun systemhalted--archive-list (posts)
  "Render POSTS as archive rows."
  (concat
   "<ol class=\"archive-list\">"
   (mapconcat
    (lambda (post)
      (format "<li class=\"archive-row\"><time datetime=\"%s\">%s</time><a href=\"%s\">%s</a></li>"
              (systemhalted--iso-datetime (systemhalted-record-date post))
              (format-time-string "%b %d" (systemhalted-record-date post) t)
              (systemhalted-record-route post)
              (systemhalted--escape-html (systemhalted-record-title post))))
    posts "")
   "</ol>"))

(defun systemhalted--archive-gateways (current)
  "Render the archive/categories/tags/emacs gateway nav, marking CURRENT
section's own link `aria-current=\"page\"' instead of always Archive."
  (cl-flet ((gateway-link
             (route label)
             (format "<a href=\"%s\"%s>%s</a>" route
                     (if (equal label current) " aria-current=\"page\"" "")
                     label)))
    (concat "<nav class=\"archive-gateways\" aria-label=\"Browse the archive\">"
            (gateway-link "/archives/" "Archive")
            "<button class=\"text-button search-open-trigger\" type=\"button\">Search</button>"
            (gateway-link "/categories/" "Categories")
            (gateway-link "/tags/" "Tags")
            "<a href=\"/categories/#series\">Series</a>"
            (gateway-link "/emacs/" "Emacs")
            "</nav>")))

(defun systemhalted--generate-archive (root posts)
  "Generate chronological archive below ROOT from POSTS."
  (let ((groups (make-hash-table :test #'equal)))
    (dolist (post posts)
      (push post (gethash (format-time-string "%Y" (systemhalted-record-date post) t) groups)))
    (let ((years (sort (hash-table-keys groups) #'string>)))
      (systemhalted--write-route
       root "/archives/"
       (systemhalted--render-generated-page
        "Archive" "A chronological archive of SystemHalted writing." "/archives/"
        (concat
         (format "<p class=\"archive-intro\">%d articles written since %s. Browse chronologically or by subject.</p>"
                 (length posts) (if posts
                                    (format-time-string "%Y" (systemhalted-record-date (car (last posts))) t)
                                  ""))
         (systemhalted--archive-gateways "Archive")
         "<div class=\"archive-controls\"><label for=\"archive-sort\">Sort</label>"
         "<select id=\"archive-sort\" class=\"archive-sort\">"
         "<option value=\"year-desc\" selected>Newest first</option>"
         "<option value=\"year-asc\">Oldest first</option>"
         "<option value=\"count-desc\">Most writing</option>"
         "<option value=\"count-asc\">Least writing</option></select></div>"
         "<div id=\"archive-years\">"
         (mapconcat
          (lambda (year)
            (let ((items (nreverse (gethash year groups))))
              (format (concat "<details class=\"archive-year\" data-year=\"%s\" data-count=\"%d\"%s>"
                              "<summary class=\"archive-year-summary\"><span class=\"archive-year-title\">%s</span>"
                              "<span class=\"archive-year-count\">%d articles</span></summary>%s</details>")
                      year (length items) (if (equal year (car years)) " open" "")
                      year (length items)
                      (systemhalted--archive-list items))))
          years "")
         "</div>")
        nil nil t)))))

(defun systemhalted--group-records (records accessor)
  "Group RECORDS by every value returned by ACCESSOR."
  (let ((groups (make-hash-table :test #'equal)))
    (dolist (record records)
      (dolist (value (funcall accessor record))
        (push record (gethash value groups))))
    groups))

(defun systemhalted--read-taxonomy (source-root)
  "Read SOURCE-ROOT's `org/data/taxonomy.org', mirroring
`main:_data/taxonomy.yml'. Returns a plist:
- :THEMES -- an ordered list of theme plists, one per that file's `themes:'
  entry, each a plist of :ID, :TITLE, :DESCRIPTION, and :CATEGORIES (itself
  an ordered list of (:NAME :DESCRIPTION) category plists, in taxonomy
  order). A theme's :ID comes from a `:CUSTOM_ID:' property on its level-1
  headline, matching the live `h2 id=' anchors on `/categories/'.
- :TAGS -- an ordered list of (GROUP-TITLE . TAG-NAMES) pairs mirroring
  that file's `tags:' reference list. This is a canonical list for content
  authors, exactly as on main: no generator reads it back, since `/tags/'
  is built directly from posts' own tags.
Returns nil when the file is missing.

`systemhalted--taxonomy-category-siblings' is the entry point for looking
up a category's theme-mates from the :THEMES list this returns."
  (let ((file (expand-file-name "org/data/taxonomy.org" source-root))
        (section 'themes)
        in-drawer
        themes theme-id theme-title theme-description categories
        category-name category-description
        tag-groups tag-group-title tag-group-tags)
    (cl-flet* ((flush-category
                ()
                (when category-name
                  (push (list :name category-name :description category-description)
                        categories))
                (setq category-name nil category-description nil))
               (flush-theme
                ()
                (flush-category)
                (when theme-title
                  (push (list :id theme-id :title theme-title
                              :description theme-description
                              :categories (nreverse categories))
                        themes))
                (setq theme-id nil theme-title nil theme-description nil categories nil))
               (flush-tag-group
                ()
                (when tag-group-title
                  (push (cons tag-group-title tag-group-tags) tag-groups))
                (setq tag-group-title nil tag-group-tags nil)))
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (string-trim-right
                         (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position)))))
              (cond
               ((equal line "* Tags") (flush-theme) (setq section 'tags))
               ((and (eq section 'themes) (string-match "\\`\\* \\(.+\\)\\'" line))
                (flush-theme)
                (setq theme-title (match-string 1 line)))
               ((and (eq section 'themes) (string-match "\\`\\*\\* \\(.+\\)\\'" line))
                (flush-category)
                (setq category-name (match-string 1 line)))
               ((equal line ":PROPERTIES:") (setq in-drawer t))
               ((equal line ":END:") (setq in-drawer nil))
               ((and in-drawer (string-match "\\`:CUSTOM_ID: +\\(.+\\)\\'" line))
                (setq theme-id (match-string 1 line)))
               ((and (eq section 'tags) (string-match "\\`\\*\\* \\(.+\\)\\'" line))
                (flush-tag-group)
                (setq tag-group-title (match-string 1 line)))
               ((and (eq section 'tags) tag-group-title (not tag-group-tags)
                     (not (string-empty-p (string-trim line))))
                (setq tag-group-tags
                      (mapcar #'string-trim (split-string line "," t "[ \t]+"))))
               ((and (eq section 'themes) (not in-drawer)
                     (not (string-empty-p (string-trim line))))
                (if category-name
                    (unless category-description
                      (setq category-description (string-trim line)))
                  (when theme-title
                    (unless theme-description
                      (setq theme-description (string-trim line))))))))
            (forward-line 1))
          (flush-theme)
          (flush-tag-group))))
    (list :themes (nreverse themes) :tags (nreverse tag-groups))))

(defun systemhalted--taxonomy-category-theme (themes category-name)
  "Return the theme plist in THEMES (as returned under :THEMES by
`systemhalted--read-taxonomy') that lists CATEGORY-NAME among its
:CATEGORIES, or nil when no theme claims it."
  (seq-find (lambda (theme)
              (seq-find (lambda (category)
                          (equal (plist-get category :name) category-name))
                        (plist-get theme :categories)))
            themes))

(defun systemhalted--taxonomy-category-siblings (themes category-name)
  "Return the names of every category sharing a theme with CATEGORY-NAME in
THEMES (as returned under :THEMES by `systemhalted--read-taxonomy'),
CATEGORY-NAME included, in taxonomy order. Return nil when CATEGORY-NAME
belongs to no theme."
  (let ((theme (systemhalted--taxonomy-category-theme themes category-name)))
    (when theme
      (mapcar (lambda (category) (plist-get category :name))
              (plist-get theme :categories)))))

(defun systemhalted--taxonomy-details-html (id name items)
  "Render a `taxonomy-group' details block anchored at ID and titled NAME,
listing ITEMS (records, any order) sorted newest first. Shared by
`systemhalted--taxonomy-category-html' (categories) and
`systemhalted--generate-tags' (tags) so their identical markup shape cannot
drift apart."
  (let ((sorted (sort (copy-sequence items)
                       (lambda (left right)
                         (time-less-p (systemhalted-record-date right)
                                      (systemhalted-record-date left))))))
    (format (concat "<details id=\"%s\" class=\"archive-year taxonomy-group\">"
                    "<summary class=\"archive-year-summary\"><span class=\"archive-year-title\">%s</span>"
                    "<span class=\"archive-year-count\">%d articles</span></summary>%s</details>")
            id (systemhalted--escape-html name) (length sorted)
            (systemhalted--archive-list sorted))))

(defun systemhalted--taxonomy-category-html (name groups)
  "Render an `archive-year' details block for category NAME, or nil when
GROUPS (as built by `systemhalted--group-records') has no posts for it."
  (let ((items (gethash name groups)))
    (when items
      (systemhalted--taxonomy-details-html
       (concat "cat-" (systemhalted--slugify name)) name items))))

(defun systemhalted--taxonomy-theme-section-html (theme groups)
  "Render a `taxonomy-section' for THEME (a plist as found under :THEMES in
`systemhalted--read-taxonomy''s result), or nil when none of its categories
have posts in GROUPS, matching `main:categories.html''s
`{% if total_posts > 0 %}' guard."
  (let ((category-html
         (delq nil (mapcar (lambda (category)
                             (systemhalted--taxonomy-category-html
                              (plist-get category :name) groups))
                           (plist-get theme :categories)))))
    (when category-html
      (format (concat "<section class=\"taxonomy-section\" aria-labelledby=\"%s\">"
                      "<h2 id=\"%s\">%s</h2>%s</section>")
              (plist-get theme :id) (plist-get theme :id)
              (systemhalted--escape-html (plist-get theme :title))
              (mapconcat #'identity category-html "")))))

(defun systemhalted--generate-categories (root posts source-root)
  "Generate `/categories/' below ROOT from POSTS, matching
`main:categories.html'. Categories are grouped by SOURCE-ROOT's
`org/data/taxonomy.org' themes (`systemhalted--read-taxonomy'), in theme
and category order; a theme section is omitted when none of its
categories have posts, and a category with posts that names no theme is
listed under \"Other categories\", sorted by name for determinism (main's
own order there follows Ruby hash-iteration order, which is not a
guarantee this build can reproduce byte-for-byte)."
  (let* ((themes (plist-get (systemhalted--read-taxonomy source-root) :themes))
         (groups (systemhalted--group-records posts #'systemhalted-record-categories))
         (theme-category-names
          (delete-dups
           (apply #'append
                  (mapcar (lambda (theme)
                            (mapcar (lambda (category) (plist-get category :name))
                                    (plist-get theme :categories)))
                          themes))))
         (theme-sections
          (delq nil (mapcar (lambda (theme)
                             (systemhalted--taxonomy-theme-section-html theme groups))
                            themes)))
         (other-names (sort (seq-remove (lambda (name) (member name theme-category-names))
                                        (hash-table-keys groups))
                            #'string-lessp))
         (other-section
          (when other-names
            (format (concat "<section class=\"taxonomy-section\" aria-labelledby=\"other-categories\">"
                            "<h2 id=\"other-categories\">Other categories</h2>%s</section>")
                    (mapconcat (lambda (name)
                                (systemhalted--taxonomy-category-html name groups))
                               other-names "")))))
    (systemhalted--write-route
     root "/categories/"
     (systemhalted--render-generated-page
      "Categories" "An archive of posts sorted by category." "/categories/"
      (concat "<p class=\"archive-intro\">Browse the archive through the recurring subjects and series in the writing.</p>"
              (systemhalted--archive-gateways "Categories")
              (mapconcat #'identity theme-sections "")
              (or other-section ""))
      nil nil t))))

(defun systemhalted--tag-ids (names)
  "Return NAMES (already sorted the way `site.tags | sort' would sort them)
paired with their `/tags/' anchor ids. Matches `main:tags.html': ids are
`slugify'd tag names, and when two different tags in NAMES slugify to the
same value, every id after the first gets a `--N' suffix, where N is that
tag's 1-based position in NAMES -- exactly what Liquid's `forloop.index'
contributes in the live template."
  (let ((seen (make-hash-table :test #'equal))
        (index 0)
        result)
    (dolist (name names)
      (setq index (1+ index))
      (let ((slug (systemhalted--slugify name)))
        (push (cons name
                    (if (gethash slug seen)
                        (format "%s--%d" slug index)
                      (puthash slug t seen)
                      slug))
              result)))
    (nreverse result)))

(defun systemhalted--tags-page-ids (posts)
  "Return an alist of (TAG-NAME . ANCHOR-ID) for every tag `/tags/' renders
from POSTS, matching `systemhalted--generate-tags' exactly (posts only --
`site.tags' on main is never populated from the `emacs' collection either)."
  (let* ((groups (systemhalted--group-records posts #'systemhalted-record-tags))
         (names (sort (hash-table-keys groups) #'string-lessp)))
    (systemhalted--tag-ids names)))

(defun systemhalted--emacs-note-tags-html (tags ids)
  "Render TAGS as `/tags/' anchor links using IDS (from
`systemhalted--tags-page-ids'), matching `main:_layouts/emacs.html's
`div.post-tags'. A tag absent from IDS (no post shares it, so `/tags/' never
renders an anchor for it either) falls back to a plain slug -- the same dead
anchor live's own `{{ tag | slugify }}' produces in that case."
  (when tags
    (format "<div class=\"post-tags\">%s</div>"
            (mapconcat
             (lambda (tag)
               (format "<a href=\"/tags/#%s\">%s</a>"
                       (or (cdr (assoc tag ids)) (systemhalted--slugify tag))
                       (systemhalted--escape-html tag)))
             tags "&nbsp;"))))

(defun systemhalted--generate-tags (root posts)
  "Generate `/tags/' below ROOT from POSTS, matching `main:tags.html'."
  (let* ((groups (systemhalted--group-records posts #'systemhalted-record-tags))
         (ids (systemhalted--tags-page-ids posts)))
    (systemhalted--write-route
     root "/tags/"
     (systemhalted--render-generated-page
      "Tags" "An archive of posts sorted by tag." "/tags/"
      (concat "<p class=\"archive-intro\">A more granular index of topics across the archive.</p>"
              (systemhalted--archive-gateways "Tags")
              "<div class=\"tag-groups\">"
              (mapconcat
               (lambda (pair)
                 (systemhalted--taxonomy-details-html
                  (cdr pair) (car pair) (gethash (car pair) groups)))
               ids "")
              "</div>")
      nil nil t))))

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
      ;; main's `emacs.html' sets no `description:' front matter, so
      ;; jekyll-seo-tag falls back to the site-wide description.
      "Emacs" systemhalted-site-description "/emacs/"
      (concat "<p class=\"archive-intro\">A small wiki of Emacs notes, configurations, and packages I keep coming back to.</p>"
              (systemhalted--archive-gateways "Emacs")
              "<ul class=\"post-feed\">"
              (mapconcat #'systemhalted--emacs-list-item notes "")
              "</ul>")
      nil nil t))))

(defun systemhalted--generate-default-pages (root records)
  "Generate required landing pages below ROOT when RECORDS do not define them."
  (dolist (definition
           '(("/about/" "About" "About Palak Mathur." "<p>Software engineer and writer.</p>")
             ("/projects/" "Projects" "Projects by Palak Mathur." "<p class=\"projects-intro\">Software, tools, and experiments I build.</p>")))
    (unless (systemhalted--record-route-present-p (car definition) records)
      (systemhalted--write-route
       root (car definition)
       (systemhalted--render-generated-page
        (nth 1 definition) (nth 2 definition) (car definition) (nth 3 definition))))))

(defun systemhalted--xml-escape (value)
  "Escape VALUE for XML text and attributes."
  (systemhalted--escape-html value t))

(defun systemhalted--cdata-escape (html)
  "Return HTML safe to embed in an XML CDATA section, splitting any literal
`]]>' so it cannot terminate the section early."
  (replace-regexp-in-string "]]>" "]]]]><![CDATA[>" html))

(defun systemhalted--generate-feed (root posts records)
  "Generate RSS feed below ROOT from POSTS, resolving cross-page links in
each post's body against RECORDS."
  (systemhalted--write-route
   root "/feed.xml"
   (concat
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" "
    "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
    "xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"><channel>"
    "<title>SystemHalted.in</title><link>https://systemhalted.in/</link><description>"
    (systemhalted--xml-escape systemhalted-site-description) "</description>"
    "<atom:link href=\"" systemhalted-site-url
    "/feed.xml\" rel=\"self\" type=\"application/rss+xml\" />"
    (mapconcat
     (lambda (post)
       (format (concat "<item><title>%s</title><link>%s%s</link><guid>%s%s</guid>"
                       "<pubDate>%s</pubDate><description>%s</description>%s"
                       "<dc:creator>%s</dc:creator>"
                       "<content:encoded><![CDATA[%s]]></content:encoded></item>")
               (systemhalted--xml-escape (systemhalted-record-title post))
               systemhalted-site-url (systemhalted-record-route post)
               systemhalted-site-url (systemhalted-record-route post)
               (format-time-string "%a, %d %b %Y %H:%M:%S %z"
                                   (systemhalted-record-date post) t)
               (systemhalted--xml-escape (systemhalted-record-description post))
               (mapconcat (lambda (category)
                            (format "<category>%s</category>"
                                    (systemhalted--xml-escape category)))
                          (systemhalted-record-categories post) "")
               (systemhalted--xml-escape systemhalted-site-author)
               (systemhalted--cdata-escape
                (systemhalted-export-body post records))))
     (seq-take posts 50) "")
    "</channel></rss>")))

(defun systemhalted--generate-links-jsonp (root posts)
  "Generate links.jsonp below ROOT from POSTS, matching main's `callback(...)'
JSONP shape and reverse-chronological order."
  (systemhalted--write-route
   root "/links.jsonp"
   (concat
    "callback("
    (json-serialize
     (vconcat
      (mapcar
       (lambda (post)
         `((text . ,(systemhalted-record-title post))
           (href . ,(concat systemhalted-site-url (systemhalted-record-route post)))))
       posts)))
    ")")))

(defun systemhalted--generated-routes (posts records)
  "Return generated routes for POSTS and RECORDS."
  (append '("/" "/archives/" "/categories/" "/tags/" "/emacs/" "/jsgames/"
            "/about/" "/projects/" "/themes/" "/webcmd/" "/kartavya-path/")
          (let ((pages (length (systemhalted--chunks posts systemhalted-page-size))) routes)
            (dotimes (index (max 0 (1- pages)))
              (push (format "/page%d/" (+ index 2)) routes))
            routes)
          (mapcar #'systemhalted-record-route records)))

(defun systemhalted--record-lastmod (record)
  "Return an ISO 8601 UTC lastmod string for RECORD's sitemap entry, or nil.
Uses RECORD's own date when present, otherwise its LAST_MODIFIED keyword;
returns nil for a plain page with neither, matching live, which omits
`<lastmod>' for such undated pages."
  (let ((date (systemhalted-record-date record)))
    (cond
     (date (systemhalted--iso-datetime date))
     ((systemhalted-record-last-modified record)
      (systemhalted--iso-datetime
       (systemhalted--parse-date (systemhalted-record-source record)
                                  (systemhalted-record-last-modified record))))
     (t nil))))

(defun systemhalted--sitemap-loc (route)
  "Return ROUTE as an absolute sitemap URL, percent-encoding each non-ASCII
path segment the way live's sitemap does, without escaping the `/' between
segments."
  (concat systemhalted-site-url
          (mapconcat #'url-hexify-string (split-string route "/" nil) "/")))

(defun systemhalted--static-sitemap-routes (output-root)
  "Return the jsgames and wireframes static routes below OUTPUT-ROOT that
belong in the sitemap, matching their inclusion in live's, even though they
have no Org record of their own."
  (append
   (let ((games-root (expand-file-name "jsgames" output-root)))
     (when (file-directory-p games-root)
       (sort
        (delq nil
              (mapcar
               (lambda (entry)
                 (and (file-directory-p entry)
                      (file-exists-p (expand-file-name "index.html" entry))
                      (format "/jsgames/%s/" (file-name-nondirectory entry))))
               (directory-files games-root t directory-files-no-dot-files-regexp)))
        #'string-lessp)))
   (let ((wireframes-root (expand-file-name "wireframes" output-root)))
     (when (file-directory-p wireframes-root)
       (sort
        (mapcar (lambda (file) (concat "/wireframes/" (file-name-nondirectory file)))
                (directory-files wireframes-root nil "\\.html\\'"))
        #'string-lessp)))))

(defun systemhalted--sitemap-entries (posts records output-root)
  "Return (ROUTE . LASTMOD) sitemap entries for POSTS and RECORDS, excluding
the 404 page and legacy redirect stubs, and including the static jsgames and
wireframes routes below OUTPUT-ROOT."
  (let ((excluded (cons "/404.html" (mapcar #'car systemhalted-legacy-redirects)))
        (lastmod (make-hash-table :test #'equal)))
    (dolist (record records)
      (let ((entry (systemhalted--record-lastmod record)))
        (when entry (puthash (systemhalted-record-route record) entry lastmod))))
    (append
     (mapcar (lambda (route) (cons route (gethash route lastmod)))
             (seq-remove (lambda (route) (member route excluded))
                         (systemhalted--generated-routes posts records)))
     (mapcar (lambda (route) (cons route nil))
             (systemhalted--static-sitemap-routes output-root)))))

(defun systemhalted--generate-sitemap (root entries)
  "Generate sitemap below ROOT from ENTRIES, each a (ROUTE . LASTMOD-OR-NIL)
pair."
  (let ((unique (make-hash-table :test #'equal)) ordered)
    (dolist (entry entries)
      (unless (gethash (car entry) unique)
        (puthash (car entry) t unique)
        (push entry ordered)))
    (setq ordered (sort (nreverse ordered)
                        (lambda (a b) (string-lessp (car a) (car b)))))
    (systemhalted--write-route
     root "/sitemap.xml"
     (concat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
             "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
             (mapconcat
              (lambda (entry)
                (format "<url><loc>%s</loc>%s</url>"
                        (systemhalted--sitemap-loc (car entry))
                        (if (cdr entry)
                            (format "<lastmod>%s</lastmod>" (cdr entry))
                          "")))
              ordered "")
             "</urlset>"))))

(defun systemhalted--generate-robots (root)
  "Generate robots.txt below ROOT, matching live's file from the
jekyll-sitemap gem."
  (systemhalted--write-route
   root "/robots.txt"
   (concat "Sitemap: " systemhalted-site-url "/sitemap.xml\n")))

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

(defun systemhalted--read-jsgames (source-root)
  "Parse SOURCE-ROOT's `org/data/jsgames.org' into an ordered list of plists
(:title :url :description), mirroring `main:_data/jsgames.yml'. A level-1
headline `* [[URL][TITLE]]' opens each entry; its first non-blank paragraph
line is the description. Returns nil when the file is missing."
  (let ((file (expand-file-name "org/data/jsgames.org" source-root))
        games title url description)
    (cl-flet ((flush ()
                (when title
                  (push (list :title title :url url :description description) games))
                (setq title nil url nil description nil)))
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (string-trim-right
                         (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position)))))
              (cond
               ((string-match "\\`\\* \\[\\[\\([^]]+\\)\\]\\[\\([^]]+\\)\\]\\]\\'" line)
                (flush)
                (setq url (match-string 1 line) title (match-string 2 line)))
               ((and title (not description) (not (string-empty-p (string-trim line))))
                (setq description (string-trim line)))))
            (forward-line 1))
          (flush)))
      (nreverse games))))

(defun systemhalted--generate-jsgames-page (root source-root)
  "Generate `/jsgames/' below ROOT from SOURCE-ROOT's `org/data/jsgames.org',
matching `main:jsgames/index.html'."
  (let ((games (systemhalted--read-jsgames source-root))
        (description "Small browser games and interactive experiments built with vanilla JavaScript."))
    (systemhalted--write-route
     root "/jsgames/"
     (systemhalted--render-generated-page
      "JavaScript Games" description "/jsgames/"
      (concat (format "<p class=\"archive-intro\">%s</p>" description)
              "<ul class=\"post-feed jsgame-list\">"
              (mapconcat #'systemhalted--jsgame-list-item games "")
              "</ul>")
      nil nil t))))

(defun systemhalted--read-themes (source-root)
  "Parse SOURCE-ROOT's `org/data/themes.org' into an ordered list of theme
plists (:name :version :description :image :tags :gem :demo :repo
:rubygems), mirroring `main:_data/themes.yml'. Returns nil when the file is
missing."
  (let ((file (expand-file-name "org/data/themes.org" source-root))
        themes name version description image tags gem demo repo rubygems)
    (cl-flet ((flush ()
                (when name
                  (push (list :name name :version version :description description
                              :image image :tags tags :gem gem :demo demo :repo repo
                              :rubygems rubygems)
                        themes))
                (setq name nil version nil description nil image nil
                      tags nil gem nil demo nil repo nil rubygems nil)))
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (string-trim-right
                         (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position)))))
              (cond
               ((string-match "\\`\\* \\(.+\\) v\\([^ ]+\\)\\'" line)
                (flush)
                (setq name (match-string 1 line) version (match-string 2 line)))
               ((string-match "\\`Image: +\\(.+\\)\\'" line)
                (setq image (string-trim (match-string 1 line))))
               ((string-match "\\`Tags: +\\(.+\\)\\'" line)
                (setq tags (mapcar #'string-trim
                                   (split-string (match-string 1 line) "," t "[ \t]+"))))
               ((string-match "\\`Install: +=gem install \\([^= \t]+\\)=\\'" line)
                (setq gem (match-string 1 line)))
               ((string-match "\\[\\[\\([^]]+\\)\\]\\[Live demo\\]\\]" line)
                (setq demo (match-string 1 line))
                (when (string-match "\\[\\[\\([^]]+\\)\\]\\[GitHub\\]\\]" line)
                  (setq repo (match-string 1 line)))
                (when (string-match "\\[\\[\\([^]]+\\)\\]\\[RubyGems\\]\\]" line)
                  (setq rubygems (match-string 1 line))))
               ((and name (not description) (not (string-empty-p (string-trim line))))
                (setq description (string-trim line)))))
            (forward-line 1))
          (flush)))
      (nreverse themes))))

(defun systemhalted--theme-card-html (theme)
  "Render THEME (a plist from `systemhalted--read-themes') as a
`theme-card' <li>, matching `main:themes.html'."
  (let* ((name (systemhalted--escape-html (plist-get theme :name)))
         (name-attr (systemhalted--escape-html (plist-get theme :name) t))
         (demo (systemhalted--escape-html (plist-get theme :demo) t))
         (tags (plist-get theme :tags)))
    (concat
     "<li class=\"theme-card\">"
     (format "<a class=\"theme-shot\" href=\"%s\">" demo)
     (format "<img src=\"%s\" alt=\"Screenshot of the %s Jekyll theme\" loading=\"lazy\"></a>"
             (systemhalted--escape-html (plist-get theme :image) t) name-attr)
     "<div class=\"theme-body\">"
     (format "<h2 class=\"theme-name\">%s <span class=\"theme-version\">v%s</span></h2>"
             name (systemhalted--escape-html (plist-get theme :version)))
     (format "<p class=\"theme-desc\">%s</p>"
             (systemhalted--escape-html (plist-get theme :description)))
     (if tags
         (concat "<ul class=\"theme-tags\">"
                 (mapconcat (lambda (tag) (format "<li>%s</li>" (systemhalted--escape-html tag)))
                            tags "")
                 "</ul>")
       "")
     (format "<p class=\"theme-install\"><code>gem install %s</code></p>"
             (systemhalted--escape-html (plist-get theme :gem)))
     "<p class=\"theme-links\">"
     (format "<a href=\"%s\">Live demo</a>" demo)
     (format "<a href=\"%s\">GitHub</a>" (systemhalted--escape-html (plist-get theme :repo) t))
     (format "<a href=\"%s\">RubyGems</a>" (systemhalted--escape-html (plist-get theme :rubygems) t))
     "</p></div></li>")))

(defconst systemhalted--themes-inline-style
  "<style>
  .theme-gallery {
    list-style: none;
    padding: 0;
    margin: 2rem 0 0;
    display: grid;
    gap: 1.75rem;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  }
  .theme-card {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border);
    border-radius: 14px;
    overflow: hidden;
    background: var(--surface);
    box-shadow: var(--shadow);
  }
  .theme-shot {
    display: block;
    line-height: 0;
    border-bottom: 1px solid var(--border);
  }
  .theme-shot img {
    width: 100%;
    height: auto;
    display: block;
  }
  .theme-body {
    padding: 1.25rem 1.25rem 1.5rem;
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  .theme-name {
    margin: 0 0 .5rem;
    font-family: var(--font-display);
  }
  .theme-version {
    font-family: var(--font-mono);
    font-size: .7em;
    font-weight: 400;
    color: var(--muted);
  }
  .theme-desc {
    margin: 0 0 1rem;
    color: var(--text);
  }
  .theme-tags {
    list-style: none;
    display: flex;
    flex-wrap: wrap;
    gap: .4rem;
    padding: 0;
    margin: 0 0 1rem;
  }
  .theme-tags li {
    font-size: .75rem;
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: .15rem .65rem;
  }
  .theme-install {
    margin: 0 0 1rem;
  }
  .theme-install code {
    display: block;
    background: var(--code-bg);
    color: var(--code-text);
    border: 1px solid var(--code-border);
    border-radius: 8px;
    padding: .5rem .75rem;
    font-family: var(--font-mono);
    font-size: .85rem;
    overflow-x: auto;
  }
  .theme-links {
    margin: auto 0 0;
    display: flex;
    flex-wrap: wrap;
    gap: 1.25rem;
  }
  .theme-links a {
    color: var(--link);
    font-weight: 600;
  }
  .theme-links a:hover {
    color: var(--link-hover);
  }
</style>"
  "The `/themes/' page's inline style block, copied verbatim from
`main:themes.html' (theme-gallery grid and theme-card layout live only on
this page, so they are not part of `assets/css/nord.css').")

(defun systemhalted--generate-themes-page (root source-root)
  "Generate `/themes/' below ROOT from SOURCE-ROOT's `org/data/themes.org',
matching `main:themes.html'."
  (let ((themes (systemhalted--read-themes source-root)))
    (systemhalted--write-route
     root "/themes/"
     (systemhalted--render-generated-page
      ;; main's `themes.html' sets no `description:' front matter, so
      ;; jekyll-seo-tag falls back to the site-wide description.
      "Jekyll Themes" systemhalted-site-description "/themes/"
      (concat
       "<section class=\"newsletter-hero\">"
       "<p class=\"newsletter-kicker\">Open source</p>"
       "<h1 class=\"newsletter-headline\">Jekyll Themes</h1>"
       "<p class=\"newsletter-lede\">Themes I've built and published as Ruby gems"
       " &mdash; including the one this site runs on. Each has a live demo and"
       " installs in one command.</p>"
       "</section>"
       "<ul class=\"theme-gallery\">"
       (mapconcat #'systemhalted--theme-card-html themes "")
       "</ul>"
       systemhalted--themes-inline-style)
      nil nil nil t))))

(defun systemhalted--generate-webcmd-page (root)
  "Generate `/webcmd/' below ROOT, matching `main:webcmd/index.html'. Its
`layout: default' front matter (not `layout: page') means it bypasses
page.html entirely, so its route is treated as a bare-main route
(`systemhalted--bare-main-route-p'); its page-only scripts are added by
`systemhalted-render-page' via base.html's `%W' slot."
  (systemhalted--write-route
   root "/webcmd/"
   (systemhalted--render-generated-page
    "In the beginning was a command line"
    ;; main's `webcmd/index.html' sets no `description:' front matter either.
    systemhalted-site-description
    "/webcmd/"
    (systemhalted--template "webcmd.html" nil))))

(defun systemhalted--newsletter-cta-html (context)
  "Render the newsletter CTA aside for CONTEXT (e.g. \"landing\"), matching
main's `_includes/newsletter-cta.html' with its `_config.yml' `newsletter_cta'
text, now kept in `site-config.el'."
  (concat
   (format "<aside class=\"newsletter-cta newsletter-cta--%s\" id=\"newsletter-cta\">" context)
   (format "<h2 class=\"newsletter-cta-title\">%s</h2>"
           (systemhalted--escape-html systemhalted-newsletter-cta-title))
   (format "<p class=\"newsletter-cta-lede\">%s</p>"
           (systemhalted--escape-html systemhalted-newsletter-cta-lede))
   (format (concat "<a class=\"newsletter-cta-fallback\" href=\"%s\" rel=\"noopener\" target=\"_blank\">"
                   "Subscribe on LinkedIn →</a>")
           (systemhalted--escape-html systemhalted-newsletter-cta-linkedin-url t))
   "<p class=\"newsletter-cta-alt\">Prefer a reader? "
   "<a href=\"/feed.xml\">Follow all writing by RSS</a>.</p>"
   "</aside>"))

(defun systemhalted--post-feed-item-html (meta route title excerpt)
  "Render a `post-feed-item' <li> shared by every `post-feed' list on the
site: META is the rendered `post-feed-meta' block (or \"\" for none), ROUTE
and TITLE (already HTML-safe) link the heading, and EXCERPT (already
HTML-safe, or nil) is the optional summary paragraph. Matches the common
shape of main's `_includes/newsletter-list-item.html', `emacs-list-item.html'
and `jsgame-list-item.html'."
  (format (concat "<li class=\"post-feed-item\">%s"
                  "<h2 class=\"post-feed-title\"><a href=\"%s\">%s</a></h2>%s</li>")
          meta route title
          (if excerpt (format "<p class=\"post-feed-excerpt\">%s</p>" excerpt) "")))

(defun systemhalted--newsletter-list-item (post)
  "Render POST as a `post-feed-item' entry for the Kartavya Path \"Past
issues\" list, matching main's `_includes/newsletter-list-item.html'."
  (systemhalted--post-feed-item-html
   (format (concat "<div class=\"post-feed-meta\">"
                   "<time class=\"post-feed-date\" datetime=\"%s\">%s</time>"
                   "<span class=\"post-feed-sep\" aria-hidden=\"true\">·</span>"
                   "<span class=\"post-feed-cat\">%s</span></div>")
           (systemhalted--iso-datetime (systemhalted-record-date post))
           (format-time-string "%b %-d, %Y" (systemhalted-record-date post) t)
           (systemhalted--escape-html systemhalted-newsletter-cta-title))
   (systemhalted-record-route post)
   (systemhalted--escape-html (systemhalted-record-title post))
   (systemhalted--escape-html (systemhalted-record-description post))))

(defun systemhalted--emacs-list-item (note)
  "Render NOTE as a `post-feed-item' entry for `/emacs/', matching main's
`_includes/emacs-list-item.html'."
  (systemhalted--post-feed-item-html
   "<div class=\"post-feed-meta\"><span class=\"post-feed-cat\">Emacs note</span></div>"
   (systemhalted-record-route note)
   (systemhalted--escape-html (systemhalted-record-title note))
   (systemhalted--escape-html (systemhalted-record-description note))))

(defun systemhalted--jsgame-list-item (game)
  "Render GAME (a plist from `systemhalted--read-jsgames') as a
`post-feed-item' entry for `/jsgames/', matching main's
`_includes/jsgame-list-item.html'."
  (systemhalted--post-feed-item-html
   "<div class=\"post-feed-meta\"><span class=\"post-feed-cat\">JS Game</span></div>"
   (plist-get game :url)
   (systemhalted--escape-html (plist-get game :title))
   (systemhalted--escape-html (plist-get game :description))))

(defun systemhalted--generate-kartavya-path (root posts)
  "Generate the `/kartavya-path/' landing page below ROOT, matching
`main:kartavya-path.html': its hero section, the shared newsletter CTA aside,
and a \"Past issues\" feed of POSTS flagged `#+KARTAVYA_PATH: true'."
  (let ((issues (seq-filter #'systemhalted-record-kartavya-path posts)))
    (systemhalted--write-route
     root "/kartavya-path/"
     (systemhalted--render-generated-page
      "Kartavya Path" systemhalted-site-description "/kartavya-path/"
      (concat
       "<section class=\"newsletter-hero\">"
       (format "<p class=\"newsletter-brand\">%s</p>"
               (systemhalted--escape-html systemhalted-newsletter-cta-title))
       "<p class=\"newsletter-kicker\" lang=\"hi\">कर्तव्य पथ</p>"
       "<h1 class=\"newsletter-headline\">A note on leadership, management, and the long road</h1>"
       "<p class=\"newsletter-lede\">"
       "Kartavya Path means \"the path of duty\" — short essays on leading teams, doing the "
       "harder right thing over the easier wrong one, and the long arc of building anything "
       "that lasts. These essays now publish on the blog, and selected ones are "
       "cross-posted to the LinkedIn newsletter — subscribe there, or follow the blog by "
       "RSS. The issues below remain part of the main writing archive."
       "</p></section>"
       (systemhalted--newsletter-cta-html "landing")
       "<h2 class=\"recent-title\">Past issues</h2>"
       "<ul class=\"post-feed\">"
       (mapconcat #'systemhalted--newsletter-list-item issues "")
       "</ul>")
      nil nil nil t))))

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

(defun systemhalted--compute-asset-version (root)
  "Return a short deterministic cache-busting token for assets below ROOT.
Derived from the contents of assets/css and assets/js, never the wall clock,
so two clean builds of the same sources stay byte-identical."
  (let ((files (sort
                (append
                 (directory-files (expand-file-name "assets/css" root) t "\\.css\\'")
                 (directory-files (expand-file-name "assets/js" root) t "\\.js\\'"))
                #'string-lessp)))
    (substring
     (secure-hash 'sha256 (mapconcat #'systemhalted--read-file files "\0"))
     0 10)))

(defun systemhalted--generate-site (source-root output-root records)
  "Generate the complete site from RECORDS into OUTPUT-ROOT."
  (make-directory output-root t)
  (systemhalted--copy-static source-root output-root)
  (let* ((posts (systemhalted--post-records
                (seq-remove #'systemhalted-record-draft records)))
         (systemhalted--asset-version (systemhalted--compute-asset-version source-root))
         (systemhalted--source-root source-root)
         (systemhalted--footer-year
          (if posts
              (format-time-string "%Y" (systemhalted-record-date (car posts)) t)
            systemhalted--footer-year)))
    (dolist (record records)
      (systemhalted-write-record record records output-root))
    (systemhalted--generate-home output-root posts records)
    (systemhalted--generate-archive output-root posts)
    (systemhalted--generate-categories output-root posts source-root)
    (systemhalted--generate-tags output-root posts)
    (systemhalted--generate-emacs-index output-root records)
    (systemhalted--generate-default-pages output-root records)
    (systemhalted--generate-feed output-root posts records)
    (systemhalted--generate-links-jsonp output-root posts)
    (systemhalted--generate-search output-root records source-root)
    (systemhalted--generate-jsgames-page output-root source-root)
    (systemhalted--generate-themes-page output-root source-root)
    (systemhalted--generate-webcmd-page output-root)
    (dolist (redirect systemhalted-legacy-redirects)
      (systemhalted--write-route output-root (car redirect)
                                 (systemhalted--redirect-page (cdr redirect))))
    (systemhalted--generate-kartavya-path output-root posts)
    (systemhalted--generate-sitemap
     output-root (systemhalted--sitemap-entries posts records output-root))
    (systemhalted--generate-robots output-root)))

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
  "Signal when an HTML file below ROOT has a `file:' URL or a missing local target."
  (dolist (file (directory-files-recursively root "\\.html\\'"))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward "\\(?:href\\|src\\)=\"\\([^\"#?]*\\)" nil t)
        (let ((url (match-string-no-properties 1)))
          (cond
           ((string-prefix-p "file:" url)
            (signal 'systemhalted-publish-error
                    (list (format "%s: file: URL %s" file url))))
           ((string-prefix-p "/" url)
            (unless (file-exists-p (systemhalted--local-target-file root url))
              (signal 'systemhalted-publish-error
                      (list (format "%s: broken local target %s" file url)))))))))))

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
