// Seeds the LOCAL Firebase emulators (project "demo-tofy") with a demo family
// for the Android parent app. Never touches production: the env vars below
// pin firebase-admin to the emulators, and a demo- project id has no backend.
//   node android/tools/seed-emulator.js
// Test parent (emulator only): parent@demo.tofy / demo-parent-1234 · family parent code 1234
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: 'demo-tofy' });
const db = admin.firestore();
const now = Date.now() / 1000;
// state/current Dates are Apple-reference seconds (since 2001), like iOS's plain JSONEncoder.
const apple = (unix) => unix - 978307200;
// Family parent code 1234 in PINManager's "salt:sha256hex(salt+pin)" format.
const crypto = require('crypto');
const salt = crypto.randomBytes(16).toString('hex');
const parentPinHash = `${salt}:${crypto.createHash('sha256').update(salt + '1234').digest('hex')}`;

(async () => {
  let user;
  try { user = await admin.auth().getUserByEmail('parent@demo.tofy'); }
  catch { user = await admin.auth().createUser({ email: 'parent@demo.tofy', password: 'demo-parent-1234', displayName: 'רני אופיר' }); }
  const uid = user.uid;
  const hid = 'DEMO-HOUSEHOLD-0001';
  const dana = '11111111-1111-4111-8111-111111111111';
  const yoav = '22222222-2222-4222-8222-222222222222';

  await db.doc(`parents/${uid}`).set({ id: uid, email: 'parent@demo.tofy', displayName: 'רני אופיר', householdIDs: [hid], fcmTokens: [], twoFactorEnabled: false, consentVersion: 1, consentAt: now - 86400 * 20 });
  await db.doc(`households/${hid}`).set({
    id: hid, parentUIDs: [uid, 'anon-dana-ipad', 'anon-yoav-ipad'], childIDs: [dana, yoav], createdBy: uid, createdAt: now - 86400 * 20,
    familyName: 'משפחת אופיר', parentPinHash, parentNames: { [uid]: 'רני אופיר' }, timeZone: 'Asia/Jerusalem',
    premiumUntil: now + 86400 * 9, premiumSource: 'gift', giftUntil: now + 86400 * 9,
  });
  const child = (id, name, gender, grade, character, cap) => ({
    id, householdID: hid, name, age: grade >= 3 ? 8 : 6, gender, avatarPresetID: 'fox', character3DID: character,
    grade, gradeSchoolYear: 2026, interests: [], learningLevel: 'medium', createdAt: now - 86400 * 19, dailyCapMinutes: cap,
  });
  await db.doc(`children/${dana}`).set(child(dana, 'דָּנָה', 'girl', 3, 'fox', 90));
  await db.doc(`children/${yoav}`).set(child(yoav, 'יוֹאָב', 'boy', 1, 'bear', 60));
  const state = (ans, cor, mins, extra = {}) => ({
    answeredToday: ans, correctToday: cor, minutesEarnedToday: mins, dailyEarnedDate: apple(now - 60),
    stars: 340, diamonds: 55, dayStreak: 6, totalAnswered: ans * 12, totalCorrect: cor * 12,
    earnedSecondsIn: 5400, earnedSecondsOut: 4200, giftSecondsIn: 1800, giftSecondsOut: 0,
    topicAccuracy: { math: 0.92, hebrew: 0.81, english: 0.7 }, topicAnswered: { math: 120, hebrew: 80, english: 40 },
    revision: 42, lastModifiedAt: apple(now - 60), ...extra,
  });
  await db.doc(`children/${dana}/state/current`).set(state(35, 34, 16));
  await db.doc(`children/${yoav}/state/current`).set(state(50, 41, 42));
  await db.doc(`children/${dana}/state/window`).set({ state: 'open', leaseID: 'lease-1', ownerDeviceID: 'dana-ipad', kind: 'gift', grantedSeconds: 1800, startedAt: admin.firestore.Timestamp.fromMillis((now - 382) * 1000) });
  const dev = (child, id, name, seen) => ({ id: `${child}_${id}`, childID: child, householdID: hid, deviceID: id, name, kind: 'ipad', systemVersion: '26.1', joinedAt: now - 86400 * 18, lastSeenAt: seen, shieldAuthorized: true, appVersion: '2026.10.5 (199)', ownerUID: `anon-${id}` });
  await db.doc(`childDevices/${dana}_dana-ipad`).set(dev(dana, 'dana-ipad', 'iPad של דנה', now - 5));
  await db.doc(`childDevices/${yoav}_yoav-ipad`).set(dev(yoav, 'yoav-ipad', 'iPad של יואב', now - 3600));
  await db.doc(`households/${hid}/chores/room`).set({ id: 'room', childID: yoav, title: 'סידור החדר', emoji: '🛏️', rewardMinutes: 15, rewardCoins: 0, isDaily: true, timesPerDay: 1, markedDoneAt: now - 600, chosenReward: 'minutes', createdAt: now - 86400 * 5 });
  console.log('seeded', { uid, hid });
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
