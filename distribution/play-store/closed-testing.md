# Google Play — Closed test: 12 testers × 14 days

> Why: Tofy's Play developer account is a **personal** account created after 13 Nov 2023. Google requires
> a closed test with **at least 12 testers who stay opted in for 14 days in a row** before the
> "Apply for production" button unlocks. (It was 20 until Dec 2024; the Console shows the live number
> on Dashboard → "Set up your app → Production access".)
> Recruit **15–20**, not 12: people drop out, and the clock counts only testers who are opted in the whole time.

---

## 0. Before the test can start (one-time)

1. **App content** all green: Privacy policy, App access (review account), Ads = No, Content rating,
   Target audience, Data safety, Accessibility API declaration (+ video), Government / Financial / Health = No.
   (See data-safety.md, families-policy.md, content-rating.md.)
2. **Main store listing** filled in he + en (listing-*.md), icon 512, feature graphic, ≥2 phone screenshots
   (+ 7" and 10" tablet screenshots if you want tablets to show the app as "designed for tablets").
3. A signed **AAB** with versionCode ≥ 1 (release-checklist-android.md).
4. Optional but recommended: push the same AAB to **Internal testing** first (up to 100 testers, no review,
   available in minutes) to check Google sign-in with the Play signing key before the closed test.

## 1. Track setup

1. Play Console → **Test and release → Testing → Closed testing** → the default track **"Closed testing - Alpha"** (or Create track → name it `families-beta`).
2. **Countries / regions:** Israel (+ any country where a tester lives — testers in an unlisted country can't install).
3. **Testers** tab → choose **Google Groups** *(recommended)*:
   - Create a group at https://groups.google.com with hello@tofyapp.com, e.g. `tofy-android-testers@googlegroups.com`.
   - Settings: *Who can join* = "Anyone can ask" (you approve) or "Invited users only"; *Who can view conversations* = "Group members"; **turn off** email delivery to members (Settings → Email options) so testers aren't spammed.
   - Add the group address in the track's Testers tab.
   - Alternative: **Email list** — paste each tester's Gmail (the Google account signed in to Play on their phone — *not* any other email).
4. **Feedback URL or email:** `mailto:hello@tofyapp.com` (or a WhatsApp group link).
5. **Create release** → upload the AAB → release name `<versionName> (<versionCode>)`, e.g. `2026.10.5 (1990)` → release notes (he/en, short) → **Review release → Start rollout to Closed testing**.
6. The first closed release goes through **review** (with Families + Accessibility usually 1–7 days). The 14-day clock starts only once the release is **available** and testers are opted in.
7. Copy the **opt-in link** from the Testers tab: `https://play.google.com/apps/testing/com.rani.tofy`
   and the web store link `https://play.google.com/store/apps/details?id=com.rani.tofy` (works only for opted-in accounts).

## 2. What each tester must do

1. Use an **Android phone or tablet** with the Play Store signed in to the **same Google account** they gave you / joined the group with.
2. Join the Google Group (or wait until Rani adds their Gmail).
3. Open the **opt-in link** in a browser **signed in with that Google account** → **"Become a tester"**.
4. Tap **"Download it on Google Play"** → Install. (If Play says "item not found", wait ~30 minutes after opting in and retry.)
5. **Stay opted in for 14 days** — don't press "Leave the program", don't remove the account. Keeping the app installed and opening it a few times a week matters: Google's production-access review asks about tester engagement.
6. Actually use it: set up a family (parent role), connect a child's device if they have one, answer questions, try chores / friends. Send feedback (bugs + "what confused you") to the WhatsApp group or hello@tofyapp.com.

## 3. Rani's daily routine during the 14 days

- Day 0: confirm in Testers tab that **≥12** are listed as opted in (the Console shows the count of opted-in testers on the Dashboard checklist).
- Every 3–4 days: nudge in the WhatsApp group with one thing to try ("today: connect the kid's phone", "today: house chores").
- Ship fixes to the **same closed track** (bump versionCode) — updating does not reset the 14 days.
- Keep a short log of feedback + what changed: the production application asks for it.

## 4. Apply for production (after day 14)

Dashboard → **Apply for production**. Draft answers:

- *How did you recruit testers?* — "Parents from our Israeli beta community and friends/family with Android devices, through a WhatsApp group and our website's beta list; most are parents of children in grades 1–8."
- *How easy was it to recruit?* — honest choice.
- *Describe the engagement you received* — "Testers set up families, connected children's Android devices with the accessibility-based lock, and used the learning rounds, chores and friends features daily. We received N feedback items (bugs in X, Y; requests for Z)."
- *Summary of feedback & changes* — from your log.
- *Who is the intended audience?* — "Parents of children aged 6–14 who want screen time earned through curriculum learning; children use it on a parent-connected device."
- *How does the app provide value?* — "It turns screen time into a reward for learning (math, reading, English, science…), with a parent-controlled lock and dashboard; available in Hebrew, English, Russian and Arabic, and works across Android and iOS in one family."
- *Expected installs in year one* — honest estimate.
- *Changes made based on testing* / *Is the app ready for production?* — Yes + what changed.

Review of the application: up to ~7 days. Then promote the tested release to Production (start with a staged rollout, e.g. 20%).

---

## 5. WhatsApp message to recruit testers (Hebrew — copy as is)

```
היי! 👋
טופי — האפליקציה שבה הילדים פותרים שאלות לימודיות ומרוויחים זמן מסך — יוצאת עכשיו גם לאנדרואיד 🤖🎉

כדי ש-Google תאשר אותה לחנות, אני צריך 12 הורים עם טלפון או טאבלט אנדרואיד שיבדקו אותה 14 יום.

מה צריך לעשות:
1️⃣ לשלוח לי כאן את כתובת ה-Gmail שמחוברת ל-Play בטלפון
2️⃣ אחרי שאוסיף אתכם — ללחוץ על הקישור שאשלח, "Become a tester", ולהתקין
3️⃣ להשאיר את האפליקציה מותקנת 14 יום, להשתמש בה מדי פעם, ולספר לי מה עבד ומה לא

זה בחינם, בלי פרסומות, ואפשר להסיר בסוף.
מי בפנים? 🙏
```

Follow-up message, after adding them:

```
תודה! 🙏 הנה הקישור:
https://play.google.com/apps/testing/com.rani.tofy
פותחים אותו בדפדפן שמחובר לאותו חשבון Gmail ← "Become a tester" ← "Download it on Google Play".
אם כתוב "הפריט לא נמצא" — מחכים חצי שעה ומנסים שוב.
חשוב: לא לצאת מהתוכנית ולא להסיר את האפליקציה במשך 14 יום. כל הערה תעזור לי מאוד 💜
```
