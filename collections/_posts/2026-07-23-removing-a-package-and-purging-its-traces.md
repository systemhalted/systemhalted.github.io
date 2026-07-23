---
layout: post
title: "Removing a Package and Purging Its Traces"
date: 2026-07-23 00:30:00 -0500
categories:
- Technology
tags:
- linux
- ubuntu
- debian
- apt
- dpkg
comments: true
description: Removing Ghostty from Ubuntu turned into a walkthrough of the Debian package lifecycle - apt remove, the ii and rc states in dpkg, apt purge, and the per-user files no package manager will clean for you.
---
After [giving up on Ghostty](/2026/07/22/running-ghostty-on-a-2012-gpu/) on
this machine, I uninstalled it. The removal itself is one command, but
checking that it actually happened turned up the parts of the Debian package
lifecycle that are easy to skip past: the difference between removing and
purging, and the package states dpkg reports along the way. This post walks
through it with the real outputs from that removal.

## Finding out how the package was installed

Removal starts with knowing what installed the file you can see:

```
$ which ghostty
/usr/bin/ghostty
$ dpkg -S /usr/bin/ghostty
ghostty: /usr/bin/ghostty
$ apt list --installed 2>/dev/null | grep ghostty
ghostty/now 1.3.1-0~ppa2 amd64 [installed,local]
```

`dpkg -S` maps a file back to the package that owns it, so this is a real
apt/dpkg package, not a manually copied binary or a snap.[^dpkg] The
`[installed,local]` marker says the package is installed but no configured
repository offers it anymore — the PPA it came from is no longer in
`/etc/apt/sources.list.d/`, so apt considers it a local package with no
update source.

Before removing, the package shows in dpkg's database like this:

```
$ dpkg -l ghostty | tail -1
ii  ghostty        1.3.1-0~ppa2 amd64        Fast, feature-rich, and cross-platform terminal emulator.
```

The two letters at the start are the package state. The first letter is the
desired state — what you asked for — and the second is the current state.
`ii` means desired "install", currently "installed": the normal state of an
installed package.[^states]

## Remove

```
$ sudo apt remove ghostty
```

`apt remove` deletes the package's files but keeps its conffiles —
configuration files, typically under `/etc`, that dpkg tracks so your edits
survive upgrades and reinstalls.[^conffiles] Keeping them on removal is
deliberate: if you reinstall the package later, your configuration is still
there.

## Confirm

Two checks. First, the binary is gone:

```
$ which ghostty
$
```

Second, the state in dpkg's database changed:

```
$ dpkg -l ghostty | tail -1
rc  ghostty        1.3.1-0~ppa2 amd64        Fast, feature-rich, and cross-platform terminal emulator.
```

`rc` reads as desired "remove", currently "config-files": the package is
removed, but its conffiles are still on disk and dpkg still has a record of
it.[^states] This is why a removed package keeps appearing in `dpkg -l`
output — the entry is not a leftover installation, just the retained
configuration. `dpkg -L ghostty` lists exactly which files remain.

## Purge

To drop the conffiles and the database record too:

```
$ sudo apt purge ghostty
```

Purge works both on installed packages (it removes and purges in one step)
and on packages already in the `rc` state. Afterward the package is gone from
the database entirely:

```
$ dpkg -l ghostty
dpkg-query: no packages found matching ghostty
```

That is the end state: no files, no conffiles, no record.

If the package pulled in dependencies nothing else uses, `sudo apt
autoremove` clears those as well; apt prints the candidates at the end of the
remove step.

## What the package manager will not clean

Everything above covers only files the package installed. Debian packages do
not write to home directories, so anything the application or you created
there stays after a purge. For Ghostty on this machine that was:

- `~/.config/ghostty/` — the application's own configuration
- `~/.local/share/applications/com.mitchellh.ghostty.desktop` — a user-level
  desktop entry I had added to override the launch command
- an `alias ghostty=...` line in `~/.bashrc` and `~/.zshrc`

The generic checklist after purging a package: its directory under
`~/.config/` and `~/.local/share/`, caches under `~/.cache/`, aliases or
environment variables in shell rc files, and — if you added one for the
package — the repository entry under `/etc/apt/sources.list.d/`.

A final check that nothing is left:

```
$ which ghostty
$ dpkg -l ghostty
dpkg-query: no packages found matching ghostty
$ grep -ri ghostty ~/.bashrc ~/.zshrc ~/.config ~/.local/share/applications
$
```

## References

[^dpkg]: [dpkg(1)](https://man7.org/linux/man-pages/man1/dpkg.1.html) — `-S` (search for a filename in installed packages), `-l` (list packages), `-L` (list a package's files). The listing and searching are done by [dpkg-query(1)](https://man7.org/linux/man-pages/man1/dpkg-query.1.html), which dpkg calls for these options.

[^states]: The state abbreviations are documented in [dpkg(1)](https://man7.org/linux/man-pages/man1/dpkg.1.html) under `-l`: the first character is the desired action (**i**nstall, **r**emove, **p**urge, **h**old), the second the package status (**i**nstalled, **c**onfig-files, **n**ot-installed, and others). `dpkg -l` prints a header decoding both columns.

[^conffiles]: [apt(8)](https://manpages.debian.org/stable/apt/apt.8.en.html) and [apt-get(8)](https://manpages.debian.org/stable/apt/apt-get.8.en.html) define `remove` (keep configuration) versus `purge` (remove everything). Conffile handling — which files qualify and how modified ones are preserved — is Debian Policy, [chapter 10.7](https://www.debian.org/doc/debian-policy/ch-files.html).
