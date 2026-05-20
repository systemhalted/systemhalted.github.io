# systemhalted.github.io

Jekyll source for systemhalted.in. The build output goes to `_site/` (generated), so edit sources only.

## Quickstart
- `bundle install`
- `bundle exec jekyll serve --livereload`
- `bundle exec jekyll build` (pre-push check)
- `bundle exec jekyll doctor` (sanity checks)

## Development workflow
- Drafts live in `collections/_drafts/`; preview them with `bundle exec jekyll serve --livereload --drafts`.
- Publish by moving drafts to `collections/_posts/` and renaming to `YYYY-MM-DD-title.md`.
- Newsletters live in `collections/_newsletter/`; preview the listing at `/kartavya-path`.
- JSGames are standalone in `jsgames/`; open `jsgames/<game>/index.html` directly or via the Jekyll server and keep assets nearby.
- For production parity, run `JEKYLL_ENV=production bundle exec jekyll serve`.

## Project structure
- `_config.yml`: site metadata, collections, pagination, sidebar nav, plugins.
- `collections/_posts/`, `collections/_drafts/`, `collections/_newsletter/`, `collections/_emacs/`: authored content.
- `_layouts/`: page shells and rendering logic (`default.html`, `post.html`, `page.html`, `category.html`, `collections.html`, `newsletter.html`, `emacs.html`).
- `_includes/`: shared UI fragments (head, sidebar, footer, share buttons, comments, list-item partials for emacs and jsgames).
- `_data/taxonomy.yml`: category themes + tag groups used by `categories.html` and related-post logic.
- `_data/jsgames.yml`: hand-curated list of standalone JS games shown on `/jsgames/`.
- `assets/`: images, site-level CSS/JS, and favicons (main bundle is `assets/css/nord.css`; main behavior is `assets/js/script.js`).
- `jsgames/`: standalone JS games with local assets.
- `webcmd/`: terminal-style UI entry page.
- `scripts/posts`: helper to list or search posts from the CLI.

## Authoring posts
- Create `collections/_posts/YYYY-MM-DD-title.md` (kebab-case title).
- Front matter example:
  ```
  ---
  layout: post
  title: Sample Post
  date: 2025-12-31
  categories: [Tech]
  tags: [jekyll, notes]
  comments: true
  featured: true
  featured_image: assets/images/2025-12-hero.jpg
  featured_image_alt: Brief alt text for the image
  featured_image_caption: Photo credit or context
  description: One-line summary for previews.
  ---
  ```
- Write Markdown below the front matter; use relative asset paths like `assets/images/2025-12-hero.jpg`.

## Collections
- Define new collections in `_config.yml` under `collections:`.
- Add docs under `collections/_<name>/` with standard front matter.
- For landing pages, the redesign uses an inline **hero + `.post-feed`** pattern instead of the older `layout: collections`. Look at `emacs.html`, `jsgames/index.html`, and `kartavya-path.html` for examples: each one is `layout: page` + `hide_page_title: true`, then renders a `.newsletter-hero` (or `.featured-hero`) block followed by a `<ul class="post-feed">` of items via a per-collection include in `_includes/`.
- Individual emacs notes use `_layouts/emacs.html` (kicker + title + content + tag chips, no date/comments/prev-next).
- Newsletter issues use `_layouts/newsletter.html`.

## Key pages
- `index.html`: paginated home grid.
- `archives.html`: year-grouped archive with client-side sorting.
- `categories.html`: category taxonomy grouped by theme.
- `tags.html`: tag archive.
- `featured.html`: posts with `featured: true`.
- `about.md`, `404.md`: static pages.

## Search and webcmd
- Search index is built at build time in `assets/js/webcmd.js` using all output docs.
- The search overlay in `assets/js/script.js` consumes the same index.
- `webcmd/index.html` exposes the command-line UI; `find <query>` performs a site search.

## Keyboard shortcuts
Globally bound in `assets/js/script.js`; in-app reference opens with `?`. See `docs/accessibility.md` for the full list. Highlights:
- `g h` / `g f` / `g k` / `g e` / `g a` — go to Home / Featured / Kartavya Path / Emacs / About
- `/` or `s` — open search; `t` — toggle theme; `m` — toggle the sidebar menu
- `?` — open the shortcuts help dialog; `Esc` — close any overlay
- Inside the sidebar: ArrowUp / ArrowDown / Home / End walk menu items; the sidebar auto-closes when focus moves away.

## Accessibility audits
Node-based [pa11y-ci](https://github.com/pa11y/pa11y-ci) is wired as a dev dependency. Run against a curated URL list (the full sitemap would drown signal):
```
npm install            # one-time
bundle exec jekyll serve   # in one terminal
npm run a11y               # in another
```
Config lives in `.pa11yci`. `/jsgames/*` is excluded by design — different constraints. See `docs/accessibility.md` for the full a11y inventory and Safari/Tab-preference caveats.

## Docs
- CSS updates guide: `docs/css-updates.md`
- CSS example snippets: see "Examples" in `docs/css-updates.md`
- Search architecture: `docs/search-architecture.md`
- Webcmd guide: `docs/webcmd.md`
- Accessibility guide: `docs/accessibility.md`
- Content metadata guide: `docs/content-metadata.md`

## Notes
- Avoid editing `_site/` directly.
- Keep filenames kebab-case and asset names short.
