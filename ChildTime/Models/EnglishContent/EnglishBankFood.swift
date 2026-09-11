import Foundation

/// 🍳 Kitchen & Food Science — English (US). Adapted from QuestionBanksFood (Hebrew).
/// Where food comes from, food groups, kitchen measuring and recipe math (US cups,
/// tablespoons, ounces, dollars), gentle kitchen safety, and simple food science.
extension EnglishContent {
    static let food: [BankQuestion] = [
        // ── Easy · where food comes from ──
        BankQuestion(prompt: "🐄\nWhich animal gives us milk?", correctAnswer: "Cow", distractors: ["Chicken", "Fish", "Butterfly"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥚\nWhich animal lays the eggs we eat?", correctAnswer: "Chicken", distractors: ["Cow", "Dog", "Cat"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍯\nWho makes honey?", correctAnswer: "Bees", distractors: ["Ladybugs", "Butterflies", "Birds"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍞\nWhat do we bake bread from?", correctAnswer: "Flour", distractors: ["Sand", "Cheese", "Chocolate"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧀\nWhat is cheese made from?", correctAnswer: "Milk", distractors: ["Water", "Juice", "Flour"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍫\nWhat is chocolate made from?", correctAnswer: "Cocoa beans", distractors: ["Apples", "Rice", "Carrots"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍇\nWhich fruit do raisins come from?", correctAnswer: "Grapes", distractors: ["Apples", "Bananas", "Watermelons"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍟\nWhich vegetable are French fries made from?", correctAnswer: "Potatoes", distractors: ["Carrots", "Tomatoes", "Onions"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍅\nWhat is ketchup made from?", correctAnswer: "Tomatoes", distractors: ["Carrots", "Potatoes", "Lettuce"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🌳\nWhich of these grows on a tree?", correctAnswer: "Apple", distractors: ["Carrot", "Potato", "Cucumber"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥔\nWhich vegetable grows under the ground?", correctAnswer: "Potato", distractors: ["Tomato", "Cucumber", "Lettuce"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🫓\nWhat is the name of the round bread with a pocket inside?", correctAnswer: "Pita", distractors: ["Bagel", "Baguette", "Croissant"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍿\nPopcorn comes from which plant?", correctAnswer: "Corn", distractors: ["Wheat", "Rice", "Oats"], tier: .easy, grades: 1...2),

        // ── Easy · fruits, vegetables and good choices ──
        BankQuestion(prompt: "🍎\nAn apple is a…", correctAnswer: "Fruit", distractors: ["Vegetable", "Cheese", "Bread"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥕\nA carrot is a…", correctAnswer: "Vegetable", distractors: ["Fruit", "Fish", "Cake"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍌\nWhat color is a ripe banana?", correctAnswer: "Yellow", distractors: ["Blue", "Purple", "Black"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍊\nWhat color is an orange?", correctAnswer: "Orange", distractors: ["Blue", "White", "Pink"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍎\nWhat is good to eat every day?", correctAnswer: "Fruits and vegetables", distractors: ["Candy", "Chocolate", "Chips"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "💧\nWhat is the best drink when you are thirsty?", correctAnswer: "Water", distractors: ["Oil", "Vinegar", "Ketchup"], tier: .easy, grades: 1...2),

        // ── Easy · little science and kitchen safety ──
        BankQuestion(prompt: "🧊\nWhat happens to ice left out in the sun?", correctAnswer: "It melts", distractors: ["It freezes", "It grows", "It turns blue"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "💧\nWater you put in the freezer turns into…", correctAnswer: "Ice", distractors: ["Steam", "Juice", "Milk"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧼\nWhat do you do before you start cooking?", correctAnswer: "Wash your hands", distractors: ["Comb your hair", "Put on your shoes", "Turn off the lights"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔥\nWho should help when you use a hot oven?", correctAnswer: "A grown-up", distractors: ["A baby", "The dog", "A teddy bear"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍲\nHow do you carry a bowl of hot soup?", correctAnswer: "Slowly and carefully", distractors: ["Running fast", "With one hand over your head", "While jumping"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥄\nWhat do you eat soup with?", correctAnswer: "A spoon", distractors: ["A fork", "A knife", "Scissors"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔪\nWhat do you use to slice bread?", correctAnswer: "A knife", distractors: ["A spoon", "A fork", "A cup"], tier: .easy, grades: 1...2),

        // ── Easy · recipe and shopping math ──
        BankQuestion(prompt: "🧁\nEach cake needs 2 eggs. How many eggs do you need for 2 cakes?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍪\nThe recipe says 3 tablespoons of sugar. You already added 1. How many more do you need?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍕\nWe cut a pizza into 8 slices and ate 3. How many slices are left?", correctAnswer: "5", distractors: ["3", "4", "6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥪\nA sandwich costs $3 and a juice costs $2. How much do they cost together?", correctAnswer: "$5", distractors: ["$1", "$4", "$6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🍎\nOne apple costs 50 cents. How much do 2 apples cost?", correctAnswer: "$1.00", distractors: ["50 cents", "$1.50", "$2.00"], tier: .easy, grades: 1...2),

        // ── Medium · where and how ──
        BankQuestion(prompt: "🫘\nWhat is hummus made from?", correctAnswer: "Chickpeas", distractors: ["Meat", "Cheese", "Potatoes"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥜\nWhat is peanut butter made from?", correctAnswer: "Peanuts", distractors: ["Walnuts", "Sesame seeds", "Wheat"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥛\nHow do you turn milk into yogurt?", correctAnswer: "Add good bacteria", distractors: ["Freeze it", "Add sugar", "Pour it through a strainer"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍞\nWhat makes bread dough rise?", correctAnswer: "Yeast", distractors: ["Salt", "Cold water", "Cocoa powder"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌾\nWhich plant is the flour for bread usually made from?", correctAnswer: "Wheat", distractors: ["Cotton", "Carrot", "Orange"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🍚\nWhere do many kinds of rice grow?", correctAnswer: "In fields flooded with water", distractors: ["On tall trees", "In the ocean", "In a dry desert"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍓\nWhere do strawberries grow?", correctAnswer: "On a low plant near the ground", distractors: ["On a tall tree", "Under the ground", "In the water"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥜\nWhere do peanuts grow?", correctAnswer: "Under the ground", distractors: ["On a tree", "On a vine", "In the water"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍇\nWhat do grapes grow on?", correctAnswer: "A vine", distractors: ["An apple tree", "A rosebush", "A palm tree"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌴\nWhich fruit grows on a palm tree?", correctAnswer: "Date", distractors: ["Apple", "Pear", "Cherry"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🧂\nWhere does salt come from?", correctAnswer: "Seawater and mines", distractors: ["Trees", "Cows", "Eggs"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍯\nWhy is honey sweet?", correctAnswer: "It has lots of natural sugars", distractors: ["A factory adds sugar to it", "It is made from milk", "It grows on trees"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🍁\nMaple syrup is made from which part of the maple tree?", correctAnswer: "The sap", distractors: ["The leaves", "The roots", "The flowers"], tier: .medium, grades: 2...4),

        // ── Medium · food groups ──
        BankQuestion(prompt: "🥬\nWhich of these belongs to the vegetable group?", correctAnswer: "Lettuce", distractors: ["Bread", "Cheese", "Egg"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🥛\nMilk, cheese, and yogurt belong to which food group?", correctAnswer: "Dairy", distractors: ["Fruits", "Grains", "Vegetables"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🍞\nBread, rice, and pasta belong to which food group?", correctAnswer: "Grains", distractors: ["Fruits", "Dairy", "Vegetables"], tier: .medium, grades: 3...4),

        // ── Medium · measuring and math ──
        BankQuestion(prompt: "🥛\nHow many cups are in 1 quart?", correctAnswer: "4", distractors: ["2", "3", "5"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "⚖️\nHow many ounces are in 1 pound?", correctAnswer: "16", distractors: ["10", "12", "100"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥄\nWhich of these measures the smallest amount?", correctAnswer: "Teaspoon", distractors: ["Tablespoon", "Cup", "Quart"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🧁\nOne cake needs 3 eggs. How many eggs do you need for 3 cakes?", correctAnswer: "9", distractors: ["6", "3", "12"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥞\nA recipe needs 2 cups of flour. You double the recipe. How many cups of flour do you need?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🍪\nA recipe needs 6 tablespoons of sugar. You make half the recipe. How many tablespoons do you need?", correctAnswer: "3", distractors: ["2", "4", "12"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "⏲️\nThe cake bakes for 40 minutes. It went into the oven at 4:00. When does it come out?", correctAnswer: "4:40", distractors: ["4:20", "4:30", "5:00"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍋\nLemonade costs 25 cents a cup. How much do 3 cups cost?", correctAnswer: "75 cents", distractors: ["50 cents", "30 cents", "$1.00"], tier: .medium, grades: 2...3),

        // ── Medium · kitchen science ──
        BankQuestion(prompt: "🔥\nAt what temperature does water boil?", correctAnswer: "212°F", distractors: ["72°F", "150°F", "300°F"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🧊\nAt what temperature does water freeze into ice?", correctAnswer: "32°F", distractors: ["10°F", "50°F", "100°F"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "♨️\nWhat do we call the white mist rising from a pot of boiling water?", correctAnswer: "Steam", distractors: ["Smoke", "Dust", "Snow"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥚\nWhat happens to the clear part of an egg when you cook it?", correctAnswer: "It turns white and firm", distractors: ["It disappears", "It turns blue", "It turns into water"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🍽️\nThe food on your plate is too hot. What do you do before you taste it?", correctAnswer: "Wait for it to cool a little", distractors: ["Eat it fast", "Put it in the freezer for an hour", "Pour water on it"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🧊\nWhy do we keep milk in the fridge?", correctAnswer: "So it stays fresh longer", distractors: ["So it gets sweeter", "So it turns into ice", "So it gets warm"], tier: .medium, grades: 2...3),

        // ── Hard · food science ──
        BankQuestion(prompt: "🫧\nWhich gas does yeast make in dough that makes it rise?", correctAnswer: "Carbon dioxide", distractors: ["Oxygen", "Helium", "Nitrogen"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🦠\nWhat is it called when bacteria or yeast turn milk into yogurt or make bread dough rise?", correctAnswer: "Fermentation", distractors: ["Freezing", "Evaporation", "Frying"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🥛\nWhat is it called when milk is heated at the dairy to make it safe to drink?", correctAnswer: "Pasteurization", distractors: ["Frying", "Freezing", "Baking"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "💨\nWater boils in a pot for a long time, and the pot slowly gets emptier. Where did the water go?", correctAnswer: "It turned into water vapor", distractors: ["The pot soaked it up", "It turned into salt", "It froze"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🧊\nWhy does an ice cube float in water?", correctAnswer: "Ice is lighter than the same amount of water", distractors: ["Because it is cold", "Because it is white", "Because it is shiny"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🍯\nWhy can honey last for many years without spoiling?", correctAnswer: "It has very little water and lots of sugar", distractors: ["People keep it in the freezer", "Salt is added to it", "The bees guard it"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🍫\nWhere do cacao trees grow?", correctAnswer: "In hot, rainy places near the equator", distractors: ["At the North Pole", "In the desert", "On snowy mountains"], tier: .hard, grades: 4...5),

        // ── Hard · plant parts we eat ──
        BankQuestion(prompt: "🍅\nA tomato grows from a flower and has seeds inside. So, to a scientist, it is a…", correctAnswer: "Fruit", distractors: ["Root", "Leaf", "Stem"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🥕\nWhich part of the plant is a carrot?", correctAnswer: "The root", distractors: ["The leaf", "The flower", "The fruit"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🥬\nWhich part of the plant do you eat when you eat lettuce?", correctAnswer: "The leaves", distractors: ["The root", "The fruit", "The seeds"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🥦\nBroccoli is really…", correctAnswer: "Flower buds that have not opened yet", distractors: ["A root", "A fruit", "A seed"], tier: .hard, grades: 4...5),

        // ── Hard · recipe math ──
        BankQuestion(prompt: "🍚\nA recipe for 4 people needs 2 cups of rice. How many cups do you need for 8 people?", correctAnswer: "4", distractors: ["2", "3", "8"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🧈\nA recipe needs 12 tablespoons of butter. You make only a quarter of the recipe. How many tablespoons do you need?", correctAnswer: "3", distractors: ["4", "6", "9"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "⏲️\nThe cake bakes for 1 hour and 15 minutes. It went into the oven at 3:30. When does it come out?", correctAnswer: "4:45", distractors: ["4:15", "4:30", "5:00"], tier: .hard, grades: 3...5),
    ]
}
