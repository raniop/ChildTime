# Fact-checking a batch of Tofy questions

You are the second pair of eyes on a batch of Hebrew multiple-choice questions written by someone else for middle-school children (כיתה ז׳–ח׳) in the Tofy app. The writer followed `SPEC.md` in this folder — read it first so you know the rules. Your job is to be the strict teacher who catches what the writer missed. Assume nothing is right until you have checked it.

## For every item, check
1. **The answer is correct** — a settled textbook fact, true as phrased (watch for "הַגָּדוֹל בְּיוֹתֵר" / "הָרִאשׁוֹן" / dates / numbers / who-did-what).
2. **Exactly one option is correct.** A distractor that is also true, partly true, or true under a common alternative definition makes the item broken.
3. **The question is unambiguous** and at the right level; no trick wording.
4. **Hebrew**: grammar, gender/number agreement, and **niqqud** on prompt and options. Fix clear niqqud mistakes (e.g. a missing dagesh after ה׳ הידיעה merge, wrong vowel under a common word). Language questions (שורש, בניין, גזרה, תחביר) — verify the linguistic claim itself very carefully.
5. **Content rules**: nothing that changes over time, nothing politically contested, respectful wording.
6. **Duplicates**: the same fact asked twice — keep the better one.

## What to do
- If an item is right: keep it unchanged.
- If it has a fixable problem (a niqqud slip, a weak distractor, awkward wording, a second-correct distractor you can replace with a clearly wrong one): fix it.
- If the fact itself is wrong or doubtful, or you cannot be sure: **delete it**. Do not "correct" a fact you are not sure of.

Write the result as a JSON array (same item format) to the VERIFIED output path you are given, and write a short log to the LOG output path: one line per changed or deleted item — `DELETED | <prompt start> | <reason>` or `FIXED | <prompt start> | <what>`.

Then run the validation command from `SPEC.md` on the verified file and make sure it is clean.

## Report back (short)
Kept unchanged / fixed / deleted counts, and the 3–5 most serious problems you found (so the founder knows what kind of errors the writer made).
