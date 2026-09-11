import Foundation

/// 🌊 Deep sea — English (US). Adapted from QuestionBanksSea (Hebrew).
/// Timeless facts only: ocean animals, salt water, oceans, tides, divers and
/// submarines, simple counting. Seas around Israel became US coasts, a Florida
/// reef and Utah's Great Salt Lake; nothing frightening.
extension EnglishContent {
    static let sea: [BankQuestion] = [
        // ── Easy · Ocean animals ──
        BankQuestion(prompt: "🦈\nWhich of these lives in the ocean?", correctAnswer: "Shark", distractors: ["Cow", "Horse", "Rooster"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐬\nWhich ocean animal is known for being smart and friendly, and loves to jump out of the water?", correctAnswer: "Dolphin", distractors: ["Crocodile", "Turtle", "Rabbit"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐙\nHow many arms does an octopus have?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐙\nWhat do we call the soft sea animal with 8 arms?", correctAnswer: "Octopus", distractors: ["Shark", "Turtle", "Crab"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐙\nHow many hearts does an octopus have?", correctAnswer: "3", distractors: ["1", "2", "5"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐢\nWhat does a sea turtle have on its back?", correctAnswer: "A shell", distractors: ["Wings", "Fur", "Horns"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐢\nWhere does a mother sea turtle lay her eggs?", correctAnswer: "In the sand on the beach", distractors: ["Deep in the ocean", "Up in a tree", "In the snow"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐋\nWhich ocean animal is the biggest animal in the whole world?", correctAnswer: "The blue whale", distractors: ["The elephant", "The shark", "The giraffe"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐬\nWhat does a dolphin do when it comes up to the top of the water?", correctAnswer: "Breathes air", distractors: ["Goes to sleep", "Eats sand", "Dries off"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐟\nWhat does a fish use to breathe underwater?", correctAnswer: "Gills", distractors: ["Lungs", "Nose", "Tail"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐠\nWhat helps a fish swim?", correctAnswer: "Fins", distractors: ["Legs", "Wings", "Hands"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐟\nWhat covers the body of most fish?", correctAnswer: "Scales", distractors: ["Fur", "Feathers", "Hair"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐟\nWhere do fish live?", correctAnswer: "In the water", distractors: ["In the air", "In trees", "In the desert"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦈\nWhat does a shark have lots and lots of, that keep getting replaced?", correctAnswer: "Teeth", distractors: ["Eyes", "Ears", "Legs"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪼\nWhich soft, see-through sea animal has long, dangly tentacles?", correctAnswer: "Jellyfish", distractors: ["Turtle", "Dolphin", "Crab"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦀\nWhich animal walks sideways on the beach and has claws?", correctAnswer: "Crab", distractors: ["Fish", "Jellyfish", "Turtle"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "⭐\nWhich sea animal is shaped like a star and often has 5 arms?", correctAnswer: "Starfish", distractors: ["Seahorse", "Swordfish", "Jellyfish"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐴\nWhich small fish looks like a horse and swims standing up?", correctAnswer: "Seahorse", distractors: ["Starfish", "Shark", "Eel"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦭\nWhich animal swims in the ocean, rests on rocks, and has whiskers?", correctAnswer: "Seal", distractors: ["Shark", "Goldfish", "Jellyfish"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐚\nWhich of these comes from the ocean and washes up on the beach?", correctAnswer: "Seashells", distractors: ["Pinecones", "Acorns", "Mushrooms"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐡\nWhich fish can puff itself up like a ball?", correctAnswer: "Pufferfish", distractors: ["Goldfish", "Tuna", "Salmon"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐳\nWhat do we call the breathing hole on top of a whale's head?", correctAnswer: "Blowhole", distractors: ["Gill", "Flipper", "Fin"], tier: .easy, grades: 1...3),

        // ── Easy · Oceans, water and boats ──
        BankQuestion(prompt: "🧂\nWhat does ocean water taste like?", correctAnswer: "Salty", distractors: ["Sweet", "Sour", "Bitter"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌍\nMost of planet Earth is covered with…", correctAnswer: "Water", distractors: ["Sand", "Ice", "Forest"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🪸\nIn which US state can you snorkel over a coral reef?", correctAnswer: "Florida", distractors: ["Colorado", "Kansas", "Montana"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🌊\nWhat do we call the water that rolls onto the beach again and again?", correctAnswer: "Waves", distractors: ["Clouds", "Rain", "Wind"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🏖️\nWhat do we call the place where the ocean meets the land?", correctAnswer: "Beach", distractors: ["Mountain", "Forest", "Desert"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌡️\nWhere is ocean water usually warmer — near the top or deep down?", correctAnswer: "Near the top", distractors: ["Deep down", "It is the same everywhere", "In the middle"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "⛵\nWhich of these sails on the water?", correctAnswer: "Boat", distractors: ["Car", "Bicycle", "Train"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚢\nWhat do we call a ship that travels underwater?", correctAnswer: "Submarine", distractors: ["Airplane", "Train", "Bus"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🤿\nWhat do we call a person who swims underwater with a mask and an air tank?", correctAnswer: "Scuba diver", distractors: ["Pilot", "Bus driver", "Goalie"], tier: .easy, grades: 1...2),

        // ── Easy · Ocean math ──
        BankQuestion(prompt: "🔢\n2 dolphins are swimming, and 3 more join them. How many dolphins are there now?", correctAnswer: "5", distractors: ["4", "6", "3"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔢\n4 yellow fish and 3 blue fish swim on the reef. How many fish are there in all?", correctAnswer: "7", distractors: ["6", "8", "1"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🔢\nThere were 6 shells on the beach, and I picked up 2. How many shells are left on the beach?", correctAnswer: "4", distractors: ["8", "3", "2"], tier: .easy, grades: 0...2),

        // ── Medium · Mammals, fish and reptiles ──
        BankQuestion(prompt: "🐬\nA dolphin is a…", correctAnswer: "Mammal", distractors: ["Fish", "Reptile", "Bird"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐋\nA whale breathes air, just like people do. What does it breathe with?", correctAnswer: "Lungs", distractors: ["Gills", "Fins", "Scales"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐬\nHow does a baby dolphin come into the world?", correctAnswer: "It is born from its mother", distractors: ["It hatches from an egg", "It grows from seaweed", "It comes out of a shell"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐟\nWhat does a fish have that a dolphin does not?", correctAnswer: "Gills", distractors: ["A tail", "Eyes", "Fins"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐢\nA sea turtle is a…", correctAnswer: "Reptile", distractors: ["Fish", "Mammal", "Insect"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐢\nWhat do baby sea turtles do right after they hatch?", correctAnswer: "Crawl to the ocean", distractors: ["Climb a tree", "Sleep for a whole year", "Fly into the air"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦈\nWhat is a shark's skeleton made of?", correctAnswer: "Cartilage", distractors: ["Bone", "Wood", "Metal"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🦈\nWhich shark is the biggest in the world, and eats mostly tiny sea creatures?", correctAnswer: "Whale shark", distractors: ["Great white shark", "Hammerhead shark", "Tiger shark"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐙\nWhat does an octopus do to hide?", correctAnswer: "Changes its color", distractors: ["Closes its eyes", "Jumps out of the water", "Sings loudly"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐙\nWhat kind of cloud does an octopus squirt out when it wants to get away?", correctAnswer: "A cloud of ink", distractors: ["A cloud of rain", "A cloud of dust", "A cloud of smoke"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🪼\nWhich of these is true about a jellyfish?", correctAnswer: "It has no bones", distractors: ["It has a shell", "It has legs", "It has feathers"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪸\nWhat is a coral?", correctAnswer: "A tiny animal", distractors: ["A plant", "A colorful rock", "A kind of fish"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐠\nWhere do most colorful fish live?", correctAnswer: "Near coral reefs", distractors: ["Deep in the dark ocean", "Near the North Pole", "In the desert"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔦\nWhen you go very deep in the ocean, what happens to the light?", correctAnswer: "It gets dark", distractors: ["It gets brighter", "It stays the same", "It turns yellow"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦦\nWhich furry ocean animal floats on its back and uses rocks to crack open shellfish?", correctAnswer: "Sea otter", distractors: ["Seal", "Walrus", "Manatee"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐚\nWhich animal lives in an empty shell and moves into a bigger one as it grows?", correctAnswer: "Hermit crab", distractors: ["Seahorse", "Starfish", "Jellyfish"], tier: .medium, grades: 1...3),

        // ── Medium · Oceans, salt water and tides ──
        BankQuestion(prompt: "🌊\nWhich ocean is along the East Coast of the United States?", correctAnswer: "Atlantic Ocean", distractors: ["Pacific Ocean", "Indian Ocean", "Arctic Ocean"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🌊\nWhich ocean is along the West Coast of the United States, next to California?", correctAnswer: "Pacific Ocean", distractors: ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🧂\nIn which very salty lake in Utah is it easy to float?", correctAnswer: "Great Salt Lake", distractors: ["Lake Michigan", "Lake Tahoe", "Lake Superior"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🛟\nWhy is it so easy to float in the Great Salt Lake?", correctAnswer: "Because the water is very salty", distractors: ["Because the water is warm", "Because the water is shallow", "Because there are no waves"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🗺️\nWhat is special about the shores of the Dead Sea?", correctAnswer: "They are the lowest land on Earth", distractors: ["They are the highest land on Earth", "They are the coldest place on Earth", "They are the rainiest place on Earth"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🌍\nWhat is the biggest ocean in the world?", correctAnswer: "Pacific Ocean", distractors: ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌊\nWhat happens at \"high tide\"?", correctAnswer: "The water rises and covers more of the beach", distractors: ["The water disappears", "The water freezes", "The water turns sweet"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌙\nWhat causes the tides in the ocean?", correctAnswer: "Mostly the pull of the Moon's gravity", distractors: ["The wind", "The fish", "The clouds"], tier: .medium, grades: 3...4),

        // ── Medium · Divers and submarines ──
        BankQuestion(prompt: "🤿\nWhy does a scuba diver take an air tank along?", correctAnswer: "To breathe underwater", distractors: ["To float to the top", "To drink water", "To light up the dark"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🤿\nWhat does a diver wear on their feet to swim faster?", correctAnswer: "Flippers", distractors: ["Boots", "Roller skates", "Sandals"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚢\nWhat does a submarine do when it wants to sink?", correctAnswer: "Fills its tanks with water", distractors: ["Turns on its lights", "Opens its windows", "Turns off its engine"], tier: .medium, grades: 3...4),

        // ── Medium · Ocean math ──
        BankQuestion(prompt: "🔢\nAn octopus has 8 arms. How many arms do 2 octopuses have?", correctAnswer: "16", distractors: ["10", "12", "18"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔢\nA group of 10 dolphins is swimming. 4 jump out of the water. How many are still underwater?", correctAnswer: "6", distractors: ["14", "5", "4"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔢\nA starfish has 5 arms. How many arms do 3 starfish have?", correctAnswer: "15", distractors: ["8", "10", "20"], tier: .medium, grades: 2...4),

        // ── Hard · The deep, oceans and salt ──
        BankQuestion(prompt: "🌍\nWhich ocean lies between Europe and Africa on one side and North and South America on the other?", correctAnswer: "Atlantic Ocean", distractors: ["Pacific Ocean", "Indian Ocean", "Arctic Ocean"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🌊\nWhat is the deepest place in all the oceans?", correctAnswer: "Mariana Trench", distractors: ["Mediterranean Sea", "Hudson Bay", "Caribbean Sea"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🔦\nSome fish deep in the ocean glow in the dark. Where does their light come from?", correctAnswer: "From their own bodies", distractors: ["From the Sun", "From a diver's flashlight", "From the Moon"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐬\nWhat does a dolphin use to \"see\" in the dark and find fish?", correctAnswer: "Echoes of sounds", distractors: ["A flashlight", "Its sense of smell", "Its whiskers"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦈\nWhat happens when a shark loses a tooth?", correctAnswer: "A new tooth takes its place", distractors: ["The gap stays forever", "It stops eating", "It goes to the dentist"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐋\nWhat does the blue whale, the biggest animal in the world, eat?", correctAnswer: "Krill — tiny shrimp-like animals", distractors: ["Sharks", "Dolphins", "Seaweed"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🧂\nWhy is the Great Salt Lake so salty?", correctAnswer: "Its water evaporates, but the salt stays behind", distractors: ["People pour salt into it", "It is connected to the ocean", "It has lots of fish"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🌙\nIn most places, how many high tides are there each day?", correctAnswer: "2", distractors: ["4", "6", "10"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🚢\nWhat is a \"periscope\" on a submarine?", correctAnswer: "A tube for peeking above the water", distractors: ["The submarine's engine", "A kind of fish", "A tool for cooking"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🔢\nA submarine went down to 300 feet deep, and then came up 120 feet. How deep is it now?", correctAnswer: "180 feet", distractors: ["420 feet", "200 feet", "150 feet"], tier: .hard, grades: 3...5),
    ]
}
