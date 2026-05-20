(function(document) {
  var toggle = document.querySelector('.sidebar-toggle');
  var sidebar = document.querySelector('#sidebar');
  var checkbox = document.querySelector('#sidebar-checkbox');
  var annotateToggle = document.querySelector('#annotate-toggle');

  if (!toggle || !sidebar || !checkbox) return;

  var navItems = Array.prototype.slice.call(sidebar.querySelectorAll('.sidebar-nav-item'));

  function setExpandedState() {
    toggle.setAttribute('aria-expanded', checkbox.checked ? 'true' : 'false');
  }

  function focusFirstItem() {
    if (!navItems.length) return;
    setRovingIndex(0);
    navItems[0].focus();
  }

  function setRovingIndex(activeIdx) {
    for (var i = 0; i < navItems.length; i++) {
      navItems[i].setAttribute('tabindex', i === activeIdx ? '0' : '-1');
    }
  }

  function openSidebar() {
    if (checkbox.checked) return;
    checkbox.checked = true;
    // Programmatic assignment to .checked does NOT fire the change event,
    // so we must call the same logic the change handler would.
    setExpandedState();
    window.requestAnimationFrame(focusFirstItem);
  }

  function closeSidebar(restoreFocus) {
    if (!checkbox.checked) return;
    var focusWasInside = sidebar.contains(document.activeElement);
    checkbox.checked = false;
    setExpandedState();
    if (restoreFocus || focusWasInside) toggle.focus();
  }

  document.addEventListener('click', function(e) {
    var target = e.target;

    if(!checkbox.checked ||
       sidebar.contains(target) ||
       (target === checkbox || target === toggle)) return;

    closeSidebar(false);
  }, false);

  // Auto-close when focus moves out of the sidebar and off the toggle.
  // The toggle stays a valid neighbor of an open sidebar (it's the close
  // affordance); anything else means the user has moved on.
  document.addEventListener('focusin', function(e) {
    if (!checkbox.checked) return;
    var target = e.target;
    if (sidebar.contains(target) || target === toggle || target === checkbox) return;
    closeSidebar(false);
  });

  // Native click on the <label> toggles the checkbox via the browser and
  // fires this change event. Keyboard (Space/Enter) goes through openSidebar()
  // / closeSidebar() above and does NOT fire change — both paths converge on
  // the same setExpandedState + focusFirstItem behavior.
  checkbox.addEventListener('change', function() {
    setExpandedState();
    if (checkbox.checked) {
      window.requestAnimationFrame(focusFirstItem);
    }
  });

  toggle.addEventListener('keydown', function(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      if (checkbox.checked) {
        closeSidebar(true);
      } else {
        openSidebar();
      }
    }
  });

  sidebar.addEventListener('keydown', function(event) {
    var key = event.key;
    if (key === 'Escape') {
      event.preventDefault();
      closeSidebar(true);
      return;
    }

    var currentIdx = navItems.indexOf(document.activeElement);
    if (currentIdx === -1) return;

    var nextIdx = -1;
    if (key === 'ArrowDown') nextIdx = (currentIdx + 1) % navItems.length;
    else if (key === 'ArrowUp') nextIdx = (currentIdx - 1 + navItems.length) % navItems.length;
    else if (key === 'Home') nextIdx = 0;
    else if (key === 'End') nextIdx = navItems.length - 1;

    if (nextIdx !== -1) {
      event.preventDefault();
      setRovingIndex(nextIdx);
      navItems[nextIdx].focus();
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

  // Expose for the global shortcuts IIFE to use.
  window.__sidebarToggle = function() {
    if (checkbox.checked) closeSidebar(true);
    else openSidebar();
  };
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

    var giscusFrame = document.querySelector('iframe.giscus-frame');
    if (giscusFrame && giscusFrame.contentWindow) {
      giscusFrame.contentWindow.postMessage(
        { giscus: { setConfig: { theme: theme === 'dark' ? 'dark' : 'light' } } },
        'https://giscus.app'
      );
    }
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

    container.setAttribute('aria-busy', 'true');
    sorted.forEach(function(section) {
      container.appendChild(section);
    });
    container.setAttribute('aria-busy', 'false');
  }

  sortSelect.addEventListener('change', function(event) {
    sortSections(event.target.value);
    var label = sortSelect.options[sortSelect.selectedIndex].textContent;
    container.setAttribute('data-sort-label', label);
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

  var emptyStateHTML = results.innerHTML;

  function renderEmptyState() {
    results.innerHTML = emptyStateHTML;
  }

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
    window.requestAnimationFrame(function() {
      window.requestAnimationFrame(function() {
        input.focus();
        input.select();
      });
    });
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
    status.textContent = message;
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
      renderEmptyState();
      return;
    }

    if (!(window.siteIndex && window.siteStore)) {
      setStatus('Building search index...', { loading: true });
    }

    var indexData = buildSearchIndex();
    if (!indexData) {
      results.innerHTML = '';
      var fallbackUrl = webcmdUrl || '/webcmd/';
      status.classList.remove('is-loading', 'is-hidden');
      status.classList.add('is-error');
      status.textContent = 'Search index not available. Try again in a moment or use the ';
      var link = document.createElement('a');
      link.href = fallbackUrl;
      link.textContent = 'command-line search';
      status.appendChild(link);
      status.appendChild(document.createTextNode('.'));
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
    renderEmptyState();
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

  function getResultLinks() {
    return Array.prototype.slice.call(results.querySelectorAll('.search-result'));
  }

  overlay.addEventListener('keydown', function(event) {
    if (!overlay.classList.contains('is-open')) return;

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp' ||
        event.key === 'Home' || event.key === 'End') {
      var items = getResultLinks();
      if (!items.length) return;
      var current = items.indexOf(document.activeElement);
      var next = -1;
      if (event.key === 'ArrowDown') {
        next = current === -1 ? 0 : (current + 1) % items.length;
      } else if (event.key === 'ArrowUp') {
        next = current === -1 ? items.length - 1 : (current - 1 + items.length) % items.length;
      } else if (event.key === 'Home') {
        next = 0;
      } else if (event.key === 'End') {
        next = items.length - 1;
      }
      if (next !== -1) {
        event.preventDefault();
        items[next].focus();
        return;
      }
    }

    if (event.key !== 'Tab') return;
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

  results.addEventListener('click', function(event) {
    var btn = event.target.closest ? event.target.closest('button[data-suggest]') : null;
    if (!btn) return;
    input.value = btn.getAttribute('data-suggest') || '';
    var evt;
    try {
      evt = new Event('input', { bubbles: true });
    } catch (e) {
      evt = document.createEvent('Event');
      evt.initEvent('input', true, true);
    }
    input.dispatchEvent(evt);
    input.focus();
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

  // Expose for the shortcuts IIFE.
  window.__openSearch = openSearch;
  window.__closeSearch = closeSearch;
})(document);

// ---------------------------------------------------------------------------
// Global keyboard shortcuts + help dialog
// ---------------------------------------------------------------------------
(function(document) {
  var helpOverlay = document.querySelector('#shortcuts-overlay');
  var helpClose = document.querySelector('#shortcuts-close');
  var lastFocused = null;
  var pendingG = false;
  var pendingGTimer = null;

  function isEditableTarget(target) {
    if (!target) return false;
    var tag = target.tagName ? target.tagName.toLowerCase() : '';
    return tag === 'input' || tag === 'textarea' || target.isContentEditable;
  }

  function isAnyOverlayOpen() {
    var search = document.querySelector('#search-overlay');
    if (search && search.classList.contains('is-open')) return true;
    if (helpOverlay && helpOverlay.classList.contains('is-open')) return true;
    return false;
  }

  function openHelp() {
    if (!helpOverlay) return;
    lastFocused = document.activeElement;
    helpOverlay.classList.add('is-open');
    helpOverlay.setAttribute('aria-hidden', 'false');
    document.body.classList.add('shortcuts-open');
    window.requestAnimationFrame(function() {
      window.requestAnimationFrame(function() {
        if (helpClose) helpClose.focus();
      });
    });
  }

  function closeHelp() {
    if (!helpOverlay) return;
    helpOverlay.classList.remove('is-open');
    helpOverlay.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('shortcuts-open');
    if (lastFocused && lastFocused.focus) lastFocused.focus();
    lastFocused = null;
  }

  function clearPendingG() {
    pendingG = false;
    if (pendingGTimer) {
      clearTimeout(pendingGTimer);
      pendingGTimer = null;
    }
  }

  function handleGoTo(letter) {
    var routes = {
      h: '/',
      f: '/featured/',
      k: '/kartavya-path/',
      e: '/emacs/',
      a: '/about/'
    };
    if (routes[letter]) {
      window.location.href = routes[letter];
    }
  }

  if (helpClose) {
    helpClose.addEventListener('click', closeHelp);
  }
  if (helpOverlay) {
    helpOverlay.addEventListener('click', function(event) {
      if (event.target === helpOverlay) closeHelp();
    });
    helpOverlay.addEventListener('keydown', function(event) {
      if (event.key === 'Tab') {
        // Keep focus inside the dialog.
        var focusable = Array.prototype.slice.call(
          helpOverlay.querySelectorAll('a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])')
        ).filter(function(el) { return el.offsetWidth || el.offsetHeight; });
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
      }
    });
  }

  document.addEventListener('keydown', function(event) {
    var key = event.key;

    // Escape closes the help dialog (search overlay handles its own Escape).
    if (key === 'Escape' && helpOverlay && helpOverlay.classList.contains('is-open')) {
      event.preventDefault();
      closeHelp();
      return;
    }

    // Never trigger shortcuts while typing, while a modifier is held, or while another overlay is open.
    if (isEditableTarget(event.target)) return;
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (isAnyOverlayOpen() && key !== '?') return;

    // Handle pending `g` chord.
    if (pendingG) {
      var lower = key.length === 1 ? key.toLowerCase() : key;
      clearPendingG();
      if ('hfkea'.indexOf(lower) !== -1) {
        event.preventDefault();
        handleGoTo(lower);
      }
      return;
    }

    if (key === 'g') {
      pendingG = true;
      pendingGTimer = setTimeout(clearPendingG, 1200);
      return;
    }

    if (key === '?') {
      event.preventDefault();
      openHelp();
      return;
    }

    if (key === 't') {
      var themeToggle = document.querySelector('#theme-toggle');
      if (themeToggle) {
        event.preventDefault();
        themeToggle.click();
      }
      return;
    }

    if (key === 's') {
      event.preventDefault();
      if (window.__openSearch) window.__openSearch();
      return;
    }

    if (key === 'm') {
      event.preventDefault();
      if (window.__sidebarToggle) window.__sidebarToggle();
      return;
    }
  });

  // Third-party scripts (Kit newsletter embed, reCAPTCHA) inject elements
  // without titles or labels, failing WCAG 4.1.2 / 3.3.2. Stamp them as
  // they appear.
  function labelIframe(node) {
    if (!node || node.tagName !== 'IFRAME') return;
    if (!node.getAttribute('title')) {
      node.setAttribute('title', 'Embedded content');
    }
  }
  function labelRecaptchaTextarea(node) {
    if (!node || node.tagName !== 'TEXTAREA') return;
    if (node.name === 'g-recaptcha-response' && !node.getAttribute('aria-label')) {
      node.setAttribute('aria-label', 'reCAPTCHA response');
    }
  }
  function scrub(root) {
    if (!root || !root.querySelectorAll) return;
    Array.prototype.forEach.call(root.querySelectorAll('iframe'), labelIframe);
    Array.prototype.forEach.call(root.querySelectorAll('textarea'), labelRecaptchaTextarea);
  }
  scrub(document);
  if (typeof MutationObserver !== 'undefined') {
    new MutationObserver(function(mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var added = mutations[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          var node = added[j];
          if (node.nodeType !== 1) continue;
          labelIframe(node);
          labelRecaptchaTextarea(node);
          scrub(node);
        }
      }
    }).observe(document.body, { childList: true, subtree: true });
  }
})(document);
