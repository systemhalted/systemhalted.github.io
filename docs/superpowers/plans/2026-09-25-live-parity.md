# Live-site parity for the Org build

Spec: `docs/superpowers/specs/2026-09-25-org-first-publishing-design.md`. This plan overrides it on two points: `/kartavya-path/` stays a full landing page instead of a redirect, and dates are handled in UTC (the spec says US/Central).

## Context

The Org/Emacs build (`publish/systemhalted-publish.el`, called "sp.el" below, plus `publish/templates/`) must produce a site that looks and behaves like the live Jekyll site at https://systemhalted.in, which is built from the `main` branch. The reference sources are `git show main:<path>`: `_layouts/`, `_includes/`, `_config.yml`, `index.html`, `categories.html`, `tags.html`, `kartavya-path.html`, `themes.html`, `webcmd/index.html`, `jsgames/index.html` and `assets/css/nord.css`.

The goal is the same look, the same URLs and the same anchors. Org-specific wrapper markup can stay as long as nord.css renders it the same way. Pagination changes are out of scope: `/pageN/` pages keep being generated, and nobody links to them.

## Global Constraints

- **Emacs only:** the build uses Emacs 31.1 and Emacs Lisp. Do not add Ruby, Python or Node as build dependencies. Node is only used for QA scripts.
- **Test-first:** before each fix, add a failing ERT test in `test/systemhalted-publish-test.el`.
- **Tests:** run every suite with `for t in test/*-test.el; do emacs -Q --batch -L publish -L test -l "$t" -f ert-run-tests-batch-and-exit; done`. Every suite must pass.
- **Build:** `emacs -Q --batch -L publish -l publish/systemhalted-workflow.el -f systemhalted-batch-build` must succeed. Two clean builds must stay byte-identical (the existing determinism test), so the output must not contain wall-clock timestamps.
- **Commits:** do not commit `_site/` or `.systemhalted-stage-*`. Use short imperative commit messages. Do **not** add any `Co-Authored-By` or "Generated with" trailer.
- **Route baseline:** if the set of public routes changes on purpose, update `test/baseline/routes.tsv` in the same commit and explain why in the commit body.
- **Dates:** the date shown on a post and its URL date are the UTC date of its timestamp, matching Jekyll on GitHub's UTC runners.
  - `<time datetime>` uses the form `YYYY-MM-DDT00:00:00+00:00`.
  - The display format for post meta is `%-d %B %Y`.
- **Where to look:** the live HTML is the ground truth for how things look. Fetch it with `curl -sL https://systemhalted.in/<path>`.

---

## Task 1: Parity check script

Create `scripts/parity-check.sh` (bash, using curl, grep and sed or xmllint if available). Python is allowed here because this is QA, not the build. It compares the live site with the local `_site/`.

1. **Routes:** fetch `https://systemhalted.in/sitemap.xml` and extract the `<loc>` paths, percent-decoded. Compare them with the `<loc>` paths in `_site/sitemap.xml` (also decoded) and print the paths that appear only on one side.
2. **Broken URLs:** count `file:` URLs anywhere in `_site/**/*.html`. Also count root-relative `href`/`src` targets that do not exist in `_site/`, ignoring external links and pure `#anchor` links.
3. **Page comparison:** for each sample page, print a compact side-by-side diff of:
   - `<title>`
   - the `rel=canonical` href
   - the `meta name=robots` content
   - every `og:*` and `twitter:*` meta
   - the JSON-LD `@type` values
   - the sorted, unique `class` tokens found inside `<main>`
4. **Sample pages:**
   - `/`
   - `/2026/09/23/java28-value-objects/`
   - `/2026/01/11/kahan-summation-java-streams/`
   - `/2026/07/17/the-2d-1d-problem-in-text-editors/`
   - `/2011/01/28/lokpal-bill/` (look up the exact route in the live sitemap)
   - `/archives/`, `/categories/`, `/tags/`, `/about/`
   - `/emacs/`, `/emacs/emacs-config/`
   - `/kartavya-path/`, `/jsgames/`, `/themes/`, `/webcmd/`, `/404.html`
5. **Exit status:** 0 when there are no route differences and no `file:` URLs, otherwise 1. Put a `--report DIR` option on it that writes full per-page diffs to DIR (default `tmp/parity/`), and add `tmp/` to `.gitignore`.

There is no ERT test for this task. Verify it by running the script against the current build and saving its output in the report. It is expected to fail at this point.

## Task 2: Root-relative links and images

Org exports `[[/path/]]` and `[[/assets/x.svg]]` as `file:///path/`. This affects 34 pages. For example, `_site/jsgames/index.html` has `href="file:///jsgames/pig-game/"`, and the 2026-07-17 post has `<img src="file:///assets/images/2026-07-17-2d-1d-grid.svg" alt="2026-07-17-2d-1d-grid.svg">`.

- In the derived HTML backend in sp.el, make `file` links whose path starts with `/` export as root-relative URLs: `href="/path/"`, and `src="/assets/..."` for inline images.
- For images, use the link description, `#+CAPTION` or `#+ATTR_HTML :alt` as the alt text, whichever the source has, and never the bare file name. Compare with the live alt text for that post.
- Make the site validator (`systemhalted--validate-output` or equivalent, around sp.el:1063-1092) fail the build when any `href`/`src` starts with `file:`.
- Add tests for the link export, for the image `src` and `alt`, and for a fixture page with a `file:` URL making validation fail.

## Task 3: UTC dates and moved post URLs

43 posts, mostly from 2006–2012, now resolve to a URL one day earlier than the live one. For example, live `/2006/08/17/nothing-is-well/` versus local `/2006/08/16/nothing-is-well/`. Jekyll converted `date: 2006-08-16 23:16 -05:00` to UTC.

1. Build in UTC. Make every date computation in sp.el use UTC explicitly (for example `format-time-string ... t` or `(set-time-zone-rule t)` inside the build). Date-only values mean 00:00 UTC.
2. Emit every `<time datetime>` (posts, archive rows, home list, related posts) in the form `YYYY-MM-DDT00:00:00+00:00`, matching the live output.
3. Use the Task 1 route diff to find every post whose route differs from the live sitemap only in its date. Fix each one by correcting the org file's `#+PERMALINK` (or `#+DATE`) so the route equals the live URL.
4. Add `test/baseline/live-routes.tsv`: the decoded live sitemap paths, excluding `/pageN/` if the live sitemap lists those. Add an ERT test that asserts every live route exists in a production build.
5. Update the spec's "US/Central" sentence to say UTC.

## Task 4: Keep drafts out, and category names that contain commas

- **Drafts:** `org/drafts/*.org` (3 files) ends up in the production build and in `_site/sitemap.xml`:
  - `2006/12/01/bas-aise-hi-likh-raha-hoon-dont-read-it`
  - `2011/06/19/usa-in-talks-with-taliban…`
  - `2026/08/02/wisdom-accumulation-notes`
  
  Find out why (see `systemhalted-load-records`, sp.el:176-198, and how `systemhalted-batch-build` calls it) and exclude drafts from production builds. Preview builds may still include them. Add a test that no draft route appears in a production build.
- **Commas:** list keywords are split on commas (sp.el:62-65), so the category `Series 2 - Turtle, BASIC, and the Long Road to Taste` becomes three categories.
  - Support double-quoted items in `#+CATEGORIES` / `#+TAGS`, for example `"Series 2 - Turtle, BASIC, and the Long Road to Taste", Computer Science`.
  - Quote every affected org file. Grep `org/` for categories that exist on `main` (`git grep -h '^categor' main -- collections/_posts`) and contain commas.
  - Add parsing tests.

## Task 5: KaTeX and Mermaid

- Add the KaTeX JS and auto-render scripts to `publish/templates/base.html`, matching `main:_includes/head.html`: the same versions, SRI and `defer`, and the same `renderMathInElement` delimiters `$$`, `$`, `\(`, `\[`. The Kahan post (`/2026/01/11/kahan-summation-java-streams/`) must then contain `katex` script tags.
- Add Mermaid support:
  - A post opts in with `#+MERMAID: true`, and only then does it load mermaid 10.9.3 the way `main:_includes/head.html` does.
  - `#+begin_src mermaid` blocks export as `<div class="mermaid">…</div>`, or in the `language-mermaid` form that main's script converts.
  - Set the keyword on `org/posts/2026-07-26-diagrams-as-text.org`, and on any other post that has mermaid blocks.
- Add tests: the script tags are present, and a mermaid block exports correctly.

## Task 6: Head metadata and SEO

Make `base.html` and the render code (around sp.el:498-561) produce the same head as `main:_includes/head.html` plus what jekyll-seo-tag emits live. Check the live HTML for the exact output.

- **Robots:** fill the `%r` slot with `<meta name="robots" content="noindex,follow">` on `/pageN/` and `/404.html`.
- **Title:** `<title>` is `Title | SystemHalted.in`.
  - Home: `SystemHalted.in | <site description>`.
  - `/pageN/`: `Page N of M for SystemHalted.in`. Check this against the live `/page2/`.
  - `og:title` and `twitter:title` are the bare title.
  - Restore the full live site description, taken from `main:_config.yml`, in `publish/site-config.el`.
- **Open Graph and Twitter:**
  - `og:type` is `website` except on posts, which use `article`, plus `article:published_time`.
  - Add `og:locale` (`en_US`), `og:image` and `twitter:image` (the featured image if the page has one, else the avatar `/assets/images/avatar.jpeg`, as an absolute URL), `twitter:title`, `meta name=author`, and `meta name=generator`.
  - `twitter:card` values: match whatever the live site emits for each page type.
- **Other head items:**
  - `google-site-verification` and Google Analytics (gtag, id `UA-36868278-1`) exactly as in `main:_includes/head.html`. Put the ids in `site-config.el`.
  - The `systemhalted-terminal-32.png` icon link.
- **JSON-LD:** port `main:_includes/structured-data.html`.
  - Person, with `sameAs` from the social links.
  - WebSite, on `/` only, with `alternateName` and `inLanguage`.
  - Posts: BlogPosting with `datePublished`, `author` pointing to `#person`, and `image`.
- **Cache-busting:** replace `?v=org` on CSS and JS with `?v=<N>`, where N is a deterministic value (for example the newest mtime or a content hash of `assets/css` and `assets/js`, not the wall clock).
- **Footer year:** the year of the newest post, not the hard-coded `2026`.
- **Search suggestions:** add `newsletter` back, giving emacs, leadership, newsletter, javascript.
- **Tests:** add a test for each item.

## Task 7: Sitemap, robots.txt, links.jsonp and feed

- **`/sitemap.xml`:**
  - Percent-encode non-ASCII paths the same way the live sitemap does.
  - Add `<lastmod>` from the date or last-modified value, in UTC.
  - Leave out `/404.html` and redirect stubs.
  - Include the `/jsgames/<game>/` pages and the wireframes page if the live sitemap has them.
  - Use the Task 1 route diff to reach zero differences.
- **`/robots.txt`:** `Sitemap: https://systemhalted.in/sitemap.xml`, matching the live file.
- **`/links.jsonp`:** port `main:links.jsonp`, which produces `callback([{"text":…,"href":…}, …])` for all posts in the same order. Check the live file for the escaping.
- **`/feed.xml`:** it stays RSS 2.0, but add:
  - `<atom:link rel="self">`
  - `<category>` per category
  - an `<author>` or `dc:creator` element
  - `<content:encoded>` with the full post HTML
  
  It must stay valid XML (the existing check covers that).
- **Tests:** add tests for all of the above.

## Task 8: Page titles and the page skeleton

- **Home:** render `/` (and `/pageN/`) directly into `base.html` without going through `page.html`, so the stray `<div class="page"><h1 class="page-title">Writing</h1>` disappears. Compare the home `<main>` with live.
  - The live home page has no pager, and `/pageN/` pages are orphans. Just remove their duplicate h1 and keep `noindex` from Task 6.
- **Page titles:** add `#+HIDE_TITLE: true` and `#+QUIET_TITLE: true` page keywords (Codex's recent commit `6a5b40f` added quiet-title support; extend it).
  - Quiet on about, archives, categories, tags, emacs, projects and jsgames.
  - Hidden on kartavya-path, themes and webcmd.
  - For generated pages (archives, categories, tags, emacs), set the equivalent in code.
- **`org/pages/404.org`:** remove the h2 that duplicates the title, so the body matches live: a bare h1 plus a paragraph with a "Head back home" link.
- **`org/pages/webcmd.org`:** remove the stray `Webcmd` paragraph and the duplicate h2. Task 11 restores the full webcmd markup.
- **Archive gateways** (sp.el around line 684): `aria-current="page"` goes on the link for the section actually being viewed (Archive, Categories, Tags or Emacs), not always Archive.
- **Tests:** add tests.

## Task 9: Kartavya Path landing page

- Remove the `/kartavya-path/` → `/archives/` redirect (sp.el around 970-976 and 1045-1049).
- Generate `/kartavya-path/` to match `main:kartavya-path.html` and `main:_includes/newsletter-cta.html`:
  - `section.newsletter-hero`: `p.newsletter-brand`, `p.newsletter-kicker[lang=hi]` "कर्तव्य पथ", `h1.newsletter-headline`, `p.newsletter-lede`.
  - `aside.newsletter-cta.newsletter-cta--landing#newsletter-cta`.
  - `h2.recent-title` "Past issues".
  - `ul.post-feed` of posts flagged as Kartavya Path, using the `newsletter-list-item` markup.
  - The text comes from `main:_config.yml` `newsletter_cta`; put it in `site-config.el`.
- Add a `#+KARTAVYA_PATH: true` keyword to the posts that have `kartavya_path: true` on main. They are the ones with a `/newsletter/` permalink; check with `git grep -l 'kartavya_path: true' main`.
- On the home page, add `section.home-section.home-kartavya` as in `main:index.html`.
- **Home page source:** add `org/pages/index.org` (permalink `/`) holding the hand-written parts of the home page: the `header.home-intro` name and tagline, and the Kartavya Path blurb. The generator keeps only the computed parts, the 10 most recent posts and the "All writing →" link, and places them between the intro and the Kartavya section. The rendered `<main>` must match `main:index.html` page 1. The author edits the home page text in Org from now on.
- Restore the `newsletter` category and tag on those posts, if main has them.
- Restore every `.newsletter-*` rule that exists in `main:assets/css/nord.css` but is missing from the worktree's `assets/css/nord.css` (diff the two files; roughly live lines 1003-1063).
- Update `test/baseline/routes.tsv` if needed.
- Update the spec text about the Kartavya Path redirect.
- Add tests.

## Task 10: Categories and tags pages

- **`/categories/`:** read `org/data/taxonomy.org`, which mirrors `main:_data/taxonomy.yml`. Render it like `main:categories.html`:
  - The intro and the gateways.
  - One `section.taxonomy-section` per taxonomy theme, with `h2#<theme-id>` (series, tech_engineering, ai_data, politics_society, books_media, language_lit_spirit, life_personal, hobbies_travel, meta_format, newsletter) and the theme description.
  - Each category in it as `details#cat-<slug>.archive-year.taxonomy-group` with the archive summary and list markup.
  - Categories that belong to no theme go under `h2#other-categories`.
  - Match the live order of themes and of categories within each theme.
- **`/tags/`:** match `main:tags.html`: `div.tag-groups`, ids equal to the slug, and when two tags slugify to the same value, add a `--N` suffix exactly as main does (for example `api-design--34`, `linux--125`, `nan--145`). Check the ids against live.
- Add tests.

## Task 11: Emacs notes, jsgames, themes and webcmd pages

- **Emacs notes:** use `p.newsletter-kicker` "Emacs note" and `h1.newsletter-title`, not `note-kicker` and `emacs-note-title`. Add `div.post-tags` with links to `/tags/#<slug>`, as `main:_layouts/emacs.html` does.
- **`/emacs/` index:** give each item `div.post-feed-meta > span.post-feed-cat` "Emacs note", as `main:_includes/emacs-list-item.html` does.
- **`/jsgames/`:** generate `ul.post-feed.jsgame-list` from `org/data/jsgames.org`, using `main:_includes/jsgame-list-item.html` markup. Remove the `#+INCLUDE`-based `org/pages/jsgames.org`, or reduce it to front matter. Use a quiet title.
- **`/themes/`:** generate from `org/data/themes.org` to match `main:themes.html`:
  - Title "Jekyll Themes", with the title hidden.
  - `section.newsletter-hero`.
  - `ul.theme-gallery > li.theme-card` with every field.
  - The page's inline `<style>` block, copied verbatim.
- **`/webcmd/`:** restore the markup of `main:webcmd/index.html` (`section.webcmd > div.webcmd-shell` and everything inside it), as a template in `publish/templates/`. Load `/assets/js/elasticlunr.min.js` and `/assets/js/webcmd.js?v=<N>` on that page only, as `main:_layouts/default.html` does. `scripts/browser-smoke.js` checks this page; keep it passing.
- Add tests.

## Task 12: Post footer

Match `main:_layouts/post.html`:
- `nav.post-nav` goes *inside* `section.post-more`, after the related list.
- `section.post-more` renders when there are related posts or newer/older links. Its heading `h2#more-writing-heading.post-more-heading` reads "More from SystemHalted".
- **Related labels** (`systemhalted--related-html`, sp.el:393-411), in order of preference:
  1. "More from <category>", using the shared category with the fewest posts site-wide.
  2. Otherwise "Also about <tag>", using the last shared tag in the page's tag order.
  3. Otherwise "Related reading".
- **Scoring** (`systemhalted--related-records`, sp.el:369): +3 per shared category, +2 per shared tag. When nothing is shared, +1 per sibling category in the same taxonomy theme (use `org/data/taxonomy.org`). Keep the top 3, and break ties by newer date.
- Related-post dates use the `%b %d, %Y` format.
- Verify three sample posts against live: the related titles, the labels and their order must match.
- Add tests.

## Task 13: Syntax highlighting

Code blocks are currently plain escaped text. Live output uses Rouge `<span class="k">` style tokens.

- Vendor `htmlize.el` (from https://github.com/hniksic/emacs-htmlize, GPL-3, keeping its header) as `publish/htmlize.el`. The directory name `vendor` is gitignored, so do not use it.
- Set `org-html-htmlize-output-type` to `'css` in the publish backend, and keep the outer wrapper markup that sp.el already emits (`div.language-X.highlighter-rouge > div.highlight > pre.highlight > code`).
- Make sure the languages used in `org/` fontify in `emacs -Q` batch: java, javascript/js, python, sh/bash, emacs-lisp, c, go, rust, sql, yaml, json, html, css, and so on. If a language has no built-in major mode (or only a tree-sitter mode with no grammar available in CI), it falls back to plain text. List those languages in the report.
- Keep the `language-bash` class name where the source says bash; don't normalise it to `sh`.
- Add CSS to `assets/css/nord.css` that colours the htmlize face classes (`org-keyword`, `org-string`, `org-comment`, `org-function-name`, `org-type`, `org-constant`, `org-variable-name`, `org-builtin`, `org-doc`, and so on) with the colours the Rouge token classes use now, in both `.theme-nord-light` and `.theme-nord-dark`.
- Builds must stay deterministic. Check that fontification doesn't depend on user config (`emacs -Q`).
- Add tests: a java block produces keyword and string spans.

## Task 14: Anchors and markup inside posts

- **Heading ids:** generate ids the way kramdown does (`auto_ids`). Lowercase the text, drop characters that aren't letters, digits, spaces or hyphens, turn spaces into `-`, and when the id would start with a non-letter, prefix `-` as live does. For example `#-is-changing-but-equals-still-matters` on the java28 post. Add a test with several live examples.
- **TOC** (`#+TOC` / `toc` pages): `ul#toc.section-nav` with `li.toc-entry.toc-hN` and links to the heading ids. Match the live java28 TOC.
- **Footnotes:** reshape the Org footnotes into kramdown's shape: `div.footnotes[role=doc-endnotes] > ol > li#fn:N`, references `sup#fnref:N > a.footnote[href="#fn:N"]`, and back-links `a.reversefootnote` "↩". Remove Org's `<h2 class="footnotes">Footnotes: </h2>`. Check one live post that has footnotes.
- **Emphasis:** export bold and italic as `<strong>` and `<em>`.
- **Tables:** tables with a header rule export `<thead>`.
- **Stray `</p>`:** find where the stray `</p>` tags come from on legacy posts (for example the 2011 lokpal-bill post) and fix it, in the export or in the org content.
- Add tests.

## Task 15: CI, cleanup and docs

- `.github/workflows/pages.yml`: before deploy, also run `test/ci-contract.sh` (install ripgrep first) and `scripts/test-eww-rendering.el`.
- In interactive Emacs, `(require 'site-config …)` doesn't reload a changed `publish/site-config.el`. The user hit `Symbol's value as variable is void: systemhalted-google-analytics-id` after Task 6. Make `systemhalted-build` / preview / publish `load` site-config.el on every run (and `defvar` instead of `defconst` so reloads rebind), and add a test that a reload picks up a changed value.
- Clean up `.systemhalted-stage-*` directories when a build fails, and delete any that are left over locally (they are gitignored).
- Update `README.md` / `docs/` for the new keywords (`HIDE_TITLE`, `QUIET_TITLE`, `MERMAID`, `KARTAVYA_PATH`, quoted categories).
- Run `scripts/parity-check.sh`. It must exit 0. Put any remaining page-level differences in the report, and explain each one as an Org-markup difference that renders the same.
