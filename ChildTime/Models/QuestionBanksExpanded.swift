import Foundation

/// Expanded question banks — adds ~300 new questions across all bank topics
/// so kids stop seeing the same questions twice in a session.
///
/// `QuestionBanks.bank(for:)` now returns the original + expanded together.
enum QuestionBanksExpanded {

    // MARK: - אנגלית (~80 extra)

    static let english: [BankQuestion] = [
        // Animals (more)
        BankQuestion(prompt: "🦓\nאיך אומרים את זה באנגלית?", correctAnswer: "zebra", distractors: ["horse", "cow", "donkey"]),
        BankQuestion(prompt: "🦒\nאיך אומרים את זה באנגלית?", correctAnswer: "giraffe", distractors: ["elephant", "horse", "camel"]),
        BankQuestion(prompt: "🐒\nאיך אומרים את זה באנגלית?", correctAnswer: "monkey", distractors: ["bear", "ape", "lion"]),
        BankQuestion(prompt: "🐻\nאיך אומרים את זה באנגלית?", correctAnswer: "bear", distractors: ["wolf", "fox", "dog"]),
        BankQuestion(prompt: "🐺\nאיך אומרים את זה באנגלית?", correctAnswer: "wolf", distractors: ["dog", "fox", "bear"]),
        BankQuestion(prompt: "🐰\nאיך אומרים את זה באנגלית?", correctAnswer: "rabbit", distractors: ["mouse", "hamster", "fox"]),
        BankQuestion(prompt: "🐭\nאיך אומרים את זה באנגלית?", correctAnswer: "mouse", distractors: ["rabbit", "rat", "cat"]),
        BankQuestion(prompt: "🐢\nאיך אומרים את זה באנגלית?", correctAnswer: "turtle", distractors: ["snake", "frog", "fish"]),
        BankQuestion(prompt: "🐸\nאיך אומרים את זה באנגלית?", correctAnswer: "frog", distractors: ["fish", "turtle", "lizard"]),
        BankQuestion(prompt: "🦋\nאיך אומרים את זה באנגלית?", correctAnswer: "butterfly", distractors: ["bee", "bird", "fly"]),
        BankQuestion(prompt: "🐝\nאיך אומרים את זה באנגלית?", correctAnswer: "bee", distractors: ["fly", "ant", "butterfly"]),
        BankQuestion(prompt: "🦊\nאיך אומרים את זה באנגלית?", correctAnswer: "fox", distractors: ["wolf", "dog", "cat"]),
        BankQuestion(prompt: "🦄\nאיך אומרים את זה באנגלית?", correctAnswer: "unicorn", distractors: ["horse", "dragon", "pony"]),
        BankQuestion(prompt: "🐬\nאיך אומרים את זה באנגלית?", correctAnswer: "dolphin", distractors: ["whale", "fish", "shark"]),
        BankQuestion(prompt: "🦈\nאיך אומרים את זה באנגלית?", correctAnswer: "shark", distractors: ["whale", "fish", "dolphin"]),
        BankQuestion(prompt: "🐢\nאיך אומרים 'איטי' באנגלית?", correctAnswer: "slow", distractors: ["fast", "small", "old"]),

        // Colors
        BankQuestion(prompt: "🔴\nמה הצבע באנגלית?", correctAnswer: "red", distractors: ["blue", "yellow", "pink"]),
        BankQuestion(prompt: "🔵\nמה הצבע באנגלית?", correctAnswer: "blue", distractors: ["red", "green", "purple"]),
        BankQuestion(prompt: "🟢\nמה הצבע באנגלית?", correctAnswer: "green", distractors: ["yellow", "blue", "brown"]),
        BankQuestion(prompt: "🟡\nמה הצבע באנגלית?", correctAnswer: "yellow", distractors: ["orange", "gold", "white"]),
        BankQuestion(prompt: "🟠\nמה הצבע באנגלית?", correctAnswer: "orange", distractors: ["yellow", "red", "brown"]),
        BankQuestion(prompt: "🟣\nמה הצבע באנגלית?", correctAnswer: "purple", distractors: ["pink", "blue", "violet"]),
        BankQuestion(prompt: "⚫\nמה הצבע באנגלית?", correctAnswer: "black", distractors: ["gray", "brown", "dark"]),
        BankQuestion(prompt: "⚪\nמה הצבע באנגלית?", correctAnswer: "white", distractors: ["gray", "silver", "light"]),

        // Numbers (Hebrew → English)
        BankQuestion(prompt: "1\nאיך אומרים את המספר באנגלית?", correctAnswer: "one", distractors: ["two", "three", "four"]),
        BankQuestion(prompt: "2\nאיך אומרים את המספר באנגלית?", correctAnswer: "two", distractors: ["three", "one", "five"]),
        BankQuestion(prompt: "3\nאיך אומרים את המספר באנגלית?", correctAnswer: "three", distractors: ["thirteen", "two", "four"]),
        BankQuestion(prompt: "4\nאיך אומרים את המספר באנגלית?", correctAnswer: "four", distractors: ["five", "fourteen", "fourty"]),
        BankQuestion(prompt: "5\nאיך אומרים את המספר באנגלית?", correctAnswer: "five", distractors: ["four", "fifteen", "six"]),
        BankQuestion(prompt: "10\nאיך אומרים את המספר באנגלית?", correctAnswer: "ten", distractors: ["twenty", "tin", "eleven"]),

        // Family
        BankQuestion(prompt: "אבא באנגלית?", correctAnswer: "father", distractors: ["mother", "brother", "sister"]),
        BankQuestion(prompt: "אמא באנגלית?", correctAnswer: "mother", distractors: ["father", "sister", "aunt"]),
        BankQuestion(prompt: "אח באנגלית?", correctAnswer: "brother", distractors: ["sister", "father", "uncle"]),
        BankQuestion(prompt: "אחות באנגלית?", correctAnswer: "sister", distractors: ["brother", "mother", "aunt"]),
        BankQuestion(prompt: "סבא באנגלית?", correctAnswer: "grandfather", distractors: ["father", "uncle", "grandson"]),
        BankQuestion(prompt: "סבתא באנגלית?", correctAnswer: "grandmother", distractors: ["mother", "aunt", "granddaughter"]),

        // Common verbs
        BankQuestion(prompt: "לרוץ באנגלית?", correctAnswer: "run", distractors: ["jump", "walk", "swim"]),
        BankQuestion(prompt: "לקפוץ באנגלית?", correctAnswer: "jump", distractors: ["run", "fly", "climb"]),
        BankQuestion(prompt: "לאכול באנגלית?", correctAnswer: "eat", distractors: ["drink", "sleep", "cook"]),
        BankQuestion(prompt: "לישון באנגלית?", correctAnswer: "sleep", distractors: ["eat", "play", "rest"]),
        BankQuestion(prompt: "לקרוא באנגלית?", correctAnswer: "read", distractors: ["write", "look", "listen"]),
        BankQuestion(prompt: "לכתוב באנגלית?", correctAnswer: "write", distractors: ["read", "draw", "speak"]),
        BankQuestion(prompt: "לשחק באנגלית?", correctAnswer: "play", distractors: ["work", "study", "sleep"]),
        BankQuestion(prompt: "לראות באנגלית?", correctAnswer: "see", distractors: ["hear", "look", "watch"]),
        BankQuestion(prompt: "לשמוע באנגלית?", correctAnswer: "hear", distractors: ["see", "say", "listen"]),
        BankQuestion(prompt: "לדבר באנגלית?", correctAnswer: "speak", distractors: ["talk", "tell", "say"]),

        // Days & time
        BankQuestion(prompt: "יום ראשון באנגלית?", correctAnswer: "Sunday", distractors: ["Monday", "Saturday", "Friday"]),
        BankQuestion(prompt: "יום שני באנגלית?", correctAnswer: "Monday", distractors: ["Sunday", "Tuesday", "Friday"]),
        BankQuestion(prompt: "יום שלישי באנגלית?", correctAnswer: "Tuesday", distractors: ["Wednesday", "Monday", "Thursday"]),
        BankQuestion(prompt: "יום רביעי באנגלית?", correctAnswer: "Wednesday", distractors: ["Tuesday", "Thursday", "Sunday"]),
        BankQuestion(prompt: "יום חמישי באנגלית?", correctAnswer: "Thursday", distractors: ["Friday", "Wednesday", "Sunday"]),
        BankQuestion(prompt: "יום שישי באנגלית?", correctAnswer: "Friday", distractors: ["Saturday", "Thursday", "Sunday"]),
        BankQuestion(prompt: "שבת באנגלית?", correctAnswer: "Saturday", distractors: ["Sunday", "Friday", "Sabbath"]),

        // Weather & nature
        BankQuestion(prompt: "🌧\nגשם באנגלית?", correctAnswer: "rain", distractors: ["snow", "wind", "cloud"]),
        BankQuestion(prompt: "❄️\nשלג באנגלית?", correctAnswer: "snow", distractors: ["ice", "rain", "cold"]),
        BankQuestion(prompt: "🌬\nרוח באנגלית?", correctAnswer: "wind", distractors: ["rain", "storm", "weather"]),
        BankQuestion(prompt: "☁️\nענן באנגלית?", correctAnswer: "cloud", distractors: ["sky", "fog", "smoke"]),
        BankQuestion(prompt: "⛈\nסערה באנגלית?", correctAnswer: "storm", distractors: ["rain", "thunder", "wind"]),

        // Body parts
        BankQuestion(prompt: "ראש באנגלית?", correctAnswer: "head", distractors: ["hand", "neck", "hair"]),
        BankQuestion(prompt: "אף באנגלית?", correctAnswer: "nose", distractors: ["mouth", "ear", "eye"]),
        BankQuestion(prompt: "פה באנגלית?", correctAnswer: "mouth", distractors: ["nose", "lip", "tongue"]),
        BankQuestion(prompt: "אוזן באנגלית?", correctAnswer: "ear", distractors: ["eye", "nose", "head"]),
        BankQuestion(prompt: "רגל באנגלית?", correctAnswer: "leg", distractors: ["hand", "foot", "knee"]),
        BankQuestion(prompt: "כף יד באנגלית?", correctAnswer: "hand", distractors: ["foot", "arm", "finger"]),

        // Food
        BankQuestion(prompt: "🧀\nגבינה באנגלית?", correctAnswer: "cheese", distractors: ["butter", "milk", "yogurt"]),
        BankQuestion(prompt: "🍕\nפיצה באנגלית?", correctAnswer: "pizza", distractors: ["pasta", "bread", "burger"]),
        BankQuestion(prompt: "🍔\nהמבורגר באנגלית?", correctAnswer: "burger", distractors: ["pizza", "hotdog", "fries"]),
        BankQuestion(prompt: "🍌\nבננה באנגלית?", correctAnswer: "banana", distractors: ["apple", "lemon", "mango"]),
        BankQuestion(prompt: "🍊\nתפוז באנגלית?", correctAnswer: "orange", distractors: ["lemon", "apple", "fruit"]),
        BankQuestion(prompt: "🍓\nתות באנגלית?", correctAnswer: "strawberry", distractors: ["raspberry", "cherry", "apple"]),
        BankQuestion(prompt: "🍉\nאבטיח באנגלית?", correctAnswer: "watermelon", distractors: ["melon", "pumpkin", "apple"]),
        BankQuestion(prompt: "🍇\nענבים באנגלית?", correctAnswer: "grapes", distractors: ["berries", "cherry", "plum"]),

        // School
        BankQuestion(prompt: "מורה באנגלית?", correctAnswer: "teacher", distractors: ["student", "doctor", "parent"]),
        BankQuestion(prompt: "תלמיד באנגלית?", correctAnswer: "student", distractors: ["teacher", "kid", "child"]),
        BankQuestion(prompt: "בית ספר באנגלית?", correctAnswer: "school", distractors: ["college", "class", "home"]),
        BankQuestion(prompt: "כיתה באנגלית?", correctAnswer: "class", distractors: ["school", "room", "lesson"]),
        BankQuestion(prompt: "עיפרון באנגלית?", correctAnswer: "pencil", distractors: ["pen", "paper", "eraser"]),
        BankQuestion(prompt: "עט באנגלית?", correctAnswer: "pen", distractors: ["pencil", "marker", "ink"]),

        // Reverse direction
        BankQuestion(prompt: "What does 'dog' mean?", correctAnswer: "כלב", distractors: ["חתול", "ארנב", "סוס"]),
        BankQuestion(prompt: "What does 'cat' mean?", correctAnswer: "חתול", distractors: ["כלב", "אריה", "נמר"]),
        BankQuestion(prompt: "What does 'house' mean?", correctAnswer: "בית", distractors: ["דירה", "וילה", "חדר"]),
        BankQuestion(prompt: "What does 'star' mean?", correctAnswer: "כוכב", distractors: ["שמש", "ירח", "ענן"]),
        BankQuestion(prompt: "What does 'water' mean?", correctAnswer: "מים", distractors: ["חלב", "מיץ", "תה"]),
        BankQuestion(prompt: "What does 'sun' mean?", correctAnswer: "שמש", distractors: ["ירח", "כוכב", "אור"]),
        BankQuestion(prompt: "What does 'red' mean?", correctAnswer: "אדום", distractors: ["כחול", "ירוק", "ורוד"]),
        BankQuestion(prompt: "What does 'happy' mean?", correctAnswer: "שמח", distractors: ["עצוב", "כועס", "עייף"]),
        BankQuestion(prompt: "What does 'big' mean?", correctAnswer: "גדול", distractors: ["קטן", "ארוך", "רחב"]),
        BankQuestion(prompt: "What does 'small' mean?", correctAnswer: "קטן", distractors: ["גדול", "צר", "קצר"]),
        BankQuestion(prompt: "What does 'fast' mean?", correctAnswer: "מהיר", distractors: ["איטי", "חזק", "ארוך"]),
        BankQuestion(prompt: "What does 'cold' mean?", correctAnswer: "קר", distractors: ["חם", "ערב", "סגריר"]),
        BankQuestion(prompt: "What does 'hot' mean?", correctAnswer: "חם", distractors: ["קר", "נעים", "סוער"]),
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
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "כדורסל", distractors: ["תפוח", "בננה", "אגס"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "שולחן", distractors: ["כלב", "חתול", "אריה"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "אופניים", distractors: ["מכונית", "אוטובוס", "מטוס"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "אריה", distractors: ["דג", "כריש", "דולפין"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "אדום", distractors: ["שלוש", "חמש", "שבע"]),

        // Comparisons
        BankQuestion(prompt: "מה גדול יותר?", correctAnswer: "פיל", distractors: ["עכבר", "נמלה", "פרפר"]),
        BankQuestion(prompt: "מה קטן יותר?", correctAnswer: "נמלה", distractors: ["סוס", "כלב", "חתול"]),
        BankQuestion(prompt: "מה מהיר יותר?", correctAnswer: "מטוס", distractors: ["אופניים", "סירה", "רכבת"]),
        BankQuestion(prompt: "מה כבד יותר?", correctAnswer: "פיל", distractors: ["נוצה", "תפוח", "ספר"]),
        BankQuestion(prompt: "מה גבוה יותר?", correctAnswer: "ג'ירפה", distractors: ["כלב", "חתול", "תרנגול"]),

        // Riddles
        BankQuestion(prompt: "אני שותה אבל לא כוס. מה אני?", correctAnswer: "צמח", distractors: ["שולחן", "חלון", "ספר"]),
        BankQuestion(prompt: "יש לי ארבע רגליים אבל לא הולך. מי אני?", correctAnswer: "שולחן", distractors: ["סוס", "כלב", "צב"]),
        BankQuestion(prompt: "אני מאיר את הלילה אך אינני שמש. מי אני?", correctAnswer: "ירח", distractors: ["כוכב", "פנס", "מנורה"]),
        BankQuestion(prompt: "אני כתום ואני ירק. מי אני?", correctAnswer: "גזר", distractors: ["תפוח", "מלפפון", "תפוז"]),
        BankQuestion(prompt: "יש לי דפים אבל לא עץ. מי אני?", correctAnswer: "ספר", distractors: ["צמח", "פרח", "פירות"]),

        // Categories
        BankQuestion(prompt: "מה זה לא צבע?", correctAnswer: "שולחן", distractors: ["אדום", "כחול", "ירוק"]),
        BankQuestion(prompt: "מה זה לא בעל חיים?", correctAnswer: "מכונית", distractors: ["סוס", "כלב", "ציפור"]),
        BankQuestion(prompt: "מה זה לא פרי?", correctAnswer: "מלפפון", distractors: ["תפוח", "בננה", "תפוז"]),
        BankQuestion(prompt: "מה זה לא ירק?", correctAnswer: "תפוז", distractors: ["מלפפון", "גזר", "עגבנייה"]),
        BankQuestion(prompt: "מה זה לא יום?", correctAnswer: "ינואר", distractors: ["שני", "שלישי", "רביעי"]),

        // True/False patterns
        BankQuestion(prompt: "אם כל הכלבים נובחים, מה נובח?", correctAnswer: "כלב", distractors: ["חתול", "תרנגול", "פרה"]),
        BankQuestion(prompt: "אם 2+2=4, אז 3+3=?", correctAnswer: "6", distractors: ["5", "7", "8"]),
        BankQuestion(prompt: "מי בא אחרי 7?", correctAnswer: "8", distractors: ["6", "9", "10"]),
        BankQuestion(prompt: "מי בא לפני 5?", correctAnswer: "4", distractors: ["6", "3", "7"]),

        // Time
        BankQuestion(prompt: "כמה ימים בשבוע?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "כמה חודשים בשנה?", correctAnswer: "12", distractors: ["10", "11", "13"]),
        BankQuestion(prompt: "כמה שעות ביממה?", correctAnswer: "24", distractors: ["12", "18", "30"]),
        BankQuestion(prompt: "כמה דקות בשעה?", correctAnswer: "60", distractors: ["50", "100", "30"]),
        BankQuestion(prompt: "כמה שניות בדקה?", correctAnswer: "60", distractors: ["100", "30", "12"]),

        // Mirror/reverse
        BankQuestion(prompt: "מה ההפך של 'גדול'?", correctAnswer: "קטן", distractors: ["ארוך", "רחב", "גבוה"]),
        BankQuestion(prompt: "מה ההפך של 'חם'?", correctAnswer: "קר", distractors: ["טעים", "מתוק", "יבש"]),
        BankQuestion(prompt: "מה ההפך של 'מהיר'?", correctAnswer: "איטי", distractors: ["חזק", "ארוך", "כבד"]),
        BankQuestion(prompt: "מה ההפך של 'יום'?", correctAnswer: "לילה", distractors: ["בוקר", "ערב", "צהריים"]),
        BankQuestion(prompt: "מה ההפך של 'שמח'?", correctAnswer: "עצוב", distractors: ["מצחיק", "רגוע", "מבולבל"]),
        BankQuestion(prompt: "מה ההפך של 'ימין'?", correctAnswer: "שמאל", distractors: ["מעל", "מתחת", "מלפנים"]),
    ]

    // MARK: - מדע (~55 extra)

    static let science: [BankQuestion] = [
        BankQuestion(prompt: "🌱\nמה צמחים צריכים כדי לגדול?", correctAnswer: "שמש, מים ואדמה", distractors: ["אוויר ועוגה", "חול בלבד", "שלג בלבד"]),
        BankQuestion(prompt: "💧\nכמה אחוז מהאדמה מכוסה במים?", correctAnswer: "כ-71%", distractors: ["20%", "50%", "100%"]),
        BankQuestion(prompt: "🧊\nמה קורה למים כשהם מגיעים ל-0 מעלות?", correctAnswer: "הם קופאים", distractors: ["הם נעלמים", "הם רותחים", "הם משנים צבע"]),
        BankQuestion(prompt: "🌡️\nבאיזו טמפרטורה רותחים מים?", correctAnswer: "100°C", distractors: ["50°C", "200°C", "30°C"]),
        BankQuestion(prompt: "🌍\nכמה לוחות טקטוניים יש?", correctAnswer: "7 גדולים", distractors: ["3", "10", "20"]),
        BankQuestion(prompt: "🦴\nכמה עצמות יש בגוף מבוגר?", correctAnswer: "206", distractors: ["150", "100", "300"]),
        BankQuestion(prompt: "👀\nכמה צבעים יש בקשת?", correctAnswer: "7", distractors: ["5", "6", "10"]),
        BankQuestion(prompt: "🐅\nאיזה איבר משאיב את הדם?", correctAnswer: "הלב", distractors: ["הריאות", "הכבד", "המוח"]),
        BankQuestion(prompt: "🌬️\nבאיזה חומר אנחנו נושמים?", correctAnswer: "חמצן", distractors: ["מימן", "פחמן", "אוזון"]),
        BankQuestion(prompt: "🌙\nכמה זמן לוקח לירח להקיף את כדור הארץ?", correctAnswer: "כ-27 ימים", distractors: ["יום", "שנה", "100 ימים"]),
        BankQuestion(prompt: "☀️\nכמה זמן לאור השמש להגיע אלינו?", correctAnswer: "8 דקות", distractors: ["שנייה", "שעה", "יום"]),
        BankQuestion(prompt: "🪐\nאיזה כוכב לכת הכי גדול?", correctAnswer: "צדק", distractors: ["נוגה", "מאדים", "כדור הארץ"]),
        BankQuestion(prompt: "🌎\nכמה כוכבי לכת במערכת השמש?", correctAnswer: "8", distractors: ["7", "9", "10"]),
        BankQuestion(prompt: "🔴\nאיזה כוכב לכת אדום?", correctAnswer: "מאדים", distractors: ["נוגה", "צדק", "שבתאי"]),
        BankQuestion(prompt: "🌟\nמה הכי קרוב לכדור הארץ במערכת השמש?", correctAnswer: "הירח", distractors: ["מאדים", "נוגה", "השמש"]),
        BankQuestion(prompt: "🌳\nמה צמחים נושמים?", correctAnswer: "פחמן דו-חמצני", distractors: ["חמצן", "מים", "חנקן"]),
        BankQuestion(prompt: "🌳\nמה צמחים מוציאים?", correctAnswer: "חמצן", distractors: ["פחמן דו-חמצני", "אדים", "מימן"]),
        BankQuestion(prompt: "🐝\nאיך פרחים מקבלים אבקה?", correctAnswer: "דרך דבורים", distractors: ["דרך גשם", "דרך אדמה", "דרך שמש"]),
        BankQuestion(prompt: "❄️\nמה התכונה של קרח?", correctAnswer: "קר וקשה", distractors: ["חם ורך", "שקוף ונוזלי", "צהוב וריחני"]),
        BankQuestion(prompt: "🔥\nמה אש צריכה כדי לדלוק?", correctAnswer: "חמצן ודלק", distractors: ["מים בלבד", "חול", "קור"]),
        BankQuestion(prompt: "🌊\nמה גורם לגלים בים?", correctAnswer: "הרוח", distractors: ["דגים", "השמש", "ירח בלבד"]),
        BankQuestion(prompt: "🌜\nמה גורם לגאות ושפל?", correctAnswer: "הירח", distractors: ["הרוח", "השמש", "דגים"]),
        BankQuestion(prompt: "🦟\nכמה רגליים יש לחרק?", correctAnswer: "6", distractors: ["4", "8", "10"]),
        BankQuestion(prompt: "🕷️\nכמה רגליים יש לעכביש?", correctAnswer: "8", distractors: ["6", "4", "10"]),
        BankQuestion(prompt: "🐍\nנחשים הם...?", correctAnswer: "זוחלים", distractors: ["יונקים", "ציפורים", "דגים"]),
        BankQuestion(prompt: "🐬\nדולפינים הם...?", correctAnswer: "יונקים", distractors: ["דגים", "זוחלים", "ציפורים"]),
        BankQuestion(prompt: "🦇\nעטלפים הם...?", correctAnswer: "יונקים", distractors: ["ציפורים", "חרקים", "זוחלים"]),
        BankQuestion(prompt: "🐢\nצבים הם...?", correctAnswer: "זוחלים", distractors: ["יונקים", "דגים", "ציפורים"]),
        BankQuestion(prompt: "🌱\nאיזה חלק בצמח שואב מים?", correctAnswer: "השורש", distractors: ["העלה", "הפרח", "הגזע"]),
        BankQuestion(prompt: "☀️\nאיזה חלק בצמח מייצר אנרגיה מהשמש?", correctAnswer: "העלה", distractors: ["השורש", "הפרח", "האדמה"]),
        BankQuestion(prompt: "💪\nמה הכי חזק בגוף?", correctAnswer: "השרירים", distractors: ["העור", "השיער", "הציפורניים"]),
        BankQuestion(prompt: "🦷\nכמה שיניים יש למבוגר?", correctAnswer: "32", distractors: ["20", "28", "40"]),
        BankQuestion(prompt: "🧠\nאיזה איבר חושב?", correctAnswer: "המוח", distractors: ["הלב", "הכבד", "הריאות"]),
        BankQuestion(prompt: "👀\nכמה עיניים יש לדבורה?", correctAnswer: "5", distractors: ["2", "3", "8"]),
        BankQuestion(prompt: "🐌\nכמה לבבות יש לתמנון?", correctAnswer: "3", distractors: ["1", "2", "5"]),
        BankQuestion(prompt: "🦒\nאיזה חיה הכי גבוהה ביבשה?", correctAnswer: "ג'ירפה", distractors: ["פיל", "סוס", "בני אדם"]),
        BankQuestion(prompt: "🐋\nאיזה חיה הכי גדולה בעולם?", correctAnswer: "לוויתן כחול", distractors: ["פיל", "כריש", "ג'ירפה"]),
        BankQuestion(prompt: "🐆\nאיזה חיה הכי מהירה?", correctAnswer: "ברדלס", distractors: ["סוס", "נמר", "אריה"]),
        BankQuestion(prompt: "⚡\nאיך נקרא רעם וברק יחד?", correctAnswer: "סופת רעמים", distractors: ["סופת חול", "טורנדו", "סופה ירוקה"]),
        BankQuestion(prompt: "🌫\nמה זה ערפל?", correctAnswer: "ענן קרוב לקרקע", distractors: ["גשם קל", "אבק", "עשן"]),
        BankQuestion(prompt: "🌋\nמה יוצא מהר געש?", correctAnswer: "לבה", distractors: ["מים", "חול", "ענן"]),
        BankQuestion(prompt: "🌊\nאיך נקרא גל ענק בים?", correctAnswer: "צונאמי", distractors: ["טורנדו", "סערה", "ערפל"]),
        BankQuestion(prompt: "💎\nאיזה חומר הכי קשה בטבע?", correctAnswer: "יהלום", distractors: ["ברזל", "אבן", "זכוכית"]),
        BankQuestion(prompt: "🧲\nמה מושך מתכת?", correctAnswer: "מגנט", distractors: ["מים", "אבן", "פלסטיק"]),
        BankQuestion(prompt: "🔦\nאיך נע אור?", correctAnswer: "בקו ישר", distractors: ["במעגלים", "בעיקולים", "בלי תנועה"]),
        BankQuestion(prompt: "👂\nאיך אנחנו שומעים?", correctAnswer: "דרך גלי קול", distractors: ["דרך גלי אור", "דרך מגע", "דרך ריח"]),
        BankQuestion(prompt: "🌈\nכמה צבעים בקשת?", correctAnswer: "7", distractors: ["5", "8", "10"]),
        BankQuestion(prompt: "🌳\nמה הצמח הכי גבוה בעולם?", correctAnswer: "סקויה", distractors: ["אלון", "אקליפטוס", "תמר"]),
        BankQuestion(prompt: "💨\nמה חומרים שמתפשטים מהר?", correctAnswer: "גזים", distractors: ["נוזלים", "מוצקים", "אבק"]),
        BankQuestion(prompt: "🌧\nמהם שלושת מצבי הצבירה?", correctAnswer: "מוצק, נוזל, גז", distractors: ["חם, קר, פושר", "אבן, מים, אוויר", "אחד, שניים, שלוש"]),
        BankQuestion(prompt: "🐦\nמה ההבדל בין ציפור לטיסה?", correctAnswer: "כנפיים", distractors: ["שיניים", "זנב", "פרווה"]),
        BankQuestion(prompt: "🌳\nאיזה גז העצים פולטים?", correctAnswer: "חמצן", distractors: ["פחמן", "מימן", "חנקן"]),
        BankQuestion(prompt: "🦠\nמה זה חיידק?", correctAnswer: "יצור חי קטנטן", distractors: ["סוג של ירק", "סוג של מתכת", "סוג של אבן"]),
        BankQuestion(prompt: "🌍\nאיזה כוח מושך אותנו לאדמה?", correctAnswer: "כוח הכובד", distractors: ["מגנט", "רוח", "אור"]),
    ]

    // MARK: - היסטוריה (~45 extra)

    static let history: [BankQuestion] = [
        BankQuestion(prompt: "🏺\nאיזו ציוויליזציה בנתה את הפירמידות?", correctAnswer: "המצרים העתיקים", distractors: ["הרומאים", "היוונים", "הוויקינגים"]),
        BankQuestion(prompt: "👑\nמי היה הקיסר הראשון של רומא?", correctAnswer: "אוגוסטוס", distractors: ["יוליוס קיסר", "נירון", "אדריאנוס"]),
        BankQuestion(prompt: "⚔️\nמי כבש את ארץ ישראל ב-70 לספירה?", correctAnswer: "הרומאים", distractors: ["היוונים", "הבבלים", "הפרסים"]),
        BankQuestion(prompt: "✡️\nמה השם של מנהיג העם בצאת מצרים?", correctAnswer: "משה", distractors: ["דוד", "שלמה", "אברהם"]),
        BankQuestion(prompt: "🏛️\nאיפה התקיים הכנסת הראשונה?", correctAnswer: "ירושלים", distractors: ["תל אביב", "חיפה", "באר שבע"]),
        BankQuestion(prompt: "🎺\nמה גרם לחומות יריחו לנפול?", correctAnswer: "תרועת השופר", distractors: ["רעידת אדמה", "סופת חול", "מבול"]),
        BankQuestion(prompt: "🏰\nמי בנה את בית המקדש הראשון?", correctAnswer: "שלמה המלך", distractors: ["דוד המלך", "שאול המלך", "חזקיהו"]),
        BankQuestion(prompt: "⚖️\nמי מלך אחרי דוד?", correctAnswer: "שלמה", distractors: ["שאול", "ירבעם", "רחבעם"]),
        BankQuestion(prompt: "🦁\nמי שלח את דניאל לגוב האריות?", correctAnswer: "המלך דריווש", distractors: ["נבוכדנצר", "אחשורוש", "כורש"]),
        BankQuestion(prompt: "👑\nמי הייתה אסתר המלכה?", correctAnswer: "מלכת פרס", distractors: ["מלכת מצרים", "מלכת בבל", "מלכת רומא"]),
        BankQuestion(prompt: "📜\nמה השפה של התנ\"ך?", correctAnswer: "עברית", distractors: ["יוונית", "ארמית", "ערבית"]),
        BankQuestion(prompt: "🛤️\nמתי הוקמה מדינת ישראל?", correctAnswer: "1948", distractors: ["1917", "1967", "1973"]),
        BankQuestion(prompt: "📜\nמי הקריא את הכרזת העצמאות?", correctAnswer: "דוד בן-גוריון", distractors: ["חיים וייצמן", "מנחם בגין", "גולדה מאיר"]),
        BankQuestion(prompt: "🇮🇱\nאיפה הוקמה מדינת ישראל?", correctAnswer: "תל אביב", distractors: ["ירושלים", "חיפה", "טבריה"]),
        BankQuestion(prompt: "👵\nמי הייתה ראשת הממשלה האישה הראשונה?", correctAnswer: "גולדה מאיר", distractors: ["שולמית אלוני", "ציפי לבני", "מירי רגב"]),
        BankQuestion(prompt: "🦅\nאיזה סמל יש על דגל ישראל?", correctAnswer: "מגן דוד", distractors: ["אריה", "נשר", "ענף זית"]),
        BankQuestion(prompt: "🇺🇸\nמתי הוקמה ארה\"ב?", correctAnswer: "1776", distractors: ["1620", "1492", "1800"]),
        BankQuestion(prompt: "🧭\nמי גילה את אמריקה ב-1492?", correctAnswer: "כריסטופר קולומבוס", distractors: ["מגלן", "וסקו דה גמה", "מרקו פולו"]),
        BankQuestion(prompt: "🚀\nמי היה האדם הראשון על הירח?", correctAnswer: "ניל ארמסטרונג", distractors: ["יורי גגארין", "באז אולדרין", "ג'ון גלן"]),
        BankQuestion(prompt: "🚀\nמי היה האדם הראשון בחלל?", correctAnswer: "יורי גגארין", distractors: ["ניל ארמסטרונג", "אלן שפרד", "באז אולדרין"]),
        BankQuestion(prompt: "🎨\nמי צייר את המונה ליזה?", correctAnswer: "לאונרדו דה וינצ'י", distractors: ["מיכלאנג'לו", "פיקאסו", "ון גוך"]),
        BankQuestion(prompt: "🎼\nמי כתב את 'אלוהי הקטנים'?", correctAnswer: "מוצרט", distractors: ["בטהובן", "באך", "שופן"]),
        BankQuestion(prompt: "💡\nמי המציא את הנורה?", correctAnswer: "תומס אדיסון", distractors: ["איינשטיין", "ניוטון", "בל"]),
        BankQuestion(prompt: "📞\nמי המציא את הטלפון?", correctAnswer: "אלכסנדר גרהם בל", distractors: ["אדיסון", "מארקוני", "ניוטון"]),
        BankQuestion(prompt: "🌌\nמי גילה את כוח הכובד?", correctAnswer: "ניוטון", distractors: ["איינשטיין", "גלילאו", "קופרניקוס"]),
        BankQuestion(prompt: "🧪\nמי גילה את הפניצילין?", correctAnswer: "פלמינג", distractors: ["פסטר", "אדיסון", "מארי קירי"]),
        BankQuestion(prompt: "👩‍🔬\nמי הייתה האישה הראשונה שזכתה בפרס נובל?", correctAnswer: "מארי קירי", distractors: ["איינשטיין", "פלמינג", "ניוטון"]),
        BankQuestion(prompt: "🏛️\nאיזו מדינה נחשבת לעריסת הדמוקרטיה?", correctAnswer: "יוון", distractors: ["רומא", "מצרים", "סין"]),
        BankQuestion(prompt: "📜\nמה הטקסט העתיק ביותר בעולם?", correctAnswer: "אפוס גלגמש", distractors: ["התנ\"ך", "האודיסיאה", "האיליאדה"]),
        BankQuestion(prompt: "🏯\nאיפה בנו את החומה הסינית הגדולה?", correctAnswer: "סין", distractors: ["יפן", "קוריאה", "הודו"]),
        BankQuestion(prompt: "🗡️\nמי היה מנהיג הצבא של נפוליאון?", correctAnswer: "נפוליאון בעצמו", distractors: ["וושינגטון", "צ'רצ'יל", "ביסמרק"]),
        BankQuestion(prompt: "👑\nמי הייתה המלכה אליזבת הראשונה?", correctAnswer: "מלכת אנגליה", distractors: ["מלכת צרפת", "מלכת ספרד", "מלכת רוסיה"]),
        BankQuestion(prompt: "🇪🇬\nמי הייתה קליאופטרה?", correctAnswer: "מלכת מצרים", distractors: ["מלכת רומא", "מלכת יוון", "מלכת בבל"]),
        BankQuestion(prompt: "⚔️\nמתי החלה מלחמת העולם הראשונה?", correctAnswer: "1914", distractors: ["1900", "1939", "1918"]),
        BankQuestion(prompt: "⚔️\nמתי הסתיימה מלחמת העולם השנייה?", correctAnswer: "1945", distractors: ["1918", "1939", "1950"]),
        BankQuestion(prompt: "🌐\nמתי הומצא האינטרנט?", correctAnswer: "1960-1970", distractors: ["1900", "1950", "2000"]),
        BankQuestion(prompt: "📱\nמתי הומצא הסמארטפון הראשון?", correctAnswer: "2007 (iPhone)", distractors: ["1990", "2000", "2015"]),
        BankQuestion(prompt: "🚂\nמי המציא את הקטר?", correctAnswer: "ג'ורג' סטיבנסון", distractors: ["וואט", "אדיסון", "פורד"]),
        BankQuestion(prompt: "🚗\nמי המציא את הרכב?", correctAnswer: "קארל בנץ", distractors: ["פורד", "אדיסון", "וואט"]),
        BankQuestion(prompt: "✈️\nמי המציאו את המטוס?", correctAnswer: "האחים רייט", distractors: ["איינשטיין", "אדיסון", "וואט"]),
        BankQuestion(prompt: "🇮🇱\nמה היה השם של ארץ ישראל לפני 1948?", correctAnswer: "פלשתינה (תחת המנדט)", distractors: ["ישראל", "ארץ הקודש", "כנען"]),
        BankQuestion(prompt: "🇮🇱\nמה תפקיד הנשיא בישראל?", correctAnswer: "ייצוגי", distractors: ["מנהל המדינה", "מפקד הצבא", "ראש בית המשפט"]),
        BankQuestion(prompt: "🏛️\nכמה חברי כנסת יש בישראל?", correctAnswer: "120", distractors: ["100", "150", "200"]),
        BankQuestion(prompt: "👴\nמי היה רא\"ל הראשון של צה\"ל?", correctAnswer: "יעקב דורי", distractors: ["דוד בן-גוריון", "משה דיין", "יצחק רבין"]),
        BankQuestion(prompt: "🎖️\nאיזה צבע הברט של חיל האוויר?", correctAnswer: "כחול", distractors: ["אדום", "שחור", "ירוק"]),
    ]

    // MARK: - גיאוגרפיה (~50 extra)

    static let geography: [BankQuestion] = [
        BankQuestion(prompt: "🇫🇷\nמה בירת צרפת?", correctAnswer: "פריז", distractors: ["מארסיי", "ליון", "ניס"]),
        BankQuestion(prompt: "🇩🇪\nמה בירת גרמניה?", correctAnswer: "ברלין", distractors: ["מינכן", "המבורג", "פרנקפורט"]),
        BankQuestion(prompt: "🇺🇸\nמה בירת ארצות הברית?", correctAnswer: "וושינגטון", distractors: ["ניו יורק", "לוס אנג'לס", "שיקגו"]),
        BankQuestion(prompt: "🇨🇦\nמה בירת קנדה?", correctAnswer: "אוטווה", distractors: ["טורונטו", "ונקובר", "מונטריאול"]),
        BankQuestion(prompt: "🇧🇷\nמה בירת ברזיל?", correctAnswer: "ברזיליה", distractors: ["ריו דה ז'ניירו", "סאו פאולו", "סלבדור"]),
        BankQuestion(prompt: "🇦🇺\nמה בירת אוסטרליה?", correctAnswer: "קנברה", distractors: ["סידני", "מלבורן", "פרת'"]),
        BankQuestion(prompt: "🇷🇺\nמה בירת רוסיה?", correctAnswer: "מוסקבה", distractors: ["סנקט פטרבורג", "קייב", "מינסק"]),
        BankQuestion(prompt: "🇨🇳\nמה בירת סין?", correctAnswer: "בייג'ינג", distractors: ["שנגחאי", "הונג קונג", "טיוואן"]),
        BankQuestion(prompt: "🇮🇳\nמה בירת הודו?", correctAnswer: "ניו דלהי", distractors: ["מומבאי", "בנגלור", "כלכותה"]),
        BankQuestion(prompt: "🇲🇽\nמה בירת מקסיקו?", correctAnswer: "מקסיקו סיטי", distractors: ["קנקון", "גוודלחרה", "מונטריי"]),
        BankQuestion(prompt: "🇦🇷\nמה בירת ארגנטינה?", correctAnswer: "בואנוס איירס", distractors: ["סנטיאגו", "מונטווידאו", "לימה"]),
        BankQuestion(prompt: "🇪🇬\nמה בירת מצרים?", correctAnswer: "קהיר", distractors: ["אלכסנדריה", "לוקסור", "אסואן"]),
        BankQuestion(prompt: "🇿🇦\nמה בירת דרום אפריקה?", correctAnswer: "פרטוריה", distractors: ["קייפ טאון", "יוהנסבורג", "דרבן"]),
        BankQuestion(prompt: "🇹🇷\nמה בירת טורקיה?", correctAnswer: "אנקרה", distractors: ["איסטנבול", "איזמיר", "בורסה"]),
        BankQuestion(prompt: "🇸🇦\nמה בירת סעודיה?", correctAnswer: "ריאד", distractors: ["מכה", "ג'דה", "מדינה"]),
        BankQuestion(prompt: "🇦🇪\nמה בירת איחוד האמירויות?", correctAnswer: "אבו דאבי", distractors: ["דובאי", "שארג'ה", "עג'מאן"]),
        BankQuestion(prompt: "🇰🇷\nמה בירת קוריאה הדרומית?", correctAnswer: "סיאול", distractors: ["בוסאן", "אינצ'ון", "פיונגיאנג"]),

        // Israel
        BankQuestion(prompt: "🇮🇱\nמה הים המלוח ביותר בעולם?", correctAnswer: "ים המלח", distractors: ["הכינרת", "הים התיכון", "ים סוף"]),
        BankQuestion(prompt: "🇮🇱\nמה אגם המים המתוקים הגדול בישראל?", correctAnswer: "הכינרת", distractors: ["ים המלח", "אגם מונפורט", "ים סוף"]),
        BankQuestion(prompt: "🇮🇱\nמה ההר הגבוה בישראל?", correctAnswer: "החרמון", distractors: ["מירון", "תבור", "כרמל"]),
        BankQuestion(prompt: "🇮🇱\nמה הנהר הארוך בישראל?", correctAnswer: "הירדן", distractors: ["הירקון", "הקישון", "האלכסנדר"]),
        BankQuestion(prompt: "🇮🇱\nאיזו עיר נמצאת על שפת ים המלח?", correctAnswer: "ערד", distractors: ["נצרת", "צפת", "אילת"]),
        BankQuestion(prompt: "🇮🇱\nאיזו עיר היא הדרומית ביותר בישראל?", correctAnswer: "אילת", distractors: ["באר שבע", "ערד", "דימונה"]),
        BankQuestion(prompt: "🇮🇱\nאיזו עיר היא הצפונית ביותר?", correctAnswer: "מטולה", distractors: ["קריית שמונה", "צפת", "טבריה"]),
        BankQuestion(prompt: "🇮🇱\nאיזו עיר היא בירת ישראל?", correctAnswer: "ירושלים", distractors: ["תל אביב", "חיפה", "באר שבע"]),
        BankQuestion(prompt: "🇮🇱\nכמה מחוזות יש בישראל?", correctAnswer: "6", distractors: ["4", "5", "8"]),
        BankQuestion(prompt: "🇮🇱\nאיזה ים נמצא במערב ישראל?", correctAnswer: "הים התיכון", distractors: ["ים סוף", "ים המלח", "האוקיינוס"]),
        BankQuestion(prompt: "🇮🇱\nאיזה ים נמצא בדרום ישראל?", correctAnswer: "ים סוף", distractors: ["הים התיכון", "ים המלח", "הים הים"]),
        BankQuestion(prompt: "🇮🇱\nאיזו מדינה גובלת עם ישראל מצפון?", correctAnswer: "לבנון", distractors: ["מצרים", "סוריה", "ירדן"]),
        BankQuestion(prompt: "🇮🇱\nאיזו מדינה גובלת עם ישראל ממזרח?", correctAnswer: "ירדן", distractors: ["לבנון", "מצרים", "סוריה"]),
        BankQuestion(prompt: "🇮🇱\nאיזו מדינה גובלת עם ישראל מדרום?", correctAnswer: "מצרים", distractors: ["סודן", "סוריה", "סעודיה"]),

        // Continents & oceans
        BankQuestion(prompt: "🌎\nכמה אוקיינוסים יש בעולם?", correctAnswer: "5", distractors: ["3", "4", "7"]),
        BankQuestion(prompt: "🌊\nאיזה אוקיינוס הוא הגדול ביותר?", correctAnswer: "השקט", distractors: ["האטלנטי", "ההודי", "הארקטי"]),
        BankQuestion(prompt: "🌍\nמה היבשת הקטנה ביותר?", correctAnswer: "אוסטרליה", distractors: ["אירופה", "אנטארקטיקה", "אפריקה"]),
        BankQuestion(prompt: "🐧\nאיזו יבשת היא הקרה ביותר?", correctAnswer: "אנטארקטיקה", distractors: ["אסיה", "אירופה", "אמריקה"]),
        BankQuestion(prompt: "🦒\nאיזו יבשת היא הכי חמה (ממוצע)?", correctAnswer: "אפריקה", distractors: ["אסיה", "אוסטרליה", "אמריקה"]),
        BankQuestion(prompt: "🌍\nאיזו יבשת היא בעלת מספר המדינות הגדול ביותר?", correctAnswer: "אפריקה", distractors: ["אסיה", "אירופה", "אמריקה"]),

        // Notable landmarks
        BankQuestion(prompt: "🗼\nמגדל אייפל נמצא ב...?", correctAnswer: "פריז", distractors: ["לונדון", "רומא", "ברלין"]),
        BankQuestion(prompt: "🗽\nפסל החירות נמצא ב...?", correctAnswer: "ניו יורק", distractors: ["וושינגטון", "שיקגו", "מיאמי"]),
        BankQuestion(prompt: "🗿\nפסלי מואי נמצאים ב...?", correctAnswer: "אי הפסחא", distractors: ["מקסיקו", "פרו", "אינדונזיה"]),
        BankQuestion(prompt: "🏯\nהחומה הסינית הגדולה נמצאת ב...?", correctAnswer: "סין", distractors: ["יפן", "קוריאה", "מונגוליה"]),
        BankQuestion(prompt: "🕌\nמרכז התפילה למוסלמים?", correctAnswer: "מכה", distractors: ["מדינה", "ירושלים", "קהיר"]),
        BankQuestion(prompt: "🕍\nמרכז התפילה ליהודים?", correctAnswer: "ירושלים", distractors: ["טבריה", "צפת", "תל אביב"]),
        BankQuestion(prompt: "⛪\nאיפה בית הכנסיה של אפיפיור?", correctAnswer: "ותיקן", distractors: ["רומא", "פריז", "לונדון"]),

        // Rivers & lakes
        BankQuestion(prompt: "🌊\nאיזה נהר הוא הארוך ביותר באפריקה?", correctAnswer: "הנילוס", distractors: ["הקונגו", "הניז'ר", "הזמבזי"]),
        BankQuestion(prompt: "🌊\nאיזה נהר הוא הארוך ביותר בדרום אמריקה?", correctAnswer: "האמזונס", distractors: ["הפראנה", "הפרגוואי", "האורינוקו"]),
        BankQuestion(prompt: "🌊\nאיזה נהר הוא הארוך ביותר באירופה?", correctAnswer: "הוולגה", distractors: ["הדנובה", "הריין", "הסיינה"]),
        BankQuestion(prompt: "🏔️\nאיזה הר נמצא בצרפת?", correctAnswer: "האלפים (חלקם)", distractors: ["האוורסט", "ההימלאיה", "האנדים"]),
        BankQuestion(prompt: "🏔️\nאיזה הר נמצא בדרום אמריקה?", correctAnswer: "האנדים", distractors: ["האלפים", "ההימלאיה", "האוראליים"]),
    ]

    // MARK: - Aggregate

    static func extras(for topic: Topic) -> [BankQuestion] {
        switch topic {
        case .english:   return english
        case .logic:     return logic
        case .science:   return science
        case .history:   return history
        case .geography: return geography
        case .math:      return []
        }
    }
}
