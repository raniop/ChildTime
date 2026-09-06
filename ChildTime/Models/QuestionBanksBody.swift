import Foundation

/// 🧍 גּוּף הָאָדָם — human-body question bank for grades ב׳–ו׳. Bones, heart,
/// lungs, senses, teeth, brain, muscles, digestion, skin, sleep and healthy
/// habits. Facts are timeless textbook facts only; wording is gentle (no
/// illness or injury). Grade-tagged like every bank (compiler-enforced).
enum QuestionBanksBody {
    static let body: [BankQuestion] = [
        // ── קַל · אֵיבָרִים וְחוּשִׁים ──
        BankQuestion(prompt: "❤️\nאֵיזֶה אֵיבָר מַזְרִים אֶת הַדָּם בַּגּוּף?", correctAnswer: "הַלֵּב", distractors: ["הָרֵאוֹת", "הַמֹּחַ", "הַקֵּבָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫁\nבְּעֶזְרַת אֵילוּ אֵיבָרִים אֲנַחְנוּ נוֹשְׁמִים?", correctAnswer: "הָרֵאוֹת", distractors: ["הַלֵּב", "הַקֵּבָה", "הָעוֹר"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧠\nאֵיזֶה אֵיבָר עוֹזֵר לָנוּ לַחְשֹׁב וְלִזְכֹּר?", correctAnswer: "הַמֹּחַ", distractors: ["הַלֵּב", "הָרֵאוֹת", "הַכָּבֵד"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👀\nעִם אֵיזֶה אֵיבָר אֲנַחְנוּ רוֹאִים?", correctAnswer: "הָעֵינַיִם", distractors: ["הָאָזְנַיִם", "הָאַף", "הַפֶּה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👂\nעִם אֵיזֶה אֵיבָר אֲנַחְנוּ שׁוֹמְעִים?", correctAnswer: "הָאָזְנַיִם", distractors: ["הָעֵינַיִם", "הָאַף", "הַיָּדַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👃\nעִם אֵיזֶה אֵיבָר אֲנַחְנוּ מְרִיחִים?", correctAnswer: "הָאַף", distractors: ["הַפֶּה", "הָאָזְנַיִם", "הָעֵינַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👅\nעִם אֵיזֶה אֵיבָר אֲנַחְנוּ טוֹעֲמִים?", correctAnswer: "הַלָּשׁוֹן", distractors: ["הָאַף", "הַשִּׁנַּיִם", "הָאָזְנַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🤲\nעִם אֵיזֶה חוּשׁ מַרְגִּישִׁים שֶׁמַּשֶּׁהוּ חַם אוֹ קַר?", correctAnswer: "חוּשׁ הַמִּשּׁוּשׁ", distractors: ["חוּשׁ הָרְאִיָּה", "חוּשׁ הַשְּׁמִיעָה", "חוּשׁ הָרֵיחַ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🖐️\nכַּמָּה חוּשִׁים עִקָּרִיִּים נוֹהֲגִים לְלַמֵּד?", correctAnswer: "5", distractors: ["3", "4", "6"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✋\nכַּמָּה אֶצְבָּעוֹת יֵשׁ בִּשְׁתֵּי הַיָּדַיִם יַחַד?", correctAnswer: "10", distractors: ["5", "8", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦶\nכַּמָּה אֶצְבָּעוֹת יֵשׁ בְּכַף רֶגֶל אַחַת?", correctAnswer: "5", distractors: ["4", "6", "10"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦷\nמָה עוֹזֵר לָנוּ לִלְעֹס אֶת הָאֹכֶל?", correctAnswer: "הַשִּׁנַּיִם", distractors: ["הָאַף", "הָאָזְנַיִם", "הָעֵינַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👄\nדֶּרֶךְ אֵיזֶה אֵיבָר הָאֹכֶל נִכְנָס לַגּוּף?", correctAnswer: "הַפֶּה", distractors: ["הָאַף", "הָאֹזֶן", "הָעַיִן"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍎\nלְאָן מַגִּיעַ הָאֹכֶל אַחֲרֵי שֶׁבּוֹלְעִים אוֹתוֹ?", correctAnswer: "לַקֵּבָה", distractors: ["לָרֵאוֹת", "לַלֵּב", "לַמֹּחַ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💪\nמָה מַזִּיז אֶת הָעֲצָמוֹת שֶׁלָּנוּ?", correctAnswer: "הַשְּׁרִירִים", distractors: ["הַשֵּׂעָר", "הָעוֹר", "הַצִּפָּרְנַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦴\nאֵיךְ קוֹרְאִים לְכָל הָעֲצָמוֹת שֶׁל הַגּוּף יַחַד?", correctAnswer: "שֶׁלֶד", distractors: ["שְׁרִיר", "עוֹר", "לֵב"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧍\nאֵיזֶה אֵיבָר מְכַסֶּה אֶת כָּל הַגּוּף מִבַּחוּץ?", correctAnswer: "הָעוֹר", distractors: ["הַשֶּׁלֶד", "הַלֵּב", "הַמֹּחַ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫀\nאֵיפֹה נִמְצָא הַלֵּב?", correctAnswer: "בֶּחָזֶה", distractors: ["בָּרֹאשׁ", "בָּרֶגֶל", "בַּיָּד"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧠\nאֵיפֹה נִמְצָא הַמֹּחַ?", correctAnswer: "בָּרֹאשׁ", distractors: ["בַּבֶּטֶן", "בַּיָּד", "בָּרֶגֶל"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦴\nאֵיזוֹ עֶצֶם שׁוֹמֶרֶת עַל הַמֹּחַ?", correctAnswer: "הַגֻּלְגֹּלֶת", distractors: ["הַצֶּלַע", "עֶצֶם הַיָּרֵךְ", "עֶצֶם הַזְּרוֹעַ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🩸\nמָה זוֹרֵם בְּתוֹךְ הַגּוּף וּמֵבִיא חַמְצָן לְכָל מָקוֹם?", correctAnswer: "הַדָּם", distractors: ["הַמַּיִם", "הָאֲוִיר", "הֶחָלָב"], tier: .easy, grades: 2...3),

        // ── קַל · הֶרְגֵּלִים בְּרִיאִים ──
        BankQuestion(prompt: "🪥\nכַּמָּה פְּעָמִים כְּדַאי לְצַחְצֵחַ שִׁנַּיִם?", correctAnswer: "פַּעֲמַיִם בְּיוֹם", distractors: ["פַּעַם בְּשָׁבוּעַ", "פַּעַם בְּחֹדֶשׁ", "פַּעַם בְּשָׁנָה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦷\nמָה עוֹשִׂים עִם מִבְרֶשֶׁת שִׁנַּיִם וּמִשְׁחַת שִׁנַּיִם?", correctAnswer: "מְצַחְצְחִים שִׁנַּיִם", distractors: ["מְסָרְקִים שֵׂעָר", "שׁוֹטְפִים יָדַיִם", "מְנַקִּים נַעֲלַיִם"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧼\nמָה כְּדַאי לַעֲשׂוֹת לִפְנֵי שֶׁאוֹכְלִים?", correctAnswer: "לִשְׁטֹף יָדַיִם", distractors: ["לָרוּץ", "לִישֹׁן", "לָשִׁיר"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "☀️\nמָה מוֹרְחִים עַל הָעוֹר כְּדֵי לְהָגֵן עָלָיו מֵהַשֶּׁמֶשׁ?", correctAnswer: "קְרֶם הֲגָנָה", distractors: ["מַיִם", "שֶׁמֶן זַיִת", "דֶּבֶק"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🛌\nמָה עוֹשֶׂה הַגּוּף בַּלַּיְלָה כְּדֵי לָנוּחַ וּלְהִתְחַדֵּשׁ?", correctAnswer: "יָשֵׁן", distractors: ["רָץ", "אוֹכֵל", "קוֹפֵץ"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💧\nמָה כְּדַאי לִשְׁתּוֹת הַרְבֵּה כְּדֵי שֶׁהַגּוּף יִהְיֶה בָּרִיא?", correctAnswer: "מַיִם", distractors: ["שֶׁמֶן", "מִיץ מָתוֹק", "קָפֶה"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏃\nמָה עוֹזֵר לַשְּׁרִירִים לִהְיוֹת חֲזָקִים?", correctAnswer: "סְפּוֹרְט", distractors: ["מַמְתַּקִּים", "טֵלֵוִיזְיָה", "מִשְׂחֲקֵי מַחְשֵׁב"], tier: .easy, grades: 2...3),

        // ── בֵּינוֹנִי · עֲצָמוֹת וְשִׁנַּיִם ──
        BankQuestion(prompt: "🦴\nכַּמָּה עֲצָמוֹת יֵשׁ בַּגּוּף שֶׁל אָדָם מְבֻגָּר?", correctAnswer: "206", distractors: ["106", "306", "520"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nמַהִי הָעֶצֶם הָאֲרֻכָּה בְּיוֹתֵר בַּגּוּף?", correctAnswer: "עֶצֶם הַיָּרֵךְ", distractors: ["עֶצֶם הַזְּרוֹעַ", "הַצֶּלַע", "הַגֻּלְגֹּלֶת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nכַּמָּה צְלָעוֹת יֵשׁ לְאָדָם?", correctAnswer: "24", distractors: ["12", "20", "30"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nאֵיזֶה חֵלֶק בַּשֶּׁלֶד שׁוֹמֵר עַל הַלֵּב וְעַל הָרֵאוֹת?", correctAnswer: "הַצְּלָעוֹת", distractors: ["הַגֻּלְגֹּלֶת", "עֶצֶם הַיָּרֵךְ", "הָאֶצְבָּעוֹת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nאֵיךְ קוֹרְאִים לַמָּקוֹם שֶׁבּוֹ שְׁתֵּי עֲצָמוֹת נִפְגָּשׁוֹת וּמְאַפְשְׁרוֹת תְּנוּעָה?", correctAnswer: "מִפְרָק", distractors: ["שְׁרִיר", "גִּיד", "עוֹר"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦵\nהַבֶּרֶךְ הִיא דֻּגְמָה לְ…", correctAnswer: "מִפְרָק", distractors: ["שְׁרִיר", "אֵיבָר פְּנִימִי", "עֶצֶם אַחַת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nכַּמָּה שִׁנֵּי חָלָב יֵשׁ לְיֶלֶד?", correctAnswer: "20", distractors: ["10", "24", "32"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nכַּמָּה שִׁנַּיִם יֵשׁ לְאָדָם מְבֻגָּר, כּוֹלֵל שִׁנֵּי בִּינָה?", correctAnswer: "32", distractors: ["20", "28", "36"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nאֵיךְ קוֹרְאִים לַשִּׁנַּיִם הָרִאשׁוֹנוֹת, שֶׁנּוֹשְׁרוֹת וּבִמְקוֹמָן צוֹמְחוֹת שִׁנַּיִם קְבוּעוֹת?", correctAnswer: "שִׁנֵּי חָלָב", distractors: ["שִׁנֵּי בִּינָה", "שִׁנֵּי זָהָב", "שִׁנֵּי בַּרְזֶל"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · לֵב, דָּם וּנְשִׁימָה ──
        BankQuestion(prompt: "🫀\nהַלֵּב הוּא בְּעֶצֶם…", correctAnswer: "שְׁרִיר", distractors: ["עֶצֶם", "מִפְרָק", "בַּלּוּטָה"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "❤️\nמָה הַלֵּב מַזְרִים דֶּרֶךְ כְּלֵי הַדָּם?", correctAnswer: "דָּם", distractors: ["אֲוִיר", "מַיִם", "אֹכֶל"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nמָה מֵבִיא הַדָּם לְכָל תָּאֵי הַגּוּף?", correctAnswer: "חַמְצָן וְחָמְרֵי מָזוֹן", distractors: ["אוֹר", "קוֹל", "חוֹל"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nמָה נָכוֹן לְגַבֵּי הַדָּם שֶׁל בְּנֵי אָדָם?", correctAnswer: "יֵשׁ כַּמָּה סוּגֵי דָּם שׁוֹנִים", distractors: ["לְכֻלָּם אוֹתוֹ סוּג דָּם", "הַדָּם עָשׂוּי מִמַּיִם בִּלְבַד", "הַדָּם יָרֹק בְּתוֹךְ הַגּוּף"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nאֵיזֶה מֵהַשֵּׁמוֹת הָאֵלֶּה הוּא שֵׁם שֶׁל סוּג דָּם?", correctAnswer: "סוּג O", distractors: ["סוּג X", "סוּג Z", "סוּג Q"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🫁\nכַּמָּה רֵאוֹת יֵשׁ לְאָדָם?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🫁\nאֵיזֶה גַּז אֲנַחְנוּ שׁוֹאֲפִים מֵהָאֲוִיר, וְהַגּוּף צָרִיךְ אוֹתוֹ?", correctAnswer: "חַמְצָן", distractors: ["פַּחְמָן דּוּ־חַמְצָנִי", "הֶלְיוּם", "מֵימָן"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌬️\nאֵיזֶה גַּז הַגּוּף מוֹסִיף לָאֲוִיר שֶׁאֲנַחְנוּ נוֹשְׁפִים הַחוּצָה?", correctAnswer: "פַּחְמָן דּוּ־חַמְצָנִי", distractors: ["חַמְצָן", "הֶלְיוּם", "מֵימָן"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌡️\nמַהוּ חֹם הַגּוּף הַתַּקִּין שֶׁל אָדָם, בְּעֵרֶךְ?", correctAnswer: "37 מַעֲלוֹת", distractors: ["20 מַעֲלוֹת", "50 מַעֲלוֹת", "100 מַעֲלוֹת"], tier: .medium, grades: 3...5),

        // ── בֵּינוֹנִי · מֹחַ, חוּשִׁים וְעִכּוּל ──
        BankQuestion(prompt: "🧠\nדֶּרֶךְ מָה הַמֹּחַ שׁוֹלֵחַ הוֹדָעוֹת לְכָל הַגּוּף?", correctAnswer: "הָעֲצַבִּים", distractors: ["כְּלֵי הַדָּם", "הַשֵּׂעָר", "הָעֲצָמוֹת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🧍\nמַהוּ הָאֵיבָר הַגָּדוֹל בְּיוֹתֵר בַּגּוּף?", correctAnswer: "הָעוֹר", distractors: ["הַלֵּב", "הַמֹּחַ", "הַכָּבֵד"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "💪\nכַּמָּה שְׁרִירִים יֵשׁ בְּעֵרֶךְ בְּגוּף הָאָדָם?", correctAnswer: "כְּ־600", distractors: ["כְּ־6", "כְּ־60", "כְּ־60,000"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "👂\nחוּץ מִשְּׁמִיעָה, בְּמָה עוֹזֶרֶת הָאֹזֶן הַפְּנִימִית?", correctAnswer: "שְׁמִירָה עַל שִׁוּוּי מִשְׁקָל", distractors: ["רְאִיָּה בַּחֹשֶׁךְ", "טְעִימַת אֹכֶל", "עִכּוּל הָאֹכֶל"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "👅\nאֵיזֶה טַעַם הַלָּשׁוֹן מַרְגִּישָׁה כְּשֶׁאוֹכְלִים לִימוֹן?", correctAnswer: "חָמוּץ", distractors: ["מָתוֹק", "מָלוּחַ", "מַר"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍽️\nמָה קוֹרֶה לָאֹכֶל בַּקֵּבָה?", correctAnswer: "מִתְפָּרֵק לַחֲלָקִים קְטַנִּים", distractors: ["הוֹפֵךְ לְעֶצֶם", "נִשְׁאָר בְּדִיּוּק אוֹתוֹ דָּבָר", "עוֹלֶה לָרֵאוֹת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍽️\nאֵיךְ קוֹרְאִים לַתַּהֲלִיךְ שֶׁבּוֹ הַגּוּף מְפָרֵק אֶת הָאֹכֶל?", correctAnswer: "עִכּוּל", distractors: ["נְשִׁימָה", "שֵׁנָה", "צְמִיחָה"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🛌\nלָמָּה חָשׁוּב לִישֹׁן מַסְפִּיק?", correctAnswer: "הַגּוּף וְהַמֹּחַ נָחִים וּמִתְחַדְּשִׁים", distractors: ["הַשִּׁנַּיִם גְּדֵלוֹת רַק בַּלַּיְלָה", "הַשֵּׂעָר מִתְקַצֵּר", "הָעֵינַיִם מַחְלִיפוֹת צֶבַע"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "😴\nכַּמָּה שְׁעוֹת שֵׁנָה בְּעֵרֶךְ צָרִיךְ יֶלֶד בְּגִיל בֵּית סֵפֶר בְּכָל לַיְלָה?", correctAnswer: "כְּ־10 שָׁעוֹת", distractors: ["כְּ־2 שָׁעוֹת", "כְּ־5 שָׁעוֹת", "כְּ־16 שָׁעוֹת"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🧼\nלָמָּה שׁוֹטְפִים יָדַיִם עִם סַבּוֹן?", correctAnswer: "כְּדֵי לְהַרְחִיק חַיְדַּקִּים", distractors: ["כְּדֵי שֶׁהַיָּדַיִם יִגְדְּלוּ", "כְּדֵי לְחַמֵּם אֶת הַיָּדַיִם", "כְּדֵי לְשַׁנּוֹת אֶת צֶבַע הָעוֹר"], tier: .medium, grades: 3...5),

        // ── קָשֶׁה ──
        BankQuestion(prompt: "👂\nאֵיפֹה נִמְצֵאת הָעֶצֶם הַקְּטַנָּה בְּיוֹתֵר בַּגּוּף?", correctAnswer: "בָּאֹזֶן", distractors: ["בָּאֶצְבַּע", "בָּאַף", "בַּבֶּרֶךְ"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦴\nמָה מְיֻצָּר בְּתוֹךְ מַח הָעֶצֶם?", correctAnswer: "תָּאֵי דָּם", distractors: ["שִׁנַּיִם", "שֵׂעָר", "צִפָּרְנַיִם"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫀\nכַּמָּה חֲלָלִים (חֲדָרִים וַעֲלִיּוֹת) יֵשׁ בַּלֵּב?", correctAnswer: "4", distractors: ["1", "2", "6"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🩸\nאֵיךְ קוֹרְאִים לִכְלֵי הַדָּם שֶׁמּוֹלִיכִים דָּם מֵהַלֵּב אֶל הַגּוּף?", correctAnswer: "עוֹרְקִים", distractors: ["וְרִידִים", "עֲצַבִּים", "גִּידִים"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🩸\nמָה תַּפְקִידָם שֶׁל תָּאֵי הַדָּם הָאֲדֻמִּים?", correctAnswer: "לָשֵׂאת חַמְצָן", distractors: ["לְעַכֵּל אֹכֶל", "לִבְנוֹת עֲצָמוֹת", "לְיַצֵּר שֵׂעָר"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "💓\nמָה מוֹדְדִים כְּשֶׁמַּנִּיחִים אֶצְבַּע עַל פֶּרֶק כַּף הַיָּד וְסוֹפְרִים פְּעִימוֹת?", correctAnswer: "דֹּפֶק", distractors: ["חֹם", "גֹּבַהּ", "מִשְׁקָל"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫁\nאֵיךְ קוֹרְאִים לַשְּׁרִיר הַגָּדוֹל שֶׁמִּתַּחַת לָרֵאוֹת, שֶׁעוֹזֵר לָנוּ לִנְשֹׁם?", correctAnswer: "הַסַּרְעֶפֶת", distractors: ["שְׁרִיר הַזְּרוֹעַ", "שְׁרִיר הַלֵּב", "שְׁרִיר הַיָּרֵךְ"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦷\nמַהוּ הַחֹמֶר הַקָּשֶׁה בְּיוֹתֵר בְּגוּף הָאָדָם?", correctAnswer: "אֵמַיְל הַשִּׁנַּיִם", distractors: ["הָעֶצֶם", "הַצִּפֹּרֶן", "הַשֵּׂעָר"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧠\nאֵיזֶה חֵלֶק בַּמֹּחַ אַחְרַאי בְּעִקָּר עַל שִׁוּוּי מִשְׁקָל וְתֵאוּם תְּנוּעוֹת?", correctAnswer: "הַמֹּחַ הַקָּטָן", distractors: ["הַמֹּחַ הַגָּדוֹל", "גֶּזַע הַמֹּחַ", "חוּט הַשִּׁדְרָה"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦴\nעַל מָה שׁוֹמֵר עַמּוּד הַשִּׁדְרָה?", correctAnswer: "עַל חוּט הַשִּׁדְרָה", distractors: ["עַל הַקֵּבָה", "עַל הָעֵינַיִם", "עַל הַשִּׁנַּיִם"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫘\nאֵיזֶה אֵיבָר מְסַנֵּן אֶת הַדָּם וּמוֹצִיא מִמֶּנּוּ עֹדֶף מַיִם?", correctAnswer: "הַכְּלָיוֹת", distractors: ["הָרֵאוֹת", "הַלֵּב", "הַמֹּחַ"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🍽️\nבְּאֵיזֶה אֵיבָר נִסְפָּגִים רֹב חָמְרֵי הַמָּזוֹן אֶל הַדָּם?", correctAnswer: "הַמְּעִי הַדַּק", distractors: ["הַקֵּבָה", "הַפֶּה", "הָרֵאוֹת"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "👁️\nאֵיךְ קוֹרְאִים לַנְּקֻדָּה הַשְּׁחֹרָה בְּמֶרְכַּז הָעַיִן, שֶׁדַּרְכָּהּ נִכְנָס הָאוֹר?", correctAnswer: "אִישׁוֹן", distractors: ["קַשְׁתִּית", "רִיס", "גַּבָּה"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧍\nמַהוּ הָאֵיבָר הַפְּנִימִי הַגָּדוֹל בְּיוֹתֵר בַּגּוּף?", correctAnswer: "הַכָּבֵד", distractors: ["הַלֵּב", "הַמֹּחַ", "הַכִּלְיָה"], tier: .hard, grades: 4...6),
    ]
}
