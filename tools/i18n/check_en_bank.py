#!/usr/bin/env python3
"""Mechanical checks for an English question bank file (see CONTENT-en.md).

    tools/i18n/check_en_bank.py ChildTime/Models/EnglishContent/EnglishBankAnimals.swift…

Checks every BankQuestion: emoji+newline prompt, no Hebrew, 3 distinct distractors
different from the answer, tier set, grades within 0...8, no duplicate prompts.
Exit code 1 when anything fails. Facts are NOT checked here — that's the reviewer.
"""
import re, sys

ITEM = re.compile(
    r'BankQuestion\(prompt: "((?:[^"\\]|\\.)*)", correctAnswer: "((?:[^"\\]|\\.)*)", '
    r'distractors: \[((?:\s*"(?:[^"\\]|\\.)*",?)*)\s*\], tier: \.(easy|medium|hard), grades: (\d)\.\.\.(\d)\)')
HEB = re.compile(r"[֐-׿]")


def check(path):
    text = open(path, encoding="utf-8").read()
    total = text.count("BankQuestion(")
    items = ITEM.findall(text)
    problems = []
    if len(items) != total:
        problems.append(f"{total - len(items)} BankQuestion(...) entries don't match the required one-line shape")
    seen = set()
    for prompt, answer, ds, tier, lo, hi in items:
        where = prompt[:60]
        distractors = re.findall(r'"((?:[^"\\]|\\.)*)"', ds)
        if HEB.search(prompt + answer + ds):
            problems.append(f"Hebrew text: {where}")
        if "\\n" not in prompt:
            problems.append(f"prompt has no emoji line: {where}")
        if len(distractors) != 3:
            problems.append(f"{len(distractors)} distractors: {where}")
        options = [answer] + distractors
        if len({o.strip().lower() for o in options}) != len(options):
            problems.append(f"duplicate options: {where}")
        if any(not o.strip() for o in options):
            problems.append(f"empty option: {where}")
        if not (0 <= int(lo) <= int(hi) <= 8):
            problems.append(f"grades {lo}...{hi}: {where}")
        key = prompt.strip().lower()
        if key in seen:
            problems.append(f"duplicate prompt: {where}")
        seen.add(key)
    print(f"{path}: {len(items)} items, {len(problems)} problems")
    for p in problems:
        print("  ", p)
    return not problems


if __name__ == "__main__":
    ok = all([check(p) for p in sys.argv[1:]])
    sys.exit(0 if ok else 1)
