#!/usr/bin/env python3
"""sfx_amiga.py - pack Maniac/Zak Amiga SFX for the IIGS interpreter.

The Amiga V2 sound blobs have no useful header: ScummVM matches them by
CRC and then slices a sample at a known offset (player_v2a.cpp, GPL).
Music tracks are skipped. Game data stays out of git. Output is an IIGS GSFX set: a small
    index (prefix+'I') plus 32K banks (prefix+'0', prefix+'1', ...) so
    each sample set fits one locked Memory Manager bank / DOC buffer.

    python3 tools/sfx_amiga.py <amiga-LFL-folder> [out-prefix]
    python3 tools/sfx_amiga.py --from-2mg <SCUMM-AMIGA.2mg> [out-prefix]
"""
import math
import os
import re
import struct
import sys
import tempfile
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lfl import Index
from prodos2mg import load_2mg, walk, file_bytes

NSND = 128
DOC_CLOCK_DIV = 1645  # TN IIGS #37: freqOffset = 32 * Hz / 1645
BASE_FREQ = 3579545

# CRC -> (kind, args...) from ScummVM player_v2a.cpp findSound(), Maniac only
# plus any CRC we meet so Zak SFX still pack if those LFL are given.
# kind: skip | once | loop
MANIAC_CRC = {}


def _crc32_scumm(data):
    """Same polynomial as player_v2a GetCRC (zlib.crc32)."""
    return zlib.crc32(data) & 0xFFFFFFFF


def _parse_v2a_table(text):
    """Read CRCToSound lines. Music -> skip; Single -> once; else loop."""
    table = {}
    for line in text.splitlines():
        m = re.search(
            r'CRCToSound\(0x([0-9A-Fa-f]+),\s*V2A_Sound_(\w+)\((.*)\)\)',
            line)
        if not m:
            continue
        crc = int(m.group(1), 16)
        cls = m.group(2)
        rest = m.group(3)
        hexes = re.findall(r'0x[0-9A-Fa-f]+', rest)
        nums = [int(x, 16) for x in hexes]
        # first two numbers are almost always offset, size
        if cls == 'Music':
            table[crc] = ('skip', 0, 0, 0, 0)
            continue
        if len(nums) < 2:
            continue
        off, size = nums[0], nums[1]
        period = nums[2] if len(nums) > 2 else 0x1C2
        vol = nums[3] if len(nums) > 3 else 0x3F
        if period > 0x2000:
            period = 0x1C2
        if vol > 0x3F:
            vol = 0x3F
        kind = 'once' if cls in ('Single',) else 'loop'
        if cls.endswith('Duration') or cls == 'Single':
            kind = 'once'
        table[crc] = (kind, off, size, period, vol)
    return table


def _v2a_source():
    here = os.path.join(os.path.dirname(__file__), 'player_v2a.crc.txt')
    if os.path.exists(here):
        return open(here).read()
    return EMBEDDED_CRC


# Minimal embedded table: Maniac lines from ScummVM player_v2a.cpp
EMBEDDED_CRC = r'''
 CRCToSound(0x8FAB08C4, V2A_Sound_SingleLooped(0x006C, 0x2B58, 0x016E, 0x3F));
 CRCToSound(0xB673160A, V2A_Sound_SingleLooped(0x006C, 0x1E78, 0x01C2, 0x1E));
 CRCToSound(0x4DB1D0B2, V2A_Sound_MultiLooped(0x0072, 0x1BC8, 0x023D, 0x3F, 0x0224, 0x3F));
 CRCToSound(0x754D75EF, V2A_Sound_Single(0x0076, 0x0738, 0x01FC, 0x3F));
 CRCToSound(0x6E3454AF, V2A_Sound_Single(0x0076, 0x050A, 0x017C, 0x3F));
 CRCToSound(0x92F0BBB6, V2A_Sound_Single(0x0076, 0x3288, 0x012E, 0x3F));
 CRCToSound(0xE1B13982, V2A_Sound_MultiLoopedDuration(0x0078, 0x0040, 0x007C, 0x3F, 0x007B, 0x3F, 0x001E));
 CRCToSound(0x288B16CF, V2A_Sound_MultiLoopedDuration(0x007A, 0x0040, 0x007C, 0x3F, 0x007B, 0x3F, 0x000A));
 CRCToSound(0xA7565268, V2A_Sound_MultiLoopedDuration(0x007A, 0x0040, 0x00F8, 0x3F, 0x00F7, 0x3F, 0x000A));
 CRCToSound(0x7D419BFC, V2A_Sound_MultiLoopedDuration(0x007E, 0x0040, 0x012C, 0x3F, 0x0149, 0x3F, 0x001E));
 CRCToSound(0x1B52280C, V2A_Sound_Single(0x0098, 0x0A58, 0x007F, 0x32));
 CRCToSound(0x38D4A810, V2A_Sound_Single(0x0098, 0x2F3C, 0x0258, 0x32));
 CRCToSound(0x09F98FC2, V2A_Sound_Single(0x0098, 0x0A56, 0x012C, 0x32));
 CRCToSound(0x90440A65, V2A_Sound_Single(0x0098, 0x0208, 0x0078, 0x28));
 CRCToSound(0x985C76EF, V2A_Sound_Single(0x0098, 0x0D6E, 0x00C8, 0x32));
 CRCToSound(0x76156137, V2A_Sound_Single(0x0098, 0x2610, 0x017C, 0x39));
 CRCToSound(0x5D95F88C, V2A_Sound_Single(0x0098, 0x0A58, 0x007F, 0x1E));
 CRCToSound(0x92D704EA, V2A_Sound_SingleLooped(0x009C, 0x29BC, 0x012C, 0x3F, 0x1BD4, 0x0DE8));
 CRCToSound(0x92F5513C, V2A_Sound_Single(0x009E, 0x0DD4, 0x01F4, 0x3F));
 CRCToSound(0xCC2F3B5A, V2A_Sound_Single(0x009E, 0x00DE, 0x01AC, 0x3F));
 CRCToSound(0x153207D3, V2A_Sound_Single(0x009E, 0x0E06, 0x02A8, 0x3F));
 CRCToSound(0xC4F370CE, V2A_Sound_Single(0x00AE, 0x0330, 0x01AC, 0x3F));
 CRCToSound(0x928C4BAC, V2A_Sound_Single(0x00AE, 0x08D6, 0x01AC, 0x3F));
 CRCToSound(0x62D5B11F, V2A_Sound_Single(0x00AE, 0x165C, 0x01CB, 0x3F));
 CRCToSound(0x3AB22CB5, V2A_Sound_Single(0x00AE, 0x294E, 0x012A, 0x3F));
 CRCToSound(0x2D70BBE9, V2A_Sound_SingleLoopedPitchbend(0x00B4, 0x1702, 0x03E8, 0x0190, 0x3F, 5));
 CRCToSound(0xFA4C1B1C, V2A_Sound_Special_Maniac69(0x00B2, 0x1702, 0x0190, 0x3F));
 CRCToSound(0x19D50D67, V2A_Sound_Special_ManiacDing(0x00B6, 0x0020, 0x00C8, 16, 2));
 CRCToSound(0x3E6FBE15, V2A_Sound_Special_ManiacTentacle(0x00B2, 0x0010, 0x007C, 0x016D, 1));
 CRCToSound(0x5305753C, V2A_Sound_Special_ManiacTentacle(0x00B2, 0x0010, 0x007C, 0x016D, 7));
 CRCToSound(0x28895106, V2A_Sound_Special_Maniac59(0x00C0, 0x00FE, 0x00E9, 0x0111, 4, 0x0A));
 CRCToSound(0xB641ACF6, V2A_Sound_Special_Maniac61(0x00C8, 0x0100, 0x00C8, 0x01C2));
 CRCToSound(0xE1A91583, V2A_Sound_Special_ManiacPhone(0x00D0, 0x0040, 0x007C, 0x3F, 0x007B, 0x3F, 0x3C, 5, 6));
 CRCToSound(0x64816ED5, V2A_Sound_Special_ManiacPhone(0x00D0, 0x0040, 0x00BE, 0x37, 0x00BD, 0x37, 0x3C, 5, 6));
 CRCToSound(0x639D72C2, V2A_Sound_Special_Maniac46(0x00D0, 0x10A4, 0x0080, 0x3F, 0x28, 3));
 CRCToSound(0xE8826D92, V2A_Sound_Special_ManiacTypewriter(0x00EC, 0x025A, 0x023C, 0x3F, 8, dummy, true));
 CRCToSound(0xEDFF3D41, V2A_Sound_Single(0x00F8, 0x2ADE, 0x01F8, 0x3F));
 CRCToSound(0x15606D06, V2A_Sound_Special_Maniac32(0x0148, 0x0020, 0x0168, 0x0020, 0x3F));
 CRCToSound(0x753EAFE3, V2A_Sound_Special_Maniac44(0x017C, 0x0010, 0x018C, 0x0020, 0x00C8, 0x0080, 0x3F));
 CRCToSound(0xB1AB065C, V2A_Sound_Music(0x0032, 0x00B2, 0x08B2, 0x1222, 0x1A52, 0x23C2, 0x3074, false));
 CRCToSound(0x091F5D9C, V2A_Sound_Music(0x0032, 0x0132, 0x0932, 0x1802, 0x23D2, 0x3EA2, 0x4F04, false));
'''


def _freq_offset(period):
    if period <= 0:
        period = 0x1C2
    hz = BASE_FREQ / period
    fo = int(32 * hz / DOC_CLOCK_DIV + 0.5)
    return max(1, min(65535, fo))


def _amiga_unsigned(sample):
    """Paula 8-bit signed -> DOC offset-binary ($80 silence).

    A zero in the wave makes the Free-Form synth stop (TN IIGS #37).
    """
    out = bytearray(len(sample))
    for i, b in enumerate(sample):
        v = (b + 128) & 0xFF
        if v == 0:
            v = 1
        out[i] = v
    return bytes(out)


def _pad_page(data):
    n = (len(data) + 255) & ~255
    if n == 0:
        n = 256
    return data + bytes([0x80] * (n - len(data)))


def _synth_door(close=False):
    """Short wood latch+panel instead of the crunchy Amiga door sample."""
    n = 768 if close else 640
    sr = 8000.0
    f0 = 92.0 if close else 128.0
    decay = 95.0 if close else 70.0
    out = bytearray(n)
    for i in range(n):
        t = i / sr
        env = math.exp(-i / decay)
        s = math.sin(2 * math.pi * f0 * t) * 0.62
        s += math.sin(2 * math.pi * (f0 * 2.15) * t) * 0.22
        # latch click in the first ~12 ms
        if i < 96:
            click = math.sin(2 * math.pi * 980 * t) * (1.0 - i / 96.0) * 0.35
            s += click
        noise = (((i * 53) ^ (i * 17)) & 31) / 31.0 - 0.5
        s += noise * 0.12 * env
        v = int(max(-118, min(118, s * env * 110)))
        b = (v + 128) & 0xFF
        out[i] = 1 if b == 0 else b
    return _pad_page(bytes(out))


def _synth_beep(cycles=24, n=512):
    """A short tone. More cycles = higher note at the same playback rate."""
    out = bytearray(n)
    for i in range(n):
        s = math.sin(2 * math.pi * cycles * i / n)
        env = 1.0
        if i < 24:
            env = i / 24.0
        elif i > n - 80:
            env = (n - i) / 80.0
        v = int(max(-118, min(118, s * env * 105)))
        b = (v + 128) & 0xFF
        out[i] = 1 if b == 0 else b
    return _pad_page(bytes(out))


def sound_blob(idx, snd_id):
    room = idx.sounds.rooms[snd_id]
    off = idx.sounds.offsets[snd_id]
    if room == 0 or off == 0xFFFF or off == 0:
        return None
    raw = idx.room_file(room)
    if off + 2 > len(raw):
        return None
    size = struct.unpack_from('<H', raw, off)[0]
    if size < 4 or off + size > len(raw):
        size = min(len(raw) - off, 65535)
    return raw[off:off + size]


class IndexL(Index):
    def _path(self, n):
        for name in (f"{n:02d}.LFL", f"{n:02d}.lfl",
                     f"L{n:02d}.LFL", f"L{n:02d}.lfl"):
            full = os.path.join(self.folder, name)
            if os.path.exists(full):
                return full
        raise FileNotFoundError(f"{n:02d}.LFL non trovato in {self.folder}")


BANK = 32768  # one IIGS locked handle / one DOC-side file


def pack_folder(folder, dest):
    """Write GSFX: dest+'I' index plus dest+'0'.. dest banks of 32K."""
    table = _parse_v2a_table(_v2a_source())
    idx = IndexL(folder)
    # each: freq, pages, flags, vol, bank, page
    entries = [(0, 0, 0, 0, 0, 0)] * NSND
    banks = [bytearray()]
    n_ok = n_skip = n_miss = 0
    for i in range(min(NSND, len(idx.sounds))):
        blob = sound_blob(idx, i)
        if not blob:
            n_miss += 1
            continue
        if len(blob) < 12:
            n_miss += 1
            continue
        crclen = struct.unpack_from('>H', blob, 8)[0]
        if crclen == 0 or 0x0A + crclen > len(blob):
            n_miss += 1
            continue
        crc = _crc32_scumm(blob[0x0A:0x0A + crclen])
        rec = table.get(crc)
        if i in (8, 9):
            wave = _synth_door(close=(i == 9))
            kind = 'once'
            period = 0x0240 if i == 9 else 0x01A8
            vol = 0x38
        elif i == 54:
            wave = _synth_beep(24) + _synth_beep(48)  # kid note, then Start octave
            kind = 'once'
            period = 0x0280
            vol = 0x3A
        elif rec is None:
            n_miss += 1
            print(f'  sound {i:3d} crc={crc:08X} size={len(blob):5d}  unknown')
            continue
        else:
            kind, off, size, period, vol = rec
            if kind == 'skip':
                n_skip += 1
                print(f'  sound {i:3d} music, skipped')
                continue
            if off >= len(blob):
                print(f'  sound {i:3d} slice {off}+{size} past {len(blob)}')
                continue
            if off + size > len(blob):
                size = len(blob) - off
            wave = _pad_page(_amiga_unsigned(blob[off:off + size]))
        if len(wave) > BANK:
            print(f'  sound {i:3d} {len(wave)} larger than a 32K bank')
            n_miss += 1
            continue
        if len(banks[-1]) + len(wave) > BANK:
            banks.append(bytearray())
        page = len(banks[-1]) // 256
        bank = len(banks) - 1
        banks[-1].extend(wave)
        flags = 1 if kind == 'loop' else 0
        v8 = ((vol << 2) | (vol >> 4)) & 0xFF
        if i == 57:
            period = min(period * 2, 0x2000)  # longer meteor impact
        if i == 56:
            period = min(period * 10, 0x2000)  # one slow whoosh, not a siren
            flags = 0
        if i == 28:
            vol = 8  # foyer clock, much quieter
        if i == 12:
            vol = 40  # light switch, a bit quieter
        fo = _freq_offset(period)
        pages = len(wave) // 256
        if pages <= 2 and fo > 120 and i not in (8, 9, 54):
            fo = 120  # keypad / tiny SFX: ~50 ms, not 9 ms
        entries[i] = (fo, pages, flags, v8, bank, page)
        n_ok += 1
        tag = 'door' if i in (8, 9) else kind
        print(f'  sound {i:3d} {tag:4s} {len(wave):5d} B  bank={bank} page={page}'
              f'  period=${period:04X} vol={vol}')
    hdr = bytearray(b'GSFX')
    hdr += struct.pack('<H', NSND)
    hdr += struct.pack('<H', n_ok)
    for fo, pages, flags, vol, bank, page in entries:
        hdr += struct.pack('<HBBBBB', fo, pages, flags, vol, bank, page)
        hdr += b'\x00'
    open(dest + 'I', 'wb').write(hdr)
    for n, blob in enumerate(banks):
        if not blob:
            continue
        open(f'{dest}{n}', 'wb').write(bytes(blob))
        print(f'  bank {n}: {len(blob)} bytes -> {dest}{n}')
    print(f'wrote {dest}I + {len(banks)} banks: {n_ok} sfx, {n_skip} music skipped')
    return dest


def pack_2mg(image, dest):
    tmp = tempfile.mkdtemp(prefix='sfxamiga_')
    vol, _ = load_2mg(image)
    folder = os.path.join(tmp, 'MM')
    os.makedirs(folder, exist_ok=True)
    for rel, ent in walk(vol):
        name = os.path.basename(rel).upper()
        if not (name.endswith('.LFL') and name.startswith('L')):
            continue
        open(os.path.join(folder, name), 'wb').write(file_bytes(vol, ent))
    return pack_folder(folder, dest)


def main():
    args = sys.argv[1:]
    if not args:
        print('usage: sfx_amiga.py <LFL dir> [out] | --from-2mg <2mg> [out]')
        sys.exit(1)
    if args[0] == '--from-2mg':
        img = args[1]
        out = args[2] if len(args) > 2 else 'SFX'
        pack_2mg(img, out)
    else:
        folder = args[0]
        out = args[1] if len(args) > 1 else 'SFX'
        pack_folder(folder, out)


if __name__ == '__main__':
    main()
