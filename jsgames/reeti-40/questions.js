/*
 * Reeti @ 40 — slide deck content.
 *
 * Edit the array below to change questions, reorder rounds, etc. Each slide
 * is one object. The `type` field decides how it's rendered (see script.js).
 *
 * Types:
 *   title    — opening card
 *   divider  — round opener
 *   mcq      — multiple choice; `answer` is the index into `choices`
 *   tf       — true/false; `answer` is boolean
 *   gag      — the population gag
 *   rapid    — rapid-fire "pick one" personal question
 *   savage   — closing savage question
 *   finale   — closing card
 *
 * Trivia facts were verified via web search (see source URLs). If anything
 * looks wrong, click through to the source before changing the answer.
 */

window.REETI_SLIDES = [
  // ─── Opening ──────────────────────────────────────────────────────
  {
    type: "title",
    kicker: "June 8, 2026 · Happy Birthday",
    q: "Reeti @ 40",
    sub: "15 trivia questions, then a roast — Limited Edition since 1986",
  },

  // ─── Round 1: Reeti's Class of '86 ────────────────────────────────
  {
    type: "divider",
    kicker: "Round 1 of 3",
    q: "Reeti's Class of '86",
    sub: "People and things that also turn 40 this year.",
  },
  {
    type: "tf",
    kicker: "Round 1 · Class of '86",
    q: "Lady Gaga, Drake, and Robert Pattinson were all born in 1986.",
    answer: true,
    note: "Gaga: March 28 · Pattinson: May 13 · Drake: October 24. (Also: Emilia Clarke, Lindsay Lohan, the Olsen twins.)",
    source: "https://en.wikipedia.org/wiki/1986",
  },
  {
    type: "tf",
    kicker: "Round 1 · Class of '86",
    q: "Rafael Nadal was born five days before Reeti.",
    answer: true,
    note: "June 3, 1986 — Reeti June 8, 1986. He's older by exactly five days.",
    source: "https://en.wikipedia.org/wiki/Rafael_Nadal",
  },
  {
    type: "tf",
    kicker: "Round 1 · Class of '86",
    q: "Pixar was founded the year Reeti was born — Steve Jobs paid $5 million to George Lucas for it.",
    answer: true,
    note: "February 3, 1986. Best $5M anyone ever spent.",
    source: "https://en.wikipedia.org/wiki/Pixar",
  },
  {
    type: "mcq",
    kicker: "Round 1 · Class of '86",
    q: "Which of these also turn 40 this year with Reeti?",
    choices: [
      "Microsoft (as a public company)",
      "The Oprah Winfrey Show",
      "Pixar",
      "All of the above",
    ],
    answer: 3,
    note: "Microsoft IPO March 13, 1986 at $21/share · Oprah went national September 8, 1986 · Pixar founded February 3, 1986.",
    source: "https://en.wikipedia.org/wiki/1986",
  },
  {
    type: "tf",
    kicker: "Round 1 · Class of '86",
    q: "The Statue of Liberty turned 100 in 1986 — making Reeti exactly 40 years younger than its centennial.",
    answer: true,
    note: "'Liberty Weekend,' July 3–6, 1986. Reagan rededicated the restored statue.",
    source: "https://en.wikipedia.org/wiki/Liberty_Weekend",
  },

  // ─── Round 2: Is This 1986? (Trap T/F) ────────────────────────────
  {
    type: "divider",
    kicker: "Round 2 of 3",
    q: "Is This 1986?",
    sub: "Everyone confidently misremembers years. True or false?",
  },
  {
    type: "tf",
    kicker: "Round 2 · Is This 1986?",
    q: "Mr. India released in 1986.",
    answer: false,
    note: "May 25, 1987. Sorry — Mogambo only turns 39 this year.",
    source: "https://en.wikipedia.org/wiki/Mr._India_(1987_film)",
  },
  {
    type: "tf",
    kicker: "Round 2 · Is This 1986?",
    q: "Qayamat Se Qayamat Tak — Aamir Khan's debut as a leading man — came out in 1986.",
    answer: false,
    note: "April 29, 1988. QSQT is two years younger than Reeti.",
    source: "https://en.wikipedia.org/wiki/Qayamat_Se_Qayamat_Tak",
  },
  {
    type: "tf",
    kicker: "Round 2 · Is This 1986?",
    q: "Madonna's 'Like a Virgin' topped charts in 1986.",
    answer: false,
    note: "December 1984. The song is older than Reeti.",
    source: "https://en.wikipedia.org/wiki/Like_a_Virgin_(song)",
  },
  {
    type: "tf",
    kicker: "Round 2 · Is This 1986?",
    q: "Crocodile Dundee was a 1986 release.",
    answer: true,
    note: "April 30 (Australia), September 26 (US). Paul Hogan, knife scene, all of it.",
    source: "https://en.wikipedia.org/wiki/Crocodile_Dundee",
  },
  {
    type: "tf",
    kicker: "Round 2 · Is This 1986?",
    q: "Top Gun made Tom Cruise a star in 1986.",
    answer: true,
    note: "May 16, 1986. Maverick turns 40 with Reeti this year.",
    source: "https://en.wikipedia.org/wiki/Top_Gun",
  },

  // ─── Round 3: Iconic 1986 Moments ─────────────────────────────────
  {
    type: "divider",
    kicker: "Round 3 of 3",
    q: "Iconic 1986 Moments",
    sub: "The big ones. Hand of God, Halley's, heavyweights.",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "In the 1986 World Cup quarterfinal, Maradona's 'Hand of God' was scored against:",
    choices: ["Brazil", "England", "Belgium", "Germany"],
    answer: 1,
    note: "June 22, 1986. Followed four minutes later by the 'Goal of the Century.'",
    source: "https://en.wikipedia.org/wiki/Argentina_v_England_(1986_FIFA_World_Cup)",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "Halley's Comet showed up in 1986. How was the viewing?",
    choices: [
      "Best in a thousand years",
      "About average",
      "Worst in two thousand years",
      "Couldn't be seen at all",
    ],
    answer: 2,
    note: "Earth and the comet were on opposite sides of the Sun near perihelion. Reeti shares a birth year with a once-a-lifetime miss.",
    source: "https://en.wikipedia.org/wiki/Halley%27s_Comet",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "Mike Tyson became the youngest heavyweight boxing champion in 1986 — at age:",
    choices: ["18", "19", "20", "21"],
    answer: 2,
    note: "November 22, 1986. 20 years, 4 months, 23 days. 2nd-round TKO of Trevor Berbick.",
    source: "https://en.wikipedia.org/wiki/Trevor_Berbick_vs._Mike_Tyson",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "Best Picture Oscar for 1986 films went to:",
    choices: ["Hannah and Her Sisters", "Children of a Lesser God", "The Mission", "Platoon"],
    answer: 3,
    note: "Oliver Stone's Vietnam War drama. Released December 19, 1986.",
    source: "https://en.wikipedia.org/wiki/Platoon_(film)",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "In 1986, Voyager 2 became the first (and so far only) spacecraft to fly past which planet?",
    choices: ["Saturn", "Uranus", "Neptune", "Pluto"],
    answer: 1,
    note: "January 24, 1986. Discovered 11 new moons and 2 new rings.",
    source: "https://www.nasa.gov/history/35-years-ago-voyager-2-explores-uranus/",
  },

  // ─── The Population Gag ───────────────────────────────────────────
  {
    type: "gag",
    kicker: "A small but important fact",
    q: "Why we hit 5 billion.",
  },

  // ─── Bonus Round: Reeti Rapid Fire ────────────────────────────────
  {
    type: "divider",
    kicker: "Bonus Round",
    q: "Reeti Rapid Fire",
    sub: "Answer quickly — no thinking! Press R to start the timer on each.",
  },
  { type: "rapid", q: "Coffee or nap?" },
  { type: "rapid", q: "Back pain or knee pain?" },
  { type: "rapid", q: "Early dinner or early bedtime?" },
  { type: "rapid", q: "Glasses on your head or glasses on your face?" },
  { type: "rapid", q: "Party all night or asleep by 10?" },
  { type: "rapid", q: "Forgot names or forgot why you walked into the room?" },
  { type: "rapid", q: "Hair fall or random grey hair?" },
  { type: "rapid", q: "Loud music or 'Can you turn that down?'" },
  { type: "rapid", q: "Netflix binge or 15-minute nap?" },
  { type: "rapid", q: "Fancy shoes or comfortable slippers?" },
  { type: "rapid", q: "Birthday cake or sugar-free cake?" },
  { type: "rapid", q: "Dance floor or sofa?" },
  { type: "rapid", q: "Young at heart or old in the knees?" },
  { type: "rapid", q: "Unlimited money or unlimited energy?" },
  { type: "rapid", q: "Alarm clock or naturally awake at 5 AM?" },
  { type: "rapid", q: "Texting or asking your kid how to use your phone?" },
  { type: "rapid", q: "Gym workout or stretching and praying?" },
  { type: "rapid", q: "Weekend party or weekend nap?" },
  { type: "rapid", q: "Reading glasses or pretending you can still read small text?" },
  { type: "rapid", q: "Memory loss or 'I know this person but forgot their name'?" },
  { type: "rapid", q: "Road trip or staycation?" },
  { type: "rapid", q: "Hot tea or heating pad?" },
  { type: "rapid", q: "Pizza or antacid after pizza?" },
  { type: "rapid", q: "Midnight celebration or 'Please let me sleep'?" },
  { type: "rapid", q: "Feeling 25 or acting 25?" },

  // ─── Bonus Round: Extra Savage ────────────────────────────────────
  {
    type: "divider",
    kicker: "Bonus Round",
    q: "Extra Savage",
    sub: "No rules. No mercy. Just questions.",
  },
  { type: "savage", q: "How many noises do you make when getting up from a chair?" },
  { type: "savage", q: "Is 40 the new 30… or just 20 with back pain?" },
  { type: "savage", q: "What hurts more: your knees or your Wi-Fi when kids are home?" },
  {
    type: "savage",
    q: "What's your wildest birthday wish — peace, sleep, or lower-back support?",
  },
  { type: "savage", q: "Are you older… or just more 'limited edition'?" },

  // ─── Finale ───────────────────────────────────────────────────────
  {
    type: "finale",
    kicker: "From all of us",
    q: "Happy 40th, Reeti.",
    sub: "Limited Edition since 1986.",
  },
];
