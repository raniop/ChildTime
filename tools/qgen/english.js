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

const byGrade = {
  1: (r) => mix(r, [
    [50, T.caseMatch], [36, T.firstLetter], [9, T.color], [10, (q) => T.digit(q, 1, 10)],
    [60, (q) => T.count(q, 1, 5)], [36, (q) => T.picToWord(q, W1, "medium")],
  ]),
  2: (r) => mix(r, [
    [67, (q) => T.picToWord(q, W2, "easy")], [67, (q) => T.wordToPic(q, W2, "medium")], [70, T.missingLetter],
    [23, T.nextLetter], [10, (q) => T.digit(q, 11, 20)], [60, (q) => T.count(q, 6, 10)],
  ]),
};

module.exports = { topic: "english", byGrade };
