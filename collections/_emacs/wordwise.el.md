---
layout: emacs
title: wordwise.el - Kindle-style vocabulary hints for Emacs
description: Inline dictionary definitions above uncommon words in Emacs reading buffers, the way Kindle's Word Wise does it.
tags: [emacs, gnu emacs]
category: [emacs]
---

Amazon Kindle has a feature called Word Wise that prints a short definition
above difficult words as you read. `wordwise.el` brings that to Emacs. When
`wordwise-mode` is active, uncommon English words in the buffer get a short
dictionary definition displayed on a phantom line above the word. The name is
an homage to the Kindle feature; the package is not affiliated with Amazon.

It is aimed at reading, not editing: by default it activates only in prose
regions of reading-oriented major modes — `org-mode`, `nov-mode`,
`markdown-mode`, `gfm-mode`, and `eww-mode` (see `wordwise-allowed-modes`).
Source blocks, inline code, links, drawers, and code-like identifiers
(camelCase, ALL_CAPS, snake_case) are skipped.

## How it works

- A bundled frequency list of roughly 9,500 common English words in five
  tiers (derived from the MIT-licensed
  [google-10000-english](https://github.com/first20hours/google-10000-english)
  word list) decides which words are common enough to skip.
- A difficulty level from 1 to 5 (default 3) controls how aggressively words
  are annotated. Level 1 annotates only words absent from the entire list;
  level 5 annotates anything outside the top ~1,000 words.
- Definitions come from dict.org over one shared asynchronous DICT
  connection. Lookups never block redisplay: cached hints appear
  immediately, and misses are deduplicated and fetched one at a time.
- Results are cached in `wordwise-cache`. With `savehist-mode` enabled the
  cache persists across Emacs restarts, so each word costs at most one
  network round-trip ever.

A privacy note: annotated words are sent to dict.org in plain text over TCP.
Don't enable the mode in buffers whose vocabulary you consider sensitive.

## Install

Requires Emacs 27.1+.

With `use-package` and `package-vc` (Emacs 29+):

```elisp
(use-package wordwise
  :vc (:url "https://github.com/systemhalted/wordwise.el" :rev :newest)
  :bind ("C-c w" . wordwise-mode))
```

Or interactively: `M-x package-vc-install RET
https://github.com/systemhalted/wordwise.el RET`.

Or clone the repo, add it to `load-path`, and `(require 'wordwise)`.

## Usage

| Command                    | Purpose                                        |
|----------------------------|------------------------------------------------|
| `wordwise-mode`            | Toggle the hints in the current buffer         |
| `wordwise-set-difficulty`  | Change annotation density (1–5) and re-scan    |
| `wordwise-ignore-word`     | Never annotate the word at point (persists)    |
| `wordwise-clear-cache`     | Flush cached definitions and re-annotate       |

Customization lives in `M-x customize-group RET wordwise`: difficulty,
allowed major modes, maximum hint length, request timeout, ignored words,
and the `wordwise-hint-face` used for the hint line.

## License

GPL-3.0-or-later. The bundled word-frequency data in
`wordwise-common-words.el` is generated from the google-10000-english list
(MIT License); see that file's header for attribution.

The package and issue tracker are at
https://github.com/systemhalted/wordwise.el. Feedback and issues are
welcome.
