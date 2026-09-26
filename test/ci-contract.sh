#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

pages_workflow=.github/workflows/pages.yml
a11y_workflow=.github/workflows/a11y.yml

rg -q 'purcell/setup-emacs@34c6ded44899fd1bf74d2889558befd1750e61a7' "$pages_workflow" "$a11y_workflow"
rg -q 'version: .31\.1.' "$pages_workflow" "$a11y_workflow"
rg -q 'systemhalted-batch-build' "$pages_workflow" "$a11y_workflow"
if rg -q 'jekyll|bundle exec|setup-ruby' "$pages_workflow" "$a11y_workflow"; then
  echo "CI still invokes the retired Jekyll/Ruby pipeline" >&2
  exit 1
fi

rg -q 'publisher-tests == .true.' "$pages_workflow"
needs_tests() { printf '%s\n' "$@" | scripts/ci-needs-publisher-tests.sh; }
[[ $(needs_tests org/posts/a.org org/pages/b.org) == publisher-tests=false ]]
[[ $(needs_tests org/posts/a.org publish/systemhalted-publish.el) == publisher-tests=true ]]
[[ $(needs_tests .github/workflows/pages.yml) == publisher-tests=true ]]
[[ $(needs_tests org/data/taxonomy.yml) == publisher-tests=true ]]
[[ $(needs_tests) == publisher-tests=true ]]

for retired in _config.yml Gemfile Gemfile.lock _layouts _includes collections; do
  if [[ -e "$retired" ]]; then
    echo "Retired publishing input remains: $retired" >&2
    exit 1
  fi
done

output=$(mktemp -d)
actual=$(mktemp)
expected=$(mktemp)
trap 'rm -rf "$output"; rm -f "$actual" "$expected"' EXIT

SYSTEMHALTED_CI_ROOT="$repo_root" SYSTEMHALTED_CI_OUTPUT="$output" \
  emacs -Q --batch -L publish \
    -l publish/systemhalted-workflow.el \
    --eval '(setq systemhalted-root-directory (getenv "SYSTEMHALTED_CI_ROOT") systemhalted-output-directory (getenv "SYSTEMHALTED_CI_OUTPUT"))' \
    -f systemhalted-batch-build

while IFS= read -r file; do
  relative=${file#"$output"/}
  case "$relative" in
    index.html) printf '/\n' ;;
    */index.html) printf '/%s\n' "${relative%index.html}" ;;
    *) printf '/%s\n' "$relative" ;;
  esac
done < <(find "$output" -type f -name '*.html' | sort) | LC_ALL=C sort > "$actual"

tail -n +2 test/baseline/routes.tsv | LC_ALL=C sort > "$expected"
# New posts add routes; only a baseline route missing from the build fails.
missing=$(LC_ALL=C comm -23 "$expected" "$actual")
if [[ -n "$missing" ]]; then
  echo "Baseline routes missing from the build:" >&2
  printf '%s\n' "$missing" >&2
  exit 1
fi

echo "CI contract passed"
