import Foundation

/// 📖 Reading comprehension — English (US), second set. Original passages.
///
/// Same shape and rules as `readingPassages`: length grows with the grade,
/// every question is answerable from the passage alone (detail, inference,
/// word in context, main idea / writer's purpose). Story names and places are
/// invented; history and science passages use only well-documented facts.
extension EnglishContent {
    static let readingPassages2: [ReadingPassage] = [

        // ——— 1st grade ———

        ReadingPassage(
            id: "en2_1_kite", tier: .easy, grades: 1...1,
            text: "Owen got a new kite. It looked like a big orange fish. He took it to the park, but there was no wind. The kite would not fly. Then a strong wind came. Up, up, up went the fish kite!",
            questions: [
                BankQuestion(prompt: "What did Owen's new kite look like?", correctAnswer: "A big orange fish", distractors: ["A big green bird", "A small red dragon", "A long blue snake"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Where did Owen take his kite?", correctAnswer: "To the park", distractors: ["To the beach", "To the school", "To the farm"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Why wouldn't Owen's kite fly at first?", correctAnswer: "There was no wind", distractors: ["The string broke", "It was raining", "The kite was torn"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "What made Owen's kite go up?", correctAnswer: "A strong wind", distractors: ["A long run", "His dad's help", "A big jump"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_1_penguins", tier: .medium, grades: 1...1,
            text: "Penguins are birds, but they cannot fly. They use their wings like flippers to swim fast in the sea. Many penguins eat fish. An emperor penguin dad keeps his egg warm. He holds it on top of his feet!",
            questions: [
                BankQuestion(prompt: "What can penguins not do?", correctAnswer: "Fly", distractors: ["Swim", "Eat fish", "Keep an egg warm"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "How do penguins use their wings?", correctAnswer: "Like flippers to swim", distractors: ["Like arms to hug", "Like fans to cool off", "Like hands to hold food"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "Who keeps the emperor penguin egg warm?", correctAnswer: "The dad", distractors: ["The mom", "The sun", "A big sister"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "Where does the emperor penguin dad hold the egg?", correctAnswer: "On top of his feet", distractors: ["Under his wing", "In a nest of sticks", "Inside his beak"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_1_muffins", tier: .medium, grades: 1...1,
            text: "Lucy and her dad made blueberry muffins. Lucy put the berries in the bowl. Dad put the pan in the hot oven. They waited for 20 minutes. Soon the whole house smelled sweet. The muffins were ready!",
            questions: [
                BankQuestion(prompt: "What kind of muffins did Lucy and her dad make?", correctAnswer: "Blueberry", distractors: ["Banana", "Apple", "Corn"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Who put the muffin pan in the hot oven?", correctAnswer: "Dad", distractors: ["Lucy", "Mom", "Grandma"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "How long did Lucy and Dad wait for the muffins?", correctAnswer: "20 minutes", distractors: ["2 minutes", "10 minutes", "One hour"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "Why did Lucy's house smell sweet?", correctAnswer: "The muffins were baking", distractors: ["Dad lit a candle", "Lucy picked flowers", "Mom made pancakes"], tier: .hard, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_1_class_hamster", tier: .easy, grades: 1...1,
            text: "Our class has a hamster named Peanut. He is small and tan. Peanut sleeps most of the day. At night, he runs on his wheel. Each week, a new kid gets to feed him.",
            questions: [
                BankQuestion(prompt: "What is the name of the class hamster?", correctAnswer: "Peanut", distractors: ["Pumpkin", "Cookie", "Pepper"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What color is the class hamster?", correctAnswer: "Tan", distractors: ["White", "Black", "Gray"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "When does Peanut run on his wheel?", correctAnswer: "At night", distractors: ["In the morning", "At lunch", "After school"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "How often does a new kid get to feed Peanut?", correctAnswer: "Each week", distractors: ["Each day", "Each month", "Each year"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_1_ladybugs", tier: .medium, grades: 1...1,
            text: "A ladybug is a small bug with spots. Many ladybugs are red with black spots. Ladybugs eat tiny bugs called aphids. Aphids hurt plants. That is why people who grow gardens are glad to see ladybugs.",
            questions: [
                BankQuestion(prompt: "What color are many ladybugs?", correctAnswer: "Red with black spots", distractors: ["Green with white spots", "Blue with yellow spots", "Brown with red spots"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What do ladybugs eat?", correctAnswer: "Tiny bugs called aphids", distractors: ["Leaves and flowers", "Seeds and berries", "Drops of honey"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What do aphids do?", correctAnswer: "They hurt plants", distractors: ["They help plants grow", "They eat ladybugs", "They make honey"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "Why are people who grow gardens glad to see ladybugs?", correctAnswer: "Ladybugs eat bugs that hurt plants", distractors: ["Ladybugs make flowers bloom", "Ladybugs are fun to catch", "Ladybugs help water plants"], tier: .hard, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_1_farmers_market", tier: .easy, grades: 1...1,
            text: "On Saturday, Ivy and her mom went to the farmers market. They bought corn, peaches, and a jar of honey. A man was playing a guitar. Ivy gave him a dollar. He smiled and played a happy song for her.",
            questions: [
                BankQuestion(prompt: "Where did Ivy and her mom go on Saturday?", correctAnswer: "The farmers market", distractors: ["The grocery store", "The pet shop", "The toy store"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "Which fruit did Ivy and her mom buy?", correctAnswer: "Peaches", distractors: ["Apples", "Grapes", "Bananas"], tier: .easy, grades: 1...1),
                BankQuestion(prompt: "What was the man at the farmers market doing?", correctAnswer: "Playing a guitar", distractors: ["Playing a drum", "Selling balloons", "Painting a picture"], tier: .medium, grades: 1...1),
                BankQuestion(prompt: "What did the man do after Ivy gave him a dollar?", correctAnswer: "Smiled and played a song", distractors: ["Gave her a peach", "Packed up his guitar", "Gave the dollar back"], tier: .medium, grades: 1...1),
            ]),

        ReadingPassage(
            id: "en2_12_no_training_wheels", tier: .medium, grades: 1...2,
            text: "Andre wanted to ride his bike without training wheels. His big sister held the back of the seat. Andre pedaled, and she let go. He wobbled and fell on the grass. He was not hurt, so he got back on. On his fifth try, he rode all the way to the mailbox by himself!",
            questions: [
                BankQuestion(prompt: "What did Andre want to learn to do?", correctAnswer: "Ride without training wheels", distractors: ["Ride a skateboard", "Swim without floaties", "Tie his own shoes"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "Who held the back of Andre's bike seat?", correctAnswer: "His big sister", distractors: ["His dad", "His best friend", "His grandma"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "What did Andre do after he fell on the grass?", correctAnswer: "Got back on the bike", distractors: ["Went inside to rest", "Put the training wheels back", "Asked his sister to ride"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "What does \"wobbled\" most likely mean in the bike story?", correctAnswer: "Rocked from side to side", distractors: ["Went very fast", "Stopped all at once", "Rang the bell"], tier: .hard, grades: 1...2),
            ]),

        ReadingPassage(
            id: "en2_12_sunflowers", tier: .hard, grades: 1...2,
            text: "Sunflowers can grow taller than a grown-up. Many have big yellow petals around a brown center. The center is full of seeds. When a sunflower is young, its head turns to follow the sun across the sky. Birds and squirrels love to eat the seeds.",
            questions: [
                BankQuestion(prompt: "How tall can sunflowers grow?", correctAnswer: "Taller than a grown-up", distractors: ["Up to a grown-up's knee", "Only as tall as a cup", "As tall as a mountain"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "What is in the center of a sunflower?", correctAnswer: "Seeds", distractors: ["Honey", "Water", "Leaves"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "What does a young sunflower's head do?", correctAnswer: "Turns to follow the sun", distractors: ["Closes up at noon", "Hides from the rain", "Points down at the ground"], tier: .medium, grades: 1...2),
                BankQuestion(prompt: "Who loves to eat sunflower seeds, according to the passage?", correctAnswer: "Birds and squirrels", distractors: ["Cows and horses", "Frogs and fish", "Cats and dogs"], tier: .medium, grades: 1...2),
            ]),

        // ——— 2nd grade ———

        ReadingPassage(
            id: "en2_2_tide_pool", tier: .medium, grades: 2...2,
            text: "When the tide went out, Aisha and her dad found a tide pool on the rocky beach. A tide pool is a puddle of seawater left behind in the rocks. Inside, Aisha saw a purple sea star holding tight to a rock. Dad told her that a sea star can grow back an arm if it loses one. Aisha wanted to take it home, but Dad shook his head. \"It needs the ocean to live,\" he said. So Aisha took a picture instead.",
            questions: [
                BankQuestion(prompt: "What is a tide pool?", correctAnswer: "Seawater left behind in the rocks", distractors: ["A pool built next to the beach", "A deep hole dug in the sand", "A river that flows into the sea"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What color was the sea star Aisha found?", correctAnswer: "Purple", distractors: ["Orange", "Red", "Pink"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What can a sea star do if it loses an arm?", correctAnswer: "Grow the arm back", distractors: ["Swim much faster", "Change its color", "Find a new rock"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "Why did Aisha take a picture instead of taking the sea star home?", correctAnswer: "The sea star needs the ocean to live", distractors: ["Her camera was brand new", "The sea star was too heavy", "Her dad wanted to paint it"], tier: .hard, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_2_fishing_grandpa", tier: .easy, grades: 2...2,
            text: "Luis and his grandpa went fishing at the lake just as the sun came up. They sat on the dock and waited a long time. At last, Luis felt a tug on his line! He reeled in a small silver fish. It was too little to keep, so Grandpa helped take out the hook, and Luis gently put the fish back into the water. \"Now it can grow bigger,\" Grandpa said.",
            questions: [
                BankQuestion(prompt: "When did Luis and his grandpa go fishing?", correctAnswer: "As the sun came up", distractors: ["Right after lunch", "When the sun went down", "In the middle of the night"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "Where did Luis and Grandpa sit while they fished?", correctAnswer: "On the dock", distractors: ["In a boat", "On the sand", "On a big rock"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What does \"a tug on his line\" tell you in the fishing story?", correctAnswer: "A fish was pulling the line", distractors: ["The line was stuck on a rock", "The wind was blowing hard", "Grandpa was pulling the line"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "Why did Luis put the little fish back in the water?", correctAnswer: "It was too little to keep", distractors: ["It was not a silver fish", "Grandpa did not like fish", "It jumped out of his hands"], tier: .medium, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_2_bats", tier: .medium, grades: 2...2,
            text: "Bats are the only mammals that can truly fly. Many bats sleep upside down in caves or trees during the day. When night comes, they wake up and go hunting. Many bats eat insects, like moths and mosquitoes. To find bugs in the dark, a bat makes high sounds. The sounds bounce off the bugs and come back as echoes. The echoes tell the bat where its dinner is.",
            questions: [
                BankQuestion(prompt: "How do many bats sleep?", correctAnswer: "Upside down", distractors: ["On their backs", "Standing up", "Curled in nests"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "When do the bats in the passage go hunting?", correctAnswer: "At night", distractors: ["In the morning", "At noon", "In the afternoon"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What is an echo, based on the bat passage?", correctAnswer: "A sound that bounces back", distractors: ["A kind of flying bug", "A cave where bats sleep", "A bat's sharp tooth"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "How do bats find bugs in the dark?", correctAnswer: "By listening to echoes", distractors: ["By smelling flowers", "By seeing bright colors", "By following the moon"], tier: .hard, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_2_trail_mix", tier: .easy, grades: 2...2,
            text: "Trail mix is a snack you can take on a hike. Here is how to make it. First, wash your hands. Next, pour one cup of pretzels and one cup of cereal into a big bag. Then add half a cup of raisins and a handful of sunflower seeds. Close the bag tight and shake it up. Now your snack is ready for the trail!",
            questions: [
                BankQuestion(prompt: "What should you do first to make trail mix?", correctAnswer: "Wash your hands", distractors: ["Shake the bag", "Add the raisins", "Pour the pretzels"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "How much cereal goes into the trail mix?", correctAnswer: "One cup", distractors: ["Half a cup", "Two cups", "A handful"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What do you do right after closing the trail mix bag?", correctAnswer: "Shake it up", distractors: ["Add the raisins", "Wash your hands", "Pour in the cereal"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What is trail mix, according to the passage?", correctAnswer: "A snack to take on a hike", distractors: ["A breakfast to eat at home", "A treat to feed the birds", "A dessert for a party"], tier: .easy, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_2_tomato_plants", tier: .hard, grades: 2...2,
            text: "Mrs. Patel went to visit her sister for a week. She asked Jonah to water her tomato plants every evening. On Wednesday, Jonah was busy playing a video game and almost forgot. He looked out the window and saw the plants drooping in the heat. He grabbed the watering can and ran next door. By morning, the plants stood tall again. When Mrs. Patel came home, she gave Jonah a basket of red, ripe tomatoes.",
            questions: [
                BankQuestion(prompt: "When was Jonah supposed to water the tomato plants?", correctAnswer: "Every evening", distractors: ["Every morning", "Every other day", "Only on Wednesday"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "What does \"drooping\" mean in the tomato plant story?", correctAnswer: "Bending down low", distractors: ["Growing very tall", "Turning bright red", "Blowing in the wind"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "Why did the tomato plants stand tall again by morning?", correctAnswer: "Jonah watered them", distractors: ["It rained all night", "Mrs. Patel came home", "The sun got hotter"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What did Mrs. Patel give Jonah when she got home?", correctAnswer: "A basket of ripe tomatoes", distractors: ["A new video game", "A green watering can", "A jar of tomato sauce"], tier: .easy, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_2_camels", tier: .medium, grades: 2...2,
            text: "Camels live in dry deserts. Many people think a camel's hump is full of water, but it is not. The hump stores fat. When food is hard to find, a camel's body can use the fat for energy. Camels also have wide, flat feet that help them walk on soft sand. Their long eyelashes help keep blowing sand out of their eyes.",
            questions: [
                BankQuestion(prompt: "What is stored inside a camel's hump?", correctAnswer: "Fat", distractors: ["Water", "Sand", "Milk"], tier: .easy, grades: 2...2),
                BankQuestion(prompt: "When does a camel's body use the fat in its hump?", correctAnswer: "When food is hard to find", distractors: ["When it is time to sleep", "When the sand is hot", "When it rains in the desert"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What do a camel's long eyelashes do?", correctAnswer: "Keep blowing sand out of its eyes", distractors: ["Help it see in the dark", "Keep the hot sun off its face", "Help it find food to eat"], tier: .medium, grades: 2...2),
                BankQuestion(prompt: "What is the camel passage mostly about?", correctAnswer: "How a camel's body helps it live in the desert", distractors: ["Why camels make good pets for families", "How deserts get so hot during the day", "Where people like to go on camel rides"], tier: .hard, grades: 2...2),
            ]),

        ReadingPassage(
            id: "en2_23_recycled_bottle", tier: .medium, grades: 2...3,
            text: "What happens to a plastic bottle after you put it in the recycling bin? First, a truck takes it to a recycling center. There, machines and workers sort the bottles, cans, and paper into different piles. The plastic bottles are washed, chopped into tiny flakes, and melted. The melted plastic can be made into something new, like another bottle or even the soft fabric in a fleece jacket. That is why it helps to rinse your bottles and put them in the right bin.",
            questions: [
                BankQuestion(prompt: "Where does a truck take a recycled plastic bottle?", correctAnswer: "To a recycling center", distractors: ["To a clothing store", "To the ocean", "To a grocery store"], tier: .easy, grades: 2...3),
                BankQuestion(prompt: "What happens right after the plastic bottles are washed?", correctAnswer: "They are chopped into tiny flakes", distractors: ["They are put in the bin", "They are made into jackets", "They are sorted into piles"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "Which new thing does the passage say old bottles can become?", correctAnswer: "Fabric for a fleece jacket", distractors: ["Paper for a notebook", "Glass for a window", "Metal for a soda can"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "What is the recycling passage mostly about?", correctAnswer: "What happens to a recycled bottle", distractors: ["Why plastic is bad for fish", "How to sew a fleece jacket", "How trucks collect the trash"], tier: .hard, grades: 2...3),
            ]),

        // ——— 3rd grade ———

        ReadingPassage(
            id: "en2_3_sloths", tier: .medium, grades: 3...3,
            text: "Sloths live high in the rain forest trees of Central and South America. They are famous for moving slowly. A sloth spends most of its life hanging upside down from branches, holding on with long, curved claws. It moves so little that tiny green algae can grow in its fur. The greenish color may help the sloth stay hidden among the leaves. Sloths do come down from their trees, though. Many climb down about once a week to go to the bathroom on the ground.",
            questions: [
                BankQuestion(prompt: "Where do sloths live?", correctAnswer: "In rain forest trees", distractors: ["In desert caves", "In snowy mountains", "In ocean reefs"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What do sloths use to hold on to branches?", correctAnswer: "Long, curved claws", distractors: ["Strong, sticky tails", "Sharp front teeth", "Webbed back feet"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Why can algae grow in a sloth's fur?", correctAnswer: "The sloth moves so little", distractors: ["The sloth swims every day", "The sloth eats green leaves", "The sloth sleeps on the ground"], tier: .hard, grades: 3...3),
                BankQuestion(prompt: "About how often do many sloths climb down from their trees?", correctAnswer: "About once a week", distractors: ["About once a day", "About once a month", "About once a year"], tier: .medium, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_3_pool_mural", tier: .hard, grades: 3...3,
            text: "Ms. Delgado's third graders were chosen to paint a mural on the wall by the town pool. Everyone had a different idea. Ethan wanted a giant shark. Layla wanted a field of flowers. Soon the class was arguing so loudly that no one could hear anyone else. Then Layla had an idea. \"What if the shark is swimming past flowers growing under the water?\" she asked. Ethan grinned. The class painted an underwater garden with a friendly shark in the middle, and everyone added one fish of their own.",
            questions: [
                BankQuestion(prompt: "Where did the class paint the mural?", correctAnswer: "On the wall by the town pool", distractors: ["On the wall of the library", "Inside the school gym", "On the side of a bus"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What did Ethan want to paint on the mural?", correctAnswer: "A giant shark", distractors: ["A field of flowers", "A big whale", "A sunny beach"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What problem did Ms. Delgado's class have?", correctAnswer: "They could not agree on an idea", distractors: ["They ran out of paint", "The wall was too small", "It rained on the mural"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "How did Layla solve the mural problem?", correctAnswer: "She mixed both ideas together", distractors: ["She let Ethan choose alone", "She asked the teacher to pick", "She painted flowers by herself"], tier: .hard, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_3_hot_air_balloon", tier: .medium, grades: 3...3,
            text: "How does a hot air balloon float? The answer is warm air. Warm air is lighter than the cooler air around it, so it rises. A balloon pilot uses a burner to heat the air inside the giant balloon. When the air inside gets hot enough, the balloon lifts off the ground, carrying a basket of riders. To come down, the pilot lets the air inside cool off. The very first hot air balloon passengers flew in France in 1783. They were not people. They were a sheep, a duck, and a rooster!",
            questions: [
                BankQuestion(prompt: "Why does warm air rise?", correctAnswer: "It is lighter than cooler air", distractors: ["It is heavier than cooler air", "It is pushed by the wind", "It is pulled by the sun"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "What does the balloon pilot use to heat the air?", correctAnswer: "A burner", distractors: ["A fan", "The sun", "A campfire"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "How does the pilot make the hot air balloon come down?", correctAnswer: "Lets the air inside cool off", distractors: ["Adds more hot air inside", "Throws the basket overboard", "Waits for rain to fall"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "Who were the first hot air balloon passengers?", correctAnswer: "A sheep, a duck, and a rooster", distractors: ["A dog, a cat, and a horse", "Two pilots and a farmer", "A goat, a pig, and a hen"], tier: .easy, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_3_walk_to_school", tier: .hard, grades: 3...3,
            text: "I think more kids should walk or bike to school. First, it is great exercise. Walking for fifteen minutes wakes up your body and your brain before class. Second, fewer cars in the drop-off line means less traffic and cleaner air around our school. Third, walking is fun! You get to see your neighbors and talk with friends on the way. Some people say the weather is too cold or rainy. But a warm coat, boots, and an umbrella can fix that. Let's leave the car at home! (Written by Julian, 3rd grade)",
            questions: [
                BankQuestion(prompt: "What does Julian want more kids to do?", correctAnswer: "Walk or bike to school", distractors: ["Ride the bus to school", "Get a car ride to school", "Start school later"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Which reason does Julian give for walking to school?", correctAnswer: "It is great exercise", distractors: ["It is faster than driving", "It saves money on gas", "Teachers give prizes for it"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "What worry about walking to school does Julian answer?", correctAnswer: "The weather can be cold or rainy", distractors: ["The walk takes too long", "Backpacks are too heavy", "There are no sidewalks"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "Why did Julian write this piece about walking to school?", correctAnswer: "To convince readers to walk or bike", distractors: ["To tell a story about his friends", "To explain how bikes work", "To describe the weather in his town"], tier: .hard, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_3_family_quilt", tier: .medium, grades: 3...3,
            text: "On Grandma June's bed lies a quilt made of many colorful squares. Each square was cut from an old piece of family clothing. The blue plaid square came from Grandpa's work shirt. The yellow square with daisies came from Mom's first-day-of-school dress. One day, Grandma asked Keisha to pick a square to add. Keisha chose her old dinosaur T-shirt. It was too small to wear now, but she did not want to throw it away. Grandma showed her how to sew it on with tiny, careful stitches. \"Now you are part of the story too,\" Grandma said.",
            questions: [
                BankQuestion(prompt: "What was each square of Grandma June's quilt made from?", correctAnswer: "Old family clothing", distractors: ["New fabric from a store", "Pieces of old blankets", "Paper and ribbon"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Where did the blue plaid square come from?", correctAnswer: "Grandpa's work shirt", distractors: ["Mom's school dress", "Keisha's T-shirt", "Grandma's apron"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "What was true about Keisha's dinosaur T-shirt?", correctAnswer: "It was too small to wear", distractors: ["It was brand new", "It had a big hole", "It belonged to Mom"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "What does Grandma mean by \"Now you are part of the story too\"?", correctAnswer: "Keisha's square joins the family memories", distractors: ["Keisha will write a book someday", "Keisha must finish the quilt alone", "Keisha is in a bedtime story"], tier: .hard, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_3_ice_cream_bag", tier: .easy, grades: 3...3,
            text: "You can make ice cream in a bag! You will need milk, sugar, vanilla, ice, salt, one small zip bag, and one large zip bag. First, pour one cup of milk, one tablespoon of sugar, and a few drops of vanilla into the small bag. Seal it tightly. Next, fill the large bag halfway with ice and add a big spoonful of salt. The salt makes the ice even colder. Put the small bag inside the large bag and seal it. Then shake for about five minutes. Wear mittens, because the bag gets very cold!",
            questions: [
                BankQuestion(prompt: "In the ice cream recipe, what goes into the small bag?", correctAnswer: "Milk, sugar, and vanilla", distractors: ["Ice and salt", "Milk and ice", "Sugar and salt"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Why do you add salt to the ice?", correctAnswer: "It makes the ice even colder", distractors: ["It makes the ice cream salty", "It helps the bag seal tight", "It makes the ice melt slower"], tier: .medium, grades: 3...3),
                BankQuestion(prompt: "How long should you shake the ice cream bags?", correctAnswer: "About five minutes", distractors: ["About one minute", "About an hour", "About thirty seconds"], tier: .easy, grades: 3...3),
                BankQuestion(prompt: "Why does the writer tell you to wear mittens?", correctAnswer: "The bag gets very cold", distractors: ["The bag might leak", "Your hands will get sticky", "It is a winter treat"], tier: .medium, grades: 3...3),
            ]),

        ReadingPassage(
            id: "en2_34_jackie_robinson", tier: .hard, grades: 3...4,
            text: "For many years, Black players were kept out of Major League Baseball. They had to play on separate teams in their own leagues. That changed on April 15, 1947, when Jackie Robinson took the field for the Brooklyn Dodgers. Some fans and players treated him cruelly, but Robinson had promised to stay calm and let his playing speak for him. He was fast, smart, and fearless on the bases. At the end of that season, he was named Rookie of the Year. Today, every April 15, all major league players wear his number, 42, to honor him.",
            questions: [
                BankQuestion(prompt: "Which team did Jackie Robinson play for in 1947?", correctAnswer: "The Brooklyn Dodgers", distractors: ["The New York Yankees", "The Boston Red Sox", "The Chicago Cubs"], tier: .easy, grades: 3...4),
                BankQuestion(prompt: "What did Robinson promise to do when people treated him cruelly?", correctAnswer: "Stay calm and let his playing speak", distractors: ["Quit the team and go back home", "Argue with the fans in the stands", "Play only on a separate team"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "What does \"let his playing speak for him\" mean?", correctAnswer: "Show who he was through how he played", distractors: ["Talk to reporters after every game", "Stop playing until people were kind", "Give a speech before each game"], tier: .hard, grades: 3...4),
                BankQuestion(prompt: "How do major league players honor Robinson every April 15?", correctAnswer: "They all wear the number 42", distractors: ["They all wear Dodgers hats", "They play a game in Brooklyn", "They give out a rookie prize"], tier: .medium, grades: 3...4),
            ]),

        // ——— 4th grade ———

        ReadingPassage(
            id: "en2_4_owl_pellets", tier: .medium, grades: 4...4,
            text: "Owls are skilled hunters of the night. Special soft edges on their feathers let them fly almost silently, so mice and other small animals don't hear them coming. An owl often swallows its prey whole. Its body digests the meat, but it cannot digest the bones and fur. Instead, the owl packs these leftovers into a small, furry lump called a pellet and coughs it up.\n\nTo scientists, an owl pellet is like a clue. By carefully pulling a pellet apart, they can find tiny skulls and bones and figure out exactly what the owl has been eating. Many students get to dissect clean owl pellets in science class, too.",
            questions: [
                BankQuestion(prompt: "How are owls able to fly almost silently?", correctAnswer: "Their feathers have soft edges", distractors: ["Their wings are very small", "They fly only when it rains", "They glide high above the trees"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "Which parts of its prey can an owl not digest?", correctAnswer: "Bones and fur", distractors: ["Meat and fat", "Meat and bones", "Fur and meat"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "Why does the writer say an owl pellet is \"like a clue\"?", correctAnswer: "It shows what the owl has been eating", distractors: ["It tells where the owl will fly next", "It is hidden in a secret place", "It helps the owl find its prey"], tier: .hard, grades: 4...4),
                BankQuestion(prompt: "What does \"dissect\" most likely mean in the owl pellet passage?", correctAnswer: "Carefully take apart to study", distractors: ["Paint and decorate", "Cook and eat", "Hide and find"], tier: .medium, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_4_lighthouses", tier: .medium, grades: 4...4,
            text: "For hundreds of years, sailors depended on lighthouses to warn them of rocky coasts and guide them safely into harbors. But how could a sailor at night tell one lighthouse from another? Each lighthouse had its own pattern of light. One might flash every five seconds, while another might shine steadily or flash twice, then pause. By timing the flashes, sailors could figure out exactly where they were.\n\nIn the daytime, lighthouses were easier to recognize because many were painted with their own designs, such as black-and-white stripes or spirals. In the 1820s, a French scientist named Augustin Fresnel invented a special lens made of rings of glass prisms. It gathered the light and bent it into a powerful beam that could be seen many miles out at sea.",
            questions: [
                BankQuestion(prompt: "How could sailors at night tell one lighthouse from another?", correctAnswer: "Each had its own pattern of light", distractors: ["Each keeper shouted its name", "Each had a numbered flag", "Each sent up fireworks"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "How did painted designs help sailors?", correctAnswer: "They made lighthouses easy to recognize by day", distractors: ["They made the light brighter at night", "They protected the towers from storms", "They showed sailors which way was north"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What did Fresnel's lens do?", correctAnswer: "Bent light into a powerful beam", distractors: ["Kept the flame from blowing out", "Kept the tower glass from breaking", "Changed the color of the light"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What is the main idea of the lighthouse passage?", correctAnswer: "Lighthouses had clever ways to guide sailors", distractors: ["Sailors were afraid of the dark sea", "Lighthouse keepers had lonely jobs", "French scientists built all lighthouses"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_4_bake_sale", tier: .hard, grades: 4...4,
            text: "Mr. Lindqvist's fourth graders planned a bake sale to raise $200 for the town animal shelter. They baked cookies, brownies, and banana bread, and made a sign shaped like a paw print. But on Saturday morning, dark clouds rolled in, and rain began to pour just as they set up their table outside the grocery store.\n\nFor a moment, everyone stood frozen. Then Zara ran inside and asked the store manager if they could move their table near the front doors. The manager said yes. Shoppers had to walk right past the table, and many stopped to buy a treat. By the end of the day, the class had raised $236. Zara's quick thinking had saved the sale.",
            questions: [
                BankQuestion(prompt: "Why did Mr. Lindqvist's fourth graders hold a bake sale?", correctAnswer: "To raise money for the animal shelter", distractors: ["To buy a new class pet", "To pay for a field trip", "To help the grocery store"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "What problem did the bake sale face on Saturday morning?", correctAnswer: "Rain began to pour", distractors: ["They forgot the brownies", "The store was closed", "Nobody wanted treats"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "By how much did the class beat its bake sale goal?", correctAnswer: "$36", distractors: ["$236", "$200", "$64"], tier: .hard, grades: 4...4),
                BankQuestion(prompt: "What does \"stood frozen\" suggest about the class?", correctAnswer: "They were too surprised to move", distractors: ["They were very cold from the rain", "They were playing a game of tag", "They were waiting in a long line"], tier: .medium, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_4_simple_circuit", tier: .easy, grades: 4...4,
            text: "An electric circuit is a path that electricity can flow around. You can build a simple one to light a small bulb.\n\nYou will need a D battery, a small flashlight bulb in a holder, and two wires with bare metal ends. First, attach one end of a wire to the top of the battery, called the positive end, and tape it in place. Connect the other end of that wire to one side of the bulb holder. Next, attach the second wire to the other side of the bulb holder. Finally, touch the free end of the second wire to the bottom of the battery, the negative end. The bulb should light up!\n\nIf you lift that wire away, the light goes out. That is because electricity can only flow through a complete loop. Any gap breaks the circuit.",
            questions: [
                BankQuestion(prompt: "What is an electric circuit?", correctAnswer: "A path that electricity flows around", distractors: ["A tool that makes batteries", "A kind of flashlight bulb", "A wire with bare metal ends"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "Which end of the battery is the positive end, according to the passage?", correctAnswer: "The top", distractors: ["The bottom", "The side", "The middle"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "Why does the bulb go out when you lift the wire away?", correctAnswer: "The loop is no longer complete", distractors: ["The battery runs out of power", "The bulb gets much too hot", "The tape comes loose"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What does \"breaks the circuit\" mean in the circuit passage?", correctAnswer: "Stops electricity from flowing", distractors: ["Snaps the wire in half", "Cracks the light bulb", "Uses up the battery"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_4_uniforms", tier: .hard, grades: 4...4,
            text: "Some parents in our town want Maple Grove Elementary to require school uniforms. I think that would be a mistake.\n\nFirst, the clothes we choose are one way we show who we are. A student who loves space might wear a rocket shirt, and that shirt can start a conversation with a new friend. Second, uniforms cost money. Most families would still need to buy regular clothes for weekends, so uniforms would be an extra expense.\n\nPeople who want uniforms say they would stop kids from teasing each other about clothes. Stopping teasing is important. But kids who want to tease will find something else to pick on, like shoes or backpacks. Teaching kindness would solve the real problem. Let's keep our own clothes and work on being kind instead.\n\n(Written by Benjamin, 4th grade)",
            questions: [
                BankQuestion(prompt: "What is Benjamin's opinion about school uniforms?", correctAnswer: "Requiring them would be a mistake", distractors: ["Every school should require them", "They should be worn only on Fridays", "Only teachers should wear them"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "Why does Benjamin say uniforms would be an extra expense?", correctAnswer: "Families still need regular clothes", distractors: ["Uniforms wear out in a week", "Uniforms come only in big sizes", "Schools charge to wash them"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What reason do people who want uniforms give?", correctAnswer: "Uniforms would stop teasing about clothes", distractors: ["Uniforms would save families money", "Uniforms would help kids find friends", "Uniforms would keep kids warmer"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "How does Benjamin respond to the idea that uniforms would stop teasing?", correctAnswer: "Kids would tease about other things, like shoes", distractors: ["Teasing only happens out at recess", "Uniforms would cause even more teasing", "Teachers already stop all the teasing"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_4_garden_gnome", tier: .medium, grades: 4...4,
            text: "Mateo's baseball sailed over the fence and landed in Mr. Greenberg's yard with a loud crack. When Mateo peeked over, he saw what had happened. The ball had knocked over Mr. Greenberg's garden gnome, and its little red hat had broken off.\n\nNo one else had seen it. Mateo could have grabbed his ball and gone inside. Instead, his stomach twisted, and he walked next door and knocked. \"I'm really sorry,\" he said, holding up the broken hat. \"I can pay for it with my allowance.\"\n\nMr. Greenberg studied the hat, then smiled. \"This old fellow has been through worse,\" he said. \"How about you help me glue it back on, and we'll call it even?\" That afternoon, the two of them fixed the gnome together.",
            questions: [
                BankQuestion(prompt: "What did Mateo's baseball break?", correctAnswer: "A garden gnome's hat", distractors: ["Mr. Greenberg's window", "A clay flower pot", "The wooden fence"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "What does \"his stomach twisted\" show about Mateo?", correctAnswer: "He felt guilty and nervous", distractors: ["He was hungry for lunch", "He had hurt himself", "He was excited to play"], tier: .medium, grades: 4...4),
                BankQuestion(prompt: "What did Mateo offer to do about the broken gnome?", correctAnswer: "Pay with his allowance", distractors: ["Buy a new baseball", "Mow Mr. Greenberg's lawn", "Paint the fence"], tier: .easy, grades: 4...4),
                BankQuestion(prompt: "What lesson does the story about Mateo and the gnome teach?", correctAnswer: "Telling the truth can make things better", distractors: ["Baseball should never be played outside", "Neighbors are usually grumpy people", "Broken things can never be fixed"], tier: .hard, grades: 4...4),
            ]),

        ReadingPassage(
            id: "en2_45_chicago_fire", tier: .hard, grades: 4...5,
            text: "On the night of October 8, 1871, a fire started in a barn southwest of downtown Chicago. The summer and fall had been very dry, and most of the city's buildings, sidewalks, and even some streets were made of wood. Strong winds from the southwest pushed the flames toward the heart of the city. The fire burned for more than a day before rain finally helped put it out.\n\nBy then, a huge part of Chicago lay in ashes, and about 100,000 people had lost their homes. For years, people blamed a cow belonging to Catherine O'Leary for kicking over a lantern, but that story was never proven. Chicago rebuilt quickly. New rules required many buildings downtown to be made of brick, stone, or other materials that do not burn easily. One of the few buildings in the fire's path to survive, the stone Chicago Water Tower, still stands today.",
            questions: [
                BankQuestion(prompt: "Which conditions helped the Chicago fire spread?", correctAnswer: "Dry weather and wooden buildings", distractors: ["Heavy rain and brick buildings", "Cold weather and stone streets", "Calm air and tall buildings"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "What finally helped put out the Chicago fire?", correctAnswer: "Rain", distractors: ["Snow", "The lake", "The wind"], tier: .easy, grades: 4...5),
                BankQuestion(prompt: "What does the passage say about the story of Mrs. O'Leary's cow?", correctAnswer: "It was never proven", distractors: ["It was proven true in court", "It was made up by a reporter", "It happened in another city"], tier: .medium, grades: 4...5),
                BankQuestion(prompt: "Why did Chicago's new rules require brick or stone buildings downtown?", correctAnswer: "Those materials do not burn easily", distractors: ["Those materials were cheaper than wood", "Those materials looked more modern", "Those materials were easier to find"], tier: .hard, grades: 4...5),
            ]),

        // ——— 5th grade ———

        ReadingPassage(
            id: "en2_5_hawaii_hot_spot", tier: .hard, grades: 5...5,
            text: "The Hawaiian Islands were built by volcanoes, one after another, in the middle of the Pacific Ocean. Deep beneath the southeastern end of the island chain is a hot spot, a place where melted rock rises from far inside the Earth. The hot spot stays in about the same place, but the Pacific Plate, the huge slab of Earth's crust on top of it, slowly moves northwest, a few inches each year.\n\nAs the plate moves, each volcano is carried away from the hot spot, and a new one begins to form. That is why the islands form a chain. The islands in the northwest, such as Kauai, are the oldest. Their volcanoes stopped erupting long ago, and wind and rain have worn them into steep cliffs and valleys. The Big Island of Hawaii, in the southeast, is the youngest, and it still has active volcanoes. Southeast of it, a new volcano is growing on the ocean floor. It may rise above the waves someday, but not for many thousands of years.",
            questions: [
                BankQuestion(prompt: "What is a hot spot, according to the Hawaii passage?", correctAnswer: "A place where melted rock rises", distractors: ["A beach with very warm sand", "The top of an active volcano", "A slab of Earth's crust"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why do the Hawaiian Islands form a chain?", correctAnswer: "The plate carries volcanoes away from the hot spot", distractors: ["The hot spot moves quickly around the ocean", "Earthquakes pushed the islands into a line", "Ocean waves dragged the islands far apart"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Why does Kauai have steep cliffs and valleys?", correctAnswer: "It is old and worn by wind and rain", distractors: ["Its volcano is still erupting today", "It sits right above the hot spot", "It was built by the newest volcano"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Based on the passage, where would you find the youngest land in Hawaii?", correctAnswer: "In the southeast", distractors: ["In the northwest", "In the center", "In the northeast"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_5_franklin_inventions", tier: .medium, grades: 5...5,
            text: "Benjamin Franklin is famous as one of the Founding Fathers of the United States, but he was also a curious inventor who liked solving everyday problems.\n\nIn the 1740s, many homes were heated by open fireplaces that sent much of their heat up the chimney and filled rooms with smoke. Franklin designed an iron stove that stood out from the wall and was meant to warm a room better while using less wood. After his experiments with electricity, he invented the lightning rod, a metal pole attached to the top of a building and connected to the ground by a wire. It gave lightning a safe path to follow, protecting buildings from fires. Later in life, Franklin grew tired of switching between two pairs of glasses, and he is credited with creating bifocals, lenses split into two parts for seeing near and far.\n\nFranklin never patented these inventions, which means he did not claim the right to control who could make them. He believed that people should share inventions freely to help others.",
            questions: [
                BankQuestion(prompt: "What problem was Franklin's stove meant to solve?", correctAnswer: "Fireplaces wasted heat and made smoke", distractors: ["Houses had no way to cook food", "Chimneys often attracted lightning", "Iron was too costly for families"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "How does a lightning rod protect a building?", correctAnswer: "It gives lightning a safe path to the ground", distractors: ["It stops storms from forming nearby", "It makes lightning strike somewhere else", "It keeps rain from reaching the roof"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What does \"patented\" mean, based on the Franklin passage?", correctAnswer: "Claimed the right to control who makes it", distractors: ["Tested it carefully many different times", "Sold it for a very high price to others", "Painted it with his initials and the date"], tier: .hard, grades: 5...5),
                BankQuestion(prompt: "What is the main idea of the Franklin passage?", correctAnswer: "Franklin invented things to solve everyday problems", distractors: ["Franklin cared more about science than politics", "Franklin wanted to become very rich from inventing", "Franklin was afraid of lightning storms at night"], tier: .medium, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_5_robot_competition", tier: .medium, grades: 5...5,
            text: "The Gearheads had spent eight weeks building their robot for the regional competition. It was supposed to drive across a table, pick up three foam blocks, and drop them into a bin. In practice, it worked almost every time.\n\nBut in the first round, the robot rolled forward, twitched, and stopped. The team's score was zero. Leah felt her face get hot. She had been in charge of wiring, and she was sure it was her fault. Instead of blaming her, Hugo handed her a flashlight. \"Let's find it together,\" he said. Crouched under the table, they discovered a wire that had wiggled loose when the robot was carried in from the car. Leah fixed it with ten minutes to spare. In the second round, the robot dropped all three blocks into the bin, and the team cheered louder than anyone in the gym.",
            questions: [
                BankQuestion(prompt: "What was the Gearheads' robot supposed to do?", correctAnswer: "Move foam blocks into a bin", distractors: ["Race other robots across the gym", "Build a tower out of foam blocks", "Draw a picture on the table"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why did Leah's face get hot during the first round?", correctAnswer: "She thought the problem was her fault", distractors: ["The gym was very warm that day", "She had run in from the parking lot", "The flashlight was shining on her"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What caused the robot to stop in the first round?", correctAnswer: "A wire had wiggled loose", distractors: ["The battery had run out", "A block got stuck in a wheel", "Hugo pressed the wrong button"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "What does Hugo's response to the problem show about him?", correctAnswer: "He is a supportive teammate", distractors: ["He wants to be the team leader", "He does not care about winning", "He thinks Leah should quit"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_5_helmet_fit", tier: .easy, grades: 5...5,
            text: "A bike helmet can only protect your head if it fits correctly. Before you ride, check your helmet with these steps.\n\n1. Size: The helmet should feel snug but comfortable. It should not rock back and forth when you move your head.\n2. Position: The helmet should sit level on your head, low on your forehead, about two finger-widths above your eyebrows.\n3. Side straps: Adjust the sliders so the straps form a V shape just below each ear.\n4. Chin strap: Buckle it, then tighten it until no more than one finger fits between the strap and your chin.\n5. Final check: Open your mouth wide as if yawning. The helmet should pull down on your head. If it doesn't, tighten the chin strap.\n\nA helmet that has been in a crash should be replaced, even if it looks fine, because the foam inside may be crushed.",
            questions: [
                BankQuestion(prompt: "How far above your eyebrows should a bike helmet sit?", correctAnswer: "About two finger-widths", distractors: ["About one hand-width", "About four finger-widths", "Right on the eyebrows"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "What shape should the side straps of a bike helmet make?", correctAnswer: "A V below each ear", distractors: ["An X behind each ear", "A circle around each ear", "A line over each ear"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "What is the purpose of the yawning test in the helmet steps?", correctAnswer: "To check that the chin strap is tight enough", distractors: ["To check that the helmet is the right color", "To stretch your face before riding a bike", "To loosen the side straps before a ride"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Why should a helmet be replaced after a crash even if it looks fine?", correctAnswer: "It may be damaged in ways you can't see", distractors: ["It will always be too small afterward", "Its straps will stop buckling at all", "Newer helmets come in more colors"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_5_allowance", tier: .hard, grades: 5...5,
            text: "Should kids get a weekly allowance? I believe parents should give their children a small allowance, even just a few dollars a week.\n\nThe main reason is that managing money takes practice. A kid with an allowance has to make real choices. If Ruby spends all five dollars on candy on Monday, she will have nothing left for the comic book she wants on Friday. Learning that lesson with five dollars at age ten is much better than learning it with a paycheck at age twenty-five. An allowance also teaches saving. A kid who puts aside two dollars a week will have more than one hundred dollars after a year.\n\nSome parents argue that kids should earn money only by doing chores. But everyone in a family should help at home simply because they live there. Chores and allowance teach different lessons, and kids need both.",
            questions: [
                BankQuestion(prompt: "What is the writer's main claim about allowance?", correctAnswer: "Parents should give kids a small allowance", distractors: ["Kids should earn money only through chores", "Kids should not handle money until they're older", "Allowances should be at least twenty dollars"], tier: .easy, grades: 5...5),
                BankQuestion(prompt: "Why does the writer include the example about Ruby?", correctAnswer: "To show how an allowance teaches choices", distractors: ["To show that candy is unhealthy", "To show that comic books cost too much", "To show that Ruby is a careless kid"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "According to the allowance passage, how much would a kid have after saving two dollars a week for a year?", correctAnswer: "More than one hundred dollars", distractors: ["About fifty dollars", "Exactly twenty-four dollars", "About two hundred dollars"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "How does the writer respond to parents who say kids should earn money only by doing chores?", correctAnswer: "Chores and allowance teach different lessons", distractors: ["Chores are not important for kids to do", "Kids should be paid for every single chore", "Parents should do all the chores at home"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_5_tucson_to_duluth", tier: .medium, grades: 5...5,
            text: "Kiara had lived in Tucson, Arizona, her whole life, where winter meant wearing a light jacket. So when her family moved to Duluth, Minnesota, in January, she felt as if she had landed on another planet. The air stung her cheeks, and parts of the huge lake beside the city were frozen solid.\n\nFor the first week, Kiara missed everything: the tall saguaro cactus in her old yard, the orange sunsets over the mountains, and especially her best friend, Brianna. At her new school, she ate lunch quietly and counted the days until spring.\n\nThen, one snowy Saturday, a girl from her class named Hailey knocked on the door holding two sleds. \"Have you ever been sledding?\" she asked. Kiara shook her head. An hour later, with snow down the back of her coat, Kiara was laughing so hard she could barely breathe. Walking home, she realized that this strange, frozen place might have a few surprises worth staying for.",
            questions: [
                BankQuestion(prompt: "Why did Kiara feel as if she had landed on another planet?", correctAnswer: "Duluth was so different from Tucson", distractors: ["She had flown on a very long trip", "Her new house looked very strange", "She had never seen a lake before"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "Which detail shows that Kiara missed her old home?", correctAnswer: "She missed the saguaro cactus in her yard", distractors: ["The air stung her cheeks in January", "Hailey came to the door with two sleds", "Parts of the lake were frozen solid"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "What does \"counted the days until spring\" suggest about Kiara?", correctAnswer: "She was unhappy and wanted winter to end", distractors: ["She was practicing her math skills", "She was excited for a spring party", "She was in charge of the class calendar"], tier: .medium, grades: 5...5),
                BankQuestion(prompt: "How do Kiara's feelings change by the end of the story?", correctAnswer: "She starts to feel hopeful about her new home", distractors: ["She decides to move back to Tucson", "She becomes angry with Hailey", "She wishes even harder for spring"], tier: .hard, grades: 5...5),
            ]),

        ReadingPassage(
            id: "en2_56_erie_canal", tier: .hard, grades: 5...6,
            text: "In the early 1800s, moving goods across New York State was slow and expensive. Farmers in western New York and beyond had to haul crops over rough roads by wagon. New York's governor, DeWitt Clinton, supported a bold plan: dig a canal about 363 miles long, connecting Lake Erie at Buffalo to the Hudson River at Albany, which flows south to New York City. Many people thought the idea was foolish and nicknamed it \"Clinton's Ditch.\"\n\nWork began in 1817. Crews dug mostly by hand, with shovels, horses, and simple machines for pulling up tree stumps. Because the land rises between the Hudson and Lake Erie, builders constructed locks, water-filled chambers that raise or lower boats from one level to the next. Mules and horses walking along a path beside the canal, called a towpath, pulled the boats with ropes.\n\nThe canal opened in 1825, and it was a huge success. The cost of shipping goods between Buffalo and New York City dropped dramatically, and the trip became much faster. New York City grew into the busiest port in the country, and towns along the canal, such as Syracuse and Rochester, boomed.",
            questions: [
                BankQuestion(prompt: "Why did people nickname the canal \"Clinton's Ditch\"?", correctAnswer: "They thought the plan was foolish", distractors: ["Clinton dug the first section himself", "The canal was built on Clinton's farm", "The ditch ran past Clinton's home"], tier: .medium, grades: 5...6),
                BankQuestion(prompt: "What is the purpose of a lock on a canal?", correctAnswer: "To raise or lower boats between levels", distractors: ["To keep boats from being stolen", "To stop the water from freezing", "To mark the end of the canal"], tier: .easy, grades: 5...6),
                BankQuestion(prompt: "What does \"boomed\" mean in the Erie Canal passage?", correctAnswer: "Grew quickly and did well", distractors: ["Made very loud noises", "Were badly flooded", "Lost many of their people"], tier: .medium, grades: 5...6),
                BankQuestion(prompt: "Which effect of the Erie Canal is described in the passage?", correctAnswer: "Shipping goods became cheaper and faster", distractors: ["Farmers stopped growing crops to sell", "Roads across the state were paved", "Albany became the busiest port"], tier: .hard, grades: 5...6),
            ]),

        // ——— 6th grade ———

        ReadingPassage(
            id: "en2_6_red_planet", tier: .medium, grades: 6...6,
            text: "Mars is often called the Red Planet, and for good reason. Its surface is covered in dust and rocks rich in iron oxide, the same compound that forms rust on an old bicycle. Wind spreads this rusty dust across the planet, and some of it drifts into the thin atmosphere, giving the Martian sky a pinkish, butterscotch color during the day.\n\nMars is a place of extremes. It is home to Olympus Mons, a volcano about two and a half times as tall as Mount Everest and one of the largest known volcanoes in the solar system. Temperatures can plunge far below zero, because the thin atmosphere cannot hold in much heat. Gravity on Mars is only a little more than one-third as strong as on Earth, so a person who weighs 90 pounds on Earth would weigh about 34 pounds there.\n\nSome things about Mars are surprisingly familiar, though. A day on Mars lasts just a little longer than a day on Earth, about 24 hours and 40 minutes. Mars also has seasons, because, like Earth, it is tilted on its axis.",
            questions: [
                BankQuestion(prompt: "Why is Mars called the Red Planet?", correctAnswer: "Its surface has lots of rusty iron oxide dust", distractors: ["Its volcanoes are always erupting lava", "Its sunlight makes the whole sky look red", "Its oceans are full of red algae"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "Why can temperatures on Mars drop so low?", correctAnswer: "The thin atmosphere holds in little heat", distractors: ["Mars is covered in thick ice sheets", "Mars gets no sunlight at all", "Mars spins much faster than Earth"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "According to the passage, about how much would a 90-pound person weigh on Mars?", correctAnswer: "About 34 pounds", distractors: ["About 45 pounds", "About 90 pounds", "About 12 pounds"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "How is the third paragraph of the Mars passage different from the second?", correctAnswer: "It shows ways Mars is like Earth", distractors: ["It lists more extremes on Mars", "It explains why Mars looks red", "It argues people should live on Mars"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_6_papyrus", tier: .easy, grades: 6...6,
            text: "Long before paper as we know it existed, the ancient Egyptians wrote on a material made from a plant. Papyrus is a tall reed that grew thickly along the banks of the Nile River.\n\nTo make a writing sheet, workers peeled away the plant's tough outer layer and cut the soft inner stalk into long, thin strips. They laid the strips side by side, then placed a second layer on top, crossing the first at a right angle. Next, they pressed or pounded the layers together. The plant's own sap helped bind the strips as they dried in the sun. Finally, the dried sheet was polished smooth with a stone. Sheets could be glued end to end to form long scrolls.\n\nPapyrus was so important that the Egyptians traded it throughout the Mediterranean world. Even our English word \"paper\" comes from the word papyrus.",
            questions: [
                BankQuestion(prompt: "Where did the papyrus plant grow?", correctAnswer: "Along the banks of the Nile River", distractors: ["In the sand of the open desert", "Along the shores of the Red Sea", "High in rocky mountains"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "How were the two layers of papyrus strips arranged?", correctAnswer: "The second layer crossed the first", distractors: ["The layers were rolled into a tube", "The strips were tied together in knots", "The layers were placed end to end"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What held the papyrus strips together as they dried?", correctAnswer: "The plant's own sap", distractors: ["Glue made from flour", "Tiny wooden pegs", "Thread sewn by hand"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "Why does the writer mention that the word \"paper\" comes from papyrus?", correctAnswer: "To show papyrus's lasting importance", distractors: ["To explain how to spell the word paper", "To show that Egyptians spoke English", "To prove that paper is made of reeds"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_6_trail_shortcut", tier: .hard, grades: 6...6,
            text: "Ezra was sure he knew a shortcut. \"The trail loops way around the ridge,\" he told his cousin Talia, pointing at the trees. \"If we cut straight through, we'll beat everyone to the lake.\" Talia glanced back at the painted blue rectangles on the tree trunks that marked the trail, then followed him.\n\nTwenty minutes later, every tree looked the same. The lake was nowhere in sight, and Ezra had gone quiet. Talia remembered what the ranger had said that morning: if you lose the trail, stop, stay calm, and think before you walk another step. She took a deep breath and listened. Somewhere to their left, she could hear the faint voices of other hikers.\n\nThey walked slowly toward the sound until Talia spotted a flash of blue paint on a tree. They were back on the trail. They reached the lake last, not first. As they sat on a log by the water catching their breath, Ezra finally said, \"Next time, let's trust the blue rectangles.\"",
            questions: [
                BankQuestion(prompt: "Why did Ezra want to leave the trail?", correctAnswer: "He thought a shortcut would be faster", distractors: ["He wanted to see a waterfall", "He heard hikers in the woods", "He wanted to find the ranger"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "What were the painted blue rectangles on the trees for?", correctAnswer: "They marked the trail", distractors: ["They warned hikers about bears", "They marked trees to be cut down", "They showed where to find water"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "What does the detail that \"Ezra had gone quiet\" suggest?", correctAnswer: "He was starting to worry", distractors: ["He was tired of talking", "He was listening for birds", "He was angry at Talia"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "What does Ezra's final comment about the blue rectangles show?", correctAnswer: "He learned from his mistake", distractors: ["He blames Talia for getting lost", "He wants to try a new shortcut", "He did not enjoy the hike"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_6_shelter_adoption", tier: .medium, grades: 6...6,
            text: "When a family decides to get a dog or cat, the first stop should be an animal shelter, not a pet store.\n\nThe strongest reason is simple: shelters are full of animals who need homes. Every pet adopted from a shelter frees up space and care for another animal in need. Adopting is also often less expensive. Many shelters include vaccinations and a checkup in the adoption fee, which can save a family a lot of money in the first year.\n\nShelter staff can also help families find a good match. Because workers spend time with the animals every day, they can tell you whether a dog is calm enough for a small apartment or whether a cat gets along with young children.\n\nSome people say they want a specific breed and can't find one at a shelter. It is true that the right pet may take patience to find. However, shelters and rescue groups often do care for purebred animals, and many will contact families when a certain type of pet arrives. A little patience is worth it when it gives an animal a second chance.",
            questions: [
                BankQuestion(prompt: "What is the writer's claim in the pet adoption passage?", correctAnswer: "Families should adopt from animal shelters", distractors: ["Families should buy pets from pet stores", "Families should not get pets at all", "Shelters should charge higher fees"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "According to the writer, how can adopting from a shelter save a family money?", correctAnswer: "Fees often include vaccinations and a checkup", distractors: ["Shelter pets never need to see a vet", "Shelters give families free food for life", "Pet stores charge a fee for every visit"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "Why can shelter staff help families find a good match?", correctAnswer: "They spend time with the animals every day", distractors: ["They were trained at pet stores", "They choose a pet for every family", "They care only for calm animals"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "How does the writer respond to people who want a specific breed?", correctAnswer: "Shelters and rescues often have purebreds", distractors: ["A pet's breed does not matter at all", "Those people should get a cat instead", "Pet stores have healthier breeds"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_6_monthly_budget", tier: .easy, grades: 6...6,
            text: "A budget is a plan for how you will use your money. Making one helps you reach your goals instead of wondering where your money went. Here's how to create a simple monthly budget.\n\nStep 1: Add up your income. Income is all the money you expect to receive. For example, Nadia earns $30 a month walking a neighbor's dog and gets $10 a month in allowance, for a total of $40.\n\nStep 2: Pay yourself first. Decide how much to save before you spend anything. Nadia is saving for a $60 pair of headphones, so she puts $15 into savings each month.\n\nStep 3: Separate needs from wants. A need is something you must pay for, like a bus pass. A want is something nice to have, like a movie ticket. Plan for needs before wants.\n\nStep 4: Track your spending. Write down every purchase. At the end of the month, compare what you planned with what you actually spent, and adjust next month's plan if needed.",
            questions: [
                BankQuestion(prompt: "What is Nadia's total monthly income?", correctAnswer: "$40", distractors: ["$30", "$10", "$15"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "What does \"pay yourself first\" mean in the budget passage?", correctAnswer: "Set aside savings before spending", distractors: ["Buy something fun for yourself first", "Pay back money you borrowed", "Spend on needs before saving"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "How many months will it take Nadia to save for the headphones?", correctAnswer: "Four", distractors: ["Three", "Six", "Two"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "Which of these is a need, as the budget passage explains it?", correctAnswer: "A bus pass", distractors: ["A movie ticket", "A pair of headphones", "A new video game"], tier: .medium, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_6_bristlecone_pines", tier: .medium, grades: 6...6,
            text: "High in the mountains of the western United States grow some of the oldest living things on Earth: Great Basin bristlecone pines. Some of these gnarled, twisted trees are more than 4,000 years old, which means they sprouted long before the Roman Empire existed.\n\nOddly, the bristlecones' harsh home may be one secret to their long lives. Many grow near 10,000 feet above sea level, where the soil is rocky, the winds are fierce, and the growing season is short. In these conditions, the trees grow very slowly, producing wood so dense that insects, fungi, and rot have trouble breaking it down. Few other plants can survive there, so wildfires have little fuel to spread.\n\nBristlecones have one more survival trick. When drought or damage strikes, parts of a tree may die back while a narrow strip of living bark keeps the rest of the tree alive. A tree that looks mostly dead may still be growing.",
            questions: [
                BankQuestion(prompt: "About how old are some Great Basin bristlecone pines?", correctAnswer: "More than 4,000 years old", distractors: ["About 400 years old", "About 1,000 years old", "More than 40,000 years old"], tier: .easy, grades: 6...6),
                BankQuestion(prompt: "What does the writer mean by the bristlecones' \"harsh home\"?", correctAnswer: "A place with tough living conditions", distractors: ["A place with many hungry animals", "A crowded forest full of trees", "A warm valley with rich soil"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "How does slow growth help bristlecones live so long?", correctAnswer: "It makes dense wood that resists rot", distractors: ["It keeps the trees short in the wind", "It lets them drink more water", "It helps them spread seeds farther"], tier: .medium, grades: 6...6),
                BankQuestion(prompt: "Why does the writer say a bristlecone that looks mostly dead may still be growing?", correctAnswer: "A strip of living bark can keep it alive", distractors: ["Its roots can grow new trees nearby", "Its needles turn green again each spring", "Its dead wood slowly comes back to life"], tier: .hard, grades: 6...6),
            ]),

        ReadingPassage(
            id: "en2_67_apollo_13", tier: .medium, grades: 6...7,
            text: "In April 1970, three NASA astronauts blasted off aboard Apollo 13, planning to become the third crew to land on the moon. Nearly 56 hours into the flight, an oxygen tank in the service module exploded. The spacecraft began losing oxygen and electrical power. The moon landing was off. Now the only goal was getting the crew home safely.\n\nThe astronauts moved into the lunar module, the small craft designed to land two people on the moon for a short stay. It became a lifeboat. But it was not built to support three people for about four days, and a new danger soon appeared: carbon dioxide from the astronauts' breath was building up. The lunar module did not have enough air filters of its own, and the spare filters from the command module were square, while the lunar module's filter openings were round.\n\nOn the ground, engineers raced to solve the puzzle using only materials the crew had on board, including plastic bags, cardboard, and tape. They talked the astronauts through building an adapter step by step. It worked. On April 17, 1970, the crew splashed down safely in the Pacific Ocean. Apollo 13 became known as a \"successful failure,\" because although it never reached its goal, the team solved problems no one had planned for and brought the crew home.",
            questions: [
                BankQuestion(prompt: "What caused the Apollo 13 crew to give up the moon landing?", correctAnswer: "An oxygen tank exploded", distractors: ["The lunar module was lost", "A storm hit the launch site", "The crew became very sick"], tier: .easy, grades: 6...7),
                BankQuestion(prompt: "Why does the writer say the lunar module \"became a lifeboat\"?", correctAnswer: "The crew used it to survive the trip home", distractors: ["It was used to land in the ocean", "It floated on the water like a boat", "It carried extra rescue supplies"], tier: .medium, grades: 6...7),
                BankQuestion(prompt: "What problem did the square and round filters create?", correctAnswer: "The spare filters did not fit the openings", distractors: ["The filters let in too much oxygen", "The filters made the air too cold", "The filters were too heavy to lift"], tier: .medium, grades: 6...7),
                BankQuestion(prompt: "Why was Apollo 13 called a \"successful failure\"?", correctAnswer: "It missed its goal but got the crew home safely", distractors: ["It landed on the moon but then broke down", "It launched late but set new speed records", "It reached the moon faster than planned"], tier: .hard, grades: 6...7),
            ]),

        // ——— 7th grade ———

        ReadingPassage(
            id: "en2_7_heat_islands", tier: .medium, grades: 7...7,
            text: "On a hot summer afternoon, a downtown city street can be several degrees warmer than a leafy park just a few miles away. Scientists call this effect an urban heat island.\n\nThe main cause is the materials cities are built with. Dark asphalt roads and roofs absorb a great deal of sunlight during the day and release that stored heat slowly, even after sunset. Tall buildings can block breezes and trap warm air between them. Cities also tend to have fewer trees and plants. That matters because plants cool the air in two ways: they provide shade, and they release water vapor from their leaves, which cools the air around them, much as sweat cools your skin.\n\nHeat islands are more than uncomfortable. They increase the demand for air conditioning, which raises energy use, and extreme heat can be dangerous to people's health. Fortunately, cities can fight back. Some are painting roofs white or light colors to reflect sunlight, planting street trees, and building \"green roofs\" covered with plants.",
            questions: [
                BankQuestion(prompt: "What is an urban heat island?", correctAnswer: "A city area warmer than places around it", distractors: ["A park that stays cool in the summer", "An island with a very hot climate", "A roof covered with growing plants"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "Why do dark roads and roofs make cities hotter?", correctAnswer: "They absorb sunlight and release heat slowly", distractors: ["They block breezes between tall buildings", "They reflect sunlight back into the sky", "They release water vapor into the air"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "Why does the writer compare plants to sweat?", correctAnswer: "Both cool things by releasing water", distractors: ["Both are signs of very hot weather", "Both make the air smell fresher", "Both help block harmful sunlight"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "What is the purpose of the last paragraph of the heat island passage?", correctAnswer: "To explain the harm and some solutions", distractors: ["To describe what causes heat islands", "To compare city parks to city streets", "To define the term urban heat island"], tier: .medium, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_7_group_project", tier: .hard, grades: 7...7,
            text: "By Thursday night, Ximena had finished the slides, written the script, and found every photo for the group's presentation on volcanoes. Theo, her partner, had done nothing but reply \"sounds good\" to her messages. She typed a long, angry text, then deleted it and typed an even longer one.\n\nBefore she could hit send, her mom asked her to carry a casserole down the hall to the Pham family, who had a new baby. Theo's family. Ximena had forgotten they lived in the same building. When the door opened, Theo stood there holding a crying infant on one hip while a toddler tugged at his sleeve. Behind him, the kitchen counter was covered in bottles. \"My mom's back at work and my dad's on the night shift,\" he said, looking embarrassed. \"I'm sorry about the project. I've been trying.\"\n\nXimena handed him the casserole. Back in her room, she deleted the long text. Instead she wrote, \"Can you practice the last three slides with me at lunch tomorrow?\" His reply came almost instantly: \"Yes. Thank you.\"",
            questions: [
                BankQuestion(prompt: "Why was Ximena angry at Theo at the beginning of the story?", correctAnswer: "She had done all the project work herself", distractors: ["He had copied her slides for himself", "He had lost all the photos she found", "He had picked a topic she disliked"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "What does Ximena discover when she brings the casserole?", correctAnswer: "Theo is helping care for his young siblings", distractors: ["Theo has been finishing the project alone", "Theo's family is moving out of the building", "Theo forgot that the presentation was due"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What does the detail that Ximena \"deleted it and typed an even longer one\" show?", correctAnswer: "Her frustration was growing", distractors: ["She was a careful writer", "Her phone was not working", "She had forgiven Theo"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What theme does the group project story suggest?", correctAnswer: "Understanding someone's situation can change your response", distractors: ["Group projects are always unfair to the hardest worker", "It is always best to do all of the work by yourself", "Sending an angry message solves problems quickly"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_7_test_retakes", tier: .medium, grades: 7...7,
            text: "When a student fails a math test, what should happen next? At many schools, the grade simply goes into the gradebook and the class moves on. I believe students should be allowed to retake tests.\n\nThe purpose of school is learning, not just ranking students on a single day. A student who fails a test on fractions but masters them a week later has still learned fractions, and that is the skill that matters for the next unit. Retakes also teach persistence. Instead of deciding \"I'm just bad at math,\" students learn that effort can turn a low score into a higher one.\n\nCritics worry that students won't bother studying the first time if they know they can try again. That is a fair point, which is why retakes should come with conditions. Before retaking a test, a student should have to correct the mistakes on the original test and attend a review session. Retakes should reward extra learning, not hand out a free second chance.",
            questions: [
                BankQuestion(prompt: "What is the writer's position on test retakes?", correctAnswer: "Students should be allowed to retake tests", distractors: ["Retakes should be banned in math class", "Every test should be taken twice", "Grades should not be recorded at all"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "Why does the writer mention a student who masters fractions a week later?", correctAnswer: "To show that later learning still counts", distractors: ["To show that fractions are very difficult", "To prove that math tests are too long", "To argue for more math homework"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What is the counterclaim in the test retake passage?", correctAnswer: "Students may not study the first time", distractors: ["Retakes teach students persistence", "School is about learning, not ranking", "Students must correct their mistakes"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "Why does the writer say test retakes should come with conditions?", correctAnswer: "So retakes reward real extra learning", distractors: ["So fewer students choose to retake", "So teachers have less grading to do", "So the second test is much harder"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_7_minor_burn_first_aid", tier: .easy, grades: 7...7,
            text: "Minor burns, like touching a hot pan or getting splashed with boiling water, are among the most common injuries in the kitchen. Knowing what to do in the first few minutes can reduce pain and help the skin heal.\n\n1. Move away from the heat source and tell an adult.\n2. Cool the burn under cool, not ice-cold, running water for at least 10 minutes. This draws heat out of the skin and eases pain.\n3. Remove rings, bracelets, or tight clothing near the burn before the area swells, but never pull off anything stuck to the skin.\n4. Cover the burn loosely with a clean, non-stick bandage or plastic wrap.\n\nJust as important is what not to do. Do not put ice on a burn; extreme cold can damage the skin further. Do not use butter or oil, which can trap heat. And do not pop any blisters, because they help protect the skin underneath from infection. Get medical help right away for burns that are larger than the palm of your hand, or that are on the face, hands, or joints.",
            questions: [
                BankQuestion(prompt: "How long should you cool a minor burn under running water?", correctAnswer: "At least 10 minutes", distractors: ["About 30 seconds", "Exactly 1 minute", "Until a blister forms"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "Why should you remove rings near a burn right away?", correctAnswer: "The area may swell", distractors: ["Rings may fall down the drain", "Rings scratch the bandage", "Water damages the jewelry"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "Why should you not pop a blister on a burn?", correctAnswer: "It protects the skin from infection", distractors: ["It helps the burn cool down faster", "It keeps the bandage from sticking", "It stops the area from swelling"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "How is the burn first aid passage organized?", correctAnswer: "Steps to take, then things to avoid", distractors: ["Causes of burns, then their effects", "A short story, then a lesson", "A problem, then several opinions"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_7_mary_anning", tier: .hard, grades: 7...7,
            text: "In the early 1800s, the cliffs near Lyme Regis, a seaside town in southern England, were crumbling into the sea, and they were full of fossils. A girl named Mary Anning grew up there. Her family was poor, and they earned money by collecting fossils from the beach and selling them to tourists.\n\nAround 1811, Mary's brother Joseph found a strange skull. Over the following months, Mary, then about twelve years old, uncovered the rest of the skeleton. It belonged to an ichthyosaur, a sea reptile that lived during the age of dinosaurs. The find amazed scientists. Mary kept searching the dangerous cliffs, especially after winter storms exposed new fossils. In 1823, she found the first complete skeleton of a plesiosaur, a long-necked marine reptile, and later she discovered one of the first pterosaur skeletons found outside Germany.\n\nDespite her skill, Mary faced barriers. As a woman, she was not allowed to join the Geological Society of London, and scientists who bought her fossils often published descriptions without crediting her. Today, however, she is recognized as one of the most important early fossil hunters, and her discoveries helped convince scientists that many species had lived long ago and died out.",
            questions: [
                BankQuestion(prompt: "How did Mary Anning's family earn money?", correctAnswer: "By selling fossils to tourists", distractors: ["By fishing along the coast", "By guiding scientists on cliffs", "By running a museum in London"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "Why did Mary Anning often search the cliffs after winter storms?", correctAnswer: "Storms exposed new fossils", distractors: ["The beach had no tourists", "Scientists visited in winter", "The cliffs were safer then"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What does the passage say an ichthyosaur was?", correctAnswer: "A sea reptile from the age of dinosaurs", distractors: ["A long-necked reptile that could fly", "A dinosaur that lived on sea cliffs", "A kind of fish that still lives today"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What is the main purpose of the third paragraph of the Mary Anning passage?", correctAnswer: "To describe her barriers and later recognition", distractors: ["To explain how fossils form in rock", "To show why the cliffs were dangerous", "To list every fossil she discovered"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_7_lightning_thunder", tier: .medium, grades: 7...7,
            text: "Lightning and thunder happen at the same moment, so why do we see the flash before we hear the rumble? The answer is speed. Light travels about 186,000 miles per second, so a lightning flash reaches your eyes almost instantly. Sound is much slower. In air, it travels roughly one mile every five seconds.\n\nThat difference lets you estimate how far away a storm is. When you see a flash, count the seconds until you hear thunder, then divide by five. If you count fifteen seconds, the lightning was about three miles away.\n\nThunder itself is created by lightning. A lightning bolt can heat the air around it to about 50,000 degrees Fahrenheit, hotter than the surface of the sun. The superheated air expands so violently that it creates a shock wave, which we hear as thunder. Because lightning can strike ten miles or more from a storm, weather experts advise going indoors as soon as you hear thunder, even if the sky above you looks clear.",
            questions: [
                BankQuestion(prompt: "Why do we see lightning before we hear thunder?", correctAnswer: "Light travels much faster than sound", distractors: ["Thunder happens after lightning ends", "Our eyes work faster than our ears", "Sound must travel around the clouds"], tier: .easy, grades: 7...7),
                BankQuestion(prompt: "If you count ten seconds between a flash and its thunder, about how far away was the lightning?", correctAnswer: "About two miles", distractors: ["About ten miles", "About five miles", "About fifty miles"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "What causes the sound of thunder?", correctAnswer: "Superheated air expanding very quickly", distractors: ["Storm clouds bumping into each other", "Heavy rain hitting the ground hard", "Lightning striking a tall tree"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "Why do experts advise going indoors when you hear thunder even if the sky looks clear?", correctAnswer: "Lightning can strike miles from a storm", distractors: ["Thunder can damage your hearing", "Clear skies mean rain is coming", "The shock wave can knock you over"], tier: .hard, grades: 7...7),
            ]),

        ReadingPassage(
            id: "en2_78_katherine_johnson", tier: .medium, grades: 7...8,
            text: "Katherine Johnson was born in 1918 in White Sulphur Springs, West Virginia, and she loved numbers from an early age. She counted everything: steps, dishes, stars. She was so advanced that she started high school at age ten and graduated from college at eighteen with degrees in mathematics and French.\n\nIn 1953, Johnson took a job at the Langley laboratory of NACA, the agency that later became NASA. She was hired as a \"computer,\" a person who performed complex calculations by hand. At the time, segregation separated Black and white workers in Virginia, and Johnson first worked in a segregated unit of Black women mathematicians. She quickly stood out for her precise work and for asking questions in meetings where women were rarely included.\n\nJohnson calculated the path for Alan Shepard's 1961 flight, which made him the first American in space. When John Glenn prepared to become the first American to orbit Earth in 1962, NASA used electronic computers to plan the flight. Glenn, however, wanted a human check. He reportedly asked that Johnson verify the computer's numbers before he would fly. She later worked on calculations for the Apollo 11 moon landing. In 2015, she received the Presidential Medal of Freedom, one of the nation's highest civilian honors.",
            questions: [
                BankQuestion(prompt: "What did the job title \"computer\" mean when Johnson was hired?", correctAnswer: "A person who did complex math by hand", distractors: ["A machine that planned space flights", "A person who repaired electronic machines", "A teacher who taught college mathematics"], tier: .easy, grades: 7...8),
                BankQuestion(prompt: "Which detail best shows that Johnson was unusually advanced as a student?", correctAnswer: "She started high school at age ten", distractors: ["She counted steps, dishes, and stars", "She studied French in college", "She was born in West Virginia"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "Why did John Glenn ask Johnson to check the computer's numbers?", correctAnswer: "He wanted a person to verify the results", distractors: ["The computers had already failed him", "She had built the electronic computers", "NASA required it for every flight"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "What does \"stood out\" mean in the Katherine Johnson passage?", correctAnswer: "Was noticed for being excellent", distractors: ["Was kept apart from coworkers", "Was left out of the meetings", "Stood up to leave the room"], tier: .hard, grades: 7...8),
            ]),

        ReadingPassage(
            id: "en2_78_conference_translator", tier: .hard, grades: 7...8,
            text: "Jiwoo had been translating for her mother since she was eight. Doctor's appointments, phone calls with the landlord, the man at the bank who talked too fast: Jiwoo turned English into Korean and Korean back into English, and she was good at it. Tonight's job was her little brother Minjun's parent-teacher conference.\n\nMs. Hartley smiled warmly, but her words were not warm. \"Minjun is bright,\" she said, \"but he rarely turns in his homework, and he's been talking during lessons.\" Jiwoo felt her mother's eyes on her, waiting. Minjun stared at his sneakers. It would be so easy to change a few words. She could say he was bright and leave out the rest, and everyone at home would have a peaceful evening.\n\nJiwoo opened her mouth, and for a second, the softer version was right there. Then she thought about the next conference, and the one after that, if the problem only grew. She translated every word. Her mother's face grew serious, and she thanked Ms. Hartley. On the walk home, her mother held Minjun's hand and talked quietly with him about a homework plan. At the corner, she reached for Jiwoo's hand, too. \"That was hard,\" she said in Korean. \"You did it right.\"",
            questions: [
                BankQuestion(prompt: "Why is Jiwoo at the parent-teacher conference?", correctAnswer: "To translate for her mother", distractors: ["To talk about her own grades", "To help Ms. Hartley teach", "To pick up her little brother"], tier: .easy, grades: 7...8),
                BankQuestion(prompt: "What does the phrase \"her words were not warm\" suggest?", correctAnswer: "The teacher's message was a criticism", distractors: ["The classroom was very cold that night", "The teacher was speaking too quietly", "The teacher was angry at Jiwoo herself"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "Why does Jiwoo decide to translate every word?", correctAnswer: "Hiding the problem could make it worse later", distractors: ["Ms. Hartley would notice any changes she made", "Minjun had asked her to tell the whole truth", "Her mother already understood all the English"], tier: .medium, grades: 7...8),
                BankQuestion(prompt: "What does the mother's final comment to Jiwoo reveal?", correctAnswer: "She values Jiwoo's honesty in a hard moment", distractors: ["She is disappointed in both of her children", "She wishes Jiwoo had softened the news", "She plans to stop going to conferences"], tier: .hard, grades: 7...8),
            ]),

        // ——— 8th grade ———

        ReadingPassage(
            id: "en2_8_penicillin", tier: .medium, grades: 8...8,
            text: "In September 1928, Scottish scientist Alexander Fleming returned to his London laboratory after a summer vacation. Before leaving, he had stacked several glass dishes growing Staphylococcus bacteria on his workbench. As he sorted through them, he noticed something odd: a fuzzy mold had contaminated one dish, and the bacteria near the mold had been destroyed.\n\nMany scientists would have thrown the ruined dish away. Fleming instead grew the mold, a type of Penicillium, and found that it produced a substance that killed many kinds of harmful bacteria. He named it penicillin. However, penicillin was difficult to purify and produce in large amounts, and for more than a decade it remained mostly a laboratory curiosity.\n\nIn the late 1930s and early 1940s, a team at the University of Oxford, led by Howard Florey and Ernst Chain, found ways to purify penicillin and showed it could cure infections in people. During World War II, companies in the United States and Britain developed methods to mass-produce it, saving countless soldiers from infected wounds. Yet Fleming himself warned in 1945 that misusing penicillin could allow bacteria to become resistant to it, a warning that doctors still repeat today about antibiotics.",
            questions: [
                BankQuestion(prompt: "What did Fleming notice about the contaminated dish?", correctAnswer: "Bacteria near the mold had been destroyed", distractors: ["The mold had spread to all of his dishes", "The bacteria had turned into a mold", "The glass dish had cracked in the heat"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why does the writer say \"Many scientists would have thrown the ruined dish away\"?", correctAnswer: "To highlight Fleming's curiosity", distractors: ["To criticize how messy labs were", "To explain how molds can spread", "To show the dish was dangerous"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why did penicillin remain \"a laboratory curiosity\" for over a decade?", correctAnswer: "It was hard to purify and produce in bulk", distractors: ["Fleming kept his discovery a secret", "It did not kill any harmful bacteria", "Doctors refused to test new medicines"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What was Fleming's 1945 warning about penicillin?", correctAnswer: "Misuse could let bacteria become resistant", distractors: ["It should be given only to soldiers", "It could never be mass-produced", "Molds would soon replace all medicines"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en2_8_strawberry_prices", tier: .medium, grades: 8...8,
            text: "Why does a carton of strawberries often cost more in January than in June? The answer lies in one of the most basic ideas in economics: supply and demand.\n\nSupply is how much of a product is available. Demand is how much of it people want to buy. In June, strawberry farms across much of the United States are harvesting, so stores are flooded with berries. When supply is high, sellers compete for customers by lowering prices. In January, most of those farms are not producing. Strawberries must come from warmer places or be shipped long distances, so fewer berries reach the stores. People still want strawberries in winter, and when demand stays steady but supply shrinks, prices rise.\n\nDemand can shift, too. If a popular cooking show suddenly features strawberry desserts, more people may rush to buy strawberries, pushing prices up even when supply hasn't changed. Economists use these patterns to explain prices for nearly everything, from concert tickets to gasoline. When you notice a price change, it is worth asking: did the supply change, the demand change, or both?",
            questions: [
                BankQuestion(prompt: "What does \"supply\" mean in the strawberry price passage?", correctAnswer: "How much of a product is available", distractors: ["How much of it people want to buy", "How much a product costs to make", "How far a product must be shipped"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "According to the passage, why are strawberries cheaper in June?", correctAnswer: "Many farms are harvesting, so supply is high", distractors: ["Fewer people want strawberries in summer", "Stores stop paying to ship berries in June", "Cooking shows feature other fruits then"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What does \"flooded\" mean as it is used in the strawberry price passage?", correctAnswer: "Filled with a very large amount", distractors: ["Damaged by heavy rain", "Washed with lots of water", "Closed for the season"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Based on the passage, what would most likely happen to prices if demand rose while supply stayed the same?", correctAnswer: "Prices would go up", distractors: ["Prices would go down", "Prices would stay the same", "Stores would stop selling them"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en2_8_service_requirement", tier: .hard, grades: 8...8,
            text: "Our school district is considering a requirement that every student complete 20 hours of community service before starting high school. The board should approve it.\n\nCommunity service teaches lessons that are hard to learn in a classroom. A student who tutors younger kids learns patience and discovers how much she actually understands about a subject. A student who sorts donations at a food bank sees firsthand that hunger exists in our own town. These experiences build empathy, the ability to understand how others feel, and they connect students to neighbors they might never have met.\n\nService can also help students discover their interests. An eighth grader who volunteers at an animal shelter might realize she wants to become a veterinarian. Twenty hours, spread over three years of middle school, is less than one hour a month, a small investment for such a large return.\n\nOpponents argue that required service isn't really volunteering, since volunteering should be a free choice. This objection deserves attention. But schools require many valuable things students might not choose on their own, from reading novels to running the mile. The requirement opens the door; what students discover on the other side is up to them. To keep it fair, the district should let students choose from a wide range of approved activities.",
            questions: [
                BankQuestion(prompt: "What requirement does the writer want the district's board to approve?", correctAnswer: "20 hours of community service before high school", distractors: ["20 hours of tutoring during every school year", "A community service club at every school", "One hour of service during every school week"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "How does the writer of the community service passage define empathy?", correctAnswer: "The ability to understand how others feel", distractors: ["The habit of helping without being asked", "The skill of teaching younger students", "The feeling of pride after hard work"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why does the writer point out that twenty hours is less than one hour a month?", correctAnswer: "To show the requirement is a small burden", distractors: ["To argue that students need more hours", "To show that service wastes students' time", "To explain how the hours will be counted"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "How does the writer respond to the claim that required service isn't real volunteering?", correctAnswer: "Schools already require valuable things students might skip", distractors: ["Most students would choose to volunteer anyway", "Volunteering is never truly a free choice", "Students who refuse should not move up a grade"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en2_8_red_bicycle", tier: .medium, grades: 8...8,
            text: "The bicycle had been hanging from two hooks in the garage for as long as Caleb could remember, covered in a gray blanket of dust. It was red, or it had been once, with a cracked white seat and a bell that no longer rang. When his mother mentioned selling it at the neighborhood yard sale, Caleb surprised himself by asking if he could fix it instead.\n\nFor three weekends, he worked with Mr. Alvarez from next door, who owned more wrenches than anyone Caleb had ever met. They replaced the tires and the brake cables, scrubbed rust from the chain, and oiled every moving part. The bell was the last thing. Mr. Alvarez took it apart, cleaned a tiny spring, and snapped it back together. Ring.\n\nWhen Caleb rolled the bike into the driveway, his mother came outside and stopped. For a long moment, she didn't say anything. Then she walked over and touched the handlebars. \"I rode this to the library every summer when I was your age,\" she said softly. \"I rang this bell at every corner so my mom would know I was almost home.\" She squeezed the bell once, and they both laughed. Caleb had thought he was fixing an old bike. He realized now he had been fixing something else, too.",
            questions: [
                BankQuestion(prompt: "What was Caleb's mother planning to do with the red bicycle?", correctAnswer: "Sell it at a yard sale", distractors: ["Give it to Mr. Alvarez", "Ride it to the library", "Hang it back on the hooks"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "What does \"surprised himself\" suggest about Caleb's request?", correctAnswer: "He had not planned to ask it", distractors: ["He was afraid of his mother", "He did not like old bicycles", "He wanted to startle his mother"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "Why is the bell an important detail in the red bicycle story?", correctAnswer: "It is tied to the mother's childhood memory", distractors: ["It was the most expensive part to fix", "It was the only part Caleb fixed alone", "It was the first part of the bike to break"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "What does Caleb mean when he realizes he was \"fixing something else, too\"?", correctAnswer: "He brought back a special memory for his mother", distractors: ["He also repaired several of Mr. Alvarez's tools", "He fixed the hooks in the garage at the same time", "He learned enough to start fixing cars next"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en2_8_checking_sources", tier: .easy, grades: 8...8,
            text: "Anyone can publish almost anything online, so before you trust a website for a research project, put it through a quick check. These steps can help you separate reliable information from rumors, advertising, and outdated claims.\n\n1. Identify the author or organization. Look for an \"About\" page. Is the writer an expert, a news organization with editors, a government agency, or someone anonymous?\n2. Check the date. Information about science, technology, or current events can go out of date quickly. A page from ten years ago may no longer be accurate.\n3. Consider the purpose. Is the site trying to inform you, or to sell you something or persuade you? A page about the health benefits of a juice, written by the company that sells the juice, deserves extra caution.\n4. Read laterally. Instead of staying on one site, open new tabs and search for what other trusted sources say about the site and its claims. Professional fact-checkers use this technique because a site can look polished and still be misleading.\n5. Look for evidence. Reliable sources usually explain where their facts come from and link to original research or data.\n\nNo single step proves a source is trustworthy, but together they make it much harder to be fooled.",
            questions: [
                BankQuestion(prompt: "Why does the source-checking passage suggest checking the date on a website?", correctAnswer: "Information can go out of date", distractors: ["Newer websites are always wrong", "Old websites are hard to read", "Dates show who wrote the page"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why does a juice company's page about its own juice deserve extra caution?", correctAnswer: "The company wants to sell its product", distractors: ["Juice companies are never experts", "The page is probably very old", "It cannot have an About page"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What does it mean to \"read laterally\"?", correctAnswer: "Check what other sources say about a site", distractors: ["Read a page slowly from top to bottom", "Read only the headlines on a site", "Read the About page before anything else"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What is the main message of the last sentence of the source-checking passage?", correctAnswer: "Using all the steps together protects you best", distractors: ["One careful step is always enough to be sure", "No information found online can be trusted", "Professional fact-checkers never make mistakes"], tier: .hard, grades: 8...8),
            ]),

        ReadingPassage(
            id: "en2_8_continental_drift", tier: .hard, grades: 8...8,
            text: "In 1912, a German scientist named Alfred Wegener proposed an idea that many of his colleagues found absurd. He suggested that the continents had once been joined in a single giant landmass, which he later called Pangaea, and had slowly drifted apart over millions of years.\n\nWegener gathered several kinds of evidence. First, the coastlines of South America and Africa fit together remarkably well, like pieces of a puzzle. Second, fossils of the same ancient species, such as Mesosaurus, a small freshwater reptile, were found in both South America and southern Africa. Mesosaurus could not have swum across a salty ocean. Third, rock layers and mountain ranges on different continents matched as if they had once been connected. He even pointed to evidence of ancient glaciers in regions that are now tropical.\n\nStill, most geologists rejected his theory, called continental drift. Their strongest objection was that Wegener could not explain what force could move entire continents. Wegener died in 1930 on an expedition in Greenland, his idea still largely dismissed. Decades later, in the 1950s and 1960s, scientists mapping the ocean floor discovered that new crust forms at underwater mountain ridges and spreads outward. This evidence led to the theory of plate tectonics, which showed that Wegener had been right about the big picture, even though the force behind the movement turned out to be different from what he had imagined.",
            questions: [
                BankQuestion(prompt: "What did Wegener propose in 1912?", correctAnswer: "The continents were once joined and drifted apart", distractors: ["The ocean floor formed from melting glaciers", "Mountains were pushed up by ancient reptiles", "Earth's continents have never moved at all"], tier: .easy, grades: 8...8),
                BankQuestion(prompt: "Why is it important that Mesosaurus was a freshwater reptile?", correctAnswer: "It could not have crossed a salty ocean", distractors: ["It shows the oceans were once fresh", "It proves reptiles lived on glaciers", "It explains how mountain ranges formed"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What does \"absurd\" most likely mean in the first paragraph of the Wegener passage?", correctAnswer: "Ridiculous or unreasonable", distractors: ["Carefully proven", "New and exciting", "Hard to understand"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "What was the main reason most geologists rejected continental drift?", correctAnswer: "Wegener could not explain what moved the continents", distractors: ["The coastlines of the continents did not match", "No matching fossils were found on two continents", "Wegener had never studied rocks or mountains"], tier: .hard, grades: 8...8),
            ]),
    ]
}
