---
layout: post
title: "Switching to WezTerm"
date: 2026-07-22
categories:
- Technology
tags:
- wezterm
- terminal
- linux
- productivity
comments: true
description: I switched to WezTerm on a 2012 ThinkPad T430 because it felt faster than GNOME Terminal and copy-paste was simpler. Benchmarks on the same machine show where that impression holds up, followed by the full Lua setup.
---
I first switched to WezTerm on my old ThinkPad T430, a 2012 laptop with an
i5-3320M and 8&nbsp;GB of RAM. Two things pushed me off GNOME Terminal on that
machine: WezTerm felt a little faster, and copying and pasting took fewer steps.
Before writing this post I went back to the same T430 and measured both claims,
because "felt faster" on a fourteen-year-old laptop is exactly the kind of
impression that can be placebo.

## Was it actually faster?

I ran each test inside a real window of each terminal on the T430 (Ubuntu,
GNOME on Wayland; WezTerm 20240203, GNOME Terminal 3.52 with VTE 0.76), six
runs each, first run discarded as warm-up. The results split cleanly in two.

| Test | WezTerm | GNOME Terminal |
|------|---------|----------------|
| Open a window, run a command, close (overhead) | 0.06–0.09 s | 0.73–0.78 s |
| `cat` a 50 MB text file | 8.0 s | 1.95 s |
| `seq 1 1000000` | 1.33 s | 0.93 s |
| Memory with one window open | ~206 MB | ~50 MB |

The snappiness I remembered is the first row. WezTerm puts a usable window on
screen in under a tenth of a second; GNOME Terminal takes about three quarters
of a second even with its background server process already running. Opening a
terminal is something I do dozens of times a day, so that latency is the speed
you actually feel.

The second and third rows go the other way, and by a wide margin. When a
command floods the screen with output, VTE (the library under GNOME Terminal)
skips rendering frames it can't keep up with, while WezTerm renders more of
them. I checked whether WezTerm's default WebGPU renderer was falling back to
software on the T430's ancient Intel HD 4000 by rerunning with
`front_end = "OpenGL"` — the numbers were the same, so this is just how WezTerm
behaves. It also uses about four times the memory.

So "a little faster" was not placebo, but it needs qualifying: WezTerm is much
faster at the thing I do constantly — opening a terminal — and slower at
dumping bulk output. If your day is `cat`-ing huge logs on old hardware,
GNOME Terminal is the faster terminal. Mine isn't, so WezTerm wins where it
matters to me.

## The copy-paste difference

This one is checkable directly from the default keybindings (`wezterm
show-keys`). In WezTerm, releasing a mouse selection runs
`CompleteSelection(ClipboardAndPrimarySelection)` — the selected text lands in
the system clipboard immediately. Selecting text *is* copying it. Plain
`Ctrl+C` and `Ctrl+V` also work: `Ctrl+C` copies when a selection exists and
sends the interrupt signal when one doesn't.

In GNOME Terminal, a mouse selection only goes to the X primary selection.
Getting it into the clipboard needs an explicit `Ctrl+Shift+C`, and pasting
into the terminal needs `Ctrl+Shift+V`. That extra shifted chord, dozens of
times a day, is the friction I was feeling.

WezTerm adds two keyboard-only tools GNOME Terminal has no equivalent for:
Quick Select (`Ctrl+Shift+Space`) overlays short labels on URLs, paths, and
hashes visible on screen so you can grab one without touching the mouse, and
Copy Mode (`Ctrl+Shift+X`) gives modal, keyboard-driven selection. URLs in
output are clickable with a plain left click.

The rest of this post is the setup I ended up with: a Lua config with
Emacs-style keybindings, workspaces, and per-machine overrides.

## Installation

On Ubuntu and Debian, WezTerm has an apt repository:

```sh
curl -fsSL https://apt.fury.io/wez/gpg.key | \
  sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | \
  sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update && sudo apt install wezterm
```

There is also a Flatpak, and packages for most other distributions are listed
at [wezfurlong.org/wezterm](https://wezfurlong.org/wezterm/installation.html).
On macOS it's `brew install --cask wezterm`; if you install to
`~/Applications` instead of `/Applications`, add
`$HOME/Applications/WezTerm.app/Contents/MacOS` to your PATH so the `wezterm`
CLI works.

## The config file

WezTerm reads `~/.wezterm.lua` (or `~/.config/wezterm/wezterm.lua`). The
config is a Lua program, which means conditionals, loops, and per-machine
logic live in the same file as the settings. Start with the config builder,
which gives better error messages when a key is misspelled:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ... your configuration ...

return config
```

## Fonts and ligatures

Pick a Nerd Font so prompt icons (Starship, Powerlevel10k) render correctly:

```lua
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Medium' })
config.font_size = 14.0

-- Enable ligatures: => becomes →, != becomes ≠
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }
```

Other good Nerd Font options: `FiraCode Nerd Font`, `Hack Nerd Font`,
`CaskaydiaCove Nerd Font`.

## Color scheme

WezTerm ships with hundreds of built-in schemes, so there is no need to paste
hex colors:

```lua
config.color_scheme = 'Catppuccin Mocha'
```

Run `wezterm ls-colors` to list them, or browse the
[color scheme gallery](https://wezfurlong.org/wezterm/colorschemes/index.html).

## Window appearance

```lua
config.window_decorations = 'TITLE | RESIZE'
config.window_background_opacity = 0.92
config.window_padding = {
  left = 12, right = 12, top = 12, bottom = 12,
}
-- macOS only; ignored elsewhere
config.macos_window_background_blur = 20
```

On a machine as old as the T430 I keep the opacity at 1.0 — transparency costs
compositing work for no benefit on a small screen.

## Tab bar

```lua
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 30
```

### Custom tab titles

Show the current directory name instead of the default process title:

```lua
wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local cwd = pane.current_working_dir
  local title = pane.title
  if cwd then
    local path = cwd.file_path or ''
    local folder = path:match('([^/]+)/?$') or title
    title = folder
  end
  if tab.is_active then
    return ' ● ' .. title .. ' '
  end
  return ' ' .. title .. ' '
end)
```

### Status bar

Show the active workspace name and time in the right status area:

```lua
wezterm.on('update-right-status', function(window)
  local workspace = window:active_workspace()
  local time = wezterm.strftime('%H:%M')
  window:set_right_status(wezterm.format({
    { Text = '  ' .. workspace .. '  │  ' .. time .. '  ' },
  }))
end)
```

## Keybindings: leader key, Emacs-style

Instead of memorizing modifier combos, I use a leader key, like tmux's
`Ctrl+b` or Emacs's `C-x`. Press the leader, then a single key.

```lua
local act = wezterm.action
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }
```

After pressing `Ctrl+Space`, you have one second to press the next key.

### Pane management

Modeled after the Emacs window commands (`C-x 2`, `C-x 3`, `C-x 0`, `C-x 1`),
so the muscle memory transfers:

| Shortcut | Action | Emacs equivalent |
|----------|--------|-----------------|
| `Leader 3` | Split horizontal (side by side) | `C-x 3` |
| `Leader 2` | Split vertical (top/bottom) | `C-x 2` |
| `Leader o` | Cycle to next pane | `C-x o` |
| `Leader 0` | Close current pane | `C-x 0` |
| `Leader 1` | Zoom (maximize) current pane | `C-x 1` |
| `Leader ←↓↑→` | Navigate panes by direction | — |

```lua
config.keys = {
  { key = '3', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '2', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'o', mods = 'LEADER', action = act.ActivatePaneDirection 'Next' },
  { key = '0', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = '1', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'LeftArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
}
```

### Tab management

| Shortcut | Action |
|----------|--------|
| `Leader c` | Create new tab |
| `Leader b` | Previous tab |
| `Leader f` | Next tab |
| `Leader k` | Close tab |

```lua
{ key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
{ key = 'b', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
{ key = 'f', mods = 'LEADER', action = act.ActivateTabRelative(1) },
{ key = 'k', mods = 'LEADER', action = act.CloseCurrentTab { confirm = true } },
```

### Resize mode

A modal resize mode where the arrow keys resize panes; `Escape` or `Enter`
exits:

```lua
{ key = 'r', mods = 'LEADER', action = act.ActivateKeyTable {
  name = 'resize_pane', one_shot = false
}},

-- Define the key table
config.key_tables = {
  resize_pane = {
    { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 2 } },
    { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 2 } },
    { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 2 } },
    { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 2 } },
    { key = 'Escape', action = 'PopKeyTable' },
    { key = 'Enter', action = 'PopKeyTable' },
  },
}
```

### Utility shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command palette |
| `Leader v` | Copy/scroll mode |
| `Leader q` | Quick select (URLs, hashes) |

(On macOS the palette is `Cmd+Shift+P`.) The copy mode and quick select
defaults (`Ctrl+Shift+X`, `Ctrl+Shift+Space`) keep working; the leader
bindings are just easier for me to remember.

## Workspaces: project-based context switching

Workspaces are the feature that let WezTerm replace tmux for me. Each
workspace is an isolated set of tabs and panes with its own working directory,
and switching between them swaps the whole window contents.

### Basic workspace commands

| Shortcut | Action |
|----------|--------|
| `Leader w` | Create new named workspace |
| `Leader s` | Switch workspace (fuzzy finder) |
| `Leader d` | Switch to default workspace |

```lua
{ key = 'w', mods = 'LEADER', action = act.PromptInputLine {
  description = 'Enter new workspace name:',
  action = wezterm.action_callback(function(window, pane, line)
    if line then
      window:perform_action(act.SwitchToWorkspace { name = line }, pane)
    end
  end),
}},
{ key = 's', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
{ key = 'd', mods = 'LEADER', action = act.SwitchToWorkspace {
  name = 'default',
  spawn = { cwd = wezterm.home_dir },
}},
```

### Per-machine workspace shortcuts

Hard-coding project paths in a tracked config file is impractical — paths
differ between machines. The fix is a local override file. Create
`~/.wezterm_local.lua` (not version-controlled):

```lua
return {
  workspaces = {
    { key = 'e', name = 'eventing', cwd = '/home/me/Work/eventing-platform' },
    { key = 'p', name = 'personal', cwd = '/home/me/Workspaces/Personal' },
    { key = 'a', name = 'api', cwd = '/home/me/Work/api-gateway' },
  }
}
```

Then load it dynamically from the main config:

```lua
local local_config = {}
local ok, loaded = pcall(dofile, wezterm.home_dir .. '/.wezterm_local.lua')
if ok and loaded then
  local_config = loaded
end

local workspace_defs = local_config.workspaces or {}

-- Dynamically register workspace keybindings
for _, ws in ipairs(workspace_defs) do
  table.insert(config.keys, {
    key = ws.key,
    mods = 'LEADER',
    action = act.SwitchToWorkspace {
      name = ws.name,
      spawn = { cwd = ws.cwd },
    },
  })
end
```

Now `Leader e` jumps to the eventing workspace, `Leader p` to personal, and so
on, with each machine defining its own list.

## Hyperlink rules: clickable Jira tickets and GitHub issues

WezTerm can detect patterns in terminal output and make them clickable:

```lua
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Jira tickets: PROJECT-1234 → opens in Atlassian
table.insert(config.hyperlink_rules, {
  regex = [[\b(MYPROJECT-\d+)\b]],
  format = 'https://myorg.atlassian.net/browse/$1',
})

-- GitHub shorthand: owner/repo#123 → opens the issue/PR
table.insert(config.hyperlink_rules, {
  regex = [[\b([A-Za-z0-9_-]+/[A-Za-z0-9_.-]+)#(\d+)\b]],
  format = 'https://github.com/$1/issues/$2',
})
```

A plain left click follows the link (on macOS it's `Cmd+Click`).

## Per-machine font size

Different monitors need different font sizes. Use the hostname:

```lua
local hostname = wezterm.hostname()
local font_size = 14.0
if hostname:find('work') then
  font_size = 13.0
end
config.font_size = font_size
```

Or put it in `~/.wezterm_local.lua` if you prefer:

```lua
-- ~/.wezterm_local.lua
return {
  font_size = 13.0,
  workspaces = { ... }
}
```

## Managing the config in dotfiles

Keep `wezterm.lua` in your dotfiles repo and symlink it:

```sh
ln -sf ~/path/to/dotfiles/wezterm.lua ~/.wezterm.lua
```

The machine-specific `~/.wezterm_local.lua` stays untracked. Add it to your
dotfiles `.gitignore` if it lives in the same directory:

```gitignore
# Per-machine overrides (never tracked)
*.local.lua
```

This gives you a single tracked config that works on every machine, with local
overrides for paths and preferences that differ.

## Quick reference

| Leader = `Ctrl+Space` | |
|---|---|
| **Panes** | |
| `Leader 2` | Split vertical |
| `Leader 3` | Split horizontal |
| `Leader o` | Next pane |
| `Leader 0` | Close pane |
| `Leader 1` | Zoom pane |
| `Leader r` | Resize mode (arrows, then Esc) |
| **Tabs** | |
| `Leader c` | New tab |
| `Leader b/f` | Prev/next tab |
| `Leader k` | Close tab |
| **Workspaces** | |
| `Leader w` | New workspace |
| `Leader s` | Switch (fuzzy) |
| `Leader d` | Default workspace |
| **Other** | |
| `Leader v` | Copy/scroll mode |
| `Leader q` | Quick select |
| `Ctrl+Shift+P` | Command palette |

## Conclusion

WezTerm replaced tmux, a color scheme plugin, and a hyperlink plugin for me,
all from a single Lua file, and it did it first on hardware where every bit of
responsiveness counts. The benchmarks say the speed I felt is window-open
latency, and that impression survives measurement even though GNOME Terminal
still wins at raw output throughput. Start with the basics — font, theme,
leader key — and layer in workspaces and hyperlink rules as your workflow
asks for them.
