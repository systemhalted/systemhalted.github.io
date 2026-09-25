# Webcmd

`/webcmd/` is a terminal-style interface to the site archive. Its page source
is `org/pages/webcmd.org`; its maintained command engine is
`publish/templates/webcmd-runtime.js`.

During a build, Emacs prepends three generated values to that runtime:

- `siteDocs`, the searchable post and Emacs-note records;
- `osFortunes`, read from `org/data/os-history.org`;
- `osTimeline`, read from the same Org data file.

The resulting browser asset is `/assets/js/webcmd.js`. Do not edit that file in
`_site/`.

## Commands and shortcuts

`runcmd()` dispatches a line to site navigation, external shortcuts, search
providers, or a function named `cmd_<name>`. Add a corresponding entry to the
`help` object when adding a command.

```js
function cmd_hello(command, argument) {
  output("hello " + (argument || "world"));
}

window.cmd_hello = cmd_hello;
help.hello = "Print a greeting";
```

Use `output()` for normal results, `error()` for failures, and
`webcmdClear()` before a command that replaces the current screen. Keep user
text escaped with `osEscape()` before inserting it as HTML.

The runtime expects `#webcmd-form`, `#line`, `#output`, `#error`, `#help`, and
`#webcmd-help-toggle` in the authored page. Update the runtime and page together
if one of those hooks changes.

Run the publisher ERT suite and browser smoke checks after changing the runtime
or its generated data.
