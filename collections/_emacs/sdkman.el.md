---
layout: emacs
title: sdkman.el - Manage your SDKs without leaving Emacs
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

## What's coming

The current release (0.1.0) handles discovery, environment application, and
the lsp-java layer. The roadmap covers:

**Phase 0**: The next foundation work is to expand the default `sdkman-known-env-vars`
mapping beyond Java, Maven, and Gradle, and to add an async `sdk` CLI runner
that later UI commands can build on.

**Phase 1**: M-x sdkman — a Magit-style transient menu showing the
SDKMAN root, the nearest .sdkmanrc, parsed entries, and installed/current
candidates per SDK; with o to open .sdkmanrc, e to show the active
buffer env, and i to show installed candidates for any SDK.

**Phase 2**: Wire sdk list and sdk current into the transient, running
them asynchronously in a dedicated process buffer.

**Phase 3**: Edit .sdkmanrc from inside Emacs — create one, switch
a project's SDK via completing-read, and have all open project buffers pick up
the new env immediately.

**Phase 4**: Add an explicit LSP restart command so you can switch project
Java and restart JDT LS in one flow.

**Phase 5**: Add the mutating sdk operations — install, uninstall,
default, upgrade, selfupdate — each confirmation-gated before touching
global SDKMAN state.

The package and its phased plan are at https://github.com/systemhalted/sdkman.el.
Feedback and issues welcome.
