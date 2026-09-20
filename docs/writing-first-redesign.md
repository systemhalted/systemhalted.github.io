# Writing-first redesign implementation note

## Repository audit (before implementation)

The following describes the interface as it existed when the redesign began.

- `_layouts/default.html` owns the shared masthead, sidebar, theme popover,
  search dialog, keyboard-shortcut dialog, content wrapper, footer, and global
  scripts. It is the main source of visible interface density.
- `index.html` combines a sticky “Start here” rail, a Kartavya Path promo,
  eight excerpt-heavy recent-post entries, and numbered pagination.
- `_layouts/post.html` renders the article title and metadata, featured image,
  sharing buttons, table of contents, focus/font/theme controls, taxonomy,
  related posts, adjacent-post navigation, and comments.
- `archives.html`, `categories.html`, and `tags.html` use nested disclosures for
  individual post excerpts. The useful hierarchy can remain while individual
  results become direct date-and-title links.
- `_layouts/newsletter.html` and `_layouts/emacs.html` reuse article prose and
  table-of-contents styles. Their table of contents should use the same quiet,
  collapsed disclosure as posts.
- `_includes/footer.html` repeats the site identity, description, navigation,
  Kartavya Path promotion, social links, and a visible shortcut trigger.
- `_includes/sidebar.html`, `_includes/share-buttons.html`, and the visible
  reading controls are removable once the shared header and article defaults
  provide the same useful paths with less chrome.
- `assets/css/nord.css` contains the palette, base typography, syntax
  highlighting, shared layouts, search, sidebar, focus mode, cards, archives,
  footer, newsletter pages, and accessibility/print rules. It should be
  consolidated instead of followed by another override layer.
- `assets/css/projects.css` is intentionally page-specific. Projects remain a
  secondary destination, so this stylesheet can remain while shared variables
  continue to support it.
- `assets/js/script.js` implements the sidebar, two-axis theme picker, archive
  sorting, search, keyboard shortcuts, third-party accessibility labelling, and
  focus/font controls. Search, one light/dark toggle, archive sorting, useful
  hidden shortcuts, and accessibility fixes remain; obsolete UI state does not.
- `assets/js/webcmd.js` builds the search documents and Elasticlunr index at
  Jekyll build time and also powers `/webcmd/`. The sibling `about-me` site
  loads `https://systemhalted.in/assets/js/webcmd.js` and depends on the public
  globals `ensureSiteIndex`, `siteIndex`, and `siteStore`/`siteDocs`. That URL,
  data shape, and those globals are compatibility requirements.
- `_includes/head.html` applies the saved theme before paint, loads typography,
  math/diagram enhancements, SEO, and analytics. Nord Light and Nord Dark form
  the two palettes. The obsolete glazed preference
  is no longer applied. The hidden CRT mode remains available to `/webcmd/`.
- `_config.yml` provides pagination, collections, taxonomy, RSS, search
  suggestions, comments, and Kartavya Path settings. URLs, collections, feeds,
  and content settings remain stable; the now-unused sidebar configuration can
  be removed after its include is retired.

## Implementation decisions

- Replace the sidebar with a compact semantic header: SystemHalted, Writing,
  About, Archive, Projects, Search, and one theme toggle. The existing
  `/projects/` showcase remains intact as a primary destination.
- Make page one a writer introduction followed by five recent date/title rows
  and one quiet Kartavya Path line. Keep `/pageN` URLs
  as compact older-writing lists.
- Make article prose the default focus state. Remove visible focus mode,
  font-size controls, share buttons, category badges, and the glazed theme.
- Keep featured images as optional closing visuals after the prose, with restrained sizing. Render opted-in
  tables of contents inside a collapsed `<details>` element.
- Keep taxonomy, three related entries, adjacent navigation, LinkedIn
  discussion links, and comments as quiet end matter.
- Make Archive the richer exploration page with Search, Categories, Tags, and
  Series gateways, year disclosures, sorting, and direct chronological rows.
- Simplify Categories and Tags to typographic disclosures with direct rows.
- Reduce the footer to copyright, palakmathur.in, RSS, LinkedIn, and Email.
- Preserve syntax highlighting, math, Mermaid, responsive images/tables,
  reduced motion, visible focus states, print styles, semantic HTML, RSS,
  existing permalinks, and the full external search-index contract.
