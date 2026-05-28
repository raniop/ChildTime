# 🚀 העלאה ל-TestFlight — צעד-אחר-צעד

הכל מוכן בקוד. ה-archive כבר עבר ולידציה מקומית של `-validate-for-store`. נשאר רק לבצע את הצעדים האלה ב-Xcode וב-App Store Connect.

## ✅ מה כבר מוכן

- ✅ Family Controls (Distribution) entitlement מאושר באקאונט שלך
- ✅ `com.apple.developer.family-controls` בקובץ entitlements
- ✅ App Groups (`group.com.childtime.shared`) בקובץ entitlements
- ✅ Privacy Manifest (`PrivacyInfo.xcprivacy`) — שום מעקב, רק UserDefaults
- ✅ App Icon (1024×1024) ב-Assets
- ✅ Display Name "טופי"
- ✅ Version 1.0, Build 5
- ✅ Release build נקי (BUILD SUCCEEDED)
- ✅ Local archive עובר validate-for-store

---

## 🔴 צעדים שאתה חייב לעשות לפני העלאה ראשונה

### צעד 1 — להפעיל Family Controls על ה-App ID (5 דקות)
1. כנס ל-https://developer.apple.com/account/resources/identifiers/list
2. לחץ על `com.rani.ChildTime`
3. גלגל ל-**Capabilities**
4. ודא ש-**Family Controls** מסומן ✓
5. שמור

> אם זה כבר היה מסומן — מצוין, דלג.

### צעד 2 — לארח את ה-Privacy Policy (5 דקות)
אפל חייבת קישור פומבי ל-Privacy Policy.

**הכי מהיר — Netlify Drop**:
1. כנס ל-https://app.netlify.com/drop
2. גרור את הקובץ `distribution/privacy-policy.html`
3. תקבל URL מיד, כמו `https://random-name-123.netlify.app/privacy-policy.html`

שמור את ה-URL — תצטרך אותו בצעד 3.

### צעד 3 — ליצור App Store Connect Listing (10 דקות)
1. כנס ל-https://appstoreconnect.apple.com
2. **My Apps** → **+** → **New App**
3. מלא:
   - Platform: **iOS**
   - Name: **טופי**
   - Primary Language: **Hebrew (Israel)**
   - Bundle ID: בחר `com.rani.ChildTime` מהרשימה (אם לא מופיע — חזור לצעד 1)
   - SKU: `childtime-001`
4. לחץ **Create**
5. במסך החדש שנפתח:
   - **App Information**:
     - Privacy Policy URL: הדבק את הקישור מצעד 2
     - Category Primary: Education
     - Subtitle: למידה שפותחת זמן משחק
   - **Age Rating**: 4+, ענה None לכל השאר
6. במסך **1.0 Prepare for Submission** (תוכל לחזור לזה אחרי שהבילד יעלה)

> אל תלחץ Submit עדיין. רק תיצור את ה-listing.

---

## 🚀 עכשיו — העלאה (5 דקות ב-Xcode)

### בXcode:
1. **תפריט המכשיר** (למעלה ליד הכפתור Play): שנה ל-**Any iOS Device (arm64)**
   ⚠️ חובה! לא iPad ספציפי
2. **Product → Archive**
3. חכה 2-5 דקות — יפתח חלון **Organizer** עם ה-archive החדש
4. בחר את ה-archive ולחץ **Distribute App**
5. בחר **App Store Connect** → **Next**
6. **Upload** → Next → Next
7. ב-Distribution Options: השאר ברירות מחדל → Next
8. ב-Signing: **Automatically manage signing** → Next
9. בדיקת קונפיגורציה → **Upload**
10. חכה דקה-שתיים → **"Upload Successful"** 🎉

### ב-App Store Connect:
1. כנס ל-**TestFlight** → ה-build יופיע **Processing** (5-15 דקות)
2. כשיהיה **Ready to Submit**: לחץ עליו
3. ענה Export Compliance: **No** (האפליקציה לא משתמשת בהצפנה לא-סטנדרטית)
4. **Internal Testing** → צור קבוצה → הוסף בני משפחה/חברים לפי אימייל
5. שלח הזמנות

---

## בעיות שעלולות לקרות

### "Provisioning profile doesn't include the entitlement"
חזור לצעד 1 — Family Controls לא הופעל על App ID. הפעל, נסה Archive שוב.

### "Invalid binary"
תקבל מייל מאפל עם פירוט. הסבירים נפוצים:
- חסר Privacy Policy URL — חזור ל-App Store Connect listing והוסף
- חסר icon — בלתי סביר (בדקנו)

### "Bundle version must be incremented"
ה-Build number צריך לעלות בכל upload. ערך נוכחי בקוד: **5**. אם תעלה שוב — שנה ל-6 ב-Xcode (General → Build).

---

## אחרי שזה הצליח

יש לי דברים מוכנים בשבילך:
- **הזמנת בודקים**: שלח להם את הקישור מ-App Store Connect
- **הם צריכים**: להוריד TestFlight מה-App Store ולפתוח את הקישור

זהו. תגיד לי כשהבילד הצליח לעלות.
