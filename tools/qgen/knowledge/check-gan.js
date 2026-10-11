// node tools/qgen/knowledge/check-gan.js <file.json> [other files to check duplicates against…]
// The gate for גן picture questions: the server's own gate + "every option is ONE widely supported picture".
"use strict";
const fs = require("fs");
const { qbProblems } = require("../core");
const [file, ...others] = process.argv.slice(2);
const items = JSON.parse(fs.readFileSync(file, "utf8"));
const bare = (s) => String(s).replace(/[֑-ׇ]/g, "").replace(/\p{Extended_Pictographic}|️/gu, "").replace(/\s+/g, " ").trim();
const seen = new Map();
for (const o of others) for (const q of JSON.parse(fs.readFileSync(o, "utf8"))) seen.set(bare(q.prompt), o);
// One emoji = one pictographic character, optionally followed by the emoji presentation selector. No ZWJ sequences, no skin tones, no flags, no keycaps.
const ONE = /^\p{Extended_Pictographic}️?$/u;
// Too new to draw on every phone still in use (added to Unicode after 2019), or not a picture of a thing (arrows, signs).
const cp = (e) => e.codePointAt(0);
const in_ = (c, ranges) => ranges.some(([lo, hi]) => c >= lo && c <= hi);
const UNICODE_12_IN_NEW_BLOCK = [[0x1FA70, 0x1FA73], [0x1FA78, 0x1FA7A], [0x1FA80, 0x1FA82], [0x1FA90, 0x1FA95]];
const tooNew = (e) => { const c = cp(e);
  return (c >= 0x1FA70 && c <= 0x1FAFF && !in_(c, UNICODE_12_IN_NEW_BLOCK))
      || in_(c, [[0x1F6D6, 0x1F6D7], [0x1F6DC, 0x1F6DF], [0x1F9A3, 0x1F9A4], [0x1F9AB, 0x1F9AD], [0x1F90C, 0x1F90C], [0x1F972, 0x1F972], [0x1F977, 0x1F979], [0x1F9CB, 0x1F9CC]]); };
const abstract = (e) => in_(cp(e), [[0x2190, 0x21FF], [0x2B05, 0x2B07], [0x27A1, 0x27A1], [0x2934, 0x2935], [0x274C, 0x274C], [0x2705, 0x2705],
  [0x2753, 0x2757], [0x2795, 0x2797], [0x1F500, 0x1F504], [0x1F519, 0x1F524], [0x1F52F, 0x1F533], [0x1F536, 0x1F53D], [0x1F4AF, 0x1F4AF]]);
let bad = 0;
for (const [i, q] of items.entries()) {
  const p = qbProblems(q);
  const opts = [q.correctAnswer, ...(q.distractors || [])];
  if ((q.distractors || []).length !== 3) p.push("needs exactly 3 distractors");
  for (const o of opts) {
    if (!ONE.test(String(o))) p.push("option is not ONE emoji: " + o);
    else if (tooNew(o)) p.push("emoji too new for older phones: " + o);
    else if (abstract(o)) p.push("option is an arrow/sign, not a picture: " + o);
  }
  if (new Set(opts).size !== opts.length) p.push("repeated option");
  if (q.gradeLo !== 0 || q.gradeHi !== 0) p.push("gradeLo/gradeHi must be 0");
  const lines = String(q.prompt).split("\n");
  if (lines.length !== 2 || !ONE.test(lines[0].trim())) p.push("prompt must be: one emoji, newline, question");
  else if (opts.includes(lines[0].trim())) p.push("the prompt's emoji is one of the options (gives it away or misleads)");
  const text = lines[1] || "";
  if (text.replace(/[֑-ׇ]/g, "").trim().split(/\s+/).length > 14) p.push("question longer than 14 words");
  if (/[A-Za-z0-9]/.test(text)) p.push("Latin letters or digits in a question for a child who cannot read");
  const key = bare(q.prompt);
  if (seen.has(key)) p.push("duplicate prompt (" + seen.get(key) + ")"); seen.set(key, "this file");
  if (p.length) { bad++; console.log(i, p.join("; "), "|", text.slice(0, 70)); }
}
console.log(items.length, "items,", bad, "with problems");
process.exitCode = bad ? 1 : 0;
