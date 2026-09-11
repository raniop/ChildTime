// node tools/qgen/import.js money soccer            → dry run: what WOULD be added
// node tools/qgen/import.js money soccer --write    → add them to the cloud bank as DRAFTS
//
// The same thing the admin page's "ייבוא" does (adminImportQuestions), for batches
// too big to paste: identical gate, identical dedupe (prompt + answer), identical
// item shape, and every item lands as a draft that waits in the review queue. It
// writes with a precondition on the document's updateTime, so a review happening
// in the admin at the same moment makes this fail instead of losing that review.
"use strict";
const fs = require("fs"), path = require("path");
const { execSync } = require("child_process");
const { qbProblems } = require("./core");

const PROJECT = "childtime-86e98";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const TIERS = ["easy", "medium", "hard"];
const write = process.argv.includes("--write");
const topics = process.argv.slice(2).filter((a) => !a.startsWith("--"));

// Firestore REST values ⇄ plain JS.
const enc = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  if (typeof v === "object") return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  return { stringValue: String(v) };
};
const dec = (v) => {
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(dec);
  if ("mapValue" in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, dec(x)]));
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("nullValue" in v) return null;
  return v.stringValue ?? v.timestampValue;
};

const token = execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
const api = async (url, opts = {}) => {
  const res = await fetch(url, { ...opts, headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } });
  const body = await res.json().catch(() => ({}));
  if (!res.ok && res.status !== 404) throw new Error(`${res.status} ${JSON.stringify(body).slice(0, 300)}`);
  return { status: res.status, body };
};
const key = (q) => `${String(q.prompt).trim()}|${String(q.correctAnswer).trim()}`;

(async () => {
  for (const topic of topics) {
    const incoming = JSON.parse(fs.readFileSync(path.join(__dirname, "out", `${topic}.json`), "utf8"));
    const { status, body: doc } = await api(`${BASE}/questionBanks/${topic}`);
    const cur = status === 404 ? { version: 0, items: [] } : dec({ mapValue: { fields: doc.fields || {} } });
    const items = Array.isArray(cur.items) ? cur.items : [];
    const have = new Set(items.map(key));
    const added = [], rejected = [];
    let dup = 0;
    for (const raw of incoming) {
      const problems = qbProblems(raw);
      if (problems.length) { rejected.push(problems.join(",")); continue; }
      if (have.has(key(raw))) { dup++; continue; }
      have.add(key(raw));
      added.push({
        id: `${topic}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
        prompt: String(raw.prompt).trim(),
        correctAnswer: String(raw.correctAnswer).trim(),
        distractors: raw.distractors.map((d) => String(d).trim()).filter(Boolean).slice(0, 3),
        tier: TIERS.includes(raw.tier) ? raw.tier : "medium",
        gradeLo: Number(raw.gradeLo), gradeHi: Number(raw.gradeHi),
        status: "draft",
        createdAt: Date.now(), createdBy: "tools/qgen",
      });
    }
    const next = { version: (cur.version || 0) + (added.length ? 1 : 0), items: items.concat(added), updatedAt: Date.now() };
    const bytes = Buffer.byteLength(JSON.stringify(next));
    console.log(`${topic}: in cloud ${items.length} · +${added.length} drafts · ↺ ${dup} duplicates · ❌ ${rejected.length} rejected · doc ≈ ${(bytes / 1024).toFixed(0)} KB`);
    // Firestore caps a document at 1 MiB; leave room for review stamps.
    if (bytes > 900 * 1024) { console.log(`  ⛔ ${topic} would exceed the document size limit — not written`); continue; }
    if (!write || !added.length) continue;

    const precondition = status === 404 ? "currentDocument.exists=false" : `currentDocument.updateTime=${encodeURIComponent(doc.updateTime)}`;
    await api(`${BASE}/questionBanks/${topic}?${precondition}`, {
      method: "PATCH", body: JSON.stringify({ fields: enc(next).mapValue.fields }),
    });
    await api(`${BASE}/questionBankIndex/current?updateMask.fieldPaths=${encodeURIComponent(`topics.${topic}`)}&updateMask.fieldPaths=updatedAt`, {
      method: "PATCH", body: JSON.stringify({ fields: { topics: enc({ [topic]: next.version }), updatedAt: enc(Date.now()) } }),
    });
    console.log(`  ✅ written · version ${next.version}`);
  }
  if (!write) console.log("\n(dry run — add --write to import)");
})().catch((e) => { console.error(e.message); process.exit(1); });
