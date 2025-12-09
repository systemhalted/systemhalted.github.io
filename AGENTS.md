# Repository Guidelines

## Project Structure & Module Organization
- Jekyll site configuration lives in `_config.yml`; avoid manual edits to `_site/` because it is generated output.
- Content is authored in `collections/_posts/` (published), `collections/_drafts/` (unpublished), and `collections/_newsletter/`; use `YYYY-MM-DD-title.md` for post filenames.
- Layouts sit in `_layouts/`, shared snippets in `_includes/`, and data files in `_data/` for repeatable metadata.
- Static assets belong in `assets/` (images, JS, CSS). Experimental games are in `jsgames/` and should keep their own assets nearby.

## Build, Test, and Development Commands
- `bundle install` — install Ruby gems from the `Gemfile` (run on first setup or when dependencies change).
- `bundle exec jekyll serve --livereload` — run the site locally at `http://localhost:4000` with live reload for drafts and posts.
- `bundle exec jekyll build` — produce the production site into `_site/`; CI/CD and GitHub Pages expect this to succeed without warnings.
- `bundle exec jekyll doctor` — sanity-check configuration for common issues before opening a PR.

## Coding Style & Naming Conventions
- Prefer 2-space indentation for YAML, HTML/Liquid, and Markdown code blocks to match existing files.
- Front matter should include `layout`, `title`, `date`, `categories` or `tags`, and any page-specific flags; keep keys lower-case and kebab-cased.
- Use kebab-case for filenames and URL slugs; keep asset names short and descriptive (e.g., `assets/images/2025-05-hero.jpg`).
- Keep Markdown concise; use Liquid includes for repeated UI fragments instead of duplicating HTML.

## Testing Guidelines
- There is no automated test suite; treat `bundle exec jekyll build` as the gate to catch Liquid or front matter errors.
- When adding scripts or interactive pages (e.g., under `jsgames/`), test locally in modern browsers and avoid breaking the main layout.
- Consider running `bundle exec jekyll serve` with `JEKYLL_ENV=production` to mirror production behavior before merging.

## Commit & Pull Request Guidelines
- Recent history favors short, imperative messages (e.g., “Fix layout”); follow that style and group related edits per commit.
- PRs should state intent, list notable pages touched (paths), and include screenshots for visual changes when feasible.
- Link relevant issues or TODOs in the description; call out any build or doctor warnings that remain.
- Avoid committing generated `_site/` contents; rely on the build to regenerate them.
