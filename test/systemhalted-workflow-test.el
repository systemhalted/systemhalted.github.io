;;; systemhalted-workflow-test.el --- Tests for interactive publishing -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'url)

(defconst systemhalted-workflow-test-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name)))))

(add-to-list 'load-path (expand-file-name "publish" systemhalted-workflow-test-root))
(ignore-errors (require 'systemhalted-workflow))

(ert-deftest systemhalted-new-post-creates-dated-org-draft ()
  "A new article starts as an Org draft with the required metadata."
  (let ((root (make-temp-file "systemhalted-authoring-" t))
        buffer)
    (unwind-protect
        (let ((systemhalted-root-directory root))
          (setq buffer (systemhalted-new-post "Hello, Org World!" "A useful description."))
          (let ((file (buffer-file-name buffer)))
            (should (string-match-p
                     (format "/org/drafts/%s-hello-org-world\\.org\\'"
                             (format-time-string "%Y-%m-%d"))
                     file))
            (with-temp-buffer
              (insert-file-contents file)
              (should (search-forward "#+TITLE: Hello, Org World!" nil t))
              (should (search-forward "#+DESCRIPTION: A useful description." nil t))
              (should (search-forward "#+DRAFT: true" nil t)))))
      (when (buffer-live-p buffer) (kill-buffer buffer))
      (delete-directory root t))))

(ert-deftest systemhalted-build-uses-production-visibility ()
  "The production command must omit drafts and future posts."
  (let ((root (make-temp-file "systemhalted-build-root-" t))
        captured)
    (unwind-protect
        (let ((systemhalted-root-directory root)
              (systemhalted-output-directory (expand-file-name "public" root)))
          (cl-letf (((symbol-function 'systemhalted-build-site)
                     (lambda (&rest arguments) (setq captured arguments) "built")))
            (should (equal (systemhalted-build) "built"))
            (should (equal (plist-get captured :root) root))
            (should-not (plist-get captured :include-drafts))
            (should-not (plist-get captured :include-future))))
      (delete-directory root t))))

(ert-deftest systemhalted-preview-saves-builds-and-opens-source-route ()
  "Preview should save the source, include hidden content, and open its route."
  (let* ((root (make-temp-file "systemhalted-preview-root-" t))
         (draft-dir (expand-file-name "org/drafts" root))
         (file (expand-file-name "2026-09-25-preview-me.org" draft-dir))
         captured opened buffer)
    (unwind-protect
        (progn
          (make-directory draft-dir t)
          (with-temp-file file
            (insert "#+TITLE: Preview me\n#+DESCRIPTION: Preview route.\n"
                    "#+DATE: 2026-09-25\n#+DRAFT: true\n\nOriginal.\n"))
          (setq buffer (find-file-noselect file))
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert "Saved.\n")
            (let ((systemhalted-root-directory root)
                  (systemhalted-output-directory (expand-file-name "public" root)))
              (cl-letf (((symbol-function 'systemhalted-build-site)
                         (lambda (&rest arguments) (setq captured arguments)))
                        ((symbol-function 'systemhalted-start-preview-server)
                         (lambda () 4567))
                        ((symbol-function 'browse-url)
                         (lambda (url &rest _) (setq opened url))))
                (systemhalted-preview))))
          (should-not (buffer-modified-p buffer))
          (should (plist-get captured :include-drafts))
          (should (plist-get captured :include-future))
          (should (equal opened "http://127.0.0.1:4567/2026/09/25/preview-me/")))
      (when (buffer-live-p buffer) (kill-buffer buffer))
      (delete-directory root t))))

(ert-deftest systemhalted-start-preview-server-reuses-live-server ()
  "Repeated previews should keep one server and one stable port."
  (let ((systemhalted-preview-process 'existing)
        (systemhalted-preview-port 4123)
        created)
    (cl-letf (((symbol-function 'process-live-p) (lambda (_) t))
              ((symbol-function 'make-network-process)
               (lambda (&rest _) (setq created t) 'new)))
      (should (= (systemhalted-start-preview-server) 4123))
      (should-not created))))

(ert-deftest systemhalted-preview-server-serves-generated-files ()
  "The built-in server should return the generated site over HTTP."
  (let ((output (make-temp-file "systemhalted-http-" t))
        (systemhalted-preview-process nil)
        (systemhalted-preview-active-port nil)
        (systemhalted-preview-port 0)
        response)
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "index.html" output)
            (insert "<!doctype html><title>Preview works</title>"))
          (let ((systemhalted-output-directory output))
            (let ((port (systemhalted-start-preview-server)))
              (setq response
                    (url-retrieve-synchronously
                     (format "http://127.0.0.1:%d/" port) t t 3))))
          (should (buffer-live-p response))
          (with-current-buffer response
            (goto-char (point-min))
            (should (search-forward "200 OK" nil t))
            (should (search-forward "Preview works" nil t))))
      (when (buffer-live-p response) (kill-buffer response))
      (systemhalted-stop-preview-server)
      (delete-directory output t))))

(ert-deftest systemhalted-publish-hands-off-to-magit-without-git-mutation ()
  "Publish validates the site, then opens Magit without staging or committing."
  (let ((root (make-temp-file "systemhalted-publish-root-" t))
        built magit-root)
    (unwind-protect
        (let ((systemhalted-root-directory root))
          (cl-letf (((symbol-function 'systemhalted-build)
                     (lambda () (setq built t)))
                    ((symbol-function 'magit-status)
                     (lambda (directory) (setq magit-root directory))))
            (systemhalted-publish)
            (should built)
            (should (equal magit-root root))))
      (delete-directory root t))))

(ert-deftest systemhalted-publish-falls-back-to-vc-dir ()
  "A stock Emacs without Magit should still open version-control status."
  (let ((root (make-temp-file "systemhalted-vc-root-" t))
        vc-root)
    (unwind-protect
        (let ((systemhalted-root-directory root))
          (cl-letf (((symbol-function 'systemhalted-build) #'ignore)
                    ((symbol-function 'fboundp)
                     (lambda (symbol) (not (eq symbol 'magit-status))))
                    ((symbol-function 'vc-dir)
                     (lambda (directory) (setq vc-root directory))))
            (systemhalted-publish)
            (should (equal vc-root root))))
      (delete-directory root t))))

(provide 'systemhalted-workflow-test)
;;; systemhalted-workflow-test.el ends here
