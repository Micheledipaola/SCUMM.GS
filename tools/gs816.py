#!/usr/bin/env python3
"""gs816.py - a 65816 in Python, just enough to run our S16.

It is not an Apple IIGS emulator: it is a test bench. It loads the OMF file
Merlin32 produces, runs the code, fakes the toolbox and GS/OS calls (the
real files are read from the host disk), and at the end hands over the
32000 bytes of video memory so they can be looked at as a picture.

It serves one purpose, but an important one: finding mistakes here in a few
seconds instead of sending out one disk at a time and waiting for somebody
to try it.

Usage:
    gs816.py <OMF file> <MM folder> [--passi N] [--png out.png]
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import struct
import sys

# ----------------------------------------------------------------------
# Memory: sixteen flat megabytes. The super hi-res screen is at $E12000.
SHR = 0xE12000
MEMSIZE = 1 << 24


class Ferma(Exception):
    """The program called Quit."""


class Memoria:
    """Flat RAM, plus the three pieces of IIGS plumbing the fast blit needs.

    Shadowing: with bit 3 of $C035 clear, every write to $2000-$9FFF of
    bank $00 or $01 is copied by the hardware into the same offset of
    $E0 or $E1.  The super hi-res screen lives in $E1, so writing into
    bank $01 paints the screen.

    RAMRD / RAMWRT ($C003/$C002 and $C005/$C004): the old IIe switches.
    With them on, reads and writes to $0200-$BFFF of bank $00 are served
    by bank $01 instead.  Since the stack and the direct page are always
    bank $00 addresses, this is the only way to put them in bank $01 --
    which is what the PEI slam needs.
    """

    def __init__(self):
        self.m = bytearray(MEMSIZE)
        self.ramrd = False       # $C003 on, $C002 off
        self.ramwrt = False      # $C005 on, $C004 off
        self.shadow = True       # $C035 bit 3 clear: SHR shadowing on
        self.c035 = 0x00
        self.softwatch = None    # a hook, for the tests

    # --- the soft switches ----------------------------------------------
    def io(self, reg, v, scrittura):
        """$C0xx in bank $00, $01, $E0 or $E1. Returns what a read sees."""
        if reg == 0x02:
            self.ramrd = False
        elif reg == 0x03:
            self.ramrd = True
        elif reg == 0x04:
            self.ramwrt = False
        elif reg == 0x05:
            self.ramwrt = True
        elif reg == 0x35:
            if scrittura:
                self.c035 = v & 0xFF
                self.shadow = not (v & 0x08)
            return self.c035
        if self.softwatch is not None:
            self.softwatch(self, reg, v, scrittura)
        return 0

    @staticmethod
    def _e_io(a):
        return (a & 0xFF00) == 0xC000 and (a >> 16) in (0x00, 0x01, 0xE0, 0xE1)

    # --- reading --------------------------------------------------------
    def b(self, a):
        a &= 0xFFFFFF
        if a < 0x020000:
            if (a & 0xFF00) == 0xC000:
                return self.io(a & 0xFF, 0, False)
            if self.ramrd and a < 0x010000 and 0x0200 <= a < 0xC000:
                a |= 0x010000
        elif (a >> 16) in (0xE0, 0xE1) and (a & 0xFF00) == 0xC000:
            return self.io(a & 0xFF, 0, False)
        return self.m[a]

    def w(self, a):
        a &= 0xFFFFFF
        if a >= 0x020000 and (a & 0xFFFF) < 0xFFFF and \
                not ((a >> 16) in (0xE0, 0xE1) and (a & 0xFF00) == 0xC000):
            return self.m[a] | (self.m[a + 1] << 8)
        return self.b(a) | (self.b((a & 0xFF0000) | ((a + 1) & 0xFFFF)) << 8)

    def l(self, a):
        return self.w(a) | (self.b((a & 0xFF0000) | ((a + 2) & 0xFFFF)) << 16)

    # --- writing --------------------------------------------------------
    def setb(self, a, v):
        a &= 0xFFFFFF
        if a < 0x020000:
            if (a & 0xFF00) == 0xC000:
                self.io(a & 0xFF, v, True)
                return
            if self.ramwrt and a < 0x010000 and 0x0200 <= a < 0xC000:
                a |= 0x010000
            self.m[a] = v & 0xFF
            if self.shadow and 0x2000 <= (a & 0xFFFF) < 0xA000:
                self.m[0xE00000 | (a & 0x01FFFF)] = v & 0xFF
            return
        if (a >> 16) in (0xE0, 0xE1) and (a & 0xFF00) == 0xC000:
            self.io(a & 0xFF, v, True)
            return
        self.m[a] = v & 0xFF

    def setw(self, a, v):
        a &= 0xFFFFFF
        if a >= 0x020000 and (a & 0xFFFF) < 0xFFFF and \
                not ((a >> 16) in (0xE0, 0xE1) and (a & 0xFF00) == 0xC000):
            self.m[a] = v & 0xFF
            self.m[a + 1] = (v >> 8) & 0xFF
            return
        self.setb(a, v)
        self.setb((a & 0xFF0000) | ((a + 1) & 0xFFFF), v >> 8)


# ----------------------------------------------------------------------
class CPU:
    def __init__(self, mem):
        self.mem = mem
        self.a = 0
        self.x = 0
        self.y = 0
        self.s = 0x01FF
        self.d = 0
        self.dbr = 0
        self.pbr = 0
        self.pc = 0
        self.p = 0x34            # M and X eight bits, as at power-on
        self.e = True
        self.passi = 0
        self.cicli = 0
        self.tracciamento = None
        self.simboli = {}
        self.fermo = False

    # --- flags ----------------------------------------------------------
    @property
    def m16(self):
        return not self.e and not (self.p & 0x20)

    @property
    def x16(self):
        return not self.e and not (self.p & 0x10)

    def setzn(self, v, bit16):
        limite = 0x8000 if bit16 else 0x80
        self.p = (self.p & ~0x82) | (0x02 if v == 0 else 0) | \
                 (0x80 if v & limite else 0)

    # --- stack ----------------------------------------------------------
    def push8(self, v):
        self.mem.setb(self.s, v)
        self.s = (self.s - 1) & 0xFFFF

    def push16(self, v):
        self.push8((v >> 8) & 0xFF)
        self.push8(v & 0xFF)

    def pop8(self):
        self.s = (self.s + 1) & 0xFFFF
        return self.mem.b(self.s)

    def pop16(self):
        lo = self.pop8()
        return lo | (self.pop8() << 8)

    # --- reading the code -----------------------------------------------
    def fb(self):
        v = self.mem.b((self.pbr << 16) | self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fw(self):
        return self.fb() | (self.fb() << 8)

    def fl(self):
        return self.fw() | (self.fb() << 16)

    # --- addressing modes -----------------------------------------------
    def a_abs(self):
        return (self.dbr << 16) | self.fw()

    def a_absx(self):
        return ((self.dbr << 16) + self.fw() + self.x) & 0xFFFFFF

    def a_absy(self):
        return ((self.dbr << 16) + self.fw() + self.y) & 0xFFFFFF

    def a_long(self):
        return self.fl()

    def a_longx(self):
        return (self.fl() + self.x) & 0xFFFFFF

    def a_dp(self):
        return (self.d + self.fb()) & 0xFFFF

    def a_dpx(self):
        return (self.d + self.fb() + self.x) & 0xFFFF

    def a_ind_long(self):           # [dp]
        p = self.a_dp()
        return self.mem.l(p)

    def a_ind_long_y(self):         # [dp],y
        p = self.a_dp()
        return (self.mem.l(p) + self.y) & 0xFFFFFF

    def a_ind_y(self):              # (dp),y
        p = self.a_dp()
        return ((self.dbr << 16) + self.mem.w(p) + self.y) & 0xFFFFFF

    # --- data access ----------------------------------------------------
    def leggi(self, addr, bit16):
        return self.mem.w(addr) if bit16 else self.mem.b(addr)

    def scrivi(self, addr, v, bit16):
        if bit16:
            self.mem.setw(addr, v)
        else:
            self.mem.setb(addr, v)

    # --- execution ------------------------------------------------------
    def passo(self):
        self.passi += 1
        if self.tracciamento is not None:
            self.tracciamento(self)
        op = self.fb()
        n = CICLI.get(op, 3)
        if op in CIC_M16 and self.m16:
            n += 1
        elif op in CIC_X16 and self.x16:
            n += 1
        self.cicli += n
        f = TAVOLA.get(op)
        if f is None:
            raise RuntimeError(
                f"opcode ${op:02X} non implementato a "
                f"${self.pbr:02X}/{(self.pc-1) & 0xFFFF:04X}"
                f" {self.dove()}")
        f(self)

    def dove(self):
        """The nearest label before the PC, to make traces readable."""
        indirizzo = (self.pbr << 16) | self.pc
        migliore, nome = -1, ''
        for n, a in self.simboli.items():
            if a <= indirizzo and a > migliore:
                migliore, nome = a, n
        return f"({nome}+{indirizzo - migliore})" if nome else ''


# ----------------------------------------------------------------------
# The instructions. A subset is enough: the ones Merlin32 generates for
# our source and for the toolbox macros.
TAVOLA = {}

# Cycles, so a measurement is not fooled by MVN. One MVN moves a whole
# block in a single step() call; counting steps makes a 20K block move
# look as cheap as a NOP, which is how a "six times faster" can hide a
# loss on the real machine. These are the 65816's published figures for
# the addressing mode, native mode, and the +1 for a 16-bit accumulator
# is added in step() from the m flag. They are not cycle-exact (no page
# crossing, no DP-not-page-aligned penalty), but they rank the hot spots
# honestly, which counting instructions does not.
CICLI = {}
def _cic(codes, n):
    for c in codes:
        CICLI[c] = n
# immediate
_cic((0xA9,0xA2,0xA0,0xC9,0xE0,0xC0,0x69,0xE9,0x29,0x09,0x49,0x89), 2)
# direct page
_cic((0xA5,0xA6,0xA4,0x85,0x86,0x84,0x64,0xC5,0xE4,0xC4,0x65,0xE5,0x25,0x05,0x45,0x24), 3)
_cic((0xB5,0xB4,0xB6,0x95,0x94,0x96,0x74,0xD5,0x75,0xF5,0x35,0x15,0x55,0x34), 4)
_cic((0xE6,0xC6,0x06,0x46,0x26,0x66,0x14,0x04), 5)
_cic((0xF6,0xD6,0x16,0x56,0x36,0x76), 6)
# absolute
_cic((0xAD,0xAE,0xAC,0x8D,0x8E,0x8C,0x9C,0xCD,0xEC,0xCC,0x6D,0xED,0x2D,0x0D,0x4D,0x2C), 4)
_cic((0xBD,0xBC,0xBE,0x9D,0x9E,0xDD,0x7D,0xFD,0x3D,0x1D,0x5D,0x3C,0x99,0xB9,0xD9,0x79,0xF9,0x39,0x19,0x59), 4)
_cic((0xEE,0xCE,0x0E,0x4E,0x2E,0x6E), 6)
_cic((0xFE,0xDE,0x1E,0x5E,0x3E,0x7E), 7)
# long and long,x
_cic((0xAF,0x8F,0xCF,0x6F,0xEF,0x2F,0x0F,0x4F,0xBF,0x9F,0xDF,0x7F,0xFF,0x3F,0x1F,0x5F), 5)
# (dp),y and [dp],y - the engine's inner loops live here
_cic((0xB1,0x91,0xD1,0x71,0xF1,0x31,0x11,0x51), 5)
_cic((0xB7,0x97,0xD7,0x77,0xF7,0x37,0x17,0x57), 6)
_cic((0xA1,0x81,0xC1,0x61,0xE1,0x21,0x01,0x41), 6)
_cic((0xA3,0x83,0xC3,0x63,0xE3,0x23,0x03,0x43), 4)
_cic((0xB3,0x93,0xD3,0x73,0xF3,0x33,0x13,0x53), 7)
_cic((0xB2,0x92,0xD2,0x72,0xF2,0x32,0x12,0x52), 5)
# implied / transfers / flags
_cic((0xEA,0x18,0x38,0x58,0x78,0xB8,0xD8,0xF8,0x1A,0x3A,0xE8,0xC8,0xCA,0x88,
      0xAA,0xA8,0x8A,0x98,0xBA,0x9A,0x9B,0xBB,0x5B,0x7B,0x1B,0x3B,0xEB,0xC2,0xE2), 2)
# stack
_cic((0x48,0xDA,0x5A,0x8B,0x4B,0x0B), 3)
_cic((0x68,0xFA,0x7A,0xAB,0x2B), 4)
_cic((0x08,), 3)
_cic((0x28,), 4)
_cic((0xF4,0xD4,0x62), 5)
# jumps and calls
_cic((0x4C,), 3)
_cic((0x6C,0x7C,0xDC), 5)
_cic((0x5C,), 4)
_cic((0x20,), 6)
_cic((0x22,), 8)
_cic((0xFC,), 8)
_cic((0x60,), 6)
_cic((0x6B,), 6)
_cic((0x40,), 7)
# branches: not taken 2, taken 3 - _ramo adds the extra itself
_cic((0x90,0xB0,0xD0,0xF0,0x10,0x30,0x50,0x70,0x80), 2)
_cic((0x82,), 4)
# the ones whose cost is the block itself
_cic((0x54,0x44), 0)

# memory opcodes that cost one more cycle with a 16-bit accumulator
CIC_M16 = frozenset((
    0xA9,0xC9,0x69,0xE9,0x29,0x09,0x49,0x89,
    0xA5,0x85,0xC5,0x65,0xE5,0x25,0x05,0x45,0x24,
    0xB5,0x95,0xD5,0x75,0xF5,0x35,0x15,0x55,0x34,0x64,0x74,
    0xE6,0xC6,0x06,0x46,0x26,0x66,0xF6,0xD6,0x16,0x56,0x36,0x76,
    0xAD,0x8D,0xCD,0x6D,0xED,0x2D,0x0D,0x4D,0x2C,0x9C,
    0xBD,0x9D,0xDD,0x7D,0xFD,0x3D,0x1D,0x5D,0x3C,0x9E,
    0xB9,0x99,0xD9,0x79,0xF9,0x39,0x19,0x59,
    0xEE,0xCE,0x0E,0x4E,0x2E,0x6E,0xFE,0xDE,0x1E,0x5E,0x3E,0x7E,
    0xAF,0x8F,0xCF,0x6F,0xEF,0x2F,0x0F,0x4F,0xBF,0x9F,0xDF,0x7F,0xFF,0x3F,0x1F,0x5F,
    0xB1,0x91,0xD1,0x71,0xF1,0x31,0x11,0x51,
    0xB7,0x97,0xD7,0x77,0xF7,0x37,0x17,0x57,
    0xA1,0x81,0xC1,0x61,0xE1,0x21,0x01,0x41,
    0xA3,0x83,0xC3,0x63,0xE3,0x23,0x03,0x43,
    0xB3,0x93,0xD3,0x73,0xF3,0x33,0x13,0x53,
    0xB2,0x92,0xD2,0x72,0xF2,0x32,0x12,0x52))
# index opcodes that cost one more with 16-bit X/Y
CIC_X16 = frozenset((0xA2,0xA0,0xE0,0xC0,0xA6,0xA4,0x86,0x84,0xAE,0xAC,0x8E,0x8C,
                     0xB6,0xB4,0x96,0x94,0xEC,0xCC,0xBE,0xBC))


def istr(code):
    def deco(f):
        TAVOLA[code] = f
        return f
    return deco


def _carica_a(c, addr):
    v = c.leggi(addr, c.m16)
    if c.m16:
        c.a = v
    else:
        c.a = (c.a & 0xFF00) | v
    c.setzn(v, c.m16)


def _salva_a(c, addr):
    c.scrivi(addr, c.a if c.m16 else c.a & 0xFF, c.m16)


def _confronto(c, valore, reg, bit16):
    mask = 0xFFFF if bit16 else 0xFF
    r = (reg & mask) - (valore & mask)
    c.p = (c.p & ~0x01) | (1 if r >= 0 else 0)
    c.setzn(r & mask, bit16)


# --- loads and stores -------------------------------------------------
for code, modo in ((0xA9, 'imm'), (0xAD, 'abs'), (0xBD, 'absx'),
                   (0xAF, 'long'), (0xBF, 'longx'), (0xA5, 'dp'),
                   (0xB5, 'dpx'), (0xA7, 'indl'), (0xB7, 'indly'),
                   (0xB1, 'indy'), (0xB9, 'absy')):
    def fa(c, modo=modo):
        if modo == 'imm':
            v = c.fw() if c.m16 else c.fb()
            if c.m16:
                c.a = v
            else:
                c.a = (c.a & 0xFF00) | v
            c.setzn(v, c.m16)
            return
        addr = {'abs': c.a_abs, 'absx': c.a_absx, 'absy': c.a_absy,
                'long': c.a_long, 'longx': c.a_longx, 'dp': c.a_dp,
                'dpx': c.a_dpx, 'indl': c.a_ind_long,
                'indly': c.a_ind_long_y, 'indy': c.a_ind_y}[modo]()
        _carica_a(c, addr)
    TAVOLA[code] = fa

for code, modo in ((0x8D, 'abs'), (0x9D, 'absx'), (0x99, 'absy'),
                   (0x8F, 'long'), (0x9F, 'longx'), (0x85, 'dp'),
                   (0x95, 'dpx'), (0x87, 'indl'), (0x97, 'indly'),
                   (0x91, 'indy')):
    def fs(c, modo=modo):
        addr = {'abs': c.a_abs, 'absx': c.a_absx, 'absy': c.a_absy,
                'long': c.a_long, 'longx': c.a_longx, 'dp': c.a_dp,
                'dpx': c.a_dpx, 'indl': c.a_ind_long,
                'indly': c.a_ind_long_y, 'indy': c.a_ind_y}[modo]()
        _salva_a(c, addr)
    TAVOLA[code] = fs


@istr(0x9C)
def stz_abs(c):
    c.scrivi(c.a_abs(), 0, c.m16)


@istr(0x9E)
def stz_absx(c):
    c.scrivi(c.a_absx(), 0, c.m16)


@istr(0x64)
def stz_dp(c):
    c.scrivi(c.a_dp(), 0, c.m16)


@istr(0x74)
def stz_dpx(c):
    c.scrivi(c.a_dpx(), 0, c.m16)


# --- index registers ---------------------------------------------------
def _ld_indice(c, quale, valore):
    setattr(c, quale, valore)
    c.setzn(valore, c.x16)


@istr(0xA2)
def ldx_imm(c):
    _ld_indice(c, 'x', c.fw() if c.x16 else c.fb())


@istr(0xA0)
def ldy_imm(c):
    _ld_indice(c, 'y', c.fw() if c.x16 else c.fb())


@istr(0xAE)
def ldx_abs(c):
    _ld_indice(c, 'x', c.leggi(c.a_abs(), c.x16))


@istr(0xAC)
def ldy_abs(c):
    _ld_indice(c, 'y', c.leggi(c.a_abs(), c.x16))


@istr(0xA6)
def ldx_dp(c):
    _ld_indice(c, 'x', c.leggi(c.a_dp(), c.x16))


@istr(0xA4)
def ldy_dp(c):
    _ld_indice(c, 'y', c.leggi(c.a_dp(), c.x16))


@istr(0xBE)
def ldx_absy(c):
    _ld_indice(c, 'x', c.leggi(c.a_absy(), c.x16))


@istr(0xBC)
def ldy_absx(c):
    _ld_indice(c, 'y', c.leggi(c.a_absx(), c.x16))


@istr(0x8E)
def stx_abs(c):
    c.scrivi(c.a_abs(), c.x, c.x16)


@istr(0x8C)
def sty_abs(c):
    c.scrivi(c.a_abs(), c.y, c.x16)


@istr(0x86)
def stx_dp(c):
    c.scrivi(c.a_dp(), c.x, c.x16)


@istr(0x84)
def sty_dp(c):
    c.scrivi(c.a_dp(), c.y, c.x16)


@istr(0xE8)
def inx(c):
    c.x = (c.x + 1) & (0xFFFF if c.x16 else 0xFF)
    c.setzn(c.x, c.x16)


@istr(0xC8)
def iny(c):
    c.y = (c.y + 1) & (0xFFFF if c.x16 else 0xFF)
    c.setzn(c.y, c.x16)


@istr(0xCA)
def dex(c):
    c.x = (c.x - 1) & (0xFFFF if c.x16 else 0xFF)
    c.setzn(c.x, c.x16)


@istr(0x88)
def dey(c):
    c.y = (c.y - 1) & (0xFFFF if c.x16 else 0xFF)
    c.setzn(c.y, c.x16)


# --- arithmetic --------------------------------------------------------
@istr(0x1A)
def inc_a(c):
    if c.m16:
        c.a = (c.a + 1) & 0xFFFF
        c.setzn(c.a, True)
    else:
        c.a = (c.a & 0xFF00) | ((c.a + 1) & 0xFF)
        c.setzn(c.a & 0xFF, False)


@istr(0x3A)
def dec_a(c):
    if c.m16:
        c.a = (c.a - 1) & 0xFFFF
        c.setzn(c.a, True)
    else:
        c.a = (c.a & 0xFF00) | ((c.a - 1) & 0xFF)
        c.setzn(c.a & 0xFF, False)


def _incdec_mem(c, addr, delta):
    v = c.leggi(addr, c.m16)
    v = (v + delta) & (0xFFFF if c.m16 else 0xFF)
    c.scrivi(addr, v, c.m16)
    c.setzn(v, c.m16)


@istr(0xEE)
def inc_abs(c):
    _incdec_mem(c, c.a_abs(), 1)


@istr(0xFE)
def inc_absx(c):
    _incdec_mem(c, c.a_absx(), 1)


@istr(0xCE)
def dec_abs(c):
    _incdec_mem(c, c.a_abs(), -1)


@istr(0xDE)
def dec_absx(c):
    _incdec_mem(c, c.a_absx(), -1)


@istr(0xE6)
def inc_dp(c):
    _incdec_mem(c, c.a_dp(), 1)


@istr(0xC6)
def dec_dp(c):
    _incdec_mem(c, c.a_dp(), -1)


def _adc(c, v):
    bit16 = c.m16
    mask = 0xFFFF if bit16 else 0xFF
    limite = 0x8000 if bit16 else 0x80
    a = c.a & mask
    r = a + (v & mask) + (c.p & 1)
    over = (~(a ^ v) & (a ^ r) & limite) != 0
    c.p = (c.p & ~0x41) | (1 if r > mask else 0) | (0x40 if over else 0)
    r &= mask
    c.a = r if bit16 else (c.a & 0xFF00) | r
    c.setzn(r, bit16)


def _sbc(c, v):
    bit16 = c.m16
    mask = 0xFFFF if bit16 else 0xFF
    limite = 0x8000 if bit16 else 0x80
    a = c.a & mask
    v &= mask
    r = a - v - (1 - (c.p & 1))
    over = ((a ^ v) & (a ^ r) & limite) != 0
    c.p = (c.p & ~0x41) | (1 if r >= 0 else 0) | (0x40 if over else 0)
    r &= mask
    c.a = r if bit16 else (c.a & 0xFF00) | r
    c.setzn(r, bit16)


for code, modo, fn in ((0x69, 'imm', _adc), (0x6D, 'abs', _adc),
                       (0x7D, 'absx', _adc), (0x65, 'dp', _adc),
                       (0x6F, 'long', _adc), (0x77, 'indly', _adc),
                       (0xE9, 'imm', _sbc), (0xED, 'abs', _sbc),
                       (0xFD, 'absx', _sbc), (0xE5, 'dp', _sbc),
                       (0xEF, 'long', _sbc)):
    def fop(c, modo=modo, fn=fn):
        if modo == 'imm':
            v = c.fw() if c.m16 else c.fb()
        else:
            addr = {'abs': c.a_abs, 'absx': c.a_absx, 'dp': c.a_dp,
                    'long': c.a_long, 'indly': c.a_ind_long_y}[modo]()
            v = c.leggi(addr, c.m16)
        fn(c, v)
    TAVOLA[code] = fop


def _logica(c, v, quale):
    bit16 = c.m16
    mask = 0xFFFF if bit16 else 0xFF
    a = c.a & mask
    r = {'and': a & v, 'ora': a | v, 'eor': a ^ v}[quale] & mask
    c.a = r if bit16 else (c.a & 0xFF00) | r
    c.setzn(r, bit16)


for code, modo, quale in ((0x29, 'imm', 'and'), (0x2D, 'abs', 'and'),
                          (0x3D, 'absx', 'and'), (0x25, 'dp', 'and'),
                          (0x27, 'indl', 'and'), (0x37, 'indly', 'and'),
                          (0x09, 'imm', 'ora'), (0x0D, 'abs', 'ora'),
                          (0x1D, 'absx', 'ora'), (0x05, 'dp', 'ora'),
                          (0x17, 'indly', 'ora'), (0x07, 'indl', 'ora'),
                          (0x49, 'imm', 'eor'), (0x4D, 'abs', 'eor'),
                          (0x45, 'dp', 'eor'), (0x57, 'indly', 'eor'),
                          (0x47, 'indl', 'eor')):
    def flog(c, modo=modo, quale=quale):
        if modo == 'imm':
            v = c.fw() if c.m16 else c.fb()
        else:
            addr = {'abs': c.a_abs, 'absx': c.a_absx, 'dp': c.a_dp,
                    'indl': c.a_ind_long, 'indly': c.a_ind_long_y}[modo]()
            v = c.leggi(addr, c.m16)
        _logica(c, v, quale)
    TAVOLA[code] = flog


for code, modo in ((0xC9, 'imm'), (0xCD, 'abs'), (0xDD, 'absx'),
                   (0xC5, 'dp'), (0xCF, 'long'), (0xD7, 'indly'),
                   (0xD9, 'absy'), (0xC3, 'sr')):
    def fcmp(c, modo=modo):
        if modo == 'imm':
            v = c.fw() if c.m16 else c.fb()
        elif modo == 'sr':
            v = c.leggi((c.s + c.fb()) & 0xFFFF, c.m16)
        else:
            addr = {'abs': c.a_abs, 'absx': c.a_absx, 'absy': c.a_absy,
                    'dp': c.a_dp, 'long': c.a_long,
                    'indly': c.a_ind_long_y}[modo]()
            v = c.leggi(addr, c.m16)
        _confronto(c, v, c.a, c.m16)
    TAVOLA[code] = fcmp


for code, modo, reg in ((0xE0, 'imm', 'x'), (0xEC, 'abs', 'x'),
                        (0xE4, 'dp', 'x'), (0xC0, 'imm', 'y'),
                        (0xCC, 'abs', 'y'), (0xC4, 'dp', 'y')):
    def fcpxy(c, modo=modo, reg=reg):
        if modo == 'imm':
            v = c.fw() if c.x16 else c.fb()
        else:
            addr = c.a_abs() if modo == 'abs' else c.a_dp()
            v = c.leggi(addr, c.x16)
        _confronto(c, v, getattr(c, reg), c.x16)
    TAVOLA[code] = fcpxy


@istr(0x0A)
def asl_a(c):
    mask = 0xFFFF if c.m16 else 0xFF
    limite = 0x8000 if c.m16 else 0x80
    a = c.a & mask
    carry = 1 if a & limite else 0
    r = (a << 1) & mask
    c.a = r if c.m16 else (c.a & 0xFF00) | r
    c.p = (c.p & ~0x01) | carry
    c.setzn(r, c.m16)


@istr(0x4A)
def lsr_a(c):
    mask = 0xFFFF if c.m16 else 0xFF
    a = c.a & mask
    carry = a & 1
    r = a >> 1
    c.a = r if c.m16 else (c.a & 0xFF00) | r
    c.p = (c.p & ~0x01) | carry
    c.setzn(r, c.m16)


@istr(0x2A)
def rol_a(c):
    mask = 0xFFFF if c.m16 else 0xFF
    limite = 0x8000 if c.m16 else 0x80
    a = c.a & mask
    carry = 1 if a & limite else 0
    r = ((a << 1) | (c.p & 1)) & mask
    c.a = r if c.m16 else (c.a & 0xFF00) | r
    c.p = (c.p & ~0x01) | carry
    c.setzn(r, c.m16)


# --- branches ----------------------------------------------------------
def _ramo(c, condizione):
    off = c.fb()
    if off & 0x80:
        off -= 256
    if condizione:
        c.cicli += 1                       # a taken branch is one more
        c.pc = (c.pc + off) & 0xFFFF


TAVOLA[0x90] = lambda c: _ramo(c, not (c.p & 0x01))       # bcc
TAVOLA[0xB0] = lambda c: _ramo(c, c.p & 0x01)             # bcs
TAVOLA[0xD0] = lambda c: _ramo(c, not (c.p & 0x02))       # bne
TAVOLA[0xF0] = lambda c: _ramo(c, c.p & 0x02)             # beq
TAVOLA[0x10] = lambda c: _ramo(c, not (c.p & 0x80))       # bpl
TAVOLA[0x30] = lambda c: _ramo(c, c.p & 0x80)             # bmi
TAVOLA[0x50] = lambda c: _ramo(c, not (c.p & 0x40))       # bvc
TAVOLA[0x70] = lambda c: _ramo(c, c.p & 0x40)             # bvs
TAVOLA[0x80] = lambda c: _ramo(c, True)                   # bra


@istr(0x82)
def brl(c):
    off = c.fw()
    if off & 0x8000:
        off -= 65536
    c.pc = (c.pc + off) & 0xFFFF


@istr(0x4C)
def jmp_abs(c):
    c.pc = c.fw()


@istr(0x5C)
def jmp_long(c):
    a = c.fl()
    c.pbr = (a >> 16) & 0xFF
    c.pc = a & 0xFFFF


@istr(0x6C)
def jmp_ind(c):
    p = c.fw()
    c.pc = c.mem.w(p)


@istr(0x7C)
def jmp_indx(c):
    p = (c.fw() + c.x) & 0xFFFF
    c.pc = c.mem.w((c.pbr << 16) | p)


@istr(0x20)
def jsr_abs(c):
    dest = c.fw()
    c.push16((c.pc - 1) & 0xFFFF)
    c.pc = dest


@istr(0xFC)
def jsr_indx(c):
    p = (c.fw() + c.x) & 0xFFFF
    dest = c.mem.w((c.pbr << 16) | p)
    c.push16((c.pc - 1) & 0xFFFF)
    c.pc = dest


@istr(0x22)
def jsl(c):
    dest = c.fl()
    c.push8(c.pbr)
    c.push16((c.pc - 1) & 0xFFFF)
    c.pbr = (dest >> 16) & 0xFF
    c.pc = dest & 0xFFFF


@istr(0x60)
def rts(c):
    c.pc = (c.pop16() + 1) & 0xFFFF


@istr(0x6B)
def rtl(c):
    c.pc = (c.pop16() + 1) & 0xFFFF
    c.pbr = c.pop8()


# --- stack and transfers ----------------------------------------------
@istr(0x48)
def pha(c):
    if c.m16:
        c.push16(c.a)
    else:
        c.push8(c.a & 0xFF)


@istr(0x68)
def pla(c):
    if c.m16:
        c.a = c.pop16()
        c.setzn(c.a, True)
    else:
        v = c.pop8()
        c.a = (c.a & 0xFF00) | v
        c.setzn(v, False)


@istr(0xDA)
def phx(c):
    c.push16(c.x) if c.x16 else c.push8(c.x & 0xFF)


@istr(0xFA)
def plx(c):
    c.x = c.pop16() if c.x16 else c.pop8()
    c.setzn(c.x, c.x16)


@istr(0x5A)
def phy(c):
    c.push16(c.y) if c.x16 else c.push8(c.y & 0xFF)


@istr(0x7A)
def ply(c):
    c.y = c.pop16() if c.x16 else c.pop8()
    c.setzn(c.y, c.x16)


@istr(0x8B)
def phb(c):
    c.push8(c.dbr)


@istr(0xAB)
def plb(c):
    c.dbr = c.pop8()
    c.setzn(c.dbr, False)


@istr(0x0B)
def phd(c):
    c.push16(c.d)


@istr(0x2B)
def pld(c):
    c.d = c.pop16()


@istr(0x4B)
def phk(c):
    c.push8(c.pbr)


@istr(0x08)
def php(c):
    c.push8(c.p)


@istr(0x28)
def plp(c):
    c.p = c.pop8()


@istr(0xF4)
def pea(c):
    c.push16(c.fw())


@istr(0xD4)
def pei(c):
    c.push16(c.mem.w(c.a_dp()))


@istr(0x62)
def per(c):
    off = c.fw()
    c.push16((c.pc + off) & 0xFFFF)


@istr(0xAA)
def tax(c):
    c.x = c.a if c.x16 else c.a & 0xFF
    c.setzn(c.x, c.x16)


@istr(0xA8)
def tay(c):
    c.y = c.a if c.x16 else c.a & 0xFF
    c.setzn(c.y, c.x16)


@istr(0x8A)
def txa(c):
    if c.m16:
        c.a = c.x
    else:
        c.a = (c.a & 0xFF00) | (c.x & 0xFF)
    c.setzn(c.a if c.m16 else c.a & 0xFF, c.m16)


@istr(0x98)
def tya(c):
    if c.m16:
        c.a = c.y
    else:
        c.a = (c.a & 0xFF00) | (c.y & 0xFF)
    c.setzn(c.a if c.m16 else c.a & 0xFF, c.m16)


@istr(0x9B)
def txy(c):
    c.y = c.x
    c.setzn(c.y, c.x16)


@istr(0xBB)
def tyx(c):
    c.x = c.y
    c.setzn(c.x, c.x16)


@istr(0x5B)
def tcd(c):
    c.d = c.a & 0xFFFF
    c.setzn(c.d, True)


@istr(0x7B)
def tdc(c):
    c.a = c.d
    c.setzn(c.a, True)


@istr(0x1B)
def tcs(c):
    c.s = c.a & 0xFFFF


@istr(0x3B)
def tsc(c):
    c.a = c.s
    c.setzn(c.a, True)


@istr(0x9A)
def txs(c):
    c.s = c.x & 0xFFFF


@istr(0xBA)
def tsx(c):
    c.x = c.s
    c.setzn(c.x, c.x16)


@istr(0xEB)
def xba(c):
    c.a = ((c.a << 8) | (c.a >> 8)) & 0xFFFF
    c.setzn(c.a & 0xFF, False)


@istr(0x18)
def clc(c):
    c.p &= ~0x01


@istr(0x38)
def sec(c):
    c.p |= 0x01


@istr(0x58)
def cli(c):
    c.p &= ~0x04


@istr(0x78)
def sei(c):
    c.p |= 0x04


@istr(0xB8)
def clv(c):
    c.p &= ~0x40


@istr(0xC2)
def rep(c):
    c.p &= ~c.fb()


@istr(0xE2)
def sep(c):
    c.p |= c.fb()


@istr(0xFB)
def xce(c):
    vecchio = c.e
    c.e = bool(c.p & 0x01)
    c.p = (c.p & ~0x01) | (1 if vecchio else 0)
    if c.e:
        c.p |= 0x30


@istr(0xEA)
def nop(c):
    pass


@istr(0x54)
def mvn(c):
    dst = c.fb()
    src = c.fb()
    n = c.a & 0xFFFF
    c.cicli += 7 * (n + 1)
    for _ in range(n + 1):
        c.mem.setb((dst << 16) | c.y, c.mem.b((src << 16) | c.x))
        c.x = (c.x + 1) & 0xFFFF
        c.y = (c.y + 1) & 0xFFFF
    c.a = 0xFFFF
    c.dbr = dst


@istr(0x00)
def brk(c):
    raise RuntimeError(f"BRK a ${c.pbr:02X}/{(c.pc-1) & 0xFFFF:04X} {c.dove()}")


# --- shifts in memory -------------------------------------------------
# Needed by Casuale, which multiplies by hand: 'asl ShLo' and 'rol ShHi'.
def _leggi_scrivi(c, addr, come):
    v = c.leggi(addr, c.m16)
    v, carry = come(c, v)
    mask = 0xFFFF if c.m16 else 0xFF
    v &= mask
    c.scrivi(addr, v, c.m16)
    c.p = (c.p & ~0x01) | carry
    c.setzn(v, c.m16)


def _asl(c, v):
    limite = 0x8000 if c.m16 else 0x80
    return v << 1, (1 if v & limite else 0)


def _lsr(c, v):
    return v >> 1, v & 1


def _rol(c, v):
    limite = 0x8000 if c.m16 else 0x80
    carry = 1 if v & limite else 0
    return (v << 1) | (c.p & 1), carry


def _ror(c, v):
    limite = 0x8000 if c.m16 else 0x80
    carry = v & 1
    return (v >> 1) | (limite if c.p & 1 else 0), carry


for _code, _come, _modo in (
        (0x06, _asl, 'dp'), (0x0E, _asl, 'abs'),
        (0x16, _asl, 'dpx'), (0x1E, _asl, 'absx'),
        (0x26, _rol, 'dp'), (0x2E, _rol, 'abs'),
        (0x36, _rol, 'dpx'), (0x3E, _rol, 'absx'),
        (0x46, _lsr, 'dp'), (0x4E, _lsr, 'abs'),
        (0x56, _lsr, 'dpx'), (0x5E, _lsr, 'absx'),
        (0x66, _ror, 'dp'), (0x6E, _ror, 'abs'),
        (0x76, _ror, 'dpx'), (0x7E, _ror, 'absx')):
    def _fai(c, _come=_come, _modo=_modo):
        addr = {'dp': c.a_dp, 'abs': c.a_abs,
                'dpx': c.a_dpx, 'absx': c.a_absx}[_modo]()
        _leggi_scrivi(c, addr, _come)
    TAVOLA[_code] = _fai
