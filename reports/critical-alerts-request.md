# בקשה לאפל: הרשאת Critical Alerts לצפצוף של טופי

**איפה מגישים:** https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
(נכנסים עם החשבון של המפתח. את הטופס אתה שולח — אני לא ממלא הצהרות בשמך.)

**פרטי האפליקציה לטופס**
- App name: טופי: לומדים ומרוויחים זמן מסך (Tofy)
- Apple ID of the app: 6773805449
- Bundle ID: com.rani.ChildTime
- Category: Education, Kids Category — a learning and parental-control app

**הטקסט לשדה שמבקש לתאר את השימוש (באנגלית, להעתקה כמו שהוא):**

> Tofy is a family app: children earn screen time by learning, and parents manage their children's devices from their own phone. One of the parent tools is "Ring the device" — when a child's iPhone or iPad is lost at home, at school or outside, the parent taps a button in the parent app and the child's device rings for up to 29 seconds so it can be found. It works like the sound in Find My, but for families who manage their children's devices through Tofy.
>
> Today the ring is a regular notification sound. On a child's device this fails exactly when it is needed: children's devices are usually on silent or in a Focus mode (school, bedtime), so a lost device stays silent and cannot be located by sound.
>
> We are requesting the Critical Alerts entitlement for this single purpose:
> - The alert is sent only when a parent explicitly taps "Ring the device" for a specific child device, from the parent's own authenticated device. It is never sent automatically, on a schedule, or for marketing.
> - It is delivered only to that child's device, inside the same family account.
> - The sound stops as soon as the child taps "Found it" on the device, or the parent taps "Stop" — and after 29 seconds at most.
> - The feature is part of location sharing, which is off by default and is turned on per child only with the parent's explicit consent.
> - We will request the critical-alert permission on the child's device with a clear explanation, at the moment the parent enables this feature, and the family can turn it off at any time in Settings.
>
> No other notification in the app will use critical alerts.

**אם יאשרו — מה אני עושה אחר כך**
1. מוסיף את ההרשאה לאפליקציה ולפרופיל החתימה.
2. מכשיר הילד מבקש אישור ל"התראות קריטיות" כשההורה מפעיל את שיתוף המיקום.
3. ההתראה של הצפצוף נשלחת כהתראה קריטית בעוצמה מלאה — גם על שקט, גם ב"נא לא להפריע", גם כשטופי סגור.
