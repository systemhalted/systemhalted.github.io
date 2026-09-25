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
- `#+LAST_MODIFIED` records a later revision date.
- `#+FEATURED_IMAGE` names a site-relative image.
- `#+FEATURED_IMAGE_ALT` describes that image; use an empty value only for a
  decorative image.
- `#+FEATURED_IMAGE_CAPTION` supplies optional credit or context.

Store featured images under `assets/images/`. The production validator rejects
missing local files.

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
