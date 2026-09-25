#!/usr/bin/env python3
"""cost2.py - the V2 costumes, that is, the animated characters.

A costume is built in layers: a list of "limbs", for each of them a list
of frames, and for each of those a compressed picture. On top sits an
animation table saying, for every facing and every movement, which frame
to show.

Counting from the start of the resource (which is also the base of every
internal offset):

    +4    byte   how many animations
    +5    byte   format ($58) and, in the high bit, whether the costume
                 can be mirrored
    +6    byte   the colour (in V2 there is only one: the screen has
                 sixteen fixed ones and the costume says which to use)
    +7    word   where the animation commands start
    +9    32     the offsets of the sixteen limbs
    +41   ...    the animations

The picture is compressed in vertical runs: one byte carries colour and
length (four bits each), and if the length is zero it sits in the next
byte. You go down a column and at the end of it move to the next.

Format worked out from ScummVM engines/scumm/costume.cpp (GPL-2.0-or-later).
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import struct
import sys

import numpy as np

from lfl import Index

FORMATO_V2 = 0x58
NIENTE = 0x7B                  # "this limb draws nothing"


class Costume:
    def __init__(self, dati, off):
        self.d = dati
        self.base = off
        b = off
        self.n_anim = dati[b + 4]
        f = dati[b + 5]
        self.formato = f & 0x7F
        self.specchiabile = bool(f & 0x80)
        self.colore = dati[b + 6]
        self.cmd_off = b + struct.unpack_from('<H', dati, b + 7)[0]
        self.frame_off = b + 9
        self.anim_off = b + 41

    def __repr__(self):
        return (f"<costume {self.n_anim} animazioni, formato ${self.formato:02X}"
                f"{', specchiabile' if self.specchiabile else ''}, "
                f"colore {self.colore}>")

    def arto(self, n):
        """Where the frame list of limb n starts."""
        return self.base + struct.unpack_from('<H', self.d,
                                              self.frame_off + n * 2)[0]

    def cella(self, arto, codice):
        """One frame's picture: (image, offsets)."""
        p = self.arto(arto)
        src = self.base + struct.unpack_from('<H', self.d, p + codice * 2)[0]
        w, h, relx, rely, movx, movy = struct.unpack_from('<6h', self.d, src)
        src += 12
        if not (0 < w <= 200 and 0 < h <= 200):
            raise ValueError(f"misure strane: {w}x{h}")
        img = np.zeros((h, w), np.uint8)
        x = y = 0
        d = self.d
        while x < w:
            b = d[src]
            src += 1
            colore = b >> 4
            lung = b & 0x0F
            if lung == 0:
                lung = d[src]
                src += 1
            for _ in range(lung):
                if x < w and y < h:
                    img[y, x] = colore
                y += 1
                if y >= h:
                    y = 0
                    x += 1
                    if x >= w:
                        break
        return img, (relx, rely, movx, movy)


def costumi(idx):
    """Every costume in the game, by number."""
    out = {}
    for n in range(len(idx.costumes)):
        r = idx.costumes.rooms[n]
        off = idx.costumes.offsets[n]
        if off in (0, 0xFFFF) or r >= len(idx.rooms):
            continue
        try:
            dati = idx.room_file(r)
        except Exception:
            continue
        if off + 42 >= len(dati):
            continue
        try:
            c = Costume(dati, off)
        except Exception:
            continue
        if c.formato == FORMATO_V2:
            out[n] = c
    return out


if __name__ == '__main__':
    idx = Index(sys.argv[1])
    tutti = costumi(idx)
    print(f"{len(tutti)} costumi leggibili")
    for n, c in list(tutti.items())[:8]:
        print(f"  costume {n:>2}: {c!r}")
