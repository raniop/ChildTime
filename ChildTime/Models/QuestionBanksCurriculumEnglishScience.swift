import Foundation

/// 🎓 אנגלית ומדעים לפי תוכנית משרד החינוך — bank items tagged with grade windows.
enum CurriculumEnglishScienceBank {

    // MARK: - אנגלית (לפי תוכנית הלימודים — מתחילים בכיתה ג׳)

    static let english: [BankQuestion] = [

        // כיתה ג׳ — צלילי אותיות ואוצר מילים בסיסי
        BankQuestion(prompt: "🔴\nאֵיךְ אוֹמְרִים אֶת הַצֶּבַע הַזֶּה בְּאַנְגְּלִית?", correctAnswer: "red", distractors: ["blue", "green", "yellow"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "🔵\nאֵיךְ אוֹמְרִים אֶת הַצֶּבַע הַזֶּה בְּאַנְגְּלִית?", correctAnswer: "blue", distractors: ["red", "green", "black"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "🟢\nאֵיךְ אוֹמְרִים אֶת הַצֶּבַע הַזֶּה בְּאַנְגְּלִית?", correctAnswer: "green", distractors: ["yellow", "blue", "orange"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "🐘\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "elephant", distractors: ["lion", "monkey", "bear"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "🦁\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "lion", distractors: ["tiger", "elephant", "dog"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "🐟\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "fish", distractors: ["frog", "bird", "cat"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "בְּאֵיזוֹ אוֹת מַתְחִילָה הַמִּלָּה dog?", correctAnswer: "D", distractors: ["B", "G", "O"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "בְּאֵיזוֹ אוֹת מַתְחִילָה הַמִּלָּה sun?", correctAnswer: "S", distractors: ["C", "N", "U"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "5️⃣\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר הַזֶּה בְּאַנְגְּלִית?", correctAnswer: "five", distractors: ["four", "six", "nine"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "3️⃣\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר הַזֶּה בְּאַנְגְּלִית?", correctAnswer: "three", distractors: ["two", "five", "eight"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים אַבָּא בְּאַנְגְּלִית?", correctAnswer: "father", distractors: ["mother", "brother", "sister"], tier: .easy, grades: 3...3),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים אִמָּא בְּאַנְגְּלִית?", correctAnswer: "mother", distractors: ["father", "sister", "teacher"], tier: .easy, grades: 3...3),

        // כיתה ד׳ — אוצר מילים יומיומי, בִּטּוּיִים, יחיד/רבים
        BankQuestion(prompt: "מָה הַפֵּרוּשׁ שֶׁל Good morning?", correctAnswer: "בֹּקֶר טוֹב", distractors: ["לַיְלָה טוֹב", "לְהִתְרָאוֹת", "תּוֹדָה רַבָּה"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "מָה הַפֵּרוּשׁ שֶׁל Thank you?", correctAnswer: "תּוֹדָה", distractors: ["בְּבַקָּשָׁה", "סְלִיחָה", "שָׁלוֹם"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל cat?", correctAnswer: "cats", distractors: ["cates", "caty", "catten"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל book?", correctAnswer: "books", distractors: ["bookes", "booky", "booken"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים מוֹרָה בְּאַנְגְּלִית?", correctAnswer: "teacher", distractors: ["student", "doctor", "driver"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים בֵּית סֵפֶר בְּאַנְגְּלִית?", correctAnswer: "school", distractors: ["park", "store", "house"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "🍞\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bread", distractors: ["cake", "cheese", "butter"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים גֶּשֶׁם בְּאַנְגְּלִית?", correctAnswer: "rain", distractors: ["snow", "wind", "cloud"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים שֶׁלֶג בְּאַנְגְּלִית?", correctAnswer: "snow", distractors: ["rain", "wind", "storm"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים אַף בְּאַנְגְּלִית?", correctAnswer: "nose", distractors: ["mouth", "hand", "eye"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "אֵיךְ אוֹמְרִים יָד בְּאַנְגְּלִית?", correctAnswer: "hand", distractors: ["foot", "head", "arm"], tier: .medium, grades: 4...4),
        BankQuestion(prompt: "✏️\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "pencil", distractors: ["pen", "paper", "eraser"], tier: .medium, grades: 4...4),

        // כיתה ה׳ — הֲבָנַת מִשְׁפָּטִים, מִלּוֹת שְׁאֵלָה, הֲפָכִים, כִּנּוּיֵי גּוּף
        BankQuestion(prompt: "The boy is eating an apple.\nמָה הַיֶּלֶד עוֹשֶׂה?", correctAnswer: "אוֹכֵל תַּפּוּחַ", distractors: ["שׁוֹתֶה מִיץ", "מְשַׂחֵק בְּכַדּוּר", "קוֹרֵא סֵפֶר"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "The girl is reading a book.\nמָה הַיַּלְדָּה עוֹשָׂה?", correctAnswer: "קוֹרֵאת סֵפֶר", distractors: ["כּוֹתֶבֶת מִכְתָּב", "אוֹכֶלֶת גְּלִידָה", "מְצַיֶּרֶת צִיּוּר"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "The dog is sleeping.\nמָה הַכֶּלֶב עוֹשֶׂה?", correctAnswer: "יָשֵׁן", distractors: ["אוֹכֵל", "רָץ", "נוֹבֵחַ"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "בְּאֵיזוֹ מִלָּה בְּאַנְגְּלִית שׁוֹאֲלִים אֵיפֹה?", correctAnswer: "Where", distractors: ["What", "Who", "When"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "מָה הַפֵּרוּשׁ שֶׁל הַמִּלָּה What?", correctAnswer: "מָה", distractors: ["מִי", "אֵיפֹה", "מָתַי"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "מָה הַפֵּרוּשׁ שֶׁל הַמִּלָּה Who?", correctAnswer: "מִי", distractors: ["מָה", "אֵיךְ", "לָמָּה"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל big בְּאַנְגְּלִית?", correctAnswer: "small", distractors: ["tall", "long", "wide"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל hot בְּאַנְגְּלִית?", correctAnswer: "cold", distractors: ["warm", "wet", "dry"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "מָה הַהֵפֶךְ שֶׁל day בְּאַנְגְּלִית?", correctAnswer: "night", distractors: ["morning", "noon", "evening"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "בְּאֵיזֶה כִּנּוּי גּוּף מִשְׁתַּמְּשִׁים כְּשֶׁמְּדַבְּרִים עַל יֶלֶד (דָּנִי)?", correctAnswer: "he", distractors: ["she", "it", "we"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "בְּאֵיזֶה כִּנּוּי גּוּף מִשְׁתַּמְּשִׁים כְּשֶׁמְּדַבְּרִים עַל יַלְדָּה (רוּת)?", correctAnswer: "she", distractors: ["he", "it", "they"], tier: .medium, grades: 5...5),
        BankQuestion(prompt: "בְּאֵיזֶה כִּנּוּי גּוּף מִשְׁתַּמְּשִׁים כְּשֶׁמְּדַבְּרִים עַל שֻׁלְחָן?", correctAnswer: "it", distractors: ["he", "she", "you"], tier: .medium, grades: 5...5),

        // כיתה ו׳ — זְמַנִּים, מִלּוֹת יַחַס, קְרִיאָה, רַבִּים יוֹצְאֵי דֹּפֶן
        BankQuestion(prompt: "בַּחֲרוּ אֶת הַצּוּרָה הַנְּכוֹנָה:\nEvery day Dan ___ to school.", correctAnswer: "walks", distractors: ["walking", "is walk", "walk"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בַּחֲרוּ אֶת הַצּוּרָה הַנְּכוֹנָה:\nLook! The baby ___ now.", correctAnswer: "is crying", distractors: ["cries", "cry", "crying"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בַּחֲרוּ אֶת הַצּוּרָה הַנְּכוֹנָה:\nShe ___ TV every evening.", correctAnswer: "watches", distractors: ["watching", "is watch", "watch"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בַּחֲרוּ אֶת הַצּוּרָה הַנְּכוֹנָה:\nRight now the children ___ in the park.", correctAnswer: "are playing", distractors: ["plays", "is playing", "played"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "הַסֵּפֶר מֻנָּח עַל הַשֻּׁלְחָן.\nThe book is ___ the table.", correctAnswer: "on", distractors: ["in", "under", "at"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "הֶחָתוּל מִתַּחַת לַמִּטָּה.\nThe cat is ___ the bed.", correctAnswer: "under", distractors: ["on", "in", "next"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "הַכַּדּוּר בְּתוֹךְ הַקֻּפְסָה.\nThe ball is ___ the box.", correctAnswer: "in", distractors: ["on", "under", "at"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל child?", correctAnswer: "children", distractors: ["childs", "childes", "childrens"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל foot?", correctAnswer: "feet", distractors: ["foots", "feets", "footes"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה צוּרַת הָרַבִּים שֶׁל mouse?", correctAnswer: "mice", distractors: ["mouses", "mices", "meese"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "Tom has a red bike. He rides it to school every day.\nבְּאֵיזֶה צֶבַע הָאוֹפַנַּיִם שֶׁל Tom?", correctAnswer: "אָדֹם", distractors: ["כָּחֹל", "יָרֹק", "צָהֹב"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "Anna lives in Haifa. She has two cats.\nכַּמָּה חֲתוּלִים יֵשׁ לְאַנָּה?", correctAnswer: "שְׁנַיִם", distractors: ["אֶחָד", "שְׁלוֹשָׁה", "אַרְבָּעָה"], tier: .hard, grades: 6...6),
    ]

    // MARK: - מדע וטכנולוגיה

    static let science: [BankQuestion] = [

        // כיתות א׳-ב׳ — חוּשִׁים, בַּעֲלֵי חַיִּים, צְמָחִים, עוֹנוֹת, יוֹם וְלַיְלָה
        BankQuestion(prompt: "בְּאֵיזֶה אֵבֶר בַּגּוּף אֲנַחְנוּ רוֹאִים?", correctAnswer: "עֵינַיִם", distractors: ["אָזְנַיִם", "אַף", "יָדַיִם"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "בְּאֵיזֶה חוּשׁ מִשְׁתַּמְּשִׁים בָּאָזְנַיִם?", correctAnswer: "שְׁמִיעָה", distractors: ["רְאִיָּה", "טַעַם", "רֵיחַ"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "מָה צָרִיךְ צֶמַח כְּדֵי לִגְדֹּל?", correctAnswer: "מַיִם, אוֹר וַאֲוִיר", distractors: ["רַק חֹשֶׁךְ", "רַק חוֹל", "סֻכָּר וּמֶלַח"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "אֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַכֶּלֶב?", correctAnswer: "כְּלַבְלַב", distractors: ["חֲתַלְתּוּל", "אֶפְרוֹחַ", "עֵגֶל"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "אֵיךְ קוֹרְאִים לַגּוּר שֶׁל הַתַּרְנְגֹלֶת?", correctAnswer: "אֶפְרוֹחַ", distractors: ["עֵגֶל", "גְּדִי", "כְּלַבְלַב"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "אֵיפֹה גָּרוֹת הַדְּבוֹרִים?", correctAnswer: "בְּכַוֶּרֶת", distractors: ["בִּמְאוּרָה", "בְּלוּל", "בְּאֻרְוָה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "מָה אוֹכֶלֶת הַפָּרָה?", correctAnswer: "עֵשֶׂב", distractors: ["בָּשָׂר", "דָּגִים", "חֲרָקִים"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "בְּאֵיזוֹ עוֹנָה יוֹרֵד הֲכִי הַרְבֵּה גֶּשֶׁם בְּיִשְׂרָאֵל?", correctAnswer: "חֹרֶף", distractors: ["קַיִץ", "אָבִיב", "סְתָו"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "מָתַי רוֹאִים אֶת הַכּוֹכָבִים בַּשָּׁמַיִם?", correctAnswer: "בַּלַּיְלָה", distractors: ["בַּצָּהֳרַיִם", "בַּבֹּקֶר", "אַחַר הַצָּהֳרַיִם"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "מֵאֵיפֹה בּוֹקֵעַ הָאֶפְרוֹחַ?", correctAnswer: "מִבֵּיצָה", distractors: ["מִזֶּרַע", "מִפֶּרַח", "מֵעָלֶה"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "אֵיזֶה חֵלֶק שֶׁל הַצֶּמַח נִמְצָא בְּתוֹךְ הָאֲדָמָה?", correctAnswer: "הַשֹּׁרֶשׁ", distractors: ["הֶעָלֶה", "הַפֶּרַח", "הַגִּבְעוֹל"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "מָה מֵאִיר וּמְחַמֵּם אֶת כַּדּוּר הָאָרֶץ בַּיּוֹם?", correctAnswer: "הַשֶּׁמֶשׁ", distractors: ["הַיָּרֵחַ", "הַכּוֹכָבִים", "הָעֲנָנִים"], tier: .easy, grades: 1...2),

        // כיתות ג׳-ד׳ — מַצְּבֵי צְבִירָה, מַחְזוֹר הַמַּיִם, גּוּף הָאָדָם, חֳמָרִים, שַׁרְשֶׁרֶת מָזוֹן
        BankQuestion(prompt: "קֶרַח הוּא מַיִם בְּמַצַּב צְבִירָה:", correctAnswer: "מוּצָק", distractors: ["נוֹזֵל", "גַּז", "אֵדִים"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "חָלָב הוּא חֹמֶר בְּמַצַּב צְבִירָה:", correctAnswer: "נוֹזֵל", distractors: ["מוּצָק", "גַּז", "אֲוִיר"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "כְּשֶׁמַּיִם רוֹתְחִים הֵם הוֹפְכִים לְ:", correctAnswer: "אֵדִים (גַּז)", distractors: ["קֶרַח", "מוּצָק", "שֶׁלֶג"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "מָה קוֹרֶה לְמֵי הַיָּם כְּשֶׁהַשֶּׁמֶשׁ מְחַמֶּמֶת אוֹתָם?", correctAnswer: "הֵם מִתְאַדִּים", distractors: ["הֵם קוֹפְאִים", "הֵם נֶעֱלָמִים לְתָמִיד", "הֵם הוֹפְכִים לְמֶלַח"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "מֵאֵיפֹה מַגִּיעַ הַגֶּשֶׁם?", correctAnswer: "מֵהָעֲנָנִים", distractors: ["מֵהַשֶּׁמֶשׁ", "מֵהַכּוֹכָבִים", "מֵהֶהָרִים"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "אֵיזֶה אֵבֶר מַזְרִים אֶת הַדָּם בַּגּוּף?", correctAnswer: "הַלֵּב", distractors: ["הָרֵאוֹת", "הַקֵּבָה", "הַמֹּחַ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "בְּאֵיזֶה אֵבֶר אֲנַחְנוּ נוֹשְׁמִים?", correctAnswer: "בָּרֵאוֹת", distractors: ["בַּלֵּב", "בַּכָּבֵד", "בַּקֵּבָה"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "מָה הַתַּפְקִיד שֶׁל הַשֶּׁלֶד בַּגּוּף?", correctAnswer: "לְהַחֲזִיק אֶת הַגּוּף וּלְהָגֵן עַל הָאֵבָרִים", distractors: ["לְעַכֵּל אֶת הָאֹכֶל", "לְהַזְרִים אֶת הַדָּם", "לִרְאוֹת בַּחֹשֶׁךְ"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "אֵיזֶה חֹמֶר הוּא שָׁקוּף?", correctAnswer: "זְכוּכִית", distractors: ["עֵץ", "בַּרְזֶל", "אֶבֶן"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "אֵיזֶה חֹמֶר נִמְשָׁךְ לְמַגְנֵט?", correctAnswer: "בַּרְזֶל", distractors: ["עֵץ", "פְּלַסְטִיק", "זְכוּכִית"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "מָה אוֹכֵל הָאַרְנָב בְּשַׁרְשֶׁרֶת הַמָּזוֹן?", correctAnswer: "צְמָחִים", distractors: ["חֲרָקִים", "דָּגִים", "בָּשָׂר"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "מִי נִמְצָא בִּתְחִלַּת שַׁרְשֶׁרֶת הַמָּזוֹן?", correctAnswer: "הַצְּמָחִים", distractors: ["הָאֲרָיוֹת", "הַנְּשָׁרִים", "בְּנֵי הָאָדָם"], tier: .medium, grades: 3...4),

        // כיתה ה׳ — אֶנֶרְגְּיָה, חַשְׁמַל, מַעֲרֶכֶת הַשֶּׁמֶשׁ, נְשִׁימָה וְדָם, מַעַרְכוֹת אֶקוֹלוֹגִיּוֹת
        BankQuestion(prompt: "אֵיזוֹ אֶנֶרְגְּיָה מְקַבֵּל כַּדּוּר הָאָרֶץ מֵהַשֶּׁמֶשׁ?", correctAnswer: "אֶנֶרְגְּיַת אוֹר וְחֹם", distractors: ["אֶנֶרְגְּיַת קוֹל", "אֶנֶרְגְּיַת רוּחַ", "אֶנֶרְגְּיָה מִבַּטֶּרְיוֹת"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "אֵיזֶה חֹמֶר מוֹלִיךְ חַשְׁמַל?", correctAnswer: "נְחֹשֶׁת", distractors: ["גּוּמִי", "פְּלַסְטִיק", "עֵץ"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "אֵיזֶה חֹמֶר הוּא מְבוֹדֵד חַשְׁמַל?", correctAnswer: "גּוּמִי", distractors: ["בַּרְזֶל", "נְחֹשֶׁת", "אֲלוּמִינְיוּם"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "כַּמָּה כּוֹכְבֵי לֶכֶת מַקִּיפִים אֶת הַשֶּׁמֶשׁ?", correctAnswer: "שְׁמוֹנָה", distractors: ["שִׁבְעָה", "תִּשְׁעָה", "עֲשָׂרָה"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "מָהוּ כּוֹכַב הַלֶּכֶת הַקָּרוֹב בְּיוֹתֵר לַשֶּׁמֶשׁ?", correctAnswer: "כּוֹכָב חַמָּה", distractors: ["נֹגַהּ", "מַאְדִּים", "צֶדֶק"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "אֵיזֶה כּוֹכַב לֶכֶת נִקְרָא הַכּוֹכָב הָאָדֹם?", correctAnswer: "מַאְדִּים", distractors: ["צֶדֶק", "שַׁבְּתַאי", "נֹגַהּ"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "אֵיזֶה גַּז הַגּוּף שֶׁלָּנוּ צָרִיךְ מֵהָאֲוִיר כְּדֵי לִחְיוֹת?", correctAnswer: "חַמְצָן", distractors: ["פַּחְמָן דּוּ־חַמְצָנִי", "מֵימָן", "חַנְקָן"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "אֵיזֶה גַּז אֲנַחְנוּ פּוֹלְטִים כְּשֶׁאֲנַחְנוּ נוֹשְׁפִים?", correctAnswer: "פַּחְמָן דּוּ־חַמְצָנִי", distractors: ["חַמְצָן", "מֵימָן", "הֶלְיוּם"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "מָה הַתַּפְקִיד שֶׁל הַדָּם בַּגּוּף?", correctAnswer: "לְהוֹבִיל חַמְצָן וּמָזוֹן לְכָל הַגּוּף", distractors: ["לְעַכֵּל אֶת הָאֹכֶל", "לִיצֹר אוֹר", "לְנַקּוֹת אֶת הָאֲוִיר"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "מַהִי מַעֲרֶכֶת אֶקוֹלוֹגִית?", correctAnswer: "בַּעֲלֵי חַיִּים וּצְמָחִים הַחַיִּים יַחַד בִּסְבִיבָתָם", distractors: ["קְבוּצַת אֲבָנִים בַּמִּדְבָּר", "מְכוֹנָה שֶׁמְּיַצֶּרֶת חַשְׁמַל", "סוּג שֶׁל מֶזֶג אֲוִיר"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "לְמָה מְשַׁמֶּשֶׁת אֶנֶרְגְּיַת הָרוּחַ בְּטוּרְבִּינוֹת?", correctAnswer: "לְהַפָּקַת חַשְׁמַל", distractors: ["לְחִמּוּם הַשֶּׁמֶשׁ", "לִיצִירַת גֶּשֶׁם", "לְהַקְפָּאַת מַיִם"], tier: .hard, grades: 5...5),
        BankQuestion(prompt: "מַדּוּעַ הַיָּרֵחַ מֵאִיר בַּלַּיְלָה?", correctAnswer: "הוּא מַחֲזִיר אֶת אוֹר הַשֶּׁמֶשׁ", distractors: ["הוּא בּוֹעֵר כְּמוֹ הַשֶּׁמֶשׁ", "הוּא מְיַצֵּר אוֹר מִשֶּׁלּוֹ", "הַכּוֹכָבִים מְאִירִים אוֹתוֹ"], tier: .hard, grades: 5...5),

        // כיתה ו׳ — פוֹטוֹסִינְתֶזָה, מְכוֹנוֹת פְּשׁוּטוֹת, אוֹר וְקוֹל, אֵיכוּת הַסְּבִיבָה, מִיקְרוֹאוֹרְגָנִיזְמִים
        BankQuestion(prompt: "מָה מְיַצֵּר הַצֶּמַח בְּתַהֲלִיךְ הַפּוֹטוֹסִינְתֶזָה?", correctAnswer: "סֻכָּר וְחַמְצָן", distractors: ["מֶלַח וּמַיִם", "רַק פַּחְמָן דּוּ־חַמְצָנִי", "אֲדָמָה חֲדָשָׁה"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה צָרִיךְ הַצֶּמַח כְּדֵי לְבַצֵּעַ פּוֹטוֹסִינְתֶזָה?", correctAnswer: "אוֹר, מַיִם וּפַחְמָן דּוּ־חַמְצָנִי", distractors: ["חֹשֶׁךְ מֻחְלָט", "רַק חַמְצָן", "מֶלַח וְסֻכָּר"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בְּאֵיזֶה חֵלֶק שֶׁל הַצֶּמַח מִתְרַחֶשֶׁת הַפּוֹטוֹסִינְתֶזָה בְּעִקָּר?", correctAnswer: "בֶּעָלִים", distractors: ["בַּשָּׁרָשִׁים", "בַּפְּרָחִים", "בַּזְּרָעִים"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בְּמָה עוֹזֵר לָנוּ הַמָּנוֹף?", correctAnswer: "לְהָרִים מַשָּׂא כָּבֵד בְּקַלּוּת", distractors: ["לְחַמֵּם מַיִם", "לִרְאוֹת לְמֵרָחוֹק", "לִשְׁמֹעַ טוֹב יוֹתֵר"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "לְמָה מְשַׁמֶּשֶׁת הַגַּלְגֶּלֶת?", correctAnswer: "לַהֲרָמַת חֲפָצִים בְּעֶזְרַת חֶבֶל", distractors: ["לִמְדִידַת טֶמְפֶּרָטוּרָה", "לִיצִירַת אוֹר", "לְקֵרוּר אֹכֶל"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה מָהִיר יוֹתֵר — הָאוֹר אוֹ הַקּוֹל?", correctAnswer: "הָאוֹר", distractors: ["הַקּוֹל", "שְׁנֵיהֶם בְּאוֹתָהּ מְהִירוּת", "תָּלוּי בְּמֶזֶג הָאֲוִיר"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מַדּוּעַ רוֹאִים בָּרָק לִפְנֵי שֶׁשּׁוֹמְעִים רַעַם?", correctAnswer: "כִּי הָאוֹר מָהִיר מֵהַקּוֹל", distractors: ["כִּי הָרַעַם נוֹצָר מְאֻחָר יוֹתֵר", "כִּי הַקּוֹל מָהִיר מֵהָאוֹר", "כִּי הַבָּרָק קָרוֹב יוֹתֵר"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "דֶּרֶךְ מָה עוֹבֵר הַקּוֹל הֲכִי מַהֵר?", correctAnswer: "דֶּרֶךְ חֳמָרִים מוּצָקִים", distractors: ["דֶּרֶךְ הָאֲוִיר", "דֶּרֶךְ רִיק (חָלָל)", "דֶּרֶךְ גַּז"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מַדּוּעַ חָשׁוּב לְמַחְזֵר?", correctAnswer: "כְּדֵי לְהַפְחִית זִהוּם וּפְסֹלֶת", distractors: ["כְּדֵי לְיַצֵּר יוֹתֵר פְּסֹלֶת", "כְּדֵי לְלַכְלֵךְ אֶת הַיָּם", "אֵין סִבָּה, זֶה רַק מִנְהָג"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "אֵיזֶה פַּח מְיֹעָד לְמִחְזוּר נְיָר בְּיִשְׂרָאֵל?", correctAnswer: "הַפַּח הַכָּחֹל", distractors: ["הַפַּח הַיָּרֹק", "הַפַּח הַכָּתֹם", "הַפַּח הָאָדֹם"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "בְּאֵיזֶה מַכְשִׁיר מִשְׁתַּמְּשִׁים כְּדֵי לִרְאוֹת חַיְדַּקִּים?", correctAnswer: "מִיקְרוֹסְקוֹפּ", distractors: ["מִשְׁקֶפֶת", "טֵלֶסְקוֹפּ", "זְכוּכִית מַגְדֶּלֶת"], tier: .hard, grades: 6...6),
        BankQuestion(prompt: "מָה גּוֹרֵם לַבָּצֵק שֶׁל הַלֶּחֶם לִתְפֹּחַ?", correctAnswer: "שְׁמָרִים", distractors: ["מֶלַח", "מַיִם קָרִים", "קֶמַח נוֹסָף"], tier: .hard, grades: 6...6),
    ]
}
