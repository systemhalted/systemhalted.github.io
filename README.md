# systemhalted.github.io

Org-first source for [systemhalted.in](https://systemhalted.in). Emacs exports
the complete static site into `_site/`. Jekyll, Ruby, and generated Markdown
are not part of the publishing path.

## Emacs setup

Load the repository workflow from your Emacs configuration:

```elisp
(load "/path/to/systemhalted.github.io/publish/systemhalted-workflow.el")
```

To try it in a running Emacs first, evaluate the same form with `M-:` (or use
`M-x load-file` and select this file). The `systemhalted-*` commands appear
after the workflow file has loaded. Keep the `load` form in your init file to
make them available after each Emacs restart.

After editing publisher code in a session where it is already loaded, reload
both files in this order so Emacs does not reuse the cached publisher feature:

```elisp
(load-file "/path/to/systemhalted.github.io/publish/systemhalted-publish.el")
(load-file "/path/to/systemhalted.github.io/publish/systemhalted-workflow.el")
```

The publisher uses the Org and HTML libraries bundled with Emacs 31.1. It does
not install packages or execute Babel blocks.

## Authoring and publishing

- `M-x systemhalted-new-post` creates `org/drafts/YYYY-MM-DD-title.org` and
  prompts for the required title and description.
- Fill in `#+CATEGORIES` and `#+TAGS`, then write the article in Org syntax.
- `M-x systemhalted-preview` saves the current source, builds drafts and future
  posts, starts a local server, and opens the page at its public route.
- `M-x systemhalted-stop-preview-server` stops the local server.
- To publish a draft, move it from `org/drafts/` to `org/posts/` and remove
  `#+DRAFT: true`.
- `M-x systemhalted-build` creates and validates the production `_site/`.
- `M-x systemhalted-publish` runs the production build and opens Magit when it
  is loaded, otherwise `vc-dir`. It does not stage, commit, or push.

The equivalent clean batch build is:

```sh
emacs -Q --batch -L publish \
  -l publish/systemhalted-workflow.el \
  -f systemhalted-batch-build
```

## Org metadata

A normal post starts with:

```org
#+TITLE: Sample Post
#+DESCRIPTION: One-line summary used in listings and metadata.
#+DATE: 2026-09-25
#+CATEGORIES: Software Engineering
#+TAGS: emacs, org, publishing
#+COMMENTS: true
#+TOC: true
```

The date and route normally come from the `YYYY-MM-DD-slug.org` filename.
`#+PERMALINK` retains an exceptional or historical URL. Optional featured-image
keywords are `#+FEATURED_IMAGE`, `#+FEATURED_IMAGE_ALT`, and
`#+FEATURED_IMAGE_CAPTION`. A featured image must exist under `assets/` and
needs useful alt text unless it is decorative. Dates are the UTC date of the
timestamp, matching Jekyll's UTC build runners.

A category or tag name containing a literal comma needs double quotes, e.g.
`#+CATEGORIES: "Series 2 - Turtle, BASIC, and the Long Road to Taste"`.

Other optional keywords: `#+MERMAID: true` loads Mermaid for a
`#+begin_src mermaid` block; `#+KARTAVYA_PATH: true` also lists a post on the
`/kartavya-path/` landing page's "Past issues" feed; `#+HIDE_TITLE: true` and
`#+QUIET_TITLE: true` (pages only) omit or de-emphasize the generated page
title. See [Content metadata](docs/content-metadata.md) for the full list and
accepted values.

Internal links may point directly at another Org source. The exporter resolves
the target record and writes its final public URL. Site-relative links such as
`[[/archives/][archive]]` also work.

## Repository structure

- `org/posts/`: published articles.
- `org/drafts/`: unpublished and in-progress articles.
- `org/emacs/`: evergreen Emacs notes.
- `org/pages/`: authored standalone pages.
- `org/data/`: editable project, theme, game, taxonomy, and webcmd data.
- `publish/`: the built-in-Emacs generator, HTML templates, site settings, and
  interactive workflow.
- `assets/`: images, CSS, JavaScript, icons, and the web manifest.
- `jsgames/`: standalone browser games with their local assets.
- `test/`: ERT coverage and the checked compatibility route manifest.
- `scripts/`: browser, accessibility, and rendering checks.

Derived pages include the home page (built from `org/pages/index.org` plus a
generated recent-posts list), its `/pageN/` pagination, `/archives/`,
`/categories/`, `/tags/`, the `/emacs/` index, RSS feed, sitemap, and search
data. `/jsgames/`, `/themes/`, `/webcmd/`, and `/kartavya-path/` are also
generated, not authored as `org/pages/*.org` files; see
[Content metadata](docs/content-metadata.md#generated-non-org-pages) for
where each one's content comes from. Kartavya Path essays are ordinary posts
in `org/posts/` at their normal date-based URLs, flagged with
`#+KARTAVYA_PATH: true` to appear on the `/kartavya-path/` landing page.

## Validation

Run the publisher and workflow suites with:

```sh
emacs -Q --batch -L publish \
  -l test/systemhalted-publish-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch -L publish \
  -l test/systemhalted-workflow-test.el \
  -f ert-run-tests-batch-and-exit
```

The production build rejects invalid metadata, duplicate or unsafe routes,
untranslated Liquid, broken local links, missing assets, and malformed XML. It
builds in a temporary directory and replaces `_site/` only after validation.

For browser accessibility checks, keep an Emacs preview running and use:

```sh
npm install
npm run a11y
```

The generated search bundle remains at `/assets/js/webcmd.js` for consumers of
the public `ensureSiteIndex`, `siteIndex`, `siteStore`, and `siteDocs` globals.

## Supporting documentation

- [Accessibility](docs/accessibility.md)
- [Content metadata](docs/content-metadata.md)
- [Search architecture](docs/search-architecture.md)
- [Webcmd](docs/webcmd.md)

Do not edit `_site/`; every file there is generated.
