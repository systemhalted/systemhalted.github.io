# Webcmd Guide

The webcmd page is a terminal-style UI at `/webcmd/`. It shares the site's theme, uses the default layout, and runs a lightweight command engine written in `assets/js/webcmd.js`. The interface is inspired by [RSC](http://swtch.com/~rsc/) and [Greg Travis](http://www.devx.com/webdev/Article/33577?trk=DXRSS_LATEST).

## How webcmd works
- Page markup: `webcmd/index.html` renders the command input, output, error, and help containers.
- Command engine: `assets/js/webcmd.js` parses input, runs commands, and renders output.
- Styling: `assets/css/nord.css` provides the themed UI styles under the `webcmd` section.
- Layout: `_layouts/default.html` includes the JS bundle so the command engine is available on `/webcmd/`.

### Data flow
1. The input form in `webcmd/index.html` submits a command string.
2. `assets/js/webcmd.js` intercepts the submit and calls `runcmd()`.
3. `runcmd()` dispatches to:
  - `searches` (search shortcuts),
  - `shortcuts` (simple URL shortcuts),
  - `navigation` (site navigation shortcuts), or
  - a function named `cmd_<name>`.
4. `output()` and `error()` print results into `#output` and `#error`.
5. `helptext()` builds the help table shown in `#help`.

## Adding a new command
Add a new function named `cmd_<name>` in `assets/js/webcmd.js`, then add a help entry so it appears in the help panel.

Example:
```js
  function cmd_hello(cmd, arg, args)
  {
      var name = arg || "world";
      output("hello " + name);
  }

  help["hello"] = "print a greeting";
```

Notes:
- `cmd`, `arg`, and `args` are passed by `runcmd()`. `arg` is the raw argument string; `args` is the split array.
- Use `output()` for normal output and `error()` for errors.
- To clear output, use `cmd_cls()` or call `document.getElementById("output").innerHTML = "";`.

## Adding or changing shortcuts
There are three shortcut maps near the top of `assets/js/webcmd.js`:
- `navigation`: site routes (opens in the same tab).
- `shortcuts`: external URLs (opens in a new tab).
- `searches`: search providers (builds a query URL and opens in a new tab).

Each shortcut should have a matching entry in the `help` map if you want it listed in the help panel.

## Help panel behavior
`helptext()` builds the help panel from:
- `navigation`, `searches`, and `shortcuts`, plus
- every function with a `cmd_` prefix found on `window`.

If a command does not appear, add a line to the `help` map:
```js
  help["yourcmd"] = "short description";
```

## Required IDs and hooks
The command engine expects these IDs to exist in `webcmd/index.html`:
- `#webcmd-form` (form that wraps the input)
- `#line` (text input)
- `#output` (command output)
- `#error` (error output)
- `#help` (help panel)
- `#webcmd-help-toggle` (help toggle button)

If you rename any of these, update the selectors in `assets/js/webcmd.js`.
