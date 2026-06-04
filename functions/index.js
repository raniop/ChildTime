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
    case "assistRequest":return { title: "בקשת עזרה 💌", body: `${name} ${g("ביקש", "ביקשה")} את עזרתכם בשאלה${dev}.` };
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

// ---- 1c) Parent quick-help -------------------------------------------------
// A child asked a specific parent for help on a question. Push that parent an
// interactive notification (category PARENT_HELP) whose two buttons are the
// answer options — rendered with real text by the HelpContentExtension. The
// parent's tap is handled in the app (background) and written back to the doc.

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
    const lines = [
      `דווח על שאלה לא טובה:`,
      ``,
      `שאלה: ${r.prompt || "(ריק)"}`,
      `תשובה נכונה: ${r.correctAnswer || "-"}`,
      `נושא: ${r.topic || "-"}`,
      `סיבה: ${r.reason || "(לא צוינה)"}`,
      ``,
      `— דווח ע"י (uid): ${r.reportedBy || "anonymous"}`,
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
const { onRequest } = require("firebase-functions/v2/https");
const ADMIN_TASK_TOKEN = defineSecret("ADMIN_TASK_TOKEN");
const DAY = 24 * 3600;

async function computeAdminStats() {
  const now = Date.now() / 1000;
  const cut30 = now - 30 * DAY, cut7 = now - 7 * DAY, cut1 = now - 1 * DAY;

  // Fetch the core collections (tens of docs) so we can drop internal/test
  // accounts before counting.
  const [parentsSnap, householdsSnap, childrenSnap, devicesSnap] = await Promise.all([
    db.collection("parents").get(),
    db.collection("households").get(),
    db.collection("children").get(),
    db.collection("childDevices").get(),
  ]);

  // Pull events per child. A child with ZERO events ever is an empty seeded/demo
  // profile and is dropped — "real" = ever actually played. Family/founder
  // accounts are intentionally KEPT: their usage is real data.
  const events = [];                 // last-30-day events of real children (metrics)
  const realChildIDs = [];
  const realHouseholds = new Set();
  const CHUNK = 25;
  for (let i = 0; i < childrenSnap.docs.length; i += CHUNK) {
    const slice = childrenSnap.docs.slice(i, i + CHUNK);
    const snaps = await Promise.all(slice.map((c) =>
      c.ref.collection("events").get().catch(() => ({ docs: [] }))));
    snaps.forEach((snap, k) => {
      if (snap.docs.length === 0) return;            // empty seed/demo profile → skip
      const c = slice[k];
      realChildIDs.push(c.id);
      realHouseholds.add(c.data().householdID);
      snap.docs.forEach((doc) => {
        const e = doc.data();
        const createdAt = Number(e.createdAt) || 0;
        if (createdAt < cut30) return;               // keep only last 30d for metrics
        events.push({
          childID: c.id, type: e.type, createdAt,
          accuracy: Number(e.accuracy) || 0, minutes: Number(e.minutes) || 0,
          stars: Number(e.stars) || 0, questions: Number(e.questions) || 0,
          topic: (e.topic || "").trim(),
        });
      });
    });
  }

  // Totals derived from real (active-ever) households only.
  const realParentUIDs = new Set();
  householdsSnap.docs.forEach((h) => {
    if (realHouseholds.has(h.id)) (h.data().parentUIDs || []).forEach((u) => realParentUIDs.add(u));
  });
  const totals = {
    parents: realParentUIDs.size,
    children: realChildIDs.length,
    households: realHouseholds.size,
    devices: devicesSnap.docs.filter((d) => realHouseholds.has(d.data().householdID)).length,
  };
  const excluded = {
    children: childrenSnap.size - realChildIDs.length,   // empty/demo profiles dropped
    parents: parentsSnap.size - realParentUIDs.size,
  };

  const uniq = (arr) => new Set(arr).size;
  const ends = events.filter((e) => e.type === "sessionEnd");   // completed rounds
  const ends7 = ends.filter((e) => e.createdAt >= cut7);
  const ends1 = ends.filter((e) => e.createdAt >= cut1);
  const accSamples = ends7.filter((e) => e.questions > 0);

  const active = {
    dau: uniq(events.filter((e) => e.createdAt >= cut1).map((e) => e.childID)),
    wau: uniq(events.filter((e) => e.createdAt >= cut7).map((e) => e.childID)),
    mau: uniq(events.map((e) => e.childID)),
  };
  const engagement = { sessionsToday: ends1.length, sessions7d: ends7.length, totalSessions: ends.length };
  const learning = {
    questions7d: ends7.reduce((s, e) => s + e.questions, 0),
    avgAccuracy: accSamples.length ? accSamples.reduce((s, e) => s + e.accuracy, 0) / accSamples.length / 100 : 0,
    minutes7d: ends7.reduce((s, e) => s + e.minutes, 0),
    stars7d: ends7.reduce((s, e) => s + e.stars, 0),
  };

  // Daily series (oldest → newest), keyed by local day bucket.
  const dayKey = (ts) => Math.floor(ts / DAY);
  const todayKey = dayKey(now);
  const daily = [];
  for (let d = 29; d >= 0; d--) {
    const k = todayKey - d;
    const dt = new Date(k * DAY * 1000);
    daily.push({
      date: `${dt.getDate()}/${dt.getMonth() + 1}`,
      activeChildren: uniq(events.filter((e) => dayKey(e.createdAt) === k).map((e) => e.childID)),
      sessions: ends.filter((e) => dayKey(e.createdAt) === k).length,
    });
  }

  // Topics (last 7 days).
  const topicMap = {};
  ends7.forEach((e) => {
    if (!e.topic) return;
    const t = topicMap[e.topic] || (topicMap[e.topic] = { topic: e.topic, sessions: 0, accSum: 0, accN: 0 });
    t.sessions += 1;
    if (e.questions > 0) { t.accSum += e.accuracy; t.accN += 1; }
  });
  const topics = Object.values(topicMap)
    .map((t) => ({ topic: t.topic, sessions: t.sessions, avgAccuracy: t.accN ? t.accSum / t.accN / 100 : 0 }))
    .sort((a, b) => b.sessions - a.sessions).slice(0, 8);

  // Accuracy distribution (last 7 days).
  const buckets = [
    { range: "0-50%", lo: 0, hi: 50, n: 0 }, { range: "50-70%", lo: 50, hi: 70, n: 0 },
    { range: "70-85%", lo: 70, hi: 85, n: 0 }, { range: "85-100%", lo: 85, hi: 101, n: 0 },
  ];
  accSamples.forEach((e) => { const b = buckets.find((b) => e.accuracy >= b.lo && e.accuracy < b.hi); if (b) b.n += 1; });

  const summary = {
    updatedAt: new Date().toLocaleString("he-IL", { timeZone: "Asia/Jerusalem" }),
    updatedAtUnix: now,
    totals, excluded,
    active, engagement, learning, daily, topics,
    accuracyBuckets: buckets.map((b) => ({ range: b.range, n: b.n })),
  };
  await db.collection("adminStats").doc("summary").set(summary);
  console.log("[adminStats] wrote summary", { ...totals, excluded, events: events.length });
  return summary;
}

exports.refreshAdminStats = onSchedule(
  { schedule: "every 6 hours", timeZone: "Asia/Jerusalem", timeoutSeconds: 300, memory: "512MiB" },
  async () => { await computeAdminStats(); }
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
