;;; systemhalted-publish-test.el --- Tests for Org site publisher -*- lexical-binding: t; -*-

(require 'cl-lib)
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

(ert-deftest systemhalted-read-record-computes-route-and-date-in-utc ()
  "A DATE with an explicit offset that crosses midnight UTC must shift the
default route to the UTC day and expose the precise UTC instant, matching
Jekyll's behavior on GitHub's UTC build runners."
  (systemhalted-test-with-org
      (concat "#+TITLE: UTC Shift\n#+DESCRIPTION: UTC shift fixture.\n"
              "#+DATE: 2026-09-25 23:30:00 -0500\n#+CATEGORIES: Tests\n#+TAGS: org\n")
    (let* ((record (systemhalted-read-record file 'post))
           (date (systemhalted-record-date record)))
      (should (string-prefix-p "/2026/09/26/" (systemhalted-record-route record)))
      (should (equal (format-time-string "%Y-%m-%dT%H:%M:%S%:z" date t)
                     "2026-09-26T04:30:00+00:00")))))

(ert-deftest systemhalted-read-record-treats-naive-datetime-as-utc ()
  "A DATE with a time but no offset must be treated as already UTC, the way
Jekyll's UTC build runners interpret an unzoned timestamp."
  (systemhalted-test-with-org
      (concat "#+TITLE: Naive Datetime\n#+DESCRIPTION: Naive datetime fixture.\n"
              "#+DATE: 2026-09-25 21:45\n#+CATEGORIES: Tests\n#+TAGS: org\n")
    (let* ((record (systemhalted-read-record file 'post))
           (date (systemhalted-record-date record)))
      (should (string-prefix-p "/2026/09/25/" (systemhalted-record-route record)))
      (should (equal (format-time-string "%Y-%m-%dT%H:%M:%S%:z" date t)
                     "2026-09-25T21:45:00+00:00")))))

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
    (should-not (systemhalted-record-toc record))
    (should-not (systemhalted-record-mermaid record))))

(ert-deftest systemhalted-read-record-parses-mermaid-keyword ()
  "A post must be able to opt into Mermaid support with #+MERMAID: true."
  (systemhalted-test-with-org
      (concat "#+TITLE: Mermaid Opt In\n#+DESCRIPTION: Mermaid keyword fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n"
              "#+MERMAID: true\n")
    (let ((record (systemhalted-read-record file 'post)))
      (should (systemhalted-record-mermaid record)))))

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

(ert-deftest systemhalted-read-record-keeps-quoted-list-item-with-comma ()
  "A double-quoted CATEGORIES/TAGS item must survive as one item even when it
contains a literal comma, instead of being split into multiple items."
  (systemhalted-test-with-org
      (concat "#+TITLE: Quoted List Item\n#+DESCRIPTION: Quoted list fixture.\n"
              "#+DATE: 2026-09-25\n"
              "#+CATEGORIES: Technology, Computer Science, "
              "\"Series 2 - Turtle, BASIC, and the Long Road to Taste\"\n"
              "#+TAGS: \"comma, in, tag\", plain-tag\n")
    (let ((record (systemhalted-read-record file 'post)))
      (should (equal (systemhalted-record-categories record)
                     '("Technology" "Computer Science"
                       "Series 2 - Turtle, BASIC, and the Long Road to Taste")))
      (should (equal (systemhalted-record-tags record)
                     '("comma, in, tag" "plain-tag"))))))

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
    (should (string-match-p "<title>Rich &amp; Structured \\| SystemHalted.in</title>" html))
    (should (string-match-p
             "<link rel=\"canonical\" href=\"https://systemhalted.in/2026/09/24/rich-content/\">"
             html))
    (should (string-match-p
             "<time datetime=\"2026-09-24T00:00:00\\+00:00\">"
             html))
    (should (string-match-p "class=\"post-toc\"" html))
    (should (string-match-p "src=\"/assets/images/avatar.jpeg\"" html))
    (should (string-match-p "data-repo=\"systemhalted/systemhalted.github.io\"" html))
    (should (string-match-p "Filed under" html))
    (should (string-match-p "Search all writing" html))))

(ert-deftest systemhalted-render-page-includes-katex-scripts ()
  "Every page must load KaTeX so inline and display math render like main."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (html (systemhalted-render-page record records)))
    (should (string-match-p
             (regexp-quote
              "<script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/katex.min.js\"")
             html))
    (should (string-match-p
             (regexp-quote
              "https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/contrib/auto-render.min.js")
             html))
    (should (string-match-p "renderMathInElement" html))
    (should (string-match-p (regexp-quote "{ left: '\\\\(', right: '\\\\)', display: false }") html))
    (should (string-match-p (regexp-quote "{ left: '\\\\[', right: '\\\\]', display: true }") html))))

(ert-deftest systemhalted-render-page-omits-mermaid-scripts-by-default ()
  "A page without #+MERMAID: true must not pay for loading mermaid.js."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (html (systemhalted-render-page record records)))
    (should-not (string-match-p "mermaid@10.9.3" html))))

(ert-deftest systemhalted-render-page-includes-mermaid-scripts-when-enabled ()
  "#+MERMAID: true must load mermaid.js and export a convertible block."
  (systemhalted-test-with-org
      (concat "#+TITLE: Mermaid Post\n#+DESCRIPTION: Mermaid rendering fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n"
              "#+MERMAID: true\n\n"
              "#+begin_src mermaid\n"
              "flowchart LR\n"
              "  a --> b\n"
              "#+end_src\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-render-page record (list record))))
      (should (string-match-p
               (regexp-quote
                "<script defer src=\"https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js\"")
               html))
      (should (string-match-p "mermaid.initialize" html))
      (should (string-match-p "class=\"language-mermaid" html))
      (should (string-match-p "flowchart LR" html)))))

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
                 "<time datetime=\"2026-09-24T00:00:00\\+00:00\">Sep 24</time>"
                 html))))))

(ert-deftest systemhalted-build-site-emits-utc-iso-datetime-in-home-and-related-lists ()
  "Home list and related-post rows must carry full UTC ISO datetime attributes,
matching live output, instead of a bare date with no time or offset."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "index.html" output))
      (should (string-match-p
               "<time datetime=\"[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\+00:00\">"
               (buffer-string))))
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "2026/09/24/rich-content/index.html" output))
      (should (string-match-p
               (concat "<time class=\"related-post-date\" "
                       "datetime=\"[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
                       "T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\+00:00\">")
               (buffer-string))))))

(ert-deftest systemhalted-build-site-generates-parseable-feed-and-sitemap ()
  "Malformed XML would make readers and crawlers reject the generated site."
  (systemhalted-test-with-built-site
    (dolist (relative '("feed.xml" "sitemap.xml"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name relative output))
        (should (libxml-parse-xml-region (point-min) (point-max)))))))

;;; Sitemap, robots.txt, links.jsonp and feed (Task 7)

(ert-deftest systemhalted-record-lastmod-prefers-date-over-last-modified ()
  "A dated record's sitemap lastmod must be its own UTC date."
  (let ((record (make-systemhalted-record
                 :source "<test>" :kind 'post
                 :date (encode-time 0 0 0 24 9 2026 t)
                 :last-modified "2026-01-01")))
    (should (equal (systemhalted--record-lastmod record)
                   "2026-09-24T00:00:00+00:00"))))

(ert-deftest systemhalted-record-lastmod-falls-back-to-last-modified-keyword ()
  "An undated record (a page or Emacs note) with LAST_MODIFIED must still get
a sitemap lastmod, matching live's per-page value for such content."
  (let ((record (make-systemhalted-record
                 :source "<test>" :kind 'emacs
                 :last-modified "2026-03-05 10:00:00 +0000")))
    (should (equal (systemhalted--record-lastmod record)
                   "2026-03-05T10:00:00+00:00"))))

(ert-deftest systemhalted-record-lastmod-is-nil-without-date-or-last-modified ()
  "A plain page with neither a date nor LAST_MODIFIED must get no lastmod,
matching live, which omits `<lastmod>' for such pages."
  (let ((record (make-systemhalted-record :source "<test>" :kind 'page)))
    (should-not (systemhalted--record-lastmod record))))

(ert-deftest systemhalted-sitemap-loc-percent-encodes-non-ascii-segments ()
  "A Devanagari route must be percent-encoded per path segment, matching
live's sitemap, which never emits raw non-ASCII bytes in `<loc>'."
  (should (equal (systemhalted--sitemap-loc
                  "/2001/08/01/तमसो-मा-ज्योतिर्गमय/")
                 (concat
                  systemhalted-site-url
                  "/2001/08/01/%E0%A4%A4%E0%A4%AE%E0%A4%B8%E0%A5%8B-%E0%A4%AE%E0%A4%BE-"
                  "%E0%A4%9C%E0%A5%8D%E0%A4%AF%E0%A5%8B%E0%A4%A4%E0%A4%BF%E0%A4%B0%E0%A5%8D"
                  "%E0%A4%97%E0%A4%AE%E0%A4%AF/"))))

(ert-deftest systemhalted-sitemap-excludes-404-and-redirect-stubs ()
  "The 404 page and legacy redirect stubs must never appear in the sitemap,
matching live, which never lists a moved or error route."
  (let ((output (make-temp-file "systemhalted-sitemap-exclude-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (with-temp-buffer
            (insert-file-contents (expand-file-name "sitemap.xml" output))
            (should-not (string-match-p "/404\\.html" (buffer-string)))
            (dolist (redirect systemhalted-legacy-redirects)
              (should-not (string-match-p (regexp-quote (car redirect))
                                          (buffer-string))))))
      (delete-directory output t))))

(ert-deftest systemhalted-sitemap-includes-jsgames-and-wireframes-routes ()
  "The jsgames and wireframes static pages have no Org record of their own,
but live's sitemap lists them, so ours must too."
  (let ((output (make-temp-file "systemhalted-sitemap-static-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (with-temp-buffer
            (insert-file-contents (expand-file-name "sitemap.xml" output))
            (let ((xml (buffer-string)))
              (dolist (route '("/jsgames/guess-number/" "/jsgames/pig-game/"
                               "/jsgames/reeti-40/"
                               "/wireframes/systemhalted-writing-first.html"))
                (should (string-match-p
                         (regexp-quote (concat systemhalted-site-url route))
                         xml))))))
      (delete-directory output t))))

(ert-deftest systemhalted-sitemap-includes-lastmod-for-dated-records ()
  "A post's sitemap entry must carry a UTC `<lastmod>' matching its date."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "sitemap.xml" output))
      (should (string-match-p
               (concat "<loc>" (regexp-quote systemhalted-site-url)
                       "/2026/09/24/rich-content/</loc>"
                       "<lastmod>2026-09-24T00:00:00\\+00:00</lastmod>")
               (buffer-string))))))

(ert-deftest systemhalted-build-site-generates-robots-txt ()
  "robots.txt must point crawlers at the sitemap, matching live's own file
from the jekyll-sitemap gem."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "robots.txt" output))
      (should (equal (buffer-string)
                     (concat "Sitemap: " systemhalted-site-url "/sitemap.xml\n"))))))

(ert-deftest systemhalted-build-site-generates-links-jsonp ()
  "links.jsonp must expose every post as a `{text, href}' pair in
reverse-chronological order, matching main's `links.jsonp', callable as
JSONP via its `callback(...)' wrapper."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "links.jsonp" output))
      (let* ((text (buffer-string)))
        (should (string-prefix-p "callback(" text))
        (should (string-suffix-p ")" text))
        (let* ((json-text (substring text (length "callback(") -1))
               (parsed (json-parse-string json-text :object-type 'alist)))
          (should (> (length parsed) 0))
          (should (string-match-p "future-post" (alist-get 'href (aref parsed 0))))
          (should (cl-some
                   (lambda (item)
                     (and (equal (alist-get 'text item) "Rich & Structured")
                          (equal (alist-get 'href item)
                                 (concat systemhalted-site-url "/2026/09/24/rich-content/"))))
                   parsed)))))))

(ert-deftest systemhalted-feed-includes-self-link-categories-author-and-content ()
  "The feed must carry an atom:link self reference, a <category> per
category, a creator element, and each post's full HTML in
<content:encoded>, matching Task 7's RSS 2.0 enrichment."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "feed.xml" output))
      (let ((xml (buffer-string)))
        (should (string-match-p
                 (concat "<atom:link[^>]*href=\"" (regexp-quote systemhalted-site-url)
                         "/feed\\.xml\"[^>]*rel=\"self\"")
                 xml))
        (should (string-match-p "<category>Software Engineering</category>" xml))
        (should (string-match-p "<category>Emacs</category>" xml))
        (should (or (string-match-p "<dc:creator>Palak Mathur</dc:creator>" xml)
                    (string-match-p "<author>[^<]*Palak Mathur[^<]*</author>" xml)))
        (should (string-match-p "<content:encoded><!\\[CDATA\\[" xml))
        (should (string-match-p "Related body" xml))
        (should (string-match-p "\\]\\]></content:encoded>" xml))))))

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
  "Dropping source assets or a retired legacy redirect would break live URLs."
  (systemhalted-test-with-built-site
    (should (file-exists-p (expand-file-name "assets/css/nord.css" output)))
    (should (file-exists-p (expand-file-name "jsgames/pig-game/script.js" output)))
    (with-temp-buffer
      (insert-file-contents
       (expand-file-name "2025/11/25/disjuntive-types/index.html" output))
      (should (search-forward "url=/2025/11/25/disjunctive-types/" nil t)))))

(ert-deftest systemhalted-read-record-parses-kartavya-path-keyword ()
  "`#+KARTAVYA_PATH: true' must flag a post for the Kartavya Path landing
page's \"Past issues\" feed."
  (systemhalted-test-with-org
      (concat "#+TITLE: Newsletter Issue\n#+DESCRIPTION: A Kartavya Path issue fixture.\n"
              "#+DATE: 2024-08-01\n#+CATEGORIES: Newsletter\n#+TAGS: newsletter\n"
              "#+KARTAVYA_PATH: true\n")
    (let ((record (systemhalted-read-record file 'post)))
      (should (systemhalted-record-kartavya-path record))))
  (systemhalted-test-with-org
      (concat "#+TITLE: Ordinary Post\n#+DESCRIPTION: Not a Kartavya Path issue.\n"
              "#+DATE: 2024-08-01\n#+CATEGORIES: Tests\n#+TAGS: org\n")
    (let ((record (systemhalted-read-record file 'post)))
      (should-not (systemhalted-record-kartavya-path record)))))

(ert-deftest systemhalted-generate-kartavya-path-matches-live-shape ()
  "`/kartavya-path/' must be a real landing page, not the retired redirect to
`/archives/': its hero, the shared newsletter CTA aside, and a \"Past
issues\" feed of posts flagged `#+KARTAVYA_PATH: true', matching
`main:kartavya-path.html'."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "kartavya-path/index.html" output))
      (let ((html (buffer-string)))
        (should-not (string-match-p "url=/archives/" html))
        (dolist (fragment
                 '("<section class=\"newsletter-hero\">"
                   "<p class=\"newsletter-brand\">Kartavya Path</p>"
                   "<p class=\"newsletter-kicker\" lang=\"hi\">"
                   "<h1 class=\"newsletter-headline\">"
                   "<aside class=\"newsletter-cta newsletter-cta--landing\" id=\"newsletter-cta\">"
                   "<h2 class=\"newsletter-cta-title\">Kartavya Path</h2>"
                   "<h2 class=\"recent-title\">Past issues</h2>"
                   "<ul class=\"post-feed\">"
                   "<span class=\"post-feed-cat\">Kartavya Path</span>"
                   "<a href=\"/newsletter/2024-08-01-kartavya-fixture-issue/\">Kartavya Fixture Issue</a>"))
          (should (string-match-p (regexp-quote fragment) html)))))))

(ert-deftest systemhalted-home-page-splices-recent-posts-between-org-authored-sections ()
  "In production, `org/pages/index.org' supplies the hand-written intro and
Kartavya Path blurb, and the generator splices the computed recent-posts
section between them at the marker, matching `main:index.html' page 1."
  (let ((output (make-temp-file "systemhalted-home-splice-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (with-temp-buffer
            (insert-file-contents (expand-file-name "index.html" output))
            (let* ((html (buffer-string))
                   (main (systemhalted-test-main-html html))
                   (intro-pos (string-match "<header class=\"home-intro\"" main))
                   (recent-pos (string-match "aria-labelledby=\"recent-writing\"" main))
                   (kartavya-pos (string-match "class=\"home-section home-kartavya\"" main)))
              (should intro-pos)
              (should recent-pos)
              (should kartavya-pos)
              (should (< intro-pos recent-pos))
              (should (< recent-pos kartavya-pos))
              (should-not (string-match-p "<!--RECENT_POSTS-->" main)))))
      (delete-directory output t))))

(ert-deftest systemhalted-restores-newsletter-category-and-tag-on-kartavya-posts ()
  "The nine former Kartavya Path essays must carry the `Newsletter' category,
the `newsletter' tag, and `#+KARTAVYA_PATH: true', matching main."
  (dolist (relative '("org/posts/2024-06-25-embracing-timely-action.org"
                      "org/posts/2024-06-28-balancing-diplomacy-firmness.org"
                      "org/posts/2024-07-01-hidden-cost-of-ineffective-product-evaluation.org"
                      "org/posts/2024-07-14-the-state-of-gurgaon.org"
                      "org/posts/2024-07-16-six-degrees-of-freedom.org"
                      "org/posts/2024-07-19-leading-with-humility.org"
                      "org/posts/2024-09-03-eliminating-inequality.org"
                      "org/posts/2024-12-28-consumption-backlog-for-mindful-knowledge.org"
                      "org/posts/2025-12-05-equality-idea-conditioning-inheritance.org"))
    (let ((record (systemhalted-read-record
                   (expand-file-name relative systemhalted-test-root) 'post)))
      (should (equal (systemhalted-record-categories record) '("Newsletter")))
      (should (member "newsletter" (systemhalted-record-tags record)))
      (should (systemhalted-record-kartavya-path record)))))

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

(ert-deftest systemhalted-production-build-excludes-drafts ()
  "org/drafts/*.org must never reach a production build or its sitemap,
even though `systemhalted-audit-content' validates them for preview use."
  (let ((output (make-temp-file "systemhalted-production-drafts-" t))
        (draft-routes '("/2006/12/01/bas-aise-hi-likh-raha-hoon-dont-read-it/"
                        "/2011/06/19/usa-in-talks-with-taliban-a-question-mark-on-usas-intentions/"
                        "/2026/08/02/wisdom-accumulation-notes/")))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (dolist (route draft-routes)
            (should-not (file-exists-p
                         (systemhalted--local-target-file output route))))
          (let ((sitemap (expand-file-name "sitemap.xml" output)))
            (should (file-exists-p sitemap))
            (with-temp-buffer
              (insert-file-contents sitemap)
              (dolist (route draft-routes)
                (should-not (string-match-p (regexp-quote route)
                                            (buffer-string)))))))
      (delete-directory output t))))

(ert-deftest systemhalted-production-build-contains-every-live-route ()
  "Every route the live site publishes must exist in a production build.
`test/baseline/live-routes.tsv' omits `/pageN/' (out of scope; nobody links to
paginated pages and the local page count intentionally differs); it does
include the `/jsgames/<game>/' and wireframes routes, matching their static
output files."
  (let ((output (make-temp-file "systemhalted-live-routes-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (let (expected)
            (with-temp-buffer
              (insert-file-contents
               (expand-file-name "test/baseline/live-routes.tsv" systemhalted-test-root))
              (goto-char (point-min))
              (forward-line 1)
              (while (not (eobp))
                (let ((route (string-trim
                              (buffer-substring (line-beginning-position)
                                                (line-end-position)))))
                  (unless (string-empty-p route) (push route expected)))
                (forward-line 1)))
            (dolist (route expected)
              (should (file-exists-p
                       (systemhalted--local-target-file output route))))))
      (delete-directory output t))))

;;; Head metadata and SEO (Task 6)

(ert-deftest systemhalted-render-page-title-formats-match-live ()
  "A bare page title must read \"<title> | SystemHalted.in\", matching live's
jekyll-seo-tag separator, not the old middle-dot."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/about.org" systemhalted-test-root)
                  'page))
         (html (systemhalted-render-page record)))
    (should (string-match-p "<title>About \\| SystemHalted.in</title>" html))
    (should (string-match-p
             "<meta property=\"og:title\" content=\"About\">" html))
    (should (string-match-p
             "<meta property=\"twitter:title\" content=\"About\">" html))))

(ert-deftest systemhalted-render-page-home-title-uses-site-description ()
  "Home's <title> has no page title of its own, so it must read
\"SystemHalted.in | <description>\", matching live, and its bare og/twitter
title must be just the site title."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p
                 (regexp-quote
                  (format "<title>%s | %s</title>"
                          systemhalted-site-title systemhalted-site-description))
                 html))
        (should (string-match-p
                 (format "<meta property=\"og:title\" content=\"%s\">"
                         (regexp-quote systemhalted-site-title))
                 html))
        (should-not (string-match-p "meta name=\"robots\"" html))))))

(ert-deftest systemhalted-render-page-page2-title-and-robots-match-live ()
  "A /pageN/ page must carry a noindex robots tag and a
\"Page N of M for SystemHalted.in | <description>\" title, matching live's
`/page2/'."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "page2/index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p
                 "<meta name=\"robots\" content=\"noindex,follow\">" html))
        (should (string-match-p
                 (regexp-quote
                  (format "<title>Page 2 of 3 for %s | %s</title>"
                          systemhalted-site-title systemhalted-site-description))
                 html))
        (should (string-match-p
                 "<link rel=\"canonical\" href=\"https://systemhalted.in/page2/\">"
                 html))))))

(ert-deftest systemhalted-render-page-404-carries-noindex-robots ()
  "The 404 page must carry a noindex robots tag, matching live."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/404.org" systemhalted-test-root)
                  'page))
         (html (systemhalted-render-page record)))
    (should (string-match-p
             "<meta name=\"robots\" content=\"noindex,follow\">" html))
    (should (string-match-p "<title>404: Page not found \\| SystemHalted.in</title>" html))))

(ert-deftest systemhalted-render-page-post-gets-article-type-and-published-time ()
  "A post must emit `og:type=article' plus `article:published_time', matching
live; other kinds must stay `website'."
  (let* ((record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (html (systemhalted-render-page record records))
         (page-record (systemhalted-read-record
                       (expand-file-name "org/pages/about.org" systemhalted-test-root)
                       'page))
         (page-html (systemhalted-render-page page-record)))
    (should (string-match-p "<meta property=\"og:type\" content=\"article\">" html))
    (should (string-match-p
             "<meta property=\"article:published_time\" content=\"2026-09-24T00:00:00\\+00:00\">"
             html))
    (should (string-match-p "<meta property=\"og:type\" content=\"website\">" page-html))
    (should-not (string-match-p "article:published_time" page-html))))

(ert-deftest systemhalted-render-page-image-falls-back-to-avatar ()
  "A page without a featured image must use the avatar as its og/twitter image;
a post with one must use it instead."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (featured-record (systemhalted-read-record
                           (systemhalted-test-fixture "2026-09-24-rich-content.org")
                           'post))
         (featured-html (systemhalted-render-page featured-record records))
         (plain-record (systemhalted-read-record
                        (expand-file-name "org/pages/about.org" systemhalted-test-root)
                        'page))
         (plain-html (systemhalted-render-page plain-record)))
    (should (string-match-p
             "<meta property=\"og:image\" content=\"https://systemhalted.in/assets/images/avatar.jpeg\">"
             featured-html))
    (should (string-match-p
             "<meta property=\"twitter:image\" content=\"https://systemhalted.in/assets/images/avatar.jpeg\">"
             featured-html))
    (should (string-match-p
             "<meta property=\"og:image\" content=\"https://systemhalted.in/assets/images/avatar.jpeg\">"
             plain-html))))

(ert-deftest systemhalted-render-page-twitter-card-matches-live-per-page-type ()
  "Home, /about/, and /pageN/ get `summary_large_image'; everything else, and
every post, gets `summary', matching what live emits for each page type."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "index.html" output))
      (should (string-match-p
               "<meta name=\"twitter:card\" content=\"summary_large_image\">"
               (buffer-string))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "about/index.html" output))
      (should (string-match-p
               "<meta name=\"twitter:card\" content=\"summary_large_image\">"
               (buffer-string))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "archives/index.html" output))
      (should (string-match-p
               "<meta name=\"twitter:card\" content=\"summary\">"
               (buffer-string))))))

(ert-deftest systemhalted-render-page-includes-locale-author-generator-and-verification ()
  "og:locale, author, generator, and the Search Console verification tag must
be present, matching live's `_includes/head.html' output."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/about.org" systemhalted-test-root)
                  'page))
         (html (systemhalted-render-page record)))
    (should (string-match-p "<meta property=\"og:locale\" content=\"en_US\">" html))
    (should (string-match-p "<meta name=\"author\" content=\"Palak Mathur\">" html))
    (should (string-match-p
             (format "<meta name=\"generator\" content=\"%s\">"
                     (regexp-quote systemhalted-generator))
             html))
    (should (string-match-p
             "<meta name=\"google-site-verification\" content=\"1v5ZSlWxFB06EQ-VB5U4n3226XFqq3ki9qusVH2m0K8\">"
             html))
    (should (string-match-p
             "googletagmanager.com/gtag/js\\?id=UA-36868278-1" html))
    (should (string-match-p "gtag('config', 'UA-36868278-1')" html))
    (should (string-match-p
             "<link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/assets/systemhalted-terminal-32.png\">"
             html))))

(ert-deftest systemhalted-render-page-structured-data-matches-live-shape ()
  "The Person node must carry `sameAs'; the WebSite node must appear only on
`/', with `alternateName' and `inLanguage'; a post's BlogPosting must carry
`datePublished', an author `@id' reference, and an image."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (record (systemhalted-read-record
                  (systemhalted-test-fixture "2026-09-24-rich-content.org")
                  'post))
         (html (systemhalted-render-page record records))
         (home-record (systemhalted--synthetic-page "Writing" "desc" "/"))
         (home-html (systemhalted-render-page home-record nil "<p>home</p>")))
    (should (string-match-p "\"sameAs\":\\[\"https://github.com/systemhalted\"" html))
    (should (string-match-p "\"@type\":\"BlogPosting\"" html))
    (should (string-match-p "\"datePublished\":\"2026-09-24T00:00:00\\+00:00\"" html))
    (should (string-match-p
             "\"author\":{\"@id\":\"https://systemhalted.in/#person\"}" html))
    (should (string-match-p "\"image\":\"https://systemhalted.in/assets/images/avatar.jpeg\"" html))
    (should (string-match-p "\"@type\":\"WebSite\"" home-html))
    (should (string-match-p
             "\"alternateName\":\\[\"The System Halted\",\"System Halted\",\"The SystemHalted\",\"systemhalted\"\\]"
             home-html))
    (should (string-match-p "\"inLanguage\":\"en-US\"" home-html))
    (should-not (string-match-p "\"@type\":\"WebSite\"" html))))

(ert-deftest systemhalted-build-site-cache-busts-with-a-deterministic-token ()
  "CSS/JS links must carry a real cache-busting value, not the literal `org'
placeholder or anything wall-clock derived; two clean builds must agree."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "index.html" output))
      (let ((html (buffer-string)))
        (should-not (string-match-p (regexp-quote "?v=org") html))
        (should (string-match-p "nord\\.css\\?v=[0-9a-f]+" html))
        (should (string-match-p "script\\.js\\?v=[0-9a-f]+" html))))))

(ert-deftest systemhalted-build-site-footer-year-tracks-newest-post ()
  "The footer year must be the newest post's year, not a hard-coded value."
  (let ((directory (make-temp-file "systemhalted-footeryear-" t))
        (output (make-temp-file "systemhalted-footeryear-out-" t))
        (systemhalted-static-paths
         (remove "wireframes" (copy-sequence systemhalted-static-paths))))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "2020-01-01-old-post.org" directory)
            (insert "#+TITLE: Old Post\n#+DESCRIPTION: An old post.\n"
                    "#+DATE: 2020-01-01\n#+CATEGORIES: Tests\n#+TAGS: org\n"))
          (with-temp-file (expand-file-name "2031-06-01-newest-post.org" directory)
            (insert "#+TITLE: Newest Post\n#+DESCRIPTION: The newest post.\n"
                    "#+DATE: 2031-06-01\n#+CATEGORIES: Tests\n#+TAGS: org\n"))
          (systemhalted-build-site
           :root systemhalted-test-root
           :output output
           :content-directories (list (cons systemhalted-test-fixtures 'post)
                                       (cons directory 'post))
           :include-drafts t
           :include-future t)
          (with-temp-buffer
            (insert-file-contents (expand-file-name "index.html" output))
            (should (string-match-p "©[ ]?2031 Palak Mathur" (buffer-string)))
            (should-not (string-match-p "© 2026 Palak Mathur" (buffer-string)))))
      (delete-directory directory t)
      (delete-directory output t))))

(ert-deftest systemhalted-render-page-search-suggestions-include-newsletter ()
  "The search overlay's suggestions must match `_config.yml's `search.suggestions',
which restores `newsletter'."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/about.org" systemhalted-test-root)
                  'page))
         (html (systemhalted-render-page record)))
    (should (string-match-p
             "data-suggestions=\"emacs,leadership,newsletter,javascript\"" html))
    (should (string-match-p "data-suggest=\"newsletter\">newsletter<" html))))

;;; Page titles and the page skeleton (Task 8)

(defun systemhalted-test-main-html (html)
  "Return the contents between <main ...> and </main> in HTML.
Used to scope title/heading assertions to the page body, since base.html's
head and header always contain their own h2 elements (the search and
shortcuts overlays)."
  (if (string-match "<main[^>]*>\\([^z-a]*?\\)</main>" html)
      (match-string 1 html)
    (error "systemhalted-test-main-html: no <main> element found")))

(ert-deftest systemhalted-read-record-parses-hide-and-quiet-title-keywords ()
  "HIDE_TITLE and QUIET_TITLE must parse into the record's title-display flags,
each independent of the other."
  (systemhalted-test-with-org
      (concat "#+TITLE: Hidden\n#+DESCRIPTION: Hidden title fixture.\n"
              "#+HIDE_TITLE: true\n")
    (let ((record (systemhalted-read-record file 'page)))
      (should (systemhalted-record-hide-title record))
      (should-not (systemhalted-record-quiet-title record))))
  (systemhalted-test-with-org
      (concat "#+TITLE: Quiet\n#+DESCRIPTION: Quiet title fixture.\n"
              "#+QUIET_TITLE: true\n")
    (let ((record (systemhalted-read-record file 'page)))
      (should (systemhalted-record-quiet-title record))
      (should-not (systemhalted-record-hide-title record)))))

(ert-deftest systemhalted-render-page-respects-hide-and-quiet-title-flags ()
  "`systemhalted-render-page' must honor a record's hide-title/quiet-title
flags when rendering a page through page.html: a quiet flag adds
`page-title-quiet' to the h1, and a hide flag drops the h1 entirely."
  (let* ((quiet (make-systemhalted-record :source "<test>" :kind 'page
                                          :title "Quiet Page" :description "d"
                                          :route "/quiet-test/" :quiet-title t))
         (hidden (make-systemhalted-record :source "<test>" :kind 'page
                                           :title "Hidden Page" :description "d"
                                           :route "/hidden-test/" :hide-title t))
         (quiet-html (systemhalted-render-page quiet nil "<p>x</p>"))
         (hidden-html (systemhalted-render-page hidden nil "<p>x</p>")))
    (should (string-match-p
             "<h1 class=\"page-title page-title-quiet\">Quiet Page</h1>" quiet-html))
    (should-not (string-match-p "page-title" hidden-html))))

(ert-deftest systemhalted-render-page-home-and-pagen-skip-page-wrapper ()
  "The home page and its `/pageN/' siblings must render straight into
base.html's <main>, with no page.html wrapper and no stray page-title h1,
matching live."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "index.html" output))
      (let ((html (buffer-string)))
        (should-not (string-match-p "class=\"page\"" html))
        (should-not (string-match-p "page-title" html))
        (should (string-match-p
                 "<main[^>]*><header class=\"home-intro\"" html))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "page2/index.html" output))
      (let ((html (buffer-string)))
        (should-not (string-match-p "class=\"page\"" html))
        (should-not (string-match-p "page-title" html))
        (should (string-match-p
                 "<main[^>]*><header class=\"page-header\"" html))))))

(ert-deftest systemhalted-quiet-title-pages-match-live ()
  "About, Projects, JS Games, and the archive/categories/tags/emacs gateway
pages must all carry the quiet page title, matching live's
`page-title-quiet' class."
  (dolist (relative '("org/pages/about.org" "org/pages/projects.org"
                      "org/pages/jsgames.org"))
    (let* ((record (systemhalted-read-record
                    (expand-file-name relative systemhalted-test-root) 'page))
           (html (systemhalted-render-page record)))
      (should (string-match-p "class=\"page-title page-title-quiet\"" html))))
  (systemhalted-test-with-built-site
    (dolist (relative '("archives/index.html" "categories/index.html"
                        "tags/index.html" "emacs/index.html"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name relative output))
        (should (string-match-p "class=\"page-title page-title-quiet\""
                                (buffer-string)))))))

(ert-deftest systemhalted-hidden-title-pages-omit-page-title ()
  "Themes and Webcmd must hide the page.html title entirely, matching live's
`hide_page_title'."
  (dolist (relative '("org/pages/themes.org" "org/pages/webcmd.org"))
    (let* ((record (systemhalted-read-record
                    (expand-file-name relative systemhalted-test-root) 'page))
           (html (systemhalted-render-page record)))
      (should-not (string-match-p "page-title"
                                  (systemhalted-test-main-html html))))))

(ert-deftest systemhalted-archive-gateways-mark-current-section ()
  "Each archive gateway page must mark its own link `aria-current=\"page\"',
not always Archive."
  (systemhalted-test-with-built-site
    (dolist (case '(("archives/index.html" . "<a href=\"/archives/\" aria-current=\"page\">Archive</a>")
                    ("categories/index.html" . "<a href=\"/categories/\" aria-current=\"page\">Categories</a>")
                    ("tags/index.html" . "<a href=\"/tags/\" aria-current=\"page\">Tags</a>")
                    ("emacs/index.html" . "<a href=\"/emacs/\" aria-current=\"page\">Emacs</a>")))
      (with-temp-buffer
        (insert-file-contents (expand-file-name (car case) output))
        (should (string-match-p (regexp-quote (cdr case)) (buffer-string)))))))

(ert-deftest systemhalted-404-page-body-matches-live-shape ()
  "The 404 page body must be a bare h1 plus a paragraph with a 'Head back
home' link, with no heading duplicating the title, matching live."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/404.org" systemhalted-test-root)
                  'page))
         (main (systemhalted-test-main-html (systemhalted-render-page record))))
    (should (string-match-p
             "<h1 class=\"page-title\">404: Page not found</h1>" main))
    (should (string-match-p "Head back home" main))
    (should-not (string-match-p "<h2" main))
    (should-not (string-match-p "outline-container" main))))

(ert-deftest systemhalted-webcmd-page-body-drops-stray-paragraph-and-duplicate-heading ()
  "Webcmd's Org body must drop the stray 'Webcmd' paragraph and the heading
that duplicates the page title; Task 11 restores the full webcmd markup."
  (let* ((record (systemhalted-read-record
                  (expand-file-name "org/pages/webcmd.org" systemhalted-test-root)
                  'page))
         (main (systemhalted-test-main-html (systemhalted-render-page record))))
    (should-not (string-match-p "<p>[[:space:]]*Webcmd[[:space:]]*</p>" main))
    (should-not (string-match-p "<h2" main))
    (should (string-match-p "id=\"webcmd-form\"" main))))

(ert-deftest systemhalted-read-taxonomy-returns-ordered-themes-with-ids ()
  "The taxonomy reader must expose each theme's `:CUSTOM_ID:' as :id, preserve
theme and category order, and thread through descriptions, matching
`main:_data/taxonomy.yml'. Losing the id or the order would break both the
live-matching `h2' anchors on `/categories/' and Task 12's sibling lookup."
  (let* ((themes (plist-get (systemhalted--read-taxonomy systemhalted-test-root) :themes))
         (series (car themes)))
    (should (equal (plist-get series :id) "series"))
    (should (equal (plist-get series :title) "Series"))
    (should (plist-get series :description))
    (should (equal (mapcar (lambda (category) (plist-get category :name))
                           (plist-get series :categories))
                   '("Series 1 - Language and Linguistics"
                     "Series 2 - Turtle, BASIC, and the Long Road to Taste"
                     "Series 3 - Project Jigsaw (JPMS)"
                     "Series 4 - Floating Point Without Tears")))
    (should (equal (plist-get (car (last themes)) :id) "newsletter"))))

(ert-deftest systemhalted-taxonomy-category-siblings-finds-theme-mates ()
  "Task 12 needs a category's theme-mates to build cross-links from
`systemhalted--taxonomy-category-siblings'; a category outside every theme
must come back nil rather than error."
  (let ((themes (plist-get (systemhalted--read-taxonomy systemhalted-test-root) :themes)))
    (should (equal (systemhalted--taxonomy-category-siblings themes "Technology")
                   '("Technology" "Software Engineering" "Computer Science")))
    (should-not (systemhalted--taxonomy-category-siblings themes "Not A Real Category"))))

(ert-deftest systemhalted-tag-ids-append-forloop-index-suffix-on-collision ()
  "Two tags that slugify to the same id must keep only the first plain id;
every later collision gets a `--N' suffix where N is that tag's 1-based
position in NAMES, matching main's `tags.html' Liquid loop (`forloop.index')
exactly, including which one wins the plain id."
  (should (equal (systemhalted--tag-ids
                  '("API Design" "Linux" "NaN" "api-design" "linux" "nan"))
                 '(("API Design" . "api-design") ("Linux" . "linux") ("NaN" . "nan")
                   ("api-design" . "api-design--4") ("linux" . "linux--5")
                   ("nan" . "nan--6")))))

(ert-deftest systemhalted-categories-page-groups-by-taxonomy-theme ()
  "`/categories/' must render one `taxonomy-section' per theme that has
posts, in theme and category order, and route categories claimed by no
theme to \"Other categories\"; a theme with no posted categories must not
render at all."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "categories/index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p
                 "<h2 id=\"tech_engineering\">Tech, Software, and Engineering</h2>" html))
        (should (string-match-p "<details id=\"cat-software-engineering\"" html))
        (should (string-match-p "<h2 id=\"newsletter\">Newsletters</h2>" html))
        (should (string-match-p "<details id=\"cat-newsletter\"" html))
        (should (string-match-p "<h2 id=\"other-categories\">Other categories</h2>" html))
        (should (string-match-p "<details id=\"cat-hindi\"" html))
        (should (string-match-p "<details id=\"cat-leadership\"" html))
        (should-not (string-match-p "<h2 id=\"ai_data\"" html))))))

(ert-deftest systemhalted-categories-page-has-intro-paragraph ()
  "`/categories/' must carry the archive-intro paragraph before the
gateways, matching `main:categories.html'; the earlier shared taxonomy
generator omitted it entirely."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "categories/index.html" output))
      (should (string-match-p
               (regexp-quote
                "<p class=\"archive-intro\">Browse the archive through the recurring subjects and series in the writing.</p>")
               (buffer-string))))))

(ert-deftest systemhalted-tags-page-has-intro-and-tag-groups ()
  "`/tags/' must carry the archive-intro paragraph before the gateways and
group every tag inside a single `tag-groups' div, matching
`main:tags.html'; the earlier shared taxonomy generator omitted the intro."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "tags/index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p
                 (regexp-quote
                  "<p class=\"archive-intro\">A more granular index of topics across the archive.</p>")
                 html))
        (should (string-match-p "<div class=\"tag-groups\">" html))
        (should (string-match-p "<details id=\"publishing\"" html))))))

(provide 'systemhalted-publish-test)
;;; systemhalted-publish-test.el ends here
