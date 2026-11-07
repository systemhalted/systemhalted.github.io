/*
 * Gaana Pakdo: song bank.
 *
 * Every song names one prop. Put all the props on the table before the game
 * starts. When the song plays, the first person to grab the right prop wins
 * the round.
 *
 * Fields:
 *   id       short key; also used to match audio files (e.g. "jhumka.mp3")
 *   title    song title (hidden on screen until the host reveals it)
 *   film     film the song is from
 *   year     release year of the film
 *   prop     the prop to grab
 *   emoji    shown with the prop
 *   hint     where the prop shows up in the song
 *   youtube  optional YouTube video id; when set, the song plays in the page
 *            behind a cover so the title stays hidden
 *   start    optional start time in seconds for the YouTube video
 *
 * Add or remove songs freely. The game needs one song per round, so the
 * number of couples times the rounds per couple must not exceed this list.
 */

window.GAANA_SONGS = [
  {
    id: "jhumka",
    title: "Jhumka Gira Re",
    film: "Mera Saaya",
    year: 1966,
    prop: "Jhumka (earring)",
    emoji: "💎",
    hint: "The jhumka falls in the bazaar of Bareilly, right in the title line.",
  },
  {
    id: "bindiya",
    title: "Bindiya Chamkegi",
    film: "Do Raaste",
    year: 1969,
    prop: "Bindi",
    emoji: "🔴",
    hint: "The bindiya that will sparkle is the first word of the song.",
  },
  {
    id: "chudiyan",
    title: "Bole Chudiyan",
    film: "Kabhi Khushi Kabhie Gham",
    year: 2001,
    prop: "Chudiyan (bangles)",
    emoji: "📿",
    hint: "The bangles are the ones doing the talking.",
  },
  {
    id: "mehndi",
    title: "Mehndi Laga Ke Rakhna",
    film: "Dilwale Dulhania Le Jayenge",
    year: 1995,
    prop: "Mehndi cone",
    emoji: "🌿",
    hint: "Keep the mehndi on; the groom's party is on its way.",
  },
  {
    id: "kajra",
    title: "Kajra Re",
    film: "Bunty Aur Babli",
    year: 2005,
    prop: "Kajal",
    emoji: "👁️",
    hint: "The whole song is about kohl-lined eyes.",
  },
  {
    id: "chashma",
    title: "Kala Chashma",
    film: "Baar Baar Dekho",
    year: 2016,
    prop: "Sunglasses",
    emoji: "🕶️",
    hint: "The black chashma is in the hook.",
  },
  {
    id: "dupatta",
    title: "Lal Dupatta",
    film: "Mujhse Shaadi Karogi",
    year: 2004,
    prop: "Dupatta",
    emoji: "🧣",
    hint: "A gust of wind blows the red dupatta away.",
  },
  {
    id: "topi",
    title: "Mera Joota Hai Japani",
    film: "Shree 420",
    year: 1955,
    prop: "Topi (hat)",
    emoji: "🎩",
    hint: "The shoe is Japanese, but the red topi on the head is Russian.",
  },
  {
    id: "telephone",
    title: "Mere Piya Gaye Rangoon",
    film: "Patanga",
    year: 1949,
    prop: "Telephone",
    emoji: "☎️",
    hint: "Piya calls from Rangoon on the telephone.",
  },
  {
    id: "khat",
    title: "Likhe Jo Khat Tujhe",
    film: "Kanyadaan",
    year: 1968,
    prop: "Khat (letter)",
    emoji: "✉️",
    hint: "The letters written to you are in the first line.",
  },
  {
    id: "saree",
    title: "Saree Ke Fall Sa",
    film: "R... Rajkumar",
    year: 2013,
    prop: "Saree",
    emoji: "🥻",
    hint: "She matches him like a fall matches a saree.",
  },
  {
    id: "sheesha",
    title: "Sheesha Ho Ya Dil Ho",
    film: "Aasha",
    year: 1980,
    prop: "Sheesha (mirror)",
    emoji: "🪞",
    hint: "Glass or heart, it breaks in the end.",
  },
  {
    id: "ghunghroo",
    title: "Pag Ghunghroo Baandh Meera Naachi Thi",
    film: "Namak Halaal",
    year: 1982,
    prop: "Ghunghroo (ankle bells)",
    emoji: "🔔",
    hint: "Meera tied ghunghroo to her feet and danced.",
  },
  {
    id: "paan",
    title: "Khaike Paan Banaraswala",
    film: "Don",
    year: 1978,
    prop: "Paan",
    emoji: "🍃",
    hint: "One Banarasi paan and the mind opens up.",
  },
];
