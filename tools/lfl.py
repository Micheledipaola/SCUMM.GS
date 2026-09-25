#!/usr/bin/env python3
"""lfl.py - reads the files of a SCUMM V2 game (Maniac Mansion, Zak).

The data lives in .LFL files, every byte inverted by an xor with $FF.
00.LFL is the index; the NN.LFL files are the rooms, and inside each room
sit the scripts, costumes and sounds that belong to it.

Index (00.LFL), after the xor:

    +0   word   signature: $0100 for the "enhanced" V2 (Maniac Mansion and
                Zak for DOS); $0132 for the C64 version, $0032 for Apple II
    +2   word   how many global objects, each followed by one byte
    then byte   how many rooms,    each followed by three bytes
    then byte   how many costumes, each followed by three bytes
    then byte   how many scripts,  each followed by three bytes
    then byte   how many sounds,   each followed by three bytes

The three-byte tables say, for every resource, which room it lives in (one
byte) and at what offset inside that file (a word).

Room (NN.LFL), after the xor:

    +4   word   width in pixels
    +6   word   height in pixels
    +$0A word   offset of the background picture

Format worked out from ScummVM engines/scumm (GPL-2.0-or-later).
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import struct

MAGIC_V2 = 0x0100          # Maniac Mansion and Zak for DOS
MAGIC_C64 = 0x0132
MAGIC_APPLE2 = 0x0032
XOR = 0xFF


def load(path):
    """The contents of a .LFL, already deciphered."""
    raw = open(path, 'rb').read()
    return bytes(b ^ XOR for b in raw)


class ResTable:
    """Where every resource lives: room and position inside the file."""

    def __init__(self, rooms, offsets):
        self.rooms = rooms
        self.offsets = offsets

    def __len__(self):
        return len(self.rooms)

    def __repr__(self):
        return f"<{len(self.rooms)} risorse>"


class Index:
    def __init__(self, folder):
        self.folder = folder
        data = load(self._path(0))
        self.data = data
        self.magic = struct.unpack('<H', data[0:2])[0]
        if self.magic != MAGIC_V2:
            raise ValueError(
                f"firma ${self.magic:04X}: questa non e' la V2 per DOS "
                f"(sarebbe $0100)")

        p = 2
        n_obj = struct.unpack('<H', data[p:p + 2])[0]
        p += 2
        self.object_flags = data[p:p + n_obj]
        p += n_obj

        self.rooms, p = self._table(data, p)
        self.costumes, p = self._table(data, p)
        self.scripts, p = self._table(data, p)
        self.sounds, p = self._table(data, p)

    @staticmethod
    def _table(data, p):
        """One block: how many resources, then room and offset for each."""
        n = data[p]
        p += 1
        rooms = list(data[p:p + n])
        p += n
        offs = list(struct.unpack(f'<{n}H', data[p:p + n * 2]))
        p += n * 2
        return ResTable(rooms, offs), p

    def _path(self, n):
        for name in (f"{n:02d}.LFL", f"{n:02d}.lfl"):
            full = os.path.join(self.folder, name)
            if os.path.exists(full):
                return full
        raise FileNotFoundError(f"{n:02d}.LFL non trovato in {self.folder}")

    def room_file(self, n):
        """The deciphered contents of room n's file."""
        return load(self._path(n))

    def summary(self):
        return (f"firma ${self.magic:04X}, {len(self.object_flags)} oggetti, "
                f"{len(self.rooms)} stanze, {len(self.costumes)} costumi, "
                f"{len(self.scripts)} script, {len(self.sounds)} suoni")


if __name__ == '__main__':
    import sys
    idx = Index(sys.argv[1] if len(sys.argv) > 1 else '.')
    print(idx.summary())
