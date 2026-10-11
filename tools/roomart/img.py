#!/usr/bin/env python3
"""img.py <out.png> <prompt-file> [--size 1024x1536] [--quality high] [--bg transparent|opaque] [--model gpt-image-2] [--ref a.png ...]
Generates one image with the OpenAI Images API. The key comes from OPENAI_API_KEY and is never printed."""
import os, sys, json, base64, uuid, urllib.request, urllib.error, argparse, time
ap = argparse.ArgumentParser()
ap.add_argument("out"); ap.add_argument("prompt_file")
ap.add_argument("--size", default="1024x1536"); ap.add_argument("--quality", default="high")
ap.add_argument("--bg", default="opaque"); ap.add_argument("--model", default="gpt-image-2")
ap.add_argument("--ref", nargs="*", default=[])
a = ap.parse_args()
key = os.environ.get("OPENAI_API_KEY") or sys.exit("no OPENAI_API_KEY")
prompt = open(a.prompt_file, encoding="utf-8").read().strip()
fields = {"model": a.model, "prompt": prompt, "size": a.size, "quality": a.quality, "background": a.bg, "n": "1"}
if a.bg == "transparent": fields["output_format"] = "png"
if a.ref:
    b = uuid.uuid4().hex; body = b""
    for k, v in fields.items():
        body += f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    for p in a.ref:
        body += f'--{b}\r\nContent-Disposition: form-data; name="image[]"; filename="{os.path.basename(p)}"\r\nContent-Type: image/png\r\n\r\n'.encode() + open(p, "rb").read() + b"\r\n"
    body += f"--{b}--\r\n".encode()
    req = urllib.request.Request("https://api.openai.com/v1/images/edits", data=body,
                                 headers={"Authorization": "Bearer " + key, "Content-Type": f"multipart/form-data; boundary={b}"})
else:
    fields["n"] = 1
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=json.dumps(fields).encode(),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
t = time.time()
try:
    r = json.load(urllib.request.urlopen(req, timeout=600))
except urllib.error.HTTPError as e:
    err = json.load(e).get("error", {}); sys.exit(f"API error {e.code}: {err.get('code')} — {str(err.get('message'))[:300]}")
open(a.out, "wb").write(base64.b64decode(r["data"][0]["b64_json"]))
u = r.get("usage") or {}
print(f"{os.path.basename(a.out)}: {time.time()-t:.0f}s · tokens in {u.get('input_tokens')} out {u.get('output_tokens')}")
