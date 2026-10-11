# בקשה לאפל: הרשאת Critical Alerts לצפצוף של טופי

**הטופס:** https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
השם, המייל והארגון כבר ממולאים שם אוטומטית. נשארו חמישה שדות — מעתיקים לכל אחד את מה שכתוב כאן.

## 1. App Type
`Personal Safety and Security`

## 2. Bundle ID
```
com.rani.ChildTime
```

## 3. Describe your app
```
Tofy is a family app for children's learning and screen time. Children earn screen time by answering learning questions, and parents manage their children's devices from their own phone: screen-time limits, app locking, and — only with the parent's consent — the location of the child's device.
```

## 4. What type of notifications will you send as Critical Alerts?
```
One type only: "Ring the device". When a child's iPhone or iPad is lost, the parent taps a button in the parent app and the child's device rings for up to 29 seconds so it can be found by sound. Nothing else in the app will use critical alerts.
```

## 5. How frequently will you send Critical Alerts?
`Rarely`

## 6. Explain why you need this entitlement and how it will be used in your app.
```
Today the ring is a regular notification sound, and it fails exactly when it is needed: children's devices are usually on silent or in a Focus mode (school, bedtime), so a lost device stays silent and cannot be located by sound.

How it will be used:
- The alert is sent only when a parent explicitly taps "Ring the device" for a specific child device, from the parent's own signed-in device. It is never sent automatically, on a schedule, or for marketing.
- It is delivered only to that child's device, inside the same family account.
- The sound stops as soon as the child taps "Found it" on the device or the parent taps "Stop", and after 29 seconds at most.
- The feature is part of location sharing, which is off by default and is turned on per child only with the parent's explicit consent.
- The child's device asks for the critical-alert permission with a clear explanation when the parent enables the feature, and the family can turn it off at any time in Settings.
```

## אחרי השליחה
אפל עונים במייל. אם יאשרו, אני מוסיף את ההרשאה לאפליקציה, מכשיר הילד מבקש אישור ל"התראות קריטיות", והצפצוף נשלח בעוצמה מלאה — גם על שקט, גם ב"נא לא להפריע", גם כשטופי סגור.
