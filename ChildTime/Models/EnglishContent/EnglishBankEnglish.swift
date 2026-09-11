import Foundation

/// 📘 English (language arts) — English (US). NEW content, not a translation:
/// in Hebrew this world teaches English as a foreign language; for a US child it
/// is their own language class. Follows Common Core–style Language and
/// Foundational Skills standards, grade by grade (0 = Kindergarten … 8 = 8th):
/// letters, sounds and rhymes → vowels, spelling patterns and end marks →
/// plurals, contractions, synonyms → parts of speech, homophones, ABC order →
/// affixes, commas, relative pronouns → conjunctions, tenses, figurative
/// language → pronoun case, roots, context clues → phrases, clauses, sentence
/// types, connotation → verbals, voice, mood, analogies.
/// Every prompt is answerable from its text alone; spelling items have exactly
/// one option spelled correctly in American English.
extension EnglishContent {
    static let english: [BankQuestion] = [
        // ── Kindergarten · letters ──
        BankQuestion(prompt: "🔤\nWhich letter comes right after A?", correctAnswer: "B", distractors: ["C", "D", "Z"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔤\nWhich letter comes right before D?", correctAnswer: "C", distractors: ["B", "E", "F"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔤\nWhich letter comes right after M?", correctAnswer: "N", distractors: ["L", "O", "P"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🥇\nWhich is the first letter of the alphabet?", correctAnswer: "A", distractors: ["Z", "B", "O"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔚\nWhich is the last letter of the alphabet?", correctAnswer: "Z", distractors: ["Y", "X", "A"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔡\nWhich is the small (lowercase) letter for B?", correctAnswer: "b", distractors: ["d", "p", "q"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🔠\nWhich is the capital letter for g?", correctAnswer: "G", distractors: ["J", "Q", "C"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🔢\nWhich one is a letter?", correctAnswer: "K", distractors: ["7", "3", "9"], tier: .easy, grades: 0...0),
        BankQuestion(prompt: "🗣️\nWhich letter is a vowel?", correctAnswer: "E", distractors: ["B", "T", "M"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🐱\nHow many letters are in the word \"cat\"?", correctAnswer: "3", distractors: ["2", "4", "5"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⚽\nHow many letters are in the word \"ball\"?", correctAnswer: "4", distractors: ["3", "5", "2"], tier: .medium, grades: 0...1),

        // ── Kindergarten · beginning and ending sounds ──
        BankQuestion(prompt: "🅱️\nWhich word starts with the letter B?", correctAnswer: "box", distractors: ["sun", "cat", "dog"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐍\nWhich word starts with the letter S?", correctAnswer: "sock", distractors: ["moon", "hat", "pig"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "Ⓜ️\nWhich word starts with the letter M?", correctAnswer: "mom", distractors: ["dad", "cup", "top"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐶\nWhat letter does \"dog\" start with?", correctAnswer: "D", distractors: ["B", "G", "P"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐟\nWhat letter does \"fish\" start with?", correctAnswer: "F", distractors: ["S", "H", "V"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🍏\nWhat letter does \"apple\" start with?", correctAnswer: "A", distractors: ["E", "P", "L"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🦇\nWhich word starts with the same sound as \"bat\"?", correctAnswer: "bed", distractors: ["cat", "hat", "sit"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🔝\nWhich word starts with the same sound as \"top\"?", correctAnswer: "ten", distractors: ["pot", "dog", "sun"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🌙\nWhich word starts with the same sound as \"moon\"?", correctAnswer: "mat", distractors: ["noon", "soon", "room"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🔚\nWhich word ends with the letter T?", correctAnswer: "pet", distractors: ["pen", "peg", "pup"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🚌\nWhich word ends with the same sound as \"bus\"?", correctAnswer: "yes", distractors: ["cup", "bed", "hat"], tier: .hard, grades: 0...1),

        // ── Kindergarten · rhyming ──
        BankQuestion(prompt: "🐈\nWhich word rhymes with \"cat\"?", correctAnswer: "hat", distractors: ["cup", "dog", "sun"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐕\nWhich word rhymes with \"dog\"?", correctAnswer: "log", distractors: ["dig", "cat", "bed"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐝\nWhich word rhymes with \"bee\"?", correctAnswer: "tree", distractors: ["bed", "bat", "bug"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⭐\nWhich word rhymes with \"star\"?", correctAnswer: "car", distractors: ["stop", "sun", "bat"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🎂\nWhich word rhymes with \"cake\"?", correctAnswer: "lake", distractors: ["cat", "kite", "cup"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🐞\nWhich word rhymes with \"bug\"?", correctAnswer: "rug", distractors: ["bag", "big", "bus"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🖊️\nWhich word rhymes with \"pen\"?", correctAnswer: "hen", distractors: ["pan", "pin", "pet"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🎶\nWhich two words rhyme?", correctAnswer: "fan and man", distractors: ["fan and fun", "sun and sit", "dog and dig"], tier: .medium, grades: 0...1),

        // ── Kindergarten · first words ──
        BankQuestion(prompt: "👀\nFill in the blank: I ___ a cat.", correctAnswer: "see", distractors: ["the", "and", "it"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🐕\nFill in the blank: The dog ___ big.", correctAnswer: "is", distractors: ["am", "are", "on"], tier: .medium, grades: 0...1),
        BankQuestion(prompt: "🎨\nWhich word names a color?", correctAnswer: "red", distractors: ["run", "rug", "rat"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔢\nWhich word is a number?", correctAnswer: "one", distractors: ["big", "up", "go"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔄\nChange the p in \"pig\" to w. What word do you get?", correctAnswer: "wig", distractors: ["wag", "pin", "big"], tier: .hard, grades: 0...1),
        BankQuestion(prompt: "🌞\nWhich letters spell \"sun\"?", correctAnswer: "s-u-n", distractors: ["s-a-n", "s-u-p", "n-u-s"], tier: .hard, grades: 0...1),
        BankQuestion(prompt: "🔤\nWhat word do these letters spell: f-o-x?", correctAnswer: "fox", distractors: ["fix", "box", "fog"], tier: .medium, grades: 0...1),

        // ── 1st grade · short and long vowels ──
        BankQuestion(prompt: "🐈\nWhich word has a short a sound, like in \"cat\"?", correctAnswer: "map", distractors: ["make", "rain", "day"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎂\nWhich word has a long a sound, like in \"cake\"?", correctAnswer: "rain", distractors: ["ran", "cat", "hat"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐷\nWhich word has a short i sound, like in \"pig\"?", correctAnswer: "sit", distractors: ["bike", "time", "kite"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "⛵\nWhich word has a long o sound, like in \"boat\"?", correctAnswer: "home", distractors: ["hot", "top", "dog"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🌳\nWhich word has a long e sound, like in \"tree\"?", correctAnswer: "team", distractors: ["bed", "ten", "net"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "☕\nWhich word has a short u sound, like in \"cup\"?", correctAnswer: "bus", distractors: ["cute", "mule", "June"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🛏️\nWhich word has the same vowel sound as \"bed\"?", correctAnswer: "red", distractors: ["bead", "bid", "bad"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🐝\nWhich word has \"ee\" making a long e sound?", correctAnswer: "green", distractors: ["bread", "ten", "then"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "✨\nAdd an e to the end of \"kit\". What word do you get?", correctAnswer: "kite", distractors: ["cute", "kept", "knit"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🐰\nAdd an e to the end of \"hop\". What word do you get?", correctAnswer: "hope", distractors: ["hoop", "hops", "hip"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🪄\nAdd an e to the end of \"cap\". What word do you get?", correctAnswer: "cape", distractors: ["cup", "caps", "cope"], tier: .medium, grades: 1...2),

        // ── 1st grade · blending, digraphs, spelling ──
        BankQuestion(prompt: "🔊\nBlend the sounds m - o - p. What word is it?", correctAnswer: "mop", distractors: ["map", "top", "hop"], tier: .easy, grades: 1...1),
        BankQuestion(prompt: "🔊\nBlend the sounds h - u - g. What word is it?", correctAnswer: "hug", distractors: ["hog", "bug", "hum"], tier: .easy, grades: 1...1),
        BankQuestion(prompt: "🚢\nWhich two letters make the first sound in \"ship\"?", correctAnswer: "sh", distractors: ["ch", "th", "wh"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🪑\nWhich two letters make the first sound in \"chair\"?", correctAnswer: "ch", distractors: ["sh", "th", "wh"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "👍\nWhich two letters make the first sound in \"thumb\"?", correctAnswer: "th", distractors: ["sh", "ch", "wh"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🦆\nWhich two letters make the last sound in \"duck\"?", correctAnswer: "ck", distractors: ["ch", "sh", "th"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🤫\nWhich word starts with \"sh\"?", correctAnswer: "shoe", distractors: ["chin", "thin", "sock"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐟\nWhich spelling is correct for the animal that swims in a pond?", correctAnswer: "fish", distractors: ["fsh", "fich", "fisch"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🐸\nWhich spelling is correct for a green animal that hops?", correctAnswer: "frog", distractors: ["frogg", "forg", "frug"], tier: .medium, grades: 1...2),

        // ── 1st grade · capitals and end marks ──
        BankQuestion(prompt: "🔠\nWhich word needs a capital letter? \"we went to the park.\"", correctAnswer: "we", distractors: ["went", "park", "the"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧒\nWhich word should have a capital letter? \"My friend sam likes to swim.\"", correctAnswer: "sam", distractors: ["friend", "likes", "swim"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🔠\nWhich word should always start with a capital letter?", correctAnswer: "Monday", distractors: ["apple", "happy", "run"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🎩\nWhat mark goes at the end? \"Where is my hat\"", correctAnswer: "?", distractors: [".", "!", ","], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔴\nWhat mark goes at the end? \"I have a red ball\"", correctAnswer: ".", distractors: ["?", ",", "-"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "😲\nWhich mark shows a big, strong feeling, like in \"Watch out\"?", correctAnswer: "!", distractors: ["?", ",", "-"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "📆\nWhat mark goes after the 4 in the date \"July 4 2026\"?", correctAnswer: ",", distractors: [".", "?", "!"], tier: .easy, grades: 1...2),

        // ── 1st grade · word endings and word kinds ──
        BankQuestion(prompt: "🐈\nOne cat, two ___.", correctAnswer: "cats", distractors: ["cat", "cates", "catses"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "📦\nOne box, two ___.", correctAnswer: "boxes", distractors: ["boxs", "box", "boxies"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🍽️\nOne dish, two ___.", correctAnswer: "dishes", distractors: ["dishs", "dish", "dishies"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🐶\nWhich word means more than one?", correctAnswer: "dogs", distractors: ["dog", "run", "big"], tier: .easy, grades: 1...1),
        BankQuestion(prompt: "🦘\nToday I jump. Yesterday I ___.", correctAnswer: "jumped", distractors: ["jumpd", "jumps", "jumping"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🤝\nFill in the blank: ___ you like to play?", correctAnswer: "Do", distractors: ["Is", "Are", "Am"], tier: .medium, grades: 1...2),
        BankQuestion(prompt: "🎬\nWhich word is an action word?", correctAnswer: "run", distractors: ["red", "cat", "tall"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "📍\nWhich word names a place?", correctAnswer: "park", distractors: ["jump", "happy", "slow"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🧸\nWhich word describes how something feels?", correctAnswer: "soft", distractors: ["sit", "sofa", "sing"], tier: .medium, grades: 1...2),

        // ── 2nd grade · irregular plurals ──
        BankQuestion(prompt: "🐭\nOne mouse, two ___.", correctAnswer: "mice", distractors: ["mouses", "mices", "meese"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧒\nOne child, many ___.", correctAnswer: "children", distractors: ["childs", "childrens", "childes"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🦷\nOne tooth, two ___.", correctAnswer: "teeth", distractors: ["tooths", "toothes", "teeths"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🦶\nOne foot, two ___.", correctAnswer: "feet", distractors: ["foots", "feets", "footes"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🪿\nOne goose, a flock of ___.", correctAnswer: "geese", distractors: ["gooses", "geeses", "goosies"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "👨\nOne man, two ___.", correctAnswer: "men", distractors: ["mans", "mens", "manies"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐑\nOne sheep, two ___.", correctAnswer: "sheep", distractors: ["sheeps", "sheepes", "sheepies"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🍂\nOne leaf, two ___.", correctAnswer: "leaves", distractors: ["leafs", "leafes", "leavs"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "👶\nOne baby, two ___.", correctAnswer: "babies", distractors: ["babys", "babyes", "babis"], tier: .medium, grades: 2...3),

        // ── 2nd grade · contractions ──
        BankQuestion(prompt: "🚫\nWhat is the short way to write \"do not\"?", correctAnswer: "don't", distractors: ["do'nt", "dont", "doesn't"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "✂️\nThe word \"can't\" is short for:", correctAnswer: "cannot", distractors: ["can it", "could not", "can too"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🙋\nThe word \"I'm\" is short for:", correctAnswer: "I am", distractors: ["I will", "I have", "I was"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "👫\nThe word \"we're\" is short for:", correctAnswer: "we are", distractors: ["we were", "we will", "we have"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "☔\nWhat is the short way to write \"it is\"?", correctAnswer: "it's", distractors: ["its", "it'is", "i'ts"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "👥\nWhat is the short way to write \"they will\"?", correctAnswer: "they'll", distractors: ["they're", "they've", "theyll"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "👧\nWhat is the short way to write \"she is\"?", correctAnswer: "she's", distractors: ["shes", "she'is", "she'll"], tier: .medium, grades: 2...3),

        // ── 2nd grade · synonyms and antonyms ──
        BankQuestion(prompt: "🐘\nWhich word means almost the same as \"big\"?", correctAnswer: "large", distractors: ["small", "tiny", "short"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "😊\nWhich word means almost the same as \"happy\"?", correctAnswer: "glad", distractors: ["sad", "mad", "tired"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐇\nWhich word means almost the same as \"fast\"?", correctAnswer: "quick", distractors: ["slow", "late", "soft"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏁\nWhich word means almost the same as \"begin\"?", correctAnswer: "start", distractors: ["stop", "end", "finish"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🔥\nWhich word means the opposite of \"hot\"?", correctAnswer: "cold", distractors: ["warm", "wet", "sunny"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "⬆️\nWhich word means the opposite of \"up\"?", correctAnswer: "down", distractors: ["over", "in", "top"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "📢\nWhich word means the opposite of \"loud\"?", correctAnswer: "quiet", distractors: ["noisy", "big", "happy"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🧺\nWhich word means the opposite of \"empty\"?", correctAnswer: "full", distractors: ["bare", "open", "clean"], tier: .medium, grades: 2...3),

        // ── 2nd grade · compound words and more ──
        BankQuestion(prompt: "🧩\nWhich one is a compound word?", correctAnswer: "sunflower", distractors: ["flower", "sunny", "running"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "➕\nPut two words together: rain + bow =", correctAnswer: "rainbow", distractors: ["rainbox", "rainy", "bowrain"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🏈\nWhich two words make \"football\"?", correctAnswer: "foot + ball", distractors: ["food + ball", "foot + bell", "four + ball"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "➕\nPut two words together: tooth + brush =", correctAnswer: "toothbrush", distractors: ["toothpaste", "brushtooth", "teethbrush"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐠\nA group of fish is called a ___.", correctAnswer: "school", distractors: ["team", "class", "flock"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🎨\nFill in the blank: I made the card by ___.", correctAnswer: "myself", distractors: ["me", "mine", "himself"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🧹\nFill in the blank: They cleaned their room by ___.", correctAnswer: "themselves", distractors: ["theirselves", "yourself", "himself"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🪑\nToday I sit. Yesterday I ___.", correctAnswer: "sat", distractors: ["sitted", "sits", "sitting"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🏃\nToday we run. Yesterday we ___.", correctAnswer: "ran", distractors: ["runned", "runs", "running"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "🐦\nToday I see a bird. Yesterday I ___ a bird.", correctAnswer: "saw", distractors: ["seed", "seen", "sees"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "📖\nToday they tell a story. Yesterday they ___ a story.", correctAnswer: "told", distractors: ["telled", "tells", "tolled"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "⚽\nWhich one shows that the ball belongs to Sam?", correctAnswer: "Sam's ball", distractors: ["Sams ball", "Sams' ball", "Sam ball"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "😞\nWhat does \"unhappy\" mean?", correctAnswer: "not happy", distractors: ["very happy", "happy again", "happy before"], tier: .easy, grades: 2...3),
        BankQuestion(prompt: "🐢\nFill in the blank: The turtle walks ___.", correctAnswer: "slowly", distractors: ["slowest", "slowness", "slowed"], tier: .medium, grades: 2...3),
        BankQuestion(prompt: "📅\nWhich spelling is correct? (It means the day after today.)", correctAnswer: "tomorrow", distractors: ["tommorow", "tomorow", "tommorrow"], tier: .hard, grades: 2...3),

        // ── 3rd grade · parts of speech ──
        BankQuestion(prompt: "🍎\nWhich word is a noun?", correctAnswer: "teacher", distractors: ["quickly", "ran", "tall"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "⚡\nWhich word is a verb?", correctAnswer: "swim", distractors: ["tiny", "happy", "window"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🧩\nWhich word is an adjective?", correctAnswer: "shiny", distractors: ["shine", "shoe", "slowly"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔎\nWhich word is an adverb?", correctAnswer: "loudly", distractors: ["lion", "laugh", "lonely"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🌬️\nWhat is the noun in this sentence? \"The kite flew high.\"", correctAnswer: "kite", distractors: ["flew", "high", "The"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "⚽\nWhat is the verb in this sentence? \"Maya kicked the ball.\"", correctAnswer: "kicked", distractors: ["Maya", "ball", "the"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🍑\nWhat is the adjective in this sentence? \"We ate a juicy peach.\"", correctAnswer: "juicy", distractors: ["ate", "peach", "We"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "💭\nWhich word is an abstract noun (something you can't see or touch)?", correctAnswer: "courage", distractors: ["pencil", "river", "dog"], tier: .hard, grades: 3...4),

        // ── 3rd grade · irregular past tense ──
        BankQuestion(prompt: "✉️\nFill in the blank: Yesterday, she ___ a letter to Grandma.", correctAnswer: "wrote", distractors: ["writed", "written", "writes"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🧊\nFill in the blank: Last night, the pond ___ solid.", correctAnswer: "froze", distractors: ["freezed", "frozen", "freezes"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🥪\nFill in the blank: We ___ our lunch at noon yesterday.", correctAnswer: "ate", distractors: ["eated", "eaten", "eats"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🐦\nFill in the blank: The bird ___ away when the cat came.", correctAnswer: "flew", distractors: ["flyed", "flown", "flys"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🎣\nFill in the blank: Tom ___ a big fish last summer.", correctAnswer: "caught", distractors: ["catched", "catch", "caughted"], tier: .medium, grades: 3...4),

        // ── 3rd grade · homophones ──
        BankQuestion(prompt: "🎒\nFill in the blank: The kids forgot ___ backpacks.", correctAnswer: "their", distractors: ["there", "they're", "thier"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📦\nFill in the blank: Put the box over ___.", correctAnswer: "there", distractors: ["their", "they're", "thier"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🦓\nFill in the blank: ___ going to the zoo today.", correctAnswer: "They're", distractors: ["Their", "There", "Thier"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🍎\nFill in the blank: I have ___ apples.", correctAnswer: "two", distractors: ["to", "too", "tow"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🙋\nFill in the blank: I want to come, ___.", correctAnswer: "too", distractors: ["to", "two", "tow"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🍃\nFill in the blank: The wind ___ the leaves away.", correctAnswer: "blew", distractors: ["blue", "blow", "bloo"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "💡\nFill in the blank: I ___ the answer!", correctAnswer: "know", distractors: ["no", "noe", "now"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏆\nFill in the blank: We ___ the game last night!", correctAnswer: "won", distractors: ["one", "wan", "wone"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔔\nFill in the blank: Can you ___ the bell?", correctAnswer: "hear", distractors: ["here", "heer", "hair"], tier: .medium, grades: 3...4),

        // ── 3rd grade · ABC order and dictionary ──
        BankQuestion(prompt: "🔤\nWhich word comes first in ABC order?", correctAnswer: "apple", distractors: ["banana", "cherry", "grape"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🔤\nWhich word comes first in ABC order: sock, sand, sun, seal?", correctAnswer: "sand", distractors: ["seal", "sock", "sun"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔤\nWhich word comes first in ABC order: pig, pan, pet, pot?", correctAnswer: "pan", distractors: ["pet", "pig", "pot"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🔤\nWhich word comes last in ABC order: bread, brown, bring, brave?", correctAnswer: "brown", distractors: ["bread", "bring", "brave"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "📕\nThe guide words on a dictionary page are \"cat\" and \"cup.\" Which word is on that page?", correctAnswer: "cow", distractors: ["cab", "dog", "cut"], tier: .hard, grades: 3...4),

        // ── 3rd grade · comparing, agreement, punctuation ──
        BankQuestion(prompt: "🐋\nFill in the blank: A whale is ___ than a dolphin.", correctAnswer: "bigger", distractors: ["biger", "more big", "biggest"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🌡️\nFill in the blank: That was the ___ day of the year.", correctAnswer: "hottest", distractors: ["hotest", "hotter", "most hot"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "📚\nFill in the blank: This book is ___ than that one.", correctAnswer: "better", distractors: ["gooder", "best", "more good"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🐕\nFill in the blank: The dogs ___ in the yard.", correctAnswer: "play", distractors: ["plays", "playing", "is play"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🏫\nFill in the blank: My sister ___ to school.", correctAnswer: "walks", distractors: ["walk", "walking", "are walk"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "🤲\nWhat does \"careless\" mean?", correctAnswer: "without care", distractors: ["full of care", "caring again", "caring before"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🤝\nWhat does \"helpful\" mean?", correctAnswer: "full of help", distractors: ["without help", "help again", "not helping"], tier: .easy, grades: 3...4),
        BankQuestion(prompt: "💬\nWhich sentence uses quotation marks correctly?", correctAnswer: "\"Let's go,\" said Mia.", distractors: ["Let's go, \"said Mia.\"", "\"Let's go, said Mia.\"", "Let's \"go,\" said Mia."], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🧸\nWhich one shows toys that belong to two boys?", correctAnswer: "the boys' toys", distractors: ["the boy's toys", "the boys toys", "the boyses toys"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🤠\nWhich city and state are written correctly?", correctAnswer: "Dallas, Texas", distractors: ["Dallas Texas,", ",Dallas Texas", "Dallas; Texas"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🤔\nWhich spelling is correct? (It tells why: \"I stayed home ___ I was sick.\")", correctAnswer: "because", distractors: ["becuase", "becaus", "becos"], tier: .medium, grades: 3...4),

        // ── 4th grade · prefixes, suffixes, roots ──
        BankQuestion(prompt: "📝\nWhat does the prefix \"re-\" mean in \"redo\"?", correctAnswer: "again", distractors: ["not", "before", "under"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "🎬\nWhat does the prefix \"pre-\" mean in \"preview\"?", correctAnswer: "before", distractors: ["after", "again", "not"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "✏️\nWhat does the prefix \"mis-\" mean in \"misspell\"?", correctAnswer: "wrongly", distractors: ["again", "before", "very"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "💬\nWhat does the prefix \"dis-\" mean in \"disagree\"?", correctAnswer: "not", distractors: ["again", "before", "more"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🎨\nWhat does the suffix \"-ish\" mean in \"greenish\"?", correctAnswer: "somewhat", distractors: ["without", "again", "before"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "👩‍🏫\nWhat does the suffix \"-er\" mean in \"teacher\"?", correctAnswer: "a person who", distractors: ["without", "full of", "again"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🧼\nWhat does the suffix \"-able\" mean in \"washable\"?", correctAnswer: "can be", distractors: ["cannot be", "full of", "before"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🚪\nWhich word means the opposite of \"lock\"?", correctAnswer: "unlock", distractors: ["relock", "prelock", "mislock"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "🍳\nWhich word means \"to cook too much\"?", correctAnswer: "overcook", distractors: ["undercook", "precook", "recook"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "⭐\nThe root \"graph\" in \"autograph\" means ___.", correctAnswer: "write", distractors: ["see", "hear", "carry"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "📞\nThe root \"tele\" in \"telephone\" means ___.", correctAnswer: "far", distractors: ["sound", "near", "small"], tier: .hard, grades: 4...5),

        // ── 4th grade · commas and sentences ──
        BankQuestion(prompt: "🧳\nWhich sentence uses commas correctly?", correctAnswer: "I packed socks, shirts, and shoes.", distractors: ["I packed, socks shirts and shoes.", "I packed socks shirts, and, shoes.", "I, packed socks, shirts and shoes."], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🐯\nWhere do the commas go? \"We saw lions tigers and bears.\"", correctAnswer: "We saw lions, tigers, and bears.", distractors: ["We saw, lions tigers, and bears.", "We saw lions tigers, and, bears.", "We, saw lions, tigers and bears."], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🐶\nWhich one is a complete sentence?", correctAnswer: "The puppy slept all day.", distractors: ["The puppy all day.", "Slept all day.", "Because the puppy slept."], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "🍕\nWhich one is a run-on sentence?", correctAnswer: "I like pizza my brother likes tacos.", distractors: ["I like pizza, and my brother likes tacos.", "I like pizza. My brother likes tacos.", "I like pizza, but not tacos."], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🐈\nWhich words are a prepositional phrase? \"The cat hid under the bed.\"", correctAnswer: "under the bed", distractors: ["The cat", "cat hid", "hid under"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🔴\nWhich phrase puts the describing words in the right order?", correctAnswer: "a big red ball", distractors: ["a red big ball", "a ball big red", "a big ball red"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "📦\nWhich phrase puts the three describing words in the right order?", correctAnswer: "a lovely old wooden box", distractors: ["a wooden old lovely box", "an old lovely wooden box", "a lovely wooden old box"], tier: .hard, grades: 4...5),

        // ── 4th grade · relative pronouns, tenses, helping verbs ──
        BankQuestion(prompt: "🏅\nFill in the blank: The girl ___ won the race is my cousin.", correctAnswer: "who", distractors: ["which", "whose", "where"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "📗\nFill in the blank: I lost the book ___ you gave me.", correctAnswer: "that", distractors: ["who", "whose", "where"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🐩\nFill in the blank: That's the boy ___ dog is so fluffy.", correctAnswer: "whose", distractors: ["who's", "who", "which"], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "⚽\nFill in the blank: This is the park ___ we play soccer.", correctAnswer: "where", distractors: ["when", "who", "whose"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "📚\nWhich sentence is in the past progressive tense?", correctAnswer: "I was reading.", distractors: ["I am reading.", "I will be reading.", "I read."], tier: .hard, grades: 4...5),
        BankQuestion(prompt: "🖍️\nWhich verb shows it is happening right now? \"She ___ a picture.\"", correctAnswer: "is drawing", distractors: ["was drawing", "will draw", "drew"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🚪\nWhich helping verb gives permission? \"You ___ go outside now.\"", correctAnswer: "may", distractors: ["must", "should", "would"], tier: .hard, grades: 4...5),

        // ── 4th grade · commonly confused words and meanings ──
        BankQuestion(prompt: "🐕\nFill in the blank: The dog wagged ___ tail.", correctAnswer: "its", distractors: ["it's", "its'", "it is"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🌧️\nFill in the blank: ___ raining outside.", correctAnswer: "It's", distractors: ["Its", "Its'", "Is"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "👟\nFill in the blank: My shoe is too ___ and keeps falling off.", correctAnswer: "loose", distractors: ["lose", "loss", "lost"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🎟️\nFill in the blank: Don't ___ your ticket!", correctAnswer: "lose", distractors: ["loose", "loss", "lows"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🥧\nFill in the blank: I ate a ___ of pie.", correctAnswer: "piece", distractors: ["peace", "peice", "peas"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🎤\nFill in the blank: She sings very ___.", correctAnswer: "well", distractors: ["good", "goodly", "weller"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🤔\nIn \"The bat flew out of the cave,\" what is a bat?", correctAnswer: "a flying animal", distractors: ["a stick for hitting balls", "a kind of rock", "a baseball glove"], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "💬\nWhat does \"It's raining cats and dogs\" mean?", correctAnswer: "It is raining very hard.", distractors: ["Pets are falling from the sky.", "It is a little sunny.", "The animals are wet."], tier: .easy, grades: 4...5),
        BankQuestion(prompt: "☀️\nWhich sentence has a simile?", correctAnswer: "Her smile was as bright as the sun.", distractors: ["Her smile was very bright.", "The sun is bright today.", "She smiled at the sun."], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🦸\nWhich word is a synonym for \"brave\"?", correctAnswer: "courageous", distractors: ["fearful", "timid", "lazy"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🏛️\nWhich word is an antonym for \"ancient\"?", correctAnswer: "modern", distractors: ["old", "huge", "broken"], tier: .medium, grades: 4...5),
        BankQuestion(prompt: "🤗\nWhich spelling is correct? (It means a person you like to play with.)", correctAnswer: "friend", distractors: ["freind", "frend", "frien"], tier: .easy, grades: 4...5),

        // ── 5th grade · conjunctions, interjections, prepositions ──
        BankQuestion(prompt: "🌙\nWhich word is a conjunction? \"I wanted to go, but it was late.\"", correctAnswer: "but", distractors: ["wanted", "late", "it"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🥪\nFill in the conjunction: I was hungry, ___ I ate a sandwich.", correctAnswer: "so", distractors: ["but", "or", "nor"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🧃\nFill in the conjunction: You can have juice ___ milk, but not both.", correctAnswer: "or", distractors: ["and", "so", "yet"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🌶️\nFill in the blank: ___ my mom nor my dad likes spicy food.", correctAnswer: "Neither", distractors: ["Either", "Both", "Whether"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🚲\nFill in the blank: We can ___ walk or ride our bikes.", correctAnswer: "either", distractors: ["neither", "both", "whether"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🌟\nFill in the blank: She is ___ smart and kind.", correctAnswer: "both", distractors: ["either", "neither", "whether"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🗯️\nWhich word is an interjection?", correctAnswer: "Ouch", distractors: ["Oven", "Over", "Only"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🎉\nFind the interjection: \"Hooray, we won the game!\"", correctAnswer: "Hooray", distractors: ["won", "game", "we"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🔑\nWhich word is a preposition? \"The keys are beneath the mat.\"", correctAnswer: "beneath", distractors: ["keys", "are", "mat"], tier: .medium, grades: 5...6),

        // ── 5th grade · verb tenses ──
        BankQuestion(prompt: "📝\nWhich sentence is in the present perfect tense?", correctAnswer: "I have finished my homework.", distractors: ["I finished my homework.", "I had finished my homework.", "I will finish my homework."], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🚗\nWhich sentence is in the past perfect tense?", correctAnswer: "They had left before we arrived.", distractors: ["They left early.", "They have left.", "They will have left."], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🎓\nFill in the blank: By next June, I ___ fifth grade.", correctAnswer: "will have finished", distractors: ["have finished", "had finished", "finishing"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🚪\nWhich sentence stays in one tense?", correctAnswer: "She opened the door and walked inside.", distractors: ["She opens the door and walked inside.", "She opened the door and walks inside.", "She will open the door and walked inside."], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "✈️\nWhat tense is the verb in \"We will travel to Ohio\"?", correctAnswer: "future", distractors: ["past", "present", "present perfect"], tier: .easy, grades: 5...6),

        // ── 5th grade · figurative language ──
        BankQuestion(prompt: "🦓\nWhich sentence is a metaphor?", correctAnswer: "The classroom was a zoo.", distractors: ["The classroom was like a zoo.", "We visited the zoo.", "The zoo was loud."], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "❄️\n\"The snow was a white blanket on the town.\" What kind of figurative language is this?", correctAnswer: "metaphor", distractors: ["simile", "onomatopoeia", "alliteration"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🐆\n\"He ran as fast as a cheetah.\" What kind of figurative language is this?", correctAnswer: "simile", distractors: ["metaphor", "onomatopoeia", "personification"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🍂\nWhich sentence uses personification?", correctAnswer: "The leaves danced in the wind.", distractors: ["The leaves fell in the wind.", "The leaves were red and gold.", "The wind was cold today."], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🔊\nWhich word is an example of onomatopoeia?", correctAnswer: "buzz", distractors: ["bee", "fly", "quiet"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🐴\n\"I'm so hungry I could eat a horse!\" What kind of figurative language is this?", correctAnswer: "hyperbole", distractors: ["simile", "metaphor", "onomatopoeia"], tier: .medium, grades: 5...6),

        // ── 5th grade · idioms and sayings ──
        BankQuestion(prompt: "🍰\nWhat does \"a piece of cake\" mean?", correctAnswer: "very easy", distractors: ["very tasty", "a small amount", "a party"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🧊\nWhat does \"break the ice\" mean?", correctAnswer: "start a friendly conversation", distractors: ["crack a frozen pond", "feel very cold", "ruin something"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "☁️\nWhat does \"under the weather\" mean?", correctAnswer: "feeling sick", distractors: ["out in the rain", "very happy", "in a hurry"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "📚\nWhat does \"hit the books\" mean?", correctAnswer: "study hard", distractors: ["throw books", "close your books", "fix old books"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🐈\nWhat does \"let the cat out of the bag\" mean?", correctAnswer: "tell a secret", distractors: ["free a pet", "go shopping", "clean up a mess"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🤔\nWhat does \"cost an arm and a leg\" mean?", correctAnswer: "be very expensive", distractors: ["cause an injury", "be free", "take a long time"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🐣\nWhat does \"Don't count your chickens before they hatch\" mean?", correctAnswer: "Don't plan on something before it happens.", distractors: ["Chickens are hard to count.", "Eggs hatch slowly.", "Always count carefully."], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🙌\nWhat does \"Actions speak louder than words\" mean?", correctAnswer: "What you do matters more than what you say.", distractors: ["Loud people get noticed.", "Talking is better than doing.", "Quiet people never act."], tier: .medium, grades: 5...6),

        // ── 5th grade · commas, titles, roots, word meaning ──
        BankQuestion(prompt: "🍲\nWhich sentence uses a comma after an introductory word correctly?", correctAnswer: "Yes, I would like some soup.", distractors: ["Yes I, would like some soup.", "Yes I would, like some soup.", "Yes I would like, some soup."], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "👋\nWhich sentence uses a comma correctly when speaking to someone by name?", correctAnswer: "Is that you, Omar?", distractors: ["Is, that you Omar?", "Is that, you Omar?", "Is that you Omar,?"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "💻\nWhen you type the title of a book, how should it look?", correctAnswer: "in italics", distractors: ["in parentheses", "in ALL CAPS", "with a colon after it"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "🧬\nThe root \"bio\" (as in biology) means ___.", correctAnswer: "life", distractors: ["earth", "water", "star"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🧩\nThe root \"port\" (as in transport) means ___.", correctAnswer: "carry", distractors: ["see", "write", "break"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🏛️\nThe root \"spect\" (as in inspect) means ___.", correctAnswer: "look", distractors: ["hear", "build", "throw"], tier: .hard, grades: 5...6),
        BankQuestion(prompt: "📜\nThe root \"geo\" (as in geography) means ___.", correctAnswer: "earth", distractors: ["life", "sound", "light"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "📄\nIn \"Please don't tear the paper,\" what does \"tear\" mean?", correctAnswer: "rip", distractors: ["a drop from your eye", "fold", "color"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "🏔️\nWhich word is a synonym for \"enormous\"?", correctAnswer: "gigantic", distractors: ["tiny", "narrow", "gentle"], tier: .easy, grades: 5...6),
        BankQuestion(prompt: "🎁\nWhich word is an antonym for \"generous\"?", correctAnswer: "selfish", distractors: ["kind", "giving", "polite"], tier: .medium, grades: 5...6),
        BankQuestion(prompt: "✅\nWhich spelling is correct? (It means \"for sure.\")", correctAnswer: "definitely", distractors: ["definately", "definitly", "defenitely"], tier: .hard, grades: 5...6),

        // ── 6th grade · pronoun case ──
        BankQuestion(prompt: "🎟️\nFill in the blank: Mom gave the tickets to Jake and ___.", correctAnswer: "her", distractors: ["she", "herself", "hers"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🏰\nFill in the blank: ___ and I built a fort.", correctAnswer: "He", distractors: ["Him", "His", "Himself"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🎵\nFill in the blank: Between you and ___, this is my favorite song.", correctAnswer: "me", distractors: ["I", "myself", "mine"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "🏀\nFill in the blank: The coach picked ___ for the team.", correctAnswer: "us", distractors: ["we", "our", "ourselves"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🥇\nFill in the blank: ___ are the best players on the team.", correctAnswer: "Sara and she", distractors: ["Sara and her", "Her and Sara", "Sara and herself"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "🍿\nFill in the blank: My friends and ___ went to the movies.", correctAnswer: "I", distractors: ["me", "myself", "mine"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎯\nWhich pronoun is in the objective case?", correctAnswer: "them", distractors: ["they", "we", "she"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎯\nWhich pronoun is in the subjective case?", correctAnswer: "I", distractors: ["me", "us", "him"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🏠\nWhich word is a possessive pronoun?", correctAnswer: "theirs", distractors: ["they", "them", "themselves"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎀\nWhich word is a reflexive pronoun?", correctAnswer: "herself", distractors: ["her", "hers", "she"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🎂\nIn \"I myself baked the whole cake,\" what kind of pronoun is \"myself\"?", correctAnswer: "intensive", distractors: ["possessive", "demonstrative", "interrogative"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "🐦\nFill in the blank: The birds built ___ nest in the oak tree.", correctAnswer: "their", distractors: ["its", "it's", "they're"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎶\nWhich word is a demonstrative pronoun? \"This is my favorite song.\"", correctAnswer: "This", distractors: ["is", "my", "song"], tier: .medium, grades: 6...7),

        // ── 6th grade · Greek and Latin roots ──
        BankQuestion(prompt: "🎭\nThe Latin root \"aud\" (as in audience) means ___.", correctAnswer: "hear", distractors: ["see", "speak", "walk"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "📜\nThe Greek root \"chron\" (as in chronological) means ___.", correctAnswer: "time", distractors: ["color", "sound", "place"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🔮\nThe Latin root \"dict\" (as in predict) means ___.", correctAnswer: "say", distractors: ["see", "hold", "carry"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎻\nThe Greek root \"phon\" (as in symphony) means ___.", correctAnswer: "sound", distractors: ["light", "love", "fear"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🌋\nThe Latin root \"rupt\" (as in erupt) means ___.", correctAnswer: "break", distractors: ["build", "carry", "turn"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🔬\nThe Greek root \"micro\" (as in microscope) means ___.", correctAnswer: "small", distractors: ["large", "far", "many"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🐠\nThe Latin root \"aqua\" (as in aquarium) means ___.", correctAnswer: "water", distractors: ["air", "fish", "earth"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🌡️\nUsing its Greek parts, what does \"thermometer\" literally mean?", correctAnswer: "heat measure", distractors: ["light writer", "sound carrier", "far seer"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "🧩\nThe prefix \"trans-\" (as in transport) means ___.", correctAnswer: "across", distractors: ["under", "again", "against"], tier: .medium, grades: 6...7),

        // ── 6th grade · context clues ──
        BankQuestion(prompt: "🥾\n\"The trail was so arduous that we had to stop and rest every few minutes.\" What does \"arduous\" mean?", correctAnswer: "very difficult", distractors: ["very short", "very pretty", "very flat"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🥪\n\"Liam was famished after skipping lunch, so he ate three sandwiches.\" What does \"famished\" mean?", correctAnswer: "very hungry", distractors: ["very tired", "very bored", "very full"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🐱\n\"The kitten was timid and hid behind the couch whenever guests arrived.\" What does \"timid\" mean?", correctAnswer: "shy", distractors: ["loud", "sleepy", "playful"], tier: .easy, grades: 6...7),
        BankQuestion(prompt: "🌉\n\"The old bridge was fragile, so only one person could cross at a time.\" What does \"fragile\" mean?", correctAnswer: "easily broken", distractors: ["very long", "brand new", "very strong"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🌊\n\"After the storm, the river was murky, and we couldn't see the bottom.\" What does \"murky\" mean?", correctAnswer: "dark and cloudy", distractors: ["clear and clean", "fast and cold", "shallow and warm"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🎁\n\"Grandpa is so frugal that he saves and reuses wrapping paper every year.\" What does \"frugal\" mean?", correctAnswer: "careful with money", distractors: ["very forgetful", "very loud", "very messy"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "🥅\n\"The fans were elated when their team scored the winning goal.\" What does \"elated\" mean?", correctAnswer: "very happy", distractors: ["very angry", "very quiet", "very worried"], tier: .easy, grades: 6...7),

        // ── 6th grade · connotation, punctuation, spelling ──
        BankQuestion(prompt: "💰\nWhich word describes someone who saves money in the most positive way?", correctAnswer: "thrifty", distractors: ["stingy", "cheap", "greedy"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🧐\nWhich word means \"curious\" but has a negative connotation?", correctAnswer: "nosy", distractors: ["interested", "inquisitive", "eager"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "📖\nA word's exact dictionary meaning is its ___.", correctAnswer: "denotation", distractors: ["connotation", "synonym", "prefix"], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "🐕\nWhich sentence uses commas correctly around extra information?", correctAnswer: "My dog, a golden retriever, loves to swim.", distractors: ["My dog a golden retriever, loves to swim.", "My dog, a golden retriever loves to swim.", "My, dog a golden retriever loves to swim."], tier: .medium, grades: 6...7),
        BankQuestion(prompt: "✏️\nWhich spelling is correct? (It means \"needed.\")", correctAnswer: "necessary", distractors: ["neccessary", "necesary", "neccesary"], tier: .hard, grades: 6...7),
        BankQuestion(prompt: "✂️\nWhich spelling is correct? (It means \"apart\" or \"not together.\")", correctAnswer: "separate", distractors: ["seperate", "separete", "seprate"], tier: .hard, grades: 6...7),

        // ── 7th grade · phrases and clauses ──
        BankQuestion(prompt: "🏟️\nWhat is \"after the game ended\"?", correctAnswer: "a dependent clause", distractors: ["an independent clause", "a prepositional phrase", "a complete sentence"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🌅\nWhat is \"in the morning\"?", correctAnswer: "a prepositional phrase", distractors: ["an independent clause", "a dependent clause", "a complete sentence"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🐕\nWhich group of words is an independent clause?", correctAnswer: "the dog barked loudly", distractors: ["because the dog barked", "when the dog barked", "barking at the mailman"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🌧️\nWhich group of words is a dependent clause?", correctAnswer: "although it was raining", distractors: ["it was raining", "the rain stopped", "we stayed inside"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🌉\nWhich group of words is a phrase, not a clause?", correctAnswer: "under the old bridge", distractors: ["the bridge creaked", "when the bridge creaked", "because it rained"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🥁\nIn \"Rosa, my best friend, plays drums,\" what is \"my best friend\"?", correctAnswer: "an appositive phrase", distractors: ["a dependent clause", "an independent clause", "a prepositional phrase"], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "🎹\nWhat is the verb phrase in \"She has been practicing piano\"?", correctAnswer: "has been practicing", distractors: ["She has", "been practicing piano", "practicing piano"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🔗\nWhich word is a subordinating conjunction?", correctAnswer: "although", distractors: ["and", "but", "or"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🔗\nWhich word is a coordinating conjunction?", correctAnswer: "yet", distractors: ["because", "since", "unless"], tier: .medium, grades: 7...8),

        // ── 7th grade · sentence types ──
        BankQuestion(prompt: "🏊\nWhat kind of sentence is this? \"I wanted to swim, but the pool was closed.\"", correctAnswer: "compound", distractors: ["simple", "complex", "compound-complex"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🛝\nWhat kind of sentence is this? \"Because the pool was closed, we went to the park.\"", correctAnswer: "complex", distractors: ["simple", "compound", "compound-complex"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🚴\nWhat kind of sentence is this? \"My cousin and I rode our bikes to the lake.\"", correctAnswer: "simple", distractors: ["compound", "complex", "compound-complex"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🔔\nWhat kind of sentence is this? \"When the bell rang, the students packed up, and the teacher waved goodbye.\"", correctAnswer: "compound-complex", distractors: ["simple", "compound", "complex"], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "⛈️\nWhich sentence is complex?", correctAnswer: "We stayed inside until the storm passed.", distractors: ["We stayed inside.", "We stayed inside, and we played cards.", "We stayed inside and played cards."], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "😴\nWhat is the best way to combine \"I was tired\" and \"I finished my homework\"?", correctAnswer: "Although I was tired, I finished my homework.", distractors: ["Because I was tired, I finished my homework.", "I was tired, I finished my homework.", "I was tired so, I finished my homework."], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "🎬\nWhich sentence is a comma splice?", correctAnswer: "The movie ended, we went home.", distractors: ["The movie ended, and we went home.", "When the movie ended, we went home.", "The movie ended; we went home."], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "📚\nWhich sentence uses a semicolon correctly?", correctAnswer: "I love to read; my brother loves to draw.", distractors: ["I love; to read and draw.", "Because I love to read; I go to the library.", "I love to read; and draw."], tier: .hard, grades: 7...8),

        // ── 7th grade · modifiers and commas ──
        BankQuestion(prompt: "🩳\nWhich sentence has a misplaced modifier?", correctAnswer: "I saw a dog running to the bus in my pajamas.", distractors: ["Running to the bus in my pajamas, I saw a dog.", "While I ran to the bus, I saw a dog.", "The dog ran past me."], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "👟\nWhich sentence fixes the dangling modifier in \"Walking to school, the rain soaked my shoes\"?", correctAnswer: "Walking to school, I got my shoes soaked by the rain.", distractors: ["Walking to school, the rain soaked my shoes and socks.", "The rain, walking to school, soaked my shoes.", "Walking to school, my shoes were soaked by the rain."], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "🍿\nWhich sentence uses a comma correctly between two adjectives?", correctAnswer: "It was a fascinating, enjoyable movie.", distractors: ["It was a fascinating enjoyable, movie.", "It was, a fascinating enjoyable movie.", "It, was a fascinating enjoyable movie."], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "✂️\nWhat is the most concise way to say \"due to the fact that\"?", correctAnswer: "because", distractors: ["although", "unless", "whenever"], tier: .easy, grades: 7...8),

        // ── 7th grade · connotation and word nuance ──
        BankQuestion(prompt: "🧱\nWhich word has the most negative connotation?", correctAnswer: "stubborn", distractors: ["determined", "persistent", "dedicated"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🏡\nWhich word describes a small house in the most positive way?", correctAnswer: "cozy", distractors: ["cramped", "tiny", "crowded"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🚗\nWhich word describes an old car in the most positive way?", correctAnswer: "classic", distractors: ["outdated", "rusty", "worn-out"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "😫\nWhich word is the strongest way to say \"very tired\"?", correctAnswer: "exhausted", distractors: ["sleepy", "drowsy", "relaxed"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🗣️\n\"Although the speech was lengthy, it was never tedious; everyone listened closely.\" What does \"tedious\" mean?", correctAnswer: "boring and tiresome", distractors: ["exciting", "short", "loud"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "😤\n\"The two friends had a heated dispute over whose turn it was.\" What does \"dispute\" mean?", correctAnswer: "argument", distractors: ["agreement", "game", "meal"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "👅\nWhich phrase uses alliteration?", correctAnswer: "silly snakes slither slowly", distractors: ["a happy yellow cat", "the tree in the yard", "we ran to school"], tier: .easy, grades: 7...8),

        // ── 7th grade · allusions and roots ──
        BankQuestion(prompt: "🦶\nIf someone calls a weakness their \"Achilles' heel,\" what do they mean?", correctAnswer: "a weak spot", distractors: ["a sore foot", "a great strength", "a fast runner"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "📦\n\"Doing that would be like opening Pandora's box.\" What does this mean?", correctAnswer: "It would cause many unexpected problems.", distractors: ["It would reveal a treasure.", "It would be a nice surprise.", "It would stay locked forever."], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "👑\nSomeone who has \"the Midas touch\" is ___.", correctAnswer: "successful at making money", distractors: ["clumsy with everything", "very gentle", "always cold"], tier: .hard, grades: 7...8),
        BankQuestion(prompt: "🎁\nThe Latin root \"bene\" (as in benefit) means ___.", correctAnswer: "good", distractors: ["bad", "many", "small"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "🔬\nThe Greek root \"logy\" (as in biology) means ___.", correctAnswer: "study of", distractors: ["fear of", "love of", "made of"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🔧\nThe Latin root \"mal\" (as in malfunction) means ___.", correctAnswer: "bad", distractors: ["good", "big", "many"], tier: .medium, grades: 7...8),
        BankQuestion(prompt: "🧩\nThe Latin root \"vis\" (as in vision) means ___.", correctAnswer: "see", distractors: ["hear", "say", "go"], tier: .easy, grades: 7...8),
        BankQuestion(prompt: "📘\nThe Greek root \"auto\" (as in autobiography) means ___.", correctAnswer: "self", distractors: ["car", "life", "many"], tier: .medium, grades: 7...8),

        // ── 8th grade · verbals ──
        BankQuestion(prompt: "🏊\nIn \"Swimming is my favorite sport,\" what is \"Swimming\"?", correctAnswer: "gerund", distractors: ["participle", "infinitive", "adverb"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "👶\nIn \"The crying baby finally fell asleep,\" what is \"crying\"?", correctAnswer: "participle", distractors: ["gerund", "infinitive", "adverb"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🇪🇸\nIn \"I want to learn Spanish,\" what is \"to learn\"?", correctAnswer: "infinitive", distractors: ["gerund", "participle", "adverb"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "🥾\nIn \"To be honest, I prefer hiking,\" what is \"hiking\"?", correctAnswer: "gerund", distractors: ["participle", "infinitive", "adjective"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🛏️\nWhich sentence uses a gerund?", correctAnswer: "Reading before bed helps me relax.", distractors: ["She was reading quietly.", "The girl reading the map is lost.", "I love to read."], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🏆\nWhich sentence uses an infinitive?", correctAnswer: "We hope to win the game.", distractors: ["Winning the game was fun.", "We went to the game.", "The winning team cheered."], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🪟\nWhich sentence uses a participle as an adjective?", correctAnswer: "The broken window let in cold air.", distractors: ["Breaking the window was an accident.", "I tried to fix the window.", "He broke the window."], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "📰\nIn \"Excited by the news, Maria called her friends,\" what is \"Excited by the news\"?", correctAnswer: "a participial phrase", distractors: ["an infinitive phrase", "a gerund phrase", "an independent clause"], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🏃\nIn \"Her goal is to finish the marathon,\" what is \"to finish the marathon\"?", correctAnswer: "an infinitive phrase", distractors: ["a participial phrase", "a gerund phrase", "a prepositional phrase"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "📣\nIn \"The team, cheering loudly, ran onto the field,\" what is \"cheering loudly\"?", correctAnswer: "a participial phrase", distractors: ["a gerund phrase", "an infinitive phrase", "a prepositional phrase"], tier: .hard, grades: 8...8),

        // ── 8th grade · active and passive voice ──
        BankQuestion(prompt: "🎂\nWhich sentence is in the passive voice?", correctAnswer: "The cake was baked by Dad.", distractors: ["Dad baked the cake.", "Dad is baking a cake.", "Dad will bake the cake."], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "📋\nWhich sentence is in the active voice?", correctAnswer: "The coach announced the lineup.", distractors: ["The lineup was announced by the coach.", "The lineup was announced.", "The lineup is being announced."], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "⚾\nChange to active voice: \"The ball was thrown by Ava.\"", correctAnswer: "Ava threw the ball.", distractors: ["The ball threw Ava.", "The ball was thrown.", "Ava was thrown the ball."], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🐈\nChange to passive voice: \"The dog chased the cat.\"", correctAnswer: "The cat was chased by the dog.", distractors: ["The dog was chased by the cat.", "The cat chased the dog.", "The dog is chasing the cat."], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "✍️\nWhy might a writer say \"Mistakes were made\" instead of \"I made mistakes\"?", correctAnswer: "to avoid saying who made them", distractors: ["to show it will happen later", "to turn it into a question", "to add more action"], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🎨\nWhich sentence avoids an awkward shift in voice?", correctAnswer: "Jen wrote the story and drew the pictures.", distractors: ["Jen wrote the story, and the pictures were drawn by her.", "The story was written by Jen, and she drew the pictures.", "The story was written, and Jen drew the pictures."], tier: .hard, grades: 8...8),

        // ── 8th grade · verb mood ──
        BankQuestion(prompt: "🚪\nWhat is the mood of the verb in \"Close the door, please\"?", correctAnswer: "imperative", distractors: ["indicative", "interrogative", "subjunctive"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "🐦\nWhat mood does \"were\" show in \"If I were a bird, I would fly\"?", correctAnswer: "subjunctive", distractors: ["imperative", "indicative", "interrogative"], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "📏\nWhich sentence uses the subjunctive mood correctly?", correctAnswer: "I wish I were taller.", distractors: ["I wish I am taller.", "I wish I is taller.", "I wish I will be taller."], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🏛️\nWhat is the mood of the verb in \"The museum opens at nine\"?", correctAnswer: "indicative", distractors: ["imperative", "subjunctive", "conditional"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🐠\nWhat is the mood of the verb in \"Did you feed the fish?\"", correctAnswer: "interrogative", distractors: ["imperative", "subjunctive", "conditional"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "⏰\nWhich sentence is in the conditional mood?", correctAnswer: "I would help if I had time.", distractors: ["Help me now.", "Do you have time?", "I have time today."], tier: .medium, grades: 8...8),

        // ── 8th grade · analogies ──
        BankQuestion(prompt: "🖐️\nFinger is to hand as toe is to ___.", correctAnswer: "foot", distractors: ["leg", "shoe", "sock"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "🌡️\nHot is to cold as tall is to ___.", correctAnswer: "short", distractors: ["big", "long", "high"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "🎼\nAuthor is to book as composer is to ___.", correctAnswer: "symphony", distractors: ["piano", "orchestra", "stage"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🐺\nBird is to flock as wolf is to ___.", correctAnswer: "pack", distractors: ["herd", "school", "den"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "📖\nPage is to book as petal is to ___.", correctAnswer: "flower", distractors: ["stem", "garden", "seed"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🩺\nHammer is to carpenter as stethoscope is to ___.", correctAnswer: "doctor", distractors: ["teacher", "chef", "pilot"], tier: .easy, grades: 8...8),
        BankQuestion(prompt: "🥚\nSeed is to plant as egg is to ___.", correctAnswer: "chick", distractors: ["nest", "shell", "yolk"], tier: .medium, grades: 8...8),

        // ── 8th grade · punctuation, irony, roots ──
        BankQuestion(prompt: "✂️\nWhat punctuation mark shows that words were left out of a quotation?", correctAnswer: "an ellipsis (...)", distractors: ["a semicolon (;)", "a colon (:)", "a hyphen (-)"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🐍\nWhich sentence uses dashes correctly to set off extra information?", correctAnswer: "My sister — the one who loves snakes — is visiting.", distractors: ["My sister the one who loves snakes — is visiting.", "My — sister the one who loves snakes is visiting.", "My sister the one — who loves snakes is visiting."], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🚒\nA fire station burns down. What kind of irony is this?", correctAnswer: "situational irony", distractors: ["verbal irony", "dramatic irony", "a simile"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "⛈️\nDuring a huge storm, Leo says, \"What lovely weather!\" This is an example of ___.", correctAnswer: "verbal irony", distractors: ["situational irony", "dramatic irony", "a simile"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🍞\nWhich sentence is a pun?", correctAnswer: "I used to be a baker, but I couldn't make enough dough.", distractors: ["I baked bread yesterday.", "The bread is as soft as a pillow.", "Baking is fun and easy."], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "🤯\nThe Latin root \"cred\" (as in incredible) means ___.", correctAnswer: "believe", distractors: ["break", "carry", "write"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "🧩\nThe Greek root \"path\" (as in empathy) means ___.", correctAnswer: "feeling", distractors: ["road", "light", "speed"], tier: .hard, grades: 8...8),
        BankQuestion(prompt: "📜\nThe Latin root \"voc\" (as in vocal) means ___.", correctAnswer: "voice", distractors: ["view", "move", "live"], tier: .medium, grades: 8...8),
        BankQuestion(prompt: "⏏️\nThe Latin root \"ject\" (as in eject) means ___.", correctAnswer: "throw", distractors: ["pull", "see", "hold"], tier: .medium, grades: 8...8),
    ]
}
