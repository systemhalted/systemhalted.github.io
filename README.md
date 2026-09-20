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
- Kartavya Path essays are regular posts marked with `kartavya_path: true`; preview their listing at `/kartavya-path/`.
- JSGames are standalone in `jsgames/`; open `jsgames/<game>/index.html` directly or via the Jekyll server and keep assets nearby.
- For production parity, run `JEKYLL_ENV=production bundle exec jekyll serve`.

## Project structure
- `_config.yml`: site metadata, collections, pagination, search suggestions, and plugins.
- `collections/_posts/`, `collections/_drafts/`, `collections/_emacs/`: authored content.
- `org/`: Org Mode post sources and the `ox-jekyll.el` exporter (excluded from the Jekyll build; posts are exported to `collections/_posts/`).
- `_layouts/`: page shells and rendering logic (`default.html`, `post.html`, `page.html`, `category.html`, `collections.html`, `emacs.html`).
- `_includes/`: shared UI fragments (head, footer, comments, archive rows, and list-item partials for emacs and jsgames).
- `_data/taxonomy.yml`: category themes + tag groups used by `categories.html` and related-post logic.
- `_data/jsgames.yml`: hand-curated list of standalone JS games shown on `/jsgames/`.
- `assets/`: images, site-level CSS/JS, and favicons (main bundle is `assets/css/nord.css`; main behavior is `assets/js/script.js`).
- `jsgames/`: standalone JS games with local assets.
- `webcmd/`: terminal-style UI entry page.
- `scripts/posts`: helper to list or search posts from the CLI.

## Authoring posts (Org Mode)
New posts are written in Emacs Org Mode; the Markdown archive stays as-is.
- Create `org/posts/YYYY-MM-DD-title.org` (drafts go in `org/drafts/`, exporting to `collections/_drafts/`).
- Keywords map to front matter: `#+TITLE`, `#+DATE`, `#+DESCRIPTION`, `#+CATEGORIES:` and `#+TAGS:` (comma-separated), `#+JEKYLL_COMMENTS` (defaults to true), `#+JEKYLL_TOC`, `#+JEKYLL_LAYOUT` (defaults to post).
- Export with `M-x org-jekyll-export` (after `(load "<repo>/org/ox-jekyll.el")`), or from the shell:
  ```
  emacs --batch -l org/ox-jekyll.el -f org-jekyll-export-file org/posts/YYYY-MM-DD-title.org
  ```
- Enable `org-jekyll-auto-export-mode` in the buffer to re-export on every save.
- Commit **both** the `.org` source and the generated `.md` — CI builds the Markdown and never needs Emacs. The generated file carries `org_source:` in its front matter; edit the `.org`, not the `.md`.

## Authoring posts (Markdown, legacy)
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
  featured_image: assets/images/2025-12-hero.jpg
  featured_image_alt: Brief alt text for the image  # required when featured_image is set; empty if decorative
  featured_image_caption: Photo credit or context
  description: One-line summary for previews.
  ---
  ```
- Write Markdown below the front matter; use relative asset paths like `assets/images/2025-12-hero.jpg`.

## Collections
- Define new collections in `_config.yml` under `collections:`.
- Add docs under `collections/_<name>/` with standard front matter.
- Collection landing pages use the standard page hierarchy followed by a `.post-feed`; `emacs.html` is the simplest example. Promotional pages such as `kartavya-path.html` may opt into a restrained inline hero with `hide_page_title: true`.
- Individual emacs notes use `_layouts/emacs.html` (kicker + title + content + tag chips, no date/comments/prev-next).
- Kartavya Path essays use the ordinary post layout and are also collected at `/kartavya-path/`.

## Key pages
- `index.html`: five recent date/title rows and quiet editorial links; subsequent pagination pages remain at `/pageN`.
- `archives.html`: year-grouped archive with client-side sorting.
- `categories.html`: category taxonomy grouped by theme.
- `tags.html`: tag archive.
- `about.md`, `404.md`: static pages.

## Search and webcmd
- Search index is built at build time in `assets/js/webcmd.js` using all output docs.
- The search overlay in `assets/js/script.js` loads Elasticlunr and that shared index only when search is first opened.
- `webcmd/index.html` exposes the command-line UI; `find <query>` performs a site search.
- `palakmathur.in` also consumes the published `assets/js/webcmd.js`; preserve its URL and the public `ensureSiteIndex`, `siteIndex`, and `siteStore`/`siteDocs` globals.

## Keyboard shortcuts
Globally bound in `assets/js/script.js`; in-app reference opens with `?`. See `docs/accessibility.md` for the full list. Highlights:
- `g w` / `g p` / `g a` / `g i` — go to Writing / Projects / Archive / About
- `/` or `s` — open search; `t` — toggle Nord Light / Nord Dark
- `?` — open the shortcuts help dialog; `Esc` — close any overlay

## Accessibility audits
The Node-based Axe runner audits a curated URL list through the system Chrome/Chromium installation (the full sitemap would drown signal):
```
npm install            # one-time
bundle exec jekyll serve   # in one terminal
npm run a11y               # in another
```
Config lives in `a11y.config.json`. `/jsgames/*` is excluded by design — different constraints. See `docs/accessibility.md` for the full a11y inventory and Safari/Tab-preference caveats.

`.github/workflows/a11y.yml` runs the same audit on every PR and push to `main` and fails the check on any violation, so fix locally before pushing.

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
