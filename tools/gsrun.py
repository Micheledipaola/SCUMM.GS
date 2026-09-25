#!/usr/bin/env python3
"""gsrun.py - runs our S16 inside the emulator, with a fake toolbox.

It loads Merlin32's OMF file, stands up just enough Apple IIGS to get the
program going (Memory Manager, QuickDraw, Event Manager, clock) and serves
the GS/OS files by really reading them from the host disk.

What comes out:
  - the video memory saved as a PNG, to look at;
  - the strings the program drew;
  - a symbolic trace, if asked for, to see where it stopped.

Usage:
    gsrun.py <OMF> <folder with the .LFL files> [--passi N] [--png f.png]
             [--traccia N] [--da LABEL]
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import struct
import sys

from gs816 import CPU, Memoria, SHR

# Where the program and the blocks it asks for go
BASE_PROG = 0x020000
BASE_HEAP = 0x030000
STACK = 0xFE00          # the S register is sixteen bits: the stack lives in bank 0

EGA = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
       (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
       (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
       (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255)]


# ----------------------------------------------------------------------
def carica_omf(path, mem, base, salto_piu_uno=False):
    """Loads the first OMF segment and applies the relocations."""
    raw = open(path, 'rb').read()
    lunghezza = struct.unpack_from('<I', raw, 8)[0]
    disp_data = struct.unpack_from('<H', raw, 42)[0]
    p = disp_data
    corpo = bytearray(lunghezza)
    scritti = 0
    riloc = []
    while p < len(raw):
        op = raw[p]
        p += 1
        if op == 0x00:                      # END
            break
        elif 0x01 <= op <= 0xDF:            # CONST
            corpo[scritti:scritti + op] = raw[p:p + op]
            scritti += op
            p += op
        elif op == 0xF2:                    # LCONST
            n = struct.unpack_from('<I', raw, p)[0]
            p += 4
            corpo[scritti:scritti + n] = raw[p:p + n]
            scritti += n
            p += n
        elif op == 0xF1:                    # DS
            n = struct.unpack_from('<I', raw, p)[0]
            p += 4
            scritti += n
        elif op == 0xE2:                    # RELOC
            size, shift = raw[p], raw[p + 1]
            off = struct.unpack_from('<I', raw, p + 2)[0]
            sub = struct.unpack_from('<I', raw, p + 6)[0]
            p += 10
            riloc.append((size, shift, off, sub))
        elif op == 0xF5:                    # cRELOC
            size, shift = raw[p], raw[p + 1]
            off = struct.unpack_from('<H', raw, p + 2)[0]
            sub = struct.unpack_from('<H', raw, p + 4)[0]
            p += 6
            riloc.append((size, shift, off, sub))
        elif op == 0xF7:                    # SUPER: compressed relocations
            n = struct.unpack_from('<I', raw, p)[0]
            p += 4
            fine = p + n
            tipo = raw[p]
            p += 1
            if tipo > 1:
                raise RuntimeError("SUPER fra segmenti non gestito")
            size = 2 if tipo == 0 else 3
            pagina = 0
            while p < fine:
                b = raw[p]
                p += 1
                if b & 0x80:                # pages with nothing to fix up
                    pagina += (b & 0x7F) + (1 if salto_piu_uno else 0)
                    continue
                for _ in range(b + 1):
                    off = pagina * 256 + raw[p]
                    p += 1
                    dentro = int.from_bytes(corpo[off:off + size], 'little')
                    riloc.append((size, 0, off, dentro))
                pagina += 1
        elif op in (0xE3, 0xF6):            # INTERSEG: not needed here
            raise RuntimeError("segmenti multipli non gestiti")
        else:
            raise RuntimeError(f"record OMF ${op:02X} sconosciuto a {p-1}")

    for size, shift, off, sub in riloc:
        valore = base + sub
        if shift:
            spost = shift - 256 if shift > 127 else shift
            valore = valore >> -spost if spost < 0 else valore << spost
        for i in range(size):
            corpo[off + i] = (valore >> (8 * i)) & 0xFF

    mem.m[base:base + len(corpo)] = corpo
    return base, len(corpo)


def simboli(listato):
    """Label -> address, from Merlin32's listing."""
    out = {}
    if not os.path.exists(listato):
        return out
    for riga in open(listato, encoding='utf-8', errors='ignore'):
        if '|' not in riga:
            continue
        pezzi = riga.split('|')
        if len(pezzi) < 8:
            continue
        ind = pezzi[6].strip()
        testo = pezzi[7].rstrip('\n')
        if '/' not in ind:
            continue
        banco, _, indirizzo = ind.partition('/')
        indirizzo = indirizzo.split(':')[0].strip()
        try:
            addr = BASE_PROG + int(banco, 16) * 65536 + int(indirizzo, 16)
        except ValueError:
            continue
        # in the listing the source column has a single leading space:
        # strip it and a line starting with a letter is a label
        if testo[:1] == ' ':
            testo = testo[1:]
        if testo[:1].isalpha():
            nome = testo.split()[0]
            if nome[:1].isalpha() and nome not in out:
                out[nome] = addr
    return out


# ----------------------------------------------------------------------
class Mondo:
    """The fake IIGS: memory, handles, files, things drawn."""

    def __init__(self, cartella):
        self.mem = Memoria()
        self.cpu = CPU(self.mem)
        self.cartella = cartella
        self.cartella_salvataggi = os.environ.get(
            'SCUMM_SALVA', '/tmp/scumm-salva')
        self.prossimo = BASE_HEAP
        self.handle_next = 0x00E000
        self.scritte = []
        self.aperti = {}
        self.refnext = 1
        self.tick = 0
        # how many steps a tick is worth. On a real IIGS it is twelve
        # thousand (seven hundred thousand steps per second, sixty hertz).
        # Lowering it makes the game live faster: the script waits get
        # shorter and a test that takes six minutes to reach the end
        # takes a few seconds instead.
        self.passi_per_tick = 12000
        self.eventi = 0
        self.gsos = []
        self.clic = None
        self.mouse = (0, 0)              # where the pointer is now
        self.tasti = None

    # --- dynamic memory ---------------------------------------------------
    def alloca(self, quanti):
        """One block. Aligned to a bank to keep things tidy."""
        if quanti >= 0x8000:
            self.prossimo = (self.prossimo + 0xFFFF) & ~0xFFFF
        indirizzo = self.prossimo
        self.prossimo = (indirizzo + quanti + 0xFF) & ~0xFF
        return indirizzo

    def nuovo_handle(self, indirizzo):
        h = self.handle_next
        self.handle_next += 4
        self.mem.setw(h, indirizzo & 0xFFFF)
        self.mem.setw(h + 2, (indirizzo >> 16) & 0xFF)
        return h

    # --- stack ----------------------------------------------------------
    def pop16(self):
        return self.cpu.pop16()

    def pop32(self):
        return self.pop16() | (self.pop16() << 16)

    def metti16(self, v):
        """Writes a result into the space the caller pushed."""
        s = self.cpu.s
        self.mem.setw(s + 1, v)

    def metti32(self, v):
        s = self.cpu.s
        self.mem.setw(s + 1, v & 0xFFFF)
        self.mem.setw(s + 3, (v >> 16) & 0xFFFF)

    # --- toolbox ----------------------------------------------------------
    def tool(self, numero):
        c = self.cpu
        if numero in (0x0201, 0x0203, 0x0301, 0x0303, 0x0304, 0x0306,
                      0xCA04, 0x9004, 0x9104, 0x9204):
            return                                  # startups and shutdowns
        if numero == 0x0202:                        # MMStartUp
            self.metti16(0x1234)
            return
        if numero in (0x0302,):                     # MMShutDown(userID)
            self.pop16()
            return
        if numero == 0x0902:                        # NewHandle
            self.pop32()                            # position
            attr = self.pop16()
            self.pop16()                            # userID
            size = self.pop32()
            indirizzo = self.alloca(size)
            h = self.nuovo_handle(indirizzo)
            self.metti32(h)
            c.p &= ~0x01                            # carry clear: it worked
            return
        if numero == 0x1002:                        # DisposeHandle
            self.pop32()
            return
        if numero == 0x0204:                        # QDStartUp
            self.pop16(), self.pop16(), self.pop16(), self.pop16()
            return
        if numero == 0x0206:                        # EMStartUp
            for _ in range(7):
                self.pop16()
            return
        if numero == 0x0A06:                        # GetNextEvent
            rec = self.pop32()
            self.pop16()                            # the mask
            self.eventi += 1
            if self.tasti and self.cpu.passi >= self.tasti[0][0]:
                voce = self.tasti.pop(0)
                ch = voce[1]
                mod = voce[2] if len(voce) > 2 else 0
                if not self.tasti:
                    self.tasti = None
                self.mem.setw(rec, 3)               # keyDownEvt
                self.mem.setw(rec + 2, ord(ch))
                self.mem.setw(rec + 4, 0)
                self.mem.setw(rec + 14, mod)        # the Apple key and friends
                self.metti16(1)
                print(f"  [tasto] {ch!r} mod ${mod:04X} al passo {self.cpu.passi}")
                return
            if self.clic and self.cpu.passi >= self.clic[0][0]:
                _, x, y = self.clic.pop(0)
                if not self.clic:
                    self.clic = None
                self.mem.setw(rec, 1)               # mouseDownEvt
                self.mem.setw(rec + 2, 0)
                self.mem.setw(rec + 4, 0)
                self.mem.setw(rec + 6, 0)
                self.mem.setw(rec + 8, 0)
                self.mem.setw(rec + 10, y)          # the point: the vertical
                self.mem.setw(rec + 12, x)          # comes first
                self.mem.setw(rec + 14, 0)          # no modifier keys
                self.mouse = (x, y)
                self.metti16(1)
                print(f"  [clic] a ({x},{y}) al passo {self.cpu.passi}")
                return
            self.metti16(0)
            return
        if numero == 0x1104:                        # SetCursor(pointer)
            self.pop32()
            return
        if numero == 0x0C06:                        # GetMouse(pointer)
            p = self.pop32()
            x, y = self.mouse
            self.mem.setw(p, y)                     # the vertical comes first
            self.mem.setw(p + 2, x)
            return
        if numero in (0xA004, 0xA204):              # Set*Color
            self.pop16()
            return
        if numero == 0x3A04:                        # MoveTo
            self.pop16(), self.pop16()
            return
        if numero == 0xA604:                        # DrawCString
            p = self.pop32()
            testo = []
            while True:
                b = self.mem.b(p)
                if not b:
                    break
                testo.append(chr(b))
                p += 1
            self.scritte.append(''.join(testo))
            return
        if numero == 0x2503:                        # GetTick
            # A IIGS does about seven hundred thousand steps per second and
            # the counter runs at sixty hertz: so one tick every twelve
            # thousand steps. With one tick per call the delays lasted only a
            # few frames, and the game behaved unlike the real machine.
            self.tick = self.cpu.passi // self.passi_per_tick
            self.metti32(self.tick)
            return
        raise RuntimeError(f"tool ${numero:04X} non previsto {self.cpu.dove()}")

    # --- GS/OS --------------------------------------------------------
    def percorso(self, p):
        n = self.mem.w(p)
        nome = ''.join(chr(self.mem.b(p + 2 + i)) for i in range(n))
        return nome

    def gsos_call(self, chiamata, parm):
        c = self.cpu
        m = self.mem
        if chiamata == 0x2010:                      # OpenGS
            if os.environ.get('GSDEBUG'):
                print(f"  [GS/OS] parm=${parm:06X} refNum=${m.w(parm+2):04X} "
                      f"path=${m.l(parm+4):06X} "
                      f"bytes={bytes(m.m[parm:parm+8]).hex(' ')}")
            nome = self.percorso(m.l(parm + 4))
            self.gsos.append(f"Open {nome}")
            vero = self.trova(nome)
            if os.environ.get('GSDEBUG'):
                print(f"  [GS/OS] Open {nome!r} -> {vero!r}")
            if vero is None:
                c.p |= 0x01
                c.a = 0x0046                        # file not found
                return
            ref = self.refnext
            self.refnext += 1
            scrivibile = vero if self.salvataggio(nome) is not None else None
            self.aperti[ref] = [open(vero, 'rb').read(), 0, scrivibile]
            m.setw(parm + 2, ref)
            c.p &= ~0x01
            return
        if chiamata == 0x2001:                      # CreateGS
            nome = self.percorso(m.l(parm + 2))
            vero = self.salvataggio(nome)
            if vero is None:
                c.p |= 0x01; c.a = 0x004E   # access denied
                return
            open(vero, 'wb').close()
            c.p &= ~0x01
            return
        if chiamata == 0x2002:                      # DestroyGS
            nome = self.percorso(m.l(parm + 2))
            vero = self.salvataggio(nome)
            if vero is not None and os.path.exists(vero):
                os.remove(vero)
                c.p &= ~0x01
            else:
                c.p |= 0x01; c.a = 0x0046
            return
        if chiamata == 0x2013:                      # WriteGS
            ref = m.w(parm + 2)
            buf = m.l(parm + 4)
            quanti = m.l(parm + 8)
            f = self.aperti[ref]
            f[0] = f[0][:f[1]] + bytes(m.m[buf:buf + quanti]) + f[0][f[1] + quanti:]
            f[1] += quanti
            if f[2] is not None:
                open(f[2], 'wb').write(f[0])
            m.setw(parm + 12, quanti & 0xFFFF)
            m.setw(parm + 14, quanti >> 16)
            c.p &= ~0x01
            return
        if chiamata == 0x2012:                      # ReadGS
            ref = m.w(parm + 2)
            buf = m.l(parm + 4)
            quanti = m.l(parm + 8)
            dati, pos = self.aperti[ref][0], self.aperti[ref][1]
            pezzo = dati[pos:pos + quanti]
            self.aperti[ref][1] = pos + len(pezzo)
            m.m[buf:buf + len(pezzo)] = pezzo
            m.setw(parm + 12, len(pezzo) & 0xFFFF)
            m.setw(parm + 14, len(pezzo) >> 16)
            if len(pezzo) < quanti:
                c.p |= 0x01
                c.a = 0x004C                        # end of file
            else:
                c.p &= ~0x01
            return
        if chiamata == 0x2014:                      # CloseGS
            ref = m.w(parm + 2)
            self.aperti.pop(ref, None)
            c.p &= ~0x01
            return
        if chiamata == 0x2016:                      # SetMarkGS
            ref = m.w(parm + 2)
            pos = m.l(parm + 6)
            if ref in self.aperti:
                self.aperti[ref][1] = pos
            c.p &= ~0x01
            return
        if chiamata == 0x2029:                      # QuitGS
            raise SystemExit
        raise RuntimeError(f"chiamata GS/OS ${chiamata:04X} non prevista")

    def salvataggio(self, nome):
        """The real file of a saved game, which lives in a separate folder."""
        pezzi = [p for p in nome.replace(':', '/').split('/') if p]
        base = pezzi[-1].upper() if pezzi else ''
        if not base.startswith('SAVE'):
            return None
        os.makedirs(self.cartella_salvataggi, exist_ok=True)
        return os.path.join(self.cartella_salvataggi, base)

    def trova(self, nome):
        """From 'MM/L00.LFL' (or '1/MM/L00.LFL') to the real file."""
        s = self.salvataggio(nome)
        if s is not None:
            return s if os.path.exists(s) else None
        pezzi = [p for p in nome.replace(':', '/').split('/') if p]
        if pezzi and pezzi[0].isdigit():
            pezzi = pezzi[1:]
        if pezzi and pezzi[0].upper() == 'MM':
            pezzi = pezzi[1:]
        if not pezzi:
            return None
        base = pezzi[-1].upper()
        if base.startswith('L') and base.endswith('.LFL'):
            vero = os.path.join(self.cartella, base[1:])
            return vero if os.path.exists(vero) else None
        vero = os.path.join(self.cartella, base)
        return vero if os.path.exists(vero) else None


# ----------------------------------------------------------------------
def salva_png(mem, path):
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        return False
    pixel = np.frombuffer(bytes(mem.m[SHR:SHR + 32000]), np.uint8)
    pixel = pixel.reshape(200, 160)
    alto = pixel >> 4
    basso = pixel & 15
    idx = np.empty((200, 320), np.uint8)
    idx[:, 0::2] = alto
    idx[:, 1::2] = basso
    # the real palette lives in video memory, one per scanline
    scb = mem.m[SHR + 0x7D00:SHR + 0x7D00 + 200]
    out = np.zeros((200, 320, 3), np.uint8)
    for y in range(200):
        pal = (scb[y] & 0x0F) * 32 + SHR + 0x7E00
        colori = []
        for i in range(16):
            w = mem.w(pal + i * 2)
            colori.append((((w >> 8) & 0xF) * 17, ((w >> 4) & 0xF) * 17,
                           (w & 0xF) * 17))
        tav = np.array(colori, np.uint8)
        out[y] = tav[idx[y]]
    Image.fromarray(out).save(path)
    return True


def main(argv):
    omf = argv[1]
    cartella = argv[2]
    passi_max = 60_000_000
    png = 'schermo.png'
    traccia_n = 0
    clic = None
    da = None
    i = 3
    while i < len(argv):
        if argv[i] == '--passi':
            passi_max = int(argv[i + 1]); i += 2
        elif argv[i] == '--png':
            png = argv[i + 1]; i += 2
        elif argv[i] == '--traccia':
            traccia_n = int(argv[i + 1]); i += 2
        elif argv[i] == '--clic':
            pezzi = argv[i + 1].split(',')
            if clic is None:
                clic = []
            clic.append((int(pezzi[2]), int(pezzi[0]), int(pezzi[1])))
            clic.sort(); i += 2
        elif argv[i] == '--da':
            da = argv[i + 1]; i += 2
        else:
            i += 1

    mondo = Mondo(cartella)
    mondo.clic = clic
    mem, cpu = mondo.mem, mondo.cpu
    base, quanti = carica_omf(omf, mem, BASE_PROG)
    cpu.simboli = simboli(os.path.splitext(omf)[0] + '_Output.txt')
    print(f"caricato {quanti} byte a ${base:06X}, "
          f"{len(cpu.simboli)} etichette")

    cpu.pbr = base >> 16
    cpu.pc = base & 0xFFFF
    cpu.s = STACK
    cpu.e = True
    cpu.p = 0x34

    # the trace: from the chosen label onwards, for N instructions
    stato = {'acceso': da is None, 'rimasti': traccia_n}
    indirizzo_da = cpu.simboli.get(da) if da else None

    def traccia(c):
        pc = (c.pbr << 16) | c.pc
        if indirizzo_da is not None and pc == indirizzo_da:
            stato['acceso'] = True
        if stato['acceso'] and stato['rimasti'] > 0:
            stato['rimasti'] -= 1
            print(f"{pc:06X} {c.mem.b(pc):02X} A={c.a:04X} X={c.x:04X} "
                  f"Y={c.y:04X} P={c.p:02X} {c.dove()}")

    if traccia_n:
        cpu.tracciamento = traccia

    conteggio = {}
    if '--profilo' in argv:
        def prof(c):
            pc = (c.pbr << 16) | c.pc
            conteggio[pc] = conteggio.get(pc, 0) + 1
        cpu.tracciamento = prof

    motivo = 'passi finiti'
    try:
        while cpu.passi < passi_max:
            pc = (cpu.pbr << 16) | cpu.pc
            if pc == 0xE10000:                      # toolbox call
                numero = cpu.x
                ritorno = cpu.pop16()
                banco = cpu.pop8()
                mondo.tool(numero)
                cpu.pbr, cpu.pc = banco, (ritorno + 1) & 0xFFFF
                continue
            if pc == 0xE100A8:                      # GS/OS call
                ritorno = cpu.pop16()
                banco = cpu.pop8()
                indirizzo = (banco << 16) | ((ritorno + 1) & 0xFFFF)
                chiamata = mem.w(indirizzo)
                parm = mem.l(indirizzo + 2)
                mondo.gsos_call(chiamata, parm)
                cpu.pbr = banco
                cpu.pc = (ritorno + 7) & 0xFFFF
                continue
            cpu.passo()
    except SystemExit:
        motivo = 'il programma e\' uscito (Quit)'
    except Exception as e:
        motivo = f"ERRORE: {e}"

    print(f"\nfermato dopo {cpu.passi} istruzioni: {motivo}")
    print(f"file aperti da GS/OS: {mondo.gsos[:8]}")
    if conteggio:
        print("dove passa il tempo:")
        for pc, n in sorted(conteggio.items(), key=lambda x: -x[1])[:12]:
            cpu.pbr, cpu.pc = pc >> 16, pc & 0xFFFF
            print(f"  {pc:06X} x{n:<8} {cpu.dove()}")
    if mondo.scritte:
        print(f"scritte a schermo: {mondo.scritte[-6:]}")
    if salva_png(mem, png):
        print(f"schermo -> {png}")


if __name__ == '__main__':
    main(sys.argv)
