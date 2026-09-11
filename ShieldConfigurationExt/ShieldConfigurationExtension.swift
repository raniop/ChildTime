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

    // iOS never paints these as given: over a dark blur it darkens them, and with
    // no blur at all it washes them out to near-white (which is how a white-on-
    // white screen happened). So feed it colours BRIGHTER than the target and let
    // the dark material bring them down to the brand purple.
    // The ceiling of this framework, learned the hard way: `backgroundColor` is
    // the only full-screen surface, it accepts no image (a pattern colour is
    // flattened to near-white), and iOS always tints whatever colour we pass.
    // A dark material with a colour BRIGHTER than the target is the one
    // combination that lands on the brand purple and keeps white text readable.
    private static let indigo = UIColor(red: 0.48, green: 0.36, blue: 1.00, alpha: 1)   // #7A5CFF
    private static let mint   = UIColor(red: 0.18, green: 0.84, blue: 0.63, alpha: 1)   // #2ED6A1
    private static let night  = UIColor(red: 0.37, green: 0.38, blue: 0.81, alpha: 1)   // #5E60CE

    private func configuration() -> ShieldConfiguration {
        let s = ShieldState.load()
        let icon = UIImage(named: "ShieldLion")
        let name = s.childName.trimmingCharacters(in: .whitespaces)

        switch s.mode {
        // ONE button, always. Apple lets a shield button do exactly one thing —
        // dismiss — so a second one that also dismisses is noise (Rani), and a
        // label that promises to open minutes would be a lie.
        case .hasMinutes:
            let mins = max(1, s.availableMinutes)
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.mint,
                icon: icon,
                // Whole sentences per gender and name, so a translation never
                // has to glue a capitalised fragment after "Noa, ".
                title: .init(text: {
                    switch (name.isEmpty, s.girl) {
                    case (true, true):   return tr("יֵשׁ לָךְ \(mins) דַּקּוֹת")
                    case (true, false):  return tr("יֵשׁ לְךָ \(mins) דַּקּוֹת")
                    case (false, true):  return tr("\(name), יֵשׁ לָךְ \(mins) דַּקּוֹת")
                    case (false, false): return tr("\(name), יֵשׁ לְךָ \(mins) דַּקּוֹת")
                    }
                }(),
                             color: .white),
                subtitle: .init(text: s.girl ? tr("הִרְוַחְתְּ אוֹתָן — הֵן מְחַכּוֹת בְּטוֹפִי")
                                            : tr("הִרְוַחְתָּ אוֹתָן — הֵן מְחַכּוֹת בְּטוֹפִי"),
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: tr("בּוֹאוּ נִפְתַּח אוֹתָן"), color: Self.mint),
                primaryButtonBackgroundColor: .white
            )

        case .dailyCapReached:
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.night,
                icon: icon,
                title: .init(text: name.isEmpty ? tr("מַסְפִּיק לְהַיּוֹם") : tr("\(name), מַסְפִּיק לְהַיּוֹם"), color: .white),
                subtitle: .init(text: s.girl ? tr("הִגַּעַתְּ לְכָל הַדַּקּוֹת שֶׁל הַיּוֹם.\nנִתְרָאֶה מָחָר בַּבֹּקֶר")
                                             : tr("הִגַּעְתָּ לְכָל הַדַּקּוֹת שֶׁל הַיּוֹם.\nנִתְרָאֶה מָחָר בַּבֹּקֶר"),
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: tr("הֵבַנְתִּי"), color: Self.night),
                primaryButtonBackgroundColor: .white
            )

        case .needsQuestions:
            // The honest rule, and the only one Tofy actually has: a correct
            // answer banks minutes. There is no question quota to reach.
            let m = max(1, s.minutesPerCorrect)
            let worth = m == 1 ? tr("דַּקָּה אַחַת") : tr("\(m) דַּקּוֹת")
            let noMinutes: String = {
                switch (name.isEmpty, s.girl) {
                case (true, true):   return tr("עוֹד אֵין לָךְ דַּקּוֹת")
                case (true, false):  return tr("עוֹד אֵין לְךָ דַּקּוֹת")
                case (false, true):  return tr("\(name), עוֹד אֵין לָךְ דַּקּוֹת")
                case (false, false): return tr("\(name), עוֹד אֵין לְךָ דַּקּוֹת")
                }
            }()
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThinMaterialDark,
                backgroundColor: Self.indigo,
                icon: icon,
                title: .init(text: noMinutes, color: .white),
                subtitle: .init(text: tr("כָּל תְּשׁוּבָה נְכוֹנָה בְּטוֹפִי = \(worth) מִשְׂחָק"),
                                color: UIColor.white.withAlphaComponent(0.85)),
                primaryButtonLabel: .init(text: tr("בּוֹאוּ נַרְוִיחַ דַּקּוֹת"), color: Self.indigo),
                primaryButtonBackgroundColor: .white
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
