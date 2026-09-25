# Org-First Publishing Design

## Goal

Make Org files the only maintained source for published writing while preserving
the current SystemHalted design, public URLs, archives, taxonomy, search, feeds,
comments, and GitHub Pages hosting. Jekyll, Ruby, Liquid, and generated Markdown
must not participate in the final publishing path.

## Architecture

Content lives as one Org file per item in `org/posts`, `org/drafts`,
`org/emacs`, and `org/pages`. Repository Elisp under `publish/` performs a
two-pass build: it first parses and validates every source into a normalized
record, then exports Org bodies and renders pages derived from the complete
record set. Static assets remain source assets and are copied unchanged.

The publisher uses only libraries bundled with Emacs 31.1. A derived `ox-html`
backend owns body behavior such as heading levels, code blocks, footnotes,
tables, raw HTML, and links between Org sources. Repository HTML templates
replace Liquid. The generated `_site` directory stays ignored.

## Content Contract

Every authored item has `#+TITLE` and `#+DESCRIPTION`. Posts also have a date,
categories, and tags. Normal post filenames use `YYYY-MM-DD-slug.org`; the
filename supplies the default date and permalink. `#+DATE` and `#+PERMALINK`
preserve legacy times and exceptional routes. Optional keywords cover comments,
table of contents, last modification, and featured-image metadata.

Drafts are separate sources and never appear in production. Preview builds may
include drafts and future-dated posts. Date-only values use UTC, matching
Jekyll on GitHub's UTC runners; dates with explicit times and offsets convert
to the equivalent UTC instant.

The former Kartavya Path essays are ordinary posts. Their existing
`/newsletter/.../` permalinks remain, while newsletter flags, promotion,
templates, taxonomy, and active landing page disappear. `/kartavya-path/`
redirects to `/archives/`.

## Generated Site

The build produces posts, pages, home pagination, chronological archives,
categories, tags, themes/series, projects, games, Emacs notes, related and
adjacent article links, RSS, sitemap, browser-search data, metadata, structured
data, Giscus comments, and redirects. Existing CSS, JavaScript, images, games,
icons, `CNAME`, and intentional standalone files continue to ship.

Writes happen in a temporary directory. A successful build atomically replaces
`_site`; a failed build leaves the last successful output intact. Duplicate or
unsafe routes, invalid metadata, missing local assets, broken internal links,
malformed XML, and nondeterministic output fail publication with the responsible
source path in the error.

## Emacs and Deployment Workflow

`systemhalted-new-post` creates a dated Org draft. `systemhalted-preview` saves
and validates the current source, builds with drafts, serves `_site` through a
small built-in-Elisp HTTP server, and opens the final URL.
`systemhalted-build` makes a production build. `systemhalted-publish` runs the
production checks and opens Magit, falling back to `vc-dir`; it never stages,
commits, or pushes.

Pushing `main` runs the same batch functions under Emacs 31.1 in GitHub Actions,
then runs the existing EWW, browser, and Axe checks and deploys the `_site`
artifact to GitHub Pages. The generator has no package or CLI dependency beyond
Emacs; Node remains a QA dependency.

## Migration and Acceptance

The existing Jekyll output supplies a checked compatibility manifest. Existing
Org sources remain authoritative. Pandoc is allowed only for the one-time
conversion of remaining Markdown and HTML content. Conversion must stop on
unrecognized Liquid rather than silently dropping it.

Before cutover, old and new builds must agree on public routes except for the
deliberate newsletter landing redirect. Titles, dates, descriptions, canonical
URLs, taxonomy, structured metadata, normalized article text, internal links,
images, feeds, search, and redirects must remain valid. Representative legacy,
modern, Unicode, code-heavy, image-heavy, custom-permalink, newsletter-origin,
and Emacs pages receive visual review. Two clean production builds must have
identical file hashes.

