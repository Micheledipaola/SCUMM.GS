#!/usr/bin/env python3
"""dis2.py - a disassembler for SCUMM V2 bytecode (Maniac Mansion, Zak).

Scripts are a sequence of one-byte opcodes. The three high bits say, for
each argument, whether that argument is a number written in the code or
the index of a variable to read:

    bit 7 -> first argument, bit 6 -> second, bit 5 -> third

Where the bit is set the argument takes one byte (the variable index);
where it is clear it takes a byte or a word depending on the opcode. That
is why the same command appears eight times in the table below: putActor
is $01, $21, $41, $61, $81, $A1, $C1, $E1, all the same command with
arguments taken from different places.

Jumps are signed words, relative to the position AFTER the word.

The table comes from descumm (scummvm-tools, engines/scumm/descumm.cpp,
function next_line_V12), GPL-2.0-or-later: it is the good reference, and
working it out by hand from ScummVM's handlers would have been far more
fragile.

Usage:
    dis2.py <LFL folder>              list the scripts and check them
    dis2.py <LFL folder> S<n>         disassemble global script n
    dis2.py <LFL folder> R<n>         room n's scripts (entry/exit)
    dis2.py <LFL folder> --conta      which opcodes are actually needed
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import struct
import sys

from lfl import Index

# The names of V2's system variables (descumm, var_names2).
VAR_NAMES = {
    0: 'EGO', 1: 'RESULT', 2: 'CAMERA_POS_X', 3: 'HAVE_MSG',
    4: 'ROOM', 5: 'OVERRIDE', 6: 'MACHINE_SPEED', 7: 'CHARCOUNT',
    8: 'ACTIVE_VERB', 9: 'ACTIVE_OBJECT1', 10: 'ACTIVE_OBJECT2',
    11: 'NUM_ACTOR', 12: 'CURRENT_LIGHTS', 13: 'CURRENTDRIVE',
    17: 'MUSIC_TIMER', 18: 'VERB_ALLOWED', 19: 'ACTOR_RANGE_MIN',
    20: 'ACTOR_RANGE_MAX', 23: 'CAMERA_MIN_X', 24: 'CAMERA_MAX_X',
    25: 'TIMER_NEXT', 26: 'SENTENCE_VERB', 27: 'SENTENCE_OBJECT1',
    28: 'SENTENCE_OBJECT2', 29: 'SENTENCE_PREPOSITION',
    30: 'VIRT_MOUSE_X', 31: 'VIRT_MOUSE_Y', 32: 'CLICK_AREA',
    33: 'CLICK_VERB', 35: 'CLICK_OBJECT', 36: 'ROOM_RESOURCE',
    37: 'LAST_SOUND', 38: 'BACKUP_VERB', 39: 'KEYPRESS',
    40: 'CUTSCENEEXIT_KEY', 41: 'TALK_ACTOR',
}

RES_TYPES = ['res0', 'res1', 'Costume', 'Room', 'res4', 'Script', 'Sound']

# Opcodes that end the flow: nothing continues in line after them.
# stopScript(0) counts as stopObjectCode ("stop me"), and chainScript
# hands over to another script: both are flagged while decoding.
TERMINALI = {0x00, 0xA0, 0x18, 0x98, 0x4A, 0xCA}


def _famiglia(base, bit_usati, nome, spec):
    """Every variant of one command: the opcodes that differ only in the
    high bits choosing variable-or-constant."""
    out = {}
    bits = [b for b in (0x80, 0x40, 0x20) if b & bit_usati]
    for n in range(1 << len(bits)):
        op = base
        for i, b in enumerate(bits):
            if n & (1 << i):
                op |= b
        out[op] = (nome, spec)
    return out


def _costruisci():
    """The fixed-shape opcode table.

    The argument letters:
        =   the destination variable (read first)
        B/W variable-or-byte / variable-or-word, first argument (bit 7)
        B2/W2  second argument (bit 6)
        B3     third argument (bit 5)
        b/w    a number always written in the code
        v      always a variable
        s      zero-terminated string
    """
    t = {}
    for op, nome in ((0x58, 'beginOverride'), (0x80, 'breakHere'),
                     (0x40, 'cutscene'), (0xC0, 'endCutscene'),
                     (0xAC, 'drawSentence'), (0x98, 'restart'),
                     (0x20, 'stopMusic'), (0x00, 'stopObjectCode'),
                     (0xA0, 'stopObjectCode'), (0x4C, 'waitForSentence'),
                     (0xAE, 'waitForMessage'),
                     (0x5C, 'dummy'), (0x6B, 'dummy'), (0x6E, 'dummy'),
                     (0xAB, 'dummy'), (0xDC, 'dummy'), (0xEB, 'dummy'),
                     (0xEE, 'dummy')):
        t[op] = (nome, ())

    t[0x2B] = ('delayVariable', ('v',))

    # one argument, variable-or-byte
    for base, nome in ((0x52, 'actorFollowCamera'), (0x4A, 'chainScript'),
                       (0x72, 'loadRoom'), (0x12, 'panCameraTo'),
                       (0x32, 'setCameraAt'), (0x02, 'startMusic'),
                       (0x42, 'startScript'), (0x1C, 'startSound'),
                       (0x62, 'stopScript'), (0x3C, 'stopSound'),
                       (0x3B, 'waitForActor')):
        t.update(_famiglia(base, 0x80, nome, ('B',)))

    # one argument, variable-or-word (nearly always an object)
    for base, nome in ((0x50, 'pickupObject'),
                       (0x77, 'clearState01'), (0x17, 'clearState02'),
                       (0x67, 'clearState04'), (0x47, 'clearState08'),
                       (0x37, 'setState01'), (0x57, 'setState02'),
                       (0x27, 'setState04'), (0x07, 'setState08')):
        t.update(_famiglia(base, 0x80, nome, ('W',)))

    # result = f(argument)
    for base, nome in ((0x71, 'getActorCostume'), (0x06, 'getActorElevation'),
                       (0x63, 'getActorFacing'), (0x56, 'getActorMoving'),
                       (0x03, 'getActorRoom'), (0x7B, 'getActorWalkBox'),
                       (0x43, 'getActorX'), (0x23, 'getActorY'),
                       (0x16, 'getRandomNr'), (0x68, 'isScriptRunning'),
                       (0x7C, 'isSoundRunning'), (0x22, 'saveLoadGame')):
        t.update(_famiglia(base, 0x80, nome, ('=', 'B')))
    for base, nome in ((0x66, 'getClosestObjActor'), (0x10, 'getObjectOwner'),
                       (0x6C, 'getObjPreposition')):
        t.update(_famiglia(base, 0x80, nome, ('=', 'W')))

    t.update(_famiglia(0x15, 0xC0, 'actorFromPos', ('=', 'B', 'B2')))
    t.update(_famiglia(0x35, 0xC0, 'findObject', ('=', 'B', 'B2')))
    t.update(_famiglia(0x34, 0xC0, 'getDist', ('=', 'W', 'W2')))
    t.update(_famiglia(0x31, 0x80, 'getBitVar', ('=', 'w', 'B')))
    t.update(_famiglia(0x1B, 0xC0, 'setBitVar', ('w', 'B', 'B2')))
    t.update(_famiglia(0x11, 0xC0, 'animateActor', ('B', 'B2')))
    t.update(_famiglia(0x09, 0xC0, 'faceActor', ('B', 'B2')))
    t.update(_famiglia(0x05, 0xE0, 'drawObject', ('W', 'B2', 'B3')))
    t.update(_famiglia(0x01, 0xE0, 'putActor', ('B', 'B2', 'B3')))
    t.update(_famiglia(0x0E, 0xC0, 'putActorAtObject', ('B', 'W2')))
    t.update(_famiglia(0x2D, 0xC0, 'putActorInRoom', ('B', 'B2')))
    t.update(_famiglia(0x24, 0xC0, 'loadRoomWithEgo', ('W', 'B2', 'b', 'b')))
    t.update(_famiglia(0x30, 0x80, 'setBoxFlags', ('B', 'b')))
    t.update(_famiglia(0x70, 0x80, 'lights', ('B', 'b', 'b')))
    t.update(_famiglia(0x54, 0x80, 'setObjectName', ('W', 's')))
    t.update(_famiglia(0x0B, 0xC0, 'setObjPreposition', ('W', 'b')))
    t.update(_famiglia(0x29, 0xC0, 'setOwnerOf', ('W', 'B2')))
    t.update(_famiglia(0x3D, 0xC0, 'setActorElevation', ('B', 'B2')))
    t.update(_famiglia(0x1E, 0xE0, 'walkActorTo', ('B', 'B2', 'B3')))
    t.update(_famiglia(0x0D, 0xC0, 'walkActorToActor', ('B', 'B2', 'b')))
    t.update(_famiglia(0x36, 0xC0, 'walkActorToObject', ('B', 'W2')))
    return t


TABELLA = _costruisci()


class Fine(Exception):
    """The code ended sooner than expected."""


class Lettore:
    def __init__(self, data, pc=0):
        self.d = data
        self.pc = pc

    def byte(self):
        if self.pc >= len(self.d):
            raise Fine(f"byte oltre la fine (${self.pc:04X})")
        b = self.d[self.pc]
        self.pc += 1
        return b

    def word(self):
        if self.pc + 2 > len(self.d):
            raise Fine(f"word oltre la fine (${self.pc:04X})")
        w = struct.unpack_from('<h', self.d, self.pc)[0]
        self.pc += 2
        return w

    def uword(self):
        return self.word() & 0xFFFF

    def guarda(self):
        return self.d[self.pc] if self.pc < len(self.d) else None


def nome_var(i):
    n = VAR_NAMES.get(i)
    return f"VAR_{n}" if n else f"Var[{i}]"


class Istruzione:
    def __init__(self, addr, op):
        self.addr = addr
        self.op = op
        self.nome = '???'
        self.args = []
        self.salto = None       # absolute destination, if there is one
        self.size = 0
        self.finale = False     # nothing continues in line after me

    def __str__(self):
        testo = f"{self.nome}({', '.join(self.args)})" if self.args \
            else f"{self.nome}()"
        if self.salto is not None:
            testo += f" -> ${self.salto:04X}"
        return testo

    def riga(self):
        return f"  ${self.addr:04X}  {self.op:02X}  {self}"


class Dis:
    """Disassembles a block of V2 bytecode."""

    def __init__(self, data, base=0):
        self.data = data
        self.base = base            # address of the first byte, for the jumps

    # --- building blocks -----------------------------------------------
    def _var(self, r):
        return nome_var(r.byte())

    def _vb(self, r, op, mask):
        return self._var(r) if op & mask else str(r.byte())

    def _vw(self, r, op, mask):
        return self._var(r) if op & mask else str(r.word())

    def _ascii(self, r):
        """Zero-terminated string, with the $FF/$FE codes (descumm)."""
        out = []
        while True:
            c = r.byte()
            if c == 0:
                break
            if c in (0xFF, 0xFE):
                i = r.byte()
                out.append(f"<{i}>")
                if 4 <= i <= 7:
                    out.append(f"[{nome_var(r.byte())}]")
            else:
                out.append(chr(c) if 32 <= c < 127 else f"\\x{c:02X}")
        return '"' + ''.join(out) + '"'

    def _pstr(self, r):
        """The print string: bit 7 = end of word, c<8 = control code."""
        out = []
        while True:
            c = r.byte()
            if c == 0:
                break
            spazio = c & 0x80
            c &= 0x7F
            if c < 8:
                out.append(f"<{c}")
                if c > 3:
                    out.append(f":{r.byte()}")
                out.append(">")
            else:
                out.append(chr(c) if 32 <= c < 127 else f"\\x{c:02X}")
            if spazio:
                out.append(' ')
        return '"' + ''.join(out) + '"'

    def _salto(self, ins, r):
        off = r.word()
        ins.salto = self.base + r.pc + off

    # --- the table ------------------------------------------------------
    def decodifica(self, pc):
        """One instruction starting at pc (relative to data)."""
        r = Lettore(self.data, pc)
        op = r.byte()
        ins = Istruzione(self.base + pc, op)
        b = op & 0x7F
        A, B, C = 0x80, 0x40, 0x20

        def semplice(nome, *spec):
            ins.nome = nome
            for s in spec:
                if s == 'b':
                    ins.args.append(str(r.byte()))
                elif s == 'w':
                    ins.args.append(str(r.word()))
                elif s == 'v':
                    ins.args.append(self._var(r))
                elif s in ('B', 'B2', 'B3'):
                    ins.args.append(self._vb(r, op, {'B': A, 'B2': B, 'B3': C}[s]))
                elif s in ('W', 'W2', 'W3'):
                    ins.args.append(self._vw(r, op, {'W': A, 'W2': B, 'W3': C}[s]))
                elif s == 's':
                    ins.args.append(self._ascii(r))

        def risultato():
            """AVARSTORE: the destination variable is read first."""
            ins.args.append(self._var(r) + ' =')

        # --- comparisons and conditional jumps ------------------------
        if op in (0x48, 0xC8, 0x78, 0xF8, 0x04, 0x84, 0x44, 0xC4,
                  0x08, 0x88, 0x38, 0xB8, 0x28, 0xA8):
            # In the engine the test is written the other way round: the
            # first operand is the variable, the second the value, and the
            # true condition is "value <operator> variable".
            segni = {0x38: '>=', 0x04: '<=', 0x08: '!=', 0x48: '==',
                     0x78: '<', 0x44: '>'}
            if op in (0x28, 0xA8):
                ins.nome = 'unless'
                sinistra = ''
                destra = self._var(r)
                segno = '!' if op == 0x28 else ''
                ins.args.append(f"{segno}{destra}")
            else:
                sinistra = self._var(r)
                destra = self._vw(r, op, A)
                ins.args.append(f"{sinistra} {segni[b]} {destra}")
                ins.nome = 'unless'
            self._salto(ins, r)

        elif op in (0x3F, 0xBF, 0x5F, 0xDF, 0x2F, 0xAF, 0x0F, 0x8F,
                    0x7F, 0xFF, 0x1F, 0x9F, 0x6F, 0xEF, 0x4F, 0xCF):
            # ifState / ifNotState on one of the four state bits
            stato = {0x3F: (1, True), 0x5F: (2, True), 0x2F: (4, True),
                     0x0F: (8, True), 0x7F: (1, False), 0x1F: (2, False),
                     0x6F: (4, False), 0x4F: (8, False)}[b]
            ogg = self._vw(r, op, A)
            ins.nome = 'unlessState'
            ins.args.append(f"{ogg} {'!=' if stato[1] else '=='} {stato[0]}")
            self._salto(ins, r)

        elif op in (0x1D, 0x5D, 0x9D, 0xDD):
            ins.nome = 'unlessClassOfIs'
            ins.args.append(self._vw(r, op, A))
            ins.args.append(self._vb(r, op, B))
            self._salto(ins, r)

        elif op == 0x18:
            ins.nome = 'goto'
            self._salto(ins, r)

        # --- assignments ----------------------------------------------
        elif op in (0x0A, 0x8A, 0x2A, 0xAA, 0x3A, 0xBA, 0x6A, 0xEA,
                    0x1A, 0x5A, 0x9A, 0xDA, 0x2C, 0x46, 0xC6):
            # The "Indirect" ones take the variable index from another
            # variable: Var[Var[i]] instead of Var[i].
            if b in (0x0A, 0x2A, 0x6A):
                dest = f"Var[Var[{r.byte()}]]"
            else:
                dest = self._var(r)
            nomi = {0x0A: ('moveIndirect', '='), 0x1A: ('move', '='),
                    0x2C: ('assignVarByte', '='), 0x3A: ('subtract', '-='),
                    0x6A: ('subIndirect', '-='), 0x2A: ('addIndirect', '+='),
                    0x5A: ('add', '+='),
                    0x46: ('decrement' if op & 0x80 else 'increment',
                           '--' if op & 0x80 else '++')}
            ins.nome, segno = nomi[b]
            if b == 0x2C:
                ins.args.append(f"{dest} = {r.byte()}")
            elif b == 0x46:
                ins.args.append(f"{dest}{segno}")
            else:
                ins.args.append(f"{dest} {segno} {self._vw(r, op, A)}")

        # --- commands with sub-opcodes --------------------------------
        elif op in (0x13, 0x53, 0x93, 0xD3):
            ins.nome = 'actorOps'
            ins.args.append(self._vb(r, op, A))
            arg = self._vb(r, op, B)
            sub = r.byte()
            if sub == 1:
                ins.args.append(f"Sound({arg})")
            elif sub == 2:
                ins.args.append(f"Color({r.byte()}, {arg})")
            elif sub == 3:
                ins.args.append(f"Name({self._ascii(r)})")
            elif sub == 4:
                ins.args.append(f"Costume({arg})")
            elif sub == 5:
                ins.args.append(f"TalkColor({arg})")
            else:
                raise Fine(f"actorOps: sotto-opcode {sub} sconosciuto")

        elif op in (0x0C, 0x8C):
            ins.nome = 'resourceRoutines'
            res = self._vb(r, op, A)
            sub = r.byte()
            tipo = sub >> 4
            nome_tipo = RES_TYPES[tipo] if tipo < len(RES_TYPES) else f"res{tipo}"
            if (sub & 0x0F) in (0, 1):
                verbo = 'load' if sub & 1 else 'nuke'
            else:
                verbo = 'lock' if sub & 1 else 'unlock'
            ins.args.append(f"{verbo}{nome_tipo}({res})")

        elif op in (0x33, 0x73, 0xB3, 0xF3):
            ins.nome = 'roomOps'
            a = self._vb(r, op, A)
            c = self._vb(r, op, B)
            sub = r.byte() & 0x1F
            # V2 really uses only 1 (camera limits, multiplied by 8) and 2
            # (room colour); the others the engine ignores after reading
            # the byte, so they are not an error.
            nomi = {1: 'RoomScroll', 2: 'RoomColor', 3: 'SetScreen',
                    4: 'SetPalColor', 5: 'ShakeOn', 6: 'ShakeOff'}
            nome_sub = nomi.get(sub, f"sub{sub}")
            ins.args.append(f"{nome_sub}({a}, {c})" if sub <= 4
                            else f"{nome_sub}()")

        elif op in (0x7A, 0xFA):
            ins.nome = 'verbOps'
            sub = r.byte()
            if sub == 0:
                ins.args.append(f"Delete({self._vb(r, op, A)})")
            elif sub == 0xFF:
                ins.args.append(f"State({r.byte()}, {r.byte()})")
            else:
                x = r.byte()
                y = r.byte()
                verbo = self._vb(r, op, A)
                chiave = r.byte()
                testo = self._ascii(r)
                ins.args.append(
                    f"New-{sub}({x}, {y}, {verbo}, {chiave}, {testo})")

        elif op in (0x26, 0xA6):
            ins.nome = 'setVarRange'
            ins.args.append(self._var(r))
            n = r.byte()
            valori = [str(r.word() if op & A else r.byte()) for _ in range(n)]
            ins.args.append(f"[{', '.join(valori)}]")

        elif op in (0x60, 0xE0):
            ins.nome = 'cursorCommand'
            ins.args.append(self._var(r) if op & A else str(r.uword()))

        elif op == 0x2E:
            ins.nome = 'delay'
            d = r.byte() | (r.byte() << 8) | (r.byte() << 16)
            ins.args.append(str(0xFFFFFF - d))

        elif op == 0xCC:
            ins.nome = 'pseudoRoom'
            ins.args.append(str(r.byte()))
            while True:
                j = r.byte()
                if not j:
                    break
                ins.args.append(str(j & 127) if j & 128 else 'IG')

        elif op in (0x19, 0x39, 0x59, 0x79, 0x99, 0xB9, 0xD9, 0xF9):
            ins.nome = 'doSentence'
            nxt = r.guarda()
            if not (op & A) and nxt == 0xFC:
                r.byte()
                ins.args.append('STOP')
            elif not (op & A) and nxt == 0xFB:
                r.byte()
                ins.args.append('RESET')
            else:
                ins.args.append(self._vb(r, op, A))
                ins.args.append(self._vw(r, op, B))
                ins.args.append(self._vw(r, op, C))
                ins.args.append(str(r.byte()))

        elif op in (0x14, 0x94):
            ins.nome = 'print'
            ins.args.append(self._vb(r, op, A))
            ins.args.append(self._pstr(r))

        elif op == 0xD8:
            ins.nome = 'printEgo'
            ins.args.append(self._pstr(r))

        # --- the rest, all fixed shape --------------------------------
        elif op in TABELLA:
            nome, spec = TABELLA[op]
            ins.nome = nome
            if spec and spec[0] == '=':
                risultato()
                spec = spec[1:]
            semplice(nome, *spec)

        else:
            raise Fine(f"opcode ${op:02X} sconosciuto")

        ins.size = r.pc - pc
        ins.finale = (op in TERMINALI
                      or (op == 0x62 and ins.args == ['0']))
        return ins

    # --- paths ----------------------------------------------------------
    def cammina(self, start=0):
        """Follows every reachable branch. Returns {offset: instruction}.

        It is the same check used on the BASS bytecode: if a jump lands
        in the middle of an instruction, the table is wrong somewhere,
        and I want to know at once.
        """
        viste = {}
        errori = []
        da_fare = [start]
        while da_fare:
            pc = da_fare.pop()
            while True:
                if pc in viste:
                    break
                if pc >= len(self.data):
                    break
                try:
                    ins = self.decodifica(pc)
                except Fine as e:
                    errori.append(f"${self.base + pc:04X}: {e}")
                    break
                viste[pc] = ins
                if ins.salto is not None:
                    dest = ins.salto - self.base
                    if 0 <= dest <= len(self.data):
                        da_fare.append(dest)
                    else:
                        errori.append(
                            f"${ins.addr:04X}: salto fuori ({ins.salto:04X})")
                if ins.finale:
                    break
                pc += ins.size
        return viste, errori

    def verifica(self):
        """Checks that jumps land on the start of an instruction."""
        viste, errori = self.cammina()
        confini = set(viste)
        for pc, ins in sorted(viste.items()):
            if ins.salto is None:
                continue
            dest = ins.salto - self.base
            if dest != len(self.data) and dest not in confini:
                errori.append(
                    f"${ins.addr:04X}: salto a ${ins.salto:04X}, che non e' "
                    f"un inizio di istruzione")
        # how much of the block was covered
        coperto = sum(i.size for i in viste.values())
        return viste, errori, coperto


# A V2 resource header: a word with the total length, then two bytes
# the engine skips (ScummVM: _resourceHeaderSize = 4 for GF_OLD_BUNDLE).
RES_HDR = 4


def blocco_risorsa(data, off):
    """A resource's contents, without its header."""
    size = struct.unpack_from('<H', data, off)[0]
    return data[off + RES_HDR:off + size]


def scarica_script(idx, n):
    """The bytecode of global script n, and which room it comes from."""
    room = idx.scripts.rooms[n]
    off = idx.scripts.offsets[n]
    if off in (0, 0xFFFF):
        raise Fine("script non presente")
    return blocco_risorsa(idx.room_file(room), off), room, off


def stanza_script(data):
    """A room's entry and exit scripts, from the pointers in the header."""
    excd = struct.unpack_from('<H', data, 0x18)[0]
    encd = struct.unpack_from('<H', data, 0x1A)[0]
    fine = struct.unpack_from('<H', data, 0)[0]
    out = {}
    if excd:
        out['exit'] = (excd, data[excd:encd or fine])
    if encd:
        out['entry'] = (encd, data[encd:fine])
    return out


def main(argv):
    src = argv[1]
    idx = Index(src)
    scelta = argv[2] if len(argv) > 2 else None

    if scelta and scelta.upper().startswith('S'):
        n = int(scelta[1:])
        data, room, off = scarica_script(idx, n)
        d = Dis(data)
        viste, errori, coperto = d.verifica()
        print(f"script {n}: stanza {room}, offset ${off:04X}, "
              f"{len(data)} byte, {len(viste)} istruzioni")
        for pc in sorted(viste):
            print(viste[pc].riga())
        for e in errori:
            print("  !! " + e)
        return

    if scelta and scelta.upper().startswith('R'):
        n = int(scelta[1:])
        data = idx.room_file(n)
        for nome, (off, blob) in stanza_script(data).items():
            d = Dis(blob, base=0)
            viste, errori, coperto = d.verifica()
            print(f"stanza {n} {nome}: ${off:04X}, {len(blob)} byte, "
                  f"{len(viste)} istruzioni")
            for pc in sorted(viste):
                print(viste[pc].riga())
            for e in errori:
                print("  !! " + e)
        return

    # no choice given: go through every script and report how it went
    conta = {}
    ok = rotti = 0
    for n in range(len(idx.scripts)):
        try:
            data, room, off = scarica_script(idx, n)
        except Exception:
            continue
        d = Dis(data)
        viste, errori, coperto = d.verifica()
        if errori:
            rotti += 1
            print(f"script {n:>3} (stanza {room:>2}): {errori[0]}")
        else:
            ok += 1
        for ins in viste.values():
            conta[ins.nome] = conta.get(ins.nome, 0) + 1
    print(f"\n{ok} script letti per intero, {rotti} con problemi")
    if '--conta' in argv:
        print(f"\n{len(conta)} comandi diversi usati:")
        for nome, c in sorted(conta.items(), key=lambda x: -x[1]):
            print(f"  {c:>5}  {nome}")


if __name__ == '__main__':
    main(sys.argv)
