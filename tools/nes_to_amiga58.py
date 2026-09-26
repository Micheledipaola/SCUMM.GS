#!/usr/bin/env python3
"""NES Maniac music streams → Amiga-58 sample cover (preview + event dump).

Same scores as the NES blobs (startSound 2, 71–81, …), same wavetables as
Amiga sound 58. Output lands in build/nes_dump/ (gitignored).

    python3 tools/nes_to_amiga58.py \\
        --nes "Maniac Mansion (USA).nes" \\
        --amiga-2mg "/path/SCUMM-AMIGA.2mg"
"""
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dump_nes_music import SOUNDS, load_prg
from dump_v2a_music import (
    TRACKS, BASE, _acf_cycle, extract_folder_from_2mg, instruments,
    inst_wave, render_mix, signed8, sound_blob,
)
from sfx_amiga import IndexL

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
INST_CH = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 1, 3, 3, 3]
NES_CLOCK = 1789772.727

# Soundtrack names (OST order for 71–77). Aliases of the intro omitted.
NAMES = {
    2: 'intro',
    49: 'short49',
    50: 'short50',
    55: 'track55',
    70: 'track70',
    71: 'dave',
    72: 'razor',
    73: 'bernard',
    74: 'syd',
    75: 'wendy',
    76: 'jeff',
    77: 'michael',
    78: 'house',
    79: 'cue79',
    80: 'cue80',
    81: 'unused81',
}

# NES APU channel → Amiga 58 instrument
CH_INST = {0: 0, 1: 0, 2: 4, 3: 1}


def nes_hz(pitch):
    t = FREQ_TABLE[pitch & 63]
    return NES_CLOCK / (16.0 * (t + 1))


def paula_period(hz, cycle):
    if hz < 20 or not cycle:
        return 0x1C2
    p = int(BASE / (hz * cycle) + 0.5)
    return max(0x54, min(0x7FF, p))


def parse_nes(blob, loops=1):
    if len(blob) < 4 or blob[0] != 2:
        return None
    n = blob[2]
    aux1 = blob[3:3 + n]
    aux2 = blob[3 + n:3 + 2 * n]
    stream = blob[3 + 2 * n:]
    if len(aux1) < n or len(aux2) < n:
        return None
    tick = 0
    nloop = 0
    i = 0
    open_n = [None] * 4
    ev = [[] for _ in range(4)]

    def close(ch, t):
        o = open_n[ch]
        if not o:
            return
        dur = max(1, t - o['tick'])
        ev[ch].append({
            'tick': o['tick'], 'period': o['period'], 'dur': dur,
            'chan': ch, 'inst': o['inst'], 'end': False,
            'nes_inst': o['nes_inst'], 'pitch': o['pitch'],
        })
        open_n[ch] = None

    while i < len(stream) and tick < 60 * 120:
        b = stream[i]
        i += 1
        if b == 0xFF:
            for ch in range(4):
                close(ch, tick)
            break
        if b == 0xFE:
            nloop += 1
            if nloop >= loops:
                for ch in range(4):
                    close(ch, tick)
                break
            i = 0
            continue
        if b < n:
            inst = aux1[b]
            pitch = aux2[b]
            ch = INST_CH[inst & 15]
            close(ch, tick)
            open_n[ch] = {
                'tick': tick, 'pitch': pitch, 'nes_inst': inst,
                'inst': CH_INST[ch], 'period': pitch,
            }
            continue
        b -= n
        if b < 16:
            close(INST_CH[b], tick)
            continue
        tick += max(1, b - 16)
    for ch in range(4):
        close(ch, tick)
        ev[ch].append({'tick': tick, 'end': True})
    return ev


def fill_periods(ev, cycles):
    for ch, notes in enumerate(ev):
        cyc = cycles.get(CH_INST[ch], 32)
        for e in notes:
            if e.get('end'):
                continue
            if ch == 3 and CH_INST[3] == 1:
                e['period'] = 0x012C
            else:
                e['period'] = paula_period(nes_hz(e['pitch']), cyc)


def cycle_of(blob58, rec, sampoff):
    wave = inst_wave(blob58, sampoff, rec)
    sig = [signed8(b) for b in wave[rec['len']:] or wave]
    return _acf_cycle(sig) or 32


def load_58(amiga_2mg):
    folder = extract_folder_from_2mg(amiga_2mg)
    blob = sound_blob(IndexL(folder), 58)
    instoff, voloff, *chs, sampoff, _loop, _crc = TRACKS[58]
    insts = instruments(blob, instoff)
    cycles = {}
    for rec in insts:
        if rec is None:
            continue
        cycles[rec['i']] = cycle_of(blob, rec, sampoff)
        print(f'  amiga58 inst {rec["i"]} cycle={cycles[rec["i"]]} '
              f'len={rec["len"]}+{rec["looplen"]}')
    return blob, instoff, voloff, chs, sampoff, insts, cycles


def main():
    nes_path = 'Maniac Mansion (USA).nes'
    amiga = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         '..', 'altri SCUMM', 'SCUMM-AMIGA.2mg')
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == '--nes':
            nes_path = args[i + 1]
            i += 2
        elif args[i] == '--amiga-2mg':
            amiga = args[i + 1]
            i += 2
        else:
            i += 1
    dest = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'build', 'nes_dump')
    os.makedirs(dest, exist_ok=True)

    print('NES', nes_path)
    prg = load_prg(nes_path)
    print('Amiga 58 samples')
    blob58, instoff, voloff, chs, sampoff, insts, cycles = load_58(amiga)

    index = []
    for sid, name in NAMES.items():
        off, ln = SOUNDS[sid]
        raw = prg[off:off + ln]
        ev = parse_nes(raw, loops=1)
        if not ev:
            print(f'  {sid} {name}: not music')
            continue
        nnotes = sum(len([e for e in ch if not e.get('end')]) for ch in ev)
        last = 0
        for ch in ev:
            for e in ch:
                if not e.get('end'):
                    last = max(last, e['tick'] + e['dur'])
        fill_periods(ev, cycles)
        print(f'  {sid:3d} {name:10s}  {ln:5d} B  notes={nnotes:4d}  '
              f'{last / 60:.1f}s')
        slim = []
        for ch in range(4):
            slim.append([{k: e[k] for k in e if k in (
                'tick', 'period', 'dur', 'chan', 'inst', 'end', 'pitch')}
                for e in ev[ch]])
        open(os.path.join(dest, f'{sid:02d}_{name}.json'), 'w').write(
            json.dumps({'id': sid, 'name': name, 'events': slim}))
        wav = os.path.join(dest, f'{sid:02d}_{name}_amiga58.wav')
        render_mix(blob58, instoff, voloff, chs, sampoff, insts, ev, wav)
        index.append({'id': sid, 'name': name, 'seconds': last / 60,
                      'notes': nnotes, 'wav': os.path.basename(wav)})
    open(os.path.join(dest, 'index.json'), 'w').write(json.dumps(index, indent=2))
    print('wrote', dest)


if __name__ == '__main__':
    main()
