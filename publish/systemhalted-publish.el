;;; systemhalted-publish.el --- Org-first static site publisher -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Palak Mathur

;;; Commentary:

;; Built-in-Emacs publishing support for systemhalted.in.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'time-date)

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

(provide 'systemhalted-publish)
;;; systemhalted-publish.el ends here
