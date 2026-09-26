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
    (should (string-match-p "<h1 id=\"heading--details\">Heading &amp; details</h1>" html))
    (should (string-match-p "class=\"language-emacs-lisp\"" html))
    (should (string-match-p "&lt;unsafe&gt;" html))
    (should (string-match-p "Example text" html))
    (should (string-match-p "<table" html))
    (should (string-match-p "<thead>" html))
    (should (string-match-p "<aside class=\"fixture\">Raw HTML</aside>" html))
    (should (string-match-p "<sup id=\"fnref:1\">" html))
    (should (string-match-p
             "href=\"/newsletter/2024-07-19-legacy-permalink/\"" html))))

(ert-deftest systemhalted-export-body-publishes-kramdown-anchor-headings ()
  "Task 14: headline levels must publish as `<hN>' carrying kramdown-style
anchor ids, with no Org outline wrappers, so live anchors keep resolving.
Every id below is copied from the live page that publishes it."
  (systemhalted-test-with-org
      (concat "#+TITLE: Anchors\n#+DESCRIPTION: Anchor fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "* Should top bureaucrats, police chiefs, and judges be allowed to enter politics?\n"
              "** ==== is changing, but =equals()= still matters\n"
              "** Savehist — persist minibuffer history\n"
              "** 1. Signed Zero: ±0.0\n"
              "** The Weird Rule: NaN ≠ NaN\n"
              "** 2. Infinity: +∞ and −∞\n"
              "** Common failure modes\n"
              "** Common failure modes\n"
              "*** Start with क्ष\n"
              "** LSP & DAP notes\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                (concat "<h1 id=\"should-top-bureaucrats-police-chiefs-and-judges-be-allowed-to-enter-politics\">"
                        "Should top bureaucrats, police chiefs, and judges be allowed to enter politics?</h1>"))
               html))
      (should (string-match-p
               (concat "<h2 id=\"-is-changing-but-equals-still-matters\">"
                       "<code>==</code> is changing, but <code>equals()</code> still matters</h2>")
               html))
      (should (string-match-p "<h2 id=\"savehist--persist-minibuffer-history\">" html))
      (should (string-match-p "<h2 id=\"1-signed-zero-00\">" html))
      (should (string-match-p "<h2 id=\"the-weird-rule-nan--nan\">" html))
      (should (string-match-p "<h2 id=\"2-infinity--and-\">" html))
      (should (string-match-p "<h2 id=\"common-failure-modes\">" html))
      (should (string-match-p "<h2 id=\"common-failure-modes-1\">" html))
      (should (string-match-p "<h3 id=\"start-with-क्ष\">" html))
      (should (string-match-p "<h2 id=\"lsp--dap-notes\">" html))
      (should-not (string-match-p "outline-container" html))
      (should-not (string-match-p "outline-text" html)))))

(ert-deftest systemhalted-export-body-keeps-custom-id-headings ()
  "Task 14: an authored `:CUSTOM_ID:' stays the heading anchor, matching the
explicit ids live publishes for `/2026/09/23/java28-value-objects/'."
  (systemhalted-test-with-org
      (concat "#+TITLE: Custom\n#+DESCRIPTION: Custom id fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "* References and Notes\n:PROPERTIES:\n:CUSTOM_ID: references-and-notes\n:END:\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p "<h1 id=\"references-and-notes\">" html))
      (should-not (string-match-p "references-and-notes-1" html)))))

(ert-deftest systemhalted-export-body-renders-kramdown-footnotes ()
  "Task 14: footnote references, the notes section, and the back-links must
carry the ids live publishes, and the Org `Footnotes:' heading must go away."
  (systemhalted-test-with-org
      (concat "#+TITLE: Notes\n#+DESCRIPTION: Footnote fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "Body with a note.[fn:note]\n\nAnd again.[fn:note]\n\n"
              "[fn:note] A footnote.\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (concat "<sup id=\"fnref:1\"><a href=\"#fn:1\" class=\"footnote\""
                       " rel=\"footnote\" role=\"doc-noteref\">1</a></sup>")
               html))
      (should (string-match-p
               (concat "<sup id=\"fnref:1:1\"><a href=\"#fn:1\" class=\"footnote\""
                       " rel=\"footnote\" role=\"doc-noteref\">1</a></sup>")
               html))
      (should (string-match-p "<div class=\"footnotes\" role=\"doc-endnotes\">" html))
      (should (string-match-p "<li id=\"fn:1\">" html))
      (should (string-match-p
               (concat "<a href=\"#fnref:1\" class=\"reversefootnote\""
                       " role=\"doc-backlink\">&#8617;</a>")
               html))
      (should (string-match-p
               (concat "<a href=\"#fnref:1:1\" class=\"reversefootnote\""
                       " role=\"doc-backlink\">&#8617;<sup>2</sup></a>")
               html))
      (should-not (string-match-p "<h2 class=\"footnotes\"" html))
      (should-not (string-match-p "class=\"footdef\"" html))
      (should-not (string-match-p "class=\"footref\"" html))
      (should-not (string-match-p "footpara" html)))))

(ert-deftest systemhalted-export-body-uses-strong-and-em-for-emphasis ()
  "Task 14: emphasis must publish as `<strong>'/`<em>', the way live's
kramdown pipeline does, rather than Org's `<b>'/`<i>'."
  (systemhalted-test-with-org
      (concat "#+TITLE: Emphasis\n#+DESCRIPTION: Emphasis fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "Some *bold* and /italic/ text.\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p "<strong>bold</strong>" html))
      (should (string-match-p "<em>italic</em>" html))
      (should-not (string-match-p "<b>" html))
      (should-not (string-match-p "<i>" html)))))

(ert-deftest systemhalted-export-body-publishes-table-header-rows-in-thead ()
  "Task 14: a table written with a header rule must publish its header row
inside `<thead>', matching the live `/2011/01/28/lokpal-bill/' table."
  (systemhalted-test-with-org
      (concat "#+TITLE: Table\n#+DESCRIPTION: Table fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "|  |  |\n|--|--|\n| *Government bill* | *Civil society bill* |\n"
              "| One | Two |\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p "<thead>" html))
      (should (string-match-p "<th" html))
      (should (string-match-p "<tbody>" html)))))

(ert-deftest systemhalted-export-body-highlights-java-source-blocks ()
  "Task 13: a java block must keep its Rouge wrapper and gain token spans."
  (systemhalted-test-with-org
      (concat "#+TITLE: Java\n#+DESCRIPTION: Java highlight fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+BEGIN_SRC java\n"
              "if (name == null) {\n    throw new IllegalArgumentException(\"name\");\n}\n"
              "#+END_SRC\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p
               (regexp-quote
                (concat "<div class=\"language-java highlighter-rouge\">"
                        "<div class=\"highlight\"><pre class=\"highlight\">"
                        "<code class=\"language-java\" data-lang=\"java\">"))
               html))
      (should (string-match-p "<span class=\"org-keyword\">if</span>" html))
      (should (string-match-p "<span class=\"org-string\">\"name\"</span>" html)))))

(ert-deftest systemhalted-export-body-keeps-the-bash-language-class ()
  "Task 13: a block written as `#+begin_src bash' must keep `language-bash'
rather than being normalised to `sh'."
  (systemhalted-test-with-org
      (concat "#+TITLE: Bash\n#+DESCRIPTION: Bash highlight fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+BEGIN_SRC bash\necho \"$HOME\" # a note\n#+END_SRC\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p "class=\"language-bash highlighter-rouge\"" html))
      (should (string-match-p "data-lang=\"bash\"" html))
      (should (string-match-p "<span class=\"org-builtin\">echo</span>" html))
      (should (string-match-p "<span class=\"org-string\">\"$HOME\"</span>" html)))))

(ert-deftest systemhalted-export-body-escapes-source-blocks-without-a-major-mode ()
  "Task 13: a language Emacs cannot fontify must still export as escaped text
inside the usual wrapper."
  (systemhalted-test-with-org
      (concat "#+TITLE: Logo\n#+DESCRIPTION: Logo highlight fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+BEGIN_SRC logo\nTO foo 90\n<unsafe>\n#+END_SRC\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record))))
      (should (string-match-p "class=\"language-logo highlighter-rouge\"" html))
      (should (string-match-p "TO foo 90" html))
      (should (string-match-p "&lt;unsafe&gt;" html))
      (should-not (string-match-p "<span" html)))))

(ert-deftest systemhalted-export-body-highlights-regardless-of-mode-remapping ()
  "Task 13: a reader's `major-mode-remap-defaults' must not change the
published HTML, so a batch build and a preview agree token for token."
  (systemhalted-test-with-org
      (concat "#+TITLE: Remap\n#+DESCRIPTION: Mode remapping fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+BEGIN_SRC java\nint a = 1;\n#+END_SRC\n")
    (let* ((record (systemhalted-read-record file 'post))
           (published (systemhalted-export-body record (list record)))
           (remapped
            (let ((major-mode-remap-defaults '((java-mode . fundamental-mode))))
              (systemhalted-export-body record (list record)))))
      (should (string-match-p "<span class=\"org-type\">int</span>" published))
      (should (equal published remapped)))))

(defun systemhalted-test-css-rules ()
  "Return an alist mapping every selector in nord.css to its declarations."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "assets/css/nord.css"
                                            systemhalted-test-root))
    ;; Drop comments first, or the rule that follows one would be read as
    ;; having the comment text as part of its selector.  A comment can span
    ;; lines, and a bare `.` stops at a newline in an Emacs regexp.
    (let ((without-comments
           (replace-regexp-in-string "/[*]\\(.\\|\n\\)*?[*]/" "" (buffer-string))))
      (erase-buffer)
      (insert without-comments))
    (goto-char (point-min))
    (let (rules)
      (while (re-search-forward "\\([^{}]+\\){[ \t\n]*\\([^{}]*\\)}" nil t)
        ;; Keep the declarations before splitting the selector list, because
        ;; splitting matches inside the rule and so loses them.
        (let ((declarations (match-string 2))
              (selectors (split-string (match-string 1) "," t)))
          (dolist (selector selectors)
            (push (cons (string-trim selector) declarations) rules))))
      (nreverse rules))))

(defun systemhalted-test-css-declarations (declarations)
  "Return DECLARATIONS with its whitespace and trailing semicolons normalised,
so two rules that mean the same compare equal."
  (string-trim (replace-regexp-in-string "[ \t\n\r]+" " " declarations) " \t\n\r;"))

(ert-deftest systemhalted-nord-css-colours-htmlize-faces-like-rouge-tokens ()
  "Task 13: every htmlize face class must carry exactly the declaration the
Rouge token class with the same meaning already has."
  (let ((rules (systemhalted-test-css-rules)))
    (dolist (pair '((org-keyword . k) (org-type . kt) (org-preprocessor . kp)
                    (org-constant . mi) (org-doc . s) (org-string . s)
                    (org-comment . c) (org-comment-delimiter . c)
                    (org-builtin . nb) (org-function-name . nf)
                    (org-variable-name . nv) (org-operator . o)
                    (org-negation-char . o)))
      (let ((htmlize (cdr (assoc (format ".highlight .%s" (car pair)) rules)))
            (rouge (cdr (assoc (format ".highlight .%s" (cdr pair)) rules))))
        (should (stringp htmlize))
        (should (stringp rouge))
        (should (equal (systemhalted-test-css-declarations htmlize)
                       (systemhalted-test-css-declarations rouge)))))))

(ert-deftest systemhalted-nord-css-covers-every-htmlize-face-a-block-emits ()
  "Task 13: nord.css must colour every class a highlighted block emits, or the
token silently falls back to plain code text."
  (systemhalted-test-with-org
      (concat "#+TITLE: Languages\n#+DESCRIPTION: Language coverage fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n\n"
              "#+BEGIN_SRC java\n// note\n/** @param x doc */\nif (a == null) { return \"s\"; }\n#+END_SRC\n\n"
              "#+BEGIN_SRC emacs-lisp\n;; note\n(defvar re \"[^\\\\n]\\\\(?:\")\n\n(defun f (x) \"doc\" (+ x 1))\n#+END_SRC\n\n"
              "#+BEGIN_SRC sh\n# note\nsudo mv f \\\n  /var/tmp\n#+END_SRC\n\n"
              "#+BEGIN_SRC python\n# note\ndef f(x):\n    return x + 1\n#+END_SRC\n\n"
              "#+BEGIN_SRC sql\n-- note\nSELECT 1 FROM t WHERE a != 2;\n#+END_SRC\n\n"
              "#+BEGIN_SRC c\n/* note */\n#include <stdio.h>\nint main(void) { return 0; }\n#+END_SRC\n\n"
              "#+BEGIN_SRC javascript\n// note\nconst x = 1;\n#+END_SRC\n\n"
              "#+BEGIN_SRC lua\n-- note\nlocal x = 1\n#+END_SRC\n\n"
              "#+BEGIN_SRC fortran\n! note\nprogram p\nend program\n#+END_SRC\n\n"
              "#+BEGIN_SRC toml\n# note\ntitle = \"x\"\n#+END_SRC\n\n"
              "#+BEGIN_SRC xml\n<!-- note -->\n<a href=\"x\">y</a>\n#+END_SRC\n\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-export-body record (list record)))
           (rules (systemhalted-test-css-rules))
           classes)
      (with-temp-buffer
        (insert html)
        (goto-char (point-min))
        (while (re-search-forward "<span class=\"\\([^\"]+\\)\"" nil t)
          (push (match-string 1) classes)))
      (should classes)
      (dolist (class (delete-dups classes))
        (should (assoc (format ".highlight .%s" class) rules))))))

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

(ert-deftest systemhalted-render-page-publishes-the-live-toc-markup ()
  "Task 14: a post asking for a table of contents must publish
`ul#toc.section-nav' with `li.toc-entry.toc-hN' entries nested by heading
level and plain-text links, matching the live java28 and emacs pages."
  (systemhalted-test-with-org
      (concat "#+TITLE: Contents\n#+DESCRIPTION: Table of contents fixture.\n"
              "#+DATE: 2026-09-25\n#+CATEGORIES: Tests\n#+TAGS: org\n#+TOC: true\n\n"
              "* Overview\n** Clipboard\n*** Move text\n** Build-in defaults\n"
              "* ==== is changing, but =equals()= still matters\n")
    (let* ((record (systemhalted-read-record file 'post))
           (html (systemhalted-render-page record (list record))))
      (should (string-match-p
               (concat "<details class=\"post-toc\"><summary>Contents</summary>"
                       "<nav aria-label=\"Table of contents\">"
                       "<ul id=\"toc\" class=\"section-nav\">")
               html))
      (should (string-match-p
               (concat "<li class=\"toc-entry toc-h1\">"
                       "<a href=\"#overview\">Overview</a>\n<ul>\n"
                       "<li class=\"toc-entry toc-h2\">"
                       "<a href=\"#clipboard\">Clipboard</a>\n<ul>\n"
                       "<li class=\"toc-entry toc-h3\">"
                       "<a href=\"#move-text\">Move text</a></li>\n</ul>\n</li>\n"
                       "<li class=\"toc-entry toc-h2\">"
                       "<a href=\"#build-in-defaults\">Build-in defaults</a></li>\n"
                       "</ul>\n</li>")
               html))
      (should (string-match-p
               (concat "<li class=\"toc-entry toc-h1\">"
                       "<a href=\"#-is-changing-but-equals-still-matters\">"
                       "== is changing, but equals() still matters</a></li>")
               html))
      (should-not (string-match-p "<a href=\"#overview\"><code>" html)))))

(ert-deftest systemhalted-gill-post-drops-its-stray-paragraph-markup ()
  "Task 14: the `/2008/04/09/' post wrapped its opening line in literal
`#+begin_html' paragraphs, which Org exports as an escaped `div.html'. The
page must publish the plain paragraph and the live `Hindu' link instead."
  (let* ((file (expand-file-name
                "org/posts/2008-04-09-implications-of-the-ms-gill-precedent-statecraft.org"
                systemhalted-test-root))
         (record (systemhalted-read-record file 'post))
         (html (systemhalted-export-body record (list record))))
    (should (string-match-p
             (regexp-quote
              (concat "Read an article with the same title on "
                      "<a href=\"http://www.hindu.com/2008/04/08/stories/2008040854301000.htm\">"
                      "Hindu</a> by Harish Khare. Here is my opinion on the issue."))
             html))
    (should-not (string-match-p "class=\"html\"" html))
    (should-not (string-match-p "&lt;p&gt;" html))
    (should-not (string-match-p "&lt;/p&gt;" html))))

(ert-deftest systemhalted-lokpal-post-publishes-a-table-header-row ()
  "Task 14: the `/2011/01/28/' table needs a header rule so the bill columns
publish inside `<thead>', the way the live table does."
  (let* ((file (expand-file-name "org/posts/2011-01-28-lokpal-bill.org"
                                 systemhalted-test-root))
         (record (systemhalted-read-record file 'post))
         (html (systemhalted-export-body record (list record))))
    (should (string-match-p "<thead>" html))
    (should (string-match-p "<th" html))
    (should (string-match-p "<strong>Government bill</strong>" html))
    (should (string-match-p "<strong>Civil society bill</strong>" html))))

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

(ert-deftest systemhalted-render-page-nests-post-nav-inside-post-more-section ()
  "Task 12: matching `main:_layouts/post.html', `nav.post-nav' must render
*inside* `section.post-more', after the related list, under a single
\"More from SystemHalted\" heading, not as a sibling section."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (record (seq-find
                  (lambda (item)
                    (equal (systemhalted-record-title item) "Rich & Structured"))
                  records))
         (html (systemhalted-render-page record records)))
    (should (= 1 (with-temp-buffer (insert html)
                                    (how-many "class=\"post-more\"" (point-min) (point-max)))))
    (should (= 1 (with-temp-buffer (insert html)
                                    (how-many "post-more-heading" (point-min) (point-max)))))
    ;; The related list and the nav must both fall inside the single
    ;; post-more section, in that order, before its closing tag.
    (should (string-match-p
             (concat "<section class=\"post-more\"[^>]*>.*?"
                     "<h2 id=\"more-writing-heading\" class=\"post-more-heading\">"
                     "More from SystemHalted</h2>.*?"
                     "<ul class=\"related-posts\">.*?</ul>.*?"
                     "<nav class=\"post-nav\"[^>]*>.*?</nav>.*?</section>")
             html))))

(ert-deftest systemhalted-render-page-post-more-section-renders-nav-only-when-no-related ()
  "A post whose category and tags match nothing else still gets its
post-more section (for the newer/older nav), but without a related-posts
list, matching main's independent `top_related_keys.size >= 1 or prev_post
or next_post' guard."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (record (seq-find
                  (lambda (item)
                    (equal (systemhalted-record-title item) "Legacy Permalink"))
                  records))
         (html (systemhalted-render-page record records)))
    (should (string-match-p "class=\"post-more\"" html))
    (should (string-match-p "class=\"post-nav" html))
    (should-not (string-match-p "class=\"related-posts\"" html))))

(ert-deftest systemhalted-render-page-omits-post-more-section-with-no-related-or-nav ()
  "A lone post with no siblings must render no post-more section at all."
  (let* ((record (seq-find
                  (lambda (item)
                    (equal (systemhalted-record-title item) "Legacy Permalink"))
                  (systemhalted-load-records systemhalted-test-fixtures
                                             :include-drafts t
                                             :include-future t)))
         (html (systemhalted-render-page record (list record))))
    (should-not (string-match-p "class=\"post-more\"" html))))

(ert-deftest systemhalted-related-html-labels-more-from-rarest-shared-category ()
  "Task 12: the related-post reason must be \"More from <category>\", using
whichever shared category has the fewest posts site-wide, not simply the
first category the page happens to list."
  (let* ((records (systemhalted-load-records systemhalted-test-fixtures
                                              :include-drafts t
                                              :include-future t))
         (record (seq-find
                  (lambda (item)
                    (equal (systemhalted-record-title item) "Rich & Structured"))
                  records))
         (html (systemhalted-render-page record records)))
    ;; "Emacs" (2 posts site-wide) is rarer than "Software Engineering"
    ;; (4 posts site-wide), even though "Software Engineering" comes first
    ;; in the page's own #+CATEGORIES order.
    (should (string-match-p
             (concat "<a class=\"related-post-title\" href=\"[^\"]*\">Derived Route</a>"
                     "<span class=\"related-post-reason\">More from Emacs</span>")
             html))
    (should (string-match-p
             (concat "<a class=\"related-post-title\" href=\"[^\"]*\">Related Publishing Post</a>"
                     "<span class=\"related-post-reason\">More from Software Engineering</span>")
             html))
    (should (string-match-p
             (concat "<a class=\"related-post-title\" href=\"[^\"]*\">Disjunctive Types</a>"
                     "<span class=\"related-post-reason\">More from Software Engineering</span>")
             html))))

(defun systemhalted-test--make-record (title date categories tags)
  "Build a minimal post record for related-post unit tests."
  (make-systemhalted-record
   :kind 'post :title title :description title :date date
   :categories categories :tags tags
   :route (format "/test/%s/" (systemhalted--slugify title))))

(ert-deftest systemhalted-related-records-scores-sibling-theme-category-bonus ()
  "Task 12: with no shared category or tag, a candidate in the same
taxonomy theme must still score +1 per sibling category shared, while a
candidate outside every matched theme must score 0 and be excluded."
  (let* ((themes (list (list :id "theme" :title "Theme" :description ""
                              :categories (list (list :name "Alpha" :description "")
                                                 (list :name "Beta" :description "")
                                                 (list :name "Gamma" :description "")))))
         (date (encode-time 0 0 0 1 1 2026 t))
         (record (systemhalted-test--make-record "Page" date '("Alpha") '("x")))
         (sibling (systemhalted-test--make-record
                   "Sibling" (encode-time 0 0 0 2 1 2026 t) '("Beta") '("y")))
         (outsider (systemhalted-test--make-record
                    "Outsider" (encode-time 0 0 0 3 1 2026 t) '("Zeta") '("z")))
         (related (systemhalted--related-records record (list record sibling outsider) themes)))
    (should (equal (mapcar #'systemhalted-record-title related) '("Sibling")))))

(ert-deftest systemhalted-related-records-sibling-bonus-outranks-recency ()
  "More matching sibling categories must outrank a single sibling match even
when the single-match candidate is newer, proving the bonus is additive
per matched sibling and not a flat +1."
  (let* ((themes (list (list :id "theme" :title "Theme" :description ""
                              :categories (list (list :name "Alpha" :description "")
                                                 (list :name "Beta" :description "")
                                                 (list :name "Gamma" :description "")))))
         (record (systemhalted-test--make-record
                  "Page" (encode-time 0 0 0 10 1 2026 t) '("Alpha") nil))
         (two-siblings (systemhalted-test--make-record
                        "Two Siblings" (encode-time 0 0 0 1 1 2026 t) '("Beta" "Gamma") nil))
         (one-sibling-newer (systemhalted-test--make-record
                             "One Sibling" (encode-time 0 0 0 9 1 2026 t) '("Beta") nil))
         (related (systemhalted--related-records
                   record (list record two-siblings one-sibling-newer) themes)))
    (should (equal (mapcar #'systemhalted-record-title related)
                   '("Two Siblings" "One Sibling")))))

(ert-deftest systemhalted-related-reason-picks-rarest-shared-category ()
  "Task 12: `systemhalted--related-reason' must pick the shared category with
the fewest site-wide posts, even when a commoner shared category is listed
first in the page's own #+CATEGORIES order."
  (let ((counts (make-hash-table :test #'equal))
        (record (systemhalted-test--make-record
                 "Page" (encode-time 0 0 0 1 1 2026 t) '("Alpha" "Beta") nil))
        (related (systemhalted-test--make-record
                  "Related" (encode-time 0 0 0 2 1 2026 t) '("Alpha" "Beta") nil)))
    (puthash "Alpha" 5 counts)
    (puthash "Beta" 2 counts)
    (should (equal (systemhalted--related-reason record related counts)
                   "More from Beta"))))

(ert-deftest systemhalted-related-reason-falls-back-to-last-shared-tag-in-page-order ()
  "Task 12: with no shared category, the reason must be \"Also about <tag>\"
using the *last* shared tag in the page's own #+TAGS order."
  (let ((counts (make-hash-table :test #'equal))
        (record (systemhalted-test--make-record
                 "Page" (encode-time 0 0 0 1 1 2026 t) '("Alpha") '("t1" "t2" "t3")))
        (related (systemhalted-test--make-record
                  "Related" (encode-time 0 0 0 2 1 2026 t) '("Zeta") '("t1" "t3"))))
    (should (equal (systemhalted--related-reason record related counts)
                   "Also about t3"))))

(ert-deftest systemhalted-related-reason-falls-back-to-related-reading ()
  "Task 12: with nothing shared (a sibling-theme-only match), the reason
must fall back to \"Related reading\"."
  (let ((counts (make-hash-table :test #'equal))
        (record (systemhalted-test--make-record
                 "Page" (encode-time 0 0 0 1 1 2026 t) '("Alpha") '("t1")))
        (related (systemhalted-test--make-record
                  "Related" (encode-time 0 0 0 2 1 2026 t) '("Zeta") '("z9"))))
    (should (equal (systemhalted--related-reason record related counts)
                   "Related reading"))))

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
  "The jsgames and wireframes static pages -- and, since Task 11, the
generated `/jsgames/' index itself -- have no Org record of their own, but
live's sitemap lists them, so ours must too."
  (let ((output (make-temp-file "systemhalted-sitemap-static-" t)))
    (unwind-protect
        (progn
          (systemhalted-build-site :root systemhalted-test-root :output output)
          (with-temp-buffer
            (insert-file-contents (expand-file-name "sitemap.xml" output))
            (let ((xml (buffer-string)))
              (dolist (route '("/jsgames/" "/jsgames/guess-number/" "/jsgames/pig-game/"
                               "/jsgames/reeti-40/"
                               "/wireframes/systemhalted-writing-first.html"))
                ;; An exact `<loc>' match, not a substring: "/jsgames/" is
                ;; itself a substring of "/jsgames/pig-game/" and would
                ;; false-pass even if the index route were missing.
                (should (string-match-p
                         (concat "<loc>" (regexp-quote (concat systemhalted-site-url route))
                                 "</loc>")
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
      (should (search-forward "src=\"/assets/js/webcmd.js?v=" nil t)))))

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
  "About and Projects must carry the quiet page title, matching live's
`page-title-quiet' class."
  (dolist (relative '("org/pages/about.org" "org/pages/projects.org"))
    (let* ((record (systemhalted-read-record
                    (expand-file-name relative systemhalted-test-root) 'page))
           (html (systemhalted-render-page record)))
      (should (string-match-p "class=\"page-title page-title-quiet\"" html))))
  (systemhalted-test-with-built-site
    (dolist (relative '("archives/index.html" "categories/index.html"
                        "tags/index.html" "emacs/index.html" "jsgames/index.html"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name relative output))
        (should (string-match-p "class=\"page-title page-title-quiet\""
                                (buffer-string)))))))

(ert-deftest systemhalted-hidden-title-pages-omit-page-title ()
  "Themes and Webcmd must hide the page.html title entirely, matching live's
`hide_page_title' (Themes) and `layout: default' (Webcmd, which skips
page.html altogether)."
  (systemhalted-test-with-built-site
    (dolist (relative '("themes/index.html" "webcmd/index.html"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name relative output))
        (should-not (string-match-p "page-title"
                                    (systemhalted-test-main-html (buffer-string))))))))

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

(ert-deftest systemhalted-webcmd-page-matches-live-markup ()
  "`/webcmd/' must restore the full `section.webcmd > div.webcmd-shell'
markup from `main:webcmd/index.html', with `elasticlunr.min.js' and a
cache-busted `webcmd.js' loaded only on this page."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "webcmd/index.html" output))
      (let ((html (buffer-string)))
        (dolist (fragment '("<section class=\"webcmd\" aria-labelledby=\"webcmd-title\">"
                            "<div class=\"webcmd-shell\">"
                            "<p class=\"webcmd-kicker\">Webcmd</p>"
                            "id=\"webcmd-title\" class=\"webcmd-title\""
                            "id=\"webcmd-form\" class=\"webcmd-form\""
                            "<div id=\"help\" class=\"webcmd-help-panel\" hidden></div>"
                            "<footer class=\"webcmd-footer\">"
                            "<script src=\"/assets/js/elasticlunr.min.js\"></script>"))
          (should (string-match-p (regexp-quote fragment) html)))
        (should (string-match-p
                 "<script src=\"/assets/js/webcmd\\.js\\?v=[^\"]+\"></script>" html))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "about/index.html" output))
      (should-not (string-match-p "webcmd\\.js\\|elasticlunr" (buffer-string))))))

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

(ert-deftest systemhalted-tags-page-ids-reuses-tag-ids-over-posts-only ()
  "`systemhalted--tags-page-ids' must group tags the same way
`systemhalted--generate-tags' does -- from posts only, sorted, with
`systemhalted--tag-ids' collision suffixes -- so an Emacs note's own tag
links can resolve to the exact anchor `/tags/' renders."
  (let* ((make (lambda (tags)
                 (make-systemhalted-record
                  :source "<test>" :kind 'post :title "T" :description "d"
                  :date (encode-time 0 0 0 1 1 2026) :tags tags :route "/t/")))
         (posts (list (funcall make '("Zeta" "api-design"))
                     (funcall make '("API Design")))))
    (should (equal (systemhalted--tags-page-ids posts)
                   '(("API Design" . "api-design") ("Zeta" . "zeta")
                     ("api-design" . "api-design--3"))))))

(ert-deftest systemhalted-emacs-note-tags-html-resolves-live-tags-anchors-and-falls-back ()
  "An Emacs note's `div.post-tags' links must resolve to the exact `--N'
suffixed anchor id `/tags/' renders for a tag shared with posts, and fall
back to a plain slug -- the same dead anchor live's own `{{ tag | slugify
}}' produces -- for a tag no post uses at all."
  (let ((ids (systemhalted--tag-ids '("API Design" "api-design"))))
    (should (equal (systemhalted--emacs-note-tags-html '("api-design" "Solo Tag") ids)
                   (concat "<div class=\"post-tags\">"
                           "<a href=\"/tags/#api-design--2\">api-design</a>&nbsp;"
                           "<a href=\"/tags/#solo-tag\">Solo Tag</a></div>"))))
  (should-not (systemhalted--emacs-note-tags-html nil nil)))

(ert-deftest systemhalted-emacs-note-rendering-uses-newsletter-classes-and-tags ()
  "An Emacs note must render with `p.newsletter-kicker'/`h1.newsletter-title'
(not the retired `note-kicker'/`emacs-note-title'), and its `div.post-tags'
must be present when it carries tags, matching `main:_layouts/emacs.html'."
  (let* ((post (make-systemhalted-record
                :source "<test>" :kind 'post :title "Post" :description "d"
                :date (encode-time 0 0 0 1 1 2026) :tags '("emacs") :route "/p/"))
         (note (make-systemhalted-record
                :source "<test>" :kind 'emacs :title "A Note" :description "d"
                :tags '("emacs" "solo") :route "/emacs/a-note/"))
         (html (systemhalted-render-page note (list note post) "<p>Body</p>")))
    (should (string-match-p "<p class=\"newsletter-kicker\">Emacs note</p>" html))
    (should (string-match-p "<h1 class=\"newsletter-title\">A Note</h1>" html))
    (should-not (string-match-p "note-kicker\\|emacs-note-title" html))
    (should (string-match-p
             (regexp-quote "<a href=\"/tags/#emacs\">emacs</a>") html))
    (should (string-match-p
             (regexp-quote "<a href=\"/tags/#solo\">solo</a>") html))))

(ert-deftest systemhalted-jsgame-list-item-matches-live-shape ()
  "A JS-game entry must render the same `post-feed-item' shape as
`main:_includes/jsgame-list-item.html': a `post-feed-cat' of \"JS Game\", not
Emacs note's or the newsletter's own category text."
  (should (equal (systemhalted--jsgame-list-item
                  '(:title "Pig Game" :url "/jsgames/pig-game/"
                    :description "Roll the dice."))
                 (concat "<li class=\"post-feed-item\">"
                         "<div class=\"post-feed-meta\">"
                         "<span class=\"post-feed-cat\">JS Game</span></div>"
                         "<h2 class=\"post-feed-title\">"
                         "<a href=\"/jsgames/pig-game/\">Pig Game</a></h2>"
                         "<p class=\"post-feed-excerpt\">Roll the dice.</p></li>"))))

(ert-deftest systemhalted-read-jsgames-parses-live-data ()
  "`systemhalted--read-jsgames' must parse every `* [[URL][TITLE]]' entry in
`org/data/jsgames.org' plus its description paragraph, in file order,
mirroring `main:_data/jsgames.yml'."
  (let ((games (systemhalted--read-jsgames systemhalted-test-root)))
    (should (equal (mapcar (lambda (g) (plist-get g :title)) games)
                   '("Pig Game" "Guess the Number" "Reeti @ 40")))
    (should (equal (plist-get (car games) :url) "/jsgames/pig-game/"))
    (should (plist-get (car games) :description))))

(ert-deftest systemhalted-read-themes-parses-live-data-with-image-and-tags ()
  "`systemhalted--read-themes' must parse each theme's name, version, image,
and tag list from `org/data/themes.org', mirroring `main:_data/themes.yml'."
  (let* ((themes (systemhalted--read-themes systemhalted-test-root))
         (first (car themes)))
    (should (equal (mapcar (lambda (t) (plist-get t :name)) themes)
                   '("System Halted" "Nord Newsletter" "Midnight Mountains")))
    (should (equal (plist-get first :version) "1.0.1"))
    (should (equal (plist-get first :image) "/assets/images/themes/systemhalted.png"))
    (should (equal (plist-get first :tags) '("blog" "search" "dark mode")))
    (should (equal (plist-get first :gem) "jekyll-theme-systemhalted"))
    (should (equal (plist-get first :demo)
                   "https://systemhalted.in/jekyll-theme-systemhalted/"))))

(ert-deftest systemhalted-theme-card-html-matches-live-shape ()
  "A theme card must render every field `main:themes.html's `theme-card'
does: shot, name, version, description, tags, install snippet, and links."
  (let ((html (systemhalted--theme-card-html
               '(:name "Nord" :version "0.1.0" :description "Desc."
                 :image "/x.png" :tags ("a" "b") :gem "jekyll-theme-nord"
                 :demo "https://d" :repo "https://r" :rubygems "https://g"))))
    (dolist (fragment '("<li class=\"theme-card\">"
                        "<a class=\"theme-shot\" href=\"https://d\">"
                        "<img src=\"/x.png\" alt=\"Screenshot of the Nord Jekyll theme\""
                        "<h2 class=\"theme-name\">Nord <span class=\"theme-version\">v0.1.0</span></h2>"
                        "<p class=\"theme-desc\">Desc.</p>"
                        "<ul class=\"theme-tags\"><li>a</li><li>b</li></ul>"
                        "<code>gem install jekyll-theme-nord</code>"
                        "<a href=\"https://r\">GitHub</a>"
                        "<a href=\"https://g\">RubyGems</a>"))
      (should (string-match-p (regexp-quote fragment) html)))))

(ert-deftest systemhalted-generate-jsgames-and-themes-pages-match-live-shape ()
  "`/jsgames/' and `/themes/' must be generated pages built from
`org/data/jsgames.org'/`org/data/themes.org', matching
`main:jsgames/index.html' and `main:themes.html': the post-feed/jsgame-list
markup, the theme gallery with its inline style block, and the site's
default description for `/themes/' (which sets no `description:' front
matter on main)."
  (systemhalted-test-with-built-site
    (with-temp-buffer
      (insert-file-contents (expand-file-name "jsgames/index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p "<ul class=\"post-feed jsgame-list\">" html))
        (should (string-match-p "<span class=\"post-feed-cat\">JS Game</span>" html))
        (should (string-match-p
                 (regexp-quote "og:description\" content=\"Small browser games and interactive experiments built with vanilla JavaScript.")
                 html))))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "themes/index.html" output))
      (let ((html (buffer-string)))
        (should (string-match-p "<section class=\"newsletter-hero\">" html))
        (should (string-match-p "<ul class=\"theme-gallery\">" html))
        (should (string-match-p "<li class=\"theme-card\">" html))
        (should (string-match-p "<style>[[:space:]]*\\.theme-gallery {" html))
        (should (string-match-p
                 (regexp-quote (concat "og:description\" content=\"" systemhalted-site-description))
                 html))))))

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
