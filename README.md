# קופיקו — ChildTime

> An iPadOS app that turns screen time into a learning game for kids ages 4-10.
> אפליקציית iPadOS שהופכת זמן מסך למשחק לימוד לילדים בגילאי 4-10.

The parent picks which entertainment apps (YouTube, TikTok, games) are blocked
by default. The child unlocks them for a limited time by answering educational
questions inside a gamified adventure with worlds, a magical companion (Kofiko),
chests, streaks, and XP.

## Stack

- SwiftUI + Swift 5 (iOS 16+, targets iOS 26.5)
- Apple **Family Controls** (`.individual` mode) — shielding via `ManagedSettings`
- **DeviceActivity** — scheduling re-shield after the play window ends
- No third-party dependencies, no analytics, no backend — all data stays on device

## Project layout

```
ChildTime/                  Main app
├── ChildTimeApp.swift      Entry point + shield enforcement
├── ContentView.swift       Router (Onboarding / Unlocked / WorldMap)
├── DesignSystem/           Color, type, spacing, motion tokens
├── Components/             Reusable UI (JuicyButton, ChestView, etc.)
├── Companion/              Kofiko — the floating companion
├── Audio/                  Sound + haptics
├── Models/                 Topic, Question, World, ProgressStore, RewardEngine
├── Views/                  All screens
└── ScreenTime/             Family Controls integration

DeviceActivityMonitorExt/   Extension that re-applies shield when time ends
distribution/               Privacy policy + App Store metadata
docs/                       GitHub Pages (privacy policy)
```

## Documents

- [DESIGN.md](DESIGN.md) — Full game design document (worlds, economy, WOW moments, V2 roadmap)
- [SETUP.md](SETUP.md) — Xcode setup steps (capabilities, signing, extension target)
- [TESTFLIGHT.md](TESTFLIGHT.md) — TestFlight roadmap
- [distribution/FAMILY_CONTROLS_REQUEST.md](distribution/FAMILY_CONTROLS_REQUEST.md) — Ready-to-paste answers for Apple's Family Controls Distribution form
- [distribution/APP_STORE_METADATA.md](distribution/APP_STORE_METADATA.md) — App Store listing copy

## Privacy

This app does not collect any personal data. See [Privacy Policy](https://raniop.github.io/ChildTime/privacy-policy.html).

## License

All rights reserved.
