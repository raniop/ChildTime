import Foundation

/// 🌍 Flags & Countries — English (US). Adapted from QuestionBanksFlags (Hebrew).
/// Timeless facts only: flags, capitals, continents, oceans, landmarks, currencies.
extension EnglishContent {
    static let flags: [BankQuestion] = [
        // ── Easy · famous flags ──
        BankQuestion(prompt: "🇺🇸\nWhich country has the flag with stars and stripes?", correctAnswer: "United States", distractors: ["Canada", "United Kingdom", "Australia"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇪🇸\nWhich country has this red and yellow striped flag?", correctAnswer: "Spain", distractors: ["Italy", "France", "Portugal"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇫🇷\nWhich country has this blue, white, and red flag?", correctAnswer: "France", distractors: ["Italy", "Germany", "Spain"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇮🇹\nWhich country has this green, white, and red flag?", correctAnswer: "Italy", distractors: ["France", "Spain", "Greece"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇯🇵\nWhich country has the flag with a red circle?", correctAnswer: "Japan", distractors: ["China", "India", "Thailand"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇨🇦\nWhich country has the flag with a red leaf?", correctAnswer: "Canada", distractors: ["United States", "Switzerland", "Japan"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇧🇷\nWhich country has this green and yellow flag?", correctAnswer: "Brazil", distractors: ["Portugal", "Argentina", "Mexico"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇬🇧\nWhich country has this flag?", correctAnswer: "United Kingdom", distractors: ["France", "Norway", "United States"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇩🇪\nWhich country has this black, red, and yellow flag?", correctAnswer: "Germany", distractors: ["Netherlands", "Austria", "Spain"], tier: .easy, grades: 3...4),

        // ── Easy · famous landmarks ──
        BankQuestion(prompt: "🗼\nIn which country is the Eiffel Tower?", correctAnswer: "France", distractors: ["Italy", "England", "Spain"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🐪\nIn which country are the famous pyramids of Giza?", correctAnswer: "Egypt", distractors: ["Greece", "Morocco", "Turkey"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🗽\nIn which country is the Statue of Liberty?", correctAnswer: "United States", distractors: ["England", "Canada", "Brazil"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🧱\nIn which country is the Great Wall, which is thousands of miles long?", correctAnswer: "China", distractors: ["Japan", "India", "Russia"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🕰️\nIn which country is Big Ben?", correctAnswer: "England", distractors: ["France", "Germany", "Italy"], tier: .easy, grades: 3...4),

        // ── Easy · capital cities ──
        BankQuestion(prompt: "🌮\nWhat is the capital of Mexico?", correctAnswer: "Mexico City", distractors: ["Cancún", "Madrid", "Lima"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🥐\nWhat is the capital of France?", correctAnswer: "Paris", distractors: ["London", "Rome", "Madrid"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🍕\nWhat is the capital of Italy?", correctAnswer: "Rome", distractors: ["Milan", "Paris", "Athens"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🎡\nWhat is the capital of England?", correctAnswer: "London", distractors: ["Paris", "Berlin", "Dublin"], tier: .easy, grades: 3...4),

        // ── Easy · continents and oceans ──
        BankQuestion(prompt: "🌎\nWhich continent is the United States on?", correctAnswer: "North America", distractors: ["South America", "Europe", "Asia"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nHow many continents do we usually learn about?", correctAnswer: "7", distractors: ["5", "6", "9"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌊\nHow many oceans are there, counting the Southern Ocean?", correctAnswer: "5", distractors: ["3", "4", "7"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nWhich continent is France on?", correctAnswer: "Europe", distractors: ["Asia", "Africa", "Australia"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌍\nWhich continent is Egypt on?", correctAnswer: "Africa", distractors: ["Europe", "South America", "Australia"], tier: .easy, grades: 3...4),

        // ── Easy · colors and symbols on the US flag ──
        BankQuestion(prompt: "🇺🇸\nWhat colors are on the US flag?", correctAnswer: "Red, white, and blue", distractors: ["Red and white", "Blue and white", "Green, white, and red"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🇺🇸\nWhat are the white shapes on the blue part of the US flag?", correctAnswer: "Stars", distractors: ["Circles", "Moons", "Leaves"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "⭐\nHow many stars are on the US flag?", correctAnswer: "50", distractors: ["13", "52", "100"], tier: .easy, grades: 3...4),

        // ── Easy · languages ──
        BankQuestion(prompt: "🗣️\nWhat language do people speak in France?", correctAnswer: "French", distractors: ["Spanish", "Italian", "German"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🗣️\nWhat language do most people speak in Mexico?", correctAnswer: "Spanish", distractors: ["Portuguese", "French", "Italian"], tier: .easy, grades: 3...4),

        // ── Medium · more flags ──
        BankQuestion(prompt: "🇨🇳\nWhich country has the red flag with 5 yellow stars?", correctAnswer: "China", distractors: ["Japan", "South Korea", "Thailand"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇦🇺\nWhich country has this flag?", correctAnswer: "Australia", distractors: ["United Kingdom", "Canada", "United States"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇲🇽\nWhich country has the flag with an eagle in the middle?", correctAnswer: "Mexico", distractors: ["Brazil", "Spain", "Argentina"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇦🇷\nWhich country has the light blue and white flag with a sun?", correctAnswer: "Argentina", distractors: ["Brazil", "Mexico", "Portugal"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇬🇷\nWhich country has the blue and white flag with stripes and a cross?", correctAnswer: "Greece", distractors: ["Turkey", "Italy", "Spain"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇹🇷\nWhich country has the red flag with a crescent moon and a star?", correctAnswer: "Turkey", distractors: ["Greece", "Morocco", "Egypt"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇷🇺\nWhich country has this white, blue, and red flag?", correctAnswer: "Russia", distractors: ["Portugal", "Poland", "Greece"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇰🇷\nWhich country has the flag with a red and blue circle?", correctAnswer: "South Korea", distractors: ["Japan", "China", "Thailand"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇮🇳\nWhich country has the orange, white, and green flag with a wheel?", correctAnswer: "India", distractors: ["China", "Japan", "Egypt"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇨🇭\nWhich country has the red flag with a white cross?", correctAnswer: "Switzerland", distractors: ["Sweden", "Belgium", "Poland"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇪🇬\nWhich country has the red, white, and black flag with a golden eagle?", correctAnswer: "Egypt", distractors: ["Turkey", "Morocco", "Greece"], tier: .medium, grades: 4...5),

        // ── Medium · capital cities ──
        BankQuestion(prompt: "🏙️\nWhat is the capital of Spain?", correctAnswer: "Madrid", distractors: ["Barcelona", "Lisbon", "Rome"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nWhat is the capital of Germany?", correctAnswer: "Berlin", distractors: ["Munich", "Vienna", "Paris"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nWhat is the capital of Japan?", correctAnswer: "Tokyo", distractors: ["Beijing", "Seoul", "Osaka"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nWhat is the capital of Russia?", correctAnswer: "Moscow", distractors: ["Saint Petersburg", "Warsaw", "Berlin"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nWhat is the capital of China?", correctAnswer: "Beijing", distractors: ["Shanghai", "Tokyo", "Seoul"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏙️\nWhat is the capital of the United States?", correctAnswer: "Washington, D.C.", distractors: ["New York City", "Los Angeles", "Chicago"], tier: .medium, grades: 4...5),

        // ── Medium · biggest, continents and neighbors ──
        BankQuestion(prompt: "🌏\nWhat is the largest continent in the world?", correctAnswer: "Asia", distractors: ["Africa", "Europe", "North America"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🗺️\nWhat is the largest country in the world by area?", correctAnswer: "Russia", distractors: ["China", "Canada", "United States"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🌊\nWhat is the largest ocean in the world?", correctAnswer: "Pacific Ocean", distractors: ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🌎\nWhich continent is Brazil on?", correctAnswer: "South America", distractors: ["North America", "Africa", "Europe"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nWhich country borders the United States to the north?", correctAnswer: "Canada", distractors: ["Mexico", "Brazil", "Japan"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nWhich country borders the United States to the south?", correctAnswer: "Mexico", distractors: ["Canada", "Brazil", "Argentina"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧭\nWhich ocean is along the east coast of the United States?", correctAnswer: "Atlantic Ocean", distractors: ["Pacific Ocean", "Indian Ocean", "Arctic Ocean"], tier: .medium, grades: 4...5),

        // ── Medium · currencies and symbols ──
        BankQuestion(prompt: "💶\nWhat money do people use in France, Germany, and Italy?", correctAnswer: "Euro", distractors: ["Dollar", "Yen", "Peso"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "💵\nWhat is the money of the United States called?", correctAnswer: "Dollar", distractors: ["Euro", "Yen", "Peso"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇨🇦\nWhich leaf is on the flag of Canada?", correctAnswer: "Maple leaf", distractors: ["Olive leaf", "Palm leaf", "Oak leaf"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🇯🇵\nWhat does the red circle on the flag of Japan stand for?", correctAnswer: "The sun", distractors: ["The moon", "A ball", "A flower"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "⭐\nWhat does each star on the US flag stand for?", correctAnswer: "One state", distractors: ["One president", "One city", "One river"], tier: .medium, grades: 4...5),

        // ── Hard · less familiar flags ──
        BankQuestion(prompt: "🇸🇪\nWhich country has the blue flag with a yellow cross?", correctAnswer: "Sweden", distractors: ["Norway", "Finland", "Denmark"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇩🇰\nWhich country has the red flag with a white cross moved to one side?", correctAnswer: "Denmark", distractors: ["Sweden", "Finland", "Poland"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇵🇹\nWhich country has this green and red flag with a shield?", correctAnswer: "Portugal", distractors: ["Spain", "Italy", "Morocco"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇿🇦\nWhich country has this colorful flag with a sideways Y shape?", correctAnswer: "South Africa", distractors: ["Kenya", "Nigeria", "Egypt"], tier: .hard, grades: 5...6),

        // ── Hard · surprising capitals ──
        BankQuestion(prompt: "🦘\nWhat is the capital of Australia?", correctAnswer: "Canberra", distractors: ["Sydney", "Melbourne", "Perth"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🍁\nWhat is the capital of Canada?", correctAnswer: "Ottawa", distractors: ["Toronto", "Vancouver", "Montreal"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🏙️\nWhat is the capital of Brazil?", correctAnswer: "Brasília", distractors: ["Rio de Janeiro", "São Paulo", "Lisbon"], tier: .hard, grades: 5...6),

        // ── Hard · records, languages and currencies ──
        BankQuestion(prompt: "🌏\nWhat is the smallest continent in the world?", correctAnswer: "Australia", distractors: ["Europe", "Antarctica", "Africa"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "⛪\nWhat is the smallest country in the world?", correctAnswer: "Vatican City", distractors: ["Monaco", "Malta", "Luxembourg"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🧊\nWhich continent is almost all covered in ice and has no countries?", correctAnswer: "Antarctica", distractors: ["Australia", "Europe", "North America"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🗣️\nWhat language do people speak in Brazil?", correctAnswer: "Portuguese", distractors: ["Spanish", "French", "Italian"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "💴\nWhat is the money of Japan called?", correctAnswer: "Yen", distractors: ["Dollar", "Yuan", "Euro"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "💷\nWhat is the money of the United Kingdom called?", correctAnswer: "Pound", distractors: ["Euro", "Dollar", "Franc"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇺🇸\nHow many stripes are on the US flag?", correctAnswer: "13", distractors: ["50", "10", "15"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🇺🇸\nWhat do the 13 stripes on the US flag stand for?", correctAnswer: "The 13 original colonies", distractors: ["The first 13 presidents", "The 13 biggest cities", "The 13 longest rivers"], tier: .hard, grades: 5...6),
    ]
}
