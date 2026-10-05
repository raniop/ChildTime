#!/usr/bin/env python3
"""Export the iOS string catalog for the Android parent app.

Writes android/app/src/main/assets/i18n/{en,ru,ar}.json — {hebrewKey: value}
or {hebrewKey: {one/few/many/other…}} for plural variations. Hebrew is the
key itself, exactly like tr() on iOS, so one catalog feeds both apps.
Run after adding strings:  python3 tools/android-strings.py
"""
import json, os
SRC = 'Shared/Localization/Localizable.xcstrings'
OUT = 'android/app/src/main/assets/i18n'
d = json.load(open(SRC, encoding='utf-8'))
os.makedirs(OUT, exist_ok=True)
for lang in ('en', 'ru', 'ar', 'he'):
    out = {}
    for key, v in d['strings'].items():
        loc = v.get('localizations', {}).get(lang)
        if not loc:
            continue
        if 'stringUnit' in loc:
            val = loc['stringUnit'].get('value')
            if val is not None and (lang != 'he' or val != key):
                out[key] = val
        elif 'variations' in loc and 'plural' in loc['variations']:
            forms = {f: u['stringUnit']['value'] for f, u in loc['variations']['plural'].items() if 'stringUnit' in u}
            if forms:
                out[key] = forms
    json.dump(out, open(f'{OUT}/{lang}.json', 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(lang, len(out))
