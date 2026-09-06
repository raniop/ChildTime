import Foundation

/// 🐾 עולם החיות — animals question pack for גן–ד׳ (grades 0...4). Timeless,
/// verified facts only: animals by continent and habitat, records, mammals /
/// birds / reptiles / fish / insects, what animals eat, baby-animal names,
/// animal sounds, animals of Israel, and simple counting. Grade-tagged like
/// every bank (compiler-enforced). Wording is always gentle — no gory nature.
enum QuestionBanksAnimals {
    static let animals: [BankQuestion] = [
        // ── קוֹלוֹת שֶׁל חַיּוֹת ──
        BankQuestion(prompt: "🐄\nאֵיזוֹ חַיָּה עוֹשָׂה \"מוּ\"?", correctAnswer: "פָּרָה", distractors: ["כֶּלֶב", "חָתוּל", "תַּרְנְגוֹל"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐱\nאֵיזוֹ חַיָּה עוֹשָׂה \"מְיָאוּ\"?", correctAnswer: "חָתוּל", distractors: ["כֶּלֶב", "פָּרָה", "סוּס"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐶\nאֵיזֶה קוֹל מַשְׁמִיעַ הַכֶּלֶב?", correctAnswer: "הַב־הַב", distractors: ["מוּ", "קוּקוּרִיקוּ", "מְיָאוּ"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐓\nאֵיזוֹ חַיָּה קוֹרֵאת \"קוּקוּרִיקוּ\" בַּבֹּקֶר?", correctAnswer: "תַּרְנְגוֹל", distractors: ["בַּרְוָז", "כֶּבֶשׂ", "עֵז"], tier: .easy, grades: 0...1),

        // ── גּוּרִים וְשֵׁמוֹת שֶׁל תִּינוֹקוֹת ──
        BankQuestion(prompt: "🐴\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַסּוּס?", correctAnswer: "סְיָח", distractors: ["גְּדִי", "טָלֶה", "עֵגֶל"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐄\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַפָּרָה?", correctAnswer: "עֵגֶל", distractors: ["סְיָח", "גְּדִי", "אֶפְרוֹחַ"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐥\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַתַּרְנְגֹלֶת?", correctAnswer: "אֶפְרוֹחַ", distractors: ["טָלֶה", "עֵגֶל", "גְּדִי"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐑\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַכִּבְשָׂה?", correctAnswer: "טָלֶה", distractors: ["גְּדִי", "עֵגֶל", "סְיָח"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐐\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הָעֵז?", correctAnswer: "גְּדִי", distractors: ["טָלֶה", "סְיָח", "עֵגֶל"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐶\nאֵיךְ קוֹרְאִים לַתִּינוֹק שֶׁל הַכֶּלֶב?", correctAnswer: "גּוּר", distractors: ["אֶפְרוֹחַ", "עֵגֶל", "טָלֶה"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐸\nאֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַצְּפַרְדֵּעַ, שֶׁחַי בַּמַּיִם וְיֵשׁ לוֹ זָנָב?", correctAnswer: "רֹאשָׁן", distractors: ["זַחַל", "אֶפְרוֹחַ", "גְּדִי"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦋\nמִי הוֹפֵךְ לְפַרְפַּר כְּשֶׁהוּא גָּדֵל?", correctAnswer: "זַחַל", distractors: ["רֹאשָׁן", "אֶפְרוֹחַ", "דָּג"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🍼\nמָה שׁוֹתִים גּוּרֵי הַיּוֹנְקִים, כְּמוֹ גּוּר כְּלָבִים אוֹ עֵגֶל, כְּשֶׁהֵם נוֹלָדִים?", correctAnswer: "חָלָב מֵאִמָּא", distractors: ["מַיִם", "מִיץ", "דְּבַשׁ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐦\nמָה בּוֹנָה הַצִּפּוֹר כְּדֵי לְהָטִיל בּוֹ בֵּיצִים?", correctAnswer: "קֵן", distractors: ["כַּוֶּרֶת", "מְאוּרָה", "אֻרְוָה"], tier: .easy, grades: 0...2),

        // ── סְפִירָה: רַגְלַיִם וּכְנָפַיִם ──
        BankQuestion(prompt: "🐕\nכַּמָּה רַגְלַיִם יֵשׁ לַכֶּלֶב?", correctAnswer: "4", distractors: ["2", "6", "8"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐜\nכַּמָּה רַגְלַיִם יֵשׁ לַנְּמָלָה?", correctAnswer: "6", distractors: ["4", "8", "10"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🦅\nכַּמָּה כְּנָפַיִם יֵשׁ לַצִּפּוֹר?", correctAnswer: "2", distractors: ["1", "4", "6"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🕷️\nכַּמָּה רַגְלַיִם יֵשׁ לָעַכָּבִישׁ?", correctAnswer: "8", distractors: ["6", "4", "10"], tier: .medium, grades: 1...3),

        // ── שִׂיאִים ──
        BankQuestion(prompt: "🐘\nמִי הַחַיָּה הַגְּדוֹלָה בְּיוֹתֵר שֶׁחַיָּה כַּיּוֹם עַל הַיַּבָּשָׁה?", correctAnswer: "הַפִּיל", distractors: ["הַסּוּס", "הַפָּרָה", "הַגָּמָל"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐋\nמִי הַחַיָּה הַגְּדוֹלָה בְּיוֹתֵר בָּעוֹלָם כֻּלּוֹ?", correctAnswer: "הַלִּוְיָתָן הַכָּחֹל", distractors: ["הַפִּיל", "הַכָּרִישׁ", "הַגִּ'ירָפָה"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦒\nמִי הַחַיָּה הַגְּבוֹהָה בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "הַגִּ'ירָפָה", distractors: ["הַפִּיל", "הַגָּמָל", "הַדֹּב"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐆\nמִי הַחַיָּה הַמְּהִירָה בְּיוֹתֵר עַל הַיַּבָּשָׁה?", correctAnswer: "הַבַּרְדְּלָס", distractors: ["הַסּוּס", "הָאַרְנָב", "הָאַרְיֵה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🦈\nמִי הַדָּג הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "כְּרִישׁ לִוְיָתָן", distractors: ["טוּנָה", "סַלְמוֹן", "דַּג זָהָב"], tier: .hard, grades: 3...5),

        // ── חֵלְקֵי גּוּף וְכִסּוּי ──
        BankQuestion(prompt: "🐫\nמָה יֵשׁ לַגָּמָל עַל הַגַּב?", correctAnswer: "דַּבֶּשֶׁת", distractors: ["קַרְנַיִם", "כְּנָפַיִם", "קַשְׂקַשִּׂים"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐘\nאֵיךְ קוֹרְאִים לָאַף הָאָרֹךְ שֶׁל הַפִּיל?", correctAnswer: "חֵדֶק", distractors: ["קֶרֶן", "דַּבֶּשֶׁת", "מַקּוֹר"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦏\nמָה יֵשׁ לַקַּרְנַף עַל הָאַף?", correctAnswer: "קֶרֶן", distractors: ["חֵדֶק", "מַקּוֹר", "דַּבֶּשֶׁת"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦓\nלְאֵיזוֹ חַיָּה יֵשׁ פַּסִּים שְׁחֹרִים וּלְבָנִים?", correctAnswer: "זֶבְּרָה", distractors: ["גִּ'ירָפָה", "פִּיל", "דֹּב"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐦\nמָה מְכַסֶּה אֶת הַגּוּף שֶׁל הַצִּפּוֹר?", correctAnswer: "נוֹצוֹת", distractors: ["קַשְׂקַשִּׂים", "פַּרְוָה", "קוֹצִים"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐍\nמָה מְכַסֶּה אֶת הַגּוּף שֶׁל הַנָּחָשׁ?", correctAnswer: "קַשְׂקַשִּׂים", distractors: ["נוֹצוֹת", "פַּרְוָה", "צֶמֶר"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nאֵיזוֹ חַיָּה נוֹשֵׂאת אֶת הַבַּיִת שֶׁלָּהּ עַל הַגַּב?", correctAnswer: "הַצָּב", distractors: ["הָאַרְנָב", "הַצְּפַרְדֵּעַ", "הַתּוּכִּי"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦘\nאֵיפֹה נוֹשֵׂאת אִמָּא קֶנְגּוּרוּ אֶת הַגּוּר שֶׁלָּהּ?", correctAnswer: "בְּכִיס עַל הַבֶּטֶן", distractors: ["עַל הַגַּב", "בַּפֶּה", "בַּזָּנָב"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐟\nבְּעֶזְרַת מָה נוֹשְׁמִים הַדָּגִים מִתַּחַת לַמַּיִם?", correctAnswer: "זִימִים", distractors: ["רֵאוֹת", "אַף", "סְנַפִּירִים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦒\nלָמָּה יֵשׁ לַגִּ'ירָפָה צַוָּאר אָרֹךְ?", correctAnswer: "כְּדֵי לְהַגִּיעַ לָעָלִים בְּרֹאשׁ הָעֵצִים", distractors: ["כְּדֵי לִשְׂחוֹת מַהֵר", "כְּדֵי לָעוּף", "כְּדֵי לַחְפֹּר בָּאֲדָמָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦎\nאֵיזוֹ חַיָּה מְשַׁנָּה אֶת הַצֶּבַע שֶׁל הָעוֹר שֶׁלָּהּ?", correctAnswer: "זִקִּית", distractors: ["צָב", "נָחָשׁ", "צְפַרְדֵּעַ"], tier: .medium, grades: 1...3),

        // ── קְבוּצוֹת: יוֹנְקִים, עוֹפוֹת, זוֹחֲלִים, דָּגִים, חֲרָקִים ──
        BankQuestion(prompt: "🐧\nאֵיזוֹ צִפּוֹר לֹא יוֹדַעַת לָעוּף, אֲבָל שׂוֹחָה מְצֻיָּן?", correctAnswer: "פִּינְגְּוִין", distractors: ["יוֹנָה", "נֶשֶׁר", "דְּרוֹר"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦜\nאֵיזוֹ צִפּוֹר יוֹדַעַת לְחַקּוֹת מִלִּים שֶׁל בְּנֵי אָדָם?", correctAnswer: "תּוּכִּי", distractors: ["יוֹנָה", "בַּרְוָז", "נֶשֶׁר"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐊\nלְאֵיזוֹ קְבוּצָה שַׁיָּכִים הַתַּנִּין, הַלְּטָאָה וְהַצָּב?", correctAnswer: "זוֹחֲלִים", distractors: ["יוֹנְקִים", "עוֹפוֹת", "דָּגִים"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐞\nלְאֵיזוֹ קְבוּצָה שַׁיָּכִים הַנְּמָלָה, הַדְּבוֹרָה וְהַפַּרְפַּר?", correctAnswer: "חֲרָקִים", distractors: ["זוֹחֲלִים", "עוֹפוֹת", "יוֹנְקִים"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐋\nהַלִּוְיָתָן חַי בַּיָּם, אֲבָל הוּא לֹא דָּג. לְאֵיזוֹ קְבוּצַת חַיּוֹת הוּא שַׁיָּךְ?", correctAnswer: "יוֹנְקִים", distractors: ["דָּגִים", "זוֹחֲלִים", "דּוּ־חַיִּים"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦇\nהָעֲטַלֵּף עָף, אֲבָל הוּא לֹא צִפּוֹר. לְאֵיזוֹ קְבוּצָה הוּא שַׁיָּךְ?", correctAnswer: "יוֹנְקִים", distractors: ["עוֹפוֹת", "חֲרָקִים", "זוֹחֲלִים"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐸\nהַצְּפַרְדֵּעַ חַיָּה גַּם בַּמַּיִם וְגַם עַל הַיַּבָּשָׁה. לְאֵיזוֹ קְבוּצָה הִיא שַׁיֶּכֶת?", correctAnswer: "דּוּ־חַיִּים", distractors: ["זוֹחֲלִים", "דָּגִים", "יוֹנְקִים"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦕\nאֵיזוֹ חַיָּה עֲנָקִית חַיְתָה לִפְנֵי מִילְיוֹנֵי שָׁנִים, וְהַיּוֹם רוֹאִים רַק אֶת הָעֲצָמוֹת שֶׁלָּהּ בַּמּוּזֵיאוֹן?", correctAnswer: "דִּינוֹזָאוּר", distractors: ["פִּיל", "גִּ'ירָפָה", "תַּנִּין"], tier: .easy, grades: 0...2),

        // ── מָה הַחַיּוֹת אוֹכְלוֹת וּמָה הֵן נוֹתְנוֹת לָנוּ ──
        BankQuestion(prompt: "🐄\nאֵיזוֹ חַיָּה נוֹתֶנֶת לָנוּ חָלָב?", correctAnswer: "פָּרָה", distractors: ["תַּרְנְגֹלֶת", "דְּבוֹרָה", "כֶּלֶב"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐔\nאֵיזוֹ חַיָּה מְטִילָה אֶת הַבֵּיצִים שֶׁאֲנַחְנוּ אוֹכְלִים?", correctAnswer: "תַּרְנְגֹלֶת", distractors: ["פָּרָה", "כִּבְשָׂה", "סוּס"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐝\nאֵיזוֹ חַיָּה מְכִינָה דְּבַשׁ?", correctAnswer: "דְּבוֹרָה", distractors: ["פַּרְפַּר", "נְמָלָה", "זְבוּב"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐝\nמָה אוֹסֶפֶת הַדְּבוֹרָה מֵהַפְּרָחִים?", correctAnswer: "צוּף", distractors: ["מַיִם", "עָלִים", "זְרָעִים"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐼\nמָה אוֹכֶלֶת הַפַּנְדָּה הַגְּדוֹלָה כִּמְעַט כָּל הַיּוֹם?", correctAnswer: "בַּמְבּוּק", distractors: ["דָּגִים", "דְּבַשׁ", "גֶּזֶר"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌿\nאֵיךְ קוֹרְאִים לְחַיָּה שֶׁאוֹכֶלֶת רַק צְמָחִים?", correctAnswer: "צִמְחוֹנִית", distractors: ["טוֹרֶפֶת", "אוֹכֶלֶת־כֹּל", "מְעוֹפֶפֶת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦁\nהָאַרְיֵה אוֹכֵל בָּשָׂר. אֵיךְ קוֹרְאִים לְחַיָּה שֶׁאוֹכֶלֶת בָּשָׂר?", correctAnswer: "טוֹרֶפֶת", distractors: ["צִמְחוֹנִית", "זוֹחֶלֶת", "מְעוֹפֶפֶת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐻\nהַדֹּב אוֹכֵל גַּם דָּגִים וְגַם פֵּרוֹת וּדְבַשׁ. אֵיךְ קוֹרְאִים לְחַיָּה שֶׁאוֹכֶלֶת גַּם צְמָחִים וְגַם בָּשָׂר?", correctAnswer: "אוֹכֶלֶת־כֹּל", distractors: ["צִמְחוֹנִית", "טוֹרֶפֶת", "מְעוֹפֶפֶת"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🐝\nלָמָּה הַדְּבוֹרִים חֲשׁוּבוֹת לַצְּמָחִים?", correctAnswer: "הֵן מַאֲבִיקוֹת אֶת הַפְּרָחִים וְעוֹזְרוֹת לַפֵּרוֹת לִגְדֹּל", distractors: ["הֵן מַשְׁקוֹת אוֹתָם", "הֵן שָׁרוֹת לָהֶם", "הֵן חוֹפְרוֹת לָהֶם בּוֹרוֹת"], tier: .hard, grades: 3...6),

        // ── בֵּית גִּדּוּל וְעוֹנוֹת ──
        BankQuestion(prompt: "🐪\nאֵיזוֹ חַיָּה יְכוֹלָה לָלֶכֶת בַּמִּדְבָּר יָמִים רַבִּים בְּלִי לִשְׁתּוֹת?", correctAnswer: "הַגָּמָל", distractors: ["הַפָּרָה", "הַחֲזִיר", "הַצְּפַרְדֵּעַ"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐻\nמָה עוֹשֶׂה הַדֹּב הַחוּם בַּחֹרֶף?", correctAnswer: "יָשֵׁן שֵׁנַת חֹרֶף", distractors: ["עָף לְאַפְרִיקָה", "שׂוֹחֶה בַּיָּם", "מַחֲלִיף צֶבַע"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦢\nלָמָּה צִפֳּרִים רַבּוֹת עָפוֹת דָּרוֹמָה בַּסְּתָו?", correctAnswer: "כְּדֵי לְהַגִּיעַ לְמָקוֹם חַם עִם הַרְבֵּה אֹכֶל", distractors: ["כְּדֵי לִלְמֹד לָעוּף", "כִּי הֵן אוֹהֲבוֹת שֶׁלֶג", "כְּדֵי לִשְׂחוֹת בַּיָּם"], tier: .medium, grades: 2...4),

        // ── חַיּוֹת לְפִי יַבָּשׁוֹת ──
        BankQuestion(prompt: "🐨\nבְּאֵיזוֹ יַבֶּשֶׁת חַיִּים הַקּוֹאָלָה וְהַקֶּנְגּוּרוּ?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["אֵירוֹפָּה", "אָסְיָה", "אַפְרִיקָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦁\nבְּאֵיזוֹ יַבֶּשֶׁת חַיִּים רֹב הָאֲרָיוֹת בַּטֶּבַע?", correctAnswer: "אַפְרִיקָה", distractors: ["אֵירוֹפָּה", "אוֹסְטְרַלְיָה", "אַנְטַרְקְטִיקָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐼\nבְּאֵיזוֹ מְדִינָה חַיָּה הַפַּנְדָּה הַגְּדוֹלָה בַּטֶּבַע?", correctAnswer: "סִין", distractors: ["בְּרָזִיל", "מִצְרַיִם", "קָנָדָה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐧\nבְּאֵיזוֹ יַבֶּשֶׁת קְפוּאָה חַיִּים הַפִּינְגְּוִינִים הַקֵּיסָרִיִּים?", correctAnswer: "אַנְטַרְקְטִיקָה", distractors: ["אַפְרִיקָה", "אֵירוֹפָּה", "אָסְיָה"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐯\nבְּאֵיזוֹ יַבֶּשֶׁת חַיִּים טִיגְרִיסִים בַּטֶּבַע?", correctAnswer: "אָסְיָה", distractors: ["אַפְרִיקָה", "אֵירוֹפָּה", "דְּרוֹם אָמֵרִיקָה"], tier: .hard, grades: 3...5),

        // ── חַיּוֹת שֶׁל יִשְׂרָאֵל ──
        BankQuestion(prompt: "🐐\nאֵיזוֹ חַיָּה יִשְׂרְאֵלִית עִם קַרְנַיִם גְּדוֹלוֹת מְטַפֶּסֶת עַל הַצּוּקִים בְּעֵין גֶּדִי?", correctAnswer: "יָעֵל", distractors: ["פִּיל", "קֶנְגּוּרוּ", "פַּנְדָּה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🪨\nאֵיזוֹ חַיָּה קְטַנָּה וּפַרְוָתִית חַיָּה בֵּין הַסְּלָעִים בְּיִשְׂרָאֵל?", correctAnswer: "שְׁפַן סֶלַע", distractors: ["קוֹאָלָה", "פִּינְגְּוִין", "דֹּב קֹטֶב"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦌\nאֵיזוֹ חַיָּה מְהִירָה וַעֲדִינָה עִם קַרְנַיִם רָצָה בַּשָּׂדוֹת וּבַגְּבָעוֹת שֶׁל יִשְׂרָאֵל?", correctAnswer: "צְבִי", distractors: ["זֶבְּרָה", "קֶנְגּוּרוּ", "פַּנְדָּה"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦎\nאֵיזֶה זוֹחֵל קָטָן מְטַפֵּס עַל הַקִּירוֹת בַּבַּיִת בַּקַּיִץ וְאוֹכֵל יַתּוּשִׁים?", correctAnswer: "שְׂמָמִית", distractors: ["צָב", "תַּנִּין", "צְפַרְדֵּעַ"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦅\nאֵיזֶה עוֹף גָּדוֹל מְרַחֵף מֵעַל הַצּוּקִים בַּגּוֹלָן וּבַנֶּגֶב, וּבְיִשְׂרָאֵל שׁוֹמְרִים עָלָיו בִּמְיֻחָד?", correctAnswer: "נֶשֶׁר", distractors: ["יוֹנָה", "תַּרְנְגוֹל", "פִּינְגְּוִין"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🏞️\nאֵיזוֹ חַיָּה מוֹפִיעָה בַּסֵּמֶל שֶׁל רָשׁוּת הַטֶּבַע וְהַגַּנִּים בְּיִשְׂרָאֵל?", correctAnswer: "יָעֵל", distractors: ["אַרְיֵה", "פִּיל", "גָּמָל"], tier: .hard, grades: 3...5),

        // ── שְׁמִירָה עַל הַטֶּבַע וְחַיּוֹת בְּסַכָּנַת הַכְחָדָה ──
        BankQuestion(prompt: "🛡️\nאֵיךְ קוֹרְאִים לְחַיָּה שֶׁנִּשְׁאֲרוּ מִמֶּנָּה מְעַט מְאוֹד בָּעוֹלָם, וְצָרִיךְ לִשְׁמֹר עָלֶיהָ?", correctAnswer: "חַיָּה בְּסַכָּנַת הַכְחָדָה", distractors: ["חַיַּת מַחְמָד", "חַיַּת מֶשֶׁק", "חַיָּה מְעוֹפֶפֶת"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦤\nמָה זֶה \"הַכְחָדָה\"?", correctAnswer: "כְּשֶׁחַיָּה נֶעֱלֶמֶת לְגַמְרֵי מֵהָעוֹלָם", distractors: ["כְּשֶׁחַיָּה יְשֵׁנָה כָּל הַחֹרֶף", "כְּשֶׁחַיָּה עוֹבֶרֶת לְגַן חַיּוֹת", "כְּשֶׁחַיָּה מַחֲלִיפָה פַּרְוָה"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🌳\nלָמָּה חָשׁוּב לִשְׁמֹר עַל הַיְּעָרוֹת?", correctAnswer: "כִּי הֵם הַבַּיִת שֶׁל חַיּוֹת רַבּוֹת", distractors: ["כְּדֵי שֶׁיִּהְיֶה מָקוֹם לְעוֹד מְכוֹנִיּוֹת", "כִּי הַחַיּוֹת לֹא צְרִיכוֹת אוֹתָם", "כְּדֵי לִבְנוֹת בָּהֶם בִּנְיָנִים"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🏞️\nאֵיךְ קוֹרְאִים לְשֶׁטַח שֶׁשּׁוֹמְרִים בּוֹ עַל הַטֶּבַע וְעַל הַחַיּוֹת?", correctAnswer: "שְׁמוּרַת טֶבַע", distractors: ["חֲנוּת חַיּוֹת", "מִגְרַשׁ מִשְׂחָקִים", "קַנְיוֹן"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nמָה כָּל יֶלֶד יָכוֹל לַעֲשׂוֹת כְּדֵי לַעֲזֹר לְחַיּוֹת הַיָּם?", correctAnswer: "לֹא לִזְרֹק פְּלַסְטִיק לַיָּם", distractors: ["לְהַאֲכִיל דָּגִים בְּמַמְתַּקִּים", "לָשִׁיר לַיָּם", "לְצַיֵּר דָּגִים"], tier: .medium, grades: 1...3),
    ]
}
