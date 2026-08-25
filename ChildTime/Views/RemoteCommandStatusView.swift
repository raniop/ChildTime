import SwiftUI

/// Live, HONEST status for a remote lock (and optional gift-revoke) the parent
/// just sent — replaces the old optimistic alert ("הנעילה תוחל מיד…") that
/// claimed success regardless of what actually happened.
///
/// The truth chain it renders, each hop verified, none assumed:
///   שולח… → ☁️ הגיע לענן (Firestore backend commit, not local queue)
///         → ⏳ ממתין למכשיר → ✅ המכשיר אישר (the device's `…AppliedAt` ack)
/// plus honest fallbacks: parent offline, child device offline (with last-seen),
/// no device connected at all. If the ack arrives after the parent left, the
/// Cloud Function's "בוצע" push closes the loop — the sheet says so.
struct RemoteCommandStatusRequest: Identifiable {
    let id = UUID()
    let profile: Profile
    /// The action also wipes all parent-given minutes ("נעל ואפס דקות מתנה").
    let includesGiftRevoke: Bool
}

struct RemoteCommandStatusSheet: View {
    let request: RemoteCommandStatusRequest
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var remote = RemoteSyncManager.shared
    @Environment(\.dismiss) private var dismiss

    private var profile: Profile { request.profile }

    /// After this long without a device ack, stop spinning and tell the truth:
    /// the device is not reachable right now.
    private static let deviceTimeout: TimeInterval = 45
    /// After this long without a backend commit, the PARENT's own device has no
    /// internet — say that instead of an eternal spinner.
    private static let cloudTimeout: TimeInterval = 8

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content
        }
    }

    private var content: some View {
        let tracker = household.commandTracker[profile.id.uuidString]
        let revoke = remote.giftRevokeTracker[profile.id]
        let devices = household.devicesByChild[profile.id.uuidString] ?? []

        return VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.35)).frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("🔒 נעילה מרחוק — \(profile.name)")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                cloudRow(tracker: tracker, revoke: revoke)

                if let tracker {
                    if tracker.targetDeviceIDs.isEmpty {
                        statusRow(icon: "iphone.slash", tint: .orange,
                                  title: "אין מכשיר מחובר ל\(profile.name)",
                                  detail: "הנעילה תחול ברגע שמכשיר יתחבר לילד.")
                    } else {
                        ForEach(tracker.targetDeviceIDs, id: \.self) { deviceID in
                            deviceRow(deviceID: deviceID, tracker: tracker, devices: devices)
                        }
                    }
                }

                if request.includesGiftRevoke {
                    giftRow(revoke: revoke)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))

            Text("אפשר לסגור — אם האישור יגיע אחר כך, תקבלו התראה ברגע שהמכשיר יינעל.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                dismiss()
            } label: {
                Text("הבנתי")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Rows

    /// Hop 1: did the command actually reach the cloud (or is the PARENT offline)?
    @ViewBuilder
    private func cloudRow(tracker: HouseholdManager.RemoteCommandTracker?,
                          revoke: RemoteSyncManager.GiftRevokeTracker?) -> some View {
        // The lock tracker is the primary signal; a revoke-only flow falls back to its tracker.
        let reached = tracker?.reachedCloud ?? revoke?.reachedCloud ?? false
        let sentAt = tracker?.sentAt ?? revoke?.sentAt ?? Date()
        let elapsed = Date().timeIntervalSince(sentAt)

        if reached {
            statusRow(icon: "checkmark.icloud.fill", tint: .green,
                      title: "הפקודה נשלחה", detail: nil)
        } else if elapsed < Self.cloudTimeout {
            spinnerRow(title: "שולח…")
        } else {
            statusRow(icon: "wifi.slash", tint: .orange,
                      title: "אין חיבור אינטרנט במכשיר שלך",
                      detail: "הפקודה שמורה ותישלח אוטומטית ברגע שיחזור החיבור — אין צורך ללחוץ שוב.")
        }
    }

    /// Hop 2: one row per target device — waiting / acked / unreachable.
    @ViewBuilder
    private func deviceRow(deviceID: String,
                           tracker: HouseholdManager.RemoteCommandTracker,
                           devices: [ChildDevice]) -> some View {
        let row = devices.first { $0.id == deviceID }
        let name = row?.name ?? "מכשיר"
        let acked = (row?.remoteLockAppliedAt ?? 0) >= tracker.stamp
        let elapsed = Date().timeIntervalSince(tracker.sentAt)

        if acked {
            statusRow(icon: "lock.fill", tint: .green,
                      title: "\(name) — ננעל ✓",
                      detail: "המכשיר אישר את הנעילה.")
        } else if elapsed < Self.deviceTimeout {
            spinnerRow(title: "\(name) — ממתין לאישור מהמכשיר…")
        } else {
            statusRow(icon: "moon.zzz.fill", tint: .orange,
                      title: "\(name) — לא מחובר כרגע",
                      detail: "נראה לאחרונה \(relativeLastSeen(row?.lastSeenAt)). הנעילה שמורה ותחול ברגע שיתחבר — ואז תקבלו התראה.")
        }
    }

    /// Hop 2b: the gift-minutes wipe ack (rides the children doc, not the device row).
    @ViewBuilder
    private func giftRow(revoke: RemoteSyncManager.GiftRevokeTracker?) -> some View {
        let elapsed = Date().timeIntervalSince(revoke?.sentAt ?? Date())

        if revoke?.applied == true {
            statusRow(icon: "gift.fill", tint: .green,
                      title: "דקות המתנה נמחקו ✓",
                      detail: "המכשיר של \(profile.name) אישר את המחיקה.")
        } else if elapsed < Self.deviceTimeout {
            spinnerRow(title: "מוחק דקות מתנה — ממתין לאישור…")
        } else {
            statusRow(icon: "gift", tint: .orange,
                      title: "מחיקת דקות המתנה ממתינה למכשיר",
                      detail: "תתבצע ברגע שהמכשיר של \(profile.name) יתחבר.")
        }
    }

    // MARK: - Row building blocks

    private func statusRow(icon: String, tint: Color, title: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spinnerRow(title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().frame(width: 28)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relativeLastSeen(_ date: Date?) -> String {
        guard let date else { return "לא ידוע" }
        let fmt = RelativeDateTimeFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
