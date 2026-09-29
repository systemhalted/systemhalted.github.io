#!/usr/bin/env bash
# Turn a failed CI log into GitHub annotations and a run-summary section.
#
#   scripts/ci-report-failures.sh ert LOG    failed ERT tests, by test file and line
#   scripts/ci-report-failures.sh build LOG  site build errors, by source file
#
# Annotations go to stdout. The summary section is appended to
# $GITHUB_STEP_SUMMARY when it is set, and printed to stdout otherwise.
set -euo pipefail

kind=$1
log=$2
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}

case "$kind" in
  ert)
    # ERT prints: "   FAILED  59/135  test-name (1.2 sec) at test/file.el:1419"
    failures=$(sed -nE 's/^ *FAILED +[0-9]+\/[0-9]+ +([^ ]+) .* at ([^:]+):([0-9]+).*/\1 \2 \3/p' "$log")
    {
      echo "## Failed publisher tests"
      echo
      if [[ -z "$failures" ]]; then
        echo "The test step failed without a FAILED line. See the step log."
      else
        while read -r name file line; do
          echo "- \`$name\` ($file:$line)"
        done <<< "$failures"
      fi
    } >> "$summary"
    if [[ -n "$failures" ]]; then
      while read -r name file line; do
        echo "::error file=$file,line=$line,title=Test failed::$name"
      done <<< "$failures"
    fi
    ;;
  build)
    # systemhalted-batch-build already printed its annotations to the log.
    errors=$(grep '^::error' "$log" || true)
    {
      echo "## Site build failed"
      echo
      if [[ -z "$errors" ]]; then
        echo "The build failed without a publishing error. See the step log."
      else
        while IFS= read -r error; do
          text=${error#*::*::}
          text=${text//%0A/ }
          text=${text//%25/%}
          if [[ $error =~ file=([^,]+), ]]; then
            echo "- \`${BASH_REMATCH[1]}\`: $text"
          else
            echo "- $text"
          fi
        done <<< "$errors"
      fi
    } >> "$summary"
    ;;
  *)
    echo "usage: $0 ert|build LOG" >&2
    exit 2
    ;;
esac
