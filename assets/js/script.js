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

// Theme menu: one popover controlling two independent axes —
//   mode  (light/dark)  -> 'theme'        key, theme-nord-light/dark classes
//   style (flat/glazed) -> 'theme-style'  key, theme-glazed class
// The classes are already applied pre-paint by the inline script in
// head.html; this wires the picker UI, persistence, and live updates.
(function(document) {
  var root = document.documentElement;
  var menuToggle = document.querySelector('#theme-menu-toggle');
  var panel = document.querySelector('#theme-menu-panel');

  if (!menuToggle || !panel) return;

  var options = Array.prototype.slice.call(panel.querySelectorAll('.theme-option'));
  var lightClass = 'theme-nord-light';
  var darkClass = 'theme-nord-dark';
  var glazedClass = 'theme-glazed';
  var modeKey = 'theme';
  var styleKey = 'theme-style';
  var mediaQuery = null;
  var storedMode = null;

  function read(key, valid) {
    try {
      var v = localStorage.getItem(key);
      return valid.indexOf(v) !== -1 ? v : null;
    } catch (e) {
      return null;
    }
  }

  function write(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
    }
  }

  function currentMode() {
    return root.classList.contains(darkClass) ? 'dark' : 'light';
  }

  function currentStyle() {
    return root.classList.contains(glazedClass) ? 'glazed' : 'flat';
  }

  function syncOptions() {
    var mode = currentMode();
    var style = currentStyle();
    options.forEach(function(option) {
      var on = option.dataset.axis === 'mode'
        ? option.dataset.value === mode
        : option.dataset.value === style;
      option.setAttribute('aria-checked', on ? 'true' : 'false');
    });
  }

  function applyTheme(mode, persist) {
    root.classList.remove(lightClass, darkClass);
    root.classList.add(mode === 'dark' ? darkClass : lightClass);

    if (persist) {
      storedMode = mode;
      write(modeKey, mode);
    }

    syncOptions();

    var giscusFrame = document.querySelector('iframe.giscus-frame');
    if (giscusFrame && giscusFrame.contentWindow) {
      giscusFrame.contentWindow.postMessage(
        { giscus: { setConfig: { theme: mode === 'dark' ? 'dark' : 'light' } } },
        'https://giscus.app'
      );
    }
  }

  function applyStyle(style, persist) {
    if (style === 'glazed') {
      root.classList.add(glazedClass);
    } else {
      root.classList.remove(glazedClass);
    }

    if (persist) {
      write(styleKey, style);
    }

    syncOptions();
  }

  // ---- popover open/close ----
  function isOpen() {
    return !panel.hidden;
  }

  function openMenu() {
    panel.hidden = false;
    menuToggle.setAttribute('aria-expanded', 'true');
    var checked = options.filter(function(o) { return o.getAttribute('aria-checked') === 'true'; })[0];
    (checked || options[0]).focus();
  }

  function closeMenu(focusToggle) {
    panel.hidden = true;
    menuToggle.setAttribute('aria-expanded', 'false');
    if (focusToggle) menuToggle.focus();
  }

  menuToggle.addEventListener('click', function() {
    if (isOpen()) {
      closeMenu(false);
    } else {
      openMenu();
    }
  });

  options.forEach(function(option) {
    option.addEventListener('click', function() {
      if (option.dataset.axis === 'mode') {
        applyTheme(option.dataset.value, true);
      } else {
        applyStyle(option.dataset.value, true);
      }
    });
  });

  // Close on Escape (return focus to trigger) and on outside pointer events.
  panel.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeMenu(true);
    }
  });

  document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && isOpen()) closeMenu(true);
  });

  document.addEventListener('pointerdown', function(event) {
    if (isOpen() && !panel.contains(event.target) && !menuToggle.contains(event.target)) {
      closeMenu(false);
    }
  });

  // ---- initial state (classes already set pre-paint) ----
  if (window.matchMedia) {
    mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
  }

  storedMode = read(modeKey, ['light', 'dark']);
  var initialMode = storedMode || (mediaQuery && mediaQuery.matches ? 'dark' : 'light');
  applyTheme(initialMode, false);
  applyStyle(read(styleKey, ['flat', 'glazed']) || 'flat', false);

  if (mediaQuery) {
    var handleSystemChange = function(event) {
      if (storedMode) return;
      applyTheme(event.matches ? 'dark' : 'light', false);
    };

    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', handleSystemChange);
    } else if (mediaQuery.addListener) {
      mediaQuery.addListener(handleSystemChange);
    }
  }

  // Exposed for the keyboard shortcuts (t = mode, Shift+G = glaze).
  window.__toggleMode = function() {
    applyTheme(currentMode() === 'dark' ? 'light' : 'dark', true);
  };
  window.__toggleGlaze = function() {
    applyStyle(currentStyle() === 'glazed' ? 'flat' : 'glazed', true);
  };

  // Exposed for the focus-mode reading controls (drive the same global theme).
  window.__setMode = function(mode) {
    applyTheme(mode === 'dark' ? 'dark' : 'light', true);
  };
  window.__currentMode = currentMode;

  // Hidden phosphor CRT theme — an Easter egg toggled from webcmd (`crt`).
  // Persisted under its own key and applied pre-paint in head.html.
  var crtClass = 'theme-crt';
  var crtKey = 'theme-crt';
  window.__toggleCRT = function() {
    var on = !root.classList.contains(crtClass);
    root.classList.toggle(crtClass, on);
    write(crtKey, on ? 'on' : 'off');
    return on;
  };
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

  // --- Konami-code "System Halted" Easter egg ---
  var haltOverlay = document.querySelector('#halt-overlay');
  var haltLastFocused = null;
  var konamiCode = ['ArrowUp','ArrowUp','ArrowDown','ArrowDown','ArrowLeft','ArrowRight','ArrowLeft','ArrowRight','b','a'];
  var konamiBuffer = [];

  function isHaltOpen() {
    return haltOverlay && haltOverlay.classList.contains('is-open');
  }

  function openHalt() {
    if (!haltOverlay || isHaltOpen()) return;
    var trivia = document.querySelector('#halt-trivia');
    var lines = (window.OS_HISTORY && window.OS_HISTORY.halt_trivia) || [];
    if (trivia && lines.length) {
      trivia.textContent = lines[Math.floor(Math.random() * lines.length)];
    }
    haltLastFocused = document.activeElement;
    haltOverlay.classList.add('is-open');
    haltOverlay.setAttribute('aria-hidden', 'false');
    document.body.classList.add('halt-open');
    var screen = haltOverlay.querySelector('.halt-screen');
    if (screen) {
      screen.setAttribute('tabindex', '-1');
      screen.focus();
    }
  }

  function closeHalt() {
    if (!haltOverlay) return;
    haltOverlay.classList.remove('is-open');
    haltOverlay.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('halt-open');
    if (haltLastFocused && haltLastFocused.focus) haltLastFocused.focus();
    haltLastFocused = null;
  }

  if (haltOverlay) {
    haltOverlay.addEventListener('click', closeHalt);
  }

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
    var routes = window.NORD_SHORTCUTS || {
      h: '/',
      f: '/featured/',
      k: '/',
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

    // The System Halted overlay dismisses on any key.
    if (isHaltOpen()) {
      event.preventDefault();
      closeHalt();
      return;
    }

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

    // Track the Konami code. We only record keys (no preventDefault) so arrow
    // keys keep scrolling; the overlay fires only on a full match.
    konamiBuffer.push(key.length === 1 ? key.toLowerCase() : key);
    if (konamiBuffer.length > konamiCode.length) {
      konamiBuffer.shift();
    }
    if (konamiBuffer.length === konamiCode.length &&
        konamiBuffer.join(',') === konamiCode.join(',')) {
      konamiBuffer = [];
      event.preventDefault();
      openHalt();
      return;
    }

    // Escape leaves focus reading mode (overlays handled above / by their own listeners).
    if (key === 'Escape' && document.body.classList.contains('reading-focus')) {
      event.preventDefault();
      if (window.__exitFocus) window.__exitFocus();
      return;
    }

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
      event.preventDefault();
      if (window.__toggleMode) window.__toggleMode();
      return;
    }

    // Shift+G toggles the glazed (frosted-glass) look. Uppercase 'G'
    // never collides with the lowercase 'g' "go to" chord above.
    if (key === 'G') {
      event.preventDefault();
      if (window.__toggleGlaze) window.__toggleGlaze();
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

    // Focus (distraction-free) reading mode — posts only. The `g f` chord is
    // handled by the pendingG branch above, so a lone `f` never collides.
    if (key === 'f') {
      if (!window.__toggleFocus) return;
      event.preventDefault();
      window.__toggleFocus();
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

// ---------------------------------------------------------------------------
// Focus (distraction-free) reading mode — posts only.
// Toggles `body.reading-focus` (CSS hides chrome + post extras), syncs a
// `#focus` URL hash so reload/sharing stays in focus, and is driven by the
// on-page Focus button, the global `f` shortcut, and Esc / the exit button.
// ---------------------------------------------------------------------------
(function(document) {
  var post = document.querySelector('.post');
  if (!post) return;

  var FOCUS_CLASS = 'reading-focus';
  var FOCUS_HASH = '#focus';
  var root = document.documentElement;
  var toggleBtn = document.querySelector('#focus-toggle');
  var exitBtn = document.querySelector('#focus-exit');
  var content = document.querySelector('.post-content');

  // Reading controls (text size + theme).
  var sizeDownBtn = document.querySelector('#focus-size-down');
  var sizeUpBtn = document.querySelector('#focus-size-up');
  var themeLightBtn = document.querySelector('#focus-theme-light');
  var themeDarkBtn = document.querySelector('#focus-theme-dark');

  var SIZE_KEY = 'reading-focus-size';
  var SIZE_DEFAULT = 1.18, SIZE_MIN = 0.95, SIZE_MAX = 1.7, SIZE_STEP = 0.09;
  var size = SIZE_DEFAULT;

  function clampSize(v) {
    return Math.max(SIZE_MIN, Math.min(SIZE_MAX, v));
  }

  function applySize(persist) {
    root.style.setProperty('--focus-reading-size', size.toFixed(2) + 'rem');
    if (sizeDownBtn) sizeDownBtn.disabled = size <= SIZE_MIN + 0.001;
    if (sizeUpBtn) sizeUpBtn.disabled = size >= SIZE_MAX - 0.001;
    if (persist) {
      try { localStorage.setItem(SIZE_KEY, size.toFixed(2)); } catch (e) {}
    }
  }

  function adjustSize(delta) {
    size = clampSize(Math.round((size + delta) * 100) / 100);
    applySize(true);
  }

  // The theme buttons drive the same global light/dark theme; reflect its state.
  function syncTheme() {
    var mode = window.__currentMode ? window.__currentMode() : 'light';
    if (themeLightBtn) themeLightBtn.setAttribute('aria-pressed', mode === 'light' ? 'true' : 'false');
    if (themeDarkBtn) themeDarkBtn.setAttribute('aria-pressed', mode === 'dark' ? 'true' : 'false');
  }

  function isOn() {
    return document.body.classList.contains(FOCUS_CLASS);
  }

  function setHash(on) {
    var base = location.pathname + location.search;
    try {
      history.replaceState(null, '', on ? base + FOCUS_HASH : base);
    } catch (e) {
      if (on) {
        location.hash = 'focus';
      } else if (location.hash === FOCUS_HASH) {
        location.hash = '';
      }
    }
  }

  function enter(updateHash) {
    if (isOn()) return;
    document.body.classList.add(FOCUS_CLASS);
    if (toggleBtn) toggleBtn.setAttribute('aria-pressed', 'true');
    syncTheme();
    if (updateHash !== false) setHash(true);
    // Move keyboard focus into the article so reading/Tab starts at the content.
    if (content) {
      content.setAttribute('tabindex', '-1');
      content.focus();
    } else if (exitBtn) {
      exitBtn.focus();
    }
  }

  function exit(updateHash) {
    if (!isOn()) return;
    document.body.classList.remove(FOCUS_CLASS);
    if (toggleBtn) toggleBtn.setAttribute('aria-pressed', 'false');
    if (updateHash !== false) setHash(false);
    if (toggleBtn) toggleBtn.focus();
  }

  function toggle() {
    if (isOn()) exit(); else enter();
  }

  if (toggleBtn) toggleBtn.addEventListener('click', function() { toggle(); });
  if (exitBtn) exitBtn.addEventListener('click', function() { exit(); });

  // Reading-control wiring.
  if (sizeDownBtn) sizeDownBtn.addEventListener('click', function() { adjustSize(-SIZE_STEP); });
  if (sizeUpBtn) sizeUpBtn.addEventListener('click', function() { adjustSize(SIZE_STEP); });
  if (themeLightBtn) themeLightBtn.addEventListener('click', function() {
    if (window.__setMode) window.__setMode('light');
    syncTheme();
  });
  if (themeDarkBtn) themeDarkBtn.addEventListener('click', function() {
    if (window.__setMode) window.__setMode('dark');
    syncTheme();
  });

  // Apply any persisted reading size up front (the CSS var defaults if unset).
  (function() {
    var stored = NaN;
    try { stored = parseFloat(localStorage.getItem(SIZE_KEY)); } catch (e) {}
    if (!isNaN(stored)) size = clampSize(stored);
    applySize(false);
  })();

  // Keep state in sync with manual hash navigation / back-forward.
  window.addEventListener('hashchange', function() {
    if (location.hash === FOCUS_HASH) enter(false);
    else exit(false);
  });

  // Enter on load when the URL already carries #focus (reload / shared link).
  if (location.hash === FOCUS_HASH) enter(false);

  window.__toggleFocus = toggle;
  window.__exitFocus = exit;
})(document);

// ---------------------------------------------------------------------------
// Console greeting — a breadcrumb for the curious who open devtools.
// ---------------------------------------------------------------------------
(function() {
  try {
    var art = [
      '',
      '  ██████ ██    ██ ███████ ████████ ███████ ███    ███',
      '  ██     ██    ██ ██         ██    ██      ████  ████',
      '  ██████  ██  ██  ███████    ██    █████   ██ ████ ██',
      '      ██   ████        ██    ██    ██      ██  ██  ██',
      '  ██████    ██    ███████    ██    ███████ ██      ██',
      '            H A L T E D',
      ''
    ].join('\n');
    console.log('%c' + art, 'color:#ffb000;font-family:monospace;');
    console.log(
      '%cSystem Halted — I am just a DOS error.%c\nCurious? Open /webcmd/ and type %chistory%c (or %cfortune%c). And somewhere here, an old cheat code still works…',
      'color:#88c0d0;font-weight:bold', 'color:inherit',
      'color:#ffb000', 'color:inherit',
      'color:#ffb000', 'color:inherit'
    );
  } catch (e) {}
})();
