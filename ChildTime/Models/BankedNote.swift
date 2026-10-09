import Foundation

/// "הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! … נִשְׁמְרוּ לְמָחָר" — one place, so one minute
/// reads "דַּקָּה אַחַת נִשְׁמְרָה" and not "1 דַּקּוֹת נִשְׁמְרוּ" (Rani, 2026-10-09).
enum BankedNote {
    /// The cap was full: `banked` minutes went to tomorrow; the bank now holds `carry` of `max`.
    static func capReached(banked: Int, carry: Int, max: Int) -> String {
        if banked == 1 {
            return Gendered.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר 🎁 (\(carry)/\(max))"),
                              tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר 🎁 (\(carry)/\(max))"))
        }
        return Gendered.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! \(banked) דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (\(carry)/\(max))"),
                          tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! \(banked) דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (\(carry)/\(max))"))
    }

    /// "🎁 N דַּקּוֹת נִשְׁמְרוּ לְמָחָר." for the minutes sheet.
    static func savedForTomorrow(_ minutes: Int) -> String {
        minutes == 1 ? tr("🎁 דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר.") : tr("🎁 \(minutes) דַּקּוֹת נִשְׁמְרוּ לְמָחָר.")
    }
}
