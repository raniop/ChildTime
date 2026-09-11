#!/usr/bin/env python3
"""Keep ChildTime/Localization/Localizable.xcstrings in step with the code.

    tools/i18n/catalog.py missing <DerivedData> [File.swift…]   # keys with no English yet (JSON on stdout)
    tools/i18n/catalog.py merge   translations.json              # add {"<hebrew key>": "<english>"} to the catalog
    tools/i18n/catalog.py check   <DerivedData>                  # every extracted key used in code has English?

Keys are extracted by the Swift compiler into *.stringsdata during a build (every
tr("…") literal, with its %@ / %lld placeholders), so the list is exact — no
guessing how an interpolation turns into a format key.
"""
import json, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "ChildTime", "Localization", "Localizable.xcstrings")


def load_catalog():
    with open(CATALOG, encoding="utf-8") as f:
        return json.load(f)


def save_catalog(cat):
    cat["strings"] = dict(sorted(cat["strings"].items()))
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2)
        f.write("\n")


def extracted(derived, files=None):
    """{key: [source files]} from the app target's .stringsdata."""
    keys = {}
    pattern = os.path.join(derived, "Build/Intermediates.noindex/ChildTime.build/*/ChildTime.build/Objects-normal/*/*.stringsdata")
    wanted = {os.path.splitext(os.path.basename(f))[0] for f in files} if files else None
    for path in glob.glob(pattern):
        name = os.path.splitext(os.path.basename(path))[0]
        if wanted is not None and name not in wanted:
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for item in data.get("tables", {}).get("Localizable", []):
            k = item.get("key")
            if k and re.search(r"[֐-׿]", k):
                keys.setdefault(k, set()).add(name)
    return keys


def english(cat, key):
    return cat["strings"].get(key, {}).get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")


def main():
    cmd = sys.argv[1]
    cat = load_catalog()
    if cmd == "missing":
        keys = extracted(sys.argv[2], sys.argv[3:] or None)
        out = {k: "" for k in sorted(keys) if not english(cat, k)}
        print(json.dumps(out, ensure_ascii=False, indent=2))
        print(f"{len(out)} of {len(keys)} keys need English", file=sys.stderr)
    elif cmd == "merge":
        with open(sys.argv[2], encoding="utf-8") as f:
            tr = json.load(f)
        added = 0
        for k, v in tr.items():
            if not v:
                continue
            # A translation must keep the same placeholders, or the app crashes / shows garbage.
            # Positional forms (%2$lld) may reorder arguments; the types must still match.
            ph = lambda s: sorted(re.sub(r"\d+\$", "", m) for m in re.findall(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.\d+f|%)", s))
            if ph(k) != ph(v):
                print(f"  ✗ placeholder mismatch: {k!r} → {v!r}", file=sys.stderr)
                continue
            entry = cat["strings"].setdefault(k, {})
            entry.setdefault("localizations", {})["en"] = {"stringUnit": {"state": "translated", "value": v}}
            added += 1
        save_catalog(cat)
        print(f"merged {added} translations → {len(cat['strings'])} keys in catalog", file=sys.stderr)
    elif cmd == "check":
        keys = extracted(sys.argv[2])
        missing = [k for k in keys if not english(cat, k)]
        by_file = {}
        for k in missing:
            for f in keys[k]:
                by_file[f] = by_file.get(f, 0) + 1
        print(f"{len(keys) - len(missing)}/{len(keys)} extracted keys have English")
        for f, n in sorted(by_file.items(), key=lambda x: -x[1]):
            print(f"  {n:4} missing in {f}")


if __name__ == "__main__":
    main()
