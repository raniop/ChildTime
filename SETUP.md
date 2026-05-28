# ChildTime - הוראות הקמה ב-Xcode

הקוד מוכן, אבל יש כמה דברים שצריך לעשות ידנית ב-Xcode כי אי אפשר לעשות אותם מה-CLI.

## 1. פתח את הפרויקט
```
open /Users/raniophir/ChildTime/ChildTime.xcodeproj
```

## 2. הגדרת חתימה (Signing & Capabilities)

1. בחר את ה-target **ChildTime** → לשונית **Signing & Capabilities**.
2. תחת **Team** - בחר את ה-Apple Developer Account שלך.
3. **Bundle Identifier** - שנה למשהו ייחודי, למשל `com.YOURNAME.childtime`.

## 3. הוסף יכולות (Capabilities) ל-target הראשי

> 💡 קובץ `ChildTime/ChildTime.entitlements` כבר קיים בפרויקט עם הערכים הנכונים. הקובץ עדיין לא מחובר ל-build settings - Xcode יחבר אותו אוטומטית ברגע שתוסיף את היכולות דרך ה-UI (זה גם יעדכן את ה-provisioning profile, מה שאי אפשר לעשות מ-CLI).

לחץ **+ Capability** והוסף:

- **Family Controls** — חובה לחסימה
- **App Groups** — הוסף קבוצה: `group.com.childtime.shared`
  (אם השם תפוס, שנה גם כאן וגם בקבצים: `Models/AppStorage.swift`, `ScreenTime/ShieldManager.swift`, `DeviceActivityMonitorExt/DeviceActivityMonitorExtension.swift`, ושני קבצי `.entitlements`)

ברגע שהוספת את שתי היכולות, Xcode יבדוק שהפרופיל מעודכן ואז הבילד יעבוד.

> ⚠️ **Family Controls Distribution Entitlement**: לפיתוח רגיל זה עובד עם חשבון Apple Developer. כדי לפרסם בחנות אתה צריך לבקש מאפל הרשאת הפצה דרך [הקישור הזה](https://developer.apple.com/contact/request/family-controls-distribution).

## 4. הוסף DeviceActivityMonitor Extension

זה ה-extension שמחזיר את החסימה אחרי שנגמר הזמן.

1. **File → New → Target...**
2. בחר **Device Activity Monitor Extension**
3. **Product Name**: `DeviceActivityMonitorExt`
4. **Language**: Swift
5. אחרי שנוצר - מחק את קובץ ה-Swift שאפל יצרה אוטומטית.
6. גרור את הקבצים מ-`DeviceActivityMonitorExt/` (שכבר נוצרו) לתוך ה-target החדש.
7. ב-target ה-extension החדש → **Signing & Capabilities** → הוסף:
   - **Family Controls**
   - **App Groups** → סמן את `group.com.childtime.shared`

## 5. הגדרות Build (אם הקבצים לא נטענים)

הפרויקט שלך משתמש ב-Synchronized Folders של Xcode 16 - הקבצים תחת `ChildTime/` נטענים אוטומטית. אם לא:
- ב-target → **Build Phases → Compile Sources** וודא שכל הקבצים שם.

## 6. הרץ על iPad פיזי

⚠️ **חשוב**: Family Controls **לא עובד בסימולטור**. אתה חייב iPad פיזי.

1. חבר iPad למחשב.
2. ב-Xcode בחר את ה-iPad כיעד הרצה.
3. **Product → Run** (⌘R).
4. בפעם הראשונה - תצטרך לאשר את האפליקציה ב-Settings → General → VPN & Device Management.

## 7. שימוש ראשון

1. בפתיחה - האפליקציה תבקש אישור Family Controls. אשר.
2. לחץ על גלגל ההגדרות (פינה ימנית עליונה).
3. הזן PIN ברירת מחדל: **1234**.
4. בחר אפליקציות לחסום (FamilyActivityPicker) - YouTube, TikTok, וכו'.
5. **שנה PIN** למשהו אחר!
6. סגור הגדרות. עכשיו האפליקציות שבחרת חסומות עד שהילד יענה על שאלות.

## ארכיטקטורה

```
ChildTime/
├── ChildTime/                            # האפליקציה הראשית
│   ├── ChildTimeApp.swift               # entry point
│   ├── ContentView.swift                # ראוטר: Onboarding / Unlocked / WorldMap
│   ├── ChildTime.entitlements
│   │
│   ├── DesignSystem/                    # תשתית עיצובית
│   │   ├── Colors.swift                 # צבעים + גרדיאנטים (AppColor, AppGradient)
│   │   ├── Typography.swift             # AppFont (hero/title/question/...)
│   │   ├── Spacing.swift                # AppSpacing, AppRadius
│   │   └── Motion.swift                 # animation presets
│   │
│   ├── Components/                      # קומפוננטים שמשמשים בכל מקום
│   │   ├── ViewModifiers.swift          # .float .pulse .glow .shimmer .rumble + JuicyPressStyle
│   │   ├── JuicyButton.swift
│   │   ├── BubbleSpeech.swift
│   │   ├── Sparkle.swift / SparkleField
│   │   ├── StarBurst.swift              # פיצוץ כוכבים
│   │   ├── Confetti.swift
│   │   ├── StarCounter.swift / MinuteCounter
│   │   ├── StreakMeter.swift
│   │   ├── XPBar.swift
│   │   ├── OptionCard.swift             # כפתור תשובה עם feedback states
│   │   ├── WorldCard.swift
│   │   └── ChestView.swift              # קופסה 4-שלבים
│   │
│   ├── Companion/                       # ניצוץ
│   │   ├── CompanionState.swift         # 5 מצבים + Controller (@Observable)
│   │   └── CompanionView.swift          # הדמות עצמה
│   │
│   ├── Audio/
│   │   ├── SoundLibrary.swift           # enum של צלילים
│   │   ├── SoundPlayer.swift            # טוען bundle / נופל ל-system sounds
│   │   └── Haptic.swift
│   │
│   ├── Models/
│   │   ├── AppStorage.swift             # App Group constants
│   │   ├── Topic.swift                  # סוגי שאלות
│   │   ├── Question.swift
│   │   ├── HebrewWords.swift            # מאגר מילים (כיתה א + ב)
│   │   ├── QuestionGenerator.swift      # ייצור שאלות + DDA
│   │   ├── World.swift                  # 3 העולמות + Worlds catalog
│   │   ├── RewardEngine.swift           # כללי תגמול (stars/gems/minutes/chest)
│   │   ├── EventEngine.swift            # מתי לירות Mystery Portal / Super Q
│   │   ├── ParentSettings.swift         # הגדרות הורה
│   │   └── ProgressStore.swift          # stars / gems / xp / level / streaks / worlds...
│   │
│   ├── Views/
│   │   ├── OnboardingView.swift         # פעם ראשונה: PIN + apps + minutes
│   │   ├── HatchingView.swift           # פעם בחיים: ביצה → ניצוץ נולד
│   │   ├── WorldMapView.swift           # הבית - מפה עם 3 עולמות
│   │   ├── WorldDetailView.swift        # quest pre-screen
│   │   ├── QuestionRunnerView.swift     # שאלות עם juice מלא
│   │   ├── RewardScreenView.swift       # פתיחת קופסה אחרי סבב
│   │   ├── LevelUpView.swift            # עליית רמת ניצוץ
│   │   ├── WorldUnlockView.swift        # פתיחת עולם חדש (קולנועי)
│   │   ├── DailyChestView.swift         # קופסה יומית
│   │   ├── UnlockedView.swift           # זמן משחק - ספירה לאחור
│   │   ├── ParentGateView.swift         # PIN keypad
│   │   ├── ParentSettingsView.swift     # הגדרות הורה
│   │   └── DemoView.swift               # מסך דמו לכל הקומפוננטים (dev)
│   │
│   └── ScreenTime/
│       ├── ShieldManager.swift          # החלת shield + תזמון re-shield
│       └── SelectionStorage.swift
│
└── DeviceActivityMonitorExt/            # ה-Extension
    ├── DeviceActivityMonitorExtension.swift
    ├── Info.plist
    └── DeviceActivityMonitorExt.entitlements
```

## זרימת חוויה

```
First launch
   ↓
Onboarding (5 שלבים) ──→ Hatching (ניצוץ נולד)
   ↓
WorldMapView (הבית)
   ├─ tap world ──→ WorldDetailView ──→ QuestionRunnerView
   │                                       ├─ Mystery Portal (10%)
   │                                       ├─ Super Question (7%)
   │                                       ├─ Magic Wand (אחרי 2 שגיאות)
   │                                       └─ End ──→ RewardScreenView
   │                                                    ├─ Level Up? → LevelUpView
   │                                                    ├─ World Unlocked? → WorldUnlockView
   │                                                    └─ "פתח דקות" → unlock
   ├─ daily chest available? ──→ DailyChestView
   ├─ has minutes? ──→ "פתחו לי X דקות" ──→ UnlockedView (countdown)
   ├─ gear icon → ParentGateView → ParentSettingsView
   └─ long-press gear → DemoView (dev)
```

## מגבלות חשובות שצריך להבין

1. **ה-shield עובד דרך iOS** - גם אם הילד יסגור את האפליקציה שלנו, האפליקציות שחסמנו יישארו חסומות. ה-Shield הוא במערכת ההפעלה.

2. **הילד יכול לבטל את החסימה דרך Settings → Screen Time** אם הוא יודע את הקוד. כדי למנוע זאת:
   - הפעל **Screen Time** ידנית ב-iPad של הילד.
   - הגדר **Screen Time Passcode** שונה מקוד המכשיר. אל תספר לילד.
   - כך הוא לא יוכל לבטל את החסימה גם אם הוא ימחק את האפליקציה שלנו.

3. **PIN ברירת מחדל הוא 1234** - שנה אותו מיד בפעם הראשונה!

4. **רענון רקע**: ה-DeviceActivityMonitor extension יחזיר את ה-shield גם אם האפליקציה הראשית לא רצה - זה היופי בארכיטקטורה.

## בעיות נפוצות

- **"Family Controls is not authorized"**: לך ל-Settings → Screen Time → ודא שהוא מופעל. הפעל את האפליקציה מחדש.
- **קוד הילד לא עובד גם אחרי PIN**: ה-PIN הראשוני שמור ב-UserDefaults. אם איפסת אותו, תצטרך להסיר את האפליקציה ולהתקין שוב.
- **FamilyActivityPicker ריק**: בסימולטור הוא ריק. חייב iPad פיזי.
- **שגיאת קומפילציה על FamilyControls**: ודא ש-deployment target הוא לפחות **iOS 16**.
