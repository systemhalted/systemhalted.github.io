# Content Metadata Guide

This guide covers taxonomy, tag hygiene, featured images, and front matter conventions for posts and newsletters.
Posts live in `collections/_posts/`. Newsletters live in `collections/_newsletter/`.

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
Featured images power the home page card thumbnails and the post hero image in `_layouts/post.html`.

Fields:
- `featured_image`: Path relative to site root, e.g., `assets/images/2025-12-hero.jpg`.
- `featured_image_alt`: Required when `featured_image` is set.
- `featured_image_caption`: Optional text shown below the image in posts.

Guidelines:
- Store images in `assets/images/` with short, kebab-case names (date-prefix recommended).
- Use a landscape image; the home card uses a ~16:10 aspect ratio (`padding-top: 62%`).
- Keep the focal subject away from edges so it crops well on cards.

## Front matter
Front matter drives listing pages, archives, tags, and related posts.

Required (posts):
- `layout: post`
- `title: ...`
- `date: YYYY-MM-DD`
- `categories` or `category`
- `tags`

Common optional keys:
- `description`: One-line summary used on the home grid and archives.
- `comments: true`: Enables the Disqus include for that post.
- `featured: true`: Includes the post on `featured.html`.
- `featured_image`, `featured_image_alt`, `featured_image_caption`

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
featured: true
featured_image: assets/images/2025-01-hero.jpg
featured_image_alt: Short, descriptive alt text.
featured_image_caption: Optional caption for the post header.
---
```

Newsletter example:
```
---
layout: page
title: Example Newsletter
date: 2024-06-30
category:
  - Newsletter
tags:
  - newsletter
  - leadership
description: One-line summary for listings.
---
```
