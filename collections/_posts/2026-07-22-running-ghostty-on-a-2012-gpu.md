---
layout: post
title: "Running Ghostty on a 2012 GPU"
date: 2026-07-22
categories:
- Technology
tags:
- ghostty
- emacs
- terminal
- linux
comments: true
description: I tried Ghostty after ghostel.el made coding agents usable inside Emacs. On my ThinkPad T430's Ivy Bridge GPU it would not open — Mesa stops at OpenGL 4.2 and Ghostty needs 4.3. The debugging steps, a look at Mesa's drivers, and why I removed it.
---
I tried Ghostty because of
[ghostel.el](https://github.com/dakra/ghostel), a terminal emulator for Emacs
powered by libghostty-vt, the VT engine extracted from the
[Ghostty](https://ghostty.org) terminal.

## Why I was trying ghostel in the first place

I run coding agents like Claude Code and OpenCode from the terminal, and I
live in Emacs, so the obvious move is to run them in eshell. That does not
work.

Eshell is not a terminal emulator. It is a shell written in Emacs Lisp that
runs a command and inserts its output into a buffer. Modern coding agents are
full-screen TUI applications — Claude Code, for instance, is built on Ink, a
React renderer for the terminal.[^ink] Programs like that assume a real
terminal: a PTY, raw-mode keyboard input, ANSI cursor addressing, the
alternate screen buffer, and a constant stream of escape sequences repainting
the screen many times a second.[^terminal]

Eshell provides almost none of that. It interprets basic color codes through
`ansi-color` and little else; it advertises `TERM=dumb`; its input model is
line-oriented, so the agent never sees individual keystrokes; and there is no
cursor positioning or alternate screen. So the agent's UI arrives as garbled
escape sequences, redraws pile up in the buffer instead of replacing each
other, and interactive prompts do not respond to keys. Eshell's escape hatch
for this — listing the program in `eshell-visual-commands` so it runs under
`term.el` — helps, but term.el is slow and its emulation is incomplete enough
that the agents still misrender.[^eshell]

Ghostel fixes this the same way vterm does: by embedding a real VT engine.
A native module (written in Zig) links libghostty-vt and handles terminal
state, rendering, and PTY I/O, while Elisp handles buffers and keymaps — the
same two-layer design as emacs-libvterm, but with Ghostty's engine instead of
libvterm. That brings the Kitty keyboard protocol, synchronized output
(DEC 2026), and OSC 8 hyperlinks, none of which libvterm supports.[^protocols] Claude Code
and OpenCode render and respond correctly inside it.

Ghostel only needs libghostty-vt, not the Ghostty application. But using it
made me curious about the terminal itself, so I installed Ghostty on my
ThinkPad T430 — the same 2012 machine from my
[WezTerm post](/2026/07/22/wezterm-setup/).

## It would not open

Launching Ghostty from the desktop, the window flashed and closed. Running
`ghostty` from a terminal showed why:

```
info: ghostty version=1.3.1
info(gtk): GTK version build=4.14.5 runtime=4.14.5
info(opengl): loaded OpenGL 4.2
warning(opengl): OpenGL version is too old. Ghostty requires OpenGL 4.3
warning(gtk_ghostty_surface): failed to initialize surface err=error.OpenGLOutdated
warning(gtk_ghostty_surface): surface failed to initialize err=error.SurfaceError
```

The system provides OpenGL 4.2; Ghostty's renderer requires 4.3. The desktop
launch fails the same way — there is just no terminal attached to show the
log, so the window appears and dies.

I checked which GPU this machine has. `glxinfo` was not installed, but
`lspci` was enough:

```
$ lspci -nn | grep -Ei 'vga|3d'
00:02.0 VGA compatible controller [0300]: Intel Corporation 3rd Gen Core processor Graphics Controller [8086:0166] (rev 09)
```

That is the Intel HD 4000, the integrated GPU on Ivy Bridge, the third
generation of Core processors, released in 2012.[^hd4000]

## Mesa's drivers

On Linux, OpenGL is implemented by Mesa: one userspace project containing many
hardware drivers, with the right one selected at runtime for the GPU present.
This machine runs Mesa 25.2.8 on Ubuntu 24.04.

Intel GPUs are split across three Mesa drivers by hardware generation:
`i915` covers gen2–3, `crocus` covers gen4–7 (it replaced the older
`i965` driver), and `iris` covers gen8 (Broadwell)
and newer. Ivy Bridge is gen7, so it is served by crocus —
`crocus_dri.so` sits in `/usr/lib/x86_64-linux-gnu/dri/` on this
machine.[^mesa-drivers]

Crocus exposes at most OpenGL 4.2 on Ivy Bridge, and GLSL 4.20 to match.
GLSL is the language shaders are written in — shaders being the small
programs a renderer runs on the GPU — and its version tracks OpenGL's.
OpenGL 4.3 is an umbrella over a bundle of features — compute shaders
(GPU programs for general computation rather than drawing), shader storage
buffer objects (blocks of GPU memory those programs can read and write), and
others — and this generation never got the complete set.[^gl43] Haswell,
one generation later, gets OpenGL 4.6. The ceiling is per GPU generation
inside the driver, so no Mesa upgrade will move it.

Mesa also ships software rasterizers — renderers that do all of the GPU's
drawing work on the CPU instead. The main one is `llvmpipe`, which uses LLVM
to generate fast machine code at runtime and implements
OpenGL 4.5.[^llvmpipe] That becomes relevant below.

## Advertising a version the hardware does not have

The version an application sees comes from Mesa: `glGetString(GL_VERSION)`
and `glGetIntegerv(GL_MAJOR_VERSION, ...)` on the context it created. Mesa
has an environment variable, `MESA_GL_VERSION_OVERRIDE`, that makes it report
a different version than the driver's real one — `4.3FC` means version 4.3,
forward-compatible core profile, the variant of OpenGL with the old
deprecated functions removed. It enables no functionality; it only changes
the advertised number. The variable exists because hardware sometimes supports
every extension an application actually uses while the driver stops short of
exposing the version umbrella, and an application that only gates on the
number will then run fine.[^envvars]

```
$ MESA_GL_VERSION_OVERRIDE=4.3FC ghostty
info(opengl): loaded OpenGL 4.3
error(opengl): shader compilation failure id=2 message=0:1(10): error:
  GLSL 4.30 is not supported. Supported versions are: 1.10, 1.20, 1.30,
  1.40, 1.50, 3.30, 4.00, 4.10, 4.20, 1.00 ES, and 3.00 ES
warning(gtk_ghostty_surface): failed to initialize surface err=error.CompileFailed
```

In order: Ghostty's version check now passes ("loaded OpenGL 4.3"). It
proceeds to compile its shaders, which begin with `#version 430`. Mesa's GLSL
compiler, which still truthfully supports only up to 4.20 on this driver,
rejects the directive. Surface initialization fails with `CompileFailed`
instead of `OpenGLOutdated`. GTK's own GSK renderer printed the same GLSL
errors once the context claimed 4.3.

There is a companion variable, `MESA_GLSL_VERSION_OVERRIDE`, that would make
the compiler accept a `#version 430` directive too — but it also adds no
functionality, so it would only move the failure into whichever 4.30 features
the shaders actually use. The override moved the failure from the version
check into the compiler, which settles the question: the limit is in the
driver and hardware, not in Ghostty being overly strict.

## Software rendering works

Mesa's llvmpipe implements OpenGL 4.5, comfortably above Ghostty's
requirement:

```
$ LIBGL_ALWAYS_SOFTWARE=1 ghostty
info(opengl): loaded OpenGL 4.5
```

The surface initializes, the window opens, and Ghostty runs normally. Making
this permanent takes two small changes: a user-level desktop entry at
`~/.local/share/applications/com.mitchellh.ghostty.desktop` that overrides
the system one with

```
Exec=env LIBGL_ALWAYS_SOFTWARE=1 /usr/bin/ghostty --gtk-single-instance=true
```

and a shell alias for terminal launches:

```sh
alias ghostty="LIBGL_ALWAYS_SOFTWARE=1 ghostty"
```

Both work. But every frame is now rendered by the CPU.

## Removing it

Ghostty's selling points are its GPU renderer and the platform-native UI. On
this machine the first one is gone — llvmpipe on an i5-3320M is functional but
it is the opposite of what the terminal is designed around. I already use
WezTerm, which runs hardware-accelerated on this same GPU (its OpenGL
front end targets a version Ivy Bridge can provide), and I documented that
setup [earlier today](/2026/07/22/wezterm-setup/). Running Ghostty in
software-rendering mode gives me nothing WezTerm does not already do better
here, so I uninstalled it and removed the desktop override and the alias.

Ghostel is unaffected by this. It links libghostty-vt directly and renders
through Emacs, so it does not depend on the GPU. The part of Ghostty I
actually needed — its terminal emulation — runs fine on this laptop, and I
will keep using it through ghostel.

## References

[^ink]: [Ink](https://github.com/vadimdemedes/ink), a React renderer for the terminal; its README lists Claude Code among the projects built on it.

[^terminal]: There is no single document that defines "a real terminal"; the pieces are specified separately. Pseudoterminals: [pty(7)](https://man7.org/linux/man-pages/man7/pty.7.html). Raw versus canonical input: [termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html). Cursor addressing and the other control functions: [ECMA-48](https://ecma-international.org/publications-and-standards/standards/ecma-48/) (the standard behind "ANSI escape sequences"). The de facto extensions terminals actually implement, including the alternate screen buffer (modes 1047/1049): [XTerm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html). Linus Åkesson's ["The TTY demystified"](https://www.linusakesson.net/programming/tty/) explains how these fit together.

[^eshell]: GNU Emacs manual, [Eshell](https://www.gnu.org/software/emacs/manual/html_mono/eshell.html) — see the Input/Output and Visual Commands sections for the `TERM` handling and the `eshell-visual-commands` mechanism.

[^protocols]: [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/); [synchronized output (DEC mode 2026)](https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036); [OSC 8 hyperlinks](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda).

[^hd4000]: The identification comes from the PCI ID in brackets. `lspci` prints the device name from the PCI ID database, where vendor `8086` is Intel and device `0166` is the ["3rd Gen Core processor Graphics Controller"](https://pci-ids.ucw.cz/read/PC/8086/0166) — the third Core generation is Ivy Bridge, launched in 2012. The marketing name is in Mesa's driver table, [`crocus_pci_ids.h`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/include/pci_ids/crocus_pci_ids.h), which maps `0x0166` to `ivb_gt2, "Intel(R) HD Graphics 4000"`. The CPU agrees: this machine's i5-3320M ships with HD Graphics 4000.

[^mesa-drivers]: [Mesa documentation](https://docs.mesa3d.org/) for the driver architecture; [mesamatrix.net](https://mesamatrix.net/) tracks which OpenGL version each Mesa driver supports.

[^gl43]: [OpenGL 4.3 core specification](https://registry.khronos.org/OpenGL/specs/gl/glspec43.core.pdf) (PDF), Khronos registry — its change-log appendix lists the features new in 4.3 (2012), including compute shaders and shader storage buffer objects.

[^envvars]: Mesa documentation, [Environment Variables](https://docs.mesa3d.org/envvars.html) — documents `MESA_GL_VERSION_OVERRIDE`, the `FC` suffix, and `MESA_GLSL_VERSION_OVERRIDE`.

[^llvmpipe]: Mesa documentation, [llvmpipe](https://docs.mesa3d.org/drivers/llvmpipe.html).
