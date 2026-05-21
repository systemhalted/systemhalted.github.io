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
    q: "The Statue of Liberty turned 100 the same year Reeti was born.",
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
    q: "Which 1986 Hindi film was the top-grossing Indian film of the year — Dilip Kumar's last great masala blockbuster?",
    choices: ["Naam", "Karma", "Nagina", "Aakhree Raasta"],
    answer: 1,
    note: "Subhash Ghai, August 8, 1986. Dilip Kumar, Nutan, Anil Kapoor, Naseeruddin Shah, Jackie Shroff.",
    source: "https://en.wikipedia.org/wiki/Karma_(1986_film)",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "In summer 1986, India won its first Test series in England in nearly 15 years. The captain was:",
    choices: ["Sunil Gavaskar", "Mohinder Amarnath", "Kapil Dev", "Dilip Vengsarkar"],
    answer: 2,
    note: "India won 2–0. Vengsarkar scored his third Lord's century in three Tests there.",
    source: "https://en.wikipedia.org/wiki/Kapil_Dev",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "Which 1986 Hindi film featured Sridevi as a snake-woman seeking revenge — the year's #2 box-office hit?",
    choices: ["Nagina", "Mr. India", "Janbaaz", "Sadma"],
    answer: 0,
    note: "November 28, 1986. The 'Main Naagin Tu Sapera' moment. (Mr. India is the 1987 trap-round friend.)",
    source: "https://en.wikipedia.org/wiki/Nagina_(1986_film)",
  },
  {
    type: "mcq",
    kicker: "Round 3 · Iconic Moments",
    q: "In 1986, Mahesh Bhatt directed a comeback film for Sanjay Dutt whose song 'Chitthi Aayi Hai' became iconic. The film was:",
    choices: ["Aashiqui", "Naam", "Saudagar", "Sadak"],
    answer: 1,
    note: "September 12, 1986. Sanjay Dutt and Kumar Gaurav. Pankaj Udhas performs the song on-screen.",
    source: "https://en.wikipedia.org/wiki/Naam_(1986_film)",
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
