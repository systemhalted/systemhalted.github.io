(function () {
  "use strict";

  const SONGS = window.GAANA_SONGS || [];
  const SONG_BY_ID = new Map(SONGS.map((s) => [s.id, s]));
  const STORE_KEY = "gaana-pakdo:game";
  const app = document.getElementById("app");
  const help = document.getElementById("help");

  // Audio picked by the host lives only in memory: object URLs keyed by song id.
  const audioUrls = new Map();
  let audioEl = null;
  let playing = false;
  // Animate the prop only on the render that first reveals it.
  let animateReveal = false;

  let state = load() || freshState();

  function freshState(couples) {
    return {
      phase: "setup",
      couples: couples || [{ a: "", b: "" }],
      roundsPerCouple: 2,
      shuffle: true,
      rounds: [],
      current: 0,
      revealed: false,
    };
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (!raw) return null;
      const saved = JSON.parse(raw);
      if (!saved || !Array.isArray(saved.couples)) return null;
      return saved;
    } catch (_e) {
      return null;
    }
  }

  function save() {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(state));
    } catch (_e) {
      /* private mode or blocked storage: the game still works */
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  function el(tag, attrs, children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (value === undefined || value === null || value === false) continue;
      if (key === "class") node.className = value;
      else if (key === "text") node.textContent = value;
      else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value === true ? "" : value);
    }
    for (const child of [].concat(children || [])) {
      if (child === null || child === undefined || child === false) continue;
      node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return node;
  }

  function shuffled(list) {
    const copy = list.slice();
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  function name(couple, who, index) {
    const value = (couple[who] || "").trim();
    if (value) return value;
    return who === "a" ? `Partner A${index + 1}` : `Partner B${index + 1}`;
  }

  function coupleLabel(i) {
    const c = state.couples[i];
    return `${name(c, "a", i)} & ${name(c, "b", i)}`;
  }

  // Which partner stands on which side this round.
  function sides(round) {
    return round.swapped ? { left: "b", right: "a" } : { left: "a", right: "b" };
  }

  function tally(coupleIndex) {
    const score = { a: 0, b: 0 };
    for (const r of state.rounds) {
      if (r.couple === coupleIndex && (r.winner === "a" || r.winner === "b")) score[r.winner]++;
    }
    return score;
  }

  function songsNeeded() {
    return state.couples.length * state.roundsPerCouple;
  }

  function unusedSongs() {
    const used = new Set(state.rounds.map((r) => r.songId));
    return SONGS.filter((s) => !used.has(s.id));
  }

  function searchUrl(song) {
    const q = `${song.title} ${song.film} song`;
    return "https://www.youtube.com/results?search_query=" + encodeURIComponent(q);
  }

  // ─── Game flow ─────────────────────────────────────────────────────

  function startGame() {
    const bank = state.shuffle ? shuffled(SONGS) : SONGS.slice();
    const rounds = [];
    let s = 0;
    // Couples take turns: every couple plays once before anyone plays again.
    for (let turn = 0; turn < state.roundsPerCouple; turn++) {
      for (let c = 0; c < state.couples.length; c++) {
        rounds.push({ couple: c, songId: bank[s++].id, swapped: turn % 2 === 1, winner: null });
      }
    }
    state.rounds = rounds;
    state.current = 0;
    state.revealed = false;
    state.phase = "play";
    save();
    render();
  }

  function addTieBreaker(coupleIndex) {
    const spare = unusedSongs();
    if (!spare.length) return;
    const pick = spare[Math.floor(Math.random() * spare.length)];
    const previous = state.rounds.filter((r) => r.couple === coupleIndex).length;
    state.rounds.push({
      couple: coupleIndex,
      songId: pick.id,
      swapped: previous % 2 === 1,
      winner: null,
      tieBreaker: true,
    });
    goTo(state.rounds.length - 1);
  }

  function goTo(index) {
    stopSong();
    if (index >= state.rounds.length) {
      state.phase = "final";
    } else {
      state.phase = "play";
      state.current = Math.max(0, index);
      state.revealed = state.rounds[state.current].winner !== null;
    }
    save();
    render();
  }

  function setWinner(who) {
    if (state.phase !== "play") return;
    const round = state.rounds[state.current];
    round.winner = who;
    animateReveal = !state.revealed;
    state.revealed = true;
    save();
    render();
  }

  function reveal() {
    if (state.phase !== "play" || state.revealed) return;
    animateReveal = true;
    state.revealed = true;
    save();
    render();
  }

  // ─── Audio ─────────────────────────────────────────────────────────

  function currentSong() {
    const round = state.rounds[state.current];
    return round ? SONG_BY_ID.get(round.songId) : null;
  }

  function canPlay(song) {
    return !!(song && (audioUrls.has(song.id) || song.audio || song.youtube));
  }

  function playSong() {
    const song = currentSong();
    if (!canPlay(song)) return;
    stopSong();
    if (audioUrls.has(song.id) || song.audio) {
      audioEl = new Audio(audioUrls.get(song.id) || song.audio);
      audioEl.addEventListener("ended", () => {
        playing = false;
        render();
      });
      audioEl.play().catch(() => {
        playing = false;
        render();
      });
    }
    playing = true;
    render();
  }

  function stopSong() {
    if (audioEl) {
      audioEl.pause();
      audioEl = null;
    }
    playing = false;
  }

  function togglePlay() {
    if (playing) {
      stopSong();
      render();
    } else {
      playSong();
    }
  }

  function matchFiles(files) {
    let matched = 0;
    for (const file of files) {
      const base = file.name.toLowerCase().replace(/\.[^.]+$/, "");
      const song = SONGS.find((s) => base === s.id || base.includes(s.id));
      if (!song) continue;
      if (audioUrls.has(song.id)) URL.revokeObjectURL(audioUrls.get(song.id));
      audioUrls.set(song.id, URL.createObjectURL(file));
      matched++;
    }
    return matched;
  }

  function attachFile(song, file) {
    if (!file) return;
    if (audioUrls.has(song.id)) URL.revokeObjectURL(audioUrls.get(song.id));
    audioUrls.set(song.id, URL.createObjectURL(file));
    render();
  }

  // ─── Screens ───────────────────────────────────────────────────────

  function render() {
    app.replaceChildren();
    if (state.phase === "play") renderPlay();
    else if (state.phase === "final") renderFinal();
    else renderSetup();
    animateReveal = false;
  }

  function header(extra) {
    return el("header", { class: "topbar" }, [
      el("h1", { class: "brand" }, [
        el("span", { class: "brand-hi", lang: "hi", text: "गाना पकड़ो" }),
        el("span", { class: "brand-en", text: "Gaana Pakdo" }),
      ]),
      el("div", { class: "topbar-actions" }, [
        extra,
        el("button", { class: "btn ghost", onclick: showHelp, text: "How to play" }),
      ]),
    ]);
  }

  function renderSetup() {
    const needed = songsNeeded();
    const enough = needed <= SONGS.length;
    const matched = SONGS.filter((s) => audioUrls.has(s.id)).length;

    const coupleRows = state.couples.map((c, i) =>
      el("div", { class: "couple-row" }, [
        el("span", { class: "couple-num", text: `${i + 1}` }),
        el("input", {
          type: "text",
          value: c.a,
          placeholder: "Partner A",
          "aria-label": `Couple ${i + 1}, partner A`,
          oninput: (e) => {
            c.a = e.target.value;
            save();
          },
        }),
        el("span", { class: "amp", "aria-hidden": "true", text: "&" }),
        el("input", {
          type: "text",
          value: c.b,
          placeholder: "Partner B",
          "aria-label": `Couple ${i + 1}, partner B`,
          oninput: (e) => {
            c.b = e.target.value;
            save();
          },
        }),
        el("button", {
          class: "btn icon",
          "aria-label": `Remove couple ${i + 1}`,
          disabled: state.couples.length === 1,
          onclick: () => {
            state.couples.splice(i, 1);
            save();
            render();
          },
          text: "✕",
        }),
      ])
    );

    const propCards = SONGS.map((s) =>
      el("li", { class: "prop" }, [
        el("span", { class: "prop-emoji", "aria-hidden": "true", text: s.emoji }),
        el("span", { text: s.prop }),
      ])
    );

    const inProgress = state.rounds.length > 0;

    app.append(
      header(null),
      el("section", { class: "setup" }, [
        el("p", {
          class: "lede",
          text:
            "A Hindi film song plays. Every song names a prop. The first partner to grab it from the table wins the round.",
        }),

        inProgress &&
          el("div", { class: "panel resume" }, [
            el("p", { text: "A game is already in progress." }),
            el("button", {
              class: "btn",
              onclick: () => goTo(Math.min(state.current, state.rounds.length)),
              text: "Resume game",
            }),
          ]),

        el("div", { class: "panel" }, [
          el("h2", { text: "1. Couples" }),
          el("p", { class: "muted", text: "Partner A starts on the left side of the table, partner B on the right." }),
          el("div", { class: "couples" }, coupleRows),
          el("button", {
            class: "btn ghost",
            onclick: () => {
              state.couples.push({ a: "", b: "" });
              save();
              render();
              const inputs = app.querySelectorAll(".couple-row input");
              inputs[inputs.length - 2].focus();
            },
            text: "+ Add couple",
          }),
        ]),

        el("div", { class: "panel" }, [
          el("h2", { text: "2. Rounds" }),
          el("label", { class: "inline" }, [
            "Turns per couple ",
            el("input", {
              type: "number",
              min: "1",
              max: String(SONGS.length),
              value: String(state.roundsPerCouple),
              onchange: (e) => {
                const n = parseInt(e.target.value, 10);
                state.roundsPerCouple = Number.isFinite(n) && n > 0 ? n : 1;
                save();
                render();
              },
            }),
          ]),
          el("label", { class: "inline" }, [
            el("input", {
              type: "checkbox",
              checked: state.shuffle,
              onchange: (e) => {
                state.shuffle = e.target.checked;
                save();
              },
            }),
            " Shuffle song order",
          ]),
          el("p", { class: enough ? "muted" : "warn" }, [
            `${state.couples.length} couple${state.couples.length === 1 ? "" : "s"} × ${state.roundsPerCouple} turns = ${needed} songs. `,
            `The bank has ${SONGS.length}.`,
            !enough && " Remove a couple or lower the turns, or add songs to songs.js.",
          ]),
        ]),

        el("div", { class: "panel" }, [
          el("h2", { text: "3. Music" }),
          el("p", { class: "muted" }, [
            "Load your own audio files. Name each file after the song's key, for example ",
            el("code", { text: "jhumka.mp3" }),
            " or ",
            el("code", { text: "kajra.m4a" }),
            ". The keys are: ",
            SONGS.map((s) => s.id).join(", "),
            ". Without files, each round has a YouTube search link for the host's phone.",
          ]),
          el("label", { class: "btn ghost file" }, [
            "Choose audio files",
            el("input", {
              type: "file",
              accept: "audio/*",
              multiple: true,
              onchange: (e) => {
                matchFiles(e.target.files);
                render();
              },
            }),
          ]),
          el("p", {
            class: "muted",
            text: `${matched} of ${SONGS.length} songs have audio loaded.`,
          }),
        ]),

        el("div", { class: "panel" }, [
          el("h2", { text: "4. Props on the table" }),
          el("p", {
            class: "muted",
            text: "Put all of these on the table for every round. The extra props are decoys.",
          }),
          el("ul", { class: "props" }, propCards),
        ]),

        el("div", { class: "start-row" }, [
          el("button", {
            class: "btn big",
            disabled: !enough,
            onclick: startGame,
            text: inProgress ? "Start a new game" : "Start the game",
          }),
        ]),
      ])
    );
  }

  function playerCard(round, side) {
    const couple = state.couples[round.couple];
    const who = sides(round)[side];
    const score = tally(round.couple)[who];
    const won = round.winner === who;
    return el(
      "button",
      {
        class: `player ${side}${won ? " won" : ""}${round.winner && !won ? " lost" : ""}`,
        "aria-pressed": won ? "true" : "false",
        onclick: () => setWinner(who),
      },
      [
        el("span", { class: "player-side", text: side === "left" ? "Left side" : "Right side" }),
        el("span", { class: "player-name", text: name(couple, who, round.couple) }),
        el("span", { class: "player-score", text: `${score} ${score === 1 ? "win" : "wins"}` }),
        el("span", { class: "player-action", text: won ? "Grabbed it first!" : "Grabbed it first" }),
      ]
    );
  }

  function renderPlay() {
    const round = state.rounds[state.current];
    const song = SONG_BY_ID.get(round.songId);
    const couple = state.couples[round.couple];
    const turnNumber = state.rounds.slice(0, state.current + 1).filter((r) => r.couple === round.couple).length;

    const progress = el("span", {
      class: "progress",
      text: `Round ${state.current + 1} of ${state.rounds.length}`,
    });

    let audioBlock;
    if (song.youtube && playing) {
      const start = song.start ? `&start=${encodeURIComponent(song.start)}` : "";
      audioBlock = el("div", { class: "yt" }, [
        el("iframe", {
          src: `https://www.youtube-nocookie.com/embed/${encodeURIComponent(song.youtube)}?autoplay=1&controls=0${start}`,
          allow: "autoplay; encrypted-media",
          title: "Song player",
        }),
        el("div", { class: "yt-cover", "aria-hidden": "true", text: "♪ Now playing ♪" }),
      ]);
    }

    const playControls = el("div", { class: "play-controls" }, [
      canPlay(song)
        ? el("button", {
            class: `btn big${playing ? " playing" : ""}`,
            onclick: togglePlay,
            text: playing ? "■ Stop" : "▶ Play song",
          })
        : el("p", { class: "muted", text: "No audio loaded for this song." }),
      el("div", { class: "audio-tools" }, [
        el("label", { class: "btn ghost small file" }, [
          canPlay(song) ? "Replace audio" : "Choose audio file",
          el("input", {
            type: "file",
            accept: "audio/*",
            onchange: (e) => attachFile(song, e.target.files[0]),
          }),
        ]),
        el("a", {
          class: "btn ghost small",
          href: searchUrl(song),
          target: "_blank",
          rel: "noopener noreferrer",
          title: "Opens a new tab that shows the song title. Use it on the host's phone if the screen is shared.",
          text: "Find on YouTube ↗",
        }),
      ]),
      audioBlock,
    ]);

    const revealBlock = state.revealed
      ? el("div", { class: animateReveal ? "reveal pop" : "reveal" }, [
          el("div", { class: "reveal-emoji", "aria-hidden": "true", text: song.emoji }),
          el("div", { class: "reveal-prop", text: song.prop }),
          el("div", { class: "reveal-song" }, [
            el("strong", { text: song.title }),
            ` · ${song.film} (${song.year})`,
          ]),
          el("p", { class: "reveal-hint", text: song.hint }),
        ])
      : el("div", { class: "mystery" }, [
          el("div", { class: "mystery-mark", "aria-hidden": "true", text: "?" }),
          el("button", { class: "btn ghost", onclick: reveal, text: "Reveal the prop" }),
        ]);

    const isLast = state.current === state.rounds.length - 1;

    app.append(
      header(progress),
      el("section", { class: "round" }, [
        el("div", { class: "round-head" }, [
          el("p", { class: "kicker" }, [
            round.tieBreaker ? "Tie-breaker · " : "",
            `Couple ${round.couple + 1} · turn ${turnNumber}`,
          ]),
          el("h2", { class: "couple-title", text: coupleLabel(round.couple) }),
          round.swapped &&
            turnNumber > 1 &&
            el("p", { class: "notice", text: "Switch sides of the table for this turn." }),
        ]),
        el("div", { class: "table" }, [
          playerCard(round, "left"),
          el("div", { class: "center" }, [
            el("p", { class: "song-num", text: `Song ${state.current + 1}` }),
            playControls,
            revealBlock,
          ]),
          playerCard(round, "right"),
        ]),
        el("div", { class: "round-foot" }, [
          el("button", {
            class: "btn ghost",
            disabled: state.current === 0,
            onclick: () => goTo(state.current - 1),
            text: "← Previous",
          }),
          el("button", {
            class: `btn ghost${round.winner === "none" ? " active" : ""}`,
            onclick: () => setWinner("none"),
            text: "Nobody got it",
          }),
          el("button", {
            class: "btn",
            disabled: round.winner === null,
            onclick: () => goTo(state.current + 1),
            text: isLast ? "See results →" : "Next round →",
          }),
        ]),
        el("p", { class: "muted small center-text" }, [
          `${name(couple, "a", round.couple)} ${tally(round.couple).a} – ${tally(round.couple).b} ${name(couple, "b", round.couple)}`,
          " · ",
          el("button", { class: "linkish", onclick: () => endEarly(), text: "End game" }),
        ]),
      ])
    );
  }

  function endEarly() {
    if (!window.confirm("End the game now and show the results?")) return;
    goTo(state.rounds.length);
  }

  function renderFinal() {
    const spare = unusedSongs().length;

    const coupleResults = state.couples.map((c, i) => {
      const t = tally(i);
      const tied = t.a === t.b;
      const leader = t.a > t.b ? name(c, "a", i) : name(c, "b", i);
      return el("li", { class: `result${tied ? " tied" : ""}` }, [
        el("div", { class: "result-score" }, [
          el("span", { class: t.a > t.b ? "lead" : "", text: name(c, "a", i) }),
          el("strong", { text: ` ${t.a} – ${t.b} ` }),
          el("span", { class: t.b > t.a ? "lead" : "", text: name(c, "b", i) }),
        ]),
        el("div", { class: "result-verdict" }, [
          tied ? "Tied." : `${leader} wins.`,
          tied &&
            (spare
              ? el("button", {
                  class: "btn small",
                  onclick: () => addTieBreaker(i),
                  text: "Play a tie-breaker",
                })
              : el("span", { class: "muted", text: " No spare songs left for a tie-breaker." })),
        ]),
      ]);
    });

    const players = [];
    state.couples.forEach((c, i) => {
      const t = tally(i);
      players.push({ who: name(c, "a", i), wins: t.a });
      players.push({ who: name(c, "b", i), wins: t.b });
    });
    players.sort((x, y) => y.wins - x.wins);
    const top = players.length ? players[0].wins : 0;

    app.append(
      header(null),
      el("section", { class: "final" }, [
        el("h2", { class: "final-title", text: "Results" }),
        el("ul", { class: "results" }, coupleResults),
        state.couples.length > 1 &&
          el("div", { class: "panel" }, [
            el("h3", { text: "Fastest hands overall" }),
            el(
              "ol",
              { class: "leaderboard" },
              players.map((p) =>
                el("li", { class: p.wins === top && top > 0 ? "top" : "" }, [
                  el("span", { text: p.who }),
                  el("span", { text: `${p.wins}` }),
                ])
              )
            ),
          ]),
        el("div", { class: "start-row" }, [
          el("button", {
            class: "btn ghost",
            onclick: () => goTo(state.rounds.length - 1),
            text: "← Back to last round",
          }),
          el("button", {
            class: "btn",
            onclick: () => {
              state = freshState(state.couples);
              save();
              render();
            },
            text: "New game, same couples",
          }),
          el("button", {
            class: "btn ghost",
            onclick: () => {
              state = freshState();
              save();
              render();
            },
            text: "Start over",
          }),
        ]),
      ])
    );
  }

  // ─── Help, fullscreen, keys ────────────────────────────────────────

  function showHelp() {
    help.hidden = false;
    help.querySelector("button").focus();
  }

  function hideHelp() {
    help.hidden = true;
  }

  help.addEventListener("click", (e) => {
    if (e.target === help || e.target.closest("[data-action='close-help']")) hideHelp();
  });

  function toggleFullscreen() {
    if (document.fullscreenElement) document.exitFullscreen();
    else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen();
  }

  document.addEventListener("keydown", (e) => {
    if (e.target.closest("input, textarea, select")) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;

    if (!help.hidden) {
      if (e.key === "Escape" || e.key === "?") hideHelp();
      return;
    }
    if (e.key === "?") return showHelp();
    if (e.key === "f" || e.key === "F") return toggleFullscreen();
    if (state.phase !== "play") return;

    const round = state.rounds[state.current];
    const onButton = e.target.closest("button, a");
    switch (e.key) {
      case " ":
        if (onButton) return;
        e.preventDefault();
        reveal();
        break;
      case "p":
      case "P":
        togglePlay();
        break;
      case "ArrowLeft":
        setWinner(sides(round).left);
        break;
      case "ArrowRight":
        setWinner(sides(round).right);
        break;
      case "0":
        setWinner("none");
        break;
      case "Enter":
        if (onButton) return;
        if (round.winner !== null) goTo(state.current + 1);
        break;
      case "Backspace":
        e.preventDefault();
        if (state.current > 0) goTo(state.current - 1);
        break;
    }
  });

  // A saved game whose songs were removed from songs.js cannot resume.
  if (state.rounds.some((r) => !SONG_BY_ID.has(r.songId))) {
    state = freshState(state.couples);
  }
  render();
})();
