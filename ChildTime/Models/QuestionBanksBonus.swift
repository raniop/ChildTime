import Foundation

/// 💫 The BONUS-QUESTION pool — a dedicated bank of REALLY hard questions
/// (Rani: "קטגוריה של שאלות בונוס ושם יהיו רק שאלות ממש ממש קשות").
///
/// Served only by `QuestionGenerator.generateBonus(topic:)` when the rare bonus
/// event fires mid-session; never mixed into the regular per-topic banks, so the
/// everyday difficulty curve is untouched. Math has no pool here — it's
/// generated procedurally with extended ranges (see `makeBonusMath`).
/// Every item is `tier: .hard` so `QuestionMemory.pickFresh` treats the pool
/// uniformly and its anti-repeat window applies.
enum BonusQuestionBank {

    static func pool(for topic: Topic) -> [BankQuestion] {
        switch topic {
        case .math:      return []   // procedural — see QuestionGenerator.makeBonusMath
        case .reading:   return []   // falls back to a hard passage via generate(.reading)
        case .english:   return english
        case .hebrew:    return hebrew
        case .logic:     return logic
        case .science:   return science
        case .history:   return history
        case .geography: return geography
        case .money:     return money
        }
    }

    // MARK: - אנגלית

    static let english: [BankQuestion] = [
        BankQuestion(prompt: "🦋\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "butterfly", distractors: ["dragonfly", "ladybug", "caterpillar"], tier: .hard),
        BankQuestion(prompt: "☂️\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "umbrella", distractors: ["raincoat", "shadow", "shelter"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים \"מִשְׁקָפַיִם\" בְּאַנְגְּלִית?", correctAnswer: "glasses", distractors: ["windows", "mirrors", "bottles"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים \"בְּקָרוֹב\" בְּאַנְגְּלִית?", correctAnswer: "soon", distractors: ["late", "never", "always"], tier: .hard),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל \"empty\"?", correctAnswer: "full", distractors: ["open", "heavy", "clean"], tier: .hard),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל \"expensive\"?", correctAnswer: "cheap", distractors: ["rich", "small", "easy"], tier: .hard),
        BankQuestion(prompt: "\"I am thirsty\" — מָה זֶה אוֹמֵר?", correctAnswer: "אֲנִי צָמֵא", distractors: ["אֲנִי רָעֵב", "אֲנִי עָיֵף", "אֲנִי שָׂמֵחַ"], tier: .hard),
        BankQuestion(prompt: "\"See you tomorrow\" — מָה זֶה אוֹמֵר?", correctAnswer: "נִתְרָאֶה מָחָר", distractors: ["לְהִתְרָאוֹת אֶתְמוֹל", "בּוֹקֶר טוֹב", "אֲנִי רוֹאֶה אוֹתְךָ עַכְשָׁיו"], tier: .hard),
        BankQuestion(prompt: "אֵיזוֹ מִלָּה הִיא חַיָּה?", correctAnswer: "squirrel", distractors: ["mountain", "kitchen", "winter"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים \"סְפָרִיָּה\" בְּאַנְגְּלִית?", correctAnswer: "library", distractors: ["laboratory", "bakery", "pharmacy"], tier: .hard),
    ]

    // MARK: - עברית

    static let hebrew: [BankQuestion] = [
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל \"אֲרִי\"?", correctAnswer: "אֲרָיוֹת", distractors: ["אֲרִיִּים", "אוֹרִים", "אֲרָיִים"], tier: .hard),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל \"חַלּוֹן\"?", correctAnswer: "חַלּוֹנוֹת", distractors: ["חַלּוֹנִים", "חֲלוֹנוֹת", "חַלּוֹנֵי"], tier: .hard),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל \"נָדִיב\"?", correctAnswer: "קַמְצָן", distractors: ["עָשִׁיר", "חָזָק", "עָצוּב"], tier: .hard),
        BankQuestion(prompt: "אֵיזוֹ מִלָּה קְרוֹבָה בְּמַשְׁמָעוּת לְ\"שָׂמֵחַ\"?", correctAnswer: "עַלִּיז", distractors: ["עָיֵף", "רָגוּעַ", "מֻפְתָּע"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "מִצְטַעֵר", distractors: ["מִסְטַעֵר", "מִצְתַּעֵר", "מִזְטַעֵר"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "הִתְרַגַּשְׁתִּי", distractors: ["הִתְרַגַּשְׁתִי", "הִתְרַגָּשְׁתִּי", "הִתְרַקַּשְׁתִּי"], tier: .hard),
        BankQuestion(prompt: "מִי אָמַר? \"הַצִּפּוֹר שָׁרָה שִׁיר יָפֶה\" — מָה הַנּוֹשֵׂא בַּמִּשְׁפָּט?", correctAnswer: "הַצִּפּוֹר", distractors: ["שָׁרָה", "שִׁיר", "יָפֶה"], tier: .hard),
        BankQuestion(prompt: "מָה פֵּרוּשׁ הַבִּטּוּי \"שָׁבַר אֶת הַקֶּרַח\"?", correctAnswer: "גָּרַם לָאֲוִירָה לִהְיוֹת נְעִימָה", distractors: ["שָׁבַר מַשֶּׁהוּ קַר", "הֵכִין גְּלִידָה", "יָצָא הַחוּצָה בַּחֹרֶף"], tier: .hard),
        BankQuestion(prompt: "מָה פֵּרוּשׁ הַבִּטּוּי \"לָשִׂים לֵב\"?", correctAnswer: "לְהִתְרַכֵּז וּלְהַבְחִין", distractors: ["לְצַיֵּר לֵב", "לֶאֱהֹב מִישֶׁהוּ", "לָשִׂים יָד עַל הַחָזֶה"], tier: .hard),
        BankQuestion(prompt: "אֵיזוֹ מִלָּה הִיא פֹּעַל?", correctAnswer: "רָקַד", distractors: ["שֻׁלְחָן", "יָפֶה", "מְאוֹד"], tier: .hard),
    ]

    // MARK: - לוגיקה

    static let logic: [BankQuestion] = [
        BankQuestion(prompt: "מָה הַמִּסְפָּר הַבָּא בַּסִּדְרָה?\n2, 4, 8, 16, ...", correctAnswer: "32", distractors: ["24", "20", "18"], tier: .hard),
        BankQuestion(prompt: "מָה הַמִּסְפָּר הַבָּא בַּסִּדְרָה?\n1, 1, 2, 3, 5, 8, ...", correctAnswer: "13", distractors: ["11", "12", "16"], tier: .hard),
        BankQuestion(prompt: "מָה הַמִּסְפָּר הַבָּא בַּסִּדְרָה?\n100, 90, 81, 73, ...", correctAnswer: "66", distractors: ["65", "64", "63"], tier: .hard),
        BankQuestion(prompt: "לְדָנָה יֵשׁ פִּי 2 גּוּלוֹת מִלְּיוֹסִי. לְיוֹסִי יֵשׁ 6. כַּמָּה יֵשׁ לִשְׁנֵיהֶם בְּיַחַד?", correctAnswer: "18", distractors: ["12", "24", "16"], tier: .hard),
        BankQuestion(prompt: "אִם כָּל הַדְּרָקוֹנִים יוֹדְעִים לָעוּף, וְרוֹנִי הוּא דְּרָקוֹן — מָה נָכוֹן בֶּטַח?", correctAnswer: "רוֹנִי יוֹדֵעַ לָעוּף", distractors: ["רוֹנִי יָרֹק", "כָּל מִי שֶׁעָף הוּא דְּרָקוֹן", "רוֹנִי לֹא עָף"], tier: .hard),
        BankQuestion(prompt: "בְּכַד יֵשׁ 3 גַּרְבַּיִם אֲדֻמִּים וְ־3 כְּחֻלִּים. כַּמָּה צָרִיךְ לְהוֹצִיא בְּלִי לְהִסְתַּכֵּל כְּדֵי שֶׁבֶּטַח יִהְיֶה זוּג בְּאוֹתוֹ צֶבַע?", correctAnswer: "3", distractors: ["2", "4", "6"], tier: .hard),
        BankQuestion(prompt: "שָׁעוֹן מַרְאֶה 3:00. מָה תַּרְאֶה הַשָּׁעָה בְּעוֹד 50 דַּקּוֹת?", correctAnswer: "3:50", distractors: ["4:00", "3:40", "4:10"], tier: .hard),
        BankQuestion(prompt: "אֲנִי מִסְפָּר. אִם תַּכְפִּילוּ אוֹתִי בְּ־3 וְתוֹסִיפוּ 1 תְּקַבְּלוּ 22. מִי אֲנִי?", correctAnswer: "7", distractors: ["6", "8", "9"], tier: .hard),
        BankQuestion(prompt: "מָה לֹא שַׁיָּךְ לַקְּבוּצָה: מְשֻׁלָּשׁ, רִבּוּעַ, עִגּוּל, מַלְבֵּן?", correctAnswer: "עִגּוּל", distractors: ["מְשֻׁלָּשׁ", "רִבּוּעַ", "מַלְבֵּן"], tier: .hard),
        BankQuestion(prompt: "אַבָּא שֶׁל דָּנָה גָּדוֹל מִסַּבָּא שֶׁל דָּנָה?", correctAnswer: "לֹא — סַבָּא הוּא אַבָּא שֶׁל אַבָּא", distractors: ["כֵּן, תָּמִיד", "הֵם בְּאוֹתוֹ גִּיל", "אִי אֶפְשָׁר לָדַעַת בִּכְלָל"], tier: .hard),
    ]

    // MARK: - מדע

    static let science: [BankQuestion] = [
        BankQuestion(prompt: "בְּאֵיזוֹ טֶמְפֶּרָטוּרָה הַמַּיִם רוֹתְחִים?", correctAnswer: "100 מַעֲלוֹת", distractors: ["50 מַעֲלוֹת", "80 מַעֲלוֹת", "200 מַעֲלוֹת"], tier: .hard),
        BankQuestion(prompt: "אֵיזֶה כּוֹכַב לֶכֶת הוּא הַגָּדוֹל בְּיוֹתֵר בְּמַעֲרֶכֶת הַשֶּׁמֶשׁ?", correctAnswer: "צֶדֶק", distractors: ["מַאְדִּים", "שַׁבְּתַאי", "נֹגַהּ"], tier: .hard),
        BankQuestion(prompt: "מָה עוֹשֶׂה הַלֵּב בַּגּוּף?", correctAnswer: "מַזְרִים דָּם לְכָל הַגּוּף", distractors: ["מְעַכֵּל אֹכֶל", "שׁוֹלֵחַ מַחְשָׁבוֹת", "מְנַקֶּה אֶת הָאֲוִיר"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ צְמָחִים מְיַצְּרִים אֹכֶל לְעַצְמָם?", correctAnswer: "פוֹטוֹסִינְתֶזָה — מֵאוֹר הַשֶּׁמֶשׁ", distractors: ["שׁוֹאֲבִים אֹכֶל מֵחֲרָקִים", "אוֹכְלִים אֲדָמָה", "קוֹנִים בַּחֲנוּת"], tier: .hard),
        BankQuestion(prompt: "כַּמָּה עֲצָמוֹת יֵשׁ בְּעֶרֶךְ בְּגוּף הָאָדָם הַבּוֹגֵר?", correctAnswer: "206", distractors: ["100", "500", "50"], tier: .hard),
        BankQuestion(prompt: "מָה מוֹשֵׁךְ אוֹתָנוּ לְמַטָּה אֶל כַּדּוּר הָאָרֶץ?", correctAnswer: "כּוֹחַ הַכְּבִידָה", distractors: ["הָרוּחַ", "הַחַשְׁמַל", "הַמַּגְנֵט שֶׁבַּשָּׁמַיִם"], tier: .hard),
        BankQuestion(prompt: "אֵיזֶה גַּז אֲנַחְנוּ נוֹשְׁמִים כְּדֵי לִחְיוֹת?", correctAnswer: "חַמְצָן", distractors: ["פַּחְמָן דּוּ־חַמְצָנִי", "מֵימָן", "הֶלְיוּם"], tier: .hard),
        BankQuestion(prompt: "מִי מֵהֶם יוֹנֵק?", correctAnswer: "דּוֹלְפִין", distractors: ["כָּרִישׁ", "תַּנִּין", "צְפַרְדֵּעַ"], tier: .hard),
        BankQuestion(prompt: "כַּמָּה זְמַן לוֹקֵחַ לְכַדּוּר הָאָרֶץ לְהַשְׁלִים סִבּוּב סְבִיב הַשֶּׁמֶשׁ?", correctAnswer: "שָׁנָה", distractors: ["יוֹם", "חֹדֶשׁ", "שָׁבוּעַ"], tier: .hard),
        BankQuestion(prompt: "מָה הַמַּצָּב שֶׁל הַמַּיִם בְּקֶרַח?", correctAnswer: "מוּצָק", distractors: ["נוֹזֵל", "גַּז", "פְּלַסְמָה"], tier: .hard),
    ]

    // MARK: - היסטוריה

    static let history: [BankQuestion] = [
        BankQuestion(prompt: "בְּאֵיזוֹ שָׁנָה קָמָה מְדִינַת יִשְׂרָאֵל?", correctAnswer: "1948", distractors: ["1918", "1967", "1938"], tier: .hard),
        BankQuestion(prompt: "מִי הָיָה רֹאשׁ הַמֶּמְשָׁלָה הָרִאשׁוֹן שֶׁל יִשְׂרָאֵל?", correctAnswer: "דָּוִד בֶּן־גּוּרְיוֹן", distractors: ["חַיִּים וַיְצְמַן", "גּוֹלְדָּה מֵאִיר", "מְנַחֵם בֵּגִין"], tier: .hard),
        BankQuestion(prompt: "אֵיזֶה עַם בָּנָה אֶת הַפִּירָמִידוֹת?", correctAnswer: "הַמִּצְרִים הַקַּדְמוֹנִים", distractors: ["הָרוֹמָאִים", "הַיְּוָנִים", "הַבַּבְלִים"], tier: .hard),
        BankQuestion(prompt: "מִי הָיָה הָאָדָם הָרִאשׁוֹן שֶׁדָּרַךְ עַל הַיָּרֵחַ?", correctAnswer: "נִיל אַרְמְסְטְרוֹנְג", distractors: ["יוּרִי גָּגָרִין", "בָּאז אוֹלְדְרִין", "אַלְבֶּרְט אַיְנְשְׁטַיְן"], tier: .hard),
        BankQuestion(prompt: "אֵיךְ קָרְאוּ לַכְּתָב שֶׁל הַמִּצְרִים הַקַּדְמוֹנִים?", correctAnswer: "כְּתַב חַרְטֻמִּים", distractors: ["כְּתַב יְתֵדוֹת", "אָלֶף־בֵּית", "כְּתַב סִינִי"], tier: .hard),
        BankQuestion(prompt: "מִי הִמְצִיא אֶת הַנּוּרָה הַחַשְׁמַלִּית?", correctAnswer: "תּוֹמָס אֶדִיסוֹן", distractors: ["אַלְבֶּרְט אַיְנְשְׁטַיְן", "אִיסָק נְיוּטוֹן", "לֵאוֹנַרְדּוֹ דָּה וִינְצִ'י"], tier: .hard),
        BankQuestion(prompt: "אֵיזוֹ עִיר עַתִּיקָה נִקְבְּרָה תַּחַת הִתְפָּרְצוּת הַר גַּעַשׁ?", correctAnswer: "פּוֹמְפֵּיִי", distractors: ["אַתּוּנָה", "רוֹמָא", "יְרוּשָׁלַיִם"], tier: .hard),
        BankQuestion(prompt: "מִי צִיֵּר אֶת הַמּוֹנָה לִיזָה?", correctAnswer: "לֵאוֹנַרְדּוֹ דָּה וִינְצִ'י", distractors: ["פִּיקָאסוֹ", "וָן גּוֹךְ", "מִיכֶלְאַנְגֶ'לוֹ"], tier: .hard),
        BankQuestion(prompt: "עַל מָה מְסַפֵּר חַג הַחֲנֻכָּה?", correctAnswer: "נִצְחוֹן הַמַּכַּבִּים וְנֵס פַּךְ הַשֶּׁמֶן", distractors: ["יְצִיאַת מִצְרַיִם", "הַצָּלַת הַיְּהוּדִים בְּפָרַס", "קַבָּלַת הַתּוֹרָה"], tier: .hard),
        BankQuestion(prompt: "מִי הָיְתָה רֹאשׁ הַמֶּמְשָׁלָה הָאִשָּׁה הָרִאשׁוֹנָה שֶׁל יִשְׂרָאֵל?", correctAnswer: "גּוֹלְדָּה מֵאִיר", distractors: ["צִפִּי לִבְנִי", "שׁוּלַמִּית אַלּוֹנִי", "מִרְיָם הַנְּבִיאָה"], tier: .hard),
    ]

    // MARK: - גיאוגרפיה

    static let geography: [BankQuestion] = [
        BankQuestion(prompt: "מָה עִיר הַבִּירָה שֶׁל יַפָּן?", correctAnswer: "טוֹקְיוֹ", distractors: ["בֵּיגִ'ין", "סֵאוּל", "בַּנְגְקוֹק"], tier: .hard),
        BankQuestion(prompt: "מָה הַנָּהָר הָאָרֹךְ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הַנִּילוּס", distractors: ["הָאָמָזוֹנָס", "הַיַּרְדֵּן", "הַמִּיסִיסִיפִּי"], tier: .hard),
        BankQuestion(prompt: "בְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת מִצְרַיִם?", correctAnswer: "אַפְרִיקָה", distractors: ["אַסְיָה", "אֵירוֹפָּה", "אָמֵרִיקָה"], tier: .hard),
        BankQuestion(prompt: "מָה הַהַר הַגָּבוֹהַּ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "אֶוֶרֶסְט", distractors: ["הַחֶרְמוֹן", "קִילִימַנְגָ'רוֹ", "מוֹן בְּלָאן"], tier: .hard),
        BankQuestion(prompt: "אֵיזֶה יָם הוּא הַמָּקוֹם הַנָּמוּךְ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "יָם הַמֶּלַח", distractors: ["הַיָּם הַתִּיכוֹן", "יָם סוּף", "הַכִּנֶּרֶת"], tier: .hard),
        BankQuestion(prompt: "מָה עִיר הַבִּירָה שֶׁל אוֹסְטְרַלְיָה?", correctAnswer: "קַנְבֶּרָה", distractors: ["סִידְנִי", "מֶלְבּוּרְן", "פֶּרְת'"], tier: .hard),
        BankQuestion(prompt: "כַּמָּה יַבָּשׁוֹת יֵשׁ בָּעוֹלָם?", correctAnswer: "7", distractors: ["5", "6", "8"], tier: .hard),
        BankQuestion(prompt: "מָה הָאוֹקְיָנוֹס הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הַשָּׁקֵט", distractors: ["הָאַטְלַנְטִי", "הַהֹדִּי", "הַצְּפוֹנִי"], tier: .hard),
        BankQuestion(prompt: "בְּאֵיזוֹ מְדִינָה נִמְצָא מִגְדַּל אַיְפֶל?", correctAnswer: "צָרְפַת", distractors: ["אִיטַלְיָה", "סְפָרַד", "אַנְגְּלִיָּה"], tier: .hard),
        BankQuestion(prompt: "אֵיזוֹ מְדִינָה הִיא גַּם יַבֶּשֶׁת שְׁלֵמָה?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["הֹדּוּ", "בְּרָזִיל", "רוּסְיָה"], tier: .hard),
    ]

    // MARK: - כסף וחיים

    static let money: [BankQuestion] = [
        BankQuestion(prompt: "צַעֲצוּעַ עוֹלֶה 45 שְׁקָלִים. שִׁלַּמְתֶּם בְּשֵׁטָר שֶׁל 50. כַּמָּה עֹדֶף תְּקַבְּלוּ?", correctAnswer: "5 שְׁקָלִים", distractors: ["10 שְׁקָלִים", "15 שְׁקָלִים", "45 שְׁקָלִים"], tier: .hard),
        BankQuestion(prompt: "גְּלִידָה עוֹלָה 12 שְׁקָלִים. כַּמָּה יַעֲלוּ 3 גְּלִידוֹת?", correctAnswer: "36 שְׁקָלִים", distractors: ["24 שְׁקָלִים", "30 שְׁקָלִים", "42 שְׁקָלִים"], tier: .hard),
        BankQuestion(prompt: "יֵשׁ לָכֶם 100 שְׁקָלִים. קְנִיתֶם סֵפֶר בְּ־35 וּמִשְׂחָק בְּ־40. כַּמָּה נִשְׁאַר?", correctAnswer: "25 שְׁקָלִים", distractors: ["35 שְׁקָלִים", "15 שְׁקָלִים", "30 שְׁקָלִים"], tier: .hard),
        BankQuestion(prompt: "מָה זֶה \"חִסָּכוֹן\"?", correctAnswer: "כֶּסֶף שֶׁשּׁוֹמְרִים לֶעָתִיד בִּמְקוֹם לְבַזְבֵּז", distractors: ["כֶּסֶף שֶׁמּוֹצִיאִים מַהֵר", "מַתָּנָה מֵחֲבֵרִים", "סוּג שֶׁל מַטְבֵּעַ"], tier: .hard),
        BankQuestion(prompt: "אִם חוֹסְכִים 10 שְׁקָלִים כָּל שָׁבוּעַ, כַּמָּה יִהְיֶה אַחֲרֵי חֹדֶשׁ (4 שָׁבוּעוֹת)?", correctAnswer: "40 שְׁקָלִים", distractors: ["10 שְׁקָלִים", "30 שְׁקָלִים", "50 שְׁקָלִים"], tier: .hard),
        BankQuestion(prompt: "מָה זֶה \"מְחִיר מִבְצָע\"?", correctAnswer: "מְחִיר זוֹל מֵהָרָגִיל לִזְמַן מֻגְבָּל", distractors: ["הַמְּחִיר הַיָּקָר בְּיוֹתֵר", "מְחִיר שֶׁל מִבְצָע צְבָאִי", "מְחִיר שֶׁמְּשַׁלְּמִים רַק בַּקַּיִץ"], tier: .hard),
        BankQuestion(prompt: "חֻלְצָה עָלְתָה 60 שְׁקָלִים וְעַכְשָׁיו בַּחֲצִי מְחִיר. כַּמָּה הִיא עוֹלָה?", correctAnswer: "30 שְׁקָלִים", distractors: ["20 שְׁקָלִים", "40 שְׁקָלִים", "55 שְׁקָלִים"], tier: .hard),
        BankQuestion(prompt: "לָמָּה כְּדַאי לְהַשְׁווֹת מְחִירִים לִפְנֵי שֶׁקּוֹנִים?", correctAnswer: "כְּדֵי לִמְצֹא אֶת אוֹתוֹ מוּצָר בְּזוֹל יוֹתֵר", distractors: ["כְּדֵי לְבַזְבֵּז יוֹתֵר זְמַן", "כִּי זֶה חוֹבָה עַל פִּי חֹק", "כְּדֵי לִקְנוֹת כַּמָּה שֶׁיּוֹתֵר"], tier: .hard),
        BankQuestion(prompt: "מָה עוֹשֶׂה הַבַּנְק בַּכֶּסֶף שֶׁחוֹסְכִים אֶצְלוֹ?", correctAnswer: "שׁוֹמֵר אוֹתוֹ וְנוֹתֵן עָלָיו רִבִּית", distractors: ["מְבַזְבֵּז אוֹתוֹ", "זוֹרֵק אוֹתוֹ", "מַחְלִיף אוֹתוֹ בְּמַמְתַּקִּים"], tier: .hard),
        BankQuestion(prompt: "בַּאֲרוּחָה: פִּיצָה בְּ־28 שְׁקָלִים וְשֵׁתִיָּה בְּ־7. כַּמָּה בְּיַחַד?", correctAnswer: "35 שְׁקָלִים", distractors: ["33 שְׁקָלִים", "37 שְׁקָלִים", "38 שְׁקָלִים"], tier: .hard),
    ]
}
