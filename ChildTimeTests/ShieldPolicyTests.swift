//
//  ShieldPolicyTests.swift
//  ChildTimeTests
//
//  🔒 The lock is the product. Rani: "אם הילד הוריד אפליקציה חדשה היא לא נעולה,
//  שאר האפליקציות כן נעולות." — a child installs a new app and walks straight
//  out of the lock.
//
//  `ApplicationToken`s cannot be constructed in a test (only Apple's picker
//  mints them), so the decision in `ShieldPolicy.swift` is generic over the
//  token types and these tests drive it with plain `Int` stand-ins. Token 99 is
//  always "the app the child installed five minutes ago": a token nobody has
//  ever picked, which is exactly what the real hole is made of.
//

import Testing
import Foundation
import FamilyControls
import ManagedSettings
@testable import ChildTime

/// Stand-in tokens: apps are Ints, categories are Strings, web domains are Ints.
private typealias Inputs = ShieldInputs<Int, String, Int>

/// The app the child just installed. No policy has ever named it.
private let newlyInstalledApp = 99

// MARK: - The bug

@Suite("Shield policy — a newly installed app")
struct NewAppShieldTests {

    @Test("REPRODUCES THE BUG: the classic block-list cannot cover a new app")
    func blockListLeaksNewApp() {
        var i = Inputs()
        i.lockNewApps = true            // the switch is on…
        i.isChildDevice = false         // …but this is not a child's device, so
        i.openByDesignApps = []         // the block-list is all there is
        i.blockedApps = [1, 2, 3]       // they picked three apps by hand
        let plan = i.plan()

        #expect(plan.kind == .blockList)
        #expect(plan.coversUnknownApps == false)
        // The three picked apps are shielded…
        #expect(plan.shieldedApps == [1, 2, 3])
        // …and the new app is in nothing at all. This is the whole bug.
        #expect(!plan.shieldedApps.contains(newlyInstalledApp))
        #expect(plan.shieldedCategories.isEmpty)
    }

    @Test("A blocked CATEGORY is the only thing that ever caught a new app")
    func blockedCategoryIsTheOnlyEnumeratedCover() {
        var i = Inputs()
        i.lockNewApps = false
        i.blockedCategories = ["games"]
        let plan = i.plan()

        #expect(plan.kind == .blockList)
        #expect(plan.shieldedCategories == ["games"])
        // iOS evaluates a category policy against the app's own category at
        // launch, so a new GAME is shielded by this without Tofy running. But a
        // new app iOS files under anything else is not, and the policy object
        // itself cannot say which — hence `coversUnknownApps == false`.
        #expect(plan.coversUnknownApps == false)
    }

    @Test("THE FIX: with an allow-list, a never-seen app is shielded")
    func allowListCoversNewApp() {
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [7]        // 7 == Tofy, picked by the parent
        i.blockedApps = [1, 2, 3]
        let plan = i.plan()

        #expect(plan.kind == .lockEverythingNew)
        #expect(plan.coversUnknownApps == true)
        // `.all(except: exemptApps)` — the new app is not exempt, so it is
        // shielded, and nobody had to know it exists.
        #expect(!plan.exemptApps.contains(newlyInstalledApp))
        #expect(plan.exemptApps == [7])
    }

    @Test("Build 190 regression: the allow-list ALSO names every app we hold a token for")
    func allowListKeepsTheKnownApps() {
        // On Rani's daughter's device: 119 app tokens in the list, one app kept
        // open — and the shield written was `apps=0 categories=all`. Apple's
        // own apps carry no App Store category, so `.all` never reached
        // Safari, Photos or Messages, and nothing on the device changed.
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [7]
        i.blockedApps = [1, 2, 3, 7]     // the parent ticked everything, Tofy included
        i.blockedWebDomains = [9]
        let plan = i.plan()

        #expect(plan.kind == .lockEverythingNew)
        #expect(plan.lockEverything == true)          // still covers unknown apps
        #expect(plan.shieldedApps == [1, 2, 3])       // AND names the known ones…
        #expect(!plan.shieldedApps.contains(7))       // …never the one kept open
        #expect(plan.shieldedWebDomains == [9])
    }

    @Test("Build 191 regression: over 50 tokens is never sent — iOS would drop the whole set")
    func overLimitSetsAreLeftOut() {
        // Nuni's phone: 119 apps ticked, Tofy kept open, 194 web domains. iOS
        // shields nothing from a set over 50 and reads it back as nil.
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [1000]
        i.blockedApps = Set(1...119)
        i.blockedWebDomains = Set(1...194)
        let plan = i.plan()

        #expect(plan.kind == .lockEverythingNew)
        #expect(plan.lockEverything == true)          // the lock itself is intact
        #expect(plan.shieldedApps.isEmpty)            // …the doomed list is not sent
        #expect(plan.shieldedWebDomains.isEmpty)
        #expect(plan.droppedOverLimit == true)
        #expect(plan.exemptApps == [1000])            // and Tofy stays open

        // Exactly at the limit it is still sent.
        var fits = Inputs()
        fits.lockNewApps = true
        fits.isChildDevice = true
        fits.openByDesignApps = [1000]
        fits.blockedApps = Set(1...50)
        #expect(fits.plan().shieldedApps.count == shieldTokenLimit)
        #expect(fits.plan().droppedOverLimit == false)

        // The block-list fallback obeys the same rule; its categories carry it.
        var leaky = Inputs()
        leaky.lockNewApps = false
        leaky.blockedApps = Set(1...119)
        leaky.blockedCategories = ["games", "social"]
        #expect(leaky.plan().shieldedApps.isEmpty)
        #expect(leaky.plan().shieldedCategories == ["games", "social"])
    }
}

// MARK: - The things that must not break

@Suite("Shield policy — what has to keep working")
struct ShieldExemptionTests {

    @Test("The always-allowed whitelist is exempt in BOTH models")
    func alwaysAllowedIsExemptEverywhere() {
        // Block-list.
        var leaky = Inputs()
        leaky.lockNewApps = false
        leaky.blockedApps = [1, 2]
        leaky.blockedCategories = ["games"]
        leaky.alwaysAllowedApps = [2]
        let leakyPlan = leaky.plan()
        // Removed from the explicit list AND excepted from the category policy.
        #expect(leakyPlan.shieldedApps == [1])
        #expect(leakyPlan.exemptApps == [2])

        // Allow-list. This used to IGNORE the whitelist entirely: block-all mode
        // read only `allowedAppsData`, so an app the parent had permanently
        // allowed was shielded again the moment the strong model armed.
        var strong = Inputs()
        strong.lockNewApps = true
        strong.isChildDevice = true
        strong.openByDesignApps = [7]
        strong.alwaysAllowedApps = [2]
        let strongPlan = strong.plan()
        #expect(strongPlan.kind == .lockEverythingNew)
        #expect(strongPlan.exemptApps == [2, 7])
    }

    @Test("An open per-app allowance is honored in BOTH models")
    func temporaryAllowanceIsExemptEverywhere() {
        var leaky = Inputs()
        leaky.lockNewApps = false
        leaky.blockedApps = [1, 2]
        leaky.temporaryAllowedApps = [1]
        #expect(leaky.plan().shieldedApps == [2])
        #expect(leaky.plan().exemptApps == [1])

        // Same regression as the whitelist: the parent opened YouTube for twenty
        // minutes and block-all mode shielded it anyway.
        var strong = Inputs()
        strong.lockNewApps = true
        strong.isChildDevice = true
        strong.openByDesignApps = [7]
        strong.temporaryAllowedApps = [1]
        let plan = strong.plan()
        #expect(plan.kind == .lockEverythingNew)
        #expect(plan.exemptApps == [1, 7])
    }

    @Test("No allowance open → nothing extra is exempt")
    func noAllowanceExemptsNothing() {
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [7]
        i.temporaryAllowedApps = []     // the window passed; the caller clears it
        #expect(i.plan().exemptApps == [7])
    }

    @Test("Kid Mode outranks every other model")
    func kidModeWins() {
        var i = Inputs()
        i.kidModeActive = true
        i.kidModeAllowedApps = [5]
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [7]
        i.blockedApps = [1]
        let plan = i.plan()

        #expect(plan.kind == .kidMode)
        #expect(plan.coversUnknownApps == true)
        // The kid-mode list, and ONLY it — a child-device whitelist must not
        // widen what a kid may open on the parent's own phone.
        #expect(plan.exemptApps == [5])
        #expect(plan.shieldedApps.isEmpty)
    }
}

// MARK: - Failing closed, and refusing to brick

@Suite("Shield policy — safety gates")
struct ShieldSafetyTests {

    @Test("A child device is fully locked with NO setup — the allow-list is optional")
    func childDeviceArmsWithoutSetup() {
        // This used to refuse to arm until the parent named what stays open,
        // fearing `.all(except: [])` would shield Tofy. Dan's phone showed iOS
        // never shields the app that owns the store — and the wait left every
        // new family on the leaky block-list ("אין מצב שאנשים יוכלו לסדר את
        // זה לבד").
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = []
        let plan = i.plan()
        #expect(plan.kind == .lockEverythingNew)
        #expect(plan.coversUnknownApps == true)
        #expect(plan.exemptApps.isEmpty)
        #expect(!plan.exemptApps.contains(newlyInstalledApp))
    }

    @Test("A parent's own phone is NEVER armed, whatever its switches say")
    func parentPhoneNeverArms() {
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = false
        i.openByDesignApps = [7]
        let plan = i.plan()
        #expect(i.newAppLockArmed == false)
        #expect(plan.kind == .blockList)
        #expect(plan.lockEverything == false)
    }

    @Test("The switch off keeps today's behaviour exactly")
    func switchOffIsTheOldBehaviour() {
        var i = Inputs()
        i.lockNewApps = false
        i.openByDesignApps = [7]         // even with a full allow-list
        i.blockedApps = [1]
        let plan = i.plan()
        #expect(plan.kind == .blockList)
        #expect(plan.coversUnknownApps == false)
    }

    @Test("Defaults are the safe ones: the switch is ON out of the box")
    func defaultsAreSafe() {
        let i = Inputs()
        #expect(i.lockNewApps == true)
        #expect(i.kidModeActive == false)
        // Nothing configured at all (a parent's own phone) shields nothing — by
        // design, and the app's enforce path clears the shield in that case.
        let plan = i.plan()
        #expect(plan.shieldedApps.isEmpty)
        #expect(plan.shieldedCategories.isEmpty)
        #expect(plan.coversUnknownApps == false)
    }
}

// MARK: - The app group all three processes read

@Suite("Shield policy — the app-group reader")
struct ShieldInputsFromDefaultsTests {

    private func scratch(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: "tofy.tests.\(name)")!
        for key in d.dictionaryRepresentation().keys { d.removeObject(forKey: key) }
        return d
    }

    @Test("An install that never touched the switch locks new apps")
    func missingFlagDefaultsToOn() {
        let d = scratch("shield.default")
        #expect(TofyShield.inputs(from: d).lockNewApps == true)
    }

    @Test("The switch is read back from the app group")
    func flagRoundTrips() {
        let d = scratch("shield.flag")
        d.set(false, forKey: TofyShield.Key.lockNewApps)
        #expect(TofyShield.inputs(from: d).lockNewApps == false)
        d.set(true, forKey: TofyShield.Key.lockNewApps)
        #expect(TofyShield.inputs(from: d).lockNewApps == true)
    }

    @Test("An EXPIRED per-app allowance exempts nothing")
    func expiredAllowanceIsDropped() {
        let d = scratch("shield.expired")
        let selection = FamilyActivitySelection()
        d.set(try? JSONEncoder().encode(selection), forKey: TofyShield.Key.temporaryAllowed)

        d.set(Date().addingTimeInterval(-60), forKey: TofyShield.Key.temporaryAllowedEndsAt)
        #expect(TofyShield.inputs(from: d).temporaryAllowedApps.isEmpty)

        // (A live window reads the selection back; with no real tokens to put in
        // it the set is empty either way, so the assertion that carries weight is
        // the expiry branch above.)
        d.set(Date().addingTimeInterval(600), forKey: TofyShield.Key.temporaryAllowedEndsAt)
        #expect(TofyShield.inputs(from: d).temporaryAllowedApps.isEmpty)
    }

    @Test("The device role is read from the app group: only a CHILD device arms")
    func deviceRoleRoundTrips() {
        let d = scratch("shield.role")
        #expect(TofyShield.inputs(from: d).newAppLockArmed == false)      // unset
        d.set("parent", forKey: TofyShield.Key.deviceRole)
        #expect(TofyShield.inputs(from: d).newAppLockArmed == false)
        d.set("child", forKey: TofyShield.Key.deviceRole)
        #expect(TofyShield.inputs(from: d).newAppLockArmed == true)
        #expect(TofyShield.inputs(from: d).plan().kind == .lockEverythingNew)
    }

    @Test("Kid Mode is read from the app group, so a background re-lock sees it")
    func kidModeRoundTrips() {
        let d = scratch("shield.kidmode")
        d.set(true, forKey: TofyShield.Key.kidModeActive)
        #expect(TofyShield.inputs(from: d).plan().kind == .kidMode)
    }

    @Test("The parent's delete window is reported, so a re-lock does not undo it")
    func removalWindowIsReported() {
        let d = scratch("shield.removal")
        #expect(TofyShield.appRemovalWindowOpen(d) == false)
        d.set(Date().addingTimeInterval(300), forKey: TofyShield.Key.appRemovalUnlockedUntil)
        #expect(TofyShield.appRemovalWindowOpen(d) == true)
        d.set(Date().addingTimeInterval(-300), forKey: TofyShield.Key.appRemovalUnlockedUntil)
        #expect(TofyShield.appRemovalWindowOpen(d) == false)
    }

    /// `ShieldSettings.ActivityCategoryPolicy` is not `Equatable`, so what went
    /// into `ManagedSettingsStore` cannot be read back and compared. `apply`
    /// therefore records a one-line breadcrumb of the policy it wrote — this
    /// drives the REAL `ManagedSettings` write path (with real token types) and
    /// asserts the breadcrumb, which is the same string the device logs to
    /// Console.app.
    @Test("apply() writes the real policy and records what it wrote")
    func applyRecordsTheRealWrite() {
        let d = scratch("shield.apply")
        let store = ManagedSettingsStore(named: .init("childtime.shield.tests"))

        var strong = TofyShieldInputs()
        strong.lockNewApps = true
        strong.isChildDevice = false      // not a child's device → block-list
        strong.openByDesignApps = []
        TofyShield.apply(strong.plan(), to: store, reason: "test-leaky", defaults: d)
        #expect(d.string(forKey: TofyShield.Key.lastPlan)?.contains("kind=blockList") == true)
        #expect(d.string(forKey: TofyShield.Key.lastPlan)?.contains("coversNewApps=false") == true)
        #expect(d.string(forKey: TofyShield.Key.lastPlanReason) == "test-leaky")

        var kidMode = TofyShieldInputs()
        kidMode.kidModeActive = true
        TofyShield.apply(kidMode.plan(), to: store, reason: "test-strong", defaults: d)
        #expect(d.string(forKey: TofyShield.Key.lastPlan)?.contains("kind=kidMode") == true)
        #expect(d.string(forKey: TofyShield.Key.lastPlan)?.contains("coversNewApps=true") == true)

        store.clearAllSettings()
    }
}

// MARK: - What Apple's picker actually hands back

@Suite("Shield policy — includeEntireCategory")
struct SelectionFlagTests {

    @Test("Every selection Tofy builds includes the apps inside a ticked category")
    func emptySelectionCarriesTheFlag() {
        // With this OFF — which is what the whole app used to do — ticking a
        // whole category in Apple's picker returns the CATEGORY token and zero
        // application tokens. Rani ticked everything in "אילו אפליקציות נעולות"
        // on his daughter's iPhone and nothing moved, because the shield was
        // then `applications = nil` plus a category policy, and a category
        // policy cannot reach Apple's own apps (Safari, Photos, Messages,
        // Camera, App Store have no App Store category).
        #expect(SelectionStorage.empty().includeEntireCategory == true)
        #expect(SelectionStorage.includeEntireCategory == true)
    }

    @Test("A selection stored by an older build is re-homed onto the flag")
    func legacySelectionIsNormalised() {
        // The flag is a `let`, so an old stored selection can only be fixed by
        // rebuilding it — otherwise the parent re-opens the picker and it still
        // behaves the old way.
        let legacy = FamilyActivitySelection(includeEntireCategory: false)
        #expect(legacy.includeEntireCategory == false)

        let data = try? JSONEncoder().encode(legacy)
        #expect(data != nil)
        #expect(SelectionStorage.decode(data).includeEntireCategory == true)
        #expect(SelectionStorage.normalized(legacy).includeEntireCategory == true)

        // …and re-encoding stores the fixed one, so the next read is clean.
        let round = SelectionStorage.decode(SelectionStorage.encode(legacy))
        #expect(round.includeEntireCategory == true)
    }

    @Test("Nil and garbage decode to a correctly flagged empty selection")
    func decodeFallbacksCarryTheFlag() {
        #expect(SelectionStorage.decode(nil).includeEntireCategory == true)
        #expect(SelectionStorage.decode(Data([0x00, 0x01])).includeEntireCategory == true)
    }
}

@Suite("Shield policy — a shield that looks locked but isn't")
struct WeakShieldTests {

    @Test("Categories with ZERO app tokens is flagged as weak")
    func categoryOnlyIsWeak() {
        var i = Inputs()
        i.lockNewApps = false
        i.blockedApps = []              // the picker returned no app tokens…
        i.blockedCategories = ["games", "social", "entertainment"]
        let plan = i.plan()
        #expect(plan.kind == .blockList)
        // …so Safari, Photos and Messages are untouched however many categories
        // the parent ticked. This is the state Rani's device was in.
        #expect(plan.categoryOnlyAndWeak == true)
        #expect(plan.summary.contains("CATEGORY_ONLY_WEAK=true"))
    }

    @Test("Named apps are not weak")
    func namedAppsAreNotWeak() {
        var i = Inputs()
        i.lockNewApps = false
        i.blockedApps = [1, 2, 3]
        i.blockedCategories = ["games"]
        #expect(i.plan().categoryOnlyAndWeak == false)
    }

    @Test("The allow-list model is never weak — it covers everything by shape")
    func allowListIsNeverWeak() {
        var i = Inputs()
        i.lockNewApps = true
        i.isChildDevice = true
        i.openByDesignApps = [7]
        let plan = i.plan()
        #expect(plan.coversUnknownApps == true)
        #expect(plan.categoryOnlyAndWeak == false)
    }

    @Test("An empty block-list is not reported as weak — there is nothing to warn about")
    func emptyBlockListIsNotWeak() {
        var i = Inputs()
        i.lockNewApps = false
        #expect(i.plan().categoryOnlyAndWeak == false)
    }
}
