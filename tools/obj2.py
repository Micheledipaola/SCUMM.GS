#!/usr/bin/env python3
"""obj2.py - the objects of a SCUMM V2 room.

Every room keeps two parallel tables of words, as long as the number of
objects (which sits at byte 20 of the room):

    at +28               offset of each object's picture (OBIM)
    at +28 + 2*n         offset of each object's description (OBCD)

The description (obcd is the address the table points at):

    +4   word   object number
    +7   byte   x in cells of 8 pixels
    +8   byte   y in cells of 8 pixels; bit 7 is the "parent" state
    +9   byte   width in cells of 8
    +10  byte   parent object
    +11  byte   x of the point the character stops at, in cells of 8
    +12  byte   y of that same point (bits 0..4)
    +13  byte   bits 0..2 the character's facing, bits 3..7 the height
    +14  byte   where the name starts, counted from obcd
    +15  ...    the verb table: pairs (verb, offset), ended by a zero;
                verb $FF covers everything not listed, and the offset is a
                single byte because an object is small

Format worked out from ScummVM engines/scumm/object.cpp and script.cpp
(GPL-2.0-or-later).
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import struct
import sys

from lfl import Index

# The Maniac Mansion verbs, as the game numbers them.
VERBI = {
    1: 'Open', 2: 'Close', 3: 'Give', 4: 'TurnOn', 5: 'TurnOff', 6: 'Fix',
    7: 'NewKid', 8: 'Unlock', 9: 'Push', 10: 'Pull', 11: 'Use', 12: 'Read',
    13: 'WalkTo', 14: 'PickUp', 15: 'WhatIs', 0xFF: 'default',
}


class Oggetto:
    def __init__(self, room, obim, obcd):
        self.room = room
        self.obim = obim
        self.obcd = obcd
        d = room
        self.numero = struct.unpack_from('<H', d, obcd + 4)[0]
        self.x = d[obcd + 7] * 8
        self.y = (d[obcd + 8] & 0x7F) * 8
        self.stato_genitore = 8 if d[obcd + 8] & 0x80 else 0
        self.w = d[obcd + 9] * 8
        self.genitore = d[obcd + 10]
        self.walk_x = d[obcd + 11] * 8
        self.walk_y = (d[obcd + 12] & 0x1F) * 8
        self.direzione = d[obcd + 13] & 7
        self.h = d[obcd + 13] & 0xF8
        self.nome = self._nome()
        self.verbi = self._verbi()

    def _nome(self):
        off = self.room[self.obcd + 14]
        if not off:
            return ''
        p = self.obcd + off
        out = []
        while p < len(self.room) and self.room[p]:
            c = self.room[p]
            out.append(chr(c) if 32 <= c < 127 else f"\\x{c:02X}")
            p += 1
        return ''.join(out)

    def _verbi(self):
        """{verb number: offset of its script inside the obcd}."""
        out = {}
        p = self.obcd + 15
        while p + 1 < len(self.room) and self.room[p]:
            out[self.room[p]] = self.room[p + 1]
            p += 2
        return out

    def script(self, verbo):
        """The bytecode starting at that verb's entry point."""
        off = self.verbi[verbo]
        return self.room[self.obcd + off:]

    def __repr__(self):
        verbi = ' '.join(VERBI.get(v, str(v)) for v in sorted(self.verbi))
        return (f"<oggetto {self.numero} \"{self.nome}\" "
                f"{self.w}x{self.h} a ({self.x},{self.y}) [{verbi}]>")


def oggetti(room):
    """Every object of an already-deciphered room."""
    n = room[20]
    base = 28
    out = []
    for i in range(n):
        obim = struct.unpack_from('<H', room, base + 2 * i)[0]
        obcd = struct.unpack_from('<H', room, base + 2 * n + 2 * i)[0]
        if not obcd or obcd + 16 > len(room):
            continue
        out.append(Oggetto(room, obim, obcd))
    return out


def main(argv):
    idx = Index(argv[1])
    solo = int(argv[2]) if len(argv) > 2 else None
    tot = 0
    for n in range(1, len(idx.rooms)):
        if solo and n != solo:
            continue
        try:
            room = idx.room_file(n)
        except Exception:
            continue
        og = oggetti(room)
        tot += len(og)
        if og:
            print(f"stanza {n}: {len(og)} oggetti")
            for o in og:
                print("   ", o)
    print(f"\n{tot} oggetti in tutto")


if __name__ == '__main__':
    main(sys.argv)
