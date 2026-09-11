import Foundation

/// 🦖 Dinosaurs — English (US). Adapted from QuestionBanksDinosaurs (Hebrew).
/// Species, sizes, diets, eggs, fossils and paleontologists, the extinction,
/// name meanings and dinosaur math. Israeli finds became US ones (Texas
/// footprints, Sue the T. rex, Dinosaur National Monument); lengths in feet.
extension EnglishContent {
    static let dinosaurs: [BankQuestion] = [
        // ── Easy · What dinosaurs were ──
        BankQuestion(prompt: "🦖\nCan you meet a living T. rex today?", correctAnswer: "No, it died out long ago", distractors: ["Yes, in the forest", "Yes, at the zoo", "Yes, in the desert"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥚\nWhere did baby dinosaurs come from?", correctAnswer: "From eggs", distractors: ["From seeds", "From flowers", "From rocks"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪺\nWhat do we call the place where a mother dinosaur laid her eggs?", correctAnswer: "Nest", distractors: ["Den", "Hive", "Fish tank"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐣\nWhat hatched out of a dinosaur egg?", correctAnswer: "A baby dinosaur", distractors: ["A kitten", "A little fish", "A butterfly"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦴\nA dinosaur bone that turned to stone over millions of years is called a…", correctAnswer: "Fossil", distractors: ["Seashell", "Coin", "Pebble"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🐊\nWhich group of animals do dinosaurs belong to?", correctAnswer: "Reptiles", distractors: ["Fish", "Insects", "Mammals"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🌍\nWhere did dinosaurs live?", correctAnswer: "All over the world", distractors: ["Only in Africa", "Only at the North Pole", "Only in Europe"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🦕\nWhich dinosaur is famous for its very long neck?", correctAnswer: "Brachiosaurus", distractors: ["Tyrannosaurus rex", "Triceratops", "Velociraptor"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦖\nWhich famous dinosaur was a giant meat-eater with big teeth and tiny arms?", correctAnswer: "Tyrannosaurus rex", distractors: ["Brachiosaurus", "Triceratops", "Stegosaurus"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦏\nWhich dinosaur had 3 horns on its face?", correctAnswer: "Triceratops", distractors: ["Tyrannosaurus rex", "Brachiosaurus", "Velociraptor"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🛡️\nWhich dinosaur had big plates on its back and spikes on its tail?", correctAnswer: "Stegosaurus", distractors: ["Brachiosaurus", "Tyrannosaurus rex", "Diplodocus"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🏃\nVelociraptor was a dinosaur that was…", correctAnswer: "Small and fast", distractors: ["Huge and slow", "Able to fly", "Living in the ocean"], tier: .easy, grades: 1...3),

        // ── Easy · What they ate and how they looked ──
        BankQuestion(prompt: "🌿\nWhat did Brachiosaurus eat?", correctAnswer: "Leaves from trees", distractors: ["Fish", "Meat", "Insects"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🍖\nWhat did Tyrannosaurus rex eat?", correctAnswer: "Meat", distractors: ["Leaves", "Fruit", "Grass"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦏\nWhat did Triceratops eat?", correctAnswer: "Plants", distractors: ["Fish", "Meat", "Insects"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥬\nStegosaurus was a…", correctAnswer: "Plant-eater", distractors: ["Meat-eater", "Fish-eater", "Bug-eater"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🌱\nWhat do we call a dinosaur that ate only plants?", correctAnswer: "Herbivore", distractors: ["Carnivore", "Omnivore", "Insectivore"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦕\nHow did its long neck help Brachiosaurus?", correctAnswer: "It could reach high leaves", distractors: ["It could swim fast", "It could fly", "It could dig in the ground"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🦵\nHow many legs did Tyrannosaurus rex walk on?", correctAnswer: "2", distractors: ["4", "6", "8"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦵\nHow many legs did Triceratops walk on?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🤏\nWhich part of Tyrannosaurus rex's body was extra small?", correctAnswer: "Its arms", distractors: ["Its head", "Its tail", "Its legs"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🐔\nWere all dinosaurs giants?", correctAnswer: "No, some were as small as a chicken", distractors: ["Yes, all were as big as a house", "Yes, all were bigger than an elephant", "No, all were smaller than a cat"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🪨\nWhere are dinosaur fossils usually found?", correctAnswer: "Inside rocks", distractors: ["On treetops", "Inside clouds", "Inside flowers"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🖌️\nWhich tool is used to gently clean dirt off a fossil?", correctAnswer: "A brush", distractors: ["A rake", "A saw", "A fork"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "🏛️\nWhere can you see a big dinosaur skeleton?", correctAnswer: "At a museum", distractors: ["At a zoo", "At a supermarket", "At a swimming pool"], tier: .easy, grades: 1...3),
        BankQuestion(prompt: "➕\nA Triceratops has 3 horns. How many horns do 2 Triceratops have?", correctAnswer: "6", distractors: ["3", "5", "9"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🦵\nT. rex walks on 2 legs and Triceratops walks on 4. How many legs do they have together?", correctAnswer: "6", distractors: ["2", "4", "8"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🥚\nThere were 5 eggs in the nest, and the mother dinosaur laid 3 more. How many eggs are in the nest now?", correctAnswer: "8", distractors: ["2", "7", "9"], tier: .easy, grades: 0...2),

        // ── Medium · Fossils, scientists and extinction ──
        BankQuestion(prompt: "🔍\nWhat do we call a scientist who studies dinosaur fossils?", correctAnswer: "Paleontologist", distractors: ["Astronaut", "Dentist", "Architect"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐦\nWhich animals living today came from dinosaurs?", correctAnswer: "Birds", distractors: ["Fish", "Butterflies", "Dogs"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦃\nWhich dinosaur was small, about the size of a turkey?", correctAnswer: "Velociraptor", distractors: ["Tyrannosaurus rex", "Brachiosaurus", "Diplodocus"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪶\nWhat covered Velociraptor's body?", correctAnswer: "Feathers", distractors: ["Fur", "Wool", "A hard shell"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "☄️\nAbout how long ago did the dinosaurs die out?", correctAnswer: "66 million years ago", distractors: ["100 years ago", "1,000 years ago", "10,000 years ago"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "☄️\nWhat do scientists think made the dinosaurs die out?", correctAnswer: "A giant asteroid hitting Earth", distractors: ["A big rainstorm", "A strong wind", "A heavy snowfall"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "👣\nWhat special dinosaur find can you see in the riverbed at Dinosaur Valley State Park in Texas?", correctAnswer: "Dinosaur footprints", distractors: ["Dinosaur eggs", "A whole T. rex skeleton", "A living dinosaur"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🧍\nDid people live at the same time as the dinosaurs?", correctAnswer: "No, dinosaurs died out long before people", distractors: ["Yes, in the same caves", "Yes, people rode them", "Yes, people raised them on farms"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "📖\nWhat does the word \"dinosaur\" mean?", correctAnswer: "Terrible lizard", distractors: ["Big animal", "King of the forest", "Long reptile"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "📖\nWhat does the name \"Triceratops\" mean?", correctAnswer: "Three-horned face", distractors: ["Long tail", "Roof lizard", "Speedy thief"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🦅\nPterosaurs were flying reptiles that lived alongside the dinosaurs. Were they dinosaurs?", correctAnswer: "No, just close relatives", distractors: ["Yes, flying dinosaurs", "Yes, tiny dinosaurs", "Yes, ocean dinosaurs"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏞️\nWhere did most dinosaurs live — in the ocean, in the air, or on land?", correctAnswer: "On land", distractors: ["In the ocean", "In the air", "Underground"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🧩\nWhat do paleontologists do with the dinosaur bones they find?", correctAnswer: "Put them together into a skeleton", distractors: ["Throw them away", "Plant them in a garden", "Cook them"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "👣\nWhat can we learn from dinosaur footprints?", correctAnswer: "How it walked and how big it was", distractors: ["What color it was", "What its name was", "What sound it made"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🧱\nOver millions of years, bones buried in mud and sand can slowly…", correctAnswer: "Turn to stone", distractors: ["Melt away into water", "Grow into trees", "Turn into gold"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "📅\nWhat is the name of one of the time periods when dinosaurs lived?", correctAnswer: "Jurassic Period", distractors: ["Stone Age", "Iron Age", "Middle Ages"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐦\nWhat do birds and dinosaurs have in common?", correctAnswer: "Both lay eggs", distractors: ["Both have fur", "Both live in the ocean", "Both eat only grass"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🏜️\nAt Dinosaur National Monument, visitors can see a famous rock wall filled with what?", correctAnswer: "Dinosaur bones", distractors: ["Cave paintings", "Gold coins", "Frozen ice"], tier: .medium, grades: 2...4),

        // ── Medium · Sizes and kinds ──
        BankQuestion(prompt: "📏\nAbout how long was a grown-up Tyrannosaurus rex?", correctAnswer: "About 40 feet", distractors: ["About 4 feet", "About 400 feet", "About 4 inches"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏢\nBrachiosaurus stood about as tall as…", correctAnswer: "A 4-story building", distractors: ["A child", "A big dog", "A baby stroller"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦷\nA Tyrannosaurus rex tooth was about as long as…", correctAnswer: "A banana", distractors: ["A button", "A grain of rice", "A school bus"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦕\nWhich dinosaur had a long neck and a very long tail like a whip?", correctAnswer: "Diplodocus", distractors: ["Triceratops", "Tyrannosaurus rex", "Stegosaurus"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🛡️\nWhich dinosaur was covered in armor and had a hard, bony club at the end of its tail?", correctAnswer: "Ankylosaurus", distractors: ["Brachiosaurus", "Velociraptor", "Diplodocus"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📏\nA T. rex was about 40 feet long and a Triceratops about 30 feet long. How long are they together?", correctAnswer: "70 feet", distractors: ["10 feet", "60 feet", "80 feet"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "📏\nA Diplodocus was about 85 feet long and a T. rex about 40 feet long. How many feet longer was the Diplodocus?", correctAnswer: "45", distractors: ["40", "55", "125"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "✖️\n3 Triceratops are walking together, and each one has 4 legs. How many legs do they have in all?", correctAnswer: "12", distractors: ["7", "9", "16"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "✖️\nA Stegosaurus has 4 spikes on its tail. How many tail spikes do 3 Stegosaurus have?", correctAnswer: "12", distractors: ["7", "8", "16"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "➗\n20 dinosaur eggs are shared equally among 4 nests. How many eggs are in each nest?", correctAnswer: "5", distractors: ["4", "6", "16"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🦖\nTyrannosaurus rex had 2 fingers on each hand. How many fingers did it have on both hands?", correctAnswer: "4", distractors: ["2", "6", "10"], tier: .medium, grades: 2...4),

        // ── Hard ──
        BankQuestion(prompt: "🌎\nThe asteroid that wiped out the dinosaurs landed near which country?", correctAnswer: "Mexico", distractors: ["Japan", "France", "Australia"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🐚\nWhat were ammonites, whose fossils are found all over the world?", correctAnswer: "Ancient sea animals with spiral shells", distractors: ["Flying reptiles", "Giant plant-eating dinosaurs", "Early mammals"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "📖\nWhat does the name \"Velociraptor\" mean?", correctAnswer: "Speedy thief", distractors: ["Terrible lizard", "Three-horned face", "Roof lizard"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "📖\nWhat does the name \"Stegosaurus\" mean?", correctAnswer: "Roof lizard", distractors: ["Arm lizard", "Speedy thief", "King of the lizards"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "📖\nWhich long-necked dinosaur's name means \"thunder lizard\"?", correctAnswer: "Brontosaurus", distractors: ["Triceratops", "Velociraptor", "Stegosaurus"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧑‍🔬\nWhich scientist made up the word \"dinosaur\" in 1842?", correctAnswer: "Richard Owen", distractors: ["Albert Einstein", "Charles Darwin", "Isaac Newton"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🎨\nWhich of these is hardest for scientists to learn from dinosaur fossils?", correctAnswer: "What color the dinosaur was", distractors: ["How many legs it had", "How big it was", "What its teeth looked like"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🌵\nWhy is it easier to hunt for fossils in dry, rocky places like deserts?", correctAnswer: "Because the rocks are bare and easy to see", distractors: ["Because it is hot there", "Because there is lots of water there", "Because dinosaurs loved sand"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🗺️\nOn which continent were Velociraptor fossils found?", correctAnswer: "Asia", distractors: ["Europe", "Africa", "South America"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🗺️\nOn which continent did Tyrannosaurus rex live?", correctAnswer: "North America", distractors: ["Europe", "Africa", "Australia"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦖\nThe famous T. rex skeleton named Sue was dug up in which US state?", correctAnswer: "South Dakota", distractors: ["Florida", "Maine", "Hawaii"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🥚\nThe name \"Maiasaura\" means \"good mother lizard.\" Why did scientists name it that?", correctAnswer: "Its nests were found with babies in them", distractors: ["It was the biggest dinosaur", "It had a horn", "It could fly"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🧠\nStegosaurus was a big dinosaur, but its brain was very small. Which of these is closest in size to its brain?", correctAnswer: "A lemon", distractors: ["A watermelon", "A basketball", "A car"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐟\nWhich dinosaur had a big \"sail\" on its back and liked to eat fish?", correctAnswer: "Spinosaurus", distractors: ["Triceratops", "Stegosaurus", "Ankylosaurus"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "⏳\nFor how long did dinosaurs live on Earth?", correctAnswer: "More than 150 million years", distractors: ["10 years", "100 years", "1,000 years"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "📅\nIn which period did Tyrannosaurus rex and Triceratops live, right before the dinosaurs died out?", correctAnswer: "Cretaceous", distractors: ["Jurassic", "Triassic", "Ice Age"], tier: .hard, grades: 4...6),
        BankQuestion(prompt: "🔢\nThe dinosaurs died out 66 million years ago. How do you write 66 million in numbers?", correctAnswer: "66,000,000", distractors: ["66,000", "6,600,000", "660,000,000"], tier: .hard, grades: 4...6),
    ]
}
