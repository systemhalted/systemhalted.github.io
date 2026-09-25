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
  "Ignoring PERMALINK would move legacy newsletter essays."
  (let ((record (systemhalted-read-record
                 (systemhalted-test-fixture "2024-07-19-legacy-permalink.org")
                 'post)))
    (should (equal (systemhalted-record-route record)
                   "/newsletter/2024-07-19-legacy-permalink/"))))

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

(provide 'systemhalted-publish-test)
;;; systemhalted-publish-test.el ends here

