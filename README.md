# systemhalted.github.io

This repo hosts the Jekyll source for systemhalted.in. Use `bundle exec jekyll serve --livereload` while drafting to see changes locally.

## How to add a new post
- Create `collections/_posts/YYYY-MM-DD-title.md` (kebab-case title). Date drives the permalink.
- Front matter example:
  ```
  ---
  layout: post
  title: Sample Post
  date: 2025-12-31
  category: [Tech]      # or `categories:` if you prefer plural key
  tags: [jekyll, notes]
  comments: true
  featured: true        # optional flag used in layouts
  featured_image: assets/images/2025-12-hero.jpg   # optional hero/thumbnail path
  featured_image_alt: Brief alt text for the image
  featured_image_caption: Photo credit or context
  description: One-line summary for previews.
  ---
  ```
- Write Markdown below the front matter. Use fenced code blocks and relative asset paths (e.g., `assets/images/2025-12-hero.jpg`).
- Run `bundle exec jekyll build` before pushing to ensure there are no front matter or Liquid errors.

## How to add a new collection
- Add the collection to `_config.yml` under `collections:`. Example:
  ```
  collections:
    guides:
      output: true
  ```
- Create a directory `collections/_guides/` and add items with front matter:
  ```
  ---
  layout: page   # or a custom layout for that collection
  title: My Guide
  date: 2025-01-01
  ---
  ```
- If you want a listing page, add a page (e.g., `guides.html`) with:
  ```
  ---
  layout: collections
  title: Guides
  collection_name: guides
  show_dates: true
  ---
  ```
  The `collections` layout loops through `site[collection_name]` and can show dates when `show_dates` is true.

## Layouts and includes
- Layouts live in `_layouts/`:
  - `default.html` sets the shell; `post.html` and `page.html` render posts/pages; `category.html` lists posts by category; `collections.html` lists a named collection.
- Includes live in `_includes/`:
  - `head.html` handles meta and the single CSS bundle (`public/css/site.css`).
  - `sidebar.html`, `comments.html`, and `share-buttons.html` are reusable fragments invoked from layouts.

## Webcmd
- Legacy command-line UI lives in `webcmd/index.html` and depends on `public/js/webcmd.js`.
- Open `webcmd/` directly to test changes; keep assets referenced via `../public/...` so they work when deployed under the site root.***

## How to add a new post
- Create `collections/_posts/YYYY-MM-DD-title.md` (kebab-case title). Date drives the permalink.
- Front matter example:
  ```
  ---
  layout: post
  title: Sample Post
  date: 2025-12-31
  category: [Tech]      # or `categories:` if you prefer plural key
  tags: [jekyll, notes]
  comments: true
  featured: true        # optional flag used in layouts
  featured_image: assets/images/2025-12-hero.jpg   # optional hero/thumbnail path
  featured_image_alt: Brief alt text for the image
  featured_image_caption: Photo credit or context
  description: One-line summary for previews.
  ---
  ```
- Write Markdown below the front matter. Use fenced code blocks and relative asset paths (e.g., `assets/images/2025-12-hero.jpg`).
- Run `bundle exec jekyll build` before pushing to ensure there are no front matter or Liquid errors.

## How to add a new collection
- Add the collection to `_config.yml` under `collections:`. Example:
  ```
  collections:
    guides:
      output: true
  ```
- Create a directory `collections/_guides/` and add items with front matter:
  ```
  ---
  layout: page   # or a custom layout for that collection
  title: My Guide
  date: 2025-01-01
  ---
  ```
- If you want a listing page, add a page (e.g., `guides.html`) with:
  ```
  ---
  layout: collections
  title: Guides
  collection_name: guides
  show_dates: true
  ---
  ```
  The `collections` layout loops through `site[collection_name]` and can show dates when `show_dates` is true.

## Layouts and includes
- Layouts live in `_layouts/`:
  - `default.html` sets the shell; `post.html` and `page.html` render posts/pages; `category.html` lists posts by category; `collections.html` lists a named collection.
- Includes live in `_includes/`:
  - `head.html` handles meta and the single CSS bundle (`public/css/site.css`).
  - `sidebar.html`, `comments.html`, and `share-buttons.html` are reusable fragments invoked from layouts.

## Webcmd
- Legacy command-line UI lives in `webcmd/index.html` and depends on `public/js/webcmd.js`.
- Use `find <query>` inside the prompt to search posts via the built-in elasticlunr index.
- Open `webcmd/` directly to test changes; keep assets referenced via `../public/...` so they work when deployed under the site root.
