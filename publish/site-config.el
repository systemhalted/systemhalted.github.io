;;; site-config.el --- Stable SystemHalted site settings -*- lexical-binding: t; -*-

(defconst systemhalted-site-title "SystemHalted.in")
(defconst systemhalted-site-brand "SystemHalted")
(defconst systemhalted-site-url "https://systemhalted.in")
(defconst systemhalted-site-description
  "SystemHalted is the personal blog of Palak Mathur, covering software engineering, leadership, management, and Emacs, plus the Kartavya Path newsletter.")
(defconst systemhalted-site-author "Palak Mathur")
(defconst systemhalted-site-email "insanethoughts@live.com")
(defconst systemhalted-social-links
  '("https://github.com/systemhalted"
    "https://www.linkedin.com/in/systemhalted/"
    "https://palakmathur.substack.com")
  "Social profile URLs, matching main's `_config.yml' `social.links'.
Used as JSON-LD `sameAs' on the Person node.")
(defconst systemhalted-google-analytics-id "UA-36868278-1"
  "Google Analytics property id, matching main's `_config.yml' `google_analytics_id'.")
(defconst systemhalted-google-site-verification
  "1v5ZSlWxFB06EQ-VB5U4n3226XFqq3ki9qusVH2m0K8"
  "Google Search Console verification token, matching main's `_config.yml'
`google_site_verification'.")
(defconst systemhalted-generator "SystemHalted static site (Emacs Lisp)"
  "Value of the `generator' meta tag.")
(defconst systemhalted-static-paths
  '("assets" "jsgames" "wireframes" "favicon.ico" "CNAME"
    "49a459d211088e5e423d87c0e7053c26.txt"))
(defconst systemhalted-legacy-redirects
  '(("/2025/11/25/disjuntive-types/" . "/2025/11/25/disjunctive-types/")))
(defvar systemhalted-page-size 10)

(provide 'site-config)
;;; site-config.el ends here
