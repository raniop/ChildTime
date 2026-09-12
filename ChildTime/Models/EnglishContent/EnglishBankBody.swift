import Foundation

/// 🧍 The human body — English (US). Adapted from QuestionBanksBody (Hebrew).
/// Bones, heart, lungs, senses, teeth, brain, muscles, digestion, skin, sleep and
/// healthy habits. Timeless textbook facts; gentle wording (no illness or injury).
extension EnglishContent {
    static let body: [BankQuestion] = [
        // ── Easy · organs and senses ──
        BankQuestion(prompt: "❤️\nWhich organ pumps blood around the body?", correctAnswer: "The heart", distractors: ["The lungs", "The brain", "The stomach"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫁\nWhich organs help us breathe?", correctAnswer: "The lungs", distractors: ["The heart", "The stomach", "The skin"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧠\nWhich organ helps us think and remember?", correctAnswer: "The brain", distractors: ["The heart", "The lungs", "The liver"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👀\nWhat do we use to see?", correctAnswer: "Our eyes", distractors: ["Our ears", "Our nose", "Our mouth"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👂\nWhat do we use to hear?", correctAnswer: "Our ears", distractors: ["Our eyes", "Our nose", "Our hands"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👃\nWhat do we use to smell?", correctAnswer: "Our nose", distractors: ["Our elbows", "Our ears", "Our eyes"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👅\nWhich body part has the taste buds we taste with?", correctAnswer: "The tongue", distractors: ["The teeth", "The ears", "The hair"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🤲\nWhich sense tells us that something is hot or cold?", correctAnswer: "Touch", distractors: ["Sight", "Hearing", "Smell"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🖐️\nHow many main senses do we usually learn about?", correctAnswer: "5", distractors: ["3", "4", "6"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✋\nHow many fingers and thumbs are on two hands altogether?", correctAnswer: "10", distractors: ["5", "8", "12"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦶\nHow many toes are on one foot?", correctAnswer: "5", distractors: ["4", "6", "10"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦷\nWhat helps us chew our food?", correctAnswer: "Our teeth", distractors: ["Our nose", "Our ears", "Our eyes"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👄\nFood goes into the body through the…", correctAnswer: "Mouth", distractors: ["Nose", "Ear", "Eye"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🍎\nAfter you swallow food, which of these does it reach?", correctAnswer: "The stomach", distractors: ["The lungs", "The heart", "The brain"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💪\nWhat moves our bones?", correctAnswer: "Muscles", distractors: ["Hair", "Skin", "Fingernails"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦴\nWhat do we call all the bones of the body together?", correctAnswer: "The skeleton", distractors: ["A muscle", "The skin", "The heart"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧍\nWhich organ covers the whole outside of the body?", correctAnswer: "The skin", distractors: ["The skeleton", "The heart", "The brain"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🫀\nWhere is your heart?", correctAnswer: "In your chest", distractors: ["In your head", "In your leg", "In your arm"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧠\nWhere is your brain?", correctAnswer: "In your head", distractors: ["In your belly", "In your hand", "In your leg"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦴\nWhich bone protects the brain?", correctAnswer: "The skull", distractors: ["A rib", "The thigh bone", "The arm bone"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🩸\nWhat flows through the body and brings oxygen everywhere?", correctAnswer: "Blood", distractors: ["Water", "Air", "Milk"], tier: .easy, grades: 2...3),

        // ── Easy · healthy habits ──
        BankQuestion(prompt: "🪥\nHow often should you brush your teeth?", correctAnswer: "Twice a day", distractors: ["Once a week", "Once a month", "Once a year"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦷\nWhat do you do with a toothbrush and toothpaste?", correctAnswer: "Brush your teeth", distractors: ["Comb your hair", "Wash your hands", "Clean your shoes"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧼\nWhat is a good thing to do before you eat?", correctAnswer: "Wash your hands", distractors: ["Run a race", "Take a nap", "Sing a song"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "☀️\nWhat do we put on our skin to protect it from the sun?", correctAnswer: "Sunscreen", distractors: ["Water", "Olive oil", "Glue"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🛌\nWhat does your body do at night to rest and recharge?", correctAnswer: "Sleep", distractors: ["Run", "Eat", "Jump"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "💧\nWhich drink is best for keeping your body healthy?", correctAnswer: "Water", distractors: ["Soda", "Syrup", "Coffee"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏃\nWhat helps your muscles get strong?", correctAnswer: "Exercise", distractors: ["Candy", "Watching TV", "Video games"], tier: .easy, grades: 2...3),

        // ── Medium · bones and teeth ──
        BankQuestion(prompt: "🦴\nHow many bones are in a grown-up's body?", correctAnswer: "206", distractors: ["106", "306", "520"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nWhat is the longest bone in the body?", correctAnswer: "The thigh bone (femur)", distractors: ["The upper arm bone", "A rib", "The skull"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nHow many ribs does a person usually have?", correctAnswer: "24", distractors: ["12", "20", "30"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nWhich part of the skeleton protects the heart and lungs?", correctAnswer: "The ribs", distractors: ["The skull", "The thigh bone", "The finger bones"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦴\nWhat do we call a place where two bones meet so the body can bend and move?", correctAnswer: "A joint", distractors: ["A muscle", "A tendon", "Skin"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦵\nThe knee is an example of a…", correctAnswer: "Joint", distractors: ["Muscle", "Organ", "Single bone"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nHow many baby teeth does a child have?", correctAnswer: "20", distractors: ["10", "24", "32"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nHow many teeth does a grown-up have, counting wisdom teeth?", correctAnswer: "32", distractors: ["20", "28", "36"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🦷\nWhat do we call the first teeth that fall out so grown-up teeth can grow in?", correctAnswer: "Baby teeth", distractors: ["Wisdom teeth", "Gold teeth", "Candy teeth"], tier: .medium, grades: 3...5),

        // ── Medium · heart, blood and breathing ──
        BankQuestion(prompt: "🫀\nThe heart is really a…", correctAnswer: "Muscle", distractors: ["Bone", "Joint", "Tooth"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "❤️\nWhat does the heart pump all through the body?", correctAnswer: "Blood", distractors: ["Air", "Water", "Food"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nWhat does blood bring to all the cells of the body?", correctAnswer: "Oxygen and nutrients", distractors: ["Light", "Sound", "Sand"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nWhich of these is true about people's blood?", correctAnswer: "There are several different blood types", distractors: ["Everyone has the same blood type", "Blood is made only of water", "Blood is green inside the body"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🩸\nWhich of these is the name of a blood type?", correctAnswer: "Type O", distractors: ["Type X", "Type Z", "Type Q"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🫁\nHow many lungs does a person have?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🫁\nWhich gas do we breathe in from the air because our body needs it?", correctAnswer: "Oxygen", distractors: ["Carbon dioxide", "Helium", "Hydrogen"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌬️\nWhich gas does the body add to the air we breathe out?", correctAnswer: "Carbon dioxide", distractors: ["Oxygen", "Helium", "Hydrogen"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🌡️\nWhat is a healthy person's normal body temperature?", correctAnswer: "About 98.6°F", distractors: ["About 50°F", "About 70°F", "About 150°F"], tier: .medium, grades: 3...5),

        // ── Medium · brain, senses and digestion ──
        BankQuestion(prompt: "🧠\nWhat does the brain use to send messages to the whole body?", correctAnswer: "Nerves", distractors: ["Muscles", "Hair", "Bones"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🧍\nWhat is the largest organ of the body?", correctAnswer: "The skin", distractors: ["The heart", "The brain", "The liver"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "💪\nAbout how many muscles are in the human body?", correctAnswer: "About 600", distractors: ["About 6", "About 60", "About 60,000"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "👂\nBesides hearing, what does the inner ear help us do?", correctAnswer: "Keep our balance", distractors: ["See in the dark", "Taste food", "Digest food"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "👅\nWhat taste does your tongue notice when you eat a lemon?", correctAnswer: "Sour", distractors: ["Sweet", "Salty", "Bitter"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍽️\nWhat happens to food in the stomach?", correctAnswer: "It gets broken down into tiny pieces", distractors: ["It turns into bone", "It stays exactly the same", "It goes up to the lungs"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🍽️\nWhat do we call the way the body breaks down food?", correctAnswer: "Digestion", distractors: ["Breathing", "Sleeping", "Growing"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🛌\nWhy is it important to get enough sleep?", correctAnswer: "The body and brain rest and recharge", distractors: ["Teeth grow only at night", "Hair gets shorter", "Eyes change color"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "😴\nAbout how many hours of sleep does a school-age child need each night?", correctAnswer: "About 10 hours", distractors: ["About 2 hours", "About 5 hours", "About 16 hours"], tier: .medium, grades: 3...5),
        BankQuestion(prompt: "🧼\nWhy do we wash our hands with soap?", correctAnswer: "To wash away germs", distractors: ["To make our hands grow", "To warm up our hands", "To change the color of our skin"], tier: .medium, grades: 3...5),

        // ── Hard ──
        BankQuestion(prompt: "👂\nWhere is the smallest bone in the body?", correctAnswer: "In the ear", distractors: ["In the finger", "In the nose", "In the knee"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦴\nWhat is made inside bone marrow?", correctAnswer: "Blood cells", distractors: ["Teeth", "Hair", "Fingernails"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫀\nHow many chambers does the heart have?", correctAnswer: "4", distractors: ["1", "2", "6"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🩸\nWhat are the blood vessels called that carry blood away from the heart to the body?", correctAnswer: "Arteries", distractors: ["Veins", "Nerves", "Tendons"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🩸\nWhat is the job of red blood cells?", correctAnswer: "To carry oxygen", distractors: ["To digest food", "To build bones", "To make hair"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "💓\nWhat are you measuring when you put a finger on your wrist and count the beats?", correctAnswer: "Your pulse", distractors: ["Your temperature", "Your height", "Your weight"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫁\nWhat is the big muscle under the lungs that helps us breathe?", correctAnswer: "The diaphragm", distractors: ["The biceps", "The heart muscle", "The thigh muscle"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦷\nWhat is the hardest material in the human body?", correctAnswer: "Tooth enamel", distractors: ["Bone", "Fingernail", "Hair"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧠\nWhich part of the brain mostly takes care of balance and smooth movement?", correctAnswer: "The cerebellum", distractors: ["The cerebrum", "The brain stem", "The spinal cord"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🦴\nWhat does the backbone (spine) protect?", correctAnswer: "The spinal cord", distractors: ["The stomach", "The eyes", "The teeth"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🫘\nWhich organs clean the blood and remove extra water from it?", correctAnswer: "The kidneys", distractors: ["The lungs", "The heart", "The brain"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🍽️\nIn which organ do most nutrients from food pass into the blood?", correctAnswer: "The small intestine", distractors: ["The stomach", "The mouth", "The lungs"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "👁️\nWhat is the black dot in the middle of the eye, where light gets in?", correctAnswer: "The pupil", distractors: ["The iris", "An eyelash", "The eyebrow"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧍\nWhat is the largest organ inside the body?", correctAnswer: "The liver", distractors: ["The heart", "The kidney", "The stomach"], tier: .hard, grades: 4...6),
    ]
}
