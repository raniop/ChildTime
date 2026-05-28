# Family Controls (Distribution) — טקסטים מוכנים לטופס

## הקישור לטופס
https://developer.apple.com/contact/request/family-controls-distribution

## איך להגיש
1. כנס לקישור עם ה-Apple ID של חשבון Developer Program שלך
2. תמלא את הטופס לפי המידע למטה
3. שלח
4. תקבל מייל אישור — תשובה תגיע ב-1-3 שבועות בדרך כלל

---

## תשובות מוכנות (Copy-Paste)

### Account Information
- **Developer Account Holder Name**: Rani Ophir
- **Developer Account Email**: ranioph@gmail.com
- **Apple Developer Team ID**: TFG2H9C76N

### App Information

**App Name**:
```
ChildTime (מסע הניצוץ)
```

**App Bundle ID**:
```
com.rani.ChildTime
```

**App Category**:
```
Education
```

**App Description** (English):
```
ChildTime ("Spark's Journey" in Hebrew) is an educational app for
children ages 4-10. The parent selects which entertainment apps
(YouTube, TikTok, games, etc.) should be blocked by default. The
child can unlock these apps for a limited time window by correctly
answering educational questions (math: addition, subtraction,
multiplication, division; and Hebrew spelling).

The app gamifies learning through worlds, a friendly animated
companion ("Spark"), reward chests, streaks, and an XP system. The
goal is to make the child want to do educational practice in order
to earn screen time.

The parent configures the app once (PIN, list of apps to shield,
minutes earned per correct answer, difficulty level). After that,
the child uses the app independently. All data is stored locally
on the device — nothing is sent to any server.
```

**Primary Use Case for Family Controls** (English):
```
The app uses Family Controls (ManagedSettings) to shield a set of
parent-selected applications. These apps remain unavailable to the
child until the child answers educational questions inside our
app. When the child redeems earned minutes, the shield is removed
for a fixed duration (typically 2-30 minutes per session), and is
re-applied automatically by our DeviceActivityMonitor extension
once the time window ends.

Family Controls is essential to our value proposition: without
the ability to actually shield apps, the educational gating
mechanism does not work. The child must complete learning
exercises before any restricted app becomes accessible.
```

**Why ManagedSettings and DeviceActivity are required**:
```
- ManagedSettings: to apply ShieldSettings.applications and
  ShieldSettings.applicationCategories based on the parent's
  FamilyActivitySelection.
- DeviceActivity: to schedule the automatic re-application of
  the shield at the end of the child's earned play-time window.
- FamilyControls: to authorize the app (.individual mode) and to
  present the FamilyActivityPicker to the parent.
```

**Target Audience**:
```
Parents of children ages 4-10 who want to encourage educational
practice through screen-time gamification. Used as a "self-managed"
device where the parent and child share the iPad and the parent
configures the rules.
```

**Country / Market**:
```
Israel (primarily Hebrew-speaking users), with English support
planned for international expansion.
```

**Distribution Plan**:
```
- Initial release on Apple App Store as a free app
- TestFlight beta testing with friends and family (5-20 testers)
  before public release
- No in-app purchases or subscriptions in the first version
```

**Privacy Policy URL**:
```
https://YOUR-HOSTING-URL/privacy-policy.html
```

(אחרי שתעלה את `distribution/privacy-policy.html` ל-GitHub Pages
או שירות דומה, תכניס את הכתובת המלאה כאן.)

**Support URL**:
```
mailto:ranioph@gmail.com
```

---

## טיפים מהשטח

1. **תשובות בלי שטויות** — אפל בודקת ידנית. תשובות "מתחממות" עוזרות.
2. **השתמש בשפה פעילה** — "the app shields" יותר טוב מ-"apps will be shielded".
3. **תהיה ספציפי על האפיון** — לא רק "אפליקציה לילדים" אלא "ages 4-10 educational app".
4. **אל תזכיר כלים אחרים** — אם תכתוב "like Bark / Qustodio", אפל תהיה זהירה יותר.
5. **אם נדחית** — שלח שאלת הבהרה. הרבה אפליקציות מקבלות אחרי ערעור.

## אחרי שאפל אישרה

תקבל מייל שאומר משהו כמו "Your request has been approved". ואז:

1. כנס ל-[Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. מצא את `com.rani.ChildTime`
3. עריכה → ודא ש-**Family Controls** מסומן
4. שמירה
5. ב-Xcode → Product → Clean Build Folder
6. הבילד הבא של Archive יעבוד עם Distribution
