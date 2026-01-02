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
