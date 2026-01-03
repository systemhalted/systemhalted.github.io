# Accessibility Guide

This project targets WCAG 2.1 AA for the site UI (excluding `jsgames/`). This doc summarizes current accessibility hooks, where they live, and what to watch when adding new content or UI.

## Current accessibility features
- Skip link to main content (`_layouts/default.html` + styles in `assets/css/nord.css`).
- `<main>` landmark around the page content (`_layouts/default.html`).
- Sidebar toggle is keyboard operable and exposes `aria-expanded` (`_layouts/default.html`, `assets/js/script.js`).
- Search overlay has focus trapping and returns focus on close (`assets/js/script.js`).
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

## Known limitations
- Many legacy posts include inline HTML with empty or missing `alt` text. Fix as you touch those posts.
- No automated accessibility tests are wired into the repo.
