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
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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

function liveMessage(event) {
  const name = event.childName || "הילד";
  switch (event.type) {
    case "sessionStart": return { title: "התחיל לשחק 📱", body: `${name} התחיל עכשיו לשחק ולומד.` };
    case "sessionEnd":   return { title: "סיים לשחק ✅", body: `${name} סיים עכשיו את מסע הלמידה.` };
    case "milestone":    return { title: "כל הכבוד! ✅", body: `${name} ענה נכון על ${event.value || "כמה"} שאלות.` };
    case "streak":       return { title: "רצף! 🔥", body: `${name} נמצא ברצף של ${event.value || "כמה"} תשובות נכונות.` };
    case "wheelWin":     return { title: "גלגל מזל! 🎡", body: `${name} זכה בסיבוב בגלגל המזל.` };
    case "discovery":    return { title: "גילוי חדש 🔭", body: `${name} מגלה עניין גובר ב${event.topic || "תחום חדש"}.` };
    case "assistRequest":return { title: "בקשת עזרה 💌", body: `${name} ביקש את עזרתכם בשאלה.` };
    default:             return null;
  }
}

async function tokensForUID(uid) {
  const p = await db.collection("parents").doc(uid).get();
  if (p.exists && Array.isArray(p.data().fcmTokens)) return [...new Set(p.data().fcmTokens)];
  return [];
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
