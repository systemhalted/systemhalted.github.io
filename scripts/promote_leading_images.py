#!/usr/bin/env python3
"""Promote a post's leading inline image to featured_image front-matter.

Match criteria (conservative):
- Post .md file under collections/_posts/
- Front-matter does NOT already have featured_image
- First non-blank line of body is a plain `![alt](url)` (no surrounding link)
- The next line(s) are blank or normal prose (not another image)

Action:
- Add `featured_image: <url>` (stripping `{{ site.baseurl }}/` prefix; the layout
  re-adds baseurl via `relative_url`)
- Add `featured_image_alt: <alt>` (blanked out if alt looks like WP junk)
- Delete the original image line from the body
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

POSTS_DIR = Path("collections/_posts")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)$", re.DOTALL)
LEADING_IMG_RE = re.compile(r"^!\[([^\]]*)\]\(([^)]+)\)\s*$")

# Alt is "junk" if any of these match
JUNK_PATTERNS = [
    re.compile(r"\.(jpg|jpeg|png|gif|svg|indd|psd|webp)$", re.IGNORECASE),
    re.compile(r"_FINAL\b|_SX\d|_SY\d|SCLZZZ|_AC_|Template|noborder", re.IGNORECASE),
    re.compile(r"\.\.\.$"),                # truncated
    re.compile(r"^Buy\s", re.IGNORECASE),  # Flipkart affiliate text
    re.compile(r"^To Buy\s", re.IGNORECASE),
    re.compile(r"Click on the Image", re.IGNORECASE),
]


KEY_ORDER = [
    "layout", "title", "date", "last_modified_at",
    "category", "categories",
    "tags", "comments",
    "featured", "featured_image", "featured_image_alt", "featured_image_caption",
    "description", "toc", "annotations",
    "slug", "permalink",
]


def is_junk_alt(alt: str) -> bool:
    s = alt.strip()
    if not s:
        return True
    return any(p.search(s) for p in JUNK_PATTERNS)


def strip_baseurl(src: str) -> str:
    """`{{ site.baseurl }}/assets/foo.jpg` -> `/assets/foo.jpg`."""
    s = src.strip()
    s = re.sub(r"^\{\{\s*site\.baseurl\s*\}\}/?", "/", s)
    # Collapse accidental double slash
    s = re.sub(r"^//", "/", s)
    return s


def reorder(fm: dict) -> dict:
    out = {}
    for k in KEY_ORDER:
        if k in fm:
            out[k] = fm[k]
    for k in fm:
        if k not in out:
            out[k] = fm[k]
    return out


def dump_frontmatter(fm: dict) -> str:
    return yaml.dump(
        fm,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=1000,
    )


def process_file(path: Path, dry_run: bool):
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None

    fm = yaml.safe_load(m.group(1)) or {}
    if "featured_image" in fm:
        return None

    body = m.group(2).lstrip("\n")
    lines = body.split("\n")
    if not lines:
        return None
    first = lines[0].strip()
    img = LEADING_IMG_RE.match(first)
    if not img:
        return None

    alt = img.group(1).strip()
    src = strip_baseurl(img.group(2))

    fm["featured_image"] = src
    fm["featured_image_alt"] = "" if is_junk_alt(alt) else alt

    # Remove the image line and any immediately-following blank lines
    new_body_lines = lines[1:]
    while new_body_lines and new_body_lines[0].strip() == "":
        new_body_lines.pop(0)
    new_body = "\n".join(new_body_lines).strip() + "\n"

    fm = reorder(fm)
    new_text = f"---\n{dump_frontmatter(fm)}---\n\n{new_body}"

    if not dry_run:
        path.write_text(new_text, encoding="utf-8")

    return {
        "alt_original": alt,
        "alt_kept": fm["featured_image_alt"],
        "src": src,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--files", nargs="*")
    args = ap.parse_args()

    if args.files:
        targets = [POSTS_DIR / f for f in args.files]
    else:
        targets = sorted(POSTS_DIR.glob("*.md"))

    promoted = 0
    for path in targets:
        if not path.exists():
            continue
        result = process_file(path, dry_run=args.dry_run)
        if result is None:
            continue
        promoted += 1
        alt_status = "(scrubbed -> blank)" if not result["alt_kept"] else f"-> kept: {result['alt_kept'][:60]!r}"
        print(f"{'WOULD PROMOTE' if args.dry_run else 'PROMOTED'}: {path.name}")
        print(f"  src: {result['src']}")
        print(f"  alt: {result['alt_original'][:80]!r}  {alt_status}")

    print(f"\nTotal {'would-promote' if args.dry_run else 'promoted'}: {promoted}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
