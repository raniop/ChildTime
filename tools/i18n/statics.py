#!/usr/bin/env python3
"""List / convert stored constants that hold Hebrew into per-language computed values.

    tools/i18n/statics.py --list    File.swift…
    tools/i18n/statics.py --convert File.swift…

  static let all: [World] = [ … ]      →   static var all: [World] { LocalizedCache.value("World.all") { [ … ] } }

A stored `static let` is evaluated once, so its Hebrew would stay Hebrew after the
language changes. The converted property is rebuilt once per language and cached,
so a view body that reads it in a loop doesn't pay for the lookups every frame.
Only declarations WITH an explicit type are converted automatically; the rest are
listed for a human.
"""
import re, sys, os

HEB = re.compile(r"[֐-׿]")
HEAD = re.compile(r"^(\s*(?:@\w+\s+)*(?:(?:private|fileprivate|public|internal)\s+)?)static\s+let\s+(\w+)\s*:\s*([^=]+?)\s*=\s*(.*)$")


def depth_delta(code):
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code.split("//")[0])
    return code.count("[") + code.count("(") + code.count("{") - code.count("]") - code.count(")") - code.count("}")


def blocks(lines):
    i = 0
    while i < len(lines):
        m = HEAD.match(lines[i])
        if m:
            d, j = depth_delta(lines[i]), i
            while d > 0 and j + 1 < len(lines):
                j += 1
                d += depth_delta(lines[j])
            body = "\n".join(lines[i : j + 1])
            if HEB.search(body):
                yield i, j, m
            i = j + 1
            continue
        i += 1


def main():
    mode, files = sys.argv[1], sys.argv[2:]
    for path in files:
        lines = open(path, encoding="utf-8").read().split("\n")
        found = list(blocks(lines))
        base = os.path.splitext(os.path.basename(path))[0]
        for i, j, m in reversed(found):
            prefix, name, typ, rest = m.group(1), m.group(2), m.group(3).strip(), m.group(4)
            print(f"{os.path.basename(path)}:{i + 1}-{j + 1}  static let {name}: {typ}")
            if mode == "--convert":
                lines[i] = f'{prefix}static var {name}: {typ} {{ LocalizedCache.value("{base}.{name}") {{ {rest}'
                lines[j] = lines[j] + " } }"
        # static lets without a type annotation that hold Hebrew
        for k, l in enumerate(lines):
            if re.match(r"^\s*(?:(?:private|fileprivate|public|internal)\s+)?static\s+let\s+\w+\s*=", l) and HEB.search(l):
                print(f"  ⚠ no type — convert by hand: {os.path.basename(path)}:{k + 1}: {l.strip()[:100]}")
        if mode == "--convert":
            open(path, "w", encoding="utf-8").write("\n".join(lines))


if __name__ == "__main__":
    main()
