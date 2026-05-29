import Foundation

/// A single hand-curated multiple-choice question used by topics where we
/// don't generate questions algorithmically (English, Logic, Science,
/// History, Geography).
struct BankQuestion {
    let prompt: String
    let correctAnswer: String
    let distractors: [String]
}

enum QuestionBanks {

    // MARK: - אנגלית

    static let english: [BankQuestion] = [
        BankQuestion(prompt: "🐈\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "cat", distractors: ["dog", "fish", "bird"]),
        BankQuestion(prompt: "🐕\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "dog", distractors: ["cat", "horse", "cow"]),
        BankQuestion(prompt: "🌞\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "sun", distractors: ["moon", "star", "sky"]),
        BankQuestion(prompt: "🍎\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "apple", distractors: ["banana", "orange", "pear"]),
        BankQuestion(prompt: "🏠\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "house", distractors: ["car", "tree", "school"]),
        BankQuestion(prompt: "📚\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "book", distractors: ["pen", "table", "chair"]),
        BankQuestion(prompt: "🚗\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "car", distractors: ["bus", "bike", "boat"]),
        BankQuestion(prompt: "🌳\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "tree", distractors: ["flower", "grass", "leaf"]),
        BankQuestion(prompt: "💧\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "water", distractors: ["fire", "ice", "milk"]),
        BankQuestion(prompt: "⭐\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "star", distractors: ["sun", "moon", "cloud"]),
        BankQuestion(prompt: "🌙\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "moon", distractors: ["star", "sun", "night"]),
        BankQuestion(prompt: "🥛\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "milk", distractors: ["water", "juice", "tea"]),
        BankQuestion(prompt: "🍞\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bread", distractors: ["cake", "rice", "egg"]),
        BankQuestion(prompt: "🐟\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "fish", distractors: ["cat", "dog", "bird"]),
        BankQuestion(prompt: "🐦\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bird", distractors: ["fish", "frog", "duck"]),
        BankQuestion(prompt: "🌸\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "flower", distractors: ["tree", "leaf", "grass"]),
        BankQuestion(prompt: "🐘\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "elephant", distractors: ["lion", "bear", "tiger"]),
        BankQuestion(prompt: "🦁\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "lion", distractors: ["tiger", "bear", "elephant"]),
        BankQuestion(prompt: "🚲\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bike", distractors: ["car", "bus", "train"]),
        BankQuestion(prompt: "🎂\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "cake", distractors: ["bread", "milk", "fruit"]),
        BankQuestion(prompt: "✋\nאֵיךְ אוֹמְרִים 'יָד' בְּאַנְגְּלִית?", correctAnswer: "hand", distractors: ["foot", "head", "eye"]),
        BankQuestion(prompt: "👁️\nאֵיךְ אוֹמְרִים 'עַיִן' בְּאַנְגְּלִית?", correctAnswer: "eye", distractors: ["ear", "nose", "mouth"]),
        BankQuestion(prompt: "What does 'apple' mean?", correctAnswer: "תַּפּוּחַ", distractors: ["בָּנָנָה", "תַּפּוּז", "אַגָּס"]),
        BankQuestion(prompt: "What does 'book' mean?", correctAnswer: "סֵפֶר", distractors: ["מַחְבֶּרֶת", "עֵט", "מִכְתָּב"]),
        BankQuestion(prompt: "What does 'tree' mean?", correctAnswer: "עֵץ", distractors: ["פֶּרַח", "עָלֶה", "עָנָף"])
    ]

    // MARK: - לוגיקה

    static let logic: [BankQuestion] = [
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n1, 2, 3, ?", correctAnswer: "4", distractors: ["5", "6", "2"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n2, 4, 6, ?", correctAnswer: "8", distractors: ["7", "10", "9"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n5, 10, 15, ?", correctAnswer: "20", distractors: ["25", "16", "18"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n10, 9, 8, ?", correctAnswer: "7", distractors: ["6", "11", "5"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n🔴🟢🔴🟢🔴?", correctAnswer: "🟢", distractors: ["🔴", "🔵", "🟡"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\n🐶🐱🐶🐱🐶?", correctAnswer: "🐱", distractors: ["🐶", "🐭", "🐰"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "🚗", distractors: ["🐶", "🐱", "🐰"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "🍎", distractors: ["🚗", "🚌", "🚲"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "📖", distractors: ["⚽", "🏀", "🎾"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "🌳", distractors: ["☀️", "🌙", "⭐"]),
        BankQuestion(prompt: "אִם 🍎=2, אָז 🍎+🍎=?", correctAnswer: "4", distractors: ["3", "5", "2"]),
        BankQuestion(prompt: "אִם 🐱>🐭, אָז מִי גָּדוֹל יוֹתֵר?", correctAnswer: "🐱", distractors: ["🐭", "אוֹתוֹ דָּבָר", "לֹא יוֹדֵעַ"]),
        BankQuestion(prompt: "מָה הַצּוּרָה הַבָּאָה?\n🔺🔻🔺🔻🔺?", correctAnswer: "🔻", distractors: ["🔺", "⬛", "⚫"]),
        BankQuestion(prompt: "כַּמָּה רַגְלַיִם יֵשׁ לְ-3 כְּלָבִים?", correctAnswer: "12", distractors: ["6", "8", "10"]),
        BankQuestion(prompt: "אִם דָּנָה גְּדוֹלָה מִמִּיכַל וּמִיכַל גְּדוֹלָה מִתּוֹם, מִי הֲכִי גָּדוֹל?", correctAnswer: "דָּנָה", distractors: ["מִיכַל", "תּוֹם", "אוֹתוֹ דָּבָר"]),
        BankQuestion(prompt: "מָה דּוֹמֶה?\n🍎 🍌 🍇 🐶", correctAnswer: "🐶 לֹא דּוֹמֶה", distractors: ["🍎 לֹא דּוֹמֶה", "🍌 לֹא דּוֹמֶה", "🍇 לֹא דּוֹמֶה"]),
        BankQuestion(prompt: "אִם הַיּוֹם שְׁלִישִׁי, מָה הָיָה אֶתְמוֹל?", correctAnswer: "שֵׁנִי", distractors: ["רְבִיעִי", "רִאשׁוֹן", "חֲמִישִׁי"]),
        BankQuestion(prompt: "אִם 5 צִיפּוֹרִים עַל עֵץ וְ-2 עָפוּ, כַּמָּה נִשְׁאֲרוּ?", correctAnswer: "3", distractors: ["7", "2", "4"]),
        BankQuestion(prompt: "מָה בָּא אַחֲרֵי?\nA, B, C, ?", correctAnswer: "D", distractors: ["E", "A", "C"]),
        BankQuestion(prompt: "בְּאֵיזוֹ צוּרָה אֵין פִּינּוֹת?", correctAnswer: "⚪", distractors: ["🔺", "⬛", "⬢"])
    ]

    // MARK: - מדע

    static let science: [BankQuestion] = [
        BankQuestion(prompt: "🕷️\nכַּמָּה רַגְלַיִם יֵשׁ לְעַכָּבִישׁ?", correctAnswer: "8", distractors: ["6", "10", "4"]),
        BankQuestion(prompt: "🌱\nמֵאֵיפֹה צְמָחִים מְקַבְּלִים אֶנֶרְגְּיָה?", correctAnswer: "מֵהַשֶּׁמֶשׁ", distractors: ["מֵהָאֲדָמָה", "מֵהָאֲוִיר", "מֵהַיָּרֵחַ"]),
        BankQuestion(prompt: "🌍\nכַּמָּה יָמִים יֵשׁ בַּשָּׁבוּעַ?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "🌈\nכַּמָּה צְבָעִים יֵשׁ בַּקֶּשֶׁת?", correctAnswer: "7", distractors: ["5", "6", "10"]),
        BankQuestion(prompt: "👂\nבְּאֵיזֶה אֵיבָר אֲנַחְנוּ שׁוֹמְעִים?", correctAnswer: "אוֹזְנַיִם", distractors: ["עֵינַיִם", "אַף", "פֶּה"]),
        BankQuestion(prompt: "🐝\nאֵיזוֹ חַיָּה עוֹשָׂה דְּבַשׁ?", correctAnswer: "דְּבוֹרָה", distractors: ["נְמָלָה", "זְבוּב", "פַּרְפַּר"]),
        BankQuestion(prompt: "❄️\nמָה קוֹרֶה לַמַּיִם בַּקֹּר?", correctAnswer: "קוֹפְאִים", distractors: ["מִתְאַדִּים", "נֶעֱלָמִים", "מִתְחַמְּמִים"]),
        BankQuestion(prompt: "🌡️\nאֵיךְ מוֹדְדִים חוֹם?", correctAnswer: "בְּמַדְחוֹם", distractors: ["בְּמִשְׁקָל", "בְּסַרְגֵּל", "בְּשָׁעוֹן"]),
        BankQuestion(prompt: "🦷\nכַּמָּה שִׁנַּיִם יֵשׁ לְאָדָם מְבֻגָּר?", correctAnswer: "32", distractors: ["20", "28", "40"]),
        BankQuestion(prompt: "🦴\nכַּמָּה יָמִים יֵשׁ בַּשָּׁנָה?", correctAnswer: "365", distractors: ["360", "350", "400"]),
        BankQuestion(prompt: "🌙\nכַּמָּה זְמַן לוֹקֵחַ לַיָּרֵחַ לְהַקִּיף אֶת כַּדּוּר הָאָרֶץ?", correctAnswer: "כְּחֹדֶשׁ", distractors: ["יוֹם", "שָׁנָה", "שָׁבוּעַ"]),
        BankQuestion(prompt: "☀️\nמָה הַכּוֹכָב הַקָּרוֹב בְּיוֹתֵר לְכַדּוּר הָאָרֶץ?", correctAnswer: "הַשֶּׁמֶשׁ", distractors: ["הַיָּרֵחַ", "מַאְדִּים", "צֶדֶק"]),
        BankQuestion(prompt: "🐠\nאֵיפֹה דָּגִים נוֹשְׁמִים?", correctAnswer: "בַּמַּיִם", distractors: ["בָּאֲוִיר", "בָּאֲדָמָה", "בָּעֵץ"]),
        BankQuestion(prompt: "🦋\nמִמָּה הוֹפֵךְ זַחַל?", correctAnswer: "לְפַרְפַּר", distractors: ["לִדְבוֹרָה", "לְצִיפּוֹר", "לְעַכָּבִישׁ"]),
        BankQuestion(prompt: "🌋\nמָה יוֹצֵא מֵהַר גַּעַשׁ?", correctAnswer: "לָבָה", distractors: ["מַיִם", "שֶׁלֶג", "חוֹל"]),
        BankQuestion(prompt: "💨\nמִמָּה עָשׂוּי אֲוִיר?", correctAnswer: "גַּזִּים", distractors: ["מַיִם", "אָבָק", "כְּלוּם"]),
        BankQuestion(prompt: "🌊\nמָה גּוֹרֵם לְגַלִּים בַּיָּם?", correctAnswer: "רוּחַ", distractors: ["דָּגִים", "הַשֶּׁמֶשׁ", "אֲבָנִים"]),
        BankQuestion(prompt: "🦷\nאֵיךְ נִקְרָא הַצֶּמַח שֶׁיֵּשׁ בַּשִּׁנַּיִם?", correctAnswer: "אֱמַייְל", distractors: ["סֻכָּר", "סִיד", "בַּרְזֶל"]),
        BankQuestion(prompt: "🚀\nאֵיךְ נִקְרָא הַכּוֹכָב הָאָדֹם?", correctAnswer: "מַאְדִּים", distractors: ["צֶדֶק", "שַׁבְתַאי", "נוֹגַהּ"]),
        BankQuestion(prompt: "🧠\nאֵיזֶה אֵיבָר עוֹזֵר לָנוּ לַחְשֹׁב?", correctAnswer: "הַמּוֹחַ", distractors: ["הַלֵּב", "הַקֵּבָה", "הָרֵאוֹת"])
    ]

    // MARK: - היסטוריה

    static let history: [BankQuestion] = [
        BankQuestion(prompt: "🇮🇱\nבְּאֵיזוֹ שָׁנָה הוּקְמָה מְדִינַת יִשְׂרָאֵל?", correctAnswer: "1948", distractors: ["1945", "1950", "1967"]),
        BankQuestion(prompt: "👨‍💼\nמִי הָיָה רֹאשׁ הַמֶּמְשָׁלָה הָרִאשׁוֹן שֶׁל יִשְׂרָאֵל?", correctAnswer: "דָּוִד בֶּן גּוּרְיוֹן", distractors: ["יִצְחָק רַבִּין", "מְנַחֵם בֵּגִין", "גּוֹלְדָּה מֵאִיר"]),
        BankQuestion(prompt: "🕯️\nבְּאֵיזֶה חַג מַדְלִיקִים נֵרוֹת 8 יָמִים?", correctAnswer: "חֲנֻכָּה", distractors: ["פֶּסַח", "סֻכּוֹת", "פּוּרִים"]),
        BankQuestion(prompt: "🥯\nבְּאֵיזֶה חַג אוֹכְלִים מַצּוֹת?", correctAnswer: "פֶּסַח", distractors: ["חֲנֻכָּה", "רֹאשׁ הַשָּׁנָה", "שָׁבוּעוֹת"]),
        BankQuestion(prompt: "🎭\nבְּאֵיזֶה חַג מִתְחַפְּשִׂים?", correctAnswer: "פּוּרִים", distractors: ["סֻכּוֹת", "חֲנֻכָּה", "פֶּסַח"]),
        BankQuestion(prompt: "🌳\nבְּאֵיזֶה חַג שׁוֹתְלִים עֵצִים?", correctAnswer: "ט\"וּ בִּשְׁבָט", distractors: ["יוֹם הָעַצְמָאוּת", "שָׁבוּעוֹת", "ל\"ג בָּעֹמֶר"]),
        BankQuestion(prompt: "🇮🇱\nאֵיךְ קוֹרְאִים לַדֶּגֶל שֶׁל יִשְׂרָאֵל?", correctAnswer: "מָגֵן דָּוִד", distractors: ["סַהַר", "צְלָב", "כּוֹכָב"]),
        BankQuestion(prompt: "📜\nמָה כָּתוּב בִּמְגִילַּת הָעַצְמָאוּת?", correctAnswer: "הֲקָמַת מְדִינַת יִשְׂרָאֵל", distractors: ["סִיפּוּר פֶּסַח", "מַתְכּוֹן", "שִׁיר"]),
        BankQuestion(prompt: "👑\nמִי הָיָה הַמֶּלֶךְ הָרִאשׁוֹן שֶׁל יִשְׂרָאֵל?", correctAnswer: "שָׁאוּל", distractors: ["דָּוִד", "שְׁלֹמֹה", "אַבְרָהָם"]),
        BankQuestion(prompt: "🏛️\nמִי בָּנָה אֶת בֵּית הַמִּקְדָּשׁ הָרִאשׁוֹן?", correctAnswer: "שְׁלֹמֹה", distractors: ["דָּוִד", "מֹשֶׁה", "שָׁאוּל"]),
        BankQuestion(prompt: "🏺\nמָה הָיָה אֵצֶל הַמַּכַּבִּים שֶׁמַּסְפִּיק לְשֶׁמֶן רַק יוֹם אֶחָד?", correctAnswer: "פַּךְ שֶׁמֶן", distractors: ["מַצָּה", "שׁוֹפָר", "סֵפֶר"]),
        BankQuestion(prompt: "🐑\nמִי הוֹצִיא אֶת בְּנֵי יִשְׂרָאֵל מִמִּצְרַיִם?", correctAnswer: "מֹשֶׁה", distractors: ["יוֹסֵף", "אַבְרָהָם", "דָּוִד"]),
        BankQuestion(prompt: "🏛️\nהַאִם הַפִּירָמִידוֹת בְּמִצְרַיִם נִבְנוּ ע\"י הַמִּצְרִים הַקַּדְמוֹנִים?", correctAnswer: "כֵּן", distractors: ["לֹא", "ע\"י רוֹמָאִים", "ע\"י יְוָונִים"]),
        BankQuestion(prompt: "🇺🇸\nאֵיזֶה יַבֶּשֶׁת גִּילָּה קוֹלוּמְבּוּס?", correctAnswer: "אָמֵרִיקָה", distractors: ["אַפְרִיקָה", "אוֹסְטְרַלְיָה", "אַסְיָה"]),
        BankQuestion(prompt: "📡\nמִי הִמְצִיא אֶת הַטֶּלֶפוֹן?", correctAnswer: "אָלֶכְּסַנְדֶּר גְּרַהַם בֶּל", distractors: ["אַיְינְשְׁטַיְין", "אֶדִיסוֹן", "בִּילְגֵייטְס"]),
        BankQuestion(prompt: "💡\nמִי הִמְצִיא אֶת הַנּוּרָה?", correctAnswer: "תּוֹמַאס אֶדִיסוֹן", distractors: ["אַיְינְשְׁטַיְין", "נְיוּטוֹן", "טֶסְלָה"]),
        BankQuestion(prompt: "📕\nמָה הַשָּׂפָה שֶׁל הַתַּנַ\"ךְ?", correctAnswer: "עִבְרִית", distractors: ["אַנְגְּלִית", "עֲרָבִית", "אֲרָמִית"]),
        BankQuestion(prompt: "📜\nאֵיפֹה חָיוּ הָאָבוֹת אַבְרָהָם, יִצְחָק וְיַעֲקֹב?", correctAnswer: "בְּאֶרֶץ יִשְׂרָאֵל", distractors: ["בְּמִצְרַיִם", "בְּאָמֵרִיקָה", "בְּאֵירוֹפָּה"]),
        BankQuestion(prompt: "📚\nכַּמָּה סְפָרִים יֵשׁ בַּתּוֹרָה?", correctAnswer: "5", distractors: ["7", "10", "3"]),
        BankQuestion(prompt: "🛡️\nמִי לָחַם בְּגָלְיָת?", correctAnswer: "דָּוִד", distractors: ["מֹשֶׁה", "שְׁלֹמֹה", "שָׁאוּל"])
    ]

    // MARK: - גיאוגרפיה

    static let geography: [BankQuestion] = [
        BankQuestion(prompt: "🇮🇱\nמָה בִּירַת יִשְׂרָאֵל?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"]),
        BankQuestion(prompt: "🌊\nאֵיזֶה יָם נִמְצָא מִמַּעֲרָב לְיִשְׂרָאֵל?", correctAnswer: "הַיָּם הַתִּיכוֹן", distractors: ["יָם סוּף", "יָם הַמֶּלַח", "הָאוֹקְיָינוֹס"]),
        BankQuestion(prompt: "🏞️\nמָה הַיָּם הַמָּלוּחַ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "יָם הַמֶּלַח", distractors: ["הַיָּם הַתִּיכוֹן", "יָם סוּף", "הַיָּם הַשָּׁחוֹר"]),
        BankQuestion(prompt: "🌎\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת יִשְׂרָאֵל?", correctAnswer: "אַסְיָה", distractors: ["אַפְרִיקָה", "אֵירוֹפָּה", "אָמֵרִיקָה"]),
        BankQuestion(prompt: "🗽\nמָה בִּירַת אַרְהַ\"ב?", correctAnswer: "וָשִׁינְגְּטוֹן", distractors: ["נְיוּ יוֹרְק", "לוֹס אַנְגֶּ'לֶס", "שִׁיקָגוֹ"]),
        BankQuestion(prompt: "🗼\nבְּאֵיזוֹ אֶרֶץ נִמְצָא מִגְדַּל אַייְפֶל?", correctAnswer: "צָרְפַת", distractors: ["אִיטַלְיָה", "אַנְגְּלִיָּה", "סְפָרַד"]),
        BankQuestion(prompt: "🐼\nאֵיפֹה חַיִּים פַּנְדּוֹת?", correctAnswer: "סִין", distractors: ["יָפָן", "אוֹסְטְרַלְיָה", "הוֹדּוּ"]),
        BankQuestion(prompt: "🦘\nאֵיפֹה חַיִּים קֶנְגּוּרוּ?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["אַפְרִיקָה", "אָמֵרִיקָה", "אֵירוֹפָּה"]),
        BankQuestion(prompt: "🐧\nאֵיפֹה חַיִּים פִּינְגְּוִוינִים?", correctAnswer: "בְּאַנְטַארְקְטִיקָה", distractors: ["בַּיָּם הַתִּיכוֹן", "בְּאַפְרִיקָה", "בְּאָמֵרִיקָה"]),
        BankQuestion(prompt: "🏔️\nמָה הָהָר הַגָּבוֹהַּ בָּעוֹלָם?", correctAnswer: "אֶוֶרֶסְט", distractors: ["חֶרְמוֹן", "קִילִימַנְגֶּ'רוֹ", "אַלְפִּים"]),
        BankQuestion(prompt: "🌊\nמָה הַיָּם הַגָּדוֹל בְּיוֹתֵר?", correctAnswer: "הָאוֹקְיָינוֹס הַשָּׁקֵט", distractors: ["הַיָּם הַתִּיכוֹן", "הָאַטְלַנְטִי", "הַהוֹדִי"]),
        BankQuestion(prompt: "🏞️\nמָה הַנָּהָר הָאָרֹךְ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הַנִּילוּס", distractors: ["הַיַּרְדֵּן", "הָאָמָזוֹנָס", "הַמִּיסִיסִיפִּי"]),
        BankQuestion(prompt: "🌍\nכַּמָּה יַבָּשׁוֹת יֵשׁ בָּעוֹלָם?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "🐘\nאֵיפֹה חַיִּים פִּילִים?", correctAnswer: "בְּאַפְרִיקָה וְהוֹדּוּ", distractors: ["בְּיִשְׂרָאֵל", "בְּאוֹסְטְרַלְיָה", "בְּאַנְטַארְקְטִיקָה"]),
        BankQuestion(prompt: "🇮🇹\nמָה בִּירַת אִיטַלְיָה?", correctAnswer: "רוֹמָא", distractors: ["מִילָאנוֹ", "פִירֶנְצֶה", "וֶנֵצְיָה"]),
        BankQuestion(prompt: "🇪🇸\nמָה בִּירַת סְפָרַד?", correctAnswer: "מַדְרִיד", distractors: ["בַּרְצֵלוֹנָה", "סֵבִילְיָה", "וָלֶנְסְיָה"]),
        BankQuestion(prompt: "🇬🇧\nמָה בִּירַת אַנְגְּלִיָּה?", correctAnswer: "לוֹנְדּוֹן", distractors: ["מַנְצֶ'סְטֶר", "לִיבֶרְפּוּל", "אֶדִינְבּוֹרוֹ"]),
        BankQuestion(prompt: "🇯🇵\nמָה בִּירַת יָפָן?", correctAnswer: "טוֹקְיוֹ", distractors: ["סֵיאוּל", "פֵּקִין", "הוֹנְג קוֹנְג"]),
        BankQuestion(prompt: "🏜️\nמָה הַמִּדְבָּר הַגָּדוֹל בְּיִשְׂרָאֵל?", correctAnswer: "הַנֶּגֶב", distractors: ["סַהַרָה", "סִינַי", "עֲרָבָה"]),
        BankQuestion(prompt: "🌍\nמָה הַיַּבֶּשֶׁת הַגְּדוֹלָה בְּיוֹתֵר?", correctAnswer: "אַסְיָה", distractors: ["אַפְרִיקָה", "אָמֵרִיקָה", "אֵירוֹפָּה"])
    ]

    /// Hebrew spelling (איות) — pick the correctly-spelled word among plausible
    /// single-letter mistakes kids commonly make (כ/ח, ת/ט, ק/כ, ס/שׂ, א/ע/ה).
    static let hebrew: [BankQuestion] = [
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "חָתוּל",   distractors: ["כָּתוּל", "חָטוּל", "חָתֻל"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "שֻׁלְחָן",  distractors: ["סֻלְחָן", "שֻׁלְכָן", "שֻׁלְחַן"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "כַּדּוּר",   distractors: ["קַדּוּר", "גַּדּוּר", "כַּדֻּר"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "מַחְבֶּרֶת",  distractors: ["מַהְבֶּרֶת", "מַכְבֶּרֶת", "מַחְבֶּרֶט"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "צָהֹב",   distractors: ["סָהֹב", "צָחֹב", "זָהֹב"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "אוֹטוֹבּוּס", distractors: ["עוֹטוֹבּוּס", "אוֹטוֹבּוּז", "אוֹטוֹפּוּס"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "סֵפֶר",    distractors: ["סֵבֶר", "שֵׁפֶר", "צֵפֶר"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "תַּפּוּז",   distractors: ["טַפּוּז", "תַּפּוּס", "דַּפּוּז"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "מַיִם",    distractors: ["מַיִים", "מַימ", "נַיִם"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "יֶלֶד",    distractors: ["יֶעֶלֶד", "יֶלֶט", "יִילֶד"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "כֶּלֶב",    distractors: ["קֶלֶב", "כֶּלֶף", "גֶּלֶב"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "בַּיִת",    distractors: ["בַּיִט", "פַּית", "בַּעַת"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "עֵץ",     distractors: ["אֵץ", "עֵס", "חֵץ"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "אַרְנָב",   distractors: ["עַרְנָב", "אַרְנָף", "הַרְנָב"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "גֶּשֶׁם",    distractors: ["קֶשֶׁם", "גֶּסֶם", "גֶּשֶׁמ"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "חָבֵר",    distractors: ["כָּבֵר", "הָבֵר", "חָפֵר"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "שֶׁמֶשׁ",    distractors: ["שֶׁמֶס", "סֶמֶשׁ", "צֶמֶשׁ"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "עוּגָה",   distractors: ["אוּגָה", "עוּקָה", "עוּגַע"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "מְקָרֵר",   distractors: ["מְכָרֵר", "מְקָר", "נְקָרֵר"]),
        BankQuestion(prompt: "אֵיךְ כּוֹתְבִים נָכוֹן?", correctAnswer: "כְּבִישׁ",   distractors: ["קְבִישׁ", "כְּבִית", "גְּבִישׁ"]),
    ]

    /// Original + expanded — call sites get the full combined pool.
    static func bank(for topic: Topic) -> [BankQuestion]? {
        switch topic {
        case .english:   return english   + QuestionBanksExpanded.english
        case .hebrew:    return hebrew
        case .logic:     return logic     + QuestionBanksExpanded.logic
        case .science:   return science   + QuestionBanksExpanded.science
        case .history:   return history   + QuestionBanksExpanded.history
        case .geography: return geography + QuestionBanksExpanded.geography
        case .math:      return nil  // generated algorithmically
        }
    }
}

// MARK: - Anti-repeat memory

/// Keeps the most-recently-served questions per topic so the runner
/// doesn't repeat items inside a session OR across the next few
/// sessions. Window slides at ~85% of the pool — when the pool refreshes
/// the kid won't see the same question for a long time.
///
/// Persisted to UserDefaults (per profile when a profile is active) so
/// closing and reopening the app doesn't erase the memory.
final class QuestionMemory {
    static let shared = QuestionMemory()
    // Init is intentionally empty so we never reach back into
    // ProfileStore.shared during its own dispatch_once boot. The first
    // call to pickFresh / reloadForActiveProfile lazily loads from disk.
    private init() {}

    private let defaults = UserDefaults.standard
    private var recent: [Topic: [String]] = [:]
    private var hasLoaded = false

    private var storageKey: String {
        let pid = ProfileStore.shared.activeID?.uuidString ?? "default"
        return "questionMemory.\(pid)"
    }

    private func ensureLoaded() {
        guard !hasLoaded else { return }
        load()
        hasLoaded = true
    }

    /// Pick a random question from `pool` that hasn't been served recently.
    /// Falls back to a true random when every question is in the recent
    /// window (only possible for very small pools).
    func pickFresh(_ pool: [BankQuestion], for topic: Topic) -> BankQuestion? {
        ensureLoaded()
        guard !pool.isEmpty else { return nil }
        // 85% — leaves a small pool of "fresh" candidates and keeps a long
        // tail of "already seen recently" out of rotation. With ~80 English
        // questions the kid will go through ~68 before any can repeat.
        let windowSize = max(5, (pool.count * 85) / 100)
        let recentList = recent[topic] ?? []
        let candidates = pool.filter { !recentList.contains(promptKey($0)) }
        let chosen = (candidates.isEmpty ? pool : candidates).randomElement()
        if let chosen {
            remember(promptKey(chosen), in: topic, windowSize: windowSize)
        }
        return chosen
    }

    /// Wipe memory for a specific profile (used by remote-reset).
    func clear(for profileID: UUID? = nil) {
        recent = [:]
        let key = profileID.map { "questionMemory.\($0.uuidString)" } ?? storageKey
        defaults.removeObject(forKey: key)
    }

    /// Pull state for the freshly-active profile.
    func reloadForActiveProfile() {
        load()
        hasLoaded = true
    }

    private func promptKey(_ q: BankQuestion) -> String { q.prompt }

    private func remember(_ key: String, in topic: Topic, windowSize: Int) {
        var list = recent[topic] ?? []
        list.append(key)
        if list.count > windowSize { list.removeFirst(list.count - windowSize) }
        recent[topic] = list
        save()
    }

    // MARK: - Persistence (per profile)

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            recent = [:]
            return
        }
        var rebuilt: [Topic: [String]] = [:]
        for (rawTopic, list) in decoded {
            if let t = Topic(rawValue: rawTopic) { rebuilt[t] = list }
        }
        recent = rebuilt
    }

    private func save() {
        let encodable = recent.reduce(into: [String: [String]]()) { dict, pair in
            dict[pair.key.rawValue] = pair.value
        }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
