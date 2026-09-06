import Foundation

/// 🚗 כְּלֵי רֶכֶב וְתַחְבּוּרָה — a young-kids pack (גן–ג׳): what has how many
/// wheels, what moves on rails / water / air, who drives what, traffic lights
/// and gentle road safety, the Israeli train and light rail, electric cars.
/// Facts are timeless; nothing here goes stale. Grade-tagged like every bank.
enum QuestionBanksVehicles {
    static let vehicles: [BankQuestion] = [
        // ── קַל · גַּלְגַּלִּים וּמִי נוֹסֵעַ אֵיפֹה ──
        BankQuestion(prompt: "🚗\nכַּמָּה גַּלְגַּלִּים יֵשׁ לִמְכוֹנִית?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚲\nכַּמָּה גַּלְגַּלִּים יֵשׁ לְאוֹפַנַּיִם?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛺\nכַּמָּה גַּלְגַּלִּים יֵשׁ לִתְלַת־אוֹפַן?", correctAnswer: "3", distractors: ["2", "4", "5"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚂\nעַל מַה נוֹסַעַת הָרַכֶּבֶת?", correctAnswer: "עַל פַּסִּים", distractors: ["עַל הַמַּיִם", "בָּאֲוִיר", "עַל הַחוֹל"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚢\nאֵיפֹה שָׁטָה הָאֳנִיָּה?", correctAnswer: "בַּיָּם", distractors: ["בַּשָּׁמַיִם", "עַל הַכְּבִישׁ", "עַל פַּסִּים"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "✈️\nאֵיפֹה טָס הַמָּטוֹס?", correctAnswer: "בַּשָּׁמַיִם", distractors: ["בַּיָּם", "עַל הַכְּבִישׁ", "מִתַּחַת לָאֲדָמָה"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚗\nאֵיפֹה נוֹסְעוֹת הַמְּכוֹנִיּוֹת?", correctAnswer: "עַל הַכְּבִישׁ", distractors: ["עַל הַמִּדְרָכָה", "בַּיָּם", "בַּשָּׁמַיִם"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚶\nאֵיפֹה הוֹלְכִים הוֹלְכֵי הָרֶגֶל?", correctAnswer: "עַל הַמִּדְרָכָה", distractors: ["בְּאֶמְצַע הַכְּבִישׁ", "עַל הַפַּסִּים", "בַּיָּם"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚤\nאֵיזֶה כְּלִי קָטָן שָׁט עַל הַמַּיִם?", correctAnswer: "סִירָה", distractors: ["מְכוֹנִית", "מָטוֹס", "אוֹפַנַּיִם"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚁\nאֵיזֶה כְּלִי טַיִס מַמְרִיא יָשָׁר לְמַעְלָה, בְּעֶזְרַת מַדְחֵף גָּדוֹל?", correctAnswer: "מַסּוֹק", distractors: ["מָטוֹס", "רַכֶּבֶת", "אוֹטוֹבּוּס"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚀\nמַה טָס עַד לֶחָלָל?", correctAnswer: "חֲלָלִית", distractors: ["מָטוֹס", "מַסּוֹק", "עֲפִיפוֹן"], tier: .easy, grades: 0...1),

        // ── קַל · מִי נוֹהֵג וְאֵיזֶה רֶכֶב ──
        BankQuestion(prompt: "🧑‍✈️\nמִי מַטִּיס אֶת הַמָּטוֹס?", correctAnswer: "טַיָּס", distractors: ["נַהָג", "רַב־חוֹבֵל", "שׁוֹטֵר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚌\nמִי נוֹהֵג בָּאוֹטוֹבּוּס?", correctAnswer: "נַהָג", distractors: ["טַיָּס", "רַב־חוֹבֵל", "רוֹפֵא"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚑\nאֵיזֶה רֶכֶב מֵבִיא אֲנָשִׁים לְבֵית הַחוֹלִים?", correctAnswer: "אַמְבּוּלַנְס", distractors: ["מַשָּׂאִית", "מוֹנִית", "טְרַקְטוֹר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚒\nאֵיזֶה רֶכֶב אָדֹם נוֹסֵעַ עִם סֻלָּם אָרֹךְ וְצִנּוֹרוֹת מַיִם?", correctAnswer: "כַּבָּאִית", distractors: ["אַמְבּוּלַנְס", "אוֹטוֹבּוּס", "מוֹנִית"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚜\nאֵיזֶה רֶכֶב עוֹזֵר לַחַקְלַאי בַּשָּׂדֶה?", correctAnswer: "טְרַקְטוֹר", distractors: ["מוֹנִית", "אוֹפַנַּיִם", "רַכֶּבֶת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚕\nאֵיזֶה רֶכֶב מַסִּיעַ נוֹסְעִים תְּמוּרַת תַּשְׁלוּם, וְאֶפְשָׁר לַעֲצֹר אוֹתוֹ בָּרְחוֹב?", correctAnswer: "מוֹנִית", distractors: ["טְרַקְטוֹר", "אוֹפַנַּיִם", "מַסּוֹק"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚌\nאֵיזֶה רֶכֶב גָּדוֹל מַסִּיעַ הַרְבֵּה נוֹסְעִים בָּעִיר?", correctAnswer: "אוֹטוֹבּוּס", distractors: ["אוֹפַנַּיִם", "קוֹרְקִינֶט", "מוֹנִית"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚚\nאֵיזֶה רֶכֶב גָּדוֹל מוֹבִיל סְחוֹרוֹת וּמִטְעָנִים?", correctAnswer: "מַשָּׂאִית", distractors: ["אוֹפַנַּיִם", "מוֹנִית", "קוֹרְקִינֶט"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛴\nעַל מַה עוֹמְדִים בְּרֶגֶל אַחַת וְדוֹחֲפִים בָּרֶגֶל הַשְּׁנִיָּה?", correctAnswer: "קוֹרְקִינֶט", distractors: ["אוֹפַנַּיִם", "מְכוֹנִית", "סִירָה"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚲\nאֵיךְ מְנִיעִים אוֹפַנַּיִם?", correctAnswer: "דּוֹוְשִׁים בָּרַגְלַיִם", distractors: ["מוֹשְׁכִים בְּחֶבֶל", "מְנַפְנְפִים בַּיָּדַיִם", "מַדְלִיקִים מָנוֹעַ"], tier: .easy, grades: 0...1),

        // ── קַל · רַמְזוֹר וּבְטִיחוּת ──
        BankQuestion(prompt: "🚦\nבְּאֵיזֶה צֶבַע שֶׁל הָרַמְזוֹר מֻתָּר לִנְסֹעַ?", correctAnswer: "יָרֹק", distractors: ["אָדֹם", "צָהֹב", "כָּחֹל"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛑\nבְּאֵיזֶה צֶבַע שֶׁל הָרַמְזוֹר עוֹצְרִים?", correctAnswer: "אָדֹם", distractors: ["יָרֹק", "כָּחֹל", "לָבָן"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚦\nכַּמָּה צְבָעִים יֵשׁ בְּרַמְזוֹר לִמְכוֹנִיּוֹת?", correctAnswer: "3", distractors: ["1", "2", "5"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦓\nאֵיפֹה חוֹצִים אֶת הַכְּבִישׁ?", correctAnswer: "בְּמַעֲבַר חֲצִיָּה", distractors: ["בְּאֶמְצַע הַכְּבִישׁ", "לְיַד הַפַּסִּים", "בֵּין הַמְּכוֹנִיּוֹת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⛑️\nמַה חוֹבְשִׁים עַל הָרֹאשׁ כְּשֶׁרוֹכְבִים עַל אוֹפַנַּיִם?", correctAnswer: "קַסְדָּה", distractors: ["כּוֹבַע צֶמֶר", "מִשְׁקָפַיִם", "כֶּתֶר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚗\nמַה חוֹגְרִים בַּמְּכוֹנִית לִפְנֵי הַנְּסִיעָה?", correctAnswer: "חֲגוֹרַת בְּטִיחוּת", distractors: ["צָעִיף", "מְעִיל", "כּוֹבַע"], tier: .easy, grades: 0...1),

        // ── קַל · חֲלָקִים וּמְקוֹמוֹת ──
        BankQuestion(prompt: "🚗\nמַה מְסוֹבֵב הַנַּהָג כְּדֵי לִפְנוֹת יָמִינָה אוֹ שְׂמֹאלָה?", correctAnswer: "הֶגֶה", distractors: ["חַלּוֹן", "מַרְאָה", "דֶּלֶת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⛽\nאֵיךְ קוֹרְאִים לַמָּקוֹם שֶׁבּוֹ מְמַלְּאִים דֶּלֶק לַמְּכוֹנִית?", correctAnswer: "תַּחֲנַת דֶּלֶק", distractors: ["תַּחֲנַת רַכֶּבֶת", "חֲנוּת", "גַּן חַיּוֹת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚉\nאֵיפֹה עוֹלִים עַל הָרַכֶּבֶת?", correctAnswer: "בְּתַחֲנַת הָרַכֶּבֶת", distractors: ["בַּנָּמֵל", "בִּשְׂדֵה הַתְּעוּפָה", "בַּחֲנוּת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛫\nאֵיפֹה מַמְרִיאִים וְנוֹחֲתִים הַמְּטוֹסִים?", correctAnswer: "בִּשְׂדֵה הַתְּעוּפָה", distractors: ["בְּתַחֲנַת הָרַכֶּבֶת", "בַּנָּמֵל", "בַּגַּן"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⚓\nאֵיפֹה עוֹגְנוֹת הָאֳנִיּוֹת?", correctAnswer: "בַּנָּמֵל", distractors: ["בִּשְׂדֵה הַתְּעוּפָה", "בַּחֲנָיָה", "בְּתַחֲנַת הָרַכֶּבֶת"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "📢\nמַה יֵשׁ לִמְכוֹנִית שֶׁמַּשְׁמִיעַ צְלִיל חָזָק?", correctAnswer: "צוֹפָר", distractors: ["פַּעֲמוֹן", "חָלִיל", "תֹּף"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔔\nמַה מְצַלְצְלִים עַל אוֹפַנַּיִם כְּדֵי שֶׁיִּשְׁמְעוּ שֶׁאֲנַחְנוּ מַגִּיעִים?", correctAnswer: "פַּעֲמוֹן", distractors: ["צוֹפָר", "שׁוֹפָר", "שָׁעוֹן"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌙\nמַה מַדְלִיקִים בַּמְּכוֹנִית כְּשֶׁחָשׁוּךְ בַּחוּץ?", correctAnswer: "פָּנָסִים", distractors: ["רַדְיוֹ", "מַזְגָן", "מַגָּבִים"], tier: .easy, grades: 0...1),

        // ── בֵּינוֹנִי · חֶשְׁבּוֹן גַּלְגַּלִּים ──
        BankQuestion(prompt: "🚲🚲\nכַּמָּה גַּלְגַּלִּים יֵשׁ בְּיַחַד לְ־2 אוֹפַנַּיִם?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗🚗\nכַּמָּה גַּלְגַּלִּים יֵשׁ בְּיַחַד לְ־2 מְכוֹנִיּוֹת?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗🚲\nכַּמָּה גַּלְגַּלִּים יֵשׁ בְּיַחַד לִמְכוֹנִית אַחַת וּלְאוֹפַנַּיִם?", correctAnswer: "6", distractors: ["4", "5", "8"], tier: .medium, grades: 1...3),

        // ── בֵּינוֹנִי · רַכָּבוֹת, אֳנִיּוֹת וּמְטוֹסִים ──
        BankQuestion(prompt: "🚂\nאֵיךְ קוֹרְאִים לַקָּרוֹן הָרִאשׁוֹן שֶׁמּוֹשֵׁךְ אֶת כָּל הָרַכֶּבֶת?", correctAnswer: "קַטָּר", distractors: ["קָרוֹן", "סִירָה", "מַשָּׂאִית"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🧑‍✈️\nמִי מְפַקֵּד עַל הָאֳנִיָּה?", correctAnswer: "רַב־חוֹבֵל", distractors: ["טַיָּס", "נַהָג", "מְכוֹנַאי"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚋\nאֵיךְ קוֹרְאִים לָרַכֶּבֶת שֶׁנּוֹסַעַת עַל פַּסִּים בְּתוֹךְ הָרְחוֹבוֹת שֶׁל הָעִיר?", correctAnswer: "רַכֶּבֶת קַלָּה", distractors: ["רַכֶּבֶת מַשָּׂא", "מוֹנִית", "סִירָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🇮🇱\nבְּאֵיזוֹ עִיר בְּיִשְׂרָאֵל נוֹסַעַת רַכֶּבֶת קַלָּה?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["אֵילַת", "טְבֶרְיָה", "צְפַת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚆\nאֵיךְ קוֹרְאִים לַחֶבְרָה שֶׁמַּפְעִילָה אֶת הָרַכָּבוֹת בְּיִשְׂרָאֵל?", correctAnswer: "רַכֶּבֶת יִשְׂרָאֵל", distractors: ["אֶגֶד", "אֶל עַל", "דָּן"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🛫\nאֵיךְ קוֹרְאִים לִשְׂדֵה הַתְּעוּפָה הַגָּדוֹל שֶׁל יִשְׂרָאֵל?", correctAnswer: "נְמַל הַתְּעוּפָה בֶּן־גּוּרְיוֹן", distractors: ["נְמַל חֵיפָה", "תַּחֲנַת הַשָּׁלוֹם", "נְמַל אַשְׁדּוֹד"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "⛴️\nאֵיךְ קוֹרְאִים לָאֳנִיָּה שֶׁמַּסִּיעָה מְכוֹנִיּוֹת וַאֲנָשִׁים מֵעֵבֶר לַיָּם?", correctAnswer: "מַעְבֹּרֶת", distractors: ["סִירַת מִשּׁוֹטִים", "צוֹלֶלֶת", "מִפְרָשִׂית"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "⛵\nמַה מֵנִיעַ סִירַת מִפְרָשׂ?", correctAnswer: "הָרוּחַ", distractors: ["הַשֶּׁמֶשׁ", "הַגֶּשֶׁם", "הַחוֹל"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚁\nמַה מַסּוֹק יוֹדֵעַ לַעֲשׂוֹת, וּמָטוֹס רָגִיל לֹא?", correctAnswer: "לְרַחֵף בַּמָּקוֹם בָּאֲוִיר", distractors: ["לָטוּס לַיָּרֵחַ", "לִנְסֹעַ עַל פַּסִּים", "לָשׁוּט בַּיָּם"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎈\nמַה מַעֲלֶה כַּדּוּר פּוֹרֵחַ לַשָּׁמַיִם?", correctAnswer: "אֲוִיר חַם", distractors: ["מְנוֹעַ סִילוֹן", "גַּלְגַּלִּים", "מִפְרָשׂ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚀\nמִי טָס יוֹתֵר גָּבוֹהַּ מִכֻּלָּם?", correctAnswer: "חֲלָלִית", distractors: ["מָטוֹס", "מַסּוֹק", "כַּדּוּר פּוֹרֵחַ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌕\nלְאָן יְכוֹלָה חֲלָלִית לְהַגִּיעַ, וּמָטוֹס לֹא?", correctAnswer: "לַיָּרֵחַ", distractors: ["לְאֵילַת", "לְאֵירוֹפָּה", "לַיָּם"], tier: .medium, grades: 1...3),

        // ── בֵּינוֹנִי · דֶּלֶק וְחַשְׁמַל ──
        BankQuestion(prompt: "⛽\nמַה מְמַלְּאִים בִּמְכוֹנִית רְגִילָה כְּדֵי שֶׁהַמָּנוֹעַ יַעֲבֹד?", correctAnswer: "דֶּלֶק", distractors: ["מַיִם", "חָלָב", "חוֹל"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔌\nמַה צָרִיךְ לַעֲשׂוֹת כְּדֵי שֶׁמְּכוֹנִית חַשְׁמַלִּית תּוּכַל לִנְסֹעַ?", correctAnswer: "לְהַטְעִין אוֹתָהּ בְּחַשְׁמַל", distractors: ["לְמַלֵּא בֶּנְזִין", "לְמַלֵּא מַיִם", "לִדְוֹשׁ בָּרַגְלַיִם"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔋\nמַה יֵשׁ לִמְכוֹנִית חַשְׁמַלִּית בִּמְקוֹם מֵיכַל דֶּלֶק?", correctAnswer: "סוֹלְלָה גְּדוֹלָה", distractors: ["מֵיכַל מַיִם", "מִפְרָשׂ", "אֲרֻבָּה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌿\nלָמָּה מְכוֹנִית חַשְׁמַלִּית טוֹבָה לָאֲוִיר שֶׁאֲנַחְנוּ נוֹשְׁמִים?", correctAnswer: "הִיא לֹא פּוֹלֶטֶת עָשָׁן", distractors: ["הִיא יוֹתֵר גְּדוֹלָה", "יֵשׁ לָהּ יוֹתֵר גַּלְגַּלִּים", "הִיא צוֹפֶרֶת יוֹתֵר"], tier: .medium, grades: 1...3),

        // ── בֵּינוֹנִי · מָהִיר וְאִטִּי ──
        BankQuestion(prompt: "🏎️\nמִי הֲכִי מָהִיר: מְכוֹנִית מֵרוֹץ, אוֹפַנַּיִם אוֹ קוֹרְקִינֶט?", correctAnswer: "מְכוֹנִית מֵרוֹץ", distractors: ["אוֹפַנַּיִם", "קוֹרְקִינֶט", "תְּלַת־אוֹפַן"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nמִי הֲכִי אִטִּי: מָטוֹס, רַכֶּבֶת אוֹ אוֹפַנַּיִם?", correctAnswer: "אוֹפַנַּיִם", distractors: ["מָטוֹס", "רַכֶּבֶת", "מְכוֹנִית מֵרוֹץ"], tier: .medium, grades: 1...3),

        // ── בֵּינוֹנִי · רַמְזוֹר וּבְטִיחוּת ──
        BankQuestion(prompt: "🚦\nמַה אוֹמֵר הָאוֹר הַצָּהֹב שֶׁנִּדְלָק אַחֲרֵי הַיָּרֹק?", correctAnswer: "לְהִתְכּוֹנֵן לַעֲצֹר", distractors: ["לִנְסֹעַ מַהֵר", "לְצַפְצֵף", "לַחֲנוֹת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚶\nבְּרַמְזוֹר לְהוֹלְכֵי רֶגֶל, מַה מַרְאֶה הָאִישׁ הַיָּרֹק?", correctAnswer: "שֶׁמֻּתָּר לַחֲצוֹת", distractors: ["שֶׁצָּרִיךְ לָרוּץ", "שֶׁאָסוּר לַחֲצוֹת", "שֶׁהַכְּבִישׁ סָגוּר"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "👀\nמַה עוֹשִׂים לִפְנֵי שֶׁחוֹצִים אֶת הַכְּבִישׁ?", correctAnswer: "עוֹצְרִים וּמִסְתַּכְּלִים לִשְׁנֵי הַצְּדָדִים", distractors: ["רָצִים מַהֵר", "סוֹגְרִים עֵינַיִם", "שָׁרִים שִׁיר"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗\nמַדּוּעַ חוֹגְרִים חֲגוֹרַת בְּטִיחוּת?", correctAnswer: "כְּדֵי שֶׁנִּהְיֶה בְּטוּחִים בַּנְּסִיעָה", distractors: ["כְּדֵי שֶׁיִּהְיֶה חַם", "כְּדֵי שֶׁהַמְּכוֹנִית תִּסַּע מַהֵר", "כְּדֵי לִשְׁמֹעַ רַדְיוֹ"], tier: .medium, grades: 1...3),

        // ── קָשֶׁה ──
        BankQuestion(prompt: "🚲🚲🚲\nכַּמָּה גַּלְגַּלִּים יֵשׁ בְּיַחַד לְ־3 אוֹפַנַּיִם וּתְלַת־אוֹפַן אֶחָד?", correctAnswer: "9", distractors: ["7", "8", "10"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚗🚗🚲\nכַּמָּה גַּלְגַּלִּים יֵשׁ בְּיַחַד לְ־2 מְכוֹנִיּוֹת וּלְאוֹפַנַּיִם?", correctAnswer: "10", distractors: ["8", "9", "12"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚄\nבֵּין אֵילוּ עָרִים נוֹסַעַת הָרַכֶּבֶת הַמְּהִירָה שֶׁל רַכֶּבֶת יִשְׂרָאֵל?", correctAnswer: "תֵּל אָבִיב וִירוּשָׁלַיִם", distractors: ["אֵילַת וְחֵיפָה", "צְפַת וּטְבֶרְיָה", "אַשְׁדּוֹד וְאַשְׁקְלוֹן"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚋\nמֵאֵיפֹה מְקַבֶּלֶת הָרַכֶּבֶת הַקַּלָּה אֶת הָאֵנֶרְגְּיָה שֶׁלָּהּ?", correctAnswer: "מֵחַשְׁמַל", distractors: ["מִבֶּנְזִין", "מִפֶּחָם", "מֵרוּחַ"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "⚓\nבְּאֵיזוֹ עִיר בְּיִשְׂרָאֵל יֵשׁ נָמֵל גָּדוֹל לָאֳנִיּוֹת?", correctAnswer: "חֵיפָה", distractors: ["יְרוּשָׁלַיִם", "בְּאֵר שֶׁבַע", "צְפַת"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🛞\nלָמָּה יֵשׁ לַצְּמִיגִים חֲרִיצִים?", correctAnswer: "כְּדֵי לֶאֱחֹז טוֹב בַּכְּבִישׁ", distractors: ["כְּדֵי שֶׁיִּהְיוּ יָפִים", "כְּדֵי לְהַשְׁמִיעַ רַעַשׁ", "כְּדֵי לִשְׁקֹל פָּחוֹת"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "✈️\nמַה מַחֲזִיק אֶת הַמָּטוֹס בָּאֲוִיר בִּזְמַן הַטִּיסָה?", correctAnswer: "הַכְּנָפַיִם", distractors: ["הַגַּלְגַּלִּים", "הַחַלּוֹנוֹת", "הַכִּסְּאוֹת"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚀\nמַה דּוֹחֵף אֶת הַטִּיל לְמַעְלָה בַּהַמְרָאָה?", correctAnswer: "גַּז חַם שֶׁיּוֹצֵא מִלְּמַטָּה", distractors: ["רוּחַ חֲזָקָה", "הַגַּלְגַּלִּים", "מִפְרָשׂ"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚂\nמַה הֵנִיעַ אֶת הַקַּטָּרִים הָרִאשׁוֹנִים, לִפְנֵי הַחַשְׁמַל וְהַדִּיזֶל?", correctAnswer: "קִיטוֹר", distractors: ["סוֹלְלָה", "רוּחַ", "שֶׁמֶשׁ"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚦\nמַה אוֹמֵר הָרַמְזוֹר כְּשֶׁאָדֹם וְצָהֹב דּוֹלְקִים בְּיַחַד?", correctAnswer: "הָאוֹר הַיָּרֹק עוֹמֵד לְהִדָּלֵק", distractors: ["צָרִיךְ לַחֲנוֹת", "הָרַמְזוֹר מְקֻלְקָל", "אָסוּר לִנְסֹעַ בַּלַּיְלָה"], tier: .hard, grades: 2...3),
    ]
}
