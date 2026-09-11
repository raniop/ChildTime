#!/usr/bin/env python3
"""Wrap Hebrew literals nested inside the interpolations of a tr("…") string.

    tr("\\(isGirl ? "עָנְתָה" : "עָנָה") עַל הַשְּׁאֵלָה")
 →  tr("\\(isGirl ? tr("עָנְתָה") : tr("עָנָה")) עַל הַשְּׁאֵלָה")

Without it the inner word stays Hebrew inside an English sentence. Hebrew output
is unchanged (a Hebrew lookup returns the key).
"""
import re, sys

HEB = re.compile(r"[֐-׿]")


def rewrite(line):
    out, i, n, changed = [], 0, len(line), 0
    while i < n:
        if line.startswith("//", i) and not in_string(line, i):
            out.append(line[i:]); break
        if line.startswith('tr("', i):
            # copy 'tr("' then walk the literal, tracking interpolation depth
            out.append('tr("'); j = i + 4; depth = 0
            while j < n:
                c = line[j]
                if depth == 0:
                    if c == "\\" and j + 1 < n and line[j + 1] == "(":
                        out.append("\\("); depth = 1; j += 2; continue
                    if c == "\\":
                        out.append(line[j:j + 2]); j += 2; continue
                    out.append(c); j += 1
                    if c == '"':
                        break
                    continue
                # inside an interpolation
                if c == "(":
                    depth += 1; out.append(c); j += 1; continue
                if c == ")":
                    depth -= 1; out.append(c); j += 1; continue
                if c == '"':
                    k = j + 1
                    while k < n and not (line[k] == '"' and line[k - 1] != "\\"):
                        k += 1
                    lit = line[j:k + 1]
                    prev = "".join(out).rstrip()
                    if HEB.search(lit) and not prev.endswith("tr("):
                        out.append("tr(" + lit + ")"); changed += 1
                    else:
                        out.append(lit)
                    j = k + 1; continue
                out.append(c); j += 1
            i = j; continue
        out.append(line[i]); i += 1
    return "".join(out), changed


def in_string(line, idx):
    return line[:idx].count('"') % 2 == 1


if __name__ == "__main__":
    total = 0
    for path in sys.argv[1:]:
        lines = open(path, encoding="utf-8").read().split("\n")
        file_changes = 0
        for k, l in enumerate(lines):
            if l.strip().startswith("//"):
                continue
            new, c = rewrite(l)
            if c:
                lines[k] = new; file_changes += c
        if file_changes:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
            print(f"{file_changes:3} {path}")
            total += file_changes
    print("total nested literals wrapped:", total)
