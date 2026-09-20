---
layout: post
title: Creating a Custom Emacs Prefix Key
category: [emacs]
tags: [emacs, gnu emacs, prefix, custom prefix, keybindings]
description: This post looks into how to create a custom prefix for personal keybindings
---

In Emacs, a prefix key is simply a small keymap attached to a shorter key sequence. It provides a namespace for related commands and keeps the global keymap easier to remember.

Emacs reserves `C-c` followed by a letter for user-defined commands. This makes it a useful place for personal keymaps. However, for my Wordwise package that I load into my config, I wanted several Wordwise commands to share the `C-c w` prefix.

In Emacs, if you start with something like this:

```elisp
 (use-package wordwise
    :load-path "local-path"
    :bind
     (("C-c w w" . mapped-function)))
```
Emacs will complain that `C-c w` is a *non-prefix key*.
Binding it directly to a regular command thus causes Emacs to report that it is not a prefix.

To overcome this, you need to explicitly define a prefix command.

```elisp
 (define-prefix-command 'systemhalted/wordwise-prefix)
 (global-set-key (kbd "C-c w") #'systemhalted/wordwise-prefix)
```
Now you can create your own bindings. For Wordwise, I bound them this way:

```elisp
 (define-key systemhalted/wordwise-prefix (kbd "w") #'wordwise-mode)
 (define-key systemhalted/wordwise-prefix (kbd "i") #'wordwise-ignore-word)
 (define-key systemhalted/wordwise-prefix (kbd "d") #'wordwise-set-difficulty)
```

This creates the following keymap:

| Key     | Command             |
| ------- | ------------------- |
| `C-c w w` | Toggle `wordwise-mode` |
| `C-c w i` | Ignore a word       |
| `C-c w d` | Set word difficulty |
