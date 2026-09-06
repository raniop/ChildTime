import Foundation

/// 🎵 מוּזִיקָה — question pack for גן–ד׳. Instruments and their families,
/// how each one is played, the 7 note names, rhythm/tempo, the orchestra and
/// its conductor, one-line composer facts, and well-known public-domain
/// Israeli children's songs (subjects only — never lyrics). Facts are
/// deliberately timeless. Grade-tagged like every bank (compiler-enforced).
enum QuestionBanksMusic {
    static let music: [BankQuestion] = [
        // ── קַל · כֵּלִים וְאֵיךְ מְנַגְּנִים בָּהֶם ──
        BankQuestion(prompt: "🎸\nכַּמָּה מֵיתָרִים יֵשׁ בְּגִיטָרָה רְגִילָה?", correctAnswer: "6", distractors: ["4", "5", "8"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎻\nכַּמָּה מֵיתָרִים יֵשׁ בְּכִנּוֹר?", correctAnswer: "4", distractors: ["3", "5", "6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎹\nבְּאֵילוּ שְׁנֵי צְבָעִים צְבוּעִים הַקְּלִידִים שֶׁל הַפְּסַנְתֵּר?", correctAnswer: "שָׁחֹר וְלָבָן", distractors: ["אָדֹם וְכָחֹל", "יָרֹק וְצָהֹב", "כָּתֹם וְסָגֹל"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥁\nאֵיךְ מְנַגְּנִים בְּתֻפִּים?", correctAnswer: "מַכִּים בָּהֶם", distractors: ["נוֹשְׁפִים בָּהֶם", "פּוֹרְטִים עֲלֵיהֶם", "מְסוֹבְבִים אוֹתָם"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎸\nאֵיךְ מְנַגְּנִים בְּגִיטָרָה?", correctAnswer: "פּוֹרְטִים עַל הַמֵּיתָרִים", distractors: ["נוֹשְׁפִים בָּהּ", "מַכִּים בָּהּ בְּמַקְלוֹת", "לוֹחֲצִים עַל קְלִידִים"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎻\nבְּמַה מוֹשְׁכִים עַל מֵיתְרֵי הַכִּנּוֹר כְּדֵי לְנַגֵּן?", correctAnswer: "בְּקֶשֶׁת", distractors: ["בְּפַטִּישׁ", "בְּמַקֵּל תֻּפִּים", "בְּכַף"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎹\nבְּאֵיזֶה כְּלִי נְגִינָה לוֹחֲצִים עַל קְלִידִים?", correctAnswer: "פְּסַנְתֵּר", distractors: ["תֹּף", "כִּנּוֹר", "חֲצוֹצְרָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪈\nבְּאֵיזֶה כְּלִי נְגִינָה נוֹשְׁפִים?", correctAnswer: "חָלִיל", distractors: ["תֹּף", "גִּיטָרָה", "פְּסַנְתֵּר"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥁\nאֵיזֶה כְּלִי נְגִינָה הוּא כְּלִי הַקָּשָׁה?", correctAnswer: "תֹּף", distractors: ["כִּנּוֹר", "חָלִיל", "גִּיטָרָה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎻\nאֵיזֶה כְּלִי נְגִינָה הוּא כְּלִי מֵיתָר?", correctAnswer: "כִּנּוֹר", distractors: ["תֹּף", "חֲצוֹצְרָה", "מְצִלְתַּיִם"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🪘\nאֵיךְ מְנַגְּנִים בְּדַרְבּוּקָה?", correctAnswer: "מַכִּים בָּהּ בַּיָּדַיִם", distractors: ["נוֹשְׁפִים בָּהּ", "מוֹשְׁכִים עָלֶיהָ קֶשֶׁת", "לוֹחֲצִים עַל קְלִידִים"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪈\nאֵיזֶה כְּלִי נְשִׁיפָה קָטָן לוֹמְדִים הַרְבֵּה יְלָדִים לְנַגֵּן בְּבֵית הַסֵּפֶר?", correctAnswer: "חֲלִילִית", distractors: ["חֲצוֹצְרָה", "פְּסַנְתֵּר", "קוֹנְטְרַבָּס"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎤\nמַה עוֹזֵר לְזַמָּר לְהִשָּׁמַע חָזָק יוֹתֵר?", correctAnswer: "מִיקְרוֹפוֹן", distractors: ["מִשְׁקָפַיִם", "כּוֹבַע", "שַׁרְבִיט"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎧\nאֵיךְ קוֹרְאִים לְמִי שֶׁמְּנַגֵּן בִּכְלִי נְגִינָה?", correctAnswer: "נַגָּן", distractors: ["זַמָּר", "צַיָּר", "סַפָּר"], tier: .easy, grades: 0...2),

        // ── קַל · תָּוִים, קֶצֶב וּצְלִילִים ──
        BankQuestion(prompt: "🎵\nכַּמָּה תָּוִים יֵשׁ בַּסֻּלָּם: דּוֹ, רֶה, מִי, פָה, סוֹל, לָה, סִי?", correctAnswer: "7", distractors: ["5", "8", "10"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎵\nמַהוּ הַתָּו הָרִאשׁוֹן בַּסֻּלָּם?", correctAnswer: "דּוֹ", distractors: ["רֶה", "סוֹל", "סִי"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎵\nאֵיזֶה תָּו בָּא מִיָּד אַחֲרֵי \"דּוֹ\"?", correctAnswer: "רֶה", distractors: ["מִי", "פָה", "לָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎼\nאֵיךְ קוֹרְאִים לַסִּימָנִים שֶׁכּוֹתְבִים בָּהֶם מוּזִיקָה?", correctAnswer: "תָּוִים", distractors: ["אוֹתִיּוֹת", "סְפָרוֹת", "נְקֻדּוֹת"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔉\nמַה הַהֵפֶךְ שֶׁל מוּזִיקָה חֲזָקָה?", correctAnswer: "מוּזִיקָה שְׁקֵטָה", distractors: ["מוּזִיקָה מְהִירָה", "מוּזִיקָה אֲרֻכָּה", "מוּזִיקָה עַלִּיזָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐇\nמַה הַהֵפֶךְ שֶׁל מוּזִיקָה אִטִּית?", correctAnswer: "מוּזִיקָה מְהִירָה", distractors: ["מוּזִיקָה חֲזָקָה", "מוּזִיקָה שְׁקֵטָה", "מוּזִיקָה עֲצוּבָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎵\nמַה הַהֵפֶךְ שֶׁל צְלִיל גָּבוֹהַּ?", correctAnswer: "צְלִיל נָמוּךְ", distractors: ["צְלִיל חָזָק", "צְלִיל מָהִיר", "צְלִיל אָרֹךְ"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐦\nאֵיזֶה קוֹל הוּא הַגָּבוֹהַּ בְּיוֹתֵר?", correctAnswer: "צִיּוּץ שֶׁל צִפּוֹר", distractors: ["גְּעִיָּה שֶׁל פָּרָה", "שְׁאָגָה שֶׁל אַרְיֵה", "צְלִיל שֶׁל טוּבָּה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "👏\nכְּשֶׁמּוֹחֲאִים כַּפַּיִם יַחַד עִם הַמּוּזִיקָה, לְפִי מַה מוֹחֲאִים?", correctAnswer: "לְפִי הַקֶּצֶב", distractors: ["לְפִי הַצֶּבַע", "לְפִי הַגֹּבַהּ", "לְפִי הַטַּעַם"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "👏\nמָחֲאנוּ כַּף 2 פְּעָמִים, וְאָז עוֹד 2 פְּעָמִים. כַּמָּה מְחִיאוֹת כַּף בְּסַךְ הַכֹּל?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 0...1),

        // ── קַל · מַקְהֵלָה, תִּזְמֹרֶת וְשִׁירִים ──
        BankQuestion(prompt: "🎤\nאֵיךְ קוֹרְאִים לִקְבוּצָה שֶׁל אֲנָשִׁים שֶׁשָּׁרִים יַחַד?", correctAnswer: "מַקְהֵלָה", distractors: ["תִּזְמֹרֶת", "לַהֲקַת רִקּוּד", "קְבוּצַת כַּדּוּרֶגֶל"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎼\nאֵיךְ קוֹרְאִים לִקְבוּצָה גְּדוֹלָה שֶׁל נַגָּנִים שֶׁמְּנַגְּנִים יַחַד?", correctAnswer: "תִּזְמֹרֶת", distractors: ["מַקְהֵלָה", "כִּתָּה", "מִשְׁפָּחָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪄\nמִי עוֹמֵד מוּל הַתִּזְמֹרֶת וּמְסַמֵּן לַנַּגָּנִים מָתַי וְאֵיךְ לְנַגֵּן?", correctAnswer: "הַמְּנַצֵּחַ", distractors: ["הַשּׁוֹפֵט", "הַנַּהָג", "הַצַּיָּר"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🌙\nאֵיךְ קוֹרְאִים לְשִׁיר שֶׁשָּׁרִים לְתִינוֹק כְּדֵי שֶׁיֵּרָדֵם?", correctAnswer: "שִׁיר עֶרֶשׂ", distractors: ["הִמְנוֹן", "שִׁיר לֶכֶת", "שִׁיר יוֹם הֻלֶּדֶת"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🌳\nעַל מַה מְסַפֵּר הַשִּׁיר \"יוֹנָתָן הַקָּטָן\"?", correctAnswer: "עַל יֶלֶד שֶׁטִּפֵּס עַל עֵץ", distractors: ["עַל חָתוּל שֶׁשָּׁתָה חָלָב", "עַל אֳנִיָּה בַּיָּם", "עַל דֻּבִּי שֶׁהָלַךְ לִישֹׁן"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎠\nעַל מַה מְסַפֵּר הַשִּׁיר \"נַד־נֵד\"?", correctAnswer: "עַל נַדְנֵדָה", distractors: ["עַל מַגְלֵשָׁה", "עַל אוֹפַנַּיִם", "עַל בָּלוֹן"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎂\nאֵיזֶה שִׁיר שָׁרִים כְּשֶׁמַּדְלִיקִים נֵרוֹת עַל עוּגַת יוֹם הֻלֶּדֶת?", correctAnswer: "יוֹם הֻלֶּדֶת שָׂמֵחַ", distractors: ["יוֹנָתָן הַקָּטָן", "נַד־נֵד", "הַתִּקְוָה"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🕎\nבְּאֵיזֶה חַג שָׁרִים \"מָעוֹז צוּר\"?", correctAnswer: "חֲנֻכָּה", distractors: ["פֶּסַח", "פּוּרִים", "סֻכּוֹת"], tier: .easy, grades: 0...2),

        // ── בֵּינוֹנִי · מִשְׁפְּחוֹת הַכֵּלִים ──
        BankQuestion(prompt: "🎸\nלְאֵיזוֹ מִשְׁפָּחָה שַׁיֶּכֶת הַגִּיטָרָה?", correctAnswer: "כְּלֵי מֵיתָר", distractors: ["כְּלֵי נְשִׁיפָה", "כְּלֵי הַקָּשָׁה", "כְּלֵי מַקְלֶדֶת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎺\nלְאֵיזוֹ מִשְׁפָּחָה שַׁיֶּכֶת הַחֲצוֹצְרָה?", correctAnswer: "כְּלֵי נְשִׁיפָה", distractors: ["כְּלֵי מֵיתָר", "כְּלֵי הַקָּשָׁה", "כְּלֵי מַקְלֶדֶת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🥁\nלְאֵיזוֹ מִשְׁפָּחָה שַׁיָּכִים הַתֻּפִּים?", correctAnswer: "כְּלֵי הַקָּשָׁה", distractors: ["כְּלֵי מֵיתָר", "כְּלֵי נְשִׁיפָה", "כְּלֵי מַקְלֶדֶת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎷\nלְאֵיזוֹ מִשְׁפָּחָה שַׁיָּךְ הַסַּקְסוֹפוֹן?", correctAnswer: "כְּלֵי נְשִׁיפָה", distractors: ["כְּלֵי מֵיתָר", "כְּלֵי הַקָּשָׁה", "כְּלֵי מַקְלֶדֶת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎹\nאוֹרְגָּן וְסִינְתִּיסַיְזֶר — לְאֵיזוֹ מִשְׁפָּחָה הֵם שַׁיָּכִים?", correctAnswer: "כְּלֵי מַקְלֶדֶת", distractors: ["כְּלֵי מֵיתָר", "כְּלֵי נְשִׁיפָה", "כְּלֵי הַקָּשָׁה"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔔\nמְצִלְתַּיִם הֵם שְׁנֵי לוּחוֹת מַתֶּכֶת עֲגֻלִּים. אֵיךְ מְנַגְּנִים בָּהֶם?", correctAnswer: "מַכִּים אוֹתָם זוֹ בָּזוֹ", distractors: ["נוֹשְׁפִים לְתוֹכָם", "פּוֹרְטִים עֲלֵיהֶם", "לוֹחֲצִים עַל קְלִידִים"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎻\nאֵיזֶה כְּלִי דּוֹמֶה לְכִנּוֹר אֲבָל גָּדוֹל יוֹתֵר, וּמְנַגְּנִים בּוֹ בִּישִׁיבָה?", correctAnswer: "צֶ'לוֹ", distractors: ["חָלִיל", "טוּבָּה", "נֵבֶל"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎻\nאֵיזֶה מֵהַכֵּלִים הָאֵלֶּה מַשְׁמִיעַ אֶת הַצְּלִילִים הַנְּמוּכִים בְּיוֹתֵר?", correctAnswer: "קוֹנְטְרַבָּס", distractors: ["כִּנּוֹר", "חֲלִילִית", "פִּיקוֹלוֹ"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎺\nטוּבָּה הִיא כְּלִי נְשִׁיפָה גָּדוֹל מְאוֹד. אֵיזֶה צְלִילִים הִיא מַשְׁמִיעָה?", correctAnswer: "נְמוּכִים", distractors: ["גְּבוֹהִים מְאוֹד", "חַדִּים כְּמוֹ שְׁרִיקָה", "דַּקִּים כְּמוֹ פַּעֲמוֹן"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪕\nאֵיזֶה כְּלִי מֵיתָר גָּדוֹל, בְּצוּרַת מְשֻׁלָּשׁ, פּוֹרְטִים עָלָיו בָּאֶצְבָּעוֹת?", correctAnswer: "נֵבֶל", distractors: ["כִּנּוֹר", "טוּבָּה", "אַקּוֹרְדְּיוֹן"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪗\nאֵיזֶה כְּלִי נְגִינָה מוֹתְחִים וּמְכַוְּצִים בַּיָּדַיִם, וְיֵשׁ לוֹ גַּם קְלִידִים?", correctAnswer: "אַקּוֹרְדְּיוֹן", distractors: ["פְּסַנְתֵּר", "חָלִיל", "תֹּף"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎸\nכַּמָּה מֵיתָרִים יֵשׁ בְּדֶרֶךְ כְּלָל בְּגִיטָרָה בַּס?", correctAnswer: "4", distractors: ["2", "6", "8"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎹\nהַקְּלִידִים הַשְּׁחֹרִים בַּפְּסַנְתֵּר מְסֻדָּרִים בִּקְבוּצוֹת שֶׁל…", correctAnswer: "2 וְ־3", distractors: ["1 וְ־4", "4 וְ־5", "3 וְ־6"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥁\nאֵיזֶה כְּלִי שׁוֹמֵר בְּדֶרֶךְ כְּלָל עַל הַקֶּצֶב בְּלַהֲקָה?", correctAnswer: "תֻּפִּים", distractors: ["חָלִיל", "כִּנּוֹר", "מִיקְרוֹפוֹן"], tier: .medium, grades: 1...3),

        // ── בֵּינוֹנִי · תָּוִים, קֶצֶב וּמֻשָּׂגִים ──
        BankQuestion(prompt: "🎵\nאֵיזֶה תָּו בָּא מִיָּד אַחֲרֵי \"מִי\"?", correctAnswer: "פָה", distractors: ["רֶה", "סוֹל", "סִי"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎵\nאֵיזֶה תָּו בָּא מִיָּד לִפְנֵי \"סוֹל\"?", correctAnswer: "פָה", distractors: ["מִי", "לָה", "דּוֹ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎵\nאֵיזֶה תָּו בָּא מִיָּד אַחֲרֵי \"לָה\"?", correctAnswer: "סִי", distractors: ["סוֹל", "פָה", "רֶה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎼\nעַל כַּמָּה קַוִּים כּוֹתְבִים אֶת הַתָּוִים בַּחַמְשָׁה?", correctAnswer: "5", distractors: ["3", "4", "7"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "⏩\nאֵיךְ קוֹרְאִים לַמְּהִירוּת שֶׁל הַמּוּזִיקָה?", correctAnswer: "טֶמְפּוֹ", distractors: ["מֶלוֹדְיָה", "הַרְמוֹנְיָה", "סֻלָּם"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎶\nמַה הַמִּלָּה הַלּוֹעֲזִית לְ\"מַנְגִּינָה\"?", correctAnswer: "מֶלוֹדְיָה", distractors: ["טֶמְפּוֹ", "רִיתְמוּס", "סוֹלוֹ"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔢\nבְּשִׁיר שֶׁסּוֹפְרִים בּוֹ 1-2-3-4, 1-2-3-4, כַּמָּה פְּעִימוֹת יֵשׁ בְּכָל תִּבָּה?", correctAnswer: "4", distractors: ["2", "3", "8"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎶\nאֵיךְ קוֹרְאִים לַחֵלֶק בַּשִּׁיר שֶׁחוֹזֵר עַל עַצְמוֹ כַּמָּה פְּעָמִים?", correctAnswer: "פִּזְמוֹן", distractors: ["בַּיִת", "תָּו", "שַׁרְבִיט"], tier: .medium, grades: 2...4),

        // ── בֵּינוֹנִי · מַלְחִינִים וְשִׁירִים ──
        BankQuestion(prompt: "✍️\nמַה עוֹשֶׂה מַלְחִין?", correctAnswer: "כּוֹתֵב מוּזִיקָה חֲדָשָׁה", distractors: ["מְתַקֵּן כְּלֵי נְגִינָה", "מוֹכֵר כַּרְטִיסִים", "מְצַלֵּם הוֹפָעוֹת"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎼\nבָּאךְ, מוֹצַרְט וּבֶטְהוֹבֶן הָיוּ…", correctAnswer: "מַלְחִינִים", distractors: ["צַיָּרִים", "שַׂחְקָנֵי כַּדּוּרֶגֶל", "טַבָּחִים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "👂\nאֵיזֶה מַלְחִין מְפֻרְסָם הִמְשִׁיךְ לְהַלְחִין יְצִירוֹת נִפְלָאוֹת גַּם כְּשֶׁכִּמְעַט לֹא שָׁמַע?", correctAnswer: "בֶּטְהוֹבֶן", distractors: ["מוֹצַרְט", "בָּאךְ", "וִיוַלְדִּי"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🇮🇱\nאֵיךְ קוֹרְאִים לַהִמְנוֹן שֶׁל מְדִינַת יִשְׂרָאֵל?", correctAnswer: "הַתִּקְוָה", distractors: ["יְרוּשָׁלַיִם שֶׁל זָהָב", "יוֹנָתָן הַקָּטָן", "הָבָה נָגִילָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "💃\nאֵיזֶה רִקּוּד יִשְׂרְאֵלִי רוֹקְדִים בְּמַעְגָּל, יָד בְּיָד?", correctAnswer: "הוֹרָה", distractors: ["בָּלֶט", "טַנְגּוֹ", "הִיפּ־הוֹפּ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐐\nבְּאֵיזֶה חַג שָׁרִים \"חַד גַּדְיָא\"?", correctAnswer: "פֶּסַח", distractors: ["חֲנֻכָּה", "פּוּרִים", "רֹאשׁ הַשָּׁנָה"], tier: .medium, grades: 1...3),

        // ── קָשֶׁה · מֻשָּׂגִים וּמַלְחִינִים ──
        BankQuestion(prompt: "🎹\nכַּמָּה קְלִידִים יֵשׁ בִּפְסַנְתֵּר רָגִיל?", correctAnswer: "88", distractors: ["50", "100", "120"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🔊\nבְּמוּזִיקָה, מַה פֵּרוּשׁ הַמִּלָּה \"פוֹרְטֶה\"?", correctAnswer: "לְנַגֵּן בְּעָצְמָה חֲזָקָה", distractors: ["לְנַגֵּן חֶרֶשׁ", "לְנַגֵּן מַהֵר", "לְנַגֵּן לְאַט"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "📈\nמַה פֵּרוּשׁ \"קְרֶשֶׁנְדּוֹ\"?", correctAnswer: "הַמּוּזִיקָה הוֹלֶכֶת וּמִתְחַזֶּקֶת", distractors: ["הַמּוּזִיקָה הוֹלֶכֶת וְנֶחְלֶשֶׁת", "הַמּוּזִיקָה נֶעֱצֶרֶת", "הַמּוּזִיקָה חוֹזֶרֶת מֵהַהַתְחָלָה"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "💃\nבְּרִקּוּד הַוַּלְס סוֹפְרִים בְּכָל תִּבָּה עַד…", correctAnswer: "3", distractors: ["2", "4", "5"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🎼\nאֵיךְ קוֹרְאִים לַסִּימָן הַמְּסֻלְסָל שֶׁמּוֹפִיעַ בִּתְחִלַּת הַחַמְשָׁה?", correctAnswer: "מַפְתֵּחַ סוֹל", distractors: ["סִימָן קְרִיאָה", "סֻלָּם", "פְּעִימָה"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🔁\nמַהוּ שִׁיר בְּ\"קָנוֹן\"?", correctAnswer: "כָּל קְבוּצָה מַתְחִילָה אֶת אוֹתָהּ הַמַּנְגִּינָה קְצָת אַחֲרֵי הַקּוֹדֶמֶת", distractors: ["שִׁיר בְּלִי מִלִּים", "שִׁיר אָרֹךְ מְאוֹד", "שִׁיר שֶׁשָּׁרִים בְּלַחַשׁ"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🇦🇹\nבְּאֵיזוֹ מְדִינָה נוֹלַד הַמַּלְחִין מוֹצַרְט?", correctAnswer: "אוֹסְטְרִיָּה", distractors: ["יִשְׂרָאֵל", "יַפָּן", "בְּרָזִיל"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "👶\nמוֹצַרְט הָיָה יֶלֶד פֶּלֶא. בְּאֵיזֶה גִּיל בְּעֵרֶךְ הוּא הִתְחִיל לְהַלְחִין?", correctAnswer: "5", distractors: ["15", "20", "30"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🍂\nמִי הִלְחִין אֶת הַיְּצִירָה \"אַרְבַּע הָעוֹנוֹת\"?", correctAnswer: "וִיוַלְדִּי", distractors: ["מוֹצַרְט", "בֶּטְהוֹבֶן", "בָּאךְ"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🇩🇪\nמֵאֵיזוֹ מְדִינָה הָיָה הַמַּלְחִין בָּאךְ?", correctAnswer: "גֶּרְמַנְיָה", distractors: ["אִיטַלְיָה", "סְפָרַד", "רוּסְיָה"], tier: .hard, grades: 3...4),
    ]
}
