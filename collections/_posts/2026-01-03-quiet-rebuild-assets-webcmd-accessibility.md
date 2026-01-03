---
layout: post
title: "A quiet rebuild: assets, webcmd, and accessibility"
date: 2026-01-03
categories: 
- Personal Essays
- Technology
tags: [jekyll, webcmd, accessibility, ux, maintenance]
featured_image: assets/images/featured/2026-01-03-quiet-rebuild-assets-webcmd-accessibility.jpg
featured_image_alt: "Translucent UI panels with code, layered cards, and checkmark lists in a cool blue palette."
featured_image_caption: "A calm, retro-futurist dashboard of systems and checks."
---

Over the last day I made a round of changes that do not scream "new feature," but materially improve how this site loads, behaves, and feels -- especially for readers who use keyboard navigation or assistive tech. This post is a quick technical walkthrough of what changed, why it matters, and how it helps you as a reader.

## 1) Consolidated assets into one place
Previously the site had both `public/` and `assets/`, which caused confusion and occasional broken paths. I merged everything into `assets/` and updated all references.

**What changed**
- CSS, JS, and favicon files moved from `public/` to `assets/`.
- All templates now link to `/assets/...`.
- The web manifest and webcmd page were updated to the new paths.

**Why it helps readers**
- Fewer path mismatches means fewer broken resources.
- Simpler structure makes maintenance faster, which reduces future regressions.

## 2) Modernized the favicon setup
I added an SVG favicon and kept the ICO fallback for broad support.

**What changed**
- `assets/favicon.svg` is now the primary favicon.
- `assets/favicon.ico` remains as a fallback.
- The `<link rel="icon">` tags were updated accordingly.

**Why it helps readers**
- SVG is crisp at any size; it looks sharper on modern devices.
- ICO fallback preserves compatibility on older browsers.

## 3) Webcmd got a real upgrade
`/webcmd/` is still the command-line page -- but it now matches the rest of the site and behaves more predictably.

**What changed**
- Webcmd now uses the default layout and site theme.
- The command UI is more readable and consistent with the Nord palette.
- Help output is semantic (lists + headings), easier to scan, and displayed in two columns on desktop.
- The `find` command now appears in the Searches section (where it belongs).
- Navigation commands (`ph`, `p`, `pi`, `pr`) now use relative URLs so they stay on localhost when you are testing.

**Why it helps readers**
- The page is easier to read and use, especially on mobile.
- Commands work the same in dev and production.
- The help panel is much more legible.

## 4) Accessibility pass (WCAG-oriented)
I did a focused accessibility sweep across the main site templates (excluding `jsgames/`) with WCAG 2.1 AA as the target.

**What changed**
- Added a Skip to content link and a proper `<main>` landmark.
- Sidebar toggle now updates `aria-expanded` and is keyboard-operable.
- The search overlay now traps focus and restores focus on close.
- "Annotate me" is now a real `<button>` (not a clickable `<span>`).
- Improved focus styles and general keyboard flow.

**Why it helps readers**
- Keyboard users can reach content faster.
- Screen reader navigation is clearer and more predictable.
- Dialog behavior is now much closer to expected modal behavior.

## 5) Reduced Disqus noise on non-post pages
Disqus counts were being loaded everywhere. Now they only load on posts that explicitly allow comments.

**Why it helps readers**
- Less third-party JS on pages that do not need it.
- Cleaner performance and fewer surprise widgets.

## 6) New documentation
To keep this sustainable, I wrote a few new internal docs:

- `docs/webcmd.md` explains how the command engine works and how to add new commands.
- `docs/accessibility.md` captures accessibility conventions and checks.
- The README was updated to link to both.

---

### In short
This was a maintenance sweep -- but the impact is tangible: the site is more consistent, easier to navigate, more accessible, and easier to extend.

If you notice anything off, ping me. Otherwise, I will keep iterating on the small stuff that makes reading feel smooth.
