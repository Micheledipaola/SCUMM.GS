#!/usr/bin/env python3
"""adf.py - read files out of an Amiga floppy image (ADF).

Just enough of the Old File System to get the game's files off the disks
the Amiga release came on: the root block holds a hash table of 72
entries, each leading to a chain of file headers, and a file's contents
are a chain of data blocks each carrying 488 bytes after a 24-byte
header. The Fast File System has no such header, and this reader handles
both by looking at the boot block.

    python3 tools/adf.py disk.adf                  list what is on it
    python3 tools/adf.py disk.adf out/             write it all out there
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import struct
import sys

BLOCCO = 512
RADICE = 880                      # the root block of a double density disk
T_LISTA = 2                       # a header block
ST_FILE = -3                      # ... of a file
ST_DIR = 2                        # ... of a directory


class Adf:
    def __init__(self, percorso):
        self.d = open(percorso, 'rb').read()
        if self.d[:3] != b'DOS':
            raise ValueError(f"{percorso}: not an Amiga filesystem")
        self.ffs = bool(self.d[3] & 1)

    def blocco(self, n):
        return self.d[n * BLOCCO:(n + 1) * BLOCCO]

    def _long(self, b, off):
        return struct.unpack_from('>I', b, off)[0]

    def _slong(self, b, off):
        return struct.unpack_from('>i', b, off)[0]

    def nome(self, b):
        n = b[432]
        return b[433:433 + n].decode('latin1')

    def voci(self, blocco_dir=RADICE, prefisso=''):
        """Every file under that directory, as (name, block, size)."""
        b = self.blocco(blocco_dir)
        out = []
        for i in range(72):                     # the hash table
            n = self._long(b, 24 + 4 * i)
            while n:
                h = self.blocco(n)
                st = self._slong(h, 508)
                nome = prefisso + self.nome(h)
                if st == ST_FILE:
                    out.append((nome, n, self._long(h, 324)))
                elif st == ST_DIR:
                    out += self.voci(n, nome + '/')
                n = self._long(h, 496)          # the next one in the chain
        return sorted(out)

    def leggi(self, blocco_file):
        """The contents of the file whose header block that is."""
        h = self.blocco(blocco_file)
        quanti = self._long(h, 324)
        out = bytearray()
        if self.ffs:
            # no header on the data blocks: the pointers are in the header,
            # last first, and carry on into the extension blocks
            testa = blocco_file
            while testa:
                b = self.blocco(testa)
                usati = self._long(b, 8)
                for i in range(usati):
                    p = self._long(b, 24 + 4 * (71 - i))
                    out += self.blocco(p)
                testa = self._long(b, 504)      # extension
        else:
            n = self._long(h, 16)               # first data block
            while n and len(out) < quanti:
                b = self.blocco(n)
                lung = self._long(b, 12)
                out += b[24:24 + lung]
                n = self._long(b, 16)           # next data block
        return bytes(out[:quanti])


def main(argv):
    if len(argv) < 2:
        raise SystemExit("usage: adf.py disk.adf [out/]")
    a = Adf(argv[1])
    voci = a.voci()
    if len(argv) < 3:
        print(f"{'FFS' if a.ffs else 'OFS'}, {len(voci)} files")
        for nome, blk, dim in voci:
            print(f"  {nome:<20} {dim:>8}")
        return
    os.makedirs(argv[2], exist_ok=True)
    for nome, blk, dim in voci:
        dati = a.leggi(blk)
        fuori = os.path.join(argv[2], nome.replace('/', '_'))
        with open(fuori, 'wb') as f:
            f.write(dati)
        stato = "ok" if len(dati) == dim else f"!! {len(dati)} of {dim}"
        print(f"  {nome:<20} {dim:>8}  {stato}")


if __name__ == '__main__':
    main(sys.argv)
