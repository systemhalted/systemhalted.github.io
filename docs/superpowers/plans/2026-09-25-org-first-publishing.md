# Org-First Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Jekyll with a built-in-Emacs Org publisher while preserving SystemHalted's content, URLs, design, and deployment behavior.

**Architecture:** Parse Org metadata into validated records, export bodies through a derived `ox-html` backend, and render all routes from repository Elisp and HTML templates. Local and CI builds call the same batch API and publish only the ignored `_site` artifact.

**Tech Stack:** Emacs 31.1, Org/ox-html, ERT, HTML/CSS/JavaScript, GitHub Actions, Playwright/Axe for existing QA, Pandoc for one-time migration only.

**Spec:** `docs/superpowers/specs/2026-09-25-org-first-publishing-design.md`

## Global Constraints

- Publishing runtime uses only libraries bundled with Emacs 31.1.
- Org is the sole maintained format for posts, drafts, Emacs notes, and authored pages.
- Existing public article URLs remain stable.
- Existing CSS, JavaScript behavior, static games, comments, search, SEO metadata, RSS, and sitemap remain functional.
- Newsletter behavior is removed; former newsletter essays remain ordinary posts at their existing permalinks.
- Generated HTML is never committed.

## Review Focus

- Percent-encoded and non-ASCII legacy slugs resolve to the same route and filesystem target.
- Liquid constructs are either translated deliberately or block migration.
- XML and JSON escaping handles titles and descriptions containing markup, quotes, and non-ASCII text.
- Draft and future-post inclusion differs correctly between preview and production.
- Failed builds cannot replace the last successful `_site` tree.

---

### Task 1: Baseline Contract and Content Records

**Files:**
- Create: `publish/systemhalted-publish.el`
- Create: `test/systemhalted-publish-test.el`
- Create: `test/fixtures/org/`
- Create: `test/baseline/routes.tsv`

**Interfaces:**
- Produces: `systemhalted-record` accessors, `systemhalted-read-record`, `systemhalted-load-records`, `systemhalted-record-route`, `systemhalted-validate-records`.
- Consumes: Org sources and the current Jekyll `_site` build.

- [ ] Write ERT tests for required metadata, filename-derived dates/routes, explicit permalinks, list/boolean fields, Unicode slugs, drafts, future posts, duplicate routes, and unsafe routes.
- [ ] Run the focused ERT suite and confirm failures are caused by the absent parser.
- [ ] Implement the minimal record parser, normalization, route derivation, and validation.
- [ ] Re-run ERT and the entire ERT suite.
- [ ] Generate the checked baseline route manifest from the successful Jekyll build.
- [ ] Commit with message `Add Org publishing content model`.

### Task 2: Org HTML Export and Page Rendering

**Files:**
- Modify: `publish/systemhalted-publish.el`
- Create: `publish/templates/base.html`
- Create: `publish/templates/post.html`
- Create: `publish/templates/page.html`
- Modify: `test/systemhalted-publish-test.el`

**Interfaces:**
- Consumes: normalized records from Task 1.
- Produces: `systemhalted-export-body`, `systemhalted-render-page`, `systemhalted-write-record`, and HTML files at each record route.

- [ ] Write failing fixture tests for headings, source/example blocks, footnotes, tables, raw HTML, Org file links, metadata, TOC, featured images, comments, and escaping.
- [ ] Implement the derived `ox-html` backend and template rendering needed to pass them.
- [ ] Add failing tests for newer/older and related-post rendering, then implement the existing ranking behavior.
- [ ] Run all ERT tests and export every fixture without warnings.
- [ ] Commit with message `Render Org content as site pages`.

### Task 3: Complete Static Site Generation

**Files:**
- Modify: `publish/systemhalted-publish.el`
- Create: `publish/site-config.el`
- Modify: `test/systemhalted-publish-test.el`

**Interfaces:**
- Consumes: records and page renderer from Tasks 1-2.
- Produces: `systemhalted-build-site`, derived collection pages, feed, sitemap, search data, redirects, and copied assets.

- [ ] Write failing integration tests for home pagination, archives, categories, tags, themes, projects, Emacs notes, RSS, sitemap, search data, static assets, and the `/kartavya-path/` redirect.
- [ ] Implement deterministic generated pages and asset copying in a staging directory.
- [ ] Add failing validation tests for broken internal links/assets, malformed XML, output collisions, and failed-build preservation; implement the validators and atomic install.
- [ ] Build fixtures twice and assert identical file hashes.
- [ ] Commit with message `Generate complete site from Org records`.

### Task 4: Migrate All Authored Content to Org

**Files:**
- Create: `org/posts/*.org`, `org/drafts/*.org`, `org/emacs/*.org`, `org/pages/*.org`, `org/data/*.org`
- Modify: `test/baseline/routes.tsv`
- Modify: `test/systemhalted-publish-test.el`

**Interfaces:**
- Consumes: the metadata/export contract from Tasks 1-3 and one-time Pandoc output.
- Produces: the complete maintained Org corpus with no Markdown publishing inputs.

- [ ] Add a migration audit test that rejects Markdown content inputs, remaining Liquid, duplicate routes, and missing source-to-route mappings.
- [ ] Run it and confirm it fails against the legacy corpus.
- [ ] Convert every maintained post, draft, Emacs note, standalone page, and editable data source; preserve the four existing Org sources.
- [ ] Translate supported Liquid constructs and resolve every audit failure explicitly.
- [ ] Build the full Org site and compare route, metadata, visible text, internal link, image, feed, sitemap, pagination, taxonomy, and search contracts with the baseline.
- [ ] Commit with message `Migrate site content to Org`.

### Task 5: Interactive Emacs Authoring Workflow

**Files:**
- Create: `publish/systemhalted-workflow.el`
- Create: `test/systemhalted-workflow-test.el`
- Modify: `README.md`

**Interfaces:**
- Consumes: `systemhalted-build-site` and record routing.
- Produces: `systemhalted-new-post`, `systemhalted-preview`, `systemhalted-build`, `systemhalted-publish`, and the preview-server lifecycle.

- [ ] Write failing ERT tests for draft creation, preview URLs, production options, failed-build preservation, server reuse, and Magit/VC handoff without Git mutation.
- [ ] Implement the interactive and batch commands plus the built-in-Elisp static server.
- [ ] Run workflow and publisher ERT suites, then preview representative fixtures through HTTP.
- [ ] Update authoring documentation and commit with message `Add Emacs publishing workflow`.

### Task 6: CI Cutover and Jekyll Removal

**Files:**
- Modify: `.github/workflows/pages.yml`
- Modify: `.github/workflows/a11y.yml`
- Modify: `.github/workflows/codeql-analysis.yml`
- Modify: `scripts/test-eww-rendering.el`, `scripts/browser-smoke.js`, `scripts/a11y.js`
- Remove: Jekyll/Ruby configuration, layouts, includes, and legacy publishing sources.

**Interfaces:**
- Consumes: batch build/validation commands from Tasks 3 and 5.
- Produces: an Emacs 31.1 GitHub Pages build and deploy workflow.

- [ ] Add a failing CI contract test that invokes the batch entry point from a clean output directory and audits the generated route set.
- [ ] Replace Jekyll setup/build steps with pinned Emacs 31.1 setup and batch publication.
- [ ] Remove newsletter-specific UI/config/tests and update the Axe route list for the redirect policy.
- [ ] Remove Jekyll, Bundler, Liquid, and legacy Markdown content inputs.
- [ ] Run ERT, the clean production build, deterministic hash comparison, EWW, browser smoke, Axe, and `git diff --check`.
- [ ] Commit with message `Publish Org site with Emacs`.

