"""Bulk-download Mixamo characters (T-pose FBX) via the authenticated API.
Reads the Bearer token from /tmp/mixtoken and the id↔name map from
/tmp/mixchars.txt. Saves FBX files to /tmp/mixfbx/. Usage: python3 mixamo_fetch.py Name1 Name2 ..."""
import urllib.request, json, time, os, sys, re

TOK = open('/tmp/mixtoken').read().strip()
HEAD = {'Authorization': 'Bearer ' + TOK, 'X-Api-Key': 'mixamo2', 'Accept': 'application/json'}

names = {}
for line in open('/tmp/mixchars.txt'):
    if '|' in line:
        i, n = line.split('|', 1)
        names[n.strip().lower()] = i.strip()

outdir = '/tmp/mixfbx'
os.makedirs(outdir, exist_ok=True)


def api_post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={**HEAD, 'Content-Type': 'application/json'}, method='POST')
    return json.load(urllib.request.urlopen(req))


def api_get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=HEAD)))


def safe(n):
    return re.sub(r'[^a-z0-9]+', '_', n.lower()).strip('_')


wanted = sys.argv[1:]
for name in wanted:
    cid = names.get(name.lower()) or next((v for k, v in names.items() if name.lower() in k), None)
    if not cid:
        print("SKIP(no id):", name); continue
    try:
        api_post("https://www.mixamo.com/api/v1/animations/export",
                 {"character_id": cid, "product_name": name, "type": "Character",
                  "preferences": {"format": "fbx7_2019", "skin": "true", "fps": "30", "reducekf": "0"}})
        url = None
        for _ in range(30):
            m = api_get(f"https://www.mixamo.com/api/v1/characters/{cid}/monitor")
            if m.get('status') == 'completed':
                url = m.get('job_result'); break
            if m.get('status') == 'failed':
                break
            time.sleep(2)
        if not url:
            print("FAIL(no result):", name); continue
        dst = os.path.join(outdir, safe(name) + '.fbx')
        urllib.request.urlretrieve(url, dst)
        print("OK", safe(name), os.path.getsize(dst) // 1024, "KB")
    except Exception as e:
        print("ERR", name, str(e)[:120])
