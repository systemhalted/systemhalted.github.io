# Content metadata

Posts are maintained in `org/posts/`, drafts in `org/drafts/`, evergreen Emacs
notes in `org/emacs/`, and standalone pages in `org/pages/`. The publisher reads
Org keywords before exporting the document body.

## Posts

Required keywords for new posts:

```org
#+TITLE: Example Post
#+DESCRIPTION: One-line summary for listings and metadata.
#+DATE: 2026-09-25
#+CATEGORIES: Software Engineering
#+TAGS: emacs, org, publishing
```

Use category names from `org/data/taxonomy.org`. One or two categories usually
produce useful related-post matches. Tags should be lower-case kebab-case and
limited to terms that help discovery.

The filename supplies the normal date and route. Add `#+PERMALINK` only when an
established route must be retained. Former Kartavya Path essays are regular
posts whose historical `/newsletter/.../` URLs remain unchanged; the site does
not have an active newsletter section.

Optional post keywords:

- `#+COMMENTS: true` enables Giscus.
- `#+TOC: true` adds a generated table of contents.
- `#+MERMAID: true` loads Mermaid and turns a `#+begin_src mermaid` block into
  a diagram in the browser.
- `#+LAST_MODIFIED` records a later revision date.
- `#+FEATURED_IMAGE` names a site-relative image.
- `#+FEATURED_IMAGE_ALT` describes that image; use an empty value only for a
  decorative image.
- `#+FEATURED_IMAGE_CAPTION` supplies optional credit or context.
- `#+KARTAVYA_PATH: true` lists the post on the `/kartavya-path/` landing
  page's "Past issues" feed. It is still an ordinary post in `org/posts/`
  at its normal date-based route; the keyword only adds it to that feed.

Store featured images under `assets/images/`. The production validator rejects
missing local files.

Boolean keywords (`#+COMMENTS`, `#+TOC`, `#+MERMAID`, `#+KARTAVYA_PATH`,
`#+HIDE_TITLE`, `#+QUIET_TITLE`, `#+DRAFT`) accept `true`, `yes`, `t`, or `1`;
anything else, including an empty value, is treated as absent.

### Categories and tags with commas

`#+CATEGORIES` and `#+TAGS` are normally comma-separated. Wrap an item in
double quotes to keep a literal comma inside it, for example a category named
`Series 2 - Turtle, BASIC, and the Long Road to Taste`:

```org
#+CATEGORIES: "Series 2 - Turtle, BASIC, and the Long Road to Taste", Emacs
```

The quotes are stripped; only a comma outside quotes splits items.

## Drafts

`M-x systemhalted-new-post` creates a dated source in `org/drafts/` with
`#+DRAFT: true`. Preview builds include drafts and future dates. Production
builds exclude both. Move a finished draft into `org/posts/` and remove the
draft keyword before publishing.

## Emacs notes and pages

Emacs notes require `#+TITLE` and `#+DESCRIPTION`; tags and a table of contents
are optional. Pages also require a title and description and normally set an
explicit route:

```org
#+TITLE: About
#+DESCRIPTION: About Palak Mathur and SystemHalted.
#+PERMALINK: /about/
```

A page may also set:

- `#+HIDE_TITLE: true` omits the generated `<h1 class="page-title">` entirely
  (the page body supplies its own heading, e.g. a hero section).
- `#+QUIET_TITLE: true` keeps the `<h1>` but adds a `page-title-quiet` class
  that de-emphasizes it visually.

Both only affect the plain `page.html` wrapper; posts, drafts, and Emacs notes
render their own headers and ignore these two keywords.

### The home page

`org/pages/index.org` (route `/`) supplies the home page's hand-written parts
— the intro header and the Kartavya Path blurb. The generator exports its
body and splices the computed "Recent writing" list (the 10 most recent
posts, plus an "All writing →" link) in at the `<!--RECENT_POSTS-->` marker
in that file. Edit the surrounding Org-authored text there; the recent-posts
list itself is generator-owned.

### Generated (non-Org) pages

These routes have no corresponding file under `org/pages/`; the publisher
builds them from data files and post records instead:

- `/pageN/` — older home-page chunks, with 10 posts per page. Page 1 is `/`
  and uses `org/pages/index.org`; later pages are fully generated.
- `/categories/`, `/tags/`, and `/archives/` — derived from post metadata
  (`#+CATEGORIES`, `#+TAGS`, and dates). `/categories/` additionally groups
  categories by theme using `org/data/taxonomy.org`.
- `/emacs/` — derived from the title and description of each source in
  `org/emacs/`.
- `/jsgames/` — listed from `org/data/jsgames.org`; the games themselves live
  under `jsgames/`.
- `/themes/` — listed from `org/data/themes.org`.
- `/webcmd/` — static markup from `publish/templates/webcmd.html`. Its
  interactive behavior is `publish/templates/webcmd-runtime.js`, appended
  into the generated `/assets/js/webcmd.js` bundle alongside the search index
  and `org/data/os-history.org` fortunes/timeline data. There is no Org
  source file for this page itself.
- `/kartavya-path/` — a landing page with fixed hero copy in the generator
  and `site-config.el` (the `systemhalted-newsletter-cta-*` values), plus a
  "Past issues" feed of every post whose `#+KARTAVYA_PATH: true` keyword
  is set. The posts themselves stay ordinary Org posts in `org/posts/`.

The other authored pages are `/404.html`, `/about/`, and `/projects/`, from
`org/pages/404.org`, `org/pages/about.org`, and `org/pages/projects.org`.
The Projects page includes the entries in `org/data/projects.org`.

### Generated non-page files

The same build writes these root and asset files:

- `/sitemap.xml` contains the public route inventory. Non-ASCII path segments
  are percent-encoded. `<lastmod>` uses a record's UTC date when it has one,
  then falls back to `#+LAST_MODIFIED` for an undated record.
- `/robots.txt` contains the absolute sitemap URL.
- `/links.jsonp` is a `callback(...)` array of post titles and absolute URLs
  in reverse chronological order.
- `/feed.xml` is RSS 2.0. It includes up to 50 posts, Atom self-link metadata,
  categories, `dc:creator`, and the full exported body in `content:encoded`.
- `/assets/js/webcmd.js` contains the post and Emacs-note search documents,
  Elasticlunr index setup, OS-history data from `org/data/os-history.org`, and
  `publish/templates/webcmd-runtime.js`. The `/webcmd/` page references it with
  a deterministic content-hash cache-busting token.

## Exported HTML compatibility

Heading IDs follow kramdown's shape: lower-case text, unsupported punctuation
removed, spaces replaced with hyphens, and numeric suffixes for duplicates.
An Org `CUSTOM_ID` overrides the derived ID.

Footnotes use `fnref:N` references, `fn:N` list entries, and reverse-footnote
backlinks. Repeated references receive numbered reference IDs and backlinks.

`#+TOC: true` creates a nested disclosure with
`<details class="post-toc">`, a “Contents” summary, a navigation landmark, and
`<ul id="toc" class="section-nav">` entries linked to the heading IDs.

### Dates are UTC

A post's displayed date and its date-based URL segment are both the UTC date
of its `#+DATE` timestamp (or filename date), matching Jekyll's behavior on
GitHub's UTC build runners. A bare date (no time) is midnight UTC.

## Links and raw HTML

Use normal Org links for external and site-relative targets. A link to another
`.org` file is resolved through its content record, so the generated HTML uses
the target's final route. Raw HTML belongs in an Org export block:

```org
#+begin_export html
<aside class="example">HTML needed by this page.</aside>
#+end_export
```

The content audit rejects Liquid constructs and non-Org files in the maintained
content directories.
