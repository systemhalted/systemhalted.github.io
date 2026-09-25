;;; systemhalted-publish-test.el --- Tests for Org site publisher -*- lexical-binding: t; -*-

(require 'ert)
(require 'subr-x)

(defconst systemhalted-test-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name)))))

(add-to-list 'load-path (expand-file-name "publish" systemhalted-test-root))
(ignore-errors (require 'systemhalted-publish))

(defconst systemhalted-test-fixtures
  (expand-file-name "test/fixtures/org" systemhalted-test-root))

(defun systemhalted-test-fixture (name)
  (expand-file-name name systemhalted-test-fixtures))

(defmacro systemhalted-test-with-org (contents &rest body)
  (declare (indent 1))
  `(let ((file (make-temp-file "systemhalted-" nil ".org" ,contents)))
     (unwind-protect (progn ,@body)
       (delete-file file))))

(ert-deftest systemhalted-read-record-requires-title ()
  "Removing TITLE must make an otherwise valid source fail validation."
  (systemhalted-test-with-org
      "#+DESCRIPTION: Missing a title.\n#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n"
    (should-error (systemhalted-read-record file 'post)
                  :type 'user-error)))

(ert-deftest systemhalted-read-record-requires-description ()
  "Removing DESCRIPTION must make an otherwise valid source fail validation."
  (systemhalted-test-with-org
      "#+TITLE: Missing description\n#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n"
    (should-error (systemhalted-read-record file 'post)
                  :type 'user-error)))

(ert-deftest systemhalted-read-record-derives-date-and-route-from-filename ()
  "Changing the dated filename must change the default post date and route."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-25-derived-route.org")
                  'post))
         (date (systemhalted-record-date record)))
    (should (equal (format-time-string "%Y-%m-%d" date t) "2026-09-25"))
    (should (equal (systemhalted-record-route record)
                   "/2026/09/25/derived-route/"))))

(ert-deftest systemhalted-read-record-preserves-explicit-permalink ()
  "Ignoring PERMALINK would move an article from its established URL."
  (let ((record (systemhalted-read-record
                 (systemhalted-test-fixture "2024-07-19-legacy-permalink.org")
                 'post)))
    (should (equal (systemhalted-record-route record)
                   "/newsletter/2024-07-19-legacy-permalink/"))))

(ert-deftest systemhalted-read-record-allows-undated-page-file-route ()
  "Standalone files such as 404.html must not gain a trailing slash."
  (systemhalted-test-with-org
      "#+TITLE: Not found\n#+DESCRIPTION: Missing page.\n#+PERMALINK: /404.html\n"
    (let ((record (systemhalted-read-record file 'page)))
      (should-not (systemhalted-record-date record))
      (should (equal (systemhalted-record-route record) "/404.html")))))

(ert-deftest systemhalted-read-record-normalizes-list-and-boolean-fields ()
  "Failing to split metadata would break taxonomy and optional post features."
  (let ((record (systemhalted-read-record
                 (systemhalted-test-fixture "2026-09-25-derived-route.org")
                 'post)))
    (should (equal (systemhalted-record-categories record)
                   '("Software Engineering" "Emacs")))
    (should (equal (systemhalted-record-tags record)
                   '("org" "publishing")))
    (should (systemhalted-record-comments record))
    (should-not (systemhalted-record-toc record))))

(ert-deftest systemhalted-read-record-keeps-percent-encoded-unicode-route ()
  "Decoding a legacy filename would break its existing public URL."
  (let ((record (systemhalted-read-record
                 (systemhalted-test-fixture
                  "2007-10-05-%e0%a4%9c%e0%a4%bf%e0%a4%82%e0%a4%a6%e0%a4%97%e0%a5%80.org")
                 'post)))
    (should (equal (systemhalted-record-route record)
                   "/2007/10/05/%e0%a4%9c%e0%a4%bf%e0%a4%82%e0%a4%a6%e0%a4%97%e0%a5%80/"))))

(ert-deftest systemhalted-load-records-filters-drafts-and-future-posts ()
  "Production must omit drafts and future posts while preview includes both."
  (let* ((now (encode-time 0 0 12 25 9 2026 t))
         (production (systemhalted-load-records systemhalted-test-fixtures
                                                 :now now))
         (preview (systemhalted-load-records systemhalted-test-fixtures
                                              :now now
                                              :include-drafts t
                                              :include-future t)))
    (should-not (seq-find #'systemhalted-record-draft production))
    (should-not (seq-find #'systemhalted-record-future-p production))
    (should (seq-find #'systemhalted-record-draft preview))
    (should (seq-find #'systemhalted-record-future-p preview))))

(ert-deftest systemhalted-validate-records-rejects-duplicate-routes ()
  "Two sources claiming one route must stop the build instead of overwriting."
  (let* ((first (systemhalted-read-record
                 (systemhalted-test-fixture "2026-09-25-derived-route.org")
                 'post))
         (second (copy-systemhalted-record first)))
    (setf (systemhalted-record-source second) "another-source.org")
    (should-error (systemhalted-validate-records (list first second))
                  :type 'user-error)))

(ert-deftest systemhalted-read-record-rejects-unsafe-route ()
  "A route that escapes the output tree must never reach the writer."
  (systemhalted-test-with-org
      "#+TITLE: Unsafe\n#+DESCRIPTION: Unsafe route.\n#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n#+PERMALINK: /../outside/\n"
    (should-error (systemhalted-read-record file 'post)
                  :type 'user-error)))

(ert-deftest systemhalted-export-body-renders-org-features ()
  "Dropping an Org construct would remove authored content from the page."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (html (systemhalted-export-body record records)))
    (should (string-match-p "<h2[^>]*>Heading &amp; details</h2>" html))
    (should (string-match-p "class=\"language-emacs-lisp\"" html))
    (should (string-match-p "&lt;unsafe&gt;" html))
    (should (string-match-p "Example text" html))
    (should (string-match-p "<table" html))
    (should (string-match-p "<aside class=\"fixture\">Raw HTML</aside>" html))
    (should (string-match-p "class=\"footref\"" html))
    (should (string-match-p
             "href=\"/newsletter/2024-07-19-legacy-permalink/\"" html))))

(ert-deftest systemhalted-export-body-renders-root-relative-link ()
  "A root-relative file link must export as a plain URL, never a file: URI."
  (systemhalted-test-with-org
      (concat "#+TITLE: Root Link\n#+DESCRIPTION: Root-relative link fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "See the [[/jsgames/pig-game/][pig game]].\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote "<a href=\"/jsgames/pig-game/\">pig game</a>")
               html))
      (should-not (string-match-p "file:" html)))))

(ert-deftest systemhalted-export-body-image-without-alt-source-is-never-filename ()
  "An image link with no description, caption, or :alt must not use the file name."
  (systemhalted-test-with-org
      (concat "#+TITLE: Bare Image\n#+DESCRIPTION: Bare image fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "[[/assets/images/bare-figure.svg]]\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                "<img src=\"/assets/images/bare-figure.svg\" alt=\"\">")
               html))
      (should-not (string-match-p "file:" html))
      (should-not (string-match-p "alt=\"bare-figure.svg\"" html)))))

(ert-deftest systemhalted-export-body-uses-image-description-as-alt ()
  "An image link's own description must become its alt text."
  (systemhalted-test-with-org
      (concat "#+TITLE: Described Image\n#+DESCRIPTION: Described image fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "[[/assets/images/cat.png][A cat sitting on a mat]]\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                "<img src=\"/assets/images/cat.png\" alt=\"A cat sitting on a mat\">")
               html)))))

(ert-deftest systemhalted-export-body-uses-caption-as-alt-when-no-description ()
  "A #+CAPTION must supply alt text when the image link has no description."
  (systemhalted-test-with-org
      (concat "#+TITLE: Captioned Image\n#+DESCRIPTION: Captioned image fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+CAPTION: Figure 1 --- a lone caption\n"
              "[[/assets/images/figure.svg]]\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                "<img src=\"/assets/images/figure.svg\" alt=\"Figure 1 --- a lone caption\">")
               html)))))

(ert-deftest systemhalted-export-body-uses-attr-html-alt-as-last-resort ()
  "A #+ATTR_HTML :alt must supply alt text when nothing else is present."
  (systemhalted-test-with-org
      (concat "#+TITLE: Attr Image\n#+DESCRIPTION: Attr image fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+ATTR_HTML: :alt Explicit alt text\n"
              "[[/assets/images/attr.png]]\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                "<img src=\"/assets/images/attr.png\" alt=\"Explicit alt text\">")
               html)))))

(ert-deftest systemhalted-validate-site-rejects-file-url ()
  "A file: URL anywhere in the output must block publication."
  (let ((output (make-temp-file "systemhalted-file-url-site-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "index.html" output)
            (insert "<img src=\"file:///assets/images/x.svg\" alt=\"x\">"))
          (should-error (systemhalted-validate-site output)
                        :type 'systemhalted-publish-error))
      (delete-directory output t))))

(ert-deftest systemhalted-export-body-skips-kill-prompts-for-its-temp-buffer ()
  "Publishing must not run user kill-buffer prompts for its private export buffer."
  (let* ((queried nil)
         (source (systemhalted-test-fixture "2026-09-24-rich-content.org"))
         (buffer-states-at-kill nil)
         (org-mode-hook
          (list (lambda ()
                  (add-hook 'kill-buffer-query-functions
                            (lambda () (setq queried t) t) nil t))))
         (kill-buffer-hook
          (list (lambda ()
                  (when (eq major-mode 'org-mode)
                    (push (list (buffer-name) buffer-file-name (buffer-modified-p))
                          buffer-states-at-kill)))))
         (record (systemhalted-read-record
                  source 'post))
         (records (systemhalted-load-records
                   systemhalted-test-fixtures :include-drafts t :include-future t)))
    (systemhalted-export-body record records)
    (should-not queried)
    (should buffer-states-at-kill)
    (should (seq-every-p (lambda (state) (equal (cdr state) '(nil nil)))
                          buffer-states-at-kill))))

(ert-deftest systemhalted-render-page-includes-post-shell-and-metadata ()
  "Losing shell fragments would break discovery, navigation, and comments."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (html (systemhalted-render-page record records)))
    (should (string-match-p "<title>Rich &amp; Structured · SystemHalted.in</title>" html))
    (should (string-match-p
             "<link rel=\"canonical\" href=\"https://systemhalted.in/2026/09/24/rich-content/\">"
             html))
    (should (string-match-p "class=\"post-toc\"" html))
    (should (string-match-p "src=\"/assets/images/avatar.jpeg\"" html))
    (should (string-match-p "data-repo=\"systemhalted/systemhalted.github.io\"" html))
    (should (string-match-p "Filed under" html))
    (should (string-match-p "Search all writing" html))))

(ert-deftest systemhalted-write-record-uses-route-output-path ()
  "Writing to a slug-only path would break dated and legacy permalinks."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2024-07-19-legacy-permalink.org")
                  'post))
         (records (list record))
         (output (make-temp-file "systemhalted-output-" t)))
    (unwind-protect
        (let ((written (systemhalted-write-record record records output)))
          (should (equal written
                         (expand-file-name
                          "newsletter/2024-07-19-legacy-permalink/index.html"
                          output)))
          (should (file-exists-p written)))
      (delete-directory output t))))

(ert-deftest systemhalted-render-page-ranks-related-and-adjacent-posts ()
  "Changing relationship or chronology rules would alter article discovery."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (record (seq-find
                  (lambda (item)
                    (equal (systemhalted-record-title item) "Rich & Structured"))
                  records))
         (html (systemhalted-render-page record records)))
    (should (string-match-p "Related Publishing Post" html))
    (should (string-match-p "class=\"post-nav" html))
    (should (string-match-p "Newer\\|Older" html))))

(defmacro systemhalted-test-with-built-site (&rest body)
  (declare (indent 0))
  `(let ((output (make-temp-file "systemhalted-site-" t))
         (systemhalted-page-size 3)
         (systemhalted-static-paths
          (remove "wireframes" (copy-sequence systemhalted-static-paths))))
     (unwind-protect
         (progn
           (systemhalted-build-site
            :root systemhalted-test-root
            :output output
            :content-directories
            (list (cons systemhalted-test-fixtures 'post))
            :include-drafts t
            :include-future t)
           ,@body)
       (delete-directory output t))))

(ert-deftest systemhalted-build-site-generates-navigation-and-collections ()
  "Omitting derived routes would strand content after removing Jekyll."
  (systemhalted-test-with-built-site
    (dolist (relative '("index.html" "page2/index.html" "archives/index.html"
                        "categories/index.html" "tags/index.html"
                        "themes/index.html" "projects/index.html"
                        "emacs/index.html" "feed.xml" "sitemap.xml"
                        "assets/js/webcmd.js" "kartavya-path/index.html"))
      (should (file-exists-p (expand-file-name relative output))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "categories/index.html" output))
      (should (search-forward "Software Engineering" nil t)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "tags/index.html" output))
      (should (search-forward "publishing" nil t)))))

(ert-deftest systemhalted-projects-page-preserves-main-structure ()
  "Org project entries must retain the semantic structure and hooks used by the live page."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/projects.org" systemhalted-test-root)
                  'page))
         (html (systemhalted-render-page record)))
    (dolist (fragment
             '("class=\"page-title page-title-quiet\""
               "class=\"projects-intro\""
               "class=\"projects-section\" aria-labelledby=\"available-projects\""
               "class=\"project-list\""
               "class=\"project-item\""
               "class=\"project-name\""
               "class=\"project-description\""
               "class=\"project-meta\""
               "<span>Beta</span><span aria-hidden=\"true\"> · </span><a href=\"https://pinstack.in\">Try the beta</a><span aria-hidden=\"true\"> →</span>"
               "<a href=\"https://github.com/systemhalted/torg/releases\">Install</a><span aria-hidden=\"true\"> · </span><a href=\"https://github.com/systemhalted/torg\">Source</a>"
               "aria-labelledby=\"workshop-projects\""))
      (should (string-match-p (regexp-quote fragment) html)))
    (with-temp-buffer
      (insert html)
      (should (= (how-many "class=\"project-item\"" (point-min) (point-max)) 16)))
    (should-not (string-match-p "file:///" html))))

(ert-deftest systemhalted-archive-preserves-main-controls-and-first-open-year ()
  "Generated archive must retain the controls, gateways, and initial state of the live page."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "archives/index.html" output))
      (let ((html (buffer-string)))
        (dolist (fragment
                 '("class=\"page-title page-title-quiet\""
                   "id=\"archive-sort\""
                   "option value=\"year-desc\" selected"
                   "search-open-trigger"
                   "#series"
                   "class=\"archive-year\" data-year=\"2026\" data-count=\"4\" open"))
          (should (string-match-p (regexp-quote fragment) html)))
        (should (string-match-p
                 "<time datetime=\"2026-09-24T00:00:00[-+][0-9:]+\">Sep 24</time>"
                 html))))))

(ert-deftest systemhalted-build-site-generates-parseable-feed-and-sitemap ()
  "Malformed XML would make readers and crawlers reject the generated site."
  (systemhalted-test-with-built-site
    (dolist (relative '("feed.xml" "sitemap.xml"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name relative output))
        (should (libxml-parse-xml-region (point-min) (point-max)))))))

(ert-deftest systemhalted-build-site-generates-compatible-search-data ()
  "Losing the public search globals would break both site and webcmd search."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "assets/js/webcmd.js" output))
      (should (search-forward "window.siteDocs" nil t))
      (goto-char (point-min))
      (should (search-forward "function ensureSiteIndex" nil t))
      (goto-char (point-min))
      (should (search-forward "Rich & Structured" nil t))
      (goto-char (point-min))
      (should (search-forward "function runcmd" nil t))
      (goto-char (point-min))
      (should (search-forward "function cmd_fortune" nil t))
      (goto-char (point-min))
      (should (search-forward "var osTimeline" nil t))
      (should (search-forward
               "Commodore Amiga & Windows 1.0 both debut" nil t))
      (should (search-forward
               "The cloud era: the OS quietly becomes a fleet" nil t)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "webcmd/index.html" output))
      (should (search-forward "id=\"line\"" nil t))
      (should (search-forward "id=\"output\"" nil t))
      (should (search-forward "src=\"/assets/js/webcmd.js\"" nil t)))))

(ert-deftest systemhalted-build-site-copies-static-assets-and-retired-route ()
  "Dropping source assets or the retired landing redirect would break live URLs."
  (systemhalted-test-with-built-site
    (should (file-exists-p (expand-file-name "assets/css/nord.css" output)))
    (should (file-exists-p (expand-file-name "jsgames/pig-game/script.js" output)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "kartavya-path/index.html" output))
      (should (search-forward "url=/archives/" nil t)))
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "2025/11/25/disjuntive-types/index.html" output))
      (should (search-forward "url=/2025/11/25/disjunctive-types/" nil t)))))

(ert-deftest systemhalted-validate-site-rejects-broken-local-target ()
  "A missing internal target must block publication."
  (let ((output (make-temp-file "systemhalted-invalid-site-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "index.html" output)
            (insert "<a href=\"/missing/\">Missing</a>"))
          (should-error (systemhalted-validate-site output)
                        :type 'systemhalted-publish-error))
      (delete-directory output t))))

(ert-deftest systemhalted-build-site-preserves-last-good-output-on-failure ()
  "A failed staged build must not erase the last successful site."
  (let ((root (make-temp-file "systemhalted-empty-root-" t))
        (output (make-temp-file "systemhalted-existing-output-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "sentinel" output) (insert "last good"))
          (should-error
           (systemhalted-build-site
            :root root
            :output output
            :content-directories (list (cons systemhalted-test-fixtures 'post))
            :include-drafts t
            :include-future t)
           :type 'systemhalted-publish-error)
          (should (file-exists-p (expand-file-name "sentinel" output))))
      (delete-directory root t)
      (delete-directory output t))))

(ert-deftest systemhalted-build-site-is-deterministic ()
  "Changing bytes between identical builds would make deployments irreproducible."
  (let ((first (make-temp-file "systemhalted-first-" t))
        (second (make-temp-file "systemhalted-second-" t))
        (systemhalted-page-size 3)
        (systemhalted-static-paths
         (remove "wireframes" (copy-sequence systemhalted-static-paths))))
    (unwind-protect
        (progn
          (dolist (output (list first second))
            (systemhalted-build-site
             :root systemhalted-test-root
             :output output
             :content-directories (list (cons systemhalted-test-fixtures 'post))
             :include-drafts t
             :include-future t))
          (should (equal (systemhalted-directory-digest first)
                         (systemhalted-directory-digest second))))
      (delete-directory first t)
      (delete-directory second t))))

(ert-deftest systemhalted-audit-content-accepts-only-complete-org-corpus ()
  "Maintained publishing inputs must be complete Org files without Liquid."
  (should (systemhalted-audit-content systemhalted-test-root)))

(ert-deftest systemhalted-production-build-preserves-baseline-routes ()
  "Migrating content must not move or drop established HTML routes."
  (let ((output (make-temp-file "systemhalted-production-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (let ((actual
                 (sort
                  (mapcar
                   (lambda (file)
                     (let ((relative (file-relative-name file output)))
                       (cond
                        ((equal relative "index.html") "/")
                        ((string-suffix-p "/index.html" relative)
                         (concat "/" (string-remove-suffix "index.html" relative)))
                        (t (concat "/" relative)))))
                   (directory-files-recursively output "\\.html\\'"))
                  #'string-lessp))
                expected)
            (with-temp-buffer
              (insert-file-contents
               (expand-file-name "test/baseline/routes.tsv" systemhalted-test-root))
              (goto-char (point-min))
              (forward-line 1)
              (while (not (eobp))
                (let ((route (string-trim
                              (buffer-substring (line-beginning-position)
                                                (line-end-position)))))
                  (unless (string-empty-p route) (push route expected)))
                (forward-line 1)))
            (should (equal actual (sort expected #'string-lessp)))))
      (delete-directory output t))))

(provide 'systemhalted-publish-test)
;;; systemhalted-publish-test.el ends here
