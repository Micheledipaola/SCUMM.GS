#!/usr/bin/env python3
"""Punch the side-hat glasses blob in Zak costume 31 cel +104.

Cel +104 is the flying-hat SIDE view (20x22). Colour-1 on row 15 cols
7-14 is a solid bar that paints as a black blob over the glasses stems.
Clear those pixels (and any gap fill on rows 16-18) so only the thin
stem tips at cols 6 and 15 remain under the brim. Crown glasses
(rows 9-11) are untouched. Staged LFL only (xor $FF); ZakEnh originals
stay clean.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

CEL = 104
NEXT = 258
XOR = 0xFF


def decode(buf: bytearray | bytes, src: int):
    w, h = struct.unpack_from("<2h", buf, src)
    p = src + 12
    img = [[0] * w for _ in range(h)]
    x = y = 0
    while x < w:
        b = buf[p]
        p += 1
        col, lung = b >> 4, b & 0xF
        if lung == 0:
            lung = buf[p]
            p += 1
        for _ in range(lung):
            if x < w and y < h:
                img[y][x] = col
            y += 1
            if y >= h:
                y = 0
                x += 1
                if x >= w:
                    break
    return img, p


def encode(img):
    h = len(img)
    w = len(img[0])
    out = bytearray()
    for x in range(w):
        y = 0
        while y < h:
            col = img[y][x]
            lung = 1
            while y + lung < h and img[y + lung][x] == col:
                lung += 1
            if 1 <= lung <= 15:
                out.append((col << 4) | lung)
            else:
                out.append((col << 4) | 0)
                out.append(lung)
            y += lung
    return out


def patch_via_index(zak_dir: Path, index_dir: Path | None = None) -> Path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from lfl import Index

    zak_dir = Path(zak_dir)
    index_dir = Path(index_dir) if index_dir else zak_dir
    idx = Index(str(index_dir))
    room = idx.costumes.rooms[31]
    off = idx.costumes.offsets[31]
    if room == 0 and off == 0:
        raise SystemExit("costume 31 not in this Zak folder")

    candidates = [
        zak_dir / f"L{room:02d}.LFL",
        zak_dir / f"L{room:02d}.lfl",
        zak_dir / f"{room:02d}.LFL",
        zak_dir / f"{room:02d}.lfl",
    ]
    path = next((p for p in candidates if p.exists()), None)
    if path is None:
        raise SystemExit(f"room {room} LFL not found in {zak_dir}")

    raw = bytearray(path.read_bytes())
    data = bytearray(b ^ XOR for b in raw)
    src = off + CEL
    w, h, relx, rely, movx, movy = struct.unpack_from("<6h", data, src)
    if (w, h) != (20, 22):
        raise SystemExit(f"unexpected cel size {w}x{h} at {path} +{src}")

    old_size = (off + NEXT) - src
    img, _ = decode(data, src)

    # Clear the solid bar / gap fill; keep stem tips at cols 6 and 15.
    cleared = 0
    for y in range(15, 19):
        for x in range(7, 15):
            if img[y][x] == 1:
                img[y][x] = 0
                cleared += 1

    new_cel = struct.pack("<6h", w, h, relx, rely, movx, movy) + encode(img)
    if len(new_cel) > old_size:
        raise SystemExit(f"re-encoded cel too big: {len(new_cel)} > {old_size}")

    data[src : src + len(new_cel)] = new_cel
    # pad leftover with original (already decoded) zeros if shorter
    path.write_bytes(bytes(b ^ XOR for b in data))
    print(f"cleared {cleared} blob pixels in cel +{CEL}")
    return path


def main(argv):
    if len(argv) < 2:
        print(f"usage: {argv[0]} <Zak LFL folder> [index folder]", file=sys.stderr)
        return 1
    path = patch_via_index(Path(argv[1]), Path(argv[2]) if len(argv) > 2 else None)
    print(f"patched costume 31 cel +{CEL} in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
