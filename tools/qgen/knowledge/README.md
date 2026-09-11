# Hand-written knowledge questions (science, history, geography, Hebrew…)

Computed topics (math, money, soccer, logic, English grammar) come from the
generators in `tools/qgen`. Knowledge topics can't be computed, so they are
written and then fact-checked by a *different* reviewer before anything reaches
the admin page — and even then they import as drafts that Rani approves.

1. **Write** — one writer per world × grade, following `SPEC.md` (format, full
   niqqud, settled facts only, one correct answer, the validation command).
   Large batches: write in parts of ~40 items (one part per output) and combine.
2. **Fact-check** — a separate reviewer follows `VERIFY.md`: keeps, fixes, or
   deletes each item and logs why. Doubtful facts are deleted, never "fixed".
   Give the reviewer the other grade's verified file so grades don't repeat.
3. **Merge** — `node tools/qgen/merge-knowledge.js <topic> <verified files…>`
   re-applies the server gate, drops collisions with built-in questions and
   duplicates, writes `docs/admin/generated/<topic>.json` and refreshes the index.
4. **Import** — admin → 🧠 תוכן ושאלות → ייבוא ואישור → 📦 → drafts → approve by grade.

Sept 2026 run (ז׳–ח׳): science 393, history 393, geography 386, Hebrew 389 —
the reviewers deleted ~3% and fixed ~6%, mostly repeats across grades, answers
longer than their distractors, and "rules" that textbooks or the Academy don't
actually enforce.
