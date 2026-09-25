#!/usr/bin/env python3
"""render2.py - draws a room the way the game would see it.

It is there to check, here and before a single line of 65816 is written,
that the data model is right: the background, the objects on top of it,
and which of them are lit at the start of a game.

The object pictures (OBIM) use exactly the same column-wise compression as
the background, only with width and height taken from the object's
description. An object is drawn if bit 8 of its state is set, which at the
start sits in the high nibble of the byte in 00.LFL (the low nibble says
who owns the object).

Usage: render2.py <LFL folder> <room number> <file.png>
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import sys

import numpy as np
from PIL import Image

from lfl import Index
from obj2 import oggetti
from room2 import EGA, Room

STATO_ACCESO = 8          # kObjectStateIntrinsic in ScummVM
SHIFT_STATO = 4           # in the 00.LFL byte: state high, owner low


def decomprimi(data, src, w, h):
    """V2's column-wise compression, on any piece.

    It is the same as room2.background(): kept separate here because for
    objects the starting point and the sizes come from somewhere else.
    """
    out = np.zeros((h, w), np.uint8)
    colonna = [0] * h
    run = 0
    color = 0
    dither = False
    for x in range(w):
        for y in range(h):
            if run == 0:
                b = data[src]
                src += 1
                if b & 0x80:
                    run = b & 0x7F
                    dither = True
                else:
                    run = b >> 4
                    dither = False
                color = b & 0x0F
                if run == 0:
                    run = data[src]
                    src += 1
            if not dither:
                colonna[y] = color
            out[y, x] = colonna[y]
            run -= 1
    return out


def disegna(idx, n):
    """Room n with the lit objects on top. Returns an array of indices."""
    dati = idx.room_file(n)
    r = Room(dati)
    quadro = decomprimi(dati, r.img_offset, r.width, r.height)

    # The game draws them last to first, so the first stays on top.
    for o in reversed(oggetti(dati)):
        stato = idx.object_flags[o.numero] >> SHIFT_STATO \
            if o.numero < len(idx.object_flags) else 0
        if not (stato & STATO_ACCESO):
            continue
        if not o.obim or not o.w or not o.h:
            continue
        try:
            img = decomprimi(dati, o.obim, o.w, o.h)
        except IndexError:
            print(f"  oggetto {o.numero} \"{o.nome}\": immagine incompleta")
            continue
        x, y = o.x, o.y
        h = min(o.h, r.height - y)
        w = min(o.w, r.width - x)
        if h <= 0 or w <= 0:
            continue
        quadro[y:y + h, x:x + w] = img[:h, :w]
    return quadro


def salva(quadro, path, scala=1):
    tav = np.array(EGA, np.uint8)
    im = Image.fromarray(tav[quadro])
    if scala != 1:
        im = im.resize((im.width * scala, im.height * scala), Image.NEAREST)
    im.save(path)
    return im


if __name__ == '__main__':
    idx = Index(sys.argv[1])
    n = int(sys.argv[2])
    quadro = disegna(idx, n)
    im = salva(quadro, sys.argv[3])
    print(f"stanza {n}: {im.width}x{im.height} -> {sys.argv[3]}")
