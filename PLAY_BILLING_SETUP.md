# 🤖 הקמת רכישות ב-Google Play — טופי+, שאלונים, עולמות ויהלומים

הקוד כבר מוכן: האפליקציה (`android/…/billing/`) והשרת (`verifyPlayPurchase` + `playRtdn` ב-`functions/index.js`).
נשאר להגדיר את המוצרים ב-Play Console, לתת לשרת הרשאה לבדוק רכישות, לחבר את ההתראות — ולפרוס.

זמן ביצוע: ~45 דקות. החבילה: `com.rani.tofy` · פרויקט הענן: `childtime-86e98`.

> ⚠️ לפני הכול: Play Console מאפשר ליצור מוצרים רק אחרי שהועלה build אחד לפחות (גם Internal testing מספיק) שכולל את ספריית ה-Billing — ה-build הנוכחי כולל אותה.

---

## איך זה עובד (בקצרה)

1. ההורה קונה ב-Play (מאחורי קוד ההורה, כמו ב-iOS). כל רכישה מתויגת ב-`obfuscatedAccountId` = מזהה המשפחה (המקבילה של `appAccountToken` באפל).
2. האפליקציה שולחת את ה-purchase token ל-`verifyPlayPurchase`. השרת בודק אותו מול Google Play Developer API.
3. **טופי+** — השרת עצמו כותב ל-`households/{id}`: `premiumUntil`, `premiumSource: "paid"`, `purchasedAt`, `playStore{…}` (כמו `appStore{…}` של אפל). האפליקציה באנדרואיד אף פעם לא כותבת `premiumUntil` בעצמה.
4. **שאלונים / עולמות / יהלומים** — רק אחרי שהשרת אישר, האפליקציה כותבת בדיוק מה ש-iOS כותב (`children.packs`, `packExpiry`, `households.ownedPacks`, `packPurchases/{orderId}`, ויהלומים להתקדמות של הילד), ואז "צורכת" את הרכישה כדי שאפשר לקנות שוב.
5. **התראות בזמן אמת (RTDN)** — Google מודיעה ל-`playRtdn` על חידוש, ביטול, פקיעה והחזר כספי, גם אם אף אחד לא פותח את האפליקציה → `premiumUntil`, `renewalOffAt`, `expiredAt`, `refundedAt`, `billingIssueAt` (כמו `appStoreNotifications`).

---

## שלב 1 — מנויי טופי+ (Subscriptions)

Play Console → **Tofy** → Monetize with Play → **Products → Subscriptions** → Create subscription.

| | חודשי | שנתי |
|---|---|---|
| **Product ID** | `tofy_plus_monthly` | `tofy_plus_yearly` |
| **Name** | טופי+ חודשי | טופי+ שנתי |
| **Base plan ID** | `monthly` | `yearly` |
| **Type** | Auto-renewing | Auto-renewing |
| **Billing period** | 1 month | 1 year |
| **מחיר ישראל** | ₪24.90 | ₪199 |
| **מחיר ארה״ב** | $5.99 | $39.99 |
| מקביל ב-iOS | `com.rani.ChildTime.premium.monthly` | `com.rani.ChildTime.premium.yearly` |

לכל base plan: **Activate**. Grace period ו-Account hold — להשאיר את ברירות המחדל (השרת מטפל בשניהם).

**ניסיון חינם (לא חובה):** ב-`tofy_plus_yearly` → Add offer → Offer ID `yearly-trial` → Eligibility: *New customer acquisition* → Phase: Free trial, 7 days.
האפליקציה מציגה אותו **רק** כשהמתג `config/conversion.storeKitTrial` דלוק (היום כבוי — מודל המתנה של 14 יום), ו-Play בעצמו מסתיר אותו ממי שכבר השתמש בניסיון.

> הבאדג׳ "חסוך X%" מחושב לבד מהמחירים של Play — אין מה להגדיר.

---

## שלב 2 — מוצרים חד-פעמיים (In-app products)

Play Console → Monetize with Play → **Products → In-app products** → Create product. כולם **consumable** מבחינת הקוד (האפליקציה צורכת אותם אחרי הענקה) — אין הגדרה מיוחדת. **לא** להפעיל Multi-quantity.

### 💎 יהלומים (נקנים במכשיר הילד, מאחורי קוד ההורה)

| Product ID | שם | ₪ | מקביל ב-iOS |
|---|---|---|---|
| `stars_small` | 60 יהלומים | 9.90 | `com.rani.ChildTime.stars.small` |
| `stars_medium` | 200 יהלומים | 24.90 | `com.rani.ChildTime.stars.medium` |
| `stars_large` | 500 יהלומים | 49.90 | `com.rani.ChildTime.stars.large` |

### ⚽ שאלונים — לתמיד, לכל ילד (ילד נוסף בחצי מחיר)

לכל אחד מ-13 השאלונים שני מוצרים: `pack_<id>` ב-**₪14.90** ו-`pack_<id>_sibling` ב-**₪7.90**.

`<id>` = `soccer`, `dinosaurs`, `space`, `animals`, `sea`, `gifted`, `food`, `israel`, `tishrei`, `music`, `body`, `vehicles`, `flags`
(מקביל ל-`com.rani.ChildTime.pack.<id>` / `.sibling`).

### 🌍 עולמות ל-30 יום — לילד אחד, בלי חידוש אוטומטי

לכל אחד מ-9 העולמות: `pass_<id>` ב-**₪6.90** ו-`pass_<id>_sibling` ב-**₪3.90**.

`<id>` = `math`, `english`, `hebrew`, `logic`, `science`, `history`, `geography`, `money`, `reading`
(מקביל ל-`com.rani.ChildTime.world.<id>.30d` / `.sibling`).

סה״כ: 3 + 26 + 18 = **47** מוצרים חד-פעמיים. כל מוצר → **Activate**.

> טיפ: אפשר לייבא את כולם בבת אחת — Products → In-app products → **Import** (CSV).
> המחירים בשאר המדינות: "Set prices" → convert from ILS, או להשאיר ל-Play.

---

## שלב 3 — הרשאה לשרת לבדוק רכישות

1. **להפעיל את ה-API:** Google Cloud Console → פרויקט `childtime-86e98` → APIs & Services → Library → **Google Play Android Developer API** → Enable.
2. **למצוא את חשבון השירות של הפונקציות:** אחרי הפריסה (שלב 5) — Cloud Console → **Cloud Run** → `verifyplaypurchase` → לשונית **Security** → *Service account*.
   ברירת המחדל ל-Cloud Functions (דור 2) היא `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`.
3. **להזמין אותו ל-Play Console:** Play Console (ברמת החשבון, לא האפליקציה) → **Users and permissions** → Invite new users →
   - Email: כתובת חשבון השירות מסעיף 2
   - App permissions → Add app → **Tofy** → לסמן:
     - ✅ **View financial data, orders, and cancellation survey responses**
     - ✅ **Manage orders and subscriptions**
   - Invite user.

> לוקח ל-Google עד ~24 שעות להפעיל הרשאה חדשה. עד אז `verifyPlayPurchase` מחזיר 401/403 בלוג, והאפליקציה מראה "הרכישה הצליחה, ואנחנו עוד מאמתים אותה" — והרכישה תושלם לבד בפתיחה הבאה.

אין צורך בקובץ מפתח (JSON key) — השרת משתמש ב-Application Default Credentials של הפונקציה.

---

## שלב 4 — התראות בזמן אמת (RTDN)

1. **ליצור את ה-topic** (שם קבוע בקוד: `PLAY_RTDN_TOPIC = "play-rtdn"`):
   ```bash
   gcloud pubsub topics create play-rtdn --project childtime-86e98
   ```
2. **לתת ל-Google Play לפרסם אליו:**
   ```bash
   gcloud pubsub topics add-iam-policy-binding play-rtdn --project childtime-86e98 \
     --member=serviceAccount:google-play-developer-notifications@system.gserviceaccount.com \
     --role=roles/pubsub.publisher
   ```
3. Play Console → **Tofy** → Monetize with Play → **Monetization setup** → *Google Play Billing* → **Real-time developer notifications**:
   - Enable real-time notifications ✅
   - Topic name: `projects/childtime-86e98/topics/play-rtdn`
   - Notification content: **Subscriptions, voided purchases, and all one-time products**
   - Save → **Send test notification** — בלוג של `playRtdn` צריכה להופיע השורה `[play] RTDN test notification ok` (אחרי שלב 5).

---

## שלב 5 — פריסה

```bash
cd ~/ChildTime
firebase deploy --only functions
```
(או רק החדשות: `firebase deploy --only functions:verifyPlayPurchase,functions:playRtdn`)

`functions/package.json` קיבל תלות אחת חדשה — `google-auth-library` (כבר הייתה מותקנת בעקיפין; עכשיו היא מוצהרת).

---

## שלב 6 — בדיקה

1. Play Console → Settings (ברמת החשבון) → **License testing** → להוסיף את חשבון ה-Gmail של המכשיר → License response: `RESPOND_NORMALLY`.
2. להתקין את ה-build מ-Internal testing (רכישות לא עובדות ב-build שהותקן ידנית עם חתימה אחרת).
3. במכשיר ההורה: טופי+ → לקנות חודשי עם "Test card, always approves".
   - ב-Firestore: `households/{id}.premiumUntil` מתעדכן, `premiumSource: "paid"`, ו-`playStore.env: "Test"`.
   - מנוי בדיקה מתחדש כל 5 דקות (חודשי) / 30 דקות (שנתי) — `billingEvents/play-…` עם `SUBSCRIPTION_RENEWED`.
   - ביטול מ-Play Store → Subscriptions → `renewalOffAt` נרשם; כשהמנוי פג → `expiredAt`.
4. שאלון: לקנות לילד אחד → `children/{id}.packs` כולל את השאלון, `packPurchases/{GPA…}` נוצר. לקנות לילד שני → המחיר ₪7.90.
5. יהלומים: במכשיר הילד → חנות יהלומים → קוד הורה → קנייה → +60 💎.
6. החזר כספי: Play Console → Order management → Refund + "Revoke" → `refundedAt` וטופי+ נסגר.

---

## מה מקביל למה (לעיון)

| | iOS | Android |
|---|---|---|
| תיוג המשפחה | `appAccountToken` | `obfuscatedAccountId` |
| אימות | StoreKit 2 (במכשיר) | `verifyPlayPurchase` (בשרת) |
| מי כותב `premiumUntil` | המכשיר (`publishPremium`) + `appStoreNotifications` | רק השרת |
| התראות שרת | `appStoreNotifications` (HTTPS) | `playRtdn` (Pub/Sub `play-rtdn`) |
| שדה המצב במשפחה | `appStore{…}` | `playStore{…}` |
| יומן אירועים | `billingEvents/{notificationUUID}` | `billingEvents/play-{messageId}` |
| מיפוי טוקן → משפחה | `appStoreOriginalTxIDs` | `playSubscriptions/{sha256(token)}` (שרת בלבד) |
