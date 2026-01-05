(function(document) {
  var toggle = document.querySelector('.sidebar-toggle');
  var sidebar = document.querySelector('#sidebar');
  var checkbox = document.querySelector('#sidebar-checkbox');
  var annotateToggle = document.querySelector('#annotate-toggle');

  if (!toggle || !sidebar || !checkbox) return;

  function setExpandedState() {
    toggle.setAttribute('aria-expanded', checkbox.checked ? 'true' : 'false');
  }

  document.addEventListener('click', function(e) {
    var target = e.target;

    if(!checkbox.checked ||
       sidebar.contains(target) ||
       (target === checkbox || target === toggle)) return;

    checkbox.checked = false;
    setExpandedState();
  }, false);

  checkbox.addEventListener('change', function() {
    setExpandedState();
  });

  toggle.addEventListener('keydown', function(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      checkbox.checked = !checkbox.checked;
      setExpandedState();
    }
  });

  setExpandedState();

  if (annotateToggle) {
    annotateToggle.addEventListener('click', function() {
      if (document.getElementById('hypothesis-script')) return;
      var script = document.createElement('script');
      script.src = 'https://hypothes.is/embed.js';
      script.id = 'hypothesis-script';
      document.head.appendChild(script);
    });
  }
})(document);

(function(document) {
  var root = document.documentElement;
  var toggle = document.querySelector('#theme-toggle');

  if (!toggle) return;

  var storageKey = 'theme';
  var lightClass = 'theme-nord-light';
  var darkClass = 'theme-nord-dark';
  var label = toggle.querySelector('.theme-toggle-label');
  var mediaQuery = null;
  var storedTheme = null;

  function normalizeTheme(value) {
    return value === 'dark' || value === 'light' ? value : null;
  }

  function getStoredTheme() {
    try {
      return normalizeTheme(localStorage.getItem(storageKey));
    } catch (e) {
      return null;
    }
  }

  function getPreferredTheme() {
    try {
      return mediaQuery && mediaQuery.matches ? 'dark' : 'light';
    } catch (e) {
      return 'light';
    }
  }

  function updateToggle(theme) {
    var isDark = theme === 'dark';
    toggle.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    toggle.setAttribute('aria-label', isDark ? 'Switch to light mode' : 'Switch to dark mode');
    toggle.setAttribute('title', isDark ? 'Switch to light mode' : 'Switch to dark mode');
    if (label) {
      label.textContent = isDark ? 'Light mode' : 'Dark mode';
    }
  }

  function applyTheme(theme, persist) {
    root.classList.remove(lightClass, darkClass);
    root.classList.add(theme === 'dark' ? darkClass : lightClass);

    if (persist) {
      storedTheme = theme;
      try {
        localStorage.setItem(storageKey, theme);
      } catch (e) {
      }
    }

    updateToggle(theme);
  }

  if (window.matchMedia) {
    mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
  }

  storedTheme = getStoredTheme();
  var initialTheme = storedTheme || getPreferredTheme();
  applyTheme(initialTheme, false);

  if (mediaQuery) {
    var handleSystemChange = function(event) {
      if (storedTheme) return;
      applyTheme(event.matches ? 'dark' : 'light', false);
    };

    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', handleSystemChange);
    } else if (mediaQuery.addListener) {
      mediaQuery.addListener(handleSystemChange);
    }
  }

  toggle.addEventListener('click', function() {
    var nextTheme = root.classList.contains(darkClass) ? 'light' : 'dark';
    applyTheme(nextTheme, true);
  });
})(document);

(function(document) {
  var container = document.querySelector('#archive-years');
  var sortSelect = document.querySelector('#archive-sort');

  if (!container || !sortSelect) return;

  var sections = Array.prototype.slice.call(container.querySelectorAll('.archive-year'));

  function sortSections(mode) {
    var sorted = sections.slice().sort(function(a, b) {
      var yearA = parseInt(a.dataset.year, 10);
      var yearB = parseInt(b.dataset.year, 10);
      var countA = parseInt(a.dataset.count, 10);
      var countB = parseInt(b.dataset.count, 10);

      switch (mode) {
        case 'year-asc':
          return yearA - yearB;
        case 'count-desc':
          if (countB !== countA) return countB - countA;
          return yearB - yearA;
        case 'count-asc':
          if (countA !== countB) return countA - countB;
          return yearB - yearA;
        case 'year-desc':
        default:
          return yearB - yearA;
      }
    });

    sorted.forEach(function(section) {
      container.appendChild(section);
    });
  }

  sortSelect.addEventListener('change', function(event) {
    sortSections(event.target.value);
  });

  sortSections(sortSelect.value);
})(document);

(function(document) {
  var toggle = document.querySelector('#search-toggle');
  var overlay = document.querySelector('#search-overlay');
  var closeBtn = document.querySelector('#search-close');
  var input = document.querySelector('#search-input');
  var results = document.querySelector('#search-results');
  var status = document.querySelector('#search-status');
  var webcmdUrl = overlay ? overlay.getAttribute('data-webcmd-url') : '/webcmd/';
  var lastFocusedElement = null;

  if (!toggle || !overlay || !closeBtn || !input || !results) return;

  function isEditableTarget(target) {
    if (!target) return false;
    var tag = target.tagName ? target.tagName.toLowerCase() : '';
    return tag === 'input' || tag === 'textarea' || target.isContentEditable;
  }

  function setOverlayState(isOpen) {
    overlay.classList.toggle('is-open', isOpen);
    overlay.setAttribute('aria-hidden', isOpen ? 'false' : 'true');
    toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    document.body.classList.toggle('search-open', isOpen);
  }

  function openSearch() {
    lastFocusedElement = document.activeElement;
    setOverlayState(true);
    window.setTimeout(function() {
      input.focus();
      input.select();
    }, 0);
  }

  function clearResults(message) {
    results.innerHTML = '';
    var msg = document.createElement('p');
    msg.className = 'search-empty';
    msg.textContent = message;
    results.appendChild(msg);
  }

  function setStatus(message, options) {
    if (!status) return;
    var opts = options || {};
    status.classList.remove('is-loading', 'is-error', 'is-hidden');
    if (!message) {
      status.textContent = '';
      status.classList.add('is-hidden');
      return;
    }
    status.classList.toggle('is-loading', !!opts.loading);
    status.classList.toggle('is-error', !!opts.error);
    if (opts.html) {
      status.innerHTML = message;
    } else {
      status.textContent = message;
    }
  }

  function buildSearchIndex() {
    if (window.siteIndex && window.siteStore) {
      return { index: window.siteIndex, store: window.siteStore };
    }
    if (window.elasticlunr) {
      var store = window.siteStore || window.siteDocs;
      if (store) {
        var idx = window.elasticlunr(function() {
          this.addField('title');
          this.addField('layout');
          this.addField('content');
          this.setRef('id');
        });
        for (var i = 0; i < store.length; i++) {
          var doc = store[i];
          if (!doc) continue;
          idx.addDoc({
            title: doc.title,
            layout: doc.layout,
            content: doc.content,
            id: doc.id
          });
        }
        window.siteIndex = idx;
        window.siteStore = store;
        return { index: idx, store: store };
      }
    }
    return null;
  }

  function findMatches(query, indexData) {
    var matches = indexData.index.search(query, { expand: true });
    if (matches.length === 0) {
      var lowered = query.toLowerCase();
      for (var i = 0; i < indexData.store.length; i++) {
        var doc = indexData.store[i];
        var haystack = (doc.title + ' ' + doc.content).toLowerCase();
        if (haystack.indexOf(lowered) !== -1) {
          matches.push({ ref: doc.id });
        }
      }
    }
    return matches;
  }

  function renderResults(query) {
    var trimmed = query.trim();
    setStatus('');
    if (!trimmed) {
      clearResults('Type to search the archive.');
      return;
    }

    if (!(window.siteIndex && window.siteStore)) {
      setStatus('Building search index...', { loading: true });
    }

    var indexData = buildSearchIndex();
    if (!indexData) {
      results.innerHTML = '';
      var fallbackUrl = webcmdUrl || '/webcmd/';
      var fallbackMessage = 'Search index not available. Try again in a moment or use the <a href="' + fallbackUrl + '">command-line search</a>.';
      setStatus(fallbackMessage, { error: true, html: true });
      return;
    }
    setStatus('');

    var matches = findMatches(trimmed, indexData);
    results.innerHTML = '';

    var count = document.createElement('div');
    count.className = 'search-count';
    count.textContent = matches.length + (matches.length === 1 ? ' result' : ' results');
    results.appendChild(count);

    if (matches.length === 0) {
      clearResults('No results for "' + trimmed + '".');
      return;
    }

    var maxResults = 12;
    for (var i = 0; i < matches.length && i < maxResults; i++) {
      var ref = matches[i].ref;
      var doc = indexData.store[ref];
      if (!doc) continue;

      var item = document.createElement('a');
      item.className = 'search-result';
      item.href = doc.link;

      var title = document.createElement('div');
      title.className = 'search-result-title';
      title.textContent = doc.title || doc.link;
      item.appendChild(title);

      if (doc.layout) {
        var meta = document.createElement('div');
        meta.className = 'search-result-meta';
        meta.textContent = doc.layout;
        item.appendChild(meta);
      }

      if (doc.snippet) {
        var snippet = document.createElement('div');
        snippet.className = 'search-result-snippet';
        snippet.textContent = doc.snippet;
        item.appendChild(snippet);
      }

      results.appendChild(item);
    }

    if (matches.length > maxResults) {
      var more = document.createElement('div');
      more.className = 'search-count';
      more.textContent = '...and ' + (matches.length - maxResults) + ' more';
      results.appendChild(more);
    }
  }

  function closeSearch() {
    setOverlayState(false);
    input.value = '';
    setStatus('');
    clearResults('Type to search the archive.');
    if (lastFocusedElement && lastFocusedElement.focus) {
      lastFocusedElement.focus();
    }
    lastFocusedElement = null;
  }

  function getFocusableElements() {
    return Array.prototype.slice.call(
      overlay.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])')
    ).filter(function(el) {
      return el.offsetWidth || el.offsetHeight || el === document.activeElement;
    });
  }

  toggle.addEventListener('click', function() {
    openSearch();
  });

  closeBtn.addEventListener('click', function() {
    closeSearch();
  });

  overlay.addEventListener('click', function(event) {
    if (event.target === overlay) {
      closeSearch();
    }
  });

  overlay.addEventListener('keydown', function(event) {
    if (event.key !== 'Tab' || !overlay.classList.contains('is-open')) return;
    var focusable = getFocusableElements();
    if (!focusable.length) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });

  input.addEventListener('input', function(event) {
    renderResults(event.target.value);
  });

  document.addEventListener('keydown', function(event) {
    if (event.key === '/' && !overlay.classList.contains('is-open') && !isEditableTarget(event.target)) {
      event.preventDefault();
      openSearch();
    } else if (event.key === 'Escape' && overlay.classList.contains('is-open')) {
      event.preventDefault();
      closeSearch();
    }
  });
})(document);
