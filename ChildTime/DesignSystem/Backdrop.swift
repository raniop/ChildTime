import Combine
import ImageIO
import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🎨 A built-in backdrop (Rani, 2026-10-11: "לתת להם כל מיני אופציות יפות…
/// וגם להורים, אולי יש כאלה שלא רוצים את הצבעוני"). Free, every one of them.
/// Each is dark enough for white text on the 14 %-white glass panes — that is
/// the one rule a new entry has to keep (check it on the kid home, a question
/// and the parent home before adding it).
struct BackdropTheme: Identifiable, Equatable {
    let id: String
    let colors: [String]
    let orbTop: String
    let orbBottom: String
    var orbOpacity: Double = 0.8

    /// The child's own photo (see `BackdropStore`), stored under this id.
    static let photoID = "photo"
    /// 📷 Up to six photos of their own (Rani, 2026-10-11). The first keeps the
    /// id every build knows; a build that does not know "photo-2" draws the
    /// default colours for it.
    static let photoIDs = [photoID] + (2...6).map { "\(photoID)-\($0)" }
    static func isPhoto(_ id: String?) -> Bool { id.map(photoIDs.contains) ?? false }

    static let tofy = BackdropTheme(id: "tofy", colors: ["7A5CFF", "5E60CE", "3E8BF0"], orbTop: "FF7BD3", orbBottom: "37E2D5")
    static let all: [BackdropTheme] = [
        tofy,
        BackdropTheme(id: "sunset", colors: ["F0683F", "D63A78", "6A35B5"], orbTop: "FFC857", orbBottom: "FF5FA8", orbOpacity: 0.7),
        BackdropTheme(id: "sea", colors: ["0E8FA8", "1565C0", "1B3FA0"], orbTop: "37E2D5", orbBottom: "6EC6FF", orbOpacity: 0.7),
        BackdropTheme(id: "forest", colors: ["1F9A63", "14746F", "0F4C75"], orbTop: "A8E063", orbBottom: "37E2D5", orbOpacity: 0.6),
        BackdropTheme(id: "candy", colors: ["F04FA0", "B14CE0", "6C5CE7"], orbTop: "FFD166", orbBottom: "FF8FB1", orbOpacity: 0.7),
        BackdropTheme(id: "rainbow", colors: ["E0457B", "7A5CFF", "1FA2A8"], orbTop: "FFC857", orbBottom: "37E2D5", orbOpacity: 0.7),
        BackdropTheme(id: "fire", colors: ["D9480F", "B3261E", "7A1F3D"], orbTop: "FFB703", orbBottom: "FF5E62", orbOpacity: 0.6),
        BackdropTheme(id: "ice", colors: ["2390C8", "2374C6", "274690"], orbTop: "A5F3FC", orbBottom: "7DD3FC", orbOpacity: 0.6),
        BackdropTheme(id: "grape", colors: ["7B2CBF", "5A189A", "3C096C"], orbTop: "E0AAFF", orbBottom: "FF6AD5", orbOpacity: 0.6),
        BackdropTheme(id: "mint", colors: ["12A594", "0E8C8C", "145C7A"], orbTop: "B8F2A8", orbBottom: "7FE7DC", orbOpacity: 0.6),
        BackdropTheme(id: "berry", colors: ["D6336C", "A61E4D", "5F1A4B"], orbTop: "FF8FAB", orbBottom: "F783AC", orbOpacity: 0.6),
        BackdropTheme(id: "space", colors: ["2A1B7A", "1B1464", "0B1026"], orbTop: "7A5CFF", orbBottom: "3E8BF0", orbOpacity: 0.55),
        BackdropTheme(id: "night", colors: ["123A7A", "132048", "0A1128"], orbTop: "4C6FFF", orbBottom: "37E2D5", orbOpacity: 0.4),
        BackdropTheme(id: "calm", colors: ["33405A", "283349", "1C2433"], orbTop: "5B7BB5", orbBottom: "3E8BF0", orbOpacity: 0.28),
        BackdropTheme(id: "dark", colors: ["1B1D24", "14161B", "0D0E12"], orbTop: "3A3F52", orbBottom: "2A2E3D", orbOpacity: 0.35),
    ]

    static func find(_ id: String?) -> BackdropTheme { all.first { $0.id == id } ?? tofy }

    /// The name as a child reads it (pointed); a parent's screen strips the points.
    /// (Some of these words are also quiz answers, translated in lower case —
    /// as a NAME each starts with a capital.)
    var displayName: String {
        let name = rawName
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private var rawName: String {
        switch id {
        case "sunset":  return tr("שְׁקִיעָה")
        case "sea":     return tr("יָם")
        case "forest":  return tr("יַעַר")
        case "candy":   return tr("סֻכָּרִיָּה")
        case "rainbow": return tr("קֶשֶׁת")
        case "fire":    return tr("אֵשׁ")
        case "ice":     return tr("קֶרַח")
        case "grape":   return tr("עֲנָבִים")
        case "mint":    return tr("מִנְתָּה")
        case "berry":   return tr("תּוּת")
        case "space":   return tr("חָלָל")
        case "night":   return tr("לַיְלָה")
        case "calm":    return tr("רָגוּעַ")
        case "dark":    return tr("כֵּהֶה")
        default:        return tr("טוֹפִי")
        }
    }
}

/// 🖼 A built-in PICTURE backdrop — an illustrated scene, bundled with the app
/// (Rani, 2026-10-11). Free, every one of them. Chosen and stored exactly like
/// a colour backdrop, by its id ("pic-…": a build that does not know it yet
/// falls back to the default colours), and drawn like a photo of their own —
/// edge to edge, under the same veil.
struct BackdropPicture: Identifiable, Equatable {
    let id: String

    static let all: [BackdropPicture] = ["ocean", "forest", "balloons", "dino", "candy", "castle", "stadium", "space", "arctic"]
        .map { BackdropPicture(id: "pic-" + $0) }

    static func find(_ id: String?) -> BackdropPicture? { all.first { $0.id == id } }

    private var assetName: String { "BackdropPic" + id.dropFirst(4).capitalized }
    /// The full picture (the system keeps it cached while it is on screen).
    var image: UIImage? { UIImage(named: assetName) }
    /// The same scene drawn wide, for a screen on its side (an iPad): the tall
    /// picture would show only its middle band there, blown up.
    var wideImage: UIImage? { UIImage(named: assetName + "Wide") }
    /// A small copy for the picker's grid — nine full pictures would not fit in memory.
    var thumbnail: UIImage? { UIImage(named: assetName + "Thumb") }

    /// Pointed, as a child reads it; a parent's screen strips the points.
    var displayName: String {
        let name = rawName
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private var rawName: String {
        switch id {
        case "pic-ocean":    return tr("מִתַּחַת לַמַּיִם")
        case "pic-forest":   return tr("יַעַר קָסוּם")
        case "pic-balloons": return tr("כַּדּוּרִים פּוֹרְחִים")
        case "pic-dino":     return tr("דִּינוֹזָאוּרִים")
        case "pic-candy":    return tr("מַמְתַּקִּים")
        case "pic-castle":   return tr("טִירָה")
        case "pic-stadium":  return tr("אִצְטַדְיוֹן")
        case "pic-space":    return tr("חָלָל")
        default:             return tr("הַקֹּטֶב")
        }
    }
}

/// 🎨 Which backdrop this device draws right now, and the photos behind it.
///
/// A CHILD's choice lives on their profile (`backdropID` + `backdropUpdatedAt`,
/// synced like the character and the language — the fresher pick wins), so it
/// follows them to every device. A photo of their own is too big for the child
/// doc; it sits in `children/{id}/backdrop/photo` and each device keeps a copy.
/// The PARENT's choice is this phone's own (UserDefaults; a photo stays on the
/// phone).
final class BackdropStore: ObservableObject {
    static let shared = BackdropStore()

    enum Owner: Equatable {
        case parent
        case child(UUID)
        var key: String {
            switch self {
            case .parent: return "parent"
            case .child(let id): return id.uuidString
            }
        }
    }

    struct Look {
        var theme: BackdropTheme
        var photo: UIImage?
        /// A built-in picture's wide version — nil for a photo of their own.
        var widePhoto: UIImage?

        /// The picture for a screen of this size: the wide one when it lies on its side.
        func photo(for size: CGSize) -> UIImage? {
            size.width > size.height ? (widePhoto ?? photo) : photo
        }
    }

    private let defaults = UserDefaults.standard
    private static let parentKey = "backdrop.parent"
    @Published private(set) var parentBackdropID: String? = UserDefaults.standard.string(forKey: BackdropStore.parentKey)
    /// Bumped when a photo file changed (picked here, or arrived from the cloud).
    @Published private(set) var photoRevision = 0
    private var photoCache: [String: UIImage] = [:]
    private var thumbCache: [String: UIImage] = [:]
    private var fetching: Set<String> = []

    // MARK: who, and what

    /// Whose screens these are: the child playing here (their own device, or a
    /// parent's phone in Kid Mode) — otherwise the parent.
    var owner: Owner {
        let kid = KidModeManager.shared
        if kid.active, let id = kid.childID { return .child(id) }
        if ParentSettings.shared.deviceRole == .child, let id = ProfileStore.shared.activeID { return .child(id) }
        return .parent
    }

    func backdropID(for owner: Owner) -> String? {
        switch owner {
        case .parent: return parentBackdropID
        case .child(let id): return ProfileStore.shared.profiles.first { $0.id == id }?.backdropID
        }
    }

    func look(for owner: Owner) -> Look {
        #if DEBUG
        // 🧪 DEMO_BACKDROP=<id> / DEMO_BACKDROP_PHOTO=<path> — screenshots.
        if let photo = Self.demoPhoto { return Look(theme: .tofy, photo: photo) }
        let demoID = ProcessInfo.processInfo.environment["DEMO_BACKDROP"]
        #else
        let demoID: String? = nil
        #endif
        let id = demoID ?? backdropID(for: owner)
        if let picture = BackdropPicture.find(id), let image = picture.image {
            return Look(theme: .tofy, photo: image, widePhoto: picture.wideImage)
        }
        if let id, BackdropTheme.isPhoto(id) {
            // Not on this device yet (it is on its way from the cloud): the default.
            return Look(theme: .tofy, photo: photo(id, for: owner))
        }
        return Look(theme: .find(id))
    }

    var look: Look { look(for: owner) }

    #if DEBUG
    /// 🧪 DEMO_BACKDROP_PHOTOS=a.jpg,b.jpg (or empty) — the picker's "mine" tab
    /// with exactly these photos, for screenshots. Demo runs never reach the cloud.
    func seedDemoPhotos(for owner: Owner) {
        guard let list = ProcessInfo.processInfo.environment["DEMO_BACKDROP_PHOTOS"] else { return }
        for id in BackdropTheme.photoIDs where hasPhoto(id, for: owner) { forget(id, ownerKey: owner.key) }
        for (i, path) in list.split(separator: ",").prefix(BackdropTheme.photoIDs.count).enumerated() {
            guard let image = UIImage(contentsOfFile: String(path)), let jpeg = Self.compress(image) else { continue }
            store(jpeg, id: BackdropTheme.photoIDs[i], ownerKey: owner.key, stamp: Double(i + 1))
        }
    }

    private static let demoPhoto: UIImage? =
        ProcessInfo.processInfo.environment["DEMO_BACKDROP_PHOTO"].flatMap(UIImage.init(contentsOfFile:))
    #endif

    // MARK: choosing

    /// Pick a built-in backdrop.
    func choose(_ theme: BackdropTheme, for owner: Owner) {
        setBackdropID(theme.id, for: owner)
    }

    /// Pick a built-in picture.
    func choose(_ picture: BackdropPicture, for owner: Owner) {
        setBackdropID(picture.id, for: owner)
    }

    /// Back to a photo that is already on this device.
    func choosePhoto(_ id: String, for owner: Owner) {
        guard hasPhoto(id, for: owner) else { return }
        setBackdropID(id, for: owner)
    }

    /// A new photo (camera or album) into the first free place: keep a copy,
    /// use it, and — for a child — send it to their other devices. False when
    /// all six places are taken.
    @discardableResult
    func addPhoto(_ image: UIImage, for owner: Owner) -> Bool {
        guard let id = BackdropTheme.photoIDs.first(where: { !hasPhoto($0, for: owner) }),
              let jpeg = Self.compress(image) else { return false }
        let stamp = Date()
        store(jpeg, id: id, ownerKey: owner.key, stamp: stamp.timeIntervalSince1970)
        setBackdropID(id, for: owner, at: stamp)
        if case .child(let childID) = owner { upload(jpeg, id: id, childID: childID, stamp: stamp) }
        return true
    }

    /// Take one of their photos away — here, and on the child's other devices.
    /// If it was the backdrop, the newest photo left takes over (or the default).
    func removePhoto(_ id: String, for owner: Owner) {
        let wasChosen = backdropID(for: owner) == id
        forget(id, ownerKey: owner.key)
        if wasChosen {
            if let next = photos(for: owner).last { setBackdropID(next.id, for: owner) }
            else { setBackdropID(BackdropTheme.tofy.id, for: owner) }
        }
        if case .child(let childID) = owner { uploadRemoval(id, childID: childID) }
    }

    private func setBackdropID(_ id: String, for owner: Owner, at stamp: Date = Date()) {
        switch owner {
        case .parent:
            parentBackdropID = id
            defaults.set(id, forKey: Self.parentKey)
        case .child(let childID):
            guard var p = ProfileStore.shared.profiles.first(where: { $0.id == childID }) else { return }
            p.backdropID = id
            p.backdropUpdatedAt = stamp
            ProfileStore.shared.update(p)     // local at once + the child's record in the cloud
        }
    }

    // MARK: the photo file

    private static var folder: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Backdrops", isDirectory: true)
    }
    private static func fileURL(_ key: String) -> URL { folder.appendingPathComponent("\(key).jpg") }
    private static func stampKey(_ key: String) -> String { "backdrop.photoStamp.\(key)" }
    /// The file and stamp name of one photo: the owner's own key for the first
    /// (where every build keeps it), "<owner>-2" … for the others.
    static func slotKey(_ ownerKey: String, _ id: String) -> String {
        ownerKey + id.dropFirst(BackdropTheme.photoID.count)
    }

    /// One of their photos, as the picker shows it.
    struct OwnPhoto: Identifiable {
        let id: String
        let thumbnail: UIImage
        let stamp: Double
    }

    func hasPhoto(_ id: String, for owner: Owner) -> Bool {
        FileManager.default.fileExists(atPath: Self.fileURL(Self.slotKey(owner.key, id)).path)
    }

    /// Their photos on this device, oldest first — the newest sits next to the "add" tile.
    func photos(for owner: Owner) -> [OwnPhoto] {
        BackdropTheme.photoIDs.compactMap { id in
            let key = Self.slotKey(owner.key, id)
            guard let thumb = thumbnail(key) else { return nil }
            return OwnPhoto(id: id, thumbnail: thumb, stamp: defaults.double(forKey: Self.stampKey(key)))
        }
        .sorted { $0.stamp < $1.stamp }
    }

    func canAddPhoto(for owner: Owner) -> Bool {
        BackdropTheme.photoIDs.contains { !hasPhoto($0, for: owner) }
    }

    /// The full picture — only the one on screen is kept in memory: six of
    /// them decoded would be ~70 MB.
    func photo(_ id: String, for owner: Owner) -> UIImage? {
        let key = Self.slotKey(owner.key, id)
        if let cached = photoCache[key] { return cached }
        guard let image = UIImage(contentsOfFile: Self.fileURL(key).path) else { return nil }
        photoCache = photoCache.filter { !$0.key.hasPrefix(owner.key) }
        photoCache[key] = image
        return image
    }

    /// A small copy for the picker's tile, read straight from the file.
    private func thumbnail(_ key: String) -> UIImage? {
        if let cached = thumbCache[key] { return cached }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 480]
        guard let source = CGImageSourceCreateWithURL(Self.fileURL(key) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg)
        thumbCache[key] = image
        return image
    }

    private func store(_ jpeg: Data, id: String, ownerKey: String, stamp: Double) {
        let key = Self.slotKey(ownerKey, id)
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try? jpeg.write(to: Self.fileURL(key), options: .atomic)
        photoCache[key] = nil
        thumbCache[key] = nil
        defaults.set(stamp, forKey: Self.stampKey(key))
        photoRevision += 1
    }

    private func forget(_ id: String, ownerKey: String) {
        let key = Self.slotKey(ownerKey, id)
        try? FileManager.default.removeItem(at: Self.fileURL(key))
        photoCache[key] = nil
        thumbCache[key] = nil
        defaults.removeObject(forKey: Self.stampKey(key))
        photoRevision += 1
    }

    /// Small enough for one Firestore document (1 MB) and for a full-screen draw:
    /// at most 1400 pt on the long side, squeezed until it is under ~600 KB.
    static func compress(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let ratio = min(1, 1400 / max(longest, 1))
        let size = CGSize(width: (image.size.width * ratio).rounded(), height: (image.size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        var quality: CGFloat = 0.7
        var data = scaled.jpegData(compressionQuality: quality)
        while let d = data, d.count > 600_000, quality > 0.3 {
            quality -= 0.1
            data = scaled.jpegData(compressionQuality: quality)
        }
        return data
    }

    // MARK: the photo, between a child's devices

    /// Changes whenever the current child's photo might need fetching.
    var photoSyncKey: String {
        guard case .child(let id) = owner,
              let p = ProfileStore.shared.profiles.first(where: { $0.id == id }),
              BackdropTheme.isPhoto(p.backdropID) else { return "" }
        return "\(id.uuidString)-\(p.backdropID ?? "")-\(p.backdropUpdatedAt?.timeIntervalSince1970 ?? 0)"
    }

    #if canImport(FirebaseFirestore)
    /// `children/{id}/backdrop/<photo id>` holds one picture; `…/index` says
    /// which exist (`photos`) and which were taken away (`removed`), each with
    /// its time — so another device can show them all without downloading
    /// them first, and drops one that was removed elsewhere.
    private func cloud(_ childID: String) -> CollectionReference {
        Firestore.firestore().collection("children").document(childID).collection("backdrop")
    }
    #endif

    private func upload(_ jpeg: Data, id: String, childID: UUID, stamp: Date) {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, HouseholdManager.shared.household != nil else { return }
        let at = stamp.timeIntervalSince1970
        cloud(childID.uuidString).document(id).setData(["data": jpeg, "updatedAt": at]) { error in
            if let error { TofyLink("backdrop photo upload failed: \(error.localizedDescription)") }
        }
        cloud(childID.uuidString).document("index")
            .setData(["photos": [id: at], "removed": [id: FieldValue.delete()]], merge: true)
        #endif
    }

    private func uploadRemoval(_ id: String, childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, HouseholdManager.shared.household != nil else { return }
        cloud(childID.uuidString).document(id).delete()
        cloud(childID.uuidString).document("index")
            .setData(["photos": [id: FieldValue.delete()], "removed": [id: Date().timeIntervalSince1970]], merge: true)
        #endif
    }

    /// The current child chose a photo on ANOTHER device, newer than the copy
    /// here (or there is none here) → bring it.
    @MainActor
    func fetchPhotoIfNeeded() async {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, case .child(let id) = owner,
              let p = ProfileStore.shared.profiles.first(where: { $0.id == id }),
              let chosen = p.backdropID, BackdropTheme.isPhoto(chosen) else { return }
        await fetch(chosen, childID: id, wanted: p.backdropUpdatedAt?.timeIntervalSince1970 ?? 0)
        #endif
    }

    /// 📷 The picker's "mine" tab on a child's second device: bring the photos
    /// added on the other one, and drop those removed there.
    @MainActor
    func syncPhotoSet(for owner: Owner) async {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, case .child(let id) = owner,
              let index = try? await cloud(id.uuidString).document("index").getDocument().data() else { return }
        let plan = Self.photoSetPlan(
            cloud: Self.stamps(index["photos"]), removed: Self.stamps(index["removed"]),
            local: Dictionary(uniqueKeysWithValues: BackdropTheme.photoIDs.compactMap { pid in
                hasPhoto(pid, for: owner) ? (pid, defaults.double(forKey: Self.stampKey(Self.slotKey(id.uuidString, pid)))) : nil
            }))
        for pid in plan.drop { forget(pid, ownerKey: id.uuidString) }
        for (pid, at) in plan.fetch { await fetch(pid, childID: id, wanted: at) }
        #endif
    }

    private static func stamps(_ any: Any?) -> [String: Double] {
        ((any as? [String: Any]) ?? [:]).compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    /// What a device has to do to match the child's photo set: which to bring
    /// (missing here, or older here) and which to drop (removed elsewhere after
    /// this copy was made). A photo added here and not yet in the index stays.
    static func photoSetPlan(cloud: [String: Double], removed: [String: Double],
                             local: [String: Double]) -> (fetch: [(String, Double)], drop: [String]) {
        let known = Set(BackdropTheme.photoIDs)
        let fetch = cloud.filter { id, at in known.contains(id) && (local[id].map { have in have + 1 < at } ?? true) }
            .sorted { $0.value < $1.value }.map { ($0.key, $0.value) }
        let drop = local.filter { id, at in cloud[id] == nil && (removed[id].map { $0 >= at } ?? false) }.map(\.key).sorted()
        return (fetch, drop)
    }

    #if canImport(FirebaseFirestore)
    @MainActor
    private func fetch(_ pid: String, childID: UUID, wanted: Double) async {
        let key = Self.slotKey(childID.uuidString, pid)
        let have = defaults.double(forKey: Self.stampKey(key))
        guard !hasPhoto(pid, for: .child(childID)) || have + 1 < wanted, !fetching.contains(key) else { return }
        fetching.insert(key)
        defer { fetching.remove(key) }
        guard let doc = try? await cloud(childID.uuidString).document(pid).getDocument(),
              let data = doc.data()?["data"] as? Data, UIImage(data: data) != nil else { return }
        let stamp = (doc.data()?["updatedAt"] as? NSNumber)?.doubleValue ?? wanted
        guard stamp + 1 >= have else { return }       // never an older picture over a newer one
        store(data, id: pid, ownerKey: childID.uuidString, stamp: stamp)
    }
    #endif
}
