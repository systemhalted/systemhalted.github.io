# Accessibility Guide

This project targets WCAG 2.1 AA for the site UI (excluding `jsgames/`). This doc summarizes current accessibility hooks, where they live, and what to watch when adding new content or UI.

## Current accessibility features
- Skip link to main content (`_layouts/default.html` + styles in `assets/css/nord.css`).
- `<main>` landmark around the page content (`_layouts/default.html`).
- Sidebar toggle is keyboard operable and exposes `aria-expanded` (`_layouts/default.html`, `assets/js/script.js`).
- Sidebar is a roving-tabindex ARIA menu: opening it moves focus to the first item; ArrowUp/Down/Home/End walk items; Escape closes and restores focus to the toggle (`_includes/sidebar.html`, `assets/js/script.js`).
- Search overlay has focus trapping and returns focus on close (`assets/js/script.js`).
- Keyboard shortcuts + in-app help dialog launched with `?` (see [Keyboard shortcuts](#keyboard-shortcuts) below).
- Webcmd help uses semantic lists and headings (`assets/js/webcmd.js`).

## Content guidelines
- Always provide meaningful `alt` text for images that convey information.
  - For posts: use `featured_image_alt` in front matter.
  - For inline images in Markdown/HTML, keep `alt` descriptive or empty (`alt=""`) if decorative.
- Keep headings hierarchical (`h1` once per page, then `h2`, `h3`, etc.).
- Use lists, tables, and blockquotes semantically instead of manual spacing.
- Avoid inline `onclick` handlers on non-interactive elements; use buttons or links with JS bindings.

## Interactive UI guidelines
- Custom controls must be keyboard accessible and expose proper ARIA:
  - Use `<button>` for actions, `<a>` for navigation.
  - If a non-button element must be interactive, add `role="button"`, `tabindex="0"`, and key handlers for Enter/Space.
- Ensure focus is visible and not removed.
- If you add a modal/overlay, trap focus inside and return it to the trigger on close.

## Color contrast
- Maintain WCAG AA contrast for text and UI states in both Nord themes.
- If you introduce new tokens, verify contrast against `--bg`, `--surface`, and `--surface-strong`.

## Where to update
- Layout landmarks and skip link: `_layouts/default.html`.
- Sidebar interactions and theme/search behavior: `assets/js/script.js`.
- Global styles and focus styles: `assets/css/nord.css`.
- Webcmd UI and help output: `assets/js/webcmd.js` and `webcmd/index.html`.

## Quick checks before shipping
- Keyboard-only pass: tab through the page, open/close the sidebar and search overlay.
- Screen reader spot-check: search overlay labels, help text in webcmd, and headings.
- Image alt audit for any new posts or pages.

## Keyboard shortcuts

Bound globally in `assets/js/script.js`. None fire while focus is in a form field (`<input>`, `<textarea>`, contenteditable), and none fire while a modifier (Cmd/Ctrl/Alt) is held.

**Go to** (chord, second key within 1.2s):
- `g h` — Home
- `g f` — Featured
- `g k` — Kartavya Path
- `g e` — Emacs
- `g a` — About

**Actions:**
- `/` or `s` — open search
- `t` — toggle light / dark
- `m` — toggle the sidebar menu
- `?` — open this help dialog
- `Esc` — close any open overlay

**In the sidebar menu** (once focus is inside it):
- `ArrowDown` / `ArrowUp` — walk items
- `Home` / `End` — first / last
- `Enter` — open the focused item

The `?` help dialog (`#shortcuts-overlay` in `_layouts/default.html`) is the canonical in-app reference; keep it in sync if you add or change a shortcut.

## Running automated audits

[pa11y-ci](https://github.com/pa11y/pa11y-ci) is wired up as a dev dependency. It runs against a curated URL list (NOT the full sitemap — the sitemap has hundreds of legacy posts and would drown the signal).

```bash
# One-time
npm install

# Each run: build + serve, then audit
bundle exec jekyll serve   # in one terminal
npm run a11y               # in another
```

Config lives in `.pa11yci`; URLs to audit are in the `urls` array. Add a URL when you ship a new page family (e.g. a new collection landing). The `jsgames/` directory is explicitly excluded — it's a different problem with different constraints.

## Browser-level caveats

- **macOS Safari**: the "Press Tab to highlight each item on a webpage" preference is OFF by default. With it off, Safari only Tabs between form fields — `<a>` links and elements with `tabindex="0"` are skipped. The site can't override this from CSS/JS. Users who want full Tab navigation in Safari should enable it in Safari → Settings → Advanced → "Press Tab to highlight each item on a webpage". This is why we layer arrow-key navigation onto the sidebar menu — it works regardless of Safari's preference, because we move focus programmatically.

## Known limitations
- Many legacy posts include inline HTML with empty or missing `alt` text. Fix as you touch those posts.
- pa11y-ci audits a curated cross-section, not every URL.
