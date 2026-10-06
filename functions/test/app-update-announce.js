#!/usr/bin/env node
/**
 * 🔄 config/appUpdate → "יש גרסה חדשה של טופי" — announce + admin publish.
 *
 * Loads functions/index.js with firebase-functions / firebase-admin / nodemailer
 * replaced by in-memory fakes (no network, no credentials, nothing reaches
 * production) and checks:
 *  • only PARENT devices are targeted (never childFcmTokens, child-device rows,
 *    or tokens stamped role "child"),
 *  • the platform split: an iOS raise reaches iOS + unknown (legacy) tokens, an
 *    Android raise reaches Android tokens only; a device already on the new
 *    build is skipped,
 *  • per-language copy, with no Hebrew in en/ru/ar pushes,
 *  • idempotency: re-saving, lowering and re-raising, `enabled: false`, and
 *    `announce: false` never send,
 *  • the admin callable's guards (Hebrew in other languages, minBuild confirm,
 *    minBuild above latest, admin-only).
 *
 * Usage:  node functions/test/app-update-announce.js
 */
"use strict";
const Module = require("module");
const path = require("path");
const fs = require("fs");
const assert = require("assert");

const FUNCTIONS_DIR = path.resolve(__dirname, "..");
const HEB = /[֐-׿]/;

// ---- fake Firestore (just what this feature touches) -----------------------
class Sentinel { constructor(kind, values) { this.kind = kind; this.values = values; } }
const FieldValue = {
  delete: () => new Sentinel("delete"),
  serverTimestamp: () => new Sentinel("serverTimestamp"),
  arrayUnion: (...v) => new Sentinel("arrayUnion", v),
  arrayRemove: (...v) => new Sentinel("arrayRemove", v),
  increment: (n) => new Sentinel("increment", [n]),
};
const isPlain = (v) => v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Sentinel);
const clone = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));
function applyValue(cur, v) {
  if (!(v instanceof Sentinel)) return { set: true, value: clone(v) };
  switch (v.kind) {
    case "delete": return { set: false };
    case "serverTimestamp": return { set: true, value: Date.now() };
    case "arrayUnion": { const a = Array.isArray(cur) ? cur.slice() : []; v.values.forEach((x) => { if (!a.includes(x)) a.push(x); }); return { set: true, value: a }; }
    case "arrayRemove": return { set: true, value: (Array.isArray(cur) ? cur : []).filter((x) => !v.values.includes(x)) };
    case "increment": return { set: true, value: (Number(cur) || 0) + v.values[0] };
    default: throw new Error("sentinel " + v.kind);
  }
}
function mergeInto(target, data) {
  for (const [k, v] of Object.entries(data)) {
    if (isPlain(v)) { if (!isPlain(target[k])) target[k] = {}; mergeInto(target[k], v); continue; }
    const r = applyValue(target[k], v);
    if (r.set) target[k] = r.value; else delete target[k];
  }
}
function makeDb() {
  let store = new Map();
  const snap = (ref) => { const d = store.get(ref.path); return { id: ref.id, ref, exists: d !== undefined, data: () => clone(d) }; };
  function docRef(p) {
    const ref = {
      id: p.split("/").pop(), path: p,
      collection: (name) => colRef(`${p}/${name}`),
      get: async () => snap(ref),
      set: async (data, opts) => { const cur = opts && opts.merge ? clone(store.get(p) || {}) : {}; mergeInto(cur, data); store.set(p, cur); },
      update: async (data) => {
        if (!store.has(p)) throw Object.assign(new Error(`NOT_FOUND: ${p}`), { code: 5 });
        const cur = clone(store.get(p));
        for (const [k, v] of Object.entries(data)) { const r = applyValue(cur[k], v); if (r.set) cur[k] = r.value; else delete cur[k]; }
        store.set(p, cur);
      },
      delete: async () => { store.delete(p); },
    };
    return ref;
  }
  function colRef(c) {
    const inCol = (p) => p.startsWith(c + "/") && !p.slice(c.length + 1).includes("/");
    return {
      path: c,
      doc: (id) => docRef(`${c}/${id}`),
      get: async () => { const docs = [...store.keys()].filter(inCol).sort().map((p) => snap(docRef(p))); return { docs, size: docs.length, empty: !docs.length, forEach: (fn) => docs.forEach(fn) }; },
    };
  }
  return {
    collection: colRef, doc: docRef,
    runTransaction: async (fn) => fn({ get: (r) => r.get(), set: (r, d, o) => r.set(d, o), update: (r, d) => r.update(d) }),
    __reset(seed) { store = new Map(); for (const [p, d] of Object.entries(seed)) store.set(p, clone(d)); },
    __get: (p) => clone(store.get(p)),
  };
}

// ---- module stubs ----------------------------------------------------------
const ENV = { db: makeDb(), fcm: [] };
const trigger = (a, b) => ({ run: typeof b === "function" ? b : a, opts: typeof b === "function" ? a : null });
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
const STUBS = {
  "firebase-functions/v2/firestore": { onDocumentCreated: trigger, onDocumentWritten: trigger },
  "firebase-functions/v2/scheduler": { onSchedule: trigger },
  "firebase-functions/v2/https": { onRequest: trigger, onCall: trigger, HttpsError },
  "firebase-functions/v2/pubsub": { onMessagePublished: trigger },
  "firebase-functions/params": { defineSecret: (name) => ({ name, value: () => "" }) },
  "nodemailer": { createTransport: () => ({ sendMail: async () => ({}) }) },
  "google-auth-library": { GoogleAuth: class { async getClient() { throw new Error("no network in tests"); } } },
  "firebase-admin": {
    initializeApp: () => {},
    firestore: Object.assign(() => ENV.db, { FieldValue }),
    messaging: () => ({
      sendEachForMulticast: async (msg) => {
        ENV.fcm.push(clone(msg));
        const responses = msg.tokens.map((t) => (/dead/.test(t)
          ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
          : { success: true, messageId: "m" }));
        return { successCount: responses.filter((r) => r.success).length, failureCount: responses.filter((r) => !r.success).length, responses };
      },
    }),
    auth: () => ({ getUser: async () => ({}) }),
  },
};
const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (Object.prototype.hasOwnProperty.call(STUBS, request)) return STUBS[request];
  return origLoad.call(this, request, parent, isMain);
};
const filename = path.join(FUNCTIONS_DIR, "__app_update_harness.js");
const m = new Module(filename, module);
m.filename = filename;
m.paths = Module._nodeModulePaths(FUNCTIONS_DIR);
m._compile(fs.readFileSync(path.join(FUNCTIONS_DIR, "index.js"), "utf8"), filename);
const F = m.exports;

// ---- fixture ---------------------------------------------------------------
// P1: iOS parent on 197 (he), iOS parent already on 199, a legacy token (en, no stamp).
// P2: Android parent on 2001 (ru), a dead legacy token, an Arabic iOS phone on 198.
// KIDACC: anonymous kid account — child tokens only, plus a pre-split legacy
//         kid token still sitting in fcmTokens (its childDevices row names it).
// P3: a same-account kid device stamped role "child" in fcmTokens by mistake.
const seed = () => ({
  "households/HH1": { parentUIDs: ["P1", "P2", "KIDACC"] },
  "households/HH2": { parentUIDs: ["P3"] },
  "parents/P1": {
    fcmTokens: ["tok-ios-197", "tok-ios-199", "tok-legacy-en"],
    tokenLanguages: { "tok-ios-197": "he", "tok-ios-199": "he", "tok-legacy-en": "en" },
    tokenDevices: { "tok-ios-197": { platform: "ios", build: 197, role: "parent" }, "tok-ios-199": { platform: "ios", build: 199, role: "parent" } },
  },
  "parents/P2": {
    fcmTokens: ["tok-and-2001", "tok-dead-legacy", "tok-ios-ar"],
    tokenLanguages: { "tok-and-2001": "ru", "tok-ios-ar": "ar" },
    tokenDevices: { "tok-and-2001": { platform: "android", build: 2001, role: "parent" }, "tok-ios-ar": { platform: "ios", build: 198, role: "parent" } },
  },
  "parents/KIDACC": { childFcmTokens: ["tok-kid-1"], fcmTokens: ["tok-kid-legacy"] },
  "parents/P3": { fcmTokens: ["tok-p3-kid"], tokenDevices: { "tok-p3-kid": { platform: "ios", build: 150, role: "child" } } },
  "children/K1": { householdID: "HH1", name: "נועה" },
  "childDevices/K1_A": { childID: "K1", householdID: "HH1", fcmToken: "tok-kid-legacy" },
  "config/appUpdate": { latestBuild: 197, version: "2026.10.3", latestAndroidBuild: 2001, androidVersion: "2026.10.5", enabled: true,
    notesByLang: { he: ["תיקון באג בנעילה"], en: ["Lock fix"], ru: [], ar: [] }, notes: ["תיקון באג בנעילה"] },
});
const ADMIN = { uid: "admin-uid", token: { email: "ranioph@gmail.com", email_verified: true } };
const write = async (after) => {
  const before = ENV.db.__get("config/appUpdate");
  if (after) await ENV.db.doc("config/appUpdate").set(after); else await ENV.db.doc("config/appUpdate").delete();
  const snap = (d) => ({ exists: d !== undefined && d !== null, data: () => clone(d) });
  await F.announceAppUpdate.run({ params: {}, data: { before: snap(before), after: snap(after) } });
};
const sentTo = () => ENV.fcm.flatMap((x) => x.tokens);
const msgFor = (tok) => ENV.fcm.find((x) => x.tokens.includes(tok));
const reset = () => { ENV.db.__reset(seed()); ENV.fcm = []; };

const tests = [];
const test = (name, fn) => tests.push({ name, fn });

test("iOS raise: iOS + legacy parent tokens below the new build, nobody else", async () => {
  reset();
  await write({ ...seed()["config/appUpdate"], latestBuild: 199, version: "2026.10.4" });
  assert.deepStrictEqual(sentTo().sort(), ["tok-dead-legacy", "tok-ios-197", "tok-ios-ar", "tok-legacy-en"].sort());
  const he = msgFor("tok-ios-197");
  assert.strictEqual(he.notification.title, "יש גרסה חדשה של טופי ✨");
  assert.ok(he.notification.body.includes("2026.10.4") && he.notification.body.includes("App Store"));
  assert.ok(he.notification.body.includes("תיקון באג בנעילה"), "Hebrew note line");
  assert.strictEqual(he.data.type, "appUpdate");
  assert.strictEqual(he.android.notification.channelId, "reports");
  const en = msgFor("tok-legacy-en");
  assert.ok(!HEB.test(JSON.stringify(en)), "no Hebrew in the English push");
  assert.ok(en.notification.body.includes("Lock fix"));
  const ar = msgFor("tok-ios-ar");
  assert.ok(!HEB.test(JSON.stringify(ar)), "no Hebrew in the Arabic push (no ar notes → no note line)");
  assert.ok(!ar.notification.body.includes("\n"));
  // dead token pruned; idempotency record written
  assert.ok(!ENV.db.__get("parents/P2").fcmTokens.includes("tok-dead-legacy"));
  const ann = ENV.db.__get("adminStats/appUpdateAnnounce");
  assert.strictEqual(ann.ios, 199);
  assert.strictEqual(ann.android, undefined);
  assert.strictEqual(ann.last.sent, 3);
  assert.strictEqual(ann.last.failed, 1);
});

test("re-saving the same numbers never re-sends", async () => {
  reset();
  const cfg = { ...seed()["config/appUpdate"], latestBuild: 199 };
  await write(cfg); ENV.fcm = [];
  await write({ ...cfg, notesByLang: { he: ["עוד שורה"], en: [], ru: [], ar: [] } });
  await write(cfg);
  assert.strictEqual(ENV.fcm.length, 0);
});

test("lowering and re-raising to an announced build never re-sends", async () => {
  reset();
  const cfg = { ...seed()["config/appUpdate"], latestBuild: 199 };
  await write(cfg); ENV.fcm = [];
  await write({ ...cfg, latestBuild: 198 });
  await write({ ...cfg, latestBuild: 199 });
  assert.strictEqual(ENV.fcm.length, 0);
  await write({ ...cfg, latestBuild: 200 });
  assert.ok(ENV.fcm.length > 0, "a genuinely newer build is announced");
  assert.ok(sentTo().includes("tok-ios-199"));
});

test("Android raise: Android parent tokens only, Russian + Google Play", async () => {
  reset();
  await write({ ...seed()["config/appUpdate"], latestAndroidBuild: 2002, androidVersion: "2026.10.6" });
  assert.deepStrictEqual(sentTo(), ["tok-and-2001"]);
  const ru = msgFor("tok-and-2001");
  assert.strictEqual(ru.notification.title, "Вышла новая версия Tofy ✨");
  assert.ok(ru.notification.body.includes("Google Play") && ru.notification.body.includes("2026.10.6"));
  assert.ok(!HEB.test(JSON.stringify(ru)));
  assert.strictEqual(ru.data.platform, "android");
  assert.strictEqual(ENV.db.__get("adminStats/appUpdateAnnounce").android, 2002);
});

test("enabled:false and announce:false send nothing and record nothing", async () => {
  reset();
  await write({ ...seed()["config/appUpdate"], latestBuild: 199, enabled: false });
  await write({ ...seed()["config/appUpdate"], latestBuild: 200, announce: false });
  assert.strictEqual(ENV.fcm.length, 0);
  assert.strictEqual(ENV.db.__get("adminStats/appUpdateAnnounce"), undefined);
});

test("child devices are never targeted", async () => {
  reset();
  await write({ ...seed()["config/appUpdate"], latestBuild: 500, latestAndroidBuild: 5000 });
  for (const t of ["tok-kid-1", "tok-kid-legacy", "tok-p3-kid"]) assert.ok(!sentTo().includes(t), t);
});

const call = (fn, data, auth = ADMIN) => F[fn].run({ data: clone(data), auth });
const form = (over) => ({ latestBuild: 199, version: "2026.10.4", latestAndroidBuild: 2002, androidVersion: "2026.10.6", enabled: true, announce: true,
  notesByLang: { he: ["שיפורים"], en: ["Improvements"], ru: [], ar: [] }, minBuild: 0, minAndroidBuild: 0, ...over });
const rejects = async (p, code) => { try { await p; } catch (e) { assert.strictEqual(e.code, code, e.message); return; } assert.fail("expected " + code); };

test("adminPublishAppUpdate writes the whole doc and mirrors Hebrew into legacy notes", async () => {
  reset();
  const r = await call("adminPublishAppUpdate", form());
  const d = ENV.db.__get("config/appUpdate");
  assert.strictEqual(d.latestBuild, 199); assert.strictEqual(d.latestAndroidBuild, 2002);
  assert.deepStrictEqual(d.notes, ["שיפורים"]);
  assert.deepStrictEqual(d.notesByLang.en, ["Improvements"]);
  assert.strictEqual(d.updatedBy, "ranioph@gmail.com");
  assert.ok(Number.isInteger(d.latestBuild));
  assert.strictEqual(r.config.version, "2026.10.4");
  await call("adminPublishAppUpdate", form({ legacyNotes: false }));
  assert.deepStrictEqual(ENV.db.__get("config/appUpdate").notes, []);
});

test("adminPublishAppUpdate guards", async () => {
  reset();
  await rejects(call("adminPublishAppUpdate", form({ notesByLang: { he: [], en: ["תיקון"], ru: [], ar: [] } })), "invalid-argument");
  await rejects(call("adminPublishAppUpdate", form({ minBuild: 190 })), "failed-precondition");
  await rejects(call("adminPublishAppUpdate", form({ minBuild: 300, confirmMinBuild: true })), "invalid-argument");
  await rejects(call("adminPublishAppUpdate", form({ latestBuild: 199.5 })), "invalid-argument");
  await rejects(call("adminPublishAppUpdate", form(), { uid: "x", token: { email: "someone@example.com", email_verified: true } }), "permission-denied");
  await call("adminPublishAppUpdate", form({ minBuild: 190, confirmMinBuild: true }));
  assert.strictEqual(ENV.db.__get("config/appUpdate").minBuild, 190);
  // unchanged floor → no confirmation needed again
  await call("adminPublishAppUpdate", form({ minBuild: 190, version: "2026.10.4b" }));
  // turning the floor off needs no confirmation either
  await call("adminPublishAppUpdate", form({ minBuild: 0 }));
  assert.strictEqual(ENV.db.__get("config/appUpdate").minBuild, 0);
});

test("adminAppUpdateReach previews the same audience", async () => {
  reset();
  const r = await call("adminAppUpdateReach", { latestBuild: 199, latestAndroidBuild: 2002 });
  assert.strictEqual(r.targeted, 5);   // 197, ar 198, legacy-en, dead-legacy, android 2001
  assert.strictEqual(r.counts.alreadyCurrent, 1);
  assert.strictEqual(r.counts.unknownPlatform, 2);
  assert.deepStrictEqual(r.installed.ios, { 197: 1, 198: 1, 199: 1 });
  assert.deepStrictEqual(r.installed.android, { 2001: 1 });
  assert.strictEqual(ENV.fcm.length, 0, "a preview sends nothing");
});

(async () => {
  let failed = 0;
  const log = console.log;
  for (const t of tests) {
    console.log = () => {};   // the functions' own logging
    try { await t.fn(); console.log = log; log(`✅ ${t.name}`); }
    catch (e) { console.log = log; failed++; log(`❌ ${t.name}\n   ${e && e.stack || e}`); }
  }
  console.log = log;
  if (failed) { console.error(`\n${failed} of ${tests.length} failed`); process.exit(1); }
  console.log(`\nAll ${tests.length} app-update tests passed.`);
})();
