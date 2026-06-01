"""Remove leftover white background from character PNGs (keeps the character's
own white, e.g. a panda's body). Flood-fills "background-like" pixels (already
transparent OR opaque near-white) that are connected to the image border.

Setup (one-time):
    python3 -m venv /tmp/rembgenv
    /tmp/rembgenv/bin/pip install numpy scipy pillow
Usage:
    /tmp/rembgenv/bin/python tools/remove_white_bg.py <in_dir> <out_dir>
"""
import os
import sys
import glob
import numpy as np
from PIL import Image
from scipy import ndimage


def clean(src, dst, white_thr=238, alpha_thr=30):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    r, g, b, al = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    near_white = (r >= white_thr) & (g >= white_thr) & (b >= white_thr)
    bg_like = (al < alpha_thr) | ((al >= alpha_thr) & near_white)
    lbl, _ = ndimage.label(bg_like)
    border = np.unique(np.concatenate([lbl[0, :], lbl[-1, :], lbl[:, 0], lbl[:, -1]]))
    border = border[border != 0]
    bgmask = np.isin(lbl, border)
    arr[..., 3] = np.where(bgmask, 0, arr[..., 3])
    Image.fromarray(arr).save(dst)
    print("cleaned", os.path.basename(dst))


if __name__ == "__main__":
    in_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for src in sorted(glob.glob(os.path.join(in_dir, "*.png"))):
        clean(src, os.path.join(out_dir, os.path.basename(src)))
