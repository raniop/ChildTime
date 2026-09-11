// node tools/qgen/merge-knowledge.js <topic> <file.json>...
// Merge hand-written, fact-checked batches into docs/admin/generated/<topic>.json
// (the admin page's 📦 card imports them as drafts). Re-applies the server gate,
// drops anything that collides with a question already built into the app
// (the device would silently drop the cloud copy), and de-duplicates.
"use strict";
const fs = require("fs"), path = require("path"), { execSync } = require("child_process");
const { qbProblems } = require("./core");
const [topic, ...files] = process.argv.slice(2);
const out = path.join(__dirname, "..", "..", "docs", "admin", "generated", `${topic}.json`);
const bare = (s) => String(s).replace(/[֑-ׇ⁦-⁩‏]/g, "").replace(/\s+/g, " ").trim();

// Built-in prompts of this topic, straight from the Swift banks.
const models = path.join(__dirname, "..", "..", "ChildTime", "Models");
const swift = fs.readdirSync(models).filter((f) => f.startsWith("QuestionBanks")).map((f) => fs.readFileSync(path.join(models, f), "utf8")).join("\n");
const builtIn = new Set([...swift.matchAll(/BankQuestion\(prompt: "((?:[^"\\]|\\.)*)", correctAnswer: "((?:[^"\\]|\\.)*)"/g)]
  .map((m) => bare(m[1].replace(/\\n/g, "\n")) + "|" + bare(m[2])));

const existing = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : [];
const seen = new Set(existing.map((q) => bare(q.prompt)));
const merged = [...existing], report = { added: 0, gate: 0, builtIn: 0, dup: 0 };
for (const f of files) for (const q of JSON.parse(fs.readFileSync(f, "utf8"))) {
  if (qbProblems(q).length) { report.gate++; continue; }
  if (builtIn.has(bare(q.prompt) + "|" + bare(q.correctAnswer))) { report.builtIn++; continue; }
  if (seen.has(bare(q.prompt))) { report.dup++; continue; }
  seen.add(bare(q.prompt)); merged.push(q); report.added++;
}
fs.writeFileSync(out, JSON.stringify(merged, null, 2));
console.log(topic, JSON.stringify(report), "→", merged.length, "items");
execSync(`node ${path.join(__dirname, "run.js")}`);   // refresh index.json
