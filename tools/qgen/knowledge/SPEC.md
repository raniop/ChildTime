# Writing questions for Tofy (טופי) — ז׳–ח׳ knowledge worlds

Tofy is an Israeli iOS app where children earn screen time by answering multiple-choice questions in Hebrew. These questions are for middle-school children (כיתה ז׳ ≈ age 12–13, כיתה ח׳ ≈ 13–14), aligned to the Israeli Ministry of Education (משרד החינוך) curriculum. They will be imported as DRAFTS and reviewed by the founder before any child sees them — but a wrong fact reaching a child is real harm, so treat every item as if it ships.

## Output format
A single JSON array written to the output path you are given. Each item:

```json
{"prompt": "🔬\nמָה הַיְּחִידָה הַקְּטַנָּה בְּיוֹתֵר שֶׁל חֹמֶר חַי?", "correctAnswer": "תָּא", "distractors": ["אֶבֶר", "רִקְמָה", "מוֹלֶקוּלָה"], "tier": "easy", "gradeLo": 7, "gradeHi": 7}
```

- `prompt`: an emoji that fits the subject, a newline (`\n`), then the question. ≤ 260 characters.
- `correctAnswer`: short (1–6 words ideally).
- `distractors`: exactly 3, all different, none equal to the answer.
- `tier`: "easy" | "medium" | "hard" — roughly 30% / 45% / 25%.
- `gradeLo` = `gradeHi` = the grade you were given.

## Hard rules
1. **Full niqqud (ניקוד) on every Hebrew word** in the prompt AND the answers, like a vowelled children's book. Correct niqqud — dagesh, shva, kamatz katan, ה׳ הידיעה merging after ב/ל/כ (בַּ, לַ, כַּ), ו׳ החיבור forms (וּ before ב/מ/פ and before shva, וְ otherwise). If you are unsure how to vowel a word, choose a different word you are sure of. Numbers and Latin (H₂O, DNA, pH) stay as they are.
2. **Only settled textbook facts.** No figures that change (populations, records, prices, "today", "the newest"), no disputed or politically charged claims, no rounding traps. Dates only where the curriculum teaches them and they are undisputed.
3. **Exactly one correct answer.** Distractors must be clearly wrong to someone who knows the material, yet plausible to someone who doesn't — same type and length as the answer (a city vs cities, a date vs dates). Never "כָּל הַתְּשׁוּבוֹת נְכוֹנוֹת" / "אַף אַחַת", never an answer that is partly right.
4. **Gender-neutral, child-appropriate wording**; plural imperative (בַּחֲרוּ, הַשְׁלִימוּ) where an instruction is needed.
5. **No duplicates** and no near-duplicates (the same fact asked twice with different words counts as a duplicate). Spread evenly over the sub-topics you were given.
6. Middle-school level — not the trivial questions of כיתה ג׳, not university.

## Style samples (existing Tofy items, lower grades)
- `🌊\nמָהוּ הָאוֹקְיָינוֹס הַגָּדוֹל בְּיוֹתֵר בָּעוֹלָם?` → `הָאוֹקְיָינוֹס הַשָּׁקֵט` ✗ `הָאוֹקְיָינוֹס הָאַטְלַנְטִי`, `הָאוֹקְיָינוֹס הַהוֹדִי`, `אוֹקְיָינוֹס הַקֶּרַח`
- `מָה פֵּרוּשׁ הַפִּתְגָּם 'סוֹף מַעֲשֶׂה בְּמַחְשָׁבָה תְּחִלָּה'?` → `כְּדַאי לְתַכְנֵן לִפְנֵי שֶׁעוֹשִׂים` ✗ `הַמַּחְשָׁבָה מַגִּיעָה תָּמִיד בַּסּוֹף`, `כָּל מַעֲשֶׂה נִגְמָר בְּמַחְשָׁבָה`, `עֲשֵׂה קֹדֶם וְתַחְשֹׁב אַחַר כָּךְ`
- `בְּאֵיזֶה בִּנְיָן הַפֹּעַל 'שָׁמַר'?` → `פָּעַל` ✗ `פִּעֵל`, `הִפְעִיל`, `נִפְעַל`

## Validate before you finish
Run this from `/Users/raniophir/ChildTime` (it applies the server's own quality gate and a few extra checks), fix everything it reports, and run it again until it is clean:

```bash
node -e '
const { qbProblems } = require("./tools/qgen/core");
const f = process.argv[1], items = JSON.parse(require("fs").readFileSync(f, "utf8"));
const seen = new Set(); let bad = 0;
for (const [i, q] of items.entries()) {
  const p = qbProblems(q);
  const hebNoNiqqud = [q.correctAnswer, ...(q.distractors || [])].filter((x) => /[א-ת]{3,}/.test(x) && !/[ְ-ׇ]/.test(x));
  if (hebNoNiqqud.length) p.push("answer without niqqud: " + hebNoNiqqud.join(" / "));
  const key = q.prompt.replace(/[ְ-ׇ]/g, "").replace(/\s+/g, " ").trim();
  if (seen.has(key)) p.push("duplicate prompt"); seen.add(key);
  if (p.length) { bad++; console.log(i, p.join("; "), "|", q.prompt.slice(0, 60)); }
}
console.log(items.length, "items,", bad, "with problems");
' OUTPUT_PATH
```

Then re-read every item once more as a strict teacher: is the answer definitely right, is exactly one option right, is the niqqud right? Fix or delete anything doubtful — 200 sure items beat 230 with doubts. Aim for 200 items.

## Report back (short)
The item count, the tier split, how many items you deleted or rewrote in your final re-read, and any sub-topic you deliberately kept thin because facts were too uncertain.
