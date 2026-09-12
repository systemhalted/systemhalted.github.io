(function(document) {
  'use strict';

  var root = document.documentElement;
  var themeToggle = document.getElementById('theme-toggle');
  var lightClass = 'theme-nord-light';
  var darkClass = 'theme-nord-dark';
  var storageKey = 'theme';
  var mediaQuery = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function storedTheme() {
    try {
      var value = localStorage.getItem(storageKey);
      return value === 'light' || value === 'dark' ? value : null;
    } catch (error) {
      return null;
    }
  }

  function currentTheme() {
    return root.classList.contains(darkClass) ? 'dark' : 'light';
  }

  function syncThemeControl() {
    if (!themeToggle) return;
    var dark = currentTheme() === 'dark';
    themeToggle.setAttribute('aria-label', dark ? 'Switch to Nord light theme' : 'Switch to Nord dark theme');
  }

  function syncComments(mode) {
    var frame = document.querySelector('iframe.giscus-frame');
    if (!frame || !frame.contentWindow) return;
    frame.contentWindow.postMessage({
      giscus: { setConfig: { theme: mode === 'dark' ? 'noborder_dark' : 'light' } }
    }, 'https://giscus.app');
  }

  function applyTheme(mode, persist) {
    var normalized = mode === 'dark' ? 'dark' : 'light';
    root.classList.remove(lightClass, darkClass);
    root.classList.add(normalized === 'dark' ? darkClass : lightClass);
    if (persist) {
      try { localStorage.setItem(storageKey, normalized); } catch (error) {}
    }
    syncThemeControl();
    syncComments(normalized);
    return normalized;
  }

  function toggleTheme() {
    return applyTheme(currentTheme() === 'dark' ? 'light' : 'dark', true);
  }

  if (themeToggle) themeToggle.addEventListener('click', toggleTheme);
  syncThemeControl();

  if (mediaQuery) {
    var handleSystemTheme = function(event) {
      if (!storedTheme()) applyTheme(event.matches ? 'dark' : 'light', false);
    };
    if (mediaQuery.addEventListener) mediaQuery.addEventListener('change', handleSystemTheme);
    else if (mediaQuery.addListener) mediaQuery.addListener(handleSystemTheme);
  }

  window.__toggleMode = toggleTheme;
  window.__setMode = function(mode) { return applyTheme(mode, true); };
  window.__syncTheme = function() { syncComments(currentTheme()); };
  window.__toggleCRT = function() {
    var enabled = !root.classList.contains('theme-crt');
    root.classList.toggle('theme-crt', enabled);
    try { localStorage.setItem('theme-crt', enabled ? 'on' : 'off'); } catch (error) {}
    return enabled;
  };
})(document);

(function(document) {
  'use strict';

  var container = document.getElementById('archive-years');
  var sortSelect = document.getElementById('archive-sort');
  if (!container || !sortSelect) return;

  var sections = Array.prototype.slice.call(container.querySelectorAll('.archive-year'));

  function sortSections(mode) {
    var sorted = sections.slice().sort(function(a, b) {
      var yearA = Number(a.getAttribute('data-year')) || 0;
      var yearB = Number(b.getAttribute('data-year')) || 0;
      var countA = Number(a.getAttribute('data-count')) || 0;
      var countB = Number(b.getAttribute('data-count')) || 0;

      if (mode === 'year-asc') return yearA - yearB;
      if (mode === 'count-desc') return countB - countA || yearB - yearA;
      if (mode === 'count-asc') return countA - countB || yearB - yearA;
      return yearB - yearA;
    });

    sorted.forEach(function(section) { container.appendChild(section); });
  }

  sortSelect.addEventListener('change', function(event) {
    sortSections(event.target.value);
  });
})(document);

(function(document) {
  'use strict';

  var overlay = document.getElementById('search-overlay');
  var closeButton = document.getElementById('search-close');
  var input = document.getElementById('search-input');
  var results = document.getElementById('search-results');
  var status = document.getElementById('search-status');
  var triggers = Array.prototype.slice.call(document.querySelectorAll('.search-toggle, .search-open-trigger'));
  if (!overlay || !closeButton || !input || !results || !triggers.length) return;

  var elasticlunrUrl = overlay.getAttribute('data-elasticlunr-url');
  var indexUrl = overlay.getAttribute('data-index-url');
  var webcmdUrl = overlay.getAttribute('data-webcmd-url') || '/webcmd/';
  var emptyStateHTML = results.innerHTML;
  var lastFocusedElement = null;
  var searchPromise = null;
  var latestQuery = '';

  function isEditableTarget(target) {
    if (!target) return false;
    var tag = target.tagName ? target.tagName.toLowerCase() : '';
    return tag === 'input' || tag === 'textarea' || tag === 'select' || target.isContentEditable;
  }

  function loadScript(src) {
    return new Promise(function(resolve, reject) {
      var script = document.createElement('script');
      script.src = src;
      script.async = true;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  function getIndexData() {
    var store = window.siteStore || window.siteDocs || [];
    if (!window.siteIndex || !store.length) return null;

    var byId = {};
    store.forEach(function(doc) {
      if (doc && doc.id !== undefined && doc.id !== null) byId[String(doc.id)] = doc;
    });
    return { index: window.siteIndex, store: store, byId: byId };
  }

  function ensureSearchIndex() {
    var existing = getIndexData();
    if (existing) return Promise.resolve(existing);
    if (searchPromise) return searchPromise;

    searchPromise = Promise.resolve()
      .then(function() {
        if (window.elasticlunr) return null;
        if (!elasticlunrUrl) throw new Error('Search library URL is missing.');
        return loadScript(elasticlunrUrl);
      })
      .then(function() {
        if (window.siteDocs && window.siteDocs.length) return null;
        if (!indexUrl) throw new Error('Search index URL is missing.');
        return loadScript(indexUrl);
      })
      .then(function() {
        if (typeof window.ensureSiteIndex === 'function') window.ensureSiteIndex();
        var data = getIndexData();
        if (!data) throw new Error('Search index did not initialize.');
        return data;
      })
      .catch(function(error) {
        searchPromise = null;
        throw error;
      });

    return searchPromise;
  }

  function setStatus(message, state) {
    if (!status) return;
    status.textContent = message || '';
    status.classList.toggle('is-hidden', !message);
    status.classList.toggle('is-loading', state === 'loading');
    status.classList.toggle('is-error', state === 'error');
  }

  function showSearchError() {
    if (!status) return;
    status.innerHTML = '';
    status.classList.remove('is-hidden', 'is-loading');
    status.classList.add('is-error');
    status.appendChild(document.createTextNode('Search could not load. Try the '));
    var fallback = document.createElement('a');
    fallback.href = webcmdUrl;
    fallback.textContent = 'command-line search';
    status.appendChild(fallback);
    status.appendChild(document.createTextNode('.'));
  }

  function resetResults() {
    results.innerHTML = emptyStateHTML;
  }

  function resolveDoc(ref, indexData) {
    return indexData.byId[String(ref)] || indexData.store[Number(ref)] || null;
  }

  function findMatches(query, indexData) {
    var matches = indexData.index.search(query, { expand: true });
    if (matches.length) return matches;

    var lowered = query.toLowerCase();
    indexData.store.forEach(function(doc) {
      if (!doc) return;
      var haystack = ((doc.title || '') + ' ' + (doc.categories || '') + ' ' + (doc.tags || '') + ' ' + (doc.content || '')).toLowerCase();
      if (haystack.indexOf(lowered) !== -1) matches.push({ ref: doc.id });
    });
    return matches;
  }

  function renderMatches(query, indexData) {
    if (query !== latestQuery) return;
    var matches = findMatches(query, indexData);
    var maxResults = 12;
    results.innerHTML = '';
    setStatus('');

    var count = document.createElement('p');
    count.className = 'search-count';
    count.textContent = matches.length + (matches.length === 1 ? ' result' : ' results');
    results.appendChild(count);

    if (!matches.length) {
      var empty = document.createElement('p');
      empty.className = 'search-empty';
      empty.textContent = 'No results for “' + query + '”.';
      results.appendChild(empty);
      return;
    }

    matches.slice(0, maxResults).forEach(function(match) {
      var doc = resolveDoc(match.ref, indexData);
      if (!doc) return;

      var link = document.createElement('a');
      link.className = 'search-result';
      link.href = doc.link;

      var title = document.createElement('span');
      title.className = 'search-result-title';
      title.textContent = doc.title || doc.link;
      link.appendChild(title);

      if (doc.snippet) {
        var snippet = document.createElement('span');
        snippet.className = 'search-result-snippet';
        snippet.textContent = doc.snippet;
        link.appendChild(snippet);
      }
      results.appendChild(link);
    });

    if (matches.length > maxResults) {
      var more = document.createElement('p');
      more.className = 'search-count';
      more.textContent = 'Showing ' + maxResults + ' of ' + matches.length + ' results.';
      results.appendChild(more);
    }
  }

  function search(query) {
    var trimmed = query.trim();
    latestQuery = trimmed;
    if (!trimmed) {
      setStatus('');
      resetResults();
      return;
    }

    setStatus('Searching…', 'loading');
    ensureSearchIndex()
      .then(function(indexData) { renderMatches(trimmed, indexData); })
      .catch(function() {
        if (trimmed === latestQuery) {
          results.innerHTML = '';
          showSearchError();
        }
      });
  }

  function setOpen(open) {
    overlay.classList.toggle('is-open', open);
    overlay.setAttribute('aria-hidden', open ? 'false' : 'true');
    document.body.classList.toggle('overlay-open', open);
    triggers.forEach(function(trigger) {
      if (trigger.hasAttribute('aria-expanded')) trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  function openSearch() {
    lastFocusedElement = document.activeElement;
    setOpen(true);
    ensureSearchIndex().catch(function() {});
    window.requestAnimationFrame(function() { input.focus(); });
  }

  function closeSearch() {
    setOpen(false);
    input.value = '';
    latestQuery = '';
    setStatus('');
    resetResults();
    if (lastFocusedElement && lastFocusedElement.focus) lastFocusedElement.focus();
    lastFocusedElement = null;
  }

  function focusableElements() {
    return Array.prototype.slice.call(overlay.querySelectorAll('a[href], button:not([disabled]), input:not([disabled])'))
      .filter(function(element) { return element.offsetWidth || element.offsetHeight || element === document.activeElement; });
  }

  triggers.forEach(function(trigger) { trigger.addEventListener('click', openSearch); });
  closeButton.addEventListener('click', closeSearch);
  input.addEventListener('input', function(event) { search(event.target.value); });

  results.addEventListener('click', function(event) {
    var suggestion = event.target.closest ? event.target.closest('button[data-suggest]') : null;
    if (!suggestion) return;
    input.value = suggestion.getAttribute('data-suggest') || '';
    search(input.value);
    input.focus();
  });

  overlay.addEventListener('click', function(event) {
    if (event.target === overlay) closeSearch();
  });

  overlay.addEventListener('keydown', function(event) {
    if (!overlay.classList.contains('is-open')) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closeSearch();
      return;
    }

    if (event.key !== 'Tab') return;
    var elements = focusableElements();
    if (!elements.length) return;
    var first = elements[0];
    var last = elements[elements.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });

  window.__openSearch = openSearch;
  window.__closeSearch = closeSearch;
  window.__isEditableTarget = isEditableTarget;
})(document);

(function(document) {
  'use strict';

  var overlay = document.getElementById('shortcuts-overlay');
  var closeButton = document.getElementById('shortcuts-close');
  var pendingGo = false;
  var pendingTimer = null;
  var lastFocusedElement = null;

  function isEditableTarget(target) {
    if (window.__isEditableTarget) return window.__isEditableTarget(target);
    if (!target) return false;
    var tag = target.tagName ? target.tagName.toLowerCase() : '';
    return tag === 'input' || tag === 'textarea' || tag === 'select' || target.isContentEditable;
  }

  function anyOverlayOpen() {
    return !!document.querySelector('.search-overlay.is-open');
  }

  function openHelp() {
    if (!overlay) return;
    lastFocusedElement = document.activeElement;
    overlay.classList.add('is-open');
    overlay.setAttribute('aria-hidden', 'false');
    document.body.classList.add('overlay-open');
    window.requestAnimationFrame(function() { if (closeButton) closeButton.focus(); });
  }

  function closeHelp() {
    if (!overlay) return;
    overlay.classList.remove('is-open');
    overlay.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('overlay-open');
    if (lastFocusedElement && lastFocusedElement.focus) lastFocusedElement.focus();
    lastFocusedElement = null;
  }

  if (closeButton) closeButton.addEventListener('click', closeHelp);
  if (overlay) {
    overlay.addEventListener('click', function(event) { if (event.target === overlay) closeHelp(); });
    overlay.addEventListener('keydown', function(event) {
      if (event.key === 'Tab' && closeButton) {
        event.preventDefault();
        closeButton.focus();
      }
    });
  }

  document.addEventListener('keydown', function(event) {
    var key = event.key;

    if (key === 'Escape' && overlay && overlay.classList.contains('is-open')) {
      event.preventDefault();
      closeHelp();
      return;
    }
    if (isEditableTarget(event.target) || event.metaKey || event.ctrlKey || event.altKey) return;

    if (pendingGo) {
      pendingGo = false;
      window.clearTimeout(pendingTimer);
      var route = (window.SYSTEMHALTED_ROUTES || {})[key.toLowerCase()];
      if (route) {
        event.preventDefault();
        window.location.href = route;
      }
      return;
    }

    if (anyOverlayOpen()) return;

    if (key === '/' || key.toLowerCase() === 's') {
      event.preventDefault();
      if (window.__openSearch) window.__openSearch();
    } else if (key.toLowerCase() === 't') {
      event.preventDefault();
      if (window.__toggleMode) window.__toggleMode();
    } else if (key === '?') {
      event.preventDefault();
      openHelp();
    } else if (key.toLowerCase() === 'g') {
      pendingGo = true;
      pendingTimer = window.setTimeout(function() { pendingGo = false; }, 900);
    }
  });
})(document);

(function(document) {
  'use strict';

  function improveThirdPartyControl(node) {
    if (!node || node.nodeType !== 1) return;

    if (node.tagName === 'IFRAME' && !node.getAttribute('title')) {
      node.setAttribute('title', 'Embedded content');
    }
    if (node.tagName === 'IFRAME' && node.classList.contains('giscus-frame')) {
      node.addEventListener('load', function() {
        if (window.__syncTheme) window.__syncTheme();
      });
    }
    if (node.tagName === 'TEXTAREA' && !node.getAttribute('aria-label')) {
      node.setAttribute('aria-label', 'Verification response');
    }

    Array.prototype.forEach.call(node.querySelectorAll('iframe'), improveThirdPartyControl);
    Array.prototype.forEach.call(node.querySelectorAll('textarea'), improveThirdPartyControl);
  }

  improveThirdPartyControl(document.body);
  if (window.MutationObserver) {
    new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        Array.prototype.forEach.call(mutation.addedNodes, improveThirdPartyControl);
      });
    }).observe(document.body, { childList: true, subtree: true });
  }
})(document);

(function(document) {
  'use strict';

  function labelIframe(node) {
    if (node.tagName === 'IFRAME' && !node.getAttribute('title')) node.setAttribute('title', 'Embedded content');
  }

  function labelRecaptchaTextarea(node) {
    if (node.tagName === 'TEXTAREA' && !node.getAttribute('aria-label')) node.setAttribute('aria-label', 'Verification response');
  }

  function scrub(scope) {
    if (!scope || !scope.querySelectorAll) return;
    Array.prototype.forEach.call(scope.querySelectorAll('iframe'), labelIframe);
    Array.prototype.forEach.call(scope.querySelectorAll('textarea'), labelRecaptchaTextarea);
  }

  scrub(document);
  if (window.MutationObserver) {
    new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        Array.prototype.forEach.call(mutation.addedNodes, function(node) {
          if (node.nodeType !== 1) return;
          labelIframe(node);
          labelRecaptchaTextarea(node);
          scrub(node);
        });
      });
    }).observe(document.documentElement, { childList: true, subtree: true });
  }
})(document);
