#!/usr/bin/env python3
"""Pack Amiga V2 music (sounds 50 and 58) for the IIGS player.

    python3 tools/pack_music.py --amiga-2mg 2mg --map music/map.txt --out stage/MM/MUS

Writes MUSI (index), MUS0 (DOC waves), MUSQ (per-track event lists).
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dump_v2a_music import TRACKS, events, extract_folder_from_2mg, inst_wave, instruments
from sfx_amiga import IndexL, _amiga_unsigned, _freq_offset, _pad_page, sound_blob


def parse_map(path):
    cfg = {
        'intro': 58, 'amiga50': 50, 'amiga58': 58,
        'house': 0, 'house_follow': 0,
        'ego': [0] * 8,
    }
    for line in open(path):
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        p = line.split()
        if p[0] == 'ego' and len(p) >= 3:
            n, tid = int(p[1]), int(p[2])
            if 1 <= n <= 7:
                cfg['ego'][n] = tid
        elif p[0] in cfg and p[0] != 'ego':
            cfg[p[0]] = int(p[1])
    return cfg


def expand_wave(rec, blob, sampoff):
    raw = inst_wave(blob, sampoff, rec)
    one, loop = rec['len'], rec['looplen']
    if loop > 8 and len(raw) < 4096:
        chunk = raw[one:] if one < len(raw) else raw[-loop:]
        if chunk:
            extra = bytearray(raw)
            while len(extra) < 4096:
                extra.extend(chunk)
            raw = bytes(extra[:8192])
    wave = _pad_page(_amiga_unsigned(raw))
    pages = len(wave) // 256
    p2 = 1
    while p2 < pages:
        p2 *= 2
    p2 = min(p2, 8)
    if len(wave) < p2 * 256:
        wave = wave + bytes([0x80] * (p2 * 256 - len(wave)))
    else:
        wave = wave[:p2 * 256]
    return wave, p2


def track_events(blob, sid):
    instoff, _vol, c1, c2, c3, c4, sampoff, _looped, _crc = TRACKS[sid]
    bounds = [c1, c2, c3, c4, sampoff]
    ev = [[] for _ in range(4)]
    for ch in range(4):
        for e in events(blob, bounds[ch], bounds[ch + 1]):
            if e.get('end'):
                continue
            ev[ch].append(e)
    return ev, instoff, sampoff


def events_bin(ev, imap):
    parts = []
    counts = []
    for ch in range(4):
        recs = [e for e in ev[ch] if not e.get('end')]
        counts.append(len(recs))
        blob = bytearray()
        for e in recs:
            inst = imap.get(e.get('inst', 0), 0)
            freq = _freq_offset(e['period'])
            dur = max(1, min(65535, e['dur']))
            tick = min(65535, e['tick'])
            blob += struct.pack('<HHHBB', tick, freq, dur, inst, 0)
        parts.append(bytes(blob))
    return struct.pack('<HHHH', *counts) + b''.join(parts)


def main():
    amiga = None
    mapp = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'music', 'map.txt')
    dest = 'MUS'
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == '--amiga-2mg':
            amiga, i = args[i + 1], i + 2
        elif args[i] == '--map':
            mapp, i = args[i + 1], i + 2
        elif args[i] == '--out':
            dest, i = args[i + 1], i + 2
        elif args[i] == '--nes':
            i += 2
        else:
            i += 1
    if not amiga:
        sys.exit('need --amiga-2mg')
    cfg = parse_map(mapp)
    want = set(filter(None, [
        cfg['intro'], cfg['amiga50'], cfg['amiga58'], cfg['house'],
        *cfg['ego'][1:],
    ]))
    ids = [s for s in (58, 50) if s in want and s in TRACKS]
    for s in sorted(want):
        if s in TRACKS and s not in ids:
            ids.append(s)
    print('map', cfg, 'amiga tracks', ids)

    folder = extract_folder_from_2mg(amiga)
    idx = IndexL(folder)

    bank = bytearray()
    samp_dir = [(0, 0)] * 8
    slot = 0
    maps = {}

    for sid in ids:
        blob = sound_blob(idx, sid)
        ev, instoff, sampoff = track_events(blob, sid)
        insts = instruments(blob, instoff)
        used = set()
        for ch in ev:
            for e in ch:
                used.add(e.get('inst', 0))
        keep = used & {0, 1, 4}
        if keep:
            used = keep
        imap = {}
        for rec in insts:
            if rec is None or rec['i'] not in used:
                continue
            if slot >= 8:
                print('  inst slot full, skip', sid, rec['i'])
                continue
            wave, pages = expand_wave(rec, blob, sampoff)
            if len(bank) + len(wave) > 32768:
                print('  inst', sid, rec['i'], 'does not fit DOC bank')
                continue
            page = len(bank) // 256
            bank.extend(wave)
            samp_dir[slot] = (page, pages)
            imap[rec['i']] = slot
            print(f'  sample {sid} inst {rec["i"]} -> slot {slot} '
                  f'page={page} pages={pages}')
            slot += 1
        maps[sid] = (ev, imap)

    while len(bank) < 32768:
        bank.append(0x80)

    seqs = []
    table = []
    off = 0
    for sid in ids:
        ev, imap = maps[sid]
        blob = events_bin(ev, imap)
        n = sum(struct.unpack_from('<HHHH', blob, 0))
        table.append((sid, len(blob), off))
        seqs.append(blob)
        off += len(blob)
        print(f'  track {sid} events={n} {len(blob)} B')

    hdr = bytearray(256)
    hdr[0:4] = b'GMUS'
    struct.pack_into('<HHHHHH', hdr, 4,
                     len(table), cfg['house_follow'] & 1, cfg['house'],
                     cfg['amiga50'], cfg['amiga58'], 8)
    for i in range(8):
        struct.pack_into('<H', hdr, 16 + i * 2, cfg['ego'][i])
    for i in range(8):
        page, pages = samp_dir[i]
        struct.pack_into('<BB', hdr, 32 + i * 2, page, pages)
    for i, (sid, nbytes, pos) in enumerate(table):
        struct.pack_into('<HHI', hdr, 48 + i * 8, sid, nbytes, pos)

    open(dest + 'I', 'wb').write(bytes(hdr))
    open(dest + '0', 'wb').write(bytes(bank))
    open(dest + 'Q', 'wb').write(b''.join(seqs))
    print(f'wrote {dest}I {dest}0 {dest}Q  seq={off} B')


if __name__ == '__main__':
    main()
