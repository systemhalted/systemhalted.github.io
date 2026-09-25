#!/usr/bin/env bash
# Parity check: compare the local Org/Emacs build in _site/ against the
# live Jekyll site at https://systemhalted.in.
#
# Usage: scripts/parity-check.sh [--report DIR] [--refresh]
#
#   --report DIR   Write cached live fetches and full per-page diffs here.
#                   Default: tmp/parity/
#   --refresh      Re-fetch the live sitemap and sample pages instead of
#                   using whatever is already cached under --report DIR.
#
# Exit status: 0 when there are no route differences between the live and
# local sitemaps and no `file:` URLs anywhere in _site/**/*.html; 1
# otherwise. Broken root-relative links and per-page metadata mismatches
# are reported but do not by themselves change the exit status.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="$ROOT/_site"
LIVE_BASE="https://systemhalted.in"

REPORT_DIR="$ROOT/tmp/parity"
REFRESH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --report)
      REPORT_DIR="$2"
      shift 2
      ;;
    --report=*)
      REPORT_DIR="${1#*=}"
      shift
      ;;
    --refresh)
      REFRESH=1
      shift
      ;;
    -h|--help)
      sed -n '2,15s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$REPORT_DIR" in
  /*) : ;;
  *) REPORT_DIR="$ROOT/$REPORT_DIR" ;;
esac

CACHE_DIR="$REPORT_DIR/cache"
mkdir -p "$CACHE_DIR"

if [ ! -f "$SITE_DIR/sitemap.xml" ]; then
  echo "error: $SITE_DIR/sitemap.xml not found; build the site first with" >&2
  echo "  emacs -Q --batch -L publish -l publish/systemhalted-workflow.el -f systemhalted-batch-build" >&2
  exit 2
fi

PYTHON="$(command -v python3 || true)"
if [ -z "$PYTHON" ]; then
  echo "error: python3 is required by this QA script" >&2
  exit 2
fi

# --- fetch (with caching) ---------------------------------------------

fetch_cached() {
  # fetch_cached <url> <cache_file>
  local url="$1" cache_file="$2"
  if [ "$REFRESH" -eq 1 ] || [ ! -s "$cache_file" ]; then
    curl -fsSL "$url" -o "$cache_file"
  fi
}

local_file_for_route() {
  # local_file_for_route <path> -> echoes the local file path (may not exist)
  local path="$1"
  if [ "$path" = "/" ]; then
    echo "$SITE_DIR/index.html"
  elif [[ "$path" == *.html ]]; then
    echo "$SITE_DIR${path}"
  elif [[ "$path" == */ ]]; then
    echo "$SITE_DIR${path}index.html"
  else
    echo "$SITE_DIR${path}/index.html"
  fi
}

# --- python helper (embedded) ------------------------------------------
# All HTML/XML parsing lives here rather than in fragile shell regexes.
# This is a QA script, not the build, so python3 is fine.

HELPER="$REPORT_DIR/.parity_helpers.py"
cat > "$HELPER" <<'PYEOF'
import difflib
import json
import os
import re
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urlparse


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


# --- sitemap-diff --------------------------------------------------------

def sitemap_paths(text):
    paths = set()
    for loc in re.findall(r"<loc>\s*(.*?)\s*</loc>", text, re.S):
        paths.add(unquote(urlparse(loc.strip()).path))
    return paths


def cmd_sitemap_diff(argv):
    live_path, local_path = argv
    live = sitemap_paths(read(live_path))
    local = sitemap_paths(read(local_path))
    only_live = sorted(live - local)
    only_local = sorted(local - live)
    print(f"live routes: {len(live)}  local routes: {len(local)}")
    print(f"only on live ({len(only_live)}):")
    for p in only_live:
        print(f"  + {p}")
    print(f"only on local ({len(only_local)}):")
    for p in only_local:
        print(f"  - {p}")
    print(f"SITEMAP_DIFF_COUNT={len(only_live) + len(only_local)}")


# --- broken-links ---------------------------------------------------------

HREF_SRC_RE = re.compile(r'\b(?:href|src)\s*=\s*"([^"]*)"')


def cmd_broken_links(argv):
    (site_dir,) = argv
    file_url_count = 0
    missing = []
    checked = 0
    html_files = []
    for root, _dirs, files in os.walk(site_dir):
        for fn in files:
            if fn.endswith(".html"):
                html_files.append(os.path.join(root, fn))
    html_files.sort()

    for hf in html_files:
        text = read(hf)
        for m in HREF_SRC_RE.finditer(text):
            val = m.group(1)
            if not val:
                continue
            if val.startswith("file:"):
                file_url_count += 1
                continue
            if not val.startswith("/") or val.startswith("//"):
                continue  # relative, external, or protocol-relative
            path = val.split("#", 1)[0].split("?", 1)[0]
            if path == "":
                continue  # was a pure #anchor
            if path == "/":
                candidates = [os.path.join(site_dir, "index.html")]
            elif path.endswith("/"):
                candidates = [os.path.join(site_dir, path.lstrip("/"), "index.html")]
            else:
                rel = path.lstrip("/")
                base = os.path.join(site_dir, rel)
                if os.path.splitext(rel)[1]:
                    candidates = [base]
                else:
                    candidates = [base, base + "/index.html", base + ".html"]
            checked += 1
            if not any(os.path.exists(c) for c in candidates):
                missing.append((os.path.relpath(hf, site_dir), val))

    print(f"file: URL count: {file_url_count}")
    print(f"root-relative links checked: {checked}")
    print(f"missing root-relative targets: {len(missing)}")
    for hf, val in missing:
        print(f"  {hf} -> {val}")
    print(f"FILE_URL_COUNT={file_url_count}")
    print(f"MISSING_COUNT={len(missing)}")


# --- page-diff --------------------------------------------------------

class PageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = None
        self._in_title = False
        self.canonical = None
        self.robots = None
        self.og_twitter = []
        self.jsonld_texts = []
        self._in_jsonld = False
        self._jsonld_buf = []
        self.main_depth = 0
        self.classes = set()

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == "title":
            self._in_title = True
            self.title = self.title or ""
        elif tag == "link" and (d.get("rel") or "").lower() == "canonical":
            self.canonical = d.get("href")
        elif tag == "meta":
            name = d.get("name") or d.get("property")
            content = d.get("content")
            if name == "robots":
                self.robots = content
            elif name and (name.startswith("og:") or name.startswith("twitter:")):
                self.og_twitter.append((name, content))
        elif tag == "script" and d.get("type") == "application/ld+json":
            self._in_jsonld = True
            self._jsonld_buf = []

        if tag == "main":
            self.main_depth += 1
        if self.main_depth > 0:
            cls = d.get("class")
            if cls:
                self.classes.update(cls.split())

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if tag == "script" and self._in_jsonld:
            self._in_jsonld = False
            self.jsonld_texts.append("".join(self._jsonld_buf))
        if tag == "main" and self.main_depth > 0:
            self.main_depth -= 1

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_jsonld:
            self._jsonld_buf.append(data)


def extract_types(obj, out):
    if isinstance(obj, dict):
        t = obj.get("@type")
        if isinstance(t, list):
            out.extend(t)
        elif t:
            out.append(t)
        for v in obj.values():
            extract_types(v, out)
    elif isinstance(obj, list):
        for item in obj:
            extract_types(item, out)


def load_page(path):
    parser = PageParser()
    parser.feed(read(path))
    types = []
    for txt in parser.jsonld_texts:
        try:
            data = json.loads(txt)
        except ValueError:
            continue
        extract_types(data, types)
    return {
        "title": (parser.title or "").strip(),
        "canonical": parser.canonical,
        "robots": parser.robots,
        "og_twitter": parser.og_twitter,
        "jsonld_types": types,
        "classes": sorted(parser.classes),
    }


def fmt_page(d):
    lines = [
        f"title: {d['title']}",
        f"canonical: {d['canonical']}",
        f"robots: {d['robots']}",
        "og/twitter meta:",
    ]
    for k, v in d["og_twitter"]:
        lines.append(f"  {k} = {v}")
    lines.append(f"jsonld @type: {', '.join(d['jsonld_types'])}")
    lines.append("main classes:")
    for c in d["classes"]:
        lines.append(f"  .{c}")
    return "\n".join(lines) + "\n"


def cmd_page_diff(argv):
    label, live_path, local_path, out_dir = argv
    missing_side = None
    if not os.path.exists(live_path):
        missing_side = "live"
    elif not os.path.exists(local_path):
        missing_side = "local"
    if missing_side:
        print(f"--- {label}: MISSING ({missing_side} page not found) ---")
        return

    live = fmt_page(load_page(live_path))
    local = fmt_page(load_page(local_path))
    diff = list(
        difflib.unified_diff(
            live.splitlines(keepends=True),
            local.splitlines(keepends=True),
            fromfile=f"{label} (live)",
            tofile=f"{label} (local)",
        )
    )

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, f"{label}.live.txt"), "w", encoding="utf-8") as f:
        f.write(live)
    with open(os.path.join(out_dir, f"{label}.local.txt"), "w", encoding="utf-8") as f:
        f.write(local)
    diff_file = os.path.join(out_dir, f"{label}.diff")
    with open(diff_file, "w", encoding="utf-8") as f:
        f.writelines(diff)

    if diff:
        print(f"--- {label}: DIFFERS (full diff: {diff_file}) ---")
        sys.stdout.writelines(diff)
    else:
        print(f"--- {label}: match ---")


def main():
    cmd, argv = sys.argv[1], sys.argv[2:]
    {
        "sitemap-diff": cmd_sitemap_diff,
        "broken-links": cmd_broken_links,
        "page-diff": cmd_page_diff,
    }[cmd](argv)


if __name__ == "__main__":
    main()
PYEOF

STATUS=0

echo "== 1. Routes (sitemap.xml) =========================================="
LIVE_SITEMAP="$CACHE_DIR/sitemap.xml"
fetch_cached "$LIVE_BASE/sitemap.xml" "$LIVE_SITEMAP"
SITEMAP_OUT="$("$PYTHON" "$HELPER" sitemap-diff "$LIVE_SITEMAP" "$SITE_DIR/sitemap.xml")"
echo "$SITEMAP_OUT" | tee "$REPORT_DIR/routes-diff.txt" | grep -v '^SITEMAP_DIFF_COUNT='
SITEMAP_DIFF_COUNT="$(echo "$SITEMAP_OUT" | sed -n 's/^SITEMAP_DIFF_COUNT=//p')"
if [ "$SITEMAP_DIFF_COUNT" -ne 0 ]; then
  STATUS=1
fi
echo

echo "== 2. Broken URLs in _site ==========================================="
BROKEN_OUT="$("$PYTHON" "$HELPER" broken-links "$SITE_DIR")"
echo "$BROKEN_OUT" | tee "$REPORT_DIR/broken-links.txt" | grep -vE '^(FILE_URL_COUNT|MISSING_COUNT)='
FILE_URL_COUNT="$(echo "$BROKEN_OUT" | sed -n 's/^FILE_URL_COUNT=//p')"
if [ "$FILE_URL_COUNT" -ne 0 ]; then
  STATUS=1
fi
echo

echo "== 3. Sample page comparison =========================================="
mkdir -p "$REPORT_DIR/pages"

# label:route pairs. Labels double as cache/report file stems.
SAMPLE_PAGES=(
  "home:/"
  "java28-value-objects:/2026/09/23/java28-value-objects/"
  "kahan-summation:/2026/01/11/kahan-summation-java-streams/"
  "2d-1d-problem:/2026/07/17/the-2d-1d-problem-in-text-editors/"
  "lokpal-bill:/2011/01/28/lokpal-bill/"
  "archives:/archives/"
  "categories:/categories/"
  "tags:/tags/"
  "about:/about/"
  "emacs-index:/emacs/"
  "emacs-config:/emacs/emacs-config/"
  "kartavya-path:/kartavya-path/"
  "jsgames:/jsgames/"
  "themes:/themes/"
  "webcmd:/webcmd/"
  "404:/404.html"
)

for entry in "${SAMPLE_PAGES[@]}"; do
  label="${entry%%:*}"
  route="${entry#*:}"
  live_cache="$CACHE_DIR/${label}.html"
  fetch_cached "$LIVE_BASE$route" "$live_cache" || {
    echo "--- $label ($route): could not fetch live page ---"
    STATUS=1
    continue
  }
  local_file="$(local_file_for_route "$route")"
  "$PYTHON" "$HELPER" page-diff "$label" "$live_cache" "$local_file" "$REPORT_DIR/pages"
done
echo

echo "== Summary ============================================================"
echo "route differences: $SITEMAP_DIFF_COUNT"
echo "file: URLs: $FILE_URL_COUNT"
echo "full report written to: $REPORT_DIR"
if [ "$STATUS" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL"
fi

exit "$STATUS"
