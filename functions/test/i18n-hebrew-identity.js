#!/usr/bin/env node
/**
 * 🌍 i18n harness for functions/index.js — "Hebrew must not change".
 *
 * Loads the ORIGINAL index.js (from git) and the CURRENT one side by side, with
 * firebase-functions / firebase-admin / nodemailer replaced by in-memory fakes
 * (no network, no credentials, nothing reaches production). Every trigger that
 * sends a push or an email is run over a matrix of inputs, and everything that
 * leaves the server — each FCM multicast payload, each email, each callable's
 * return value, and the final Firestore state — is captured.
 *
 *  Suite 1 · Hebrew identity: a family with NO language data (every install
 *    before the language picker). ORIGINAL and CURRENT must produce identical
 *    output, byte for byte.
 *  Suite 2 · Mixed languages: the same family with some devices set to English.
 *    Per token: a Hebrew device gets exactly what the ORIGINAL sent it; an
 *    English device gets the same number of messages (minus campaigns with no
 *    English copy), with the same data/apns shape, and no Hebrew letters.
 *
 * Usage (from the repo root or functions/):
 *   node functions/test/i18n-hebrew-identity.js            # base = last commit before i18n (auto)
 *   node functions/test/i18n-hebrew-identity.js --base=HEAD
 *   node functions/test/i18n-hebrew-identity.js --show-en  # print every English message
 */
"use strict";
const Module = require("module");
const path = require("path");
const assert = require("assert");
const { execFileSync } = require("child_process");

const FUNCTIONS_DIR = path.resolve(__dirname, "..");
const REPO = path.resolve(FUNCTIONS_DIR, "..");
const args = process.argv.slice(2);
const SHOW_EN = args.includes("--show-en");

// ---- which ORIGINAL to compare against -------------------------------------
function baseRef() {
  const explicit = args.find((a) => a.startsWith("--base="));
  if (explicit) return explicit.slice(7);
  // The commit that introduced the language plumbing; its parent is pre-i18n.
  try {
    const intro = execFileSync("git", ["-C", REPO, "log", "--format=%H", "-S", "TOKEN_LANG", "--", "functions/index.js"],
      { encoding: "utf8" }).trim().split("\n").filter(Boolean).pop();
    if (intro) return `${intro}^`;
  } catch (e) { /* not a git checkout → fall through */ }
  return "HEAD";
}
const BASE = baseRef();
const baseSource = execFileSync("git", ["-C", REPO, "show", `${BASE}:functions/index.js`], { encoding: "utf8", maxBuffer: 64 << 20 });
const currentSource = require("fs").readFileSync(path.join(FUNCTIONS_DIR, "index.js"), "utf8");

// ---- deterministic world ---------------------------------------------------
const FIXED_NOW = Date.parse("2026-09-15T14:30:00Z");          // Tuesday 17:30 Asia/Jerusalem
const NOW_S = FIXED_NOW / 1000;
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length === 0) super(FIXED_NOW); else super(...a); }
  static now() { return FIXED_NOW; }
}
global.Date = FakeDate;
require("crypto").randomBytes = (n) => Buffer.alloc(n, 0xab);   // chore photo tokens

// ---- fake Firestore --------------------------------------------------------
class Sentinel { constructor(kind, values) { this.kind = kind; this.values = values; } }
class Timestamp {
  constructor(ms) { this._ms = ms; }
  toMillis() { return this._ms; }
  toDate() { return new Date(this._ms); }
}
const FieldValue = {
  delete: () => new Sentinel("delete"),
  serverTimestamp: () => new Sentinel("serverTimestamp"),
  arrayUnion: (...v) => new Sentinel("arrayUnion", v),
  arrayRemove: (...v) => new Sentinel("arrayRemove", v),
  increment: (n) => new Sentinel("increment", [n]),
};
const isPlain = (v) => v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Sentinel) && !(v instanceof Timestamp) && !Buffer.isBuffer(v);
function clone(v) {
  if (Array.isArray(v)) return v.map(clone);
  if (v instanceof Timestamp) return new Timestamp(v._ms);
  if (Buffer.isBuffer(v)) return Buffer.from(v);
  if (v instanceof Sentinel) return v;
  if (isPlain(v)) { const o = {}; for (const [k, x] of Object.entries(v)) o[k] = clone(x); return o; }
  return v;
}
function applyValue(cur, v) {
  if (!(v instanceof Sentinel)) return { set: true, value: clone(v) };
  switch (v.kind) {
    case "delete": return { set: false };
    case "serverTimestamp": return { set: true, value: new Timestamp(FIXED_NOW) };
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
function setPath(target, dotted, v) {
  const parts = dotted.split(".");
  let o = target;
  for (const p of parts.slice(0, -1)) { if (!isPlain(o[p])) o[p] = {}; o = o[p]; }
  const last = parts[parts.length - 1];
  const r = applyValue(o[last], v);
  if (r.set) o[last] = r.value; else delete o[last];
}
const getPath = (obj, dotted) => dotted.split(".").reduce((o, p) => (o == null ? undefined : o[p]), obj);

function makeDb() {
  let store = new Map();
  let autoId = 0;
  const snap = (ref) => {
    const d = store.get(ref.path);
    return { id: ref.id, ref, exists: d !== undefined, data: () => (d === undefined ? undefined : clone(d)),
      get: (f) => (d === undefined ? undefined : clone(getPath(d, f))),
      updateTime: new Timestamp(FIXED_NOW - 1000), createTime: new Timestamp(FIXED_NOW - 5000) };
  };
  const qsnap = (docs) => ({ docs, size: docs.length, empty: docs.length === 0, forEach: (fn) => docs.forEach(fn) });
  function docRef(p) {
    const id = p.split("/").pop();
    const ref = {
      id, path: p,
      collection: (name) => colRef(`${p}/${name}`),
      get: async () => snap(ref),
      set: async (data, opts) => {
        if (opts && opts.merge) { const cur = clone(store.get(p) || {}); mergeInto(cur, data); store.set(p, cur); }
        else { const cur = {}; mergeInto(cur, data); store.set(p, cur); }
      },
      update: async (data) => {
        if (!store.has(p)) { const e = new Error(`NOT_FOUND: ${p}`); e.code = 5; throw e; }
        const cur = clone(store.get(p));
        for (const [k, v] of Object.entries(data)) setPath(cur, k, v);
        store.set(p, cur);
      },
      create: async (data) => {
        if (store.has(p)) { const e = new Error(`ALREADY_EXISTS: ${p}`); e.code = 6; throw e; }
        const cur = {}; mergeInto(cur, data); store.set(p, cur);
      },
      delete: async () => { store.delete(p); },
    };
    return ref;
  }
  function query(match, state = {}) {
    const q = {
      where: (f, op, v) => query((p, d) => match(p, d) && test(getPath(d, f), op, v), state),
      orderBy: (f, dir) => query(match, { ...state, order: [f, dir] }),
      limit: (n) => query(match, { ...state, limit: n }),
      select: () => q,
      get: async () => {
        let paths = [...store.keys()].filter((p) => match(p, store.get(p))).sort();
        if (state.order) {
          const [f, dir] = state.order;
          paths.sort((a, b) => { const x = getPath(store.get(a), f), y = getPath(store.get(b), f); return (x < y ? -1 : x > y ? 1 : 0) * (dir === "desc" ? -1 : 1); });
        }
        if (state.limit) paths = paths.slice(0, state.limit);
        return qsnap(paths.map((p) => snap(docRef(p))));
      },
    };
    return q;
  }
  function test(val, op, v) {
    switch (op) {
      case "==": return val === v;
      case "array-contains": return Array.isArray(val) && val.includes(v);
      case "<=": return val !== undefined && val <= v;
      case ">=": return val !== undefined && val >= v;
      case "<": return val !== undefined && val < v;
      case ">": return val !== undefined && val > v;
      case "in": return v.includes(val);
      default: throw new Error("op " + op);
    }
  }
  function colRef(c) {
    const inCol = (p) => p.startsWith(c + "/") && !p.slice(c.length + 1).includes("/");
    const q = query((p) => inCol(p));
    return { ...q, path: c, doc: (id) => docRef(`${c}/${id || `auto${String(++autoId).padStart(4, "0")}`}`) };
  }
  return {
    collection: colRef,
    doc: docRef,
    collectionGroup: (name) => query((p) => { const s = p.split("/"); return s.length % 2 === 0 && s[s.length - 2] === name; }),
    runTransaction: async (fn) => fn({
      get: (ref) => ref.get(),
      set: (ref, d, o) => ref.set(d, o),
      update: (ref, d) => ref.update(d),
    }),
    batch: () => { const ops = []; return { set: (r, d, o) => ops.push(() => r.set(d, o)), update: (r, d) => ops.push(() => r.update(d)), delete: (r) => ops.push(() => r.delete()), commit: async () => { for (const op of ops) await op(); } }; },
    recursiveDelete: async (ref) => { for (const p of [...store.keys()]) if (p === ref.path || p.startsWith(ref.path + "/")) store.delete(p); },
    // harness-only
    __reset(seed) { store = new Map(); autoId = 0; for (const [p, d] of Object.entries(seed)) { const cur = {}; mergeInto(cur, d); store.set(p, cur); } },
    __dump() { const o = {}; for (const p of [...store.keys()].sort()) o[p] = clone(store.get(p)); return o; },
  };
}

// ---- module stubs ----------------------------------------------------------
const ENV = { db: makeDb(), cap: [] };
const trigger = (a, b) => ({ run: typeof b === "function" ? b : a, opts: typeof b === "function" ? a : null });
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
const STUBS = {
  "firebase-functions/v2/firestore": { onDocumentCreated: trigger, onDocumentWritten: trigger },
  "firebase-functions/v2/scheduler": { onSchedule: trigger },
  "firebase-functions/v2/https": { onRequest: trigger, onCall: trigger, HttpsError },
  "firebase-functions/params": { defineSecret: (name) => ({ name, value: () => ({ GMAIL_USER: "bot@example.com", GMAIL_PASS: "pw", ADMIN_TASK_TOKEN: "tok" }[name] || "") }) },
  "nodemailer": { createTransport: () => ({ sendMail: async (m) => { ENV.cap.push({ kind: "mail", msg: clone(m) }); return { messageId: "x" }; } }) },
  "firebase-admin": {
    initializeApp: () => {},
    firestore: Object.assign(() => ENV.db, { FieldValue, Timestamp }),
    messaging: () => ({
      sendEachForMulticast: async (msg) => {
        ENV.cap.push({ kind: "fcm", msg: clone(msg) });
        const responses = msg.tokens.map((t) => (/dead/.test(t)
          ? { success: false, error: { code: "messaging/registration-token-not-registered", message: "not registered" } }
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
function loadIndex(source, label) {
  const filename = path.join(FUNCTIONS_DIR, `__i18n_harness_${label}.js`);
  const m = new Module(filename, module);
  m.filename = filename;
  m.paths = Module._nodeModulePaths(FUNCTIONS_DIR);
  // Expose the one non-exported sender (the conversion engine) to the harness.
  m._compile(`${source}\n;module.exports.__runConversionEngine = runConversionEngine;\n`, filename);
  return m.exports;
}

// ---- fixture ---------------------------------------------------------------
// latin: Latin user content (names, chore titles…) so English output can be
// checked for Hebrew letters. langs: write the per-device language fields.
function seedFamily({ latin, langs }) {
  const T = (he, en) => (latin ? en : he);
  const L = (o) => (langs ? o : {});
  return {
    "households/HH1": { parentUIDs: ["P1", "P2", "KIDACC"], childIDs: ["K1", "K2", "K3"], createdBy: "P1", parentNames: { P1: T("רני", "Rani") }, premiumUntil: 0 },
    "households/HH2": { parentUIDs: ["P3"], childIDs: ["K4"], createdBy: "P3", premiumUntil: NOW_S + 90 * 86400, familyName: T("לוי", "Levi") },
    "parents/P1": { email: "p1@example.com", displayName: T("רני", "Rani"), fcmTokens: ["tok-p1-a", "tok-p1-b"], householdIDs: ["HH1"], ...L({ tokenLanguages: { "tok-p1-b": "en" }, language: "en" }) },
    "parents/P2": { email: "p2@example.com", fcmTokens: ["tok-p2-a", "tok-dead-p2"], householdIDs: ["HH1"], ...L({ tokenLanguages: { "tok-p2-a": "en", "tok-dead-p2": "en" }, language: "en" }) },
    "parents/KIDACC": { childFcmTokens: ["tok-kid-1", "tok-kid-2"], fcmTokens: [], householdIDs: ["HH1"], ...L({ tokenLanguages: { "tok-kid-1": "he", "tok-kid-2": "en" }, language: "en" }) },
    "parents/P3": { email: "p3@example.com", fcmTokens: ["tok-p3-a"], childFcmTokens: ["tok-kid-4"], householdIDs: ["HH2"], ...L({ tokenLanguages: { "tok-kid-4": "en" }, language: "he" }) },
    "parents/admin-uid": { email: "ranioph@gmail.com", fcmTokens: ["tok-admin-a", "tok-admin-b"], childFcmTokens: ["tok-admin-kid"], ...L({ tokenLanguages: { "tok-admin-b": "en" } }) },
    "children/K1": { householdID: "HH1", name: T("נועה", "Noa"), gender: "girl", grade: 3, createdAt: NOW_S - 100 * 86400, interests: ["math"], packs: [] },
    "children/K2": { householdID: "HH1", name: T("יואב", "Yoav"), gender: "boy", grade: 5, createdAt: NOW_S - 100 * 86400, interests: ["science"], packs: ["soccer"] },
    "children/K3": { householdID: "HH1", grade: 0, createdAt: NOW_S - 100 * 86400 },
    "children/K4": { householdID: "HH2", name: T("דנה", "Dana"), gender: "girl", grade: 1, createdAt: NOW_S - 100 * 86400, packs: ["soccer"] },
    "childDevices/K1_INST1": { childID: "K1", householdID: "HH1", fcmToken: "tok-kid-1", ownerUID: "KIDACC", lastSeenAt: NOW_S - 60, name: T("האייפד של נועה", "Noa's iPad"), ...L({ language: "he" }) },
    "childDevices/K2_INST2": { childID: "K2", householdID: "HH1", fcmToken: "tok-kid-2", ownerUID: "KIDACC", lastSeenAt: NOW_S - 60, ...L({ language: "en" }) },
    "childDevices/K4_INST4": { childID: "K4", householdID: "HH2", fcmToken: "tok-kid-4", ownerUID: "P3", lastSeenAt: NOW_S - 60, ...L({ language: "en" }) },
    "friendCards/K1": { ownerUID: "KIDACC" }, "friendCards/K2": { ownerUID: "KIDACC" }, "friendCards/K4": { ownerUID: "P3" },
  };
}

// ---- scenario steps --------------------------------------------------------
const ADMIN_AUTH = { uid: "admin-uid", token: { email: "ranioph@gmail.com", email_verified: true } };
const docSnap = (p, d) => {
  const ref = ENV.db.doc(p);
  return { id: ref.id, ref, exists: d !== undefined && d !== null, data: () => (d == null ? undefined : clone(d)) };
};
const S = {
  created: (fn, p, data, params) => async (mod) => { await ENV.db.doc(p).set(data); return mod[fn].run({ params, data: docSnap(p, data) }); },
  written: (fn, p, before, after, params) => async (mod) => {
    if (after) await ENV.db.doc(p).set(after); else await ENV.db.doc(p).delete();
    return mod[fn].run({ params, data: { before: docSnap(p, before), after: docSnap(p, after) } });
  },
  seed: (p, data) => async () => { await ENV.db.doc(p).set(data); },
  schedule: (fn) => async (mod) => mod[fn].run({}),
  call: (fn, data) => async (mod) => { ENV.lastInput = clone(data); return { returned: await mod[fn].run({ data: clone(data), auth: ADMIN_AUTH }) }; },
  engine: () => async (mod) => ({ returned: await mod.__runConversionEngine() }),
};

function scenarios(fx) {
  const T = (he, en) => (fx.latin ? en : he);
  const out = [];
  const add = (name, steps, extraSeed = {}) => out.push({ name, steps, seed: () => ({ ...seedFamily(fx), ...extraSeed }) });

  // 1) live events — every type × gender × name × device
  const kid = { girl: "K1", boy: "K2", none: "K3" };
  const events = [
    { type: "sessionStart" },
    { type: "sessionEnd" }, { type: "sessionEnd", questions: 12, accuracy: 83, minutes: 6, stars: 40 }, { type: "sessionEnd", questions: 1, accuracy: 100 }, { type: "sessionEnd", minutes: 3 }, { type: "sessionEnd", stars: 1 },
    { type: "screenTimeStart" }, { type: "screenTimeStart", minutes: 15 },
    { type: "screenTimeEnd" }, { type: "screenTimeEnd", minutes: 1 },
    { type: "screenTimeMoved", fromKind: "ipad", deviceKind: "iphone" }, { type: "screenTimeMoved", fromKind: "iphone", deviceKind: "ipad" }, { type: "screenTimeMoved", fromKind: "mac" },
    { type: "assistRequest" }, { type: "parentGateOpened" }, { type: "playPINForgot" }, { type: "milestone" }, { type: "wheelWin" },
  ];
  const devices = [{}, { deviceName: T("האייפד של נועה", "Noa's iPad") }, { deviceName: "iPad", deviceKind: "ipad" }, { deviceName: "מכשיר", deviceKind: "iphone" }, { deviceKind: "ipod" }];
  let n = 0;
  for (const ev of events) for (const g of ["girl", "boy", "none"]) for (const named of [true, false]) for (const dev of devices) {
    const data = { ...ev, ...dev, createdAt: NOW_S, ...(g !== "none" ? { gender: g } : {}), ...(named ? { childName: T("נועה", "Noa") } : {}), ...(n % 3 === 0 ? { originToken: "tok-p1-a" } : {}) };
    add(`liveEvent ${ev.type} ${g} named=${named} dev=${JSON.stringify(dev)} #${n}`, [S.created("sendLiveEvent", `children/${kid[g]}/events/E${n}`, data, { childID: kid[g], eventID: `E${n}` })]);
    n++;
  }

  // 2) duplicate / suspicious alerts
  add("dupChild same name", [S.created("detectDuplicateChild", "children/K9", { householdID: "HH1", name: T("נועה", "Noa") }, { childID: "K9" })]);
  add("dupChild unique name", [S.created("detectDuplicateChild", "children/K9", { householdID: "HH1", name: T("שירה", "Shira") }, { childID: "K9" })]);
  for (const createdAt of [NOW_S - 3600, new Date(FIXED_NOW - 7200e3).toISOString(), NOW_S - 30 * 86400]) {
    add(`suspiciousState createdAt=${createdAt}`, [S.seed("children/K8", { householdID: "HH1", name: "x", createdAt }),
      S.created("detectSuspiciousState", "children/K8/state/current", { stars: 5120 }, { childID: "K8", stateID: "current" })]);
  }

  // 3) Tofy+ and pack requests
  const topics = ["math", "english", "hebrew", "logic", "science", "history", "geography", "money", "reading", "", "unknownTopic"];
  for (const g of ["girl", "boy", "none"]) for (const topic of topics) {
    const id = kid[g]; const base = seedFamily(fx)[`children/${id}`];
    add(`premiumRequest ${g} ${topic}`, [S.written("onPremiumRequest", `children/${id}`, base, { ...base, premiumRequestedAt: 1757000000.4, premiumRequestedTopic: topic }, { childID: id })]);
  }
  add("premiumRequest unchanged", [S.written("onPremiumRequest", "children/K1", { premiumRequestedAt: 5 }, { householdID: "HH1", premiumRequestedAt: 5 }, { childID: "K1" })]);
  const packs = ["soccer", "dinosaurs", "space", "animals", "sea", "gifted", "food", "israel", "tishrei", "music", "body", "vehicles", "flags", "nope"];
  for (const g of ["girl", "boy", "none"]) for (const packID of packs) {
    const id = kid[g]; const base = seedFamily(fx)[`children/${id}`];
    add(`packRequest ${g} ${packID}`, [S.written("onPackRequest", `children/${id}`, base, { ...base, packRequestedAt: 1757000001, packRequestedID: packID }, { childID: id })]);
  }

  // 4) parent commands: wake, lock, acks
  const k1 = seedFamily(fx)["children/K1"];
  add("childCommand wake", [S.written("wakeOnChildCommand", "children/K1", k1, { ...k1, pendingMinuteAdjustment: 5 }, { childID: "K1" })]);
  for (const [id, name] of [["K1", undefined], ["K9", T("עומר", "Omer")], ["K9", undefined]]) {
    const before = { householdID: "HH1", ...(name ? { name } : {}) };
    add(`revokeAck ${id} ${name}`, [S.written("wakeOnChildCommand", `children/${id}`, before, { ...before, revokeGiftAppliedAt: NOW_S - 300 }, { childID: id })]);
    add(`giftAck ${id} ${name}`, [S.written("wakeOnChildCommand", `children/${id}`, before, { ...before, giftAppliedAt: NOW_S - 300 }, { childID: id })]);
    add(`giftAck instant ${id}`, [S.written("wakeOnChildCommand", `children/${id}`, before, { ...before, giftAppliedAt: NOW_S - 2 }, { childID: id })]);
  }
  for (const [row, childID] of [["K1_INST1", "K1"], ["K2_INST2", "K2"], ["K4_INST4", "K4"], ["K3_NEW", "K3"]]) {
    const hh = childID === "K4" ? "HH2" : "HH1";
    const before = seedFamily(fx)[`childDevices/${row}`] || { childID, householdID: hh };
    add(`remoteLock ${row}`, [S.written("wakeOnDeviceCommand", `childDevices/${row}`, before, { ...before, remoteLockAt: 1757000100 }, { id: row })]);
    add(`remoteUnlock ${row}`, [S.written("wakeOnDeviceCommand", `childDevices/${row}`, before, { ...before, remoteUnlockAt: 1757000200 }, { id: row })]);
    add(`lockAck ${row}`, [S.written("wakeOnDeviceCommand", `childDevices/${row}`, before, { ...before, remoteLockAppliedAt: NOW_S - 400 }, { id: row })]);
  }
  add("lockAck unknown child", [S.written("wakeOnDeviceCommand", "childDevices/K7_X", { childID: "K7", householdID: "HH1" }, { childID: "K7", householdID: "HH1", remoteLockAppliedAt: NOW_S - 400 }, { id: "K7_X" })]);

  // 5) live game
  for (const hostName of [T("נועה", "Noa"), undefined]) {
    add(`liveGameInvite host=${hostName}`, [S.created("onLiveGameInvite", "liveGames/G1", { invited: ["K4", "K2"], hostOwnerUID: "KIDACC", ...(hostName ? { hostName } : {}) }, { gameID: "G1" })]);
    add(`liveGameInvite sameAccount host=${hostName}`, [S.created("onLiveGameInvite", "liveGames/G2", { invited: ["K1"], hostOwnerUID: "P3", ...(hostName ? { hostName } : {}) }, { gameID: "G2" })]);
    add(`liveGameNudge host=${hostName}`, [S.created("onLiveGameNudge", "liveGames/G1/nudges/N1", { targetID: "K4", ownerUID: "KIDACC", ...(hostName ? { hostName } : {}) }, { gameID: "G1", nudgeID: "N1" })]);
    add(`liveGameNudge toKid2 host=${hostName}`, [S.created("onLiveGameNudge", "liveGames/G1/nudges/N2", { targetID: "K2", ownerUID: "P3", ...(hostName ? { hostName } : {}) }, { gameID: "G1", nudgeID: "N2" })]);
  }

  // 6) sibling time transfer
  const tt = { householdID: "HH1", toName: T("יואב", "Yoav"), fromName: T("נועה", "Noa"), minutes: 10, diamondPrice: 30 };
  add("timeTransfer pendingSeller", [S.written("onTimeTransferWritten", "timeTransfers/T1", { ...tt, status: "requested" }, { ...tt, status: "pendingSeller" }, { id: "T1" })]);
  add("timeTransfer pendingParent buy", [S.written("onTimeTransferWritten", "timeTransfers/T1", { ...tt, status: "pendingSeller" }, { ...tt, status: "pendingParent" }, { id: "T1" })]);
  add("timeTransfer pendingParent gift", [S.written("onTimeTransferWritten", "timeTransfers/T2", null, { ...tt, minutes: 1, diamondPrice: 0, status: "pendingParent" }, { id: "T2" })]);

  // 7) chores
  for (const childID of ["K1", "K2", "K3", "K9"]) for (const reward of ["coins", "minutes"]) for (const extra of [{}, { emoji: "🍽️", title: T("לפנות את הכלים", "Clear the dishes"), photoData: "jpeg-bytes" }]) {
    const base = { childID, rewardCoins: 5, rewardMinutes: 12, ...extra };
    add(`chore marked ${childID} ${reward} ${!!extra.title}`, [S.written("onChoreWritten", "households/HH1/chores/C1", { ...base }, { ...base, chosenReward: reward, markedDoneAt: 1757000300 }, { householdID: "HH1", choreID: "C1" })]);
    add(`chore approved ${childID} ${reward} ${!!extra.title}`, [S.written("onChoreWritten", "households/HH1/chores/C1", { ...base, chosenReward: reward, markedDoneAt: 1 }, { ...base, lastApprovedAt: 1757000400, markedDoneAt: 1 }, { householdID: "HH1", choreID: "C1" })]);
  }

  // 8) parent help
  for (const parentUID of ["all", "P2", "P1"]) for (const g of ["girl", "boy", undefined]) for (const named of [true, false]) {
    add(`help ${parentUID} ${g} ${named}`, [S.created("onHelpRequest", "helpRequests/H1", {
      parentUID, fromUID: "KIDACC", householdID: "HH1", childID: "K1", gender: g, ...(named ? { childName: T("נועה", "Noa") } : {}),
      question: T("כמה זה 7 ועוד 5?", "What is 7 + 5?"), optionA: "12", optionB: "13", correctAnswer: "12", topic: "math" }, { id: "H1" })]);
  }

  // 9) child link requests
  for (const fromParentName of [T("רני", "Rani"), undefined]) {
    add(`childLink created ${fromParentName}`, [S.written("onChildLinkRequest", "childLinkRequests/R1", null, { status: "pending", toEmail: "p2@example.com", fromParentUID: "P1", ...(fromParentName ? { fromParentName } : {}) }, { id: "R1" })]);
    add(`childLink created toHebrewAccount ${fromParentName}`, [S.written("onChildLinkRequest", "childLinkRequests/R3", null, { status: "pending", toEmail: "p3@example.com", fromParentUID: "P1", ...(fromParentName ? { fromParentName } : {}) }, { id: "R3" })]);
  }
  add("childLink approved", [S.written("onChildLinkRequest", "childLinkRequests/R1", { status: "pending", fromParentUID: "P1" }, { status: "approved", fromParentUID: "P1" }, { id: "R1" })]);
  add("childLink approved P2", [S.written("onChildLinkRequest", "childLinkRequests/R2", { status: "pending", fromParentUID: "P2" }, { status: "approved", fromParentUID: "P2" }, { id: "R2" })]);

  // 10) weekly report
  add("weeklyReport", [
    S.seed("children/K1/dailyStats/2026-09-14", { date: "2026-09-14", questionsAnswered: 12, correct: 10, minutesEarned: 6, longestStreak: 4 }),
    S.seed("children/K1/dailyStats/2026-09-12", { date: "2026-09-12", questionsAnswered: 30, correct: 25, minutesEarned: 14, longestStreak: 9 }),
    S.seed("children/K3/dailyStats/2026-09-13", { date: "2026-09-13", questionsAnswered: 1, correct: 1, minutesEarned: 1, longestStreak: 1 }),
    S.seed("children/K4/dailyStats/2026-09-10", { date: "2026-09-10", questionsAnswered: 5, correct: 3, minutesEarned: 0, longestStreak: 0 }),
    S.seed("children/K2/dailyStats/2026-08-01", { date: "2026-08-01", questionsAnswered: 50, correct: 40, minutesEarned: 20, longestStreak: 7 }),
    S.schedule("weeklyReport")]);

  // 11) test push
  for (const uid of ["P1", "P2", "P3", "nobody"]) add(`testPush ${uid}`, [S.created("sendTestPush", "pushTests/X1", { uid }, { id: "X1" })]);

  // 12) emails (team emails stay Hebrew; the welcome email follows the signup's language)
  add("parentFeedback", [S.created("onParentFeedback", "parentFeedback/F1", { message: "hi", fromUID: "P1", householdID: "HH1", appVersion: "1.0", locale: "he", createdAt: NOW_S }, { id: "F1" })]);
  add("questionReport", [S.created("onQuestionReport", "questionReports/Q1", { prompt: "2+2?", correctAnswer: "4", topic: "math", reason: "wrong", childName: "x", reportedBy: "P1", createdAt: NOW_S }, { id: "Q1" })]);
  for (const w of [{ email: "new@example.com", name: T("רני אופיר", "Rani Ophir"), childAge: "7" }, { email: "new@example.com" }, { email: "not-an-email", name: "x" },
    { email: "p2@example.com", name: T("עמית", "Amit") }, { email: "p1@example.com" },
    { email: "new2@example.com", name: T("טל", "Tal"), ...(fx.langs ? { language: "en" } : {}) }, { email: "new3@example.com", ...(fx.langs ? { lang: "en" } : {}) }]) {
    add(`waitlist ${JSON.stringify(w)}`, [S.created("onWaitlistSignup", "waitlist/W1", { ...w, createdAt: new Date(FIXED_NOW).toISOString() }, { id: "W1" })]);
  }

  // 13) campaigns — composed by the admin, the admin's test, and the dispatcher
  const heCopy = { emoji: "📣", title: T("חדש בטופי", "New in Tofy"), body: T("עולם חדש מחכה לכם", "A new world awaits") };
  const enCopy = { titleEn: "New in Tofy", bodyEn: "A new world is waiting for you." };
  const enChild = { childTitleEn: "Want to explore?", childBodyEn: "Ask Mom or Dad 💌" };
  const campaignVariants = [
    ["parents he-only", { ...heCopy, audience: { roles: ["parents"] } }],
    ["parents+kids he-only", { ...heCopy, childTitle: T("רוצים לנסות?", "Try it?"), audience: { roles: ["parents", "children"] }, imageURL: "https://tofyapp.com/x.png" }],
    ["parents+kids with en", { ...heCopy, ...enCopy, audience: { roles: ["parents", "children"] } }],
    ["kids with en child copy", { ...heCopy, ...enCopy, ...enChild, childTitle: T("רוצים?", "Want?"), childBody: T("בקשו", "Ask"), audience: { roles: ["children"] } }],
    ["en title only (body missing)", { ...heCopy, titleEn: "Only a title", audience: { roles: ["parents", "children"] } }],
    ["pack campaign grade filter", { ...heCopy, ...enCopy, audience: { roles: ["parents", "children"], gradeMin: 2, gradeMax: 8, excludeOwners: true }, action: { type: "pack", packID: "soccer" } }],
    ["premium without + topics", { ...heCopy, audience: { roles: ["parents", "children"], premium: "without", topics: ["math"] } }],
    ["premium with", { ...heCopy, ...enCopy, audience: { roles: ["parents"], premium: "with" }, action: { type: "tofyPlus" } }],
  ];
  for (const [label, c] of campaignVariants) {
    add(`campaign test ${label}`, [S.call("adminSendCampaignTest", c)]);
    add(`campaign dispatch ${label}`, [S.call("adminSaveCampaign", { ...c, status: "scheduled", scheduledAt: FIXED_NOW - 60e3 }), S.schedule("dispatchCampaigns")]);
  }
  for (const packID of packs.slice(0, 13)) {
    add(`pack launch ${packID}`, [S.call("adminSetPackEnabled", { packID, enabled: true }), S.schedule("dispatchCampaigns")]);
  }

  // 14) world-pass reminders
  const worlds = ["math", "english", "hebrew", "logic", "science", "history", "geography", "money", "reading", "soccer"];
  const expiry = Object.fromEntries(worlds.map((w, i) => [w, NOW_S + 2.5 * 86400 + i]));
  add("worldPassReminders", [S.seed("children/K1", { ...k1, packExpiry: expiry }), S.seed("children/K3", { householdID: "HH1", packExpiry: { math: NOW_S + 2.2 * 86400, english: NOW_S + 9 * 86400 } }),
    S.schedule("worldPassReminders")]);

  // 15) conversion engine — gift start, every gift day, with/without favourite, both genders
  const journey = { households: {}, children: {} };
  const extra = {};
  const cases = [];
  for (const g of ["girl", "boy"]) for (const fav of [true, false]) {
    cases.push({ kind: "start", g, fav });
    for (const [day, left] of [[4, 11], [9, 6], [12, 3], [13, 2], [14, 1]]) cases.push({ kind: "day", g, fav, day, left });
  }
  cases.push({ kind: "day", g: "girl", fav: true, day: 12, left: 3, noTopicsToday: true });
  cases.push({ kind: "day", g: "boy", fav: false, day: 13, left: 2, noStar: true });
  cases.push({ kind: "start", g: "boy", fav: false, noStar: true });
  cases.push({ kind: "free" });
  cases.forEach((cs, i) => {
    const hid = `HG${i}`, cid = `CG${i}`;
    extra[`households/${hid}`] = cs.kind === "day"
      ? { parentUIDs: ["P1", "P2"], premiumSource: "gift", giftStartedAt: NOW_S - (cs.day - 1) * 86400 - 3600, premiumUntil: NOW_S + cs.left * 86400 - 3600 }
      : { parentUIDs: ["P1", "P2"], premiumUntil: 0 };
    journey.households[hid] = { kids: [cid], activated: cs.kind === "start", activeDays: 2, questions: 17 };
    journey.children[cid] = {
      name: T(cs.g === "girl" ? "מאיה" : "איתי", cs.g === "girl" ? "Maya" : "Itai"), gender: cs.g, everQuestions: cs.noStar ? 0 : 120, questions30: 64,
      favorite: cs.fav ? { topic: "math", label: "🧮 מתמטיקה", questions: 41, days: 6 } : null,
      topicsToday: cs.noTopicsToday ? {} : { math: { q: 3 }, science: { q: 1 } },
    };
  });
  const seedEngine = [S.seed("adminStats/journey", journey), ...Object.entries(extra).map(([p, d]) => S.seed(p, d))];
  add("conversionEngine default copy", [...seedEngine, S.engine()]);
  add("conversionEngine custom copy", [...seedEngine, S.seed("config/conversion", {
    giftDays: 21, copyActivation: "🎁 מתנה ל{שם} · {שם} ענה על {שאלות} שאלות, {ימים} ימים עד {תאריך}.", copyTwoDays: "⏰ יומיים · {עולם אהוב} {חזרות} {מחיר חודשי בשנתי} {לא קיים}" }), S.engine()]);
  // a favourite world whose topic is a pack / unknown
  journey.children.CG1 = { ...journey.children.CG1, favorite: { topic: "soccer", label: "⚽ כדורגל", questions: 9, days: 2 } };
  journey.children.CG3 = { ...journey.children.CG3, favorite: { topic: "weird", label: "weird", questions: 1, days: 1 } };
  add("conversionEngine pack favourite", [S.seed("adminStats/journey", journey), ...Object.entries(extra).map(([p, d]) => S.seed(p, d)), S.engine()]);
  return out;
}

// ---- running ---------------------------------------------------------------
async function runSuite(mod, fx) {
  const results = [];
  for (const sc of scenarios(fx)) {
    ENV.db.__reset(sc.seed());
    ENV.cap = [];
    ENV.lastInput = null;
    const quiet = [console.log, console.warn, console.error];
    console.log = console.warn = console.error = () => {};
    let error = null;
    try {
      for (const step of sc.steps) {
        const r = await step(mod);
        if (r && r.returned !== undefined) ENV.cap.push({ kind: "return", value: clone(r.returned) });
      }
    } catch (e) { error = String(e && e.stack || e); }
    finally { [console.log, console.warn, console.error] = quiet; }
    results.push({ name: sc.name, cap: ENV.cap, store: ENV.db.__dump(), input: ENV.lastInput, error });
  }
  return results;
}

// Keys the i18n change legitimately ADDS (never a Hebrew string): English campaign
// copy, and the count of devices skipped for missing English copy.
const NEW_KEYS = /^(titleEn|bodyEn|childTitleEn|childBodyEn|skippedLanguage)$/;
function withoutNewKeys(v) {
  if (Array.isArray(v)) return v.map(withoutNewKeys);
  if (v instanceof Timestamp) return { __ts: v._ms };
  if (Buffer.isBuffer(v)) return { __buf: v.toString("hex") };
  if (isPlain(v)) { const o = {}; for (const [k, x] of Object.entries(v)) if (!NEW_KEYS.test(k)) o[k] = withoutNewKeys(x); return o; }
  return v;
}
function firstDiff(a, b, p = "") {
  if (a === b) return null;
  if (typeof a !== typeof b || a === null || b === null || typeof a !== "object") return `${p || "(root)"}: ORIGINAL=${JSON.stringify(a)} CURRENT=${JSON.stringify(b)}`;
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of keys) { const d = firstDiff(a[k], b[k], `${p}.${k}`); if (d) return d; }
  return null;
}
const HEB = /[א-ת]/;
let hebrewStrings = 0;
function countHebrew(v) {
  if (typeof v === "string") { if (HEB.test(v)) hebrewStrings++; return; }
  if (v && typeof v === "object") Object.values(v).forEach(countHebrew);
}

// Deliveries per token, in order: what each device received.
function perToken(cap) {
  const m = new Map();
  for (const c of cap) {
    if (c.kind !== "fcm") continue;
    const { tokens, ...payload } = c.msg;
    for (const t of tokens) { if (!m.has(t)) m.set(t, []); m.get(t).push(payload); }
  }
  return m;
}
const texts = (p) => [p.notification && p.notification.title, p.notification && p.notification.body,
  ...(((p.apns || {}).payload || {}).aps || {}).alert ? [p.apns.payload.aps.alert.title, p.apns.payload.aps.alert.body] : []].filter((x) => x !== undefined);

(async () => {
  const failures = [];
  const base = loadIndex(baseSource, "base");
  const current = loadIndex(currentSource, "current");
  for (const name of Object.keys(base)) if (!(name in current)) failures.push(`export ${name} missing from CURRENT`);

  // ---- Suite 1: Hebrew identity ----
  const fxHe = { latin: false, langs: false };
  const b1 = await runSuite(base, fxHe);
  const c1 = await runSuite(current, fxHe);
  let messages1 = 0;
  b1.forEach((rb, i) => {
    const rc = c1[i];
    messages1 += rb.cap.filter((c) => c.kind !== "return").length;
    countHebrew(rb.cap);
    if (rb.error) failures.push(`[he] ${rb.name}: ORIGINAL threw ${rb.error.split("\n")[0]}`);
    if (rc.error) { failures.push(`[he] ${rc.name}: CURRENT threw ${rc.error}`); return; }
    const d = firstDiff(withoutNewKeys({ cap: rb.cap, store: rb.store }), withoutNewKeys({ cap: rc.cap, store: rc.store }));
    if (d) failures.push(`[he] ${rb.name}: ${d}`);
  });
  console.log(`Suite 1 · Hebrew identity: ${b1.length} scenarios, ${messages1} pushes/emails, ${hebrewStrings} Hebrew strings compared against ${BASE}`);
  // Coverage per trigger family, so a fake that silently sends nothing shows up as 0.
  const cover = {};
  b1.forEach((r) => { const k = r.name.split(" ").slice(0, 2).join(" ").replace(/[^A-Za-z ]/g, ""); const c = cover[k] = cover[k] || [0, 0]; c[0]++; c[1] += r.cap.filter((x) => x.kind !== "return").length; });
  console.log("  " + Object.entries(cover).map(([k, [s, m]]) => `${k}: ${m}/${s}`).join(" · "));

  // ---- Suite 2: mixed languages ----
  const fxMix = { latin: true, langs: true };
  const base2 = loadIndex(baseSource, "base2");
  const current2 = loadIndex(currentSource, "current2");
  const b2 = await runSuite(base2, fxMix);
  const c2 = await runSuite(current2, fxMix);
  const seedMix = seedFamily(fxMix);
  const enTokens = new Set();
  for (const d of Object.values(seedMix)) {
    Object.entries(d.tokenLanguages || {}).forEach(([t, l]) => { if (l === "en") enTokens.add(t); });
    if (d.language === "en" && d.fcmToken) enTokens.add(d.fcmToken);
  }
  let heChecked = 0, enChecked = 0, enSkippedCampaign = 0;
  b2.forEach((rb, i) => {
    const rc = c2[i];
    if (rc.error) { failures.push(`[mix] ${rc.name}: CURRENT threw ${rc.error}`); return; }
    const pb = perToken(rb.cap), pc = perToken(rc.cap);
    for (const [t, want] of pb) {
      const got = pc.get(t) || [];
      if (!enTokens.has(t)) {
        const d = firstDiff(withoutNewKeys(want), withoutNewKeys(got));
        if (d) failures.push(`[mix/he ${t}] ${rb.name}: ${d}`);
        heChecked += want.length;
        continue;
      }
      // English device: same messages minus campaigns that have no English copy.
      const expected = want.filter((p) => {
        if ((p.data || {}).type !== "campaign") return true;
        // the admin's test send never stores a doc — its copy is the call's input
        const camp = rc.store[`campaigns/${p.data.campaignID}`] || rc.input || {};
        const child = p.data.role === "child";
        const title = child ? (camp.childTitleEn || camp.titleEn) : camp.titleEn;
        const body = child ? (camp.childBodyEn || camp.bodyEn) : camp.bodyEn;
        const heBody = child ? (camp.childBody || camp.body) : camp.body;
        const ok = !!title && (!!body || !heBody);
        if (!ok) enSkippedCampaign++;
        return ok;
      });
      if (expected.length !== got.length) { failures.push(`[mix/en ${t}] ${rb.name}: expected ${expected.length} message(s), got ${got.length}`); continue; }
      got.forEach((p, j) => {
        enChecked++;
        const w = expected[j];
        const strip = (x) => { const y = clone(x); delete y.notification; if (y.apns && y.apns.payload && y.apns.payload.aps) delete y.apns.payload.aps.alert; if (y.data) delete y.data.childName; return y; };
        const d = firstDiff(withoutNewKeys(strip(w)), withoutNewKeys(strip(p)));
        if (d) failures.push(`[mix/en ${t}] ${rb.name}: payload shape changed: ${d}`);
        const tx = texts(p);
        const silent = !texts(w).length;   // data-only wake: nothing to translate
        if ((!silent && !tx.length) || tx.some((s) => typeof s !== "string" || !s.trim())) failures.push(`[mix/en ${t}] ${rb.name}: empty English text ${JSON.stringify(tx)}`);
        if (silent && JSON.stringify(p).match(HEB)) failures.push(`[mix/en ${t}] ${rb.name}: Hebrew in a silent payload`);
        if (tx.some((s) => HEB.test(s))) failures.push(`[mix/en ${t}] ${rb.name}: Hebrew in English message: ${JSON.stringify(tx)}`);
        if (SHOW_EN) console.log(`  EN ${rb.name} → ${tx.join("  |  ")}`);
      });
    }
    for (const t of pc.keys()) if (!pb.has(t)) failures.push(`[mix ${t}] ${rb.name}: CURRENT sent to a token ORIGINAL never targeted`);
    // Emails: the team's stay identical; a welcome email follows the signup's language.
    const mb = rb.cap.filter((c) => c.kind === "mail"), mc = rc.cap.filter((c) => c.kind === "mail");
    if (mb.length !== mc.length) failures.push(`[mix mail] ${rb.name}: ${mb.length} vs ${mc.length} emails`);
    mc.forEach((m, j) => {
      const team = Array.isArray(m.msg.to);
      const scenarioDoc = (rc.store["waitlist/W1"] || {});
      const parentLang = Object.values(seedMix).find((d) => d.email && d.email === scenarioDoc.email);
      const english = !team && (scenarioDoc.language === "en" || scenarioDoc.lang === "en" || (!scenarioDoc.language && !scenarioDoc.lang && parentLang && parentLang.language === "en"));
      if (!english) {
        const d = firstDiff(mb[j] && mb[j].msg, m.msg);
        if (d) failures.push(`[mix mail/he] ${rb.name}: ${d}`);
        return;
      }
      enChecked++;
      if (HEB.test(m.msg.subject) || HEB.test(m.msg.text) || HEB.test(m.msg.html)) failures.push(`[mix mail/en] ${rb.name}: Hebrew in English email`);
      if (!/dir="ltr"/.test(m.msg.html) || /dir="rtl"/.test(m.msg.html)) failures.push(`[mix mail/en] ${rb.name}: English email is not left-to-right`);
      if (SHOW_EN) console.log(`  EN MAIL ${rb.name} → ${m.msg.subject}\n${m.msg.text}`);
    });
  });
  console.log(`Suite 2 · Mixed languages: ${b2.length} scenarios, ${heChecked} Hebrew-device deliveries identical, ${enChecked} English deliveries checked, ${enSkippedCampaign} campaign deliveries withheld from English devices (no English copy)`);

  if (failures.length) {
    console.error(`\n❌ ${failures.length} failure(s):`);
    failures.slice(0, args.includes("--all") ? Infinity : 80).forEach((f) => console.error(" - " + f));
    process.exit(1);
  }
  console.log("\n✅ Hebrew output is byte-identical; English devices get English.");
})().catch((e) => { console.error(e); process.exit(1); });
