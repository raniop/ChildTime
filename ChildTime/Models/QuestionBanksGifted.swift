import Foundation

/// 🧠 הֲכָנָה לִמְחוֹנָנִים — reasoning puzzles in the spirit of the Israeli gifted
/// screening (שלב א׳/ב׳): number series, letter/shape patterns, analogies,
/// odd-one-out, single-answer logic riddles, verbal spatial reasoning (mirror,
/// quarter-turn rotation, folding), two-step word problems and counting puzzles.
/// Every answer is objectively checkable. Grades ב׳–ה׳, grade-tagged like every bank.
enum QuestionBanksGifted {
    static let gifted: [BankQuestion] = [
        // ── קַל · סִדְרוֹת מִסְפָּרִים ──
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 2, 4, 6, 8, ?", correctAnswer: "10", distractors: ["9", "11", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🖐️\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 5, 10, 15, 20, ?", correctAnswer: "25", distractors: ["21", "24", "30"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 3, 5, 7, ?", correctAnswer: "9", distractors: ["8", "10", "11"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "⬇️\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 10, 9, 8, 7, ?", correctAnswer: "6", distractors: ["5", "4", "11"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 3, 6, 9, 12, ?", correctAnswer: "15", distractors: ["13", "14", "16"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✨\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 2, 4, 8, ?", correctAnswer: "16", distractors: ["10", "12", "14"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💯\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 100, 90, 80, 70, ?", correctAnswer: "60", distractors: ["65", "50", "69"], tier: .easy, grades: 2...3),

        // ── קַל · אָנָלוֹגְיוֹת ──
        BankQuestion(prompt: "🧤\nיָד : כְּפָפָה כְּמוֹ רֶגֶל : ?", correctAnswer: "נַעַל", distractors: ["כּוֹבַע", "חֻלְצָה", "צָעִיף"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐦\nצִפּוֹר : שָׁמַיִם כְּמוֹ דָּג : ?", correctAnswer: "יָם", distractors: ["עֵץ", "מִדְבָּר", "הַר"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐄\nפָּרָה : חָלָב כְּמוֹ תַּרְנְגֹלֶת : ?", correctAnswer: "בֵּיצָה", distractors: ["צֶמֶר", "דְּבַשׁ", "גְּבִינָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐘\nגָּדוֹל : קָטָן כְּמוֹ חַם : ?", correctAnswer: "קַר", distractors: ["חָמִים", "רָטֹב", "גָּבוֹהַּ"], tier: .easy, grades: 2...3),

        // ── קַל · מִי לֹא שַׁיָּךְ ──
        BankQuestion(prompt: "🥕\nמִי לֹא שַׁיָּךְ לַקְּבוּצָה: תַּפּוּחַ, בָּנָנָה, גֶּזֶר, אַגָּס?", correctAnswer: "גֶּזֶר", distractors: ["תַּפּוּחַ", "בָּנָנָה", "אַגָּס"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎨\nמִי לֹא שַׁיָּךְ לַקְּבוּצָה: אָדֹם, כָּחֹל, עָגֹל, יָרֹק?", correctAnswer: "עָגֹל", distractors: ["אָדֹם", "כָּחֹל", "יָרֹק"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "📅\nמִי לֹא שַׁיָּךְ לַקְּבוּצָה: יוֹם רִאשׁוֹן, יוֹם שֵׁנִי, יָנוּאָר, יוֹם שְׁלִישִׁי?", correctAnswer: "יָנוּאָר", distractors: ["יוֹם רִאשׁוֹן", "יוֹם שֵׁנִי", "יוֹם שְׁלִישִׁי"], tier: .easy, grades: 2...3),

        // ── קַל · דְּפוּסִים שֶׁל אוֹתִיּוֹת וְצוּרוֹת ──
        BankQuestion(prompt: "🔤\nמָה הָאוֹת הַבָּאָה בַּסִּדְרָה: א, ב, ג, ד, ?", correctAnswer: "ה", distractors: ["ו", "ז", "ח"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔤\nמָה הָאוֹת הַבָּאָה בַּסִּדְרָה: א, ג, ה, ז, ?", correctAnswer: "ט", distractors: ["ח", "י", "כ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔵\nמָה הַצּוּרָה הַבָּאָה בַּסִּדְרָה: עִגּוּל, רִבּוּעַ, עִגּוּל, רִבּוּעַ, ?", correctAnswer: "עִגּוּל", distractors: ["רִבּוּעַ", "מְשֻׁלָּשׁ", "כּוֹכָב"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔴\nמָה הַצֶּבַע הַבָּא בַּסִּדְרָה: אָדֹם, אָדֹם, כָּחֹל, אָדֹם, אָדֹם, כָּחֹל, אָדֹם, ?", correctAnswer: "אָדֹם", distractors: ["כָּחֹל", "יָרֹק", "צָהֹב"], tier: .easy, grades: 2...3),

        // ── קַל · בְּעָיוֹת מִלּוּלִיּוֹת וּסְפִירָה ──
        BankQuestion(prompt: "🍎\nלְנֹעַם יֵשׁ 3 תַּפּוּחִים. הוּא נָתַן 1 לְחָבֵר וְקִבֵּל 2 מֵאִמָּא. כַּמָּה תַּפּוּחִים יֵשׁ לוֹ עַכְשָׁו?", correctAnswer: "4", distractors: ["3", "5", "6"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🚌\nבָּאוֹטוֹבּוּס הָיוּ 5 יְלָדִים. בַּתַּחֲנָה עָלוּ 3 וְיָרְדוּ 2. כַּמָּה יְלָדִים יֵשׁ עַכְשָׁו בָּאוֹטוֹבּוּס?", correctAnswer: "6", distractors: ["4", "5", "10"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍬\nלְדָנָה יֵשׁ 6 סֻכָּרִיּוֹת, וּלְיוֹסִי יֵשׁ 2 יוֹתֵר מִמֶּנָּה. כַּמָּה סֻכָּרִיּוֹת יֵשׁ לְיוֹסִי?", correctAnswer: "8", distractors: ["4", "6", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🕐\nהַשָּׁעָה עַכְשָׁו 3. מָה תִּהְיֶה הַשָּׁעָה בְּעוֹד 2 שָׁעוֹת?", correctAnswer: "5", distractors: ["1", "4", "6"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐔\nכַּמָּה רַגְלַיִם יֵשׁ לְ־3 תַּרְנְגוֹלוֹת בְּיַחַד?", correctAnswer: "6", distractors: ["3", "9", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐶\nכַּמָּה רַגְלַיִם יֵשׁ לְ־2 כְּלָבִים וְתַרְנְגֹלֶת אַחַת בְּיַחַד?", correctAnswer: "10", distractors: ["6", "8", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🪑\nבַּכִּתָּה 4 שֻׁלְחָנוֹת, וּלְיַד כָּל שֻׁלְחָן 2 כִּסְאוֹת. כַּמָּה כִּסְאוֹת יֵשׁ בַּכִּתָּה?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .easy, grades: 2...3),

        // ── בֵּינוֹנִי · סִדְרוֹת מִסְפָּרִים ──
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 4, 9, 16, ?", correctAnswer: "25", distractors: ["20", "24", "32"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 2, 3, 5, 8, 12, ?", correctAnswer: "17", distractors: ["15", "16", "18"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐚\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 1, 2, 3, 5, 8, ?", correctAnswer: "13", distractors: ["10", "11", "16"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 3, 6, 12, 24, ?", correctAnswer: "48", distractors: ["30", "36", "72"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 2, 4, 7, 11, ?", correctAnswer: "16", distractors: ["14", "15", "22"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · דְּפוּסִים שֶׁל אוֹתִיּוֹת וְצוּרוֹת ──
        BankQuestion(prompt: "🔤\nמָה הָאוֹת הַבָּאָה בַּסִּדְרָה: א, ד, ז, י, ?", correctAnswer: "מ", distractors: ["כ", "ל", "נ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔤\nמָה הָאוֹת הַבָּאָה בַּסִּדְרָה: ת, ש, ר, ק, ?", correctAnswer: "צ", distractors: ["פ", "ס", "ע"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔷\nמָה הַצּוּרָה הַבָּאָה בַּסִּדְרָה: מְשֻׁלָּשׁ, רִבּוּעַ, מְחֻמָּשׁ, ?", correctAnswer: "מְשֻׁשֶּׁה", distractors: ["עִגּוּל", "מְשֻׁלָּשׁ", "מַלְבֵּן"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · אָנָלוֹגְיוֹת ──
        BankQuestion(prompt: "📖\nסֵפֶר : קְרִיאָה כְּמוֹ עִפָּרוֹן : ?", correctAnswer: "כְּתִיבָה", distractors: ["שִׁירָה", "רִיצָה", "שְׁתִיָּה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "☀️\nחַם : קַיִץ כְּמוֹ קַר : ?", correctAnswer: "חֹרֶף", distractors: ["אָבִיב", "סְתָו", "לַיְלָה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🩺\nרוֹפֵא : בֵּית חוֹלִים כְּמוֹ מוֹרָה : ?", correctAnswer: "בֵּית סֵפֶר", distractors: ["סִפְרִיָּה", "חֲנוּת", "מִשְׂרָד"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · מִי לֹא שַׁיָּךְ ──
        BankQuestion(prompt: "🔢\nאֵיזֶה מִסְפָּר לֹא שַׁיָּךְ לַקְּבוּצָה: 3, 5, 7, 8, 11?", correctAnswer: "8", distractors: ["3", "7", "11"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥛\nמִי לֹא שַׁיָּךְ לַקְּבוּצָה: מַיִם, חָלָב, מִיץ, לֶחֶם?", correctAnswer: "לֶחֶם", distractors: ["מַיִם", "חָלָב", "מִיץ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍂\nמִי לֹא שַׁיָּךְ לַקְּבוּצָה: קַיִץ, חֹרֶף, סְתָו, יוּלִי?", correctAnswer: "יוּלִי", distractors: ["קַיִץ", "חֹרֶף", "סְתָו"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · חֲשִׁיבָה מֶרְחָבִית ──
        BankQuestion(prompt: "🪞\nאִילָן עוֹמֵד וּפָנָיו לַצָּפוֹן. הוּא מִסְתּוֹבֵב חֲצִי סִבּוּב. לְאָן פָּנָיו עַכְשָׁו?", correctAnswer: "לַדָּרוֹם", distractors: ["לַצָּפוֹן", "לַמִּזְרָח", "לַמַּעֲרָב"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔄\nחֵץ מַצְבִּיעַ לְמַעְלָה. מְסוֹבְבִים אוֹתוֹ רֶבַע סִבּוּב בְּכִוּוּן הַשָּׁעוֹן. לְאָן הוּא מַצְבִּיעַ עַכְשָׁו?", correctAnswer: "יָמִינָה", distractors: ["שְׂמֹאלָה", "לְמַטָּה", "לְמַעְלָה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔄\nחֵץ מַצְבִּיעַ יָמִינָה. מְסוֹבְבִים אוֹתוֹ חֲצִי סִבּוּב. לְאָן הוּא מַצְבִּיעַ עַכְשָׁו?", correctAnswer: "שְׂמֹאלָה", distractors: ["לְמַעְלָה", "לְמַטָּה", "יָמִינָה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📄\nמְקַפְּלִים דַּף נְיָר לִשְׁנַיִם, וְאָז שׁוּב לִשְׁנַיִם, וּפוֹתְחִים. לְכַמָּה חֲלָקִים שָׁוִים מְחֻלָּק הַדַּף?", correctAnswer: "4", distractors: ["2", "3", "8"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · חִידוֹת הִגָּיוֹן ──
        BankQuestion(prompt: "🧦\nבַּמְּגֵרָה 2 גַּרְבַּיִם אֲדֻמִּים וְ־2 גַּרְבַּיִם כְּחֻלִּים. כַּמָּה גַּרְבַּיִם צָרִיךְ לְהוֹצִיא בְּלִי לְהִסְתַּכֵּל כְּדֵי לִהְיוֹת בְּטוּחִים שֶׁיֵּשׁ זוּג בְּאוֹתוֹ צֶבַע?", correctAnswer: "3", distractors: ["1", "2", "4"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "⚖️\nמַה שׁוֹקֵל יוֹתֵר: קִילוֹ נוֹצוֹת אוֹ קִילוֹ בַּרְזֶל?", correctAnswer: "אוֹתוֹ הַמִּשְׁקָל", distractors: ["קִילוֹ בַּרְזֶל", "קִילוֹ נוֹצוֹת", "אִי אֶפְשָׁר לָדַעַת"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📅\nאִם מָחָר יוֹם רְבִיעִי, אֵיזֶה יוֹם הָיָה אֶתְמוֹל?", correctAnswer: "יוֹם שֵׁנִי", distractors: ["יוֹם שְׁלִישִׁי", "יוֹם חֲמִישִׁי", "יוֹם רִאשׁוֹן"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏃\nדָּנִי רָץ מַהֵר יוֹתֵר מִגִּיל, וְגִיל רָץ מַהֵר יוֹתֵר מֵרוֹן. מִי הֲכִי אִטִּי?", correctAnswer: "רוֹן", distractors: ["דָּנִי", "גִּיל", "אִי אֶפְשָׁר לָדַעַת"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐝\nמַה מְשֻׁתָּף לִנְמָלָה, דְּבוֹרָה וּזְבוּב?", correctAnswer: "כֻּלָּם חֲרָקִים", distractors: ["כֻּלָּם עוֹפוֹת", "כֻּלָּם דָּגִים", "כֻּלָּם יוֹנְקִים"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · בְּעָיוֹת מִלּוּלִיּוֹת וּסְפִירָה ──
        BankQuestion(prompt: "🏫\nבַּכִּתָּה 12 בָּנִים וְ־14 בָּנוֹת. 6 יְלָדִים הָלְכוּ לַסִּפְרִיָּה. כַּמָּה יְלָדִים נִשְׁאֲרוּ בַּכִּתָּה?", correctAnswer: "20", distractors: ["18", "22", "26"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "💰\nלְרוֹן יֵשׁ 20 שְׁקָלִים. הוּא קָנָה 2 מְחָקִים, כָּל מַחַק בְּ־3 שְׁקָלִים. כַּמָּה שְׁקָלִים נִשְׁאֲרוּ לוֹ?", correctAnswer: "14", distractors: ["12", "16", "17"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🎂\nדָּנָה בַּת 8, וְאָחִיהָ גָּדוֹל מִמֶּנָּה בְּ־3 שָׁנִים. כַּמָּה שָׁנִים הֵם בְּיַחַד?", correctAnswer: "19", distractors: ["11", "16", "21"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🚗\nבַּחֲנָיָה 3 מְכוֹנִיּוֹת וְ־4 אוֹפַנַּיִם. כַּמָּה גַּלְגַּלִּים יֵשׁ בְּסַךְ הַכֹּל?", correctAnswer: "20", distractors: ["14", "16", "24"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nכַּמָּה מִסְפָּרִים מִ־1 עַד 20 (כּוֹלֵל 20) מִתְחַלְּקִים בְּ־5 בְּלִי שְׁאֵרִית?", correctAnswer: "4", distractors: ["2", "3", "5"], tier: .medium, grades: 3...4),

        // ── קָשֶׁה · סִדְרוֹת מִסְפָּרִים וְאוֹתִיּוֹת ──
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 2, 5, 11, 23, ?", correctAnswer: "47", distractors: ["35", "45", "46"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 81, 27, 9, ?", correctAnswer: "3", distractors: ["0", "1", "6"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 2, 6, 24, ?", correctAnswer: "120", distractors: ["48", "96", "100"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔀\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 1, 10, 2, 20, 3, 30, 4, ?", correctAnswer: "40", distractors: ["5", "34", "50"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nמַה הַמִּסְפָּר הַבָּא בַּסִּדְרָה: 3, 4, 6, 9, 13, ?", correctAnswer: "18", distractors: ["16", "17", "20"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔤\nמָה הָאוֹת הַבָּאָה בַּסִּדְרָה: ב, ד, ו, ח, ?", correctAnswer: "י", distractors: ["ט", "כ", "ל"], tier: .hard, grades: 4...5),

        // ── קָשֶׁה · חֲשִׁיבָה מֶרְחָבִית ──
        BankQuestion(prompt: "🔄\nחֵץ מַצְבִּיעַ לְמַעְלָה. מְסוֹבְבִים אוֹתוֹ 3 רִבְעֵי סִבּוּב בְּכִוּוּן הַשָּׁעוֹן. לְאָן הוּא מַצְבִּיעַ עַכְשָׁו?", correctAnswer: "שְׂמֹאלָה", distractors: ["יָמִינָה", "לְמַטָּה", "לְמַעְלָה"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔄\nחֵץ מַצְבִּיעַ שְׂמֹאלָה. מְסוֹבְבִים אוֹתוֹ 5 רִבְעֵי סִבּוּב נֶגֶד כִּוּוּן הַשָּׁעוֹן. לְאָן הוּא מַצְבִּיעַ עַכְשָׁו?", correctAnswer: "לְמַטָּה", distractors: ["לְמַעְלָה", "יָמִינָה", "שְׂמֹאלָה"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📄\nמְקַפְּלִים דַּף לִשְׁנַיִם וְגוֹזְרִים מְשֻׁלָּשׁ קָטָן בְּאֶמְצַע קַו הַקִּפּוּל. כְּשֶׁפּוֹתְחִים אֶת הַדַּף, אֵיזוֹ צוּרָה יֵשׁ בְּאֶמְצָעוֹ?", correctAnswer: "חוֹר בְּצוּרַת מְעֻיָּן", distractors: ["חוֹר עָגֹל", "שְׁנֵי חוֹרִים", "בְּלִי חוֹר"], tier: .hard, grades: 4...5),

        // ── קָשֶׁה · חִידוֹת הִגָּיוֹן וּסְפִירָה ──
        BankQuestion(prompt: "👨‍👧‍👧\nלְאַבָּא יֵשׁ 3 בָּנוֹת, וּלְכָל בַּת יֵשׁ אָח אֶחָד. כַּמָּה יְלָדִים יֵשׁ לְאַבָּא?", correctAnswer: "4", distractors: ["3", "6", "7"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "7️⃣\nכַּמָּה פְּעָמִים מוֹפִיעָה הַסִּפְרָה 7 בַּמִּסְפָּרִים מִ־1 עַד 50?", correctAnswer: "5", distractors: ["4", "6", "10"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🤝\n4 יְלָדִים לוֹחֲצִים יָדַיִם, כָּל אֶחָד עִם כָּל אֶחָד פַּעַם אַחַת בְּדִיּוּק. כַּמָּה לְחִיצוֹת יָדַיִם יֵשׁ בְּסַךְ הַכֹּל?", correctAnswer: "6", distractors: ["4", "8", "12"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📏\nרוֹן גָּבוֹהַּ מִדָּן, דָּן נָמוּךְ מִגִּיל, וְגִיל נָמוּךְ מֵרוֹן. מִי הָאֶמְצָעִי בַּגֹּבַהּ?", correctAnswer: "גִּיל", distractors: ["רוֹן", "דָּן", "אִי אֶפְשָׁר לָדַעַת"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📅\nהַיּוֹם יוֹם שְׁלִישִׁי. אֵיזֶה יוֹם יִהְיֶה בְּעוֹד 10 יָמִים?", correctAnswer: "יוֹם שִׁשִּׁי", distractors: ["יוֹם רְבִיעִי", "יוֹם חֲמִישִׁי", "שַׁבָּת"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🐇\nבֶּחָצֵר יֵשׁ אַרְנָבִים וְתַרְנְגוֹלוֹת. סַךְ הַכֹּל 5 רָאשִׁים וְ־14 רַגְלַיִם. כַּמָּה אַרְנָבִים יֵשׁ בֶּחָצֵר?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .hard, grades: 4...5),

        // ── קָשֶׁה · בְּעָיוֹת מִלּוּלִיּוֹת בִּשְׁנֵי שְׁלַבִּים ──
        BankQuestion(prompt: "✏️\nבַּחֲנוּת 3 קֻפְסָאוֹת, וּבְכָל קֻפְסָה 8 עֶפְרוֹנוֹת. מְחַלְּקִים אֶת כָּל הָעֶפְרוֹנוֹת שָׁוֶה בְּשָׁוֶה בֵּין 4 יְלָדִים. כַּמָּה עֶפְרוֹנוֹת מְקַבֵּל כָּל יֶלֶד?", correctAnswer: "6", distractors: ["4", "8", "12"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🎂\nיוֹסִי בֶּן 10 וְאִמּוֹ בַּת 40. בְּעוֹד כַּמָּה שָׁנִים יִהְיֶה גִּיל אִמּוֹ פִּי 3 מִגִּילוֹ?", correctAnswer: "5", distractors: ["3", "4", "10"], tier: .hard, grades: 4...5),
    ]
}
