# Accessibility Guide

This project targets WCAG 2.1 AA for the site UI (excluding `jsgames/`). This doc summarizes current accessibility hooks, where they live, and what to watch when adding new content or UI.

## Current accessibility features
- Skip link to main content (`publish/templates/base.html` + styles in `assets/css/nord.css`).
- `<main>` landmark around the page content (`publish/templates/base.html`).
- The compact primary navigation is a native `<nav>` containing ordinary links (`publish/templates/base.html`).
- The single theme button has an accessible label that states the theme it will activate (`assets/js/script.js`).
- Search overlay has focus trapping and returns focus on close (`assets/js/script.js`).
- Keyboard shortcuts + in-app help dialog launched with `?` (see [Keyboard shortcuts](#keyboard-shortcuts) below).
- Webcmd help uses a semantic list and a labelled toggle
  (`publish/templates/webcmd-runtime.js` and `publish/templates/webcmd.html`).
- Search and shortcut dialogs are materialized from an HTML template when
  JavaScript runs. Keep the primary navigation and reading content outside that
  template so non-JavaScript readers, including Emacs EWW, receive a clean page.

## Content guidelines
- Always provide meaningful `alt` text for images that convey information.
  - For posts: use `#+FEATURED_IMAGE_ALT` in the Org metadata.
  - For inline Org or HTML images, keep `alt` descriptive or empty (`alt=""`) if decorative.
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
- Maintain WCAG AA contrast for text and UI states in Nord Light and Nord Dark.
- If you introduce new tokens, verify contrast against `--background`,
  `--surface`, and `--surface-quiet`.
- For warm accent text, use `--accent-warm-text` (AA-compliant), not `--accent-warm` (used for backgrounds/borders only).
- Code blocks use `--code-bg`, `--code-text`, and `--code-border`. Inline
  `<code>` uses `--surface`, `--text`, and `--border`.

## Where to update
- Layout landmarks and skip link: `publish/templates/base.html`.
- Theme, search, archive-sort, and shortcut behavior: `assets/js/script.js`.
- Global styles and focus styles: `assets/css/nord.css`.
- Webcmd page markup and help output: `publish/templates/webcmd.html` and
  `publish/templates/webcmd-runtime.js`.

## Quick checks before shipping
- Keyboard-only pass: tab through the header, open/close search, toggle the theme, and expand a long article's contents disclosure.
- Screen reader spot-check: search overlay labels, help text in webcmd, and headings.
- Image alt audit for any new posts or pages.

## Keyboard shortcuts

Bound globally in `assets/js/script.js`. None fire while focus is in a form field (`<input>`, `<textarea>`, contenteditable), and none fire while a modifier (Cmd/Ctrl/Alt) is held.

**Go to** (chord, second key within 1.2s):
- `g w` — Writing
- `g p` — Projects
- `g a` — Archive
- `g i` — About

**Actions:**
- `/` or `s` — open search
- `t` — toggle light / dark
- `?` — open this help dialog
- `Esc` — close any open overlay

The `?` help dialog (`#shortcuts-overlay` in `publish/templates/base.html`) is the canonical in-app reference; keep it in sync if you add or change a shortcut.

## Running automated audits

The accessibility script uses [Axe](https://github.com/dequelabs/axe-core) through `playwright-core`. It launches the existing system Chrome/Chromium installation, avoiding browser-download dependencies, and audits a curated URL list (NOT the full sitemap — the sitemap has hundreds of legacy posts and would drown the signal).

```bash
# One-time
npm install

# Each run: serve a preview on port 4002, then audit
npm run smoke              # in another
npm run a11y               # in another
```

The Node checks use port 4002. The interactive preview defaults to port 4000,
so set `systemhalted-preview-port` to 4002 before running
`M-x systemhalted-preview` for these checks.

After building the site, check the homepage with the same renderer EWW uses:

```bash
emacs -Q --batch --script scripts/test-eww-rendering.el _site/index.html
```

Config lives in `a11y.config.json`; URLs to audit are in the `urls` array. Add a URL when you ship a new page family (e.g. a new collection landing). The runner checks `CHROME_PATH`, `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`, and `PUPPETEER_EXECUTABLE_PATH` before common Linux Chrome paths. The `jsgames/` directory is explicitly excluded — it's a different problem with different constraints.

`.github/workflows/a11y.yml` runs the CI contract, production build, EWW
rendering check, browser smoke test, and Axe audit on every PR and push to
`main`. The job fails on any Axe violation.

## Browser-level caveats

- **macOS Safari**: the "Press Tab to highlight each item on a webpage" preference is OFF by default. With it off, Safari only Tabs between form fields and may skip links. The site cannot override this preference. Users who want full Tab navigation should enable it in Safari → Settings → Advanced.

## Known limitations
- Many legacy posts include inline HTML with empty or missing `alt` text. Fix as you touch those posts.
- The Axe runner audits a curated cross-section, not every URL.
- Third-party embeds such as Giscus comments may inject elements without proper labels. A `MutationObserver` in `script.js` stamps iframes and reCAPTCHA textareas with fallback labels; if a future embed introduces new offending elements, extend `labelIframe`/`labelRecaptchaTextarea`.
- Tags page (`/tags/`) merges duplicate-slug tag names (e.g. `India` and `india`) under per-instance unique IDs; the first occurrence keeps the canonical slug for stable anchors.
