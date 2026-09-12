import Foundation

/// 📖 Reading comprehension — English (US), K–8. Original passages.
///
/// Written for US children, not translated from the Hebrew set. Length grows
/// with the grade: K–1 two to four short sentences, 2–3 a short paragraph,
/// 4–5 one to two paragraphs, 6–8 two to three paragraphs across informational,
/// narrative, argument and procedural texts. Every question is answerable from
/// the passage alone: a detail, an inference, a word in context, or the main
/// idea / the writer's purpose. Names, places and people in the stories are
/// invented; the history passages use only well-documented facts.
extension EnglishContent {
    static let readingPassages: [ReadingPassage] = [

        // ——— Kindergarten ———

        ReadingPassage(
            id: "en_k_puppy", tier: .easy, grades: 0...0,
            text: "Max is a little puppy. He has brown spots. Max likes to dig in the yard.",
            questions: [
                BankQuestion(prompt: "What kind of animal is Max?", correctAnswer: "A puppy", distractors: ["A kitten", "A bunny", "A duck"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "What color are Max's spots?", correctAnswer: "Brown", distractors: ["Black", "White", "Orange"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "Where does Max like to dig?", correctAnswer: "In the yard", distractors: ["In the sand", "In the snow", "In the house"], tier: .easy, grades: 0...0),
            ]),

        ReadingPassage(
            id: "en_k_red_hat", tier: .easy, grades: 0...0,
            text: "Ana has a red hat. The wind blew her hat away. Dad ran and got it back.",
            questions: [
                BankQuestion(prompt: "What color is Ana's hat?", correctAnswer: "Red", distractors: ["Blue", "Green", "Yellow"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "What made Ana's hat fly away?", correctAnswer: "The wind", distractors: ["The dog", "The rain", "Her brother"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "Who got Ana's hat back?", correctAnswer: "Dad", distractors: ["Mom", "Ana", "Grandma"], tier: .easy, grades: 0...0),
            ]),

        ReadingPassage(
            id: "en_k_frog", tier: .easy, grades: 0...1,
            text: "A green frog sat on a log. It saw a fly. Hop! The frog jumped into the pond.",
            questions: [
                BankQuestion(prompt: "Where did the green frog sit?", correctAnswer: "On a log", distractors: ["On a rock", "On a leaf", "On a boat"], tier: .easy, grades: 0...1),
                BankQuestion(prompt: "What did the frog see?", correctAnswer: "A fly", distractors: ["A fish", "A bird", "A duck"], tier: .easy, grades: 0...1),
                BankQuestion(prompt: "Where did the frog jump?", correctAnswer: "Into the pond", distractors: ["Onto the grass", "Up a tree", "Under the log"], tier: .easy, grades: 0...1),
            ]),

        ReadingPassage(
            id: "en_k_snowman", tier: .medium, grades: 0...0,
            text: "It snowed last night. Leo put on his boots and mittens. He went outside and made a big snowman.",
            questions: [
                BankQuestion(prompt: "What happened last night?", correctAnswer: "It snowed", distractors: ["It rained", "It was hot", "It was windy"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "What did Leo put on?", correctAnswer: "Boots and mittens", distractors: ["Sandals and shorts", "A swimsuit and cap", "Slippers and pajamas"], tier: .medium, grades: 0...0),
                BankQuestion(prompt: "What did Leo make outside?", correctAnswer: "A big snowman", distractors: ["A sand castle", "A snow angel", "A mud pie"], tier: .medium, grades: 0...0),
            ]),

        ReadingPassage(
            id: "en_k_birthday", tier: .medium, grades: 0...0,
            text: "Today is Zoe's birthday. She is five years old. Mom made her a cake with pink frosting. Zoe blew out all the candles.",
            questions: [
                BankQuestion(prompt: "How old is Zoe?", correctAnswer: "Five", distractors: ["Four", "Six", "Three"], tier: .easy, grades: 0...0),
                BankQuestion(prompt: "Who made Zoe's birthday cake?", correctAnswer: "Mom", distractors: ["Dad", "Grandma", "Zoe"], tier: .medium, grades: 0...0),
                BankQuestion(prompt: "What color was the frosting?", correctAnswer: "Pink", distractors: ["Purple", "White", "Yellow"], tier: .medium, grades: 0...0),
                BankQuestion(prompt: "What did Zoe blow out?", correctAnswer: "The candles", distractors: ["The balloons", "The lights", "The bubbles"], tier: .medium, grades: 0...0),
            ]),

        ReadingPassage(
            id: "en_k_bus", tier: .medium, grades: 0...1,
            text: "Sam rides the bus to school. The bus is big and yellow. Sam sits next to his friend Kim. They wave to the driver when they get off.",
            questions: [
                BankQuestion(prompt: "How does Sam get to school?", correctAnswer: "He rides the bus", distractors: ["He walks there", "Dad drives him", "He rides a bike"], tier: .easy, grades: 0...1),
                BankQuestion(prompt: "What color is Sam's school bus?", correctAnswer: "Yellow", distractors: ["Red", "Blue", "Green"], tier: .easy, grades: 0...1),
                BankQuestion(prompt: "Who does Sam sit next to on the bus?", correctAnswer: "His friend Kim", distractors: ["His big sister", "His teacher", "His dad"], tier: .medium, grades: 0...1),
                BankQuestion(prompt: "What do Sam and Kim do when they get off the bus?", correctAnswer: "Wave to the driver", distractors: ["Sing a song", "Run to the park", "Eat a snack"], tier: .medium, grades: 0...1),
            ]),

        ReadingPassage(
            id: "en_k_apples", tier: .hard, grades: 0...1,
            text: "Mia and Grandpa went to pick apples. Mia picked three apples. Grandpa picked a whole basket! They took the apples home to make a pie.",
            questions: [
                BankQuestion(prompt: "Who picked apples with Mia?", correctAnswer: "Grandpa", distractors: ["Grandma", "Her mom", "Her friend"], tier: .easy, grades: 0...1),
                BankQuestion(prompt: "How many apples did Mia pick?", correctAnswer: "Three", distractors: ["Two", "Five", "Ten"], tier: .medium, grades: 0...1),
                BankQuestion(prompt: "Who picked the most apples?", correctAnswer: "Grandpa", distractors: ["Mia", "Mom", "Grandma"], tier: .hard, grades: 0...1),
                BankQuestion(prompt: "What will Mia and Grandpa make with the apples?", correctAnswer: "A pie", distractors: ["Apple juice", "A salad", "Muffins"], tier: .medium, grades: 0...1),
            ]),

        // ——— 1st grade ———

        ReadingPassage(
            id: "en_1_robin_nest", tier: .easy, grades: 1...1,
            text: "A mother robin built a nest in our tree. She used twigs and grass. Soon there were three blue eggs in the nest. We watch from the window so we do not scare her.",
            questions: [
                BankQuestion(prompt: "What did the robin use to build her nest?", correctAnswer: "Twigs and grass", distractors: ["Rocks and shells", "Paper and string", "Yarn and cotton"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "How many eggs were in the robin's nest?", correctAnswer: "Three", distractors: ["Two", "Four", "Five"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What color were the robin's eggs?", correctAnswer: "Blue", distractors: ["White", "Brown", "Green"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Why do the kids watch the nest from the window?", correctAnswer: "So they do not scare the robin", distractors: ["So they can stay warm inside", "Because the tree is too tall", "So they can count the birds"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en_1_lemonade", tier: .medium, grades: 1...2,
            text: "Jamal and his sister set up a lemonade stand. They sold each cup for 25 cents. It was a hot day, so lots of people stopped to buy some. By lunchtime, their pitcher was empty.",
            questions: [
                BankQuestion(prompt: "Who ran the lemonade stand?", correctAnswer: "Jamal and his sister", distractors: ["Jamal and his dad", "Jamal and a friend", "Jamal by himself"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "How much did one cup of lemonade cost?", correctAnswer: "25 cents", distractors: ["50 cents", "10 cents", "One dollar"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "Why did lots of people stop at the lemonade stand?", correctAnswer: "It was a hot day", distractors: ["The lemonade was free", "They had cookies too", "It was a holiday"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "What does \"their pitcher was empty\" tell you?", correctAnswer: "They sold all the lemonade", distractors: ["They spilled the lemonade", "Nobody bought any lemonade", "They made more lemonade"], tier: .hard, grades: 1...2),
            ]),

        ReadingPassage(
            id: "en_1_pumpkin_patch", tier: .easy, grades: 1...1,
            text: "In October, Rosa's class went to a pumpkin patch. Rosa looked for the biggest pumpkin. She found one, but it was too heavy to lift. Her teacher helped her carry it to the wagon.",
            questions: [
                BankQuestion(prompt: "When did Rosa's class go to the pumpkin patch?", correctAnswer: "In October", distractors: ["In May", "In December", "In July"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What was the problem with Rosa's pumpkin?", correctAnswer: "It was too heavy to lift", distractors: ["It was too small to keep", "It had a big hole in it", "It was still very green"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "Who helped Rosa carry the pumpkin?", correctAnswer: "Her teacher", distractors: ["Her mom", "A farmer", "Her best friend"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Where did they carry Rosa's pumpkin?", correctAnswer: "To the wagon", distractors: ["To the bus", "To the classroom", "To the car"], tier: .easy, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en_1_box_turtle", tier: .medium, grades: 1...2,
            text: "A box turtle carries its home on its back. Its hard shell keeps it safe. When a box turtle is scared, it pulls its head and legs inside the shell. Then it waits until the danger is gone.",
            questions: [
                BankQuestion(prompt: "What keeps a box turtle safe?", correctAnswer: "Its hard shell", distractors: ["Its long tail", "Its sharp teeth", "Its fast legs"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "What does a box turtle do when it is scared?", correctAnswer: "It hides inside its shell", distractors: ["It runs away very fast", "It climbs up a tree", "It digs a deep hole"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "How long does the turtle stay inside its shell?", correctAnswer: "Until the danger is gone", distractors: ["Until it gets dark", "Until it starts to rain", "Until it gets hungry"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "What does \"carries its home on its back\" mean?", correctAnswer: "Its shell is like a house", distractors: ["It lives inside a box", "It carries sticks on its back", "It builds a house to live in"], tier: .hard, grades: 1...2),
            ]),

        ReadingPassage(
            id: "en_1_soccer_goal", tier: .easy, grades: 1...1,
            text: "Ella plays soccer every Saturday. Her team wears green shirts. Today Ella kicked the ball right into the net. Her whole team cheered, \"Goal!\"",
            questions: [
                BankQuestion(prompt: "When does Ella play soccer?", correctAnswer: "Every Saturday", distractors: ["Every Monday", "Every morning", "After school"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What color shirts does Ella's team wear?", correctAnswer: "Green", distractors: ["Red", "Blue", "Orange"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What did Ella do at soccer today?", correctAnswer: "She scored a goal", distractors: ["She lost her shoe", "She missed the game", "She caught the ball"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "How did Ella's team feel when the ball went in?", correctAnswer: "Happy", distractors: ["Sad", "Angry", "Sleepy"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en_1_moon_shapes", tier: .hard, grades: 1...2,
            text: "One night, Ben looked up at the moon. It was big and round like a ball. Some nights later, the moon looked thin, like a banana. Ben's mom said the moon seems to change its shape a little every night.",
            questions: [
                BankQuestion(prompt: "What did the moon look like on the first night?", correctAnswer: "Round like a ball", distractors: ["Thin like a banana", "Square like a box", "Pointy like a star"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "What did the moon look like some nights later?", correctAnswer: "Thin, like a banana", distractors: ["Big and round", "Shaped like a heart", "Bright like the sun"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "Who told Ben that the moon seems to change shape?", correctAnswer: "His mom", distractors: ["His dad", "His teacher", "His sister"], tier: .hard, grades: 1...2),
            ]),

        ReadingPassage(
            id: "en_1_lost_tooth", tier: .medium, grades: 1...1,
            text: "Kai's front tooth was loose for a week. At dinner, he bit into a crunchy carrot. Out came the tooth! Kai grinned and showed everyone the gap in his smile.",
            questions: [
                BankQuestion(prompt: "How long was Kai's tooth loose?", correctAnswer: "For a week", distractors: ["For one day", "For a month", "For a year"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What made Kai's tooth come out?", correctAnswer: "Biting a crunchy carrot", distractors: ["Brushing his teeth", "Eating soft soup", "Falling off his bike"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "What did Kai show everyone at dinner?", correctAnswer: "The gap in his smile", distractors: ["His crunchy carrot", "A shiny new coin", "A picture he drew"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "How did Kai feel when his tooth came out?", correctAnswer: "Happy", distractors: ["Scared", "Angry", "Sad"], tier: .hard, grades: 1...1),
            ]),

        // ——— 2nd grade ———

        ReadingPassage(
            id: "en_2_library_card", tier: .easy, grades: 2...2,
            text: "Priya got her very first library card on Tuesday. The librarian, Mr. Hill, showed her where the animal books were. Priya chose one book about sharks and one about owls. She can keep the books for two weeks. After that, she has to bring them back so other kids can read them too.",
            questions: [
                BankQuestion(prompt: "Who is Mr. Hill?", correctAnswer: "The librarian", distractors: ["Priya's dad", "Priya's teacher", "The bus driver"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What were Priya's two library books about?", correctAnswer: "Sharks and owls", distractors: ["Horses and bees", "Dinosaurs and frogs", "Space and rockets"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "How long can Priya keep the books?", correctAnswer: "Two weeks", distractors: ["Two days", "One month", "One year"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "Why does Priya have to bring the books back?", correctAnswer: "So other kids can read them", distractors: ["Because the books are torn", "So Mr. Hill can read them", "So she can get a prize"], tier: .medium, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en_2_bean_plant", tier: .medium, grades: 2...3,
            text: "Here is how to grow a bean plant. First, fill a paper cup with soil. Next, push a bean seed into the soil with your finger. Then add a little water and set the cup by a sunny window. Check on it every day. In about a week, a tiny green sprout will poke up out of the soil.",
            questions: [
                BankQuestion(prompt: "What is the first step in growing a bean plant?", correctAnswer: "Fill a paper cup with soil", distractors: ["Push a seed into the soil", "Add a little water", "Set the cup by a window"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "Where should you put the cup with the bean seed?", correctAnswer: "By a sunny window", distractors: ["In a dark closet", "Inside the fridge", "Under your bed"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "In this passage, what is a \"sprout\"?", correctAnswer: "A new little plant", distractors: ["A kind of bean seed", "A small paper cup", "A drop of water"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "What is the bean plant passage mostly teaching you?", correctAnswer: "How to grow a bean plant", distractors: ["How to cook green beans", "Why plants need rain", "Where beans come from"], tier: .medium, grades: 2...3),
            ]),

        ReadingPassage(
            id: "en_2_new_kid", tier: .medium, grades: 2...2,
            text: "Carlos was new at Oak Hill Elementary. At recess, he stood by the fence and watched the other kids play. Hannah noticed him standing alone. She walked over and asked, \"Do you want to play tag with us?\" Carlos smiled and nodded. By the end of the day, the two of them were laughing like old friends.",
            questions: [
                BankQuestion(prompt: "Where did Carlos stand at recess?", correctAnswer: "By the fence", distractors: ["On the slide", "Near the swings", "By the classroom door"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What did Hannah ask Carlos to do?", correctAnswer: "Play tag", distractors: ["Share her snack", "Sit with her at lunch", "Read a book"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "How did Carlos most likely feel before Hannah came over?", correctAnswer: "Lonely", distractors: ["Excited", "Angry", "Silly"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What lesson does the story about Carlos and Hannah teach?", correctAnswer: "Being kind helps others feel welcome", distractors: ["Tag is the best game at recess", "New kids should stay by the fence", "Recess is too short to make friends"], tier: .hard, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en_2_octopus", tier: .easy, grades: 2...3,
            text: "An octopus has eight long arms. Each arm is covered with round suckers that help it grab and hold things. An octopus can also change the color of its skin. This helps it blend in with rocks and sand, so hungry animals cannot find it.",
            questions: [
                BankQuestion(prompt: "How many arms does an octopus have?", correctAnswer: "Eight", distractors: ["Six", "Ten", "Four"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "What do the suckers help an octopus do?", correctAnswer: "Grab and hold things", distractors: ["Swim very fast", "See in the dark", "Breathe under water"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "What does \"blend in\" mean in the octopus passage?", correctAnswer: "Look like the things around it", distractors: ["Mix food together in a bowl", "Swim with a big group of fish", "Grow bigger and stronger"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "Why does an octopus change its color?", correctAnswer: "To hide from hungry animals", distractors: ["To stay warm in cold water", "To make its arms grow longer", "To help it swim faster"], tier: .medium, grades: 2...3),
            ]),

        ReadingPassage(
            id: "en_2_fourth_of_july", tier: .easy, grades: 2...2,
            text: "On the Fourth of July, Nia's family had a picnic at the park. They ate corn on the cob and cold watermelon. When it got dark, they spread out a blanket on the grass. Boom! Bright fireworks burst across the sky. Nia's little brother covered his ears, but he was smiling the whole time.",
            questions: [
                BankQuestion(prompt: "Where did Nia's family have their picnic?", correctAnswer: "At the park", distractors: ["At the beach", "In their backyard", "At Grandma's house"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "When did the fireworks start?", correctAnswer: "When it got dark", distractors: ["Right after lunch", "Early in the morning", "Before the picnic"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "Why did Nia's brother cover his ears?", correctAnswer: "The fireworks were loud", distractors: ["His ears were cold", "He did not like music", "A bug flew near him"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "How did Nia's brother feel about the fireworks?", correctAnswer: "He enjoyed them", distractors: ["He was very scared", "He was bored", "He wanted to go home"], tier: .hard, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en_2_rainy_saturday", tier: .hard, grades: 2...3,
            text: "It rained all day on Saturday, so Tyler could not ride his new bike. He sat by the window feeling grumpy. Then Grandma pulled a dusty box out of the closet. It was full of old board games! They played checkers, and then they built a tall tower out of playing cards. At bedtime, Tyler said, \"That was the best rainy day ever.\"",
            questions: [
                BankQuestion(prompt: "Why couldn't Tyler ride his new bike?", correctAnswer: "It rained all day", distractors: ["His bike was broken", "It was too dark out", "Grandma said no"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "What does \"grumpy\" mean?", correctAnswer: "In a bad mood", distractors: ["Very sleepy", "Really hungry", "Full of energy"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "What was in Grandma's dusty box?", correctAnswer: "Old board games", distractors: ["Winter clothes", "Family photos", "Art supplies"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "How did Tyler's feelings change during the day?", correctAnswer: "He went from grumpy to happy", distractors: ["He went from happy to grumpy", "He stayed grumpy all day", "He went from scared to brave"], tier: .hard, grades: 2...3),
            ]),

        // ——— 3rd grade ———

        ReadingPassage(
            id: "en_3_honeybees", tier: .medium, grades: 3...3,
            text: "Honeybees live together in a home called a hive. Each hive has one queen bee, and her job is to lay eggs. Most of the other bees are worker bees. Workers fly from flower to flower to collect pollen and nectar, a sweet liquid made by flowers. Back at the hive, they turn the nectar into honey. When a worker finds a good patch of flowers, she does a special \"waggle dance.\" The dance shows the other bees which way to fly to find the flowers.",
            questions: [
                BankQuestion(prompt: "What is the queen bee's job?", correctAnswer: "To lay eggs", distractors: ["To make honey", "To guard the hive", "To collect pollen"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What is nectar?", correctAnswer: "A sweet liquid made by flowers", distractors: ["A special kind of bee", "The wax that forms the hive", "A part of the bee's wing"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "Why does a worker bee do the waggle dance?", correctAnswer: "To show others where flowers are", distractors: ["To wake up the queen bee", "To keep the hive warm", "To scare away other insects"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "What is the main idea of the honeybee passage?", correctAnswer: "Bees in a hive each have jobs", distractors: ["Bees are scary to be near", "Flowers need rain to grow", "Honey is a healthy snack"], tier: .hard, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en_3_lost_dog", tier: .easy, grades: 3...3,
            text: "On his way home from school, Marcus spotted a small white dog sitting under a bench. The dog was shivering, and it wore a red collar with a tag. Marcus read the tag. It said \"Biscuit\" and had a phone number. Marcus's mom called the number, and twenty minutes later a woman named Mrs. Lopez hurried down the street. \"Biscuit, there you are!\" she cried. She hugged the dog and thanked Marcus again and again.",
            questions: [
                BankQuestion(prompt: "Where did Marcus find the little white dog?", correctAnswer: "Under a bench", distractors: ["Behind the school", "In his backyard", "Next to a store"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "How did Marcus learn the dog's name?", correctAnswer: "He read the tag", distractors: ["A neighbor told him", "He made a guess", "His mom knew it"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Who is Mrs. Lopez?", correctAnswer: "Biscuit's owner", distractors: ["Marcus's teacher", "A dog trainer", "A police officer"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "How did Mrs. Lopez feel when she saw Biscuit?", correctAnswer: "Relieved and happy", distractors: ["Angry and upset", "Tired and bored", "Nervous and shy"], tier: .medium, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en_3_frog_life_cycle", tier: .medium, grades: 3...4,
            text: "A frog's life begins as a tiny egg floating in a pond. After a few days or weeks, the egg hatches into a tadpole. A tadpole looks more like a small fish than a frog. It has a long tail for swimming, and it breathes underwater with gills. As the tadpole grows, it sprouts back legs, and then front legs. Its tail slowly shrinks, and it grows lungs so it can breathe air. At last, the young frog hops out of the water onto land.",
            questions: [
                BankQuestion(prompt: "What hatches out of a frog egg?", correctAnswer: "A tadpole", distractors: ["A small frog", "A tiny fish", "A water bug"], tier: .easy, grades: 3...4),
                BankQuestion(prompt: "How does a tadpole breathe?", correctAnswer: "With gills underwater", distractors: ["With lungs on land", "Through its long tail", "Through its back legs"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "Which legs grow first on a tadpole?", correctAnswer: "Back legs", distractors: ["Front legs", "All four together", "None until it's a frog"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "How is the frog life cycle passage organized?", correctAnswer: "In the order things happen", distractors: ["From least to most exciting", "By comparing frogs and fish", "As a list of questions"], tier: .hard, grades: 3...4),
            ]),

        ReadingPassage(
            id: "en_3_school_garden", tier: .hard, grades: 3...4,
            text: "I think our school should start a garden. First, a garden would help us learn. We could measure how fast plants grow and watch how bees visit the flowers. Second, we could grow healthy food like lettuce, carrots, and tomatoes for the cafeteria. Some people say a garden is too much work. But if every class takes a turn watering and pulling weeds, no one would have too much to do. A school garden would be good for everyone! (Written by Grace, 3rd grade)",
            questions: [
                BankQuestion(prompt: "What does Grace want her school to do?", correctAnswer: "Start a garden", distractors: ["Build a playground", "Buy new books", "Get a class pet"], tier: .easy, grades: 3...4),
                BankQuestion(prompt: "Which foods does Grace say the school could grow?", correctAnswer: "Lettuce, carrots, and tomatoes", distractors: ["Apples, pears, and grapes", "Corn, beans, and peppers", "Potatoes, onions, and squash"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "How does Grace answer people who say a garden is too much work?", correctAnswer: "Every class could take a turn", distractors: ["Parents could do the work", "The garden could be tiny", "The school could hire a gardener"], tier: .hard, grades: 3...4),
                BankQuestion(prompt: "Why did Grace write this piece?", correctAnswer: "To get readers to agree with her", distractors: ["To tell a funny story", "To explain how seeds grow", "To describe a garden she visited"], tier: .hard, grades: 3...4),
            ]),

        ReadingPassage(
            id: "en_3_pinecone_feeder", tier: .easy, grades: 3...3,
            text: "You can make a simple bird feeder with a pinecone. First, tie a piece of string around the top of the pinecone. Next, use a plastic knife to spread sunflower seed butter all over it. Then roll the sticky pinecone in a plate of birdseed until it is covered. Finally, hang your feeder from a tree branch where you can see it from a window. Soon, hungry birds will stop by for a snack!",
            questions: [
                BankQuestion(prompt: "What do you do first to make the pinecone feeder?", correctAnswer: "Tie string around the top", distractors: ["Roll it in birdseed", "Hang it from a branch", "Spread seed butter on it"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What makes the birdseed stick to the pinecone?", correctAnswer: "Sunflower seed butter", distractors: ["A piece of string", "Water from the sink", "Glue from a bottle"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Why should you hang the feeder where you can see it from a window?", correctAnswer: "So you can watch the birds", distractors: ["So the birds stay dry", "So the feeder won't fall", "So it gets more sunlight"], tier: .medium, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en_3_snowflake_bentley", tier: .hard, grades: 3...4,
            text: "Long ago, a Vermont farm boy named Wilson Bentley loved snow. He wanted to show people how beautiful a single snowflake could be. But snowflakes melt fast, and they are very small. Wilson attached a camera to a microscope and practiced for years. In 1885, when he was nineteen, he took the first photograph of a single snowflake. Over his lifetime, he photographed more than 5,000 snowflakes. Because of this, people gave him the nickname \"Snowflake Bentley.\"",
            questions: [
                BankQuestion(prompt: "In which state did Wilson Bentley live?", correctAnswer: "Vermont", distractors: ["Maine", "Alaska", "Colorado"], tier: .easy, grades: 3...4),
                BankQuestion(prompt: "Why was it hard to photograph a snowflake?", correctAnswer: "They melt fast and are tiny", distractors: ["They fall only at night", "Cameras froze in the cold", "Farmers were too busy"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "How old was Wilson when he took his first snowflake photo?", correctAnswer: "Nineteen", distractors: ["Nine", "Twenty-nine", "Fifteen"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "Why did people call him \"Snowflake Bentley\"?", correctAnswer: "He photographed thousands of snowflakes", distractors: ["He was born on a very snowy day", "He could make it snow on his farm", "He built giant snowmen every winter"], tier: .hard, grades: 3...4),
            ]),

        // ——— 4th grade ———

        ReadingPassage(
            id: "en_4_monarchs", tier: .medium, grades: 4...5,
            text: "Every fall, millions of monarch butterflies begin an amazing journey. Monarchs that spend the summer in the eastern United States and Canada fly south to the mountains of central Mexico. Some travel as far as 3,000 miles.\n\nWhat makes this trip even more surprising is that none of these butterflies has ever made it before. Most monarchs live only a few weeks, but the butterflies born at the end of summer can live for several months. They spend the winter clustered together on fir trees, where the cool mountain air helps them rest. In spring, they head north again. Along the way, they lay eggs on milkweed plants, and it takes their children, grandchildren, and even great-grandchildren to finish the trip back.",
            questions: [
                BankQuestion(prompt: "Where do eastern monarchs spend the winter?", correctAnswer: "In the mountains of central Mexico", distractors: ["On the beaches of southern Florida", "In the forests of northern Canada", "In the deserts of Arizona"], tier: .easy, grades: 4...5),
                BankQuestion(prompt: "Why does the writer call the monarchs' trip surprising?", correctAnswer: "None of them has made the trip before", distractors: ["They fly only at night", "They travel in a straight line", "They never stop to rest"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "What does \"clustered\" most likely mean in the monarch passage?", correctAnswer: "Gathered close in a group", distractors: ["Hidden under the snow", "Spread far apart", "Flying in circles"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "What do monarchs do on milkweed plants during the trip north?", correctAnswer: "Lay eggs", distractors: ["Sleep for the winter", "Spin webs", "Build nests"], tier: .hard, grades: 4...5),
            ]),

        ReadingPassage(
            id: "en_4_railroad", tier: .hard, grades: 4...5,
            text: "In the 1860s, traveling across the United States could take months by wagon. Many Americans dreamed of a railroad that would connect the East to the West. Two companies took on the job. The Central Pacific started in California and built east, and the Union Pacific started near the Missouri River and built west.\n\nThe work was hard and often dangerous. Crews blasted tunnels through the Sierra Nevada mountains and laid track across hot, dry plains. Thousands of workers, including many immigrants from China and Ireland, did this difficult work. Finally, on May 10, 1869, the two lines met at Promontory Summit in the Utah Territory. A golden spike was tapped into the last tie. Now a trip across the country took about a week instead of months.",
            questions: [
                BankQuestion(prompt: "Where did the Central Pacific start building?", correctAnswer: "In California", distractors: ["Near the Missouri River", "In the Utah Territory", "In New York"], tier: .easy, grades: 4...5),
                BankQuestion(prompt: "Where did the two railroad lines meet?", correctAnswer: "At Promontory Summit", distractors: ["In the Sierra Nevada", "Near the Missouri River", "On the California coast"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "How did the railroad change travel across the country?", correctAnswer: "The trip became much faster", distractors: ["Wagon trips became faster", "People stopped moving west", "Trips became more dangerous"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "What does \"took on the job\" mean in the railroad passage?", correctAnswer: "Agreed to do the work", distractors: ["Refused to do the work", "Finished the work early", "Paid others to do the work"], tier: .hard, grades: 4...5),
            ]),

        ReadingPassage(
            id: "en_4_spelling_bee", tier: .medium, grades: 4...4,
            text: "Aiden's hands were sweaty as he walked onto the stage for the school spelling bee. For three weeks, he had practiced words with his dad every night after dinner. His first word was \"giraffe,\" and he spelled it perfectly. He also spelled \"library\" and \"February\" correctly.\n\nThen came \"necessary.\" Aiden took a deep breath and spelled it with two c's. The judge gently shook her head. Aiden sat down, disappointed. But when he looked out at the crowd, his dad gave him two thumbs up. On the way home, Aiden asked, \"Can we start practicing for next year tonight?\"",
            questions: [
                BankQuestion(prompt: "How did Aiden get ready for the spelling bee?", correctAnswer: "He practiced with his dad every night", distractors: ["He read the dictionary at school", "He studied with his teacher at lunch", "He practiced with friends on weekends"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "Which word did Aiden misspell?", correctAnswer: "Necessary", distractors: ["Giraffe", "February", "Library"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "What do Aiden's sweaty hands show?", correctAnswer: "He felt nervous", distractors: ["He was very hot", "He had been swimming", "He felt sick"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What does Aiden's question at the end show about him?", correctAnswer: "He wants to keep trying", distractors: ["He is angry at the judge", "He never wants to spell again", "He thinks he should have won"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en_4_water_cycle", tier: .easy, grades: 4...4,
            text: "The water you drink today may once have been part of a cloud, an ocean, or even a glacier. That is because Earth's water moves in a never-ending loop called the water cycle.\n\nIt starts when the sun warms water in oceans, lakes, and rivers. Some of the water evaporates, which means it turns into an invisible gas called water vapor and rises into the air. High in the sky, the air is cooler, so the vapor condenses into tiny droplets that form clouds. When the droplets join together and get too heavy, they fall as rain, snow, sleet, or hail. This is called precipitation. The water collects in oceans, lakes, and rivers, or soaks into the ground, and the cycle begins again.",
            questions: [
                BankQuestion(prompt: "What does \"evaporates\" mean in the water cycle passage?", correctAnswer: "Turns into a gas", distractors: ["Turns into ice", "Falls from the sky", "Soaks into soil"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "What makes water vapor turn into clouds?", correctAnswer: "Cooler air high in the sky", distractors: ["Warm wind near the ground", "Sunlight hitting the ocean", "Rain falling on lakes"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "Which of these is a kind of precipitation named in the passage?", correctAnswer: "Hail", distractors: ["Fog", "Dew", "Frost"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "Why does the writer say the water you drink may once have been part of a cloud?", correctAnswer: "Water keeps moving through the cycle", distractors: ["Clouds are made of drinking water", "All water comes from glaciers", "Rain is cleaner than lake water"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en_4_rain_gauge", tier: .medium, grades: 4...5,
            text: "Want to find out how much rain falls where you live? You can build a rain gauge.\n\nYou will need a clear plastic jar with straight sides and a flat bottom, a ruler, and tape. Tape the ruler to the outside of the jar so that the zero mark lines up with the bottom. Place the jar outside in an open spot, away from trees and roofs that could block the rain or drip extra water into it. After each rainfall, read the water level at eye level and write it down in a notebook. Then empty the jar so it is ready for the next storm. After a month, add up your numbers to find the total rainfall.",
            questions: [
                BankQuestion(prompt: "Why should the ruler's zero mark line up with the bottom of the jar?", correctAnswer: "So the measurement is correct", distractors: ["So the ruler stays dry", "So the jar won't tip over", "So the tape sticks better"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "Why should the rain gauge be placed away from trees?", correctAnswer: "Trees could block or add water", distractors: ["Trees could scare birds away", "Trees make the jar too cold", "Trees could knock it over"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "What should you do after you write down the water level?", correctAnswer: "Empty the jar", distractors: ["Refill the jar", "Move the jar indoors", "Take off the ruler"], tier: .easy, grades: 4...5),
                BankQuestion(prompt: "What is the writer's purpose in the rain gauge passage?", correctAnswer: "To explain how to build and use a tool", distractors: ["To tell a story about a big storm", "To convince readers to enjoy rain", "To compare different kinds of weather"], tier: .hard, grades: 4...5),
            ]),

        ReadingPassage(
            id: "en_4_longer_recess", tier: .hard, grades: 4...5,
            text: "Dear Principal Adams,\n\nMy name is Sofia Ramirez, and I am in Mrs. Chen's fourth-grade class. I am writing to ask you to make recess 10 minutes longer.\n\nRight now, recess is only 20 minutes. By the time we put on our coats and line up to go outside, we have even less time to play. Running around helps our bodies stay healthy. After recess, my classmates and I are calmer and ready to focus. I know that a longer recess means less class time. But if we pay attention better, we will learn more in the time we have.\n\nThank you for thinking about my idea.\n\nSincerely,\nSofia",
            questions: [
                BankQuestion(prompt: "How long is recess right now, according to Sofia?", correctAnswer: "20 minutes", distractors: ["10 minutes", "30 minutes", "45 minutes"], tier: .easy, grades: 4...5),
                BankQuestion(prompt: "What problem with recess time does Sofia point out?", correctAnswer: "Getting ready uses up play time", distractors: ["Recess starts too early", "The playground is too small", "Lunch is too short to finish"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "Which reason does Sofia give for a longer recess?", correctAnswer: "Kids focus better after playing", distractors: ["Teachers need more breaks", "The playground has new swings", "Other schools have longer recess"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "How does Sofia answer the worry that a longer recess means less class time?", correctAnswer: "Kids will learn more by focusing better", distractors: ["Class time is not very important", "The school day should be longer", "Teachers can give more homework"], tier: .hard, grades: 4...5),
            ]),

        // ——— 5th grade ———

        ReadingPassage(
            id: "en_5_ocean_zones", tier: .medium, grades: 5...5,
            text: "The ocean is not the same from top to bottom. Scientists divide it into layers, or zones, based on how much sunlight reaches them.\n\nThe top layer is the sunlight zone, which reaches down about 650 feet. It is warm and bright, so plants and algae can grow there, and most ocean animals live in this zone. Below it lies the twilight zone. Only a little light reaches this layer, and plants cannot grow. Deeper still, starting at around 3,300 feet, is the midnight zone. No sunlight reaches it at all. The water is very cold, and the pressure is enormous. Yet animals live here too. Many of them make their own light, called bioluminescence, to find food or attract mates in the darkness.",
            questions: [
                BankQuestion(prompt: "How do scientists divide the ocean into zones?", correctAnswer: "By how much sunlight reaches them", distractors: ["By how salty the water is", "By which animals live there", "By how far they are from land"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why can plants grow in the sunlight zone but not in the twilight zone?", correctAnswer: "Too little light reaches the twilight zone", distractors: ["The twilight zone is too salty", "Animals eat all the plants there", "The twilight zone is too warm"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What does \"bioluminescence\" mean?", correctAnswer: "Light that living things make", distractors: ["A kind of deep-sea plant", "The pressure of deep water", "The cold at the ocean floor"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Which detail shows that the midnight zone is a hard place to live?", correctAnswer: "It is dark and cold, with enormous pressure", distractors: ["Most ocean animals live there", "Plants and algae grow there", "It reaches down about 650 feet"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en_5_lewis_and_clark", tier: .hard, grades: 5...6,
            text: "In 1803, the United States bought a huge area of land from France, called the Louisiana Purchase. President Thomas Jefferson wanted to know what was there. He chose Meriwether Lewis to lead a group, called the Corps of Discovery, to explore it and look for a water route to the Pacific Ocean. Lewis asked William Clark to share the command.\n\nThe group set out from near St. Louis in May 1804. They traveled up the Missouri River in boats, mapped rivers and mountains, and recorded hundreds of plants and animals that were new to them. A young Shoshone woman named Sacagawea traveled with them, carrying her baby son. She helped as an interpreter, and her presence showed the Native American nations they met that the group was not a war party. In November 1805, the explorers finally reached the Pacific Ocean. They did not find an all-water route, but the maps and notes they brought home in 1806 changed how Americans understood the West.",
            questions: [
                BankQuestion(prompt: "Why did President Jefferson send the Corps of Discovery?", correctAnswer: "To explore the land and seek a route west", distractors: ["To buy the land from France", "To start a new town in the West", "To search for gold in the mountains"], tier: .medium, grades: 5...6),
                BankQuestion(prompt: "How did the explorers travel at the start of the trip?", correctAnswer: "Up the Missouri River in boats", distractors: ["Across the plains on horses", "By train from St. Louis", "Along the coast on a ship"], tier: .easy, grades: 5...6),
                BankQuestion(prompt: "According to the passage, how did Sacagawea help the group?", correctAnswer: "She was an interpreter, and she showed others that the group came in peace", distractors: ["She drew the maps of every river", "She built the boats for the journey", "She found them an all-water route"], tier: .medium, grades: 5...6),
                BankQuestion(prompt: "What was one result of the Lewis and Clark expedition?", correctAnswer: "Their maps changed how Americans saw the West", distractors: ["They found an all-water route to the ocean", "They bought the Louisiana land from France", "They built a settlement on the Pacific coast"], tier: .hard, grades: 5...6),
            ]),

        ReadingPassage(
            id: "en_5_science_fair", tier: .medium, grades: 5...5,
            text: "For the science fair, Mei wanted to find out which brand of paper towel soaked up the most water. She was sure the most expensive brand would win.\n\nMei cut one square from each of three brands, each exactly the same size. She dipped every square into a cup of water for five seconds, then squeezed the water into a measuring cup. She repeated the test three times for each brand to make sure her results weren't just a fluke. To her surprise, the cheapest brand soaked up the most water every time. At first, Mei was disappointed that her guess was wrong. Then her teacher, Mr. Okafor, reminded her that a surprising result is still a real discovery. Mei proudly wrote \"My hypothesis was not supported\" at the top of her poster.",
            questions: [
                BankQuestion(prompt: "What did Mei predict before her experiment?", correctAnswer: "The priciest brand would win", distractors: ["The cheapest brand would win", "All the brands would tie", "No brand would soak much"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why did Mei cut all the squares the same size?", correctAnswer: "To make the test fair", distractors: ["To save paper towels", "To fit them in the cup", "To make the poster neat"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What does \"fluke\" most likely mean?", correctAnswer: "A lucky accident", distractors: ["A careful plan", "A kind of paper", "A rule of science"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What did Mr. Okafor help Mei understand?", correctAnswer: "A surprising result is still a discovery", distractors: ["Her experiment was done the wrong way", "She should change her results to match", "Expensive brands are always the best"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en_5_fall_leaves", tier: .easy, grades: 5...5,
            text: "Why do leaves turn from green to red, orange, and yellow in the fall? The answer is hiding inside the leaf all along.\n\nDuring spring and summer, leaves are full of a green chemical called chlorophyll. Chlorophyll helps the tree use sunlight to make food. There is so much of it that the green covers up the other colors in the leaf. As fall arrives, the days get shorter and cooler, and trees stop making chlorophyll. As the green fades, yellow and orange colors that were there the whole time begin to show. Some trees, like red maples, also make new red and purple colors in the fall. That is why a red maple can seem to glow in October.",
            questions: [
                BankQuestion(prompt: "What does chlorophyll help a tree do?", correctAnswer: "Use sunlight to make food", distractors: ["Grow new branches", "Drink water from the ground", "Keep its leaves warm"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why can't we see yellow and orange in summer leaves?", correctAnswer: "The green chlorophyll covers them up", distractors: ["Those colors are made only in fall", "The summer sun bleaches them away", "Summer rain washes the colors off"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What causes trees to stop making chlorophyll?", correctAnswer: "Shorter, cooler days", distractors: ["Heavy spring rain", "Hungry insects", "Strong summer winds"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Which colors does the passage say were in the leaf the whole time?", correctAnswer: "Yellow and orange", distractors: ["Red and purple", "Green and brown", "Blue and pink"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en_5_kids_should_cook", tier: .hard, grades: 5...6,
            text: "Every student should learn to cook before finishing elementary school. Cooking is a life skill, just like reading a map or counting money.\n\nFirst, cooking uses the things we learn in class. When you double a recipe, you are multiplying fractions. When you watch water boil or bread rise, you are seeing science in action. Second, kids who can cook are more independent. They can make a simple breakfast or help get dinner ready when their families are busy. Finally, people who cook for themselves often choose fresher foods.\n\nSome parents worry that kitchens are too dangerous for kids. That is a fair concern. However, with an adult nearby and simple rules, like using oven mitts and turning pot handles inward, children can cook safely. The benefits are too important to skip.",
            questions: [
                BankQuestion(prompt: "What is the main claim of the cooking passage?", correctAnswer: "Every student should learn to cook", distractors: ["Kitchens are too dangerous for kids", "Math matters more than cooking", "Families should eat out more often"], tier: .easy, grades: 5...6),
                BankQuestion(prompt: "Which example does the writer use to connect cooking to math?", correctAnswer: "Doubling a recipe", distractors: ["Watching water boil", "Using oven mitts", "Making breakfast"], tier: .medium, grades: 5...6),
                BankQuestion(prompt: "What is the counterclaim in the cooking passage?", correctAnswer: "Kitchens may be too dangerous", distractors: ["Cooking uses math and science", "Kids who cook are independent", "Fresh foods are a better choice"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "How does the writer respond to the worry about kitchen safety?", correctAnswer: "An adult and simple rules keep kids safe", distractors: ["Kids should only make cold foods", "Parents worry too much in general", "Only teenagers should use a kitchen"], tier: .hard, grades: 5...6),
            ]),

        ReadingPassage(
            id: "en_5_set_up_tent", tier: .easy, grades: 5...5,
            text: "Setting up a tent is easier when you follow the steps in order.\n\n1. Choose a flat spot and clear away sticks and rocks so they don't poke through the floor.\n2. Lay a ground cloth down first. It protects the bottom of the tent from dampness.\n3. Spread the tent on top of the ground cloth with the door facing the way you want.\n4. Slide the poles through the sleeves or clip them onto the tent, then raise it up.\n5. Push stakes into the ground at each corner, angled away from the tent, to hold it steady.\n6. If rain is possible, attach the rain fly over the top.\n\nPractice once in your backyard before your trip, so you're not learning in the dark!",
            questions: [
                BankQuestion(prompt: "Why should you clear away sticks and rocks before setting up a tent?", correctAnswer: "So they don't poke through the floor", distractors: ["So the tent stays warm at night", "So animals stay away from camp", "So the stakes are easier to push"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "What is the purpose of the ground cloth?", correctAnswer: "It keeps dampness off the tent bottom", distractors: ["It keeps bugs out of the tent", "It holds the poles in place", "It covers the top when it rains"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Which step comes right after spreading the tent out?", correctAnswer: "Adding the poles", distractors: ["Laying the ground cloth", "Clearing the spot", "Attaching the rain fly"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Why does the writer suggest practicing in your backyard?", correctAnswer: "So you are not learning in the dark", distractors: ["So a neighbor can help you", "So the tent can dry out first", "So you can test the weather"], tier: .hard, grades: 5...5),
            ]),

        // ——— 6th grade ———

        ReadingPassage(
            id: "en_6_dust_bowl", tier: .hard, grades: 6...7,
            text: "In the early 1900s, farmers poured into the southern Great Plains, in states like Oklahoma, Kansas, and Texas. Wheat prices were high, and new tractors made it possible to plow huge fields. Farmers tore up millions of acres of native prairie grass. Those deep-rooted grasses had held the soil in place for thousands of years.\n\nThen, in the 1930s, a severe drought struck. With no grass roots to anchor it, the dry topsoil turned to dust. Powerful winds lifted it into enormous clouds called \"black blizzards\" that could block out the sun. On April 14, 1935, a day later called Black Sunday, one of the worst storms rolled across the plains. Dust piled up like snowdrifts against houses, and many families packed up and moved west, hoping for a fresh start.\n\nThe disaster taught the nation a hard lesson. In 1935, the government created the Soil Conservation Service to teach farmers methods like planting rows of trees as windbreaks and plowing along the curves of the land. These practices helped protect the soil for the future.",
            questions: [
                BankQuestion(prompt: "What had held the soil of the Great Plains in place for thousands of years?", correctAnswer: "Deep-rooted prairie grasses", distractors: ["Long rows of wheat", "Thick pine forests", "Stone walls built by farmers"], tier: .easy, grades: 6...7),
                BankQuestion(prompt: "What were \"black blizzards\"?", correctAnswer: "Huge clouds of blowing dust", distractors: ["Winter storms with dark snow", "Swarms of insects eating crops", "Thunderstorms with heavy rain"], tier: .medium, grades: 6...7),
                BankQuestion(prompt: "According to the passage, which two things together caused the Dust Bowl?", correctAnswer: "Plowed-up grassland and a severe drought", distractors: ["High wheat prices and cold winters", "Too many trees and heavy rains", "New tractors and flooded rivers"], tier: .hard, grades: 6...7),
                BankQuestion(prompt: "What was the purpose of the Soil Conservation Service?", correctAnswer: "To teach farmers ways to protect the soil", distractors: ["To help families move to the West", "To buy farms from struggling families", "To raise the price of wheat again"], tier: .medium, grades: 6...7),
            ]),

        ReadingPassage(
            id: "en_6_tardigrades", tier: .medium, grades: 6...6,
            text: "If you scoop up a clump of damp moss and look at it under a microscope, you might meet one of the toughest animals on Earth: the tardigrade. Tardigrades are usually less than a millimeter long. They have eight stubby legs with tiny claws, and they lumber along so slowly that people nicknamed them \"water bears.\"\n\nWhat makes tardigrades remarkable is their ability to survive conditions that would kill most living things. When their home dries out, many tardigrades curl up and lose almost all the water in their bodies. In this state, called a tun, their bodies nearly stop working. A tun can survive extreme cold, a lack of oxygen, and even high doses of radiation. When water returns, the tardigrade can soak it up and start moving again, sometimes after years.\n\nScientists study tardigrades hoping to learn how cells can be protected from damage. Their secrets might one day help preserve medicines that normally need to be kept cold.",
            questions: [
                BankQuestion(prompt: "Where does the writer say you might find a tardigrade?", correctAnswer: "In damp moss", distractors: ["In a bear's fur", "In an ice cube", "In a honeycomb"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "Why were tardigrades nicknamed \"water bears\"?", correctAnswer: "They lumber slowly on stubby legs", distractors: ["They catch fish the way bears do", "They sleep through the whole winter", "They are covered in thick fur"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What is a tun?", correctAnswer: "A dried-out state that helps it survive", distractors: ["A tiny claw on a tardigrade's leg", "A type of moss where tardigrades live", "A microscope used to see tardigrades"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What does \"remarkable\" mean in the second paragraph about tardigrades?", correctAnswer: "Worth noticing because it is unusual", distractors: ["Small and very hard to find", "Common and ordinary", "Slow and clumsy"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en_6_chess_abuelo", tier: .medium, grades: 6...6,
            text: "Every Sunday, Diego walked two blocks to his grandfather's apartment to play chess. For as long as he could remember, Abuelo had won every game. He never let Diego win on purpose, either. \"A victory you didn't earn,\" Abuelo liked to say, \"is like a sandwich made of air.\"\n\nThis fall, Diego had joined the chess club at school. He learned openings, studied famous old games, and solved puzzles on the bus. On the first cold Sunday in November, he moved his knight, and Abuelo went quiet. Abuelo studied the board for a long time. Then he tipped over his king, a sign that he was giving up.\n\nDiego expected to feel like shouting. Instead, he felt strangely calm. Abuelo was grinning so widely that his glasses slid down his nose. \"Now,\" Abuelo said, reaching for the pieces to set up another game, \"that sandwich has something in it.\"",
            questions: [
                BankQuestion(prompt: "What did Diego do this fall to get better at chess?", correctAnswer: "He joined the chess club at school", distractors: ["He played online every single night", "He took lessons from a champion", "He watched his grandfather play others"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "What does it mean when Abuelo tips over his king?", correctAnswer: "He is giving up the game", distractors: ["He is making a new move", "He wants to take a break", "He is angry at Diego"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What does Abuelo mean by \"a sandwich made of air\"?", correctAnswer: "A win you did not earn feels empty", distractors: ["Sandwiches are not a healthy lunch", "Playing chess makes a person hungry", "Winning does not matter at all"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "How does Abuelo feel about losing to Diego?", correctAnswer: "Proud and happy", distractors: ["Upset and embarrassed", "Bored and tired", "Confused and worried"], tier: .medium, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en_6_phones_in_lockers", tier: .hard, grades: 6...7,
            text: "At Westbrook Middle School, students may keep their phones in their pockets during class as long as the phones stay silent. I believe this rule should change: phones should stay in lockers during class time.\n\nThe biggest problem is distraction. Even a silent phone buzzes, lights up, and tempts us to check it. In a survey our student council gave to 200 Westbrook students, 64 percent admitted they had checked a phone during a lesson in the past week. Every glance pulls attention away from the teacher. Keeping phones in lockers would also give students a break from group chats and social media during the school day.\n\nSome students argue that they need their phones in case of an emergency. This is an understandable worry. However, every classroom already has a phone, and the front office can reach any family within minutes. In a real emergency, a teacher can contact help faster than a student searching for a signal. Our phones will still be there at the end of the day; the lessons we miss will not.",
            questions: [
                BankQuestion(prompt: "What change to the phone rule does the writer want?", correctAnswer: "Keep phones in lockers during class", distractors: ["Ban phones from the school building", "Let students use phones if silent", "Give every student a school phone"], tier: .easy, grades: 6...7),
                BankQuestion(prompt: "What evidence does the writer use to support the point about distraction?", correctAnswer: "A student council survey", distractors: ["A study by a university", "A quote from the principal", "A story about a friend"], tier: .medium, grades: 6...7),
                BankQuestion(prompt: "Which of these is the counterclaim the writer responds to?", correctAnswer: "Students may need phones for emergencies", distractors: ["Silent phones still tempt students", "Every glance pulls attention away", "Phones will still be there later"], tier: .hard, grades: 6...7),
                BankQuestion(prompt: "What does the writer mean by \"Our phones will still be there at the end of the day; the lessons we miss will not\"?", correctAnswer: "Time lost in class can't be made up", distractors: ["Teachers will stop giving lessons", "Lessons are stored in the lockers", "Students will forget their phones"], tier: .hard, grades: 6...7),
            ]),

        ReadingPassage(
            id: "en_6_needle_compass", tier: .easy, grades: 6...6,
            text: "Long before GPS, sailors used compasses to find their way. You can make a simple compass with a few household items.\n\nMaterials: a sewing needle, a small magnet, a thin slice of cork, and a shallow bowl of water.\n\nStep 1: Hold the needle by its eye. Stroke the magnet along the needle from the eye to the point about 30 times, always in the same direction. Lift the magnet away at the end of each stroke; rubbing back and forth will cancel out the effect.\nStep 2: Carefully lay the needle on the cork slice.\nStep 3: Float the cork in the middle of the bowl, away from metal objects.\n\nWatch as the cork slowly turns. The needle has become a weak magnet, so it lines up with Earth's magnetic field and points north and south. To check which end points north, compare it with a compass app on a phone.",
            questions: [
                BankQuestion(prompt: "Why must you stroke the magnet along the needle in only one direction?", correctAnswer: "Rubbing back and forth cancels the effect", distractors: ["It keeps the needle from breaking", "It helps the needle float on water", "It makes the magnet itself stronger"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "Why should the bowl be kept away from metal objects?", correctAnswer: "Metal could pull the needle off course", distractors: ["Metal could make the water too cold", "Metal could cause the cork to sink", "Metal could make the needle rust"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "Why does the floating needle point north and south?", correctAnswer: "It lines up with Earth's magnetic field", distractors: ["The water current pushes it that way", "The cork always turns to face north", "Sunlight pulls on the metal needle"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What is the purpose of the first paragraph of the compass instructions?", correctAnswer: "To connect the project to history", distractors: ["To list the materials needed", "To warn readers about needles", "To explain how GPS works"], tier: .medium, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en_6_leap_year", tier: .medium, grades: 6...7,
            text: "A year is supposed to measure how long Earth takes to travel once around the sun. The problem is that this trip doesn't take a neat 365 days. It takes about 365 and one-quarter days.\n\nThat extra quarter day may not sound like much, but it adds up. If calendars ignored it, they would slip about one day every four years. After a century, the calendar would be off by nearly a month. Over several centuries, summer heat would start arriving in months the calendar called fall.\n\nThe fix is the leap year. About every four years, an extra day, February 29, is added to the calendar. But even this correction is a little too much, because the real extra time is slightly less than a quarter of a day. So there is one more rule: years that end in 00 are leap years only if they can be divided evenly by 400. That is why 2000 was a leap year, but 1900 was not.",
            questions: [
                BankQuestion(prompt: "According to the passage, how long does Earth take to travel around the sun?", correctAnswer: "About 365 and one-quarter days", distractors: ["Exactly 365 days", "About 366 and one-half days", "About 364 and three-quarter days"], tier: .easy, grades: 6...7),
                BankQuestion(prompt: "What would happen if calendars ignored the extra quarter day?", correctAnswer: "The calendar would drift from the seasons", distractors: ["Every month would lose one day", "Earth would orbit the sun faster", "February would vanish from the calendar"], tier: .medium, grades: 6...7),
                BankQuestion(prompt: "Why was 1900 not a leap year?", correctAnswer: "It ends in 00 and isn't divisible by 400", distractors: ["It cannot be divided evenly by 4", "Leap years did not start until 2000", "February was skipped entirely that year"], tier: .hard, grades: 6...7),
                BankQuestion(prompt: "What does \"correction\" mean in the leap year passage?", correctAnswer: "A change that fixes an error", distractors: ["A mistake in the calendar", "A special national holiday", "An extra month of the year"], tier: .medium, grades: 6...7),
            ]),

        // ——— 7th grade ———

        ReadingPassage(
            id: "en_7_harriet_tubman", tier: .hard, grades: 7...8,
            text: "Harriet Tubman was born into slavery in Maryland around 1822. As an adolescent, she suffered a severe head injury when an overseer threw a heavy weight at another enslaved person and struck her instead. For the rest of her life, she had sudden sleeping spells, but the injury did not stop her.\n\nIn 1849, Tubman escaped, traveling mostly at night until she reached Pennsylvania, a free state. Freedom alone did not satisfy her. She later described feeling lonely there, because the people she loved were still enslaved. Over the next decade, she returned to Maryland about 13 times, guiding roughly 70 people, including members of her own family, along the network of secret routes and safe houses known as the Underground Railroad. She later said she never lost a single passenger.\n\nDuring the Civil War, Tubman served the Union Army as a scout, spy, and nurse. In 1863, she helped lead a raid along the Combahee River in South Carolina that freed more than 700 enslaved people.",
            questions: [
                BankQuestion(prompt: "Why wasn't Tubman satisfied with only her own freedom?", correctAnswer: "The people she loved were still enslaved", distractors: ["She wanted to become famous quickly", "She disliked the weather in Pennsylvania", "She wanted to join the army right away"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "What does the detail about her head injury reveal about Tubman?", correctAnswer: "She kept going despite serious hardship", distractors: ["She was often careless and clumsy", "She could never travel on her own", "Her injury ended her work early"], tier: .hard, grades: 7...8),
                BankQuestion(prompt: "In the Tubman passage, what was the Underground Railroad?", correctAnswer: "A network of secret routes and safe houses", distractors: ["A train that ran in tunnels to the North", "A group of soldiers in the Union Army", "A river crossing in South Carolina"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "How is the Harriet Tubman passage mainly organized?", correctAnswer: "In chronological order", distractors: ["By comparing two people", "As a list of opinions", "From least to most famous"], tier: .medium, grades: 7...8),
            ]),

        ReadingPassage(
            id: "en_7_coral_reefs", tier: .medium, grades: 7...7,
            text: "Coral reefs look like colorful underwater gardens, but corals are not plants. Most corals are colonies of tiny animals called polyps. A polyp has a soft body and builds a hard skeleton of limestone around itself. Over hundreds or thousands of years, generations of polyps build reefs large enough to be seen from space.\n\nCorals depend on a partnership. Microscopic algae live inside the polyps' tissues. The algae use sunlight to make food and share much of it with the coral. In return, the coral gives the algae a protected home. The algae also give many corals much of their color.\n\nThis partnership is fragile. When ocean water stays too warm for too long, stressed corals push the algae out. Without them, the coral turns white, a process called coral bleaching. A bleached coral is not dead yet, and it can recover if conditions improve. But if the stress lasts too long, the coral may starve.",
            questions: [
                BankQuestion(prompt: "What are coral polyps?", correctAnswer: "Tiny animals that build limestone skeletons", distractors: ["Small plants that grow on ocean rocks", "Microscopic algae that make their food", "Little fish that live inside the reef"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "What do corals give the algae in their partnership?", correctAnswer: "A protected home", distractors: ["Extra sunlight", "Warmer water", "Bright colors"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What does \"fragile\" mean as it is used in the coral passage?", correctAnswer: "Easily damaged", distractors: ["Very colorful", "Extremely old", "Hard to see"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "Based on the passage, why might a bleached coral starve?", correctAnswer: "It lost the algae that shared food with it", distractors: ["The warm water dissolved its skeleton", "Nearby fish ate all of its food", "Its white color attracted predators"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en_7_audition", tier: .hard, grades: 7...7,
            text: "The auditorium smelled like dust and floor polish. I sat in the third row, clutching a crumpled page of lines, while Jada Brooks auditioned for the spring play. She was flawless. When she finished, even Ms. Rivera, who never clapped during auditions, clapped.\n\n\"Lily Tran?\" Ms. Rivera called.\n\nMy legs felt like they belonged to someone else. I climbed the steps, stood in the spotlight, and opened my mouth. Nothing came out. The silence stretched until it seemed to fill the whole room. Then, from the third row, I heard a whisper: \"You've got this.\" It was Jada.\n\nI unfolded the page, even though I knew every word by heart, and began. My voice shook on the first line and steadied on the second. By the end, I had forgotten about the spotlight entirely. I didn't know yet whether I'd get a part. But walking back down those steps, I realized the hardest part of the audition hadn't been the lines at all.",
            questions: [
                BankQuestion(prompt: "Why does the narrator mention that Ms. Rivera \"never clapped during auditions\"?", correctAnswer: "To show how impressive Jada was", distractors: ["To show that Ms. Rivera is unkind", "To show that the audition ran late", "To describe how the auditorium smelled"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What does \"My legs felt like they belonged to someone else\" suggest?", correctAnswer: "Lily was so nervous she felt unsteady", distractors: ["Lily had hurt her legs on the steps", "Lily was wearing borrowed shoes", "Lily was eager to run onto the stage"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What part does Jada play in the turning point of the story?", correctAnswer: "Her encouragement helps Lily begin", distractors: ["Her perfect audition makes Lily quit", "She takes Lily's part in the play", "She reads Lily's lines out loud for her"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "What does Lily realize at the end of the audition story?", correctAnswer: "Facing her fear was harder than the lines", distractors: ["She should have practiced her lines more", "Jada deserves the lead more than she does", "Acting is not the right hobby for her"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en_7_skate_park", tier: .medium, grades: 7...8,
            text: "Linden Heights has four baseball fields, two tennis courts, and a public pool. It does not have a single place where teens can legally skateboard. The town council should approve the proposed skate park at Miller Field.\n\nFirst, a skate park would give young people a safe place to practice. Right now, skaters use parking lots, stair rails, and sidewalks, where they risk collisions with cars and pedestrians. Second, skateboarding is good exercise. It builds balance, strength, and persistence, since every trick takes dozens of attempts to master. Third, a skate park would be affordable. The proposed design costs about $250,000, and a local business group has already offered to cover one-third of that amount.\n\nOpponents worry that a skate park would bring noise and litter to the neighborhood around Miller Field. These are reasonable concerns, but they can be managed. The plan includes trash cans, posted hours from 8 a.m. to 8 p.m., and a sound-reducing wall facing nearby homes. The town has made room for many other sports. It is time to make room for this one.",
            questions: [
                BankQuestion(prompt: "What is the writer's central claim about Linden Heights?", correctAnswer: "The town should approve the skate park", distractors: ["Skateboarding should be banned downtown", "The town needs more baseball fields", "Teens should skate only in parking lots"], tier: .easy, grades: 7...8),
                BankQuestion(prompt: "According to the writer, where do skaters practice right now?", correctAnswer: "Parking lots, stair rails, and sidewalks", distractors: ["Baseball fields and tennis courts", "The public pool deck and park paths", "School gyms and playgrounds"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "About how much has the business group offered to pay for the skate park?", correctAnswer: "About $83,000", distractors: ["About $250,000", "About $125,000", "About $25,000"], tier: .hard, grades: 7...8),
                BankQuestion(prompt: "How does the writer address the concern about noise and litter?", correctAnswer: "By pointing to the plan's trash cans, posted hours, and sound wall", distractors: ["By saying the neighbors should move away", "By arguing that noise is not a real problem", "By suggesting a different location instead"], tier: .hard, grades: 7...8),
            ]),

        ReadingPassage(
            id: "en_7_how_a_bill_becomes_law", tier: .medium, grades: 7...8,
            text: "In the United States, federal laws are made by Congress, which has two parts: the House of Representatives and the Senate. The path from idea to law has several steps, and a bill can fail at any of them.\n\nFirst, a member of Congress introduces a bill. It is sent to a committee, a smaller group of lawmakers who study the topic closely. The committee may hold hearings, make changes, or simply set the bill aside. If the committee approves it, the full chamber debates and votes. A bill that passes one chamber must then pass the other in exactly the same form. If the House and Senate pass different versions, they must work out their differences first.\n\nNext, the bill goes to the president. If the president signs it, it becomes law. If the president vetoes, or rejects, it, the bill returns to Congress. Congress can still make it a law by overriding the veto, but that requires a two-thirds vote in both the House and the Senate, which is difficult to achieve. This system of checks is designed so that no single part of the government has too much power.",
            questions: [
                BankQuestion(prompt: "What does a congressional committee do with a bill?", correctAnswer: "Studies it closely and may change it", distractors: ["Signs it into law right away", "Overrides the president's veto", "Sends it straight to the president"], tier: .easy, grades: 7...8),
                BankQuestion(prompt: "What does \"vetoes\" mean in the passage about Congress?", correctAnswer: "Rejects", distractors: ["Signs", "Rewrites", "Introduces"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "What must happen for Congress to override a veto?", correctAnswer: "A two-thirds vote in both chambers", distractors: ["A simple majority in the House", "A new hearing in a committee", "A signature from the president"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "Why does the writer call the lawmaking process a system of checks?", correctAnswer: "It keeps power from piling up in one place", distractors: ["It makes new laws faster to pass", "It lets the president make laws alone", "It lets committees skip the votes"], tier: .hard, grades: 7...8),
            ]),

        ReadingPassage(
            id: "en_7_creek_cleanup", tier: .easy, grades: 7...7,
            text: "WILLOW CREEK — Forty-two students from Willow Creek Middle School spent last Saturday morning knee-deep in the creek that gives their town its name.\n\nArmed with gloves, buckets, and grabbers, the seventh graders pulled 380 pounds of trash from a half-mile stretch of water, including plastic bottles, a shopping cart, and three bicycle tires. The cleanup was part of a science unit on watersheds, which are areas of land where all the rain and melted snow drain into the same body of water.\n\n\"We learned that trash dropped in a parking lot miles away can wash into this creek during a storm,\" said student organizer Omar Haddad, 12. \"So it's not just a creek problem. It's an everyone problem.\"\n\nScience teacher Karen Whitfield said the class will test the creek's water quality each month through June. The students also plan to paint reminders beside storm drains near the school.",
            questions: [
                BankQuestion(prompt: "How much trash did the Willow Creek students remove?", correctAnswer: "380 pounds", distractors: ["42 pounds", "180 pounds", "38 pounds"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "What is a watershed, as defined in the article?", correctAnswer: "Land that drains into one body of water", distractors: ["A shed for storing cleanup gear", "A dam that holds back a creek", "A storm that floods a whole town"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What does Omar mean when he calls it \"an everyone problem\"?", correctAnswer: "Trash from far away can reach the creek", distractors: ["Everyone in town lives beside the creek", "Everyone should help test the water", "The creek belongs to all the students"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "Why do the students most likely plan to paint reminders beside storm drains?", correctAnswer: "To stop trash from washing into the creek", distractors: ["To mark where the class tests water", "To decorate the parking lot for June", "To show where the shopping cart was"], tier: .hard, grades: 7...7),
            ]),

        // ——— 8th grade ———

        ReadingPassage(
            id: "en_8_printing_press", tier: .medium, grades: 8...8,
            text: "Before the mid-1400s, books in Europe were copied by hand, often by monks who might spend months on a single volume. Books were so rare and expensive that mostly churches, universities, and the very wealthy owned them.\n\nAround 1440, Johannes Gutenberg, a goldsmith from Mainz, Germany, began developing a printing press that used movable metal type. Each letter was cast as a separate small block. Workers arranged the letters into lines, inked them, and pressed them onto paper. When a page was finished, the letters could be taken apart and reused. Gutenberg's workshop completed its famous Bible around 1455.\n\nThe impact was enormous. By 1500, printing shops had spread to more than 200 cities across Europe, and millions of books had been produced. As books became cheaper, more people learned to read. Scientists could share discoveries quickly and accurately, and new ideas, including challenges to powerful institutions, spread faster than any authority could control them. Historians often rank the printing press among the most important inventions in human history.",
            questions: [
                BankQuestion(prompt: "Why were books rare in Europe before the printing press?", correctAnswer: "Each one had to be copied by hand", distractors: ["Paper had not been invented yet", "Very few people wanted to read", "Churches did not allow any books"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "What made Gutenberg's movable type so efficient?", correctAnswer: "The letters could be rearranged and reused", distractors: ["Each page was carved from a single block", "The ink never needed any time to dry", "Monks could print books in their homes"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Which effect of the printing press is stated in the passage?", correctAnswer: "More people learned to read", distractors: ["Monks became goldsmiths", "Universities shut down", "Books grew more expensive"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What does \"spread faster than any authority could control them\" suggest?", correctAnswer: "Leaders could no longer easily stop ideas", distractors: ["Books were banned all across Europe", "Printers worked only for the government", "New ideas were mostly ignored by readers"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en_8_zebra_mussels", tier: .hard, grades: 8...8,
            text: "In 1988, researchers found an unfamiliar striped mussel, no bigger than a fingernail, in Lake St. Clair, which connects Lake Huron and Lake Erie. Scientists believe the zebra mussel, native to the region around the Black and Caspian Seas, arrived in the ballast water of cargo ships. Ships take on this water for stability and release it when they reach port, along with any stowaways inside.\n\nWith few natural predators to keep them in check, zebra mussels multiplied rapidly. A single female can release hundreds of thousands of eggs in a year. The mussels attached themselves to boats, docks, and especially the intake pipes of power plants and water treatment facilities, clogging them and costing millions of dollars in cleanup.\n\nThe ecological effects are more complicated. Zebra mussels filter enormous amounts of water, removing the tiny plankton that young fish and native mussels depend on. As a result, the water in some lakes became noticeably clearer. At first glance, that sounds like an improvement. However, clearer water lets sunlight reach deeper, fueling the growth of weeds and algae on the lake bottom and changing the habitat for many species. The zebra mussel shows how one small newcomer can reshape an entire ecosystem.",
            questions: [
                BankQuestion(prompt: "How do scientists believe zebra mussels reached the Great Lakes?", correctAnswer: "In ballast water released from cargo ships", distractors: ["Attached to the feet of migrating birds", "Carried in buckets by fishermen as bait", "Swimming up rivers from the Atlantic"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why did zebra mussels spread so quickly?", correctAnswer: "Few predators and huge numbers of eggs", distractors: ["Warm water and plenty of sunlight", "Help from fish that carried them", "Clear water and large weed beds"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why does the writer say the ecological effects are \"more complicated\"?", correctAnswer: "A seemingly good change also caused harm", distractors: ["Scientists are not allowed to study lakes", "The cleanup cost millions of dollars", "No one knows what the mussels eat"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "Which statement best expresses the central idea of the zebra mussel passage?", correctAnswer: "One small invader can reshape an ecosystem", distractors: ["Clearer water is always better for lakes", "Cargo ships should stop crossing oceans", "Zebra mussels are harmless to native life"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en_8_last_game", tier: .hard, grades: 8...8,
            text: "Riverside Field was being torn down in the spring to make room for apartments, so the October game against Eastwood would be the last one ever played there. Noah had played on that field since he was six, back when the grass seemed as wide as an ocean and his cleats were two sizes too big.\n\nNow he was fourteen, and the field looked smaller. The bleachers sagged, and the scoreboard had a burned-out bulb that no one had fixed in years. Still, the stands were packed with former players, some of them gray-haired, pointing out spots where they had once made great plays.\n\nWith a minute left and the score tied, the ball found Noah's feet. He could see the goal, and he could see his teammate Ruben, wide open and closer. For a heartbeat, Noah pictured his own name in the stories people would tell about the last game at Riverside. Then he passed. Ruben scored.\n\nLater, as the crowd drifted toward the parking lot, an old man in a faded Riverside jersey stopped beside Noah. \"Best play of the night,\" he said, \"was the one right before the goal.\"",
            questions: [
                BankQuestion(prompt: "Why was the October game against Eastwood special?", correctAnswer: "It was the last game ever at Riverside Field", distractors: ["It was the league championship game", "It was Noah's very first soccer game", "It was the first game played at night"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "What does \"as wide as an ocean\" show about Noah as a young child?", correctAnswer: "The field seemed enormous to him", distractors: ["He wanted to become a swimmer", "The field was often flooded", "He was afraid of the field"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What choice does Noah make in the final minute?", correctAnswer: "He passes to an open teammate", distractors: ["He shoots and scores the winner", "He kicks the ball out of bounds", "He holds the ball until time ends"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What does the old man mean by his comment to Noah?", correctAnswer: "Noah's unselfish pass was the real highlight", distractors: ["Ruben should not have taken the shot", "Noah should have shot the ball himself", "The goal was only a lucky accident"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en_8_later_school_start", tier: .medium, grades: 8...8,
            text: "Most middle and high schools in our district begin at 7:25 a.m. That start time is working against students, and the school board should move it to 8:30 a.m. or later.\n\nThe science behind this is clear. During puberty, the body's internal clock shifts, so teenagers naturally tend to fall asleep later at night. This isn't laziness; it is biology. Sleep experts recommend that teens get 8 to 10 hours of sleep each night, yet a student who can't fall asleep until 11 p.m. and must wake at 6 a.m. gets only seven hours at best. The American Academy of Pediatrics has recommended that middle and high schools start no earlier than 8:30 a.m. for exactly this reason.\n\nCritics point out that a later start could complicate bus schedules and push after-school sports and jobs later into the evening. Those challenges are real. But other school districts have adjusted bus routes and practice times successfully. Tired students struggle to focus, and a schedule should serve the people it was built for: the students.",
            questions: [
                BankQuestion(prompt: "What does the writer want the school board to do?", correctAnswer: "Start school at 8:30 a.m. or later", distractors: ["Start school before 7:25 a.m.", "Cancel all after-school sports", "Shorten the school day by an hour"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why does the writer say \"This isn't laziness; it is biology\"?", correctAnswer: "To show late sleep has a physical cause", distractors: ["To blame teens for staying up late", "To argue that biology class matters", "To prove teens need less sleep"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Which evidence in the school start passage comes from an outside authority?", correctAnswer: "The pediatricians' recommendation", distractors: ["The district's 7:25 start time", "The student who wakes at 6 a.m.", "The idea that tired kids struggle"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "How does the writer respond to concerns about buses and sports?", correctAnswer: "Other districts have solved these problems", distractors: ["Sports matter less than classes do", "Buses should be removed entirely", "The concerns are not real at all"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en_8_design_a_survey", tier: .easy, grades: 8...8,
            text: "A survey can reveal what a group of people thinks, but only if it is designed carefully. Follow these steps to create a survey you can trust.\n\n1. Define your question. Decide exactly what you want to learn, such as how students at your school get to school each morning.\n2. Choose your sample. Surveying every student may be impossible, so select a sample: a smaller group that represents the whole population. A random sample, such as names picked by chance from the enrollment list, is better than asking only your friends, who may share your habits and opinions.\n3. Write neutral questions. A question like \"Don't you agree that the cafeteria food is terrible?\" pushes people toward one answer. Instead, ask, \"How would you rate the cafeteria food?\"\n4. Test the survey. Give it to a few people first to catch confusing wording.\n5. Collect and analyze the results. Organize responses in a table or graph, and be careful not to claim more than the data shows.",
            questions: [
                BankQuestion(prompt: "What is a sample, as defined in the survey passage?", correctAnswer: "A small group that represents everyone", distractors: ["The first question on a survey", "A graph of the survey results", "A list of every student's name"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why is surveying only your friends a poor way to choose a sample?", correctAnswer: "They may share your habits and opinions", distractors: ["They are usually too busy to answer", "They might not understand the questions", "There are far too many of them to ask"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why is \"Don't you agree that the cafeteria food is terrible?\" a poor survey question?", correctAnswer: "It pushes people toward one answer", distractors: ["It is too short to understand", "It asks about too many topics", "It uses words students don't know"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What is the purpose of testing a survey on a few people first?", correctAnswer: "To catch confusing wording", distractors: ["To collect the final results", "To pick a random sample", "To make a table of answers"], tier: .easy, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en_8_womens_suffrage", tier: .medium, grades: 8...8,
            text: "In July 1848, about 300 people gathered in Seneca Falls, New York, for the first women's rights convention in the United States. The organizers, including Elizabeth Cady Stanton and Lucretia Mott, presented a Declaration of Sentiments modeled on the Declaration of Independence. Its most controversial demand was that women have the right to vote. Even some supporters at the convention thought that goal was too radical.\n\nThe struggle that followed lasted more than seventy years. Suffragists gave speeches, organized parades, signed petitions, and pressed lawmakers for support. Some were arrested for picketing outside the White House. Western states and territories moved first: Wyoming Territory granted women the vote in 1869. State by state, support grew.\n\nFinally, Congress passed the 19th Amendment, and in August 1920 it was ratified, declaring that the right to vote could not be denied on account of sex. Yet the victory was incomplete. Many Black women, Native American women, and other women of color continued to face unfair laws and intimidation that kept them from voting for decades, until later civil rights laws helped protect those rights.",
            questions: [
                BankQuestion(prompt: "What was the most controversial demand in the Declaration of Sentiments?", correctAnswer: "Women's right to vote", distractors: ["Women's right to own land", "An end to the Civil War", "A new national holiday"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "What does \"radical\" most likely mean in the first paragraph about Seneca Falls?", correctAnswer: "Too extreme for the time", distractors: ["Old-fashioned and dull", "Easy to achieve", "Carefully planned out"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "According to the passage, which place granted women the vote in 1869?", correctAnswer: "Wyoming Territory", distractors: ["New York", "Washington, D.C.", "Seneca Falls"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why does the writer call the 1920 victory \"incomplete\"?", correctAnswer: "Many women of color still faced barriers", distractors: ["Only western states ratified it", "Congress later took the amendment back", "Women could vote only for president"], tier: .hard, grades: 8...8),
            ]),
    ]
}
