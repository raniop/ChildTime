import Foundation

/// 🐾 Animals — English (US). Adapted from QuestionBanksAnimals (Hebrew).
/// Timeless facts only: sounds, baby names, body parts, animal groups, diets,
/// habitats and continents, conservation. "Animals of Israel" became animals of
/// North America (bighorn sheep, prairie dog, deer, bald eagle, bison).
extension EnglishContent {
    static let animals: [BankQuestion] = [
        // ── Animal sounds ──
        BankQuestion(prompt: "🐄\nWhich animal says \"moo\"?", correctAnswer: "Cow", distractors: ["Dog", "Cat", "Rooster"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐱\nWhich animal says \"meow\"?", correctAnswer: "Cat", distractors: ["Dog", "Cow", "Horse"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐶\nWhat sound does a dog make?", correctAnswer: "Woof", distractors: ["Moo", "Cock-a-doodle-doo", "Meow"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐓\nWhich animal calls \"cock-a-doodle-doo\" in the morning?", correctAnswer: "Rooster", distractors: ["Duck", "Sheep", "Goat"], tier: .easy, grades: 0...1),

        // ── Baby animals ──
        BankQuestion(prompt: "🐴\nWhat do we call a baby horse?", correctAnswer: "Foal", distractors: ["Kid", "Lamb", "Calf"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐄\nWhat do we call a baby cow?", correctAnswer: "Calf", distractors: ["Foal", "Kid", "Chick"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐥\nWhat do we call a baby chicken?", correctAnswer: "Chick", distractors: ["Lamb", "Calf", "Kid"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐑\nWhat do we call a baby sheep?", correctAnswer: "Lamb", distractors: ["Kid", "Calf", "Foal"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐐\nWhat do we call a baby goat?", correctAnswer: "Kid", distractors: ["Lamb", "Foal", "Calf"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐶\nWhat do we call a baby dog?", correctAnswer: "Puppy", distractors: ["Chick", "Calf", "Lamb"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐸\nWhat do we call a baby frog that lives in the water and has a tail?", correctAnswer: "Tadpole", distractors: ["Caterpillar", "Chick", "Lamb"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦋\nWho turns into a butterfly when it grows up?", correctAnswer: "Caterpillar", distractors: ["Tadpole", "Chick", "Fish"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🍼\nWhat do baby mammals, like puppies and calves, drink when they are born?", correctAnswer: "Milk from their mother", distractors: ["Water", "Juice", "Honey"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐦\nWhat does a bird build to lay its eggs in?", correctAnswer: "Nest", distractors: ["Hive", "Den", "Stable"], tier: .easy, grades: 0...2),

        // ── Counting legs and wings ──
        BankQuestion(prompt: "🐕\nHow many legs does a dog have?", correctAnswer: "4", distractors: ["2", "6", "8"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐜\nHow many legs does an ant have?", correctAnswer: "6", distractors: ["4", "8", "10"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🦅\nHow many wings does a bird have?", correctAnswer: "2", distractors: ["1", "4", "6"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🕷️\nHow many legs does a spider have?", correctAnswer: "8", distractors: ["6", "4", "10"], tier: .medium, grades: 1...3),

        // ── Animal records ──
        BankQuestion(prompt: "🐘\nWhat is the biggest animal living on land today?", correctAnswer: "The elephant", distractors: ["The horse", "The cow", "The camel"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐋\nWhat is the biggest animal in the whole world?", correctAnswer: "The blue whale", distractors: ["The elephant", "The shark", "The giraffe"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦒\nWhat is the tallest animal in the world?", correctAnswer: "The giraffe", distractors: ["The elephant", "The camel", "The bear"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐆\nWhat is the fastest animal on land?", correctAnswer: "The cheetah", distractors: ["The horse", "The rabbit", "The lion"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🦈\nWhat is the biggest fish in the world?", correctAnswer: "Whale shark", distractors: ["Tuna", "Salmon", "Goldfish"], tier: .hard, grades: 3...5),

        // ── Body parts and coverings ──
        BankQuestion(prompt: "🐪\nWhat does a camel have on its back?", correctAnswer: "A hump", distractors: ["Horns", "Wings", "Scales"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐘\nWhat do we call an elephant's long nose?", correctAnswer: "Trunk", distractors: ["Horn", "Hump", "Beak"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦏\nWhat does a rhinoceros have on its nose?", correctAnswer: "A horn", distractors: ["A trunk", "A beak", "A hump"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦓\nWhich animal has black and white stripes?", correctAnswer: "Zebra", distractors: ["Giraffe", "Elephant", "Bear"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐦\nWhat covers a bird's body?", correctAnswer: "Feathers", distractors: ["Scales", "Fur", "Spines"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐍\nWhat covers a snake's body?", correctAnswer: "Scales", distractors: ["Feathers", "Fur", "Wool"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nWhich animal carries its house on its back?", correctAnswer: "The turtle", distractors: ["The rabbit", "The frog", "The parrot"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦘\nWhere does a mother kangaroo carry her baby?", correctAnswer: "In a pouch on her belly", distractors: ["On her back", "In her mouth", "On her tail"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐟\nWhat do fish use to breathe underwater?", correctAnswer: "Gills", distractors: ["Lungs", "Nose", "Fins"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦒\nWhy does a giraffe have a long neck?", correctAnswer: "To reach the leaves high up in trees", distractors: ["To swim fast", "To fly", "To dig in the ground"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦎\nWhich animal can change the color of its skin?", correctAnswer: "Chameleon", distractors: ["Turtle", "Snake", "Rabbit"], tier: .medium, grades: 1...3),

        // ── Animal groups: mammals, birds, reptiles, amphibians, insects ──
        BankQuestion(prompt: "🐧\nWhich bird can't fly, but is a great swimmer?", correctAnswer: "Penguin", distractors: ["Pigeon", "Eagle", "Sparrow"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦜\nWhich bird can copy words that people say?", correctAnswer: "Parrot", distractors: ["Pigeon", "Duck", "Eagle"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐊\nWhich group do crocodiles, lizards and turtles belong to?", correctAnswer: "Reptiles", distractors: ["Mammals", "Birds", "Fish"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐞\nWhich group do ants, bees and butterflies belong to?", correctAnswer: "Insects", distractors: ["Reptiles", "Birds", "Mammals"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐋\nA whale lives in the ocean, but it is not a fish. Which group does it belong to?", correctAnswer: "Mammals", distractors: ["Fish", "Reptiles", "Amphibians"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦇\nA bat can fly, but it is not a bird. Which group does it belong to?", correctAnswer: "Mammals", distractors: ["Birds", "Insects", "Reptiles"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🐸\nA frog lives both in the water and on land. Which group does it belong to?", correctAnswer: "Amphibians", distractors: ["Reptiles", "Fish", "Mammals"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦕\nWhich giant animal lived millions of years ago, and today we only see its bones in museums?", correctAnswer: "Dinosaur", distractors: ["Elephant", "Giraffe", "Crocodile"], tier: .easy, grades: 0...2),

        // ── What animals eat and what they give us ──
        BankQuestion(prompt: "🐄\nWhich animal gives us milk?", correctAnswer: "Cow", distractors: ["Chicken", "Bee", "Dog"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐔\nWhich animal lays the eggs that we eat?", correctAnswer: "Chicken", distractors: ["Cow", "Sheep", "Horse"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐝\nWhich animal makes honey?", correctAnswer: "Bee", distractors: ["Butterfly", "Ant", "Fly"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐝\nWhat does a bee collect from flowers to make honey?", correctAnswer: "Nectar", distractors: ["Sand", "Leaves", "Mud"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐼\nWhat does a giant panda eat almost all day long?", correctAnswer: "Bamboo", distractors: ["Fish", "Honey", "Carrots"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌿\nWhat do we call an animal that eats only plants?", correctAnswer: "Herbivore", distractors: ["Carnivore", "Omnivore", "Insectivore"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦁\nA lion eats meat. What do we call an animal that eats meat?", correctAnswer: "Carnivore", distractors: ["Herbivore", "Omnivore", "Hibernator"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦝\nA raccoon eats berries and nuts, and also fish and eggs. What do we call an animal that eats both plants and meat?", correctAnswer: "Omnivore", distractors: ["Herbivore", "Carnivore", "Insectivore"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🐝\nWhy are bees important for plants?", correctAnswer: "They pollinate flowers and help fruit grow", distractors: ["They water the plants", "They sing to the plants", "They dig holes for the plants"], tier: .hard, grades: 3...6),

        // ── Habitats and seasons ──
        BankQuestion(prompt: "🐪\nWhich animal can walk in the desert for many days without drinking?", correctAnswer: "The camel", distractors: ["The cow", "The pig", "The frog"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐻\nWhat does a brown bear do in the winter?", correctAnswer: "Sleeps in its den for a long time", distractors: ["Flies south", "Moves into the ocean", "Turns white"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦢\nWhy do many birds fly south in the fall?", correctAnswer: "To reach a warm place with lots of food", distractors: ["To learn how to fly", "Because they love snow", "To swim in the ocean"], tier: .medium, grades: 2...4),

        // ── Animals around the world ──
        BankQuestion(prompt: "🐨\nOn which continent do koalas and kangaroos live?", correctAnswer: "Australia", distractors: ["Europe", "Asia", "Africa"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦁\nOn which continent do most wild lions live?", correctAnswer: "Africa", distractors: ["Europe", "Australia", "Antarctica"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐼\nIn which country do giant pandas live in the wild?", correctAnswer: "China", distractors: ["Brazil", "Egypt", "Canada"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐧\nOn which frozen continent do emperor penguins live?", correctAnswer: "Antarctica", distractors: ["Africa", "Europe", "Asia"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🐯\nOn which continent do tigers live in the wild?", correctAnswer: "Asia", distractors: ["Africa", "Europe", "South America"], tier: .hard, grades: 3...5),

        // ── Animals of North America ──
        BankQuestion(prompt: "🐏\nWhich North American animal has big curled horns and climbs steep mountain cliffs?", correctAnswer: "Bighorn sheep", distractors: ["Elephant", "Kangaroo", "Panda"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌾\nWhich small, furry animal digs tunnels on the prairie and lives in big groups called \"towns\"?", correctAnswer: "Prairie dog", distractors: ["Koala", "Penguin", "Polar bear"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦌\nWhich gentle animal with a white tail lives in forests and fields across much of North America?", correctAnswer: "White-tailed deer", distractors: ["Zebra", "Kangaroo", "Panda"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦎\nWhich small reptile has special toe pads that let it climb walls and even glass?", correctAnswer: "Gecko", distractors: ["Turtle", "Crocodile", "Snake"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🦅\nWhich big bird is the national bird of the United States?", correctAnswer: "Bald eagle", distractors: ["Pigeon", "Rooster", "Penguin"], tier: .medium, grades: 1...4),
        BankQuestion(prompt: "🏞️\nWhich animal is on the arrowhead badge of the US National Park Service?", correctAnswer: "Bison", distractors: ["Lion", "Elephant", "Camel"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦬\nWhich big, shaggy animal is the national mammal of the United States?", correctAnswer: "Bison", distractors: ["Moose", "Grizzly bear", "Elk"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "💨\nWhich animal is the fastest runner in North America?", correctAnswer: "Pronghorn", distractors: ["Moose", "Black bear", "Beaver"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦫\nWhich animal builds dams across streams with sticks and mud?", correctAnswer: "Beaver", distractors: ["Rabbit", "Squirrel", "Deer"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🦨\nWhich black and white animal sprays a stinky smell to protect itself?", correctAnswer: "Skunk", distractors: ["Zebra", "Panda", "Penguin"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "👶\nWhich North American animal carries its babies in a pouch, just like a kangaroo?", correctAnswer: "Opossum", distractors: ["Raccoon", "Squirrel", "Skunk"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🦋\nWhich orange and black butterfly flies thousands of miles to Mexico for the winter?", correctAnswer: "Monarch", distractors: ["Blue morpho", "Cabbage white", "Tiger swallowtail"], tier: .medium, grades: 2...4),

        // ── Protecting nature and endangered animals ──
        BankQuestion(prompt: "🛡️\nWhat do we call an animal that has very few of its kind left in the world, so we must protect it?", correctAnswer: "Endangered animal", distractors: ["Pet", "Farm animal", "Flying animal"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🦤\nWhat does \"extinct\" mean?", correctAnswer: "A kind of animal is gone from the world forever", distractors: ["An animal sleeps all winter", "An animal moves to a zoo", "An animal changes its fur"], tier: .hard, grades: 3...5),
        BankQuestion(prompt: "🌳\nWhy is it important to protect forests?", correctAnswer: "They are home to many animals", distractors: ["To make room for more cars", "Animals don't need them", "To build tall buildings there"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🏞️\nWhat do we call a place where nature and wild animals are protected?", correctAnswer: "Nature preserve", distractors: ["Pet store", "Playground", "Shopping mall"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nWhat can every kid do to help ocean animals?", correctAnswer: "Keep plastic trash out of the ocean", distractors: ["Feed candy to the fish", "Sing to the ocean", "Draw pictures of fish"], tier: .medium, grades: 1...3),
    ]
}
