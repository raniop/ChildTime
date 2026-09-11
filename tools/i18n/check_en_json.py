#!/usr/bin/env python3
"""Mechanical checks for an English cloud question batch (JSON array).

    tools/i18n/check_en_json.py docs/admin/generated/en/animals-w1-part1.json…

Mirrors the server's qbProblems for lang "en" plus the content rules in
CONTENT-en.md: emoji line, no Hebrew, 3 distinct distractors that differ from the
answer, tier set, grades 0..8, prompt ≤ 260 chars, no duplicate prompts — also
against the built-in English bank for the same topic.
"""
import json, os, re, sys

HEB = re.compile(r"[֐-׿]")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BANK_PROMPT = re.compile(r'BankQuestion\(prompt: "((?:[^"\\]|\\.)*)"')


def builtin_prompts(topic):
    """Prompts of EVERY built-in English bank — the same question can sit in two
    worlds (a science fact inside Body), and a child plays both."""
    folder = os.path.join(ROOT, "ChildTime", "Models", "EnglishContent")
    out = set()
    for name in os.listdir(folder) if os.path.isdir(folder) else []:
        if name.startswith("EnglishBank") and name.endswith(".swift"):
            text = open(os.path.join(folder, name), encoding="utf-8").read()
            out |= {p.replace('\\n', '\n').replace('\\"', '"').strip().lower() for p in BANK_PROMPT.findall(text)}
    return out


def check(path):
    topic = os.path.basename(path).split("-")[0]
    items = json.load(open(path, encoding="utf-8"))
    known = builtin_prompts(topic)
    problems, seen = [], set()
    if not isinstance(items, list):
        print(f"{path}: not a JSON array"); return False
    for q in items:
        p = str(q.get("prompt", "")); a = str(q.get("correctAnswer", "")).strip()
        ds = [str(d).strip() for d in q.get("distractors", [])]
        where = p[:60].replace("\n", " ")
        if HEB.search(json.dumps(q, ensure_ascii=False)): problems.append(f"Hebrew: {where}")
        if "\n" not in p: problems.append(f"no emoji line: {where}")
        if len(p) > 260: problems.append(f"prompt > 260 chars: {where}")
        if len(ds) != 3: problems.append(f"{len(ds)} distractors: {where}")
        opts = [a] + ds
        if len({o.lower() for o in opts}) != len(opts) or any(not o for o in opts): problems.append(f"duplicate/empty options: {where}")
        if q.get("tier") not in ("easy", "medium", "hard"): problems.append(f"tier: {where}")
        lo, hi = q.get("gradeLo"), q.get("gradeHi")
        if not (isinstance(lo, int) and isinstance(hi, int) and 0 <= lo <= hi <= 8): problems.append(f"grades {lo}-{hi}: {where}")
        key = p.strip().lower()
        if key in seen: problems.append(f"duplicate prompt in batch: {where}")
        if key in known: problems.append(f"already in the built-in bank: {where}")
        seen.add(key)
    print(f"{path}: {len(items)} items, {len(problems)} problems")
    for x in problems: print("  ", x)
    return not problems


if __name__ == "__main__":
    sys.exit(0 if all([check(p) for p in sys.argv[1:]]) else 1)
