(function () {
  "use strict";

  const stage = document.getElementById("stage");
  const progressEl = document.getElementById("progress");
  const slides = window.REETI_SLIDES || [];

  let index = 0;
  let revealed = false;
  let rapidTimerId = null;
  let rapidRemaining = 0;
  let helpVisible = false;

  const RAPID_SECONDS = 5;

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
    const slide = slides[index];
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
    revealed = false;

    const slide = slides[index];
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
      return;
    }
    // Click outside the help card dismisses the overlay
    if (helpVisible && e.target.id === "help-overlay") {
      closeHelp();
    }
  });

  buildHelpOverlay();
  render();
})();
