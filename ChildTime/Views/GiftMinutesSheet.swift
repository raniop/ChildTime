import SwiftUI

/// 💝 Gift minutes, from the child's card on the home screen (Rani approved the
/// mockup 2026-10-12: "הייתי מוסיף מתנה לעמוד הראשי… ומשם פותח חלון יפה עם
/// הסבר וכמה דקות במתנה כבר נתתי"). One window, top to bottom: what a gift
/// is · what was already given · the ring that sets the minutes · send.
///
/// Sending opens nothing: the SAME screen stays, the send button gives its
/// place to one live status line (sending → saved → reached the device), and
/// the ring keeps showing what was sent (Rani, 2026-10-12: "פתרון יפה בתוך
/// המסך ששולחים, ולא שייפתח מסך שלישי").
struct GiftMinutesSheet: View {
    let profile: Profile
    /// Minutes the parents gave today, and gift minutes still waiting unopened.
    let givenToday: Int
    let waiting: Int
    /// The most one gift may hold right now (the minutes left until midnight).
    let capLeft: Int
    /// Sends the gift; returns the status to show, or nil when nothing was sent.
    let onSend: (Int) -> RemoteCommandStatusRequest?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var remote = RemoteSyncManager.shared
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @State private var minutes = 30
    /// The minutes that were sent — nil until "שליחה" is pressed.
    @State private var sentMinutes: Int?
    /// What was given BEFORE this window opened. `givenToday` is live: once the
    /// child's device takes the gift it grows by itself, and adding what was
    /// just sent on top of that would count the same minutes twice.
    @State private var givenAtOpen: Int?

    private var name: String { Question.stripNiqqud(profile.name) }
    private var girl: Bool { profile.gender == .girl }
    /// One full turn of the ring. More than that is a second gift.
    static let ringMinutes = 120
    private var ceiling: Int { max(5, min(Self.ringMinutes, capLeft / 5 * 5)) }

    var body: some View {
        chooser
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environment(\.layoutDirection, .app)
            .onAppear {
                minutes = min(minutes, ceiling)
                if givenAtOpen == nil { givenAtOpen = givenToday }
            }
    }

    private var chooser: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(verbatim: "💝")
                    .font(.system(size: 54))
                    .shadow(color: Color(hex: "FF5F9A").opacity(0.55), radius: 14, y: 8)
                    .padding(.top, 6)
                Text(tr("מתנת דקות ל\(name)"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(girl
                     ? tr("זמן מסך שאתם נותנים מהלב — בלי שאלות. \(name) פותחת אותו מתי שהיא רוצה.")
                     : tr("זמן מסך שאתם נותנים מהלב — בלי שאלות. \(name) פותח אותו מתי שהוא רוצה."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    stat((givenAtOpen ?? givenToday) + (sentMinutes ?? 0), tr("נתתם היום"))
                    stat(waiting, tr("עוד לא נוצלו"))   // "מחכות לנוני" was not clear (Rani)
                }

                GiftRing(minutes: $minutes, ceiling: ceiling, locked: sentMinutes != nil)
                    .frame(width: 250, height: 250)
                    .padding(.vertical, 4)

                if sentMinutes != nil {
                    // One line that tells the truth as it changes, where the button was.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in statusLine }
                    Button { dismiss() } label: {
                        Text(tr("סיום"))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "4B3FBF"))
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        if let status = onSend(minutes), case .gift(let allowed, _) = status.kind {
                            withAnimation(.easeInOut(duration: 0.25)) { sentMinutes = allowed; minutes = allowed }
                        }
                    } label: {
                        Text("💝 " + tr("שליחת \(minutes) דקות"))
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "3A2700"))
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color(hex: "F7B63A").opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)

                    Text(tr("דקות מתנה שלא נוצלו היום נשמרות למחר."))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 24)
            .frame(maxWidth: 460).frame(maxWidth: .infinity)
            .foregroundStyle(GlassInk.primary)
        }
        .background(GlassBackdrop().ignoresSafeArea())
        // ✕ where it was approved — the reading-leading corner — except on the
        // foldable, where that corner can be the clock's: a tap there never
        // arrives (measured 2026-10-12: in Hebrew the ✕ sat under the clock).
        // Laid out left-to-right so the corner is the PHYSICAL one.
        .overlay {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GlassInk.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סגירה"))
            .padding(.horizontal, 14).padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: closeOnLeft ? .topLeading : .topTrailing)
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// Which physical corner holds the ✕.
    private var closeOnLeft: Bool {
        if display.hasBarStrip { return !display.barOnLeft }
        return !LanguageStore.shared.current.isRightToLeft
    }

    // MARK: - After sending

    /// After this long without a backend commit, THIS phone has no internet; after
    /// this long without the device's word, it is not reachable right now.
    private static let cloudTimeout: TimeInterval = 8
    private static let deviceTimeout: TimeInterval = 45

    /// Where the gift is right now — the furthest hop that is KNOWN, never assumed
    /// (the same chain `RemoteCommandStatusSheet` shows, in one line).
    @ViewBuilder private var statusLine: some View {
        let send = remote.giftSendTracker[profile.id]
        let devices = household.devicesByChild[profile.id.uuidString] ?? []
        let elapsed = Date().timeIntervalSince(send?.sentAt ?? Date())
        if send?.failed == true {
            status("exclamationmark.triangle.fill", GlassInk.weak, tr("המתנה לא נשלחה"), tr("משהו חסם את השליחה. נסו שוב עוד רגע."))
        } else if send?.applied == true {
            status("checkmark.circle.fill", GlassInk.good, tr("המתנה הגיעה למכשיר של \(profile.name) ✓"), nil)
        } else if send?.reachedCloud == true {
            if devices.isEmpty {
                status("checkmark.icloud.fill", GlassInk.good, tr("המתנה נשלחה ונשמרה"), tr("המתנה תופיע ברגע שמכשיר יתחבר."))
            } else if elapsed < Self.deviceTimeout {
                status(nil, GlassInk.good, tr("המתנה נשלחה ונשמרה"), tr("ממתין למכשיר של \(profile.name)…"))
            } else {
                status("checkmark.icloud.fill", GlassInk.good, tr("המתנה נשלחה ונשמרה"), tr("המכשיר של \(profile.name) לא מחובר כרגע"))
            }
        } else if elapsed < Self.cloudTimeout {
            status(nil, GlassInk.primary, tr("שולח מתנה…"), nil)
        } else {
            status("wifi.slash", GlassInk.warn, tr("אין חיבור אינטרנט במכשיר שלך"),
                   tr("המתנה שמורה ותישלח אוטומטית ברגע שיחזור החיבור — אין צורך ללחוץ שוב."))
        }
    }

    /// `icon` nil = still in motion (a spinner).
    private func status(_ icon: String?, _ tint: Color, _ title: String, _ detail: String?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .glassPane(radius: 16, strength: 0.16, shadow: false)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
                Text(tr("דק׳"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .glassPane(radius: 16, strength: 0.14, shadow: false)
    }
}

/// The ring that sets the minutes: drag around it, five minutes a step, a tick
/// in the finger at each. A full turn is two hours — or less, late in the day,
/// when fewer minutes are left until midnight.
struct GiftRing: View {
    @Binding var minutes: Int
    let ceiling: Int
    /// After sending the ring shows what was sent and no longer turns.
    var locked = false

    private let line: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = (side - line) / 2 - 8
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let fraction = CGFloat(minutes) / CGFloat(GiftMinutesSheet.ringMinutes)
            let angle = Angle.degrees(Double(fraction) * 360 - 90)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: line)
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .trim(from: 0, to: max(0.004, fraction))
                    .stroke(AngularGradient(colors: [Color(hex: "FFE07A"), Color(hex: "FF9F5A"), Color(hex: "FF5F9A"), Color(hex: "FFE07A")],
                                            center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .fill(.white)
                    .opacity(locked ? 0 : 1)
                    .frame(width: line + 12, height: line + 12)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                    .position(x: centre.x + radius * CGFloat(cos(angle.radians)),
                              y: centre.y + radius * CGFloat(sin(angle.radians)))
                VStack(spacing: 0) {
                    Text(locked ? tr("נשלחו") : tr("מסובבים באצבע"))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    Text("\(minutes)")
                        .font(.system(size: 68, weight: .heavy, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text(tr("דקות"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                .foregroundStyle(GlassInk.primary)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard !locked else { return }
                set(Self.minutes(at: value.location, centre: centre, ceiling: ceiling, from: minutes))
            })
        }
        // The ring turns clockwise from the top in every language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(tr("מתנת דקות"))
        .accessibilityValue(tr("\(minutes) דקות"))
        .accessibilityAdjustableAction { direction in
            set(minutes + (direction == .increment ? 5 : -5))
        }
    }

    private func set(_ value: Int) {
        let clamped = min(ceiling, max(5, value))
        guard clamped != minutes else { return }
        minutes = clamped
        Haptic.selection()
    }

    /// The minutes under a finger: clockwise from the top, in steps of five,
    /// between 5 and the ceiling. Crossing the top does not jump from a full
    /// ring to an empty one (or back) — the ring stops at its end.
    static func minutes(at point: CGPoint, centre: CGPoint, ceiling: Int, from current: Int,
                        ring: Int = GiftMinutesSheet.ringMinutes) -> Int {
        var degrees = atan2(point.y - centre.y, point.x - centre.x) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        var value = Int((Double(degrees) / 360 * Double(ring) / 5).rounded()) * 5
        let quarter = ring / 4
        if current >= ring - quarter, value <= quarter { value = ring }        // past the top going forward
        else if current <= quarter, value >= ring - quarter { value = 5 }     // past the top going back
        return min(ceiling, max(5, value))
    }
}
