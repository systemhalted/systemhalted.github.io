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
featured_image_caption: "Site maintenance: assets, webcmd, accessibility."
---

Over the last day or so, I made a round of changes to this site that will not look like much from the outside, but that I think materially improve how it loads, how it behaves, and how it feels to use — especially for readers who navigate by keyboard or rely on assistive technology. None of this is glamorous work, but the kind of unglamorous maintenance that quietly removes friction is, in my experience, often the thing that makes a site usable over the long run. What follows is a short walkthrough of what changed and why I thought it was worth doing.

## 1) Consolidated assets into one place

The site had grown to keep static files in two different locations — `public/` and `assets/` — and the inconsistency had begun to cause exactly the sort of small problems that consistency is supposed to prevent: occasional broken paths, references that pointed to the wrong directory, and a small but real amount of cognitive overhead every time I had to remember which folder a particular file lived in.

I have now merged everything into `assets/`. CSS, JavaScript, and the favicon files have all moved over from `public/`, every template has been updated to reference `/assets/...`, and the web manifest along with the webcmd page have been corrected to match. The reader-facing benefit is mostly negative — fewer broken resources where there is no good reason for any to break — but the structural simplification also makes future maintenance easier, which I expect will matter more over time than any single fix in this round.

## 2) Modernized the favicon setup

While I was tidying up `assets/`, I also took the opportunity to modernise the favicon. The site now serves an SVG favicon as the primary asset, with the old ICO file still in place as a fallback for older browsers that do not yet handle SVG icons gracefully. The `<link rel="icon">` tags in the templates were updated accordingly. SVG is crisp at any size and looks visibly sharper on modern displays, while the ICO fallback preserves compatibility for the small but persistent set of browsers that still need it.

## 3) Webcmd was modernised

The `/webcmd/` page is still the command-line interface to the site that it always was, but it had drifted out of sync with the rest of the site in a few small ways. It is now using the default site layout and theme, which means it inherits the Nord palette and reads consistently with everything else. The help output, which was previously a wall of text, is now properly semantic — lists and headings rather than line-by-line plaintext — which makes it easier to scan and renders in two columns on desktop while collapsing sensibly on mobile.

A couple of smaller fixes also went in. The `find` command, which had quietly been listed under the wrong section, is now grouped with the other Searches commands where it belongs. The navigation commands (`ph`, `p`, `pi`, `pr`) now use relative URLs, which means they continue to work as expected when I am testing locally on `localhost` — previously they would silently rewrite to the production host, which made local testing more annoying than it had any reason to be.

## 4) Accessibility pass (WCAG-oriented)

I also did a focused accessibility sweep across the main site templates, with WCAG 2.1 AA as the target — the `jsgames/` directory is excluded for now, since it is a different problem with a different set of constraints.

The work was less about adding any one big feature and more about closing a number of small gaps. There is now a "Skip to content" link at the top of every page, and a proper `<main>` landmark wrapping the primary content, both of which make keyboard and screen-reader navigation considerably faster. The sidebar toggle correctly updates `aria-expanded` and is now operable from the keyboard rather than only by mouse. The search overlay now traps focus while it is open and restores focus to the original element when it is closed, which is what a modal dialog should do but which my old implementation was not doing. The "Annotate me" control, which had been a clickable `<span>` for historical reasons, is now a real `<button>`. And the focus styles across the site have been tightened up so that keyboard users can actually see where they are at any given time.

The cumulative effect, for readers using assistive technology, should be noticeably more predictable behaviour throughout the site, and a meaningful reduction in the number of places where keyboard navigation hits an unexpected dead end.

## 5) Reduced Disqus noise on non-post pages

Disqus comment-count scripts were, until this round, being loaded on every page of the site, including pages that do not and never will have comments. They are now only loaded on posts that explicitly allow comments. This means there is less third-party JavaScript running on the home page, archive pages, and other non-post views, which both improves page-load performance modestly and reduces the slightly disorienting experience of seeing comment-related widgets briefly flicker on pages that have no comments to count.

## 6) New documentation

Finally, in the interest of keeping all of the above sustainable rather than letting it bit-rot, I wrote a couple of internal documents to capture the conventions I have adopted. `docs/webcmd.md` explains how the command engine works and how to add new commands without re-learning the system every time. `docs/accessibility.md` captures the accessibility conventions I am now trying to maintain, along with a small checklist of things to verify when adding new templates. The README has been updated to point to both, so that next-me, or anyone else who eventually pokes at the codebase, has a fighting chance of doing it correctly.

---

### In short

Taken individually, none of these changes is a headline. Taken together, however, they leave the site noticeably more consistent, more accessible, and easier to extend — which is, I think, what most maintenance work ought to look like when it is going well.

If you notice anything that looks broken or behaves oddly after this round of changes, please do let me know. Otherwise, I will keep working through the small stuff in the background, on the assumption that the cumulative result of doing so over time tends to be worth more than any single big feature would have been.
