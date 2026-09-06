import Foundation

/// 🌍 דְּגָלִים וּמְדִינוֹת — flags, capitals, continents, landmarks and currencies
/// for grades ג׳–ו׳. Facts are deliberately timeless (flags, capitals, geography,
/// counting stripes and stars) — no politics, no disputed territories, nothing that
/// changes with an election. Grade-tagged like every bank (compiler-enforced).
enum QuestionBanksFlags {
    static let flags: [BankQuestion] = [
        // ── קַל · דְּגָלִים מֻכָּרִים ──
        BankQuestion(prompt: "🇮🇱\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַזֶּה?", correctAnswer: "יִשְׂרָאֵל", distractors: ["צָרְפַת", "אִיטַלְיָה", "אַרְצוֹת הַבְּרִית"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇺🇸\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל עִם הַכּוֹכָבִים וְהַפַּסִּים?", correctAnswer: "אַרְצוֹת הַבְּרִית", distractors: ["קָנָדָה", "בְּרִיטַנְיָה", "אוֹסְטְרַלְיָה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇫🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַכָּחֹל־לָבָן־אָדֹם הַזֶּה?", correctAnswer: "צָרְפַת", distractors: ["אִיטַלְיָה", "גֶּרְמַנְיָה", "סְפָרַד"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇮🇹\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַיָּרֹק־לָבָן־אָדֹם הַזֶּה?", correctAnswer: "אִיטַלְיָה", distractors: ["צָרְפַת", "סְפָרַד", "יָוָן"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇯🇵\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל עִם הָעִגּוּל הָאָדֹם?", correctAnswer: "יַפָּן", distractors: ["סִין", "הֹדּוּ", "תָּאִילַנְד"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇨🇦\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל עִם הֶעָלֶה הָאָדֹם?", correctAnswer: "קָנָדָה", distractors: ["אַרְצוֹת הַבְּרִית", "שְׁוַיְץ", "יַפָּן"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇧🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַיָּרֹק־צָהֹב הַזֶּה?", correctAnswer: "בְּרָזִיל", distractors: ["פּוֹרְטוּגָל", "אַרְגֶּנְטִינָה", "מֶקְסִיקוֹ"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇬🇧\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַזֶּה?", correctAnswer: "הַמַּמְלָכָה הַמְּאֻחֶדֶת (בְּרִיטַנְיָה)", distractors: ["צָרְפַת", "נוֹרְבֶגְיָה", "אַרְצוֹת הַבְּרִית"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇩🇪\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַשָּׁחֹר־אָדֹם־צָהֹב הַזֶּה?", correctAnswer: "גֶּרְמַנְיָה", distractors: ["בֶּלְגְּיָה", "אוֹסְטְרִיָּה", "סְפָרַד"], tier: .easy, grades: 3...4),

        // ── קַל · אֲתָרִים מְפֻרְסָמִים ──
        BankQuestion(prompt: "🗼\nבְּאֵיזוֹ מְדִינָה נִמְצָא מִגְדַּל אַיְפֶל?", correctAnswer: "צָרְפַת", distractors: ["אִיטַלְיָה", "אַנְגְּלִיָּה", "סְפָרַד"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🐪\nבְּאֵיזוֹ מְדִינָה נִמְצָאוֹת הַפִּירָמִידוֹת הַמְּפֻרְסָמוֹת?", correctAnswer: "מִצְרַיִם", distractors: ["יָוָן", "מֶקְסִיקוֹ", "טוּרְקִיָּה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🗽\nבְּאֵיזוֹ מְדִינָה נִמְצָא פֶּסֶל הַחֵרוּת?", correctAnswer: "אַרְצוֹת הַבְּרִית", distractors: ["צָרְפַת", "קָנָדָה", "בְּרָזִיל"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🧱\nבְּאֵיזוֹ מְדִינָה נִמְצֵאת הַחוֹמָה הַגְּדוֹלָה, שֶׁאָרְכָּהּ אַלְפֵי קִילוֹמֶטְרִים?", correctAnswer: "סִין", distractors: ["יַפָּן", "הֹדּוּ", "רוּסְיָה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🕰️\nבְּאֵיזוֹ מְדִינָה נִמְצָא \"בִּיג בֶּן\"?", correctAnswer: "אַנְגְּלִיָּה", distractors: ["צָרְפַת", "גֶּרְמַנְיָה", "אִיטַלְיָה"], tier: .easy, grades: 3...4),

        // ── קַל · עָרֵי בִּירָה ──
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת יִשְׂרָאֵל?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🥐\nמַהִי בִּירַת צָרְפַת?", correctAnswer: "פָּרִיז", distractors: ["לוֹנְדוֹן", "רוֹמָא", "מַדְרִיד"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🍕\nמַהִי בִּירַת אִיטַלְיָה?", correctAnswer: "רוֹמָא", distractors: ["מִילָאנוֹ", "פָּרִיז", "אָתוּנָה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🎡\nמַהִי בִּירַת אַנְגְּלִיָּה?", correctAnswer: "לוֹנְדוֹן", distractors: ["פָּרִיז", "בֶּרְלִין", "דַּבְּלִין"], tier: .easy, grades: 3...4),

        // ── קַל · יַבָּשׁוֹת וְאוֹקְיָנוֹסִים ──
        BankQuestion(prompt: "🌏\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת יִשְׂרָאֵל?", correctAnswer: "אַסְיָה", distractors: ["אֵירוֹפָּה", "אַפְרִיקָה", "אַמֶרִיקָה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nכַּמָּה יַבָּשׁוֹת יֵשׁ בָּעוֹלָם?", correctAnswer: "7", distractors: ["5", "6", "9"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌊\nכַּמָּה אוֹקְיָנוֹסִים יֵשׁ בָּעוֹלָם?", correctAnswer: "5", distractors: ["3", "4", "7"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת צָרְפַת?", correctAnswer: "אֵירוֹפָּה", distractors: ["אַסְיָה", "אַפְרִיקָה", "אוֹסְטְרַלְיָה"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת מִצְרַיִם?", correctAnswer: "אַפְרִיקָה", distractors: ["אַסְיָה", "אֵירוֹפָּה", "דְּרוֹם אַמֶרִיקָה"], tier: .easy, grades: 3...4),

        // ── קַל · צְבָעִים וּסְמָלִים בַּדֶּגֶל ──
        BankQuestion(prompt: "🇮🇱\nמָה הֵם צִבְעֵי דֶּגֶל יִשְׂרָאֵל?", correctAnswer: "כָּחֹל וְלָבָן", distractors: ["אָדֹם וְלָבָן", "כָּחֹל וְאָדֹם", "יָרֹק וְלָבָן"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "✡️\nאֵיזֶה סֵמֶל מוֹפִיעַ בְּמֶרְכַּז דֶּגֶל יִשְׂרָאֵל?", correctAnswer: "מָגֵן דָּוִד", distractors: ["מְנוֹרָה", "כּוֹכָב אֶחָד", "עֲלֵה זַיִת"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "⭐\nכַּמָּה כּוֹכָבִים יֵשׁ בְּדֶגֶל אַרְצוֹת הַבְּרִית?", correctAnswer: "50", distractors: ["13", "52", "100"], tier: .easy, grades: 3...4),

        // ── קַל · שָׂפוֹת וּמַטְבְּעוֹת ──
        BankQuestion(prompt: "🗣️\nבְּאֵיזוֹ שָׂפָה מְדַבְּרִים בְּצָרְפַת?", correctAnswer: "צָרְפָתִית", distractors: ["סְפָרַדִּית", "אִיטַלְקִית", "גֶּרְמָנִית"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🪙\nמַהוּ הַמַּטְבֵּעַ שֶׁל יִשְׂרָאֵל?", correctAnswer: "שֶׁקֶל", distractors: ["דּוֹלָר", "אֵירוֹ", "לִירָה"], tier: .easy, grades: 3...4),

        // ── בֵּינוֹנִי · עוֹד דְּגָלִים ──
        BankQuestion(prompt: "🇨🇳\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הָאָדֹם עִם 5 הַכּוֹכָבִים הַצְּהֻבִּים?", correctAnswer: "סִין", distractors: ["יַפָּן", "דְּרוֹם קוֹרֵיאָה", "תָּאִילַנְד"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇦🇺\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַזֶּה?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["בְּרִיטַנְיָה", "קָנָדָה", "אַרְצוֹת הַבְּרִית"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇲🇽\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל עִם הַנֶּשֶׁר בַּמֶּרְכָּז?", correctAnswer: "מֶקְסִיקוֹ", distractors: ["בְּרָזִיל", "סְפָרַד", "אַרְגֶּנְטִינָה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇦🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַתְּכֵלֶת־לָבָן עִם הַשֶּׁמֶשׁ?", correctAnswer: "אַרְגֶּנְטִינָה", distractors: ["בְּרָזִיל", "מֶקְסִיקוֹ", "פּוֹרְטוּגָל"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇬🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַכָּחֹל־לָבָן עִם הַפַּסִּים וְהַצְּלָב?", correctAnswer: "יָוָן", distractors: ["טוּרְקִיָּה", "אִיטַלְיָה", "סְפָרַד"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇹🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הָאָדֹם עִם הַסַּהַר וְהַכּוֹכָב?", correctAnswer: "טוּרְקִיָּה", distractors: ["יָוָן", "מָרוֹקוֹ", "מִצְרַיִם"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇷🇺\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַלָּבָן־כָּחֹל־אָדֹם הַזֶּה?", correctAnswer: "רוּסְיָה", distractors: ["צָרְפַת", "פּוֹלִין", "יָוָן"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇰🇷\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל עִם הָעִגּוּל הָאָדֹם־כָּחֹל?", correctAnswer: "דְּרוֹם קוֹרֵיאָה", distractors: ["יַפָּן", "סִין", "תָּאִילַנְד"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇮🇳\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַכָּתֹם־לָבָן־יָרֹק עִם הַגַּלְגַּל?", correctAnswer: "הֹדּוּ", distractors: ["סִין", "יַפָּן", "מִצְרַיִם"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇨🇭\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הָאָדֹם עִם הַצְּלָב הַלָּבָן?", correctAnswer: "שְׁוַיְץ", distractors: ["שְׁוֶדְיָה", "בֶּלְגְּיָה", "פּוֹלִין"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇪🇬\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הָאָדֹם־לָבָן־שָׁחֹר עִם הַנֶּשֶׁר הַזָּהֹב?", correctAnswer: "מִצְרַיִם", distractors: ["טוּרְקִיָּה", "מָרוֹקוֹ", "יָוָן"], tier: .medium, grades: 4...5),

        // ── בֵּינוֹנִי · עָרֵי בִּירָה ──
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת סְפָרַד?", correctAnswer: "מַדְרִיד", distractors: ["בַּרְצֶלוֹנָה", "לִיסְבּוֹן", "רוֹמָא"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת גֶּרְמַנְיָה?", correctAnswer: "בֶּרְלִין", distractors: ["מִינְכֶן", "וִינָה", "פָּרִיז"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת יַפָּן?", correctAnswer: "טוֹקְיוֹ", distractors: ["בֵּיגִ'ינְג", "סֵאוּל", "אוֹסָקָה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת רוּסְיָה?", correctAnswer: "מוֹסְקְבָה", distractors: ["סַנְט פֶּטֶרְבּוּרְג", "וַרְשָׁה", "בֶּרְלִין"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת מִצְרַיִם?", correctAnswer: "קָהִיר", distractors: ["אֲלֶכְּסַנְדְּרִיָּה", "עַמָּאן", "רַבָּאט"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת אַרְצוֹת הַבְּרִית?", correctAnswer: "וָשִׁינְגְּטוֹן", distractors: ["נְיוּ יוֹרְק", "לוֹס אַנְגֶ'לֶס", "שִׁיקָגוֹ"], tier: .medium, grades: 4...5),

        // ── בֵּינוֹנִי · גָּדוֹל וְקָטָן, יַבָּשׁוֹת וּשְׁכֵנִים ──
        BankQuestion(prompt: "🌏\nמַהִי הַיַּבֶּשֶׁת הַגְּדוֹלָה בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "אַסְיָה", distractors: ["אַפְרִיקָה", "אֵירוֹפָּה", "צְפוֹן אַמֶרִיקָה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🗺️\nמַהִי הַמְּדִינָה הַגְּדוֹלָה בְּיוֹתֵר בָּעוֹלָם בְּשִׁטְחָהּ?", correctAnswer: "רוּסְיָה", distractors: ["סִין", "קָנָדָה", "אַרְצוֹת הַבְּרִית"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🌊\nמַהוּ הָאוֹקְיָנוֹס הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הָאוֹקְיָנוֹס הַשָּׁקֵט", distractors: ["הָאוֹקְיָנוֹס הָאַטְלַנְטִי", "הָאוֹקְיָנוֹס הַהֹדִּי", "הָאוֹקְיָנוֹס הָאַרְקְטִי"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🌎\nבְּאֵיזוֹ יַבֶּשֶׁת נִמְצֵאת בְּרָזִיל?", correctAnswer: "דְּרוֹם אַמֶרִיקָה", distractors: ["צְפוֹן אַמֶרִיקָה", "אַפְרִיקָה", "אֵירוֹפָּה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nאֵיזוֹ מְדִינָה שְׁכֵנָה נִמְצֵאת מִצָּפוֹן לְיִשְׂרָאֵל?", correctAnswer: "לְבָנוֹן", distractors: ["מִצְרַיִם", "יַרְדֵּן", "טוּרְקִיָּה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nאֵיזוֹ מְדִינָה שְׁכֵנָה נִמְצֵאת מִמִּזְרָח לְיִשְׂרָאֵל?", correctAnswer: "יַרְדֵּן", distractors: ["לְבָנוֹן", "מִצְרַיִם", "יָוָן"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nאֵיזוֹ מְדִינָה שְׁכֵנָה נִמְצֵאת מִדְּרוֹם־מַעֲרָב לְיִשְׂרָאֵל?", correctAnswer: "מִצְרַיִם", distractors: ["לְבָנוֹן", "סוּרְיָה", "קַפְרִיסִין"], tier: .medium, grades: 4...5),

        // ── בֵּינוֹנִי · מַטְבְּעוֹת וּסְמָלִים ──
        BankQuestion(prompt: "💶\nבְּאֵיזֶה מַטְבֵּעַ מְשַׁלְּמִים בְּצָרְפַת, בְּגֶרְמַנְיָה וּבְאִיטַלְיָה?", correctAnswer: "אֵירוֹ", distractors: ["דּוֹלָר", "שֶׁקֶל", "לִירָה"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "💵\nמַהוּ הַמַּטְבֵּעַ שֶׁל אַרְצוֹת הַבְּרִית?", correctAnswer: "דּוֹלָר", distractors: ["אֵירוֹ", "שֶׁקֶל", "יֶן"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🍁\nאֵיזֶה עָלֶה מוֹפִיעַ בְּדֶגֶל קָנָדָה?", correctAnswer: "עֲלֵה אֶדֶר", distractors: ["עֲלֵה זַיִת", "עֲלֵה דֶּקֶל", "עֲלֵה אַלּוֹן"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇯🇵\nמָה מְסַמֵּל הָעִגּוּל הָאָדֹם בְּדֶגֶל יַפָּן?", correctAnswer: "הַשֶּׁמֶשׁ", distractors: ["הַיָּרֵחַ", "כַּדּוּר", "פֶּרַח"], tier: .medium, grades: 4...5),

        // ── קָשֶׁה · דְּגָלִים פָּחוֹת מֻכָּרִים ──
        BankQuestion(prompt: "🇸🇪\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַכָּחֹל עִם הַצְּלָב הַצָּהֹב?", correctAnswer: "שְׁוֶדְיָה", distractors: ["נוֹרְבֶגְיָה", "פִינְלַנְד", "דֶּנְמַרְק"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇩🇰\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הָאָדֹם עִם הַצְּלָב הַלָּבָן הַמּוּזָז לַצַּד?", correctAnswer: "דֶּנְמַרְק", distractors: ["שְׁוֶדְיָה", "פִינְלַנְד", "פּוֹלִין"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇵🇹\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַיָּרֹק־אָדֹם הַזֶּה?", correctAnswer: "פּוֹרְטוּגָל", distractors: ["סְפָרַד", "אִיטַלְיָה", "מָרוֹקוֹ"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇿🇦\nשֶׁל אֵיזוֹ מְדִינָה הַדֶּגֶל הַצִּבְעוֹנִי הַזֶּה עִם צוּרַת Y?", correctAnswer: "דְּרוֹם אַפְרִיקָה", distractors: ["קֶנְיָה", "נִיגֶרְיָה", "מִצְרַיִם"], tier: .hard, grades: 5...6),

        // ── קָשֶׁה · עָרֵי בִּירָה מַפְתִּיעוֹת ──
        BankQuestion(prompt: "🦘\nמַהִי בִּירַת אוֹסְטְרַלְיָה?", correctAnswer: "קַנְבֶּרָה", distractors: ["סִידְנִי", "מֶלְבּוּרְן", "פֶּרְת'"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🍁\nמַהִי בִּירַת קָנָדָה?", correctAnswer: "אוֹטָוָה", distractors: ["טוֹרוֹנְטוֹ", "וַנְקוּבֶר", "מוֹנְטְרֵיאוֹל"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🏙️\nמַהִי בִּירַת בְּרָזִיל?", correctAnswer: "בְּרָזִילְיָה", distractors: ["רִיּוֹ דֶה זָ'נֵירוֹ", "סָאוֹ פָּאוּלוֹ", "לִיסְבּוֹן"], tier: .hard, grades: 5...6),

        // ── קָשֶׁה · שִׂיאִים, שָׂפוֹת וּמַטְבְּעוֹת ──
        BankQuestion(prompt: "🌏\nמַהִי הַיַּבֶּשֶׁת הַקְּטַנָּה בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["אֵירוֹפָּה", "אַנְטַרְקְטִיקָה", "אַפְרִיקָה"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "⛪\nמַהִי הַמְּדִינָה הַקְּטַנָּה בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "וָתִיקָן", distractors: ["מוֹנָקוֹ", "מַלְטָה", "יִשְׂרָאֵל"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🧊\nאֵיזוֹ יַבֶּשֶׁת כִּמְעַט כֻּלָּהּ מְכֻסָּה בְּקֶרַח וְאֵין בָּהּ מְדִינוֹת?", correctAnswer: "אַנְטַרְקְטִיקָה", distractors: ["אוֹסְטְרַלְיָה", "אֵירוֹפָּה", "צְפוֹן אַמֶרִיקָה"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🗣️\nבְּאֵיזוֹ שָׂפָה מְדַבְּרִים בִּבְרָזִיל?", correctAnswer: "פּוֹרְטוּגֵזִית", distractors: ["סְפָרַדִּית", "צָרְפָתִית", "אִיטַלְקִית"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "💴\nמַהוּ הַמַּטְבֵּעַ שֶׁל יַפָּן?", correctAnswer: "יֶן", distractors: ["דּוֹלָר", "יוּאָן", "אֵירוֹ"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "💷\nמַהוּ הַמַּטְבֵּעַ שֶׁל בְּרִיטַנְיָה?", correctAnswer: "לִירָה שְׁטֶרְלִינְג", distractors: ["אֵירוֹ", "דּוֹלָר", "פְרַנְק"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇺🇸\nכַּמָּה פַּסִּים יֵשׁ בְּדֶגֶל אַרְצוֹת הַבְּרִית?", correctAnswer: "13", distractors: ["50", "10", "15"], tier: .hard, grades: 5...6),
    ]
}
