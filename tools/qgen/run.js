// node tools/qgen/run.js money soccer   →  docs/admin/generated/<topic>.json + a report
// The admin page lists those files under "📦 שאלות מהמחולל" and imports them as drafts.
"use strict";
const fs = require("fs"), path = require("path");
const { collect } = require("./core");
const TARGET = Number(process.env.PER_GRADE || 200);
const outDir = path.join(__dirname, "..", "..", "docs", "admin", "generated"); fs.mkdirSync(outDir, { recursive: true });
for (const name of process.argv.slice(2)) {
  const gen = require(`./${name}`);
  const all = []; const report = [];
  for (let grade = 1; grade <= 6; grade++) {
    if (!gen.byGrade[grade]) continue;   // a generator may cover only some grades
    const { items, rejected } = collect(gen.topic, grade, TARGET, gen.byGrade[grade]);
    all.push(...items);
    const tiers = items.reduce((m, i) => (m[i.tier] = (m[i.tier] || 0) + 1, m), {});
    report.push(`  כיתה ${grade}: ${String(items.length).padStart(3)} ${items.length < TARGET ? "⚠️ " : "✅"}  ${JSON.stringify(tiers)}${Object.keys(rejected).length ? "  נדחו: " + JSON.stringify(rejected) : ""}`);
  }
  fs.writeFileSync(path.join(outDir, `${gen.topic}.json`), JSON.stringify(all, null, 2));
  console.log(`\n${gen.topic}: ${all.length} items`); console.log(report.join("\n"));
}
// index.json — what the admin page offers to import.
const batches = fs.readdirSync(outDir).filter((f) => f.endsWith(".json") && f !== "index.json").map((f) => {
  const items = JSON.parse(fs.readFileSync(path.join(outDir, f), "utf8"));
  const byGrade = items.reduce((m, i) => (m[i.gradeLo] = (m[i.gradeLo] || 0) + 1, m), {});
  return { topic: f.replace(/\.json$/, ""), count: items.length, byGrade, generatedAt: fs.statSync(path.join(outDir, f)).mtime.toISOString() };
});
fs.writeFileSync(path.join(outDir, "index.json"), JSON.stringify({ batches }, null, 2));
