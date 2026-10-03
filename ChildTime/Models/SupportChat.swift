import Foundation
import Combine
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// 💬 Live support chat — a parent talks to צוות טופי (Rani + Amit) without
/// leaving the app (Kids Category 1.3: no links out). One chat per household:
///
///   supportChats/{householdID}               summary — written ONLY by the
///                                            `onSupportMessage` Cloud Function
///   supportChats/{householdID}/messages/{id} { text, from, senderUID, senderName, at }
///
/// Parents never see who on the team answered: every team bubble on the parent
/// side, and every parent push, says only "צוות טופי". The team's own inbox
/// shows the name (`senderName`).

/// The team: the founders' accounts. Mirrors `ADMIN_EMAILS` in
/// functions/index.js and `supportTeam()` in firestore.rules — the server is
/// the real gate; this only decides whether the inbox button is shown.
enum SupportTeam {
    static let emails: Set<String> = ["ranioph@gmail.com", "amitgolans@gmail.com"]

    @MainActor static var isCurrentUser: Bool {
        guard AuthManager.shared.isRealAccount, let mail = AuthManager.shared.email else { return false }
        return emails.contains(mail.lowercased())
    }
}

struct SupportMessage: Identifiable, Equatable {
    enum Sender: String { case parent, team }
    var id: String
    var text: String
    var from: Sender
    var senderUID: String
    var senderName: String
    /// nil only for a moment: our own write before the server stamps it.
    var at: Date?
    var pending: Bool = false

    #if canImport(FirebaseFirestore)
    init?(_ doc: DocumentSnapshot) {
        // `.estimate` so our own just-sent message has a time (and a place in
        // the order) before the server's timestamp comes back.
        guard let d = doc.data(with: .estimate),
              let text = d["text"] as? String,
              let from = Sender(rawValue: d["from"] as? String ?? "") else { return nil }
        id = doc.documentID
        self.text = text
        self.from = from
        senderUID = d["senderUID"] as? String ?? ""
        senderName = d["senderName"] as? String ?? ""
        at = (d["at"] as? Timestamp)?.dateValue()
        pending = doc.metadata.hasPendingWrites
    }
    #endif
}

struct SupportChatSummary: Identifiable, Equatable {
    var id: String            // householdID
    var familyName: String
    var kidsSummary: String
    var parentName: String
    var lastText: String
    var lastFrom: String
    var lastAt: Date?
    var needsReply: Bool

    #if canImport(FirebaseFirestore)
    init(_ doc: DocumentSnapshot) {
        let d = doc.data(with: .estimate) ?? [:]
        id = doc.documentID
        familyName = d["familyName"] as? String ?? ""
        kidsSummary = d["kidsSummary"] as? String ?? ""
        parentName = d["parentName"] as? String ?? ""
        lastText = d["lastText"] as? String ?? ""
        lastFrom = d["lastFrom"] as? String ?? ""
        lastAt = (d["lastAt"] as? Timestamp)?.dateValue()
        needsReply = d["needsReply"] as? Bool ?? false
    }
    #endif
}

/// Where a tap (a button or a notification) wants to land.
enum SupportChatRoute: Identifiable, Equatable {
    /// The parent's own chat with the team.
    case parent(householdID: String)
    /// The team's list of every chat.
    case inbox
    /// The team, inside one family's thread.
    case teamThread(householdID: String)

    var id: String {
        switch self {
        case .parent(let h): return "parent.\(h)"
        case .inbox: return "inbox"
        case .teamThread(let h): return "team.\(h)"
        }
    }
}

@MainActor
final class SupportChatStore: ObservableObject {
    static let shared = SupportChatStore()

    /// Team replies the parent hasn't opened yet (badge on 💬).
    @Published private(set) var parentUnread = 0
    /// Every chat, newest first — team accounts only.
    @Published private(set) var teamChats: [SupportChatSummary] = []
    /// What the dashboard should present (set by taps and by notification taps).
    @Published var route: SupportChatRoute?
    /// The thread on screen right now — its pushes don't need a banner.
    var visibleHouseholdID: String?
    /// A parent tapped a "צוות טופי ענו לכם" push before the family loaded
    /// (cold launch) — open their chat as soon as it has.
    private var wantsParentChat = false

    /// Chats whose last word is the parent's — the team's red badge.
    var teamAwaitingReply: Int { teamChats.filter(\.needsReply).count }

    static let textLimit = 2000

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var parentListener: ListenerRegistration?
    private var parentListenerHousehold: String?
    private var teamListener: ListenerRegistration?

    /// Badge for the parent's own chat. Safe to call on every appear.
    func startParent(householdID: String?) {
        guard !HouseholdManager.skipsCloudSync, AuthManager.shared.isRealAccount,
              let householdID, !householdID.isEmpty else { return }
        if wantsParentChat {
            wantsParentChat = false
            route = .parent(householdID: householdID)
        }
        if parentListenerHousehold == householdID, parentListener != nil { return }
        parentListener?.remove()
        parentListenerHousehold = householdID
        parentListener = db.collection("supportChats").document(householdID)
            .addSnapshotListener { [weak self] snap, error in
                if let error { print("[Support] chat listen failed: \(error.localizedDescription)"); return }
                let n = (snap?.data()?["parentUnread"] as? NSNumber)?.intValue ?? 0
                Task { @MainActor in
                    guard let self else { return }
                    self.parentUnread = max(0, n)
                    // Already reading this chat → it's read.
                    if n > 0, self.visibleHouseholdID == householdID, case .parent = self.route {
                        self.markParentRead(householdID: householdID)
                    }
                }
            }
    }

    /// The team's inbox. Does nothing for anyone else.
    func startTeamIfNeeded() {
        guard !HouseholdManager.skipsCloudSync, SupportTeam.isCurrentUser, teamListener == nil else { return }
        teamListener = db.collection("supportChats")
            .order(by: "lastAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snap, error in
                if let error { print("[Support] inbox listen failed: \(error.localizedDescription)"); return }
                let chats = (snap?.documents ?? []).map { SupportChatSummary($0) }
                Task { @MainActor in self?.teamChats = chats }
            }
    }

    func stop() {
        parentListener?.remove(); parentListener = nil; parentListenerHousehold = nil
        teamListener?.remove(); teamListener = nil
        parentUnread = 0
        teamChats = []
    }

    /// The parent opened their chat — clear the counter (only when there is one:
    /// before the first message there is no chat doc to update).
    func markParentRead(householdID: String) {
        guard parentUnread > 0 else { return }
        parentUnread = 0
        db.collection("supportChats").document(householdID).updateData([
            "parentUnread": 0,
            "parentReadAt": FieldValue.serverTimestamp(),
        ]) { err in
            if let err { print("[Support] mark read failed: \(err.localizedDescription)") }
        }
    }

    func messagesQuery(householdID: String) -> CollectionReference {
        db.collection("supportChats").document(householdID).collection("messages")
    }

    /// Send one message into a family's thread. Firestore queues it offline and
    /// delivers later; the bubble shows at once (pending) either way.
    /// Returns false only when the server REJECTED it.
    @discardableResult
    func send(_ raw: String, householdID: String, asTeam: Bool) async -> Bool {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.textLimit))
        guard !text.isEmpty, let uid = AuthManager.shared.userID else { return false }
        var data: [String: Any] = [
            "text": text,
            "from": asTeam ? "team" : "parent",
            "senderUID": uid,
            "at": FieldValue.serverTimestamp(),
        ]
        data["senderName"] = asTeam ? Self.teamSenderName : String((AuthManager.shared.displayName ?? "").prefix(80))
        let ref = messagesQuery(householdID: householdID).document()
        let outcome = await confirmedSet(ref, data)
        if outcome == .denied, !asTeam {
            // A parent who lost their place in parentUIDs (the duplicate-child
            // era) — re-assert membership once and retry.
            if await HouseholdManager.shared.reassertMembership() {
                return await confirmedSet(ref, data) != .denied
            }
            return false
        }
        return outcome != .denied && outcome != .error
    }

    /// `setData` (not merge) that waits for the server like `confirmedMerge`.
    private func confirmedSet(_ ref: DocumentReference, _ data: [String: Any],
                              timeout: TimeInterval = 4) async -> ConfirmedWriteOutcome {
        await withCheckedContinuation { (cont: CheckedContinuation<ConfirmedWriteOutcome, Never>) in
            let latch = WriteLatch()
            let assumeQueued = DispatchWorkItem { if latch.fire() { cont.resume(returning: .queued) } }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: assumeQueued)
            ref.setData(data) { err in
                assumeQueued.cancel()
                guard latch.fire() else { return }
                if let err = err as NSError? {
                    let denied = err.domain == FirestoreErrorDomain && err.code == 7
                    cont.resume(returning: denied ? .denied : .error)
                } else {
                    cont.resume(returning: .ok)
                }
            }
        }
    }
    #else
    func startParent(householdID: String?) {}
    func startTeamIfNeeded() {}
    func stop() {}
    func markParentRead(householdID: String) {}
    @discardableResult
    func send(_ raw: String, householdID: String, asTeam: Bool) async -> Bool { false }
    #endif

    // MARK: - Reply straight from the notification (team)

    /// The team typed a reply into the notification's "הָשֵׁב" field. iOS may
    /// have woken the app in the background just for this, so: one HTTPS call
    /// to the `supportReply` callable (server checks the team account), held
    /// open by a background task until it answers. A queued Firestore write
    /// could sit unsent until the next launch.
    func replyFromNotification(householdID: String, text raw: String) async -> Bool {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.textLimit))
        guard !text.isEmpty, !householdID.isEmpty else { return false }
        let app = UIApplication.shared
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = app.beginBackgroundTask(withName: "support.reply") {
            if taskID != .invalid { app.endBackgroundTask(taskID); taskID = .invalid }
        }
        defer { if taskID != .invalid { app.endBackgroundTask(taskID); taskID = .invalid } }
        let ok = await callSupportReply(householdID: householdID, text: text)
        let content = UNMutableNotificationContent()
        content.title = ok ? tr("✅ הַתְּשׁוּבָה נִשְׁלְחָה") : tr("הַתְּשׁוּבָה לֹא נִשְׁלְחָה")
        content.body = ok ? text : tr("פִּתְחוּ אֶת הַשִּׂיחָה בָּאַפְּלִיקַצְיָה וְנַסּוּ שׁוּב.")
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "support.sent.\(householdID)", content: content, trigger: nil))
        return ok
    }

    /// A Firebase callable over plain HTTPS (the protocol is
    /// `POST {"data": …}` with the user's ID token) — no extra SDK in the app.
    private func callSupportReply(householdID: String, text: String) async -> Bool {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard let user = Auth.auth().currentUser,
              let project = FirebaseApp.app()?.options.projectID,
              let url = URL(string: "https://us-central1-\(project).cloudfunctions.net/supportReply") else { return false }
        do {
            let token = try await user.getIDToken()
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["data": [
                "householdID": householdID,
                "text": text,
                "senderName": Self.teamSenderName,
            ]])
            let (body, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 { print("[Support] supportReply HTTP \(status): \(String(data: body, encoding: .utf8) ?? "")") }
            return status == 200
        } catch {
            print("[Support] supportReply failed: \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    /// The first name on the team member's account ("רני" / "עמית") — for the
    /// team's own inbox only; parents never see it.
    static var teamSenderName: String {
        let first = (AuthManager.shared.displayName ?? "").split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "צוות טופי" : first
    }

    /// A tapped support push: the team lands in that family's thread, a parent
    /// in their own chat.
    func open(fromPush info: [AnyHashable: Any]) {
        let hid = info["householdID"] as? String ?? ""
        if info["audience"] as? String == "team", SupportTeam.isCurrentUser, !hid.isEmpty {
            route = .teamThread(householdID: hid)
        } else if AuthManager.shared.isRealAccount, ParentSettings.shared.deviceRole != .child {
            if let mine = HouseholdManager.shared.household?.id {
                route = .parent(householdID: mine)
            } else {
                wantsParentChat = true
            }
        }
    }
}
