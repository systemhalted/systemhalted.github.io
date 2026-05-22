(function () {
  "use strict";

  const stage = document.getElementById("stage");
  const progressEl = document.getElementById("progress");
  const slides = window.REETI_SLIDES || [];

  let index = 0;
  let revealed = false;
  let rapidTimerId = null;
  let rapidRemaining = 0;
  let autoTimerId = null;
  let hasInteracted = false;
  let helpVisible = false;
  let editVisible = false;

  const RAPID_SECONDS = 5;
  const EDITS_KEY = "reeti-40:edits";
  // Field order used when serializing slides for export — matches questions.js layout.
  const KEY_ORDER = ["type", "kicker", "q", "choices", "answer", "sub", "vs", "note", "source"];

  let edits = loadEdits();

  function loadEdits() {
    try {
      const raw = localStorage.getItem(EDITS_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (_e) {
      return {};
    }
  }

  function persistEdits() {
    try {
      localStorage.setItem(EDITS_KEY, JSON.stringify(edits));
    } catch (_e) {
      /* quota / private mode — ignore */
    }
  }

  function getSlide(i) {
    const base = slides[i];
    if (!base) return null;
    return edits[i] ? { ...base, ...edits[i] } : base;
  }

  function equalDeep(a, b) {
    if (a === b) return true;
    if (Array.isArray(a) && Array.isArray(b)) {
      if (a.length !== b.length) return false;
      return a.every((x, i) => equalDeep(x, b[i]));
    }
    return JSON.stringify(a) === JSON.stringify(b);
  }

  // Section markers — anything the host might want to jump to directly.
  // Derived from the slide array so reordering questions.js keeps shortcuts correct.
  const SECTION_TYPES = new Set(["title", "divider", "gag", "finale"]);
  const sections = slides
    .map((s, i) => ({ slide: s, index: i }))
    .filter(({ slide }) => SECTION_TYPES.has(slide.type))
    .map(({ slide, index: i }) => ({
      index: i,
      label: slide.q,
      kicker: slide.kicker || "",
    }));

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function letter(i) {
    return ["A", "B", "C", "D", "E", "F"][i] || String(i + 1);
  }

  function clearAutoTimer() {
    if (autoTimerId !== null) {
      clearTimeout(autoTimerId);
      autoTimerId = null;
    }
  }

  function clearRapidTimer() {
    if (rapidTimerId !== null) {
      clearInterval(rapidTimerId);
      rapidTimerId = null;
    }
  }

  function renderTriviaCount() {
    const triviaTypes = new Set(["mcq", "tf"]);
    let triviaIdx = 0;
    let triviaTotal = 0;
    slides.forEach((s, i) => {
      if (triviaTypes.has(s.type)) {
        triviaTotal++;
        if (i <= index) triviaIdx++;
      }
    });
    return { triviaIdx, triviaTotal };
  }

  function updateProgress() {
    const slide = getSlide(index);
    if (!slide) {
      progressEl.textContent = "—";
      return;
    }
    if (slide.type === "mcq" || slide.type === "tf") {
      const { triviaIdx, triviaTotal } = renderTriviaCount();
      progressEl.textContent = `Question ${triviaIdx} of ${triviaTotal}`;
    } else if (slide.type === "rapid") {
      progressEl.textContent = "Rapid Fire";
    } else if (slide.type === "savage") {
      progressEl.textContent = "Extra Savage";
    } else if (slide.type === "divider") {
      progressEl.textContent = slide.kicker || "—";
    } else if (slide.type === "title") {
      progressEl.textContent = "Welcome";
    } else if (slide.type === "gag") {
      progressEl.textContent = "Population Gag";
    } else if (slide.type === "finale") {
      progressEl.textContent = "Finale";
    } else {
      progressEl.textContent = "—";
    }
    if (edits[index]) progressEl.textContent += " · edited";
  }

  function renderSourceLink(source) {
    if (!source) return "";
    return `<small class="reveal-source">Source: <a href="${escapeHtml(
      source,
    )}" target="_blank" rel="noopener">${escapeHtml(source)}</a></small>`;
  }

  function renderMcq(slide) {
    const choicesHtml = slide.choices
      .map(
        (c, i) =>
          `<li data-choice="${i}"><span class="letter">${letter(i)}</span><span>${escapeHtml(
            c,
          )}</span></li>`,
      )
      .join("");
    return `
      <article class="slide mcq" data-type="mcq">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "1986 Trivia")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        <ul class="choices">${choicesHtml}</ul>
        <button class="reveal-btn" data-action="reveal">Reveal answer</button>
        <div class="reveal">
          <div class="reveal-inner">
            <span class="reveal-answer">Answer: ${letter(slide.answer)} — ${escapeHtml(
              slide.choices[slide.answer],
            )}</span>
            ${slide.note ? escapeHtml(slide.note) : ""}
            ${renderSourceLink(slide.source)}
          </div>
        </div>
      </article>
    `;
  }

  function renderTf(slide) {
    return `
      <article class="slide tf" data-type="tf">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "True or False")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        <div class="tf-options">
          <span class="tf-btn" data-tf="true">True</span>
          <span class="tf-btn" data-tf="false">False</span>
        </div>
        <button class="reveal-btn" data-action="reveal">Reveal answer</button>
        <div class="reveal">
          <div class="reveal-inner">
            <span class="reveal-answer">${slide.answer ? "TRUE" : "FALSE"}</span>
            ${slide.note ? escapeHtml(slide.note) : ""}
            ${renderSourceLink(slide.source)}
          </div>
        </div>
      </article>
    `;
  }

  function renderDivider(slide) {
    return `
      <article class="slide divider" data-type="divider">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "Next Round")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        ${slide.sub ? `<p class="slide-sub">${escapeHtml(slide.sub)}</p>` : ""}
      </article>
    `;
  }

  function renderTitle(slide) {
    return `
      <article class="slide title" data-type="title">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "Happy Birthday")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        ${slide.sub ? `<p class="slide-sub">${escapeHtml(slide.sub)}</p>` : ""}
      </article>
    `;
  }

  function renderGag(slide) {
    return `
      <article class="slide gag" data-type="gag">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "The Population Gag")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        <div class="gag-numbers">
          <span>World population in 1986:</span>
          <span>4,999,999,999</span>
          <span class="arrow">↓</span>
          <span>Reeti was born</span>
          <span class="arrow">↓</span>
          <span>5,000,000,000</span>
        </div>
        <p class="gag-punch">Officially, she's why we hit 5 billion.</p>
      </article>
    `;
  }

  function renderRapid(slide) {
    return `
      <article class="slide rapid" data-type="rapid">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "Rapid Fire — pick one!")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        ${
          slide.vs
            ? `<p class="rapid-vs">${escapeHtml(slide.vs)}</p>`
            : ""
        }
        <span class="rapid-timer" id="rapid-timer">—</span>
      </article>
    `;
  }

  function renderSavage(slide) {
    return `
      <article class="slide savage" data-type="savage">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "Extra Savage")}</span>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
      </article>
    `;
  }

  function renderPhoto(slide) {
    return `
      <article class="slide photo" data-type="photo">
        <img src="${escapeHtml(slide.src || "")}" alt="${escapeHtml(slide.alt || "")}">
      </article>
    `;
  }

  function renderCollage(slide) {
    const imgs = (slide.images || [])
      .map(
        (img) =>
          `<img src="${escapeHtml(img.src || "")}" alt="${escapeHtml(img.alt || "")}" loading="lazy">`,
      )
      .join("");
    const count = (slide.images || []).length;
    return `
      <article class="slide collage" data-type="collage" data-count="${count}">
        <div class="collage-grid">${imgs}</div>
      </article>
    `;
  }

  function renderFinale(slide) {
    return `
      <article class="slide finale" data-type="finale">
        <span class="slide-kicker">${escapeHtml(slide.kicker || "Happy 40th")}</span>
        <div class="finale-cake" aria-hidden="true">🎂</div>
        <h2 class="slide-q">${escapeHtml(slide.q)}</h2>
        ${slide.sub ? `<p class="slide-sub">${escapeHtml(slide.sub)}</p>` : ""}
      </article>
    `;
  }

  function render() {
    clearRapidTimer();
    clearAutoTimer();
    revealed = false;

    const slide = getSlide(index);
    if (!slide) {
      stage.innerHTML = '<article class="slide"><h2 class="slide-q">No slides loaded.</h2></article>';
      return;
    }

    let html;
    switch (slide.type) {
      case "mcq": html = renderMcq(slide); break;
      case "tf": html = renderTf(slide); break;
      case "divider": html = renderDivider(slide); break;
      case "title": html = renderTitle(slide); break;
      case "gag": html = renderGag(slide); break;
      case "rapid": html = renderRapid(slide); break;
      case "savage": html = renderSavage(slide); break;
      case "finale": html = renderFinale(slide); break;
      case "photo": html = renderPhoto(slide); break;
      case "collage": html = renderCollage(slide); break;
      default: html = renderDivider(slide); break;
    }

    stage.innerHTML = html;

    // Apply correct-highlight classes (visible after reveal)
    if (slide.type === "mcq") {
      const li = stage.querySelector(`.choices li[data-choice="${slide.answer}"]`);
      if (li) li.classList.add("correct");
    }
    if (slide.type === "tf") {
      const correctValue = slide.answer ? "true" : "false";
      const btn = stage.querySelector(`.tf-btn[data-tf="${correctValue}"]`);
      if (btn) btn.classList.add("correct");
    }

    if (hasInteracted && typeof slide.autoplayMs === "number" && slide.autoplayMs > 0) {
      autoTimerId = setTimeout(() => {
        autoTimerId = null;
        next();
      }, slide.autoplayMs);
    }

    updateProgress();
  }

  function reveal() {
    const slideEl = stage.querySelector(".slide");
    if (!slideEl) return;
    const type = slideEl.dataset.type;
    if (type !== "mcq" && type !== "tf") return;
    slideEl.classList.add("revealed");
    revealed = true;
  }

  function next() {
    hasInteracted = true;
    const slide = slides[index];
    const isTrivia = slide && (slide.type === "mcq" || slide.type === "tf");

    if (isTrivia && !revealed) {
      reveal();
      return;
    }

    if (index < slides.length - 1) {
      index++;
      render();
    }
  }

  function back() {
    hasInteracted = true;
    if (index > 0) {
      index--;
      render();
    }
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen?.().catch(() => {});
    } else {
      document.exitFullscreen?.();
    }
  }

  function jumpToSection(n) {
    if (n < 1 || n > sections.length) return;
    hasInteracted = true;
    index = sections[n - 1].index;
    render();
  }

  function buildHelpOverlay() {
    const overlay = document.getElementById("help-overlay");
    if (!overlay) return;
    const rows = sections
      .map(
        (s, i) =>
          `<tr><td><kbd>${i + 1}</kbd></td><td>${escapeHtml(s.label)}</td></tr>`,
      )
      .join("");
    overlay.innerHTML = `
      <div class="help-card" role="dialog" aria-labelledby="help-title">
        <h2 id="help-title">Keyboard shortcuts</h2>
        <h3>Navigation</h3>
        <table class="help-table">
          <tr><td><kbd>←</kbd></td><td>Previous slide</td></tr>
          <tr><td><kbd>→</kbd> or <kbd>Space</kbd></td><td>Reveal answer / next slide</td></tr>
          <tr><td><kbd>E</kbd></td><td>Edit current slide</td></tr>
          <tr><td><kbd>R</kbd></td><td>Start rapid-fire timer</td></tr>
          <tr><td><kbd>F</kbd></td><td>Toggle fullscreen</td></tr>
          <tr><td><kbd>?</kbd> or <kbd>Esc</kbd></td><td>Show / hide this help</td></tr>
        </table>
        <h3>Jump to a section</h3>
        <table class="help-table">${rows}</table>
        <button class="help-close" data-action="close-help">Close</button>
      </div>
    `;
  }

  function openHelp() {
    const overlay = document.getElementById("help-overlay");
    if (!overlay) return;
    overlay.hidden = false;
    helpVisible = true;
  }

  function closeHelp() {
    const overlay = document.getElementById("help-overlay");
    if (!overlay) return;
    overlay.hidden = true;
    helpVisible = false;
  }

  function toggleHelp() {
    if (helpVisible) closeHelp();
    else openHelp();
  }

  // ─── Edit overlay ─────────────────────────────────────────────────
  function editField(name, label, value, opts) {
    const o = opts || {};
    const v = value == null ? "" : value;
    if (o.textarea) {
      return `
        <label class="edit-field">
          <span class="edit-field-label">${label}</span>
          <textarea class="edit-input" data-field="${name}" rows="${o.rows || 2}">${escapeHtml(v)}</textarea>
        </label>
      `;
    }
    return `
      <label class="edit-field">
        <span class="edit-field-label">${label}</span>
        <input type="text" class="edit-input" data-field="${name}" value="${escapeHtml(v)}">
      </label>
    `;
  }

  function renderEditFields(slide) {
    const t = slide.type;
    if (t === "mcq") {
      const choices = (slide.choices || []).slice(0, 4);
      while (choices.length < 4) choices.push("");
      const choiceFields = choices
        .map((c, i) => editField(`choices.${i}`, `Choice ${letter(i)}`, c))
        .join("");
      const answerRadios = choices
        .map(
          (c, i) => `
        <label class="edit-radio">
          <input type="radio" name="answer" data-field="answer" value="${i}" ${
            i === slide.answer ? "checked" : ""
          }>
          <span>${letter(i)} — ${escapeHtml(c)}</span>
        </label>
      `,
        )
        .join("");
      return `
        ${editField("kicker", "Kicker", slide.kicker)}
        ${editField("q", "Question", slide.q, { textarea: true, rows: 2 })}
        <div class="edit-group">
          <span class="edit-field-label">Choices</span>
          ${choiceFields}
        </div>
        <div class="edit-group">
          <span class="edit-field-label">Correct answer</span>
          ${answerRadios}
        </div>
        ${editField("note", "Note", slide.note, { textarea: true, rows: 3 })}
        ${editField("source", "Source URL", slide.source)}
      `;
    }
    if (t === "tf") {
      return `
        ${editField("kicker", "Kicker", slide.kicker)}
        ${editField("q", "Statement", slide.q, { textarea: true, rows: 2 })}
        <div class="edit-group">
          <span class="edit-field-label">Correct answer</span>
          <label class="edit-radio">
            <input type="radio" name="answer" data-field="answer" value="true" ${
              slide.answer ? "checked" : ""
            }>
            <span>TRUE</span>
          </label>
          <label class="edit-radio">
            <input type="radio" name="answer" data-field="answer" value="false" ${
              !slide.answer ? "checked" : ""
            }>
            <span>FALSE</span>
          </label>
        </div>
        ${editField("note", "Note", slide.note, { textarea: true, rows: 3 })}
        ${editField("source", "Source URL", slide.source)}
      `;
    }
    if (t === "rapid" || t === "savage") {
      return editField("q", "Question", slide.q, { textarea: true, rows: 2 });
    }
    if (t === "gag") {
      return `
        ${editField("kicker", "Kicker", slide.kicker)}
        ${editField("q", "Heading", slide.q)}
        <p class="edit-export-hint">The population numbers and punchline below are hardcoded in the slide template, not editable here.</p>
      `;
    }
    // title / divider / finale
    return `
      ${editField("kicker", "Kicker", slide.kicker)}
      ${editField("q", "Heading", slide.q)}
      ${editField("sub", "Subhead", slide.sub)}
    `;
  }

  function orderKeys(obj) {
    const out = {};
    KEY_ORDER.forEach((k) => {
      if (k in obj) out[k] = obj[k];
    });
    Object.keys(obj).forEach((k) => {
      if (!(k in out)) out[k] = obj[k];
    });
    return out;
  }

  function buildExportText() {
    const merged = slides.map((s, i) => orderKeys({ ...s, ...(edits[i] || {}) }));
    return `window.REETI_SLIDES = ${JSON.stringify(merged, null, 2)};\n`;
  }

  function openEdit() {
    const overlay = document.getElementById("edit-overlay");
    if (!overlay) return;
    const slide = getSlide(index);
    if (!slide) return;
    overlay.innerHTML = `
      <div class="edit-card" role="dialog" aria-labelledby="edit-title">
        <header class="edit-header">
          <h2 id="edit-title">Edit slide ${index + 1} of ${slides.length}</h2>
          <span class="edit-type-badge">${escapeHtml(slide.type)}</span>
        </header>
        <form class="edit-form" onsubmit="return false;">
          ${renderEditFields(slide)}
        </form>
        <div class="edit-actions">
          <button type="button" class="edit-btn edit-btn-primary" data-action="edit-save">Save (⌘S)</button>
          ${
            edits[index]
              ? '<button type="button" class="edit-btn edit-btn-danger" data-action="edit-discard">Discard this slide\'s edits</button>'
              : ""
          }
          <button type="button" class="edit-btn" data-action="edit-close">Close</button>
        </div>
        <details class="edit-export">
          <summary>Export all edits as JSON</summary>
          <p class="edit-export-hint">Copy this and paste into <code>jsgames/reeti-40/questions.js</code> to commit edits back to the repo.</p>
          <textarea class="edit-export-text" readonly rows="14">${escapeHtml(buildExportText())}</textarea>
          <div class="edit-actions">
            <button type="button" class="edit-btn edit-btn-primary" data-action="edit-copy">Copy to clipboard</button>
            <button type="button" class="edit-btn edit-btn-danger" data-action="edit-clear-all">Clear all local edits</button>
            <span class="edit-copy-status" id="edit-copy-status" aria-live="polite"></span>
          </div>
        </details>
      </div>
    `;
    overlay.hidden = false;
    editVisible = true;
    const firstInput = overlay.querySelector("input[type=text], textarea");
    if (firstInput) firstInput.focus();
  }

  function closeEdit() {
    const overlay = document.getElementById("edit-overlay");
    if (!overlay) return;
    overlay.hidden = true;
    editVisible = false;
  }

  function saveSlideEdits() {
    const overlay = document.getElementById("edit-overlay");
    if (!overlay) return;
    const form = overlay.querySelector(".edit-form");
    if (!form) return;
    const baseline = slides[index];
    if (!baseline) return;
    const next = { ...baseline };

    form.querySelectorAll("[data-field]").forEach((el) => {
      const path = el.dataset.field;
      if (el.type === "radio" && !el.checked) return;
      let value = el.value;
      if (path === "answer" && baseline.type === "tf") {
        value = value === "true";
      } else if (path === "answer" && baseline.type === "mcq") {
        value = parseInt(value, 10);
      }
      if (path.startsWith("choices.")) {
        const idx = parseInt(path.split(".")[1], 10);
        if (!Array.isArray(next.choices)) next.choices = [...(baseline.choices || [])];
        else next.choices = [...next.choices];
        next.choices[idx] = value;
      } else {
        // Drop empty strings for optional fields so they don't override absent baselines
        if (value === "" && !(path in baseline)) return;
        next[path] = value;
      }
    });

    const diff = {};
    Object.keys(next).forEach((k) => {
      if (!equalDeep(next[k], baseline[k])) diff[k] = next[k];
    });

    if (Object.keys(diff).length === 0) delete edits[index];
    else edits[index] = diff;

    persistEdits();
    closeEdit();
    render();
  }

  function discardSlideEdits() {
    delete edits[index];
    persistEdits();
    closeEdit();
    render();
  }

  function copyExportToClipboard() {
    const overlay = document.getElementById("edit-overlay");
    if (!overlay) return;
    const textarea = overlay.querySelector(".edit-export-text");
    const status = overlay.querySelector("#edit-copy-status");
    if (!textarea) return;
    const flash = (msg) => {
      if (!status) return;
      status.textContent = msg;
      setTimeout(() => {
        if (status) status.textContent = "";
      }, 2000);
    };
    const fallback = () => {
      textarea.select();
      try {
        document.execCommand("copy");
        flash("Copied!");
      } catch (_e) {
        flash("Select and copy manually.");
      }
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(textarea.value).then(() => flash("Copied!"), fallback);
    } else {
      fallback();
    }
  }

  function clearAllEdits() {
    if (Object.keys(edits).length === 0) return;
    if (!confirm("Discard ALL local edits across every slide? This can't be undone.")) return;
    edits = {};
    persistEdits();
    closeEdit();
    render();
  }

  function startRapidTimer() {
    const timerEl = document.getElementById("rapid-timer");
    if (!timerEl) return;
    clearRapidTimer();
    rapidRemaining = RAPID_SECONDS;
    timerEl.textContent = rapidRemaining;
    timerEl.classList.remove("expired");
    rapidTimerId = setInterval(() => {
      rapidRemaining--;
      if (rapidRemaining <= 0) {
        timerEl.textContent = "0";
        timerEl.classList.add("expired");
        clearRapidTimer();
      } else {
        timerEl.textContent = rapidRemaining;
      }
    }, 1000);
  }

  // Keyboard
  document.addEventListener("keydown", (e) => {
    // When the edit overlay is open, let form inputs receive keys naturally.
    // Only Escape (close) and ⌘/Ctrl+S (save) are intercepted.
    if (editVisible) {
      if (e.key === "Escape") {
        e.preventDefault();
        closeEdit();
      } else if ((e.key === "s" || e.key === "S") && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        saveSlideEdits();
      }
      return;
    }

    if (e.key === "ArrowRight" || e.key === " " || e.key === "Spacebar") {
      e.preventDefault();
      next();
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      back();
    } else if (e.key === "r" || e.key === "R") {
      e.preventDefault();
      startRapidTimer();
    } else if (e.key === "f" || e.key === "F") {
      e.preventDefault();
      toggleFullscreen();
    } else if (e.key === "e" || e.key === "E") {
      e.preventDefault();
      openEdit();
    } else if (e.key === "?" || (e.key === "/" && e.shiftKey)) {
      e.preventDefault();
      toggleHelp();
    } else if (e.key === "Escape" && helpVisible) {
      e.preventDefault();
      closeHelp();
    } else if (/^[1-9]$/.test(e.key)) {
      e.preventDefault();
      jumpToSection(parseInt(e.key, 10));
    }
  });

  // Touch / click
  document.addEventListener("click", (e) => {
    const target = e.target.closest("[data-action]");
    if (target) {
      const action = target.dataset.action;
      if (action === "next") next();
      else if (action === "back") back();
      else if (action === "reveal") reveal();
      else if (action === "close-help") closeHelp();
      else if (action === "toggle-help") toggleHelp();
      else if (action === "edit-save") saveSlideEdits();
      else if (action === "edit-discard") discardSlideEdits();
      else if (action === "edit-close") closeEdit();
      else if (action === "edit-copy") copyExportToClipboard();
      else if (action === "edit-clear-all") clearAllEdits();
      return;
    }
    if (helpVisible && e.target.id === "help-overlay") closeHelp();
    if (editVisible && e.target.id === "edit-overlay") closeEdit();
  });

  buildHelpOverlay();
  render();
})();
