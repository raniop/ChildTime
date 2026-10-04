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
        i.lockNewApps = true            // the parent WANTS new apps locked…
        i.openByDesignApps = []         // …but never said what stays open
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

    @Test("An empty allow-list must NOT arm `.all(except:)`")
    func emptyAllowListNeverArms() {
        var i = Inputs()
        i.lockNewApps = true
        i.openByDesignApps = []
        let plan = i.plan()
        // `.all(except: [])` shields Tofy itself, and an app cannot mint its own
        // token — the child could never earn another minute. Failing to the
        // leaky model is bad; locking a child out of the app that unlocks their
        // phone is worse.
        #expect(plan.kind == .blockList)
        #expect(i.newAppLockArmed == false)
        #expect(i.newAppLockNeedsSetup == true)
    }

    @Test("A categories-only allow-list must NOT arm either")
    func categoriesOnlyAllowListNeverArms() {
        var i = Inputs()
        i.lockNewApps = true
        i.openByDesignApps = []          // no APP tokens…
        i.openByDesignWebDomains = [4]   // …only other kinds of token
        // `.all(except:)` takes application tokens only, so this would still be
        // `.all(except: [])`. The old `SelectionStorage.isEmpty` check counted
        // categories and would have armed it — and bricked the device.
        #expect(i.newAppLockArmed == false)
        #expect(i.plan().kind == .blockList)
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
        #expect(i.newAppLockNeedsSetup == false)
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
