import Foundation

enum AppSound: String, CaseIterable {
    case uiTap            = "ui_tap"
    case correctSmall     = "correct_small"
    case correctBig       = "correct_big"
    case wrongSoft        = "wrong_soft"
    case streakUp         = "streak_up"
    case portalAppear     = "portal_appear"
    case chestOpen        = "chest_open"
    case levelUp          = "level_up"
    case companionCheer   = "companion_cheer"
    case worldUnlock      = "world_unlock"

    var fileName: String { rawValue + ".caf" }
}
