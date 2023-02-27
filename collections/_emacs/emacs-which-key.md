---
layout: page
title: which-key: A Helpful Emacs Package
tags: [emacs, gnu emacs, which-key]
category: [emacs]
---

When working in Emacs, you often find yourself using complex keybindings to access various functions and commands. Memorizing all of these keybindings can be a daunting task, especially when you are dealing with multiple modes and packages. This is where the which-key package comes in. which-key is a package that provides a pop-up window that displays available keybindings and their associated commands.

## Capabilities

The main feature of which-key is its ability to display available keybindings in a pop-up window. This window appears automatically whenever you type a prefix key, such as `C-x` or `M-x`, and displays a list of all the available keybindings that start with that prefix. For example, if you type `C-x`, which-key will show you all of the available keybindings that start with `C-x`.

Additionally, which-key can be configured to display information about the command associated with each keybinding. This can be helpful if you are unsure about the purpose of a specific command or if you are trying to learn a new package.

Another useful feature of which-key is its ability to group related keybindings together. For example, if you are in Org-mode, which-key can group all of the available keybindings for Org-mode commands together in the pop-up window.

## Installation using use-package

The easiest way to install which-key is by using the popular Emacs package manager, use-package. Here are the steps to install and configure which-key using use-package:

* Open your Emacs configuration file (usually located at `~/.emacs.d/init.el` or `~/.emacs`).
* Add the following lines to your configuration file:

      
      (use-package which-key
        :ensure t
        :config
        (which-key-mode))
       
* Save the configuration file and restart Emacs.

That's it! which-key should now be installed and active in your Emacs session.

Sources
* [which-key GitHub page](https://github.com/justbur/emacs-which-key)







