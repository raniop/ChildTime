// ⚽🇬🇧 English inside the soccer world.
//
// Rani: "תערבב בתוכם שאלות שגם קשורות לחשבון ולאנגלית — מה זה Yellow card —
// ואז הוא לומד אנגלית תוך כדי כדורגל". Soccer already carries the maths
// (soccer.js); this adds the language of the game: Hebrew ⇄ English terms by
// grade band, and English definitions for middle school. Every word appears in
// exactly one band, so a prompt never repeats across grades.
"use strict";
const { pick } = require("./core");

const iso = (x) => `⁦${x}⁩`;
const shuffle = (r, a) => a.map((v) => [r(), v]).sort((x, y) => x[0] - y[0]).map((x) => x[1]);

// [English, Hebrew]
const EASY = [["ball", "כַּדּוּר"], ["team", "קְבוּצָה"], ["player", "שַׂחְקָן"], ["goal", "שַׁעַר"], ["goalkeeper", "שׁוֹעֵר"],
  ["referee", "שׁוֹפֵט"], ["coach", "מְאַמֵּן"], ["fans", "אוֹהֲדִים"], ["stadium", "אִצְטַדְיוֹן"], ["win", "נִצָּחוֹן"],
  ["whistle", "מַשְׁרוֹקִית"], ["yellow card", "כַּרְטִיס צָהֹב"], ["red card", "כַּרְטִיס אָדֹם"], ["field", "מִגְרָשׁ"], ["net", "רֶשֶׁת"]];
const MEDIUM = [["penalty", "פֶּנְדֵּל"], ["corner kick", "בְּעִיטַת קֶרֶן"], ["free kick", "בְּעִיטָה חָפְשִׁית"], ["offside", "נִבְדָּל"],
  ["defender", "מָגֵן"], ["striker", "חָלוּץ"], ["midfielder", "קַשָּׁר"], ["winger", "כַּנָּף"], ["substitute", "שַׂחְקָן מַחְלִיף"],
  ["captain", "קַפְּטֶן"], ["header", "נְגִיחָה"], ["pass", "מְסִירָה"], ["foul", "עֲבֵרָה"], ["half-time", "מַחֲצִית"],
  ["extra time", "הַאֲרָכָה"], ["draw", "תֵּיקוֹ"], ["trophy", "גָּבִיעַ"], ["league", "לִיגָה"], ["bench", "סַפְסָל"],
  ["save", "הַצָּלָה"], ["champion", "אַלּוּף"]];
// [definition, word] — middle school reads the definition in English.
const DEFINITIONS = [
  ["the player who guards the goal", "goalkeeper"], ["the person who controls the game and blows the whistle", "referee"],
  ["a player who comes on to replace another player", "substitute"], ["a card that sends a player off the field", "red card"],
  ["a warning card shown to a player", "yellow card"], ["a game that ends with the same score for both teams", "draw"],
  ["extra minutes played when a knockout game is tied", "extra time"], ["hitting the ball with your head", "header"],
  ["a kick taken from the corner of the field", "corner kick"], ["the person who trains the team", "coach"],
  ["the leader of the team on the field", "captain"], ["the break between the two halves of the game", "half-time"],
  ["breaking a rule, like pushing or tripping a player", "foul"], ["a kick at the goal from the penalty spot", "penalty"],
  ["a group of teams that play each other during the season", "league"], ["the people who support a team", "fans"],
  ["a player whose main job is to score goals", "striker"], ["a player whose main job is to stop the other team from scoring", "defender"],
  ["the long seat where the substitutes wait", "bench"], ["a prize given to the winning team", "trophy"],
  ["when the goalkeeper stops a shot", "save"], ["a big place for games, with thousands of seats for fans", "stadium"],
  ["the team that wins the league or the cup", "champion"],
];

function bandItems(r, words, gradeLo, gradeHi, tier) {
  const out = [];
  for (const [en, he] of words) {
    const others = words.filter((w) => w[0] !== en);
    out.push({ prompt: `⚽🇬🇧\nמָה פֵּרוּשׁ ${iso(en)} בְּעוֹלַם הַכַּדּוּרֶגֶל?`, correctAnswer: he,
      distractors: shuffle(r, others).slice(0, 3).map((w) => w[1]), tier, gradeLo, gradeHi });
    out.push({ prompt: `⚽🇬🇧\nאֵיךְ אוֹמְרִים ״${he}״ בְּאַנְגְּלִית?`, correctAnswer: en,
      distractors: shuffle(r, others).slice(0, 3).map((w) => w[0]), tier, gradeLo, gradeHi });
  }
  return out;
}

function items(r) {
  const defs = DEFINITIONS.map(([def, word]) => ({
    prompt: `⚽🇬🇧\nאֵיזוֹ מִלָּה מַתְאִימָה לַהַגְדָּרָה?\n${iso(def)}`, correctAnswer: word,
    distractors: shuffle(r, DEFINITIONS.filter((d) => d[1] !== word)).slice(0, 3).map((d) => d[1]),
    tier: "hard", gradeLo: 7, gradeHi: 8 }));
  return [...bandItems(r, EASY, 2, 4, "easy"), ...bandItems(r, MEDIUM, 5, 6, "medium"), ...defs];
}

module.exports = { topic: "soccer", items };
