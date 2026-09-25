#!/usr/bin/env python3
"""font_mm.py - lift the game's own font out of its DOS executable.

SCUMM V2 keeps no font in the .LFL files. On DOS it sits inside
MANIAC.EXE as a plain bitmap table: eight bytes per character, one byte
per row, leftmost pixel in bit seven - the same shape the interpreter
wants. The table starts at file offset $108FD and begins at character
48, the digit zero; below that the same area is x86 code, not glyphs.

So this script takes what is really there - digits, capitals, lowercase
and the symbols in between - and fills everything under 48 (the space,
the punctuation) from the font drawn for this project, which is what the
interpreter uses anyway when nobody has run this script.

    python3 tools/font_mm.py /path/to/MANIAC.EXE > src/fontdata.s

The result is game data. It stays out of the repository, and .gitignore
is set up to keep it out.
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from font_orig import byte_glifo

OFFSET = 0x108FD          # where the table starts in the file
PRIMO = 48                # and which character it starts at


def leggi(percorso):
    """The glyphs the executable really holds, by character number."""
    dati = open(percorso, 'rb').read()
    fine = OFFSET + (127 - PRIMO + 1) * 8
    if len(dati) < fine:
        raise SystemExit(
            f"{percorso} is {len(dati)} bytes: too short for a font table at "
            f"${OFFSET:X}. Is this the DOS MANIAC.EXE?")
    out = {}
    for c in range(PRIMO, 128):
        p = OFFSET + (c - PRIMO) * 8
        out[c] = list(dati[p:p + 8])
    return out


def sembra_un_font(g):
    """A cheap check that we are looking at glyphs and not at code.

    Text drawn in an eight by eight cell leaves room under the letters and
    after them, so in a real table the last row is almost always empty and
    the low bits are almost always clear. Machine code has no such habit.
    """
    ultime = sum(1 for c in range(65, 91) if g[c][7] == 0)
    vuoti = sum(1 for c in range(65, 91) if not any(g[c]))
    return ultime >= 20 and vuoti == 0


def main(argv):
    if len(argv) < 2:
        raise SystemExit(
            "usage: font_mm.py /path/to/MANIAC.EXE > src/fontdata.s")
    g = leggi(argv[1])
    if not sembra_un_font(g):
        print("warning: what is at ${:X} does not look like a font table. "
              "The offset is right for the release this was written against; "
              "another build of the game may put it elsewhere."
              .format(OFFSET), file=sys.stderr)

    print("* fontdata.s - the game's own 8x8 font.")
    print("*")
    print("* Lifted out of MANIAC.EXE by tools/font_mm.py. This is game data:")
    print("* it is not distributed with this project, and .gitignore keeps it")
    print("* out of the repository.")
    print("*")
    print(f"* The table in the executable starts at ${OFFSET:X}, at character")
    print(f"* {PRIMO}. Everything below that is x86 code there, so the space and")
    print("* the punctuation come from the font drawn for this project.")
    print("FontData         anop")
    for c in range(128):
        if c in g:
            b = g[c]
            da = "game"
        else:
            b = byte_glifo(chr(c)) if 32 <= c < 127 else [0] * 8
            da = "drawn"
        nome = chr(c) if 33 <= c < 127 else f"${c:02X}"
        print("                 hex   " + ''.join(f"{x:02X}" for x in b)
              + f"   ; {nome} ({da})")


if __name__ == '__main__':
    main(sys.argv)
