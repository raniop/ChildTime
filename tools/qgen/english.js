// 🇬🇧 English for כיתה א׳–ב׳ — the grades that had no English of their own.
//
// Until now a first-grader in the English world was topped up with כיתה ג׳
// questions (the nearest grade that had any). Early English in Israeli schools is
// letters, colours, numbers and a first picture vocabulary, so that is exactly
// what this builds — every answer comes from the tables below, nothing is
// remembered, and the Hebrew instructions are short, vowelled and never change.
"use strict";
const { int, pick } = require("./core");

const shuffle = (r, a) => a.map((v) => [r(), v]).sort((x, y) => x[0] - y[0]).map((x) => x[1]);
// Up to three distinct picks from `pool`, never the answer, preferring `near` first.
function three(r, answer, near, pool) {
  const out = [];
  for (const v of [...shuffle(r, near), ...shuffle(r, pool)]) {
    if (out.length === 3) break;
    if (v !== answer && !out.includes(v)) out.push(v);
  }
  return out.length === 3 ? out : null;
}

// ——— Letters ———
const UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
// Letters a child genuinely mixes up — a distractor from the same shape family
// tests the letter, a random one only tests the alphabet's length.
const LOOKALIKE = [["b", "d", "p", "q"], ["m", "n", "h", "u", "r"], ["c", "e", "o", "a"], ["v", "w", "y", "x"],
  ["f", "t", "k", "h"], ["g", "q", "y", "j"], ["s", "z", "c"], ["i", "j", "t"]];
const near = (ch) => (LOOKALIKE.find((g) => g.includes(ch)) || []).filter((x) => x !== ch);
// In a rounded font lowercase l and capital I are the same stroke — never show
// them as a prompt or put them side by side as options.
const AMBIGUOUS = new Set(["l", "I"]);

// ——— Words (א׳: three letters, one picture each; ב׳: a wider first vocabulary) ———
const W1 = [
  ["cat", "🐱", "animal"], ["dog", "🐶", "animal"], ["pig", "🐷", "animal"], ["cow", "🐄", "animal"], ["hen", "🐔", "animal"],
  ["fox", "🦊", "animal"], ["bee", "🐝", "animal"], ["ant", "🐜", "animal"], ["owl", "🦉", "animal"], ["bat", "🦇", "animal"],
  ["rat", "🐀", "animal"], ["bug", "🐛", "animal"],
  ["sun", "☀️", "thing"], ["ice", "🧊", "thing"], ["web", "🕸️", "thing"], ["log", "🪵", "thing"], ["bed", "🛏️", "thing"],
  ["box", "📦", "thing"], ["key", "🔑", "thing"], ["pen", "🖊️", "thing"], ["map", "🗺️", "thing"], ["hat", "🎩", "thing"],
  ["cap", "🧢", "thing"], ["bag", "👜", "thing"], ["bow", "🎀", "thing"], ["fan", "🪭", "thing"],
  ["bus", "🚌", "ride"], ["car", "🚗", "ride"], ["van", "🚐", "ride"],
  ["ear", "👂", "body"], ["eye", "👁️", "body"], ["leg", "🦵", "body"],
  ["egg", "🥚", "food"], ["pie", "🥧", "food"], ["tea", "🍵", "food"], ["nut", "🥜", "food"],
];
const W2 = [
  ["lion", "🦁", "animal"], ["frog", "🐸", "animal"], ["duck", "🦆", "animal"], ["fish", "🐟", "animal"], ["bird", "🐦", "animal"],
  ["horse", "🐴", "animal"], ["sheep", "🐑", "animal"], ["mouse", "🐭", "animal"], ["snake", "🐍", "animal"], ["tiger", "🐯", "animal"],
  ["zebra", "🦓", "animal"], ["monkey", "🐵", "animal"], ["rabbit", "🐰", "animal"], ["bear", "🐻", "animal"], ["whale", "🐳", "animal"],
  ["shark", "🦈", "animal"], ["snail", "🐌", "animal"], ["camel", "🐫", "animal"], ["goat", "🐐", "animal"],
  ["apple", "🍎", "food"], ["banana", "🍌", "food"], ["bread", "🍞", "food"], ["cake", "🎂", "food"], ["pizza", "🍕", "food"],
  ["grapes", "🍇", "food"], ["lemon", "🍋", "food"], ["carrot", "🥕", "food"], ["cheese", "🧀", "food"], ["cookie", "🍪", "food"],
  ["cherry", "🍒", "food"], ["corn", "🌽", "food"],
  ["book", "📖", "thing"], ["chair", "🪑", "thing"], ["door", "🚪", "thing"], ["ball", "⚽", "thing"], ["clock", "⏰", "thing"],
  ["phone", "📱", "thing"], ["house", "🏠", "thing"], ["pencil", "✏️", "thing"], ["kite", "🪁", "thing"], ["drum", "🥁", "thing"],
  ["gift", "🎁", "thing"], ["bell", "🔔", "thing"],
  ["star", "⭐", "nature"], ["moon", "🌙", "nature"], ["tree", "🌳", "nature"], ["flower", "🌸", "nature"], ["cloud", "☁️", "nature"],
  ["rain", "🌧️", "nature"], ["snow", "❄️", "nature"], ["fire", "🔥", "nature"],
  ["hand", "✋", "body"], ["foot", "🦶", "body"], ["nose", "👃", "body"], ["mouth", "👄", "body"], ["tooth", "🦷", "body"],
  ["shirt", "👕", "wear"], ["shoe", "👟", "wear"], ["sock", "🧦", "wear"], ["dress", "👗", "wear"], ["coat", "🧥", "wear"],
  ["bike", "🚲", "ride"], ["boat", "⛵", "ride"], ["train", "🚂", "ride"], ["plane", "✈️", "ride"], ["truck", "🚚", "ride"],
];
// Every English word a missing-letter option could accidentally spell.
const ALL_WORDS = new Set([...W1, ...W2].map((w) => w[0]).concat(
  ["cut", "cot", "bill", "bull", "hat", "hot", "hit", "pin", "pan", "bag", "big", "bog", "fin", "fun", "fan", "ten", "tin", "ton",
    "cold", "gold", "hold", "bold", "bake", "lake", "make", "take", "wake", "rake", "dock", "rock", "lock", "sick", "sack", "suck",
    "boot", "foot", "moan", "loan", "mice", "nice", "rice", "dice", "hose", "rose", "pose", "nose", "cook", "look", "hook", "took",
    "bead", "read", "lead", "head", "dead", "date", "gate", "late", "mate", "rate", "hate", "fate", "shop", "ship", "chip", "chop"]));

const COLORS = [["red", "🔴"], ["blue", "🔵"], ["green", "🟢"], ["yellow", "🟡"], ["orange", "🟠"],
  ["purple", "🟣"], ["black", "⚫"], ["white", "⚪"], ["brown", "🟤"]];
const NUM = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"];
const KEYCAP = ["0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"];
const COUNTABLE = ["🍎", "⭐", "🐟", "🌸", "🎈", "🍌", "🐝", "⚽", "🚗", "🦋", "🍪", "🐱"];
const numNear = (n, lo, hi) => [n - 1, n + 1, n - 2, n + 2, n + 3].filter((x) => x >= lo && x <= hi).map((x) => NUM[x]);
const sameKind = (list, w) => list.filter((x) => x[2] === w[2] && x[0] !== w[0]);

// ——— Templates ———
const T = {
  // a → A   /   B → b
  caseMatch(r) {
    const up = pick(r, UPPER), low = up.toLowerCase();
    if (r() < 0.5) {
      if (AMBIGUOUS.has(low)) return null;
      const opts = three(r, up, near(low).map((x) => x.toUpperCase()), UPPER.filter((x) => !AMBIGUOUS.has(x)));
      return opts && { prompt: `${low}\nמָה הָאוֹת הַגְּדוֹלָה?`, correctAnswer: up, distractors: opts, tier: "easy" };
    }
    if (AMBIGUOUS.has(up)) return null;
    const opts = three(r, low, near(low), UPPER.map((x) => x.toLowerCase()).filter((x) => !AMBIGUOUS.has(x)));
    return opts && { prompt: `${up}\nמָה הָאוֹת הַקְּטַנָּה?`, correctAnswer: low, distractors: opts, tier: "easy" };
  },
  // 🐶 dog → d
  firstLetter(r) {
    const [word, pic] = pick(r, W1), first = word[0];
    const opts = three(r, first, near(first), "abcdefghjkmnoprstuvwyz".split(""));
    return opts && { prompt: `${pic} ${word}\nבְּאֵיזוֹ אוֹת מַתְחִילָה הַמִּלָּה?`, correctAnswer: first, distractors: opts, tier: "medium" };
  },
  color(r) {
    const [word, dot] = pick(r, COLORS);
    return { prompt: `${dot}\nמָה הַצֶּבַע בְּאַנְגְּלִית?`, correctAnswer: word, distractors: three(r, word, [], COLORS.map((c) => c[0])), tier: "easy" };
  },
  digit(r, lo, hi) {
    const n = int(r, lo, hi);
    return { prompt: `${n <= 10 ? KEYCAP[n] : n}\nאֵיךְ קוֹרְאִים לַמִּסְפָּר בְּאַנְגְּלִית?`, correctAnswer: NUM[n],
      distractors: three(r, NUM[n], numNear(n, Math.max(0, lo - 2), hi + 2), NUM.slice(lo, hi + 1)), tier: n > 10 ? "medium" : "easy" };
  },
  count(r, lo, hi) {
    const n = int(r, lo, hi), e = pick(r, COUNTABLE);
    return { prompt: `${Array(n).fill(e).join(" ")}\nסִפְרוּ: אֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?`, correctAnswer: NUM[n],
      distractors: three(r, NUM[n], numNear(n, 1, 10), NUM.slice(1, 11)), tier: "easy" };
  },
  // 🦁 → lion
  picToWord(r, list, tier) {
    const w = pick(r, list);
    const opts = three(r, w[0], sameKind(list, w).map((x) => x[0]), list.map((x) => x[0]));
    return opts && { prompt: `${w[1]}\nמָה הַמִּלָּה בְּאַנְגְּלִית?`, correctAnswer: w[0], distractors: opts, tier };
  },
  // lion → 🦁
  wordToPic(r, list, tier) {
    const w = pick(r, list);
    const opts = three(r, w[1], sameKind(list, w).map((x) => x[1]), list.map((x) => x[1]));
    return opts && { prompt: `${w[0]}\nאֵיזוֹ תְּמוּנָה מַתְאִימָה לַמִּלָּה?`, correctAnswer: w[1], distractors: opts, tier };
  },
  // 🐸 fr_g → o
  missingLetter(r) {
    const [word, pic] = pick(r, W2);
    const i = int(r, 1, word.length - 1), ch = word[i];
    const vowels = "aeiou".split(""), cons = "bcdfghkmnprstw".split("");
    const pool = vowels.includes(ch) ? vowels : cons;
    // A wrong option must not spell a real word too ("b_ll": a / e both work).
    const spellsWord = (x) => ALL_WORDS.has(word.slice(0, i) + x + word.slice(i + 1));
    const opts = three(r, ch, [], pool.filter((x) => !spellsWord(x)));
    return opts && { prompt: `${pic} ${word.slice(0, i)}_${word.slice(i + 1)}\nאֵיזוֹ אוֹת חֲסֵרָה?`, correctAnswer: ch, distractors: opts, tier: "hard" };
  },
  // O P Q _ → R   (a run of letters, not "Q → ?": an arrow reads backwards on a right-to-left screen)
  nextLetter(r) {
    const i = int(r, 2, 24), up = UPPER[i], ans = UPPER[i + 1];
    if (AMBIGUOUS.has(ans)) return null;
    const run = UPPER.slice(i - 2, i + 1).join(" ");
    const opts = three(r, ans, [UPPER[i - 1], UPPER[i + 2], UPPER[i + 3]].filter(Boolean).filter((x) => !AMBIGUOUS.has(x)),
      UPPER.filter((x) => !UPPER.slice(i - 2, i + 1).includes(x) && !AMBIGUOUS.has(x)));
    return opts && { prompt: `${run} _\nאֵיזוֹ אוֹת בָּאָה אַחַר כָּךְ?`, correctAnswer: ans, distractors: opts, tier: "medium" };
  },
};

// Weighted by how many distinct questions each template can make, so the rare
// ones (9 colours) don't get asked for 50 times and stall the batch.
const mix = (r, entries) => { let x = r() * entries.reduce((s, e) => s + e[0], 0); for (const [w, f] of entries) { if ((x -= w) < 0) return f(r); } return entries[0][1](r); };

// ——— ז׳–ח׳: grammar from tables. Every wrong option is wrong IN THIS SENTENCE —
// "They played football every day" is fine English, so a past form is never
// offered as the wrong answer to a present-simple gap, and so on.
const iso = (x) => `⁦${x}⁩`;   // an English sentence inside a Hebrew question
const FILL = "הַשְׁלִימוּ אֶת הַמִּשְׁפָּט:";

// base, 3rd person, past, past participle, -ing, object phrase
const VERBS = [
  ["go", "goes", "went", "gone", "going", "to school"], ["see", "sees", "saw", "seen", "seeing", "the sea"],
  ["eat", "eats", "ate", "eaten", "eating", "breakfast"], ["buy", "buys", "bought", "bought", "buying", "bread"],
  ["take", "takes", "took", "taken", "taking", "the bus"], ["write", "writes", "wrote", "written", "writing", "a letter"],
  ["drink", "drinks", "drank", "drunk", "drinking", "orange juice"], ["swim", "swims", "swam", "swum", "swimming", "in the pool"],
  ["run", "runs", "ran", "run", "running", "in the park"], ["give", "gives", "gave", "given", "giving", "a present"],
  ["make", "makes", "made", "made", "making", "a cake"], ["sing", "sings", "sang", "sung", "singing", "a song"],
  ["sleep", "sleeps", "slept", "slept", "sleeping", "at a friend's house"], ["meet", "meets", "met", "met", "meeting", "our friends"],
  ["find", "finds", "found", "found", "finding", "a coin"], ["fly", "flies", "flew", "flown", "flying", "a kite"],
  ["bring", "brings", "brought", "brought", "bringing", "a ball"], ["catch", "catches", "caught", "caught", "catching", "the ball"],
  ["win", "wins", "won", "won", "winning", "the game"], ["lose", "loses", "lost", "lost", "losing", "the key"],
  ["break", "breaks", "broke", "broken", "breaking", "a glass"], ["ride", "rides", "rode", "ridden", "riding", "a horse"],
  ["speak", "speaks", "spoke", "spoken", "speaking", "English"], ["wear", "wears", "wore", "worn", "wearing", "a hat"],
  ["draw", "draws", "drew", "drawn", "drawing", "a picture"], ["forget", "forgets", "forgot", "forgotten", "forgetting", "the homework"],
  ["send", "sends", "sent", "sent", "sending", "a message"], ["read", "reads", "read", "read", "reading", "a book"],
  ["watch", "watches", "watched", "watched", "watching", "a movie"], ["play", "plays", "played", "played", "playing", "football"],
  ["study", "studies", "studied", "studied", "studying", "math"], ["wash", "washes", "washed", "washed", "washing", "the dishes"],
  ["do", "does", "did", "done", "doing", "the homework"], ["have", "has", "had", "had", "having", "lunch"],
  ["teach", "teaches", "taught", "taught", "teaching", "the class"], ["drive", "drives", "drove", "driven", "driving", "a car"],
];
// Verbs that read naturally as a habit ("every day") and as an activity in progress.
const HABIT = new Set(["go", "eat", "take", "write", "drink", "swim", "run", "make", "sing", "meet", "fly", "ride", "speak", "wear", "draw", "read", "watch", "play", "study", "wash", "do", "have", "teach", "drive", "buy", "send"]);
const ACTIVITY = new Set(["go", "eat", "take", "write", "drink", "swim", "run", "make", "sing", "sleep", "fly", "ride", "speak", "draw", "read", "watch", "play", "study", "wash", "do", "have", "teach", "drive", "buy", "send"]);
const REGULARIZED = { go: "goed", see: "seed", eat: "eated", buy: "buyed", take: "taked", write: "writed", drink: "drinked", swim: "swimmed", run: "runned", give: "gived", make: "maked", sing: "singed", sleep: "sleeped", meet: "meeted", find: "finded", fly: "flyed", bring: "bringed", catch: "catched", win: "winned", lose: "losed", break: "breaked", ride: "rided", speak: "speaked", wear: "weared", draw: "drawed", forget: "forgetted", send: "sended", teach: "teached", drive: "drived" };
const ONE = [["He", true], ["She", true], ["My brother", true], ["Our teacher", true], ["Dana", true], ["The boy", true]];
const MANY = [["They", false], ["We", false], ["My parents", false], ["The children", false], ["You", false], ["I", false]];
// adjective, comparative, superlative, a wrong regular form of each
const ADJ = [
  ["tall", "taller", "tallest", "more tall", "most tall"], ["big", "bigger", "biggest", "biger", "bigest"],
  ["hot", "hotter", "hottest", "hoter", "hotest"], ["happy", "happier", "happiest", "happyer", "happyest"],
  ["easy", "easier", "easiest", "easyer", "more easy"], ["fast", "faster", "fastest", "more fast", "most fast"],
  ["good", "better", "best", "gooder", "goodest"], ["bad", "worse", "worst", "badder", "baddest"],
  ["beautiful", "more beautiful", "most beautiful", "beautifuller", "beautifullest"],
  ["expensive", "more expensive", "most expensive", "expensiver", "expensivest"],
  ["interesting", "more interesting", "most interesting", "interestinger", "interestingest"],
  ["young", "younger", "youngest", "more young", "most young"], ["old", "older", "oldest", "more old", "most old"],
  ["cold", "colder", "coldest", "more cold", "most cold"], ["funny", "funnier", "funniest", "funnyer", "more funny"],
  ["heavy", "heavier", "heaviest", "heavyer", "more heavy"], ["strong", "stronger", "strongest", "more strong", "most strong"],
  ["dangerous", "more dangerous", "most dangerous", "dangerouser", "dangerousest"],
  ["difficult", "more difficult", "most difficult", "difficulter", "difficultest"], ["thin", "thinner", "thinnest", "thiner", "thinest"],
];
const COMPARE = { tall: ["Dan is ___ than his little brother."], big: ["An elephant is ___ than a dog."], hot: ["Summer is ___ than winter in Israel."],
  happy: ["Noa is ___ today than yesterday."], easy: ["This test is ___ than the last one."], fast: ["A car is ___ than a bike."],
  good: ["My new phone is ___ than my old one."], bad: ["The weather today is ___ than yesterday."], beautiful: ["This flower is ___ than that one."],
  expensive: ["A plane ticket is ___ than a bus ticket."], interesting: ["This book is ___ than the movie."], young: ["My sister is ___ than me."],
  old: ["My grandfather is ___ than my father."], cold: ["Winter is ___ than spring."], funny: ["This joke is ___ than the first one."],
  heavy: ["A bag of books is ___ than a bag of feathers."], strong: ["A lion is ___ than a cat."], dangerous: ["A shark is ___ than a fish."],
  difficult: ["Chess is ___ than checkers."], thin: ["This pencil is ___ than that one."] };
const SUPER = { tall: "He is the ___ boy in the class.", big: "The blue whale is the ___ animal in the sea.", hot: "August is the ___ month of the year.",
  happy: "It was the ___ day of my life.", easy: "This is the ___ question on the test.", fast: "The cheetah is the ___ animal on land.",
  good: "She is the ___ player on the team.", bad: "That was the ___ movie I have ever seen.", beautiful: "It is the ___ beach in the country.",
  expensive: "This is the ___ car in the shop.", interesting: "History is the ___ lesson this week.", young: "Tom is the ___ child in the family.",
  old: "This is the ___ building in the city.", cold: "January is the ___ month here.", funny: "He tells the ___ jokes.",
  heavy: "This is the ___ box of all.", strong: "He is the ___ man in the gym.", dangerous: "It is the ___ road in the area.",
  difficult: "This is the ___ puzzle in the book.", thin: "This is the ___ book on the shelf." };
const PLURAL = [["child", "children", ["childs", "childrens"]], ["man", "men", ["mans", "mens"]], ["woman", "women", ["womans", "womens"]],
  ["tooth", "teeth", ["tooths", "teeths"]], ["foot", "feet", ["foots", "feets"]], ["mouse", "mice", ["mouses", "mices"]],
  ["person", "people", ["persones", "peoples"]], ["sheep", "sheep", ["sheeps", "sheepes"]], ["knife", "knives", ["knifes", "knivs"]],
  ["leaf", "leaves", ["leafs", "leafes"]], ["wolf", "wolves", ["wolfs", "wolfes"]], ["box", "boxes", ["boxs", "boxies"]],
  ["bus", "buses", ["buss", "busies"]], ["city", "cities", ["citys", "cityes"]], ["baby", "babies", ["babys", "babyes"]],
  ["potato", "potatoes", ["potatos", "potatoies"]], ["goose", "geese", ["gooses", "geeses"]], ["life", "lives", ["lifes", "lifs"]],
  ["watch", "watches", ["watchs", "watchies"]], ["dish", "dishes", ["dishs", "dishies"]]];
const OPPOSITE = [["hot", "cold"], ["big", "small"], ["happy", "sad"], ["fast", "slow"], ["open", "closed"], ["early", "late"],
  ["full", "empty"], ["easy", "difficult"], ["strong", "weak"], ["cheap", "expensive"], ["clean", "dirty"], ["long", "short"],
  ["light", "dark"], ["young", "old"], ["rich", "poor"], ["loud", "quiet"], ["wet", "dry"], ["heavy", "light"], ["first", "last"],
  ["always", "never"], ["buy", "sell"], ["win", "lose"], ["remember", "forget"], ["arrive", "leave"], ["push", "pull"],
  ["give", "take"], ["begin", "end"], ["laugh", "cry"], ["up", "down"], ["inside", "outside"]];
const QWORDS = [["___ do you live? – In Haifa.", "Where"], ["___ is your birthday? – In May.", "When"], ["___ is your English teacher? – Mrs. Levi.", "Who"],
  ["___ old are you? – I'm thirteen.", "How"], ["___ are you late? – Because I missed the bus.", "Why"], ["___ bag is this? – It's Dana's.", "Whose"],
  ["___ time does the movie start? – At eight.", "What"], ["___ many brothers do you have? – Two.", "How"], ["___ did you go last summer? – To Eilat.", "Where"],
  ["___ did you call? – My grandmother.", "Who"], ["___ do you go to bed? – At ten o'clock.", "When"], ["___ are you crying? – Because I'm sad.", "Why"],
  ["___ is your favorite food? – Pizza.", "What"], ["___ much is this shirt? – 50 shekels.", "How"], ["___ phone is ringing? – It's mine.", "Whose"]];
const QW = ["Where", "When", "Who", "How", "Why", "Whose", "What"];
// One sentence per gap, so the time phrase always fits it (no "at/on the weekend" — both are correct English).
const TIMEPREP = [["at", "The movie starts ___ 7 o'clock."], ["on", "We have a test ___ Monday."], ["in", "My birthday is ___ July."],
  ["in", "I was born ___ 2012."], ["at", "Owls hunt ___ night."], ["on", "We had a party ___ my birthday."], ["in", "I drink coffee ___ the morning."],
  ["at", "We eat lunch ___ noon."], ["on", "They visit us ___ Friday evening."], ["in", "It is very hot here ___ the summer."],
  ["on", "The school trip is ___ the first of May."], ["in", "I do my homework ___ the afternoon."], ["at", "The fireworks start ___ midnight."],
  ["in", "It often rains ___ winter."], ["at", "The shop closes ___ 9 o'clock."], ["on", "We go to the beach ___ Saturdays."], ["in", "The Olympics were ___ 2024."]];

const byGrade = {
  1: (r) => mix(r, [
    [50, T.caseMatch], [36, T.firstLetter], [9, T.color], [10, (q) => T.digit(q, 1, 10)],
    [60, (q) => T.count(q, 1, 5)], [36, (q) => T.picToWord(q, W1, "medium")],
  ]),
  2: (r) => mix(r, [
    [67, (q) => T.picToWord(q, W2, "easy")], [67, (q) => T.wordToPic(q, W2, "medium")], [70, T.missingLetter],
    [23, T.nextLetter], [10, (q) => T.digit(q, 11, 20)], [60, (q) => T.count(q, 6, 10)],
  ]),
  // ז׳: present simple, past simple (irregular), comparatives, plurals, opposites, am/is/are
  7: (r) => {
    switch (int(r, 0, 5)) {
      case 0: { const v = pick(r, VERBS.filter((x) => HABIT.has(x[0]))), [subj, third] = pick(r, [...ONE, ...MANY]);
        const answer = third ? v[1] : v[0], wrong = [third ? v[0] : v[1], v[4], `to ${v[0]}`];
        return { prompt: `${FILL}\n${iso(`${subj} ___ ${v[5]} every day.`)}`, correctAnswer: answer, distractors: wrong, tier: "easy" }; }
      case 1: { const v = pick(r, VERBS.filter((x) => REGULARIZED[x[0]])), subj = pick(r, ["I", "we", "they", "she", "my friend"]);
        return { prompt: `${FILL}\n${iso(`Yesterday ${subj} ___ ${v[5]}.`)}`, correctAnswer: v[2], distractors: [REGULARIZED[v[0]], v[1], v[4]], tier: "medium" }; }
      case 2: { const v = pick(r, VERBS.filter((x) => REGULARIZED[x[0]]));
        return { prompt: `מָה צוּרַת הֶעָבָר שֶׁל הַפֹּעַל ${iso(v[0])}?`, correctAnswer: v[2], distractors: [REGULARIZED[v[0]], v[1], v[3] !== v[2] ? v[3] : v[4]], tier: "medium" }; }
      case 3: { const a = pick(r, ADJ);
        return { prompt: `${FILL}\n${iso(`${COMPARE[a[0]][0]} (${a[0]})`)}`, correctAnswer: a[1], distractors: [a[3], a[2], a[0]], tier: "medium" }; }
      case 4: { const [one, many, wrong] = pick(r, PLURAL);
        return { prompt: `מָה צוּרַת הָרַבִּים שֶׁל ${iso(one)}?`, correctAnswer: many, distractors: [...wrong, one === many ? `${one}en` : one], tier: "medium" }; }
      default: { const [a, b] = pick(r, OPPOSITE), flip = r() < 0.5, w = flip ? b : a, ans = flip ? a : b;
        const opts = OPPOSITE.flat().filter((x) => x !== ans && x !== w && !OPPOSITE.some(([p, q]) => (p === w && q === x) || (q === w && p === x)));
        return { prompt: `מָה הַהֶפֶךְ שֶׁל ${iso(w)}?`, correctAnswer: ans, distractors: [...new Set(opts.sort(() => r() - 0.5))].slice(0, 3), tier: "easy" }; }
    }
  },
  // ח׳: present perfect, past progressive, superlatives, first conditional, question words, time prepositions, was/were
  8: (r) => {
    switch (int(r, 0, 6)) {
      case 0: { const v = pick(r, VERBS.filter((x) => x[3] !== x[2])), [subj, third] = pick(r, [...ONE, ...MANY].filter(([s]) => s !== "I" && s !== "You"));
        return { prompt: `${FILL}\n${iso(`${subj} ${third ? "has" : "have"} already ___ ${v[5]}.`)}`, correctAnswer: v[3], distractors: [v[2], v[0], v[4]], tier: "hard" }; }
      case 1: { const v = pick(r, VERBS.filter((x) => ACTIVITY.has(x[0]))), [subj, one] = pick(r, [["I", true], ["He", true], ["She", true], ["We", false], ["They", false], ["My parents", false]]);
        const answer = `${one ? "was" : "were"} ${v[4]}`;
        return { prompt: `${FILL}\n${iso(`${subj} ___ ${v[5]} when the phone rang.`)}`, correctAnswer: answer, distractors: [`${one ? "were" : "was"} ${v[4]}`, `${subj === "I" ? "am" : one ? "is" : "are"} ${v[4]}`, v[4]], tier: "hard" }; }
      case 2: { const a = pick(r, ADJ);
        return { prompt: `${FILL}\n${iso(`${SUPER[a[0]]} (${a[0]})`)}`, correctAnswer: a[2], distractors: [a[4], a[1], a[0]], tier: "medium" }; }
      case 3: { const pairs = [["rains", "stay at home"], ["is sunny", "go to the beach"], ["is late", "take a taxi"], ["snows", "build a snowman"], ["is hungry", "order a pizza"], ["is tired", "go to sleep early"]];
        const [cond, act] = pick(r, pairs), first = act.split(" ")[0], rest = act.split(" ").slice(1).join(" ");
        const who = cond.startsWith("is") && !["is sunny"].includes(cond) ? pick(r, ["Dan", "the bus"]) : "it";
        if (who === "the bus" && cond !== "is late") return null;
        // Dan's condition, Dan's action — "If Dan is tired, I will go to sleep" makes no sense.
        const subj = who === "Dan" ? "he" : who === "the bus" ? pick(r, ["we", "I"]) : pick(r, ["we", "they", "I"]);
        const ing = first === "stay" ? "staying" : first === "go" ? "going" : first === "take" ? "taking" : first === "build" ? "building" : first === "order" ? "ordering" : `${first}ing`;
        return { prompt: `${FILL}\n${iso(`If ${who} ${cond}, ${subj} ___ ${rest}.`)}`, correctAnswer: `will ${first}`, distractors: [`would ${first}`, `${first === "go" ? "went" : first === "take" ? "took" : first === "build" ? "built" : `${first}ed`}`, ing], tier: "hard" }; }
      case 4: { const [q, a] = pick(r, QWORDS);
        return { prompt: `אֵיזוֹ מִלַּת שְׁאֵלָה חֲסֵרָה?\n${iso(q)}`, correctAnswer: a, distractors: QW.filter((x) => x !== a).sort(() => r() - 0.5).slice(0, 3), tier: "medium" }; }
      case 5: { const [prep, sentence] = pick(r, TIMEPREP);
        return { prompt: `${FILL}\n${iso(sentence)}`, correctAnswer: prep, distractors: ["in", "on", "at", "to"].filter((x) => x !== prep), tier: "medium" }; }
      default: { const [subj, one] = pick(r, [["I", true], ["she", true], ["my dog", true], ["we", false], ["they", false], ["my friends", false]]), place = pick(r, ["at the beach", "at home", "in Jerusalem", "at the concert", "very tired"]);
        return { prompt: `${FILL}\n${iso(`Yesterday ${subj} ___ ${place}.`)}`, correctAnswer: one ? "was" : "were", distractors: [one ? "were" : "was", one ? (subj === "I" ? "am" : "is") : "are", "be"], tier: "easy" }; }
    }
  },
};

module.exports = { topic: "english", byGrade };
