# 💰 הקמת מנוי "טופי+" — מדריך App Store Connect

קוד ה-Paywall + SubscriptionManager כבר עובד באפליקציה. נשאר רק להגדיר את ה-products ב-App Store Connect.

זמן ביצוע: ~30 דקות.

---

## שלב 1 — Subscription Group

1. App Store Connect → My Apps → **טופי וחברים** → **App Information** → גלול ל-Subscriptions.
2. אם אין כבר — צור Subscription Group חדש:
   - **Reference Name**: `Tofi Premium`
   - **Subscription Group Localization** (Hebrew):
     - Subscription Group Display Name: `טופי+`

---

## שלב 2 — שלושת ה-Products

צור 3 מוצרים. ה-IDs **חייבים להיות בדיוק** כפי שמופיע למטה — כך הקוד מצפה.

### א. מנוי חודשי

| שדה | ערך |
|---|---|
| **Product ID** | `com.rani.ChildTime.premium.monthly` |
| **Reference Name** | Tofi Premium — Monthly |
| **Subscription Group** | Tofi Premium |
| **Duration** | 1 חודש |
| **Price (Israel tier)** | **₪29.90** (Tier 30) |
| **Localization (he)** — Display Name | `חודשי` |
| **Localization (he)** — Description | `גישה מלאה לטופי+. כל הנושאים, כל העולמות, פרופילים לכל ילד.` |

### ב. מנוי שנתי **(זה ה-money-maker)**

| שדה | ערך |
|---|---|
| **Product ID** | `com.rani.ChildTime.premium.yearly` |
| **Reference Name** | Tofi Premium — Yearly |
| **Subscription Group** | Tofi Premium |
| **Duration** | 1 שנה |
| **Price (Israel tier)** | **₪249** (Tier 249) — חיסכון של ~30% מ-12 חודשי |
| **Localization (he)** — Display Name | `שנתי` |
| **Localization (he)** — Description | `הדרך החסכונית ביותר. חיסכון של 30% לעומת חודשי, וניסיון 7 ימים חינם.` |
| **Introductory Offer** | **Free Trial — 7 ימים** (חובה. בלי זה תנפול ל-Conversion < 2%) |

איך מוסיפים את ה-Free Trial:
- בתוך עמוד ה-Product → גלול ל-**Subscription Prices** → **Add Introductory Offer** → Type: `Free`, Duration: `7 Days`, Territory: All.

### ג. רכישה לכל החיים

| שדה | ערך |
|---|---|
| **Product Type** | Non-Consumable (לא subscription!) צריך ליצור אותו דרך **In-App Purchases → Manage** ולא דרך Subscription Group |
| **Product ID** | `com.rani.ChildTime.premium.lifetime` |
| **Reference Name** | Tofi Premium — Lifetime |
| **Price** | **₪449** (Tier 449) |
| **Localization (he)** — Display Name | `לכל החיים` |
| **Localization (he)** — Description | `תשלום חד-פעמי. גישה לטופי+ לכל החיים. אין מנוי, אין חידוש.` |

---

## שלב 3 — Family Sharing

כדי שהורה אחד יכסה את כל הילדים:
- בכל אחד מ-3 המוצרים → סמן **"Family Sharing"** → Enable.

---

## שלב 4 — Sandbox Testing

לפני שמשחררים — לבדוק ב-Sandbox:

1. App Store Connect → **Users and Access** → **Sandbox** → **Testers** → צור משתמש בדיקה (אימייל שונה מה-Apple ID האמיתי).
2. במכשיר: **Settings → App Store → Sandbox Account** → התחבר עם המשתמש החדש.
3. הרץ את האפליקציה → פתח את ה-Paywall (Parent Settings → 👑 שדרג ל-טופי+) → קנה את המסלול השנתי → אמור לעבור ל-7-day trial בלי חיוב אמיתי.
4. בדוק שגם **Restore Purchases** עובד אחרי uninstall.

---

## שלב 5 — Review Submission

כשמגישים את הגרסה ל-App Review, חשוב:

1. **Screenshot חובה** של ה-Paywall (App Store Connect → Version → Screenshots).
2. **App Review Info → Review Notes** הוסף הסבר קצר באנגלית:
   ```
   Tofi+ is an optional auto-renewable subscription that unlocks all 6 educational topics, 6 themed worlds, multi-child profiles, weekly parent reports, and cross-device sync. The yearly plan includes a 7-day free trial.
   
   Pricing:
   - Monthly: ₪29.90 / month
   - Yearly: ₪249 / year (7-day free trial)
   - Lifetime: ₪449 one-time
   
   Subscription auto-renews unless cancelled in Apple ID settings.
   ```
3. **EULA** — Apple's standard EULA כבר מקושר ב-Paywall. אין צורך ב-EULA מותאם אישית, אלא אם רוצים.
4. **Privacy Policy URL** — חייב להיות נגיש. כרגע: `https://github.com/raniop/ChildTime/blob/main/distribution/PRIVACY_POLICY.html` (שווה לקנות דומיין ולהעלות לשם בעתיד).

---

## מה הקוד עושה אוטומטית

- ✅ טוען את 3 ה-products בזמן עליית האפליקציה
- ✅ מציג Paywall עם 3 הכרטיסים, מסלול שנתי מסומן כברירת מחדל
- ✅ Free trial badge מופיע אוטומטית על המסלול השנתי
- ✅ Confetti + dismiss אחרי רכישה מוצלחת
- ✅ Restore Purchases דרך כפתור בתוך ה-Paywall **וגם** מ-Parent Settings
- ✅ מציג סטטוס מנוי חי ב-Parent Settings (כולל תאריך חידוש)
- ✅ קליטה אוטומטית של refunds / cancellations דרך `Transaction.updates`
- ✅ אימות חתימות StoreKit 2 (verified transactions בלבד)

---

## KPIs לעקוב אחריהם (אחרי launch)

| Metric | טוב | מצוין |
|---|---|---|
| Paywall → Purchase Conversion | 2-3% | 5%+ |
| Trial → Paid Conversion | 35-45% | 55%+ |
| Yearly vs Monthly split | 60/40 | 70/30 (יותר שנתי) |
| Churn (12-month) | < 20% | < 10% |
| LTV / CAC | > 3 | > 5 |

מומלץ להוסיף Firebase Analytics אחרי שיהיו תוצאות (שווה לדעת מאיזה מסך הולכים ל-Paywall, איזה מסלול נבחר וכו').

---

## הצעדים הבאים שאני ממליץ

1. **עכשיו**: צור את ה-Subscription Group + 3 ה-products במצב "Ready to Submit" (לא צריך להגיש לאישור עדיין).
2. **בדיקה ב-Sandbox**: תאמת שהכל עובד עם משתמש בדיקה.
3. **גרסה חדשה ל-TestFlight**: שלח build חדש (build number 11) שכולל את ה-Paywall — תן ל-5-10 הורים לנסות.
4. **גרסה ל-App Store**: כשמרוצה — שלח גם את ה-products וגם את ה-version לאישור באותה הגשה.
5. **לעבוד על gating חכם**: כרגע ה-Paywall נגיש מ-Parent Settings, אבל אין gating על תוכן. השלב הבא — לחסום נושאים/עולמות לפי `subs.isPremium`. תגיד לי כשתרצה להתחיל.

---

**Build pass**: ✅ עבר `xcodebuild` ב-Debug ל-iOS device.
**Files created**:
- `ChildTime/Paywall/SubscriptionManager.swift`
- `ChildTime/Paywall/PaywallView.swift`
- Updated: `ChildTimeApp.swift`, `ParentSettingsView.swift`
