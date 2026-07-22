---
layout: emacs
title: sdkman.el - Manage your SDKs without leaving Emacs
description: Use project SDKMAN toolchains in Emacs buffers, subprocesses, and Java language servers.
tags: [emacs, gnu emacs]
category: [emacs]
---

If you use SDKMAN! to manage JVM toolchains and run Emacs from a desktop
launcher or a Wayland session, you've probably hit this: `M-x compile` picks
up the system Java, not the one `.sdkmanrc` says the project uses. 

The root cause is that GUI Emacs doesn't source your shell's init files, so
the `sdk env` behavior that auto-applies `.sdkmanrc` in an interactive
terminal never runs. SDKMAN! sets up a shell function and not a binary, so
there's nothing on `PATH` to find.

`sdkman.el` solves this by reading `.sdkmanrc` directly and applying the
project's SDK selection to Emacs buffer-local environments. No shell init
required.

## What it does

When you visit any file in a project that has a `.sdkmanrc` (or any ancestor
directory does), `global-sdkman-mode` activates `sdkman-mode` in that buffer.

The mode:

- Locates the nearest `.sdkmanrc` by walking up the directory tree.
- Parses it into an alist of `(sdk . candidate)` pairs.
- For each candidate, resolves the installed directory under
  `~/.sdkman/candidates/<sdk>/<candidate>/`.
- Prepends that candidate's `bin/` to buffer-local `exec-path` and `PATH`.
- Sets `JAVA_HOME`, `MAVEN_HOME`, or `GRADLE_HOME` for the three SDKs in the
  default mapping.

This is all buffer-local. Other buffers keep whatever environment they had. A
project using Java 21 and a project using Java 26 can both be open at once and
each gets its own `exec-path`.

The important split is between command lookup and home variables. For every
installed SDK named in `.sdkmanrc`, `sdkman.el` prepends that candidate's
`bin/` directory to the current buffer's `exec-path` and `PATH`. That means
Emacs subprocesses can find `java`, `mvn`, `gradle`, `scala`, `kotlinc`, `sbt`,
`ant`, `groovy`, `jbang`, or any other executable shipped by a SDKMAN
candidate.

Dedicated home variables are separate. By default, `sdkman.el` knows three
SDK-to-variable mappings:

- `java` sets `JAVA_HOME`
- `maven` sets `MAVEN_HOME`
- `gradle` sets `GRADLE_HOME`

If another SDK needs a conventional home variable, extend
`sdkman-known-env-vars`:

```elisp
(setq sdkman-known-env-vars
      (append sdkman-known-env-vars
              '(("scala"  . "SCALA_HOME")
                ("kotlin" . "KOTLIN_HOME"))))
```

### lsp-java integration

When a project's `.sdkmanrc` contains a `java=<candidate>` entry and
`lsp-java` is installed, `sdkman-mode` also:

- Points `lsp-java-java-path` at the project JDK's bin/java.
- Seeds `lsp-java-configuration-runtimes` with a JavaSE-N runtime derived
  from the candidate version (26-tem → JavaSE-26).

JDT LS launches with the project JDK. This works because global-sdkman-mode
fires before lsp-deferred actually starts the server, so the buffer-local
vars are in place when JDT LS reads them.

`lsp-java` is optional — the package doesn't require it and loads cleanly
without it.

### Transient menu

Version 0.2.0 adds a read-only `M-x sdkman` menu. Its header shows the SDKMAN
root, the nearest `.sdkmanrc`, and whether each configured candidate is
installed and current.

- `o` opens the nearest `.sdkmanrc`.
- `e` shows the environment applied to the current buffer.
- `i` lists installed candidates for a selected SDK.
- `q` closes the menu.

### Install

The package isn't on MELPA yet. Clone the repo and load it locally.

With use-package and a local path:

```elisp
(use-package sdkman
  :load-path "/path/to/sdkman.el/"
  :init
  (global-sdkman-mode 1))
```

With straight.el:

```elisp
(use-package sdkman
  :straight (sdkman :type git :host github :repo "systemhalted/sdkman.el")
  :init
  (global-sdkman-mode 1))
```

Requires Emacs 27.1+. No other dependencies.

## Current status and roadmap

Version 0.2.0 includes project discovery, buffer-local environment application,
the `lsp-java` integration, and the read-only transient menu. The remaining
V1 work focuses on:

- Creating and editing `.sdkmanrc` files from inside Emacs, then reapplying
  the environment to affected project buffers.
- Running `sdk list`, `sdk current`, and later install or maintenance
  operations asynchronously in a dedicated process buffer.
- Adding an explicit command that applies the selected Java runtime and
  restarts the current language server.
- Confirmation-gating mutating SDKMAN operations such as install, uninstall,
  default, upgrade, and selfupdate.

The package, complete roadmap, and issue tracker are at
https://github.com/systemhalted/sdkman.el. Feedback and issues are welcome.
