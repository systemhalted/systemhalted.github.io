#!/usr/bin/env python3
"""Migrate WordPress-imported posts in collections/_posts/ to clean Markdown.

What it does:
- Renames *.html -> *.md
- Converts <p>/<strong>/<em>/<a>/<img>/lists/blockquotes/headings to Markdown via markdownify
- Preprocesses [caption ...]<img/>Text[/caption] WP shortcodes to image + italic caption
- Decodes lingering HTML entities (&nbsp;, &#8217;, etc.)
- Preserves Liquid templating ({{ site.baseurl }}) and Jekyll's <!--more--> tag
- Trims front-matter to a documented whitelist
- Normalizes date to YYYY-MM-DD
- Drops `permalink:` when it equals the URL Jekyll would auto-generate from filename
- Idempotent: re-running on already-clean .md is a no-op (or minor whitespace touch)
"""

from __future__ import annotations

import argparse
import datetime as _dt
import re
import sys
from pathlib import Path

import yaml
from markdownify import markdownify

POSTS_DIR = Path("collections/_posts")

KEEP_KEYS = {
    "layout", "title", "date", "category", "categories", "tags",
    "description", "comments", "featured",
    "featured_image", "featured_image_alt", "featured_image_caption",
    "toc", "last_modified_at", "annotations",
    "permalink", "slug",
}

DROP_KEYS = {
    "type", "parent_id", "published", "password", "status",
    "author", "meta",
}

FILENAME_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})-(.+)\.(html|md|markdown)$")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)$", re.DOTALL)

MORE_PLACEHOLDER = "XJEKYLLMORETAGZ"

ENTITY_MAP = {
    "&nbsp;": " ",
    "&#160;": " ",
    "&#8217;": "'",
    "&#8216;": "'",
    "&#8220;": "“",
    "&#8221;": "”",
    "&#8211;": "–",
    "&#8212;": "—",
    "&#8230;": "…",
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&quot;": '"',
}

# Yaml dump key order for the trimmed front-matter (matches the user's native posts)
KEY_ORDER = [
    "layout", "title", "date", "last_modified_at",
    "category", "categories",
    "tags", "comments",
    "featured", "featured_image", "featured_image_alt", "featured_image_caption",
    "description", "toc", "annotations",
    "slug", "permalink",
]


def expected_permalink(filename: str) -> str | None:
    """The permalink Jekyll generates from filename, given /:year/:month/:day/:title/.

    Only returns a value if the filename slug is ASCII-safe (letters/digits/-/_).
    Filenames with %XX byte-escapes or non-ASCII characters (e.g. Hindi) are
    NOT comparable as strings to Jekyll's runtime URL generation, so we bail.
    """
    m = FILENAME_RE.match(filename)
    if not m:
        return None
    y, mo, d, slug, _ext = m.groups()
    if not re.match(r"^[A-Za-z0-9_-]+$", slug):
        return None
    return f"/{y}/{mo}/{d}/{slug}/"


def normalize_date(value):
    """Preserve datetime precision when given (timezones affect Jekyll's URL day).
    Strip only the nanosecond noise ('.000000000') from WP's weird format.
    """
    if isinstance(value, (_dt.date, _dt.datetime)):
        return value  # PyYAML dumps these as bare YAML timestamps
    s = str(value).strip()
    # WP style: "2009-03-26 21:13:30.000000000 -05:00"
    m = re.match(
        r"^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?\s*([+-])(\d{2}):?(\d{2})\s*$",
        s,
    )
    if m:
        y, mo, d, h, mi, se, sign, tzh, tzm = m.groups()
        offset = _dt.timedelta(hours=int(tzh), minutes=int(tzm))
        if sign == "-":
            offset = -offset
        return _dt.datetime(
            int(y), int(mo), int(d), int(h), int(mi), int(se),
            tzinfo=_dt.timezone(offset),
        )
    # Plain YYYY-MM-DD
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", s)
    if m:
        return _dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    return s


def preprocess_captions(html: str) -> str:
    """Convert [caption ...]<img .../>Text[/caption] -> markdown image + italic caption."""
    pattern = re.compile(r"\[caption\b[^\]]*\](.*?)\[/caption\]", re.DOTALL)

    def repl(m: re.Match) -> str:
        inner = m.group(1).strip()
        # Find the image tag
        img_match = re.search(r"<img\b([^>]*?)/?>", inner, re.IGNORECASE)
        if not img_match:
            return inner
        attrs = img_match.group(1)
        src_match = re.search(r"src=[\"']([^\"']+)[\"']", attrs)
        alt_match = re.search(r"alt=[\"']([^\"']*)[\"']", attrs)
        src = src_match.group(1) if src_match else ""
        alt = alt_match.group(1) if alt_match else ""
        # Caption = inner minus the img tag, stripped of remaining tags
        caption = re.sub(r"<img\b[^>]*/?>", "", inner)
        caption = re.sub(r"<a\b[^>]*>", "", caption)
        caption = re.sub(r"</a>", "", caption)
        caption = re.sub(r"<[^>]+>", "", caption).strip()
        if not src:
            return caption
        return f"\n\n![{alt or caption}]({src})\n*{caption}*\n\n"

    return pattern.sub(repl, html)


def strip_wp_attributes(html: str) -> str:
    """Drop WP-specific class names and inline width/height from images so markdownify gets clean inputs."""
    # Strip class="wp-* alignleft size-full ..." attributes entirely from img tags
    html = re.sub(
        r'(<img\b[^>]*?)\sclass=[\"\'][^\"\']*[\"\']',
        r"\1",
        html,
        flags=re.IGNORECASE,
    )
    # Drop title="..." on imgs (usually duplicates alt or is junk)
    html = re.sub(
        r'(<img\b[^>]*?)\stitle=[\"\'][^\"\']*[\"\']',
        r"\1",
        html,
        flags=re.IGNORECASE,
    )
    # Drop width/height on imgs (size from WP, irrelevant in MD)
    html = re.sub(
        r'(<img\b[^>]*?)\s(width|height)=[\"\']?\d+[\"\']?',
        r"\1",
        html,
        flags=re.IGNORECASE,
    )
    return html


def decode_entities(text: str) -> str:
    for ent, ch in ENTITY_MAP.items():
        text = text.replace(ent, ch)
    return text


def convert_body(body: str, is_html: bool) -> str:
    # Always normalize <!--more--> to a placeholder so neither markdownify nor entity
    # decoding touches it.
    body = body.replace("<!--more-->", MORE_PLACEHOLDER)

    if is_html:
        body = preprocess_captions(body)
        body = strip_wp_attributes(body)
        body = markdownify(
            body,
            heading_style="ATX",
            bullets="-",
            strip=["span", "div"],
            escape_underscores=False,
            escape_asterisks=False,
            escape_misc=False,
        )

    body = decode_entities(body)
    body = body.replace(MORE_PLACEHOLDER, "<!--more-->")
    # Collapse runs of 3+ blank lines to 2.
    body = re.sub(r"\n{3,}", "\n\n", body)
    return body.strip() + "\n"


def trim_frontmatter(fm: dict, filename: str) -> dict:
    out = {k: v for k, v in fm.items() if k in KEEP_KEYS}

    # Normalize date
    if "date" in out:
        out["date"] = normalize_date(out["date"])

    # Drop redundant permalink
    if "permalink" in out:
        stored = str(out["permalink"]).strip().strip('"').strip("'")
        expected = expected_permalink(filename)
        if expected and stored == expected:
            del out["permalink"]

    # Sort keys per KEY_ORDER (unknown keys preserved at the end in original order)
    ordered = {}
    for k in KEY_ORDER:
        if k in out:
            ordered[k] = out[k]
    for k in out:
        if k not in ordered:
            ordered[k] = out[k]
    return ordered


def dump_frontmatter(fm: dict) -> str:
    # default_flow_style=False keeps lists block-style; allow_unicode preserves Hindi titles
    return yaml.dump(
        fm,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=1000,  # don't auto-wrap titles
    )


def process_file(path: Path, dry_run: bool) -> tuple[Path, bool]:
    """Returns (new_path, changed)."""
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        return path, False

    fm = yaml.safe_load(m.group(1)) or {}
    body = m.group(2)
    is_html = path.suffix == ".html"

    new_fm = trim_frontmatter(fm, path.name)
    new_body = convert_body(body, is_html=is_html)
    new_text = f"---\n{dump_frontmatter(new_fm)}---\n\n{new_body}"

    if is_html:
        new_path = path.with_suffix(".md")
    else:
        new_path = path

    if dry_run:
        return new_path, (new_text != text or new_path != path)

    new_path.write_text(new_text, encoding="utf-8")
    if new_path != path:
        path.unlink()
    return new_path, (new_text != text or new_path != path)


def show_diff(old_path: Path, new_path: Path, new_text: str, label: str) -> None:
    print(f"\n{'='*70}\n{label}: {old_path.name} -> {new_path.name}\n{'='*70}")
    old = old_path.read_text(encoding="utf-8")
    print("--- BEFORE (first 30 lines) ---")
    for ln in old.splitlines()[:30]:
        print(ln)
    print("--- AFTER  (first 30 lines) ---")
    for ln in new_text.splitlines()[:30]:
        print(ln)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Don't write; print sample diffs")
    ap.add_argument("--limit", type=int, default=0, help="Process only N files (for dry-run sampling)")
    ap.add_argument("--files", nargs="*", help="Specific files to process (relative to posts dir)")
    args = ap.parse_args()

    if args.files:
        targets = [POSTS_DIR / f for f in args.files]
    else:
        targets = sorted(POSTS_DIR.glob("*.html")) + sorted(POSTS_DIR.glob("*.md")) + sorted(POSTS_DIR.glob("*.markdown"))
    if args.limit:
        targets = targets[: args.limit]

    changed = 0
    renamed = 0
    for path in targets:
        if not path.exists():
            print(f"SKIP missing: {path}")
            continue
        try:
            if args.dry_run:
                # Recompute new_text for printing
                text = path.read_text(encoding="utf-8")
                m = FRONTMATTER_RE.match(text)
                if not m:
                    continue
                fm = yaml.safe_load(m.group(1)) or {}
                body = m.group(2)
                is_html = path.suffix == ".html"
                new_fm = trim_frontmatter(fm, path.name)
                new_body = convert_body(body, is_html=is_html)
                new_text = f"---\n{dump_frontmatter(new_fm)}---\n\n{new_body}"
                new_path = path.with_suffix(".md") if is_html else path
                if new_text != text or new_path != path:
                    show_diff(path, new_path, new_text, "DRY-RUN")
                    changed += 1
            else:
                new_path, did_change = process_file(path, dry_run=False)
                if did_change:
                    changed += 1
                    if new_path != path:
                        renamed += 1
                    print(f"{'RENAMED' if new_path != path else 'UPDATED'}: {path.name}{' -> ' + new_path.name if new_path != path else ''}")
        except Exception as e:
            print(f"ERROR processing {path}: {e}", file=sys.stderr)
            raise

    print(f"\nTotal changed: {changed}, renamed: {renamed}, processed: {len(targets)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
