;;; test-eww-rendering.el --- Check the site in Emacs SHR -*- lexical-binding: t; -*-

(require 'shr)

(defun systemhalted-test--render-html (file)
  "Render FILE with the same SHR library used by EWW."
  (let ((dom (with-temp-buffer
               (insert-file-contents file)
               (libxml-parse-html-region (point-min) (point-max))))
        (shr-discard-aria-hidden nil)
        (shr-inhibit-images t)
        (shr-use-fonts nil)
        (shr-width 100))
    (with-temp-buffer
      (shr-insert-document dom)
      (buffer-substring-no-properties (point-min) (point-max)))))

(defun systemhalted-test--assert-contains (rendered text)
  "Fail unless RENDERED contains TEXT."
  (unless (string-match-p (regexp-quote text) rendered)
    (error "Expected EWW output to contain %S" text)))

(defun systemhalted-test--assert-omits (rendered text)
  "Fail when RENDERED contains TEXT."
  (when (string-match-p (regexp-quote text) rendered)
    (error "Expected EWW output to omit %S" text)))

(let* ((file (or (car command-line-args-left) "_site/index.html"))
       (rendered (systemhalted-test--render-html file)))
  (systemhalted-test--assert-contains rendered "SystemHalted")
  (systemhalted-test--assert-contains rendered "Writing")
  (systemhalted-test--assert-contains rendered "Projects")
  (systemhalted-test--assert-contains rendered "Archive")
  (systemhalted-test--assert-contains rendered "About")
  (systemhalted-test--assert-contains rendered "Recent writing")
  (systemhalted-test--assert-contains rendered "RSS")
  (systemhalted-test--assert-omits rendered "Search all writing")
  (systemhalted-test--assert-omits rendered "Show this help")
  (message "EWW rendering check passed: %s" file))

;;; test-eww-rendering.el ends here
