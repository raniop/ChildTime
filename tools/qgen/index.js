// Rebuild docs/admin/generated/index.json — what the admin page offers to import.
//   node tools/qgen/index.js
// Hebrew batches sit in generated/ (no lang); English (US) batches in generated/en/
// carry lang "en", so the dashboard lists them under 🇺🇸 and imports them as English.
const fs = require("fs"), path = require("path");
const outDir = path.join(__dirname, "..", "..", "docs", "admin", "generated");

function batchesIn(dir, prefix, lang) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.endsWith(".json") && f !== "index.json").sort().map((f) => {
    const items = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
    const byGrade = items.reduce((m, i) => (m[i.gradeLo] = (m[i.gradeLo] || 0) + 1, m), {});
    // "soccer-english.json" belongs to the soccer world; "animals-w1-part2.json" to animals.
    const topic = f.replace(/\.json$/, "").split("-")[0];
    const label = f.includes("-") ? f.replace(/\.json$/, "").split("-").slice(1).join(" ") : "";
    return { topic, file: prefix + f, label, count: items.length, byGrade,
      generatedAt: fs.statSync(path.join(dir, f)).mtime.toISOString(), ...(lang ? { lang } : {}) };
  });
}

function writeIndex() {
  const batches = [...batchesIn(outDir, "", null), ...batchesIn(path.join(outDir, "en"), "en/", "en")];
  fs.writeFileSync(path.join(outDir, "index.json"), JSON.stringify({ batches }, null, 2));
  return batches;
}

module.exports = { writeIndex };
if (require.main === module) {
  const b = writeIndex();
  console.log(`index.json: ${b.length} batches (${b.filter((x) => x.lang === "en").length} English)`);
}
