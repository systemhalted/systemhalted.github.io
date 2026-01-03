---
---
/* Webcmd command interface with built-in search index */

// Build siteDocs and search index at load time (includes all output docs across collections).
var siteDocs = [];
{% assign doc_id = 0 %}
{% for coll in site.collections %}
  {% for doc in coll.docs %}
    {% if doc.output != false %}
siteDocs.push({
  id: {{ doc_id }},
  title: {{ doc.title | jsonify }},
  layout: {{ doc.layout | jsonify }},
  content: {{ doc.content | strip_html | jsonify }},
  link: {{ doc.url | relative_url | jsonify }},
  snippet: {{ doc.content | strip_html | truncate: 140 | jsonify }}
});
{% assign doc_id = doc_id | plus: 1 %}
    {% endif %}
{% endfor %}
{% endfor %}

window.siteDocs = siteDocs;
window.siteStore = siteDocs;

if(typeof elasticlunr !== "undefined"){
  var preloadIndex = elasticlunr(function () {
    this.addField('title');
    this.addField('layout');
    this.addField('content');
    this.setRef('id');
  });
  for(var i = 0; i < siteDocs.length; i++){
    var doc = siteDocs[i];
    preloadIndex.addDoc({
      title: doc.title,
      layout: doc.layout,
      content: doc.content,
      id: doc.id
    });
  }
  window.siteIndex = preloadIndex;
}

/* Palak Mathur | In the beginning was a command line */

// Simple shortcuts: name: url.
var navigation = {
    "p":   {{ "/webcmd/" | relative_url | jsonify }},
    "pi":   {{ "/about/" | relative_url | jsonify }},
    "pr":   {{ "/feed.xml" | relative_url | jsonify }},
    "ph":   {{ "/" | relative_url | jsonify }},
    "pgh":   "https://github.com/systemhalted"
}

var shortcuts = {
    
    "m":   "https://mail.google.com/",
    "c":   "https://www.google.com/calendar",
    "r":   "http://reddit.com/",
    "bb":   "http://boingboing.net/",
    "fb":   "http://facebook.com",
    
    "git":   "http://gitref.org/",
    "omscs": "http://omscs.gatech.edu/current-courses",
    "l": "https://library.gatech.edu",
    "n":   "http://netflix.com",
    "q":   "http://www.quora.com"
}

// Search shortcuts: name: [url, cgiparam, {extra cgi}]
var searches = {
    "a":	["http://www.amazon.com/s", "field-keywords",
		 {"url": "search-alias=aps" }],
    "g":	["http://www.google.com/search", "q"],
    "gi":	["http://www.google.com/images", "q"],
    "w":	["http://en.wikipedia.org/wiki/Special:Search", "search"],
    "f":    ["http://www.flipkart.com/search/a/all", "query",
	     {"vertical": "All+Categories", "affid":"palakmathur"}],
    "mdn": ["https://developer.mozilla.org/en-US/search", "q"]

}

// Help text to be displayed for shortcuts & commands.
var help = {
    "p":    "Home Page (this ugly page)",
    "pi":   "About Me",
    "pa":   "Articles",
    "pc":   "Contact",
    "pr":   "RSS Feed",
    "ph":   "Home Page in Normal Mode (not commandline)",
    "pbb":  "Code Repositories on Bitbucket",
    "pgh":  "Code Repositories on Github",
    "a":    "amazon",
    "g":	"google search",
    "gi":	"google image search",
    "cs":	"google code search",
    "mdn": "mdn web docs search",
    "oeis":	"online encyclopedia of integer sequences",
    "m":	"google mail",
    "c":	"google calendar",
    "w":	"wikipedia",
    "e":	"javascript evaluator",
    "l":	"GATech Library",
    "omscs": "GATech OMSCS Courses",
    "f":    "flipkart",
    "cls":  "clear output/errors",
    "find": "search site posts (find <query>)"
    
    
}

// Commands: args are command name, arg text,
// and array of arg text split by white space.
// Commands must be named cmd_foo where
// foo is the actual command name.

// Evaluate an argument.
function cmd_e(cmd, arg, args)
{
    output(arg + " = " + eval(arg));
}

function cmd_cls(cmd, arg, arg)
{
    document.getElementById("error").innerHTML = "" ;
    document.getElementById("output").innerHTML = "";
    document.getElementById("line").focus();
    document.getElementById("line").value = "";
}

function ensureSiteIndex()
{
    if(typeof siteIndex !== "undefined" && typeof siteStore !== "undefined"){
	return true;
    }
    if(typeof elasticlunr === "undefined"){
	error("search unavailable (elasticlunr missing)");
	return false;
    }
    if(typeof siteDocs === "undefined" || !siteDocs.length){
	error("search unavailable (no docs loaded)");
	return false;
    }

    // siteIndex may have been preloaded at the top of this file; if not, build now.
    var idx = elasticlunr(function () {
	this.addField('title');
	this.addField('layout');
	this.addField('content');
	this.setRef('id');
    });
    for(var i = 0; i < siteDocs.length; i++){
	var doc = siteDocs[i];
	idx.addDoc({
	    title: doc.title,
	    layout: doc.layout,
	    content: doc.content,
	    id: doc.id
	});
    }
    window.siteIndex = idx;
    window.siteStore = siteDocs;
    return true;
}

function cmd_find(cmd, arg, args)
{
    if(!arg){
	error("usage: find <query>");
	return;
    }
    // Clear previous output/errors so each search shows fresh results.
    var out = document.getElementById("output");
    var err = document.getElementById("error");
    if(out){ out.innerHTML = ""; }
    if(err){ err.innerHTML = ""; }

    if(!ensureSiteIndex()){
	error("search unavailable (index not loaded)");
	return;
    }

    var results = siteIndex.search(arg, { expand: true });
    // Fallback to manual substring search if lunr index returns nothing.
    if(results.length === 0 && siteStore && siteStore.length){
	var q = arg.toLowerCase();
	for(var j = 0; j < siteStore.length; j++){
	    var d = siteStore[j];
	    var hay = (d.title + " " + d.content).toLowerCase();
	    if(hay.indexOf(q) !== -1){
		results.push({ ref: j });
	    }
	}
    }

    if(results.length === 0){
	output("No results for \"" + arg + "\"");
	return;
    }

    var maxResults = 10;
    for(var i = 0; i < results.length && i < maxResults; i++){
	var ref = results[i].ref;
	var doc = siteStore[ref];
	if(!doc){ continue; }
	var line = (i+1) + ". <a href=\"" + doc.link + "\">" + doc.title + "</a>";
	if(doc.snippet){
	    line += " <span class=\"snippet\">"+ doc.snippet +"</span>";
	}
	output(line);
    }
    if(results.length > maxResults){
	output("...and " + (results.length - maxResults) + " more");
    }
}
// Ensure global reference is enumerable for help listing.
window.cmd_find = cmd_find;

// Build the index as soon as scripts load so find works immediately.
ensureSiteIndex();

/////
///// Below here you should not need to fiddle with.
/////

// Compute help text.
function helptext()
{
    //alert("helptext");
    var a;
    var i = 0;
    var s = "";
    
    s += "<table cellspacing=0 cellpadding=0 border=0>";   
    //alert("1");
    
    a = new Array();
    i = 0;
    for(var k in navigation)
	a[i++] = k;
    //a.sort();
    //alert("2");
    s += "<tr><td colspan=3><b>Site Navigation Commands:</b>";
    
    for(i=0; i<a.length; i++){	  
	var h = help[a[i]];        
	if(h == undefined)
	    h = navigation[a[i]];
	s += "<tr><td><b>" + a[i] + "</b><td width=10><td>" + h + "\n";
    }
    s += "<tr height=10>\n";
    
    a = new Array();
    i = 0;
    for(var k in searches)
	a[i++] = k;
    if(a.indexOf("find") === -1)
        a[i++] = "find";
    a.sort();
    s += "<tr><td colspan=3><b>Searches:</b>";
    for(i=0; i<a.length; i++){	     
	var h = help[a[i]];
	if(h == undefined && searches[a[i]] != undefined)
	    h = searches[a[i]][0];
	if(h == undefined)
            h = "???";
        //alert("a[" + i +"]:" + a[i]);
	s += "<tr><td><b>" + a[i] + "</b><td width=10><td>" + h + "\n";
	
    }
    
    s += "<tr height=10>\n";

    a = new Array();
    i = 0;
    for(var k in shortcuts)
	a[i++] = k;
    a.sort();
    s += "<tr><td colspan=3><b>Shortcuts:</b>";
    for(i=0; i<a.length; i++){
	var h = help[a[i]];
	if(h == undefined)
	    h = shortcuts[a[i]];
	s += "<tr><td><b>" + a[i] + "</b><td width=10><td>" + h + "\n";
    }
    s += "<tr height=10>\n";
    
    a = new Array();
    i = 0;
    for(var k in window)
	if(k.substr(0,4) == "cmd_") {
            var cmdName = k.substr(4);
            if(cmdName === "find") continue;
	    a[i++] = cmdName;
        }
    a.sort();
    s += "<tr><td colspan=3><b>Additional Commands:</b>";
    for(i=0; i<a.length; i++){
	var h = help[a[i]];
	if(h == undefined)
	    h = "???";
	s += "<tr><td><b>" + a[i] + "</b><td width=10><td>" + h + "\n";
    }
    s += "<tr height=10>\n";

    s += "</table>\n";
    
    return s;
}

// Run command.
function runcmd(cmd)
{
    //alert("inside runcmd")
    // Check for URL.
    var space = cmd.indexOf(' ');
    
    if(space == -1 && (cmd.indexOf('/') != -1 || cmd.indexOf('.') != -1)){
	// No spaces, has slash or dot: assume URL.
	if(cmd.indexOf('://') == -1)
	    cmd = "http://" + cmd;
	// window.location = cmd;
	window.open(cmd);
	return false;
    }
    if(space == -1){
	arg = "";
	args = new Array();
    }else{
	arg = cmd.substr(space+1);
	cmd = cmd.substr(0, space);
	args = toarray(arg.split(/\s+/));
    }

    var fn;
    if(searches[cmd] != undefined)
	fn = search;
    else if(shortcuts[cmd] != undefined)
	fn = shortcut;
    else if(navigation[cmd] != undefined)
        fn = navigations;
    else{
	fn = window["cmd_" + cmd];
	if(fn == undefined){
	    error("no command: " + cmd);
	    return false;
	}
    }
    
    fn(cmd, arg, args);
    return false;
}

// Print output on page.
function output(s)
{
    var out = document.getElementById("output");
    if (!out) {
        return;
    }
    out.innerHTML += s + "<br>";
}

// Print error on page.
function error(s)
{
    var err = document.getElementById("error");
    if (!err) {
        return;
    }
    err.innerHTML += s + "<br>";
}

// Convert whatever split returns into an Array.
function toarray(args)
{
    var a = new Array();
    for(var i = 0; i < args.length; i++)
	a[i] = args[i];
    return a;
}

// Return a URL with some CGI args.
function cgiurl(base, params)
{
    var url = base + "?";
    for(var k in params)
	url += k + "=" + escape(params[k]) + "&";
    return url;
}

// Handle search shortcut.
function search(cmd, arg, args)
{
    var a = searches[cmd][2];
    if(a == undefined)
	a = {};
    a[searches[cmd][1]] = arg;
    window.open(cgiurl(searches[cmd][0], a), "_blank");
    //window.location = cgiurl(searches[cmd][0], a);
}

// Handle simple shortcut.
function shortcut(cmd, arg, args)
{
    window.open(shortcuts[cmd], "_blank");
    // window.location = shortcuts[cmd];
}

function navigations(cmd, arg, args)
{
    window.location = navigation[cmd];
}

if (typeof window.jQuery !== "undefined") {
    window.jQuery(function($) {
        if (document.getElementById("output")) {
            $('a').attr('target', '_blank');
        }
    });
}

// Wire up the webcmd UI when present.
(function() {
    function initWebcmdUI() {
        var form = document.getElementById("webcmd-form");
        var input = document.getElementById("line");
        var helpPanel = document.getElementById("help");
        var helpToggle = document.getElementById("webcmd-help-toggle");
        var errorBox = document.getElementById("error");

        if (!form || !input) {
            return;
        }

        if (helpPanel && typeof helptext === "function") {
            helpPanel.innerHTML = helptext();
        }

        if (helpToggle && helpPanel) {
            helpToggle.addEventListener("click", function() {
                var isOpen = !helpPanel.hasAttribute("hidden");
                if (isOpen) {
                    helpPanel.setAttribute("hidden", "");
                    helpToggle.setAttribute("aria-expanded", "false");
                    helpToggle.textContent = "Show commands";
                } else {
                    helpPanel.removeAttribute("hidden");
                    helpToggle.setAttribute("aria-expanded", "true");
                    helpToggle.textContent = "Hide commands";
                }
            });
        }

        form.addEventListener("submit", function(event) {
            event.preventDefault();
            if (typeof runcmd === "function") {
                runcmd(input.value);
            } else if (errorBox) {
                errorBox.textContent = "Command engine not available. Try reloading the page.";
            }
        });

        input.focus();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initWebcmdUI);
    } else {
        initWebcmdUI();
    }
})();
