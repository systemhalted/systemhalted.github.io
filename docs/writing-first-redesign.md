# Writing-first site architecture

The published site is generated from Org files by
`publish/systemhalted-publish.el`. Shared HTML lives in `publish/templates/`,
while `assets/css/nord.css` and `assets/js/script.js` provide the visual and
interactive layers. `_site/` is disposable output.

This document began with the writing-first redesign. The later Org-first
migration kept that interface and replaced the Jekyll build. The current
implementation is described below. The `jekyll-final` tag retains the last
Jekyll version for rollback and comparison.

## Interface structure

- `publish/templates/base.html` provides the masthead, primary navigation,
  search and shortcut dialogs, main landmark, and footer.
- `publish/templates/post.html` provides article metadata, an optional contents
  disclosure, prose, related entries, adjacent navigation, and comments.
- `publish/templates/page.html` provides the shell for generated indexes and
  authored pages.
- `publish/systemhalted-publish.el` generates `feed.xml`, `sitemap.xml`,
  `robots.txt`, `links.jsonp`, and `/assets/js/webcmd.js` directly.
- `publish/templates/webcmd.html` provides the `/webcmd/` markup.
  `publish/templates/webcmd-runtime.js` implements its commands and retains
  the public search globals.

## Design decisions

- The compact header links to Writing, About, Archive, and Projects, with
  search and a light/dark theme toggle beside them.
- The homepage uses `org/pages/index.org` for its hand-written sections. The
  publisher replaces its `<!--RECENT_POSTS-->` marker with the 10 most recent
  entries. Older entries are available through the pagination and archive
  routes.
- Article prose is the primary visual element. Taxonomy, related entries,
  adjacent navigation, and discussion links appear as quieter end matter.
- Archive, Categories, and Tags use direct date-and-title rows with disclosure
  sections where grouping helps navigation.
- Featured images are optional and appear after the prose. Long posts may opt
  into a collapsed contents disclosure.
- The footer contains copyright, durable links, and the credit “Proudly made
  with Emacs and Org mode.”
- Existing permalinks remain stable, including historical paths whose names no
  longer describe an active section of the site.

## Compatibility requirements

The public file `/assets/js/webcmd.js` exposes `ensureSiteIndex`, `siteIndex`,
`siteStore`, and `siteDocs`. The publisher builds its documents and operating
system history data from Org records, then appends the maintained runtime.

The generator preserves syntax highlighting, math, Mermaid diagrams,
responsive images and tables, reduced-motion behavior, visible focus states,
print styles, RSS, and the established route set. Syntax highlighting uses the
vendored `publish/htmlize.el`; its `org-*` token classes are coloured in
`assets/css/nord.css`. Languages without an available built-in major mode in
batch Emacs remain plain text.

`test/ci-contract.sh` checks the CI configuration, rejects retired publishing
inputs, performs a clean batch build, and compares its HTML routes with the
checked manifest. `.github/workflows/pages.yml` also runs the ERT suites and
EWW rendering check before deployment. `.github/workflows/a11y.yml` adds the
browser smoke and Axe checks.
