import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen a child actually meets when they open a locked app.
///
/// Until now this was Apple's grey "Restricted" wall — English, generic, and a
/// dead end. It is also the highest-intent moment in the whole product: the
/// child wants to play *right now*. So instead of refusing, the shield says
/// exactly what stands between them and the app, in their own name.
///
/// Constraints worth remembering before editing: this process gets a few
/// seconds and NO network, so every value comes pre-written from the app via
/// the App Group. Apple owns the layout — icon, title, subtitle, two buttons —
/// we only choose the colors, the image and the words.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let indigo = UIColor(red: 0.29, green: 0.25, blue: 0.75, alpha: 1)   // #4B3FBF
    private static let mint   = UIColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1)   // #1D9E75
    private static let night  = UIColor(red: 0.24, green: 0.20, blue: 0.54, alpha: 1)   // #3C3489

    private func configuration() -> ShieldConfiguration {
        let s = ShieldState.load()
        let icon = UIImage(named: "ShieldLion")
        let name = s.childName.trimmingCharacters(in: .whitespaces)

        switch s.mode {
        case .hasMinutes:
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.mint,
                icon: icon,
                title: .init(text: "יֵשׁ לְךָ \(s.availableMinutes) דַּקּוֹת", color: .white),
                subtitle: .init(text: name.isEmpty
                                ? "הִרְוַחְתָּ אוֹתָן הַיּוֹם. רוֹצֶה לִפְתֹּחַ עַכְשָׁו?"
                                : "\(name), הִרְוַחְתָּ אוֹתָן הַיּוֹם.\nרוֹצֶה לִפְתֹּחַ עַכְשָׁו?",
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: "פִּתְחוּ לִי \(s.availableMinutes) דַּקּוֹת", color: Self.mint),
                primaryButtonBackgroundColor: .white,
                secondaryButtonLabel: .init(text: "אַחַר כָּךְ", color: UIColor.white.withAlphaComponent(0.8))
            )

        case .dailyCapReached:
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.night,
                icon: icon,
                title: .init(text: "מַסְפִּיק לְהַיּוֹם", color: .white),
                subtitle: .init(text: "הִגַּעְתָּ לְכָל הַדַּקּוֹת שֶׁל הַיּוֹם.\nנִתְרָאֶה מָחָר בַּבֹּקֶר",
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: "בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא", color: Self.night),
                primaryButtonBackgroundColor: .white,
                secondaryButtonLabel: .init(text: "סְגִירָה", color: UIColor.white.withAlphaComponent(0.8))
            )

        case .needsQuestions:
            let n = max(1, s.questionsToGo)
            let questions = n == 1 ? "עוֹד שְׁאֵלָה אַחַת" : "עוֹד \(n) שְׁאֵלוֹת"
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.indigo,
                icon: icon,
                title: .init(text: questions, color: .white),
                subtitle: .init(text: name.isEmpty
                                ? "עוֹד כַּמָּה תְּשׁוּבוֹת נְכוֹנוֹת וְזֶה נִפְתָּח לְ־\(s.minutesPerWindow) דַּקּוֹת"
                                : "\(name), \(questions) נְכוֹנוֹת\nוְזֶה נִפְתָּח לְ־\(s.minutesPerWindow) דַּקּוֹת",
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: "בּוֹאוּ נַרְוִיחַ דַּקּוֹת", color: Self.indigo),
                primaryButtonBackgroundColor: .white,
                secondaryButtonLabel: .init(text: "סְגִירָה", color: UIColor.white.withAlphaComponent(0.8))
            )
        }
    }

    // Every entry point Apple can shield resolves to the same screen: from the
    // child's side "this app is locked" is one situation, not four.
    override func configuration(shielding application: Application) -> ShieldConfiguration { configuration() }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration { configuration() }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { configuration() }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration { configuration() }
}
