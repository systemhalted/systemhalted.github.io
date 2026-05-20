# CSS Update Guide

This site uses a single stylesheet: `assets/css/nord.css`. It is loaded from `_includes/head.html` and applies globally to all layouts, collections, and static pages.

## How CSS is organized
- Theme tokens live in the `theme-nord-light` and `theme-nord-dark` blocks and drive all colors, surfaces, borders, and shadows.
- Base styles (reset + typography) are at the top: `html`, `body`, headings, lists, tables, `code`, `pre`, and global element defaults.
- Layout primitives follow: `.wrap`, `.container`, `.masthead`, `.sidebar`, `.content`.
- Components come next: search overlay, post pages, post cards, pagination, category/tag blocks, archives, and the footer.
- Utilities and legacy helpers are near the end: `.alignleft`, `.alignright`, `.wp-caption`, `.pull-quote`, org-mode helpers.

## Theme system
The root `<html>` element gets either `theme-nord-light` or `theme-nord-dark` (set in `_includes/head.html` and toggled in `assets/js/script.js`). Colors are never hard-coded in component rules; they are referenced through variables like `--bg`, `--surface`, `--text`, and `--accent`.

When you change colors:
- Update both `theme-nord-light` and `theme-nord-dark`.
- Prefer semantic tokens (`--bg`, `--surface`, `--text-strong`) over palette tokens (`--nord8`) inside components.
- If you introduce a new token, add it to both theme blocks.

### Accent-warm split (text vs. fill)
The raw Nord12 / Nord13 warm accent doesn't meet WCAG AA as text on the light bg, so we split the token:
- `--accent-warm` — backgrounds, borders, decorative fills only.
- `--accent-warm-text` — any `color:` rule that needs the warm accent (kickers, brand marks, link emphasis).

If you reach for the warm color in a `color:` rule, use `--accent-warm-text`. The light theme value is a darker burnt orange tuned for ≥4.5:1 on `--bg`.

### Code blocks vs. inline code
Two separate token families intentionally diverge:
- Inline `<code>` uses `--code-bg` / `--code-text` / `--code-border` — light bg in light theme, contained chip look.
- `<pre>` code blocks use `--code-block-bg` / `--code-block-text` / `--code-block-border` — always a dark Nord canvas so the Rouge syntax tokens (which are designed for dark backgrounds) hit AA in both themes.

Don't merge them — that's the trap the original styling fell into. The block-vs-inline distinction is the whole point.

## Finding the right selector
Start from the markup, then jump to the selector:
- Layouts are in `_layouts/` and includes in `_includes/`.
- Pages like `index.html`, `categories.html`, and `archives.html` define section-specific classes.

Helpful searches:
```
rg -n "post-grid|post-card|masthead|search-overlay|archive" assets/css/nord.css
rg -n "post-grid|post-card|masthead|search-overlay|archive" _layouts _includes *.html
```

## Component map (where styles live)
- Masthead: `.masthead`, `.masthead-title`, `.masthead-wordmark`, `.masthead-actions`, `.icon-button`
- Sidebar: `.sidebar`, `.sidebar-toggle`, `.sidebar-nav`, `.sidebar-nav-item`, `#sidebar-checkbox` (sr-only clip pattern; checked-state controlled with sibling selectors)
- Search overlay: `.search-overlay`, `.search-dialog`, `.search-input`, `.search-result`, `.search-status`
- Shortcuts dialog: `.shortcuts-overlay` (reuses `.search-overlay` base), `.shortcuts-dialog`, `.shortcuts-title`, `.shortcuts-body`, `.shortcuts-section`, `.shortcuts-heading`, `.shortcuts-list` (dl/dt/dd), `kbd`, `.shortcut-or`
- Hero blocks (used by landing pages with `hide_page_title: true`): `.newsletter-hero`, `.newsletter-brand` (warm accent brand mark for `/kartavya-path/`), `.newsletter-kicker`, `.newsletter-headline`, `.newsletter-lede`, `.newsletter-title`, `.newsletter-issue`; `.featured-hero`, `.featured-kicker`, `.featured-headline` (used by `/featured/`)
- Single-column reading feed (replaced the old `.post-grid` card grid): `.post-feed`, `.post-feed-item`, `.post-feed-meta`, `.post-feed-date`, `.post-feed-cat`, `.post-feed-sep`, `.post-feed-title`, `.post-feed-excerpt`
- Posts and pages: `.post`, `.post-content` (36rem reading column), `.post-title`, `.page-title` (gated by `hide_page_title` front-matter flag), `.post-date`, `.post-featured`, `.post-categories`, `.post-tags`, `.post-toc`
- Emacs notes: `.emacs-note`, `.emacs-note-header` (individual notes rendered by `_layouts/emacs.html`)
- Post cards (legacy; still used in some places): `.post-grid`, `.post-card`, `.card-media`, `.card-body`, `.card-title`, `.card-excerpt`
- Pagination: `.pager`, `.page-btn`, `.page-btn.active` (uses `--accent-press` for AA contrast)
- Categories/tags: `.category-block`, `.category-posts`, `.tag-box`
- Archives: `.archive-controls`, `.archive-year`, `.archive-post-summary`, `.archive-post-description`
- Share buttons: `.share-buttons` (nav landmark), `.share-buttons-label`, `.share-button` + per-network variants (`.share-facebook`, `.share-twitter`, `.share-linkedin`, `.share-pinterest`, `.share-mail`)
- Footer: `.site-footer`, `.footer-*`, `.footer-shortcuts` (the `Keyboard shortcuts (?)` trigger); the Browse and Connect columns are `<nav class="footer-column" aria-label="…">` landmarks

## Updating existing styles
1. Identify the class in the layout or page that renders the UI you want to change.
2. Locate its selector in `assets/css/nord.css`.
3. Modify spacing, typography, and color using existing tokens.
4. Check both themes (toggle with the UI button in the masthead).
5. Validate responsive behavior; there are a few breakpoints:
   - `@media (min-width: 38em)` for base font-size
   - `@media (max-width: 48em)` for masthead layout
   - `@media (min-width: 30em)` for sidebar toggle positioning

## Adding new styles
If you add new markup or classes:
- Add the class to the relevant layout/include/page first.
- Co-locate the new CSS near related component sections in `assets/css/nord.css`.
- Use existing tokens and spacing patterns (rem units, consistent borders, rounded corners).
- If the new element needs JS interaction, ensure selectors are aligned with `assets/js/script.js`.

## JS-coupled selectors to keep stable
Some selectors are referenced in JavaScript and should not be renamed without updating JS:
- Theme toggle: `theme-nord-light`, `theme-nord-dark` on `<html>`, `#theme-toggle`
- Search overlay: `.search-overlay`, `.search-overlay.is-open`, `body.search-open`, `#search-toggle`, `#search-input`, `#search-close`, `#search-overlay`, `#search-results`, `#search-status`
- Shortcuts dialog: `#shortcuts-overlay`, `.shortcuts-overlay.is-open`, `body.shortcuts-open`, `#shortcuts-close`, `#footer-shortcuts-trigger`
- Sidebar: `#sidebar-checkbox`, `.sidebar-toggle`, `.sidebar`, `.sidebar-nav-item` (the script reads the list at startup and manages a roving `tabindex` across items, so each menu link needs the `.sidebar-nav-item` class and a `role="menuitem"`)
- Archive sort: `#archive-years`, `#archive-sort`, `.archive-year` (with `data-year` and `data-count`)

If you rename any of these, update `assets/js/script.js` and the related HTML in `_layouts/default.html`, `_includes/sidebar.html`, or `_includes/footer.html`.

## Layout flags worth knowing
- **`hide_page_title: true`** in a page's front matter suppresses the `<h2 class="page-title">` that `_layouts/page.html` would otherwise inject. Use this on any page that provides its own h1 via a hero block (`.newsletter-hero`, `.featured-hero`, etc.) to avoid a duplicate, off-width title. Applied today on `emacs.html`, `jsgames/index.html`, `featured.html`, `kartavya-path.html`. Pages without a hero (`about.md`, `archives.html`, `categories.html`, `tags.html`, `docs/content-metadata.md`) should *not* set this — they rely on `.page-title` as their only heading.

## Motion and forced-colors

Two global media queries near the top and bottom of `assets/css/nord.css` apply site-wide and don't usually need to be touched:
- `@media (prefers-reduced-motion: reduce)` near the top neutralizes all animations and transitions for users who request reduced motion. New components inherit this for free — don't add component-level `prefers-reduced-motion` blocks unless you have a specific override.
- `@media (forced-colors: active)` at the bottom of the file maps interactive elements (buttons, focus rings, active pagination, sidebar items) to Windows High Contrast system colors (`ButtonText`, `Highlight`, `LinkText`, `CanvasText`). If you add a new interactive component, ensure it's covered in this block or relies on already-covered base selectors.

## Sidebar / horizontal-overflow invariant
The sidebar open animation applies `transform: translateX(14rem)` to `.wrap` (full-viewport-width). This pushes the wrap 14rem past the viewport's right edge while it's open. To prevent a horizontal scrollbar, `overflow-x: hidden` is set on **both** `html` and `body`. Don't remove either — body-only doesn't always propagate to the viewport scrollbar. Code blocks keep their own scoped `overflow-x: auto`, so syntax-highlighted prose still scrolls horizontally inside the block.

## Verification checklist
- Run `bundle exec jekyll serve --livereload`.
- Check light and dark themes on the home page, a post page, and the archives page.
- Verify search overlay and sidebar interactions still work (open with click, open with `m`, open with `?` for the shortcuts dialog).
- Confirm category/tag chips, pagination buttons, and footer layout on mobile widths.
- Open the sidebar and confirm there's no horizontal scrollbar.
- Run `npm run a11y` for an automated WCAG2AA sweep (see `docs/accessibility.md`).

## Examples
Use these as templates; apply them near the existing component blocks in `assets/css/nord.css`.

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
.search-result:focus-visible {
  border-color: var(--accent);
  box-shadow: var(--shadow-strong);
}
```
Prefer `:focus-visible` over `:focus` for interactive states — mouse-click users don't get a sticky focus ring, keyboard users still do. The codebase has been converted to this pattern; match it when adding new components.
