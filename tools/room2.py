#!/usr/bin/env python3
"""room2.py - the background picture of a SCUMM V2 room.

From V3 on, the graphics are cut into eight-pixel strips, handy for
redrawing in pieces. V2 is not: it is one single block, and written in
columns instead of rows.

One byte is read at a time and counted:

    bit 7 set     run = bits 0..6, and the colour is NOT updated in the
                  column table (this is the dithering trick: those pixels
                  take back the colour the previous column had on that
                  same row)
    bit 7 clear   run = bits 4..7; if that comes out zero, the real run
                  length is in the next byte
    either way the colour is in bits 0..3

Walking the columns from top to bottom fills a table as tall as the room:
that is the one the dithering reuses.

The palette is the standard sixteen-colour EGA one, and here is the luck:
its values are 0, 85, 170 and 255, which divided by seventeen give 0, 5,
10 and 15 - exactly the IIGS four-bits-per-channel grid. The conversion is
lossless, no approximation needed.

Format worked out from ScummVM engines/scumm/gfx.cpp (GPL-2.0-or-later).
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import struct

import numpy as np

# The sixteen-colour EGA palette, and its exact IIGS equivalent.
EGA = [
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
    (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255),
]


def iigs_palette():
    """The sixteen $0RGB words to write into the IIGS video memory."""
    out = bytearray()
    for r, g, b in EGA:
        w = ((r // 17) << 8) | ((g // 17) << 4) | (b // 17)
        out += w.to_bytes(2, 'little')
    return bytes(out)


class Room:
    def __init__(self, data):
        self.data = data
        self.width = struct.unpack('<H', data[4:6])[0]
        self.height = struct.unpack('<H', data[6:8])[0]
        self.img_offset = struct.unpack('<H', data[0x0A:0x0C])[0]

    def __repr__(self):
        return (f"<stanza {self.width}x{self.height}, "
                f"immagine a ${self.img_offset:04X}>")

    def background(self):
        """The background as an (height, width) array of colour indices."""
        w, h = self.width, self.height
        out = np.zeros((h, w), np.uint8)
        src = self.img_offset
        d = self.data
        colonna = [0] * h          # the colour the dithering reuses
        run = 0
        color = 0
        dither = False
        for x in range(w):
            for y in range(h):
                if run == 0:
                    b = d[src]
                    src += 1
                    if b & 0x80:
                        run = b & 0x7F
                        dither = True
                    else:
                        run = b >> 4
                        dither = False
                    color = b & 0x0F
                    if run == 0:
                        run = d[src]
                        src += 1
                if not dither:
                    colonna[y] = color
                out[y, x] = colonna[y]
                run -= 1
        return out


if __name__ == '__main__':
    import sys
    from lfl import Index
    idx = Index(sys.argv[1])
    for n in range(1, len(idx.rooms)):
        try:
            r = Room(idx.room_file(n))
            print(f"stanza {n:>2}: {r!r}")
        except Exception as e:
            print(f"stanza {n:>2}: {e}")
