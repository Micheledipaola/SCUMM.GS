#!/usr/bin/env python3
"""font_mm.py - find the game's own font inside one of its programs.

SCUMM V2 keeps no font in the .LFL files: it sits inside the program,
different for every machine the game was released on. So rather than
hard-coding one offset this looks for the table, which is easy to
recognise once you know what you are looking at.

A font drawn in an eight by eight cell leaves room under the letters and
after them, so in a real table almost every capital has an empty last
row and clear low bits, and no letter is blank. Machine code has no such
habit. Sliding that test over the file finds the table in seconds, and
the same test works whatever release you have - it was written against
the DOS MANIAC.EXE, where the table starts at $108FD and at character
48, and it finds the Amiga one at $1890C and at character 32 without
being told.

    python3 tools/font_mm.py /path/to/MANIAC.EXE > src/fontdata.s
    python3 tools/font_mm.py /path/to/Maniac    > src/fontdata.s

The Amiga program is the file called "Maniac" on the first floppy;
tools/adf.py gets it off the disk image. Whatever the source, the result
is game data: it stays out of the repository, and .gitignore keeps it
out. Characters the table does not reach - on DOS everything below 48 is
x86 code, not glyphs - are filled from the font drawn for this project.
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from font_orig import byte_glifo

INIZI = (32, 48)          # where a table is worth trying from


def glifo(d, off, primo, c):
    p = off + (c - primo) * 8
    return d[p:p + 8]


def punteggio(d, off, primo):
    """How much the bytes at off look like a font that starts at `primo`."""
    if off + (128 - primo) * 8 > len(d):
        return -1
    lettere = [c for c in list(range(65, 91)) + list(range(48, 58))
               if c >= primo]
    s = 0
    for c in lettere:
        g = glifo(d, off, primo, c)
        if not any(g):
            return -1                       # no letter is blank
        if g[7] == 0:
            s += 2                          # room under it
        if all(b & 0x01 == 0 for b in g):
            s += 1                          # and after it
    if primo <= 32 and any(glifo(d, off, primo, 32)):
        return -1                           # the space is blank
    return s


def cerca(d):
    """The best place in the file, as (score, offset, first character)."""
    meglio = (-1, 0, 32)
    for primo in INIZI:
        for off in range(0, len(d) - (128 - primo) * 8):
            s = punteggio(d, off, primo)
            if s > meglio[0]:
                meglio = (s, off, primo)
    return meglio


def main(argv):
    if len(argv) < 2:
        raise SystemExit(
            "usage: font_mm.py /path/to/the/game/program > src/fontdata.s")
    d = open(argv[1], 'rb').read()
    s, off, primo = cerca(d)
    # A real table scores about four per letter; code never comes close.
    if s < 80:
        raise SystemExit(
            f"no font table found in {argv[1]} (best guess scored {s}). "
            f"Is this the game's program? On DOS it is MANIAC.EXE, on the "
            f"Amiga the file called Maniac on the first floppy.")
    print(f"found at ${off:X}, from character {primo}, score {s}",
          file=sys.stderr)

    print("* fontdata.s - the game's own 8x8 font.")
    print("*")
    print(f"* Found by tools/font_mm.py in {os.path.basename(argv[1])}, at")
    print(f"* offset ${off:X}, starting at character {primo}. This is game")
    print("* data: it is not distributed with this project, and .gitignore")
    print("* keeps it out of the repository.")
    if primo > 32:
        print("*")
        print(f"* The table begins at character {primo}, so the space and the")
        print("* punctuation below it come from the font drawn for this")
        print("* project instead.")
    print("FontData         anop")
    for c in range(128):
        if c >= primo:
            b = list(glifo(d, off, primo, c))
            da = "game"
        else:
            b = byte_glifo(chr(c)) if 32 <= c < 127 else [0] * 8
            da = "drawn"
        nome = chr(c) if 33 <= c < 127 else f"${c:02X}"
        print("                 hex   " + ''.join(f"{x:02X}" for x in b)
              + f"   ; {nome} ({da})")


if __name__ == '__main__':
    main(sys.argv)
