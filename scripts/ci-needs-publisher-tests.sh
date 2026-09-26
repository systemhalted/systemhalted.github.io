#!/usr/bin/env bash
# Read changed paths on stdin, one per line. Print publisher-tests=false when
# every path is an Org source under org/, and publisher-tests=true otherwise.
# An empty list prints true, so an unknown change set always runs the tests.
set -euo pipefail

needs=true
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ "$path" == org/*.org ]]; then
    needs=false
  else
    needs=true
    break
  fi
done

echo "publisher-tests=$needs"
