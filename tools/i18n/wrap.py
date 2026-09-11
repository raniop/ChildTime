#!/usr/bin/env python3
"""Wrap user-facing Hebrew string literals in tr(…) — the localization pass.

    tools/i18n/wrap.py --scan  File.swift…   # report literals and risky contexts
    tools/i18n/wrap.py --apply File.swift…   # rewrite safe literals as tr("…")

The Hebrew text itself becomes the lookup key (see ChildTime/Localization), so a
wrapped literal renders exactly as before in Hebrew. Literals the tool can't
wrap safely are listed and left alone for a human:
  • comparisons / pattern matches  ("…" == x, case "…", contains("…"))
  • static stored properties       (evaluated once — would freeze the language)
  • markdown in Text               (Text(String) doesn't render **bold**)
  • literals already inside tr(…)
"""
import re, sys

HEB = re.compile(r"[֐-׿]")
RISKY_BEFORE = re.compile(r"(==|!=|\bcase|contains\(|hasPrefix\(|hasSuffix\(|firstIndex\(of:|range\(of:|forKey:)\s*$")


def literals(line):
    """(start, end) of each single-line string literal, honouring \\( … ) interpolation."""
    out, i, n = [], 0, len(line)
    while i < n:
        if line.startswith("//", i):
            break
        if line[i] == '"':
            if line.startswith('"""', i):
                return out
            j, depth = i + 1, 0
            while j < n:
                c = line[j]
                if depth == 0 and c == "\\" and j + 1 < n and line[j + 1] == "(":
                    depth, j = 1, j + 2
                    continue
                if depth > 0:
                    if c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                    elif c == '"':  # a nested literal inside the interpolation
                        k = j + 1
                        while k < n and not (line[k] == '"' and line[k - 1] != "\\"):
                            k += 1
                        j = k
                    j += 1
                    continue
                if c == "\\":
                    j += 2
                    continue
                if c == '"':
                    break
                j += 1
            out.append((i, j))
            i = j + 1
            continue
        i += 1
    return out


def classify(line, a, b):
    lit = line[a : b + 1]
    before = line[:a].rstrip()
    if before.endswith("tr("):
        return "done"
    if RISKY_BEFORE.search(before) or line[b + 1 :].lstrip().startswith(("==", "!=")):
        return "compare"
    if re.search(r"\bstatic\s+(let|var)\b", line) and "{" not in line.split("=", 1)[0]:
        return "static"
    if "**" in lit:
        return "markdown"
    if re.search(r"(AppAnalytics|print|TofyLink|debugPrint|os_log|Logger)\S*\(\s*$", before):
        return "log"
    return "wrap"


def process(path, apply):
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    counts, flagged = {}, []
    in_block_comment = False
    for idx, line in enumerate(lines):
        s = line.strip()
        if s.startswith("/*"):
            in_block_comment = True
        if in_block_comment:
            if "*/" in s:
                in_block_comment = False
            continue
        if s.startswith("//"):
            continue
        spans = [(a, b) for a, b in literals(line) if HEB.search(line[a : b + 1])]
        new = line
        for a, b in reversed(spans):
            kind = classify(line, a, b)
            counts[kind] = counts.get(kind, 0) + 1
            if kind == "wrap":
                new = new[:a] + "tr(" + new[a : b + 1] + ")" + new[b + 1 :]
            elif kind not in ("done",):
                flagged.append(f"  {kind:8} {path.split('/')[-1]}:{idx + 1}: {s[:120]}")
        lines[idx] = new
    if apply:
        open(path, "w", encoding="utf-8").write("\n".join(lines))
    print(path.split("/")[-1], counts)
    for f in flagged:
        print(f)


if __name__ == "__main__":
    mode = sys.argv[1]
    for p in sys.argv[2:]:
        process(p, apply=(mode == "--apply"))
