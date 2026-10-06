#!/usr/bin/env python3
"""Export the app's "מה חדש" releases for the admin's one-click update.

Reads ChildTime/Models/WhatsNewContent.swift (build, version, items) and the
shared string catalog, and writes docs/admin/releases.json:
  [{"build": 199, "version": "2026.10.5", "notes": {"he": [...], "en": [...], ...}}]
A note line is "<emoji> <title>"; a language without a translation gets no
line rather than the Hebrew one. Run after editing WhatsNewContent:
  python3 tools/releases-json.py
"""
import json, re
SRC = 'ChildTime/Models/WhatsNewContent.swift'
CAT = 'Shared/Localization/Localizable.xcstrings'
OUT = 'docs/admin/releases.json'
PITCH = 'tools/update-pitch.json'
LANGS = ('en', 'ru', 'ar')
s = open(SRC, encoding='utf-8').read()
cat = json.load(open(CAT, encoding='utf-8'))['strings']
def unesc(x): return x.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\' in x else x
def tr(he, lang):
    loc = cat.get(he, {}).get('localizations', {}).get(lang, {}).get('stringUnit', {}).get('value')
    return loc
out = []
for m in re.finditer(r'Release\(build:\s*(\d+),\s*version:\s*"([^"]+)"(.*?)\]\),', s, re.S):
    build, version, body = int(m.group(1)), m.group(2), m.group(3)
    items = re.findall(r'Item\(emoji:\s*"([^"]*)",\s*title:\s*tr\("((?:[^"\\]|\\.)*)"\)', body)
    notes = {'he': []}; [notes.setdefault(l, []) for l in LANGS]
    for emoji, title in items[:3]:
        title = title.replace('\\"', '"')
        notes['he'].append(f'{emoji} {title}')
        for l in LANGS:
            t = tr(title, l)
            if t: notes[l].append(f'{emoji} {t}')
    out.append({'build': build, 'version': version, 'notes': notes})
out.sort(key=lambda r: -r['build'])
# The update sheet's text is written for EXISTING users (tools/update-pitch.json),
# not the What's New titles (those are for people who just installed).
pitch = json.load(open(PITCH, encoding='utf-8'))
fixes = pitch['_fixes']
for r in out:
    # Every version gets a pitch: its own lines, or just the friendly fixes line.
    r['pitch'] = pitch.get(r['version']) or {l: [fixes[l]] for l in fixes}
json.dump(out, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(out), 'releases →', OUT, '· newest', out[0]['build'] if out else None)
