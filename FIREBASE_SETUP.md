# 🔐 Firebase Authentication — הוראות הקמה

המטרה: ילד שמשחק על iPad וגם iPhone, רואה אותה התקדמות בשני המכשירים — דרך חיבור חשבון Apple ID או Google.

הקוד באפליקציה כבר מוכן (`Auth/AuthManager.swift`, `Views/SignInView.swift`). נשאר לחבר את ה-SDKs ולהפעיל את ה-providers ב-Firebase Console.

---

## שלב 1 — Firebase Console (10 דקות)

### 1א. הוסף אפליקציית iOS לפרויקט
1. כנס ל-https://console.firebase.google.com/u/1/project/childtime-86e98/overview
2. לחץ על אייקון **iOS+** במרכז (או "Add app")
3. מלא:
   - **Apple bundle ID**: `com.rani.ChildTime`
   - **App nickname**: טופי
   - **App Store ID**: השאר ריק (אפשר להוסיף אחרי הפצה)
4. לחץ **Register app**
5. **הורד `GoogleService-Info.plist`** — שמור אותו במקום נגיש
6. דלג על שלבי SPM/CocoaPods (נעשה אותם ב-Xcode)
7. דלג גם על "Initialize Firebase" — הקוד שלנו כבר עושה את זה
8. **Continue to console**

### 1ב. הפעל Authentication
1. בסיידבר השמאלי: **Build → Authentication → Get Started**
2. בלשונית **Sign-in method**:

   **Apple**:
   - לחץ Apple → Enable
   - Services ID — השאר ריק (לא נדרש לאפליקציה iOS)
   - שמור

   **Google**:
   - לחץ Google → Enable
   - **Project support email**: ranioph@gmail.com
   - לחץ Save
   - ⚠️ חשוב: אחרי שמירה — תרד למטה בעמוד הזה ותראה את **Web SDK configuration**. צריך משם את ה-`Web client ID` בהמשך.

### 1ג. (אופציונלי) Firestore Database
לסנכרון התקדמות בעתיד:
1. בסיידבר: **Build → Firestore Database → Create database**
2. בחר **Start in production mode**
3. **Cloud Firestore location**: `eur3 (europe-west)` (קרוב לישראל)
4. Done.

---

## שלב 2 — Xcode (15 דקות)

### 2א. הוסף את GoogleService-Info.plist
1. ב-Finder, גרור את `GoogleService-Info.plist` (מהורדה בשלב 1א) **לתיקיית `ChildTime/`** בפרויקט
2. ב-Xcode יקפוץ דיאלוג: סמן **Copy items if needed**, ודא ש-target **ChildTime** מסומן
3. Add

### 2ב. הוסף Firebase iOS SDK (Swift Package Manager)
1. ב-Xcode: **File → Add Package Dependencies…**
2. ב-search למעלה הדבק: `https://github.com/firebase/firebase-ios-sdk`
3. **Dependency Rule**: Up to Next Major Version (11.0.0)
4. **Add Package**
5. בחר את ה-products הבאים:
   - ✅ **FirebaseAuth**
   - ✅ **FirebaseFirestore** (לסנכרון בעתיד)
   - ✅ **FirebaseCore** (אוטומטי)
6. Add Package

### 2ג. הוסף Google Sign-In SDK
1. **File → Add Package Dependencies…**
2. URL: `https://github.com/google/GoogleSignIn-iOS`
3. **Add Package**
4. בחר:
   - ✅ **GoogleSignIn**
   - ✅ **GoogleSignInSwift**
5. Add

### 2ד. הוסף Sign in with Apple Capability
1. בחר את ה-project → target **ChildTime** → **Signing & Capabilities**
2. **+ Capability** → חפש **Sign in with Apple** → Add

### 2ה. הוסף URL Type ל-Google Sign-In
ה-callback של Google Sign-In עובד דרך URL scheme.

1. פתח את `GoogleService-Info.plist` ב-Xcode וחפש את הערך של **REVERSED_CLIENT_ID** (משהו כמו `com.googleusercontent.apps.123456-abc...`)
2. בחר ה-target **ChildTime** → **Info** → **URL Types**
3. לחץ **+**
4. ב-**URL Schemes**: הדבק את ה-REVERSED_CLIENT_ID

### 2ו. (אופציונלי) Sign-in with Apple לסימולטור
לסימולטור צריך להתחבר ב-Settings → Apple ID. במכשיר אמיתי אין בעיה.

---

## שלב 3 — בנייה והרצה

1. **Product → Clean Build Folder** (`⇧⌘K`)
2. **Build** (`⌘B`)
3. אם יש שגיאות — תצלם screenshot ושלח לי

לאחר בנייה מוצלחת — האפליקציה תכלול:
- מסך SignIn ב-Onboarding (אופציונלי — אפשר לדלג ולשמור הכל מקומית)
- כפתור Sign In ב-Parent Settings
- חיווי "מחובר כ-…" כשמחובר
- כפתור Sign Out

---

## איך זה יעבוד

1. ההורה נכנס ל-Parent Settings ולוחץ Sign In with Apple/Google
2. אחרי התחברות, ה-User ID נשמר באפליקציה
3. (בעתיד) ההתקדמות של הילד תיסנכרן ל-Firestore תחת ה-User ID
4. ב-iPad וב-iPhone — ההורה מתחבר עם אותו חשבון → אותה התקדמות

---

## בעיות נפוצות

### "No GoogleService-Info.plist found"
לא הוספת את הקובץ לפרויקט. חזור לשלב 2א.

### "Failed to sign in with Google" — error code 4
URL Type לא הוגדר נכון. חזור לשלב 2ה.

### "Sign in with Apple not available"
לא הוספת את ה-capability. חזור לשלב 2ד.

### Firebase לא מתחבר
ודא שיש את הקוד `FirebaseApp.configure()` ב-`ChildTimeApp.swift` (כבר הוספתי).
