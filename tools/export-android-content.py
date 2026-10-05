#!/usr/bin/env python3
"""Export the iOS built-in question content to JSON assets for the Android app.

The Swift sources stay the single source of truth. Instead of re-parsing Swift
literals (escapes, `\\n`, string concatenation, the difficulty side-table…),
this compiles the content files themselves with `swiftc` against a few tiny
stubs, runs the result, and lets Swift print every bank as JSON — so whatever
the iOS app compiles is exactly what Android ships.

Output (android/app/src/main/assets/content/):
  banks/{he,en,ru,ar}.json   {"topic": [item, …]}   built-in banks per language
                             (he = QuestionBanks.builtInBank, others = <Lang>Content.bank)
  reading/{he,en,ru,ar}.json [passage, …]           ReadingContent.passages(in:)
  bonus/he.json              {"topic": [item, …]}   BonusQuestionBank (Hebrew only, as on iOS)
  manifest.json              counts per language/topic + the cross-check below

Item shape = RemoteQuestionBank.Item (the cloud wire format) + topic:
  {id, prompt, correctAnswer, distractors, tier, gradeLo, gradeHi, lang, topic}
`tier` is resolved exactly like BankQuestion.difficulty (inline tier, else the
QuestionDifficultyTags side-map, else "medium").

Cross-check: every `BankQuestion(` literal in the Swift sources must land in
exactly one exported item; the script fails loudly when the totals differ
(an item that compiles but is never wired into a bank would be a silent drop).

Usage:  python3 tools/export-android-content.py
"""
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "ChildTime", "Models")
OUT = os.path.join(ROOT, "android", "app", "src", "main", "assets", "content")
LANGS = ["he", "en", "ru", "ar"]

SOURCES = sorted(
    [os.path.join(MODELS, f) for f in ["Question.swift", "Topic.swift", "ReadingContent.swift", "ContentLanguage.swift"]]
    + glob.glob(os.path.join(MODELS, "QuestionBanks*.swift"))
    + glob.glob(os.path.join(MODELS, "QuestionDifficultyTags*.swift"))
    + glob.glob(os.path.join(MODELS, "EnglishContent", "*.swift"))
    + glob.glob(os.path.join(MODELS, "RussianContent", "*.swift"))
    + glob.glob(os.path.join(MODELS, "ArabicContent", "*.swift"))
)

# Just enough of the app for the content files to compile. Nothing here may
# change content: tr() is identity (bank literals don't go through it anyway),
# the cloud bank is empty (built-ins only), and the language is switchable.
STUBS = r'''
import Foundation
func tr(_ s: String) -> String { s }
enum AppLanguage: String, CaseIterable { case he, en, ru, ar
    var isRightToLeft: Bool { self == .he || self == .ar } }
final class LanguageStore { static let shared = LanguageStore(); var current: AppLanguage = .he }
final class ProfileStore { static let shared = ProfileStore(); var activeID: UUID? = nil }
final class RemoteQuestionBank { static let shared = RemoteQuestionBank()
    func questions(for topic: Topic, in language: AppLanguage = .he) -> [BankQuestion] { [] } }
struct QuestionPack {}
enum QuestionPacks { static func pack(for topic: Topic) -> QuestionPack? { nil } }
'''

MAIN = r'''
import Foundation
func item(_ q: BankQuestion, _ topic: String, _ lang: String) -> [String: Any] {
    ["prompt": q.prompt, "correctAnswer": q.correctAnswer, "distractors": q.distractors,
     "tier": q.difficulty.rawValue, "gradeLo": q.grades.lowerBound, "gradeHi": q.grades.upperBound,
     "lang": lang, "topic": topic]
}
var banks: [String: [String: [[String: Any]]]] = [:]
var reading: [String: [[String: Any]]] = [:]
for lang in AppLanguage.allCases {
    LanguageStore.shared.current = lang
    var perTopic: [String: [[String: Any]]] = [:]
    for t in Topic.allCases {
        let list: [BankQuestion]
        switch lang {
        case .he: list = QuestionBanks.builtInBank(for: t) ?? []
        case .en: list = EnglishContent.bank(for: t)
        case .ru: list = RussianContent.bank(for: t)
        case .ar: list = ArabicContent.bank(for: t)
        }
        if !list.isEmpty { perTopic[t.rawValue] = list.map { item($0, t.rawValue, lang.rawValue) } }
    }
    banks[lang.rawValue] = perTopic
    reading[lang.rawValue] = ReadingContent.passages(in: lang).map { p in
        ["id": p.id, "tier": p.tier.rawValue, "gradeLo": p.gradeWindow.lowerBound, "gradeHi": p.gradeWindow.upperBound,
         "text": p.text, "lang": lang.rawValue,
         "questions": p.questions.map { item($0, "reading", lang.rawValue) }] as [String: Any]
    }
}
LanguageStore.shared.current = .he
var bonus: [String: [[String: Any]]] = [:]
for t in Topic.allCases {
    let pool = BonusQuestionBank.pool(for: t)
    if !pool.isEmpty { bonus[t.rawValue] = pool.map { item($0, t.rawValue, "he") } }
}
let topics = Topic.allCases.map(\.rawValue)
let out: [String: Any] = ["banks": banks, "reading": reading, "bonus": bonus, "topics": topics]
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
'''


def build_and_run():
    work = tempfile.mkdtemp(prefix="tofy-content-")
    stubs, main = os.path.join(work, "Stubs.swift"), os.path.join(work, "main.swift")
    open(stubs, "w").write(STUBS)
    open(main, "w").write(MAIN)
    exe = os.path.join(work, "export")
    cmd = ["xcrun", "swiftc", "-Onone", "-suppress-warnings", "-o", exe, stubs, main] + SOURCES
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-6000:])
        sys.exit("swiftc failed — a content file now depends on something the stubs lack")
    r = subprocess.run([exe], capture_output=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr.decode()[-3000:])
        sys.exit("export binary failed")
    return json.loads(r.stdout)


def stable_ids(items, seen):
    """RemoteQuestionBank.Item.id — a stable hash of language|topic|prompt|answer."""
    for it in items:
        base = hashlib.sha1(f"{it['lang']}|{it['topic']}|{it['prompt']}|{it['correctAnswer']}".encode()).hexdigest()[:12]
        uid, n = f"{it['lang']}-{it['topic']}-{base}", 1
        while uid in seen:
            n += 1
            uid = f"{it['lang']}-{it['topic']}-{base}-{n}"
        seen.add(uid)
        it["id"] = uid
    return items


def literal_count():
    """`BankQuestion(` literals in the sources (excluding the struct and comments)."""
    total = 0
    for path in SOURCES:
        for line in open(path, encoding="utf-8"):
            s = line.strip()
            if s.startswith("//"):
                continue
            total += len(re.findall(r"(?<![\w.])BankQuestion\(prompt:", line))
    return total


def write(rel, obj):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return os.path.getsize(path)


def main():
    data = build_and_run()
    seen = set()
    manifest = {"topics": data["topics"], "banks": {}, "reading": {}, "bonus": {}, "files": {}}
    exported = 0
    # The Hebrew world for ru/ar children is served from the Hebrew bank — that
    # routing lives in Kotlin (QuestionBanks.assemble), nothing is duplicated here.
    for lang in LANGS:
        banks = data["banks"].get(lang, {})
        for topic in sorted(banks):
            stable_ids(banks[topic], seen)
        manifest["banks"][lang] = {t: len(v) for t, v in sorted(banks.items())}
        manifest["files"][f"banks/{lang}.json"] = write(f"banks/{lang}.json", banks)
        exported += sum(len(v) for v in banks.values())

        passages = data["reading"].get(lang, [])
        for p in passages:
            stable_ids(p["questions"], seen)
        manifest["reading"][lang] = {"passages": len(passages), "questions": sum(len(p["questions"]) for p in passages)}
        manifest["files"][f"reading/{lang}.json"] = write(f"reading/{lang}.json", passages)
        exported += manifest["reading"][lang]["questions"]

    bonus = data["bonus"]
    for topic in sorted(bonus):
        stable_ids(bonus[topic], seen)
    manifest["bonus"]["he"] = {t: len(v) for t, v in sorted(bonus.items())}
    manifest["files"]["bonus/he.json"] = write("bonus/he.json", bonus)
    exported += sum(len(v) for v in bonus.values())

    literals = literal_count()
    manifest["crossCheck"] = {"swiftLiterals": literals, "exportedItems": exported}
    write("manifest.json", manifest)

    for lang in LANGS:
        b = manifest["banks"][lang]
        print(f"{lang}: {sum(b.values())} bank items in {len(b)} topics · "
              f"{manifest['reading'][lang]['passages']} passages / {manifest['reading'][lang]['questions']} reading questions")
        print("    " + ", ".join(f"{t} {n}" for t, n in b.items()))
    print(f"bonus he: {manifest['bonus']['he']}")
    print(f"cross-check: {literals} BankQuestion literals in Swift, {exported} exported items")
    for rel, size in manifest["files"].items():
        print(f"  {rel}: {size / 1024:.0f} KB")
    if literals != exported:
        sys.exit("MISMATCH — some Swift items were not exported (or exported twice). Investigate before shipping.")


if __name__ == "__main__":
    main()
