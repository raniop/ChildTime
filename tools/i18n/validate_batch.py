#!/usr/bin/env python3
"""validate_batch.py batchN.json batchN.en.json — every key translated, placeholders intact."""
import json, re, sys
src = json.load(open(sys.argv[1], encoding="utf-8"))
keys = [k for ks in src["files"].values() for k in ks] if "files" in src else list(src)
out = json.load(open(sys.argv[2], encoding="utf-8"))
ph = lambda s: sorted(re.sub(r"\d+\$", "", m) for m in re.findall(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.\d+f|%)", s))
problems = 0
for k in keys:
    v = out.get(k)
    if not v or not v.strip():
        print("MISSING:", k[:80]); problems += 1; continue
    if ph(k) != ph(v):
        print("PLACEHOLDERS:", k[:60], "→", v[:60]); problems += 1
    if re.search(r"[֐-׿]", v):
        print("HEBREW LEFT IN ENGLISH:", v[:80]); problems += 1
extra = set(out) - set(keys)
if extra:
    print(f"{len(extra)} keys not in the batch (typo in a key?) e.g.", list(extra)[:2]); problems += len(extra)
print(f"{len(keys)} keys · {problems} problems")
