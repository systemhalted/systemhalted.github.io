---
layout: emacs
title: Emacs Configuration
toc: true
tags: [emacs, gnu emacs]
category: [emacs]
description: This is a compact Emacs configuration focused on Org mode, Java, Python and Jupyter notebooks, web programming, Git, and documentation formats.
---

# Overview

This is a compact Emacs configuration focused on Org mode, Java, Python and
Jupyter notebooks, web programming, Git, and documentation formats.

The guiding rule is simple: keep Emacs excellent at the work that happens here
every day, and remove stacks that mainly preserve old habits. 

The current direction favors composable packages that use Emacs' built-in
completion and language APIs. Large, all-in-one frameworks were replaced where a
smaller stack gives the same workflow with less hidden state. Org is treated as a
system for thinking, consuming, and executing, not as a maximal task manager.


# Startup and Package Management

Startup is intentionally boring. Package archives are current and explicit:
GNU/Nongnu provide core ecosystem packages, MELPA provides actively maintained
tooling, and MELPA Stable remains lower priority. `use-package` is used only to
make package ownership and configuration boundaries obvious. External packages
declare `:ensure t` at the call site; built-in packages declare `:ensure nil`.
There is no global auto-install switch because broad implicit installs make
reloads harder to reason about.

Emacs Custom can still write local state, but it is redirected under
`var/custom.el` so generated choices do not churn this repository. Settings that
are part of the intentional configuration should live here instead. Opaque
fingerprints, such as trusted theme hashes, can remain in ignored Custom state;
readable preferences, such as the `lsp-ui` face overrides below, belong in the
literate config.

Native compilation runs asynchronously for installed packages, and several
upstream packages (`dap-mode`, `lsp-java`, `posframe`, `lsp-treemacs`) emit
"function not known to be defined" warnings because cross-package references are
visible to the byte compiler before their `declare-function` forms load. The
warnings are benign — every symbol resolves at runtime via autoloads — so the
Warnings buffer is silenced. Messages are still written to the
`*Native-compile-Log*` buffer if a real failure ever needs investigation.
```emacs-lisp
    ;;; systemhalted.el --- Personal Emacs configuration -*- lexical-binding: t; -*-
    
    (setq gc-cons-threshold (* 50 1000 1000))
    
    (setq native-comp-async-report-warnings-errors 'silent)
    
    (add-hook 'emacs-startup-hook
              (lambda ()
                (message "Emacs loaded in %.2f seconds with %d garbage collections."
                         (float-time (time-subtract after-init-time before-init-time))
                         gcs-done)))
    
    (setq custom-file (expand-file-name "var/custom.el" user-emacs-directory))
    (make-directory (file-name-directory custom-file) t)
    (when (file-exists-p custom-file)
      (load custom-file))
    
    (require 'package)
    (setq package-enable-at-startup nil
          package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                             ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                             ("melpa" . "https://melpa.org/packages/")
                             ("melpa-stable" . "https://stable.melpa.org/packages/"))
          package-archive-priorities '(("gnu" . 30)
                                       ("nongnu" . 25)
                                       ("melpa" . 20)
                                       ("melpa-stable" . 10)))
    (package-initialize)
    (unless package-archive-contents
      (package-refresh-contents))
    
    (unless (package-installed-p 'use-package)
      (package-install 'use-package))
    (require 'use-package)
    (setq use-package-always-ensure nil)
```

# Core Editing

This section keeps editor behavior predictable before adding packages. The UI is
quiet, frames start fullscreen, runtime files are routed under `~/.emacs.d/`, and
reload/visit commands make this literate file easy to edit from inside Emacs.
`C-h T` surfaces the tutorial subtrees from this file as read-only indirect
buffers, the same way `C-h t` opens the built-in Emacs tutorial — the docs
live next to the code that binds them, and the buffer renders as Org so tables,
links, and verbatim keys stay legible.

Nord is the preferred theme. Theme loading disables previously enabled themes
first because repeated config reloads should not stack faces or leave stale theme
state behind.
```emacs-lisp
    (setq inhibit-startup-screen t
          initial-scratch-message nil
          initial-major-mode 'org-mode
          ring-bell-function 'ignore
          echo-keystrokes 0.01
          confirm-kill-emacs #'yes-or-no-p
          backup-by-copying t
          backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory)))
          auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save-list/" user-emacs-directory) t))
          delete-old-versions t
          kept-new-versions 3
          kept-old-versions 2
          version-control t)
    
    (fset 'yes-or-no-p #'y-or-n-p)
    (prefer-coding-system 'utf-8)
    (set-language-environment 'utf-8)
    (set-default-coding-systems 'utf-8)
    
    
    (when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
    (when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
    (when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
    
    (when (display-graphic-p)
      ;; ns-use-native-fullscreen is the NeXTSTEP (macOS) fullscreen mode
      ;; toggle and is unbound on Linux; (fullscreen . fullboth) below is
      ;; the portable bit that handles X11/PGTK.
      (when (eq system-type 'darwin)
        (setq ns-use-native-fullscreen t)))
    (add-to-list 'initial-frame-alist '(fullscreen . fullboth))
    (add-to-list 'default-frame-alist '(fullscreen . fullboth))
    
    (global-display-line-numbers-mode 1)
    (dolist (hook '(org-mode-hook term-mode-hook shell-mode-hook eshell-mode-hook))
      (add-hook hook (lambda () (display-line-numbers-mode -1))))
    
    (column-number-mode 1)
    (display-time-mode 1)
    (display-battery-mode 1)
    (electric-pair-mode 1)
    (show-paren-mode 1)
    (save-place-mode 1)
    (recentf-mode 1)
    (global-auto-revert-mode 1)
    
    (global-set-key (kbd "C-x k") #'kill-current-buffer)
    
    ;;enable cua mode
    (cua-mode 1)
    
    ;; enable windmove, for easy navigation between open windows
    (use-package windmove)
    
    (defun systemhalted/config-visit ()
      "Open the literate Emacs configuration."
      (interactive)
      (find-file (expand-file-name "systemhalted.org" user-emacs-directory)))
    (global-set-key (kbd "C-c e") #'systemhalted/config-visit)
    
    (defun systemhalted/config-reload ()
      "Save and reload the literate Emacs configuration."
      (interactive)
      (let* ((config-file (expand-file-name "systemhalted.org" user-emacs-directory))
             (config-buffer (get-file-buffer config-file)))
        (when (and config-buffer (buffer-modified-p config-buffer))
          (with-current-buffer config-buffer
            (save-buffer)))
        (message "Reloading Emacs configuration...")
        (org-babel-load-file config-file)
        (message "Reloaded Emacs configuration.")))
    (global-set-key (kbd "C-c r") #'systemhalted/config-reload)
    
    (defvar systemhalted/tutorials
      '(("Minimal Org workflow" . "Tutorial: Using the Minimal Org Workflow")
        ("LSP and DAP"          . "Using LSP and DAP")
        ("LaTeX"                . "Tutorial: Using LaTeX"))
      "Alist of (DISPLAY-NAME . ORG-HEADING) tutorial subtrees in systemhalted.org.")
    
    (defun systemhalted/tutorial ()
      "Pick a tutorial subtree from systemhalted.org and view it read-only.
    Mirrors `help-with-tutorial' (C-h t): a registry of named tutorials is
    offered via `completing-read', and the chosen subtree is shown as a
    narrowed, read-only indirect buffer over the literate config so edits
    to the source remain visible without losing place."
      (interactive)
      (let* ((choice (completing-read "Tutorial: "
                                      (mapcar #'car systemhalted/tutorials)
                                      nil t))
             (heading (cdr (assoc choice systemhalted/tutorials)))
             (buf-name (format "*Tutorial: %s*" choice)))
        (if-let ((existing (get-buffer buf-name)))
            (pop-to-buffer existing)
          (let* ((org-file (expand-file-name "systemhalted.org" user-emacs-directory))
                 (base (find-file-noselect org-file))
                 (pos (with-current-buffer base
                        (org-find-exact-headline-in-buffer heading))))
            (unless pos
              (user-error "Tutorial heading %S not found in %s" heading org-file))
            (let ((indirect (make-indirect-buffer base buf-name t)))
              (with-current-buffer indirect
                (goto-char pos)
                (org-narrow-to-subtree)
                (org-show-subtree)
                (goto-char (point-min))
                (read-only-mode 1))
              (pop-to-buffer indirect))))))
    (global-set-key (kbd "C-h T") #'systemhalted/tutorial)
    
    (with-eval-after-load 'dired
      (define-key dired-mode-map (kbd "c") #'dired-create-empty-file))
    
    (when (display-graphic-p)
      (when (find-font (font-spec :name "Fira Code"))
        (set-face-attribute 'default nil :font "Fira Code" :height 150))
      (when (find-font (font-spec :name "Cantarell"))
        (set-face-attribute 'variable-pitch nil :font "Cantarell" :height 150)))
    
    (defun systemhalted/load-theme ()
      "Load the preferred theme without stacking themes on reload."
      (mapc #'disable-theme custom-enabled-themes)
      (load-theme 'nord t))
    
    (use-package nord-theme
      :ensure t
      :custom
      (nord-region-highlight "frost")
      :config
      (systemhalted/load-theme))
```

## Clipboard

GUI Emacs already shares the system clipboard with the host on every windowed
backend it supports (NS/Cocoa, X11, PGTK, Wayland). The options below add the
polish that turns that bidirectional plumbing into the behavior most people
expect:

-   `save-interprogram-paste-before-kill` pushes whatever currently sits in the
    host clipboard onto the kill-ring *before* a new Emacs kill overwrites the
    selection, so a paste from outside Emacs is still recoverable through `M-y` /
    `consult-yank-pop`.
-   `yank-pop-change-selection` mirrors the result of `M-y` back to the system
    clipboard so the next external paste matches what is visible in Emacs.
-   `kill-do-not-save-duplicates` collapses adjacent identical kills in the
    kill-ring so `M-y` history is not cluttered by repeated yanks of the same
    thing.

Terminal Emacs (`emacs -nw` inside Terminal.app, iTerm2, GNOME Terminal,
Alacritty, etc.) talks to no display server and therefore cannot reach the
host clipboard without help. `xclip` bridges the gap: on macOS it shells out
to `pbcopy` / `pbpaste`, on X11 to `xclip` or `xsel`, on Wayland to `wl-copy`
/ `wl-paste`. It is loaded only when the starting frame is non-graphical so
it does not displace the native bridge in windowed GUI Emacs.

```emacs-lisp
    (setq select-enable-clipboard t
          select-enable-primary nil
          save-interprogram-paste-before-kill t
          yank-pop-change-selection t
          kill-do-not-save-duplicates t)
    
    (use-package xclip
      :ensure t
      :if (not (display-graphic-p))
      :config
      (xclip-mode 1))
```

## Text Manipulation


### Move text

Sometimes, I need to move a text up and down a bit. Here, I am mapping M-n and M-p to move text down and move text up respectively.

```emacs-lisp
    (use-package move-text
     :ensure t
     :bind (("M-n" . move-text-down)
            ("M-p" . move-text-up))
     :config
     (message "move-text loaded successfully"))
```

### Duplicate the current line

Equivalent of `C-d` (`Cmd-d` on Mac) in Intellij Idea. Source: <https://www.emacswiki.org/emacs/CopyingWholeLines#toc12>

```emacs-lisp
    (define-key global-map (kbd "C-c d")
    (defun systemhalted/duplicate-line-or-region (&optional n)
      "Duplicate current line, or region if active.
      With argument N, make N copies.
      With negative N, comment out original line and use the absolute value."
      (interactive "*p")
      (let ((use-region (use-region-p)))
        (save-excursion
          (let ((text (if use-region        ;Get region if active, otherwise line
                          (buffer-substring (region-beginning) (region-end))
                        (prog1 (thing-at-point 'line)
                          (end-of-line)
                          (if (< 0 (forward-line 1)) ;Go to beginning of next line, or make a new one
                              (newline))))))
            (dotimes (i (abs (or n 1)))     ;Insert N times, or once if not specified
              (insert text))))
        (if use-region nil                  ;Only if we're working with a line (not a region)
          (let ((pos (- (point) (line-beginning-position)))) ;Save column
            (if (> 0 n)                             ;Comment out original with negative arg
                (comment-region (line-beginning-position) (line-end-position)))
            (forward-line 1)
            (forward-char pos))))))
```

### Join following line
```emacs-lisp
    (define-key global-map (kbd "C-c k")
    (defun systemhalted/join-following-line (arg)
      "Joins the following line or the whole selected region"
      (interactive "P")
      (if (use-region-p)
          (let ((fill-column (point-max)))
            (fill-region (region-beginning) (region-end)))
        (join-line -1))))
```

# Completion, Navigation, and Help

The completion stack is built from small packages that cooperate through
Emacs' standard completion system and adjacent help/navigation APIs rather than
a single large framework. Each piece has one job:

-   `Savehist` persists minibuffer, search, kill-ring, and completion history.
-   `Orderless` decides *what counts as a match* for a typed query.
-   `Vertico` renders *minibuffer* candidates (file pickers, `M-x`, prompts).
-   `Marginalia` annotates those minibuffer candidates with extra context.
-   `Consult` supplies jump-and-search commands that feed the minibuffer.
-   `Embark` acts on the current candidate or symbol without leaving context.
-   `Helpful` renders richer reference buffers for commands, variables, keys, and symbols.
-   `Corfu` renders *in-buffer* completion (the popup while typing code).
-   `Projectile` adds project-scoped commands (find file in project, etc.).
-   `ibuffer` manages buffers in bulk (mark, filter, kill) at `C-x C-b`.
-   `which-key` pops up keymap continuations after any prefix key.

Two surfaces, two UIs: minibuffer completion (Vertico) is intentionally
separate from at-point completion (Corfu). Both reuse the same matching style
through Orderless. Help and discovery sit beside those completion surfaces:
Embark exposes available actions, Helpful explains Lisp objects, and which-key
shows prefix maps. Any one piece can be swapped or removed without disturbing
the others.


## Savehist — persist minibuffer history

[Savehist](https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-History.html) persists minibuffer history across restarts. It is the substrate
the rest of this section sits on: `vertico` sorts candidates by recency,
`consult-yank-pop` reads `kill-ring`, and `corfu-history` persists itself
through `savehist-additional-variables`. Bumping `history-length` to 200
keeps enough recent entries to be useful without bloating `history`.

```emacs-lisp
    (use-package savehist
      :ensure nil
      :custom
      (savehist-additional-variables '(search-ring regexp-search-ring kill-ring))
      (history-length 200)
      :init
      (savehist-mode 1))
```

## Orderless — flexible matching style

[Orderless](https://github.com/oantolin/orderless) is a completion *style*, not a UI. It changes how the typed
input is matched against candidates: whitespace-separated components match
in any order, anywhere in the candidate. Typing `kafka proj` can match
`src/projects/kafka-bridge.clj` even though those tokens are not adjacent
and not in that order. Every minibuffer command (Vertico) and every at-point
popup (Corfu) inherits this behavior because they both ask Emacs' generic
completion machinery to filter, and that machinery consults
`completion-styles`.

The `basic` fallback is kept for cases like TRAMP paths where strict prefix
matching is required, and `partial-completion` is added for file names so
`/u/s/l` still expands to `/usr/share/local`.

`orderless-matching-styles` adds `orderless-prefixes` to the default chain.
That style splits a single token on `-` or `_` and matches each piece as a
prefix anywhere in the candidate, so `M-x desc-fun` finds
`describe-function`, `sql-co-bu` finds `sql-connect-buffer`, etc. — the
behavior most people expect when typing a hyphenated symbol from memory.
`orderless-literal` still wins when the token contains characters that
would not parse as a regexp, and `orderless-regexp` remains as the final
fallback.

```emacs-lisp
    (use-package orderless
      :ensure t
      :custom
      (completion-styles '(orderless basic))
      (orderless-matching-styles '(orderless-literal
                                   orderless-prefixes
                                   orderless-regexp))
      (completion-category-defaults nil)
      (completion-category-overrides '((file (styles basic partial-completion)))))
```

## Built-in completion defaults

A few built-in switches make the small-package stack feel polished without
adding any new package. `completion-ignore-case` and its file/buffer
counterparts let Orderless tokens match regardless of case: `M-x desc-fun`
finds `describe-function`. `enable-recursive-minibuffers` allows nested
prompts (`M-:` from inside `find-file`, or any Embark action that opens a
new minibuffer); `minibuffer-depth-indicate-mode` pairs with it so the
prompt shows a `[2]`, `[3]` prefix when nested — without that, `C-g` can
look like it "exits completely" when really it just dropped one level.
The `minibuffer-prompt-properties` addition plus `cursor-intangible-mode`
prevents the cursor from accidentally landing inside the prompt text.

```emacs-lisp
(use-package emacs
      :ensure nil
      :custom
      (completion-ignore-case t)
      (read-buffer-completion-ignore-case t)
      (read-file-name-completion-ignore-case t)
      (enable-recursive-minibuffers t)
      (minibuffer-prompt-properties
       '(read-only t cursor-intangible-mode t face minibuffer-prompt))
      :hook (minibuffer-setup . cursor-intangible-mode)
      :init
      (minibuffer-depth-indicate-mode 1))
```

## Vertico — minibuffer UI

[Vertico](https://github.com/minad/vertico) is what shows up whenever Emacs reads something interactively:
`C-x C-f` (find file), `C-x b` (switch buffer), `M-x` (run command),
`C-h f` (describe function), capture template selection, yes/no prompts,
and so on. Candidates appear as a vertical list under the prompt; `C-n` /
`C-p` move the selection, `RET` accepts, `TAB` completes the common prefix.
`vertico-cycle t` lets the selection wrap around at the ends of the list.

Vertico does not decide *which* candidates match — Orderless does that.
Vertico just displays the filtered set and tracks the current choice.

```emacs-lisp
    (use-package vertico
      :ensure t
      :custom
      (vertico-cycle t)
      :config
      (vertico-mode 1))
```

## Vertico-Directory — Ivy-style file path navigation

[Vertico-Directory](https://github.com/minad/vertico/blob/main/extensions/vertico-directory.el) is an extension that ships with Vertico. It rebinds three
keys inside `vertico-map` so the minibuffer behaves like a file browser when
the prompt holds a path:

-   `RET` on a directory candidate *descends into* that directory and lists
    its contents, instead of selecting it as a literal value. Pair with `M-RET`
    (Vertico default) when you really do want the literal path.
-   `C-l` moves *up* one directory regardless of where point sits in the
    prompt — the Ivy `counsel-find-file` reflex.
-   `DEL` at the end of `~/.emacs.d/foo/` deletes the trailing path component
    back to `~/.emacs.d/`, the way Ivy's `counsel-find-file` behaved. Outside
    that context it is an ordinary backspace.
-   `M-DEL` deletes a word inside the path.

The `rfn-eshadow-update-overlay` hook installs `vertico-directory-tidy` so
shadowed prefixes collapse cleanly: typing `/etc` after `~/foo/` shows
`/etc`, not `~/foo//etc`. The extension lives inside the installed Vertico
package, so `:ensure nil :after vertico` is correct — no separate install.

```emacs-lisp
  (use-package vertico-directory
      :ensure nil
      :after vertico
      :bind (:map vertico-map
                  ("RET"   . vertico-directory-enter)
                  ("C-l"   . vertico-directory-up)
                  ("DEL"   . vertico-directory-delete-char)
                  ("M-DEL" . vertico-directory-delete-word))
      :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))
```

## Hidden file toggle in file prompts

Pressing `M-h` inside any file prompt flips visibility of dotfiles for the
current and subsequent prompts. The implementation is small:
`systemhalted-vertico-show-hidden-files` is a global flag (defaults to `t`
to match plain `read-file-name` behavior — show everything). An `:around`
advice on `read-file-name` installs a wrapping predicate that drops dotfiles
when the flag is nil, *except* when the basename being typed in the prompt
already starts with `.` — that escape hatch lets you reach a hidden file
without first hitting the toggle.

The toggle command flips the flag and forces Vertico to re-filter the
current candidate set in place by invalidating its input cache and calling
`vertico--exhibit`, so you don't have to abort and re-prompt to see the
effect. `M-h` is bound in `vertico-map`, not in
`minibuffer-local-filename-completion-map`, because Vertico's setup hook
replaces the local map outright (`use-local-map vertico-map`); the latter
map is never consulted during a Vertico-driven file prompt. The command
guards itself with `minibuffer-completing-file-name` so pressing `M-h` in a
buffer / command / variable prompt is a clear no-op rather than a surprise.

```emacs-lisp
    (defvar systemhalted-vertico-show-hidden-files t
      "When non-nil, file-name completion shows hidden files (dotfiles).
    Toggle with `systemhalted/vertico-toggle-hidden-files' inside a file prompt.")
    
    (defun systemhalted--file-name-hidden-p (file)
      "Return non-nil if FILE's basename is a dotfile (excluding `.' and `..')."
      (let ((name (file-name-nondirectory (directory-file-name file))))
        (and (string-prefix-p "." name)
             (not (member name '("." ".."))))))
    
    (defun systemhalted--read-file-name-with-hidden-filter
        (orig prompt &optional dir default-filename mustmatch initial predicate)
      "Around-advice for `read-file-name' that hides dotfiles per the toggle."
      (let ((merged
             (lambda (f)
               (and (or systemhalted-vertico-show-hidden-files
                        (string-prefix-p
                         "."
                         (file-name-nondirectory
                          (or (and (minibufferp)
                                   (minibuffer-contents-no-properties))
                              "")))
                        (not (systemhalted--file-name-hidden-p f)))
                    (or (null predicate) (funcall predicate f))))))
        (funcall orig prompt dir default-filename mustmatch initial merged)))
    
    (advice-add 'read-file-name :around
                #'systemhalted--read-file-name-with-hidden-filter)
    
    (defun systemhalted/vertico-toggle-hidden-files ()
      "Toggle visibility of hidden files in the current minibuffer file prompt.
    Flips `systemhalted-vertico-show-hidden-files' and refreshes Vertico in
    place when called from inside an active file prompt. No-op on non-file
    prompts so the keybinding does not surprise in `M-x' or buffer prompts."
      (interactive)
      (cond
       ((and (minibufferp) (not minibuffer-completing-file-name))
        (message "Hidden-file toggle only applies to file prompts"))
       (t
        (setq systemhalted-vertico-show-hidden-files
              (not systemhalted-vertico-show-hidden-files))
        (when (and (minibufferp) (boundp 'vertico--input))
          (setq vertico--input t)
          (when (fboundp 'vertico--exhibit)
            (vertico--exhibit)))
        (message "Hidden files: %s"
                 (if systemhalted-vertico-show-hidden-files "shown" "hidden")))))
    
    (with-eval-after-load 'vertico
      (define-key vertico-map (kbd "M-h")
                  #'systemhalted/vertico-toggle-hidden-files))
```

## Marginalia — annotations in the minibuffer

[Marginalia](https://github.com/minad/marginalia) adds a right-aligned annotation column to Vertico's candidates.
The annotation depends on the candidate type: commands show their docstring
summary and key binding, files show mode/size/mtime, buffers show their
major mode and file path, variables show their current value. This turns
`M-x` and `describe-variable` into a passive reference — you can browse
without committing to a selection.

It loads after Vertico because the annotation hook is only useful once a
minibuffer UI is active. The default `marginalia-annotators` registry
already lists the rich annotator first for each candidate category, so
full annotations show on the first prompt — no override required. `M-A`
inside the minibuffer cycles each category to its lighter variants
(`builtin`, `none`) when the default annotation feels too long.

```emacs-lisp
    (use-package marginalia
      :ensure t
      :after vertico
      :bind (:map minibuffer-local-map
                  ("M-A" . marginalia-cycle))
      :init
      (marginalia-mode 1))
```

## Consult — focused search and navigation commands

[Consult](https://github.com/minad/consult) is a collection of commands purpose-built to feed the
Vertico-style minibuffer. They take something Emacs already knows about
(buffer lines, open buffers, project files, recent files, bookmarks, the
kill ring, marks, …) and expose it as a narrowable, previewable list.

The daily bindings here:

-   `C-s` runs `consult-line` — incremental search across the current
    buffer's lines, but each candidate is a full line so Orderless tokens
    apply. Better than `isearch` when the goal is *jump to* rather than
    *step through*.
-   `C-x b` and `C-c b` run `consult-buffer` — a unified picker over open
    buffers, recent files, and bookmarks. Type the narrowing key (`b`, `f`,
    `m`, `p`, …) at the start to restrict the source.
-   `C-c s` runs `consult-ripgrep` — streams `rg` results into the
    minibuffer with live preview. The de facto project search.
-   `M-y` runs `consult-yank-pop` — pick from the kill ring as a previewable
    list instead of cycling blindly. Persisted across restarts because
    `savehist-additional-variables` keeps `kill-ring`.
-   `M-g g` and `M-g M-g` remap to `consult-goto-line`, which previews the
    destination line as you type the number.

Both `C-x b` and `C-c b` bind the same command on purpose: `C-x b` matches
Emacs muscle memory, `C-c b` sits in the user prefix range alongside the
other `C-c` shortcuts.

`consult-narrow-key` is set to `<` so a leading `<` followed by a narrowing
character restricts the source (e.g. `< b` for buffers in `consult-buffer`).
The `xref-show-*-function` hooks route `M-.` and `xref-find-references`
through Consult, so `Vertico` replaces the legacy `*xref*` buffer when
multiple candidates exist. Previews are debounced via `consult-customize`:
buffers/recent files preview after 0.2s of stillness, ripgrep/grep/line
previews wait 0.4s, which keeps large repos from churning the display while
you scroll candidates.

```emacs-lisp
    (use-package consult
      :ensure t
      :bind
      (("C-s"   . consult-line)
       ("C-x b" . consult-buffer)
       ("C-c b" . consult-buffer)
       ("C-c s" . consult-ripgrep)
       ("M-y"   . consult-yank-pop)
       ([remap goto-line] . consult-goto-line))
      :custom
      (consult-narrow-key "<")
      (xref-show-xrefs-function       #'consult-xref)
      (xref-show-definitions-function #'consult-xref)
      :config
      (consult-customize
       consult-buffer consult-recent-file
       :preview-key '(:debounce 0.2 any)
       consult-ripgrep consult-grep consult-line
       :preview-key '(:debounce 0.4 any)))
```

## Embark — act on minibuffer candidates

[Embark](https://github.com/oantolin/embark) adds the verb that the rest of this stack was missing. With a
candidate selected in any minibuffer prompt, `C-.` opens a context-sensitive
action menu: open in another window, copy path, kill the buffer, browse the
URL, run grep on the directory, describe the symbol, etc. `C-;` is
`embark-dwim`, which runs the most likely action without showing the menu.
`C-h B` lists every action bound for the current candidate type, which is
how to discover what's available without leaving the prompt.

Setting `prefix-help-command` to `embark-prefix-help-command` replaces the
default `C-h-after-prefix` help with a Vertico-rendered prompt: pressing
`C-h` after `C-x` shows every `C-x` binding as a searchable list.

The integration with Consult is built into Embark: `embark-export` from a
`consult-line` or `consult-ripgrep` result produces an editable grep-mode
buffer, and `consult-preview-at-point-mode` previews the underlying
location as you move through an `embark-collect` buffer.

```emacs-lisp
    (use-package embark
      :ensure t
      :bind
      (("C-."   . embark-act)
       ("C-;"   . embark-dwim)
       ("C-h B" . embark-bindings))
      :custom
      (prefix-help-command #'embark-prefix-help-command)
      :config
      ;; Consult integration is built into embark; just enable the preview hook.
      (with-eval-after-load 'consult
        (add-hook 'embark-collect-mode-hook #'consult-preview-at-point-mode)))
```

## Helpful — richer describe buffers

[Helpful](https://github.com/Wilfred/helpful) replaces the built-in
`describe-*` buffers with richer Emacs Lisp reference pages. It does not
participate in completion or navigation directly; Vertico, Consult, Embark,
Corfu, Projectile, and Xref still own those jobs. Helpful is for the moment
after a command, variable, key, or symbol has been found and you want better
documentation: source links, aliases, callers, key bindings, plist details,
and a more useful summary of what kind of Lisp object is being described.

The standard help keys are remapped rather than duplicated, so `C-h f`,
`C-h v`, and `C-h k` keep their muscle memory while opening Helpful buffers.
`C-h f` goes to `helpful-callable` instead of `helpful-function` because a
symbol at that prompt may be a function, macro, or special form. Direct
bindings for `helpful-function` and `helpful-symbol` remain on `C-h F` and
`C-h S` for cases where the narrower command is wanted.

`C-h .` is intentionally reassigned from `display-local-help` to
`helpful-at-point`. This configuration is maintained mostly by editing
Emacs Lisp in `systemhalted.org`, so "describe the symbol under point" is
more useful than showing button or widget `help-echo` text. The built-in
local help command remains available on `C-h C-.` for the occasional UI
button/widget case.

Programming-language hover documentation stays under LSP: use `C-c l h h`
for Java, Python, TypeScript, and other language-server buffers. Helpful is
for Emacs Lisp symbols, commands, variables, faces, and keys.

```emacs-lisp
    (use-package helpful
      :ensure t
      :bind
      (([remap describe-function] . helpful-callable)
       ([remap describe-command]  . helpful-command)
       ([remap describe-variable] . helpful-variable)
       ([remap describe-key]      . helpful-key)
       ("C-h ."                   . helpful-at-point)
       ("C-h C-."                 . display-local-help)
       ("C-h F"                   . helpful-function)
       ("C-h S"                   . helpful-symbol)))
```

## Corfu — in-buffer completion popup

[Corfu](https://github.com/minad/corfu) is the popup that appears *inside* a buffer while typing code:
function names, local variables, LSP suggestions, snippet keys, dabbrev
matches. It is the in-buffer counterpart to Vertico, and it consumes
candidates from `completion-at-point-functions` (capf) — the same hook
that `lsp-mode`, `yasnippet`, and the Emacs builtins write to. Whatever
the active mode contributes to capf, Corfu shows.

With `corfu-auto t` the popup appears automatically after `corfu-auto-delay`
(`0.35s`) once the typed prefix is at least `corfu-auto-prefix` characters
(`3`). The slightly slower trigger is intentional: Java LSP completion can
allocate a lot of Emacs-side JSON and candidate metadata, so completion waits
until the prefix is specific enough to be useful. `TAB` accepts the selection,
`M-n` / `M-p` cycle, `corfu-cycle t` wraps at the ends, and
`corfu-preselect 'prompt` keeps your typed prefix selected so `RET` inserts
what you typed rather than the first suggestion. `global-corfu-mode` turns it
on in every buffer.

Corfu replaces `company` from the older config; see the Programming section
for how `lsp-mode` is configured to feed Corfu through capf.

```emacs-lisp
    (use-package corfu
      :ensure t
      :custom
      (corfu-auto t)
      (corfu-auto-delay 0.35)
      (corfu-auto-prefix 3)
      (corfu-cycle t)
      (corfu-preselect 'prompt)
      :config
      (global-corfu-mode 1))
```

## Corfu-Popupinfo — docs panel beside the candidate list

[Corfu-Popupinfo](https://github.com/minad/corfu/blob/main/extensions/corfu-popupinfo.el) is a Corfu extension that shows the docstring or signature
of the currently selected candidate in a side popup. In LSP buffers that extra
documentation can trigger language-server requests while typing, so the mode is
available but not enabled automatically. Toggle it for the current buffer with
`C-c l i` when you want completion-side docs. Like `vertico-directory`, this
file ships inside the installed Corfu package, so `:ensure nil :after corfu`
is the right recipe.

```emacs-lisp
    (use-package corfu-popupinfo
      :ensure nil
      :after corfu
      :custom
      (corfu-popupinfo-delay '(0.4 . 0.2)))
```

## Corfu-History — frecency-sorted candidates

[Corfu-History](https://github.com/minad/corfu/blob/main/extensions/corfu-history.el) is the in-buffer counterpart to Vertico's recency sort. It
remembers which candidates were chosen recently and floats them to the top
of the list. Adding `corfu-history` to `savehist-additional-variables`
persists the table across restarts, so the history is useful from the very
first completion of a session.

```emacs-lisp
    (use-package corfu-history
      :ensure nil
      :after (corfu savehist)
      :init
      (corfu-history-mode 1)
      :config
      (add-to-list 'savehist-additional-variables 'corfu-history))
```

## Projectile — project-scoped commands

[Projectile](https://github.com/bbatsov/projectile) knows what a *project* is — any directory containing a `.git`,
a recognized build file, or a `.projectile` marker — and exposes commands
that operate over that scope as a unit: switch project, find file in
project, kill project buffers, run the project's tests, search/replace
across the project, etc. The full keymap lives under the conventional
`C-c p` prefix. `systemhalted/promote-to-todo` takes `C-c P` (capital)
because day-to-day project work happens far more often than backlog
promotion, so the more frequent operation gets the easier chord.

`projectile-completion-system 'default` keeps Projectile's prompts going
through Emacs' standard completion — meaning Vertico + Orderless +
Marginalia all apply to project pickers too. `projectile-indexing-method
'alien` delegates the file listing to external tools (`git ls-files`,
`find`) instead of Emacs traversing directories itself; on large
repositories this is the difference between instant and seconds-long
listings. `projectile-project-search-path` seeds project discovery from
`~/Workspace` so `C-c p p` shows known projects without first having to
visit a file inside each one.

Common entry points (all under `C-c p`):

-   `C-c p p` — switch project.
-   `C-c p f` — find file in current project.
-   `C-c p b` — switch buffer within current project.
-   `C-c p s g` — grep across the project (or use `C-c s` for ripgrep via
    Consult, which is usually faster).

```emacs-lisp
    (use-package projectile
      :ensure t
      :bind-keymap
      ("C-c p" . projectile-command-map)
      :custom
      (projectile-completion-system 'default)
      (projectile-indexing-method 'alien)
      :config
      (projectile-mode 1)
      (when (file-directory-p "~/Workspace")
        (setq projectile-project-search-path '("~/Workspace"))))
```

## compile — multiple compilation buffers

Projectile's run commands (`C-c P u`) use Emacs' built-in `compile`
infrastructure. By default, all compilation commands share a single
`*compilation*` buffer, which means running a long-lived process like
`mvn spring-boot:run` blocks any subsequent `mvn test` invocation.

Setting `compilation-buffer-name-function` to generate unique buffer names
allows multiple compilation processes to run in parallel. Each buffer is
named after the command that spawned it, making it easy to identify which
process is which when switching buffers.

```emacs-lisp
    (use-package compile
      :ensure nil
      :custom
      (compilation-scroll-output t)
      :config
      (defun systemhalted/compilation-buffer-name (mode)
        "Generate a unique compilation buffer name based on the command.
    MODE is the major mode name passed by `compilation-start'."
        (let* ((cmd (or compilation-arguments "compile"))
               ;; Truncate long commands for readability
               (short-cmd (if (> (length cmd) 40)
                              (concat (substring cmd 0 37) "...")
                            cmd)))
          (generate-new-buffer-name (format "*%s: %s*" mode short-cmd))))
      (setq compilation-buffer-name-function #'systemhalted/compilation-buffer-name))
```

## ibuffer — buffer management

`ibuffer` ships with Emacs, so this is a built-in (`:ensure nil`). It
replaces the basic `list-buffers` menu on `C-x C-b` with a full
major-mode listing where buffers can be marked, filtered (by mode, file
name, size, project), killed or saved in bulk, and grouped. Think of it
as `dired` for buffers.

It complements rather than replaces `consult-buffer`. Daily switching
stays on `C-x b` / `C-c b` via Consult — one prompt, one selection, go.
ibuffer is for the periodic cleanup pass: "kill every Help and Magit
buffer left over from yesterday." Two different jobs, two different
tools, no overlap.

```emacs-lisp
    (use-package ibuffer
      :ensure nil
      :bind ("C-x C-b" . ibuffer))
```

## which-key — keymap discovery

[which-key](https://github.com/justbur/emacs-which-key) is a passive
keymap aid. Press a prefix key — `C-c`, `C-x`, `C-h`, `C-x 4`, `C-c p` for
Projectile — and after a short idle delay a popup lists every continuation
bound under that prefix together with the command it runs. This makes the
rest of this section's bindings self-documenting: typing `C-c` and waiting
reveals `C-c b`, `C-c s`, `C-c p`, `C-c r`, `C-c c`, `C-c a`, etc., without
having to remember or look them up.

`which-key-idle-delay 0.4` is the wait before the popup appears. Short
enough that it surfaces during a hesitation, long enough that it stays out
of the way during fluent typing of a known chord.

```emacs-lisp
    (use-package which-key
      :ensure t
      :config
      (which-key-mode 1)
      (setq which-key-idle-delay 0.4
            which-key-sort-order 'which-key-description-order))
```

# Org Mode

Org is deliberately narrow here. The model is:

    TODO    -> intentional execution
    BACKLOG -> passive exploration and consumption
    NOTES   -> thinking and writing output

That separation replaced the old GTD-heavy setup. Agenda views are useful only
when they show actionable work, so `todo.org` is the only agenda file. Backlog
and notes are protected from TODO drift with file-local validation. Promotion is
manual through `C-c P` to force intent before something becomes work.

Jupyter support is opt-in. Normal Org startup should stay light and quiet; when a
notebook workflow is needed, `C-c j` enables the Jupyter Babel integration for
that session.

Org export is available for common document formats:

-   `C-c C-e m m` exports the current Org file to Markdown.
-   `C-c C-e h h` exports the current Org file to HTML.
-   `C-c C-e l l` exports the current Org file to LaTeX source.
-   `C-c C-e l p` exports the current Org file to PDF through LaTeX.

For this configuration, run those commands from `systemhalted.org`. Markdown,
HTML, and LaTeX source exports are written next to the Org file as
`systemhalted.md`, `systemhalted.html`, and `systemhalted.tex`. PDF export uses
the `latexmk` setup in the LaTeX section.


## Tutorial: Using the Minimal Org Workflow

This workflow has three places for information. Use them literally:

-   `~/org/todo.org` is for execution: small work you intend to do.
-   `~/org/backlog.org` is for passive intake: articles, books, ideas, and things
    you may explore later.
-   `~/org/notes.org` is for output: understanding, writing, and durable thinking.

Do not start by asking "where can Org store this?" Ask what the item is.

If it is something you will do, capture a todo:

    C-c c t

This creates a `TODO` under `* Tasks` in `todo.org`. Use this only for work that
belongs in the agenda. Keep the wording executable, for example:

    * Tasks
    *,* TODO Review Kafka notes and decide next experiment
    *,* IN-PROGRESS Implement retry handling
    *,* DONE Update project README

Use `C-c C-t` on a task to move it through the only allowed lifecycle:

    TODO -> IN-PROGRESS -> DONE

If it is something you might consume or explore, capture backlog:

    C-c c b

This opens a sub-menu so the item is filed by kind instead of dumped into one
bucket. Pick one:

    a -> Article
    b -> Book
    i -> Idea
    v -> Video
    c -> Course

Backlog entries are plain headings, not tasks. The file is organized as passive
categories:

    * Articles
    *,* Kafka exactly-once semantics
    
    * Books
    *,* Designing Data-Intensive Applications
    
    * Ideas
    *,* Event Gateway abstraction
    
    * Videos
    *,* Jepsen talk on consistency
    
    * Courses
    *,* MIT 6.824 Distributed Systems

Do not add `TODO`, `SCHEDULED`, or `DEADLINE` in backlog. If an item becomes real
work, open the backlog item, place point inside its subtree, and promote it:

    C-c P

Promotion moves the subtree into `todo.org` under `* Tasks` and marks it `TODO`.
This manual step is intentional. Backlog is allowed to be large and speculative;
todo should stay small and committed.

If it is something you learned, wrote, or want to develop as thinking, capture a
note:

    C-c c n

Capture behavior is source-aware:

-   If you launch `C-c c n` while point is on a heading in `backlog.org` (or any
    other Org file with a heading), the note is filed under a top-level heading
    in `notes.org` dedicated to that source. The source heading gains an `:ID:`
    property the first time, and the notes heading gains a matching `:SOURCE_ID:`.
    Every future note captured from the same item joins the same subtree, even if
    the source is later renamed in `backlog.org`.
-   If you launch `C-c c n` from a non-Org buffer (or from inside `notes.org`
    itself), the note falls back under the flat top-level `* Notes` heading.

Notes are not tasks. The captured body also contains a backlink (`%a`) so
`C-c C-o` on it jumps back to the originating backlog item.

\#+begin<sub>example</sub>


# Designing Data-Intensive Applications


## Kafka delivery guarantees

Exactly-once is a coordination property, not just a producer setting.
`[[id:7d4f1b08-3a19-4c92-b5e1-2c8b9f0e1d7a][Designing Data-Intensive Applications]]`


# Notes


## A standalone thought captured from a code buffer

\#+end<sub>example</sub>

Use agenda only for execution:

    C-c a n

The custom `Now` agenda shows `IN-PROGRESS` first and then `TODO`. Because only
`todo.org` is in `org-agenda-files`, the agenda cannot be polluted by notes or
backlog material. Standard agenda commands still operate over the same restricted
file set.

The intended daily loop is:

    Capture -> Backlog -> manually promote -> Todo -> Done -> Notes

In practice:

1.  Capture quick thoughts without over-classifying them.
2.  Review backlog when you want new work or reading material.
3.  Promote only the item you are actually willing to execute.
4.  Use the agenda to work from `IN-PROGRESS` and `TODO`.
5.  Convert completed understanding into notes when it becomes useful knowledge.

The guardrails are part of the workflow. If saving `backlog.org` errors because a
TODO or scheduled item exists, either remove the task keyword/planning line or
promote the item with `C-c P`. If saving `notes.org` errors because a TODO exists,
move that work to `todo.org` or rewrite it as a plain note.

For code and notebooks, Org Babel loads Emacs Lisp, Java, Python, and shell by
default. Jupyter support is available on demand:

    C-c j

Use Jupyter only when an Org file needs notebook-style execution. Keeping it
opt-in prevents normal Org startup from carrying notebook server state.

```emacs-lisp
    (defun systemhalted/org-file (file)
      "Return FILE expanded inside `org-directory'."
      (expand-file-name file org-directory))
    
    (defconst systemhalted/org-task-states '("TODO" "IN-PROGRESS" "DONE")
      "Org states that are reserved for todo.org only.")
    
    (defun systemhalted/org-buffer-file-p (file)
      "Return non-nil when the current buffer visits FILE in `org-directory'."
      (and buffer-file-name
           (string= (file-truename buffer-file-name)
                    (file-truename (systemhalted/org-file file)))))
    
    (defun systemhalted/org-buffer-has-task-heading-p ()
      "Return non-nil when the current buffer contains a task heading."
      (save-excursion
        (goto-char (point-min))
        (re-search-forward
         (concat "^\\*+ \\("
                 (regexp-opt systemhalted/org-task-states)
                 "\\)\\(?:[ \t]\\|$\\)")
         nil t)))
    
    (defun systemhalted/validate-backlog ()
      "Ensure backlog remains passive and never contains task entries."
      (when (systemhalted/org-buffer-has-task-heading-p)
        (error "Backlog must not contain TODO items; promote intentionally with C-c P"))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "^[ \t]*\\(?:SCHEDULED\\|DEADLINE\\):" nil t)
          (error "Backlog must not contain scheduled or deadline items"))))
    
    (defun systemhalted/validate-notes ()
      "Ensure notes remain writing/thinking output, not tasks."
      (when (systemhalted/org-buffer-has-task-heading-p)
        (error "Notes must not contain TODO items")))
    
    (defun systemhalted/restrict-todo-usage ()
      "Disallow TODO state changes outside todo.org."
      (when (and org-state
                 (member org-state systemhalted/org-task-states)
                 (not (systemhalted/org-buffer-file-p "todo.org")))
        (let ((inhibit-message t))
          (org-todo 'none))
        (error "TODO states are only allowed in todo.org")))
    
    (defun systemhalted/assert-agenda-scope ()
      "Ensure the agenda only reads the execution file."
      (unless (equal org-agenda-files
                     (list (systemhalted/org-file "todo.org")))
        (error "Agenda must only include todo.org")))
    
    (defun systemhalted/org-goto-or-create-heading (heading)
      "Move to the end of top-level HEADING, creating it when needed."
      (goto-char (point-min))
      (unless (re-search-forward
               (format "^\\* %s[ \t]*$" (regexp-quote heading)) nil t)
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (unless (bobp)
          (insert "\n"))
        (insert "* " heading "\n"))
      (beginning-of-line)
      (org-end-of-subtree t t)
      (unless (bolp)
        (insert "\n")))
    
    (defun systemhalted/promote-to-todo ()
      "Move the current Org subtree to todo.org as a TODO."
      (interactive)
      (unless (derived-mode-p 'org-mode)
        (user-error "Promotion only works from Org buffers"))
      (org-back-to-heading t)
      (org-cut-subtree)
      (with-current-buffer (find-file-noselect (systemhalted/org-file "todo.org"))
        ;; Promotions land in the execution bucket and are normalized as tasks.
        (systemhalted/org-goto-or-create-heading "Tasks")
        (let ((start (point)))
          (org-paste-subtree 2)
          (goto-char start)
          (org-todo "TODO"))
        (save-buffer))
      (message "Promoted item to todo.org"))
    
    (defun systemhalted/ensure-backlog-structure ()
      "Seed an empty backlog with passive categories."
      (when (and (systemhalted/org-buffer-file-p "backlog.org")
                 (= (buffer-size) 0))
        (insert "* Articles\n\n* Books\n\n* Ideas\n\n* Videos\n\n* Courses\n")))
    
    (defun systemhalted/apply-org-file-constraints ()
      "Attach file-local guards for the minimal Org workflow."
      (cond
       ((systemhalted/org-buffer-file-p "backlog.org")
        ;; Backlog is passive intake, so task states and planning lines are rejected.
        (add-hook 'before-save-hook #'systemhalted/validate-backlog nil t))
       ((systemhalted/org-buffer-file-p "notes.org")
        ;; Notes are for thinking and writing output, so TODO cycling is disabled.
        (setq-local org-todo-keywords nil)
        (add-hook 'before-save-hook #'systemhalted/validate-notes nil t))))
    
    (defun systemhalted/org-notes-target ()
      "Position point in notes.org for a `file+function' capture target.
    When capture is launched from an Org heading outside notes.org, ensure that
    heading has an :ID: and file the new note under a top-level heading in
    notes.org keyed by :SOURCE_ID:.  This groups every note about the same source
    under one subtree even after the source is renamed.  When capture is launched
    from anywhere else, fall back to the flat `* Notes' heading."
      (let* ((src-buf (org-capture-get :original-buffer))
             (src-info
              (when (and src-buf (buffer-live-p src-buf))
                (with-current-buffer src-buf
                  (when (and (derived-mode-p 'org-mode)
                             buffer-file-name
                             (not (systemhalted/org-buffer-file-p "notes.org"))
                             (ignore-errors (org-back-to-heading t) t))
                    (cons (org-get-heading t t t t)
                          (org-id-get-create)))))))
        (goto-char (point-min))
        (cond
         (src-info
          (let ((title (car src-info))
                (id (cdr src-info)))
            (if (re-search-forward
                 (format "^[ \t]*:SOURCE_ID:[ \t]+%s[ \t]*$" (regexp-quote id))
                 nil t)
                (progn
                  (org-back-to-heading t)
                  (org-end-of-subtree t t)
                  (unless (bolp) (insert "\n")))
              (goto-char (point-max))
              (unless (bolp) (insert "\n"))
              (insert "* " title "\n"
                      "  :PROPERTIES:\n"
                      "  :SOURCE_ID: " id "\n"
                      "  :END:\n"))))
         (t
          (systemhalted/org-goto-or-create-heading "Notes")))))
    
    (use-package org
      :ensure nil
      :bind
      (("C-c a" . org-agenda)
       ("C-c c" . org-capture)
       ("C-c l" . org-store-link))
      :hook
      (org-mode . visual-line-mode)
      :custom
      (org-directory (expand-file-name "~/org/"))
      (org-default-notes-file (systemhalted/org-file "notes.org"))
      (org-log-done 'time)
      (org-ellipsis " ...")
      (org-startup-indented t)
      (org-hide-emphasis-markers t)
      (org-src-window-setup 'current-window)
      (org-confirm-babel-evaluate t)
      (org-todo-keywords
       '((sequence "TODO" "IN-PROGRESS" "|" "DONE")))
      :config
      ;; Agenda is only for execution. Backlog and notes stay out of the task view.
      (setq org-agenda-files
            (list (systemhalted/org-file "todo.org"))
            ;; Refile stays narrow; promotion from backlog to todo is explicit below.
            org-refile-targets '((org-agenda-files :maxlevel . 2))
            ;; TODO is intentional work; backlog is passive consumption/exploration;
            ;; notes are thinking and writing output. Promotion is manual by design.
            org-capture-templates
            `(("t" "Todo" entry
               (file+headline ,(systemhalted/org-file "todo.org") "Tasks")
               "* TODO %?\n%U")
              ;; Backlog is split by kind so passive intake routes into the right
              ;; bucket instead of defaulting everything to Ideas. C-c c b shows the
              ;; sub-menu; pick a, b, i, v, or c.
              ("b" "Backlog")
              ("ba" "Article" entry
               (file+headline ,(systemhalted/org-file "backlog.org") "Articles")
               "* %?\n")
              ("bb" "Book" entry
               (file+headline ,(systemhalted/org-file "backlog.org") "Books")
               "* %?\n")
              ("bi" "Idea" entry
               (file+headline ,(systemhalted/org-file "backlog.org") "Ideas")
               "* %?\n")
              ("bv" "Video" entry
               (file+headline ,(systemhalted/org-file "backlog.org") "Videos")
               "* %?\n")
              ("bc" "Course" entry
               (file+headline ,(systemhalted/org-file "backlog.org") "Courses")
               "* %?\n")
              ;; Notes are routed through a function so each backlog item linked-to
              ;; gets its own subtree in notes.org, keyed by :SOURCE_ID:.  %a
              ;; embeds an inline backlink for one-keystroke navigation back.
              ("n" "Note" entry
               (file+function ,(systemhalted/org-file "notes.org")
                              systemhalted/org-notes-target)
               "* %?\n%a"))
            ;; One high-signal view: current work first, then intentional todo items.
            org-agenda-custom-commands
            '(("n" "Now"
               ((todo "IN-PROGRESS")
                (todo "TODO")))))
      ;; These hooks preserve the Todo/Backlog/Notes boundaries over time.
      (add-hook 'org-mode-hook #'systemhalted/apply-org-file-constraints)
      (add-hook 'org-after-todo-state-change-hook #'systemhalted/restrict-todo-usage)
      (add-hook 'find-file-hook #'systemhalted/ensure-backlog-structure)
      (add-hook 'after-init-hook #'systemhalted/assert-agenda-scope)
      (systemhalted/assert-agenda-scope)
      (global-set-key (kbd "C-c P") #'systemhalted/promote-to-todo)
      (org-babel-do-load-languages
       'org-babel-load-languages
       '((emacs-lisp . t)
         (java . t)
         (python . t)
         (shell . t))))
    
    (use-package org-tempo
      :ensure nil
      :after org)
    
    (use-package org-id
      :ensure nil
      :after org
      ;; Stable IDs let notes link back to a backlog item that is later renamed or
      ;; reordered. `create-if-interactive' means `org-store-link' and the %a capture
      ;; escape lazily attach an :ID: property the first time an item is linked.
      :custom
      (org-id-link-to-org-use-id 'create-if-interactive)
      (org-id-locations-file (expand-file-name ".org-id-locations" user-emacs-directory)))
    
    (use-package ox-md
      :ensure nil
      :after org)
    
    (use-package ox-html
      :ensure nil
      :after org)
    
    (use-package ox-latex
      :ensure nil
      :after org)
    
    (defun systemhalted/org-babel-enable-jupyter ()
      "Enable Jupyter support for Org Babel in the current Emacs session."
      (interactive)
      (require 'ob-jupyter)
      (add-to-list 'org-babel-load-languages '(jupyter . t))
      (org-babel-do-load-languages
       'org-babel-load-languages
       org-babel-load-languages)
      (message "Org Babel Jupyter support enabled."))
    
    (use-package jupyter
      :ensure t
      :commands
      (jupyter-run-repl
       jupyter-connect-repl
       jupyter-server-list-kernels
       systemhalted/org-babel-enable-jupyter)
      :init
      (with-eval-after-load 'org
        (define-key org-mode-map (kbd "C-c j") #'systemhalted/org-babel-enable-jupyter)))
```

## Book view for reading

A book-style reading view for any buffer, inspired by Rougier's `book-mode` but
built from two small, theme-agnostic MELPA packages instead of pulling in
`nano-theme` and its global hook installations. The visual feel comes from two
things:

-   `olivetti` centers the buffer body in the window with wide symmetric margins,
    giving the "page" feel.
-   `mixed-pitch` renders body text in `variable-pitch` (already configured as
    Cantarell at the start of this file) while keeping `fixed-pitch` for source
    blocks, tables, inline code, and other monospace-sensitive faces. This is the
    single biggest contributor to the book look.

The other ingredients are already in place above: `org-startup-indented` for
heading indentation, `org-hide-emphasis-markers` to drop the markup characters,
and `visual-line-mode` for soft wrapping at the right margin.

Activation is on-demand via `C-c B` (capital, since `C-c b` is `consult-buffer`,
mirroring the `C-c P` convention used for `systemhalted/promote-to-todo`). The
toggle is global rather than wired into `org-mode-hook` because the three-file
model treats `todo.org` and `backlog.org` as workflow surfaces, not reading
surfaces &#x2014; book view there would harm scanning. `notes.org`, tutorial
buffers, and long-form drafts are where it belongs, and the keybinding makes it
trivial to invoke wherever it helps.

```emacs-lisp
    (use-package olivetti
      :ensure t
      :commands olivetti-mode
      :custom
      (olivetti-body-width 80)
      (olivetti-style 'fancy))
    
    (use-package mixed-pitch
      :ensure t
      :commands mixed-pitch-mode)
    
    (defun systemhalted/book-view-toggle ()
      "Toggle a book-style reading view in the current buffer.
    Enables Olivetti centered margins and mixed-pitch body text;
    re-running disables both. Intended for org reading sessions
    (notes.org, tutorials, long-form drafts) --- task and capture
    workflow is unaffected unless invoked explicitly."
      (interactive)
      (let ((enabling (not (bound-and-true-p olivetti-mode))))
        (olivetti-mode (if enabling 1 -1))
        (mixed-pitch-mode (if enabling 1 -1))))
    
    (global-set-key (kbd "C-c B") #'systemhalted/book-view-toggle)
```

# Git and Documentation

Magit is the Git interface because it is high value and isolated: one key opens
the status buffer, and the package does not impose a broader workflow. Markdown
and YAML are kept as direct file-mode support for common project documentation
and configuration files.

```emacs-lisp
    (use-package magit
      :ensure t
      :bind
      ("C-x g" . magit-status))
    
    (use-package markdown-mode
      :ensure t
      :mode
      (("README\\.md\\'" . gfm-mode)
       ("\\.md\\'" . markdown-mode)
       ("\\.markdown\\'" . markdown-mode)))
    
    (use-package yaml-mode
      :ensure t
      :mode
      (("\\.ya?ml\\'" . yaml-mode)
       ("Bogiefile\\'" . yaml-mode))
      :hook
      (yaml-mode . (lambda ()
                     (setq-local tab-width 2)
                     (define-key yaml-mode-map (kbd "RET") #'newline-and-indent))))
```

# Programming

Programming support is centered on LSP because Java, Python, and web projects
all benefit from language-server features: diagnostics, jump-to-definition,
rename, completion metadata, and formatting. `lsp-mode` owns the protocol,
`lsp-ui` adds lightweight UI affordances, `lsp-java` configures JDT LS, and
`lsp-pyright` provides Python analysis through Pyright. Debugging is layered on
top through `dap-mode`, the Emacs front-end for the Debug Adapter Protocol;
`dap-java` reuses the JDT LS that `lsp-java` already installs, so Java gets
breakpoints and stepping with no extra server.

This replaces older language-specific stacks such as Elpy/Tide/company-centered
configuration. The goal is fewer parallel systems: Flycheck reports diagnostics,
Yasnippet provides snippets, Corfu handles completion UI, and LSP supplies
language intelligence. Web editing is split by file type: `web-mode` for
HTML/TSX, `rjsx-mode` for JSX/JS, `typescript-mode` for TS, and built-in
`css-mode` for CSS.

The LSP defaults below favor bounded memory over automatic UI richness. A Java
editing session previously pushed the Emacs process above 50 GB of application
memory; JDT LS itself is capped by `lsp-java-vmargs`, so the risk is Emacs
retaining protocol messages, file watches, hover payloads, and completion
metadata. Logs and IO history are capped, recursive file watchers are disabled,
and workspaces shut down when their last buffer closes. Docs, code actions,
project refreshes, and debugger UI remain available from explicit keybindings.

Shell scripts and shell dotfiles use the built-in `sh-mode`. `lsp-mode` ships a
client for `bash-language-server` (no extra wrapper package needed), and
Flycheck routes diagnostics through `shellcheck` when it is on `PATH`. Both
are external binaries; install them once before opening a shell file:

    # bash-language-server (npm, all platforms):
    npm install -g bash-language-server
    
    # shellcheck:
    # macOS, MacPorts:   sudo port install shellcheck
    # macOS, Homebrew:   brew install shellcheck
    # Fedora:            sudo dnf install ShellCheck
    # Ubuntu / Debian:   sudo apt install shellcheck

A small hook, `systemhalted/sh-pick-shell`, sets `sh-shell` to `zsh` for
recognised zsh dotfiles (`.zshrc`, `.zshenv`, `.zprofile`, `.zlogin`,
`.zlogout`, `*.zsh`) and to `bash` for `.bashrc` / `.bash_*` so font-lock
matches the dialect. Ambiguous names like `.profile` are left to `sh-mode`'s
own detection (shebang or `$SHELL`).

A short usage tutorial for both LSP and DAP lives at the end of this section,
under `Using LSP and DAP`.

Note on `lsp-completion-provider`: it is set to `:none`, not `:capf`, even
though completion is very much wanted. `lsp-completion-mode` always registers
`lsp-completion-at-point` on `completion-at-point-functions` regardless of
this setting; the provider option only controls whether `lsp-mode` tries to
auto-enable `company-mode`. Since this configuration uses Corfu (capf-based)
and intentionally does not install company, `:capf` falls through to the
company branch and emits **"Unable to autoconfigure company-mode."** once per
LSP buffer. `:none` skips that branch while leaving the capf wired up.

JDK locations are **not** hard-coded here. GUI Emacs &#x2014; on macOS, on Linux
Wayland (PGTK), and on Linux X11 launched outside a terminal &#x2014; does not
inherit the user's interactive shell environment, so things like `JAVA_HOME`
and SDKMAN / Homebrew / MacPorts / asdf / distro-package `PATH` entries are
missing from the Emacs process unless we copy them in. `exec-path-from-shell`
does exactly that: it spawns a login + interactive shell, reads the named
environment variables, and pushes them into Emacs at startup. With
`JAVA_HOME` imported this way, `lsp-java` / JDT LS has a sane fallback:
whichever JDK SDKMAN (or the distro's `update-alternatives`) currently
considers default.

Java buffers get one extra project-local layer before LSP starts. If a nearby
`.sdkmanrc` contains `java=<version>` (or `maven=…`, `gradle=…`, or any other
SDKMAN candidate), `global-sdkman-mode` &#x2014; from the local `sdkman.el`
package at `~/Workspace/Personal/setup/sdkman.el/` &#x2014; applies the project
candidates to the buffer's `process-environment`, `exec-path`, and `PATH`, sets
`JAVA_HOME` / `MAVEN_HOME` / `GRADLE_HOME` as appropriate, points
`lsp-java-java-path` at that JDK's `bin/java` so JDT LS itself launches with
the project JDK, and sends the same JDK to JDT LS as the default
`java.configuration.runtimes` entry. This keeps GUI Emacs startup generic while
letting each Java project choose its own SDKMAN JDK. The Java language level
still comes from the project model (Maven/Gradle/Eclipse metadata such as
`maven.compiler.release` or `maven.compiler.source`), not from `JAVA_HOME`
alone.

The `java-mode` hook below only gates `lsp-deferred` against generated JDT LS
support directories (workspace cache and server source). `lsp-deferred` itself
does not start LSP until the buffer becomes visible, so the buffer-local
SDKMAN state applied by `global-sdkman-mode` via `after-change-major-mode-hook`
is already in place by the time JDT LS launches.

```emacs-lisp
    (setq read-process-output-max (* 1024 1024))
    
    (use-package exec-path-from-shell
      :ensure t
      :if (or (daemonp) (memq window-system '(mac ns x pgtk)))
      :init
      (setq exec-path-from-shell-variables '("PATH" "MANPATH" "JAVA_HOME"))
      ;; SDKMAN init lives in ~/.zshrc (interactive), not ~/.zprofile (login),
      ;; so a plain login shell sees no JAVA_HOME. Use -l -i to source both.
      (setq exec-path-from-shell-arguments '("-l" "-i"))
      :config
      (exec-path-from-shell-initialize))
    
    (use-package flycheck
      :ensure t
      :hook
      (prog-mode . flycheck-mode))
    
    (use-package yasnippet
      :ensure t
      :config
      (yas-global-mode 1))
    
    (use-package yasnippet-snippets
      :ensure t
      :after yasnippet)
    
    (use-package sdkman
      :load-path "~/Workspace/Personal/setup/sdkman.el/"
      :commands (sdkman-mode global-sdkman-mode sdkman-lsp-java-excluded-file-p)
      :init
      (global-sdkman-mode 1))
    
    (defun systemhalted/lsp-deferred-unless-excluded ()
      "Start `lsp-deferred' unless this buffer is generated LSP support source.
    Buffer-local SDKMAN + `lsp-java' state is applied by `global-sdkman-mode'."
      (unless (sdkman-lsp-java-excluded-file-p buffer-file-name)
        (lsp-deferred)))
    
    (use-package lsp-mode
      :ensure t
      :commands
      (lsp lsp-deferred)
      :hook
      ((java-mode . systemhalted/lsp-deferred-unless-excluded)
       ((js-mode rjsx-mode typescript-mode web-mode css-mode) . lsp-deferred))
      :bind
      (:map lsp-mode-map
            ("C-c C-f" . lsp-format-buffer)
            ("C-c l h h" . lsp-describe-thing-at-point)
            ("C-c l i" . corfu-popupinfo-toggle)
            ("C-c l H" . lsp-toggle-symbol-highlight)
            ("C-c l F" . lsp-toggle-on-type-formatting)
            ("C-c l R" . lsp-workspace-restart)
            ("C-c l j u" . lsp-java-update-project-configuration))
      :custom
      (lsp-keymap-prefix "C-c l")
      ;; :none is the Corfu-correct value despite the name. lsp-completion-mode
      ;; registers `lsp-completion-at-point' on `completion-at-point-functions'
      ;; unconditionally; the provider setting only controls whether lsp-mode
      ;; tries to auto-enable company-mode. With Corfu we don't have company,
      ;; so :capf still takes the company branch and warns "Unable to
      ;; autoconfigure company-mode." :none skips that branch entirely while
      ;; leaving capf wired up — which is what Corfu consumes.
      (lsp-completion-provider :none)
      (lsp-completion-show-detail nil)
      (lsp-completion-show-kind nil)
      (lsp-enable-file-watchers nil)
      (lsp-enable-symbol-highlighting nil)
      (lsp-enable-on-type-formatting nil)
      (lsp-idle-delay 1.0)
      (lsp-io-messages-max 200)
      (lsp-keep-workspace-alive nil)
      (lsp-log-io nil)
      (lsp-log-max 2000)
      (lsp-file-watch-threshold 2000)
      (lsp-headerline-breadcrumb-enable nil)
      (lsp-enable-snippet t)
      (lsp-modeline-code-actions-enable nil)
      (lsp-response-timeout 30))
    
    (use-package lsp-ui
      :ensure t
      :after lsp-mode
      :commands lsp-ui-mode
      :hook
      (lsp-mode . lsp-ui-mode)
      :custom
      (lsp-ui-doc-enable nil)
      (lsp-ui-doc-include-signature t)
      (lsp-ui-doc-show-with-mouse nil)
      (lsp-ui-sideline-enable nil)
      (lsp-ui-sideline-show-code-actions nil)
      :custom-face
      (lsp-ui-doc-background ((t (:background unspecified))))
      (lsp-ui-doc-header ((t (:inherit (font-lock-string-face italic))))))
    
    (use-package lsp-java
      :ensure t
      :after lsp-mode
      :custom
      (lsp-java-completion-guess-method-arguments nil)
      (lsp-java-configuration-update-build-configuration "interactive")
      (lsp-java-server-install-dir (expand-file-name "eclipse.jdt.ls/server/" user-emacs-directory))
      (lsp-java-workspace-dir (expand-file-name "eclipse.jdt.ls/workspace/" user-emacs-directory)))
    
    (defun systemhalted/with-longer-dap-java-timeout (orig-fun &rest args)
      "Call ORIG-FUN with a longer timeout for DAP Java launch metadata."
      ;; `dap-java-debug' resolves main class, classpath, and debug-server
      ;; metadata through synchronous JDT LS commands. Cold Maven imports can
      ;; exceed the normal interactive LSP timeout without implying server failure.
      (let ((lsp-response-timeout 60))
        (apply orig-fun args)))
    
    (use-package dap-mode
      :ensure t
      :after lsp-java
      :bind
      (:map lsp-mode-map
            ("C-c l d" . dap-hydra))
      :custom
      (dap-auto-configure-features '(sessions locals controls tooltip))
      :config
      (require 'dap-java)
      (advice-remove 'dap-java--populate-default-args
                     #'systemhalted/with-longer-dap-java-timeout)
      (advice-add 'dap-java--populate-default-args
                  :around
                  #'systemhalted/with-longer-dap-java-timeout))
    
    (use-package lsp-pyright
      :ensure t
      :after lsp-mode
      :hook
      (python-mode . (lambda ()
                       (require 'lsp-pyright)
                       (lsp-deferred)))
      :custom
      (lsp-pyright-langserver-command "pyright"))
    
    (use-package python
      :ensure nil
      :custom
      (python-shell-interpreter "python3"))
    
    (use-package web-mode
      :ensure t
      :mode
      (("\\.html?\\'" . web-mode)
       ("\\.tsx\\'" . web-mode))
      :custom
      (web-mode-markup-indent-offset 2)
      (web-mode-css-indent-offset 2)
      (web-mode-code-indent-offset 2))
    
    (use-package rjsx-mode
      :ensure t
      :mode
      (("\\.jsx?\\'" . rjsx-mode))
      :custom
      (js-indent-level 2)
      (js2-basic-offset 2)
      (js2-mode-show-parse-errors nil)
      (js2-mode-show-strict-warnings nil))
    
    (use-package typescript-mode
      :ensure t
      :mode
      (("\\.ts\\'" . typescript-mode))
      :custom
      (typescript-indent-level 2))
    
    (use-package css-mode
      :ensure nil
      :hook
      (css-mode . lsp-deferred)
      :custom
      (css-indent-offset 2))
    
    (use-package sh-script
      :ensure nil
      :mode (("\\.zshrc\\'"    . sh-mode)
             ("\\.zshenv\\'"   . sh-mode)
             ("\\.zprofile\\'" . sh-mode)
             ("\\.zlogin\\'"   . sh-mode)
             ("\\.zlogout\\'"  . sh-mode))
      :hook
      (sh-mode . systemhalted/sh-pick-shell)
      (sh-mode . lsp-deferred)
      :config
      (defun systemhalted/sh-pick-shell ()
        "Set `sh-shell' for known shell dotfiles; leave the default alone otherwise.
    Matching only well-known names avoids clobbering `sh-mode''s own detection
    \(shebang, `$SHELL') for ambiguous files like `.profile' or `foo.zshrc'."
        (when buffer-file-name
          (let ((name (file-name-nondirectory buffer-file-name)))
            (cond
             ((or (string-match-p "\\`\\.?z\\(?:shrc\\|shenv\\|profile\\|login\\|logout\\)\\'" name)
                  (string-match-p "\\.zsh\\'" name))
              (sh-set-shell "zsh" nil nil))
             ((string-match-p "\\`\\.?bash\\(?:rc\\|_profile\\|_login\\|_logout\\|_aliases\\)\\'" name)
              (sh-set-shell "bash" nil nil)))))))
    
    (when (fboundp 'js-json-mode)
      (add-to-list 'auto-mode-alist '("\\.json\\'" . js-json-mode))
      (add-hook 'js-json-mode-hook #'lsp-deferred))
    
    ;;; systemhalted.el ends here
```

-   Associate Java and related files with java-mode

    `lsp-java` caches JDK source content under filenames like
    `BlockingQueue.java(<java.util.concurrent(BlockingQueue.class)`.
    The literal trailing ')' keeps `` `\\.java\\` `` from matching, so teach
    `auto-mode-alist` about the parenthesized form explicitly.
  
  ```emacs-lisp
        ;; lsp-java caches JDK source content under filenames like
        ;;   BlockingQueue.java(<java.util.concurrent(BlockingQueue.class)
        ;; The literal trailing `)' keeps `\\.java\\'' from matching, so
        ;; teach `auto-mode-alist' about the parenthesized form explicitly.
        (add-to-list 'auto-mode-alist '("\\.java([^)]*)\\'" . java-mode))
   ```

## Using LSP and DAP

This sub-section is documentation, not configuration; nothing here tangles
into `systemhalted.el`. It captures the day-to-day workflow for the LSP and
DAP stacks set up above so the keys and commands live next to the code that
binds them.


### LSP — everyday code intelligence

LSP attaches automatically to `java-mode`, `python-mode`, `js-mode`,
`rjsx-mode`, `typescript-mode`, `web-mode`, `css-mode`, and `sh-mode` via the
`lsp-deferred` hook on `lsp-mode`. The mode line shows `LSP[<server>]` once
the server is up (`jdtls` for Java, `pyright` for Python, etc.). If it does
not appear, the server probably failed to start — check `*lsp-log*`.

Jumping to a definition (the most common move, e.g. from a Java method call
to its declaration): place point on the symbol and press `M-.`. `lsp-mode`
installs an `xref` backend when it attaches, so the standard Emacs key routes
through the language server automatically — for Java, that is JDT LS. `M-,`
returns to where you jumped from; the stack unwinds cleanly across repeated
jumps. `C-c l g g` is the `lsp-mode`-native equivalent and is useful when you
want LSP semantics specifically.

The LSP prefix is `C-c l`. The most-used commands:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Keys</th>
<th scope="col" class="org-left">Command</th>
<th scope="col" class="org-left">What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left"><code>M-.</code></td>
<td class="org-left"><code>xref-find-definitions</code></td>
<td class="org-left">jump to definition (routed via LSP)</td>
</tr>

<tr>
<td class="org-left"><code>M-,</code></td>
<td class="org-left"><code>xref-go-back</code></td>
<td class="org-left">return to the previous location</td>
</tr>

<tr>
<td class="org-left"><code>C-c l g g</code></td>
<td class="org-left"><code>lsp-find-definition</code></td>
<td class="org-left">jump to definition (LSP-native)</td>
</tr>

<tr>
<td class="org-left"><code>C-c l g r</code></td>
<td class="org-left"><code>lsp-find-references</code></td>
<td class="org-left">list references</td>
</tr>

<tr>
<td class="org-left"><code>C-c l g i</code></td>
<td class="org-left"><code>lsp-find-implementation</code></td>
<td class="org-left">jump to implementation</td>
</tr>

<tr>
<td class="org-left"><code>C-c l r r</code></td>
<td class="org-left"><code>lsp-rename</code></td>
<td class="org-left">rename symbol across the workspace</td>
</tr>

<tr>
<td class="org-left"><code>C-c l a a</code></td>
<td class="org-left"><code>lsp-execute-code-action</code></td>
<td class="org-left">quick fixes, imports, refactors</td>
</tr>

<tr>
<td class="org-left"><code>C-c l h h</code></td>
<td class="org-left"><code>lsp-describe-thing-at-point</code></td>
<td class="org-left">hover docs</td>
</tr>

<tr>
<td class="org-left"><code>C-c l i</code></td>
<td class="org-left"><code>corfu-popupinfo-toggle</code></td>
<td class="org-left">toggle completion docs for buffer</td>
</tr>

<tr>
<td class="org-left"><code>C-c l H</code></td>
<td class="org-left"><code>lsp-toggle-symbol-highlight</code></td>
<td class="org-left">toggle symbol highlighting</td>
</tr>

<tr>
<td class="org-left"><code>C-c l F</code></td>
<td class="org-left"><code>lsp-toggle-on-type-formatting</code></td>
<td class="org-left">toggle on-type formatting</td>
</tr>

<tr>
<td class="org-left"><code>C-c l R</code></td>
<td class="org-left"><code>lsp-workspace-restart</code></td>
<td class="org-left">restart current LSP workspace</td>
</tr>

<tr>
<td class="org-left"><code>C-c l j u</code></td>
<td class="org-left"><code>lsp-java-update-project-configuration</code></td>
<td class="org-left">refresh Java project model</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-f</code></td>
<td class="org-left"><code>lsp-format-buffer</code></td>
<td class="org-left">format the buffer</td>
</tr>
</tbody>
</table>

`which-key` is enabled, so pressing `C-c l` and pausing pops up the full
submenu — useful for discovering the rest of the prefix without memorizing
it.

Companion behaviors that are not LSP commands but feel like them:

-   Symbol documentation is manual, not hover-driven: `C-c l h h` asks the
    language server about the symbol at point.
-   Completion documentation is manual: `C-c l i` toggles the Corfu docs panel
    for the current buffer.
-   Flycheck owns diagnostics: `C-c ! n` / `C-c ! p` step through errors,
    `C-c ! l` lists them.
-   Corfu handles in-buffer completion after three typed characters and a short
    pause: `TAB` accepts, `M-n` / `M-p` cycle.
-   Yasnippet expands snippets at point with `TAB`.
-   Symbol highlighting and on-type formatting are off by default. Use
    `C-c l H` to toggle symbol highlighting and `C-c l F` to toggle on-type
    formatting when you want them temporarily. Full-buffer formatting remains
    available at `C-c C-f`.

When something is off, the two recovery commands worth memorizing:

-   `C-c l R` — restart the server for the current project.
-   `M-x lsp-describe-session` — see which servers are running and where.

For Java specifically, JDT LS imports the project on first open. Wait for
`LSP[jdtls]` in the mode line before invoking refactors or debugging — code
actions and `dap-java-debug-*` require the project model to be ready.
Automatic build-configuration updates are interactive; after changing
`pom.xml`, `build.gradle`, or dependency state outside Emacs, use `C-c l j u`
to ask JDT LS to refresh the project model.


### DAP — debugging Java

DAP turns `lsp-mode` buffers into debugger front-ends, but it is not enabled
for every LSP buffer at startup. That keeps normal Java editing lighter and
avoids allocating debugger UI state until it is needed. `C-c l d` opens
`dap-hydra`, the transient menu that exposes every debug command without
having to memorize bindings.

A typical first session in a Java project:

1.  Open a source file. Wait for `LSP[jdtls]` in the mode line.
2.  Move point to the line you want to pause on and run
    `M-x dap-breakpoint-toggle` (or `b t` from the hydra). A red dot appears
    in the fringe.
3.  Launch one of:
    -   `M-x dap-java-debug` — debug a class with a `main` method.
    -   `M-x dap-java-debug-test-method` — debug the JUnit test at point.
    -   `M-x dap-java-debug-test-class` — debug every test in the current class.
4.  Execution stops at the breakpoint. The *Locals*, *Sessions*, and
    *Controls* side windows open automatically (from
    `dap-auto-configure-features`).

Stepping through, mostly via `dap-hydra`:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Hydra key</th>
<th scope="col" class="org-left">Command</th>
<th scope="col" class="org-left">What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left"><code>n</code></td>
<td class="org-left"><code>dap-next</code></td>
<td class="org-left">step over</td>
</tr>

<tr>
<td class="org-left"><code>i</code></td>
<td class="org-left"><code>dap-step-in</code></td>
<td class="org-left">step into</td>
</tr>

<tr>
<td class="org-left"><code>o</code></td>
<td class="org-left"><code>dap-step-out</code></td>
<td class="org-left">step out</td>
</tr>

<tr>
<td class="org-left"><code>c</code></td>
<td class="org-left"><code>dap-continue</code></td>
<td class="org-left">continue</td>
</tr>

<tr>
<td class="org-left"><code>r</code></td>
<td class="org-left"><code>dap-restart-frame</code></td>
<td class="org-left">restart current frame</td>
</tr>

<tr>
<td class="org-left"><code>q</code></td>
<td class="org-left"><code>dap-disconnect</code></td>
<td class="org-left">end the session</td>
</tr>
</tbody>
</table>

Other commands worth knowing:

-   `M-x dap-ui-inspect-thing-at-point` — inspect the value at point. Hovering
    also shows a tooltip.
-   `M-x dap-breakpoint-condition` — turn the breakpoint on the current line
    into a conditional one (Java boolean expression).
-   `M-x dap-breakpoint-log-message` — make a breakpoint log instead of
    pause; useful for temporary tracing without recompiling.
-   `M-x dap-debug-last` — re-run the most recent launch configuration.

Breakpoints persist per project in `.dap-breakpoints`, which is already
gitignored.


### Common failure modes

-   *JDT LS does not start.* Check `*lsp-log*`. If
    `eclipse.jdt.ls/server/` under `~/.emacs.d/` is empty, run
    `M-x lsp-install-server RET jdtls`.
-   *`dap-java-debug-*` cannot find a main class or test.* The project has
    not finished importing. Open a source file, wait for `LSP[jdtls]`, then
    retry.
-   *Stale state after a dependency change.* `M-x lsp-workspace-restart`,
    or `C-c l R`, then re-launch the debug session. If the build file itself
    changed, use `C-c l j u` first to refresh JDT LS project configuration.
-   *External file changes do not appear immediately.* Recursive LSP file
    watchers are disabled to keep Emacs memory bounded. Restart the workspace
    with `C-c l R` after large external changes.
-   *Emacs memory still grows without bound.* Keep `lsp-log-io` off and close
    old project buffers so `lsp-keep-workspace-alive nil` can shut down idle
    servers. If memory still climbs, the next deeper fix is enabling
    `LSP_USE_PLISTS=true` before `lsp-mode` loads and recompiling/reinstalling
    `lsp-mode`.
-   *No completions or diagnostics in a shell buffer.* The two binaries the
    shell stack relies on are not bundled with `lsp-mode` or Flycheck. Install
    with `npm install -g bash-language-server` and `brew install shellcheck`,
    then reopen the buffer (or `M-x lsp-workspace-restart`). `*lsp-log*` will
    name `bash-ls` explicitly when the language server is the missing piece.


# LaTeX

LaTeX support is split across three layers: AUCTeX for editing and
compilation, `preview-latex` (bundled with AUCTeX) for inline math and
figure previews inside the source buffer, and `latexmk` as the build
driver so reruns for cross-references and bibliographies happen
automatically. RefTeX is enabled on top for label, reference, and
citation completion &#x2014; it is built in and integrates with AUCTeX
without extra configuration.

The compiled PDF opens in the OS's default PDF viewer: `Preview.app` on
macOS via `open -a`, and whatever is registered for `application/pdf` on
Linux via `xdg-open` (Evince on GNOME, Okular on KDE, Atril on MATE, etc.).
This avoids the `pdf-tools` build chain (poppler + epdfinfo compile) and
is enough for the edit -> compile -> read -> save workflow. `pdf-tools`
can be turned on later for in-Emacs viewing and bidirectional SyncTeX;
the commented build dependencies below show the exact swap.

Org's PDF export is rerouted through `latexmk` so `C-c C-e l p` in any
`.org` file gets the same robust build behavior as `.tex` files
(handles `\ref`, `\cite`, and TOC reruns automatically).

External binaries: a TeX distribution providing `pdflatex` / `xelatex`
/ `latexmk` is required. Install per platform; the full distribution
(~4 GB) is preferred so missing-package chasing never blocks a build.

    # TeX Live (full distribution + latexmk):
    # macOS, MacPorts:   sudo port install texlive +full
    # macOS, Homebrew:   brew install --cask mactex-no-gui
    # Fedora:            sudo dnf install texlive-scheme-full latexmk
    # Ubuntu / Debian:   sudo apt install texlive-full latexmk
    
    # Optional later: pdf-tools for in-Emacs PDF viewing with SyncTeX.
    # macOS, MacPorts:   sudo port install poppler automake
    # macOS, Homebrew:   brew install poppler automake
    # Fedora:            sudo dnf install poppler-glib-devel automake
    # Ubuntu / Debian:   sudo apt install libpoppler-glib-dev automake
    # Then in Emacs: M-x pdf-tools-install

After installation, the TeX Live `bin` directory must be on the shell
`PATH` that Emacs inherits (via `exec-path-from-shell`, configured in
the Programming section). On macOS the installer adds `/Library/TeX/texbin`
to `/etc/paths.d/`, which login shells pick up automatically. On Linux
the distro package installs into `/usr/bin` so it is already on `PATH`
without extra setup. If `M-x executable-find RET latexmk` returns `nil`
after install, restart the shell (or Emacs) so the new `PATH` entry is
visible.

```emacs-lisp
    (use-package tex
      :ensure auctex
      :hook
      ((LaTeX-mode . turn-on-reftex)
       (LaTeX-mode . LaTeX-math-mode)
       (LaTeX-mode . TeX-source-correlate-mode))
      :custom
      (TeX-auto-save t)
      (TeX-parse-self t)
      (TeX-master nil)
      (TeX-PDF-mode t)
      (TeX-source-correlate-method 'synctex)
      (TeX-source-correlate-start-server t)
      ;; latexmk handles reruns for refs/bib/TOC; auctex-latexmk registers it.
      (TeX-command-default "LatexMk")
      :config
      ;; Open the compiled PDF in the OS's default viewer.
      ;; macOS:        `open -a Preview.app' launches Preview.
      ;; Linux/BSD:    `xdg-open' dispatches to Evince/Okular/Atril/etc.
      ;; To switch to in-Emacs viewing later, install pdf-tools (see shell
      ;; block above) and change the selection to '((output-pdf "PDF Tools")).
      (if (eq system-type 'darwin)
          (setq TeX-view-program-selection '((output-pdf "Preview"))
                TeX-view-program-list      '(("Preview" "open -a Preview.app %o")))
        (setq TeX-view-program-selection '((output-pdf "xdg-open"))
              TeX-view-program-list      '(("xdg-open" "xdg-open %o")))))
    
    (use-package auctex-latexmk
      :ensure t
      :after tex
      :config
      (auctex-latexmk-setup))
    
    (use-package reftex
      :ensure nil
      :custom
      (reftex-plug-into-AUCTeX t)
      (reftex-default-bibliography nil))
    
    ;; Route Org's PDF export through latexmk so cross-refs and citations
    ;; resolve in one C-c C-e l p, matching the AUCTeX build above.
    (with-eval-after-load 'ox-latex
      (setq org-latex-pdf-process
            '("latexmk -pdf -interaction=nonstopmode -output-directory=%o %f")))
```

## Tutorial: Using LaTeX

This tutorial is reachable from anywhere with `C-h T` -> *LaTeX*. It
covers the full edit -> preview -> PDF loop assuming TeX Live and the
Emacs blocks above are already installed.

Open or create a `.tex` file. The mode line should show `LaTeX/P` &#x2014;
that is AUCTeX's `LaTeX-mode` with `TeX-PDF-mode` active. If it shows
plain `LaTeX` without the `/P`, `TeX-PDF-mode` is off and builds will
target DVI; check the `:custom` block above.

Day-to-day workflow inside a `.tex` buffer:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Keys</th>
<th scope="col" class="org-left">Command</th>
<th scope="col" class="org-left">What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left"><code>C-c C-c</code></td>
<td class="org-left"><code>TeX-command-master</code></td>
<td class="org-left">run the default command (LatexMk -&gt; PDF)</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-a</code></td>
<td class="org-left"><code>TeX-command-run-all</code></td>
<td class="org-left">build, then view, in one step</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-v</code></td>
<td class="org-left"><code>TeX-view</code></td>
<td class="org-left">open the compiled PDF (forward SyncTeX)</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-p C-p</code></td>
<td class="org-left"><code>preview-at-point</code></td>
<td class="org-left">inline-render the math/figure at point</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-p C-d</code></td>
<td class="org-left"><code>preview-document</code></td>
<td class="org-left">inline-render every preview in the file</td>
</tr>

<tr>
<td class="org-left"><code>C-c C-p C-c C-p</code></td>
<td class="org-left"><code>preview-clearout-at-point</code></td>
<td class="org-left">remove the inline preview at point</td>
</tr>

<tr>
<td class="org-left"><code>C-c (</code></td>
<td class="org-left"><code>reftex-label</code></td>
<td class="org-left">insert a label</td>
</tr>

<tr>
<td class="org-left"><code>C-c )</code></td>
<td class="org-left"><code>reftex-reference</code></td>
<td class="org-left">pick from existing labels and insert <code>\ref</code></td>
</tr>

<tr>
<td class="org-left"><code>C-c [</code></td>
<td class="org-left"><code>reftex-citation</code></td>
<td class="org-left">pick from .bib entries and insert <code>\cite</code></td>
</tr>

<tr>
<td class="org-left"><code>C-c =</code></td>
<td class="org-left"><code>reftex-toc</code></td>
<td class="org-left">navigable table of contents</td>
</tr>
</tbody>
</table>

**Producing a PDF.** Press `C-c C-c`. AUCTeX prompts with `LatexMk` as
the default command &#x2014; accept with `RET`. The `*compilation*` window
shows latexmk's output; on success, `C-c C-v` opens the resulting PDF
in the OS's default viewer (Preview.app on macOS; whatever GNOME / KDE
/ etc. has registered for `application/pdf` on Linux &#x2014; typically
Evince, Okular, or Atril). The PDF lives next to the `.tex` source (or
under the directory set in a `% !TeX output-directory` magic comment,
if any). Save-a-copy keys differ per app: `Cmd-S` in Preview, `Ctrl-S`
in Evince / Okular / Atril &#x2014; that is "downloading" the PDF.

**Inline previews of math.** Place point inside any math environment
(e.g., between the `$` delimiters of `$x^2 + y^2 = z^2$`) and press
`C-c C-p C-p`. The TeX source is replaced visually by a rendered
image; the source restores itself the moment you edit the underlying
TeX. `C-c C-p C-d` renders every previewable region in the file &#x2014;
useful for skimming a long document. `C-c C-p C-c C-p` removes the
preview at point and goes back to source view explicitly.

**Cross-references and citations via RefTeX.** `C-c (` inserts a label
at the current location (RefTeX picks a sensible prefix like `eq:` or
`sec:` based on context). `C-c )` opens a picker over every label in
the document and inserts the matching `\ref{...}`. `C-c [` opens a
picker over the entries in any `\bibliography` file and inserts
`\cite{...}`. `C-c =` shows a navigable table of contents in a side
buffer.

**Org -> PDF.** Inside any `.org` file, `C-c C-e l p` exports to PDF
using the `org-latex-pdf-process` override above. Same latexmk
invocation as `.tex` builds, so `\ref` / `\cite` / TOC reruns happen
in one shot.


### Common failure modes

-   *`C-c C-c` says "Searching for program&#x2026; No such file or directory,
    latexmk".* The TeX distribution is not on Emacs's `PATH`. Confirm
    with `M-x executable-find RET latexmk`. If `nil`, install per the
    shell block at the top of this section and restart Emacs so
    `exec-path-from-shell` picks up the new `bin` directory
    (`/Library/TeX/texbin` on macOS, `/usr/bin` on Linux when installed
    via the distro package).
-   *Compile fails with "File \`foo.sty' not found".* Unlikely with
    `texlive +full` / `texlive-scheme-full` / `texlive-full`, but if it
    happens, install the specific collection the LaTeX error names
    (`sudo port install texlive-<collection>` on macOS / MacPorts;
    `sudo dnf install texlive-<collection>` on Fedora; `sudo apt install
      texlive-<collection>` on Ubuntu).
-   *SyncTeX forward-search opens the PDF but does not jump to a
    location.* Expected with system viewers &#x2014; Preview.app and most
    Linux PDF readers (Evince, Atril, Okular under default settings)
    don't honour SyncTeX forward-search reliably. Install `pdf-tools`
    and switch `TeX-view-program-selection` to `PDF Tools` for true
    bidirectional SyncTeX.
-   *Inline preview `C-c C-p C-p` renders nothing or a blank box.*
    `preview-latex` shells out to `dvipng` or `gs`. Both ship inside
    `texlive +full`; if previews come up empty, check
    `M-x executable-find RET gs`.

