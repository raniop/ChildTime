// Shared machinery for computed question generators.
//
// Every item here is correct BY CONSTRUCTION — the answer is calculated, never
// remembered — which is what makes generating thousands safe. Everything still
// passes the exact same quality gate the server applies on import.
"use strict";
const fs = require("fs");
const path = require("path");

// Pull qbProblems straight from functions/index.js so the generator and the
// server can never disagree about what a playable item is.
const src = fs.readFileSync(path.join(__dirname, "..", "..", "functions", "index.js"), "utf8");
const gateSrc = src.slice(src.indexOf("const QB_TIERS"), src.indexOf("function qbKey"));
const qbProblems = new Function(gateSrc + "\nreturn qbProblems;")();

// Deterministic PRNG so a run is reproducible and reviewable.
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const int = (r, lo, hi) => lo + Math.floor(r() * (hi - lo + 1));
const pick = (r, arr) => arr[Math.floor(r() * arr.length)];

// Three wrong numbers a child could genuinely arrive at.
//
// `mistakes` come first: the specific wrong operation for THIS question (added
// instead of multiplied, forgot to divide, took the total). Then near misses —
// small steps only, inside [min, max]. The old version reached ±10 steps, which
// put "15" next to an answer of 5 for a first-grader and "208 ₪" in a split of
// 80 ₪ — options nobody would pick, so they tested nothing.
function numericDistractors(r, answer, { step = 1, min = 0, max = Infinity, mistakes = [], fmt = String } = {}) {
  const out = [];
  const push = (v) => {
    v = Math.round(v * 100) / 100;
    if (Number.isFinite(v) && v !== answer && v >= min && v <= max && !out.includes(v)) out.push(v);
  };
  for (const v of mistakes) push(v);
  for (const o of [step, -step, 2 * step, -2 * step, 3 * step, -3 * step].sort(() => r() - 0.5)) {
    if (out.length >= 3) break;
    push(answer + o);
  }
  for (let k = 4; out.length < 3 && k < 60; k++) { push(answer + k * step); push(answer - k * step); }
  return out.slice(0, 3).map(fmt);
}

// Hebrew prefixes that change the word they attach to:
//  • ל/ב/כ + the definite article merge:  לְ + הַשְּׁחֹרִים → לַשְּׁחֹרִים
//  • a dagesh qal drops after a prefix:     לְ + דָּנָה     → לְדָנָה
const DAGESH = "\u05BC", PATAH = "\u05B7", QAMATS = "\u05B8";
const isMark = (ch) => ch >= "\u0591" && ch <= "\u05C7";
function prefixed(prefix, word) {
  const base = prefix[0]; // ל / ב / כ / ו
  // Split off the first letter together with all its marks — in Unicode the
  // dagesh sits AFTER the vowel (canonical order), not right after the letter.
  let n = 1; while (n < word.length && isMark(word[n])) n++;
  const head = word.slice(0, n), rest = word.slice(n);
  if ((base === "ל" || base === "ב" || base === "כ") && head[0] === "ה" && (head.includes(PATAH) || head.includes(QAMATS))) {
    const vowel = head.includes(PATAH) ? PATAH : QAMATS;
    // ב and כ take a dagesh when they swallow the article (בַּמִּגְרָשׁ); ל never does (לַשְּׁחֹרִים).
    return base + vowel + (base === "ל" ? "" : DAGESH) + rest;
  }
  if ("בגדכפת".includes(head[0])) return prefix + head.split(DAGESH).join("") + rest;
  return prefix + word;
}

// "and" in front of a word — the conjunction changes shape by what follows:
//  • before ב/מ/פ, or a letter carrying a shva:  וּבֻבָּה · וּמַחְבֶּרֶת · וּגְלִידָה
//  • before יְ it merges into a hiriq:           וִירֻקִּים
//  • otherwise וְ, and a dagesh qal still drops:  וְכַדּוּר · וְסֵפֶר
const SHVA = "\u05B0", HIRIQ = "\u05B4";
function and(word) {
  let n = 1; while (n < word.length && isMark(word[n])) n++;
  const head = word.slice(0, n), rest = word.slice(n);
  const soft = "בגדכפת".includes(head[0]) ? head.split(DAGESH).join("") : head;
  if (head[0] === "י" && head.includes(SHVA)) return "וִ" + "י" + rest;
  if ("במפ".includes(head[0]) || head.includes(SHVA)) return "וּ" + soft + rest;
  return "וְ" + soft + rest;
}

// Boy/girl names with the verb forms that match them — Hebrew agrees in gender,
// so a template carries both and the generator picks the matching one.
const KIDS = [
  { n: "דָּנָה", g: "f" }, { n: "יוֹאָב", g: "m" }, { n: "נוֹעָה", g: "f" }, { n: "אוּרִי", g: "m" },
  { n: "מָאיָה", g: "f" }, { n: "אִיתַי", g: "m" }, { n: "תָּמָר", g: "f" }, { n: "עִידוֹ", g: "m" },
  { n: "שִׁירָה", g: "f" }, { n: "רוֹעִי", g: "m" }, { n: "לִיָּה", g: "f" }, { n: "אֵיתָן", g: "m" },
];
const g = (kid, m, f) => (kid.g === "f" ? f : m);

// Run a generator until it produces `target` unique, gate-passing items.
function collect(topic, grade, target, make, { seed = 1, maxTries = 20000 } = {}) {
  const r = rng(seed * 1009 + grade * 97 + topic.length);
  const out = [], keys = new Set(), rejected = {};
  for (let i = 0; i < maxTries && out.length < target; i++) {
    const q = make(r, grade);
    if (!q) continue;
    const item = { gradeLo: grade, gradeHi: grade, tier: "medium", ...q };
    const key = `${item.prompt}|${item.correctAnswer}`;
    if (keys.has(key)) continue;
    const problems = qbProblems(item);
    if (problems.length) { for (const p of problems) rejected[p] = (rejected[p] || 0) + 1; continue; }
    keys.add(key); out.push(item);
  }
  return { items: out, rejected };
}

// A share can't pass 100% or go below 0 — a "110%" option is one a child
// crosses out instantly, so it does no work as a distractor.
function pctDistractors(r, pct, step = 5) {
  const cands = [pct + step, pct - step, pct + 2 * step, pct - 2 * step, pct + 3 * step, pct - 3 * step,
                 100 - pct, pct + 1, pct - 1];
  const out = [];
  for (const v of cands.sort(() => r() - 0.5)) {
    if (v === pct || v < 0 || v > 100 || out.includes(v)) continue;
    out.push(v); if (out.length === 3) break;
  }
  return out.map((v) => `${v}%`);
}

// Math inside a Hebrew question: keep it left-to-right and in one piece (a
// wrap split "x = 0" across lines; "−5" can render as "5−" without the isolate).
const ltr = (x) => `\u2066${String(x).replace(/ /g, "\u00A0")}\u2069`;
// A signed number as a child reads it: real minus sign, isolated.
const signed = (n) => ltr(n < 0 ? `−${-n}` : `${n}`);
const gcd = (a, b) => (b ? gcd(b, a % b) : Math.abs(a));
const frac = (n, d) => { const k = gcd(n, d); return ltr(`${n / k}/${d / k}`); };

module.exports = { qbProblems, rng, int, pick, numericDistractors, pctDistractors, prefixed, and, KIDS, g, collect, ltr, signed, gcd, frac };
