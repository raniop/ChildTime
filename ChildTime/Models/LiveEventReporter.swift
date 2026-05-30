import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Writes child learning events to `children/{childID}/events`. A Cloud Function
/// (see `functions/`) listens to these and pushes a notification to the other
/// parents in the household — so a co-parent gets "יואב התחיל מסע למידה" /
/// "יואב ברצף של 5" / "יואב גילה עניין במדע" in real time.
///
/// No-op without FirebaseFirestore; safe to call from anywhere on the main actor.
@MainActor
enum LiveEventReporter {
    enum EventType: String {
        case sessionStart
        case sessionEnd         // child finished / left a play session
        case milestone          // e.g. answered 8/10
        case streak             // hit a streak threshold
        case wheelWin           // earned / spun the lucky wheel
        case discovery          // growing interest in a new topic
        case assistRequest      // child asked a parent for help
    }

    static func report(_ type: EventType, value: String? = nil, topic: Topic? = nil) {
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn,
              let childID = ProfileStore.shared.activeID else { return }
        let childName = ProfileStore.shared.active?.name ?? ""
        var payload: [String: Any] = [
            "type": type.rawValue,
            "childName": childName,
            "originUID": AuthManager.shared.userID ?? "",
            "originToken": PushManager.shared.currentToken ?? "",
            "deviceID": ProgressSnapshot.thisDeviceID,
            "createdAt": Date().timeIntervalSince1970
        ]
        if let value { payload["value"] = value }
        if let topic { payload["topic"] = topic.displayName }
        Firestore.firestore()
            .collection("children").document(childID.uuidString)
            .collection("events").addDocument(data: payload)
        #endif
    }
}
