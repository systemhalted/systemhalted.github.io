---
layout: post
title: Creating a Custom Emacs Prefix Key
category: [emacs]
tags: [emacs, gnu emacs, prefix, custom prefix, keybindings]
description: Hto create a custom Emacs prefix for organizing related personal keybindings
---

In Emacs, a prefix key is a small keymap attached to a shorter key sequence, which in itself contains additional keybindings. It provides a namespace for related commands and keeps the global keymap easier to remember.

Emacs reserves `C-c` followed by a letter for user-defined commands. This makes it a natural place for personal keymaps. However, for Wordwise, a package that I load into my Emacs config, I wanted several Wordwise commands to share the `C-c w` prefix.

I initially tried defining a longer key sequence directly

```elisp
 (use-package wordwise
    :load-path "local-path"
    :bind
     (("C-c w w" . mapped-function)))
```

Emacs reported that `C-c w` was a *non-prefix key*. Before Emacs can bind `C-c w w`, it must know that `C-c w` introduces another keymap. 

To do that, we need to explicitly define a prefix command and bind it to `C-c w`:

```elisp
 (define-prefix-command 'systemhalted/wordwise-prefix)
 (global-set-key (kbd "C-c w") #'systemhalted/wordwise-prefix)
```

The prefix command creates a keymap to which additional commands can now be bound. For Wordwise, I created following:

```elisp
 (define-key systemhalted/wordwise-prefix (kbd "w") #'wordwise-mode)
 (define-key systemhalted/wordwise-prefix (kbd "i") #'wordwise-ignore-word)
 (define-key systemhalted/wordwise-prefix (kbd "d") #'wordwise-set-difficulty)
```

This creates the following keybindings:

| Key     | Command             |
| ------- | ------------------- |
| `C-c w w` | Toggle `wordwise-mode` |
| `C-c w i` | Ignore a word       |
| `C-c w d` | Set word difficulty |

With `C-c w` acting as a dedicated prefix, related Wordwise commands remain grouped under a single, memorable namespace.