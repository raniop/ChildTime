# 🚀 TestFlight Roadmap

מפת הדרכים המלאה משליחת הבקשה הראשונה ועד שהאפליקציה אצל בודקים.

## סטטוס נוכחי

✅ אפליקציה רצה על ה-iPad שלך עם Family Controls (Development)
✅ Privacy Policy מוכן (`distribution/privacy-policy.html`)
✅ PrivacyInfo.xcprivacy בפרויקט
✅ Metadata מוכן לכל השדות (`distribution/APP_STORE_METADATA.md`)
✅ טקסטים מוכנים לטופס Distribution (`distribution/FAMILY_CONTROLS_REQUEST.md`)

⏳ **חסום על Family Controls (Distribution) entitlement מאפל**

---

## הצעדים בסדר הנכון

### שלב 1: הגשת הבקשה לאפל (היום! 10 דקות)

1. פתח את `distribution/FAMILY_CONTROLS_REQUEST.md`
2. כנס ל-[הטופס](https://developer.apple.com/contact/request/family-controls-distribution)
3. העתק-הדבק את התשובות לשדות
4. שלח
5. תקבל מייל אישור הגשה

**⏱ המתנה לתשובה: 1-3 שבועות**

---

### שלב 2: בזמן ההמתנה (אפשר עכשיו)

#### 2א. העלאת Privacy Policy לאינטרנט (5 דקות)

הקובץ `distribution/privacy-policy.html` צריך להיות נגיש ב-URL פומבי.

**אפשרות 1: GitHub Pages (חינמי, מומלץ)**
1. צור repo חדש ב-GitHub בשם `childtime-legal` (פומבי)
2. העלה את `privacy-policy.html` ל-root
3. Settings → Pages → Source: main branch
4. תקבל URL כמו `https://raniophir.github.io/childtime-legal/privacy-policy.html`

**אפשרות 2: Netlify Drop (אפילו יותר מהיר)**
1. https://app.netlify.com/drop
2. תגרור את הקובץ
3. מקבל URL מיד

שמור את ה-URL — תצטרך אותו ב-App Store Connect וגם עכשיו לטופס Family Controls (אפשר לעדכן את התשובה דרך מייל אם כבר שלחת).

#### 2ב. יצירת App Store Connect Listing (10 דקות)

1. כנס ל-[App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. מלא לפי `distribution/APP_STORE_METADATA.md`:
   - Platform: iOS
   - Name: קופיקו
   - Primary Language: Hebrew
   - Bundle ID: com.rani.ChildTime (יבחר מהרשימה)
   - SKU: childtime-001
4. אחרי יצירה — תכנס ל-App Information ותמלא:
   - Subtitle, Privacy Policy URL, Category
5. תכנס ל-1.0 (Prepare for Submission) ותמלא:
   - Description, Keywords, Promotional Text, What's New
   - Support URL
6. **אל תלחץ Submit עדיין** — צריך build קודם

#### 2ג. הכנת Screenshots (15 דקות)

צילומי מסך נדרשים לפני שתוכל להגיש ל-TestFlight חיצוני (אינטרני זה לא חובה).

1. הרץ את האפליקציה על iPad
2. בכל מסך חשוב: לחץ במקביל על Volume Up + Power
3. מומלץ לצלם:
   - מסך מפת העולמות
   - שאלה במהלך משחק (עם קומבו)
   - מסך פתיחת קופסה
4. ב-App Store Connect → 1.0 → Screenshots → גרור 3+ צילומים לקטגוריית **iPad 13"**

#### 2ד. תיקונים אפשריים (אם בא לך)

הקוד יציב — אבל בזמן ההמתנה אפשר:
- להוסיף עוד מילים עבריות (קובץ `Models/HebrewWords.swift`)
- לבנות את ה-DeviceActivityMonitor Extension target
- לשפר אנימציות

---

### שלב 3: אחרי שאפל אישרה (~ 1-3 שבועות מעכשיו)

תקבל מייל "Your request has been approved" 🎉. אז:

#### 3א. הפעלת ה-Entitlement (5 דקות)

1. [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. לחץ על `com.rani.ChildTime`
3. **Capabilities**: ודא ש-**Family Controls** מסומן
4. שמירה

#### 3ב. עדכון Xcode (5 דקות)

1. פתח את הפרויקט
2. **Product → Clean Build Folder** (`⇧⌘K`)
3. ב-**Signing & Capabilities** של target ChildTime:
   - תוודא שאין סימן אזהרה צהוב
   - אם יש: לחץ "Try Again" אם זה מופיע
4. עדכן את build number ב-General → Identity:
   - **Version**: 1.0
   - **Build**: 1 (תעלה ב-1 בכל upload)

#### 3ג. בניית Archive (10 דקות)

1. למעלה ב-Xcode → תפריט המכשיר → בחר **Any iOS Device (arm64)** (לא iPad!)
2. **Product → Archive**
3. חכה ל-build (כמה דקות)
4. ייפתח Organizer עם ה-archive החדש
5. בחר את ה-archive → לחץ **Distribute App**
6. בחר **App Store Connect** → **Upload**
7. אישורים → Next → Next → Upload
8. אחרי דקה-שתיים — מקבל "Upload Successful"

#### 3ד. הגדרת TestFlight (10 דקות)

1. App Store Connect → המוצר שלך → **TestFlight**
2. ה-build החדש יופיע "Processing" — חכה 5-15 דקות
3. כשהוא Ready: לחץ עליו → ענה על Export Compliance ("No encryption")
4. **Internal Testing**:
   - **+** → Create New Group
   - הוסף בני משפחה / חברים על ידי האימייל שלהם
   - הם צריכים להיות חברים ב-iTunes Connect שלך (פשוט להוסיף, חינמי)
   - שלח להם הזמנה
5. **External Testing** (אופציונלי):
   - דורש Beta App Review מאפל (1-3 ימים)
   - מאפשר עד 10,000 בודקים

#### 3ה. הזמנת בודקים (5 דקות)

הבודקים יקבלו מייל עם קישור. ההוראות:
1. להוריד את אפליקציית **TestFlight** מה-App Store
2. לפתוח את הקישור
3. ללחוץ "Accept" ואז "Install"
4. בזמן הגשתן הם יראו את הסמליל שלך עם תווית "Beta"

---

## טיפים חשובים

### בזמן TestFlight
- כל גרסה חדשה — תעלה את ה-Build number ב-1
- אם יש שינויים גדולים — תעלה Version (1.0 → 1.1)
- בודקים מקבלים auto-update אם פתחו TestFlight האפליקציה

### דיווח על באגים מבודקים
- TestFlight מאפשר לבודקים לשלוח feedback ולשתף צילומי מסך
- ב-App Store Connect → TestFlight → Feedback

### חידוש Build (כל 90 יום)
- TestFlight builds פגי תוקף אחרי 90 יום
- כדי להאריך — תעלה build חדש

---

## איפה הקבצים שהכנו

```
distribution/
├── privacy-policy.html              ← להעלות לאינטרנט
├── FAMILY_CONTROLS_REQUEST.md       ← תשובות לטופס אפל
└── APP_STORE_METADATA.md            ← טקסטים ל-App Store Connect

ChildTime/
└── PrivacyInfo.xcprivacy            ← Privacy Manifest (כבר בפרויקט)
```

---

## שאלות נפוצות

**Q: אפשר להעלות ל-TestFlight בלי לחכות לאפל?**
A: לא. הוואלידציה של App Store Connect תדחה את ה-upload אם אין Family Controls (Distribution) entitlement.

**Q: כמה זמן באמת לוקח?**
A: רוב הבקשות נענות ב-1-2 שבועות. לפעמים מהר יותר. לעתים נדירות 4 שבועות.

**Q: מה אם אפל דוחים?**
A: יקבלו פירוט. בדרך כלל הסיבה היא תיאור לא מספק. עונים לשרשור עם הבהרות ובדרך כלל מאשרים.

**Q: עלות?**
A: $99/שנה ל-Apple Developer Program (יש לך כבר). TestFlight עצמו חינמי.
