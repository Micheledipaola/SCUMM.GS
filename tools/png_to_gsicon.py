#!/usr/bin/env python3
"""png_to_gsicon.py - PNG to Apple IIGS Finder icon file (type $CA).

The Finder loads these from an Icons/ folder. Each record matches a
filename and file type, then holds a 32x32 colour icon and a 16x16 one
(QuickDraw II Auxiliary Icon record: 4-bit image + 4-bit mask).

    python3 tools/png_to_gsicon.py <in.png> <out> [name] [type-hex]

Default name SCUMM, file type $B3 (GS/OS application).
"""
import struct
import sys

from PIL import Image

# Apple IIGS default 320-mode 16 (12-bit $0RGB → 8-bit)
IIGS16 = [
    (0x00, 0x00, 0x00),
    (0x77, 0x77, 0x77),
    (0x88, 0x44, 0x11),
    (0x77, 0x22, 0xCC),
    (0x00, 0x00, 0xFF),
    (0x00, 0x88, 0x00),
    (0xFF, 0x77, 0x00),
    (0xDD, 0x00, 0x00),
    (0xFF, 0xAA, 0x99),
    (0xFF, 0xFF, 0x00),
    (0x00, 0xEE, 0x00),
    (0xAA, 0xFF, 0xFF),
    (0x00, 0xDD, 0xFF),
    (0xDD, 0xAA, 0xFF),
    (0xFF, 0xFF, 0xAA),
    (0xFF, 0xFF, 0xFF),
]


def nearest(rgb):
    r, g, b = rgb
    if g >= r + 16 and g >= b + 16:
        cands = (5, 10)  # dark green, bright green — keep the S lime, not yellow
    else:
        cands = range(16)
    best, d0 = 0, 1e9
    for i in cands:
        pr, pg, pb = IIGS16[i]
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < d0:
            best, d0 = i, d
    return best


def pstr(s, width):
    raw = s.encode('ascii', 'replace')[: width - 1]
    return bytes([len(raw)]) + raw + bytes(width - 1 - len(raw))


def pack_row(indices):
    out = bytearray((len(indices) + 1) // 2)
    for i, pix in enumerate(indices):
        if i % 2 == 0:
            out[i // 2] = (pix & 0xF) << 4
        else:
            out[i // 2] |= pix & 0xF
    return bytes(out)


def raster(img, size):
    """Fit into size×size, keep aspect, transparent pad. Returns idx, mask."""
    src = img.convert('RGBA')
    src.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    x = (size - src.size[0]) // 2
    y = (size - src.size[1]) // 2
    canvas.paste(src, (x, y), src)
    pix = list(canvas.getdata())
    idx, mask = [], []
    for r, g, b, a in pix:
        if a < 32:
            idx.append(0)
            mask.append(0)
        else:
            idx.append(nearest((r, g, b)))
            mask.append(0xF)
    return idx, mask


def qd_icon(idx, mask, w, h):
    """QuickDraw II Auxiliary colour Icon record."""
    image = bytearray()
    mbytes = bytearray()
    rb = (w + 1) // 2
    for y in range(h):
        row = idx[y * w:(y + 1) * w]
        mrow = mask[y * w:(y + 1) * w]
        image += pack_row(row)
        mbytes += pack_row(mrow)
        assert len(pack_row(row)) == rb
    icon_size = len(image)
    hdr = struct.pack('<HHHH', 0x8000, icon_size, h, w)
    return hdr + bytes(image) + bytes(mbytes)


def build_file(png_path, name='SCUMM', ftype=0x00B3, aux=0):
    img = Image.open(png_path)
    big = qd_icon(*raster(img, 32), 32, 32)
    small = qd_icon(*raster(img, 16), 16, 16)
    rec = bytearray()
    rec += b'\x00\x00'  # iDataLen filled below
    rec += pstr('', 64)
    rec += pstr(name, 16)
    rec += struct.pack('<HH', ftype, aux)
    rec += big
    rec += small
    struct.pack_into('<H', rec, 0, len(rec))
    blk = bytearray()
    blk += struct.pack('<I', 0)       # iBlkNext
    blk += struct.pack('<H', 1)       # iBlkID
    blk += struct.pack('<I', 0)       # iBlkPath
    blk += pstr(name, 16)             # iBlkName
    blk += rec
    blk += struct.pack('<H', 0)       # end of Icon Data list
    return bytes(blk)


def main():
    if len(sys.argv) < 3:
        print('usage: png_to_gsicon.py <png> <out> [name] [type-hex]')
        sys.exit(1)
    png, dest = sys.argv[1], sys.argv[2]
    name = sys.argv[3] if len(sys.argv) > 3 else 'SCUMM'
    ftype = int(sys.argv[4], 16) if len(sys.argv) > 4 else 0xB3
    data = build_file(png, name, ftype)
    open(dest, 'wb').write(data)
    print(f'wrote {dest} ({len(data)} bytes) as {name} type ${ftype:02X}')


if __name__ == '__main__':
    main()
