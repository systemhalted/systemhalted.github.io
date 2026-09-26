# Repository Guidelines

## Project structure

- Authored content lives in `org/posts/`, `org/drafts/`, `org/emacs/`, and
  `org/pages/`. Use `YYYY-MM-DD-title.org` for posts and drafts.
- Editable site data lives in `org/data/`.
- The built-in-Emacs publisher, templates, settings, and interactive workflow
  live in `publish/`.
- Static files live in `assets/`; standalone games remain in `jsgames/`.
- `_site/` is generated output and must not be edited or committed.

## Build and test commands

- `emacs -Q --batch -L publish -l publish/systemhalted-workflow.el -f systemhalted-batch-build`
  builds and validates the production site.
- `emacs -Q --batch -L publish -l test/systemhalted-publish-test.el -l test/systemhalted-workflow-test.el -f ert-run-tests-batch-and-exit`
  runs the publisher and workflow suites.
- `test/ci-contract.sh` checks the clean batch entry point, CI configuration,
  retired inputs, and public route manifest.
- Run `M-x systemhalted-preview` in Emacs for a draft-inclusive local preview.
- With the preview running on port 4002, `npm run smoke` and `npm run a11y`
  exercise browser behavior and accessibility.

## Style and content conventions

- Use 2-space indentation for YAML, HTML, CSS, and JavaScript.
- New posts need `#+TITLE`, `#+DESCRIPTION`, `#+DATE`, `#+CATEGORIES`, and
  `#+TAGS` keywords.
- Use kebab-case for filenames and URL slugs. Preserve established routes with
  `#+PERMALINK`.
- Reuse publisher templates for shared markup. Do not introduce Liquid or
  Markdown publishing inputs.
- Keep asset names short and descriptive. Featured images need alt text unless
  they are decorative.

## Verification and reviews

- Treat the batch build and ERT suites as the primary gate.
- Test scripts and browser games in a modern browser when changing their code.
- Include screenshots in pull requests for visible layout changes when useful.
- Keep commit messages short and imperative, and group related edits.
- Do not add generated `_site/` files or attribution trailers to commits.
