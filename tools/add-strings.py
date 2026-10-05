#!/usr/bin/env python3
"""Add translated entries to the shared catalog: python3 tools/add-strings.py new.json
new.json = {"hebrew key": {"en": "...", "ru": "...", "ar": "..."}}. Existing keys get missing langs filled."""
import json, sys, io
p = 'Shared/Localization/Localizable.xcstrings'
d = json.load(io.open(p, encoding='utf-8'))
new = json.load(open(sys.argv[1], encoding='utf-8'))
for k, tr in new.items():
    e = d['strings'].setdefault(k, {})
    loc = e.setdefault('localizations', {})
    for lang, v in tr.items():
        if lang not in loc:
            loc[lang] = {'stringUnit': {'state': 'translated', 'value': v}}
d['strings'] = dict(sorted(d['strings'].items()))
io.open(p, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, separators=(',', ' : ')) + '\n')
print('added/updated', len(new))
