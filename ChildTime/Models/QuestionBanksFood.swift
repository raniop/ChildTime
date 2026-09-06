import Foundation

/// 🍳 מִטְבָּח וּמַדָּע שֶׁל אֹכֶל — where food comes from, fruits vs vegetables,
/// food groups, kitchen measuring + recipe arithmetic, gentle kitchen safety,
/// and simple food science (boiling, melting, yeast, fermentation). Facts are
/// timeless; grades א׳–ה׳. Grade-tagged like every bank (compiler-enforced).
enum QuestionBanksFood {
    static let food: [BankQuestion] = [
        // ── קַל · מֵאֵיפֹה מַגִּיעַ הָאֹכֶל ──
        BankQuestion(prompt: "🐄\nמֵאֵיזוֹ חַיָּה מְקַבְּלִים חָלָב?", correctAnswer: "פָּרָה", distractors: ["תַּרְנְגֹלֶת", "דָּג", "פַּרְפַּר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥚\nאֵיזוֹ חַיָּה מְטִילָה אֶת הַבֵּיצִים שֶׁאֲנַחְנוּ אוֹכְלִים?", correctAnswer: "תַּרְנְגֹלֶת", distractors: ["פָּרָה", "כֶּלֶב", "חָתוּל"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍯\nמִי מֵכִין אֶת הַדְּבַשׁ?", correctAnswer: "הַדְּבוֹרִים", distractors: ["הַנְּמָלִים", "הַפַּרְפָּרִים", "הַצִּפּוֹרִים"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍞\nמִמָּה אוֹפִים לֶחֶם?", correctAnswer: "מִקֶּמַח", distractors: ["מֵחוֹל", "מִגְּבִינָה", "מִשּׁוֹקוֹלָד"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧀\nמִמָּה מְכִינִים גְּבִינָה?", correctAnswer: "מֵחָלָב", distractors: ["מִמַּיִם", "מִמִּיץ", "מִקֶּמַח"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍫\nמִמָּה מְכִינִים שׁוֹקוֹלָד?", correctAnswer: "מִפּוּלֵי קָקָאוֹ", distractors: ["מִתַּפּוּחִים", "מֵאֹרֶז", "מִגֶּזֶר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍇\nמֵאֵיזֶה פְּרִי מְכִינִים צִמּוּקִים?", correctAnswer: "מֵעֲנָבִים", distractors: ["מִתַּפּוּחִים", "מִבָּנָנוֹת", "מֵאֲבַטִּיחַ"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍟\nמֵאֵיזֶה יָרָק מְכִינִים צִ'יפְּס?", correctAnswer: "מִתַּפּוּחֵי אֲדָמָה", distractors: ["מִגֶּזֶר", "מֵעַגְבָנִיּוֹת", "מִבָּצָל"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍅\nמִמָּה מְכִינִים קֶטְשׁוֹפּ?", correctAnswer: "מֵעַגְבָנִיּוֹת", distractors: ["מִגֶּזֶר", "מִתַּפּוּחֵי אֲדָמָה", "מֵחַסָּה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🌳\nאֵיזֶה פְּרִי גָּדֵל עַל עֵץ?", correctAnswer: "תַּפּוּחַ", distractors: ["גֶּזֶר", "תַּפּוּחַ אֲדָמָה", "מְלָפְפוֹן"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥔\nאֵיזֶה יָרָק גָּדֵל מִתַּחַת לָאֲדָמָה?", correctAnswer: "תַּפּוּחַ אֲדָמָה", distractors: ["עַגְבָנִיָּה", "מְלָפְפוֹן", "חַסָּה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🫓\nאֵיךְ קוֹרְאִים לַלֶּחֶם הָעָגֹל שֶׁיֵּשׁ לוֹ כִּיס בְּתוֹכוֹ?", correctAnswer: "פִּתָּה", distractors: ["חַלָּה", "בָּגֶט", "קְרוּאָסוֹן"], tier: .easy, grades: 1...2),

        // ── קַל · פֵּרוֹת, יְרָקוֹת וּמָה כְּדַאי ──
        BankQuestion(prompt: "🍎\nתַּפּוּחַ הוּא…", correctAnswer: "פְּרִי", distractors: ["יָרָק", "גְּבִינָה", "לֶחֶם"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥕\nגֶּזֶר הוּא…", correctAnswer: "יָרָק", distractors: ["פְּרִי", "דָּג", "עוּגָה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍌\nאֵיזֶה צֶבַע יֵשׁ לְבָנָנָה בְּשֵׁלָה?", correctAnswer: "צָהֹב", distractors: ["כָּחֹל", "סָגֹל", "שָׁחֹר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍊\nאֵיזֶה צֶבַע יֵשׁ לְתַפּוּז?", correctAnswer: "כָּתֹם", distractors: ["כָּחֹל", "לָבָן", "וָרֹד"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍎\nמָה כְּדַאי לֶאֱכֹל בְּכָל יוֹם?", correctAnswer: "פֵּרוֹת וִירָקוֹת", distractors: ["סֻכָּרִיּוֹת", "שׁוֹקוֹלָד", "צִ'יפְּס"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "💧\nמָה הֲכִי טוֹב לִשְׁתּוֹת כְּשֶׁצְּמֵאִים?", correctAnswer: "מַיִם", distractors: ["שֶׁמֶן", "חֹמֶץ", "קֶטְשׁוֹפּ"], tier: .easy, grades: 1...2),

        // ── קַל · מַדָּע קָטָן וּבְטִיחוּת בַּמִּטְבָּח ──
        BankQuestion(prompt: "🧊\nמָה קוֹרֶה לְקֶרַח שֶׁמַּשְׁאִירִים בַּשֶּׁמֶשׁ?", correctAnswer: "הוּא נָמֵס", distractors: ["הוּא קוֹפֵא", "הוּא גָּדֵל", "הוּא נִהְיֶה כָּחֹל"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "💧\nמַיִם שֶׁשָּׂמִים בַּמַּקְפִּיא הוֹפְכִים לְ…", correctAnswer: "קֶרַח", distractors: ["אֵדִים", "מִיץ", "חָלָב"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧼\nמָה עוֹשִׂים לִפְנֵי שֶׁמַּתְחִילִים לְבַשֵּׁל?", correctAnswer: "שׁוֹטְפִים יָדַיִם", distractors: ["מְסָרְקִים שֵׂעָר", "נוֹעֲלִים נַעֲלַיִם", "מְכַבִּים אֶת הָאוֹר"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔥\nמִי צָרִיךְ לַעֲזֹר כְּשֶׁמִּשְׁתַּמְּשִׁים בַּתַּנּוּר הַחַם?", correctAnswer: "מְבֻגָּר", distractors: ["אָח קָטָן", "הַכֶּלֶב", "הַבֻּבָּה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍲\nאֵיךְ נוֹשְׂאִים צַלַּחַת עִם מָרָק חַם?", correctAnswer: "לְאַט וּבִזְהִירוּת", distractors: ["בְּרִיצָה", "בְּיָד אַחַת מֵעַל הָרֹאשׁ", "תּוֹךְ כְּדֵי קְפִיצָה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥄\nבְּמָה אוֹכְלִים מָרָק?", correctAnswer: "בְּכַף", distractors: ["בְּמַזְלֵג", "בְּסַכִּין", "בְּמִסְפָּרַיִם"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔪\nבְּמָה חוֹתְכִים לֶחֶם?", correctAnswer: "בְּסַכִּין", distractors: ["בְּכַף", "בְּמַזְלֵג", "בְּכוֹס"], tier: .easy, grades: 1...2),

        // ── קַל · חֶשְׁבּוֹן שֶׁל מַתְכּוֹנִים ──
        BankQuestion(prompt: "🧁\nלְכָל עוּגָה צָרִיךְ 2 בֵּיצִים. כַּמָּה בֵּיצִים צָרִיךְ לִשְׁתֵּי עוּגוֹת?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍪\nבַּמַּתְכּוֹן כָּתוּב 3 כַּפּוֹת סֻכָּר. שַׂמְנוּ כְּבָר כַּף אַחַת. כַּמָּה כַּפּוֹת עוֹד צָרִיךְ?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍕\nחָתַכְנוּ פִּיצָה לְ־8 מְשֻׁלָּשִׁים וְאָכַלְנוּ 3. כַּמָּה מְשֻׁלָּשִׁים נִשְׁאֲרוּ?", correctAnswer: "5", distractors: ["3", "4", "6"], tier: .easy, grades: 1...2),

        // ── בֵּינוֹנִי · מֵאֵיפֹה וְאֵיךְ ──
        BankQuestion(prompt: "🧆\nמִמָּה מְכִינִים פָלָאפֶל?", correctAnswer: "מֵחִמְצָה", distractors: ["מִבָּשָׂר", "מִגְּבִינָה", "מִתַּפּוּחֵי אֲדָמָה"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌱\nמִמָּה מְכִינִים טְחִינָה?", correctAnswer: "מִשֻּׁמְשְׁמִין", distractors: ["מֵאֱגוֹזִים", "מִבֹּטְנִים", "מֵחִטָּה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥛\nאֵיךְ הוֹפְכִים חָלָב לְיוֹגוּרְט?", correctAnswer: "מוֹסִיפִים חַיְדַּקִּים טוֹבִים", distractors: ["מַקְפִּיאִים אוֹתוֹ", "מוֹסִיפִים סֻכָּר", "מְסַנְּנִים אוֹתוֹ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍞\nמָה גּוֹרֵם לַבָּצֵק שֶׁל הַלֶּחֶם לִתְפֹּחַ?", correctAnswer: "שְׁמָרִים", distractors: ["מֶלַח", "מַיִם קָרִים", "אֲבָקַת קָקָאוֹ"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌾\nמֵאֵיזֶה צֶמַח מְכִינִים בְּדֶרֶךְ כְּלָל אֶת הַקֶּמַח לְלֶחֶם?", correctAnswer: "חִטָּה", distractors: ["כֻּתְנָה", "גֶּזֶר", "תַּפּוּז"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🍚\nאֵיפֹה מְגַדְּלִים סוּגִים רַבִּים שֶׁל אֹרֶז?", correctAnswer: "בְּשָׂדוֹת מוּצָפִים בְּמַיִם", distractors: ["עַל עֵצִים גְּבוֹהִים", "בְּתוֹךְ הַיָּם", "בַּמִּדְבָּר הַיָּבֵשׁ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍓\nאֵיפֹה גָּדֵל תּוּת שָׂדֶה?", correctAnswer: "עַל צֶמַח נָמוּךְ קָרוֹב לָאֲדָמָה", distractors: ["עַל עֵץ גָּבוֹהַּ", "מִתַּחַת לָאֲדָמָה", "בְּתוֹךְ הַמַּיִם"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥜\nאֵיפֹה גְּדֵלִים בֹּטְנִים?", correctAnswer: "מִתַּחַת לָאֲדָמָה", distractors: ["עַל עֵץ", "עַל גֶּפֶן", "בַּמַּיִם"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍇\nעַל מָה גְּדֵלִים עֲנָבִים?", correctAnswer: "עַל גֶּפֶן", distractors: ["עַל עֵץ תַּפּוּחַ", "עַל שִׂיחַ וְרָדִים", "עַל דֶּקֶל"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌴\nאֵיזֶה פְּרִי גָּדֵל עַל דֶּקֶל?", correctAnswer: "תָּמָר", distractors: ["תַּפּוּחַ", "אַגָּס", "דֻּבְדְּבָן"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🧂\nמֵאֵיפֹה מְקַבְּלִים מֶלַח?", correctAnswer: "מִמֵּי הַיָּם וּמִמִּכְרוֹת", distractors: ["מֵעֵצִים", "מִפָּרוֹת", "מִבֵּיצִים"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍯\nלָמָּה הַדְּבַשׁ מָתוֹק?", correctAnswer: "כִּי יֵשׁ בּוֹ הַרְבֵּה סֻכָּרִים טִבְעִיִּים", distractors: ["מוֹסִיפִים לוֹ סֻכָּר בַּמִּפְעָל", "הוּא עָשׂוּי מֵחָלָב", "הוּא גָּדֵל עַל עֵצִים"], tier: .medium, grades: 2...4),

        // ── בֵּינוֹנִי · קְבוּצוֹת מָזוֹן ──
        BankQuestion(prompt: "🥬\nאֵיזֶה מֵהָאֵלֶּה שַׁיָּךְ לִקְבוּצַת הַיְּרָקוֹת?", correctAnswer: "חַסָּה", distractors: ["לֶחֶם", "גְּבִינָה", "בֵּיצָה"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🥛\nחָלָב, גְּבִינָה וְיוֹגוּרְט שַׁיָּכִים לִקְבוּצַת…", correctAnswer: "מוּצְרֵי הֶחָלָב", distractors: ["הַפֵּרוֹת", "הַדְּגָנִים", "הַיְּרָקוֹת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🍞\nלֶחֶם, אֹרֶז וּפַסְטָה שַׁיָּכִים לִקְבוּצַת…", correctAnswer: "הַדְּגָנִים", distractors: ["הַפֵּרוֹת", "מוּצְרֵי הֶחָלָב", "הַיְּרָקוֹת"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · מְדִידָה וְחֶשְׁבּוֹן ──
        BankQuestion(prompt: "🥛\nכַּמָּה כּוֹסוֹת שֶׁל 250 מִ״ל יֵשׁ בְּלִיטֶר אֶחָד?", correctAnswer: "4", distractors: ["2", "3", "5"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "⚖️\nכַּמָּה גְּרָמִים יֵשׁ בְּקִילוֹגְרָם אֶחָד?", correctAnswer: "1,000", distractors: ["100", "10", "500"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥄\nבַּמַּתְכּוֹן כָּתוּב \"כַּפִּית\". אֵיזֶה כְּלִי לוֹקְחִים?", correctAnswer: "כַּף קְטַנָּה", distractors: ["כַּף גְּדוֹלָה", "כּוֹס", "מַצֶּקֶת"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🧁\nלְעוּגָה אַחַת צָרִיךְ 3 בֵּיצִים. כַּמָּה בֵּיצִים צָרִיךְ לְ־3 עוּגוֹת?", correctAnswer: "9", distractors: ["6", "3", "12"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥞\nמַתְכּוֹן דּוֹרֵשׁ 2 כּוֹסוֹת קֶמַח. מַכְפִּילִים אֶת הַמַּתְכּוֹן. כַּמָּה כּוֹסוֹת קֶמַח צָרִיךְ?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🍪\nמַתְכּוֹן דּוֹרֵשׁ 6 כַּפּוֹת סֻכָּר. מְכִינִים רַק חֲצִי מַתְכּוֹן. כַּמָּה כַּפּוֹת צָרִיךְ?", correctAnswer: "3", distractors: ["2", "4", "12"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "⏲️\nהָעוּגָה צְרִיכָה לְהֵאָפוֹת 40 דַּקּוֹת. הִכְנַסְנוּ אוֹתָהּ לַתַּנּוּר בְּ־4:00. מָתַי מוֹצִיאִים?", correctAnswer: "4:40", distractors: ["4:20", "4:30", "5:00"], tier: .medium, grades: 3...4),

        // ── בֵּינוֹנִי · מַדָּע בַּמִּטְבָּח ──
        BankQuestion(prompt: "🔥\nבְּאֵיזוֹ טֶמְפֶּרָטוּרָה מַיִם רוֹתְחִים?", correctAnswer: "100 מַעֲלוֹת צֶלְזְיוּס", distractors: ["10 מַעֲלוֹת צֶלְזְיוּס", "50 מַעֲלוֹת צֶלְזְיוּס", "200 מַעֲלוֹת צֶלְזְיוּס"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🧊\nבְּאֵיזוֹ טֶמְפֶּרָטוּרָה מַיִם הוֹפְכִים לְקֶרַח?", correctAnswer: "0 מַעֲלוֹת צֶלְזְיוּס", distractors: ["10 מַעֲלוֹת צֶלְזְיוּס", "50 מַעֲלוֹת צֶלְזְיוּס", "100 מַעֲלוֹת צֶלְזְיוּס"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "♨️\nאֵיךְ קוֹרְאִים לָאֵדִים שֶׁעוֹלִים מִסִּיר שֶׁל מַיִם רוֹתְחִים?", correctAnswer: "קִיטוֹר", distractors: ["עָשָׁן", "עָנָן", "שֶׁלֶג"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥚\nמָה קוֹרֶה לַחֶלְבּוֹן הַשָּׁקוּף כְּשֶׁמְּבַשְּׁלִים בֵּיצָה?", correctAnswer: "הוּא נִהְיֶה לָבָן וּמוּצָק", distractors: ["הוּא נֶעְלָם", "הוּא נִהְיֶה כָּחֹל", "הוּא הוֹפֵךְ לְמַיִם"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🍽️\nהָאֹכֶל בַּצַּלַּחַת חַם מִדַּי. מָה עוֹשִׂים לִפְנֵי שֶׁטּוֹעֲמִים?", correctAnswer: "מְחַכִּים שֶׁיִּתְקָרֵר קְצָת", distractors: ["אוֹכְלִים מַהֵר", "שָׂמִים אוֹתוֹ בַּמַּקְפִּיא לְשָׁעָה", "שׁוֹפְכִים עָלָיו מַיִם"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🧊\nלָמָּה שָׂמִים חָלָב בַּמְּקָרֵר?", correctAnswer: "כְּדֵי שֶׁיִּשָּׁאֵר טָרִי יוֹתֵר זְמַן", distractors: ["כְּדֵי שֶׁיִּהְיֶה מָתוֹק", "כְּדֵי שֶׁיַּהֲפֹךְ לְקֶרַח", "כְּדֵי שֶׁיִּהְיֶה חַם"], tier: .medium, grades: 2...3),

        // ── קָשֶׁה · מַדָּע שֶׁל אֹכֶל ──
        BankQuestion(prompt: "🫧\nאֵיזֶה גַּז יוֹצְרִים הַשְּׁמָרִים בַּבָּצֵק וְגוֹרֵם לוֹ לִתְפֹּחַ?", correctAnswer: "פַּחְמָן דּוּ־חַמְצָנִי", distractors: ["חַמְצָן", "הֶלְיוּם", "חַנְקָן"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🦠\nאֵיךְ קוֹרְאִים לַתַּהֲלִיךְ שֶׁבּוֹ חַיְדַּקִּים אוֹ שְׁמָרִים הוֹפְכִים חָלָב לְיוֹגוּרְט אוֹ בָּצֵק לְלֶחֶם תָּפוּחַ?", correctAnswer: "תְּסִיסָה", distractors: ["הַקְפָּאָה", "אִדּוּי", "טִגּוּן"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🥛\nאֵיךְ קוֹרְאִים לְחִמּוּם הֶחָלָב בַּמַּחְלָבָה, שֶׁשּׁוֹמֵר עָלָיו בָּטוּחַ לִשְׁתִיָּה?", correctAnswer: "פִּסְטוּר", distractors: ["טִגּוּן", "הַקְפָּאָה", "אֲפִיָּה"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "💨\nמַיִם רוֹתְחִים בַּסִּיר הַרְבֵּה זְמַן, וְהַסִּיר מִתְרוֹקֵן לְאַט. לְאָן נֶעֶלְמוּ הַמַּיִם?", correctAnswer: "הֵם הָפְכוּ לְאֵדִים", distractors: ["הַסִּיר סָפַג אוֹתָם", "הֵם הָפְכוּ לְמֶלַח", "הֵם קָפְאוּ"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🧊\nלָמָּה קֻבִּיַּת קֶרַח צָפָה עַל הַמַּיִם?", correctAnswer: "כִּי קֶרַח קַל יוֹתֵר מִמַּיִם בְּאוֹתוֹ נֶפַח", distractors: ["כִּי הוּא קַר", "כִּי הוּא לָבָן", "כִּי הוּא מַבְרִיק"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🍯\nלָמָּה דְּבַשׁ יָכוֹל לְהִשָּׁמֵר שָׁנִים רַבּוֹת בְּלִי לְהִתְקַלְקֵל?", correctAnswer: "כִּי יֵשׁ בּוֹ מְעַט מְאוֹד מַיִם וְהַרְבֵּה סֻכָּר", distractors: ["כִּי שׁוֹמְרִים אוֹתוֹ בַּמַּקְפִּיא", "כִּי מוֹסִיפִים לוֹ מֶלַח", "כִּי הַדְּבוֹרִים שׁוֹמְרוֹת עָלָיו"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🍫\nאֵיפֹה גְּדֵלִים עֲצֵי הַקָּקָאוֹ?", correctAnswer: "בַּאֲזוֹרִים חַמִּים וְלַחִים לְיַד קַו הַמַּשְׁוֶה", distractors: ["בַּקֹּטֶב הַצְּפוֹנִי", "בַּמִּדְבָּר", "בְּהָרִים מֻשְׁלָגִים"], tier: .hard, grades: 4...5),

        // ── קָשֶׁה · חֶלְקֵי הַצֶּמַח שֶׁאוֹכְלִים ──
        BankQuestion(prompt: "🍅\nעַגְבָנִיָּה צוֹמַחַת מִפֶּרַח וְיֵשׁ בָּהּ זְרָעִים. לָכֵן, מִבְּחִינָה מַדָּעִית, הִיא…", correctAnswer: "פְּרִי", distractors: ["שֹׁרֶשׁ", "עָלֶה", "גִּבְעוֹל"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🥕\nאֵיזֶה חֵלֶק שֶׁל הַצֶּמַח הוּא הַגֶּזֶר?", correctAnswer: "הַשֹּׁרֶשׁ", distractors: ["הֶעָלֶה", "הַפֶּרַח", "הַפְּרִי"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🥬\nאֵיזֶה חֵלֶק שֶׁל הַצֶּמַח אוֹכְלִים כְּשֶׁאוֹכְלִים חַסָּה?", correctAnswer: "הֶעָלִים", distractors: ["הַשֹּׁרֶשׁ", "הַפְּרִי", "הַזְּרָעִים"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🥦\nבְּרוֹקוֹלִי הוּא בְּעֶצֶם…", correctAnswer: "פְּרָחִים שֶׁעוֹד לֹא נִפְתְּחוּ", distractors: ["שֹׁרֶשׁ", "פְּרִי", "זֶרַע"], tier: .hard, grades: 4...5),

        // ── קָשֶׁה · חֶשְׁבּוֹן שֶׁל מַתְכּוֹנִים ──
        BankQuestion(prompt: "🍚\nמַתְכּוֹן לְ־4 אֲנָשִׁים דּוֹרֵשׁ 200 גְּרָם אֹרֶז. כַּמָּה גְּרָם צָרִיךְ לְ־8 אֲנָשִׁים?", correctAnswer: "400", distractors: ["200", "300", "800"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🥛\nמַתְכּוֹן דּוֹרֵשׁ לִיטֶר חָלָב (1,000 מִ״ל). מְכִינִים רַק רֶבַע מַתְכּוֹן. כַּמָּה מִ״ל חָלָב צָרִיךְ?", correctAnswer: "250", distractors: ["500", "100", "750"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "⏲️\nהָעוּגָה נֶאֱפֵית שָׁעָה וְ־15 דַּקּוֹת. הִכְנַסְנוּ אוֹתָהּ לַתַּנּוּר בְּ־3:30. מָתַי מוֹצִיאִים?", correctAnswer: "4:45", distractors: ["4:15", "4:30", "5:00"], tier: .hard, grades: 3...5),
    ]
}
