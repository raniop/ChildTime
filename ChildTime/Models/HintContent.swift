import Foundation

/// Per-topic help the companion can offer. Two depths, picked by the equipped
/// character's tier: a short nudge (`hint`) or a method explanation (`explain`).
/// Neither ever reveals the answer — they teach *how to think*, in line with the
/// app's "safe, never-failure" tone.
enum HintContent {
    /// A one-line nudge (rare/epic helper).
    static func hint(_ t: Topic) -> String {
        switch t {
        case .math:      return tr("סְפוֹר לְאַט, אֶחָד-אֶחָד 🔢")
        case .english:   return tr("תַּגִּיד אֶת הַמִּלָּה בְּקוֹל 🔊")
        case .hebrew:    return tr("אֱמוֹר אֶת הַמִּלָּה לְאַט 🗣️")
        case .logic:     return tr("חַפֵּשׂ מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩")
        case .science:   return tr("חֲשׁוֹב עַל הַטֶּבַע סְבִיבְךָ 🔬")
        case .history:   return tr("חֲשׁוֹב מָה קָרָה קוֹדֶם 🏛️")
        case .geography: return tr("דַּמְיֵן אֶת הַמַּפָּה 🌍")
        case .money:     return tr("חֲשׁוֹב כַּמָּה זֶה עוֹלֶה 💰")
        case .reading:   return tr("קְרָא שׁוּב אֶת הַקֶּטַע לְאַט 📖")
        case .soccer:    return tr("תַּחְשֹׁב עַל מִשְׂחָק שֶׁרָאִיתָ ⚽")
        case .gifted:    return tr("חַפֵּשׂ אֶת הַחֹק שֶׁחוֹזֵר 🧠")
        case .dinosaurs, .space, .animals, .sea, .food, .israel, .music, .body, .vehicles, .flags, .tishrei:
            return tr("תַּחְשֹׁב עַל מַה שֶּׁרָאִיתָ אוֹ שָׁמַעְתָּ עַל זֶה 💡")
        }
    }

    /// A short method explanation (legendary/mythic helper).
    static func explain(_ t: Topic) -> String {
        switch t {
        case .math:      return tr("אֶפְשָׁר לִסְפּוֹר עַל הָאֶצְבָּעוֹת אוֹ לְצַיֵּר נְקוּדּוֹת וְאָז לִסְפּוֹר אֶת הַכֹּל.")
        case .english:   return tr("חֲשׁוֹב אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפֵּשׂ אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל.")
        case .hebrew:    return tr("פָּרֵק אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמַע אֵיךְ כָּל חֵלֶק נִכְתָּב.")
        case .logic:     return tr("בְּדוֹק מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשֵׁךְ אֶת הַסֵּדֶר.")
        case .science:   return tr("נַסֵּה לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִיתָ בָּעוֹלָם הָאֲמִתִּי.")
        case .history:   return tr("סַדֵּר אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו.")
        case .geography: return tr("חֲשׁוֹב עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ.")
        case .money:     return tr("סְפוֹר אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבְדוֹק כַּמָּה יֵשׁ סַךְ הַכֹּל.")
        case .reading:   return tr("הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפֵּשׂ בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה.")
        case .soccer:    return tr("דַּמְיֵן אֶת הַמִּגְרָשׁ: אֵיפֹה עוֹמֵד כָּל שַׂחְקָן וּמָה מֻתָּר לוֹ לַעֲשׂוֹת.")
        case .gifted:    return tr("קְרָא שׁוּב לְאַט, וּבְדֹק אֵיזֶה חֹק מַתְאִים לְכָל הָאֵיבָרִים בַּסִּדְרָה.")
        case .dinosaurs, .space, .animals, .sea, .food, .israel, .music, .body, .vehicles, .flags, .tishrei:
            return tr("הוֹרִידוּ קֹדֶם אֶת הַתְּשׁוּבוֹת שֶׁבֶּטַח לֹא נְכוֹנוֹת — וּבַחֲרוּ מִמַּה שֶּׁנִּשְׁאַר.")
        }
    }
}
