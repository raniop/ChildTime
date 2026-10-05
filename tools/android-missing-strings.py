#!/usr/bin/env python3
"""List tr("…") keys used by the Android app that the shared catalog lacks
(or lacks en/ru/ar for). Exit 1 if any — the Android twin of the language gate."""
import json, re, pathlib, sys
cat = json.load(open('Shared/Localization/Localizable.xcstrings', encoding='utf-8'))['strings']
pat = re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"')
missing = {}
for f in pathlib.Path('android/app/src/main/java').rglob('*.kt'):
    for m in pat.finditer(f.read_text(encoding='utf-8')):
        k = m.group(1).encode().decode('unicode_escape').encode('latin1').decode('utf-8') if '\\' in m.group(1) else m.group(1)
        k = k.replace('$', '$')
        loc = cat.get(k, {}).get('localizations', {})
        lacks = [l for l in ('en', 'ru', 'ar') if l not in loc]
        if lacks:
            missing.setdefault(k, set()).add(f.name)
for k, files in sorted(missing.items()):
    print(f'{k}\t{",".join(sorted(files))}')
print(f'-- {len(missing)} missing', file=sys.stderr)
sys.exit(1 if missing else 0)
