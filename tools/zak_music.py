#!/usr/bin/env python3
"""zak_music.py - V2 PCjr sound resources, played offline into IIGS events.

Maniac Mansion and Zak McKracken (DOS, V2) keep every sound - music and
sound effects alike - in one format: a small script per voice, run by the
PCjr player at 236 steps a second. This tool runs those scripts (the logic
is ScummVM's player_v2base.cpp / player_v2.cpp, GPL-2.0-or-later, tables in
v2tables.py) and writes down, for each sound, what the four voices do, at
the 60 Hz the IIGS engine keeps time with. The engine then needs no
interpreter: it only moves the four DOC oscillators when an event is due.

    python3 tools/zak_music.py DATA_DIR OUT_ZMUS [--wav SOUND OUT.wav]

File ZMUS (little endian):

    +0   'ZMUS'
    +4   word   how many sounds the game has
    +6   table of 128 slots, 16 bytes a slot: long offset, long length (0 = no sound),
                                 byte priority, byte restartable,
                                 word loop tick ($FFFF = plays once),
                                 long loop offset (into the events)
    then 4352 bytes of waves for DOC RAM $8000 (17 pages: a square wave,
    2048 samples of white noise, 2048 of periodic noise), then the events
    of every sound, 4 bytes each:

         byte  delta, in 1/60 s since the previous event
         byte  bits 0-2 voice (0-2 tone, 3 noise, 4 music timer, 5 end of
                        sound, 7 nothing: a pause longer than 255 ticks)
               bits 3-6 volume step, 0 (loudest) .. 15 (silent)
               bit 7    white noise (voice 3; clear = periodic)
         word  DOC frequency offset  [music timer: its value]
"""
#
# Copyright (C) 2026 Michele Di Paola
# This program is free software under the GNU General Public License,
# version 2 or later. It comes with ABSOLUTELY NO WARRANTY.

import os
import math
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import v2tables as T
from lfl import Index

TICK_HZ = 236                     # the player's own clock
OUT_HZ = 60                       # the IIGS engine's
PCJR_CLK = 111860
DOC_DIV = 1645                    # TN IIGS #37: freqOffset = 32 * Hz / 1645
MINDIV = 14                       # dividers under this are ultrasonic (8 kHz+)
WAVE_LEN = 256                    # one page of square wave
MAXSECONDS = 400
NSLOTS = 128                      # slots in the file's table, whatever the game has

NG_PRESET = 0x0F35
FB_WNOISE = 0x12000
FB_PNOISE = 0x08000

# channel_data as words (ScummVM player_v2base.h)
(TIME_LEFT, NEXT_CMD, BASE_FREQ, FREQ_DELTA, FREQ, VOLUME, VOLUME_DELTA,
 TEMPO, INTER_NOTE_PAUSE, TRANSPOSE, NOTE_LENGTH, HULL_CURVE, HULL_OFFSET,
 HULL_COUNTER, FREQMOD_TABLE, FREQMOD_OFFSET, FREQMOD_INCR,
 FREQMOD_MULTIPLIER, FREQMOD_MODULO) = range(19)
MUSIC_TIMER = 23
NWORDS = 25


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


HULLS = [s16(v) for v in T.HULLS]


class PlayerV2:
    def __init__(self, data):
        self.d = data
        self.ch = [[0] * NWORDS for _ in range(5)]
        self.retaddr = 0
        self.hl = 4
        self.music_timer_ctr = 0
        self.running = True
        for i in range(4):
            nc = struct.unpack_from('<H', data, self.hl + 10 + 2 * i)[0]
            self.ch[i][NEXT_CMD] = nc
            if nc:
                self.ch[i][TIME_LEFT] = 1

    def clear(self, c):
        for k in (NEXT_CMD, BASE_FREQ, FREQ_DELTA, FREQ, VOLUME,
                  VOLUME_DELTA, INTER_NOTE_PAUSE, TRANSPOSE, HULL_CURVE,
                  HULL_OFFSET, HULL_COUNTER, FREQMOD_TABLE, FREQMOD_OFFSET,
                  FREQMOD_INCR, FREQMOD_MULTIPLIER, FREQMOD_MODULO):
            c[k] = 0

    def execute_cmd(self, ci):
        d = self.d
        cur = self.ch[ci]
        channel = cur
        end = False
        started = cur[NEXT_CMD] != 0
        p = 0
        if started:
            p = cur[NEXT_CMD]
            while not end:
                op = d[p]
                p += 1
                if op >= 0xF8:
                    if op == 0xF8:
                        channel[HULL_CURVE] = T.HULL_OFFSETS[d[p] // 2]
                        p += 1
                    elif op == 0xF9:
                        ix = d[p] // 4
                        channel[FREQMOD_TABLE] = T.FREQMOD_OFFSETS[ix]
                        channel[FREQMOD_MODULO] = T.FREQMOD_LENGTHS[ix]
                        p += 1
                    elif op == 0xFD or op == 0xFA:
                        if op == 0xFD:
                            v = struct.unpack_from('<H', d, p)[0] // 50
                            p += 2
                            if v >= 5:
                                v = 4
                            channel = self.ch[v]
                        self.clear(channel)
                    elif op == 0xFB:
                        p = self.retaddr
                    elif op == 0xFC:
                        off = struct.unpack_from('<h', d, p)[0]
                        p += 2
                        self.retaddr = p
                        p = off
                    elif op == 0xFE:
                        idx = d[p]
                        p += 1
                        off = struct.unpack_from('<h', d, p)[0]
                        p += 2
                        k = idx // 2
                        if not channel[k]:
                            p += off
                        else:
                            channel[k] = (channel[k] - 1) & 0xFFFF
                            if channel[k]:
                                p += off
                    elif op == 0xFF:
                        idx = d[p]
                        p += 1
                        val = struct.unpack_from('<H', d, p)[0]
                        channel[idx // 2] = val
                        p += 2
                        if idx == 0:
                            end = True
                else:
                    while True:
                        dest = self.ch[(op >> 5) & 3]
                        if not (op & 0x80):
                            tempo = channel[TEMPO] or 1
                            channel[TIME_LEFT] = (tempo * T.NOTE_LENGTHS[op & 0x1F]) & 0xFFFF
                            note = d[p]
                            p += 1
                            last = note & 0x80
                            note &= 0x7F
                            if note == 0x7F:
                                end = True
                                break
                        else:
                            channel[TIME_LEFT] = ((op & 7) << 8) | d[p]
                            p += 1
                            if op & 0x10:
                                end = True
                                break
                            last = 0
                            note = d[p] & 0x7F
                            p += 1
                        dest[TIME_LEFT] = channel[TIME_LEFT]
                        dest[NOTE_LENGTH] = (channel[TIME_LEFT] - dest[INTER_NOTE_PAUSE]) & 0xFFFF
                        note += s16(dest[TRANSPOSE])
                        while note < 0:
                            note += 12
                        octave = note // 12
                        note = note % 12
                        dest[HULL_OFFSET] = 0
                        dest[HULL_COUNTER] = 1
                        if dest is self.ch[3]:
                            dest[HULL_CURVE] = 196 + note * 12
                            myfreq = 384 - 64 * octave
                        else:
                            myfreq = T.PCJR_FREQ_TABLE[note] >> octave
                        dest[FREQ] = dest[BASE_FREQ] = myfreq & 0xFFFF
                        if last:
                            end = True
                            break
                        op = d[p]
                        p += 1
        # label "end:" (or check_stopped, when there was nothing to run)
        if started:
            channel = cur
            if channel[TIME_LEFT]:
                channel[NEXT_CMD] = p
                return
            channel[NEXT_CMD] = 0
        if not any(self.ch[i][TIME_LEFT] for i in range(4)):
            self.running = False

    def next_freqs(self, ci):
        c = self.ch[ci]
        c[VOLUME] = (c[VOLUME] + c[VOLUME_DELTA]) & 0xFFFF
        c[BASE_FREQ] = (c[BASE_FREQ] + c[FREQ_DELTA]) & 0xFFFF
        if c[FREQMOD_MODULO] > 0:
            c[FREQMOD_OFFSET] = (c[FREQMOD_OFFSET] + c[FREQMOD_INCR]) % c[FREQMOD_MODULO]
        else:
            c[FREQMOD_OFFSET] = 0
        fm = T.FREQMOD_TABLE[c[FREQMOD_TABLE] + (c[FREQMOD_OFFSET] >> 4)]
        fm = fm if fm < 128 else fm - 256
        val = int(fm * c[FREQMOD_MULTIPLIER] / 256) + c[BASE_FREQ]
        c[FREQ] = val & 0xFFFF
        if c[NOTE_LENGTH]:
            c[NOTE_LENGTH] = (c[NOTE_LENGTH] - 1) & 0xFFFF
            if not c[NOTE_LENGTH]:
                c[HULL_OFFSET] = 16
                c[HULL_COUNTER] = 1
        c[TIME_LEFT] = (c[TIME_LEFT] - 1) & 0xFFFF
        if not c[TIME_LEFT]:
            self.execute_cmd(ci)
        if c[HULL_COUNTER]:
            c[HULL_COUNTER] = (c[HULL_COUNTER] - 1) & 0xFFFF
            if not c[HULL_COUNTER]:
                while True:
                    h = c[HULL_CURVE] + c[HULL_OFFSET] // 2
                    if HULLS[h + 1] == -1:
                        c[VOLUME] = HULLS[h] & 0xFFFF
                        if HULLS[h] == 0:
                            c[VOLUME_DELTA] = 0
                        c[HULL_OFFSET] = (c[HULL_OFFSET] + 4) & 0xFFFF
                    else:
                        c[VOLUME_DELTA] = HULLS[h] & 0xFFFF
                        c[HULL_COUNTER] = HULLS[h + 1] & 0xFFFF
                        c[HULL_OFFSET] = (c[HULL_OFFSET] + 4) & 0xFFFF
                        break

    def tick(self):
        for i in range(4):
            if not self.ch[i][TIME_LEFT]:
                continue
            self.next_freqs(i)


def voice_state(pl):
    """What each voice sounds like right now: (divider, volume step, noise)."""
    out = []
    for i in range(4):
        c = pl.ch[i]
        audible = c[VOLUME] != 0 and c[TIME_LEFT] != 0
        vol = (65535 - c[VOLUME]) >> 12
        if not audible or vol >= 15:
            out.append(None)
            continue
        f = c[FREQ] >> 6
        if i < 3:
            if f < MINDIV:                    # above hearing on a real PCjr
                out.append(None)
                continue
            out.append((f, vol, 0))
        else:
            nb = 2 if (f & 4) else 1            # 1 periodic, 2 white
            n = f & 3
            if n == 3:
                dv = 2 * (pl.ch[2][FREQ] >> 6)
            else:
                dv = 1 << (5 + n)
            out.append((max(dv, 1), vol, nb))
    return out


_SKIP = (BASE_FREQ, FREQ, VOLUME, VOLUME_DELTA, NOTE_LENGTH, HULL_OFFSET,
         HULL_COUNTER, FREQMOD_OFFSET, FREQ_DELTA)


def find_loop(data, maxsec=MAXSECONDS):
    """(t0, t1) in player ticks if the sound repeats itself, else None."""
    pl = PlayerV2(data)
    seen = {}
    for t in range(maxsec * TICK_HZ):
        pl.tick()
        if not pl.running:
            return None
        # The musical state only: where each voice is in its script, and
        # its settings. Phases of vibrato and the slow ramps of pitch and
        # volume are left out - they never line up exactly twice.
        key = hash((tuple(tuple(v for k, v in enumerate(c)
                                if k not in _SKIP) for c in pl.ch[:4]),
                    pl.retaddr))
        if key in seen:
            return seen[key], t
        seen[key] = t
    return None


FORCE_SECONDS = 60


def sounds_on(data, seconds):
    pl = PlayerV2(data)
    for _ in range(seconds * TICK_HZ):
        pl.tick()
        if not pl.running:
            return False
    return True


def run_sound(data, maxsec=MAXSECONDS):
    """Events for one sound, ticks in 1/60 s: (events, ended, loop_k0)."""
    loop = find_loop(data, maxsec)
    k0 = k1 = None
    if loop:
        t0, t1 = loop
        k0 = -(-t0 * OUT_HZ // TICK_HZ)              # round up
        k1 = max(k0 + 1, (t1 * OUT_HZ + TICK_HZ // 2) // TICK_HZ)
    elif sounds_on(data, maxsec):
        # Never repeats exactly (voices of different lengths drifting
        # against each other, like wind chimes): play a minute of it and
        # go round again.
        loop = (0, FORCE_SECONDS * TICK_HZ)
        k0, k1 = 0, FORCE_SECONDS * OUT_HZ
    pl = PlayerV2(data)
    events = []
    last = [None, None, None, None]
    timer_last = None
    t236 = 0
    t60_next = 0
    window = [[], [], [], []]
    ended = False
    limit = maxsec * TICK_HZ
    while t236 < limit:
        pl.tick()
        st = voice_state(pl)
        for i in range(4):
            window[i].append(st[i])
        t236 += 1
        while (t60_next + 1) * TICK_HZ <= t236 * OUT_HZ:
            if loop and t60_next == k1:
                break
            if loop and t60_next == k0:
                last = [None, None, None, None]       # the loop starts whole
                timer_last = None
            for i in range(4):
                best = None
                for s in window[i]:
                    if s is None:
                        continue
                    if best is None or s[1] < best[1]:
                        best = s
                window[i] = []
                if best != last[i]:
                    events.append((t60_next, i, best))
                    last[i] = best
            mt = pl.ch[0][MUSIC_TIMER]
            if mt != timer_last:
                events.append((t60_next, 4, mt))
                timer_last = mt
            t60_next += 1
        if loop and t60_next >= k1:
            ended = True
            break
        if not pl.running:
            ended = True
            break
    events.append((t60_next, 5, None))
    return events, ended, (k0 if loop else None)


def doc_fo(hz):
    fo = int(32 * hz / DOC_DIV + 0.5)
    return max(1, min(65535, fo))


def pack_events(events, k0=None):
    """4 bytes an event: delta ticks, voice/volume byte, DOC frequency.
    Returns the bytes and the offset of the first event of the loop."""
    out = bytearray()
    prev = 0
    loop_off = 0
    for tick, v, st in events:
        if k0 is not None and tick >= k0 and not loop_off:
            # a NOP exactly at the loop's start, so deltas inside the loop
            # are measured from there and the jump back needs no fixing up
            dt = k0 - prev
            while dt > 255:
                out += struct.pack('<BBH', 255, 7, 0)
                dt -= 255
            out += struct.pack('<BBH', dt, 7, 0)
            prev = k0
            loop_off = len(out)
        dt = tick - prev
        prev = tick
        while dt > 255:
            out += struct.pack('<BBH', 255, 7, 0)
            dt -= 255
        if v == 4:
            ctl, fo = 4, st & 0xFFFF
        elif v == 5:
            ctl, fo = 5, 0
        elif st is None:
            ctl, fo = v | (15 << 3), 0
        elif v == 6:
            ctl = 6 | (min(14, st[1] + 1) << 3)
            fo = doc_fo(DRUM_HZ[st[0]]) | (st[0] << 14)
        elif v < 3:
            ctl = v | (st[1] << 3) | (0x80 if st[2] == 3 else 0)
            fo = doc_fo(PCJR_CLK / st[0] * WAVE_LEN)
            if st[2] == 4:                              # a triangle (NES scores)
                fo |= 0x8000
        else:
            ctl = 3 | (min(14, st[1] + 1) << 3) | (0x80 if st[2] == 2 else 0)   # a step softer
            fo = doc_fo(2 * PCJR_CLK / st[0])
        out += struct.pack('<BBH', dt, ctl, fo)
    return bytes(out), loop_off


def sound_blob(ix, n, cache):
    r = ix.sounds.rooms[n]
    o = ix.sounds.offsets[n]
    if r in (0, 255) or r >= 200:
        return None
    if r not in cache:
        try:
            cache[r] = ix.room_file(r)
        except FileNotFoundError:
            cache[r] = None
    f = cache[r]
    if f is None or o + 2 > len(f):
        return None
    size = struct.unpack_from('<H', f, o)[0]
    if size < 24 or o + size > len(f):
        return None
    return f[o:o + size]


def lfsr_bits(feedback, n=2048):
    """The noise generator of player_v2.cpp: a stream of 0/1 levels."""
    rng, lvl, out = NG_PRESET, 0, []
    for _ in range(n):
        if rng & 1:
            rng ^= feedback
            lvl ^= 1
        rng >>= 1
        out.append(lvl)
    return out


def lfsr_wave(feedback, n=2048, amp=44, alpha=0.28):
    """The same noise, softened: a one-pole low-pass takes the edge off the
    hiss and a smaller swing keeps the percussion from poking out of the
    mix. 0 would halt the oscillator, so samples never go below 1."""
    y, out = 0.0, bytearray()
    bits = lfsr_bits(feedback, n)
    for i in range(n * 2):                      # second lap: wrap is seamless
        y += alpha * ((1.0 if bits[i % n] else -1.0) - y)
        if i >= n:
            out.append(max(1, min(255, int(round(128 + amp * y)))))
    return bytes(out)


def square_wave(harmonics=5, amp=96):
    """A band-limited square (odd harmonics only, 1/n weights): the same
    note as the PCjr's pulse, minus the buzzing top end. With few
    harmonics it is the page for high notes, which would alias otherwise."""
    out = bytearray()
    for i in range(256):
        v = sum(math.sin(2 * math.pi * k * i / 256) / k
                for k in range(1, 2 * harmonics, 2))
        out.append(max(1, min(255, int(round(128 + amp * v * 4 / math.pi)))))
    return bytes(out)


def triangle_wave(amp=100):
    out = bytearray()
    for i in range(256):
        x = i / 256.0
        v = 4 * x - 1 if x < 0.5 else 3 - 4 * x
        out.append(max(1, min(255, int(round(128 + amp * v)))))
    return bytes(out)


def sine_wave(amp=90):
    return bytes(max(1, min(255, int(round(128 + amp * math.sin(
        2 * math.pi * i / 256))))) for i in range(256))


# Drum samples (played once: the last byte is 0, which halts the DOC) and
# the rate each is meant to run at.
DRUM_HZ = {1: 12000, 2: 9000, 3: 5000}          # hat, snare, kick
DRUM_OF_DIV = {32: 1, 64: 2, 128: 3}            # the noise rate says which


def drum_wave(kind, n=2048):
    import numpy as np
    rng = np.random.RandomState(7 + kind)
    t = np.arange(n) / DRUM_HZ[kind]
    nz = rng.uniform(-1, 1, n)
    if kind == 1:                                # closed hat: bright, brief
        x = np.diff(nz, prepend=0) * np.exp(-t / 0.030)
    elif kind == 2:                              # snare: body plus a rattle
        lp = np.convolve(nz, np.ones(3) / 3, mode='same')
        x = (0.8 * np.diff(lp, prepend=0) * np.exp(-t / 0.060)
             + 0.7 * np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.045))
    else:                                        # kick: a falling sine
        f = 45 + 95 * np.exp(-t / 0.030)
        ph = 2 * np.pi * np.cumsum(f) / DRUM_HZ[kind]
        x = np.sin(ph) * np.exp(-t / 0.110)
        x[:40] += 0.5 * nz[:40] * np.linspace(1, 0, 40)
    x = x / max(1e-9, np.abs(x).max())
    out = bytearray(max(1, min(255, int(round(128 + 112 * v)))) for v in x)
    out[-1] = 0
    return bytes(out)


def buzz_wave(harmonics=12):
    """A reed: a sawtooth with its middle harmonics pushed up, the nasal
    buzz of a kazoo. One 256-byte cycle, like the square."""
    vals = []
    for i in range(256):
        v = 0.0
        for k in range(1, harmonics + 1):
            a = 1.0 / k
            if 3 <= k <= 6:
                a *= 1.8
            v += a * math.sin(2 * math.pi * k * i / 256 + 0.3 * k)
        vals.append(v)
    peak = max(abs(x) for x in vals)
    return bytes(max(1, min(255, int(round(128 + 100 * x / peak))))
                 for x in vals)


def wave_block():
    """46 pages for DOC RAM $8000: square (up to 9 harmonics), white noise,
    periodic noise, hat, snare, kick, the kazoo's reed, then squares with
    3 and 2 harmonics a sine for the highest notes and a triangle (the NES scores)."""
    return (square_wave(5) + lfsr_wave(FB_WNOISE) + lfsr_wave(FB_PNOISE)
            + drum_wave(1) + drum_wave(2) + drum_wave(3) + buzz_wave()
            + square_wave(3) + square_wave(2) + sine_wave() + triangle_wave())


def drum_events(ev):
    """In a piece whose noise voice is a drum kit (rates 32, 64, 128), each
    new hit becomes a sample: an attack is a halt (so the sample starts
    over) followed by a type-6 event; the decay that follows only moves
    the volume."""
    noise = [st for _, v, st in ev if v == 3 and st is not None and st[2] == 2]
    if len(noise) < 100:
        return ev
    if sum(1 for st in noise if st[0] in DRUM_OF_DIV) < 0.9 * len(noise):
        return ev
    out = []
    prev = None
    for tick, v, st in ev:
        if v != 3:
            out.append((tick, v, st))
            continue
        if st is None or st[2] != 2 or st[0] not in DRUM_OF_DIV:
            prev = None
            out.append((tick, v, st))
            continue
        kind = DRUM_OF_DIV[st[0]]
        attack = (prev is None or prev[0] != kind or st[1] < prev[1] - 1)
        if attack:
            out.append((tick, 3, None))
        out.append((tick, 6, (kind, st[1])))
        prev = (kind, st[1])
    return out


# Taste adjustments, made on the player's feedback after listening to the
# port: sound -> (time scale, volume steps quieter, octaves up for tones).
# The actor sounds (6-9) are the footsteps: they run on every step, so they
# must be brief and soft. The kazoo (33) came out too low and too hasty.
TWEAK = {
    6: (1.0, 2, 0), 7: (1.0, 2, 0), 8: (1.0, 2, 0),
    9: (0.45, 3, 0),
    33: (1.5, 0, 1),
}
BUZZ = {33}                      # the kazoo: a reed-like wave, not a flute


def tweak_events(n, ev, lp):
    t = TWEAK.get(n)
    if not t:
        return ev, lp
    scale, quieter, octaves = t
    out = []
    for tick, v, st in ev:
        tick = int(round(tick * scale))
        if v < 4 and st is not None:
            dv, vol, nb = st
            if v < 3 and octaves:
                dv = max(MINDIV, dv >> octaves)
            vol = min(14, vol + quieter)
            if v < 3 and n in BUZZ:
                nb = 3
            st = (dv, vol, nb)
        out.append((tick, v, st))
    if lp is not None:
        lp = int(round(lp * scale))
    return out, lp


def build(datadir, out, verbose=True, only=None, tweak=True):
    ix = Index(datadir)
    nsnd = len(ix.sounds)
    if nsnd > NSLOTS:
        raise SystemExit(f'{nsnd} sounds do not fit {NSLOTS} slots')
    cache = {}
    table = []
    body = bytearray()
    hdr = 6 + 16 * NSLOTS + len(wave_block())
    stats = []
    for n in range(nsnd):
        blob = sound_blob(ix, n, cache)
        if blob is None or (only is not None and n not in only):
            table.append((0, 0, 0, 0, 0xFFFF, 0))
            continue
        try:
            ev, ended, lp = run_sound(blob)
        except Exception as e:                      # a resource we misread
            if verbose:
                print(f'  sound {n}: {e!r}, skipped')
            table.append((0, 0, 0, 0, 0xFFFF, 0))
            continue
        if tweak:
            ev, lp = tweak_events(n, ev, lp)
        ev = drum_events(ev)
        pk, loff = pack_events(ev, lp)
        if lp is None:
            ltick, loff = 0xFFFF, 0
        else:
            ltick = lp
        table.append((hdr + len(body), len(pk), blob[4], blob[5], ltick, loff))
        body += pk
        stats.append((n, len(ev), len(pk), ev[-1][0] / OUT_HZ, ended, lp))
    with open(out, 'wb') as f:
        f.write(b'ZMUS' + struct.pack('<H', nsnd))
        table += [(0, 0, 0, 0, 0xFFFF, 0)] * (NSLOTS - len(table))
        for off, ln, pr, rs, lt, lo in table:
            f.write(struct.pack('<IIBBHI', off, ln, pr, rs, lt, lo))
        f.write(wave_block())
        f.write(body)
    if verbose:
        for n, ne, nb, sec, ended, lp in stats:
            print(f'  sound {n:3d}: {ne:5d} events {nb:6d} B  {sec:6.1f} s'
                  f'{"" if ended else "  (cut: still running)"}'
                  f'{"" if lp is None else f"  loop from {lp / OUT_HZ:.1f} s"}')
        print(f'{len(stats)} sounds, {len(body)} bytes of events -> {out}')


def render_wav(datadir, sound, path):
    """A quick square-wave mix to listen with: a check, not the product."""
    import wave
    ix = Index(datadir)
    blob = sound_blob(ix, sound, {})
    ev, _, _lp = run_sound(blob)
    rate = 22050
    end = ev[-1][0]
    n = int(end / OUT_HZ * rate) + rate // 10
    mix = [0.0] * n
    state = [None] * 4
    evi = 0
    # per-voice phase
    import random
    ph = [0.0] * 4
    rng = random.Random(1)
    nz = [0, 0, 0, 0]
    for i in range(n):
        t60 = int(i * OUT_HZ / rate)
        while evi < len(ev) and ev[evi][0] <= t60:
            _, v, st = ev[evi]
            if v < 4:
                state[v] = st
            evi += 1
        s = 0.0
        for v in range(4):
            st = state[v]
            if st is None:
                continue
            amp = 0.8 ** st[1]
            if v < 3:
                f = PCJR_CLK / st[0]
                ph[v] = (ph[v] + f / rate) % 1.0
                s += amp * (0.25 if ph[v] < 0.5 else -0.25)
            else:
                f = 2 * PCJR_CLK / st[0]
                ph[v] += f / rate
                while ph[v] >= 1.0:
                    ph[v] -= 1.0
                    nz[v] = rng.choice((-1, 1))
                s += amp * 0.25 * nz[v]
        mix[i] = max(-1.0, min(1.0, s))
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(b''.join(struct.pack('<h', int(x * 20000)) for x in mix))
    w.close()


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) >= 4 and a[2] == '--wav':
        render_wav(a[0], int(a[3]), a[4])
    else:
        only = None
        if '--only' in a:
            only = {int(x) for x in a[a.index('--only') + 1].split(',')}
        # the taste tweaks are Zak's: sound numbers mean other things in Maniac
        build(a[0], a[1], only=only, tweak='--plain' not in a)
