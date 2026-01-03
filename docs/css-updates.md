# CSS Update Guide

This site uses a single stylesheet: `public/css/nord.css`. It is loaded from `_includes/head.html` and applies globally to all layouts, collections, and static pages.

## How CSS is organized
- Theme tokens live in the `theme-nord-light` and `theme-nord-dark` blocks and drive all colors, surfaces, borders, and shadows.
- Base styles (reset + typography) are at the top: `html`, `body`, headings, lists, tables, `code`, `pre`, and global element defaults.
- Layout primitives follow: `.wrap`, `.container`, `.masthead`, `.sidebar`, `.content`.
- Components come next: search overlay, post pages, post cards, pagination, category/tag blocks, archives, and the footer.
- Utilities and legacy helpers are near the end: `.alignleft`, `.alignright`, `.wp-caption`, `.pull-quote`, org-mode helpers.

## Theme system
The root `<html>` element gets either `theme-nord-light` or `theme-nord-dark` (set in `_includes/head.html` and toggled in `public/js/script.js`). Colors are never hard-coded in component rules; they are referenced through variables like `--bg`, `--surface`, `--text`, and `--accent`.

When you change colors:
- Update both `theme-nord-light` and `theme-nord-dark`.
- Prefer semantic tokens (`--bg`, `--surface`, `--text-strong`) over palette tokens (`--nord8`) inside components.
- If you introduce a new token, add it to both theme blocks.

## Finding the right selector
Start from the markup, then jump to the selector:
- Layouts are in `_layouts/` and includes in `_includes/`.
- Pages like `index.html`, `categories.html`, and `archives.html` define section-specific classes.

Helpful searches:
```
rg -n "post-grid|post-card|masthead|search-overlay|archive" public/css/nord.css
rg -n "post-grid|post-card|masthead|search-overlay|archive" _layouts _includes *.html
```

## Component map (where styles live)
- Masthead: `.masthead`, `.masthead-title`, `.masthead-wordmark`, `.masthead-actions`, `.icon-button`
- Sidebar: `.sidebar`, `.sidebar-toggle`, `#sidebar-checkbox` (checked-state is controlled with sibling selectors)
- Search overlay: `.search-overlay`, `.search-dialog`, `.search-input`, `.search-result`, `.search-status`
- Posts and pages: `.post`, `.post-title`, `.post-date`, `.post-featured`, `.post-categories`, `.post-tags`
- Post cards (home): `.post-grid`, `.post-card`, `.card-media`, `.card-body`, `.card-title`, `.card-excerpt`
- Pagination: `.pager`, `.page-btn`
- Categories/tags: `.category-block`, `.category-posts`, `.tag-box`
- Archives: `.archive-controls`, `.archive-year`, `.archive-post-summary`, `.archive-post-description`
- Footer: `.site-footer`, `.footer-*`

## Updating existing styles
1. Identify the class in the layout or page that renders the UI you want to change.
2. Locate its selector in `public/css/nord.css`.
3. Modify spacing, typography, and color using existing tokens.
4. Check both themes (toggle with the UI button in the masthead).
5. Validate responsive behavior; there are a few breakpoints:
   - `@media (min-width: 38em)` for base font-size
   - `@media (max-width: 48em)` for masthead layout
   - `@media (min-width: 30em)` for sidebar toggle positioning

## Adding new styles
If you add new markup or classes:
- Add the class to the relevant layout/include/page first.
- Co-locate the new CSS near related component sections in `public/css/nord.css`.
- Use existing tokens and spacing patterns (rem units, consistent borders, rounded corners).
- If the new element needs JS interaction, ensure selectors are aligned with `public/js/script.js`.

## JS-coupled selectors to keep stable
Some selectors are referenced in JavaScript and should not be renamed without updating JS:
- Theme toggle: `theme-nord-light`, `theme-nord-dark` on `<html>`
- Search overlay: `.search-overlay`, `.search-overlay.is-open`, `body.search-open`, `#search-toggle`, `#search-input`
- Sidebar: `#sidebar-checkbox`, `.sidebar-toggle`, `.sidebar`

If you rename any of these, update `public/js/script.js` and the related HTML in `_layouts/default.html` or `_includes/sidebar.html`.

## Verification checklist
- Run `bundle exec jekyll serve --livereload`.
- Check light and dark themes on the home page, a post page, and the archives page.
- Verify search overlay and sidebar interactions still work.
- Confirm category/tag chips, pagination buttons, and footer layout on mobile widths.

## Examples
Use these as templates; apply them near the existing component blocks in `public/css/nord.css`.

### Example: tighten the masthead wordmark
Adjust the wordmark block in the masthead section:
```
.masthead-wordmark {
  font-size: clamp(2.4rem, 5.5vw, 4.2rem);
  letter-spacing: 0.01em;
}
```

### Example: refine archive summary chips
```
.archive-year-summary,
.archive-post-summary {
  border-radius: 12px;
  background: var(--surface-strong);
}

.archive-year-summary::after,
.archive-post-summary::after {
  border-right-width: 3px;
  border-bottom-width: 3px;
}
```

### Example: widen the sidebar and adjust typography
```
.sidebar {
  width: 16rem;
  left: -16rem;
  font-size: 0.95rem;
}

#sidebar-checkbox:checked ~ .sidebar,
#sidebar-checkbox:checked ~ .wrap,
#sidebar-checkbox:checked ~ .sidebar-toggle {
  transform: translateX(16rem);
}
```

### Example: tighten footer layout
```
.footer-inner {
  gap: 1.5rem;
}

.footer-heading {
  text-transform: uppercase;
  letter-spacing: 0.06em;
  font-size: 0.85rem;
}
```

### Example: increase contrast on post cards
```
.post-card {
  background: var(--surface-strong);
  border-color: var(--border);
}
```

### Example: unify tag and category chips
```
.post-categories a,
.post-tags a,
.tag-box a {
  background: var(--surface-strong);
  border-color: var(--border);
  font-size: 0.9rem;
}
```

### Example: make search results feel more clickable
```
.search-result {
  border-color: var(--border);
}

.search-result:hover,
.search-result:focus {
  border-color: var(--accent);
  box-shadow: var(--shadow-strong);
}
```
