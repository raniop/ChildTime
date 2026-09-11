import Foundation

/// 🎵 Music — English (US). Adapted from QuestionBanksMusic (Hebrew).
/// Instruments and their families, notes, rhythm and tempo, the orchestra,
/// one-line composer facts, and well-known public-domain children's songs
/// (titles and subjects only — never lyrics).
extension EnglishContent {
    static let music: [BankQuestion] = [
        // ── Easy · instruments and how to play them ──
        BankQuestion(prompt: "🎸\nHow many strings does a regular guitar have?", correctAnswer: "6", distractors: ["4", "5", "8"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎻\nHow many strings does a violin have?", correctAnswer: "4", distractors: ["3", "5", "6"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎹\nWhat two colors are the keys on a piano?", correctAnswer: "Black and white", distractors: ["Red and blue", "Green and yellow", "Orange and purple"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥁\nHow do you play drums?", correctAnswer: "You hit them", distractors: ["You blow into them", "You strum them", "You spin them"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎸\nHow do you play a guitar?", correctAnswer: "You strum the strings", distractors: ["You blow into it", "You hit it with sticks", "You press keys"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎻\nWhat do you pull across the strings of a violin to play it?", correctAnswer: "A bow", distractors: ["A hammer", "A drumstick", "A spoon"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎹\nOn which instrument do you press keys?", correctAnswer: "Piano", distractors: ["Drum", "Violin", "Guitar"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪈\nWhich instrument do you blow into?", correctAnswer: "Flute", distractors: ["Drum", "Guitar", "Piano"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🥁\nWhich instrument is a percussion instrument?", correctAnswer: "Drum", distractors: ["Violin", "Flute", "Guitar"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎻\nWhich instrument is a string instrument?", correctAnswer: "Violin", distractors: ["Drum", "Trumpet", "Cymbals"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🪘\nHow do you play bongo drums?", correctAnswer: "You tap them with your hands", distractors: ["You blow into them", "You pull a bow across them", "You press keys"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪈\nWhich small wind instrument do many kids learn to play at school?", correctAnswer: "Recorder", distractors: ["Tuba", "Piano", "Double bass"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎤\nWhat helps a singer sound louder?", correctAnswer: "A microphone", distractors: ["Glasses", "A hat", "A wand"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎹\nWhat do we call a person who plays the piano?", correctAnswer: "Pianist", distractors: ["Florist", "Dentist", "Cyclist"], tier: .easy, grades: 1...2),

        // ── Easy · notes, rhythm and sounds ──
        BankQuestion(prompt: "🎵\nHow many notes are in the scale do, re, mi, fa, sol, la, ti?", correctAnswer: "7", distractors: ["5", "8", "10"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🎵\nWhat is the first note of the scale?", correctAnswer: "Do", distractors: ["Re", "Sol", "Ti"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎵\nWhich note comes right after \"do\"?", correctAnswer: "Re", distractors: ["Mi", "Fa", "La"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎼\nWhat do we call the symbols we use to write music?", correctAnswer: "Notes", distractors: ["Letters", "Numbers", "Commas"], tier: .easy, grades: 1...2),
        BankQuestion(prompt: "🔉\nWhat is the opposite of loud music?", correctAnswer: "Quiet music", distractors: ["Fast music", "Long music", "Happy music"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐇\nWhat is the opposite of slow music?", correctAnswer: "Fast music", distractors: ["Loud music", "Quiet music", "Sad music"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎵\nWhat is the opposite of a high sound?", correctAnswer: "A low sound", distractors: ["A loud sound", "A fast sound", "A long sound"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐦\nWhich sound is the highest?", correctAnswer: "A bird's tweet", distractors: ["A cow's moo", "A lion's roar", "A tuba's note"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "👏\nWhen you clap along with music, what do you clap to?", correctAnswer: "The beat", distractors: ["The color", "The smell", "The taste"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "👏\nWe clapped 2 times, then 2 more times. How many claps in all?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 0...1),

        // ── Easy · choir, orchestra and songs ──
        BankQuestion(prompt: "🎤\nWhat do we call a group of people who sing together?", correctAnswer: "Choir", distractors: ["Orchestra", "Dance team", "Soccer team"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎼\nWhat do we call a big group of musicians who play instruments together?", correctAnswer: "Orchestra", distractors: ["Choir", "Class", "Family"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🪄\nWho stands in front of the orchestra and shows the players when and how to play?", correctAnswer: "The conductor", distractors: ["The referee", "The driver", "The painter"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🌙\nWhat do we call a song you sing to help a baby fall asleep?", correctAnswer: "Lullaby", distractors: ["Anthem", "March", "Birthday song"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🐄\nWhich song is about a farmer and the animals on his farm?", correctAnswer: "Old MacDonald Had a Farm", distractors: ["Twinkle, Twinkle, Little Star", "Row, Row, Row Your Boat", "Rock-a-bye Baby"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "⛵\nWhat is the song \"Row, Row, Row Your Boat\" about?", correctAnswer: "A boat", distractors: ["A train", "A bike", "A kite"], tier: .easy, grades: 0...2),
        BankQuestion(prompt: "🎂\nWhich song do we sing when the candles are lit on a birthday cake?", correctAnswer: "Happy Birthday to You", distractors: ["Twinkle, Twinkle, Little Star", "Row, Row, Row Your Boat", "The Star-Spangled Banner"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌟\nWhich song is about a little star in the sky?", correctAnswer: "Twinkle, Twinkle, Little Star", distractors: ["Old MacDonald Had a Farm", "Row, Row, Row Your Boat", "Baa, Baa, Black Sheep"], tier: .easy, grades: 0...2),

        // ── Medium · instrument families ──
        BankQuestion(prompt: "🎸\nWhich family does the guitar belong to?", correctAnswer: "String instruments", distractors: ["Wind instruments", "Percussion instruments", "Keyboard instruments"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎺\nWhich family does the trumpet belong to?", correctAnswer: "Brass instruments", distractors: ["String instruments", "Percussion instruments", "Keyboard instruments"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🥁\nWhich family do drums belong to?", correctAnswer: "Percussion instruments", distractors: ["String instruments", "Brass instruments", "Woodwind instruments"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎷\nWhich family does the saxophone belong to?", correctAnswer: "Woodwind instruments", distractors: ["String instruments", "Percussion instruments", "Keyboard instruments"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎹\nThe organ and the synthesizer both have keys. Which family do they belong to?", correctAnswer: "Keyboard instruments", distractors: ["String instruments", "Brass instruments", "Percussion instruments"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔔\nCymbals are two round metal plates. How do you play them?", correctAnswer: "Crash them together", distractors: ["Blow into them", "Strum them", "Press keys"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎻\nWhich instrument looks like a violin but is bigger, and you play it sitting down?", correctAnswer: "Cello", distractors: ["Flute", "Tuba", "Harp"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎻\nWhich of these instruments makes the lowest sounds?", correctAnswer: "Double bass", distractors: ["Violin", "Recorder", "Piccolo"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎺\nThe tuba is a very big brass instrument. What kind of sounds does it make?", correctAnswer: "Low sounds", distractors: ["Very high sounds", "Sharp, whistling sounds", "Tiny bell sounds"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎶\nWhich big, triangle-shaped string instrument do you pluck with your fingers?", correctAnswer: "Harp", distractors: ["Violin", "Tuba", "Accordion"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🪗\nWhich instrument do you squeeze and stretch with your hands, and it also has keys?", correctAnswer: "Accordion", distractors: ["Piano", "Flute", "Drum"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎸\nHow many strings does a bass guitar usually have?", correctAnswer: "4", distractors: ["2", "6", "8"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎹\nThe black keys on a piano are arranged in groups of…", correctAnswer: "2 and 3", distractors: ["1 and 4", "4 and 5", "3 and 6"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🥁\nIn a band, which instrument usually keeps the beat?", correctAnswer: "Drums", distractors: ["Flute", "Violin", "Microphone"], tier: .medium, grades: 1...3),

        // ── Medium · notes, rhythm and music words ──
        BankQuestion(prompt: "🎵\nWhich note comes right after \"mi\"?", correctAnswer: "Fa", distractors: ["Re", "Sol", "Ti"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎵\nWhich note comes right before \"sol\"?", correctAnswer: "Fa", distractors: ["Mi", "La", "Do"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎵\nWhich note comes right after \"la\"?", correctAnswer: "Ti", distractors: ["Sol", "Fa", "Re"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎹\nMusic notes are named with the letters A to G. After G, which letter comes next?", correctAnswer: "A", distractors: ["H", "B", "C"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎼\nHow many lines does a music staff have?", correctAnswer: "5", distractors: ["3", "4", "7"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "⏩\nWhat do we call how fast or slow music is played?", correctAnswer: "Tempo", distractors: ["Melody", "Harmony", "Scale"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎶\nWhat do we call the tune of a song, the part you can hum?", correctAnswer: "Melody", distractors: ["Tempo", "Rhythm", "Solo"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🔢\nIn a song you count 1-2-3-4, 1-2-3-4. How many beats are in each measure?", correctAnswer: "4", distractors: ["2", "3", "8"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🎶\nWhat do we call the part of a song that comes back again and again with the same words?", correctAnswer: "Chorus", distractors: ["Verse", "Note", "Tempo"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "🩰\nWhich kind of dance is done up on the tips of the toes, often in a tutu?", correctAnswer: "Ballet", distractors: ["Hip-hop", "Tap dance", "Square dance"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🤠\nIn square dancing, how many couples usually make one square?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .medium, grades: 2...4),

        // ── Medium · composers and songs ──
        BankQuestion(prompt: "✍️\nWhat does a composer do?", correctAnswer: "Writes new music", distractors: ["Fixes instruments", "Sells tickets", "Takes photos at concerts"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎼\nBach, Mozart, and Beethoven were famous…", correctAnswer: "Composers", distractors: ["Painters", "Soccer players", "Chefs"], tier: .medium, grades: 2...4),
        BankQuestion(prompt: "👂\nWhich famous composer kept writing wonderful music even when he could barely hear?", correctAnswer: "Beethoven", distractors: ["Mozart", "Bach", "Vivaldi"], tier: .medium, grades: 3...4),
        BankQuestion(prompt: "🇺🇸\nWhat is the national anthem of the United States called?", correctAnswer: "The Star-Spangled Banner", distractors: ["America the Beautiful", "Yankee Doodle", "Happy Birthday to You"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎺\nWhich American composer was called \"The March King\" and wrote \"The Stars and Stripes Forever\"?", correctAnswer: "John Philip Sousa", distractors: ["Mozart", "Beethoven", "Bach"], tier: .medium, grades: 3...4),

        // ── Hard · music words and composers ──
        BankQuestion(prompt: "🎹\nHow many keys does a standard piano have?", correctAnswer: "88", distractors: ["50", "100", "120"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🔊\nIn music, what does the word \"forte\" mean?", correctAnswer: "Play loudly", distractors: ["Play softly", "Play fast", "Play slowly"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "📈\nWhat does \"crescendo\" mean?", correctAnswer: "The music gets louder and louder", distractors: ["The music gets softer and softer", "The music stops", "The music starts over"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "💃\nIn a waltz, what number do you count to in each measure?", correctAnswer: "3", distractors: ["2", "4", "5"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🎼\nWhat is the curly symbol at the start of the staff for high notes called?", correctAnswer: "Treble clef", distractors: ["Exclamation point", "Scale", "Beat"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🔁\nWhat is a round in music?", correctAnswer: "A song where each group starts the same tune a little later", distractors: ["A song with no words", "A very long song", "A song you sing in a whisper"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🎼\nIn which country was the composer Mozart born?", correctAnswer: "Austria", distractors: ["United States", "Japan", "Brazil"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "👶\nMozart was a child prodigy. About how old was he when he started writing music?", correctAnswer: "5", distractors: ["15", "20", "30"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🍂\nWho composed \"The Four Seasons\"?", correctAnswer: "Vivaldi", distractors: ["Mozart", "Beethoven", "Bach"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🎹\nWhich country was the composer Bach from?", correctAnswer: "Germany", distractors: ["Italy", "Spain", "Russia"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🎹\nWhich composer wrote the famous piano piece \"Für Elise\"?", correctAnswer: "Beethoven", distractors: ["Mozart", "Vivaldi", "Sousa"], tier: .hard, grades: 3...4),
        BankQuestion(prompt: "🩰\nWho composed the music for the ballet \"The Nutcracker\"?", correctAnswer: "Tchaikovsky", distractors: ["Mozart", "Bach", "Sousa"], tier: .hard, grades: 3...4),
    ]
}
