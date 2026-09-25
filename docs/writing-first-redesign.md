# Writing-first site architecture

The published site is generated from Org files by
`publish/systemhalted-publish.el`. Shared HTML lives in `publish/templates/`,
while `assets/css/nord.css` and `assets/js/script.js` provide the visual and
interactive layers. `_site/` is disposable output.

## Interface structure

- `publish/templates/base.html` provides the masthead, primary navigation,
  search and shortcut dialogs, main landmark, and footer.
- `publish/templates/post.html` provides article metadata, an optional contents
  disclosure, prose, related entries, adjacent navigation, and comments.
- `publish/templates/page.html` provides the shell for generated indexes and
  authored pages.
- `publish/templates/feed.xml` and `publish/templates/sitemap.xml` provide the
  XML entry points.
- `publish/templates/webcmd-runtime.js` implements `/webcmd/` and retains the
  public search globals used by the sibling `about-me` site.

## Design decisions

- The compact header links to Writing, About, Archive, and Projects, with
  search and a light/dark theme toggle beside them.
- The homepage introduces the author and lists five recent entries. Older
  entries are available through the pagination and archive routes.
- Article prose is the primary visual element. Taxonomy, related entries,
  adjacent navigation, and discussion links appear as quieter end matter.
- Archive, Categories, and Tags use direct date-and-title rows with disclosure
  sections where grouping helps navigation.
- Featured images are optional and appear after the prose. Long posts may opt
  into a collapsed contents disclosure.
- The footer contains copyright and a small group of durable external links.
- Existing permalinks remain stable, including historical paths whose names no
  longer describe an active section of the site.

## Compatibility requirements

The public file `/assets/js/webcmd.js` exposes `ensureSiteIndex`, `siteIndex`,
`siteStore`, and `siteDocs`. The publisher builds its documents and operating
system history data from Org records, then appends the maintained runtime.

The generator must also preserve syntax highlighting, math, Mermaid diagrams,
responsive images and tables, reduced-motion behavior, visible focus states,
print styles, RSS, and the established route set. `test/ci-contract.sh` checks
the route inventory during CI.
