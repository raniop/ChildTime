import Foundation
import Combine
import CoreLocation
import UIKit
import AVFoundation
import UserNotifications

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// 📍 Where the children are (Rani, 2026-10-07: "אנחנו רוצים להיות הפמלי לינק").
///
/// ONE object for both sides:
///  * on a CHILD's device it shares the phone's last fix and arrive/leave
///    crossings of the family's places — only while a parent switched sharing
///    on for this child (`children/{id}.locationSharing.enabled`) and the
///    phone allows it;
///  * on a PARENT's device it reads those fixes and sends the two commands —
///    refresh and beep.
///
/// Privacy by construction: only the LAST fix is stored (no route of the day),
/// place events are pushed to the parents and deleted by the server, nothing
/// goes to a third party, and turning sharing off deletes the stored fix.
/// Battery: significant-change updates + region monitoring, never a running
/// GPS. A fresh fix comes when the parent opens the map or taps "רענון".
///
/// Firestore (all under the existing children/{id}/{sub=**} household rule):
///   children/{id}.locationSharing      {enabled, consentAt, consentBy}   parent
///   children/{id}/location/fix_<dev>   each device's last fix            child
///   children/{id}/location/request     {at, by}  → push "location-request" parent
///   children/{id}/location/beep        {at, by, stop, deviceID?, foundAt} both
///   children/{id}/placeEvents/*        {placeID, kind, clientAt}         child
@MainActor
final class LocationSharing: NSObject, ObservableObject {
    static let shared = LocationSharing()

    // MARK: Child side
    /// A parent switched sharing on for the child on this device.
    @Published private(set) var enabledHere = false
    @Published private(set) var permission: CLAuthorizationStatus = .notDetermined
    /// 🔔 A beep is ringing on this device — the kid overlay shows "מָצָאתִי!".
    @Published var beeping = false

    // MARK: Parent side
    /// childID → each of the child's devices' last fix, freshest first.
    @Published private(set) var fixes: [String: [ChildLocationFix]] = [:]
    @Published private(set) var sharing: [String: Bool] = [:]
    /// childID → the parent's beep state: started (unix) and found (unix).
    @Published private(set) var beeps: [String: (at: Double, found: Double?, stop: Bool)] = [:]

    /// DEMO_SCREEN only: places when there is no real household.
    @Published private(set) var demoPlaces: [FamilyPlace]?

    /// The family's places (the demo set when a demo run has no household).
    var familyPlaces: [FamilyPlace] { HouseholdManager.shared.household?.places ?? demoPlaces ?? [] }

    /// DEMO_SCREEN=location…: two children sharing, one at school, plus two places.
    func seedDemo(childIDs: [String]) {
        let school = FamilyPlace(id: "demo-school", name: tr("בית הספר"), emoji: "🏫", lat: 32.0870, lng: 34.7900, radius: 200,
                                 alerts: Dictionary(uniqueKeysWithValues: childIDs.map { ($0, FamilyPlace.PlaceAlert(arrive: true, leave: true)) }))
        let home = FamilyPlace(id: "demo-home", name: tr("הבית"), emoji: "🏠", lat: 32.0790, lng: 34.7810, radius: 100)
        demoPlaces = [school, home]
        let now = Date().timeIntervalSince1970
        for (i, cid) in childIDs.enumerated() {
            sharing[cid] = true
            fixes[cid] = i == 0
                ? [ChildLocationFix(deviceID: "d-phone", kind: "iphone", lat: 32.0872, lng: 34.7903, accuracy: 30, at: now - 4,
                                    battery: 0.56, placeID: school.id, placeSince: now - 3600 * 2.5, permission: "always"),
                   ChildLocationFix(deviceID: "d-ipad", kind: "ipad", lat: 32.0791, lng: 34.7811, accuracy: 30, at: now - 3600,
                                    battery: 0.9, placeID: home.id, placeSince: now - 3600 * 20, permission: "always")]
                : [ChildLocationFix(deviceID: "y-phone", kind: "android", lat: 32.0805, lng: 34.7845, accuracy: 30, at: now - 9,
                                    battery: 0.81, placeID: nil, placeSince: nil, permission: "always")]
        }
    }

    private let manager = CLLocationManager()
    private var bag = Set<AnyCancellable>()
    private var lastWrite: Date = .distantPast
    private var lastReported: String?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var player: AVAudioPlayer?
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var childListeners: [ListenerRegistration] = []
    private var parentListeners: [ListenerRegistration] = []
    private var listeningChild: String?
    #endif

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        permission = manager.authorizationStatus
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    /// Call at launch: iOS relaunches the app in the background for a
    /// significant change or a fence crossing, and the delegate must exist.
    func start() {
        ProfileStore.shared.$activeID
            .combineLatest(ParentSettings.shared.$deviceRole)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.bindChild() }
            .store(in: &bag)
        HouseholdManager.shared.$household
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncRegions() }
            .store(in: &bag)
    }

    private var childID: String? {
        guard ParentSettings.shared.deviceRole == .child, !KidModeManager.shared.active else { return nil }
        return ProfileStore.shared.activeID?.uuidString
    }
    private var places: [FamilyPlace] { HouseholdManager.shared.household?.places ?? [] }
    private var hasPermission: Bool { permission == .authorizedAlways || permission == .authorizedWhenInUse }

    /// The kid's one-time explanation before Apple's own question.
    var needsPermissionPrompt: Bool { enabledHere && (permission == .notDetermined || permission == .authorizedWhenInUse) }

    func requestPermission() {
        // From "not determined" iOS asks while-using first and offers "always"
        // later on its own; from while-using this asks for the upgrade.
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Child: binding and sharing

    private func bindChild() {
        #if canImport(FirebaseFirestore)
        let cid = childID
        guard cid != listeningChild else { return }
        childListeners.forEach { $0.remove() }; childListeners = []
        listeningChild = cid
        guard let cid else { setEnabled(false); return }
        let child = db.collection("children").document(cid)
        childListeners.append(child.addSnapshotListener { [weak self] doc, _ in
            let on = ((doc?.data()?["locationSharing"] as? [String: Any])?["enabled"] as? Bool) ?? false
            self?.setEnabled(on)
        })
        // While Tofy is open, a parent's refresh/beep arrives here directly too.
        childListeners.append(child.collection("location").document("request").addSnapshotListener { [weak self] doc, _ in
            guard let self, doc?.metadata.hasPendingWrites == false, doc?.exists == true else { return }
            Task { await self.freshFix() }
        })
        childListeners.append(child.collection("location").document("beep").addSnapshotListener { [weak self] doc, _ in
            guard let self, let d = doc?.data(), doc?.metadata.hasPendingWrites == false else { return }
            let at = (d["at"] as? Timestamp)?.dateValue() ?? .distantPast
            // A beep aimed at the child's OTHER device is not ours.
            if let target = d["deviceID"] as? String, !target.isEmpty, target != DeviceIdentity.installID { return }
            if d["stop"] as? Bool == true { self.stopBeep(report: false); return }
            // A beep from the last minute that nobody answered yet.
            if Date().timeIntervalSince(at) < 60, d["foundAt"] == nil { self.startBeep() }
        })
        #endif
    }

    private func setEnabled(_ on: Bool) {
        enabledHere = on
        if on { startSharing() } else { stopSharing() }
    }

    private func startSharing() {
        guard enabledHere, hasPermission else { reportPermission(); return }
        manager.startMonitoringSignificantLocationChanges()
        syncRegions()
        manager.requestLocation()
    }

    /// Tofy came to the front on the child's phone: a fresh fix now (a phone
    /// that only allows "while using" can share ONLY now), the fences again
    /// (a place added while the phone slept), and what the phone allows.
    func appBecameActive() {
        guard enabledHere else { return }
        reportPermission()
        guard hasPermission else { return }
        lastWrite = .distantPast
        syncRegions()
        manager.requestLocation()
    }

    private func stopSharing() {
        enabledHere = false
        manager.stopMonitoringSignificantLocationChanges()
        for r in manager.monitoredRegions where r.identifier.hasPrefix("place.") { manager.stopMonitoring(for: r) }
    }

    /// One fence per family place (iOS allows 20 per app).
    private func syncRegions() {
        guard enabledHere, hasPermission, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let want = Dictionary(uniqueKeysWithValues: places.prefix(19).map { ("place.\($0.id)", $0) })
        for r in manager.monitoredRegions where r.identifier.hasPrefix("place.") {
            guard let p = want[r.identifier], let c = r as? CLCircularRegion,
                  c.radius == p.radius, c.center.latitude == p.lat, c.center.longitude == p.lng else {
                manager.stopMonitoring(for: r); continue
            }
        }
        let have = Set(manager.monitoredRegions.map(\.identifier))
        for (id, p) in want where !have.contains(id) {
            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng),
                                          radius: max(100, p.radius), identifier: id)
            region.notifyOnEntry = true; region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
    }

    /// The parent asked (push or listener): one fresh fix, written now. Holds
    /// the app awake up to 20 s for it — a silent push gives us about 30.
    func freshFix() async {
        guard enabledHere, hasPermission else { reportPermission(); return }
        lastWrite = .distantPast
        manager.requestLocation()
        await withCheckedContinuation { cont in
            waiters.append(cont)
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.releaseWaiters() }
        }
    }
    private func releaseWaiters() { let w = waiters; waiters = []; w.forEach { $0.resume() } }

    private func write(_ loc: CLLocation, force: Bool = false) {
        #if canImport(FirebaseFirestore)
        guard let cid = childID, enabledHere else { return }
        guard force || Date().timeIntervalSince(lastWrite) > 60 else { return }
        lastWrite = Date()
        let place = FamilyPlace.place(at: loc.coordinate.latitude, loc.coordinate.longitude, in: places,
                                      slack: loc.horizontalAccuracy)
        let d = AppGroup.defaults
        let now = Date().timeIntervalSince1970
        // "מאז" must survive a single bad reading. Indoors one fix can land
        // outside the place's circle, and resetting on it turned "at school
        // since 8:00" into "since 12:43" (Rani, 2026-10-08). The child has left
        // only after 10 minutes with no match, or on arriving somewhere else.
        if let place {
            if d.string(forKey: "location.placeID") != place.id {
                d.set(place.id, forKey: "location.placeID")
                d.set(now, forKey: "location.placeSince")
            }
            d.removeObject(forKey: "location.awaySince")
        } else if d.string(forKey: "location.placeID") != nil {
            let away = d.double(forKey: "location.awaySince")
            if away == 0 {
                d.set(now, forKey: "location.awaySince")
            } else if now - away > 600 {
                d.removeObject(forKey: "location.placeID")
                d.removeObject(forKey: "location.awaySince")
            }
        }
        let battery = UIDevice.current.batteryLevel
        let data: [String: Any] = [
            "lat": loc.coordinate.latitude, "lng": loc.coordinate.longitude,
            "accuracy": loc.horizontalAccuracy, "clientAt": loc.timestamp.timeIntervalSince1970,
            "at": FieldValue.serverTimestamp(), "platform": "ios", "deviceID": DeviceIdentity.installID,
            "kind": DeviceIdentity.kind,
            "permission": permissionName, "battery": battery >= 0 ? Double(battery) : NSNull(),
            "placeID": place?.id ?? NSNull(),
            "placeSince": place == nil ? NSNull() : d.double(forKey: "location.placeSince"),
        ]
        db.collection("children").document(cid).collection("location").document(Self.fixDoc).setData(data)
        #endif
    }

    private static var fixDoc: String { "fix_\(DeviceIdentity.installID)" }

    private var permissionName: String {
        switch permission {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied, .restricted: return "denied"
        default: return "notDetermined"
        }
    }

    /// Tell the parent what the phone allows, so "waiting for the phone" can
    /// say why. Writes only the permission field.
    private func reportPermission() {
        #if canImport(FirebaseFirestore)
        guard let cid = childID, enabledHere, permissionName != lastReported else { return }
        lastReported = permissionName
        db.collection("children").document(cid).collection("location").document(Self.fixDoc)
            .setData(["permission": permissionName, "platform": "ios", "kind": DeviceIdentity.kind,
                      "deviceID": DeviceIdentity.installID], merge: true)
        #endif
    }

    private func crossed(_ region: CLRegion, arrive: Bool) {
        #if canImport(FirebaseFirestore)
        guard let cid = childID, enabledHere, region.identifier.hasPrefix("place.") else { return }
        let placeID = String(region.identifier.dropFirst("place.".count))
        db.collection("children").document(cid).collection("placeEvents").addDocument(data: [
            "placeID": placeID, "kind": arrive ? "arrive" : "leave",
            "clientAt": Date().timeIntervalSince1970, "deviceID": DeviceIdentity.installID,
        ])
        lastWrite = .distantPast
        manager.requestLocation()
        #endif
    }

    // MARK: - Child: 🔔 beep

    /// Loud, looping, until "מָצָאתִי" or 30 s. In the foreground `.playback`
    /// plays through the silent switch; in the background the push's own
    /// sound has already played (iOS mutes it on silent — Apple's rule).
    func startBeep() {
        guard !beeping, let url = Bundle.main.url(forResource: "tofy_beep", withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1      // the stop timer below ends it at 30 s
        player?.volume = 1
        player?.play()
        beeping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.stopBeep(report: false) }
    }

    /// `report`: the child pressed "מָצָאתִי" — tell the parents it was found.
    func stopBeep(report: Bool) {
        player?.stop(); player = nil
        if beeping { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        beeping = false
        UNUserNotificationCenter.current().getDeliveredNotifications { list in
            let ids = list.filter { ($0.request.content.userInfo["type"] as? String) == "beep" }.map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
        #if canImport(FirebaseFirestore)
        if report, let cid = childID {
            db.collection("children").document(cid).collection("location").document("beep")
                .setData(["foundAt": FieldValue.serverTimestamp()], merge: true)
        }
        #endif
    }

    // MARK: - Parent side

    /// "הרצל 12, תל אביב" for a fix outside every family place (Apple's
    /// geocoder, on the parent's phone; cached per ~50 m so a child standing
    /// still costs one lookup).
    @Published private(set) var addresses: [String: String] = [:]
    private var geocoding = Set<String>()
    private let geocoder = CLGeocoder()

    static func addressKey(_ f: ChildLocationFix) -> String {
        String(format: "%.4f,%.4f", (f.lat * 2000).rounded() / 2000, (f.lng * 2000).rounded() / 2000)
    }

    func address(for f: ChildLocationFix) -> String? {
        let key = Self.addressKey(f)
        if let a = addresses[key] { return a }
        if !geocoding.contains(key), !geocoder.isGeocoding {
            geocoding.insert(key)
            geocoder.reverseGeocodeLocation(CLLocation(latitude: f.lat, longitude: f.lng),
                                            preferredLocale: LanguageStore.shared.current.locale) { [weak self] marks, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.geocoding.remove(key)
                    guard let m = marks?.first else { return }
                    let street = [m.thoroughfare, m.subThoroughfare].compactMap { $0 }.joined(separator: " ")
                    let line = [street.isEmpty ? m.name : street, m.locality].compactMap { $0 }.filter { !$0.isEmpty }
                    if !line.isEmpty { self.addresses[key] = line.joined(separator: ", ") }
                }
            }
        }
        return nil
    }

    /// A tapped "🏫 נוני הגיעה" push → the dashboard opens the map on that child.
    @Published var openMapFor: String?

    /// The map opened: follow, and ask every sharing phone for a fresh fix.
    func watch(childIDs: [String]) {
        follow(childIDs: childIDs)
        refresh(childIDs: childIDs)
    }

    private var following: [String] = []

    /// Follow every child's fixes, sharing switch and beep (the parent home's
    /// location line + the map). Cheap — three listeners a child — and only
    /// re-attached when the set of children changes. Sends nothing to the phones.
    func follow(childIDs: [String]) {
        #if canImport(FirebaseFirestore)
        guard !AppInfo.isDemoRun else { return }   // the demo's seeded fixes stay
        guard childIDs.sorted() != following else { return }
        following = childIDs.sorted()
        unwatch()
        for cid in childIDs {
            let child = db.collection("children").document(cid)
            parentListeners.append(child.addSnapshotListener { [weak self] doc, _ in
                self?.sharing[cid] = ((doc?.data()?["locationSharing"] as? [String: Any])?["enabled"] as? Bool) ?? false
            })
            parentListeners.append(child.collection("location").addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                self.fixes[cid] = snap.documents.filter { $0.documentID.hasPrefix("fix_") }.map { doc in
                    let d = doc.data()
                    let at = (d["at"] as? Timestamp)?.dateValue().timeIntervalSince1970 ?? (d["clientAt"] as? Double) ?? 0
                    let lat = d["lat"] as? Double, lng = d["lng"] as? Double
                    return ChildLocationFix(deviceID: d["deviceID"] as? String ?? "", kind: d["kind"] as? String ?? "",
                                            lat: lat ?? 0, lng: lng ?? 0,
                                            accuracy: (lat == nil || lng == nil) ? -1 : (d["accuracy"] as? Double ?? 0), at: at,
                                            battery: d["battery"] as? Double, placeID: d["placeID"] as? String,
                                            placeSince: d["placeSince"] as? Double, permission: d["permission"] as? String)
                }.sorted { $0.at > $1.at }
            })
            parentListeners.append(child.collection("location").document("beep").addSnapshotListener { [weak self] doc, _ in
                guard let d = doc?.data(), let at = (d["at"] as? Timestamp)?.dateValue() else { return }
                self?.beeps[cid] = (at.timeIntervalSince1970,
                                    (d["foundAt"] as? Timestamp)?.dateValue().timeIntervalSince1970,
                                    d["stop"] as? Bool ?? false)
            })
        }
        #endif
    }

    func unwatch() {
        #if canImport(FirebaseFirestore)
        parentListeners.forEach { $0.remove() }; parentListeners = []
        #endif
    }

    /// childID → when the parent last asked for a fresh fix (the card says
    /// "מרענן…", then why nothing came if the phone did not answer).
    @Published private(set) var refreshedAt: [String: Date] = [:]

    /// "רענון" (and the map opening): ask each sharing child's phone for a fix.
    func refresh(childIDs: [String]) {
        for cid in childIDs { refreshedAt[cid] = Date() }
        #if canImport(FirebaseFirestore)
        let me = Auth.auth().currentUser?.uid ?? ""
        for cid in childIDs {
            db.collection("children").document(cid).collection("location").document("request")
                .setData(["at": FieldValue.serverTimestamp(), "by": me])
        }
        #endif
    }

    /// `deviceID`: one of the child's devices (the iPad on the sofa), nil = all.
    func beep(childID: String, deviceID: String? = nil, stop: Bool = false) {
        #if canImport(FirebaseFirestore)
        let me = Auth.auth().currentUser?.uid ?? ""
        db.collection("children").document(childID).collection("location").document("beep")
            .setData(["at": FieldValue.serverTimestamp(), "by": me, "stop": stop, "deviceID": deviceID ?? ""])
        #endif
    }

    /// The parent's consent switch. Off also deletes the stored fix — nothing
    /// lingers once a parent stops sharing.
    func setSharing(childID: String, on: Bool) async -> Bool {
        #if canImport(FirebaseFirestore)
        let me = Auth.auth().currentUser?.uid ?? ""
        let ref = db.collection("children").document(childID)
        let fields: [String: Any] = ["locationSharing": on
            ? ["enabled": true, "consentAt": Date().timeIntervalSince1970, "consentBy": me]
            : ["enabled": false, "consentAt": NSNull(), "consentBy": NSNull()]]
        var out = await confirmedMerge(ref, fields)
        if out == .denied, await HouseholdManager.shared.reassertMembership() { out = await confirmedMerge(ref, fields) }
        if !on, let docs = try? await ref.collection("location").getDocuments().documents {
            for d in docs where d.documentID.hasPrefix("fix_") { try? await d.reference.delete() }
        }
        return out == .ok || out == .queued
        #else
        return false
        #endif
    }

    func savePlaces(_ places: [FamilyPlace]) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let hid = HouseholdManager.shared.household?.id else { return false }
        let ref = db.collection("households").document(hid)
        let out = await confirmedMerge(ref, ["places": places.map(\.firestore)])
        return out == .ok || out == .queued
        #else
        return false
        #endif
    }
}

extension LocationSharing: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.permission = status
            // iOS answers the first ask with "while using" only and offers
            // "always" much later on its own. Asking again right after the
            // first answer shows Apple's "Change to Always Allow" sheet NOW —
            // while the parent still holds the phone (once; iOS allows one).
            let key = "location.askedAlwaysUpgrade"
            if status == .authorizedWhenInUse, self.enabledHere, !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                manager.requestAlwaysAuthorization()
            }
            if self.enabledHere { self.reportPermission(); self.startSharing() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.write(loc, force: !self.waiters.isEmpty)
            self.releaseWaiters()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.releaseWaiters() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in self.crossed(region, arrive: true) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in self.crossed(region, arrive: false) }
    }
}
