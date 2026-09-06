import Foundation

/// 🌊 מַעֲמַקֵּי הַיָּם — sea & ocean question pack for גן–ה׳. Only timeless,
/// verified facts (animals, seas around Israel, oceans, tides, salt water,
/// divers & submarines, simple counting) — nothing that goes stale and nothing
/// frightening. Grade-tagged like every bank (compiler-enforced).
enum QuestionBanksSea {
    static let sea: [BankQuestion] = [
        // ── קַל · חַיּוֹת הַיָּם ──
        BankQuestion(prompt: "🦈\nמִי מִבֵּין אֵלֶּה חַי בַּיָּם?", correctAnswer: "כָּרִישׁ", distractors: ["פָּרָה", "סוּס", "תַּרְנְגוֹל"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐬\nאֵיזוֹ חַיַּת יָם יְדוּעָה כַּחֲכָמָה וִידִידוּתִית, וְאוֹהֶבֶת לִקְפֹּץ מֵהַמַּיִם?", correctAnswer: "דּוֹלְפִין", distractors: ["תַּנִּין", "צָב", "אַרְנָב"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐙\nכַּמָּה זְרוֹעוֹת יֵשׁ לְתַמְנוּן?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐙\nאֵיךְ קוֹרְאִים לַחַיָּה הָרַכָּה עִם 8 זְרוֹעוֹת?", correctAnswer: "תַּמְנוּן", distractors: ["כָּרִישׁ", "צָב", "סַרְטָן"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐙\nכַּמָּה לְבָבוֹת יֵשׁ לְתַמְנוּן?", correctAnswer: "3", distractors: ["1", "2", "5"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐢\nמַה יֵשׁ לְצַב הַיָּם עַל הַגַּב?", correctAnswer: "שִׁרְיוֹן", distractors: ["כְּנָפַיִם", "פַּרְוָה", "קַרְנַיִם"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐢\nאֵיפֹה צַבַּת הַיָּם מַטִּילָה אֶת הַבֵּיצִים שֶׁלָּהּ?", correctAnswer: "בַּחוֹל עַל הַחוֹף", distractors: ["בְּעֹמֶק הַיָּם", "עַל עֵץ", "בַּשֶּׁלֶג"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐋\nמִי הַחַיָּה הַגְּדוֹלָה בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הַלִּוְיָתָן הַכָּחֹל", distractors: ["הַפִּיל", "הַכָּרִישׁ", "הַגִּ'ירָפָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐬\nמַה עוֹשֶׂה הַדּוֹלְפִין כְּשֶׁהוּא עוֹלֶה אֶל פְּנֵי הַמַּיִם?", correctAnswer: "נוֹשֵׁם אֲוִיר", distractors: ["יָשֵׁן", "אוֹכֵל חוֹל", "מִתְיַבֵּשׁ"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐟\nבְּעֶזְרַת מָה הַדָּג נוֹשֵׁם מִתַּחַת לַמַּיִם?", correctAnswer: "זִימִים", distractors: ["רֵאוֹת", "אַף", "פֶּה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐠\nמַה עוֹזֵר לַדָּג לִשְׂחוֹת?", correctAnswer: "סְנַפִּירִים", distractors: ["רַגְלַיִם", "כְּנָפַיִם", "יָדַיִם"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐟\nבַּמֶּה מְכֻסֶּה הַגּוּף שֶׁל רֹב הַדָּגִים?", correctAnswer: "קַשְׂקַשִּׂים", distractors: ["פַּרְוָה", "נוֹצוֹת", "שֵׂעָר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐟\nאֵיפֹה חַיִּים דָּגִים?", correctAnswer: "בַּמַּיִם", distractors: ["בָּאֲוִיר", "עַל עֵצִים", "בַּמִּדְבָּר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦈\nמָה יֵשׁ לַכָּרִישׁ הַרְבֵּה מְאוֹד, וְהֵן מִתְחַלְּפוֹת כָּל הַזְּמַן?", correctAnswer: "שִׁנַּיִם", distractors: ["עֵינַיִם", "אָזְנַיִם", "רַגְלַיִם"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪼\nאֵיזוֹ חַיַּת יָם רַכָּה וּשְׁקוּפָה, עִם זְרוֹעוֹת אֲרֻכּוֹת, מַגִּיעָה לְחוֹפֵי יִשְׂרָאֵל בַּקַּיִץ?", correctAnswer: "מֶדוּזָה", distractors: ["צָב", "דּוֹלְפִין", "סַרְטָן"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦀\nאֵיזוֹ חַיָּה הוֹלֶכֶת הַצִּדָּה עַל הַחוֹף, וְיֵשׁ לָהּ צְבָתוֹת?", correctAnswer: "סַרְטָן", distractors: ["דָּג", "מֶדוּזָה", "צָב"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "⭐\nאֵיזוֹ חַיַּת יָם נִרְאֵית כְּמוֹ כּוֹכָב, וְיֵשׁ לָהּ 5 זְרוֹעוֹת?", correctAnswer: "כּוֹכַב יָם", distractors: ["סוּס יָם", "דַּג חֶרֶב", "מֶדוּזָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐴\nאֵיזֶה דָּג קָטָן נִרְאֶה כְּמוֹ סוּס, וְשׂוֹחֶה בְּמַצָּב זָקוּף?", correctAnswer: "סוּס יָם", distractors: ["כּוֹכַב יָם", "כָּרִישׁ", "צְלוֹפָח"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦭\nאֵיזוֹ חַיָּה שׂוֹחָה בַּיָּם וְגַם נָחָה עַל הַסְּלָעִים, וְיֵשׁ לָהּ שָׂפָם?", correctAnswer: "כֶּלֶב יָם", distractors: ["כָּרִישׁ", "דַּג זָהָב", "מֶדוּזָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐚\nמַה אֶפְשָׁר לִמְצֹא עַל חוֹף הַיָּם?", correctAnswer: "צְדָפִים", distractors: ["אִצְטְרֻבָּלִים", "פְּטָרִיּוֹת", "שֶׁלֶג"], tier: .easy, grades: 0...1),

        // ── קַל · יַמִּים, מַיִם וּכְלֵי שַׁיִט ──
        BankQuestion(prompt: "🧂\nאֵיזֶה טַעַם יֵשׁ לְמֵי הַיָּם?", correctAnswer: "מָלוּחַ", distractors: ["מָתוֹק", "חָמוּץ", "מַר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌍\nרֹב כַּדּוּר הָאָרֶץ מְכֻסֶּה בְּ…", correctAnswer: "מַיִם", distractors: ["חוֹל", "קֶרַח", "יַעַר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🪸\nבְּאֵיזוֹ עִיר בְּיִשְׂרָאֵל אֶפְשָׁר לִרְאוֹת שׁוּנִית אַלְמֻגִּים?", correctAnswer: "בְּאֵילַת", distractors: ["בְּתֵל אָבִיב", "בִּירוּשָׁלַיִם", "בְּחֵיפָה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🌊\nאֵיךְ קוֹרְאִים לַמַּיִם שֶׁעוֹלִים וְיוֹרְדִים עַל הַחוֹף שׁוּב וָשׁוּב?", correctAnswer: "גַּלִּים", distractors: ["עֲנָנִים", "גְּשָׁמִים", "רוּחוֹת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🏖️\nאֵיךְ קוֹרְאִים לַמָּקוֹם שֶׁבּוֹ הַיָּם פּוֹגֵשׁ אֶת הַיַּבָּשָׁה?", correctAnswer: "חוֹף", distractors: ["הַר", "יַעַר", "מִדְבָּר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌡️\nאֵיפֹה מֵי הַיָּם בְּדֶרֶךְ כְּלָל חַמִּים יוֹתֵר — קָרוֹב לִפְנֵי הַמַּיִם אוֹ בְּעֹמֶק?", correctAnswer: "קָרוֹב לִפְנֵי הַמַּיִם", distractors: ["עָמֹק לְמַטָּה", "בְּדִיּוּק אוֹתוֹ דָּבָר", "בָּאֶמְצַע"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "⛵\nמַה שָׁט עַל הַמַּיִם?", correctAnswer: "סִירָה", distractors: ["מְכוֹנִית", "אוֹפַנַּיִם", "רַכֶּבֶת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚢\nאֵיךְ קוֹרְאִים לִכְלִי שַׁיִט שֶׁנּוֹסֵעַ מִתַּחַת לַמַּיִם?", correctAnswer: "צוֹלֶלֶת", distractors: ["מָטוֹס", "רַכֶּבֶת", "אוֹטוֹבּוּס"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🤿\nאֵיךְ קוֹרְאִים לְמִי שֶׁצּוֹלֵל מִתַּחַת לַמַּיִם עִם מַסֵּכָה וּמְכַל אֲוִיר?", correctAnswer: "צוֹלְלָן", distractors: ["טַיָּס", "נֶהָג", "שׁוֹעֵר"], tier: .easy, grades: 1...2),

        // ── קַל · חֶשְׁבּוֹן בַּיָּם ──
        BankQuestion(prompt: "🔢\n2 דּוֹלְפִינִים שׂוֹחִים, וְעוֹד 3 מִצְטָרְפִים אֲלֵיהֶם. כַּמָּה דּוֹלְפִינִים יֵשׁ עַכְשָׁו?", correctAnswer: "5", distractors: ["4", "6", "3"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔢\nבַּשּׁוּנִית שׂוֹחִים 4 דָּגִים צְהֻבִּים וְ־3 דָּגִים כְּחֻלִּים. כַּמָּה דָּגִים בְּסַךְ הַכֹּל?", correctAnswer: "7", distractors: ["6", "8", "1"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🔢\nעַל הַחוֹף הָיוּ 6 צְדָפִים, וְאָסַפְתִּי 2. כַּמָּה צְדָפִים נִשְׁאֲרוּ עַל הַחוֹף?", correctAnswer: "4", distractors: ["8", "3", "2"], tier: .easy, grades: 0...2),

        // ── בֵּינוֹנִי · יוֹנְקִים, דָּגִים וְזוֹחֲלִים ──
        BankQuestion(prompt: "🐬\nהַדּוֹלְפִין הוּא…", correctAnswer: "יוֹנֵק", distractors: ["דָּג", "זוֹחֵל", "צִפּוֹר"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐋\nהַלִּוְיָתָן נוֹשֵׁם אֲוִיר, כְּמוֹ בְּנֵי אָדָם. בְּעֶזְרַת מָה?", correctAnswer: "רֵאוֹת", distractors: ["זִימִים", "סְנַפִּירִים", "קַשְׂקַשִּׂים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐬\nאֵיךְ מַגִּיעַ לָעוֹלָם דּוֹלְפִין קָטָן?", correctAnswer: "נוֹלָד מֵאִמּוֹ", distractors: ["בּוֹקֵעַ מִבֵּיצָה", "צוֹמֵחַ מֵאַצָּה", "יוֹצֵא מִצְּדָפָה"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐟\nמָה יֵשׁ לַדָּג וְאֵין לַדּוֹלְפִין?", correctAnswer: "זִימִים", distractors: ["זָנָב", "עֵינַיִם", "סְנַפִּירִים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐢\nצַב הַיָּם הוּא…", correctAnswer: "זוֹחֵל", distractors: ["דָּג", "יוֹנֵק", "חֶרֶק"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐢\nמַה עוֹשִׂים צַבֵּי הַיָּם הַקְּטַנִּים מִיָּד אַחֲרֵי שֶׁהֵם בּוֹקְעִים מֵהַבֵּיצָה?", correctAnswer: "רָצִים אֶל הַיָּם", distractors: ["מְטַפְּסִים עַל עֵץ", "יְשֵׁנִים שָׁנָה שְׁלֵמָה", "עָפִים בָּאֲוִיר"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦈\nמִמָּה עָשׂוּי הַשֶּׁלֶד שֶׁל הַכָּרִישׁ?", correctAnswer: "מִסְּחוּס", distractors: ["מֵעֲצָמוֹת", "מֵעֵץ", "מִמַּתֶּכֶת"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🦈\nמַהוּ הַכָּרִישׁ הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם, שֶׁנִּזּוֹן בְּעִקָּר מִיְצוּרִים זְעִירִים?", correctAnswer: "כָּרִישׁ לִוְיָתָן", distractors: ["כָּרִישׁ לָבָן", "כָּרִישׁ פַּטִּישׁ", "כָּרִישׁ נָמֵר"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐙\nמַה עוֹשֶׂה הַתַּמְנוּן כְּדֵי לְהִסְתַּתֵּר?", correctAnswer: "מְשַׁנֶּה אֶת צִבְעוֹ", distractors: ["עוֹצֵם עֵינַיִם", "קוֹפֵץ מֵהַמַּיִם", "שָׁר בְּקוֹל"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐙\nאֵיזֶה עָנָן מְשַׁחְרֵר הַתַּמְנוּן כְּשֶׁהוּא רוֹצֶה לִבְרֹחַ?", correctAnswer: "עָנָן דְּיוֹ", distractors: ["עָנָן גֶּשֶׁם", "עָנָן אָבָק", "עָנָן עָשָׁן"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🪼\nמָה נָכוֹן לְגַבֵּי הַמֶּדוּזָה?", correctAnswer: "אֵין לָהּ עֲצָמוֹת", distractors: ["יֵשׁ לָהּ שִׁרְיוֹן", "יֵשׁ לָהּ רַגְלַיִם", "יֵשׁ לָהּ נוֹצוֹת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪸\nמַהוּ אַלְמֹג?", correctAnswer: "בַּעַל חַיִּים זָעִיר", distractors: ["צֶמַח", "אֶבֶן צִבְעוֹנִית", "סוּג שֶׁל דָּג"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐠\nאֵיפֹה חַיִּים רֹב הַדָּגִים הַצִּבְעוֹנִיִּים?", correctAnswer: "לְיַד שׁוּנִיּוֹת הָאַלְמֻגִּים", distractors: ["בְּעֹמֶק חָשׁוּךְ", "לְיַד הַקֹּטֶב", "בַּמִּדְבָּר"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔦\nכְּשֶׁיּוֹרְדִים עָמֹק מְאוֹד בַּיָּם, מַה קוֹרֶה לָאוֹר?", correctAnswer: "נַעֲשֶׂה חָשׁוּךְ", distractors: ["נַעֲשֶׂה בָּהִיר יוֹתֵר", "נִשְׁאָר אוֹתוֹ דָּבָר", "נַעֲשֶׂה צָהֹב"], tier: .medium, grades: 2...4),

        // ── בֵּינוֹנִי · יַמִּים, אוֹקְיָנוֹסִים וְגֵאוּת ──
        BankQuestion(prompt: "🪸\nבְּאֵיזֶה יָם נִמְצֵאת שׁוּנִית הָאַלְמֻגִּים שֶׁל אֵילַת?", correctAnswer: "בְּיַם סוּף", distractors: ["בַּיָּם הַתִּיכוֹן", "בְּיַם הַמֶּלַח", "בַּכִּנֶּרֶת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌊\nאֵיזֶה יָם נִמְצָא מִמַּעֲרָב לְיִשְׂרָאֵל, לְיַד תֵּל אָבִיב וְחֵיפָה?", correctAnswer: "הַיָּם הַתִּיכוֹן", distractors: ["יַם סוּף", "יַם הַמֶּלַח", "הָאוֹקְיָנוֹס הַשָּׁקֵט"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🧂\nבְּאֵיזֶה יָם קַל מְאוֹד לָצוּף, כִּי הוּא מָלוּחַ מְאוֹד?", correctAnswer: "יַם הַמֶּלַח", distractors: ["הַיָּם הַתִּיכוֹן", "יַם סוּף", "הַכִּנֶּרֶת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🛟\nלָמָּה צָפִים בְּיַם הַמֶּלַח בְּלִי מַאֲמָץ?", correctAnswer: "כִּי הַמַּיִם מְלוּחִים מְאוֹד", distractors: ["כִּי הַמַּיִם חַמִּים", "כִּי הַמַּיִם רְדוּדִים", "כִּי אֵין בּוֹ גַּלִּים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🗺️\nמַה מְיֻחָד בְּיַם הַמֶּלַח?", correctAnswer: "הוּא הַמָּקוֹם הַיַּבַּשְׁתִּי הַנָּמוּךְ בָּעוֹלָם", distractors: ["הוּא הַיָּם הַגָּדוֹל בָּעוֹלָם", "הוּא הַיָּם הֶעָמֹק בָּעוֹלָם", "הוּא הַיָּם הַקַּר בָּעוֹלָם"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌍\nמַהוּ הָאוֹקְיָנוֹס הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הָאוֹקְיָנוֹס הַשָּׁקֵט", distractors: ["הָאוֹקְיָנוֹס הָאַטְלַנְטִי", "הָאוֹקְיָנוֹס הַהֹדִּי", "הָאוֹקְיָנוֹס הָאַרְקְטִי"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌊\nמַה קוֹרֶה בַּיָּם בִּזְמַן \"גֵּאוּת\"?", correctAnswer: "הַמַּיִם עוֹלִים וּמְכַסִּים יוֹתֵר מֵהַחוֹף", distractors: ["הַמַּיִם נֶעֱלָמִים", "הַמַּיִם קוֹפְאִים", "הַמַּיִם נַעֲשִׂים מְתוּקִים"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌙\nמַה גּוֹרֵם לַגֵּאוּת וְלַשֵּׁפֶל בַּיָּם?", correctAnswer: "בְּעִקָּר כֹּחַ הַמְּשִׁיכָה שֶׁל הַיָּרֵחַ", distractors: ["הָרוּחַ", "הַדָּגִים", "הָעֲנָנִים"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · צוֹלְלָנִים וְצוֹלְלוֹת ──
        BankQuestion(prompt: "🤿\nלָמָּה הַצּוֹלְלָן לוֹקֵחַ אִתּוֹ מְכַל צְלִילָה?", correctAnswer: "כְּדֵי לִנְשֹׁם מִתַּחַת לַמַּיִם", distractors: ["כְּדֵי לָצוּף לְמַעְלָה", "כְּדֵי לִשְׁתּוֹת מַיִם", "כְּדֵי לְהָאִיר בַּחֹשֶׁךְ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🤿\nמַה נוֹעֵל הַצּוֹלְלָן עַל הָרַגְלַיִם כְּדֵי לִשְׂחוֹת מַהֵר יוֹתֵר?", correctAnswer: "סְנַפִּירִים", distractors: ["מַגָּפַיִם", "גַּלְגִּלִּיּוֹת", "סַנְדָּלִים"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚢\nמַה עוֹשָׂה צוֹלֶלֶת כְּשֶׁהִיא רוֹצָה לִשְׁקֹעַ?", correctAnswer: "מְמַלֵּאת מֵיכָלִים בְּמַיִם", distractors: ["מַדְלִיקָה אוֹרוֹת", "פּוֹתַחַת חַלּוֹנוֹת", "מְכַבָּה אֶת הַמָּנוֹעַ"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · חֶשְׁבּוֹן בַּיָּם ──
        BankQuestion(prompt: "🔢\nלְתַמְנוּן 8 זְרוֹעוֹת. כַּמָּה זְרוֹעוֹת יֵשׁ לְ־2 תַּמְנוּנִים?", correctAnswer: "16", distractors: ["10", "12", "18"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔢\nבְּלַהֲקָה שׂוֹחִים 10 דּוֹלְפִינִים. 4 קָפְצוּ מֵהַמַּיִם. כַּמָּה נִשְׁאֲרוּ מִתַּחַת לַמַּיִם?", correctAnswer: "6", distractors: ["14", "5", "4"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔢\nלְכוֹכַב יָם 5 זְרוֹעוֹת. כַּמָּה זְרוֹעוֹת יֵשׁ לְ־3 כּוֹכְבֵי יָם?", correctAnswer: "15", distractors: ["8", "10", "20"], tier: .medium, grades: 2...4),

        // ── קָשֶׁה · מַעֲמַקִּים, אוֹקְיָנוֹסִים וּמֶלַח ──
        BankQuestion(prompt: "🌍\nאֵיזֶה אוֹקְיָנוֹס נִמְצָא בֵּין אֵירוֹפָּה וְאַפְרִיקָה לְבֵין אָמֶרִיקָה?", correctAnswer: "הָאוֹקְיָנוֹס הָאַטְלַנְטִי", distractors: ["הָאוֹקְיָנוֹס הַשָּׁקֵט", "הָאוֹקְיָנוֹס הַהֹדִּי", "הָאוֹקְיָנוֹס הָאַרְקְטִי"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🌊\nמַהוּ הַמָּקוֹם הֶעָמֹק בְּיוֹתֵר בָּאוֹקְיָנוֹסִים?", correctAnswer: "שְׁקַע מָרִיאָנָה", distractors: ["הַיָּם הַתִּיכוֹן", "יַם הַמֶּלַח", "תְּעָלַת סוּאֵץ"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔦\nיֵשׁ דָּגִים בְּמַעֲמַקֵּי הַיָּם שֶׁמְּאִירִים בַּחֹשֶׁךְ. מֵאֵיפֹה מַגִּיעַ הָאוֹר?", correctAnswer: "מֵהַגּוּף שֶׁלָּהֶם", distractors: ["מֵהַשֶּׁמֶשׁ", "מִפָּנָס שֶׁל צוֹלְלָן", "מֵהַיָּרֵחַ"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐬\nבְּעֶזְרַת מָה הַדּוֹלְפִין \"רוֹאֶה\" בַּחֹשֶׁךְ וּמוֹצֵא דָּגִים?", correctAnswer: "הֵד שֶׁל צְלִילִים", distractors: ["פָּנָס", "חוּשׁ הָרֵיחַ", "שְׂפָמוֹת"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦈\nמַה קוֹרֶה כְּשֶׁשֵּׁן שֶׁל כָּרִישׁ נוֹפֶלֶת?", correctAnswer: "שֵׁן חֲדָשָׁה מַחְלִיפָה אוֹתָהּ", distractors: ["נִשְׁאָר חוֹר לְתָמִיד", "הוּא מַפְסִיק לֶאֱכֹל", "הוּא הוֹלֵךְ לְרוֹפֵא שִׁנַּיִם"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐋\nמַה אוֹכֵל הַלִּוְיָתָן הַכָּחֹל, הַחַיָּה הַגְּדוֹלָה בָּעוֹלָם?", correctAnswer: "קְרִיל — סַרְטָנִים זְעִירִים", distractors: ["כְּרִישִׁים", "דּוֹלְפִינִים", "אַצּוֹת"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🧂\nמַדּוּעַ יַם הַמֶּלַח מָלוּחַ כָּל כָּךְ?", correctAnswer: "הַמַּיִם מִתְאַדִּים, הַמֶּלַח נִשְׁאָר", distractors: ["שׁוֹפְכִים לְתוֹכוֹ מֶלַח", "הוּא מְחֻבָּר לָאוֹקְיָנוֹס", "יֵשׁ בּוֹ הַרְבֵּה דָּגִים"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🌙\nכַּמָּה פְּעָמִים בְּיוֹם יֵשׁ בְּדֶרֶךְ כְּלָל גֵּאוּת בַּיָּם?", correctAnswer: "2", distractors: ["1", "5", "10"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🚢\nמַהוּ \"פֶּרִיסְקוֹפּ\" בְּצוֹלֶלֶת?", correctAnswer: "צִנּוֹר לְהַצָּצָה מֵעַל הַמַּיִם", distractors: ["הַמָּנוֹעַ שֶׁל הַצּוֹלֶלֶת", "סוּג שֶׁל דָּג", "מַכְשִׁיר לְבִשּׁוּל"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🔢\nצוֹלֶלֶת יָרְדָה לְעֹמֶק 300 מֶטֶר, וְאַחַר כָּךְ עָלְתָה 120 מֶטֶר. בְּאֵיזֶה עֹמֶק הִיא עַכְשָׁו?", correctAnswer: "180 מֶטֶר", distractors: ["420 מֶטֶר", "200 מֶטֶר", "150 מֶטֶר"], tier: .hard, grades: 3...5),
    ]
}
