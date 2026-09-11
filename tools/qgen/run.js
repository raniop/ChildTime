// node tools/qgen/run.js money soccer   →  tools/qgen/out/<topic>.json + a report
"use strict";
const fs = require("fs"), path = require("path");
const { collect } = require("./core");
const TARGET = Number(process.env.PER_GRADE || 200);
const outDir = path.join(__dirname, "out"); fs.mkdirSync(outDir, { recursive: true });
for (const name of process.argv.slice(2)) {
  const gen = require(`./${name}`);
  const all = []; const report = [];
  for (let grade = 1; grade <= 6; grade++) {
    const { items, rejected } = collect(gen.topic, grade, TARGET, gen.byGrade[grade]);
    all.push(...items);
    const tiers = items.reduce((m, i) => (m[i.tier] = (m[i.tier] || 0) + 1, m), {});
    report.push(`  כיתה ${grade}: ${String(items.length).padStart(3)} ${items.length < TARGET ? "⚠️ " : "✅"}  ${JSON.stringify(tiers)}${Object.keys(rejected).length ? "  נדחו: " + JSON.stringify(rejected) : ""}`);
  }
  fs.writeFileSync(path.join(outDir, `${gen.topic}.json`), JSON.stringify(all, null, 2));
  console.log(`\n${gen.topic}: ${all.length} items`); console.log(report.join("\n"));
}
