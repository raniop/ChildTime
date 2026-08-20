import Foundation

/// Per-topic help the companion can offer. Two depths, picked by the equipped
/// character's tier: a short nudge (`hint`) or a method explanation (`explain`).
/// Neither ever reveals the answer — they teach *how to think*, in line with the
/// app's "safe, never-failure" tone.
enum HintContent {
    /// A one-line nudge (rare/epic helper).
    static func hint(_ t: Topic) -> String {
        switch t {
        case .math:      return "סְפוֹר לְאַט, אֶחָד-אֶחָד 🔢"
        case .english:   return "תַּגִּיד אֶת הַמִּלָּה בְּקוֹל 🔊"
        case .hebrew:    return "אֱמוֹר אֶת הַמִּלָּה לְאַט 🗣️"
        case .logic:     return "חַפֵּשׂ מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩"
        case .science:   return "חֲשׁוֹב עַל הַטֶּבַע סְבִיבְךָ 🔬"
        case .history:   return "חֲשׁוֹב מָה קָרָה קוֹדֶם 🏛️"
        case .geography: return "דַּמְיֵן אֶת הַמַּפָּה 🌍"
        case .money:     return "חֲשׁוֹב כַּמָּה זֶה עוֹלֶה 💰"
        case .reading:   return "קְרָא שׁוּב אֶת הַקֶּטַע לְאַט 📖"
        }
    }

    /// A short method explanation (legendary/mythic helper).
    static func explain(_ t: Topic) -> String {
        switch t {
        case .math:      return "אֶפְשָׁר לִסְפּוֹר עַל הָאֶצְבָּעוֹת אוֹ לְצַיֵּר נְקוּדּוֹת וְאָז לִסְפּוֹר אֶת הַכֹּל."
        case .english:   return "חֲשׁוֹב אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפֵּשׂ אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל."
        case .hebrew:    return "פָּרֵק אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמַע אֵיךְ כָּל חֵלֶק נִכְתָּב."
        case .logic:     return "בְּדוֹק מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשֵׁךְ אֶת הַסֵּדֶר."
        case .science:   return "נַסֵּה לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִיתָ בָּעוֹלָם הָאֲמִתִּי."
        case .history:   return "סַדֵּר אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו."
        case .geography: return "חֲשׁוֹב עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ."
        case .money:     return "סְפוֹר אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבְדוֹק כַּמָּה יֵשׁ סַךְ הַכֹּל."
        case .reading:   return "הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפֵּשׂ בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה."
        }
    }
}
