package com.rani.tofy.kid.enforce

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  kid/enforce — the lock on a DEDICATED child Android device
 * ════════════════════════════════════════════════════════════════════════════
 *
 * iOS: FamilyControls shields every app but Tofy until the child earns time;
 * opening earned/gift/parent time lifts the shield for the window; when it
 * ends (or a parent locks remotely) everything re-locks. Android has no
 * FamilyControls, so this package rebuilds it:
 *
 *   TofyGuardService   AccessibilityService. Sees only "a window came to the
 *                      front" (never screen content), asks EnforcementPolicy,
 *                      sends a blocked app home and covers it with GuardOverlay
 *                      (a TYPE_ACCESSIBILITY_OVERLAY window — no "draw over
 *                      apps" permission). Re-checks on KidSession events
 *                      (RemoteLock, WindowEnded, …), at the window's end, and
 *                      on a 30 s safety tick. Binds KidSession itself after a
 *                      reboot so remote lock/unlock keep arriving.
 *   EnforcementPolicy  PURE decision (ShieldPolicy.swift twin) — unit-tested.
 *   GuardOverlay       the lock card = ShieldConfigurationExtension's copy.
 *   AllowList          launcher / phone / emergency / keyboard / permission
 *                      dialog = always open; Settings + uninstall dialog =
 *                      parent-only; launchable apps for the picker.
 *   EnforcementStore   "what stays open" + temporary allowance (local prefs,
 *                      like iOS's app group).
 *   UsageAccess        fallback only: the foreground app right after the
 *                      guard (re)connects. Optional for the parent.
 *   EnforcementStatus  isActive(ctx) + reporting shieldAuthorized/newAppsLocked.
 *   ChildLockSetupScreen / ProminentDisclosureScreen / AlwaysOpenAppsPicker.
 *
 * ── WIRING (for the lead) ──────────────────────────────────────────────────
 *  1. After a CHILD device joins (iOS: ChildLockSetup.markPending → step ④),
 *     show ChildLockSetupScreen(onDone = …) before the child's home. It walks:
 *     disclosure → accessibility → usage access (skippable) → what stays open.
 *     `!EnforcementStore.setupDone(ctx)` tells you it is still pending.
 *  2. From the kid gear (KidDeviceControls, already behind ParentGateThen),
 *     add a row "נעילת האפליקציות" that opens
 *     ChildLockSetupScreen(onDone = close, fromOnboarding = false) — the
 *     manage view: guard status, usage access, what stays open, and
 *     "פתיחת הגדרות המכשיר ל-10 דקות" (Settings is parent-only on a child device).
 *     openDeviceSettingsForParent(ctx) is public if you want the button elsewhere.
 *  3. Call EnforcementStatus.refresh(context) on the kid UI's ON_START
 *     (KidExperience lifecycle observer). It sets KidSession.shieldAuthorized /
 *     newAppsLocked (carried by every heartbeat) and writes our childDevices
 *     row at once when the value CHANGED — so the parent's onboarding
 *     "waiting for the lock" ends and the server's "🔓 הנעילה של טופי כובתה…"
 *     push fires. The guard also calls it on connect (true) and on unbind.
 *  4. Nothing to start: Android binds the service itself once the parent
 *     switches it on, and restarts it after reboot / crash.
 *
 * ── PUBLIC API ─────────────────────────────────────────────────────────────
 *   @Composable ChildLockSetupScreen(onDone, fromOnboarding = !setupDone)
 *   @Composable ProminentDisclosureScreen(onAccept, onDecline)
 *   @Composable AlwaysOpenAppsPicker(initial, onSave, onClose)
 *   EnforcementStatus.isActive(ctx)            guard switched on in Settings
 *   EnforcementStatus.isRunning                guard connected right now
 *   EnforcementStatus.refresh(ctx)             report shieldAuthorized (see 3.)
 *   EnforcementPolicy.shouldBlock(pkg, now, GuardState, SystemApps)
 *   EnforcementStore.openByDesign / setOpenByDesign / allowTemporarily / clearTemporary
 *   openDeviceSettingsForParent(ctx, minutes = 10)
 *   UsageAccess.isGranted(ctx) / settingsIntent(ctx)
 *
 * ── PLAY POLICY ────────────────────────────────────────────────────────────
 *  • Accessibility API for a non-accessibility purpose: isAccessibilityTool=
 *    false, the in-app ProminentDisclosure before the settings redirect
 *    (affirmative "מאשרים וממשיכים" + decline), and the Play Console
 *    "Accessibility API" declaration with a short video of this flow.
 *    Minimal footprint for review: typeWindowStateChanged only,
 *    canRetrieveWindowContent=false, no gestures, nothing stored or sent.
 *  • PACKAGE_USAGE_STATS: special access granted by the parent in Settings;
 *    no Play declaration form, but say it in the Data safety form ("App
 *    activity → other actions", processed on-device, not collected).
 *  • No SYSTEM_ALERT_WINDOW, no QUERY_ALL_PACKAGES (<queries> instead), no
 *    Device Admin, no foreground service.
 *  • AllowList.GUARD_UNINSTALL keeps the uninstall dialog parent-only (iOS
 *    denyAppRemoval parity). If review flags it as "hindering uninstall",
 *    flip it to false — the lock-off push still tells the parents.
 *  • Families policy: the guard is set up by a parent, on a parent-labelled
 *    screen; nothing child-facing asks for a permission.
 */
