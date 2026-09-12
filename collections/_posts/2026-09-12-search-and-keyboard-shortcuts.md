---
layout: post
title: "Search and Keyboard Shortcuts on This Blog"
date: 2026-09-12
categories:
  - Personal Essays
  - Technology
tags:
  - search
  - keyboard
  - ux
description: "A short guide to the search overlay and the keyboard shortcuts on SystemHalted."
comments: true
toc: true
---

During the recent redesign I moved search and theme switching out of the visual foreground, but I did not remove them. Two small features that used to announce themselves loudly now sit quietly in the corner of the header: a search button, and a set of keyboard shortcuts. This post is a quick reference for people who want to use them.

## Search

Search on this site is a client-side overlay. It runs entirely in your browser against an index built from every post and newsletter item, so there are no server round-trips once the page has loaded.

To open it:

- Click the magnifying glass in the header, or
- Press <kbd>/</kbd> or <kbd>s</kbd> anywhere on the site.

Start typing and results appear as you go. Each entry shows the article title and a short snippet, with a count at the top. Search covers both the title and the full body text of every post, and it tolerates partial or slightly-off matches. The index is particularly good at prefix matches, and if it comes up empty it falls back to plain substring matching, so most of what you remember about an article in fragments will still find it.

Up to twelve results are shown. If there are more, the count line tells you how many were left out.

The overlay opens empty with a few suggested searches — currently `emacs`, `leadership`, `newsletter`, and `javascript` — so you can click a starting point instead of typing. Press <kbd>Esc</kbd> or click outside the dialog to close it; focus returns to wherever you were before.

One note: if the search index fails to load, the overlay points you to the command-line search on the [webcmd page](/webcmd/), which is a terminal-style interface to the site with a `find` command of its own. You should not normally need it, but on a flaky connection it is a useful fallback.

## Keyboard shortcuts

The site has a small set of keyboard shortcuts. They are deliberately few, and every one of them is something you could do with the mouse instead. They exist to save the small effort of the pointer when your hands are already on the home row.

<table>
  <thead>
    <tr><th>Keys</th><th>Action</th></tr>
  </thead>
  <tbody>
    <tr><td><kbd>/</kbd> or <kbd>s</kbd></td><td>Open search</td></tr>
    <tr><td><kbd>t</kbd></td><td>Toggle light and dark theme</td></tr>
    <tr><td><kbd>g</kbd> <kbd>w</kbd></td><td>Go to Writing</td></tr>
    <tr><td><kbd>g</kbd> <kbd>p</kbd></td><td>Go to Projects</td></tr>
    <tr><td><kbd>g</kbd> <kbd>a</kbd></td><td>Go to Archive</td></tr>
    <tr><td><kbd>g</kbd> <kbd>i</kbd></td><td>Go to About</td></tr>
    <tr><td><kbd>?</kbd></td><td>Show this list of shortcuts</td></tr>
    <tr><td><kbd>Esc</kbd></td><td>Close an open overlay</td></tr>
  </tbody>
</table>

A few behaviour notes:

- The <kbd>g</kbd> shortcuts are two-key sequences. Press <kbd>g</kbd> and then the destination key within about a second. They are modelled on the `gx` navigation you may know from Vim-style interfaces.
- Shortcuts are ignored while you are typing in a search box, a comment form, or any other text field, and when you hold a modifier key like <kbd>Ctrl</kbd> or <kbd>⌘</kbd>. So no surprise behaviour while you are mid-sentence.
- Press <kbd>?</kbd> at any point to bring up the reference overlay with the full list. This is the same list shown above, and on a small screen it is easier than trying to remember it.

## Why mention this at all

The redesign moved search into a quieter corner, which worried me for a moment. A feature that is not advertised is one people may not discover. But there is a difference between not advertising something and hiding it. The search button is still in the header on every page, the shortcuts are one keypress away from being listed, and this post is an attempt at the documentation side of that decision.

So: everything that used to be loud is still there. It just waits for you to ask for it.