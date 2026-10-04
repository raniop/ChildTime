#!/usr/bin/env python3
"""Canonical formatter for Localizable.xcstrings — stdin → stdout.

Xcode rewrites the string catalog on every build: it re-indents the whole
file (`"key" : value`, where Python writes `"key": value`) and re-orders the
keys with its own collation. Nothing of substance changes, but git sees
~53,000 changed lines, which buries real translation edits and makes it easy
to commit a build artifact over hand-written translations.

This script is wired up as a git clean filter (see .gitattributes), so every
version git stores is canonical no matter who wrote it — Xcode or one of our
Python scripts. The working copy keeps whatever Xcode last wrote; the diff
stays empty.

Canonical form: keys sorted by Python's plain sort, Xcode's `" : "` separator
and two-space indent, trailing newline.
"""
import json
import sys


def dump(value, indent=0):
    pad = "  " * indent
    inner = "  " * (indent + 1)
    if isinstance(value, dict):
        if not value:
            # Xcode writes an empty object as "{\n\n<indent>}".
            return "{\n\n" + pad + "}"
        items = [
            inner + json.dumps(k, ensure_ascii=False) + " : " + dump(v, indent + 1)
            for k, v in sorted(value.items())
        ]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(value, list):
        if not value:
            return "[\n\n" + pad + "]"
        items = [inner + dump(v, indent + 1) for v in value]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(value, ensure_ascii=False)


def main():
    text = sys.stdin.read()
    if not text.strip():
        sys.stdout.write(text)
        return
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        # Never destroy content we cannot parse — pass it through untouched.
        sys.stdout.write(text)
        return
    sys.stdout.write(dump(data) + "\n")


if __name__ == "__main__":
    main()
