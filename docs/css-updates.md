# CSS updates

The site uses one hand-written stylesheet, `assets/css/nord.css`. Keep it
direct and small; do not add a framework or a layer of override rules for
ordinary changes.

## Theme and tokens

The root `<html>` element receives either `theme-nord-light` or
`theme-nord-dark`. `_includes/head.html` applies the saved or system preference
before paint and `assets/js/script.js` toggles and persists it.

Component rules should use semantic variables such as `--background`,
`--surface`, `--text`, `--muted`, `--border`, `--accent`, and the `--code-*`
tokens. Add a token to both theme blocks when a component genuinely needs a
new role. Syntax-highlighted block code keeps its dark Nord canvas in both
themes.

## Layout map

- `.container`, `.content`: shared 820px page shell.
- `.site-header`, `.primary-nav`, `.header-actions`: compact masthead.
- `.home-intro`, `.writing-list`, `.writing-row`, `.home-section`: homepage.
- `.post`, `.post-header`, `.post-content`, `.post-toc`, `.post-end`: articles.
- `.archive-*`, `.taxonomy-*`: Archive, Categories, and Tags.
- `.search-overlay`, `.search-dialog`, `.search-results`: search and the hidden
  shortcuts dialog.
- `.site-footer`: compact footer links.
- `.webcmd-*`, `.project-*`, and collection selectors: specialist pages.

Article prose is capped near 700px and uses Newsreader; navigation and metadata
use the sans-serif stack. Homepage and archive rows use typography, alignment,
and whitespace rather than card surfaces.

## JavaScript-coupled selectors

Coordinate renames with `_layouts/default.html` and `assets/js/script.js`:

- Theme: `theme-nord-light`, `theme-nord-dark`, `#theme-toggle`.
- Search: `.search-toggle`, `#search-overlay`, `#search-input`,
  `#search-close`, `#search-results`, `#search-status`.
- Shortcuts: `#shortcuts-overlay`, `#shortcuts-close`.
- Archive sort: `[data-archive-sort]`, `[data-archive-years]`.

The retired sidebar, share bar, focus mode, font controls, glazed theme, cards,
and theme settings panel should not be reintroduced as compatibility styles.

## Accessibility and responsive rules

Keep `:focus-visible` states clear in both themes. Preserve the reduced-motion,
forced-colors, mobile, and print sections at the bottom of the stylesheet.
Horizontal scrolling belongs on code and table wrappers, not on the page.

Before shipping a visual change, inspect the homepage, a short post, a long
post with its collapsed contents disclosure, Archive, Projects, search, mobile
width, and both themes. Then run the Jekyll build and `npm run a11y`.
