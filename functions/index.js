/**
 * ChildTime Cloud Functions
 *
 * 1) sendLiveEvent — on a new child event, push a notification to every OTHER
 *    parent in the household (the playing device's parent is skipped), in
 *    Hebrew, matching the spec's live-learning notifications.
 * 2) weeklyReport — every Monday, build a per-child weekly summary, store it,
 *    and push a digest to the household's parents.
 *
 * Deploy:  firebase deploy --only functions
 * Requires: APNs key uploaded to Firebase (Project Settings → Cloud Messaging),
 *           Push Notifications capability on the iOS app.
 */
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// Where parent feedback is emailed, and the Gmail account used to send it.
// Set the secrets before deploying:
//   firebase functions:secrets:set GMAIL_USER   (the sending Gmail address)
//   firebase functions:secrets:set GMAIL_PASS   (a Gmail APP PASSWORD, not the login)
// Optionally override the recipient:
//   firebase deploy --only functions  (FEEDBACK_TO defaults to ranioph@gmail.com)
const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_PASS = defineSecret("GMAIL_PASS");
const FEEDBACK_TO = ["ranioph@gmail.com", "amitgolans@gmail.com"];  // recipients for feedback + question reports

function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Wrap the lines in a right-to-left, right-aligned HTML body so Hebrew emails
// render correctly (plain text shows left-aligned in most clients).
function rtlBody(lines) {
  const html = lines.map((l) => escapeHtml(l) || "&nbsp;").join("<br>");
  return `<div dir="rtl" style="text-align:right;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.7;">${html}</div>`;
}

// ---- Helpers ---------------------------------------------------------------

async function tokensForHousehold(householdID, excludeUID) {
  const hh = await db.collection("households").doc(householdID).get();
  if (!hh.exists) return [];
  const parentUIDs = (hh.data().parentUIDs || []).filter((u) => u !== excludeUID);
  const tokens = [];
  for (const uid of parentUIDs) {
    const p = await db.collection("parents").doc(uid).get();
    if (p.exists && Array.isArray(p.data().fcmTokens)) tokens.push(...p.data().fcmTokens);
  }
  return [...new Set(tokens)];
}

// A short " · <device>" suffix so the parent knows WHICH device it happened on
// (iPad vs iPhone). Prefers the device's friendly name, else a generic label.
function deviceLabel(event) {
  const nm = (event.deviceName || "").trim();
  const generic = ["מכשיר", "iPhone", "iPad", "iPod touch"];
  if (nm && !generic.includes(nm)) return ` · ${nm}`;
  if (event.deviceKind === "ipad") return " · אייפד";
  if (event.deviceKind === "iphone") return " · אייפון";
  return "";
}

function liveMessage(event) {
  const f = event.gender === "girl";                 // feminine forms?
  const name = event.childName || (f ? "הילדה" : "הילד");
  const g = (male, female) => (f ? female : male);   // pick by gender
  const dev = deviceLabel(event);                    // " · אייפד" / " · אייפון" / ""
  switch (event.type) {
    case "sessionStart": return { title: g("התחיל לשחק 📱", "התחילה לשחק 📱"), body: `${name} ${g("התחיל", "התחילה")} עכשיו לשחק ${g("ולומד", "ולומדת")}${dev}.` };
    case "sessionEnd": {
      const q = Number(event.questions) || 0;
      const acc = Number(event.accuracy) || 0;
      const mins = Number(event.minutes) || 0;
      const stars = Number(event.stars) || 0;
      const parts = [];
      if (q > 0) parts.push(`${q} שאלות`);
      if (q > 0) parts.push(`${acc}% הצלחה`);
      if (mins > 0) parts.push(`${mins} דק' שנצברו`);
      if (stars > 0) parts.push(`${stars} ⭐`);
      const summary = parts.length ? parts.join(" · ") : `${g("סיים", "סיימה")} את מסע הלמידה`;
      return { title: g("סיים לשחק ✅", "סיימה לשחק ✅"), body: `${name}${dev}: ${summary}` };
    }
    case "screenTimeStart": {
      const mins = Number(event.minutes) || 0;
      const tail = mins > 0 ? ` (${mins} דק')` : "";
      return { title: g("פתח זמן מסך 🎮", "פתחה זמן מסך 🎮"), body: `${name} ${g("פתח", "פתחה")} זמן משחק${tail}${dev}.` };
    }
    case "screenTimeEnd": {
      const mins = Number(event.minutes) || 0;
      const tail = mins > 0 ? ` · נשארו ${mins} דק'` : "";
      return { title: g("סיים זמן מסך ⏹️", "סיימה זמן מסך ⏹️"), body: `${name} ${g("סיים", "סיימה")} את זמן המשחק${dev}${tail}.` };
    }
    case "screenTimeMoved": {
      // The child moved their OPEN play window between their own devices — the
      // source device was locked (stop-and-save, nothing lost) and play resumed
      // on the destination. `deviceKind` on the event is the device it moved TO.
      const kindLabel = (k) => (k === "ipad" ? "אייפד" : (k === "iphone" ? "אייפון" : "מכשיר אחר"));
      const from = kindLabel(event.fromKind);
      const to = kindLabel(event.deviceKind);
      return { title: g("העביר זמן משחק 🔄", "העבירה זמן משחק 🔄"),
               body: `${name} ${g("העביר", "העבירה")} את זמן המשחק מה${from} ל${to}. ה${from} ננעל 🔒` };
    }
    case "assistRequest":return { title: "בקשת עזרה 💌", body: `${name} ${g("ביקש", "ביקשה")} את עזרתכם בשאלה${dev}.` };
    case "parentGateOpened": return { title: "🔐 נכנסו להגדרות ההורה", body: `מישהו פתח את הגדרות ההורה במכשיר של ${name}${dev}.` };
    // Deliberately does NOT include the code itself — lock-screen previews are
    // often visible to the very kid (or sibling) the code guards against. The
    // parent sees the code inside the gated dashboard.
    case "playPINForgot": return { title: "🔒 קוד הגנת הזמן נשכח", body: `${name} ${g("שכח", "שכחה")} את קוד הגנת זמן המשחק${dev}. הקוד מופיע בכרטיס של ${name} בלוח ההורים — ואפשר גם לאפס שם, או ישירות במכשיר של הילד עם קוד ההורה.` };
    // Intentionally NO push for milestone / streak / wheelWin / discovery —
    // those flooded the parent. Only start/finish, screen-time open/close, and
    // help requests notify.
    default:             return null;
  }
}

async function tokensForUID(uid) {
  const p = await db.collection("parents").doc(uid).get();
  if (p.exists && Array.isArray(p.data().fcmTokens)) return [...new Set(p.data().fcmTokens)];
  return [];
}

// CHILD-device tokens (live-game invites target a kid's own device). Reads
// `childFcmTokens`, plus legacy `fcmTokens` so devices that haven't re-uploaded
// since the parent/child token split still get game invites during migration.
async function childTokensForUID(uid) {
  const p = await db.collection("parents").doc(uid).get();
  if (!p.exists) return [];
  const d = p.data();
  const child = Array.isArray(d.childFcmTokens) ? d.childFcmTokens : [];
  const legacy = Array.isArray(d.fcmTokens) ? d.fcmTokens : [];
  return [...new Set([...child, ...legacy])];
}

// All CHILD-device tokens across a household (best-effort sibling notifications:
// same-account siblings share the parent's childFcmTokens, so this reaches every
// kid device in the family — the right sibling acts on it in-app).
async function childTokensForHousehold(householdID) {
  const hh = await db.collection("households").doc(householdID).get();
  if (!hh.exists) return [];
  const parentUIDs = hh.data().parentUIDs || [];
  const tokens = [];
  for (const uid of parentUIDs) tokens.push(...(await childTokensForUID(uid)));
  return [...new Set(tokens)];
}

// Deliver a push to recipients, dropping the host's OWN device tokens so the
// host isn't pinged by their own invite — but NEVER drop a real invite to empty
// (same-account test families share tokens; the invited kid must still get it).
function withoutHost(recipientTokens, hostTokens) {
  const host = new Set(hostTokens || []);
  const filtered = recipientTokens.filter((t) => !host.has(t));
  return filtered.length ? filtered : recipientTokens;
}

async function tokensForEmail(email) {
  if (!email) return [];
  const snap = await db.collection("parents").where("email", "==", email).get();
  const tokens = [];
  snap.forEach((d) => { if (Array.isArray(d.data().fcmTokens)) tokens.push(...d.data().fcmTokens); });
  return [...new Set(tokens)];
}

async function send(tokens, notification, data) {
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification,
    data: data || {},
    apns: { payload: { aps: { sound: "default" } } },
  });
}

// ---- 1) Live events --------------------------------------------------------

exports.sendLiveEvent = onDocumentCreated("children/{childID}/events/{eventID}", async (event) => {
  const data = event.data && event.data.data();
  if (!data) return;

  const child = await db.collection("children").doc(event.params.childID).get();
  if (!child.exists) return;
  const householdID = child.data().householdID;

  // Notify every parent device in the household EXCEPT the one that's playing.
  // Exclude by FCM token (not uid) so the parent's other device still gets the
  // push even when both devices share one account.
  let tokens = await tokensForHousehold(householdID, null);
  if (data.originToken) tokens = tokens.filter((t) => t !== data.originToken);
  const msg = liveMessage(data);
  if (!msg) return;
  await send(tokens, msg, { childID: event.params.childID, type: data.type });
});

// ---- 1a-pre) Duplicate-child detector ---------------------------------------
// The day-one families kept getting "duplicate children" (a stale local UUID
// re-uploaded with the real kid's live points — e.g. 36502FEA with Yoav's
// stars at revision 178). Client-side guards now block the known paths; this
// is the early-warning net for anything they miss: alert the household's
// parents the moment a suspicious child doc appears, BEFORE the family is
// confused by it. Detection only — never deletes anything.
exports.detectDuplicateChild = onDocumentCreated("children/{childID}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.householdID || !data.name) return;
  const same = await db.collection("children")
    .where("householdID", "==", data.householdID)
    .where("name", "==", data.name).get();
  const others = same.docs.filter((d) => d.id !== event.params.childID);
  if (!others.length) return;
  console.error("[dupDetector] duplicate child name:", data.name,
    "new=", event.params.childID, "existing=", others.map((d) => d.id).join(","),
    "hh=", data.householdID);
  const tokens = await tokensForHousehold(data.householdID, null);
  await send(tokens, {
    title: "⚠️ יתכן שנוצר ילד כפול",
    body: `נוצר עכשיו ילד חדש בשם "${data.name}" למרות שכבר קיים ילד בשם הזה במשפחה. אם לא יצרתם אותו בכוונה — אל תמחקו כלום, פנו לתמיכה.`,
  }, { type: "dupAlert", childID: event.params.childID });
});

// A freshly-created state doc with MANY stars but a LOW revision is the exact
// fingerprint of the contamination bug (a new UUID inheriting a real kid's
// live points). Log + alert so it's caught in minutes, not weeks.
exports.detectSuspiciousState = onDocumentCreated("children/{childID}/state/{stateID}", async (event) => {
  const s = event.data && event.data.data();
  if (!s) return;
  const stars = Number(s.stars) || 0;
  if (stars <= 3000) return;
  const child = await db.collection("children").doc(event.params.childID).get();
  if (!child.exists) return;
  // The duplication fingerprint is a BRAND-NEW child whose very first state doc
  // already carries thousands of stars. An established child re-creating its
  // state doc (restore, resync, reset) is normal — never alarm that family.
  //
  // We deliberately no longer key on `revision < 500`. That worked only because
  // `revision` doubled as an activity counter (~10 bumps per answered question),
  // so a legitimate heavy account sat above 500. `revision` is now a causal
  // GENERATION that stays small for everyone, which would have turned this into a
  // false-alarm machine pushing "⚠️ נתוני התקדמות חשודים" at real families.
  const raw = child.data().createdAt;
  const createdMs = raw && typeof raw.toMillis === "function" ? raw.toMillis()
    : (typeof raw === "number" ? (raw > 1e12 ? raw : raw * 1000)
      : (typeof raw === "string" ? Date.parse(raw) : NaN));
  if (!Number.isFinite(createdMs)) return;                 // can't judge → stay quiet
  const ageHours = (Date.now() - createdMs) / 3600000;
  if (ageHours < 0 || ageHours > 48) return;               // not a new child
  console.error("[dupDetector] suspicious state: child=", event.params.childID,
    "stars=", stars, "ageHours=", Math.round(ageHours), "device=", s.deviceID || "?");
  const hh = child.data().householdID;
  if (!hh) return;
  const tokens = await tokensForHousehold(hh, null);
  await send(tokens, {
    title: "⚠️ נתוני התקדמות חשודים",
    body: `זוהה פרופיל חדש עם ${stars} כוכבים — יתכן שכפול של ילד קיים. אל תמחקו כלום, פנו לתמיכה.`,
  }, { type: "dupAlert", childID: event.params.childID });
});

// ---- 1a) Tombstone enforcement — deleted children can't come back -----------
// A child is deleted on one device, but OTHER devices in the household still
// hold it locally and re-upload it on next launch (so it "kept coming back").
// On delete we write a `deletedChildren/{id}` tombstone; whenever a child doc is
// (re)created, if it's tombstoned we wipe it again — server-side, regardless of
// which device tried — plus its subcollections and leaderboard card.
exports.blockTombstonedChild = onDocumentCreated("children/{childID}", async (event) => {
  const childID = event.params.childID;
  const tomb = await db.collection("deletedChildren").doc(childID).get();
  if (!tomb.exists) return;   // a normal, live child — leave it alone
  try {
    const hid = event.data && event.data.data() && event.data.data().householdID;
    if (hid) {
      await db.collection("households").doc(hid)
        .update({ childIDs: admin.firestore.FieldValue.arrayRemove(childID) }).catch(() => {});
    }
    await db.recursiveDelete(db.collection("children").doc(childID));
    await db.collection("friendCards").doc(childID).delete().catch(() => {});
    console.log("[tombstone] blocked resurrection of deleted child", childID);
  } catch (e) {
    console.error("[tombstone] cleanup failed for", childID, e && e.message);
  }
});

// ---- 1a) Wake the child's device for a parent command -----------------------
// Parent commands (±minutes, gift, reset, revoke, remote lock/unlock) are written
// to Firestore and consumed by the child's device listener — but a BACKGROUNDED
// app never sees the write until the kid reopens Tofy. For a remote LOCK that's
// exactly the wrong moment. So: on any command write, send a SILENT push
// (content-available) to the household's child devices; iOS wakes the app for a
// few seconds, the listener fires, the command applies. No banner, no sound.

/** Balance a child actually has, in whole minutes. Counters first; the legacy
 *  minute field only for documents written before the counters existed. */
function walletMinutes(d, pocket) {
  const inKey = pocket === "gift" ? "giftSecondsIn" : "earnedSecondsIn";
  const outKey = pocket === "gift" ? "giftSecondsOut" : "earnedSecondsOut";
  if (typeof d[inKey] === "number" || typeof d[outKey] === "number") {
    return Math.max(0, (d[inKey] || 0) - (d[outKey] || 0)) / 60 | 0;
  }
  return (pocket === "gift" ? d.parentGiftMinutes : d.pendingMinutes) || 0;
}


// ---- 👑 A child asked for Tofy+ -------------------------------------------------
// The subscription is per FAMILY, bought once on a parent's phone. A child device
// never sells anything; it stamps `premiumRequestedAt` on its own child doc. Tell
// the parents — visibly, so it lands even if Tofy is force-quit on their phone.
exports.onPremiumRequest = onDocumentWritten("children/{childID}", async (event) => {
  const before = event.data.before && event.data.before.data ? event.data.before.data() : null;
  const after = event.data.after && event.data.after.data ? event.data.after.data() : null;
  if (!after) return;
  const stamp = after.premiumRequestedAt;
  if (!stamp || (before && before.premiumRequestedAt === stamp)) return;   // unchanged
  const hhID = after.householdID;
  if (!hhID) return;
  // One push per request: claim a dedup doc first (see PUSH-DEDUP INVARIANT).
  const key = `premiumreq_${event.params.childID}_${Math.round(stamp)}`;
  try { await db.collection("pushDedup").doc(key).create({ at: Date.now() }); }
  catch (e) { return; }
  const tokens = await tokensForHousehold(hhID);
  if (!tokens.length) return;
  const name = after.name || "הילד";
  const girl = after.gender === "girl";
  const TOPIC_HE = { math: "מתמטיקה 🧮", english: "אנגלית 🇬🇧", hebrew: "עברית ✍️", logic: "לוגיקה 🧩", science: "מדעים 🔬",
                     history: "היסטוריה 🏛️", geography: "גיאוגרפיה 🌍", money: "חינוך פיננסי 💰", reading: "הבנת הנקרא 📖" };
  const topic = TOPIC_HE[after.premiumRequestedTopic || ""];
  await send(tokens,
    topic
      ? { title: `${name} ${girl ? "רוצה" : "רוצה"} ללמוד ${topic}`,
          body: `${name} ${girl ? "לחצה" : "לחץ"} על העולם הזה בטופי. הוא נפתח עם טופי+ — מנוי אחד לכל המשפחה, מהטלפון שלכם.` }
      : { title: `👑 ${name} ${girl ? "רוצה" : "רוצה"} טופי+`,
          body: `${name} ${girl ? "ביקשה" : "ביקש"} לפתוח את המשחקים והעולמות. המנוי הוא לכל המשפחה — פותחים פעם אחת מהטלפון שלכם.` },
    { type: "premium-request", childID: event.params.childID });
});

// ⚽ A child asked for a question pack from their device ("בקש מאבא או אמא").
// Same shape as the Tofy+ request: one push per request, to the parents only.
exports.onPackRequest = onDocumentWritten("children/{childID}", async (event) => {
  const before = event.data.before && event.data.before.data ? event.data.before.data() : null;
  const after = event.data.after && event.data.after.data ? event.data.after.data() : null;
  if (!after) return;
  const stamp = after.packRequestedAt;
  if (!stamp || (before && before.packRequestedAt === stamp)) return;   // unchanged
  const hhID = after.householdID;
  if (!hhID) return;
  const key = `packreq_${event.params.childID}_${Math.round(stamp)}`;
  try { await db.collection("pushDedup").doc(key).create({ at: Date.now() }); }
  catch (e) { return; }
  const tokens = await tokensForHousehold(hhID);
  if (!tokens.length) return;
  const name = after.name || "הילד";
  const girl = after.gender === "girl";
  const packID = after.packRequestedID || "";
  const packName = PACK_NAMES[packID] || "שאלון חדש";
  await send(tokens,
    { title: `${PACK_EMOJI[packID] || "✨"} ${name} ${girl ? "מבקשת" : "מבקש"} את ${packName}`,
      body: `${name} ${girl ? "רוצה" : "רוצה"} ללמוד ${packName}. השאלון הוא תוספת חד-פעמית — פותחים מהטלפון שלכם.` },
    { type: "pack-request", childID: event.params.childID, packID });
});
// Pack copy for pushes — keep in sync with QuestionPacks (iOS) and PACKS in
// docs/admin/notifications.html.
const PACK_META = {
  soccer: { name: "עולם הכדורגל", emoji: "⚽", subject: "כדורגל", tagline: "שחקנים, קבוצות, תחרויות ועובדות מפתיעות" },
  dinosaurs: { name: "דינוזאורים", emoji: "🦖", subject: "דינוזאורים", tagline: "מינים, גדל, מה אכלו, ואיך מגלים מאבנים" },
  space: { name: "חלל וכוכבים", emoji: "🚀", subject: "חלל", tagline: "כוכבי לכת, ירח, אסטרונאוטים ושמש" },
  animals: { name: "עולם החיות", emoji: "🐾", subject: "חיות", tagline: "יבשות, חיות בסכנה ושיאים" },
  sea: { name: "מעמקי הים", emoji: "🌊", subject: "הים", tagline: "כרישים, לויתנים, שוניות, ומי חי איפה" },
  gifted: { name: "הכנה למחוננים", emoji: "🧠", subject: "חשיבה", tagline: "חשיבה, סדרות, הקשים ותפיסה מרחבית" },
  food: { name: "מטבח ומדע של אכל", emoji: "🍳", subject: "אכל", tagline: "מאין מגיע אכל, מדידות ומתכונים בחשבון" },
  israel: { name: "ישראל שלי", emoji: "🏛️", subject: "ישראל", tagline: "ערים, סמלים, חגים, דמיות וטבע" },
  music: { name: "מוזיקה", emoji: "🎵", subject: "מוזיקה", tagline: "כלי נגינה, קצב, מלחינים ושירי ילדים" },
  body: { name: "גוף האדם", emoji: "🧍", subject: "גוף האדם", tagline: "עצמות, לב, נשימה ובריאות" },
  vehicles: { name: "כלי רכב ותחבורה", emoji: "🚗", subject: "כלי רכב", tagline: "מכוניות, רכבות, מטוסים, ואיך זה עובד" },
  flags: { name: "דגלים ומדינות", emoji: "🌍", subject: "דגלים ומדינות", tagline: "דגלים, בירות ויבשות" },
};
const PACK_NAMES = Object.fromEntries(Object.entries(PACK_META).map(([k, v]) => [k, v.name]));
const PACK_EMOJI = Object.fromEntries(Object.entries(PACK_META).map(([k, v]) => [k, v.emoji]));

// The agreed launch message (Rani, 2026-09-06): the moment a pack is switched
// on, every family's parents get this — "we found a new world", never "buy".
function launchCampaignFor(packID) {
  const p = PACK_META[packID]; if (!p) return null;
  return {
    title: `עולם חדש בטופי: ${p.name}`, emoji: p.emoji,
    body: `גילינו עולם חדש בשביל הילדים: ${p.tagline}. על כל תשובה נכונה מרוויחים דקות משחק. למנויי טופי+ הוא כבר פתוח; אחרת שולחים לילד מהטלפון שלכם.`,
    childTitle: `רוצה ללמוד על ${p.subject}?`, childBody: `${p.tagline} — בקש מאבא או אמא`,
    audience: { roles: ["parents"], gradeMin: 0, gradeMax: 6, premium: "any", topics: [], excludeOwners: true },
    action: { type: "pack", packID }, showPopup: true,
  };
}

const COMMAND_FIELDS_CHILD = ["pendingMinuteAdjustment", "pendingGiftAdjustment", "pendingMoneyAdjustment", "resetRequestedAt", "revokeGiftAt"];
// appRemovalUnlockAt was MISSING here — the "allow app deletion" window never
// woke the child's device and only applied when the kid reopened Tofy.
const COMMAND_FIELDS_DEVICE = ["remoteLockAt", "remoteUnlockAt", "appRemovalUnlockAt"];

function commandChanged(before, after, fields) {
  return fields.some((f) => {
    const a = after ? after[f] : undefined, b = before ? before[f] : undefined;
    if (a === undefined || a === null) return false;      // cleared/consumed → not a new command
    if (typeof a === "number" && a === 0) return false;    // zeroed → consumed
    return a !== b;
  });
}

async function wakeChildDevices(householdID, reason) {
  if (!householdID) return;
  const tokens = await childTokensForHousehold(householdID);
  if (!tokens.length) return;
  try {
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      data: { type: "wake", reason: String(reason || "") },
      apns: { headers: { "apns-priority": "5", "apns-push-type": "background" },
              payload: { aps: { "content-available": 1 } } },
    });
    console.log("[wake]", reason, "sent", res.successCount, "/", tokens.length);
  } catch (e) { console.error("[wake] failed", e && e.message); }
}

// One-shot claim: create() fails if the doc exists, so exactly ONE function
// invocation wins per key. Vital because a command is written onto EVERY device
// row of the child — N rows → N invocations → N duplicate pushes without this
// (the "מלא נוטיפיקיישנים" bug).
async function claimOnce(key) {
  try {
    await db.collection("pushDedup").doc(key)
      .create({ at: admin.firestore.FieldValue.serverTimestamp() });
    return true;
  } catch (e) { return false; }
}

// Tokens of THIS child's devices only — from the fcmToken each device stamps on
// its own childDevices row. Precise: no siblings, no parents. Falls back to the
// household-wide childFcmTokens list (STRICT — child tokens only, never the
// legacy parent list: that fallback used to push kid-facing notifications to
// PARENT devices) for installs that haven't uploaded a per-row token yet.
async function tokensForChildOwnDevices(childID, householdID) {
  try {
    const snap = await db.collection("childDevices")
      .where("childID", "==", String(childID || "")).get();
    const tokens = snap.docs.map((d) => d.data())
      .filter((d) => d.removed !== true && d.fcmToken)
      .map((d) => d.fcmToken);
    if (tokens.length) return [...new Set(tokens)];
  } catch (e) { /* fall through */ }
  const hh = await db.collection("households").doc(String(householdID || "")).get();
  if (!hh.exists) return [];
  const tokens = [];
  for (const uid of hh.data().parentUIDs || []) {
    const p = await db.collection("parents").doc(uid).get();
    if (p.exists && Array.isArray(p.data().childFcmTokens)) tokens.push(...p.data().childFcmTokens);
  }
  return [...new Set(tokens)];
}

// A remote LOCK gets a stronger delivery than the throttleable silent wake: a
// VISIBLE high-priority push (gentle Hebrew, per the "never a failure" tone) that
// iOS delivers far more reliably. mutable-content lets the app's notification
// service extension apply the shield THE MOMENT the push arrives — even if Tofy
// itself was killed — and content-available still wakes the app when possible.
async function sendLockPushToChildDevices(householdID, childID) {
  if (!householdID) return;
  const tokens = await tokensForChildOwnDevices(childID, householdID);
  if (!tokens.length) return;
  try {
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      data: { type: "remote-lock" },
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: "טופי 💙", body: "זמן המסך נסגר עכשיו. אפשר להרוויח עוד דקות בטופי! 🌟" },
            "content-available": 1,
            "mutable-content": 1,
          },
        },
      },
    });
    console.log("[lock-push] sent", res.successCount, "/", tokens.length);
  } catch (e) { console.error("[lock-push] failed", e && e.message); }
}

// The parent's dashboard shows the ack live while it's open. This push closes
// the loop for the parent who already left: when a device acks a command LATE
// (it was offline/asleep when the parent tapped), tell the parent it happened.
const ACK_LATE_SECONDS = 25;

function newAck(before, after, field) {
  const a = after ? Number(after[field] || 0) : 0;
  const b = before ? Number(before[field] || 0) : 0;
  return a > b ? a : 0;   // the ack stamp == the command's own stamp
}

async function notifyParentsAckApplied(householdID, title, body) {
  // ALL parents, including the sender: a late ack means the sender long left the
  // live status sheet — this push IS the promised "נעדכן אותך כשזה יקרה".
  const tokens = await tokensForHousehold(householdID);
  if (!tokens.length) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) { console.error("[ack-push] failed", e && e.message); }
}

async function childNameFor(childID, fallback) {
  try {
    const c = await db.collection("children").doc(String(childID || "")).get();
    if (c.exists && c.data().name) return c.data().name;
  } catch (e) { /* fall through */ }
  return fallback;
}

exports.wakeOnChildCommand = onDocumentWritten("children/{childID}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  if (commandChanged(before, after, COMMAND_FIELDS_CHILD)) {
    await wakeChildDevices(after.householdID, "child-command");
  }
  // ACKs from the child's device → push the parents, but only when the ack
  // landed LATE (an instant ack already showed live in the dashboard sheet).
  const revokeAck = newAck(before, after, "revokeGiftAppliedAt");
  if (revokeAck && Date.now() / 1000 - revokeAck > ACK_LATE_SECONDS
      && await claimOnce(`revokeack_${event.params.childID}_${revokeAck}`)) {
    const name = await childNameFor(event.params.childID, after.name || "הילד/ה");
    await notifyParentsAckApplied(after.householdID,
      "💝 דקות המתנה נמחקו",
      `המכשיר של ${name} אישר עכשיו את מחיקת דקות המתנה.`);
  }
  const giftAck = newAck(before, after, "giftAppliedAt");
  if (giftAck && Date.now() / 1000 - giftAck > ACK_LATE_SECONDS
      && await claimOnce(`giftack_${event.params.childID}_${giftAck}`)) {
    const name = await childNameFor(event.params.childID, after.name || "הילד/ה");
    await notifyParentsAckApplied(after.householdID,
      "💝 המתנה הגיעה",
      `המכשיר של ${name} התחבר וקיבל את דקות המתנה.`);
  }
});

exports.wakeOnDeviceCommand = onDocumentWritten("childDevices/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  if (commandChanged(before, after, COMMAND_FIELDS_DEVICE)) {
    // A lock rides a reliable visible push; everything else keeps the silent
    // wake. Both dedup per (child, stamp): the command lands on EVERY device row
    // of the child, and without the claim each row's invocation sent its own
    // copy to every device — the notification-flood bug.
    if (commandChanged(before, after, ["remoteLockAt"])) {
      if (await claimOnce(`lock_${after.childID}_${after.remoteLockAt}`)) {
        await sendLockPushToChildDevices(after.householdID, after.childID);
      }
    } else {
      const stamp = after.remoteUnlockAt || after.appRemovalUnlockAt || 0;
      if (await claimOnce(`wake_${after.childID}_${stamp}`)) {
        await wakeChildDevices(after.householdID, "device-command");
      }
    }
  }
  // Lock ACK from the device → close the loop for a parent who already left.
  // Late-only (instant acks show live in the sheet), sender's devices excluded.
  const ack = newAck(before, after, "remoteLockAppliedAt");
  if (ack && Date.now() / 1000 - ack > ACK_LATE_SECONDS
      && await claimOnce(`lockack_${event.params.id}_${ack}`)) {
    const name = await childNameFor(after.childID, "הילד/ה");
    const device = after.name ? ` (${after.name})` : "";
    await notifyParentsAckApplied(after.householdID,
      "✅ הנעילה בוצעה",
      `המכשיר של ${name}${device} התחבר וננעל עכשיו.`);
  }
});

// ---- 1b) Live friends-quiz invite ------------------------------------------
// A child started a live quiz and invited their friends. Push each invited
// friend's device so they can jump in. We can't read tokens by childID directly
// (tokens live under the PARENT uid), so we resolve each invited child's owning
// parent via their public friendCard.ownerUID, then look up that parent's tokens.

exports.onLiveGameInvite = onDocumentCreated("liveGames/{gameID}", async (event) => {
  const data = event.data && event.data.data();
  if (!data) return;
  const invited = Array.isArray(data.invited) ? data.invited : [];
  if (!invited.length) return;

  const gameID = event.params.gameID;
  const hostName = data.hostName || "חבר";
  const hostOwnerUID = data.hostOwnerUID || null;
  const hostTokens = hostOwnerUID ? await childTokensForUID(hostOwnerUID) : [];

  const tokenSet = new Set();
  for (const childID of invited) {
    const card = await db.collection("friendCards").doc(childID).get();
    const ownerUID = card.exists ? card.data().ownerUID : null;
    if (!ownerUID || ownerUID === hostOwnerUID) continue;  // skip the host's own account
    const tokens = await childTokensForUID(ownerUID);       // invite a kid's OWN device
    tokens.forEach((t) => tokenSet.add(t));
  }
  const tokens = withoutHost([...tokenSet], hostTokens);
  console.log(`onLiveGameInvite game=${gameID} invited=${invited.length} -> ${tokens.length} token(s)`);
  if (!tokens.length) return;

  await send(
    tokens,
    { title: "🎮 הזמנה למשחק!", body: `${hostName} מזמין/ה אתכם למשחק חידון נגד חברים — מי הכי מהיר?` },
    { type: "liveGameInvite", gameID, link: `tofy://game?g=${gameID}` },
  );
});

// A direct invite to ONE friend, sent from the lobby ("הזמינו" button) so the
// host can call a specific friend who hasn't joined yet.
exports.onLiveGameNudge = onDocumentCreated("liveGames/{gameID}/nudges/{nudgeID}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.targetID) return;

  const gameID = event.params.gameID;
  const hostName = data.hostName || "חבר";
  const card = await db.collection("friendCards").doc(data.targetID).get();
  const ownerUID = card.exists ? card.data().ownerUID : null;
  if (!ownerUID) { console.log(`onLiveGameNudge: no friendCard/ownerUID for ${data.targetID}`); return; }
  // This is an INTENTIONAL invite to one chosen friend — just drop the host's own
  // device (with a fallback so a same-account test still delivers).
  const targetTokens = await childTokensForUID(ownerUID);    // the friend's OWN device
  const hostTokens = data.ownerUID ? await childTokensForUID(data.ownerUID) : [];
  const tokens = withoutHost(targetTokens, hostTokens);
  console.log(`onLiveGameNudge target=${data.targetID} owner=${ownerUID} targetTokens=${targetTokens.length} -> send ${tokens.length}`);
  if (!tokens.length) return;

  await send(
    tokens,
    { title: "🎮 קוראים לך למשחק!", body: `${hostName} מזמין/ה אותך להצטרף עכשיו — מי הכי מהיר?` },
    { type: "liveGameInvite", gameID, link: `tofy://game?g=${gameID}` },
  );
});

// ---- 1d) Sibling time transfers --------------------------------------------
// Buy flow: a child requests → the sibling (seller) agrees (pendingSeller) → a
// parent gives the final OK (pendingParent). Push the sibling when their consent
// is needed, and the parents when the final approval is needed. Gifts skip the
// sibling step and land straight on pendingParent.

exports.onTimeTransferWritten = onDocumentWritten("timeTransfers/{id}", async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after || !after.householdID) return;   // deleted, or malformed
  const beforeStatus = before ? before.status : null;

  // → pendingSeller: the sibling must agree to sell. Notify family child devices.
  if (after.status === "pendingSeller" && beforeStatus !== "pendingSeller") {
    const tokens = await childTokensForHousehold(after.householdID);
    if (tokens.length) {
      await send(
        tokens,
        { title: "🛒 בקשה לקניית זמן", body: `${after.toName} רוצה לקנות ממך ${after.minutes} דקות תמורת ${after.diamondPrice} 💎` },
        { type: "timeTransferSeller", id: event.params.id },
      );
    }
  }

  // → pendingParent: the sibling agreed (or it's a gift). Notify the parents.
  if (after.status === "pendingParent" && beforeStatus !== "pendingParent") {
    const tokens = await tokensForHousehold(after.householdID, null);
    if (tokens.length) {
      const body = (after.diamondPrice > 0)
        ? `${after.toName} רוצה לקנות ${after.minutes} דקות מ${after.fromName} — צריך אישור`
        : `${after.fromName} רוצה לתת ${after.minutes} דקות ל${after.toName} — צריך אישור`;
      await send(
        tokens,
        { title: "⏳ בקשת העברת זמן לאישור", body },
        { type: "timeTransferParent", id: event.params.id },
      );
    }
  }
});

// ---- 1c) Parent quick-help -------------------------------------------------
// A child asked a specific parent for help on a question. Push that parent an
// interactive notification (category PARENT_HELP) whose two buttons are the
// answer options — rendered with real text by the HelpContentExtension. The
// parent's tap is handled in the app (background) and written back to the doc.

// 🧹 Chores: push the PARENTS when a kid marks a chore done (approval needed),
// and the child's own device when the parent approved (the reward landed).
exports.onChoreWritten = onDocumentWritten("households/{householdID}/chores/{choreID}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const hhID = event.params.householdID;

  let name = "הילד/ה"; let doneVerb = "סיים/ה";
  try {
    const c = await db.collection("children").doc(String(after.childID || "")).get();
    if (c.exists) {
      name = c.data().name || name;
      doneVerb = c.data().gender === "girl" ? "סיימה" : "סיים";
    }
  } catch (e) { /* keep fallbacks */ }
  const choreLabel = `${after.emoji || "🧹"} ${after.title || "מטלה"}`;

  // Kid marked it done → the parents get an approve nudge. Interactive:
  // category CHORE_APPROVAL carries a "בוצע — אשרו" button the app handles in
  // the background (no launch), and mutable-content lets the notification
  // service extension attach the kid's proof photo, served by `chorePhoto`
  // behind an unguessable per-mark token.
  const markedNow = after.markedDoneAt && (!before || before.markedDoneAt !== after.markedDoneAt);
  if (markedNow) {
    const tokens = await tokensForHousehold(hhID);
    if (!tokens.length) return;
    const reward = after.chosenReward === "coins"
      ? `💰 ₪${after.rewardCoins || 0}` : `🎮 ${after.rewardMinutes || 0} דק׳`;
    const data = {
      type: "choreApproval",
      householdID: String(hhID),
      choreID: String(event.params.choreID),
    };
    if (after.photoData) {
      const token = require("crypto").randomBytes(16).toString("hex");
      await event.data.after.ref.update({ photoToken: token });
      data.photoURL = `https://us-central1-childtime-86e98.cloudfunctions.net/chorePhoto` +
        `?hh=${encodeURIComponent(hhID)}&chore=${encodeURIComponent(event.params.choreID)}&token=${token}`;
    }
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: `🧹 ${name} ${doneVerb} מטלה!`,
                      body: `${choreLabel} — מחכה לאישור שלכם (${reward})` },
      data,
      apns: { payload: { aps: { "sound": "default",
                                "category": "CHORE_APPROVAL",
                                "mutable-content": 1 } } },
    });
    return;
  }

  // Parent approved → celebrate on the kid's device. (chosenReward is cleared
  // by the approval write, so read the kid's pick from BEFORE.)
  const approvedNow = after.lastApprovedAt && (!before || before.lastApprovedAt !== after.lastApprovedAt);
  if (approvedNow) {
    const tokens = await tokensForChildOwnDevices(after.childID, hhID);
    if (!tokens.length) return;
    const reward = (before && before.chosenReward === "coins")
      ? `💰 ₪${after.rewardCoins || 0} נכנסו לקופה!`
      : `🎮 ${after.rewardMinutes || 0} דקות משחק נוספו!`;
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: "🎉 המטלה אושרה!", body: `${choreLabel} — ${reward}` },
      apns: { payload: { aps: { sound: "default" } } },
    });
  }
});

exports.onHelpRequest = onDocumentCreated("helpRequests/{id}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.parentUID) return;

  const tokens = await tokensForUID(data.parentUID);
  if (!tokens.length) return;

  const childName = data.childName || "הילד";
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: `🧠 ${childName} ביקש עזרה`, body: String(data.question || "") },
    data: {
      type: "parentHelp",
      helpRequestID: event.params.id,
      optionA: String(data.optionA || ""),
      optionB: String(data.optionB || ""),
      correctAnswer: String(data.correctAnswer || ""),
      childName: String(childName),
      question: String(data.question || ""),
      topic: String(data.topic || ""),
    },
    apns: {
      payload: {
        aps: {
          category: "PARENT_HELP",
          "mutable-content": 1,
          sound: "default",
        },
      },
    },
  });
});

// ---- 1b) Child-link requests ----------------------------------------------

exports.onChildLinkRequest = onDocumentWritten("childLinkRequests/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;

  // Created → notify the child (the targeted email) to open & approve.
  if (!before && after.status === "pending") {
    const tokens = await tokensForEmail(after.toEmail);
    await send(tokens,
      { title: "בקשת צירוף למשפחה 👨‍👩‍👧",
        body: `${after.fromParentName || "הורה"} מבקש/ת לצרף אותך למשפחה. פתחו את טופי כדי לאשר.` },
      { kind: "childLinkRequest", requestID: event.params.id });
    return;
  }

  // Approved → notify the requesting parent that the child is now linked.
  if (before && before.status !== "approved" && after.status === "approved") {
    const tokens = await tokensForUID(after.fromParentUID);
    await send(tokens,
      { title: "הצירוף אושר! ✅",
        body: "הילד/ה אישר/ה את הבקשה ומופיע/ה עכשיו במשפחה שלך." },
      { kind: "childLinkApproved", requestID: event.params.id });
  }
});

// ---- 2) Weekly report ------------------------------------------------------

exports.weeklyReport = onSchedule({ schedule: "every monday 18:00", timeZone: "Asia/Jerusalem" }, async () => {
  const childrenSnap = await db.collection("children").get();
  const since = Date.now() / 1000 - 7 * 24 * 3600;

  for (const childDoc of childrenSnap.docs) {
    const childID = childDoc.id;
    const name = childDoc.data().name || "הילד";
    const householdID = childDoc.data().householdID;

    const daysSnap = await childDoc.ref.collection("dailyStats").get();
    let questions = 0, correct = 0, minutesEarned = 0, longestStreak = 0, activeDays = 0;
    daysSnap.forEach((d) => {
      const s = d.data();
      const ts = Date.parse(s.date) / 1000;
      if (isNaN(ts) || ts < since) return;
      questions += s.questionsAnswered || 0;
      correct += s.correct || 0;
      minutesEarned += s.minutesEarned || 0;
      longestStreak = Math.max(longestStreak, s.longestStreak || 0);
      if ((s.questionsAnswered || 0) > 0) activeDays += 1;
    });

    const week = new Date().toISOString().slice(0, 10);
    await db.collection("weeklyReports").doc(childID).collection("weeks").doc(week)
      .set({ questions, correct, minutesEarned, longestStreak, activeDays, generatedAt: Date.now() / 1000 });

    if (questions === 0) continue;
    const tokens = await tokensForHousehold(householdID, null);
    await send(tokens,
      { title: `📊 דוח שבועי — ${name}`,
        body: `${questions} שאלות · ${minutesEarned} דק' שנצברו · רצף ${longestStreak} · ${activeDays} ימי פעילות` },
      { childID, kind: "weeklyReport" });
  }
});

// ---- Test push (self-check from Parent Settings) ---------------------------
// The app writes pushTests/{id} with its own uid; we push a test notification
// to THAT uid's tokens (not excluding any device, so the sender gets it too).
exports.sendTestPush = onDocumentCreated("pushTests/{id}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.uid) { console.log("[testPush] no uid in doc"); return; }
  const tokens = await tokensForUID(data.uid);
  console.log(`[testPush] uid=${data.uid} tokenCount=${tokens.length}`);
  if (!tokens.length) {
    console.warn("[testPush] NO TOKENS for this uid — the app hasn't uploaded an FCM token to parents/{uid}.fcmTokens yet.");
    await event.data.ref.delete().catch(() => {});
    return;
  }
  try {
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: "טופי — בדיקת התראות ✅", body: "מעולה! ההתראות עובדות." },
      apns: { payload: { aps: { sound: "default" } } },
    });
    console.log(`[testPush] sent: success=${res.successCount} failure=${res.failureCount}`);
    res.responses.forEach((r, i) => {
      if (!r.success) console.error(`[testPush] token#${i} FAILED: ${r.error && r.error.message}`);
    });
  } catch (e) {
    console.error("[testPush] send threw:", e && e.message);
  }
  await event.data.ref.delete().catch(() => {});
});

// ---- Parent feedback → email ----------------------------------------------
// When a parent submits feedback from the dashboard's floating button (written
// to `parentFeedback/{id}`), email it to the team so we see suggestions/bugs.
// Needs the GMAIL_USER / GMAIL_PASS secrets set (see top of file). Degrades
// gracefully: if creds are missing it just logs and leaves the doc in place.
exports.onParentFeedback = onDocumentCreated(
  { document: "parentFeedback/{id}", secrets: [GMAIL_USER, GMAIL_PASS] },
  async (event) => {
    const fb = (event.data && event.data.data()) || {};
    const when = fb.createdAt
      ? new Date(Number(fb.createdAt) * 1000).toLocaleString("he-IL", { timeZone: "Asia/Jerusalem" })
      : "";
    const lines = [
      `הודעה:`,
      `${fb.message || "(ריק)"}`,
      ``,
      `— מאת (uid): ${fb.fromUID || "anonymous"}`,
      `— משפחה: ${fb.householdID || "-"}`,
      `— גרסה: ${fb.appVersion || "-"}`,
      `— שפה: ${fb.locale || "-"}`,
      `— מתי: ${when}`,
    ];

    // Email to the team.
    const user = GMAIL_USER.value();
    const pass = GMAIL_PASS.value();
    if (!user || !pass) {
      console.warn("[feedback] GMAIL_USER/GMAIL_PASS not set — skipping email. Feedback:", lines.join(" | "));
      return;
    }

    try {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user, pass },
      });
      await transporter.sendMail({
        from: `ChildTime <${user}>`,
        to: FEEDBACK_TO,
        subject: "📩 פידבק חדש מהורה — ChildTime",
        text: lines.join("\n"),
        html: rtlBody(lines),
      });
      console.log("[feedback] emailed to", FEEDBACK_TO.join(", "));
    } catch (e) {
      console.error("[feedback] send failed:", e && e.message);
    }
  }
);

// ---- Bad-question report → email ------------------------------------------
// When a parent flags a question (the 🚩 in the game, written to
// `questionReports/{id}`), email it to the team so we can fix/remove it.
// Same Gmail secrets + recipient as parent feedback.
exports.onQuestionReport = onDocumentCreated(
  { document: "questionReports/{id}", secrets: [GMAIL_USER, GMAIL_PASS] },
  async (event) => {
    const r = (event.data && event.data.data()) || {};
    const when = r.createdAt
      ? new Date(Number(r.createdAt) * 1000).toLocaleString("he-IL", { timeZone: "Asia/Jerusalem" })
      : "";

    // Identify the reporter for the email: prefer the parent email/name the client
    // attached; if absent (e.g. reported from a child device), look up the account
    // by its uid. Falls back to the raw uid so the line is never empty.
    let reporterEmail = r.reporterEmail || "";
    let reporterName = r.reporterName || "";
    if ((!reporterEmail || !reporterName) && r.reportedBy && r.reportedBy !== "anonymous") {
      try {
        const p = await db.collection("parents").doc(r.reportedBy).get();
        if (p.exists) {
          reporterEmail = reporterEmail || p.data().email || "";
          reporterName = reporterName || p.data().displayName || "";
        }
      } catch (e) { console.warn("[questionReport] parent lookup failed:", e && e.message); }
    }
    const reporter = [reporterName, reporterEmail].filter(Boolean).join(" · ")
      || r.reportedBy || "anonymous";

    const lines = [
      `דווח על שאלה לא טובה:`,
      ``,
      `שאלה: ${r.prompt || "(ריק)"}`,
      `תשובה נכונה: ${r.correctAnswer || "-"}`,
      `נושא: ${r.topic || "-"}`,
      `סיבה: ${r.reason || "(לא צוינה)"}`,
      ``,
      `— ילד: ${r.childName || "-"}`,
      `— דווח ע"י: ${reporter}`,
      `— uid: ${r.reportedBy || "anonymous"}`,
      `— מתי: ${when}`,
    ];

    const user = GMAIL_USER.value();
    const pass = GMAIL_PASS.value();
    if (!user || !pass) {
      console.warn("[questionReport] GMAIL_USER/GMAIL_PASS not set — skipping email. Report:", lines.join(" | "));
      return;
    }

    try {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user, pass },
      });
      await transporter.sendMail({
        from: `ChildTime <${user}>`,
        to: FEEDBACK_TO,
        subject: "🚩 דיווח על שאלה לא טובה — ChildTime",
        text: lines.join("\n"),
        html: rtlBody(lines),
      });
      console.log("[questionReport] emailed to", FEEDBACK_TO.join(", "));
    } catch (e) {
      console.error("[questionReport] send failed:", e && e.message);
    }
  }
);

// ---- Early-access signup (marketing site) → email -------------------------
// A new doc in `waitlist/{id}` is created by the tofyapp.com early-access form.
// Email the team so we see every signup the moment it lands. Same Gmail secrets
// + recipients as feedback/reports.
exports.onWaitlistSignup = onDocumentCreated(
  { document: "waitlist/{id}", secrets: [GMAIL_USER, GMAIL_PASS] },
  async (event) => {
    const w = (event.data && event.data.data()) || {};
    let when = "";
    try {
      const t = w.createdAt;
      const d = t && t.toDate ? t.toDate() : (t ? new Date(t) : new Date());
      when = d.toLocaleString("he-IL", { timeZone: "Asia/Jerusalem" });
    } catch (e) { /* leave blank */ }
    const lines = [
      `נרשם חדש לרשימת ההמתנה של טופי! 🦁🎉`,
      ``,
      `אימייל: ${w.email || "-"}`,
      `שם: ${w.name || "-"}`,
      `גיל הילד: ${w.childAge || "-"}`,
      `מקור: ${w.source || "web"}`,
      `מתי: ${when}`,
    ];

    const user = GMAIL_USER.value();
    const pass = GMAIL_PASS.value();
    if (!user || !pass) {
      console.warn("[waitlist] GMAIL_USER/GMAIL_PASS not set — skipping email. Signup:", lines.join(" | "));
      return;
    }

    try {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user, pass },
      });
      // 1) Notify the team.
      await transporter.sendMail({
        from: `טופי <${user}>`,
        to: FEEDBACK_TO,
        subject: "🦁 נרשם חדש לרשימת ההמתנה — טופי",
        text: lines.join("\n"),
        html: rtlBody(lines),
      });
      console.log("[waitlist] team emailed to", FEEDBACK_TO.join(", "));

      // 2) Warm welcome/confirmation to the signup themselves (only if the
      //    address looks like a real email — never blast junk input).
      const signupEmail = String(w.email || "").trim();
      if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(signupEmail)) {
        const hi = w.name ? `היי ${w.name}! 🎉` : "היי! 🎉";
        const welcome = [
          hi,
          ``,
          `תודה שנרשמתם לרשימת ההמתנה של טופי — אתם רשמית מהראשונים בתור! 🦁`,
          ``,
          `נעדכן אתכם ברגע שטופי עולה לאוויר, ותקבלו הטבת השקה מיוחדת ל־טופי+.`,
          `בקרוב נלמד, נשחק, ונהפוך זמן מסך לפרס שמרוויחים. ✨`,
          ``,
          `נתראה בקרוב,`,
          `צוות טופי 🦁`,
        ];
        await transporter.sendMail({
          from: `טופי <${user}>`,
          to: signupEmail,
          subject: "ברוכים הבאים לטופי! 🦁 שמרנו לכם מקום",
          text: welcome.join("\n"),
          html: rtlBody(welcome),
        });
        console.log("[waitlist] welcome emailed to", signupEmail);
      }
    } catch (e) {
      console.error("[waitlist] send failed:", e && e.message);
    }
  }
);

// ---- 3) Founder analytics aggregator ---------------------------------------
// Computes AGGREGATE, non-PII numbers from the family data and writes them to
// adminStats/summary. The tofyapp.com/admin dashboard reads ONLY this doc — no
// raw child data ever reaches the browser. Refreshed every 6h, and triggerable
// on demand via runAdminStats (token-guarded) for the first backfill.
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");

// 📸 Serves a chore's proof photo to the notification service extension —
// gated by the random per-mark token minted in onChoreWritten. The photo (and
// with it this URL) dies when the parent approves/returns the chore.
exports.chorePhoto = onRequest(async (req, res) => {
  const { hh, chore, token } = req.query;
  if (!hh || !chore || !token) { res.status(400).send("bad request"); return; }
  try {
    const doc = await db.collection("households").doc(String(hh))
      .collection("chores").doc(String(chore)).get();
    const d = doc.exists ? doc.data() : null;
    if (!d || !d.photoToken || d.photoToken !== token || !d.photoData) {
      res.status(404).send("not found"); return;
    }
    res.set("Content-Type", "image/jpeg");
    res.set("Cache-Control", "private, max-age=600");
    res.send(Buffer.from(d.photoData));
  } catch (e) {
    console.error("[chorePhoto]", e && e.message);
    res.status(500).send("error");
  }
});
const ADMIN_TASK_TOKEN = defineSecret("ADMIN_TASK_TOKEN");
const DAY = 24 * 3600;
// Who may trigger an on-demand recompute from the signed-in /admin dashboard.
const ADMIN_EMAILS = ["ranioph@gmail.com", "amitgolans@gmail.com"];

async function computeAdminStats() {
  const now = Date.now() / 1000;
  const cut1 = now - 1 * DAY, cut7 = now - 7 * DAY, cut30 = now - 30 * DAY;
  const DK = (ts) => Math.floor(ts / DAY);
  const todayKey = DK(now);
  const uniq = (arr) => new Set(arr).size;
  const sum = (arr, f) => arr.reduce((s, x) => s + f(x), 0);
  const inWin = (arr, cut) => arr.filter((e) => e.createdAt >= cut);

  const [parentsSnap, householdsSnap, childrenSnap, devicesSnap] = await Promise.all([
    db.collection("parents").get(), db.collection("households").get(),
    db.collection("children").get(), db.collection("childDevices").get(),
  ]);

  // childID -> {createdAt, householdID}
  const meta = {};
  childrenSnap.docs.forEach((c) => {
    const d = c.data();
    meta[c.id] = { createdAt: Number(d.createdAt) || 0, householdID: d.householdID };
  });

  // Pull ALL events per child. Empty (zero events ever) = seeded/demo profile → dropped.
  const byChild = {};                 // childID -> sorted event array
  const realChildIDs = [], realHouseholds = new Set();
  const CHUNK = 25;
  for (let i = 0; i < childrenSnap.docs.length; i += CHUNK) {
    const slice = childrenSnap.docs.slice(i, i + CHUNK);
    const snaps = await Promise.all(slice.map((c) =>
      c.ref.collection("events").get().catch(() => ({ docs: [] }))));
    snaps.forEach((snap, k) => {
      if (snap.docs.length === 0) return;
      const c = slice[k];
      realChildIDs.push(c.id);
      realHouseholds.add(c.data().householdID);
      byChild[c.id] = snap.docs.map((doc) => {
        const e = doc.data();
        return {
          type: e.type, createdAt: Number(e.createdAt) || 0,
          accuracy: Number(e.accuracy) || 0, minutes: Number(e.minutes) || 0,
          stars: Number(e.stars) || 0, questions: Number(e.questions) || 0,
          xp: Number(e.xp) || 0, avgResponseMs: Number(e.avgResponseMs) || 0,
          wheelSpins: Number(e.wheelSpins) || 0, mystery: Number(e.mystery) || 0,
          topics: (e.topics && typeof e.topics === "object") ? e.topics : null,
        };
      }).sort((a, b) => a.createdAt - b.createdAt);
    });
  }
  const allEvents = realChildIDs.flatMap((id) => byChild[id].map((e) => ({ ...e, childID: id })));
  const ends = allEvents.filter((e) => e.type === "sessionEnd");
  const ends1 = inWin(ends, cut1), ends7 = inWin(ends, cut7), ends30 = inWin(ends, cut30);

  // ---- Totals: real adults + active-ever children ----
  const adultUIDs = new Set(parentsSnap.docs
    .filter((p) => { const d = p.data(); const cf = d.childFcmTokens; return !!d.email && !(cf && cf.length); })
    .map((p) => p.id));
  const realParentUIDs = new Set();
  householdsSnap.docs.forEach((h) => {
    if (realHouseholds.has(h.id)) (h.data().parentUIDs || []).forEach((u) => { if (adultUIDs.has(u)) realParentUIDs.add(u); });
  });
  const totals = {
    parents: realParentUIDs.size, children: realChildIDs.length, households: realHouseholds.size,
    devices: devicesSnap.docs.filter((d) => realHouseholds.has(d.data().householdID)).length,
  };
  const excluded = { children: childrenSnap.size - realChildIDs.length, parents: parentsSnap.size - realParentUIDs.size };

  // ================= 1) GROWTH =================
  const dau = uniq(inWin(allEvents, cut1).map((e) => e.childID));
  const wau = uniq(inWin(allEvents, cut7).map((e) => e.childID));
  const mau = uniq(inWin(allEvents, cut30).map((e) => e.childID));
  const newChildren7d = realChildIDs.filter((id) => meta[id].createdAt >= cut7).length;
  const hhFirst = {};                 // household -> earliest child createdAt
  realChildIDs.forEach((id) => {
    const hh = meta[id].householdID, ts = meta[id].createdAt;
    if (hh && ts && (hhFirst[hh] === undefined || ts < hhFirst[hh])) hhFirst[hh] = ts;
  });
  const newFamilies7d = Object.values(hhFirst).filter((ts) => ts >= cut7).length;
  // Retention: of children whose account is ≥N days old, the share who returned
  // (were active on a different day) within N days of joining.
  function retention(n) {
    const cohort = realChildIDs.filter((id) => meta[id].createdAt > 0 && (todayKey - DK(meta[id].createdAt)) >= n);
    if (!cohort.length) return { rate: null, cohort: 0 };
    const back = cohort.filter((id) => {
      const jd = DK(meta[id].createdAt);
      const days = new Set(byChild[id].map((e) => DK(e.createdAt)));
      for (let d = 1; d <= n; d++) if (days.has(jd + d)) return true;
      return false;
    }).length;
    return { rate: back / cohort.length, cohort: cohort.length };
  }
  const r1 = retention(1), r7 = retention(7), r30 = retention(30);

  // ================= 2) ENGAGEMENT =================
  // Session durations by pairing sessionStart -> sessionEnd per child.
  const sessions = [];                // {endTs, durMin|null}
  realChildIDs.forEach((id) => {
    let openTs = null;
    byChild[id].forEach((e) => {
      if (e.type === "sessionStart") openTs = e.createdAt;
      else if (e.type === "sessionEnd") {
        let dur = openTs != null ? (e.createdAt - openTs) / 60 : null;
        if (dur != null && (dur < 0 || dur > 180)) dur = null;   // sanity cap 3h
        sessions.push({ endTs: e.createdAt, durMin: dur });
        openTs = null;
      }
    });
  });
  const dur7 = sessions.filter((s) => s.endTs >= cut7 && s.durMin != null);
  const avgSessionLengthMin = dur7.length ? sum(dur7, (s) => s.durMin) / dur7.length : null;
  const childDays7 = uniq(inWin(allEvents, cut7).map((e) => e.childID + "|" + DK(e.createdAt)));
  const sessionsPerActiveChildDay = childDays7 ? ends7.length / childDays7 : 0;
  const avgMinPerChildDay = avgSessionLengthMin != null ? avgSessionLengthMin * sessionsPerActiveChildDay : null;
  const questionsPerDay = sum(ends7, (e) => e.questions) / 7;
  const questionsPerSession = ends7.length ? sum(ends7, (e) => e.questions) / ends7.length : 0;
  const totalQuestions = sum(ends, (e) => e.questions);

  // ================= 3) LEARNING =================
  const accAvg = (arr) => { const s = arr.filter((e) => e.questions > 0); return s.length ? sum(s, (e) => e.accuracy) / s.length / 100 : null; };
  const accuracy = { today: accAvg(ends1), week: accAvg(ends7), month: accAvg(ends30) };
  const topicMap = {};
  ends7.forEach((e) => {
    if (!e.topics) return;
    for (const [name, v] of Object.entries(e.topics)) {
      const q = Number(v.q) || 0, correct = Number(v.correct) || 0, avgMs = Number(v.avgMs) || 0;
      const t = topicMap[name] || (topicMap[name] = { topic: name, q: 0, correct: 0, msW: 0 });
      t.q += q; t.correct += correct; t.msW += avgMs * correct;
    }
  });
  const topicArr = Object.values(topicMap).map((t) => ({
    topic: t.topic, sessions: t.q, avgAccuracy: t.q ? t.correct / t.q : null,
    avgResponseSec: t.correct ? Math.round(t.msW / t.correct / 100) / 10 : null,
  }));
  const topicsPopular = topicArr.slice().sort((a, b) => b.sessions - a.sessions).slice(0, 5);
  const ranked = topicArr.filter((t) => t.avgAccuracy != null && t.sessions >= 2);
  const topicsStrong = ranked.slice().sort((a, b) => b.avgAccuracy - a.avgAccuracy).slice(0, 3);
  const topicsWeak = ranked.slice().sort((a, b) => a.avgAccuracy - b.avgAccuracy).slice(0, 3);

  // ================= 4) ECONOMY =================
  const earned1 = sum(ends1, (e) => e.minutes), earned7 = sum(ends7, (e) => e.minutes), earned30 = sum(ends30, (e) => e.minutes);
  // Minutes USED: pair screenTimeStart (available) -> screenTimeEnd (left); used = avail - left.
  let used7 = 0;
  realChildIDs.forEach((id) => {
    let openMin = null;
    byChild[id].forEach((e) => {
      if (e.type === "screenTimeStart") openMin = e.minutes;
      else if (e.type === "screenTimeEnd") {
        if (openMin != null && e.createdAt >= cut7) { const u = openMin - e.minutes; if (u > 0 && u <= 600) used7 += u; }
        openMin = null;
      }
    });
  });
  // XP, wheel spins, mystery portals, and response time (from the enriched
  // sessionEnd events — populate once the build that emits them is in use).
  const xp1 = sum(ends1, (e) => e.xp), xp7 = sum(ends7, (e) => e.xp), xp30 = sum(ends30, (e) => e.xp);
  const wheelSpins7 = sum(ends7, (e) => e.wheelSpins), mystery7 = sum(ends7, (e) => e.mystery);
  const rtS = ends7.filter((e) => e.avgResponseMs > 0 && e.questions > 0);
  const rtNum = sum(rtS, (e) => e.avgResponseMs * e.questions), rtDen = sum(rtS, (e) => e.questions);
  const avgResponseSec = rtDen ? Math.round(rtNum / rtDen / 100) / 10 : null;

  // Daily series (30d): active children, sessions, minutes earned.
  const daily = [];
  for (let d = 29; d >= 0; d--) {
    const k = todayKey - d, dt = new Date(k * DAY * 1000);
    const dayEnds = ends.filter((e) => DK(e.createdAt) === k);
    daily.push({
      date: `${dt.getDate()}/${dt.getMonth() + 1}`,
      activeChildren: uniq(allEvents.filter((e) => DK(e.createdAt) === k).map((e) => e.childID)),
      sessions: dayEnds.length, minutes: sum(dayEnds, (e) => e.minutes),
    });
  }

  const summary = {
    updatedAt: new Date().toLocaleString("he-IL", { timeZone: "Asia/Jerusalem" }),
    updatedAtUnix: now,
    totals, excluded,
    headline: { learningMinutes: { today: earned1, week: earned7, month: earned30 } },
    growth: {
      dau, wau, mau, newChildren7d, newFamilies7d,
      retention: { d1: r1.rate, d7: r7.rate, d30: r30.rate, cohort: { d1: r1.cohort, d7: r7.cohort, d30: r30.cohort } },
    },
    engagement: {
      avgMinPerChildDay, avgSessionLengthMin, sessionsPerActiveChildDay,
      questionsPerDay, questionsPerSession, totalQuestions,
      sessionsToday: ends1.length, sessions7d: ends7.length,
    },
    learning: { accuracy, avgResponseSec, topicsPopular, topicsStrong, topicsWeak },
    economy: {
      minutesEarned: { today: earned1, week: earned7, month: earned30 },
      minutesUsed7: used7, minutesUnused7: Math.max(0, earned7 - used7),
      xp: { today: xp1, week: xp7, month: xp30 }, wheelSpins7, mystery7,
    },
    daily,
    notTracked: ["minutesLostToMistakes"],
  };
  await db.collection("adminStats").doc("summary").set(summary);
  console.log("[adminStats] wrote summary", { ...totals, events: allEvents.length });
  return summary;
}

exports.refreshAdminStats = onSchedule(
  { schedule: "every 6 hours", timeZone: "Asia/Jerusalem", timeoutSeconds: 300, memory: "512MiB" },
  async () => { await computeAdminStats(); }
);

// On-demand recompute for the signed-in /admin dashboard. The dashboard polls
// this every few seconds so the founder sees fresh numbers without reloading.
// Auth-guarded: only the allow-listed admin Google accounts may call it.
exports.recomputeAdminStats = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const summary = await computeAdminStats();
    return { ok: true, updatedAt: summary.updatedAt };
  }
);

// Full families overview for the founder's product page (/admin/families.html):
// every household with its parents, children, progress and devices. READ-ONLY,
// aggregated server-side (no broad client read rules), admin-gated like
// recomputeAdminStats. First-party founder tooling — no third-party analytics.
exports.adminFamiliesOverview = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const [hhSnap, kidsSnap, devsSnap, tombSnap, parentsSnap] = await Promise.all([
      db.collection("households").get(),
      db.collection("children").get(),
      db.collection("childDevices").get(),
      db.collection("deletedChildren").get(),
      db.collection("parents").get(),
    ]);
    const parentInfo = {};
    parentsSnap.forEach((p) => {
      const d = p.data();
      parentInfo[p.id] = {
        email: d.email || null,
        name: d.displayName || null,
        updatedAt: p.updateTime ? p.updateTime.toMillis() / 1000 : null,
      };
    });
    const kidsByHH = {};
    kidsSnap.forEach((k) => {
      const d = k.data();
      (kidsByHH[d.householdID] = kidsByHH[d.householdID] || [])
        .push({ id: k.id, createdAt: k.createTime ? k.createTime.toMillis() / 1000 : null, ...d });
    });
    const devsByChild = {};
    // uids that own a device row seen in the last 14 days ("live account").
    // Rows from builds before the ownerUID stamp have no uid — tri-state below.
    const liveUIDs = new Set();
    const parentDevsByHH = {};      // householdID -> the PARENT phones
    let anyRowHasUID = false;
    devsSnap.forEach((dv) => {
      const cid = dv.id.split("_")[0];
      const d = dv.data();
      // A parent's phone registers in the same collection with role:"parent" and
      // no childID, so it must not be grouped under a child — it is not one of
      // the child's play devices and is never part of the window checks.
      if (d.role === "parent" || !d.childID) {
        (parentDevsByHH[d.householdID] = parentDevsByHH[d.householdID] || []).push({
          docID: dv.id, lastSeenAt: d.lastSeenAt || 0,
          kind: d.deviceKind || d.kind || null,
          name: d.deviceName || d.name || null,
          appVersion: d.appVersion || null,
          kidModeChildID: d.kidModeChildID || null,
        });
        return;
      }
      if (d.ownerUID) {
        anyRowHasUID = true;
        const seen = typeof d.lastSeenAt === "number" ? d.lastSeenAt : 0;
        if (seen > Date.now() / 1000 - 14 * 86400) liveUIDs.add(d.ownerUID);
      }
      (devsByChild[cid] = devsByChild[cid] || [])
        .push({ docID: dv.id, lastSeenAt: d.lastSeenAt || 0, kind: d.deviceKind || null,
                name: d.deviceName || null, appVersion: d.appVersion || null });
    });
    const tombsByHH = {};
    tombSnap.forEach((t) => { const h = t.data().householdID; tombsByHH[h] = (tombsByHH[h] || 0) + 1; });

    // Per-child progress — read state/current in parallel; use the doc's own
    // server updateTime as "last active" (the payload's lastModifiedAt is a
    // Swift reference-date number, not unix).
    const states = {};
    const windows = {};
    await Promise.all(kidsSnap.docs.map(async (k) => {
      const stateRef = db.collection("children").doc(k.id).collection("state");
      const [st, win] = await Promise.all([stateRef.doc("current").get(),
                                           stateRef.doc("window").get()]);
      if (st.exists) states[k.id] = { data: st.data(), updatedAt: st.updateTime.toMillis() / 1000 };
      // The OPEN play window. While a child is playing their wallet reads 0 —
      // the minutes are held by the lease, not the pocket — so a dashboard that
      // only shows the balance says "0" about a child who is playing right now.
      // The lease carries a server-stamped start and a length, so the remaining
      // time is derivable and can tick live in the browser.
      const w = win.exists ? win.data() : null;
      if (w && w.state === "open" && w.startedAt && w.grantedSeconds) {
        const startedAt = typeof w.startedAt.toMillis === "function"
          ? w.startedAt.toMillis() / 1000 : Number(w.startedAt) || 0;
        if (startedAt) {
          windows[k.id] = { endsAt: startedAt + Number(w.grantedSeconds),
                            kind: w.kind || "earned",
                            ownerName: w.ownerName || null };
        }
      }
    }));

    const families = [];
    hhSnap.forEach((h) => {
      const d = h.data();
      const kids = (kidsByHH[h.id] || []).map((k) => {
        const s = states[k.id];
        const devs = devsByChild[k.id] || [];
        return {
          id: k.id.slice(0, 8),
          name: k.name || "?",
          grade: (k.grade === 0 || k.grade) ? k.grade : null,
          gender: k.gender || null,
          createdAt: k.createdAt,
          liveWindow: windows[k.id] || null,
          stars: s ? (s.data.stars || 0) : 0,
          diamonds: s ? (s.data.diamonds || 0) : 0,
          // Prefer the wallet COUNTERS (in - out, in seconds). The legacy minute
          // fields are a last-write-wins mirror that a device whose counters are
          // behind can win, so reading them showed 0 next to a real balance.
          pendingMinutes: s ? walletMinutes(s.data, "earned") : 0,
          giftMinutes: s ? walletMinutes(s.data, "gift") : 0,
          answered: s ? (s.data.totalAnswered || 0) : 0,
          revision: s ? (s.data.revision || 0) : 0,
          lastActiveAt: s ? s.updatedAt : null,
          devices: devs.length,
          deviceRows: devs
            .sort((a, b) => (b.lastSeenAt || 0) - (a.lastSeenAt || 0))
            .map((x) => ({ docID: x.docID, kind: x.kind, name: x.name,
                           appVersion: x.appVersion || null, lastSeenAt: x.lastSeenAt || null })),
          lastSeenAt: devs.reduce((m, x) => Math.max(m, x.lastSeenAt || 0), 0) || null,
        };
      }).sort((a, b) => (b.lastActiveAt || 0) - (a.lastActiveAt || 0));
      const parents = (d.parentUIDs || []).map((uid) => ({
        uid,   // admin page needs it for unlink actions
        name: (d.parentNames || {})[uid] || parentInfo[uid]?.name || null,
        email: parentInfo[uid]?.email || null,
        anonymous: !parentInfo[uid]?.email,
        // The household CREATOR with an anonymous account is a GUEST PARENT
        // (using Tofy without signing up) — not a child device's account.
        isGuestParent: uid === d.createdBy && !parentInfo[uid]?.email,
        lastUpdateAt: parentInfo[uid]?.updatedAt || null,
        // true = owns a device row seen <14d; false = uid-stamped rows exist
        // but none is this uid's (dead account); null = no stamp data yet
        // (old builds) — the page falls back to the update-time signal.
        hasLiveDevice: anyRowHasUID ? liveUIDs.has(uid) : null,
      }));
      // 🧪 Demo detection: an admin-marked family (label contains 🧪), or a
      // NAMELESS one whose children are exactly the DEMO_SCREEN seed names
      // (דנה/יואב, niqqud-stripped) — the signature of a leaked demo run.
      const strip = (s) => String(s || "").normalize("NFD").replace(/[֑-ׇ]/g, "").trim();
      const demoNames = new Set(["דנה", "יואב"]);
      const named = Object.values(d.parentNames || {}).filter((n) => String(n || "").trim());
      // Explicit admin flag wins in BOTH directions; auto-detection (🧪 label
      // or the seed-name signature) only applies when no flag was set.
      const isDemo = d.demo === true ? true : d.demo === false ? false :
        ((d.familyLabel || "").includes("🧪") ||
         (named.length === 0 && kids.length > 0 && kids.every((k) => demoNames.has(strip(k.name)))));
      const parentDevs = (parentDevsByHH[h.id] || [])
        .sort((a, b) => (b.lastSeenAt || 0) - (a.lastSeenAt || 0));
      families.push({
        parentDevices: parentDevs,
        id: h.id.slice(0, 8),
        fullId: h.id,     // needed by the admin actions (admin-only page)
        familyLabel: d.familyLabel || null,   // admin-set display label
        familyName: d.familyName || null,   // the parent-set name (Settings → שם המשפחה)
        premiumUntil: d.premiumUntil || null,   // Tofy+ for the whole family (epoch seconds)
        isDemo,
        parents,
        tombstones: tombsByHH[h.id] || 0,
        children: kids,
        lastActiveAt: kids.reduce((m, k) => Math.max(m, k.lastActiveAt || 0, k.lastSeenAt || 0), 0) || null,
      });
    });
    families.sort((a, b) => (b.lastActiveAt || 0) - (a.lastActiveAt || 0));
    const now = Date.now() / 1000;
    return {
      generatedAt: now,
      totals: {
        families: families.length,
        familiesWithKids: families.filter((f) => f.children.length).length,
        children: kidsSnap.size,
        activeToday: families.filter((f) => f.lastActiveAt && now - f.lastActiveAt < 86400).length,
      },
      families,
    };
  }
);

// Delete an EMPTY household from the admin families page. Defense in depth:
// admin-gated AND the server re-verifies emptiness itself — a household with
// any children docs or any NAMED parent is refused no matter what the client
// sent. Cleans the invites that pointed at it and unlinks it from parents
// docs so an abandoned anonymous uid re-bootstraps cleanly. A real family can
// NEVER be deleted through this path.
exports.adminDeleteHousehold = onCall(
  { timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const hhID = String(request.data && request.data.householdID || "");
    if (!/^[0-9A-Fa-f-]{36}$/.test(hhID)) {
      throw new HttpsError("invalid-argument", "householdID must be a UUID.");
    }
    const ref = db.collection("households").doc(hhID);
    const hh = await ref.get();
    if (!hh.exists) throw new HttpsError("not-found", "Household not found.");
    const d = hh.data();
    // SERVER-SIDE safety re-checks — never trust the caller's view.
    const named = Object.values(d.parentNames || {}).filter((n) => String(n || "").trim());
    if (named.length) {
      throw new HttpsError("failed-precondition", `Household has a named parent (${named[0]}) — refusing to delete.`);
    }
    const kids = await db.collection("children").where("householdID", "==", hhID).get();
    if (!kids.empty) {
      // A NAMELESS household that still holds children (an abandoned guest /
      // pre-signup family) may be removed ONLY with the explicit withChildren
      // flag AND when every child has been inactive for 30+ days. Children are
      // deleted through the full tombstone flow so no device resurrects them.
      if (!(request.data && request.data.withChildren)) {
        throw new HttpsError("failed-precondition", "Household has children — pass withChildren to delete a dormant nameless family.");
      }
      // 🧪 A confirmed DEMO family (admin 🧪 label, or nameless with exactly
      // the DEMO_SCREEN seed child names) skips the 30-day dormancy rule —
      // it was never a real family. Everything else must be truly dormant.
      const strip = (s) => String(s || "").normalize("NFD").replace(/[֑-ׇ]/g, "").trim();
      const demoNames = new Set(["דנה", "יואב"]);
      const isDemo = d.demo === true || (d.familyLabel || "").includes("🧪") ||
        kids.docs.every((k) => demoNames.has(strip(k.data().name)));
      if (!isDemo) {
        const cutoff = Date.now() - 30 * 86400 * 1000;
        for (const k of kids.docs) {
          const st = await db.collection("children").doc(k.id).collection("state").doc("current").get();
          const lastMs = Math.max(st.exists ? st.updateTime.toMillis() : 0, k.updateTime.toMillis());
          if (lastMs > cutoff) {
            throw new HttpsError("failed-precondition",
              `Child "${k.data().name || k.id.slice(0, 8)}" was active in the last 30 days — refusing to delete.`);
          }
        }
      }
      for (const k of kids.docs) {
        await db.collection("deletedChildren").doc(k.id).set({
          householdID: hhID, deletedAt: Date.now() / 1000, reason: "admin-nameless-family-cleanup",
        });
        await db.recursiveDelete(db.collection("children").doc(k.id));
        await db.collection("friendCards").doc(k.id).delete().catch(() => {});
      }
      console.log("[adminDeleteHousehold]", email, "tombstoned+deleted", kids.size, "dormant children of", hhID);
    }
    // Cleanup: invites for this household, and unlink from parents docs.
    const invites = await db.collection("invites").where("householdID", "==", hhID).get();
    for (const inv of invites.docs) await inv.ref.delete();
    const linkedParents = await db.collection("parents")
      .where("householdIDs", "array-contains", hhID).get();
    for (const p of linkedParents.docs) {
      await p.ref.update({ householdIDs: admin.firestore.FieldValue.arrayRemove(hhID) });
    }
    await ref.delete();
    console.log("[adminDeleteHousehold]", email, "deleted empty household", hhID,
      `(invites: ${invites.size}, unlinked parents: ${linkedParents.size})`);
    return { ok: true, invitesDeleted: invites.size, parentsUnlinked: linkedParents.size };
  }
);

// Unlink an ANONYMOUS uid (a child device's account) from a household's
// parentUIDs — replaced devices' accounts linger there forever, inflating the
// family's "child devices" count. Guarded: an account WITH an email (a real
// parent) can never be unlinked here. Inherently safe for live devices too:
// a still-active child device re-adds its own uid on next launch (the
// preferredHousehold self-heal in ensureHousehold).
exports.adminUnlinkParentUID = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const hhID = String(request.data && request.data.householdID || "");
    const uid = String(request.data && request.data.uid || "");
    if (!/^[0-9A-Fa-f-]{36}$/.test(hhID) || !/^[A-Za-z0-9]{10,128}$/.test(uid)) {
      throw new HttpsError("invalid-argument", "householdID (UUID) and uid required.");
    }
    const pDoc = await db.collection("parents").doc(uid).get();
    if (pDoc.exists && String(pDoc.data().email || "").trim()) {
      throw new HttpsError("failed-precondition", "That uid belongs to a REAL parent account — refusing to unlink.");
    }
    await db.collection("households").doc(hhID).update({
      parentUIDs: admin.firestore.FieldValue.arrayRemove(uid),
      [`parentNames.${uid}`]: admin.firestore.FieldValue.delete(),
    });
    if (pDoc.exists) {
      await pDoc.ref.update({ householdIDs: admin.firestore.FieldValue.arrayRemove(hhID) }).catch(() => {});
    }
    console.log("[adminUnlinkParentUID]", email, "unlinked anonymous uid", uid.slice(0, 8), "from", hhID);
    return { ok: true };
  }
);

// Flag / unflag a household as DEMO (shown in the admin page's 🧪 section).
// Explicit flag overrides auto-detection both ways. Display-only power: the
// delete path STILL refuses any household with a named parent, so flagging a
// real family as demo cannot make it deletable.
exports.adminSetDemoFlag = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const hhID = String(request.data && request.data.householdID || "");
    if (!/^[0-9A-Fa-f-]{36}$/.test(hhID)) {
      throw new HttpsError("invalid-argument", "householdID must be a UUID.");
    }
    const demo = request.data && request.data.demo === true;
    const ref = db.collection("households").doc(hhID);
    if (!(await ref.get()).exists) throw new HttpsError("not-found", "Household not found.");
    await ref.update({ demo });
    console.log("[adminSetDemoFlag]", email, hhID, "→ demo:", demo);
    return { ok: true, demo };
  }
);

// Set / clear the admin-facing display label of a household (shown on the
// families page — e.g. naming a family whose parents have no account name).
exports.adminSetFamilyLabel = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const hhID = String(request.data && request.data.householdID || "");
    if (!/^[0-9A-Fa-f-]{36}$/.test(hhID)) {
      throw new HttpsError("invalid-argument", "householdID must be a UUID.");
    }
    const label = String(request.data && request.data.label || "").trim().slice(0, 60);
    const ref = db.collection("households").doc(hhID);
    if (!(await ref.get()).exists) throw new HttpsError("not-found", "Household not found.");
    if (label) await ref.update({ familyLabel: label });
    else await ref.update({ familyLabel: admin.firestore.FieldValue.delete() });
    console.log("[adminSetFamilyLabel]", email, hhID, "→", label || "(cleared)");
    return { ok: true, label: label || null };
  }
);

// Delete a single childDevices row from the admin families page (a replaced /
// retired device that lingers in the list). SAFE by nature: an ACTIVE device
// re-creates its own row on its next heartbeat, so even a mistaken delete
// self-heals within minutes; only truly-dead devices stay gone.
exports.adminDeleteChildDevice = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
    if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
      throw new HttpsError("permission-denied", "Not an authorized admin.");
    }
    const docID = String(request.data && request.data.docID || "");
    if (!/^[0-9A-Fa-f-]{36}_[0-9A-Fa-f-]{36}$/.test(docID)) {
      throw new HttpsError("invalid-argument", "docID must be childID_installID.");
    }
    await db.collection("childDevices").doc(docID).delete();
    console.log("[adminDeleteChildDevice]", email, "deleted device row", docID);
    return { ok: true };
  }
);

// Nightly hygiene: drop childDevices rows silent for 60+ days — replaced or
// wiped devices whose rows otherwise linger forever (Dan showed 7 devices
// with 2 real). Active devices refresh lastSeenAt constantly, so they are
// never touched; a false positive would self-heal on the device's next
// heartbeat anyway.
exports.pruneStaleChildDevices = onSchedule(
  { schedule: "every day 03:30", timeZone: "Asia/Jerusalem", timeoutSeconds: 300 },
  async () => {
    const cutoff = Date.now() / 1000 - 60 * 86400;
    const snap = await db.collection("childDevices").get();
    let pruned = 0;
    for (const dv of snap.docs) {
      const seen = dv.data().lastSeenAt || 0;
      if (seen && seen < cutoff) { await dv.ref.delete(); pruned++; }
    }
    if (pruned) console.log(`[pruneStaleChildDevices] pruned ${pruned} rows silent for 60+ days`);

    // NOTE: automatic orphan-ACCOUNT unlinking was removed 2026-08-30 after it
    // stripped the anonymous parent uid off two REAL guest families on its
    // first run. The "parents doc untouched for 60 days" signal is wrong for
    // devices that declined notifications (they never rewrite their doc after
    // creation). Account cleanup stays MANUAL via the admin families page,
    // where the ✕ per-uid button shows context first. Only the device-ROW
    // prune above remains — that one is genuinely self-healing.
  }
);

// Manual trigger / first backfill — guarded by a shared token (secret). Returns
// the aggregate only to the token holder; otherwise 403.
exports.runAdminStats = onRequest(
  { secrets: [ADMIN_TASK_TOKEN], timeoutSeconds: 300, memory: "512MiB" },
  async (req, res) => {
    const token = req.query.token || req.get("x-admin-token");
    if (!ADMIN_TASK_TOKEN.value() || token !== ADMIN_TASK_TOKEN.value()) {
      res.status(403).json({ error: "forbidden" });
      return;
    }
    try {
      // ?breakdown=1 — founder-only diagnostic (token-guarded, never stored):
      // lists each child with its parent email + recent activity, so you can
      // spot which accounts are test/demo and add them to EXCLUDE_EMAILS.
      if (req.query.breakdown) {
        const [pSnap, hSnap, cSnap] = await Promise.all([
          db.collection("parents").get(), db.collection("households").get(), db.collection("children").get(),
        ]);
        const email = {}; pSnap.docs.forEach((p) => { email[p.id] = p.data().email || p.data().displayName || p.id; });
        const hhP = {}; hSnap.docs.forEach((h) => { hhP[h.id] = (h.data().parentUIDs || []).map((u) => email[u] || u); });
        const cut7 = Date.now() / 1000 - 7 * DAY;
        const rows = await Promise.all(cSnap.docs.map(async (c) => {
          const ev = await c.ref.collection("events").where("createdAt", ">=", cut7).get().catch(() => ({ docs: [] }));
          return {
            child: c.data().name || c.id,
            parents: (hhP[c.data().householdID] || []).join(", "),
            sessions7d: ev.docs.filter((d) => d.data().type === "sessionEnd").length,
          };
        }));
        res.json({ ok: true, children: rows.length, rows: rows.sort((a, b) => b.sessions7d - a.sessions7d) });
        return;
      }
      res.json({ ok: true, summary: await computeAdminStats() });
    } catch (e) { console.error(e); res.status(500).json({ error: e && e.message }); }
  }
);

// ============================================================================
// 📣 Campaigns — "הודעות ועדכונים" (admin push + in-app announcements)
// ============================================================================
// A campaign is one message to one audience at one time. The admin page
// composes it (adminSaveCampaign), estimates who it reaches
// (adminCampaignEstimate), sends itself a test (adminSendCampaignTest), and
// the scheduler delivers due campaigns (dispatchCampaigns). Every step of the
// funnel is counted in OUR Firestore by the app (campaigns/{id}.stats.*) —
// no third-party analytics (Kids Category).

function requireAdmin(request) {
  const email = (request.auth && request.auth.token && request.auth.token.email || "").toLowerCase();
  if (!email || !ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(email)) {
    throw new HttpsError("permission-denied", "Not an authorized admin.");
  }
  return email;
}

const CAMPAIGN_STAT_KEYS = ["targeted", "sent", "failed", "opened", "page", "purchaseStarted", "purchased", "sentToChild", "popup"];

function cleanCampaign(input) {
  const d = input || {};
  const s = (v, n) => String(v == null ? "" : v).trim().slice(0, n);
  const aud = d.audience || {};
  const roles = Array.isArray(aud.roles) ? aud.roles.filter((r) => r === "parents" || r === "children") : ["parents"];
  const gradeMin = Number.isFinite(Number(aud.gradeMin)) ? Math.max(0, Math.min(6, Number(aud.gradeMin))) : 0;
  const gradeMax = Number.isFinite(Number(aud.gradeMax)) ? Math.max(0, Math.min(6, Number(aud.gradeMax))) : 6;
  const premium = ["any", "with", "without"].includes(aud.premium) ? aud.premium : "any";
  const topics = Array.isArray(aud.topics) ? aud.topics.map((t) => s(t, 24)).filter(Boolean).slice(0, 12) : [];
  const act = d.action || {};
  const actionType = ["none", "pack", "parentHome", "kidHome", "tofyPlus"].includes(act.type) ? act.type : "none";
  const packID = actionType === "pack" ? s(act.packID, 40) : "";
  const scheduledAt = Number(d.scheduledAt) > 0 ? Number(d.scheduledAt) : Date.now();
  const status = ["draft", "scheduled"].includes(d.status) ? d.status : "draft";
  return {
    title: s(d.title, 80), body: s(d.body, 240), emoji: s(d.emoji, 8), imageURL: s(d.imageURL, 400),
    childTitle: s(d.childTitle, 80), childBody: s(d.childBody, 240),
    audience: { roles: roles.length ? roles : ["parents"], gradeMin, gradeMax, premium, topics,
                excludeOwners: aud.excludeOwners !== false },
    action: { type: actionType, packID },
    scheduledAt, status, showPopup: d.showPopup !== false,
  };
}

// Everyone the audience describes: parent tokens + child-device tokens, and
// the counts the admin page shows. One pass over the family data (like
// adminFamiliesOverview) — fine at our scale, and it runs once per campaign.
async function resolveAudience(audience) {
  const [hhSnap, kidsSnap, devsSnap, parentsSnap] = await Promise.all([
    db.collection("households").get(), db.collection("children").get(),
    db.collection("childDevices").get(), db.collection("parents").get(),
  ]);
  const now = Date.now() / 1000;
  const parents = {}; parentsSnap.forEach((p) => { parents[p.id] = p.data() || {}; });
  const kidsByHH = {}; kidsSnap.forEach((k) => { const d = k.data() || {}; (kidsByHH[d.householdID] = kidsByHH[d.householdID] || []).push({ id: k.id, ...d }); });
  const devsByKid = {}; devsSnap.forEach((dv) => { const d = dv.data() || {}; if (d.childID) (devsByKid[d.childID] = devsByKid[d.childID] || []).push(d); });
  const childTokenSet = new Set(); devsSnap.forEach((dv) => { const t = (dv.data() || {}).fcmToken; if (t) childTokenSet.add(t); });

  const wantParents = audience.roles.includes("parents"), wantChildren = audience.roles.includes("children");
  const parentTokens = new Set(), childTokens = new Set();
  let parentsN = 0, childrenN = 0, householdsN = 0;
  // Per-household detail for the delivery report ("למי נשלח"): token → who.
  const owners = {};   // token → { householdID, family, kind: "parent"|"child", who }
  const kidMatches = (k) => {
    const g = (k.grade === 0 || k.grade) ? Number(k.grade) : null;
    if (g != null && (g < audience.gradeMin || g > audience.gradeMax)) return false;
    if (audience.topics.length) {
      const interests = new Set([...(k.interests || []), ...Object.keys(k.difficultyByTopic || {}), ...(k.enabledTopics || [])]);
      if (!audience.topics.some((t) => interests.has(t))) return false;
    }
    return true;
  };
  hhSnap.forEach((h) => {
    const hh = h.data() || {};
    const premiumOn = Number(hh.premiumUntil || 0) > now;
    if (audience.premium === "with" && !premiumOn) return;
    if (audience.premium === "without" && premiumOn) return;
    const kids = (kidsByHH[h.id] || []).filter((k) => !k.deletedAt);
    if (audience.excludeOwners && audience.packID && kids.length && kids.every((k) => (k.packs || []).includes(audience.packID))) return;
    const matching = kids.filter(kidMatches);
    if (!matching.length && (audience.topics.length || audience.gradeMin > 0 || audience.gradeMax < 6)) return;
    householdsN += 1;
    const family = hh.familyName || hh.familyLabel || (kids.map((k) => k.name).filter(Boolean).join(", ") || h.id.slice(0, 8));
    if (wantParents) {
      for (const uid of hh.parentUIDs || []) {
        const p = parents[uid]; if (!p) continue;
        const toks = (p.fcmTokens || []).filter((t) => !childTokenSet.has(t));
        if (!toks.length) continue;
        parentsN += 1;
        toks.forEach((t) => { parentTokens.add(t); owners[t] = { householdID: h.id, family, kind: "parent", who: (hh.parentNames || {})[uid] || p.displayName || p.email || "הורה", uid }; });
      }
    }
    if (wantChildren) {
      for (const k of matching) {
        const toks = (devsByKid[k.id] || []).map((d) => d.fcmToken).filter(Boolean);
        if (!toks.length) continue;
        childrenN += 1;
        toks.forEach((t) => { childTokens.add(t); owners[t] = { householdID: h.id, family, kind: "child", who: k.name || "ילד" }; });
      }
    }
  });
  return { parentTokens: [...parentTokens], childTokens: [...childTokens], parentsN, childrenN, householdsN, owners };
}

function campaignPayload(c, forChild) {
  const title = forChild ? (c.childTitle || c.title) : c.title;
  const body = forChild ? (c.childBody || c.body) : c.body;
  const notification = { title: (c.emoji ? c.emoji + " " : "") + title, body };
  const data = { type: "campaign", campaignID: c.id, action: c.action.type, packID: c.action.packID || "", role: forChild ? "child" : "parent" };
  const apns = { payload: { aps: { sound: "default", "mutable-content": 1 } } };
  if (c.imageURL) { data.imageURL = c.imageURL; apns.fcmOptions = { imageURL: c.imageURL }; }
  return { notification, data, apns };
}

async function sendCampaignTo(tokens, c, forChild) {
  let sent = 0, failed = 0;
  const results = [];   // { token, ok, error }
  const payload = campaignPayload(c, forChild);
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    try {
      const res = await admin.messaging().sendEachForMulticast({ tokens: chunk, ...payload });
      sent += res.successCount; failed += res.failureCount;
      res.responses.forEach((r, j) => results.push({ token: chunk[j], ok: r.success, error: r.success ? "" : (r.error && r.error.code || "error") }));
    } catch (e) {
      console.error("[campaign] send failed", c.id, e && e.message); failed += chunk.length;
      chunk.forEach((t) => results.push({ token: t, ok: false, error: String(e && e.message || e) }));
    }
  }
  return { sent, failed, results };
}

// A token FCM says is dead ("not registered") belongs to a deleted install —
// drop it from the parents doc so the next count is honest.
async function pruneDeadTokens(results, owners) {
  const dead = results.filter((r) => !r.ok && /not-registered|invalid-registration|invalid-argument/.test(r.error));
  for (const r of dead) {
    const o = owners && owners[r.token];
    if (!o || !o.uid) continue;
    try {
      await db.collection("parents").doc(o.uid).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(r.token),
        childFcmTokens: admin.firestore.FieldValue.arrayRemove(r.token),
      });
    } catch (e) { /* best effort */ }
  }
  return dead.length;
}

// 🌍 World passes end after 30 days — 3 days before, the parents hear about
// it once ("המתמטיקה של נועה נגמרת ביום שלישי"), so the child never meets a
// closed world by surprise. Runs daily; dedup per child+pack+expiry.
exports.worldPassReminders = onSchedule(
  { schedule: "every day 17:30", timeZone: "Asia/Jerusalem", timeoutSeconds: 300, memory: "512MiB" },
  async () => {
    const now = Date.now() / 1000;
    const lo = now + 2 * 86400, hi = now + 3 * 86400 + 3600;
    const kids = await db.collection("children").get();
    const WORLD_HE = { math: "המתמטיקה 🧮", english: "האנגלית 🇬🇧", hebrew: "העברית ✍️", logic: "הלוגיקה 🧩", science: "המדעים 🔬",
                       history: "ההיסטוריה 🏛️", geography: "הגיאוגרפיה 🌍", money: "החינוך הפיננסי 💰", reading: "הבנת הנקרא 📖" };
    let sent = 0;
    for (const k of kids.docs) {
      const d = k.data() || {}; const exp = d.packExpiry || {};
      for (const [packID, at] of Object.entries(exp)) {
        if (!(Number(at) >= lo && Number(at) <= hi) || !WORLD_HE[packID]) continue;
        const key = `passend_${k.id}_${packID}_${Math.round(Number(at))}`;
        try { await db.collection("pushDedup").doc(key).create({ at: Date.now() }); } catch (e) { continue; }
        const tokens = await tokensForHousehold(d.householdID);
        if (!tokens.length) continue;
        const name = d.name || "הילד";
        const day = new Date(Number(at) * 1000).toLocaleDateString("he-IL", { weekday: "long", timeZone: "Asia/Jerusalem" });
        await send(tokens,
          { title: `${WORLD_HE[packID]} של ${name} ${d.gender === "girl" ? "נגמרת" : "נגמרת"} ב${day}`,
            body: `30 הימים מסתיימים. אפשר לפתוח עוד 30 יום, או טופי+ לכל המשפחה — מהטלפון שלכם. ההתקדמות נשמרת.` },
          { type: "pass-ending", childID: k.id, packID });
        sent += 1;
      }
    }
    console.log("[worldPassReminders] sent", sent);
  }
);

// 🧹📸 A chore photo the parent never approved/archived must not linger —
// privacy policy: deleted at approval, and after 7 days at most.
exports.pruneChorePhotos = onSchedule(
  { schedule: "every day 04:10", timeZone: "Asia/Jerusalem", timeoutSeconds: 300, memory: "512MiB" },
  async () => {
    const cutoff = Date.now() / 1000 - 7 * 86400;
    const snap = await db.collectionGroup("chores").where("markedDoneAt", "<=", cutoff).get();
    let pruned = 0;
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (!d.photoData && !d.photoToken) continue;
      await doc.ref.update({ photoData: admin.firestore.FieldValue.delete(), photoToken: admin.firestore.FieldValue.delete() });
      pruned += 1;
    }
    console.log("[pruneChorePhotos] pruned", pruned, "of", snap.size);
  }
);

exports.adminSaveCampaign = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data && request.data.id || "").trim();
  const c = cleanCampaign(request.data);
  if (!c.title) throw new HttpsError("invalid-argument", "title required");
  const ref = id ? db.collection("campaigns").doc(id) : db.collection("campaigns").doc();
  const existing = id ? await ref.get() : null;
  if (existing && existing.exists && ["sending", "sent"].includes(existing.data().status)) {
    throw new HttpsError("failed-precondition", "A sent campaign can't be edited.");
  }
  const base = existing && existing.exists ? {} : { createdAt: Date.now(), createdBy: email,
    stats: Object.fromEntries(CAMPAIGN_STAT_KEYS.map((k) => [k, 0])) };
  await ref.set({ ...base, ...c, updatedAt: Date.now(), updatedBy: email }, { merge: true });
  console.log("[adminSaveCampaign]", email, ref.id, c.status, c.title);
  return { ok: true, id: ref.id };
});

exports.adminCampaignEstimate = onCall({ timeoutSeconds: 120, memory: "512MiB" }, async (request) => {
  requireAdmin(request);
  const c = cleanCampaign(request.data);
  const r = await resolveAudience({ ...c.audience, packID: c.action.packID });
  return { parents: r.parentsN, children: r.childrenN, households: r.householdsN,
           parentTokens: r.parentTokens.length, childTokens: r.childTokens.length };
});

// The admin's OWN devices only (their parents doc) — never the real audience.
exports.adminSendCampaignTest = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const c = { ...cleanCampaign(request.data), id: "test" };
  const p = await db.collection("parents").doc(request.auth.uid).get();
  const d = p.exists ? p.data() : {};
  const parentToks = [...new Set(d.fcmTokens || [])];
  const childToks = [...new Set(d.childFcmTokens || [])];
  const wantP = c.audience.roles.includes("parents"), wantC = c.audience.roles.includes("children");
  const a = wantP ? await sendCampaignTo(parentToks, c, false) : { sent: 0, failed: 0, results: [] };
  const b = wantC ? await sendCampaignTo(childToks, c, true) : { sent: 0, failed: 0, results: [] };
  const owners = {}; parentToks.forEach((t) => owners[t] = { uid: request.auth.uid }); childToks.forEach((t) => owners[t] = { uid: request.auth.uid });
  const pruned = await pruneDeadTokens([...a.results, ...b.results], owners);
  const devices = [
    ...a.results.map((r, i) => ({ kind: "הורה", n: i + 1, ok: r.ok, error: r.error })),
    ...b.results.map((r, i) => ({ kind: "ילד", n: i + 1, ok: r.ok, error: r.error })),
  ];
  return { ok: true, sent: a.sent + b.sent, failed: a.failed + b.failed, targeted: devices.length,
           skippedParents: wantP ? 0 : parentToks.length, skippedChildren: wantC ? 0 : childToks.length, pruned, devices };
});

exports.adminListCampaigns = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const snap = await db.collection("campaigns").orderBy("scheduledAt", "desc").limit(100).get();
  return { campaigns: snap.docs.map((d) => ({ id: d.id, ...d.data() })) };
});

exports.adminCampaignDeliveries = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const id = String(request.data && request.data.id || "");
  if (!id) throw new HttpsError("invalid-argument", "id required");
  const snap = await db.collection("campaigns").doc(id).collection("deliveries").limit(500).get();
  return { deliveries: snap.docs.map((d) => ({ householdID: d.id, ...d.data() })) };
});

exports.adminDeleteCampaign = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data && request.data.id || "");
  if (!id) throw new HttpsError("invalid-argument", "id required");
  await db.collection("campaigns").doc(id).delete();
  console.log("[adminDeleteCampaign]", email, id);
  return { ok: true };
});

// ⚽ The launch switch for a question pack (packs/{id}.enabled).
exports.adminSetPackEnabled = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data && request.data.packID || "").trim();
  if (!/^[a-z0-9_-]{2,40}$/.test(id)) throw new HttpsError("invalid-argument", "packID");
  const enabled = !!(request.data && request.data.enabled);
  const ref = db.collection("packs").doc(id);
  const before = (await ref.get()).data() || {};
  await ref.set({ enabled, updatedAt: Date.now(), updatedBy: email,
    ...(enabled ? { launchedAt: admin.firestore.FieldValue.serverTimestamp() } : {}) }, { merge: true });
  // First switch-on → the launch push to every family, once (re-toggling never re-sends).
  let campaignID = before.launchCampaignID || null;
  if (enabled && !campaignID) {
    const c = launchCampaignFor(id);
    if (c) {
      const cref = db.collection("campaigns").doc();
      await cref.set({ ...c, scheduledAt: Date.now(), status: "scheduled", source: "launch", packID: id,
        createdAt: Date.now(), createdBy: email, updatedAt: Date.now(), updatedBy: email,
        stats: Object.fromEntries(CAMPAIGN_STAT_KEYS.map((k) => [k, 0])) });
      campaignID = cref.id;
      await ref.set({ launchCampaignID: campaignID }, { merge: true });
    }
  }
  console.log("[adminSetPackEnabled]", email, id, enabled, campaignID || "(no launch push)");
  return { ok: true, campaignID, launched: enabled && !before.launchCampaignID && !!campaignID };
});

exports.adminListPacks = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const snap = await db.collection("packs").get();
  const sales = await db.collection("packPurchases").get();
  const byPack = {};
  sales.forEach((s) => { const d = s.data() || {}; const b = byPack[d.packID] = byPack[d.packID] || { purchases: 0, children: 0, revenue: 0 };
    b.purchases += 1; b.children += (d.childIDs || []).length; b.revenue += Number(d.price || 0); });
  return { packs: Object.fromEntries(snap.docs.map((d) => [d.id, d.data()])), sales: byPack };
});

// Every 5 minutes: deliver campaigns whose time has come. Claims the doc
// (scheduled → sending) in a transaction so two runs can never double-send.
exports.dispatchCampaigns = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Jerusalem", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const due = await db.collection("campaigns").where("status", "==", "scheduled")
      .where("scheduledAt", "<=", Date.now()).get();
    for (const doc of due.docs) {
      const claimed = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists || fresh.data().status !== "scheduled") return false;
        tx.update(doc.ref, { status: "sending", sendingAt: Date.now() });
        return true;
      });
      if (!claimed) continue;
      const c = { id: doc.id, ...doc.data() };
      try {
        const aud = await resolveAudience({ ...c.audience, packID: (c.action || {}).packID });
        const a = c.audience.roles.includes("parents") ? await sendCampaignTo(aud.parentTokens, c, false) : { sent: 0, failed: 0, results: [] };
        const b = c.audience.roles.includes("children") ? await sendCampaignTo(aud.childTokens, c, true) : { sent: 0, failed: 0, results: [] };
        const results = [...a.results, ...b.results];
        await pruneDeadTokens(results, aud.owners);
        // "למי נשלח" — one row per household: who got it, who didn't.
        const byHH = {};
        for (const r of results) {
          const o = aud.owners[r.token]; if (!o) continue;
          const row = byHH[o.householdID] = byHH[o.householdID] || { family: o.family, parentsOK: 0, parentsFailed: 0, childrenOK: 0, childrenFailed: 0, who: [] };
          if (o.kind === "parent") { r.ok ? row.parentsOK++ : row.parentsFailed++; } else { r.ok ? row.childrenOK++ : row.childrenFailed++; }
          row.who.push(`${o.kind === "parent" ? "👤" : "🧒"} ${o.who}${r.ok ? " ✓" : " ✗"}`);
        }
        let batch = db.batch(), n = 0;
        for (const [hid, row] of Object.entries(byHH)) {
          batch.set(doc.ref.collection("deliveries").doc(hid), { ...row, who: [...new Set(row.who)].slice(0, 12), at: Date.now() });
          if (++n % 400 === 0) { await batch.commit(); batch = db.batch(); }
        }
        if (n % 400) await batch.commit();
        await doc.ref.update({
          status: "sent", sentAt: Date.now(),
          "stats.targeted": aud.parentsN + aud.childrenN,
          "stats.sent": a.sent + b.sent, "stats.failed": a.failed + b.failed,
          reach: { parents: aud.parentsN, children: aud.childrenN, households: aud.householdsN },
        });
        console.log("[dispatchCampaigns]", c.id, c.title, "sent", a.sent + b.sent, "failed", a.failed + b.failed);
      } catch (e) {
        console.error("[dispatchCampaigns] failed", c.id, e && e.message);
        await doc.ref.update({ status: "failed", error: String(e && e.message || e) });
      }
    }
  }
);

// ============================================================================
// 🛠 Admin app (docs/admin/app.html) — journey, overview, activity, content,
// support, config. Everything first-party from Firestore; precomputed hourly
// into adminStats/journey so the panels open instantly.
// ============================================================================

const CONVERSION_DEFAULTS = {
  activationDays: 3, activationQuestions: 40, giftDays: 14,
  guestWorlds: 2, guestRotateDays: 7, lockedShown: 3, lockedRotateDays: 3,
  giftPushDays: [4, 9, 12, 13, 14], giftPushHour: 17,
  oneTimeAfterGiftOnly: true, paywall: "personal", storeKitTrial: false,
  guestTopics: ["math", "reading"],
  copyActivation: "🎁 פתחנו ל{שם} את טופי+ במתנה · {שם} עבר/ה {שאלות} שאלות, אז ל־{ימים} הימים הקרובים כל העולמות פתוחים. בלי כרטיס, לא מתחדש. מסתיים ב־{תאריך}.",
  copyTwoDays: "⏰ נשארו יומיים לטופי+ של {שם} · {עולם אהוב}: {חזרות} חזרות השבוע. השאירו את כל העולמות פתוחים, {מחיר חודשי בשנתי} לחודש.",
};
async function conversionConfig() {
  const d = await db.collection("config").doc("conversion").get();
  return { ...CONVERSION_DEFAULTS, ...(d.exists ? d.data() : {}) };
}

const TOPIC_LABEL = { math: "🧮 מתמטיקה", english: "🇬🇧 אנגלית", hebrew: "✍️ עברית", logic: "🧩 לוגיקה", science: "🔬 מדעים", history: "🏛️ היסטוריה",
  geography: "🌍 גיאוגרפיה", money: "💰 חינוך פיננסי", reading: "📖 הבנת הנקרא", soccer: "⚽ כדורגל", dinosaurs: "🦖 דינוזאורים", space: "🚀 חלל", animals: "🐾 חיות",
  sea: "🌊 ים", gifted: "🧠 מחוננים", food: "🍳 מטבח", israel: "🏛️ ישראל שלי", music: "🎵 מוזיקה", body: "🧍 גוף האדם", vehicles: "🚗 כלי רכב", flags: "🌍 דגלים" };

// The whole family journey from raw data. Runs hourly (and on demand).
async function computeJourney() {
  const cfg = await conversionConfig();
  const nowMs = Date.now(), nowS = nowMs / 1000;
  const dayKey = (d) => { const x = new Date(d); return `${x.getUTCFullYear()}-${String(x.getUTCMonth() + 1).padStart(2, "0")}-${String(x.getUTCDate()).padStart(2, "0")}`; };
  // Day keys in Israel time (the app writes dayKey in device-local time; close enough).
  const il = (ms) => dayKey(ms + 3 * 3600 * 1000);
  const todayKey = il(nowMs);
  const last14 = Array.from({ length: 14 }, (_, i) => il(nowMs - (13 - i) * 86400000));
  const [hhSnap, kidsSnap, devSnap, parentsSnap, salesSnap, reportsSnap, feedbackSnap] = await Promise.all([
    db.collection("households").get(), db.collection("children").get(), db.collection("childDevices").get(),
    db.collection("parents").get(), db.collection("packPurchases").get(),
    db.collection("questionReports").where("status", "!=", "resolved").get().catch(() => ({ size: 0 })),
    db.collection("parentFeedback").get().catch(() => ({ size: 0 })),
  ]);
  const parents = {}; parentsSnap.forEach((p) => { parents[p.id] = p.data() || {}; });
  const kids = kidsSnap.docs.filter((k) => !(k.data() || {}).deletedAt);
  // dailyStats per child (≤ 30 docs each), in chunks
  const perChild = {};
  const CHUNK = 20;
  for (let i = 0; i < kids.length; i += CHUNK) {
    const slice = kids.slice(i, i + CHUNK);
    const snaps = await Promise.all(slice.map((k) => k.ref.collection("dailyStats").get().catch(() => ({ docs: [] }))));
    snaps.forEach((snap, j) => {
      const k = slice[j], d = k.data() || {};
      const days = snap.docs.map((x) => x.data() || {}).filter((x) => x.date);
      const cut30 = il(nowMs - 30 * 86400000);
      const recent = days.filter((x) => x.date >= cut30);
      const activeDays = recent.filter((x) => (x.questionsAnswered || 0) > 0);
      const questions30 = recent.reduce((s, x) => s + (x.questionsAnswered || 0), 0);
      const today = days.find((x) => x.date === todayKey) || {};
      const topicTotals = {};
      for (const x of recent) for (const [t, v] of Object.entries(x.perTopic || {})) { topicTotals[t] = topicTotals[t] || { q: 0, c: 0, days: 0 }; topicTotals[t].q += v.answered || 0; topicTotals[t].c += v.correct || 0; topicTotals[t].days += 1; }
      const fav = Object.entries(topicTotals).sort((a, b) => b[1].q - a[1].q)[0];
      const everQ = days.reduce((s, x) => s + (x.questionsAnswered || 0), 0);
      const everDays = days.filter((x) => (x.questionsAnswered || 0) > 0).length;
      perChild[k.id] = {
        name: d.name || "", householdID: d.householdID, grade: (d.grade === 0 || d.grade) ? d.grade : null, gender: d.gender || null,
        activeDays30: activeDays.length, questions30, everQuestions: everQ, everActiveDays: everDays,
        lastActive: activeDays.map((x) => x.date).sort().slice(-1)[0] || null,
        today: { questions: today.questionsAnswered || 0, correct: today.correct || 0, minutesEarned: today.minutesEarned || 0, minutesUsed: today.minutesUsed || 0 },
        series14: last14.map((dk) => { const x = days.find((y) => y.date === dk); return x && (x.questionsAnswered || 0) > 0 ? 1 : 0; }),
        activated: everDays >= cfg.activationDays && everQ >= cfg.activationQuestions,
        favorite: fav ? { topic: fav[0], label: TOPIC_LABEL[fav[0]] || fav[0], questions: fav[1].q, days: fav[1].days, accuracy: fav[1].q ? Math.round(100 * fav[1].c / fav[1].q) : 0 } : null,
        topicsToday: Object.fromEntries(Object.entries(today.perTopic || {}).map(([t, v]) => [t, { q: v.answered || 0, c: v.correct || 0 }])),
        packs: d.packs || [], packExpiry: d.packExpiry || {},
      };
    });
  }
  // households → journey state
  const households = {};
  const funnel = { registered: 0, childPlayed: 0, activated: 0, gift: 0, valued: 0, paywall: 0, purchaseStarted: 0, purchased: 0, renewed: 0 };
  const states = { free_new: 0, free_activated: 0, gift: 0, gift_expiring: 0, plus: 0, returned: 0, inactive: 0 };
  let mrr = 0, monthlyN = 0, yearlyN = 0, premiumN = 0;
  hhSnap.forEach((h) => {
    const hh = h.data() || {};
    const kidsOf = Object.entries(perChild).filter(([, c]) => c.householdID === h.id).map(([id, c]) => ({ id, ...c }));
    const realParent = (hh.parentUIDs || []).some((u) => parents[u] && (parents[u].email || parents[u].displayName));
    const played = kidsOf.some((c) => c.everQuestions > 0);
    const activated = kidsOf.some((c) => c.activated);
    const premiumUntil = Number(hh.premiumUntil || 0);
    const premium = premiumUntil > nowS;
    const gift = premium && hh.premiumSource === "gift";
    const daysLeft = premium ? Math.ceil((premiumUntil - nowS) / 86400) : 0;
    const lastActive = kidsOf.map((c) => c.lastActive).filter(Boolean).sort().slice(-1)[0] || null;
    const inactive = !lastActive || lastActive < il(nowMs - 14 * 86400000);
    let state = "free_new";
    if (premium && gift) state = daysLeft <= 3 ? "gift_expiring" : "gift";
    else if (premium) state = "plus";
    else if (hh.giftEndedAt) state = "returned";
    else if (activated) state = "free_activated";
    if (!premium && inactive && played) state = "inactive";
    states[state] += 1;
    if (realParent || played) funnel.registered += 1;
    if (played) funnel.childPlayed += 1;
    if (activated) funnel.activated += 1;
    if (gift || hh.giftEndedAt || hh.giftStartedAt) funnel.gift += 1;
    if (kidsOf.some((c) => c.questions30 >= 20 && c.activeDays30 >= 2)) funnel.valued += 1;
    if (hh.paywallViews) funnel.paywall += 1;
    if (hh.purchaseStarted) funnel.purchaseStarted += 1;
    if (premium && !gift) { funnel.purchased += 1; premiumN += 1; if (daysLeft > 60) { yearlyN += 1; mrr += 199 / 12; } else { monthlyN += 1; mrr += 24.9; } }
    if (hh.renewedAt) funnel.renewed += 1;
    households[h.id] = { state, premium, gift, daysLeft, premiumUntil, activated, played, lastActive, familyName: hh.familyName || hh.familyLabel || null,
      plan: premium && !gift ? (daysLeft > 60 ? "yearly" : "monthly") : null, purchaseSource: hh.purchaseSource || null, kids: kidsOf.map((c) => c.id) };
  });
  // today + series
  const childrenToday = Object.values(perChild).filter((c) => c.today.questions > 0).length;
  const questionsToday = Object.values(perChild).reduce((s, c) => s + c.today.questions, 0);
  const correctToday = Object.values(perChild).reduce((s, c) => s + c.today.correct, 0);
  const minutesToday = Object.values(perChild).reduce((s, c) => s + c.today.minutesEarned, 0);
  const activeSeries = last14.map((_, i) => Object.values(perChild).filter((c) => c.series14[i]).length);
  const worldsToday = {};
  for (const c of Object.values(perChild)) for (const [t, v] of Object.entries(c.topicsToday)) { worldsToday[t] = worldsToday[t] || { q: 0, c: 0, kids: 0 }; worldsToday[t].q += v.q; worldsToday[t].c += v.c; if (v.q) worldsToday[t].kids += 1; }
  const active30 = Object.values(households).filter((h) => h.lastActive && h.lastActive >= il(nowMs - 30 * 86400000)).length;
  const sales = salesSnap.docs.map((s) => s.data() || {});
  const packRevenue = sales.reduce((s, x) => s + Number(x.price || 0), 0);
  const journey = {
    computedAt: nowMs, config: cfg,
    overview: { activeFamilies30: active30, childrenToday, questionsToday, accuracyToday: questionsToday ? Math.round(100 * correctToday / questionsToday) : 0,
      minutesToday, mrr: Math.round(mrr), premiumFamilies: premiumN, yearlyShare: premiumN ? Math.round(100 * yearlyN / premiumN) : 0,
      activatedToPaid30: funnel.activated ? Math.round(1000 * funnel.purchased / funnel.activated) / 10 : 0,
      openReports: reportsSnap.size || 0, feedbackCount: feedbackSnap.size || 0, packSales: sales.length, packRevenue: Math.round(packRevenue),
      activeSeries, activeSeriesDays: last14, worldsToday: Object.entries(worldsToday).map(([t, v]) => ({ topic: t, label: TOPIC_LABEL[t] || t, ...v, accuracy: v.q ? Math.round(100 * v.c / v.q) : 0 })).sort((a, b) => b.q - a.q).slice(0, 8) },
    states, funnel, households, children: perChild,
  };
  // Firestore document limit is 1 MB — keep children compact if the roster grows.
  await db.collection("adminStats").doc("journey").set(journey);
  return journey;
}

exports.refreshJourney = onSchedule({ schedule: "every 60 minutes", timeZone: "Asia/Jerusalem", timeoutSeconds: 540, memory: "1GiB" }, async () => { await computeJourney(); });

exports.adminJourney = onCall({ timeoutSeconds: 300, memory: "1GiB" }, async (request) => {
  requireAdmin(request);
  if (request.data && request.data.recompute) return await computeJourney();
  const d = await db.collection("adminStats").doc("journey").get();
  return d.exists ? d.data() : await computeJourney();
});

// Recent things worth a glance on the dashboard.
exports.adminActivity = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const items = [];
  const push = (at, kind, text, ref) => { if (at) items.push({ at, kind, text, ref: ref || null }); };
  const [sales, camps, reports, feedback, chores] = await Promise.all([
    db.collection("packPurchases").orderBy("at", "desc").limit(15).get().catch(() => ({ docs: [] })),
    db.collection("campaigns").where("status", "==", "sent").orderBy("sentAt", "desc").limit(10).get().catch(() => ({ docs: [] })),
    db.collection("questionReports").orderBy("createdAt", "desc").limit(10).get().catch(() => ({ docs: [] })),
    db.collection("parentFeedback").orderBy("createdAt", "desc").limit(10).get().catch(() => ({ docs: [] })),
    db.collectionGroup("chores").where("markedDoneAt", ">", Date.now() / 1000 - 86400).limit(10).get().catch(() => ({ docs: [] })),
  ]);
  const hhName = async (id) => { if (!id) return "משפחה"; const h = await db.collection("households").doc(id).get(); const d = h.exists ? h.data() : {}; return d.familyName || d.familyLabel || "משפחה " + String(id).slice(0, 4); };
  for (const s of sales.docs) { const d = s.data(); push(Number(d.at) * 1000, "sale", `💎 ${await hhName(d.householdID)} רכשה ${PACK_META[d.packID]?.emoji || ""} ${PACK_META[d.packID]?.name || d.packID}${d.campaignID ? " · מקור: הודעה" : ""}`, { householdID: d.householdID }); }
  for (const c of camps.docs) { const d = c.data(); push(d.sentAt, "campaign", `📣 נשלחה הודעה "${d.emoji ? d.emoji + " " : ""}${d.title}" ל־${d.stats?.sent || 0} מכשירים`); }
  for (const r of reports.docs) { const d = r.data(); push(Number(d.createdAt) * (Number(d.createdAt) > 1e12 ? 1 : 1000), "report", `🚩 דיווח על שאלה: "${String(d.prompt || d.question || "").replace(/\n/g, " ").slice(0, 60)}" · ${TOPIC_LABEL[d.topic] || d.topic || ""}`); }
  for (const f of feedback.docs) { const d = f.data(); push(Number(d.createdAt) * (Number(d.createdAt) > 1e12 ? 1 : 1000), "feedback", `💬 פידבק מהורה: "${String(d.message || "").slice(0, 80)}"`); }
  for (const ch of chores.docs) { const d = ch.data(); push(Number(d.markedDoneAt) * 1000, "chore", `🧹${d.photoToken ? "📸" : ""} מטלה "${d.title || ""}" סומנה כבוצעה · ממתינה לאישור`); }
  items.sort((a, b) => b.at - a.at);
  return { items: items.slice(0, 30) };
});

exports.adminListReports = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const snap = await db.collection("questionReports").orderBy("createdAt", "desc").limit(200).get().catch(() => ({ docs: [] }));
  return { reports: snap.docs.map((d) => ({ id: d.id, ...d.data() })) };
});
exports.adminSetReportStatus = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data?.id || ""), status = String(request.data?.status || "");
  if (!id || !["open", "resolved", "disabled"].includes(status)) throw new HttpsError("invalid-argument", "id/status");
  await db.collection("questionReports").doc(id).set({ status, resolvedBy: email, resolvedAt: Date.now() }, { merge: true });
  return { ok: true };
});

exports.adminListSupport = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  requireAdmin(request);
  const [fb, wl] = await Promise.all([
    db.collection("parentFeedback").orderBy("createdAt", "desc").limit(100).get().catch(() => ({ docs: [] })),
    db.collection("waitlist").get().catch(() => ({ size: 0 })),
  ]);
  const items = [];
  for (const d of fb.docs) { const x = d.data(); let family = null; if (x.householdID) { const h = await db.collection("households").doc(x.householdID).get(); family = h.exists ? (h.data().familyName || h.data().familyLabel || null) : null; }
    items.push({ id: d.id, kind: "feedback", at: Number(x.createdAt) * (Number(x.createdAt) > 1e12 ? 1 : 1000), family, householdID: x.householdID || null, text: x.message || "", device: x.appVersion || "", status: x.status || "open" }); }
  return { items, waitlist: wl.size || 0 };
});
exports.adminSetSupportStatus = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data?.id || ""), status = String(request.data?.status || "open");
  await db.collection("parentFeedback").doc(id).set({ status, handledBy: email, handledAt: Date.now() }, { merge: true });
  return { ok: true };
});

exports.adminGetConfig = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => { requireAdmin(request); return { config: await conversionConfig(), defaults: CONVERSION_DEFAULTS }; });
exports.adminSetConfig = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const patch = request.data && request.data.config || {};
  const allowed = Object.keys(CONVERSION_DEFAULTS);
  const clean = {}; for (const k of allowed) if (patch[k] !== undefined) clean[k] = patch[k];
  await db.collection("config").doc("conversion").set({ ...clean, updatedAt: Date.now(), updatedBy: email }, { merge: true });
  return { ok: true, config: await conversionConfig() };
});

// Pack meta from the worlds panel: proofread flag, scheduled launch.
exports.adminSetPackMeta = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const id = String(request.data?.packID || "");
  if (!/^[a-z0-9_-]{2,40}$/.test(id)) throw new HttpsError("invalid-argument", "packID");
  const patch = {};
  if (request.data.reviewed !== undefined) patch.reviewed = !!request.data.reviewed;
  if (request.data.launchAt !== undefined) patch.launchAt = request.data.launchAt ? Number(request.data.launchAt) : admin.firestore.FieldValue.delete();
  await db.collection("packs").doc(id).set({ ...patch, updatedAt: Date.now(), updatedBy: email }, { merge: true });
  return { ok: true };
});
// A scheduled launch fires the same path as the manual switch.
exports.launchScheduledPacks = onSchedule({ schedule: "every 15 minutes", timeZone: "Asia/Jerusalem", timeoutSeconds: 120, memory: "256MiB" }, async () => {
  const snap = await db.collection("packs").where("launchAt", "<=", Date.now()).get();
  for (const d of snap.docs) {
    const p = d.data() || {}; if (p.enabled) { await d.ref.update({ launchAt: admin.firestore.FieldValue.delete() }); continue; }
    await d.ref.set({ enabled: true, launchedAt: admin.firestore.FieldValue.serverTimestamp(), launchAt: admin.firestore.FieldValue.delete() }, { merge: true });
    if (!p.launchCampaignID) { const c = launchCampaignFor(d.id); if (c) { const cref = db.collection("campaigns").doc();
      await cref.set({ ...c, scheduledAt: Date.now(), status: "scheduled", source: "launch", packID: d.id, createdAt: Date.now(), createdBy: "scheduler", stats: Object.fromEntries(CAMPAIGN_STAT_KEYS.map((k) => [k, 0])) });
      await d.ref.set({ launchCampaignID: cref.id }, { merge: true }); } }
    console.log("[launchScheduledPacks] launched", d.id);
  }
});

// 🎁 Give / extend Tofy+ to one family from the admin (marked as a gift).
exports.adminGiftHousehold = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const email = requireAdmin(request);
  const hhID = String(request.data?.householdID || ""); const days = Math.max(1, Math.min(365, Number(request.data?.days || 14)));
  if (!/^[0-9A-Fa-f-]{36}$/.test(hhID)) throw new HttpsError("invalid-argument", "householdID");
  const ref = db.collection("households").doc(hhID); const h = await ref.get(); if (!h.exists) throw new HttpsError("not-found", "household");
  const now = Date.now() / 1000; const base = Math.max(Number(h.data().premiumUntil || 0), now);
  const until = base + days * 86400;
  await ref.set({ premiumUntil: until, premiumSource: "gift", giftStartedAt: h.data().giftStartedAt || now, giftBy: email }, { merge: true });
  console.log("[adminGiftHousehold]", email, hhID, "+", days, "days");
  return { ok: true, premiumUntil: until };
});

// ============================================================================
// 🎁 Conversion engine (server only — no app change needed)
// Free → activated → gift → expiring → paid / returned. Runs hourly from the
// precomputed journey; pushes go to PARENTS only; every step is deduped.
// ============================================================================

function fill(tpl, vars) { return String(tpl || "").replace(/\{([^}]+)\}/g, (m, k) => (vars[k] !== undefined && vars[k] !== null ? String(vars[k]) : m)); }
const ilDate = (s) => new Date(s * 1000).toLocaleDateString("he-IL", { day: "numeric", month: "numeric", timeZone: "Asia/Jerusalem" });
const ilWeekday = (s) => new Date(s * 1000).toLocaleDateString("he-IL", { weekday: "long", timeZone: "Asia/Jerusalem" });

async function onceKey(key) { try { await db.collection("pushDedup").doc(key).create({ at: Date.now() }); return true; } catch (e) { return false; } }

async function runConversionEngine() {
  const cfg = await conversionConfig();
  const jdoc = await db.collection("adminStats").doc("journey").get();
  const journey = jdoc.exists ? jdoc.data() : await computeJourney();
  const now = Date.now() / 1000;
  const hour = Number(new Date().toLocaleString("en-US", { hour: "numeric", hour12: false, timeZone: "Asia/Jerusalem" }));
  let gifted = 0, pushed = 0, ended = 0;
  for (const [hhID, h] of Object.entries(journey.households || {})) {
    const ref = db.collection("households").doc(hhID);
    const snap = await ref.get(); if (!snap.exists) continue;
    const hh = snap.data() || {};
    const premiumUntil = Number(hh.premiumUntil || 0);
    const kids = (h.kids || []).map((id) => ({ id, ...(journey.children[id] || {}) }));
    const star = kids.filter((k) => k.everQuestions > 0).sort((a, b) => b.questions30 - a.questions30)[0];
    const name = star ? star.name : "הילד"; const girl = star && star.gender === "girl";
    const totalQ = kids.reduce((s, k) => s + (k.questions30 || 0), 0);
    const fav = star && star.favorite;
    const vars = { "שם": name, "שאלות": totalQ, "ימים": cfg.giftDays, "עולם אהוב": fav ? fav.label : "העולם האהוב", "חזרות": fav ? fav.days : 0, "מחיר חודשי בשנתי": "₪16.60" };
    // 1. activation → gift (only families that never had a gift and are not paying)
    if (h.activated && premiumUntil <= now && !hh.giftStartedAt && !hh.giftEndedAt) {
      const until = now + cfg.giftDays * 86400;
      await ref.set({ premiumUntil: until, premiumSource: "gift", giftStartedAt: now, giftDays: cfg.giftDays }, { merge: true });
      gifted += 1;
      if (await onceKey(`gift_start_${hhID}`)) {
        const tokens = await tokensForHousehold(hhID);
        if (tokens.length) { await send(tokens, { title: `🎁 פתחנו ל${name} את טופי+ במתנה`, body: fill(cfg.copyActivation, { ...vars, "תאריך": ilDate(until) }).replace(/^🎁[^·]*·\s*/, "") }, { type: "gift-start", householdID: hhID }); pushed += 1; }
      }
      continue;
    }
    // 2. during a gift: the day-based pushes (parents only), at the configured hour
    if (hh.premiumSource === "gift" && premiumUntil > now && hh.giftStartedAt && hour === Number(cfg.giftPushHour || 17)) {
      const day = Math.floor((now - Number(hh.giftStartedAt)) / 86400) + 1;
      const daysLeft = Math.ceil((premiumUntil - now) / 86400);
      if ((cfg.giftPushDays || []).includes(day) && await onceKey(`gift_day${day}_${hhID}`)) {
        let msg = null;
        if (daysLeft <= 1) msg = { title: `היום מסתיימת מתנת טופי+ של ${name}`, body: `${name} ${girl ? "תמשיך" : "ימשיך"} ללמוד ולהרוויח זמן בחינם כרגיל. כדי להשאיר את ${fav ? fav.label.replace(/^\S+\s/, "") + " ו" : ""}שאר העולמות פתוחים: המשיכו עם טופי+.` };
        else if (daysLeft <= 2) msg = { title: `⏰ נשארו יומיים לטופי+ של ${name}`, body: fill(cfg.copyTwoDays, vars).replace(/^⏰[^·]*·\s*/, "") };
        else if (day <= 5) msg = fav ? { title: `❤️ נראה ש${name} ${girl ? "מצאה" : "מצא"} משהו ש${girl ? "היא אוהבת" : "הוא אוהב"}`, body: `${fav.label} הוא המקום ש${girl ? "היא חוזרת" : "הוא חוזר"} אליו הכי הרבה בטופי: ${fav.days} ימים, ${fav.questions} שאלות.` } : null;
        else msg = { title: `${name} ${girl ? "גילתה" : "גילה"} ${kids.reduce((s, k) => s + Object.keys(k.topicsToday || {}).length, 0) || "כמה"} עולמות 🌎`, body: `${totalQ} שאלות בחודש האחרון${fav ? " · האהוב: " + fav.label : ""}. המתנה מסתיימת ב${ilWeekday(premiumUntil)}. השאירו את כל העולמות פתוחים.` };
        if (msg) { const tokens = await tokensForHousehold(hhID); if (tokens.length) { await send(tokens, msg, { type: "gift-day", householdID: hhID, day: String(day) }); pushed += 1; } }
      }
    }
    // 3. gift ended without a purchase → back to free (the app sees premiumUntil in the past)
    if (hh.premiumSource === "gift" && premiumUntil <= now && hh.giftStartedAt && !hh.giftEndedAt) {
      await ref.set({ giftEndedAt: now }, { merge: true }); ended += 1;
    }
  }
  console.log("[conversionEngine] gifted", gifted, "pushed", pushed, "ended", ended);
  return { gifted, pushed, ended };
}
exports.conversionEngine = onSchedule({ schedule: "every 60 minutes", timeZone: "Asia/Jerusalem", timeoutSeconds: 540, memory: "1GiB" }, async () => { await computeJourney(); await runConversionEngine(); });
exports.adminRunConversionEngine = onCall({ timeoutSeconds: 300, memory: "1GiB" }, async (request) => { requireAdmin(request); await computeJourney(); return await runConversionEngine(); });

// A real purchase lands as a NEW premiumUntil written by the parent's device
// (publishPremium). If the family was on a gift, that write is the conversion:
// mark it paid, remember when and from where.
exports.onHouseholdPremiumWritten = onDocumentWritten("households/{hid}", async (event) => {
  const before = event.data.before && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after && event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const b = Number(before && before.premiumUntil || 0), a = Number(after.premiumUntil || 0);
  if (a <= b) return;                                       // not a new/longer entitlement
  const now = Date.now() / 1000;
  const giftEnd = Number(after.giftStartedAt || 0) + Number(after.giftDays || 14) * 86400;
  const wasGift = after.premiumSource === "gift";
  // A gift grant itself is written by the engine (source gift) — skip it; a paid
  // entitlement extends well beyond the gift window (≥ 25 days from now).
  if (wasGift && a <= giftEnd + 86400) return;
  if (a < now + 25 * 86400) return;
  if (after.premiumSource === "paid" && after.purchasedAt) return;
  await event.data.after.ref.set({ premiumSource: "paid", purchasedAt: now, purchaseSource: after.lastPaywallSource || (after.packRequestedFlag ? "child_request" : "card"),
    ...(wasGift ? { giftConvertedAt: now } : {}) }, { merge: true });
  console.log("[premium] paid conversion", event.params.hid, wasGift ? "from gift" : "direct");
});
