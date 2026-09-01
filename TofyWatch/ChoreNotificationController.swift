import SwiftUI
import WatchKit
import UserNotifications

/// ⌚️🧹 Rich chore-approval notification: the mirrored version can't display
/// the proof photo, so this scene fetches it from the token-gated `photoURL`
/// in the payload and shows it above the system-provided action buttons.
final class ChoreNotificationController: WKUserNotificationHostingController<ChoreNotificationView> {
    private var title = ""
    private var bodyText = ""
    private var photoURL: URL?

    override var body: ChoreNotificationView {
        ChoreNotificationView(title: title, bodyText: bodyText, photoURL: photoURL)
    }

    override func didReceive(_ notification: UNNotification) {
        title = notification.request.content.title
        bodyText = notification.request.content.body
        photoURL = (notification.request.content.userInfo["photoURL"] as? String)
            .flatMap(URL.init(string:))
    }
}

struct ChoreNotificationView: View {
    let title: String
    let bodyText: String
    let photoURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.trailing)
                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                if let photoURL {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure:
                            EmptyView()
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
