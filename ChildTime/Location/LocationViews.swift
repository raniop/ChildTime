import SwiftUI
import MapKit
import Combine

// MARK: - The map (MapKit, iOS 16)

/// The family map: one marker per child with a fix, one circle per place.
/// `centerPin` mode (the place editor) reports the map's centre as it moves.
struct FamilyMapView: UIViewRepresentable {
    struct Kid: Equatable { let id: String; let initial: String; let girl: Bool; let lat: Double; let lng: Double }
    var kids: [Kid]
    var places: [FamilyPlace]
    /// Centre the camera here once (a child, or the edited place).
    var focus: CLLocationCoordinate2D?
    var focusSpan: Double = 0.02
    /// Off in the place editor: its own centre pin marks the place.
    var showPlaceMarkers = true
    /// The family map: frame every child and place (not one point at a fixed
    /// zoom, which left the circles as specks).
    var fitAll = false
    var onCenterChange: ((CLLocationCoordinate2D) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.pointOfInterestFilter = .excludingAll
        map.layer.cornerRadius = 24
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)
        for p in places {
            let c = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng)
            map.addOverlay(MKCircle(center: c, radius: p.radius))
            guard showPlaceMarkers else { continue }
            let a = Pin(kind: .place(p.emoji)); a.coordinate = c; a.title = p.name
            map.addAnnotation(a)
        }
        for k in kids {
            let a = Pin(kind: .kid(k.initial, k.girl)); a.coordinate = CLLocationCoordinate2D(latitude: k.lat, longitude: k.lng)
            map.addAnnotation(a)
        }
        if fitAll {
            let key = map.annotations.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }.sorted().joined(separator: "|")
            if !key.isEmpty, context.coordinator.focused != key {
                context.coordinator.focused = key
                var rect = MKMapRect.null
                for a in map.annotations {
                    let p = MKMapPoint(a.coordinate)
                    rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
                }
                for o in map.overlays { rect = rect.union(o.boundingMapRect) }
                // At least ~1 km across, so a single child is not shown at street-sign zoom.
                let minSide = MKMapPointsPerMeterAtLatitude(map.annotations[0].coordinate.latitude) * 1000
                if rect.size.width < minSide { rect = rect.insetBy(dx: -(minSide - rect.size.width) / 2, dy: 0) }
                if rect.size.height < minSide { rect = rect.insetBy(dx: 0, dy: -(minSide - rect.size.height) / 2) }
                map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40), animated: false)
            }
        } else if let f = focus, context.coordinator.focused != "\(f.latitude),\(f.longitude)" {
            context.coordinator.focused = "\(f.latitude),\(f.longitude)"
            map.setRegion(MKCoordinateRegion(center: f, span: MKCoordinateSpan(latitudeDelta: focusSpan, longitudeDelta: focusSpan)), animated: false)
        }
    }

    /// A place is just its emoji in a small white dot at the centre of its
    /// circle (Rani: name tags covered the map). The name shows on a tap.
    final class PlaceTagView: MKAnnotationView {
        init(annotation: MKAnnotation?, emoji: String) {
            super.init(annotation: annotation, reuseIdentifier: nil)
            let size: CGFloat = 26
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            dot.backgroundColor = .white
            dot.layer.cornerRadius = size / 2
            dot.layer.shadowColor = UIColor.black.cgColor
            dot.layer.shadowOpacity = 0.18
            dot.layer.shadowRadius = 2
            dot.layer.shadowOffset = CGSize(width: 0, height: 1)
            let label = UILabel(frame: dot.bounds)
            label.text = emoji
            label.font = .systemFont(ofSize: 14)
            label.textAlignment = .center
            dot.addSubview(label)
            addSubview(dot)
            frame = dot.bounds
            canShowCallout = true
            displayPriority = .required
            collisionMode = .none
        }
        required init?(coder: NSCoder) { fatalError() }
    }

    final class Pin: MKPointAnnotation {
        enum Kind { case kid(String, Bool), place(String) }
        let kind: Kind
        init(kind: Kind) { self.kind = kind }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FamilyMapView
        var focused: String?
        init(_ p: FamilyMapView) { parent = p }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? Pin else { return nil }
            switch pin.kind {
            case .kid(let initial, let girl):
                let v = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: nil)
                v.glyphText = initial
                v.markerTintColor = girl ? UIColor(red: 1, green: 0.37, blue: 0.66, alpha: 1) : UIColor(red: 0.02, green: 0.7, blue: 0.54, alpha: 1)
                v.displayPriority = .required
                return v
            case .place(let emoji):
                // A place is a small emoji dot in the middle of its circle —
                // never a second balloon that a child's marker could hide.
                return PlaceTagView(annotation: pin, emoji: emoji)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKCircleRenderer(overlay: overlay)
            r.fillColor = UIColor(red: 0.48, green: 0.36, blue: 0.98, alpha: 0.16)
            r.strokeColor = UIColor(red: 0.48, green: 0.36, blue: 0.98, alpha: 0.7)
            r.lineWidth = 2
            return r
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onCenterChange?(mapView.centerCoordinate)
        }
    }
}

// MARK: - Parent: איפה הילדים

struct ParentLocationView: View {
    /// Open on this child (their card's line, the ⚡ menu, a tapped arrival push).
    var focusChildID: String? = nil
    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var loc = LocationSharing.shared
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var consentFor: Profile?
    @State private var showingPlaces = false
    @State private var now = Date()
    /// childID → the device the parent picked to look at (default: the phone).
    @State private var picked: [String: String] = [:]
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var kids: [Profile] { profiles.profiles }
    private var places: [FamilyPlace] { _ = household.household; return loc.familyPlaces }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    FamilyMapView(kids: mapKids, places: places, focus: mapFocus, focusSpan: 0.012, fitAll: focusChildID == nil)
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 1))
                    ForEach(kids) { p in card(p) }
                }
                .padding(16)
                .readableColumn()
            }
            .background(GlassBackdrop())
            .navigationTitle(tr("איפה הילדים"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(tr("סִיּוּם")) { dismiss() } }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingPlaces = true } label: { Text(tr("📍 מקומות")) }
                }
            }
        }
        .onAppear { loc.watch(childIDs: kids.map { $0.id.uuidString }) }
        .onReceive(ticker) { now = $0 }
        .sheet(item: $consentFor) { p in
            LocationConsentSheet(profile: p).environment(\.layoutDirection, .app)
        }
        .sheet(isPresented: $showingPlaces) {
            PlacesListView().environmentObject(profiles).environment(\.layoutDirection, .app)
        }
        .environment(\.layoutDirection, .app)
    }

    /// Every device with a real fix, for every child who shares.
    private func located(_ p: Profile) -> [ChildLocationFix] {
        guard loc.sharing[p.id.uuidString] == true else { return [] }
        return (loc.fixes[p.id.uuidString] ?? []).filter { $0.accuracy >= 0 }
    }

    /// The device shown for a child: the parent's pick, else the phone (a
    /// tablet usually stays home), else the freshest.
    private func shown(_ p: Profile) -> ChildLocationFix? {
        loc.shownFix(p.id.uuidString, picked: picked[p.id.uuidString])
    }

    private var mapKids: [FamilyMapView.Kid] {
        kids.compactMap { p in
            shown(p).map { f in
                FamilyMapView.Kid(id: p.id.uuidString, initial: String(Question.stripNiqqud(p.name).prefix(1)),
                                  girl: p.gender == .girl, lat: f.lat, lng: f.lng)
            }
        }
    }

    private var mapFocus: CLLocationCoordinate2D? {
        if let id = focusChildID, let k = mapKids.first(where: { $0.id == id }) {
            return CLLocationCoordinate2D(latitude: k.lat, longitude: k.lng)
        }
        if let k = mapKids.first { return CLLocationCoordinate2D(latitude: k.lat, longitude: k.lng) }
        if let p = places.first { return CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng) }
        return nil
    }

    static func deviceName(_ kind: String) -> String {
        switch kind {
        case "iphone": return tr("📱 אייפון")
        case "ipad": return tr("📲 אייפד")
        case "android": return tr("📱 אנדרואיד")
        default: return tr("📱 טלפון")
        }
    }

    @ViewBuilder private func card(_ p: Profile) -> some View {
        let cid = p.id.uuidString
        let name = Question.stripNiqqud(p.name)
        let devices = located(p)
        let current = shown(p)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatarView(profile: p, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    // When the phone was last seen sits by the name (Rani).
                    HStack(alignment: .center, spacing: 7) {
                        Text(name).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(GlassInk.primary)
                        if let f = current {
                            Circle().fill(GlassInk.secondary).frame(width: 4, height: 4)
                            Text(Self.relative(f.at, now: now))
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundStyle(now.timeIntervalSince1970 - f.at < 600 ? Color(hex: "9FF5DD") : GlassInk.secondary)
                        }
                    }
                    Text(statusLine(p))
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if devices.count < 2, let b = current?.battery {
                    Text("🔋 \(Int((b * 100).rounded()))%")
                        .font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.black.opacity(0.18), in: Capsule())
                }
            }
            // "רענון" got no answer within 30 s — say why, instead of nothing.
            if let why = refreshUnanswered(p) {
                Text(why)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFE58A"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Allowed "while using" only: the map works, arrive/leave alerts need
            // "always" — say exactly where that is, once, in the card.
            if current?.permission == "whenInUse" {
                Text(tr("כדי לקבל התראות הגעה: בטלפון של \(name) ← הגדרות ← טופי ← מיקום ← תמיד"))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFE58A"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Two devices (a phone and an iPad): ONE line, and the parent picks
            // which device it is about — the beep goes to the same one. Every
            // device shows its own battery (the iPad at 9% matters too).
            if devices.count > 1, let current {
                HStack(spacing: 8) {
                    ForEach(devices, id: \.deviceID) { f in
                        let on = f.deviceID == current.deviceID
                        Button { Haptic.light(); picked[cid] = f.deviceID } label: {
                            Text(f.battery.map { "\(Self.deviceName(f.kind)) · 🔋 \(Int(($0 * 100).rounded()))%" } ?? Self.deviceName(f.kind))
                                .font(.system(size: 14, weight: .heavy, design: .rounded)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(on ? Color.white.opacity(0.32) : Color.black.opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(on ? Color.white.opacity(0.7) : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            if loc.sharing[cid] == true {
                HStack(spacing: 10) {
                    beepButton(cid: cid, deviceID: devices.count > 1 ? current?.deviceID : nil)
                    Button { Haptic.light(); loc.refresh(childIDs: [cid]) } label: {
                        Text(isRefreshing(cid) ? tr("מרענן…") : tr("↻ רענון"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button { consentFor = p } label: {
                    Text(tr("📍 הפעלת מיקום ל\(name)"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .glassPane(radius: 22, shadow: false)
    }

    private func isRefreshing(_ cid: String) -> Bool {
        guard let at = loc.refreshedAt[cid], now.timeIntervalSince(at) < 30 else { return false }
        let newest = (loc.fixes[cid] ?? []).map(\.at).max() ?? 0
        return newest < at.timeIntervalSince1970 - 5
    }

    /// The parent asked 30 s–10 min ago and no fix came: the honest reason.
    private func refreshUnanswered(_ p: Profile) -> String? {
        let cid = p.id.uuidString
        guard let at = loc.refreshedAt[cid] else { return nil }
        let waited = now.timeIntervalSince(at)
        let newest = (loc.fixes[cid] ?? []).map(\.at).max() ?? 0
        guard waited >= 30, waited < 600, newest < at.timeIntervalSince1970 - 5 else { return nil }
        let name = Question.stripNiqqud(p.name)
        if (loc.fixes[cid] ?? []).contains(where: { $0.permission == "whenInUse" }) {
            return p.gender == .girl
                ? tr("הטלפון של \(name) מאשר מיקום רק בזמן השימוש, ולכן לא עונה לרענון — בטלפון שלה: הגדרות ← טופי ← מיקום ← תמיד")
                : tr("הטלפון של \(name) מאשר מיקום רק בזמן השימוש, ולכן לא עונה לרענון — בטלפון שלו: הגדרות ← טופי ← מיקום ← תמיד")
        }
        return tr("הטלפון של \(name) לא ענה — כנראה הוא כבוי או בלי אינטרנט, או שטופי סגור בו לגמרי. כשטופי ייפתח בו, המיקום יתעדכן")
    }

    /// Rings the device on screen (all of them when the child has one).
    @ViewBuilder private func beepButton(cid: String, deviceID: String?) -> some View {
        let b = loc.beeps[cid]
        let ringing = b.map { !$0.stop && $0.found == nil && now.timeIntervalSince1970 - $0.at < 35 } ?? false
        Button { Haptic.medium(); loc.beep(childID: cid, deviceID: deviceID, stop: ringing) } label: {
            Text(ringing ? tr("⏹ עצירת הצפצוף") : tr("🔔 צפצוף"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(LinearGradient(colors: [Color(hex: "FF5FA8"), Color(hex: "FFA53A")], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// "🏫 בית הספר · מאז 08:02 · לפני 3 דקות", or the street address when the
    /// device is outside every family place.
    private func whereLine(_ f: ChildLocationFix) -> String { loc.whereLine(f) }

    private func statusLine(_ p: Profile) -> String {
        let cid = p.id.uuidString
        let girl = p.gender == .girl
        let name = Question.stripNiqqud(p.name)
        guard loc.sharing[cid] == true else { return tr("המיקום כבוי") }
        if let b = loc.beeps[cid], let found = b.found, now.timeIntervalSince1970 - found < 120 {
            return girl ? tr("✅ \(name) מצאה את הטלפון") : tr("✅ \(name) מצא את הטלפון")
        }
        let all = loc.fixes[cid] ?? []
        guard let f = shown(p) else {
            if all.contains(where: { $0.permission == "denied" }) {
                return tr("המיקום חסום בטלפון של \(name) — מאשרים בהגדרות של הטלפון ← טופי ← מיקום")
            }
            return tr("מחכה לאישור בטלפון של \(name) — פותחים בו את טופי")
        }
        return whereLine(f)
    }

    /// "עכשיו" / "לפני 3 דק׳" / "לפני 2 שע׳" / the date. (The system's own
    /// relative formatter writes "לפני שעה (1)" in Hebrew.)
    static func relative(_ at: Double, now: Date) -> String {
        let secs = Int(now.timeIntervalSince1970 - at)
        if secs < 60 { return tr("עכשיו") }
        if secs < 3600 { return tr("לפני \(secs / 60) דק׳") }
        if secs < 86_400 { return tr("לפני \(secs / 3600) שע׳") }
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        return f.string(from: Date(timeIntervalSince1970: at))
    }
}

// MARK: - Parent: consent

struct LocationConsentSheet: View {
    let profile: Profile
    init(profile: Profile, startEnabled: Bool = false) {
        self.profile = profile
        self.startEnabled = startEnabled
        _enabled = State(initialValue: startEnabled)
    }
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    /// After "אישור": what to do on the child's phone (Rani: the parent could
    /// not guess that the next step happens THERE).
    @State private var enabled = false
    /// DEMO_SCREEN=locconsent DEMO_NEXT=1 — open on the next-step page.
    var startEnabled = false

    var body: some View {
        let name = Question.stripNiqqud(profile.name)
        let girl = profile.gender == .girl
        NavigationStack {
            if enabled { nextStep(name: name, girl: girl) } else {
            ScrollView {
                VStack(spacing: 16) {
                    Text("📍").font(.system(size: 44))
                    Text(tr("לדעת איפה \(name) — בלי לשאול"))
                        .font(.system(size: 22, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 0) {
                        row("🗺️", girl ? tr("מה נשמר: המיקום האחרון של הטלפון שלה, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום.")
                                       : tr("מה נשמר: המיקום האחרון של הטלפון שלו, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום."))
                        row("👪", tr("מי רואה: רק ההורים במשפחה. שום דבר לא עובר לאף גורם אחר."))
                        row("🗑️", tr("אפשר לכבות בכל רגע, והמיקום השמור נמחק מיד."))
                        row("🔋", tr("סוללה: מתעדכן כשהטלפון זז או כשמבקשים — בלי GPS שרץ כל הזמן."), last: true)
                    }
                    .padding(.horizontal, 16)
                    .glassPane(radius: 20, shadow: false)
                    Text(girl ? tr("בטלפון של \(name) יופיע אישור מיקום, והיא תדע שהמיקום שלה גלוי לכם.")
                              : tr("בטלפון של \(name) יופיע אישור מיקום, והוא ידע שהמיקום שלו גלוי לכם."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    Button {
                        saving = true
                        Task {
                            _ = await LocationSharing.shared.setSharing(childID: profile.id.uuidString, on: true)
                            saving = false
                            Haptic.success()
                            withAnimation { enabled = true }
                        }
                    } label: {
                        Text(tr("אישור והפעלת מיקום"))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "4B3BC4"))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(saving)
                }
                .foregroundStyle(.white)
                .padding(18)
                .readableColumn()
            }
            .background(GlassBackdrop())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("ביטול")) { dismiss() } } }
            }
        }
    }

    private func nextStep(name: String, girl: Bool) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("📱").font(.system(size: 48))
                Text(tr("עוד צעד אחד — בטלפון של \(name)"))
                    .font(.system(size: 23, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 0) {
                    step(1, tr("פותחים את טופי בטלפון של \(name)"))
                    step(2, tr("לוחצים \"ממשיכים\" ומאשרים מיקום — ואם שואלים, בוחרים \"תמיד\""))
                    step(3, girl ? tr("זהו — \(name) תופיע כאן על המפה") : tr("זהו — \(name) יופיע כאן על המפה"), last: true)
                }
                .padding(.horizontal, 16)
                .glassPane(radius: 20, shadow: false)
                Text(tr("שלחנו לטלפון של \(name) התראה שמזכירה לפתוח את טופי."))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary).multilineTextAlignment(.center)
                Button { dismiss() } label: {
                    Text(tr("הבנתי"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3BC4"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(18)
            .readableColumn()
        }
        .background(GlassBackdrop())
    }

    private func step(_ n: Int, _ text: String, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.system(size: 15, weight: .black, design: .rounded))
                .frame(width: 28, height: 28).background(Color.white.opacity(0.22), in: Circle())
            Text(text).font(.system(size: 15, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(.white.opacity(0.14)).frame(height: 1) } }
    }

    private func row(_ emoji: String, _ text: String, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 20))
            Text(text).font(.system(size: 14.5, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(.white.opacity(0.14)).frame(height: 1) } }
    }
}

// MARK: - Parent: places

struct PlacesListView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var loc = LocationSharing.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editing: FamilyPlace?
    @State private var confirmStopFor: Profile?

    private var places: [FamilyPlace] { _ = household.household; return loc.familyPlaces }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if places.isEmpty {
                        Text(tr("עוד אין מקומות. הוסיפו את הבית ואת בית הספר, ותקבלו התראה כשהילדים מגיעים ויוצאים."))
                            .font(.system(size: 14.5, weight: .medium, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                    }
                    ForEach(places) { p in
                        Button { editing = p } label: {
                            HStack(spacing: 12) {
                                Text(p.emoji).font(.system(size: 22))
                                Text(p.name).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(GlassInk.primary)
                                Spacer()
                                Text(tr("\(Int(p.radius)) מ׳")).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)
                            }
                        }
                    }
                    Button { editing = newPlace() } label: {
                        Text(tr("＋ הוספת מקום")).font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                } header: { Text(tr("מקומות קבועים")) }
                .glassRows()

                Section {
                    ForEach(profiles.profiles) { p in
                        if loc.sharing[p.id.uuidString] == true {
                            Button { confirmStopFor = p } label: {
                                Text(tr("כיבוי המיקום של \(Question.stripNiqqud(p.name))"))
                                    .foregroundStyle(GlassInk.weak)
                            }
                        }
                    }
                } header: { Text(tr("שיתוף מיקום")) }
                .glassRows()
            }
            .readableColumn()
            .glassForm()
            .navigationTitle(tr("📍 מקומות"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("סִיּוּם")) { dismiss() } } }
        }
        .sheet(item: $editing) { p in
            PlaceEditorView(place: p).environmentObject(profiles).environment(\.layoutDirection, .app)
        }
        .confirmationDialog(tr("לכבות את שיתוף המיקום? המיקום השמור יימחק."), isPresented: Binding(
            get: { confirmStopFor != nil }, set: { if !$0 { confirmStopFor = nil } }), titleVisibility: .visible) {
            Button(tr("כיבוי המיקום"), role: .destructive) {
                if let p = confirmStopFor { Task { _ = await loc.setSharing(childID: p.id.uuidString, on: false) } }
                confirmStopFor = nil
            }
        }
    }

    private func newPlace() -> FamilyPlace {
        // Start where a child is now, else at the first place, else Tel Aviv.
        let fix = profiles.profiles.flatMap { loc.fixes[$0.id.uuidString] ?? [] }.first { $0.accuracy >= 0 }
        var alerts: [String: FamilyPlace.PlaceAlert] = [:]
        for p in profiles.profiles { alerts[p.id.uuidString] = .init(arrive: true, leave: false) }
        return FamilyPlace(name: "", emoji: "🏠", lat: fix?.lat ?? places.first?.lat ?? 32.0853,
                           lng: fix?.lng ?? places.first?.lng ?? 34.7818, alerts: alerts)
    }
}

struct PlaceEditorView: View {
    @State var place: FamilyPlace
    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var focus: CLLocationCoordinate2D?
    @State private var saving = false

    private static let emojis = ["🏠", "🏫", "⚽", "🎨", "🎵", "👵", "🏊", "📍"]
    private static var defaultNames: [String: String] {
        ["🏠": tr("הבית"), "🏫": tr("בית הספר"), "⚽": tr("חוג"), "👵": tr("סבא וסבתא"), "🏊": tr("בריכה")]
    }
    private var isNew: Bool { !LocationSharing.shared.familyPlaces.contains { $0.id == place.id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        TextField(tr("חיפוש כתובת או מקום"), text: $query)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).frame(height: 46)
                            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onSubmit { search() }
                        Button(tr("חיפוש")) { search() }.font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(results.prefix(4), id: \.self) { item in
                                Button {
                                    let c = item.placemark.coordinate
                                    place.lat = c.latitude; place.lng = c.longitude
                                    focus = c; results = []
                                    if place.name.isEmpty { place.name = item.name ?? "" }
                                } label: {
                                    Text([item.name, item.placemark.thoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .glassPane(radius: 16, shadow: false)
                    }
                    ZStack {
                        FamilyMapView(kids: [], places: [place], focus: focus, focusSpan: 0.008, showPlaceMarkers: false) { c in
                            place.lat = c.latitude; place.lng = c.longitude
                        }
                        Text("📍").font(.system(size: 34)).offset(y: -16).allowsHitTesting(false)
                    }
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(tr("הזיזו את המפה כך שהסיכה על המקום"))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("שם המקום")).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.secondary)
                        TextField(tr("למשל: בית הספר"), text: $place.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 14).frame(height: 46)
                            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        HStack(spacing: 6) {
                            ForEach(Self.emojis, id: \.self) { e in
                                Button {
                                    // An empty name takes the obvious one, in the app's language.
                                    if place.name.trimmingCharacters(in: .whitespaces).isEmpty || Self.defaultNames.values.contains(place.name) {
                                        place.name = Self.defaultNames[e] ?? place.name
                                    }
                                    place.emoji = e
                                } label: {
                                    Text(e).font(.system(size: 22)).frame(maxWidth: .infinity, minHeight: 40)
                                        .background((place.emoji == e ? AppColor.successMint.opacity(0.5) : Color.white.opacity(0.1)),
                                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(tr("גודל האזור")).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.secondary)
                        HStack(spacing: 8) {
                            ForEach(FamilyPlace.radii, id: \.self) { r in
                                Button { place.radius = r } label: {
                                    Text(tr("\(Int(r)) מ׳")).font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .frame(maxWidth: .infinity, minHeight: 42)
                                        .background((place.radius == r ? AppColor.successMint.opacity(0.45) : Color.white.opacity(0.12)),
                                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .glassPane(radius: 20, shadow: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("התראות על המקום הזה")).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.secondary)
                        ForEach(profiles.profiles) { p in alertRow(p) }
                    }
                    .padding(14)
                    .glassPane(radius: 20, shadow: false)

                    if !isNew {
                        Button(role: .destructive) { save(delete: true) } label: {
                            Text(tr("מחיקת המקום")).font(.system(size: 15, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .foregroundStyle(GlassInk.weak)
                    }
                }
                .foregroundStyle(.white)
                .padding(16)
                .readableColumn()
            }
            .background(GlassBackdrop())
            .navigationTitle(isNew ? tr("מקום חדש") : place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("ביטול")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("שמירה")) { save(delete: false) }
                        .disabled(saving || place.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { focus = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng) }
    }

    /// Rani: "התראה כש… — לא מובן מה לעשות". Two plain switches per child,
    /// each a whole sentence.
    private func alertRow(_ p: Profile) -> some View {
        let cid = p.id.uuidString
        let girl = p.gender == .girl
        let name = Question.stripNiqqud(p.name)
        let a = place.alerts[cid] ?? .init(arrive: false, leave: false)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ProfileAvatarView(profile: p, size: 28)
                Text(name).font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .padding(.top, 6)
            Toggle(isOn: Binding(get: { a.arrive }, set: { place.alerts[cid] = .init(arrive: $0, leave: a.leave) })) {
                Text(girl ? tr("להודיע לי כש\(name) מגיעה לכאן") : tr("להודיע לי כש\(name) מגיע לכאן"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .tint(AppColor.successMint)
            Toggle(isOn: Binding(get: { a.leave }, set: { place.alerts[cid] = .init(arrive: a.arrive, leave: $0) })) {
                Text(girl ? tr("להודיע לי כש\(name) יוצאת מכאן") : tr("להודיע לי כש\(name) יוצא מכאן"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .tint(AppColor.successMint)
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng),
                                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        MKLocalSearch(request: req).start { resp, _ in results = resp?.mapItems ?? [] }
    }

    private func save(delete: Bool) {
        saving = true
        var all = LocationSharing.shared.familyPlaces
        all.removeAll { $0.id == place.id }
        if !delete {
            place.name = place.name.trimmingCharacters(in: .whitespaces)
            all.append(place)
        }
        Task {
            _ = await LocationSharing.shared.savePlaces(all)
            saving = false
            dismiss()
        }
    }
}

// MARK: - Child: the one-time explanation before Apple's question

struct KidLocationPermissionSheet: View {
    @ObservedObject private var loc = LocationSharing.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let girl = Gendered.isGirl
        VStack(spacing: 22) {
            Spacer(minLength: 20)
            ZStack(alignment: .topTrailing) {
                Text("📍").font(.system(size: 76))
            }
            Text(Gendered.g(tr("אַבָּא וְאִמָּא יִרְאוּ אֵיפֹה אַתָּה"), tr("אַבָּא וְאִמָּא יִרְאוּ אֵיפֹה אַתְּ")))
                .font(.system(size: 26, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            Text(girl ? tr("כְּשֶׁהַטֵּלֵפוֹן זָז, הַהוֹרִים שֶׁלָּךְ יוֹדְעִים שֶׁהִגַּעַתְּ בְּשָׁלוֹם — לְבֵית הַסֵּפֶר, הַבַּיְתָה אוֹ לַחוּג.")
                      : tr("כְּשֶׁהַטֵּלֵפוֹן זָז, הַהוֹרִים שֶׁלְּךָ יוֹדְעִים שֶׁהִגַּעְתָּ בְּשָׁלוֹם — לְבֵית הַסֵּפֶר, הַבַּיְתָה אוֹ לַחוּג."))
                .font(.system(size: 17, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
            Text(girl ? tr("👉 בַּמָּסָךְ הַבָּא הַטֵּלֵפוֹן יִשְׁאַל — לִחְצִי עַל הָאִשּׁוּר")
                      : tr("👉 בַּמָּסָךְ הַבָּא הַטֵּלֵפוֹן יִשְׁאַל — לְחַץ עַל הָאִשּׁוּר"))
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .padding(14).frame(maxWidth: .infinity)
                .glassPane(radius: 18, shadow: false)
            Spacer()
            Button {
                Haptic.light()
                loc.requestPermission()
                dismiss()
            } label: {
                Text(tr("מַמְשִׁיכִים ←"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "6C4DF0"))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(26)
        .readableColumn()
        .background(GlassBackdrop())
        .interactiveDismissDisabled()
    }
}

// MARK: - Child: 🔔 "מְחַפְּשִׂים אֶת הַטֵּלֵפוֹן!"

struct KidBeepOverlay: View {
    @ObservedObject private var loc = LocationSharing.shared

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text("🔔").font(.system(size: 90))
            Text(tr("מְחַפְּשִׂים אֶת הַטֵּלֵפוֹן!"))
                .font(.system(size: 30, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            Text(tr("אַבָּא אוֹ אִמָּא בִּקְּשׁוּ לְצַפְצֵף כְּדֵי לִמְצֹא אוֹתוֹ"))
                .font(.system(size: 17, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
            Spacer()
            Button {
                Haptic.success()
                loc.stopBeep(report: true)
            } label: {
                Text(tr("מָצָאתִי! 👋"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "6C4DF0"))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: "FF5FA8"), Color(hex: "B25BEA"), Color(hex: "6C4DF0")],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

// MARK: - Shared by the map and the parent home's location line

extension LocationSharing {
    /// The device shown for a child: the parent's pick, else the phone (a
    /// tablet usually stays home), else the freshest. nil = not sharing / no fix.
    func shownFix(_ childID: String, picked: String? = nil) -> ChildLocationFix? {
        guard sharing[childID] == true else { return nil }
        let all = (fixes[childID] ?? []).filter { $0.accuracy >= 0 }
        if let id = picked, let f = all.first(where: { $0.deviceID == id }) { return f }
        return all.first { $0.kind != "ipad" } ?? all.first
    }

    /// "🏫 בית הספר · מאז 08:02", or the street address when the device is
    /// outside every family place. (How fresh it is sits beside, not inside.)
    func whereLine(_ f: ChildLocationFix) -> String {
        // The child's phone names the place when it writes the fix; the parent
        // also checks here, so a place added after the phone last moved (or a
        // fix a little off indoors) still reads "🏠 הבית" and not a street.
        let reported = f.placeID.flatMap { id in familyPlaces.first { $0.id == id } }
        if let place = reported ?? FamilyPlace.place(at: f.lat, f.lng, in: familyPlaces, slack: f.accuracy) {
            if let s = f.placeSince, reported != nil {
                return tr("\(place.emoji) \(place.name) · מאז \(QuietHoursManager.clock(Date(timeIntervalSince1970: s)))")
            }
            return "\(place.emoji) \(place.name)"
        }
        if let a = address(for: f) { return "📍 \(a)" }
        return tr("📍 מחפשים כתובת…")
    }
}
