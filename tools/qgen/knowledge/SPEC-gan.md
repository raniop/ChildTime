# Writing PICTURE questions for Tofy (טופי) — גן (ages 4–6, children who cannot read yet)

Tofy is an Israeli app where children earn screen time by answering questions. A גן child cannot read: the app READS THE QUESTION ALOUD and the child taps one of FOUR PICTURES (emoji). These are "thinking" questions — the child has to know or work out something about the world, not just find a named picture. A mother of a 5-year-old asked for exactly this ("מה מגן על המוח", "מה עושה הדם", "מה יקרה לקרח בשמש"). They import as DRAFTS that the founder reviews, but a wrong fact reaching a child is real harm: treat every item as if it ships.

## Output format
A single JSON array written to the output path you are given. Each item:

```json
{"prompt": "🔬\nמָה נִהְיֶה מִמַּיִם שֶׁשָּׂמִים בַּמַּקְפִּיא?", "correctAnswer": "🧊", "distractors": ["🔥", "🌈", "🍃"], "tier": "easy", "gradeLo": 0, "gradeHi": 0}
```

- `prompt`: ONE neutral emoji for the subject, a newline (`\n`), then the question in Hebrew. The emoji must NOT be the answer or hint at it, and must not be one of the options.
- `correctAnswer` and each of the 3 `distractors`: exactly ONE emoji — a clear picture of a THING a small child recognises at a glance on a small tile.
- `tier`: "easy" (about 70%) or "medium" (about 30%). No "hard".
- `gradeLo` = `gradeHi` = 0.

## Hard rules
1. **The question is heard, not read.** One short, natural spoken sentence — at most 14 words, everyday words a 5-year-old knows, no numbers written as digits, no Latin letters. Start with a question word (מָה, אֵיזֶה, אֵיזוֹ, אֵיפֹה, מִי, בְּמָה…).
2. **Full, correct niqqud (ניקוד) on every Hebrew word**, like a vowelled children's book — dagesh, shva, ה׳ הידיעה merging after ב/ל/כ (בַּ, לַ, כַּ), ו׳ החיבור (וּ before ב/מ/פ and before shva, וְ otherwise). If you are not sure how to vowel a word, choose another word.
3. **Pictures only.** Every option is ONE emoji: no pairs, no arrows, no ✅/❌/❓, no signs or symbols, no text, no flags, no skin-tone or joined (ZWJ) emoji, and nothing added to Unicode after 2019 — so NOT 🪨 🪵 🪶 🫀 🫁 🫧 🫚 🫥 🪴 🪲 🦭 🦬 🪸. Coloured circles (🔴 🟠 🟡 🟢 🔵 🟣) are fine for colour questions.
4. **Exactly one correct picture.** The three others must be clearly wrong to an adult — and of the same kind where possible (animals with animals, foods with foods), so the child has to think. Never two pictures that could both be right (e.g. ☀️ and ⭐ for "what gives light" — the sun is a star; 🐟 and 🐸 for "lives in water").
5. **Only settled, concrete facts a kindergarten teacher would teach.** Things the child can see, touch or has heard at גן. Nothing that depends on country, culture, religion or opinion; nothing frightening (no blood, injury, death, skulls, weapons, fire accidents).
6. **No duplicates and no near-duplicates** — the same fact asked in other words counts. You will be given a file of items that already exist: do not repeat any fact in it.
7. Gender-neutral wording (אֲנַחְנוּ, plural), warm and simple.

## Validate before you finish
Run this from `/Users/raniophir/ChildTime`, fix everything it reports, and run again until it prints `0 with problems`:

```bash
node tools/qgen/knowledge/check-gan.js OUTPUT_PATH [EXISTING_FILES…]
```

Then read every item once more as a strict kindergarten teacher: is the answer definitely right, is exactly one picture right, would a 5-year-old understand the sentence when it is read aloud, is the niqqud right? Fix or delete anything doubtful — fewer sure items beat more with doubts.

## Report back (short)
The item count, the easy/medium split, how many you deleted or rewrote in the final re-read, and any sub-topic you kept thin on purpose.
