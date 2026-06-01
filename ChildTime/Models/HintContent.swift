import Foundation

/// Per-topic help the companion can offer. Two depths, picked by the equipped
/// character's tier: a short nudge (`hint`) or a method explanation (`explain`).
/// Neither ever reveals the answer — they teach *how to think*, in line with the
/// app's "safe, never-failure" tone.
enum HintContent {
    /// A one-line nudge (rare/epic helper).
    static func hint(_ t: Topic) -> String {
        switch t {
        case .math:      return "סְפֹר לְאַט, אֶחָד-אֶחָד 🔢"
        case .english:   return "תַּגִּיד אֶת הַמִּלָּה בְּקוֹל 🔊"
        case .hebrew:    return "אֱמֹר אֶת הַמִּלָּה לְאַט 🗣️"
        case .logic:     return "חַפֵּשׂ מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩"
        case .science:   return "חֲשֹׁב עַל הַטֶּבַע סְבִיבְךָ 🔬"
        case .history:   return "חֲשֹׁב מָה קָרָה קֹדֶם 🏛️"
        case .geography: return "דַּמְיֵן אֶת הַמַּפָּה 🌍"
        case .money:     return "חֲשֹׁב כַּמָּה זֶה עוֹלֶה 💰"
        }
    }

    /// A short method explanation (legendary/mythic helper).
    static func explain(_ t: Topic) -> String {
        switch t {
        case .math:      return "אֶפְשָׁר לִסְפֹּר עַל הָאֶצְבָּעוֹת אוֹ לְצַיֵּר נְקֻדּוֹת וְאָז לִסְפֹּר אֶת הַכֹּל."
        case .english:   return "חֲשֹׁב אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפֵּשׂ אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל."
        case .hebrew:    return "פָּרֵק אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמַע אֵיךְ כָּל חֵלֶק נִכְתָּב."
        case .logic:     return "בְּדֹק מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשֵׁךְ אֶת הַסֵּדֶר."
        case .science:   return "נַסֵּה לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִיתָ בָּעוֹלָם הָאֲמִתִּי."
        case .history:   return "סַדֵּר אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו."
        case .geography: return "חֲשֹׁב עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ."
        case .money:     return "סְפֹר אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבְדֹק כַּמָּה יֵשׁ סַךְ הַכֹּל."
        }
    }
}
