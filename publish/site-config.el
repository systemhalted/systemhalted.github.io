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
(defconst systemhalted-page-size 10
  "A `defconst', not a `defvar': `systemhalted-reload-site-config' re-`load's
this file to pick up edited values, and `load' only re-runs top-level
forms; a `defvar' would leave the first-loaded value in place forever
since `defvar' never re-sets an already-bound variable, while `defconst'
always does.")
(defconst systemhalted-newsletter-cta-title "Kartavya Path"
  "Kartavya Path newsletter title, matching main's `_config.yml'
`newsletter_cta.title'. Used by the `/kartavya-path/' landing page and the
newsletter CTA aside shown there.")
(defconst systemhalted-newsletter-cta-lede
  "A note on leadership, management, and the long road. Free, occasional, no spam."
  "Kartavya Path newsletter lede, matching main's `_config.yml'
`newsletter_cta.lede'.")
(defconst systemhalted-newsletter-cta-linkedin-url
  "https://www.linkedin.com/newsletters/kartavya-path-path-of-duty-7211363300905738240"
  "Kartavya Path LinkedIn newsletter URL, matching main's `_config.yml'
`newsletter_cta.linkedin_url'.")

(provide 'site-config)
;;; site-config.el ends here
