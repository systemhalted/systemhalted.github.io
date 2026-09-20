# Content Metadata Guide

This guide covers taxonomy, tag hygiene, featured images, and front matter conventions for posts, Kartavya Path essays, and Emacs notes.
- Posts live in `collections/_posts/`.
- Kartavya Path essays are posts marked with `kartavya_path: true`.
- Emacs notes live in `collections/_emacs/` (rendered with `_layouts/emacs.html`).

## Taxonomy and categories
Category themes live in `_data/taxonomy.yml` under `themes`. They are used by:
- `categories.html` to group posts by theme.
- `_layouts/post.html` to compute related posts based on overlapping categories.

Guidelines:
- Use the exact category strings defined in `_data/taxonomy.yml` (case and spacing matter).
- Prefer 1-2 categories per post to keep related posts meaningful.
- When introducing a new category, add it to the appropriate theme in `_data/taxonomy.yml` so it appears under the correct heading.

## Tag hygiene
Tags are listed in `_data/taxonomy.yml` under `tags` as a reference list.

Guidelines:
- Use lower-case, kebab-case tags (e.g., `machine-learning`, `computer-science`).
- Avoid duplicates and near-duplicates (`ai` vs `AI`, `book-review` vs `books`).
- Keep tag counts small (3-6 is typical) and only add tags that aid discovery.
- If a new tag is needed, add it to `_data/taxonomy.yml` so the canonical list stays current.

## Featured images
Featured images appear as optional closing visuals after the article prose in `_layouts/post.html`. The text-first homepage does not use thumbnails.

Fields:
- `featured_image`: Path relative to site root, e.g., `assets/images/2025-12-hero.jpg`.
- `featured_image_alt`: Required when `featured_image` is set.
- `featured_image_caption`: Optional text shown below the image in posts.

Guidelines:
- Store images in `assets/images/` with short, kebab-case names (date-prefix recommended).
- Prefer an image that rewards finishing the article rather than acting as introductory decoration.

## Front matter
Front matter drives listing pages, archives, tags, and related posts.

Required (posts):
- `layout: post`
- `title: ...`
- `date: YYYY-MM-DD`
- `categories` or `category`
- `tags`

Common optional keys:
- `description`: One-line summary used for metadata and selected listing pages.
- `comments: true`: Enables the Disqus include for that post.
- `featured_image`, `featured_image_alt`, `featured_image_caption`

There is no per-post `featured` flag; `featured_image` is an image, not a highlight marker.

Notes:
- Both `category` and `categories` are supported by Jekyll; prefer `categories` for new posts.
- Keep keys lower-case and avoid introducing new naming styles unless required by existing templates.

Post example:
```
---
layout: post
title: Example Post
date: 2025-01-01
categories:
  - Technology
tags:
  - ai
  - software-engineering
description: One-line summary used in listings.
comments: true
featured_image: assets/images/2025-01-hero.jpg
featured_image_alt: Short, descriptive alt text.
featured_image_caption: Optional caption for the post header.
---
```

Kartavya Path post example:
```
---
layout: post
title: Example Kartavya Path Essay
date: 2026-06-30
category:
  - Newsletter
tags:
  - newsletter
  - leadership
description: One-line summary for listings.
kartavya_path: true
---
```

The nine migrated issues also have explicit `/newsletter/YYYY-MM-DD-title/` permalinks so their established URLs do not change. New essays can use the standard dated post URL.

### Where things live

- **systemhalted.in** — canonical home of all essays and posts. Everything publishes here first.
- **Kartavya Path on LinkedIn** — syndication target for selected professional-audience posts (see workflow below). Not a source of original content.
- **Substack (palakmathur.substack.com)** — native home for creative writing (short stories, poetry, narrative essays). Not mirrored on the blog.
- **palakmathur.in** — the identity hub (`about-me` repo). Links to all of the above; changes only when a platform is added or retired.

### Publishing workflow (blog-only, LinkedIn syndication)

Everything publishes as a regular blog post in `collections/_posts/`; there is no separate newsletter collection. Legacy issues were moved into the main post archive and marked with `kartavya_path: true`. The Kit (ConvertKit) email list is retired; the on-site CTA and footer point to the LinkedIn newsletter (`newsletter_cta.linkedin_url` in `_config.yml`) and RSS instead.

Selected posts (ones that fit a professional audience) are cross-posted to the Kartavya Path newsletter on LinkedIn:

1. **Publish on the blog first** — commit, push, let Pages build, confirm the public URL renders.
2. **Cross-post the full text to LinkedIn** after the blog URL is live. Prefix the LinkedIn version with "Originally published at <blog URL>" and link the title to the canonical blog post.
3. **Capture the LinkedIn URL** in front matter as `linkedin_url: https://www.linkedin.com/...`. `_layouts/post.html` then renders the "Join the discussion on LinkedIn →" link at the end of the post. Posts without `linkedin_url` are unaffected.

`jekyll-seo-tag` already emits `<link rel="canonical">` pointing to the blog URL, so search engines treat the blog post as canonical even after the LinkedIn cross-post — no extra config needed.

All LinkedIn touchpoints on the site are plain HTML links — no LinkedIn script embeds or plugins — which keeps the site outside LinkedIn's Plugin Terms of Use.

## Emacs notes

Notes live in `collections/_emacs/` and are surfaced on `/emacs/` via `_includes/emacs-list-item.html`. They render through `_layouts/emacs.html` (kicker + title + content + tag chips — no date, comments, or prev/next, since they're evergreen reference material, not dated posts).

Required:
- `layout: emacs`
- `title`

Optional:
- `tags`, `category` — same conventions as posts.
- `toc: true` — render a Table of Contents at the top of the body (uses `jekyll-toc`).
- `description` — short summary used as the excerpt on `/emacs/`. **Strongly recommended** for any note whose first paragraph isn't a natural one-liner; without it, the include falls back to `note.excerpt`, which can be visually noisy or (in pathological cases) malformed HTML.

Emacs note example:
```
---
layout: emacs
title: which-key - A Helpful Emacs Package
tags: [emacs, gnu emacs, which-key]
category: [emacs]
toc: true
description: which-key surfaces all candidate keybindings after a prefix key, removing the need to memorize chord trees.
---
```

## Hero landing pages — `hide_page_title`

Landing pages that provide their own `<h1>` via a hero block (e.g. `.newsletter-hero` on `/kartavya-path/`) should set `hide_page_title: true` in front matter. This suppresses the standard `.page-title` that `_layouts/page.html` would otherwise inject, preventing a duplicate heading above the hero.

Example:
```
---
title: Kartavya Path
layout: page
permalink: /kartavya-path/
hide_page_title: true
---
```

Pages without a hero block (`about.md`, `archives.html`, `categories.html`, `tags.html`, `emacs.html`) should *not* set this flag — they rely on the auto-injected `.page-title` as their only heading. Use `quiet_title: true` when the title should match the restrained About/Archive hierarchy. See `docs/css-updates.md` for the full list.
