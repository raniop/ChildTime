import Foundation

/// Expanded question banks — adds ~300 new questions across all bank topics
/// so kids stop seeing the same questions twice in a session.
///
/// `QuestionBanks.bank(for:)` now returns the original + expanded together.
enum QuestionBanksExpanded {

    // MARK: - אנגלית (~80 extra)

    static let english: [BankQuestion] = [
        // Animals (more)
        BankQuestion(prompt: "🦓\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "zebra", distractors: ["horse", "cow", "donkey"]),
        BankQuestion(prompt: "🦒\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "giraffe", distractors: ["elephant", "horse", "camel"]),
        BankQuestion(prompt: "🐒\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "monkey", distractors: ["bear", "ape", "lion"]),
        BankQuestion(prompt: "🐻\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bear", distractors: ["wolf", "fox", "dog"]),
        BankQuestion(prompt: "🐺\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "wolf", distractors: ["dog", "fox", "bear"]),
        BankQuestion(prompt: "🐰\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "rabbit", distractors: ["mouse", "hamster", "fox"]),
        BankQuestion(prompt: "🐭\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "mouse", distractors: ["rabbit", "rat", "cat"]),
        BankQuestion(prompt: "🐢\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "turtle", distractors: ["snake", "frog", "fish"]),
        BankQuestion(prompt: "🐸\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "frog", distractors: ["fish", "turtle", "lizard"]),
        BankQuestion(prompt: "🦋\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "butterfly", distractors: ["bee", "bird", "fly"]),
        BankQuestion(prompt: "🐝\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "bee", distractors: ["fly", "ant", "butterfly"]),
        BankQuestion(prompt: "🦊\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "fox", distractors: ["wolf", "dog", "cat"]),
        BankQuestion(prompt: "🦄\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "unicorn", distractors: ["horse", "dragon", "pony"]),
        BankQuestion(prompt: "🐬\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "dolphin", distractors: ["whale", "fish", "shark"]),
        BankQuestion(prompt: "🦈\nאֵיךְ אוֹמְרִים אֶת זֶה בְּאַנְגְּלִית?", correctAnswer: "shark", distractors: ["whale", "fish", "dolphin"]),
        BankQuestion(prompt: "🐢\nאֵיךְ אוֹמְרִים 'אִיטִּי' בְּאַנְגְּלִית?", correctAnswer: "slow", distractors: ["fast", "small", "old"]),

        // Colors
        BankQuestion(prompt: "🔴\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "red", distractors: ["blue", "yellow", "pink"]),
        BankQuestion(prompt: "🔵\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "blue", distractors: ["red", "green", "purple"]),
        BankQuestion(prompt: "🟢\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "green", distractors: ["yellow", "blue", "brown"]),
        BankQuestion(prompt: "🟡\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "yellow", distractors: ["orange", "gold", "white"]),
        BankQuestion(prompt: "🟠\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "orange", distractors: ["yellow", "red", "brown"]),
        BankQuestion(prompt: "🟣\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "purple", distractors: ["pink", "blue", "violet"]),
        BankQuestion(prompt: "⚫\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "black", distractors: ["gray", "brown", "dark"]),
        BankQuestion(prompt: "⚪\nמַה הַצֶּבַע בְּאַנְגְּלִית?", correctAnswer: "white", distractors: ["gray", "silver", "light"]),

        // Numbers (Hebrew → English)
        BankQuestion(prompt: "1\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "one", distractors: ["two", "three", "four"]),
        BankQuestion(prompt: "2\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "two", distractors: ["three", "one", "five"]),
        BankQuestion(prompt: "3\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "three", distractors: ["thirteen", "two", "four"]),
        BankQuestion(prompt: "4\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "four", distractors: ["five", "fourteen", "fourty"]),
        BankQuestion(prompt: "5\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "five", distractors: ["four", "fifteen", "six"]),
        BankQuestion(prompt: "10\nאֵיךְ אוֹמְרִים אֶת הַמִּסְפָּר בְּאַנְגְּלִית?", correctAnswer: "ten", distractors: ["twenty", "tin", "eleven"]),

        // Family
        BankQuestion(prompt: "אַבָּא בְּאַנְגְּלִית?", correctAnswer: "father", distractors: ["mother", "brother", "sister"]),
        BankQuestion(prompt: "אִמָּא בְּאַנְגְּלִית?", correctAnswer: "mother", distractors: ["father", "sister", "aunt"]),
        BankQuestion(prompt: "אָח בְּאַנְגְּלִית?", correctAnswer: "brother", distractors: ["sister", "father", "uncle"]),
        BankQuestion(prompt: "אָחוֹת בְּאַנְגְּלִית?", correctAnswer: "sister", distractors: ["brother", "mother", "aunt"]),
        BankQuestion(prompt: "סָבָא בְּאַנְגְּלִית?", correctAnswer: "grandfather", distractors: ["father", "uncle", "grandson"]),
        BankQuestion(prompt: "סָבְתָא בְּאַנְגְּלִית?", correctAnswer: "grandmother", distractors: ["mother", "aunt", "granddaughter"]),

        // Common verbs
        BankQuestion(prompt: "לָרוּץ בְּאַנְגְּלִית?", correctAnswer: "run", distractors: ["jump", "walk", "swim"]),
        BankQuestion(prompt: "לִקְפֹּץ בְּאַנְגְּלִית?", correctAnswer: "jump", distractors: ["run", "fly", "climb"]),
        BankQuestion(prompt: "לֶאֱכֹל בְּאַנְגְּלִית?", correctAnswer: "eat", distractors: ["drink", "sleep", "cook"]),
        BankQuestion(prompt: "לִישֹׁן בְּאַנְגְּלִית?", correctAnswer: "sleep", distractors: ["eat", "play", "rest"]),
        BankQuestion(prompt: "לִקְרֹא בְּאַנְגְּלִית?", correctAnswer: "read", distractors: ["write", "look", "listen"]),
        BankQuestion(prompt: "לִכְתֹּב בְּאַנְגְּלִית?", correctAnswer: "write", distractors: ["read", "draw", "speak"]),
        BankQuestion(prompt: "לְשַׂחֵק בְּאַנְגְּלִית?", correctAnswer: "play", distractors: ["work", "study", "sleep"]),
        BankQuestion(prompt: "לִרְאוֹת בְּאַנְגְּלִית?", correctAnswer: "see", distractors: ["hear", "look", "watch"]),
        BankQuestion(prompt: "לִשְׁמֹעַ בְּאַנְגְּלִית?", correctAnswer: "hear", distractors: ["see", "say", "listen"]),
        BankQuestion(prompt: "לְדַבֵּר בְּאַנְגְּלִית?", correctAnswer: "speak", distractors: ["talk", "tell", "say"]),

        // Days & time
        BankQuestion(prompt: "יוֹם רִאשׁוֹן בְּאַנְגְּלִית?", correctAnswer: "Sunday", distractors: ["Monday", "Saturday", "Friday"]),
        BankQuestion(prompt: "יוֹם שֵׁנִי בְּאַנְגְּלִית?", correctAnswer: "Monday", distractors: ["Sunday", "Tuesday", "Friday"]),
        BankQuestion(prompt: "יוֹם שְׁלִישִׁי בְּאַנְגְּלִית?", correctAnswer: "Tuesday", distractors: ["Wednesday", "Monday", "Thursday"]),
        BankQuestion(prompt: "יוֹם רְבִיעִי בְּאַנְגְּלִית?", correctAnswer: "Wednesday", distractors: ["Tuesday", "Thursday", "Sunday"]),
        BankQuestion(prompt: "יוֹם חֲמִישִׁי בְּאַנְגְּלִית?", correctAnswer: "Thursday", distractors: ["Friday", "Wednesday", "Sunday"]),
        BankQuestion(prompt: "יוֹם שִׁשִּׁי בְּאַנְגְּלִית?", correctAnswer: "Friday", distractors: ["Saturday", "Thursday", "Sunday"]),
        BankQuestion(prompt: "שַׁבָּת בְּאַנְגְּלִית?", correctAnswer: "Saturday", distractors: ["Sunday", "Friday", "Sabbath"]),

        // Weather & nature
        BankQuestion(prompt: "🌧\nגֶּשֶׁם בְּאַנְגְּלִית?", correctAnswer: "rain", distractors: ["snow", "wind", "cloud"]),
        BankQuestion(prompt: "❄️\nשֶׁלֶג בְּאַנְגְּלִית?", correctAnswer: "snow", distractors: ["ice", "rain", "cold"]),
        BankQuestion(prompt: "🌬\nרוּחַ בְּאַנְגְּלִית?", correctAnswer: "wind", distractors: ["rain", "storm", "weather"]),
        BankQuestion(prompt: "☁️\nעָנָן בְּאַנְגְּלִית?", correctAnswer: "cloud", distractors: ["sky", "fog", "smoke"]),
        BankQuestion(prompt: "⛈\nסְעָרָה בְּאַנְגְּלִית?", correctAnswer: "storm", distractors: ["rain", "thunder", "wind"]),

        // Body parts
        BankQuestion(prompt: "רֹאשׁ בְּאַנְגְּלִית?", correctAnswer: "head", distractors: ["hand", "neck", "hair"]),
        BankQuestion(prompt: "אַף בְּאַנְגְּלִית?", correctAnswer: "nose", distractors: ["mouth", "ear", "eye"]),
        BankQuestion(prompt: "פֶּה בְּאַנְגְּלִית?", correctAnswer: "mouth", distractors: ["nose", "lip", "tongue"]),
        BankQuestion(prompt: "אֹזֶן בְּאַנְגְּלִית?", correctAnswer: "ear", distractors: ["eye", "nose", "head"]),
        BankQuestion(prompt: "רֶגֶל בְּאַנְגְּלִית?", correctAnswer: "leg", distractors: ["hand", "foot", "knee"]),
        BankQuestion(prompt: "כַּף יָד בְּאַנְגְּלִית?", correctAnswer: "hand", distractors: ["foot", "arm", "finger"]),

        // Food
        BankQuestion(prompt: "🧀\nגְּבִינָה בְּאַנְגְּלִית?", correctAnswer: "cheese", distractors: ["butter", "milk", "yogurt"]),
        BankQuestion(prompt: "🍕\nפִּיצָה בְּאַנְגְּלִית?", correctAnswer: "pizza", distractors: ["pasta", "bread", "burger"]),
        BankQuestion(prompt: "🍔\nהַמְבּוּרְגֶּר בְּאַנְגְּלִית?", correctAnswer: "burger", distractors: ["pizza", "hotdog", "fries"]),
        BankQuestion(prompt: "🍌\nבָּנָנָה בְּאַנְגְּלִית?", correctAnswer: "banana", distractors: ["apple", "lemon", "mango"]),
        BankQuestion(prompt: "🍊\nתַּפּוּז בְּאַנְגְּלִית?", correctAnswer: "orange", distractors: ["lemon", "apple", "fruit"]),
        BankQuestion(prompt: "🍓\nתּוּת בְּאַנְגְּלִית?", correctAnswer: "strawberry", distractors: ["raspberry", "cherry", "apple"]),
        BankQuestion(prompt: "🍉\nאֲבַטִּיחַ בְּאַנְגְּלִית?", correctAnswer: "watermelon", distractors: ["melon", "pumpkin", "apple"]),
        BankQuestion(prompt: "🍇\nעֲנָבִים בְּאַנְגְּלִית?", correctAnswer: "grapes", distractors: ["berries", "cherry", "plum"]),

        // School
        BankQuestion(prompt: "מוֹרֶה בְּאַנְגְּלִית?", correctAnswer: "teacher", distractors: ["student", "doctor", "parent"]),
        BankQuestion(prompt: "תַּלְמִיד בְּאַנְגְּלִית?", correctAnswer: "student", distractors: ["teacher", "kid", "child"]),
        BankQuestion(prompt: "בֵּית סֵפֶר בְּאַנְגְּלִית?", correctAnswer: "school", distractors: ["college", "class", "home"]),
        BankQuestion(prompt: "כִּתָּה בְּאַנְגְּלִית?", correctAnswer: "class", distractors: ["school", "room", "lesson"]),
        BankQuestion(prompt: "עִפָּרוֹן בְּאַנְגְּלִית?", correctAnswer: "pencil", distractors: ["pen", "paper", "eraser"]),
        BankQuestion(prompt: "עֵט בְּאַנְגְּלִית?", correctAnswer: "pen", distractors: ["pencil", "marker", "ink"]),

        // Reverse direction
        BankQuestion(prompt: "What does 'dog' mean?", correctAnswer: "כֶּלֶב", distractors: ["חָתוּל", "אַרְנָב", "סוּס"]),
        BankQuestion(prompt: "What does 'cat' mean?", correctAnswer: "חָתוּל", distractors: ["כֶּלֶב", "אַרְיֵה", "נָמֵר"]),
        BankQuestion(prompt: "What does 'house' mean?", correctAnswer: "בַּיִת", distractors: ["דִּירָה", "וִילָה", "חֶדֶר"]),
        BankQuestion(prompt: "What does 'star' mean?", correctAnswer: "כּוֹכָב", distractors: ["שֶׁמֶשׁ", "יָרֵחַ", "עָנָן"]),
        BankQuestion(prompt: "What does 'water' mean?", correctAnswer: "מַיִם", distractors: ["חָלָב", "מִיץ", "תֵּה"]),
        BankQuestion(prompt: "What does 'sun' mean?", correctAnswer: "שֶׁמֶשׁ", distractors: ["יָרֵחַ", "כּוֹכָב", "אוֹר"]),
        BankQuestion(prompt: "What does 'red' mean?", correctAnswer: "אָדֹם", distractors: ["כָּחֹל", "יָרֹק", "וָרֹד"]),
        BankQuestion(prompt: "What does 'happy' mean?", correctAnswer: "שָׂמֵחַ", distractors: ["עָצוּב", "כּוֹעֵס", "עָיֵף"]),
        BankQuestion(prompt: "What does 'big' mean?", correctAnswer: "גָּדוֹל", distractors: ["קָטָן", "אָרֹךְ", "רָחָב"]),
        BankQuestion(prompt: "What does 'small' mean?", correctAnswer: "קָטָן", distractors: ["גָּדוֹל", "צַר", "קָצָר"]),
        BankQuestion(prompt: "What does 'fast' mean?", correctAnswer: "מָהִיר", distractors: ["אִיטִּי", "חָזָק", "אָרֹךְ"]),
        BankQuestion(prompt: "What does 'cold' mean?", correctAnswer: "קַר", distractors: ["חַם", "עָרֵב", "סַגְרִיר"]),
        BankQuestion(prompt: "What does 'hot' mean?", correctAnswer: "חַם", distractors: ["קַר", "נָעִים", "סוֹעֵר"]),
    ]

    // MARK: - לוגיקה (~50 extra)

    static let logic: [BankQuestion] = [
        // Sequences
        BankQuestion(prompt: "2, 4, 6, 8, ?", correctAnswer: "10", distractors: ["9", "11", "12"]),
        BankQuestion(prompt: "5, 10, 15, 20, ?", correctAnswer: "25", distractors: ["22", "30", "24"]),
        BankQuestion(prompt: "1, 4, 9, 16, ?", correctAnswer: "25", distractors: ["20", "24", "30"]),
        BankQuestion(prompt: "1, 1, 2, 3, 5, ?", correctAnswer: "8", distractors: ["6", "7", "10"]),
        BankQuestion(prompt: "100, 90, 80, ?", correctAnswer: "70", distractors: ["75", "60", "85"]),
        BankQuestion(prompt: "1, 3, 5, 7, ?", correctAnswer: "9", distractors: ["8", "10", "11"]),
        BankQuestion(prompt: "10, 20, 40, 80, ?", correctAnswer: "160", distractors: ["100", "120", "200"]),
        BankQuestion(prompt: "A, C, E, G, ?", correctAnswer: "I", distractors: ["H", "J", "K"]),
        BankQuestion(prompt: "ב, ד, ו, ?", correctAnswer: "ח", distractors: ["ז", "ט", "י"]),
        BankQuestion(prompt: "🔴🔵🔴🔵🔴?", correctAnswer: "🔵", distractors: ["🔴", "🟢", "🟡"]),

        // Odd one out
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "כַּדּוּרְסַל", distractors: ["תַּפּוּחַ", "בָּנָנָה", "אַגָּס"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "שֻׁלְחָן", distractors: ["כֶּלֶב", "חָתוּל", "אַרְיֵה"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "אוֹפַנַּיִם", distractors: ["מְכוֹנִית", "אוֹטוֹבּוּס", "מָטוֹס"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "אַרְיֵה", distractors: ["דָּג", "כָּרִישׁ", "דּוֹלְפִין"]),
        BankQuestion(prompt: "מִי לֹא שַׁיָּךְ?", correctAnswer: "אָדֹם", distractors: ["שָׁלוֹשׁ", "חָמֵשׁ", "שֶׁבַע"]),

        // Comparisons
        BankQuestion(prompt: "מַה גָּדוֹל יוֹתֵר?", correctAnswer: "פִּיל", distractors: ["עַכְבָּר", "נְמָלָה", "פַּרְפַּר"]),
        BankQuestion(prompt: "מַה קָטָן יוֹתֵר?", correctAnswer: "נְמָלָה", distractors: ["סוּס", "כֶּלֶב", "חָתוּל"]),
        BankQuestion(prompt: "מַה מָהִיר יוֹתֵר?", correctAnswer: "מָטוֹס", distractors: ["אוֹפַנַּיִם", "סִירָה", "רַכֶּבֶת"]),
        BankQuestion(prompt: "מַה כָּבֵד יוֹתֵר?", correctAnswer: "פִּיל", distractors: ["נוֹצָה", "תַּפּוּחַ", "סֵפֶר"]),
        BankQuestion(prompt: "מַה גָּבוֹהַּ יוֹתֵר?", correctAnswer: "גִּ'ירָפָה", distractors: ["כֶּלֶב", "חָתוּל", "תַּרְנְגוֹל"]),

        // Riddles
        BankQuestion(prompt: "אֲנִי שׁוֹתֶה אֲבָל לֹא כּוֹס. מָה אֲנִי?", correctAnswer: "צֶמַח", distractors: ["שֻׁלְחָן", "חַלּוֹן", "סֵפֶר"]),
        BankQuestion(prompt: "יֵשׁ לִי אַרְבַּע רַגְלַיִם אֲבָל לֹא הוֹלֵךְ. מִי אֲנִי?", correctAnswer: "שֻׁלְחָן", distractors: ["סוּס", "כֶּלֶב", "צָב"]),
        BankQuestion(prompt: "אֲנִי מֵאִיר אֶת הַלַּיְלָה אַךְ אֵינֶנִּי שֶׁמֶשׁ. מִי אֲנִי?", correctAnswer: "יָרֵחַ", distractors: ["כּוֹכָב", "פָּנָס", "מְנוֹרָה"]),
        BankQuestion(prompt: "אֲנִי כָּתֹם וַאֲנִי יֶרֶק. מִי אֲנִי?", correctAnswer: "גֶּזֶר", distractors: ["תַּפּוּחַ", "מְלָפְפוֹן", "תַּפּוּז"]),
        BankQuestion(prompt: "יֵשׁ לִי דַּפִּים אֲבָל לֹא עֵץ. מִי אֲנִי?", correctAnswer: "סֵפֶר", distractors: ["צֶמַח", "פֶּרַח", "פֵּרוֹת"]),

        // Categories
        BankQuestion(prompt: "מַה זֶה לֹא צֶבַע?", correctAnswer: "שֻׁלְחָן", distractors: ["אָדֹם", "כָּחֹל", "יָרֹק"]),
        BankQuestion(prompt: "מַה זֶה לֹא בַּעַל חַיִּים?", correctAnswer: "מְכוֹנִית", distractors: ["סוּס", "כֶּלֶב", "צִפּוֹר"]),
        BankQuestion(prompt: "מַה זֶה לֹא פְּרִי?", correctAnswer: "מְלָפְפוֹן", distractors: ["תַּפּוּחַ", "בָּנָנָה", "תַּפּוּז"]),
        BankQuestion(prompt: "מַה זֶה לֹא יֶרֶק?", correctAnswer: "תַּפּוּז", distractors: ["מְלָפְפוֹן", "גֶּזֶר", "עַגְבָנִיָּה"]),
        BankQuestion(prompt: "מַה זֶה לֹא יוֹם?", correctAnswer: "יָנוּאָר", distractors: ["שֵׁנִי", "שְׁלִישִׁי", "רְבִיעִי"]),

        // True/False patterns
        BankQuestion(prompt: "אִם כָּל הַכְּלָבִים נוֹבְחִים, מָה נוֹבֵחַ?", correctAnswer: "כֶּלֶב", distractors: ["חָתוּל", "תַּרְנְגוֹל", "פָּרָה"]),
        BankQuestion(prompt: "אִם 2+2=4, אָז 3+3=?", correctAnswer: "6", distractors: ["5", "7", "8"]),
        BankQuestion(prompt: "מִי בָּא אַחֲרֵי 7?", correctAnswer: "8", distractors: ["6", "9", "10"]),
        BankQuestion(prompt: "מִי בָּא לִפְנֵי 5?", correctAnswer: "4", distractors: ["6", "3", "7"]),

        // Time
        BankQuestion(prompt: "כַּמָּה יָמִים בַּשָּׁבוּעַ?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "כַּמָּה חֳדָשִׁים בַּשָּׁנָה?", correctAnswer: "12", distractors: ["10", "11", "13"]),
        BankQuestion(prompt: "כַּמָּה שָׁעוֹת בַּיְּמָמָה?", correctAnswer: "24", distractors: ["12", "18", "30"]),
        BankQuestion(prompt: "כַּמָּה דַּקּוֹת בְּשָׁעָה?", correctAnswer: "60", distractors: ["50", "100", "30"]),
        BankQuestion(prompt: "כַּמָּה שְׁנִיּוֹת בְּדַקָּה?", correctAnswer: "60", distractors: ["100", "30", "12"]),

        // Mirror/reverse
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'גָּדוֹל'?", correctAnswer: "קָטָן", distractors: ["אָרֹךְ", "רָחָב", "גָּבוֹהַּ"]),
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'חַם'?", correctAnswer: "קַר", distractors: ["טָעִים", "מָתוֹק", "יָבֵשׁ"]),
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'מָהִיר'?", correctAnswer: "אִיטִּי", distractors: ["חָזָק", "אָרֹךְ", "כָּבֵד"]),
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'יוֹם'?", correctAnswer: "לַיְלָה", distractors: ["בֹּקֶר", "עֶרֶב", "צָהֳרַיִם"]),
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'שָׂמֵחַ'?", correctAnswer: "עָצוּב", distractors: ["מַצְחִיק", "רָגוּעַ", "מְבֻלְבָּל"]),
        BankQuestion(prompt: "מַה הַהֵפֶךְ שֶׁל 'יָמִין'?", correctAnswer: "שְׂמֹאל", distractors: ["מֵעַל", "מִתַּחַת", "מִלְּפָנִים"]),
    ]

    // MARK: - מדע (~55 extra)

    static let science: [BankQuestion] = [
        BankQuestion(prompt: "🌱\nמַה צְמָחִים צְרִיכִים כְּדֵי לִגְדֹּל?", correctAnswer: "שֶׁמֶשׁ, מַיִם וַאֲדָמָה", distractors: ["אֲוִיר וְעוּגָה", "חוֹל בִּלְבַד", "שֶׁלֶג בִּלְבַד"]),
        BankQuestion(prompt: "💧\nכַּמָּה אָחוּז מֵהָאֲדָמָה מְכֻסֶּה בְּמַיִם?", correctAnswer: "כ-71%", distractors: ["20%", "50%", "100%"]),
        BankQuestion(prompt: "🧊\nמַה קוֹרֶה לַמַּיִם כְּשֶׁהֵם מַגִּיעִים ל-0 מַעֲלוֹת?", correctAnswer: "הֵם קוֹפְאִים", distractors: ["הֵם נֶעֱלָמִים", "הֵם רוֹתְחִים", "הֵם מְשַׁנִּים צֶבַע"]),
        BankQuestion(prompt: "🌡️\nבְּאֵיזוֹ טֶמְפֶּרָטוּרָה רוֹתְחִים מַיִם?", correctAnswer: "100°C", distractors: ["50°C", "200°C", "30°C"]),
        BankQuestion(prompt: "🌍\nכַּמָּה לוּחוֹת טֶקְטוֹנִיִּים יֵשׁ?", correctAnswer: "7 גְּדוֹלִים", distractors: ["3", "10", "20"]),
        BankQuestion(prompt: "🦴\nכַּמָּה עֲצָמוֹת יֵשׁ בַּגּוּף מְבֻגָּר?", correctAnswer: "206", distractors: ["150", "100", "300"]),
        BankQuestion(prompt: "👀\nכַּמָּה צְבָעִים יֵשׁ בַּקֶּשֶׁת?", correctAnswer: "7", distractors: ["5", "6", "10"]),
        BankQuestion(prompt: "🐅\nאֵיזֶה אֵיבָר מַשְׁאִיב אֶת הַדָּם?", correctAnswer: "הַלֵּב", distractors: ["הָרֵאוֹת", "הַכָּבֵד", "הַמֹּחַ"]),
        BankQuestion(prompt: "🌬️\nבְּאֵיזֶה חֹמֶר אֲנַחְנוּ נוֹשְׁמִים?", correctAnswer: "חַמְצָן", distractors: ["מֵימָן", "פַּחְמָן", "אוֹזוֹן"]),
        BankQuestion(prompt: "🌙\nכַּמָּה זְמַן לוֹקֵחַ לַיָּרֵחַ לְהַקִּיף אֶת כַּדּוּר הָאָרֶץ?", correctAnswer: "כ-27 יָמִים", distractors: ["יוֹם", "שָׁנָה", "100 יָמִים"]),
        BankQuestion(prompt: "☀️\nכַּמָּה זְמַן לְאוֹר הַשֶּׁמֶשׁ לְהַגִּיעַ אֵלֵינוּ?", correctAnswer: "8 דַּקּוֹת", distractors: ["שְׁנִיָּה", "שָׁעָה", "יוֹם"]),
        BankQuestion(prompt: "🪐\nאֵיזֶה כּוֹכַב לֶכֶת הֲכִי גָּדוֹל?", correctAnswer: "צֶדֶק", distractors: ["נוֹגַהּ", "מַאְדִּים", "כַּדּוּר הָאָרֶץ"]),
        BankQuestion(prompt: "🌎\nכַּמָּה כּוֹכְבֵי לֶכֶת בְּמַעֲרֶכֶת הַשֶּׁמֶשׁ?", correctAnswer: "8", distractors: ["7", "9", "10"]),
        BankQuestion(prompt: "🔴\nאֵיזֶה כּוֹכַב לֶכֶת אָדֹם?", correctAnswer: "מַאְדִּים", distractors: ["נוֹגַהּ", "צֶדֶק", "שַׁבְּתַאי"]),
        BankQuestion(prompt: "🌟\nמַה הֲכִי קָרוֹב לְכַדּוּר הָאָרֶץ בְּמַעֲרֶכֶת הַשֶּׁמֶשׁ?", correctAnswer: "הַיָּרֵחַ", distractors: ["מַאְדִּים", "נוֹגַהּ", "הַשֶּׁמֶשׁ"]),
        BankQuestion(prompt: "🌳\nמַה צְמָחִים נוֹשְׁמִים?", correctAnswer: "פַּחְמָן דּוּ-חַמְצָנִי", distractors: ["חַמְצָן", "מַיִם", "חַנְקָן"]),
        BankQuestion(prompt: "🌳\nמַה צְמָחִים מוֹצִיאִים?", correctAnswer: "חַמְצָן", distractors: ["פַּחְמָן דּוּ-חַמְצָנִי", "אֵדִים", "מֵימָן"]),
        BankQuestion(prompt: "🐝\nאֵיךְ פְּרָחִים מְקַבְּלִים אַבְקָה?", correctAnswer: "דֶּרֶךְ דְּבוֹרִים", distractors: ["דֶּרֶךְ גֶּשֶׁם", "דֶּרֶךְ אֲדָמָה", "דֶּרֶךְ שֶׁמֶשׁ"]),
        BankQuestion(prompt: "❄️\nמַה הַתְּכוּנָה שֶׁל קֶרַח?", correctAnswer: "קַר וְקָשֶׁה", distractors: ["חַם וְרַךְ", "שָׁקוּף וְנוֹזְלִי", "צָהֹב וְרֵיחָנִי"]),
        BankQuestion(prompt: "🔥\nמַה אֵשׁ צְרִיכָה כְּדֵי לִדְלֹק?", correctAnswer: "חַמְצָן וְדֶלֶק", distractors: ["מַיִם בִּלְבַד", "חוֹל", "קֹר"]),
        BankQuestion(prompt: "🌊\nמַה גּוֹרֵם לְגַלִּים בַּיָּם?", correctAnswer: "הָרוּחַ", distractors: ["דָּגִים", "הַשֶּׁמֶשׁ", "יָרֵחַ בִּלְבַד"]),
        BankQuestion(prompt: "🌜\nמַה גּוֹרֵם לְגֵאוּת וְשֵׁפֶל?", correctAnswer: "הַיָּרֵחַ", distractors: ["הָרוּחַ", "הַשֶּׁמֶשׁ", "דָּגִים"]),
        BankQuestion(prompt: "🦟\nכַּמָּה רַגְלַיִם יֵשׁ לְחֶרֶק?", correctAnswer: "6", distractors: ["4", "8", "10"]),
        BankQuestion(prompt: "🕷️\nכַּמָּה רַגְלַיִם יֵשׁ לְעַכָּבִישׁ?", correctAnswer: "8", distractors: ["6", "4", "10"]),
        BankQuestion(prompt: "🐍\nנְחָשִׁים הֵם...?", correctAnswer: "זוֹחֲלִים", distractors: ["יוֹנְקִים", "צִפּוֹרִים", "דָּגִים"]),
        BankQuestion(prompt: "🐬\nדּוֹלְפִינִים הֵם...?", correctAnswer: "יוֹנְקִים", distractors: ["דָּגִים", "זוֹחֲלִים", "צִפּוֹרִים"]),
        BankQuestion(prompt: "🦇\nעֲטַלֵּפִים הֵם...?", correctAnswer: "יוֹנְקִים", distractors: ["צִפּוֹרִים", "חֲרָקִים", "זוֹחֲלִים"]),
        BankQuestion(prompt: "🐢\nצָבִים הֵם...?", correctAnswer: "זוֹחֲלִים", distractors: ["יוֹנְקִים", "דָּגִים", "צִפּוֹרִים"]),
        BankQuestion(prompt: "🌱\nאֵיזֶה חֵלֶק בַּצֶּמַח שׁוֹאֵב מַיִם?", correctAnswer: "הַשֹּׁרֶשׁ", distractors: ["הֶעָלֶה", "הַפֶּרַח", "הַגֶּזַע"]),
        BankQuestion(prompt: "☀️\nאֵיזֶה חֵלֶק בַּצֶּמַח מְיַצֵּר אֶנֶרְגְּיָה מֵהַשֶּׁמֶשׁ?", correctAnswer: "הֶעָלֶה", distractors: ["הַשֹּׁרֶשׁ", "הַפֶּרַח", "הָאֲדָמָה"]),
        BankQuestion(prompt: "💪\nמַה הֲכִי חָזָק בַּגּוּף?", correctAnswer: "הַשְּׁרִירִים", distractors: ["הָעוֹר", "הַשֵּׂעָר", "הַצִּפָּרְנַיִם"]),
        BankQuestion(prompt: "🦷\nכַּמָּה שִׁנַּיִם יֵשׁ לִמְבֻגָּר?", correctAnswer: "32", distractors: ["20", "28", "40"]),
        BankQuestion(prompt: "🧠\nאֵיזֶה אֵיבָר חוֹשֵׁב?", correctAnswer: "הַמֹּחַ", distractors: ["הַלֵּב", "הַכָּבֵד", "הָרֵאוֹת"]),
        BankQuestion(prompt: "👀\nכַּמָּה עֵינַיִם יֵשׁ לִדְבוֹרָה?", correctAnswer: "5", distractors: ["2", "3", "8"]),
        BankQuestion(prompt: "🐌\nכַּמָּה לְבָבוֹת יֵשׁ לְתַמְנוּן?", correctAnswer: "3", distractors: ["1", "2", "5"]),
        BankQuestion(prompt: "🦒\nאֵיזוֹ חַיָּה הֲכִי גְּבוֹהָה בַּיַּבָּשָׁה?", correctAnswer: "גִּ'ירָפָה", distractors: ["פִּיל", "סוּס", "בְּנֵי אָדָם"]),
        BankQuestion(prompt: "🐋\nאֵיזוֹ חַיָּה הֲכִי גְּדוֹלָה בָּעוֹלָם?", correctAnswer: "לִוְיָתָן כָּחֹל", distractors: ["פִּיל", "כָּרִישׁ", "גִּ'ירָפָה"]),
        BankQuestion(prompt: "🐆\nאֵיזוֹ חַיָּה הֲכִי מְהִירָה?", correctAnswer: "בַּרְדְּלָס", distractors: ["סוּס", "נָמֵר", "אַרְיֵה"]),
        BankQuestion(prompt: "⚡\nאֵיךְ נִקְרָא רַעַם וּבָרָק יַחַד?", correctAnswer: "סוּפַת רְעָמִים", distractors: ["סוּפַת חוֹל", "טוֹרְנָדוֹ", "סוּפָה יְרֻקָּה"]),
        BankQuestion(prompt: "🌫\nמַה זֶה עֲרָפֶל?", correctAnswer: "עָנָן קָרוֹב לַקַּרְקַע", distractors: ["גֶּשֶׁם קַל", "אָבָק", "עָשָׁן"]),
        BankQuestion(prompt: "🌋\nמַה יוֹצֵא מֵהַר גַּעַשׁ?", correctAnswer: "לָבָה", distractors: ["מַיִם", "חוֹל", "עָנָן"]),
        BankQuestion(prompt: "🌊\nאֵיךְ נִקְרָא גַּל עֲנָק בַּיָּם?", correctAnswer: "צוּנָאמִי", distractors: ["טוֹרְנָדוֹ", "סְעָרָה", "עֲרָפֶל"]),
        BankQuestion(prompt: "💎\nאֵיזֶה חֹמֶר הֲכִי קָשֶׁה בַּטֶּבַע?", correctAnswer: "יַהֲלוֹם", distractors: ["בַּרְזֶל", "אֶבֶן", "זְכוּכִית"]),
        BankQuestion(prompt: "🧲\nמַה מוֹשֵׁךְ מַתֶּכֶת?", correctAnswer: "מַגְנֵט", distractors: ["מַיִם", "אֶבֶן", "פְּלַסְטִיק"]),
        BankQuestion(prompt: "🔦\nאֵיךְ נָע אוֹר?", correctAnswer: "בְּקַו יָשָׁר", distractors: ["בְּמַעְגָּלִים", "בְּעִקּוּלִים", "בְּלִי תְּנוּעָה"]),
        BankQuestion(prompt: "👂\nאֵיךְ אֲנַחְנוּ שׁוֹמְעִים?", correctAnswer: "דֶּרֶךְ גַּלֵּי קוֹל", distractors: ["דֶּרֶךְ גַּלֵּי אוֹר", "דֶּרֶךְ מַגָּע", "דֶּרֶךְ רֵיחַ"]),
        BankQuestion(prompt: "🌈\nכַּמָּה צְבָעִים בַּקֶּשֶׁת?", correctAnswer: "7", distractors: ["5", "8", "10"]),
        BankQuestion(prompt: "🌳\nמַה הַצֶּמַח הֲכִי גָּבוֹהַּ בָּעוֹלָם?", correctAnswer: "סְקוֹיָה", distractors: ["אַלּוֹן", "אֵקָלִיפְּטוּס", "תָּמָר"]),
        BankQuestion(prompt: "💨\nמַה חֳמָרִים שֶׁמִּתְפַּשְּׁטִים מַהֵר?", correctAnswer: "גַּזִּים", distractors: ["נוֹזְלִים", "מוּצָקִים", "אָבָק"]),
        BankQuestion(prompt: "🌧\nמֵהֶם שְׁלוֹשֶׁת מַצְּבֵי הַצְּבִירָה?", correctAnswer: "מוּצָק, נוֹזֵל, גַּז", distractors: ["חַם, קַר, פּוֹשֵׁר", "אֶבֶן, מַיִם, אֲוִיר", "אֶחָד, שְׁנַיִם, שָׁלוֹשׁ"]),
        BankQuestion(prompt: "🐦\nמַה הַהֶבְדֵּל בֵּין צִפּוֹר לְטִיסָה?", correctAnswer: "כְּנָפַיִם", distractors: ["שִׁנַּיִם", "זָנָב", "פַּרְוָה"]),
        BankQuestion(prompt: "🌳\nאֵיזֶה גַּז הָעֵצִים פּוֹלְטִים?", correctAnswer: "חַמְצָן", distractors: ["פַּחְמָן", "מֵימָן", "חַנְקָן"]),
        BankQuestion(prompt: "🦠\nמַה זֶה חַיְדַּק?", correctAnswer: "יְצוּר חַי קְטַנְטָן", distractors: ["סוּג שֶׁל יֶרֶק", "סוּג שֶׁל מַתֶּכֶת", "סוּג שֶׁל אֶבֶן"]),
        BankQuestion(prompt: "🌍\nאֵיזֶה כֹּחַ מוֹשֵׁךְ אוֹתָנוּ לָאֲדָמָה?", correctAnswer: "כֹּחַ הַכֹּבֶד", distractors: ["מַגְנֵט", "רוּחַ", "אוֹר"]),
    ]

    // MARK: - היסטוריה (~45 extra)

    static let history: [BankQuestion] = [
        BankQuestion(prompt: "🏺\nאֵיזוֹ צִיוִילִיזַצְיָה בָּנְתָה אֶת הַפִּירָמִידוֹת?", correctAnswer: "הַמִּצְרִים הָעַתִּיקִים", distractors: ["הָרוֹמָאִים", "הַיְּוָונִים", "הַוִּיקִינְגִים"]),
        BankQuestion(prompt: "👑\nמִי הָיָה הַקֵּיסָר הָרִאשׁוֹן שֶׁל רוֹמָא?", correctAnswer: "אוֹגוּסְטוּס", distractors: ["יוּלְיוּס קֵיסָר", "נֵירוֹן", "אַדְרִיָאנוּס"]),
        BankQuestion(prompt: "⚔️\nמִי כָּבַשׁ אֶת אֶרֶץ יִשְׂרָאֵל ב-70 לִסְפִירָה?", correctAnswer: "הָרוֹמָאִים", distractors: ["הַיְּוָונִים", "הַבַּבְלִים", "הַפַּרְסִים"]),
        BankQuestion(prompt: "✡️\nמַה הַשֵּׁם שֶׁל מַנְהִיג הָעָם בְּצֵאת מִצְרַיִם?", correctAnswer: "מֹשֶׁה", distractors: ["דָּוִד", "שְׁלֹמֹה", "אַבְרָהָם"]),
        BankQuestion(prompt: "🏛️\nאֵיפֹה הִתְקַיְּמָה הַכְּנֶסֶת הָרִאשׁוֹנָה?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"]),
        BankQuestion(prompt: "🎺\nמַה גָּרַם לְחוֹמוֹת יְרִיחוֹ לִנְפֹּל?", correctAnswer: "תְּרוּעַת הַשּׁוֹפָר", distractors: ["רְעִידַת אֲדָמָה", "סוּפַת חוֹל", "מַבּוּל"]),
        BankQuestion(prompt: "🏰\nמִי בָּנָה אֶת בֵּית הַמִּקְדָּשׁ הָרִאשׁוֹן?", correctAnswer: "שְׁלֹמֹה הַמֶּלֶךְ", distractors: ["דָּוִד הַמֶּלֶךְ", "שָׁאוּל הַמֶּלֶךְ", "חִזְקִיָּהוּ"]),
        BankQuestion(prompt: "⚖️\nמִי מָלַךְ אַחֲרֵי דָּוִד?", correctAnswer: "שְׁלֹמֹה", distractors: ["שָׁאוּל", "יָרָבְעָם", "רְחַבְעָם"]),
        BankQuestion(prompt: "🦁\nמִי שָׁלַח אֶת דָּנִיֵּאל לְגוֹב הָאֲרָיוֹת?", correctAnswer: "הַמֶּלֶךְ דַּרְיָוֶשׁ", distractors: ["נְבוּכַדְנֶצַּר", "אֲחַשְׁוֵרוֹשׁ", "כֹּרֶשׁ"]),
        BankQuestion(prompt: "👑\nמִי הָיְתָה אֶסְתֵּר הַמַּלְכָּה?", correctAnswer: "מַלְכַּת פָּרָס", distractors: ["מַלְכַּת מִצְרַיִם", "מַלְכַּת בָּבֶל", "מַלְכַּת רוֹמָא"]),
        BankQuestion(prompt: "📜\nמַה הַשָּׂפָה שֶׁל הַתַּנַ\"ךְ?", correctAnswer: "עִבְרִית", distractors: ["יְוָונִית", "אֲרָמִית", "עֲרָבִית"]),
        BankQuestion(prompt: "🛤️\nמָתַי הוּקְמָה מְדִינַת יִשְׂרָאֵל?", correctAnswer: "1948", distractors: ["1917", "1967", "1973"]),
        BankQuestion(prompt: "📜\nמִי הִקְרִיא אֶת הַכְרָזַת הָעַצְמָאוּת?", correctAnswer: "דָּוִד בֶּן-גּוּרְיוֹן", distractors: ["חַיִּים וַייצְמָן", "מְנַחֵם בֵּגִין", "גּוֹלְדָּה מֵאִיר"]),
        BankQuestion(prompt: "🇮🇱\nאֵיפֹה הוּקְמָה מְדִינַת יִשְׂרָאֵל?", correctAnswer: "תֵּל אָבִיב", distractors: ["יְרוּשָׁלַיִם", "חֵיפָה", "טְבֶרְיָה"]),
        BankQuestion(prompt: "👵\nמִי הָיְתָה רֹאשַׁת הַמֶּמְשָׁלָה הָאִשָּׁה הָרִאשׁוֹנָה?", correctAnswer: "גּוֹלְדָּה מֵאִיר", distractors: ["שׁוּלַמִּית אַלוֹנִי", "צִיפִּי לִבְנִי", "מִירִי רֶגֶב"]),
        BankQuestion(prompt: "🦅\nאֵיזֶה סֵמֶל יֵשׁ עַל דֶּגֶל יִשְׂרָאֵל?", correctAnswer: "מָגֵן דָּוִד", distractors: ["אַרְיֵה", "נֶשֶׁר", "עֲנַף זַיִת"]),
        BankQuestion(prompt: "🇺🇸\nמָתַי הוּקְמָה אַרְהַ\"ב?", correctAnswer: "1776", distractors: ["1620", "1492", "1800"]),
        BankQuestion(prompt: "🧭\nמִי גִּילָּה אֶת אֲמֵרִיקָה ב-1492?", correctAnswer: "כְּרִיסְטוֹפֶר קוֹלוּמְבּוּס", distractors: ["מָגֶלָן", "וַסְקוֹ דֶּה גָּאמָה", "מַרְקוֹ פּוֹלוֹ"]),
        BankQuestion(prompt: "🚀\nמִי הָיָה הָאָדָם הָרִאשׁוֹן עַל הַיָּרֵחַ?", correctAnswer: "נִיל אַרְמְסְטְרוֹנְג", distractors: ["יוּרִי גָּגָארִין", "בָּאז אוֹלְדְּרִין", "גִּ'ון גְּלֵן"]),
        BankQuestion(prompt: "🚀\nמִי הָיָה הָאָדָם הָרִאשׁוֹן בֶּחָלָל?", correctAnswer: "יוּרִי גָּגָארִין", distractors: ["נִיל אַרְמְסְטְרוֹנְג", "אָלֶן שֶׁפַּרְד", "בָּאז אוֹלְדְּרִין"]),
        BankQuestion(prompt: "🎨\nמִי צִיֵּר אֶת הַמוֹנָה לִיזָה?", correctAnswer: "לֵאוֹנַרְדּוֹ דָּה וִינְצִ'י", distractors: ["מִיכֶלְאַנְגֶּ'לוֹ", "פִּיקָאסוֹ", "וָון גּוֹךְ"]),
        BankQuestion(prompt: "🎼\nמִי כָּתַב אֶת 'אֱלֹהֵי הַקְּטַנִּים'?", correctAnswer: "מוֹצַרְט", distractors: ["בֵּטְהוֹבֶן", "בָּאךְ", "שׁוֹפֵּן"]),
        BankQuestion(prompt: "💡\nמִי הִמְצִיא אֶת הַנּוּרָה?", correctAnswer: "תּוֹמַס אֵדִיסוֹן", distractors: ["אַיינְשְׁטַיין", "נְיוּטוֹן", "בֵּל"]),
        BankQuestion(prompt: "📞\nמִי הִמְצִיא אֶת הַטֶּלֶפוֹן?", correctAnswer: "אָלֶכְּסַנְדֶּר גְּרַהַם בֵּל", distractors: ["אֵדִיסוֹן", "מַארְקוֹנִי", "נְיוּטוֹן"]),
        BankQuestion(prompt: "🌌\nמִי גִּילָּה אֶת כֹּחַ הַכֹּבֶד?", correctAnswer: "נְיוּטוֹן", distractors: ["אַיינְשְׁטַיין", "גָּלִילֵאוֹ", "קוֹפֶּרְנִיקוּס"]),
        BankQuestion(prompt: "🧪\nמִי גִּילָּה אֶת הַפֵּנִיצִילִין?", correctAnswer: "פְלֵמִינְג", distractors: ["פַּסְטֵר", "אֵדִיסוֹן", "מָארִי קִירִי"]),
        BankQuestion(prompt: "👩‍🔬\nמִי הָיְתָה הָאִשָּׁה הָרִאשׁוֹנָה שֶׁזָּכְתָה בִּפְרַס נוֹבֶּל?", correctAnswer: "מָארִי קִירִי", distractors: ["אַיינְשְׁטַיין", "פְלֵמִינְג", "נְיוּטוֹן"]),
        BankQuestion(prompt: "🏛️\nאֵיזוֹ מְדִינָה נֶחְשֶׁבֶת לַעֲרִיסַת הַדֶּמוֹקְרַטְיָה?", correctAnswer: "יָוָון", distractors: ["רוֹמָא", "מִצְרַיִם", "סִין"]),
        BankQuestion(prompt: "📜\nמַה הַטֶּקְסְט הָעַתִּיק בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "אֶפּוֹס גִּלְגָּמֶשׁ", distractors: ["הַתַּנַ\"ךְ", "הָאוֹדִיסֵאָה", "הָאִילִיאָדָה"]),
        BankQuestion(prompt: "🏯\nאֵיפֹה בָּנוּ אֶת הַחוֹמָה הַסִּינִית הַגְּדוֹלָה?", correctAnswer: "סִין", distractors: ["יָפָאן", "קוֹרֵאָה", "הֹדּוּ"]),
        BankQuestion(prompt: "🗡️\nמִי הָיָה מַנְהִיג הַצָּבָא שֶׁל נָפּוֹלְיוֹן?", correctAnswer: "נָפּוֹלְיוֹן בְּעַצְמוֹ", distractors: ["וָשִׁינְגְטוֹן", "צֶּ'רְצִּ'יל", "בִּיסְמַרְק"]),
        BankQuestion(prompt: "👑\nמִי הָיְתָה הַמַּלְכָּה אֱלִיזָבֶּת הָרִאשׁוֹנָה?", correctAnswer: "מַלְכַּת אַנְגְלִיָּה", distractors: ["מַלְכַּת צָרְפַת", "מַלְכַּת סְפָרַד", "מַלְכַּת רוּסְיָה"]),
        BankQuestion(prompt: "🇪🇬\nמִי הָיְתָה קְלֵיאוֹפַּטְרָה?", correctAnswer: "מַלְכַּת מִצְרַיִם", distractors: ["מַלְכַּת רוֹמָא", "מַלְכַּת יָוָון", "מַלְכַּת בָּבֶל"]),
        BankQuestion(prompt: "⚔️\nמָתַי הֵחֵלָּה מִלְחֶמֶת הָעוֹלָם הָרִאשׁוֹנָה?", correctAnswer: "1914", distractors: ["1900", "1939", "1918"]),
        BankQuestion(prompt: "⚔️\nמָתַי הִסְתַּיְּמָה מִלְחֶמֶת הָעוֹלָם הַשְּׁנִיָּה?", correctAnswer: "1945", distractors: ["1918", "1939", "1950"]),
        BankQuestion(prompt: "🌐\nמָתַי הוּמְצָא הָאִינְטֶרְנֶט?", correctAnswer: "1960-1970", distractors: ["1900", "1950", "2000"]),
        BankQuestion(prompt: "📱\nמָתַי הוּמְצָא הַסְּמַארְטְפוֹן הָרִאשׁוֹן?", correctAnswer: "2007 (iPhone)", distractors: ["1990", "2000", "2015"]),
        BankQuestion(prompt: "🚂\nמִי הִמְצִיא אֶת הַקַּטָּר?", correctAnswer: "גִּ'ורְג' סְטִיבֶנְסוֹן", distractors: ["וָואט", "אֵדִיסוֹן", "פוֹרְד"]),
        BankQuestion(prompt: "🚗\nמִי הִמְצִיא אֶת הָרֶכֶב?", correctAnswer: "קַארְל בֶּנְץ", distractors: ["פוֹרְד", "אֵדִיסוֹן", "וָואט"]),
        BankQuestion(prompt: "✈️\nמִי הִמְצִיאוּ אֶת הַמָּטוֹס?", correctAnswer: "הָאַחִים רַייט", distractors: ["אַיינְשְׁטַיין", "אֵדִיסוֹן", "וָואט"]),
        BankQuestion(prompt: "🇮🇱\nמַה הָיָה הַשֵּׁם שֶׁל אֶרֶץ יִשְׂרָאֵל לִפְנֵי 1948?", correctAnswer: "פָּלֶשְׂתִּינָה (תַּחַת הַמַּנְדָּט)", distractors: ["יִשְׂרָאֵל", "אֶרֶץ הַקֹּדֶשׁ", "כְּנַעַן"]),
        BankQuestion(prompt: "🇮🇱\nמַה תַּפְקִיד הַנָּשִׂיא בְּיִשְׂרָאֵל?", correctAnswer: "יִיצּוּגִי", distractors: ["מְנַהֵל הַמְּדִינָה", "מְפַקֵּד הַצָּבָא", "רֹאשׁ בֵּית הַמִּשְׁפָּט"]),
        BankQuestion(prompt: "🏛️\nכַּמָּה חַבְרֵי כְּנֶסֶת יֵשׁ בְּיִשְׂרָאֵל?", correctAnswer: "120", distractors: ["100", "150", "200"]),
        BankQuestion(prompt: "👴\nמִי הָיָה רַא\"ל הָרִאשׁוֹן שֶׁל צַהַ\"ל?", correctAnswer: "יַעֲקֹב דּוֹרִי", distractors: ["דָּוִד בֶּן-גּוּרְיוֹן", "מֹשֶׁה דַּיָּן", "יִצְחָק רַבִּין"]),
        BankQuestion(prompt: "🎖️\nאֵיזֶה צֶבַע הַבֶּרֶט שֶׁל חֵיל הָאֲוִיר?", correctAnswer: "כָּחֹל", distractors: ["אָדֹם", "שָׁחֹר", "יָרֹק"]),
    ]

    // MARK: - גיאוגרפיה (~50 extra)

    static let geography: [BankQuestion] = [
        BankQuestion(prompt: "🇫🇷\nמַה בִּירַת צָרְפַת?", correctAnswer: "פָּרִיז", distractors: ["מַארְסֵיי", "לִיוֹן", "נִיס"]),
        BankQuestion(prompt: "🇩🇪\nמַה בִּירַת גֶּרְמַנְיָה?", correctAnswer: "בֶּרְלִין", distractors: ["מִינְכֶן", "הַמְבּוּרְג", "פְרַנְקְפוּרְט"]),
        BankQuestion(prompt: "🇺🇸\nמַה בִּירַת אַרְצוֹת הַבְּרִית?", correctAnswer: "וָשִׁינְגְטוֹן", distractors: ["נְיוּ יוֹרְק", "לוֹס אַנְגֶּ'לֶס", "שִׁיקָגוֹ"]),
        BankQuestion(prompt: "🇨🇦\nמַה בִּירַת קָנָדָה?", correctAnswer: "אוֹטָוָוה", distractors: ["טוֹרוֹנְטוֹ", "וַנְקוּבֶר", "מוֹנְטְרֵיאוֹל"]),
        BankQuestion(prompt: "🇧🇷\nמַה בִּירַת בְּרָזִיל?", correctAnswer: "בְּרָזִילְיָה", distractors: ["רִיוֹ דֶּה זָ'נֵיירוֹ", "סָאוֹ פָּאוּלוֹ", "סָלְבָדוֹר"]),
        BankQuestion(prompt: "🇦🇺\nמַה בִּירַת אוֹסְטְרַלְיָה?", correctAnswer: "קַנְבֶּרָה", distractors: ["סִידְנִי", "מֶלְבּוּרְן", "פֶּרְת'"]),
        BankQuestion(prompt: "🇷🇺\nמַה בִּירַת רוּסְיָה?", correctAnswer: "מוֹסְקְבָה", distractors: ["סַנְקְט פֶּטֶרְבּוּרְג", "קִייֶב", "מִינְסְק"]),
        BankQuestion(prompt: "🇨🇳\nמַה בִּירַת סִין?", correctAnswer: "בֵּייגִּ'ינְג", distractors: ["שַׁנְחַאי", "הוֹנְג קוֹנְג", "טַייוָואן"]),
        BankQuestion(prompt: "🇮🇳\nמַה בִּירַת הֹדּוּ?", correctAnswer: "נְיוּ דֶּלְהִי", distractors: ["מוּמְבַּאי", "בַּנְגָּלוֹר", "כַּלְכּוּתָּה"]),
        BankQuestion(prompt: "🇲🇽\nמַה בִּירַת מֶקְסִיקוֹ?", correctAnswer: "מֶקְסִיקוֹ סִיטִי", distractors: ["קַנְקוּן", "גוּאָדָלָחָרָה", "מוֹנְטֵרִי"]),
        BankQuestion(prompt: "🇦🇷\nמַה בִּירַת אַרְגֶּנְטִינָה?", correctAnswer: "בּוּאֵנוֹס אַיירֶס", distractors: ["סַנְטְיָאגוֹ", "מוֹנְטֶבִידֵאוֹ", "לִימָה"]),
        BankQuestion(prompt: "🇪🇬\nמַה בִּירַת מִצְרַיִם?", correctAnswer: "קָהִיר", distractors: ["אָלֶכְּסַנְדְּרְיָה", "לוּקְסוֹר", "אַסְוָואן"]),
        BankQuestion(prompt: "🇿🇦\nמַה בִּירַת דְּרוֹם אַפְרִיקָה?", correctAnswer: "פְּרֵטוֹרְיָה", distractors: ["קֵייפּ טָאוּן", "יוֹהָנֶסְבּוּרְג", "דֶּרְבָּן"]),
        BankQuestion(prompt: "🇹🇷\nמַה בִּירַת טוּרְקְיָה?", correctAnswer: "אַנְקָרָה", distractors: ["אִיסְטַנְבּוּל", "אִיזְמִיר", "בּוּרְסָה"]),
        BankQuestion(prompt: "🇸🇦\nמַה בִּירַת סְעוּדְיָה?", correctAnswer: "רִיָאד", distractors: ["מֶכָּה", "גֶּ'דָּה", "מְדִינָה"]),
        BankQuestion(prompt: "🇦🇪\nמַה בִּירַת אִיחוּד הָאֵמִירוּיוֹת?", correctAnswer: "אַבּוּ דָאבִּי", distractors: ["דּוּבַּאי", "שַׁארְגָּ'ה", "עַגְ'מָאן"]),
        BankQuestion(prompt: "🇰🇷\nמַה בִּירַת קוֹרֵאָה הַדְּרוֹמִית?", correctAnswer: "סֵאוּל", distractors: ["בּוּסָאן", "אִינְצֶ'ון", "פְּיוֹנְגְיָאנְג"]),

        // Israel
        BankQuestion(prompt: "🇮🇱\nמַה הַיָּם הַמָּלוּחַ בְּיוֹתֵר בָּעוֹלָם?", correctAnswer: "יָם הַמֶּלַח", distractors: ["הַכִּנֶּרֶת", "הַיָּם הַתִּיכוֹן", "יָם סוּף"]),
        BankQuestion(prompt: "🇮🇱\nמַה אֲגַם הַמַּיִם הַמְּתוּקִים הַגָּדוֹל בְּיִשְׂרָאֵל?", correctAnswer: "הַכִּנֶּרֶת", distractors: ["יָם הַמֶּלַח", "אֲגַם מוֹנְפוֹרְט", "יָם סוּף"]),
        BankQuestion(prompt: "🇮🇱\nמַה הָהָר הַגָּבוֹהַּ בְּיִשְׂרָאֵל?", correctAnswer: "הַחֶרְמוֹן", distractors: ["מֵירוֹן", "תָּבוֹר", "כַּרְמֶל"]),
        BankQuestion(prompt: "🇮🇱\nמַה הַנָּהָר הָאָרֹךְ בְּיִשְׂרָאֵל?", correctAnswer: "הַיַּרְדֵּן", distractors: ["הַיַּרְקוֹן", "הַקִּישׁוֹן", "הָאָלֶכְּסַנְדֶּר"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ עִיר נִמְצֵאת עַל שְׂפַת יָם הַמֶּלַח?", correctAnswer: "עֲרָד", distractors: ["נָצְרַת", "צְפַת", "אֵילַת"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ עִיר הִיא הַדְּרוֹמִית בְּיוֹתֵר בְּיִשְׂרָאֵל?", correctAnswer: "אֵילַת", distractors: ["בְּאֵר שֶׁבַע", "עֲרָד", "דִּימוֹנָה"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ עִיר הִיא הַצְּפוֹנִית בְּיוֹתֵר?", correctAnswer: "מְטוּלָּה", distractors: ["קִרְיַת שְׁמוֹנָה", "צְפַת", "טְבֶרְיָה"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ עִיר הִיא בִּירַת יִשְׂרָאֵל?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["תֵּל אָבִיב", "חֵיפָה", "בְּאֵר שֶׁבַע"]),
        BankQuestion(prompt: "🇮🇱\nכַּמָּה מְחוֹזוֹת יֵשׁ בְּיִשְׂרָאֵל?", correctAnswer: "6", distractors: ["4", "5", "8"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזֶה יָם נִמְצָא בְּמַעֲרַב יִשְׂרָאֵל?", correctAnswer: "הַיָּם הַתִּיכוֹן", distractors: ["יָם סוּף", "יָם הַמֶּלַח", "הָאוֹקְיָנוֹס"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזֶה יָם נִמְצָא בִּדְרוֹם יִשְׂרָאֵל?", correctAnswer: "יָם סוּף", distractors: ["הַיָּם הַתִּיכוֹן", "יָם הַמֶּלַח", "הַיָּם הַיָּם"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ מְדִינָה גּוֹבֶלֶת עִם יִשְׂרָאֵל מִצָּפוֹן?", correctAnswer: "לְבָנוֹן", distractors: ["מִצְרַיִם", "סוּרְיָה", "יַרְדֵּן"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ מְדִינָה גּוֹבֶלֶת עִם יִשְׂרָאֵל מִמִּזְרָח?", correctAnswer: "יַרְדֵּן", distractors: ["לְבָנוֹן", "מִצְרַיִם", "סוּרְיָה"]),
        BankQuestion(prompt: "🇮🇱\nאֵיזוֹ מְדִינָה גּוֹבֶלֶת עִם יִשְׂרָאֵל מִדָּרוֹם?", correctAnswer: "מִצְרַיִם", distractors: ["סוּדָאן", "סוּרְיָה", "סְעוּדְיָה"]),

        // Continents & oceans
        BankQuestion(prompt: "🌎\nכַּמָּה אוֹקְיָנוֹסִים יֵשׁ בָּעוֹלָם?", correctAnswer: "5", distractors: ["3", "4", "7"]),
        BankQuestion(prompt: "🌊\nאֵיזֶה אוֹקְיָנוֹס הוּא הַגָּדוֹל בְּיוֹתֵר?", correctAnswer: "הַשָּׁקֵט", distractors: ["הָאַטְלַנְטִי", "הַהֹדִּי", "הָאַרְקְטִי"]),
        BankQuestion(prompt: "🌍\nמַה הַיַּבֶּשֶׁת הַקְּטַנָּה בְּיוֹתֵר?", correctAnswer: "אוֹסְטְרַלְיָה", distractors: ["אֵירוֹפָּה", "אַנְטַארְקְטִיקָה", "אַפְרִיקָה"]),
        BankQuestion(prompt: "🐧\nאֵיזוֹ יַבֶּשֶׁת הִיא הַקָּרָה בְּיוֹתֵר?", correctAnswer: "אַנְטַארְקְטִיקָה", distractors: ["אַסְיָה", "אֵירוֹפָּה", "אֲמֵרִיקָה"]),
        BankQuestion(prompt: "🦒\nאֵיזוֹ יַבֶּשֶׁת הִיא הֲכִי חַמָּה (מְמֻצָּע)?", correctAnswer: "אַפְרִיקָה", distractors: ["אַסְיָה", "אוֹסְטְרַלְיָה", "אֲמֵרִיקָה"]),
        BankQuestion(prompt: "🌍\nאֵיזוֹ יַבֶּשֶׁת הִיא בַּעֲלַת מִסְפַּר הַמְּדִינוֹת הַגָּדוֹל בְּיוֹתֵר?", correctAnswer: "אַפְרִיקָה", distractors: ["אַסְיָה", "אֵירוֹפָּה", "אֲמֵרִיקָה"]),

        // Notable landmarks
        BankQuestion(prompt: "🗼\nמִגְדַּל אַייפֶל נִמְצָא ב...?", correctAnswer: "פָּרִיז", distractors: ["לוֹנְדּוֹן", "רוֹמָא", "בֶּרְלִין"]),
        BankQuestion(prompt: "🗽\nפֶּסֶל הַחֵרוּת נִמְצָא ב...?", correctAnswer: "נְיוּ יוֹרְק", distractors: ["וָשִׁינְגְטוֹן", "שִׁיקָגוֹ", "מַיָאמִי"]),
        BankQuestion(prompt: "🗿\nפִּסְלֵי מוֹאַי נִמְצָאִים ב...?", correctAnswer: "אִי הַפֶּסַח", distractors: ["מֶקְסִיקוֹ", "פֵּרוּ", "אִינְדּוֹנֶזְיָה"]),
        BankQuestion(prompt: "🏯\nהַחוֹמָה הַסִּינִית הַגְּדוֹלָה נִמְצֵאת ב...?", correctAnswer: "סִין", distractors: ["יָפָאן", "קוֹרֵאָה", "מוֹנְגּוֹלְיָה"]),
        BankQuestion(prompt: "🕌\nמֶרְכַּז הַתְּפִילָּה לְמֻסְלְמִים?", correctAnswer: "מֶכָּה", distractors: ["מְדִינָה", "יְרוּשָׁלַיִם", "קָהִיר"]),
        BankQuestion(prompt: "🕍\nמֶרְכַּז הַתְּפִילָּה לִיהוּדִים?", correctAnswer: "יְרוּשָׁלַיִם", distractors: ["טְבֶרְיָה", "צְפַת", "תֵּל אָבִיב"]),
        BankQuestion(prompt: "⛪\nאֵיפֹה בֵּית הַכְּנֵסִיָּה שֶׁל אַפִּיפְיוֹר?", correctAnswer: "וָתִיקָן", distractors: ["רוֹמָא", "פָּרִיז", "לוֹנְדּוֹן"]),

        // Rivers & lakes
        BankQuestion(prompt: "🌊\nאֵיזֶה נָהָר הוּא הָאָרֹךְ בְּיוֹתֵר בְּאַפְרִיקָה?", correctAnswer: "הַנִּילוּס", distractors: ["הַקּוֹנְגּוֹ", "הַנִּיזֶ'ר", "הַזַּמְבֶּזִי"]),
        BankQuestion(prompt: "🌊\nאֵיזֶה נָהָר הוּא הָאָרֹךְ בְּיוֹתֵר בִּדְרוֹם אֲמֵרִיקָה?", correctAnswer: "הָאַמָזוֹנַס", distractors: ["הַפָּרָאנָה", "הַפָּרָגוּאַי", "הָאוֹרִינוֹקוֹ"]),
        BankQuestion(prompt: "🌊\nאֵיזֶה נָהָר הוּא הָאָרֹךְ בְּיוֹתֵר בְּאֵירוֹפָּה?", correctAnswer: "הַוֹּולְגָּה", distractors: ["הַדָּנוּבָּה", "הָרַיין", "הַסֵּיינָה"]),
        BankQuestion(prompt: "🏔️\nאֵיזֶה הַר נִמְצָא בְּצָרְפַת?", correctAnswer: "הָאַלְפִּים (חֶלְקָם)", distractors: ["הָאֶוֶורֶסְט", "הַהִימָלָאיָה", "הָאַנְדִּים"]),
        BankQuestion(prompt: "🏔️\nאֵיזֶה הַר נִמְצָא בִּדְרוֹם אֲמֵרִיקָה?", correctAnswer: "הָאַנְדִּים", distractors: ["הָאַלְפִּים", "הַהִימָלָאיָה", "הָאוּרָלִיִּים"]),
    ]

    // MARK: - Aggregate

    static func extras(for topic: Topic) -> [BankQuestion] {
        switch topic {
        case .english:   return english
        case .logic:     return logic
        case .science:   return science
        case .history:   return history
        case .geography: return geography
        case .hebrew:    return []
        case .money:     return []
        case .math:      return []
        }
    }
}
