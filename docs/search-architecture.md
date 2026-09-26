# Search architecture

The site search overlay and `/webcmd/` share one generated Elasticlunr index.
`systemhalted--generate-search` exports searchable Org records, strips their
rendered HTML to text, and writes `/assets/js/webcmd.js` during every build.
Only posts and Emacs notes become search documents.

```text
Org records
    ↓ Emacs exporter
siteDocs + ensureSiteIndex()
    ↓
generated assets/js/webcmd.js
    ├── global search overlay
    └── /webcmd/ find command
```

The maintained command runtime is
`publish/templates/webcmd-runtime.js`. Operating-system fortunes and timeline
entries come from `org/data/os-history.org` and are serialized beside the search
documents. The `/webcmd/` page markup is `publish/templates/webcmd.html`.

The public compatibility globals are:

- `window.siteDocs`: searchable records.
- `window.siteStore`: the same records used to display results.
- `window.siteIndex`: the initialized Elasticlunr index.
- `ensureSiteIndex()`: initializes the index when Elasticlunr is available.

`assets/js/script.js` loads Elasticlunr and the generated bundle when the search
overlay first opens. The webcmd page loads them directly and its `find <query>`
command uses the same index. The Webcmd page's bundle URL carries the first 10
hexadecimal characters of a SHA-256 hash of the generated file. A change to the
search corpus, OS-history data, or runtime therefore changes its cache-busting
token. Identical source produces the same token.

Drafts and future posts appear only in preview output. Production search data is
built from the production record set, so hidden content does not leak into the
bundle.

When changing the schema, keep the published compatibility globals stable
because `palakmathur.in` also loads this URL. Run
the ERT suite and the browser smoke test after any search or webcmd change.
