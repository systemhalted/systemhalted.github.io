/* Command-line interface for /webcmd/. Generated search and history data are
   written above this runtime by the Emacs publisher. */

var navigation = {
  p: "/webcmd/",
  pi: "/about/",
  pr: "/feed.xml",
  ph: "/",
  pgh: "https://github.com/systemhalted"
};

var shortcuts = {
  m: "https://mail.google.com/",
  c: "https://calendar.google.com/",
  w: "https://en.wikipedia.org/"
};

var searches = {
  a: ["https://www.amazon.com/s", "field-keywords", { url: "search-alias=aps" }],
  g: ["https://www.google.com/search", "q"],
  gi: ["https://www.google.com/images", "q"],
  w: ["https://en.wikipedia.org/wiki/Special:Search", "search"],
  mdn: ["https://developer.mozilla.org/en-US/search", "q"]
};

var help = {
  p: "Home page (command line)",
  pi: "About",
  pr: "RSS feed",
  ph: "Home page",
  pgh: "GitHub profile",
  a: "Amazon search",
  g: "Google search",
  gi: "Google image search",
  w: "Wikipedia search",
  mdn: "MDN Web Docs search",
  m: "Google Mail",
  c: "Google Calendar",
  e: "JavaScript evaluator",
  cls: "Clear output",
  find: "Search site posts: find <query>",
  fortune: "A random line of OS history",
  history: "A short history of operating systems",
  uname: "System banner",
  halt: "Halt the system",
  bsod: "Alias for halt",
  crt: "Toggle the phosphor CRT theme"
};

function output(value) {
  var target = document.getElementById("output");
  if (target) target.insertAdjacentHTML("beforeend", value + "<br>");
}

function error(value) {
  var target = document.getElementById("error");
  if (target) target.insertAdjacentHTML("beforeend", value + "<br>");
}

function webcmdClear() {
  var outputTarget = document.getElementById("output");
  var errorTarget = document.getElementById("error");
  if (outputTarget) outputTarget.textContent = "";
  if (errorTarget) errorTarget.textContent = "";
}

function osEscape(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function cmd_e(command, argument) {
  output(osEscape(argument) + " = " + osEscape(eval(argument)));
}

function cmd_cls() {
  webcmdClear();
  var input = document.getElementById("line");
  if (input) {
    input.value = "";
    input.focus();
  }
}

function cmd_find(command, argument) {
  webcmdClear();
  if (!argument) {
    error("usage: find &lt;query&gt;");
    return;
  }
  if (!ensureSiteIndex()) {
    error("search unavailable");
    return;
  }
  var results = window.siteIndex.search(argument, { expand: true });
  if (!results.length) {
    var query = argument.toLowerCase();
    results = window.siteStore
      .filter(function(doc) {
        return [doc.title, doc.categories, doc.tags, doc.content]
          .join(" ").toLowerCase().indexOf(query) !== -1;
      })
      .map(function(doc) { return { ref: doc.id }; });
  }
  if (!results.length) {
    output("No results for &quot;" + osEscape(argument) + "&quot;");
    return;
  }
  results.slice(0, 10).forEach(function(result, index) {
    var doc = window.siteStore[result.ref];
    if (!doc) return;
    output((index + 1) + ". <a href=\"" + doc.link + "\">" +
      osEscape(doc.title) + "</a> <span class=\"snippet\">" +
      osEscape(doc.snippet || "") + "</span>");
  });
}

function cmd_fortune() {
  webcmdClear();
  if (!osFortunes.length) {
    output("(no fortunes loaded)");
    return;
  }
  output("<span class=\"webcmd-fortune\">" +
    osEscape(osFortunes[Math.floor(Math.random() * osFortunes.length)]) +
    "</span>");
}

function cmd_history() {
  webcmdClear();
  var lines = ["A very short history of operating systems:", ""];
  osTimeline.forEach(function(row) {
    lines.push(row.year + "  —  " + row.event);
  });
  output("<pre class=\"webcmd-pre\">" + osEscape(lines.join("\n")) + "</pre>");
}

function cmd_uname() {
  webcmdClear();
  output("<pre class=\"webcmd-pre\">" + osEscape([
    "SystemHalted DOS 1.0 (i am just a DOS error)",
    "kernel: nostalgia " + new Date().getFullYear() + " #1 RETRO",
    "machine: x86 real-mode dreams",
    "uptime: since 1969",
    "status: HALTED, with affection"
  ].join("\n")) + "</pre>");
}

function cmd_halt() {
  webcmdClear();
  output("<pre class=\"webcmd-pre webcmd-halt\">" + osEscape([
    "*** SYSTEM HALTED ***", "",
    "A problem has been detected and the daydream has been",
    "shut down to prevent damage to your productivity.", "",
    "    THE_INTERNET_IS_TOO_INTERESTING"
  ].join("\n")) + "</pre>");
}

function cmd_bsod() { cmd_halt(); }

function cmd_crt() {
  webcmdClear();
  if (typeof window.__toggleCRT === "function") {
    output("CRT mode " + (window.__toggleCRT() ? "engaged." : "disengaged."));
  } else {
    error("CRT mode unavailable on this page.");
  }
}

Object.assign(window, {
  cmd_e: cmd_e,
  cmd_cls: cmd_cls,
  cmd_find: cmd_find,
  cmd_fortune: cmd_fortune,
  cmd_history: cmd_history,
  cmd_uname: cmd_uname,
  cmd_halt: cmd_halt,
  cmd_bsod: cmd_bsod,
  cmd_crt: cmd_crt
});

function cgiurl(base, parameters) {
  var query = new URLSearchParams(parameters);
  return base + "?" + query.toString();
}

function helptext() {
  var commands = Object.keys(help).sort();
  return "<div class=\"webcmd-help-block\"><div class=\"webcmd-help-heading\">Commands</div>" +
    "<ul class=\"webcmd-help-list\">" + commands.map(function(command) {
      return "<li><span class=\"webcmd-help-key\">" + command +
        "</span><span class=\"webcmd-help-desc\">" + help[command] + "</span></li>";
    }).join("") + "</ul></div>";
}

function runcmd(line) {
  var value = line.trim();
  if (!value) return false;
  var parts = value.split(/\s+/);
  var command = parts.shift();
  var argument = parts.join(" ");
  if (!argument && (command.indexOf("/") !== -1 || command.indexOf(".") !== -1)) {
    window.open(command.indexOf("://") === -1 ? "https://" + command : command);
  } else if (navigation[command]) {
    window.location = navigation[command];
  } else if (shortcuts[command]) {
    window.open(shortcuts[command], "_blank");
  } else if (searches[command]) {
    var definition = searches[command];
    var parameters = Object.assign({}, definition[2] || {});
    parameters[definition[1]] = argument;
    window.open(cgiurl(definition[0], parameters), "_blank");
  } else if (typeof window["cmd_" + command] === "function") {
    window["cmd_" + command](command, argument, parts);
  } else {
    error("no command: " + osEscape(command));
  }
  return false;
}

(function initializeWebcmd() {
  function initialize() {
    var form = document.getElementById("webcmd-form");
    var input = document.getElementById("line");
    var helpPanel = document.getElementById("help");
    var helpToggle = document.getElementById("webcmd-help-toggle");
    if (!form || !input) return;
    if (helpPanel) helpPanel.innerHTML = helptext();
    if (helpToggle && helpPanel) {
      helpToggle.addEventListener("click", function() {
        var open = !helpPanel.hasAttribute("hidden");
        helpPanel.toggleAttribute("hidden", open);
        helpToggle.setAttribute("aria-expanded", String(!open));
        helpToggle.textContent = open ? "Show commands" : "Hide commands";
      });
    }
    form.addEventListener("submit", function(event) {
      event.preventDefault();
      runcmd(input.value);
    });
    input.focus();
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
}());
