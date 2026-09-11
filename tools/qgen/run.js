// node tools/qgen/run.js money soccer   →  docs/admin/generated/<topic>.json + a report
// The admin page lists those files under "📦 שאלות מהמחולל" and imports them as drafts.
"use strict";
const fs = require("fs"), path = require("path");
const { collect } = require("./core");
const TARGET = Number(process.env.PER_GRADE || 200);
const outDir = path.join(__dirname, "..", "..", "docs", "admin", "generated"); fs.mkdirSync(outDir, { recursive: true });
const { qbProblems, rng } = require("./core");
for (const name of process.argv.slice(2)) {
  const gen = require(`./${name}`);
  // A module with a fixed item list (e.g. soccer-english: every word once) writes
  // <name>.json; its world comes from `topic`, so the admin imports it there.
  if (gen.items) {
    const list = gen.items(rng(97 + name.length)), bad = list.filter((q) => qbProblems(q).length);
    const seen = new Set(), unique = list.filter((q) => !bad.includes(q) && !seen.has(q.prompt + "|" + q.correctAnswer) && seen.add(q.prompt + "|" + q.correctAnswer));
    fs.writeFileSync(path.join(outDir, `${name}.json`), JSON.stringify(unique, null, 2));
    console.log(`\n${name} → ${gen.topic}: ${unique.length} items${bad.length ? ` (${bad.length} failed the gate)` : ""}`);
    continue;
  }
  const all = []; const report = [];
  for (let grade = 1; grade <= 8; grade++) {
    if (!gen.byGrade[grade]) continue;   // a generator may cover only some grades
    const { items, rejected } = collect(gen.topic, grade, TARGET, gen.byGrade[grade]);
    all.push(...items);
    const tiers = items.reduce((m, i) => (m[i.tier] = (m[i.tier] || 0) + 1, m), {});
    report.push(`  כיתה ${grade}: ${String(items.length).padStart(3)} ${items.length < TARGET ? "⚠️ " : "✅"}  ${JSON.stringify(tiers)}${Object.keys(rejected).length ? "  נדחו: " + JSON.stringify(rejected) : ""}`);
  }
  fs.writeFileSync(path.join(outDir, `${gen.topic}.json`), JSON.stringify(all, null, 2));
  console.log(`\n${gen.topic}: ${all.length} items`); console.log(report.join("\n"));
}
// index.json — what the admin page offers to import (Hebrew + English batches).
require("./index.js").writeIndex();
