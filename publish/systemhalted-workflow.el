;;; systemhalted-workflow.el --- Author and publish SystemHalted from Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; Interactive commands for writing, previewing, validating, and handing a
;; completed publication to the user's normal version-control interface.

;;; Code:

(require 'browse-url)
(require 'subr-x)
(require 'url-util)

(defconst systemhalted-workflow-directory
  (file-name-directory (or load-file-name buffer-file-name)))

(require 'systemhalted-publish
         (expand-file-name "systemhalted-publish" systemhalted-workflow-directory))

(defgroup systemhalted nil
  "Org-first publishing for SystemHalted."
  :group 'org)

(defcustom systemhalted-root-directory
  (file-name-directory (directory-file-name systemhalted-workflow-directory))
  "Repository root used by interactive publishing commands."
  :type 'directory)

(defcustom systemhalted-output-directory
  (expand-file-name "_site" systemhalted-root-directory)
  "Generated site directory."
  :type 'directory)

(defcustom systemhalted-preview-port 4000
  "TCP port for the local preview server.
Set this to zero to ask the operating system for an available port."
  :type 'integer)

(defvar systemhalted-preview-process nil
  "Network server process used by `systemhalted-preview'.")

(defvar systemhalted-preview-active-port nil
  "Actual port used by `systemhalted-preview-process'.")

(defun systemhalted--authoring-slug (title)
  "Return a filename-safe slug for TITLE."
  (let ((slug (downcase (string-trim title))))
    (setq slug (replace-regexp-in-string "[^[:alnum:]]+" "-" slug))
    (string-trim slug "-+" "-+")))

(defun systemhalted-new-post (title description)
  "Create a dated Org draft for TITLE with DESCRIPTION.
Interactively, prompt for both required values. Return the visiting buffer."
  (interactive (list (read-string "Title: ")
                     (read-string "Description: ")))
  (when (string-empty-p (string-trim title))
    (user-error "A post title is required"))
  (when (string-empty-p (string-trim description))
    (user-error "A post description is required"))
  (let* ((date (format-time-string "%Y-%m-%d"))
         (slug (systemhalted--authoring-slug title))
         (directory (expand-file-name "org/drafts" systemhalted-root-directory))
         (file (expand-file-name (format "%s-%s.org" date slug) directory)))
    (when (file-exists-p file)
      (user-error "Draft already exists: %s" file))
    (make-directory directory t)
    (let ((coding-system-for-write 'utf-8-unix))
      (with-temp-file file
        (insert (format (concat "#+TITLE: %s\n#+DESCRIPTION: %s\n"
                                "#+DATE: %s\n#+CATEGORIES: \n#+TAGS: \n"
                                "#+DRAFT: true\n\n")
                        title description date))))
    (let ((buffer (find-file-noselect file)))
      (when (called-interactively-p 'interactive)
        (switch-to-buffer buffer)
        (goto-char (point-max)))
      buffer)))

(defun systemhalted-build ()
  "Build and validate the production site, excluding drafts and future posts.
Re-reads `site-config.el' first, so a session that already loaded the
publisher still picks up an edited setting without restarting Emacs."
  (interactive)
  (systemhalted-reload-site-config)
  (let ((result (systemhalted-build-site
                 :root systemhalted-root-directory
                 :output systemhalted-output-directory)))
    (when (called-interactively-p 'interactive)
      (message "Built %s" result))
    result))

(defun systemhalted--source-kind (file)
  "Return the content kind represented by FILE."
  (cond
   ((string-match-p "/org/drafts/" file) 'draft)
   ((string-match-p "/org/posts/" file) 'post)
   ((string-match-p "/org/emacs/" file) 'emacs)
   ((string-match-p "/org/pages/" file) 'page)
   (t nil)))

(defun systemhalted--preview-route ()
  "Return the route for the current Org source, or the home route."
  (let* ((file (buffer-file-name))
         (kind (and file (systemhalted--source-kind (expand-file-name file)))))
    (if kind
        (systemhalted-record-route (systemhalted-read-record file kind))
      "/")))

(defun systemhalted--preview-target (request-path)
  "Resolve REQUEST-PATH safely below `systemhalted-output-directory'."
  (let* ((path (decode-coding-string
                (url-unhex-string (car (split-string request-path "[?#]")))
                'utf-8))
         (relative (string-remove-prefix "/" path)))
    (when (or (string-match-p "\\(?:^\\|/\\)\\.\\.?\\(?:/\\|$\\)" relative)
              (file-name-absolute-p relative))
      (user-error "Unsafe preview path"))
    (let ((target (expand-file-name relative systemhalted-output-directory)))
      (if (or (string-empty-p relative) (string-suffix-p "/" path))
          (expand-file-name "index.html" target)
        target))))

(defun systemhalted--mime-type (file)
  "Return a useful response content type for FILE."
  (pcase (downcase (or (file-name-extension file) ""))
    ((or "html" "htm") "text/html; charset=utf-8")
    ("css" "text/css; charset=utf-8")
    ("js" "text/javascript; charset=utf-8")
    ((or "xml" "rss") "application/xml; charset=utf-8")
    ("json" "application/json; charset=utf-8")
    ("svg" "image/svg+xml")
    ("png" "image/png")
    ((or "jpg" "jpeg") "image/jpeg")
    ("gif" "image/gif")
    ("ico" "image/x-icon")
    (_ "application/octet-stream")))

(defun systemhalted--preview-response (status content-type body)
  "Return an HTTP response with STATUS, CONTENT-TYPE, and BODY."
  (let ((header (format (concat "HTTP/1.1 %s\r\nContent-Type: %s\r\n"
                                "Content-Length: %d\r\nConnection: close\r\n\r\n")
                        status content-type (string-bytes body))))
    (concat (encode-coding-string header 'utf-8) body)))

(defun systemhalted--preview-filter (process chunk)
  "Serve one HTTP request received as CHUNK on PROCESS."
  (let ((request (concat (or (process-get process 'request) "") chunk)))
    (process-put process 'request request)
    (when (string-match-p "\r?\n\r?\n" request)
      (let ((response
             (condition-case nil
                 (if (string-match "\\`GET[ \t]+\\([^ \t\r\n]+\\)" request)
                     (let ((target (systemhalted--preview-target
                                    (match-string 1 request))))
                       (if (and (file-regular-p target)
                                (file-in-directory-p
                                 target (expand-file-name systemhalted-output-directory)))
                           (let ((body (with-temp-buffer
                                         (set-buffer-multibyte nil)
                                         (insert-file-contents-literally target)
                                         (buffer-string))))
                             (systemhalted--preview-response
                              "200 OK" (systemhalted--mime-type target) body))
                         (systemhalted--preview-response
                          "404 Not Found" "text/plain; charset=utf-8"
                          (encode-coding-string "Not found\n" 'utf-8))))
                   (systemhalted--preview-response
                    "405 Method Not Allowed" "text/plain; charset=utf-8"
                    (encode-coding-string "Method not allowed\n" 'utf-8)))
               (error
                (systemhalted--preview-response
                 "400 Bad Request" "text/plain; charset=utf-8"
                 (encode-coding-string "Bad request\n" 'utf-8))))))
        (process-send-string process response)
        (delete-process process)))))

(defun systemhalted-start-preview-server ()
  "Start or reuse the local preview server and return its port."
  (if (and systemhalted-preview-process
           (process-live-p systemhalted-preview-process))
      (or systemhalted-preview-active-port systemhalted-preview-port)
    (setq systemhalted-preview-process
          (make-network-process
           :name "systemhalted-preview"
           :server t
           :host "127.0.0.1"
           :service systemhalted-preview-port
           :family 'ipv4
           :coding 'binary
           :noquery t
           :filter #'systemhalted--preview-filter))
    (setq systemhalted-preview-active-port
          (string-to-number
           (format "%s" (process-contact systemhalted-preview-process :service))))
    systemhalted-preview-active-port))

(defun systemhalted-stop-preview-server ()
  "Stop the local preview server if it is running."
  (interactive)
  (when (and systemhalted-preview-process
             (process-live-p systemhalted-preview-process))
    (delete-process systemhalted-preview-process))
  (setq systemhalted-preview-process nil
        systemhalted-preview-active-port nil))

(defun systemhalted-preview ()
  "Save the current source, build a preview, serve it, and open its URL.
Re-reads `site-config.el' first, so a session that already loaded the
publisher still picks up an edited setting without restarting Emacs."
  (interactive)
  (systemhalted-reload-site-config)
  (when (and (buffer-file-name) (buffer-modified-p))
    (save-buffer))
  (let ((route (systemhalted--preview-route)))
    (systemhalted-build-site
     :root systemhalted-root-directory
     :output systemhalted-output-directory
     :include-drafts t
     :include-future t)
    (let* ((port (systemhalted-start-preview-server))
           (url (format "http://127.0.0.1:%d%s" port route)))
      (browse-url url)
      url)))

(defun systemhalted-publish ()
  "Run production checks and open a version-control status buffer.
This command does not stage, commit, or push changes."
  (interactive)
  (systemhalted-build)
  (if (fboundp 'magit-status)
      (magit-status systemhalted-root-directory)
    (vc-dir systemhalted-root-directory)))

(defun systemhalted-batch-build ()
  "Batch entry point for a production build."
  (systemhalted-audit-content systemhalted-root-directory)
  (systemhalted-build))

(provide 'systemhalted-workflow)
;;; systemhalted-workflow.el ends here
