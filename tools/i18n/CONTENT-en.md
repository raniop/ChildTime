# Tofy — English (US) question content

English questions are **not** a word-for-word translation of the Hebrew banks.
They are the same learning goals rewritten for a child in the United States.

## Output format
One Swift file per topic under `ChildTime/Models/EnglishContent/`, named
`EnglishBank<Topic>.swift`:

```swift
import Foundation

/// 🐾 Animals — English (US). Adapted from QuestionBanksAnimals (Hebrew).
extension EnglishContent {
    static let animals: [BankQuestion] = [
        BankQuestion(prompt: "🐄\nWhich animal says \"moo\"?", correctAnswer: "Cow", distractors: ["Dog", "Cat", "Rooster"], tier: .easy, grades: 0...1),
    ]
}
```

- `prompt`: an emoji, `\n`, then the question — the same shape as the Hebrew banks.
  Escape inner quotes (`\"`). No niqqud, no Hebrew anywhere.
- `correctAnswer` + exactly 3 `distractors`, all different from each other and from
  the answer (case-insensitive), all the same kind of thing (four animals, four numbers…).
- `tier`: `.easy` / `.medium` / `.hard` — ALWAYS set.
- `grades`: `lo...hi` on Tofy's scale **0 = Kindergarten, 1 = 1st grade … 8 = 8th grade**.
  Israeli and US grades line up (גן חובה = K, א׳ = 1st …); keep the source window
  unless US curriculum clearly puts the idea elsewhere.

## Adapting
- Keep everything universal (animals, space, the human body, physics, logic…).
- Replace Israel-specific items with a US or world equivalent that teaches the same
  thing (a US state, a US coin, a US landmark) — or drop the item. Never keep a
  question that only makes sense in Israel (Israeli cities, holidays, shekels,
  Israeli teams/players, the Hebrew language).
- Money is in dollars and cents; measurements may use US customary units where a
  US child meets them (inches, feet, °F) — metric stays fine in science.
- Spelling and vocabulary: American English ("color", "soccer").
- Kid voice: short, warm, clear; a 1st-grade prompt must be readable by a 1st grader
  (it is also read aloud). Never gory, scary or shaming.

## Correctness (non-negotiable)
- Timeless, verifiable facts only. No "current" records, rosters, champions or
  prices that change. If you are not certain an item is true and has exactly one
  defensible answer, drop it.
- Distractors must be clearly wrong to an adult who knows the subject.
- No trick wording, no "all of the above", no negatives unless the grade can handle it.

## Quantity
Translate/adapt every usable source item; aim to keep at least 80% of the source
count, and add new US-relevant items to replace what you dropped.
