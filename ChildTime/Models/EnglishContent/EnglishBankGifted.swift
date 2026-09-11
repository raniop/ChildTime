import Foundation

/// 🧠 Gifted prep — English (US). Adapted from QuestionBanksGifted (Hebrew).
/// Reasoning puzzles: number series, letter/shape patterns, analogies, odd-one-out,
/// single-answer logic riddles, spatial reasoning and two-step word problems.
/// Hebrew-alphabet series were rebuilt on the English alphabet; shekels became dollars.
extension EnglishContent {
    static let gifted: [BankQuestion] = [
        // ── Easy · number series ──
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 2, 4, 6, 8, ?", correctAnswer: "10", distractors: ["9", "11", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🖐️\nWhat number comes next in the series: 5, 10, 15, 20, ?", correctAnswer: "25", distractors: ["21", "24", "30"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 1, 3, 5, 7, ?", correctAnswer: "9", distractors: ["8", "10", "11"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "⬇️\nWhat number comes next in the series: 10, 9, 8, 7, ?", correctAnswer: "6", distractors: ["5", "4", "11"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 3, 6, 9, 12, ?", correctAnswer: "15", distractors: ["13", "14", "16"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✨\nWhat number comes next in the series: 1, 2, 4, 8, ?", correctAnswer: "16", distractors: ["10", "12", "14"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💯\nWhat number comes next in the series: 100, 90, 80, 70, ?", correctAnswer: "60", distractors: ["65", "50", "69"], tier: .easy, grades: 2...3),

        // ── Easy · analogies ──
        BankQuestion(prompt: "🧤\nHand is to glove as foot is to ___?", correctAnswer: "Shoe", distractors: ["Hat", "Shirt", "Scarf"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐦\nBird is to sky as fish is to ___?", correctAnswer: "Sea", distractors: ["Tree", "Desert", "Mountain"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐄\nCow is to milk as chicken is to ___?", correctAnswer: "Egg", distractors: ["Wool", "Honey", "Cheese"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐘\nBig is to small as hot is to ___?", correctAnswer: "Cold", distractors: ["Warm", "Wet", "Tall"], tier: .easy, grades: 2...3),

        // ── Easy · odd one out ──
        BankQuestion(prompt: "🤔\nWhich one does not belong: apple, banana, carrot, pear?", correctAnswer: "Carrot", distractors: ["Apple", "Banana", "Pear"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎨\nWhich one does not belong: red, blue, round, green?", correctAnswer: "Round", distractors: ["Red", "Blue", "Green"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🤔\nWhich one does not belong: Sunday, Monday, January, Tuesday?", correctAnswer: "January", distractors: ["Sunday", "Monday", "Tuesday"], tier: .easy, grades: 2...3),

        // ── Easy · letter and shape patterns ──
        BankQuestion(prompt: "🔤\nWhat letter comes next in the series: A, B, C, D, ?", correctAnswer: "E", distractors: ["F", "G", "H"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🔤\nWhat letter comes next in the series: A, C, E, G, ?", correctAnswer: "I", distractors: ["H", "J", "K"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧩\nWhat shape comes next: circle, square, circle, square, ?", correctAnswer: "Circle", distractors: ["Square", "Triangle", "Star"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🎨\nWhat color comes next: red, red, blue, red, red, blue, red, ?", correctAnswer: "Red", distractors: ["Blue", "Green", "Yellow"], tier: .easy, grades: 2...3),

        // ── Easy · word problems and counting ──
        BankQuestion(prompt: "🍎\nNoah has 3 apples. He gives 1 to a friend and gets 2 from his mom. How many apples does he have now?", correctAnswer: "4", distractors: ["3", "5", "6"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🚌\nThere were 5 kids on the bus. At the stop, 3 got on and 2 got off. How many kids are on the bus now?", correctAnswer: "6", distractors: ["4", "5", "10"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍬\nEmma has 6 candies. Jake has 2 more than Emma. How many candies does Jake have?", correctAnswer: "8", distractors: ["4", "6", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🕒\nIt is 3 o'clock now. What time will it be in 2 hours?", correctAnswer: "5 o'clock", distractors: ["1 o'clock", "4 o'clock", "6 o'clock"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐔\nHow many legs do 3 chickens have altogether?", correctAnswer: "6", distractors: ["3", "9", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐶\nHow many legs do 2 dogs and 1 chicken have altogether?", correctAnswer: "10", distractors: ["6", "8", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🪑\nA classroom has 4 tables, with 2 chairs at each table. How many chairs are there?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .easy, grades: 2...3),

        // ── Medium · number series ──
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 1, 4, 9, 16, ?", correctAnswer: "25", distractors: ["20", "24", "32"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 2, 3, 5, 8, 12, ?", correctAnswer: "17", distractors: ["15", "16", "18"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐚\nWhat number comes next in the series: 1, 1, 2, 3, 5, 8, ?", correctAnswer: "13", distractors: ["10", "11", "16"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 3, 6, 12, 24, ?", correctAnswer: "48", distractors: ["30", "36", "72"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 1, 2, 4, 7, 11, ?", correctAnswer: "16", distractors: ["14", "15", "22"], tier: .medium, grades: 3...4),

        // ── Medium · letter and shape patterns ──
        BankQuestion(prompt: "🔤\nWhat letter comes next in the series: A, D, G, J, ?", correctAnswer: "M", distractors: ["K", "L", "N"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔤\nWhat letter comes next in the series: Z, Y, X, W, ?", correctAnswer: "V", distractors: ["U", "T", "S"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔷\nWhat shape comes next: triangle, square, pentagon, ?", correctAnswer: "Hexagon", distractors: ["Circle", "Triangle", "Rectangle"], tier: .medium, grades: 3...4),

        // ── Medium · analogies ──
        BankQuestion(prompt: "📖\nBook is to reading as pencil is to ___?", correctAnswer: "Writing", distractors: ["Singing", "Running", "Drinking"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "☀️\nHot is to summer as cold is to ___?", correctAnswer: "Winter", distractors: ["Spring", "Fall", "Morning"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🩺\nDoctor is to hospital as teacher is to ___?", correctAnswer: "School", distractors: ["Library", "Store", "Office"], tier: .medium, grades: 3...4),

        // ── Medium · odd one out ──
        BankQuestion(prompt: "🔢\nWhich number does not belong: 3, 5, 7, 8, 9?", correctAnswer: "8", distractors: ["3", "7", "9"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥛\nWhich one does not belong: water, milk, juice, bread?", correctAnswer: "Bread", distractors: ["Water", "Milk", "Juice"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍂\nWhich one does not belong: summer, winter, fall, July?", correctAnswer: "July", distractors: ["Summer", "Winter", "Fall"], tier: .medium, grades: 3...4),

        // ── Medium · spatial reasoning ──
        BankQuestion(prompt: "🧭\nEthan is facing north. He turns halfway around. Which way is he facing now?", correctAnswer: "South", distractors: ["North", "East", "West"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔄\nAn arrow points up. You turn it a quarter turn clockwise. Which way does it point now?", correctAnswer: "Right", distractors: ["Left", "Down", "Up"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔄\nAn arrow points right. You turn it halfway around. Which way does it point now?", correctAnswer: "Left", distractors: ["Up", "Down", "Right"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📄\nYou fold a sheet of paper in half, then in half again, and then open it. Into how many equal parts is the sheet divided?", correctAnswer: "4", distractors: ["2", "3", "8"], tier: .medium, grades: 3...4),

        // ── Medium · logic riddles ──
        BankQuestion(prompt: "🧦\nA drawer has 2 red socks and 2 blue socks. Without looking, how many socks must you take out to be sure you have a pair of the same color?", correctAnswer: "3", distractors: ["1", "2", "4"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "⚖️\nWhich weighs more: a pound of feathers or a pound of iron?", correctAnswer: "They weigh the same", distractors: ["The pound of iron", "The pound of feathers", "You can't tell"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📅\nIf tomorrow is Wednesday, what day was yesterday?", correctAnswer: "Monday", distractors: ["Tuesday", "Thursday", "Sunday"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏃\nMax runs faster than Leo, and Leo runs faster than Sam. Who is the slowest?", correctAnswer: "Sam", distractors: ["Max", "Leo", "You can't tell"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐝\nWhat do an ant, a bee and a fly have in common?", correctAnswer: "They are all insects", distractors: ["They are all birds", "They are all fish", "They are all mammals"], tier: .medium, grades: 3...4),

        // ── Medium · word problems and counting ──
        BankQuestion(prompt: "🏫\nA class has 12 boys and 14 girls. 6 kids went to the library. How many kids are still in the classroom?", correctAnswer: "20", distractors: ["18", "22", "26"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "💵\nRyan has $20. He buys 2 notebooks that cost $3 each. How much money does he have left?", correctAnswer: "$14", distractors: ["$12", "$16", "$17"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🎂\nLily is 8 years old. Her brother is 3 years older. How old are they together?", correctAnswer: "19", distractors: ["11", "16", "21"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🚗\nA parking lot has 3 cars and 4 bicycles. How many wheels are there in all?", correctAnswer: "20", distractors: ["14", "16", "24"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔢\nHow many numbers from 1 to 20 (including 20) can be divided by 5 with no remainder?", correctAnswer: "4", distractors: ["2", "3", "5"], tier: .medium, grades: 3...4),

        // ── Hard · number and letter series ──
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 2, 5, 11, 23, ?", correctAnswer: "47", distractors: ["35", "45", "46"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 81, 27, 9, ?", correctAnswer: "3", distractors: ["0", "1", "6"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 1, 2, 6, 24, ?", correctAnswer: "120", distractors: ["48", "96", "100"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔀\nWhat number comes next in the series: 1, 10, 2, 20, 3, 30, 4, ?", correctAnswer: "40", distractors: ["5", "34", "50"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔢\nWhat number comes next in the series: 3, 4, 6, 9, 13, ?", correctAnswer: "18", distractors: ["16", "17", "20"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔤\nWhat letter comes next in the series: B, D, F, H, ?", correctAnswer: "J", distractors: ["I", "K", "L"], tier: .medium, grades: 4...5),

        // ── Hard · spatial reasoning ──
        BankQuestion(prompt: "🔄\nAn arrow points up. You turn it 3 quarter turns clockwise. Which way does it point now?", correctAnswer: "Left", distractors: ["Right", "Down", "Up"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔄\nAn arrow points left. You turn it 5 quarter turns counterclockwise. Which way does it point now?", correctAnswer: "Down", distractors: ["Up", "Right", "Left"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📄\nYou fold a sheet of paper in half and cut a small half-circle out of the folded edge. When you open the paper, what shape is the hole?", correctAnswer: "A circle", distractors: ["A half-circle", "A square", "Two separate holes"], tier: .hard, grades: 4...5),

        // ── Hard · logic riddles and counting ──
        BankQuestion(prompt: "👨‍👧‍👧\nA dad has 3 daughters, and each daughter has one brother. How many children does the dad have?", correctAnswer: "4", distractors: ["3", "6", "7"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "7️⃣\nHow many times does the digit 7 appear when you write the numbers from 1 to 50?", correctAnswer: "5", distractors: ["4", "6", "10"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🤝\n4 kids shake hands. Each kid shakes hands with every other kid exactly once. How many handshakes are there in all?", correctAnswer: "6", distractors: ["4", "8", "12"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📏\nRyan is taller than Dan. Dan is shorter than Gabe. Gabe is shorter than Ryan. Who is in the middle?", correctAnswer: "Gabe", distractors: ["Ryan", "Dan", "You can't tell"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📅\nToday is Tuesday. What day of the week will it be in 10 days?", correctAnswer: "Friday", distractors: ["Wednesday", "Thursday", "Saturday"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🐇\nA yard has rabbits and chickens. Together they have 5 heads and 14 legs. How many rabbits are in the yard?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .hard, grades: 4...5),

        // ── Hard · two-step word problems ──
        BankQuestion(prompt: "✏️\nA store has 3 boxes with 8 pencils in each box. All the pencils are shared equally among 4 kids. How many pencils does each kid get?", correctAnswer: "6", distractors: ["4", "8", "12"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🎂\nJoey is 10 and his mom is 40. In how many years will his mom be exactly 3 times as old as Joey?", correctAnswer: "5", distractors: ["3", "4", "10"], tier: .hard, grades: 4...5),
    ]
}
