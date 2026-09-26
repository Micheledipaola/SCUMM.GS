#!/usr/bin/env python3
"""Dump Maniac Amiga V2 music resources (sounds 50 and 58).

Layout is the ScummVM V2A_Sound_Music map (GPL player_v2a.cpp):
  Music(inst, vol, ch1, ch2, ch3, ch4, samples, loop)

Offsets are from the start of the XOR-decoded sound blob.
Game data is written under build/ (gitignored), never into src/.

    python3 tools/dump_v2a_music.py --from-2mg ../altri\\ SCUMM/SCUMM-AMIGA.2mg
"""
import math
import os
import struct
import sys
import tempfile
import wave
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx_amiga import IndexL, _crc32_scumm, sound_blob
from prodos2mg import load_2mg, walk, file_bytes

# sound id -> (inst, vol, ch1, ch2, ch3, ch4, samp, looped, crc)
TRACKS = {
    50: (0x0032, 0x00B2, 0x08B2, 0x1222, 0x1A52, 0x23C2, 0x3074, False, 0xB1AB065C),
    58: (0x0032, 0x0132, 0x0932, 0x1802, 0x23D2, 0x3EA2, 0x4F04, False, 0x091F5D9C),
}

BASE = 3579545


def be16(data, off):
    return struct.unpack_from('>H', data, off)[0]


def events(data, start, end):
    """16-byte big-endian events until period == $FFFF or start >= end."""
    out = []
    p = start
    while p + 16 <= end:
        tick = be16(data, p)
        period = be16(data, p + 2)
        if period == 0xFFFF:
            out.append({'tick': tick, 'end': True, 'off': p})
            break
        rec = {
            'off': p,
            'tick': tick,
            'period': period,
            'dur': be16(data, p + 4),
            'chan': be16(data, p + 6) & 3,
            'inst': be16(data, p + 8),
            'u10': be16(data, p + 10),
            'u12': be16(data, p + 12),
            'u14': be16(data, p + 14),
            'end': False,
        }
        out.append(rec)
        p += 16
    return out


def instruments(data, instoff, n=16):
    recs = []
    for i in range(n):
        o = instoff + i * 32
        if o + 32 > len(data):
            break
        raw = data[o:o + 32]
        if raw == b'\x00' * 32:
            recs.append(None)
            continue
        recs.append({
            'i': i,
            'volidx': be16(raw, 0),
            'w02': be16(raw, 2),
            'w04': be16(raw, 4),
            'w06': be16(raw, 6),
            'w08': be16(raw, 8),
            'w0a': be16(raw, 10),
            'w0c': be16(raw, 12),
            'w0e': be16(raw, 14),
            'looplen': be16(raw, 0x10),
            'w12': be16(raw, 0x12),
            'offset': be16(raw, 0x14),
            'loopoff': be16(raw, 0x16),
            'len': be16(raw, 0x18),
            'w1a': be16(raw, 0x1A),
            'w1c': be16(raw, 0x1C),
            'w1e': be16(raw, 0x1E),
        })
    return recs


def inst_wave(data, sampoff, inst):
    """Same concatenation ScummVM uses: oneshot then loop."""
    if inst is None:
        return b''
    off = sampoff + inst['offset']
    loop = sampoff + inst['loopoff']
    a = data[off:off + inst['len']]
    b = data[loop:loop + inst['looplen']]
    return a + b


def write_wav(path, signed8, period):
    hz = max(1, int(BASE / max(period, 1)))
    # DOC/Paula 8-bit signed -> WAV unsigned
    pcm = bytes((b + 128) & 0xFF for b in signed8)
    if len(pcm) < 2:
        pcm = pcm + b'\x80'
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(hz)
        w.writeframes(pcm)


def analyze(sid, blob, dest):
    instoff, voloff, *chs, sampoff, looped, expect = TRACKS[sid]
    choffs = chs
    size_le = struct.unpack_from('<H', blob, 0)[0]
    crclen = struct.unpack_from('>H', blob, 8)[0]
    crc = _crc32_scumm(blob[0x0A:0x0A + crclen]) if crclen else 0
    print(f'\n=== sound {sid} ===')
    print(f'  blob {len(blob)} B  sizeLE={size_le}  crc={crc:08X} expect={expect:08X}'
          f'  looped={looped}')
    print(f'  inst=${instoff:04X} vol=${voloff:04X} samp=${sampoff:04X}'
          f'  ch={[hex(c) for c in choffs]}')
    print(f'  sample payload {len(blob) - sampoff} B  seq {sampoff - instoff} B')

    bounds = sorted(choffs + [sampoff, len(blob)])
    used_inst = set()
    all_ev = []
    for i, start in enumerate(choffs):
        end = bounds[bounds.index(start) + 1] if start in bounds else len(blob)
        ev = events(blob, start, end)
        all_ev.append(ev)
        notes = [e for e in ev if not e['end']]
        last_tick = notes[-1]['tick'] + notes[-1]['dur'] if notes else 0
        insts = sorted({e['inst'] for e in notes})
        used_inst.update(insts)
        periods = sorted({e['period'] for e in notes})
        print(f'  ch{i} @{start:04X}: {len(notes)} notes  end_tick={last_tick}'
              f'  (~{last_tick / 60:.1f}s @60Hz)  inst={insts}'
              f'  periods {len(periods)} unique')
        if ev and ev[-1].get('end'):
            print(f'       terminator tick={ev[-1]["tick"]}')

    insts = instruments(blob, instoff)
    sample_map = {}
    total_wave = 0
    padded = 0
    os.makedirs(dest, exist_ok=True)
    print('  instruments (32 B each):')
    for rec in insts:
        if rec is None:
            continue
        if rec['i'] not in used_inst and rec['len'] == 0 and rec['looplen'] == 0:
            continue
        wave = inst_wave(blob, sampoff, rec)
        key = (rec['offset'], rec['len'], rec['loopoff'], rec['looplen'])
        sample_map.setdefault(key, []).append(rec['i'])
        pad = (len(wave) + 255) & ~255
        total_wave += len(wave)
        padded += pad
        mark = 'USED' if rec['i'] in used_inst else 'idle'
        print(f'    #{rec["i"]:2d} {mark} volidx={rec["volidx"]}  '
              f'one={rec["offset"]}+{rec["len"]}  '
              f'loop={rec["loopoff"]}+{rec["looplen"]}  '
              f'wave={len(wave)} pad256={pad}  '
              f'w02={rec["w02"]:04X} w12={rec["w12"]:04X}')
        if wave:
            # typical mid note ~ period $016E
            write_wav(os.path.join(dest, f'snd{sid}_inst{rec["i"]:02d}.wav'),
                      wave, 0x016E)

    unique = 0
    for key, ids in sample_map.items():
        off, ln, lo, ll = key
        unique += ln + ll
        if len(ids) > 1:
            print(f'    shared sample {key} by inst {ids}')
    print(f'  unique sample bytes (oneshot+loop, no pad): {unique}')
    print(f'  sum of used waves (may duplicate): {total_wave}, page-padded {padded}')
    print(f'  vol tables: ${voloff:04X}..${choffs[0]:04X} = {choffs[0] - voloff} B'
          f'  ({(choffs[0] - voloff) / 512:.1f} blocks of 512)')

    raw_path = os.path.join(dest, f'snd{sid}.bin')
    open(raw_path, 'wb').write(blob)
    print(f'  wrote {raw_path}')
    mix_path = os.path.join(dest, f'snd{sid}_mix.wav')
    render_mix(blob, instoff, voloff, choffs, sampoff, insts, all_ev, mix_path)
    if sid == 58:
        doc_waves = {}
        for rec in insts:
            if rec is None:
                continue
            orig = inst_wave(blob, sampoff, rec)
            if orig:
                doc_waves[rec['i']] = doc_replace(rec, orig)
                write_wav(os.path.join(dest, f'snd{sid}_doc_inst{rec["i"]:02d}.wav'),
                          doc_waves[rec['i']], 0x016E)
        doc_path = os.path.join(dest, f'snd{sid}_doc.wav')
        render_mix(blob, instoff, voloff, choffs, sampoff, insts, all_ev, doc_path,
                   waves=doc_waves)
    return padded


RATE = 22050
TICK_HZ = 60


def signed8(b):
    return b - 256 if b >= 128 else b


def _acf_cycle(sig, lo=10, hi=None):
    n = len(sig)
    if n < 40:
        return None
    hi = min(hi or n // 3, n // 2)
    mean = sum(sig) / n
    s = [x - mean for x in sig]
    best, bp = -1.0, None
    for p in range(lo, hi):
        acc = 0.0
        for i in range(0, n - p, 2):
            acc += s[i] * s[i + p]
        if acc > best:
            best, bp = acc, p
    return bp


def _pcm8(vals):
    out = bytearray(len(vals))
    for i, v in enumerate(vals):
        x = int(max(-118, min(118, v)))
        out[i] = (x + 128) & 0xFF
        if out[i] == 0:
            out[i] = 1
    return bytes(out)


def doc_replace(rec, orig):
    """Same length / loop points as the Amiga instrument, cleaner DOC-like wave.

    Pitch stays put because the cycle length of the loop is kept; only the
    spectrum changes (band-limited pulse/bass/pluck or a short noise hit).
    """
    n = len(orig)
    n_one, n_loop = rec['len'], rec['looplen']
    sig = [signed8(b) for b in orig]
    loop = sig[n_one:] if n_loop > 8 else sig
    cyc = _acf_cycle(loop) if loop else None
    perc = n_loop <= 8
    out = [0.0] * n

    def tone(i, cyc, partials):
        if not cyc:
            return 0.0
        a = 0.0
        for h, amp in partials:
            a += amp * math.sin(2 * math.pi * h * i / cyc)
        return a

    if perc:
        for i in range(n):
            t = i / max(n, 1)
            env = math.exp(-t * (18 if n < 900 else 8))
            if n < 900:
                ny = 1.0 if ((i * 57 + 13) ^ (i * 91)) & 32 else -1.0
                out[i] = 90 * env * ny + 40 * env * math.sin(2 * math.pi * i / 9)
            else:
                c = max(18, 70 - t * 40)
                out[i] = 110 * env * math.sin(2 * math.pi * i / c)
    else:
        if rec['i'] in (0,):
            partials = ((1, 70), (2, 28), (3, 18), (4, 8), (6, 5))
        elif rec['i'] in (4,):
            partials = ((1, 90), (2, 35), (3, 12))
        else:
            partials = ((1, 80), (2, 20), (3, 25), (5, 8))
        if not cyc:
            cyc = 32
        for i in range(n):
            env = 1.0
            if n_one and i < n_one:
                env = min(1.0, i / 24) * (0.7 + 0.3 * (i / n_one))
            if rec['i'] not in (0, 4) and n_loop <= 8:
                env *= math.exp(-i / max(n * 0.45, 1))
            out[i] = env * tone(i, cyc, partials)
        if n_loop > 8:
            fade = min(32, n_loop // 4)
            for k in range(fade):
                t = (k + 1) / fade
                j = n_one + n_loop - fade + k
                out[j] = out[j] * (1 - t) + out[n_one + (k % cyc)] * t
    return _pcm8(out)


def render_mix(blob, instoff, voloff, choffs, sampoff, insts, all_ev, path,
               waves=None):
    """60 Hz V2A_Sound_Music mixer → stereo WAV (preview only)."""
    voices = []
    for ev in all_ev:
        voices.append({'ev': ev, 'ei': 0, 'ticks': 0, 'dur': 0,
                       'volbase': 0, 'volptr': 0, 'wave': b'',
                       'len': 0, 'loop0': 0, 'loop1': 0,
                       'pos': 0.0, 'step': 0.0, 'vol': 0, 'on': False})
    last = 0
    for ev in all_ev:
        notes = [e for e in ev if not e['end']]
        if notes:
            last = max(last, notes[-1]['tick'] + notes[-1]['dur'] + 8)
    ntick = last + 1
    nsamp = int(ntick * RATE / TICK_HZ)
    left = [0] * nsamp
    right = [0] * nsamp
    sp_tick = RATE / TICK_HZ
    inst_by_i = {r['i']: r for r in insts if r}

    def start_note(v, e):
        rec = inst_by_i.get(e['inst'])
        if not rec or e['period'] == 0:
            v['on'] = False
            return
        wave = waves[rec['i']] if waves and rec['i'] in waves else inst_wave(blob, sampoff, rec)
        v['wave'] = wave
        v['len'] = rec['len']
        v['loop0'] = rec['len']
        v['loop1'] = rec['len'] + rec['looplen']
        v['pos'] = 0.0
        v['step'] = (BASE / e['period']) / RATE
        v['dur'] = e['dur']
        v['volbase'] = voloff + (rec['volidx'] << 9)
        v['volptr'] = 0
        v['vol'] = be16(blob, v['volbase'])
        v['volptr'] = 1
        v['on'] = True

    out_i = 0
    for tick in range(ntick):
        for vi, v in enumerate(voices):
            if v['dur']:
                v['dur'] -= 1
                if v['dur'] == 0:
                    v['on'] = False
                else:
                    vb = v['volbase'] + (v['volptr'] << 1)
                    if vb + 2 <= len(blob):
                        v['vol'] = be16(blob, vb)
                    v['volptr'] = (v['volptr'] + 1) & 0xFF
                    if v['volptr'] == 0:
                        v['on'] = False
                        v['dur'] = 0
            ev = v['ev']
            while v['ei'] < len(ev):
                e = ev[v['ei']]
                if e.get('end'):
                    break
                if e['tick'] > v['ticks']:
                    break
                start_note(v, e)
                v['ei'] += 1
            v['ticks'] += 1

        n = int(round((tick + 1) * sp_tick)) - out_i
        for _ in range(n):
            if out_i >= nsamp:
                break
            l = r = 0
            for vi, v in enumerate(voices):
                if not v['on'] or not v['wave']:
                    continue
                p = int(v['pos'])
                loop1 = v['loop1'] if v['loop1'] > v['loop0'] else len(v['wave'])
                if p >= loop1:
                    if v['loop1'] > v['loop0'] + 1:
                        v['pos'] = float(v['loop0'])
                        p = v['loop0']
                    else:
                        v['on'] = False
                        continue
                if p >= len(v['wave']):
                    v['on'] = False
                    continue
                s = signed8(v['wave'][p]) * v['vol']
                # Amiga: 0+3 left, 1+2 right
                if vi in (0, 3):
                    l += s
                else:
                    r += s
                v['pos'] += v['step']
            left[out_i] = l
            right[out_i] = r
            out_i += 1

    peak = max(1, max(abs(x) for x in left + right))
    scale = 30000 / peak
    frames = bytearray()
    for i in range(out_i):
        lv = int(left[i] * scale)
        rv = int(right[i] * scale)
        lv = max(-32767, min(32767, lv))
        rv = max(-32767, min(32767, rv))
        frames += struct.pack('<hh', lv, rv)
    with wave.open(path, 'w') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print(f'  mix {path}  {out_i / RATE:.1f}s')


def extract_folder_from_2mg(image):
    tmp = tempfile.mkdtemp(prefix='v2amusic_')
    vol, _ = load_2mg(image)
    folder = os.path.join(tmp, 'MM')
    os.makedirs(folder, exist_ok=True)
    for rel, ent in walk(vol):
        name = os.path.basename(rel).upper()
        if not (name.endswith('.LFL') and name.startswith('L')):
            continue
        open(os.path.join(folder, name), 'wb').write(file_bytes(vol, ent))
    return folder


def main():
    args = sys.argv[1:]
    dest = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'build', 'music_dump')
    if args and args[0] == '--from-2mg':
        folder = extract_folder_from_2mg(args[1])
    else:
        folder = args[0] if args else os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data')
    idx = IndexL(folder)
    print(idx.summary())
    for sid in (50, 58):
        room = idx.sounds.rooms[sid]
        off = idx.sounds.offsets[sid]
        blob = sound_blob(idx, sid)
        print(f'sound {sid}: room {room} offset ${off:04X} blob={None if not blob else len(blob)}')
        if blob:
            analyze(sid, blob, dest)
    print(f'\ndump dir: {dest}')


if __name__ == '__main__':
    main()
