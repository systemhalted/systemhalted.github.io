;;; site-config.el --- Stable SystemHalted site settings -*- lexical-binding: t; -*-

(defconst systemhalted-site-title "SystemHalted.in")
(defconst systemhalted-site-brand "SystemHalted")
(defconst systemhalted-site-url "https://systemhalted.in")
(defconst systemhalted-site-description
  "The personal blog of Palak Mathur, covering software engineering, leadership, management, and Emacs.")
(defconst systemhalted-site-author "Palak Mathur")
(defconst systemhalted-site-email "insanethoughts@live.com")
(defconst systemhalted-static-paths
  '("assets" "jsgames" "favicon.ico" "CNAME"
    "49a459d211088e5e423d87c0e7053c26.txt"))
(defconst systemhalted-legacy-redirects
  '(("/2025/11/25/disjuntive-types/" . "/2025/11/25/disjunctive-types/")))
(defvar systemhalted-page-size 10)

(provide 'site-config)
;;; site-config.el ends here
