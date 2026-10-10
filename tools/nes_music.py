#!/usr/bin/env python3
"""nes_music.py - the Maniac Mansion NES scores, played into IIGS events.

The NES release keeps its music as small scores (one blob per sound, the
same sound numbers as the PC game: 58 the title tune, 50, 55 and 70 the
others). This tool reads those blobs from a NES ROM (any language: the
music is the same, found by its shape and length), turns each note into
what the DOC can do - two square voices, a triangle, a noise voice played
as sampled drums - and writes a ZMUS file (see zak_music.py) the engine
plays with the same code as Zak's PCjr music.

    python3 tools/nes_music.py ROM.nes OUT_ZMUS [DATA_DIR]

DATA_DIR (the game's LFL folder) only supplies each sound's priority.
The NES score format and its pitch table are ScummVM's (extract_mm_nes /
the MM NES player, GPL-2.0-or-later).
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zak_music as Z

OUT_HZ = 60
NES_CLOCK = 1789772.727
# the pitch table of the NES sound engine: index -> APU timer value
FREQ_TABLE = [
    0x07F0, 0x077E, 0x0712, 0x06AE, 0x064E, 0x05F3, 0x059E, 0x054D,
    0x0501, 0x04B9, 0x0475, 0x0435, 0x03F8, 0x03BF, 0x0389, 0x0357,
    0x0327, 0x02F9, 0x02CF, 0x02A6, 0x0280, 0x025C, 0x023A, 0x021A,
    0x01FC, 0x01DF, 0x01C4, 0x01AB, 0x0193, 0x017C, 0x0167, 0x0152,
    0x013F, 0x012D, 0x011C, 0x010C, 0x00FD, 0x00EE, 0x00E1, 0x00D4,
    0x00C8, 0x00BD, 0x00B2, 0x00A8, 0x009F, 0x0096, 0x008D, 0x0085,
    0x007E, 0x0076, 0x0070, 0x0069, 0x0063, 0x005E, 0x0058, 0x0053,
    0x004F, 0x004A, 0x0046, 0x0042, 0x003E, 0x003A, 0x0037, 0x0034,
]
# which APU channel an instrument number plays on: 0 pulse A, 1 pulse B,
# 2 triangle, 3 noise
INST_CH = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 1, 3, 3, 3]
# blob length -> the sound number it has in the game (USA table)
LENGTHS = {0x832: 58, 0x5D1: 50, 0x98E: 55, 0x49E: 70}


def blob_length(b):
    n = b[2]
    i = 3 + 2 * n
    while i < len(b) and b[i] not in (0xFE, 0xFF):
        i += 1
    return i + 1


def find_scores(prg):
    out = {}
    for m in re.finditer(b'\x02\x64', prg):
        h = m.start()
        b = prg[h:h + 0x3000]
        if len(b) < 8 or b[2] == 0:
            continue
        ln = blob_length(b)
        if ln in LENGTHS and LENGTHS[ln] not in out:
            out[LENGTHS[ln]] = b[:ln]
    return out


def parse_score(blob):
    """Notes per channel: (tick, duration, pitch index, instrument) and the
    tick the score ends at, plus whether it loops."""
    n = blob[2]
    aux1 = blob[3:3 + n]
    aux2 = blob[3 + n:3 + 2 * n]
    stream = blob[3 + 2 * n:]
    tick = 0
    i = 0
    opened = [None] * 4
    notes = [[] for _ in range(4)]
    loops = False

    def close(ch, t):
        o = opened[ch]
        if o:
            notes[ch].append((o[0], max(1, t - o[0]), o[1], o[2]))
            opened[ch] = None

    while i < len(stream):
        b = stream[i]
        i += 1
        if b == 0xFF or b == 0xFE:
            loops = (b == 0xFE)
            for ch in range(4):
                close(ch, tick)
            break
        if b < n:
            inst, pitch = aux1[b], aux2[b]
            ch = INST_CH[inst & 15]
            close(ch, tick)
            opened[ch] = (tick, pitch, inst)
            continue
        b -= n
        if b < 16:
            close(INST_CH[b], tick)
            continue
        tick += max(1, b - 16)
    for ch in range(4):
        close(ch, tick)
    return notes, tick, loops


def hz_of(pitch, divisor):
    return NES_CLOCK / (divisor * (FREQ_TABLE[pitch & 63] + 1))


def drum_kind(pitch):
    if pitch <= 13:
        return 3                       # kick
    if pitch <= 16:
        return 2                       # snare
    return 1                           # hat


def score_events(blob):
    notes, end, loops = parse_score(blob)
    ev = []                            # (tick, order, voice, state)
    for ch in range(3):
        v = ch
        for tick, dur, pitch, inst in notes[ch]:
            if ch == 2:                # the triangle: one octave lower, no envelope
                hz = hz_of(pitch, 32)
                div, nb, step = Z.PCJR_CLK / hz, 4, 3
            else:
                hz = hz_of(pitch, 16)
                div, nb, step = Z.PCJR_CLK / hz, 0, (2 if ch == 0 else 4)
            if hz > 4200 or hz < 30:
                continue
            ev.append((tick, 1, v, (div, step, nb)))
            if ch < 2 and dur > 8:     # a pulse note fades a little
                for k in range(1, 4):
                    t = tick + 8 * k
                    if t < tick + dur:
                        ev.append((t, 1, v, (div, min(10, step + k), nb)))
            ev.append((tick + dur, 0, v, None))
    for tick, dur, pitch, inst in notes[3]:
        kind = drum_kind(pitch)
        ev.append((tick, 1, 3, 'drum'))
        ev[-1] = (tick, 1, 3, (kind, 3))
    ev.sort(key=lambda e: (e[0], e[1]))
    out = []
    for tick, _o, v, st in ev:
        if v == 3:
            out.append((tick, 3, None))               # halt: the hit starts over
            out.append((tick, 6, st))
        else:
            out.append((tick, v, st))
    out.append((end, 5, None))
    return out, (0 if loops else None)


def main():
    rom, out = sys.argv[1], sys.argv[2]
    data = sys.argv[3] if len(sys.argv) > 3 else None
    raw = open(rom, 'rb').read()
    prg = raw[16:16 + 262144] if raw[:4] == b'NES\x1a' else raw[:262144]
    scores = find_scores(prg)
    prio = {}
    if data:
        from lfl import Index
        ix = Index(data)
        for n in scores:
            b = Z.sound_blob(ix, n, {})
            if b:
                prio[n] = (b[4], b[5])
    nsnd = 71
    table = [(0, 0, 0, 0, 0xFFFF, 0)] * Z.NSLOTS
    table = list(table)
    body = bytearray()
    hdr = 6 + 16 * Z.NSLOTS + len(Z.wave_block())
    for n in sorted(scores):
        ev, lp = score_events(scores[n])
        pk, loff = Z.pack_events(ev, lp)
        pr, rs = prio.get(n, (10, 0))
        table[n] = (hdr + len(body), len(pk), pr, rs,
                    0xFFFF if lp is None else lp, loff)
        body += pk
        print(f'  sound {n}: {len(ev)} events, {ev[-1][0] / OUT_HZ:.1f} s'
              f'{" (loops)" if lp is not None else ""}')
    with open(out, 'wb') as f:
        f.write(b'ZMUS' + struct.pack('<H', nsnd))
        for off, ln, pr, rs, lt, lo in table:
            f.write(struct.pack('<IIBBHI', off, ln, pr, rs, lt, lo))
        f.write(Z.wave_block())
        f.write(body)
    print(f'{len(scores)} scores, {len(body)} bytes of events -> {out}')


if __name__ == '__main__':
    main()
