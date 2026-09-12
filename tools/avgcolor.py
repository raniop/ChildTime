#!/usr/bin/env python3
"""Average RGB of a PNG, using only the standard library.

ffmpeg on this Mac is an x86 binary and sips refuses to write outside the
sandbox, so the screenshot guard decodes the PNG itself.
"""
import sys, zlib, struct

def main(path):
    d = open(path, "rb").read()
    pos, idat, w, h, bd, ct = 8, [], None, None, None, None
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos+4])[0]
        typ = d[pos+4:pos+8]
        body = d[pos+8:pos+8+ln]
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", body[:10])
        elif typ == b"IDAT":
            idat.append(body)
        elif typ == b"IEND":
            break
        pos += 12 + ln
    raw = zlib.decompress(b"".join(idat))
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    assert bd == 8, f"bit depth {bd} unsupported"
    stride = w * ch
    prev = bytearray(stride)
    r = g = b = n = 0
    i = 0
    # Sample every 16th row — an average, not a measurement.
    for y in range(h):
        f = raw[i]; i += 1
        line = bytearray(raw[i:i+stride]); i += stride
        if f == 1:
            for x in range(ch, stride): line[x] = (line[x] + line[x-ch]) & 255
        elif f == 2:
            for x in range(stride): line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x-ch] if x >= ch else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-ch] if x >= ch else 0
                c = prev[x-ch] if x >= ch else 0
                p = a + prev[x] - c
                pa, pb, pc = abs(p-a), abs(p-prev[x]), abs(p-c)
                pr = a if (pa <= pb and pa <= pc) else (prev[x] if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        if y % 16 == 0:
            for x in range(0, stride, ch * 8):
                r += line[x]; g += line[x+1]; b += line[x+2]; n += 1
        prev = line
    print(r // n, g // n, b // n)

main(sys.argv[1])
