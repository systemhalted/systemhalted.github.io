# systemhalted.github.io

Org-first source for [systemhalted.in](https://systemhalted.in). Emacs exports
the complete static site into `_site/`. Jekyll, Ruby, and generated Markdown
are not part of the publishing path.

## Emacs setup

The interactive commands can be autoloaded from an Emacs configuration. This
keeps the publisher unloaded until one of the commands is invoked:

```elisp
(let ((workflow "/path/to/systemhalted.github.io/publish/systemhalted-workflow.el"))
  (dolist (command '(systemhalted-new-post
                     systemhalted-preview
                     systemhalted-build
                     systemhalted-publish
                     systemhalted-stop-preview-server))
    (autoload command workflow nil t)))
```

Loading `publish/systemhalted-workflow.el` directly also defines the commands.
`systemhalted-build` and `systemhalted-preview` reload
`publish/site-config.el` on every run. `systemhalted-publish` and the batch
entry point call `systemhalted-build`, so they receive the same settings.

After editing publisher code in a session where it is already loaded, reload
both files in this order so Emacs does not reuse the cached publisher feature:

```elisp
(load-file "/path/to/systemhalted.github.io/publish/systemhalted-publish.el")
(load-file "/path/to/systemhalted.github.io/publish/systemhalted-workflow.el")
```

The publisher uses the Org and HTML libraries bundled with Emacs 31.1 and the
vendored `publish/htmlize.el`. It does not install packages or execute Babel
blocks.

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

The authored home page contains a `<!--RECENT_POSTS-->` marker. The generator
replaces it with the 10 newest posts and an “All writing” link. `/about/`,
`/projects/`, and `/404.html` also come from `org/pages/`; the Projects source
includes `org/data/projects.org`. Generated collection data lives in
`org/data/jsgames.org`, `org/data/themes.org`, `org/data/taxonomy.org`, and
`org/data/os-history.org`. The Webcmd page markup lives in
`publish/templates/webcmd.html`.

The common footer comes from `publish/templates/base.html` and includes the
credit “Proudly made with Emacs and Org mode.”

## Generated compatibility files

The build writes files used by crawlers, feed readers, search, and older
consumers in addition to HTML pages:

- `/sitemap.xml` percent-encodes non-ASCII route segments and adds `<lastmod>`
  from a record's UTC date, or from `#+LAST_MODIFIED` when the record has no
  date.
- `/robots.txt` points crawlers to the sitemap.
- `/links.jsonp` calls `callback(...)` with every post title and absolute URL
  in reverse chronological order.
- `/feed.xml` is an RSS 2.0 feed. It includes Atom self-link metadata,
  categories, author data, and full post HTML in `content:encoded`.
- `/assets/js/webcmd.js` contains the post and Emacs-note search documents,
  the Elasticlunr compatibility globals, OS-history data, and the maintained
  Webcmd runtime. `/webcmd/` loads it with a deterministic SHA-256-derived
  content token in the query string.

## Export compatibility

Org headings receive kramdown-compatible IDs. Repeated headings get `-1`,
`-2`, and later suffixes. Footnote references and the endnotes list use the
kramdown `fnref:` and `fn:` ID shape, including backlinks. `#+TOC: true`
builds a nested `<details class="post-toc">` disclosure with a
`nav` labelled “Table of contents” and a `ul.section-nav` list.

Source blocks keep the kramdown/Rouge wrapper classes. The publisher uses the
vendored htmlize library with CSS classes prefixed `org-`; their colours are
defined in `assets/css/nord.css`. A language is highlighted only when the
clean batch Emacs has a built-in major mode for it. Go, Rust, JSON, and YAML
blocks currently remain escaped plain text because their requested major modes
and tree-sitter grammars are unavailable in the batch environment.

## Validation

Run every ERT suite in a separate clean Emacs process:

```sh
for t in test/*-test.el; do
  emacs -Q --batch -L publish -L test -l "$t" \
    -f ert-run-tests-batch-and-exit
done
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

After a production build, compare the generated site with the live site:

```sh
scripts/parity-check.sh
```

The script compares decoded sitemap routes, scans generated HTML for `file:`
URLs and missing root-relative targets, and compares selected live and local
pages for titles, canonical and robots metadata, Open Graph and Twitter tags,
JSON-LD types, and classes inside `<main>`. `--report DIR` selects the cache
and report directory; the default is `tmp/parity/`. `--refresh` fetches the
live sitemap and sample pages again instead of using cached copies.

For a completed comparison, the script exits 0 when the sitemap routes match
and `_site/` contains no `file:` URLs. Route differences, `file:` URLs, or a
failed live sample fetch produce exit 1. Missing root-relative targets and
sample-page metadata differences are reported but do not change the exit
status.

`.github/workflows/pages.yml` runs the ERT suites, production build, CI
contract, and EWW rendering check before uploading and deploying `_site/` to
GitHub Pages. `.github/workflows/a11y.yml` runs the CI contract, production
build, EWW check, browser smoke test, and Axe audit on pushes to `main` and on
pull requests.

The annotated tag `jekyll-final` identifies the last Jekyll version of the
site and is the rollback reference for the retired build.

## Supporting documentation

- [Accessibility](docs/accessibility.md)
- [Content metadata](docs/content-metadata.md)
- [Search architecture](docs/search-architecture.md)
- [Webcmd](docs/webcmd.md)

Do not edit `_site/`; every file there is generated.
