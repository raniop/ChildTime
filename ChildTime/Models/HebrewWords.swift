import Foundation

struct HebrewWord: Equatable, Hashable {
    let text: String
    let emoji: String
}

enum HebrewWords {
    static let grade1: [HebrewWord] = [
        HebrewWord(text: "אבא",      emoji: "👨"),
        HebrewWord(text: "אמא",      emoji: "👩"),
        HebrewWord(text: "ילד",      emoji: "👦"),
        HebrewWord(text: "ילדה",     emoji: "👧"),
        HebrewWord(text: "בית",      emoji: "🏠"),
        HebrewWord(text: "ספר",      emoji: "📖"),
        HebrewWord(text: "יום",      emoji: "🌞"),
        HebrewWord(text: "לילה",     emoji: "🌙"),
        HebrewWord(text: "שמש",      emoji: "☀️"),
        HebrewWord(text: "ירח",      emoji: "🌙"),
        HebrewWord(text: "מים",      emoji: "💧"),
        HebrewWord(text: "אש",       emoji: "🔥"),
        HebrewWord(text: "ים",       emoji: "🌊"),
        HebrewWord(text: "חתול",     emoji: "🐈"),
        HebrewWord(text: "כלב",      emoji: "🐕"),
        HebrewWord(text: "פיל",      emoji: "🐘"),
        HebrewWord(text: "אריה",     emoji: "🦁"),
        HebrewWord(text: "דב",       emoji: "🐻"),
        HebrewWord(text: "ציפור",    emoji: "🐦"),
        HebrewWord(text: "דג",       emoji: "🐟"),
        HebrewWord(text: "פרח",      emoji: "🌸"),
        HebrewWord(text: "עץ",       emoji: "🌳"),
        HebrewWord(text: "עלה",      emoji: "🍃"),
        HebrewWord(text: "כוכב",     emoji: "⭐"),
        HebrewWord(text: "ענן",      emoji: "☁️"),
        HebrewWord(text: "גשם",      emoji: "🌧️"),
        HebrewWord(text: "שלג",      emoji: "❄️"),
        HebrewWord(text: "סוס",      emoji: "🐴"),
        HebrewWord(text: "פרה",      emoji: "🐄"),
        HebrewWord(text: "ביצה",     emoji: "🥚"),
        HebrewWord(text: "חלב",      emoji: "🥛"),
        HebrewWord(text: "לחם",      emoji: "🍞"),
        HebrewWord(text: "תפוח",     emoji: "🍎"),
        HebrewWord(text: "בננה",     emoji: "🍌"),
        HebrewWord(text: "ענב",      emoji: "🍇"),
        HebrewWord(text: "תות",      emoji: "🍓"),
        HebrewWord(text: "גזר",      emoji: "🥕"),
        HebrewWord(text: "סבא",      emoji: "👴"),
        HebrewWord(text: "סבתא",     emoji: "👵"),
        HebrewWord(text: "אח",       emoji: "👬"),
        HebrewWord(text: "אחות",     emoji: "👭"),
        HebrewWord(text: "כדור",     emoji: "⚽"),
        HebrewWord(text: "אופניים",  emoji: "🚲"),
        HebrewWord(text: "אוטו",     emoji: "🚗")
    ]

    static let grade2: [HebrewWord] = [
        HebrewWord(text: "מורה",     emoji: "🧑‍🏫"),
        HebrewWord(text: "תלמיד",    emoji: "🎒"),
        HebrewWord(text: "כיתה",     emoji: "🏫"),
        HebrewWord(text: "לוח",      emoji: "📋"),
        HebrewWord(text: "מחברת",    emoji: "📓"),
        HebrewWord(text: "עפרון",    emoji: "✏️"),
        HebrewWord(text: "מחק",      emoji: "🧽"),
        HebrewWord(text: "תיק",      emoji: "🎒"),
        HebrewWord(text: "מטבח",     emoji: "🍳"),
        HebrewWord(text: "חדר",      emoji: "🛏️"),
        HebrewWord(text: "מיטה",     emoji: "🛏️"),
        HebrewWord(text: "כיסא",     emoji: "🪑"),
        HebrewWord(text: "שולחן",    emoji: "🍽️"),
        HebrewWord(text: "חלון",     emoji: "🪟"),
        HebrewWord(text: "דלת",      emoji: "🚪"),
        HebrewWord(text: "מכונית",   emoji: "🚗"),
        HebrewWord(text: "אוטובוס",  emoji: "🚌"),
        HebrewWord(text: "רכבת",     emoji: "🚆"),
        HebrewWord(text: "מטוס",     emoji: "✈️"),
        HebrewWord(text: "אוניה",    emoji: "🚢"),
        HebrewWord(text: "אופנוע",   emoji: "🏍️"),
        HebrewWord(text: "רופא",     emoji: "🧑‍⚕️"),
        HebrewWord(text: "שוטר",     emoji: "👮"),
        HebrewWord(text: "כבאי",     emoji: "🧑‍🚒"),
        HebrewWord(text: "טייס",     emoji: "🧑‍✈️"),
        HebrewWord(text: "אופה",     emoji: "🧑‍🍳"),
        HebrewWord(text: "מחשב",     emoji: "💻"),
        HebrewWord(text: "טלפון",    emoji: "📱"),
        HebrewWord(text: "טלוויזיה", emoji: "📺"),
        HebrewWord(text: "מקרר",     emoji: "🧊"),
        HebrewWord(text: "מקלחת",    emoji: "🚿"),
        HebrewWord(text: "חורף",     emoji: "🧣"),
        HebrewWord(text: "אביב",     emoji: "🌷"),
        HebrewWord(text: "קיץ",      emoji: "🌞"),
        HebrewWord(text: "סתיו",     emoji: "🍂"),
        HebrewWord(text: "מעיל",     emoji: "🧥"),
        HebrewWord(text: "כובע",     emoji: "🧢"),
        HebrewWord(text: "נעליים",   emoji: "👟"),
        HebrewWord(text: "פיצה",     emoji: "🍕"),
        HebrewWord(text: "גלידה",    emoji: "🍦"),
        HebrewWord(text: "עוגה",     emoji: "🍰"),
        HebrewWord(text: "סוכריה",   emoji: "🍬"),
        HebrewWord(text: "שוקולד",   emoji: "🍫"),
        HebrewWord(text: "מרק",      emoji: "🍲"),
        HebrewWord(text: "סלט",      emoji: "🥗")
    ]

    static let alphabet: [Character] = Array("אבגדהוזחטיכלמנסעפצקרשת")
    static let finalLetters: [Character: Character] = ["כ": "ך", "מ": "ם", "נ": "ן", "פ": "ף", "צ": "ץ"]

    /// All known valid Hebrew words across grades, for ambiguity detection in spelling questions.
    static let dictionary: Set<String> = {
        var set = Set<String>()
        for w in grade1 + grade2 {
            set.insert(w.text)
            set.insert(normalizeFinals(w.text))
        }
        return set
    }()

    /// Replace final-form letters with their regular forms (used for dictionary lookups).
    static func normalizeFinals(_ s: String) -> String {
        var result = ""
        for ch in s {
            let reverse = finalLetters.first { $0.value == ch }?.key
            result.append(reverse ?? ch)
        }
        return result
    }
}
