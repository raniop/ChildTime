import Foundation

/// Per-topic help the companion can offer. Two depths, picked by the equipped
/// character's tier: a short nudge (`hint`) or a method explanation (`explain`).
/// Neither ever reveals the answer — they teach *how to think*, in line with the
/// app's "safe, never-failure" tone.
enum HintContent {
    /// A one-line nudge (rare/epic helper).
    static func hint(_ t: Topic) -> String {
        switch t {
        case .math:      return Gendered.g(tr("סְפוֹר לְאַט, אֶחָד-אֶחָד 🔢"), tr("סִפְרִי לְאַט, אֶחָד-אֶחָד 🔢"))
        case .english:   return Gendered.g(tr("תַּגִּיד אֶת הַמִּלָּה בְּקוֹל 🔊"), tr("תַּגִּידִי אֶת הַמִּלָּה בְּקוֹל 🔊"))
        case .hebrew:    return Gendered.g(tr("אֱמוֹר אֶת הַמִּלָּה לְאַט 🗣️"), tr("אִמְרִי אֶת הַמִּלָּה לְאַט 🗣️"))
        case .logic:     return Gendered.g(tr("חַפֵּשׂ מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩"), tr("חַפְּשִׂי מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩"))
        case .science:   return Gendered.g(tr("חֲשׁוֹב עַל הַטֶּבַע סְבִיבְךָ 🔬"), tr("חִשְׁבִי עַל הַטֶּבַע סְבִיבֵךְ 🔬"))
        case .history:   return Gendered.g(tr("חֲשׁוֹב מָה קָרָה קוֹדֶם 🏛️"), tr("חִשְׁבִי מָה קָרָה קוֹדֶם 🏛️"))
        case .geography: return Gendered.g(tr("דַּמְיֵן אֶת הַמַּפָּה 🌍"), tr("דַּמְיְנִי אֶת הַמַּפָּה 🌍"))
        case .money:     return Gendered.g(tr("חֲשׁוֹב כַּמָּה זֶה עוֹלֶה 💰"), tr("חִשְׁבִי כַּמָּה זֶה עוֹלֶה 💰"))
        case .reading:   return Gendered.g(tr("קְרָא שׁוּב אֶת הַקֶּטַע לְאַט 📖"), tr("קִרְאִי שׁוּב אֶת הַקֶּטַע לְאַט 📖"))
        case .soccer:    return Gendered.g(tr("תַּחְשֹׁב עַל מִשְׂחָק שֶׁרָאִיתָ ⚽"), tr("תַּחְשְׁבִי עַל מִשְׂחָק שֶׁרָאִית ⚽"))
        case .gifted:    return Gendered.g(tr("חַפֵּשׂ אֶת הַחֹק שֶׁחוֹזֵר 🧠"), tr("חַפְּשִׂי אֶת הַחֹק שֶׁחוֹזֵר 🧠"))
        case .dinosaurs, .space, .animals, .sea, .food, .israel, .music, .body, .vehicles, .flags, .tishrei, .holidays:
            return Gendered.g(tr("תַּחְשֹׁב עַל מַה שֶּׁרָאִיתָ אוֹ שָׁמַעְתָּ עַל זֶה 💡"), tr("תַּחְשְׁבִי עַל מַה שֶּׁרָאִית אוֹ שָׁמַעַתְּ עַל זֶה 💡"))
        }
    }

    /// A short method explanation (legendary/mythic helper).
    static func explain(_ t: Topic) -> String {
        switch t {
        case .math:      return tr("אֶפְשָׁר לִסְפּוֹר עַל הָאֶצְבָּעוֹת אוֹ לְצַיֵּר נְקוּדּוֹת וְאָז לִסְפּוֹר אֶת הַכֹּל.")
        case .english:   return Gendered.g(tr("חֲשׁוֹב אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפֵּשׂ אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל."), tr("חִשְׁבִי אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפְּשִׂי אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל."))
        case .hebrew:    return Gendered.g(tr("פָּרֵק אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמַע אֵיךְ כָּל חֵלֶק נִכְתָּב."), tr("פָּרְקִי אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמְעִי אֵיךְ כָּל חֵלֶק נִכְתָּב."))
        case .logic:     return Gendered.g(tr("בְּדוֹק מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשֵׁךְ אֶת הַסֵּדֶר."), tr("בִּדְקִי מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשִׁיכִי אֶת הַסֵּדֶר."))
        case .science:   return Gendered.g(tr("נַסֵּה לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִיתָ בָּעוֹלָם הָאֲמִתִּי."), tr("נַסִּי לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִית בָּעוֹלָם הָאֲמִתִּי."))
        case .history:   return Gendered.g(tr("סַדֵּר אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו."), tr("סַדְּרִי אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו."))
        case .geography: return Gendered.g(tr("חֲשׁוֹב עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ."), tr("חִשְׁבִי עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ."))
        case .money:     return Gendered.g(tr("סְפוֹר אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבְדוֹק כַּמָּה יֵשׁ סַךְ הַכֹּל."), tr("סִפְרִי אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבִדְקִי כַּמָּה יֵשׁ סַךְ הַכֹּל."))
        case .reading:   return Gendered.g(tr("הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפֵּשׂ בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה."), tr("הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפְּשִׂי בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה."))
        case .soccer:    return Gendered.g(tr("דַּמְיֵן אֶת הַמִּגְרָשׁ: אֵיפֹה עוֹמֵד כָּל שַׂחְקָן וּמָה מֻתָּר לוֹ לַעֲשׂוֹת."), tr("דַּמְיְנִי אֶת הַמִּגְרָשׁ: אֵיפֹה עוֹמֵד כָּל שַׂחְקָן וּמָה מֻתָּר לוֹ לַעֲשׂוֹת."))
        case .gifted:    return Gendered.g(tr("קְרָא שׁוּב לְאַט, וּבְדֹק אֵיזֶה חֹק מַתְאִים לְכָל הָאֵיבָרִים בַּסִּדְרָה."), tr("קִרְאִי שׁוּב לְאַט, וּבִדְקִי אֵיזֶה חֹק מַתְאִים לְכָל הָאֵיבָרִים בַּסִּדְרָה."))
        case .dinosaurs, .space, .animals, .sea, .food, .israel, .music, .body, .vehicles, .flags, .tishrei, .holidays:
            return tr("הוֹרִידוּ קֹדֶם אֶת הַתְּשׁוּבוֹת שֶׁבֶּטַח לֹא נְכוֹנוֹת — וּבַחֲרוּ מִמַּה שֶּׁנִּשְׁאַר.")
        }
    }
}
