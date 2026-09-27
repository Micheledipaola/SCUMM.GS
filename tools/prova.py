#!/usr/bin/env python3
"""prova.py - make the interpreter play inside the emulator, quickly.

The whole intro on the fake IIGS took six minutes, because script waits
count ticks and one tick is twelve thousand steps. Here the counter runs
faster (`veloce`), so the game lives the same story in a few seconds, and
clicks are given when they are needed instead of at a guessed step count.

    from prova import Partita
    p = Partita()
    p.corri(fino=lambda p: p.var('CurRoom') == 45)
    p.clicca(76, 100)
    ...
    p.png('/tmp/screen.png')
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gsrun import (BASE_PROG, STACK, Mondo, carica_omf, salva_png, simboli)

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(QUI)


class Partita:
    def __init__(self, veloce=400, dati=None, omf=None, listato=None):
        self.mondo = Mondo(dati or os.path.join(RADICE, 'data'))
        self.mondo.passi_per_tick = veloce
        self.mem = self.mondo.mem
        self.cpu = self.mondo.cpu
        base, _ = carica_omf(omf or os.path.join(RADICE, 'src', 'SCUMM'),
                             self.mem, BASE_PROG)
        if listato is None:
            for cand in (
                    os.path.join(RADICE, 'src', 'SCUMM_S01_Segment1_Output.txt'),
                    os.path.join(RADICE, 'src', 'SCUMM_Output.txt')):
                if os.path.exists(cand):
                    listato = cand
                    break
        self.cpu.simboli = simboli(listato or
                                   os.path.join(RADICE, 'src',
                                                'SCUMM_Output.txt'))
        self.S = self.cpu.simboli
        self.cpu.pbr = base >> 16
        self.cpu.pc = base & 0xFFFF
        self.cpu.s = STACK
        self.cpu.e = True
        self.cpu.p = 0x34
        self.errore = None

    # --- reading the interpreter's memory ------------------------------
    def var(self, nome, indice=0):
        """The value of one of the interpreter's variables, by name."""
        return self.mem.w(self.S[nome] + 2 * indice)

    def scumm(self, n):
        """One of the game's variables (Vars)."""
        return self.mem.w(self.S['Vars'] + 2 * n)

    # --- running --------------------------------------------------------
    def corri(self, passi=None, fino=None, guarda=None, ogni=20000):
        """Run until `fino` is true, or for that many steps.

        `guarda` is called every `ogni` steps with the game, so you can
        print whatever you want to follow.
        """
        cpu, mem, mondo = self.cpu, self.mem, self.mondo
        limite = cpu.passi + (passi if passi is not None else 40_000_000)
        try:
            while cpu.passi < limite:
                pc = (cpu.pbr << 16) | cpu.pc
                if pc == 0xE10000:
                    k = cpu.x
                    r = cpu.pop16()
                    b = cpu.pop8()
                    mondo.tool(k)
                    cpu.pbr, cpu.pc = b, (r + 1) & 0xFFFF
                    continue
                if pc == 0xE100A8:
                    r = cpu.pop16()
                    b = cpu.pop8()
                    i = (b << 16) | ((r + 1) & 0xFFFF)
                    mondo.gsos_call(mem.w(i), mem.l(i + 2))
                    cpu.pbr, cpu.pc = b, (r + 7) & 0xFFFF
                    continue
                cpu.passo()
                if cpu.passi % ogni == 0:
                    if guarda is not None:
                        guarda(self)
                    if fino is not None and fino(self):
                        return True
        except Exception as e:                       # noqa: BLE001
            self.errore = f"{e} {cpu.dove()}"
            print("stop:", self.errore, flush=True)
        return False

    # --- input ----------------------------------------------------------
    def clicca(self, x, y, e_poi=200000, attesa=20_000_000):
        """A click as soon as the game looks at events again.

        While loading, and during some waits, the interpreter does not
        call GetNextEvent: simply queueing the click and running on for a
        while would lose it. So we wait until it is really picked up, and
        only then let the game run.
        """
        self.mondo.clic = [(self.cpu.passi, x, y)]
        fine = self.cpu.passi + attesa
        while self.mondo.clic and self.cpu.passi < fine:
            if not self.corri(passi=200000):
                if self.errore:
                    return False
        self.corri(passi=e_poi)
        return self.mondo.clic is None

    def tasto(self, ch, e_poi=200000, mela=False):
        self.mondo.tasti = [(self.cpu.passi, ch, 0x0100 if mela else 0)]
        self.corri(passi=e_poi)

    def muovi(self, x, y):
        """Move the pointer without pressing (for verbs that light up)."""
        self.mondo.mouse = (x, y)

    def verbi(self):
        """{verb id: (x, y) on screen}, as the game placed them."""
        out = {}
        for i in range(16):
            v = self.var('VerbId', i)
            if v:
                out[v] = (self.var('VerbX', i), self.var('VerbY', i))
        return out

    def clicca_verbo(self, id_verbo, e_poi=300000):
        v = self.verbi()
        if id_verbo not in v:
            raise KeyError(f"verbo {id_verbo} non installato: {sorted(v)}")
        x, y = v[id_verbo]
        self.clicca(x + 4, y + 3, e_poi=e_poi)
        return True

    def png(self, path):
        salva_png(self.mem, path)
        return path


def intro(p=None, veloce=400, ragazzi=((76, 116), (116, 116), (156, 116)),
          start=(290, 76), racconta=False):
    """From the title to room 44, through the choice of the kids."""
    p = p or Partita(veloce=veloce)
    t0 = time.time()
    p.corri(fino=lambda p: p.var('CurRoom') == 45)
    for x, y in ragazzi:
        p.clicca(x, y, e_poi=400000)
    p.clicca(*start, e_poi=400000)
    p.corri(fino=lambda p: p.var('CurRoom') == 44, passi=30_000_000)
    if racconta:
        print(f"stanza {p.var('CurRoom')} in {time.time() - t0:.0f}s "
              f"({p.cpu.passi / 1e6:.1f}M passi)")
    return p


if __name__ == '__main__':
    p = intro(racconta=True)
    p.png('/tmp/prova.png')
    print('schermo -> /tmp/prova.png')
