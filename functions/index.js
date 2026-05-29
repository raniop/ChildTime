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
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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
    case "sessionStart": return { title: "מסע למידה חדש 📱", body: `${name} התחיל עכשיו מסע למידה חדש.` };
    case "milestone":    return { title: "כל הכבוד! ✅", body: `${name} ענה נכון על ${event.value || "כמה"} שאלות.` };
    case "streak":       return { title: "רצף! 🔥", body: `${name} נמצא ברצף של ${event.value || "כמה"} תשובות נכונות.` };
    case "wheelWin":     return { title: "גלגל מזל! 🎡", body: `${name} זכה בסיבוב בגלגל המזל.` };
    case "discovery":    return { title: "גילוי חדש 🔭", body: `${name} מגלה עניין גובר ב${event.topic || "תחום חדש"}.` };
    case "assistRequest":return { title: "בקשת עזרה 💌", body: `${name} ביקש את עזרתכם בשאלה.` };
    default:             return null;
  }
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

  const tokens = await tokensForHousehold(householdID, data.originUID);
  const msg = liveMessage(data);
  if (!msg) return;
  await send(tokens, msg, { childID: event.params.childID, type: data.type });
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
