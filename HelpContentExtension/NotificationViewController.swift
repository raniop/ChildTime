//
//  NotificationViewController.swift
//  HelpContentExtension
//
//  Custom UI for the "parent help" interactive notification: shows the child's
//  question and presents the two answer options as DYNAMIC action buttons
//  (their titles are the actual answers, e.g. "פריז" / "ברלין" — which a plain
//  category can't do). The parent taps one straight from the notification; the
//  tap is handled in the main app (background) and written back to Firestore.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet var label: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        label?.numberOfLines = 0
        label?.textAlignment = .center
        label?.font = .systemFont(ofSize: 22, weight: .heavy)
        label?.adjustsFontSizeToFitWidth = true
        label?.minimumScaleFactor = 0.6
        view.semanticContentAttribute = .forceRightToLeft
    }

    func didReceive(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        // The question to help with.
        label?.text = (info["question"] as? String) ?? notification.request.content.body

        // Dynamic answer buttons — the actual option texts. The identifiers are
        // stable so the main app can map a tap back to "kept A / kept B".
        let optionA = (info["optionA"] as? String) ?? ""
        let optionB = (info["optionB"] as? String) ?? ""
        var actions: [UNNotificationAction] = []
        if !optionA.isEmpty {
            actions.append(UNNotificationAction(identifier: "HELP_OPT_A", title: optionA, options: []))
        }
        if !optionB.isEmpty {
            actions.append(UNNotificationAction(identifier: "HELP_OPT_B", title: optionB, options: []))
        }
        extensionContext?.notificationActions = actions
    }
}
