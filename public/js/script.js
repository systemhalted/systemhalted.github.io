(function(document) {
  var toggle = document.querySelector('.sidebar-toggle');
  var sidebar = document.querySelector('#sidebar');
  var checkbox = document.querySelector('#sidebar-checkbox');

  document.addEventListener('click', function(e) {
    var target = e.target;

    if(!checkbox.checked ||
       sidebar.contains(target) ||
       (target === checkbox || target === toggle)) return;

    checkbox.checked = false;
  }, false);
})(document);

(function(document) {
  var root = document.documentElement;
  var toggle = document.querySelector('#theme-toggle');

  if (!toggle) return;

  var storageKey = 'theme';
  var lightClass = 'theme-nord-light';
  var darkClass = 'theme-nord-dark';
  var label = toggle.querySelector('.theme-toggle-label');

  function getStoredTheme() {
    try {
      return localStorage.getItem(storageKey);
    } catch (e) {
      return null;
    }
  }

  function getPreferredTheme() {
    try {
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        return 'dark';
      }
    } catch (e) {
      return 'light';
    }
    return 'light';
  }

  function updateToggle(theme) {
    var isDark = theme === 'dark';
    toggle.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    if (label) {
      label.textContent = isDark ? 'Light mode' : 'Dark mode';
    }
  }

  function applyTheme(theme, persist) {
    root.classList.remove(lightClass, darkClass);
    root.classList.add(theme === 'dark' ? darkClass : lightClass);

    if (persist) {
      try {
        localStorage.setItem(storageKey, theme);
      } catch (e) {
        return;
      }
    }

    updateToggle(theme);
  }

  var initialTheme = getStoredTheme() || getPreferredTheme();
  applyTheme(initialTheme, false);

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
