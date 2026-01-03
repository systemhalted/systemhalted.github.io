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
- `_layouts/`: page shells and rendering logic (`default.html`, `post.html`, `page.html`, `category.html`, `collections.html`).
- `_includes/`: shared UI fragments (head, sidebar, share buttons, comments).
- `_data/taxonomy.yml`: category themes + tag groups used by `categories.html` and related-post logic.
- `assets/`: images, site-level CSS/JS, and favicons (main bundle is `assets/css/nord.css`).
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
- Use `layout: collections` + `collection_name:` pages for listings (see `emacs.html` and `kartavya-path.html`).

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
