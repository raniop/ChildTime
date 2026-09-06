import Foundation

/// 🏛️ יִשְׂרָאֵל שֶׁלִּי — a homeland question pack for ב׳–ו׳: cities and what they
/// are known for, the flag / emblem / anthem, holidays and their foods, seas and
/// mountains, national symbols (דוכיפת, כלנית), landmarks, Independence Day
/// (1948), Israeli inventions and a few founding figures — all timeless facts,
/// deliberately free of politics and conflict. Grade-tagged like every bank.
enum QuestionBanksIsrael {
    static let israel: [BankQuestion] = [
        // ── קַל · סְמָלִים וְעִיר הַבִּירָה ──
        BankQuestion(prompt: "🏛️\nמַהִי עִיר הַבִּירָה שֶׁל יִשְׂרָאֵל?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🇮🇱\nאֵילוּ צְבָעִים יֵשׁ בְּדֶגֶל יִשְׂרָאֵל?", correctAnswer: "כָּחֹל וְלָבָן", distractors: ["אָדֹם וְלָבָן", "יָרֹק וְלָבָן", "כָּחֹל וְאָדֹם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✡️\nאֵיזֶה סֵמֶל מְצֻיָּר בְּאֶמְצַע דֶּגֶל יִשְׂרָאֵל?", correctAnswer: "מָגֵן דָּוִד", distractors: ["לֵב", "שֶׁמֶשׁ", "מְנוֹרָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "📏\nכַּמָּה פַּסִּים כְּחֻלִּים יֵשׁ בְּדֶגֶל יִשְׂרָאֵל?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🕎\nמָה מְצֻיָּר בְּאֶמְצַע סֵמֶל מְדִינַת יִשְׂרָאֵל?", correctAnswer: "מְנוֹרָה", distractors: ["דֶּגֶל", "אַרְיֵה", "מָגֵן דָּוִד"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫒\nעַנְפֵי אֵיזֶה עֵץ נִמְצָאִים מִשְּׁנֵי צִדֵּי הַמְּנוֹרָה בְּסֵמֶל הַמְּדִינָה?", correctAnswer: "זַיִת", distractors: ["דֶּקֶל", "תְּאֵנָה", "אֹרֶן"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎵\nאֵיךְ קוֹרְאִים לַהִמְנוֹן שֶׁל מְדִינַת יִשְׂרָאֵל?", correctAnswer: "הַתִּקְוָה", distractors: ["יְרוּשָׁלַיִם שֶׁל זָהָב", "שִׁיר הַשָּׁלוֹם", "שִׁיר הָעֶמֶק"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐦\nמַהִי הַצִּפּוֹר הַלְּאֻמִּית שֶׁל יִשְׂרָאֵל?", correctAnswer: "דּוּכִיפַת", distractors: ["יוֹנָה", "נֶשֶׁר", "תֻּכִּי"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🌸\nמַהוּ הַפֶּרַח הַלְּאֻמִּי שֶׁל יִשְׂרָאֵל?", correctAnswer: "כַּלָּנִית", distractors: ["וֶרֶד", "חַמָּנִיָּה", "נַרְקִיס"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🪙\nאֵיךְ קוֹרְאִים לַמַּטְבֵּעַ שֶׁמְּשַׁלְּמִים בּוֹ בְּיִשְׂרָאֵל?", correctAnswer: "שֶׁקֶל", distractors: ["דּוֹלָר", "אֵירוֹ", "לִירָה"], tier: .easy, grades: 2...3),

        // ── קַל · חַגִּים ──
        BankQuestion(prompt: "🕎\nבְּאֵיזֶה חַג מַדְלִיקִים חֲנֻכִּיָּה וּמְשַׂחֲקִים בִּסְבִיבוֹן?", correctAnswer: "חֲנֻכָּה", distractors: ["פּוּרִים", "פֶּסַח", "סֻכּוֹת"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍩\nאֵיזֶה מַאֲכָל מָתוֹק אוֹכְלִים בַּחֲנֻכָּה?", correctAnswer: "סֻפְגָּנִיּוֹת", distractors: ["אָזְנֵי הָמָן", "מַצּוֹת", "תַּפּוּחַ בִּדְבַשׁ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎭\nבְּאֵיזֶה חַג מִתְחַפְּשִׂים?", correctAnswer: "פּוּרִים", distractors: ["חֲנֻכָּה", "שָׁבוּעוֹת", "פֶּסַח"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍪\nאֵיזוֹ עוּגִיָּה מְשֻׁלֶּשֶׁת אוֹכְלִים בְּפוּרִים?", correctAnswer: "אָזְנֵי הָמָן", distractors: ["סֻפְגָּנִיּוֹת", "לְבִיבוֹת", "מַצּוֹת"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫓\nבְּאֵיזֶה חַג אוֹכְלִים מַצּוֹת בִּמְקוֹם לֶחֶם?", correctAnswer: "פֶּסַח", distractors: ["סֻכּוֹת", "חֲנֻכָּה", "פּוּרִים"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍎\nבְּאֵיזֶה חַג טוֹבְלִים תַּפּוּחַ בִּדְבַשׁ?", correctAnswer: "רֹאשׁ הַשָּׁנָה", distractors: ["פּוּרִים", "פֶּסַח", "ט״וּ בִּשְׁבָט"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🛖\nבְּאֵיזֶה חַג בּוֹנִים סֻכָּה וְיוֹשְׁבִים בָּהּ?", correctAnswer: "סֻכּוֹת", distractors: ["פֶּסַח", "חֲנֻכָּה", "שָׁבוּעוֹת"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🌳\nבְּאֵיזֶה חַג נוֹטְעִים עֵצִים?", correctAnswer: "ט״וּ בִּשְׁבָט", distractors: ["פּוּרִים", "סֻכּוֹת", "חֲנֻכָּה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎆\nמָה נָהוּג לַעֲשׂוֹת בְּיוֹם הָעַצְמָאוּת?", correctAnswer: "עוֹשִׂים מַנְגָּל וְרוֹאִים זִקּוּקִים", distractors: ["בּוֹנִים סֻכָּה", "מִתְחַפְּשִׂים", "אוֹכְלִים מַצּוֹת"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎂\nאֵיזֶה חַג הוּא \"יוֹם הַהֻלֶּדֶת\" שֶׁל מְדִינַת יִשְׂרָאֵל?", correctAnswer: "יוֹם הָעַצְמָאוּת", distractors: ["רֹאשׁ הַשָּׁנָה", "פּוּרִים", "ט״וּ בִּשְׁבָט"], tier: .easy, grades: 2...3),

        // ── קַל · יַמִּים, הָרִים וְעָרִים ──
        BankQuestion(prompt: "🌊\nאֵיזֶה יָם נִמְצָא לְיַד תֵּל אָבִיב וְחֵיפָה?", correctAnswer: "הַיָּם הַתִּיכוֹן", distractors: ["יַם הַמֶּלַח", "יַם סוּף", "הַכִּנֶּרֶת"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏖️\nאֵיזוֹ עִיר נִמְצֵאת בַּקָּצֶה הַדְּרוֹמִי שֶׁל יִשְׂרָאֵל, עַל חוֹף יַם סוּף?", correctAnswer: "אֵילַת", distractors: ["חֵיפָה", "נַהֲרִיָּה", "טְבֶרְיָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧂\nבְּאֵיזֶה יָם הַמַּיִם כָּל כָּךְ מְלוּחִים, שֶׁצָּפִים בָּהֶם בְּלִי מַאֲמָץ?", correctAnswer: "יַם הַמֶּלַח", distractors: ["הַיָּם הַתִּיכוֹן", "הַכִּנֶּרֶת", "יַם סוּף"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏜️\nאֵיךְ קוֹרְאִים לַמִּדְבָּר הַגָּדוֹל בִּדְרוֹם יִשְׂרָאֵל?", correctAnswer: "הַנֶּגֶב", distractors: ["הַכַּרְמֶל", "הַגָּלִיל", "הַשָּׁרוֹן"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "⛷️\nעַל אֵיזֶה הַר נִמְצָא אֲתַר הַסְּקִי הַיָּחִיד בְּיִשְׂרָאֵל?", correctAnswer: "הַחֶרְמוֹן", distractors: ["הַכַּרְמֶל", "הַר תָּבוֹר", "הַר הַזֵּיתִים"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "⛰️\nאֵיזוֹ עִיר בְּנוּיָה עַל הַר הַכַּרְמֶל?", correctAnswer: "חֵיפָה", distractors: ["תֵּל אָבִיב", "אֵילַת", "בְּאֵר שֶׁבַע"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏙️\nמַהִי הָעִיר הַגְּדוֹלָה שֶׁל הַנֶּגֶב?", correctAnswer: "בְּאֵר שֶׁבַע", distractors: ["אֵילַת", "חֵיפָה", "נְתַנְיָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧱\nאֵיךְ קוֹרְאִים לַכֹּתֶל הָעַתִּיק בִּירוּשָׁלַיִם, שֶׁאֲנָשִׁים מַכְנִיסִים בֵּין אֲבָנָיו פְּתָקִים?", correctAnswer: "הַכֹּתֶל הַמַּעֲרָבִי", distractors: ["הַחוֹמָה הַסִּינִית", "מְצָדָה", "מִגְדַּל דָּוִד"], tier: .easy, grades: 2...3),

        // ── בֵּינוֹנִי · עָרִים וּמְקוֹמוֹת ──
        BankQuestion(prompt: "🏙️\nאֵיזוֹ עִיר נִקְרֵאת \"הָעִיר הַלְּבָנָה\" בִּזְכוּת הַבִּנְיָנִים הַלְּבָנִים שֶׁלָּהּ?", correctAnswer: "תֵּל אָבִיב", distractors: ["חֵיפָה", "יְרוּשָׁלַיִם", "אֵילַת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🐠\nאֵיזוֹ עִיר מְפֻרְסֶמֶת בְּשׁוּנִית הָאַלְמֻגִּים וּבַדָּגִים הַצִּבְעוֹנִיִּים שֶׁלָּהּ?", correctAnswer: "אֵילַת", distractors: ["חֵיפָה", "טְבֶרְיָה", "אַשְׁדּוֹד"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍊\nאֵיזֶה פְּרִי מְפֻרְסָם בָּעוֹלָם נִקְרָא עַל שֵׁם הָעִיר יָפוֹ?", correctAnswer: "תַּפּוּז", distractors: ["בָּנָנָה", "תַּפּוּחַ", "אֲבַטִּיחַ"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🛥️\nאֵיזוֹ עִיר יוֹשֶׁבֶת עַל חוֹף הַכִּנֶּרֶת?", correctAnswer: "טְבֶרְיָה", distractors: ["צְפַת", "נַהֲרִיָּה", "עַכּוֹ"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🎨\nאֵיזוֹ עִיר בַּגָּלִיל מְפֻרְסֶמֶת בַּסִּמְטָאוֹת הָעַתִּיקוֹת וּבַגָּלֶרְיוֹת שֶׁל הָאָמָּנִים?", correctAnswer: "צְפַת", distractors: ["בְּאֵר שֶׁבַע", "אֵילַת", "חוֹלוֹן"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🏛️\nבְּאֵיזוֹ עִיר נִמְצָא בִּנְיַן הַכְּנֶסֶת?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🏰\nאֵיךְ קוֹרְאִים לַמִּבְצָר הָעַתִּיק שֶׁעַל רֹאשׁ הַר לְיַד יַם הַמֶּלַח, שֶׁעוֹלִים אֵלָיו בְּרַכֶּבֶל אוֹ בָּרֶגֶל בִּשְׁבִיל הַנָּחָשׁ?", correctAnswer: "מְצָדָה", distractors: ["רֹאשׁ הַנִּקְרָה", "קֵיסָרְיָה", "מִגְדַּל דָּוִד"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌊\nאֵיפֹה נִמְצָאוֹת הַנְּקָרוֹת הַלְּבָנוֹת שֶׁהַיָּם חָצַב בַּסֶּלַע, בַּקָּצֶה הַצְּפוֹנִי שֶׁל חוֹף יִשְׂרָאֵל?", correctAnswer: "רֹאשׁ הַנִּקְרָה", distractors: ["אֵילַת", "מְצָדָה", "יָפוֹ"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🕳️\nבְּאֵיזֶה אֵזוֹר נִמְצָא מַכְתֵּשׁ רָמוֹן?", correctAnswer: "בַּנֶּגֶב", distractors: ["בַּגָּלִיל", "בַּכַּרְמֶל", "בַּשָּׁרוֹן"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · גֵּאוֹגְרַפְיָה ──
        BankQuestion(prompt: "🗺️\nהַיָּם הַתִּיכוֹן, יַם הַמֶּלַח, יַם סוּף וְהַכִּנֶּרֶת — כַּמָּה \"יַמִּים\" יֵשׁ לְיִשְׂרָאֵל?", correctAnswer: "4", distractors: ["2", "3", "5"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🚰\nאֵיזֶה מֵהַיַּמִּים שֶׁל יִשְׂרָאֵל הוּא אֲגַם שֶׁל מַיִם מְתוּקִים, שֶׁאֶפְשָׁר לִשְׁתּוֹת?", correctAnswer: "הַכִּנֶּרֶת", distractors: ["יַם הַמֶּלַח", "הַיָּם הַתִּיכוֹן", "יַם סוּף"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🧭\nבְּאֵיזֶה צַד שֶׁל יִשְׂרָאֵל נִמְצָא יַם הַמֶּלַח?", correctAnswer: "בַּמִּזְרָח", distractors: ["בַּמַּעֲרָב", "בַּצָּפוֹן", "בַּדָּרוֹם"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🏞️\nאֵיךְ קוֹרְאִים לַנָּהָר שֶׁזּוֹרֵם מֵהַכִּנֶּרֶת אֶל יַם הַמֶּלַח?", correctAnswer: "הַיַּרְדֵּן", distractors: ["הַיַּרְקוֹן", "הַקִּישׁוֹן", "הַנִּילוּס"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "📉\nאֵיזֶה מָקוֹם בְּיִשְׂרָאֵל הוּא הַנָּמוּךְ בְּיוֹתֵר בָּעוֹלָם עַל פְּנֵי הַיַּבָּשָׁה?", correctAnswer: "יַם הַמֶּלַח", distractors: ["הַכִּנֶּרֶת", "הַנֶּגֶב", "אֵילַת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🏔️\nמַהוּ הָהָר הַגָּבוֹהַּ בְּיוֹתֵר בְּיִשְׂרָאֵל?", correctAnswer: "הַחֶרְמוֹן", distractors: ["הַכַּרְמֶל", "הַר מֵירוֹן", "הַר תָּבוֹר"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌍\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת יִשְׂרָאֵל?", correctAnswer: "אַסְיָה", distractors: ["אֵירוֹפָּה", "אַפְרִיקָה", "אָמֵרִיקָה"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍯\nאֶרֶץ יִשְׂרָאֵל מְכֻנָּה \"אֶרֶץ זָבַת…\" — מָה?", correctAnswer: "חָלָב וּדְבַשׁ", distractors: ["מַיִם וְיַיִן", "לֶחֶם וּמֶלַח", "שֶׁמֶן וְזֵיתִים"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · טֶבַע ──
        BankQuestion(prompt: "🦌\nאֵיזֶה בַּעַל חַיִּים עִם קַרְנַיִם מְעֻקָּלוֹת מְטַפֵּס עַל הַצּוּקִים בְּעֵין גֶּדִי?", correctAnswer: "יָעֵל", distractors: ["זֶבְּרָה", "פִּיל", "דֹּב"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌺\nבְּאֵיזֶה צֶבַע פּוֹרְחוֹת רֹב הַכַּלָּנִיּוֹת שֶׁמְּמַלְּאוֹת אֶת שְׂדוֹת הַדָּרוֹם בַּחֹרֶף?", correctAnswer: "אָדֹם", distractors: ["כָּחֹל", "צָהֹב", "שָׁחֹר"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🐦\nמָה מְיֻחָד בַּמַּרְאֶה שֶׁל הַדּוּכִיפַת?", correctAnswer: "צִיצַת נוֹצוֹת עַל הָרֹאשׁ", distractors: ["זָנָב אָרֹךְ כְּמוֹ שֶׁל טַוָּס", "צַוָּאר אָרֹךְ מְאוֹד", "רַגְלַיִם וְרֻדּוֹת"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · חַגִּים ──
        BankQuestion(prompt: "🧀\nבְּאֵיזֶה חַג נָהוּג לֶאֱכֹל מַאַכְלֵי חָלָב וּלְהִתְקַשֵּׁט בִּזְרֵי פְּרָחִים?", correctAnswer: "שָׁבוּעוֹת", distractors: ["סֻכּוֹת", "פּוּרִים", "חֲנֻכָּה"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🔥\nבְּאֵיזֶה חַג מַדְלִיקִים מְדוּרוֹת?", correctAnswer: "ל״ג בָּעֹמֶר", distractors: ["חֲנֻכָּה", "פֶּסַח", "שָׁבוּעוֹת"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · הִיסְטוֹרְיָה וְהַמְצָאוֹת ──
        BankQuestion(prompt: "📅\nבְּאֵיזוֹ שָׁנָה קָמָה מְדִינַת יִשְׂרָאֵל?", correctAnswer: "1948", distractors: ["1900", "1967", "2000"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "👔\nמִי הָיָה רֹאשׁ הַמֶּמְשָׁלָה הָרִאשׁוֹן שֶׁל יִשְׂרָאֵל?", correctAnswer: "דָּוִד בֶּן־גּוּרְיוֹן", distractors: ["בִּנְיָמִין זְאֵב הֶרְצְל", "חַיִּים וַיְצְמָן", "גּוֹלְדָּה מֵאִיר"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🎩\nמִי מְכֻנֶּה \"חוֹזֵה הַמְּדִינָה\"?", correctAnswer: "בִּנְיָמִין זְאֵב הֶרְצְל", distractors: ["דָּוִד בֶּן־גּוּרְיוֹן", "אֱלִיעֶזֶר בֶּן־יְהוּדָה", "חַיִּים נַחְמָן בְּיָאלִיק"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🚗\nאֵיזוֹ אַפְּלִיקַצְיַת נִוּוּט מְפֻרְסֶמֶת הֻמְצְאָה בְּיִשְׂרָאֵל?", correctAnswer: "Waze", distractors: ["גּוּגְל מַפּוֹת", "יוּטְיוּבּ", "טִיקְטוֹק"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍅\nאֵיזֶה יֶרֶק קָטָן וּמָתוֹק פֻּתַּח בְּיִשְׂרָאֵל וְנִמְכָּר הַיּוֹם בְּכָל הָעוֹלָם?", correctAnswer: "עַגְבָנִיּוֹת שֶׁרִי", distractors: ["מְלָפְפוֹן", "גֶּזֶר", "תַּפּוּחַ אֲדָמָה"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "💧\nאֵיזוֹ שִׁיטַת הַשְׁקָיָה, שֶׁמְּטַפְטֶפֶת מַיִם יָשָׁר לַשֹּׁרֶשׁ, הֻמְצְאָה בְּיִשְׂרָאֵל?", correctAnswer: "הַשְׁקָיָה בְּטִפְטוּף", distractors: ["הַשְׁקָיָה בְּמַמְטֵרוֹת", "הַשְׁקָיָה בִּדְלָיִים", "הַשְׁקָיָה בְּצִנּוֹר"], tier: .medium, grades: 3...5),

        // ── קָשֶׁה ──
        BankQuestion(prompt: "📖\nמִי הֶחֱיָה אֶת הָעִבְרִית וְהָפַךְ אוֹתָהּ שׁוּב לְשָׂפָה מְדֻבֶּרֶת?", correctAnswer: "אֱלִיעֶזֶר בֶּן־יְהוּדָה", distractors: ["בִּנְיָמִין זְאֵב הֶרְצְל", "דָּוִד בֶּן־גּוּרְיוֹן", "חַיִּים נַחְמָן בְּיָאלִיק"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🎼\nמִי כָּתַב אֶת מִלּוֹת הַהִמְנוֹן \"הַתִּקְוָה\"?", correctAnswer: "נַפְתָּלִי הֶרְץ אִימְבֶּר", distractors: ["חַיִּים נַחְמָן בְּיָאלִיק", "נָעֳמִי שֶׁמֶר", "לֵאָה גּוֹלְדְבֶּרְג"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "📜\nבְּאֵיזוֹ עִיר הִכְרִיז דָּוִד בֶּן־גּוּרְיוֹן עַל הֲקָמַת מְדִינַת יִשְׂרָאֵל?", correctAnswer: "תֵּל אָבִיב", distractors: ["יְרוּשָׁלַיִם", "חֵיפָה", "בְּאֵר שֶׁבַע"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🏗️\nאֵיזוֹ עִיר נוֹסְדָה בִּשְׁנַת 1909 וְנֶחְשֶׁבֶת לָעִיר הָעִבְרִית הָרִאשׁוֹנָה?", correctAnswer: "תֵּל אָבִיב", distractors: ["חֵיפָה", "רִאשׁוֹן לְצִיּוֹן", "פֶּתַח תִּקְוָה"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "👥\nאֵיזוֹ עִיר הִיא הַגְּדוֹלָה בְּיוֹתֵר בְּיִשְׂרָאֵל בְּמִסְפַּר הַתּוֹשָׁבִים?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "רִאשׁוֹן לְצִיּוֹן"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🚇\nבְּאֵיזוֹ עִיר נוֹסַעַת \"הַכַּרְמֶלִית\" — הָרַכֶּבֶת הַתַּחְתִּית הַיְּחִידָה בְּיִשְׂרָאֵל?", correctAnswer: "חֵיפָה", distractors: ["תֵּל אָבִיב", "יְרוּשָׁלַיִם", "בְּאֵר שֶׁבַע"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🏞️\nאֵיךְ קוֹרְאִים לַנָּהָר שֶׁזּוֹרֵם דֶּרֶךְ תֵּל אָבִיב אֶל הַיָּם הַתִּיכוֹן?", correctAnswer: "הַיַּרְקוֹן", distractors: ["הַיַּרְדֵּן", "הַקִּישׁוֹן", "הַנִּילוּס"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🏜️\nאֵיזֶה חֵלֶק מִשֶּׁטַח מְדִינַת יִשְׂרָאֵל תּוֹפֵס הַנֶּגֶב?", correctAnswer: "יוֹתֵר מֵחֵצִי", distractors: ["פָּחוֹת מֵעֲשִׂירִית", "בְּעֵרֶךְ רֶבַע", "בְּעֵרֶךְ שְׁלִישׁ"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🚰\nאֵיךְ קוֹרְאִים לַמִּפְעָל הַגָּדוֹל שֶׁמּוֹלִיךְ מַיִם מֵהַכִּנֶּרֶת דָּרוֹמָה, עַד הַנֶּגֶב?", correctAnswer: "הַמּוֹבִיל הָאַרְצִי", distractors: ["תְּעָלַת סוּאֵץ", "הַיַּרְקוֹן", "הַמְּסִלָּה הָאַרְצִית"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🌊\nאֵיךְ קוֹרְאִים לַתַּהֲלִיךְ שֶׁבּוֹ הוֹפְכִים בְּיִשְׂרָאֵל מֵי יָם לְמֵי שְׁתִיָּה?", correctAnswer: "הַתְפָּלָה", distractors: ["הַקְפָּאָה", "הַרְתָּחָה", "סִנּוּן בְּחוֹל"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "💾\nאֵיזֶה מַכְשִׁיר קָטָן לְאִחְסוּן קְבָצִים, שֶׁמְּחַבְּרִים לַמַּחְשֵׁב, הֻמְצָא בְּיִשְׂרָאֵל?", correctAnswer: "דִּיסְק־אוֹן־קִי", distractors: ["הָעַכְבָּר", "הַמַּדְפֶּסֶת", "הַמִּקְלֶדֶת"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "☀️\nאֵיזֶה מִתְקָן עַל הַגַּגּוֹת בְּיִשְׂרָאֵל מְחַמֵּם מַיִם בְּעֶזְרַת הַשֶּׁמֶשׁ?", correctAnswer: "דּוּד שֶׁמֶשׁ", distractors: ["מַזְגָּן", "אַנְטֶנָה", "מְקָרֵר"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🌳\nאֵיזֶה עֵץ נִבְחַר לָעֵץ הַלְּאֻמִּי שֶׁל יִשְׂרָאֵל?", correctAnswer: "זַיִת", distractors: ["אֹרֶן", "אֵיקָלִיפְּטוּס", "דֶּקֶל"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🗓️\nבְּאֵיזֶה חֹדֶשׁ עִבְרִי חָל יוֹם הָעַצְמָאוּת?", correctAnswer: "אִיָּר", distractors: ["תִּשְׁרֵי", "נִיסָן", "כִּסְלֵו"], tier: .hard, grades: 4...6),
    ]
}
