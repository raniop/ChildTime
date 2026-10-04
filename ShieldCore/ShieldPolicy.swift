import Foundation

// MARK: - The decision (pure, framework-free, unit-testable)

/// 🔒 The ONE place that decides what a locked device shields.
///
/// Three separate processes re-apply Tofy's shield — the app, the
/// `DeviceActivityMonitor` extension (background re-lock) and the push service
/// (remote lock). They each used to re-derive the policy by hand, and they
/// drifted: the app honored the parent's "always allowed" whitelist in one mode
/// but not the other, the extension honored a temporary allowance the app
/// forgot, and *none* of them covered an app the child installed after the
/// policy was written. This file is the shared brain they now all ask.
///
/// ## Why a newly installed app used to stay OPEN
/// `ManagedSettings` can shield apps in exactly two shapes:
///  * `shield.applications = {tokens}` — an enumerated set of *specific* apps.
///  * `shield.applicationCategories` — either `.specific(categories, except:)`
///    (enumerated categories) or `.all(except: apps)` (**everything**).
///
/// An `ApplicationToken` only exists for an app the parent actually picked in
/// Apple's `FamilyActivityPicker`. An app installed later therefore has a token
/// nobody has ever seen, so an enumerated policy cannot possibly name it. It is
/// shielded only if it happens to land in one of the categories the parent
/// blocked — and a parent who picked individual apps (the common case) blocked
/// no categories at all, so the child installs anything and walks out of the
/// lock.
///
/// The only mechanism in the framework that covers an unknown future app is
/// `.all(except:)`. That is what `lockEverything` turns on.
///
/// ## Why it can't simply always be on
/// `.all(except:)` shields Tofy itself too, and an app cannot mint its own
/// `ApplicationToken` — only the parent can, by picking Tofy in Apple's picker.
/// So the strong model is armed only once the parent has chosen the apps that
/// stay open (`openByDesignApps`), the one list whose screen tells them to
/// include Tofy. Until then we fall back to the enumerated block-list, which is
/// leaky but cannot lock a child out of the app that earns their minutes.
enum ShieldPlanKind: String, Equatable, Sendable {
    /// Kid Mode on a parent's own phone: everything except the kid-mode list.
    case kidMode
    /// The child device's strong baseline: everything, including apps that do
    /// not exist yet, except the parent's open-by-design + whitelist + any
    /// temporary allowance.
    case lockEverythingNew
    /// The classic enumerated block-list. A newly installed app outside a
    /// blocked category is NOT covered — see the note above.
    case blockList
}

/// The shield to write, as plain sets — no `ManagedSettings` types, so the whole
/// decision can be exercised in tests with stand-in tokens.
struct ShieldPlan<App: Hashable, Cat: Hashable, Web: Hashable>: Equatable {
    /// `true` → `applicationCategories = .all(except: exemptApps)`: every app on
    /// the device, now and in the future, unless exempt.
    var lockEverything: Bool
    /// Specific apps to shield on top of the category policy (block-list only).
    var shieldedApps: Set<App>
    /// Categories to shield (block-list only; meaningless when `lockEverything`).
    var shieldedCategories: Set<Cat>
    var shieldedWebDomains: Set<Web>
    /// Never shielded, in either shape.
    var exemptApps: Set<App>
    var exemptWebDomains: Set<Web>
    var kind: ShieldPlanKind

    /// True when a newly installed app is covered without anyone picking it.
    var coversUnknownApps: Bool { lockEverything }

    /// ⚠️ The shield names CATEGORIES but not a single app. A category policy
    /// only reaches apps iOS files under an App Store category, so Apple's own
    /// built-ins — Safari, Photos, Messages, Camera, App Store, Settings — are
    /// never covered. The device looks locked and the child walks out through
    /// Safari. This is what a selection made with `includeEntireCategory: false`
    /// produces when a parent ticks a whole category.
    var categoryOnlyAndWeak: Bool {
        !lockEverything && shieldedApps.isEmpty && !shieldedCategories.isEmpty
    }

    /// One line for `os_log` / the app-group breadcrumb, so a real-device run
    /// can be checked in Console.app and a test can assert what was written.
    var summary: String {
        let cats = lockEverything ? "all" : "\(shieldedCategories.count)"
        return "kind=\(kind.rawValue) coversNewApps=\(coversUnknownApps) "
            + "apps=\(shieldedApps.count) categories=\(cats) "
            + "web=\(shieldedWebDomains.count) exemptApps=\(exemptApps.count) "
            + "exemptWeb=\(exemptWebDomains.count) "
            + "CATEGORY_ONLY_WEAK=\(categoryOnlyAndWeak)"
    }
}

/// Everything the decision depends on. Defaults are the SAFE ones: a caller that
/// forgets a field gets a locked device, never an open one.
struct ShieldInputs<App: Hashable, Cat: Hashable, Web: Hashable> {
    // Kid Mode (a parent's own phone acting as a child device).
    var kidModeActive = false
    var kidModeAllowedApps: Set<App> = []
    var kidModeAllowedWebDomains: Set<Web> = []

    /// The parent's switch: "lock newly installed apps too" (default ON).
    var lockNewApps = true

    /// The classic block-list the parent picked.
    var blockedApps: Set<App> = []
    var blockedCategories: Set<Cat> = []
    var blockedWebDomains: Set<Web> = []

    /// Never shielded, even under a blocked category ("תמיד מותרות").
    var alwaysAllowedApps: Set<App> = []
    var alwaysAllowedWebDomains: Set<Web> = []

    /// The apps the parent deliberately keeps open on a locked device. This is
    /// the list that ARMS `lockNewApps`, because its screen is the one that tells
    /// the parent to include Tofy itself.
    var openByDesignApps: Set<App> = []
    var openByDesignWebDomains: Set<Web> = []

    /// An UNEXPIRED per-app allowance. Callers must pass the empty set once the
    /// window has passed.
    var temporaryAllowedApps: Set<App> = []
    var temporaryAllowedWebDomains: Set<Web> = []

    /// Apps that must stay open whatever model is in force.
    var exemptApps: Set<App> {
        alwaysAllowedApps.union(openByDesignApps).union(temporaryAllowedApps)
    }
    var exemptWebDomains: Set<Web> {
        alwaysAllowedWebDomains.union(openByDesignWebDomains).union(temporaryAllowedWebDomains)
    }

    /// `lockNewApps` is only SAFE once the parent has named at least one app that
    /// stays open — otherwise `.all(except: [])` would shield Tofy itself, whose
    /// token we cannot add programmatically, and the child could never earn a
    /// minute again. Categories in that list do not count: a category token in
    /// `except:` is not a thing `ManagedSettings` accepts, so a parent who picked
    /// only "Education" would still get `.all(except: [])`.
    var newAppLockArmed: Bool { lockNewApps && !openByDesignApps.isEmpty }

    /// `lockNewApps` is on but inert — a new app is NOT locked and the parent
    /// has to finish the setup. Surfaces as a warning in the UI.
    var newAppLockNeedsSetup: Bool { lockNewApps && openByDesignApps.isEmpty }

    func plan() -> ShieldPlan<App, Cat, Web> {
        // Kid Mode first. A background re-lock that fell through to the parent's
        // (usually empty) block-list used to unlock the whole phone for the kid.
        if kidModeActive {
            return ShieldPlan(lockEverything: true,
                              shieldedApps: [],
                              shieldedCategories: [],
                              shieldedWebDomains: [],
                              exemptApps: kidModeAllowedApps,
                              exemptWebDomains: kidModeAllowedWebDomains,
                              kind: .kidMode)
        }
        let exemptApps = self.exemptApps
        let exemptWebDomains = self.exemptWebDomains
        if newAppLockArmed {
            // 🐛 THE ONE THAT SHIPPED AND DID NOTHING (Rani, build 190: "לא
            // השתנה כלום! מה שהיה פתוח נשאר פתוח"). This used to hand back an
            // EMPTY `shieldedApps`, on the reasoning that `.all(except:)`
            // already covers everything — and `apply` then wrote
            // `shield.applications = nil`, throwing away the 119 application
            // tokens the parent's picker had just produced.
            //
            // A category policy only reaches an app iOS files under an App
            // Store category. Apple's own apps — Safari, Photos, Messages,
            // Camera, App Store, Settings — carry no category, so `.all` never
            // touched them, and every app that WAS covered was already covered
            // by the old `.specific(13 categories)`. Same shield, new name:
            // nothing on the device changed.
            //
            // The two shapes are a UNION, not a choice. Name every app we hold
            // a token for AS WELL, and `.all(except:)` goes on covering the
            // ones nobody has ever picked.
            return ShieldPlan(lockEverything: true,
                              shieldedApps: blockedApps.subtracting(exemptApps),
                              shieldedCategories: [],
                              shieldedWebDomains: blockedWebDomains.subtracting(exemptWebDomains),
                              exemptApps: exemptApps,
                              exemptWebDomains: exemptWebDomains,
                              kind: .lockEverythingNew)
        }
        return ShieldPlan(lockEverything: false,
                          shieldedApps: blockedApps.subtracting(exemptApps),
                          shieldedCategories: blockedCategories,
                          shieldedWebDomains: blockedWebDomains.subtracting(exemptWebDomains),
                          exemptApps: exemptApps,
                          exemptWebDomains: exemptWebDomains,
                          kind: .blockList)
    }
}

// MARK: - Binding the decision to Apple's frameworks

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
import os.log

typealias TofyShieldInputs = ShieldInputs<ApplicationToken, ActivityCategoryToken, WebDomainToken>
typealias TofyShieldPlan = ShieldPlan<ApplicationToken, ActivityCategoryToken, WebDomainToken>

/// The shared shield, readable and writable from the app and from both
/// extensions. Everything here works off the app group, so the three processes
/// cannot disagree about what "locked" means.
enum TofyShield {
    static let appGroupID = "group.com.childtime.shared"
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }
    static var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("childtime.shield")) }

    /// Keys written by `ParentSettings` / `KidModeManager` into the app group.
    enum Key {
        static let blocked = "activitySelection"
        static let lockNewApps = "blockAllExceptAllowed"   // legacy name, kept so
                                                           // an installed build's
                                                           // stored value carries over
        static let openByDesign = "allowedAppsData"
        static let alwaysAllowed = "alwaysAllowedAppsData"
        static let temporaryAllowed = "allowExceptionData"
        static let temporaryAllowedEndsAt = "allowExceptionEndsAt"
        static let kidModeActive = "kidModeActive"
        static let kidModeAllowed = "kidModeAllowedData"
        static let appRemovalUnlockedUntil = "appRemovalUnlockedUntil"
        /// Breadcrumb of the last policy actually written — the only way to check
        /// from the outside what a background re-lock did.
        static let lastPlan = "shield.lastAppliedPlan"
        static let lastPlanAt = "shield.lastAppliedPlanAt"
        static let lastPlanReason = "shield.lastAppliedPlanReason"
    }

    static func selection(_ defaults: UserDefaults, _ key: String) -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: key) else { return FamilyActivitySelection() }
        return (try? JSONDecoder().decode(FamilyActivitySelection.self, from: data))
            ?? FamilyActivitySelection()
    }

    /// Diagnostics: what is in force right now, in words a person can read out
    /// over the phone. `includeEntireCategory` matters because a selection made
    /// with it OFF hands back category tokens and no application tokens, and a
    /// category-only shield cannot reach Apple's own apps.
    static func liveReport(_ defaults: UserDefaults = TofyShield.defaults) -> String {
        let i = inputs(from: defaults)
        let plan = i.plan()
        let blocked = selection(defaults, Key.blocked)
        return [
            "kind=\(plan.kind.rawValue)",
            "coversNewApps=\(plan.coversUnknownApps)",
            "blockedApps=\(blocked.applicationTokens.count)",
            "blockedCategories=\(blocked.categoryTokens.count)",
            "entireCategory=\(blocked.includeEntireCategory)",
            "staysOpen=\(i.openByDesignApps.count)",
            "alwaysAllowed=\(i.alwaysAllowedApps.count)",
            "temporary=\(i.temporaryAllowedApps.count)",
            "shieldedApps=\(plan.shieldedApps.count)",
            "exemptApps=\(plan.exemptApps.count)",
            "lastWrite=\(defaults.string(forKey: Key.lastPlan) ?? "never")",
            "lastReason=\(defaults.string(forKey: Key.lastPlanReason) ?? "-")",
        ].joined(separator: " ")
    }

    /// Read the whole policy out of the app group. Used by the app AND both
    /// extensions, so a re-lock in the background is byte-for-byte the re-lock
    /// the app would have applied.
    static func inputs(from defaults: UserDefaults = TofyShield.defaults) -> TofyShieldInputs {
        var i = TofyShieldInputs()
        i.kidModeActive = (defaults.object(forKey: Key.kidModeActive) as? Bool) ?? false
        let kidMode = selection(defaults, Key.kidModeAllowed)
        i.kidModeAllowedApps = kidMode.applicationTokens
        i.kidModeAllowedWebDomains = kidMode.webDomainTokens

        // Default ON: an install that never touched the switch locks new apps.
        i.lockNewApps = (defaults.object(forKey: Key.lockNewApps) as? Bool) ?? true

        let blocked = selection(defaults, Key.blocked)
        i.blockedApps = blocked.applicationTokens
        i.blockedCategories = blocked.categoryTokens
        i.blockedWebDomains = blocked.webDomainTokens

        let always = selection(defaults, Key.alwaysAllowed)
        i.alwaysAllowedApps = always.applicationTokens
        i.alwaysAllowedWebDomains = always.webDomainTokens

        let open = selection(defaults, Key.openByDesign)
        i.openByDesignApps = open.applicationTokens
        i.openByDesignWebDomains = open.webDomainTokens

        // Only an UNEXPIRED window exempts anything.
        if let endsAt = defaults.object(forKey: Key.temporaryAllowedEndsAt) as? Date, endsAt > Date() {
            let temp = selection(defaults, Key.temporaryAllowed)
            i.temporaryAllowedApps = temp.applicationTokens
            i.temporaryAllowedWebDomains = temp.webDomainTokens
        }
        return i
    }

    /// Write a plan to `ManagedSettingsStore`.
    ///
    /// Order matters. Each property is a separate write, so between two of them
    /// the device is running a mixture of the old policy and the new one. We
    /// always widen BEFORE we narrow, so that mixture is never weaker than
    /// either policy — there is no instant in which nothing shields an app.
    static func apply(_ plan: TofyShieldPlan,
                      to store: ManagedSettingsStore = TofyShield.store,
                      reason: String,
                      defaults: UserDefaults = TofyShield.defaults,
                      log: Logger? = nil) {
        if plan.lockEverything {
            // Widen first: `.all(except:)` already covers everything the old
            // explicit list covered, so clearing that list afterwards cannot
            // open a gap.
            store.shield.applicationCategories = .all(except: plan.exemptApps)
            store.shield.webDomainCategories =
                ShieldSettings.ActivityCategoryPolicy<WebDomain>.all(except: plan.exemptWebDomains)
            store.shield.applications = plan.shieldedApps.isEmpty ? nil : plan.shieldedApps
            store.shield.webDomains = plan.shieldedWebDomains.isEmpty ? nil : plan.shieldedWebDomains
        } else {
            // Relaxing from `.all(except:)` to an enumerated set: name the
            // explicit apps BEFORE dropping `.all`, so they are never briefly
            // unshielded.
            store.shield.applications = plan.shieldedApps.isEmpty ? nil : plan.shieldedApps
            store.shield.webDomains = plan.shieldedWebDomains.isEmpty ? nil : plan.shieldedWebDomains
            store.shield.applicationCategories = plan.shieldedCategories.isEmpty
                ? ShieldSettings.ActivityCategoryPolicy<Application>.none
                : .specific(plan.shieldedCategories, except: plan.exemptApps)
            store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy<WebDomain>.none
        }
        defaults.set(plan.summary, forKey: Key.lastPlan)
        defaults.set(reason, forKey: Key.lastPlanReason)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastPlanAt)
        log?.notice("shield applied (\(reason, privacy: .public)) \(plan.summary, privacy: .public)")
        if plan.categoryOnlyAndWeak {
            log?.error("shield WARNING: categories but ZERO app tokens — Safari/Photos/Messages are NOT covered. The parent's picker returned no application tokens (includeEntireCategory off, or only categories ticked).")
        }
    }

    /// `true` while the parent's short "you may delete Tofy" window is open.
    static func appRemovalWindowOpen(_ defaults: UserDefaults = TofyShield.defaults) -> Bool {
        guard let until = defaults.object(forKey: Key.appRemovalUnlockedUntil) as? Date else { return false }
        return until > Date()
    }

    /// Re-apply the locked baseline from the app group. The single entry point
    /// every process uses, so there is exactly one definition of "locked".
    static func relock(reason: String, log: Logger? = nil) {
        let defaults = TofyShield.defaults
        let store = TofyShield.store
        // A managed device must not be deletable — deleting Tofy would wipe the
        // shield. The one exception is the parent's own short delete window.
        store.application.denyAppRemoval = appRemovalWindowOpen(defaults) ? nil : true
        apply(inputs(from: defaults).plan(), to: store, reason: reason, defaults: defaults, log: log)
    }
}
#endif
