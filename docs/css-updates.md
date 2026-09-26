# CSS updates

The site uses `assets/css/nord.css` for global styles and
`assets/css/projects.css` for the Projects page. Keep both direct and small;
do not add a framework or a layer of override rules for ordinary changes.

## Theme and tokens

The root `<html>` element receives either `theme-nord-light` or
`theme-nord-dark`. `publish/templates/base.html` applies the saved or system
preference before paint and `assets/js/script.js` toggles and persists it.

Component rules should use semantic variables such as `--background`,
`--surface`, `--text`, `--muted`, `--border`, `--accent`, and the `--code-*`
tokens. Add a token to both theme blocks when a component genuinely needs a
new role. Syntax-highlighted block code keeps its dark Nord canvas in both
themes.

## Syntax highlighting

`publish/systemhalted-publish.el` loads the vendored `publish/htmlize.el` by
path. Source blocks retain the `language-*`, `highlighter-rouge`, and
`highlight` wrappers used by the older site. Htmlize adds token spans with
`org-*` classes, and the matching colours are defined in this stylesheet.

The clean batch build highlights a language only when Emacs has a built-in
major mode that can fontify it. Major-mode remapping is disabled so an
interactive Emacs and a batch build produce the same markup. Languages that
depend on unavailable modes or tree-sitter grammars remain escaped plain text
inside the normal code-block wrapper. Go, Rust, JSON, and YAML currently take
that path.

When a supported mode emits a new htmlize face, add its `.highlight .org-*`
rule beside the existing syntax tokens. The ERT suite checks that every face
emitted by its language fixture has a colour rule.

## Layout map

- `.container`, `.content`: shared 820px page shell.
- `.site-header`, `.primary-nav`, `.header-actions`: compact masthead.
- `.home-intro`, `.writing-list`, `.writing-row`, `.home-section`: homepage.
- `.post`, `.post-header`, `.post-content`, `.post-toc`, `.post-end`: articles.
- `.archive-*`, `.taxonomy-*`: Archive, Categories, and Tags.
- `.search-overlay`, `.search-dialog`, `.search-results`: search and the hidden
  shortcuts dialog.
- `.site-footer`: compact footer links.
- `.webcmd-*` and collection selectors: specialist pages in `nord.css`.
- `.project-*`: the Projects page in `projects.css`.

Article prose is capped near 700px and uses Newsreader; navigation and metadata
use the sans-serif stack. Homepage and archive rows use typography, alignment,
and whitespace rather than card surfaces.

## JavaScript-coupled selectors

Coordinate renames with `publish/templates/base.html` and `assets/js/script.js`:

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
width, and both themes. Then run `M-x systemhalted-build` and `npm run a11y`.
