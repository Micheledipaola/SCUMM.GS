#!/usr/bin/env python3
"""Read (and optionally extract) a ProDOS 2MG volume."""
import os
import struct
import sys

BLOCK = 512


def load_2mg(path):
    data = open(path, 'rb').read()
    if data[:4] != b'2IMG':
        raise ValueError(f'not a 2MG: {path}')
    off = struct.unpack_from('<I', data, 0x18)[0]
    ln = struct.unpack_from('<I', data, 0x1C)[0]
    return bytearray(data[off:off + ln]), data[:off]


def prodos_name(raw):
    nlen = raw[0] & 0x0F
    return raw[1:1 + nlen].decode('ascii', 'replace')


def iter_entries(vol, key_block):
    blk = key_block
    seen = set()
    while blk and blk not in seen:
        seen.add(blk)
        b = vol[blk * BLOCK:(blk + 1) * BLOCK]
        if len(b) < BLOCK:
            break
        # first entry in a directory key/header is 0x04 bytes into the block
        # after prev/next pointers
        nxt = struct.unpack_from('<H', b, 2)[0]
        pos = 4
        while pos + 39 <= BLOCK:
            st = b[pos]
            if st != 0 and st != 0xE5:
                storage = st >> 4
                name = prodos_name(b[pos:])
                ftype = b[pos + 0x10]
                key = struct.unpack_from('<H', b, pos + 0x11)[0]
                blocks_used = struct.unpack_from('<H', b, pos + 0x13)[0]
                eof = int.from_bytes(b[pos + 0x15:pos + 0x18], 'little')
                aux = struct.unpack_from('<H', b, pos + 0x1F)[0]
                yield {
                    'name': name,
                    'storage': storage,
                    'type': ftype,
                    'key': key,
                    'blocks': blocks_used,
                    'eof': eof,
                    'aux': aux,
                    'dir_block': blk,
                    'dir_pos': pos,
                }
            pos += 39
        blk = nxt


def index_block(vol, block):
    b = vol[block * BLOCK:(block + 1) * BLOCK]
    out = []
    for i in range(256):
        lo = b[i]
        hi = b[256 + i]
        n = lo | (hi << 8)
        if n:
            out.append(n)
    return out


def file_bytes(vol, ent):
    st = ent['storage']
    key = ent['key']
    eof = ent['eof']
    chunks = []
    if st == 1:  # seedling
        chunks.append(vol[key * BLOCK:(key + 1) * BLOCK])
    elif st == 2:  # sapling
        for blk in index_block(vol, key):
            chunks.append(vol[blk * BLOCK:(blk + 1) * BLOCK])
    elif st == 3:  # tree
        for idx in index_block(vol, key):
            for blk in index_block(vol, idx):
                chunks.append(vol[blk * BLOCK:(blk + 1) * BLOCK])
    else:
        return b''
    return b''.join(chunks)[:eof]


def volume_key(vol):
    return 2


def walk(vol, key=2, prefix=''):
    files = []
    for ent in iter_entries(vol, key):
        st = ent['storage']
        path = prefix + ent['name']
        if st == 0x0D or st == 0x0F:  # subdirectory / volume header skip
            if st == 0x0D:
                files.extend(walk(vol, ent['key'], path + '/'))
            continue
        if ent['name'].startswith('.'):
            continue
        files.append((path, ent))
    return files


def extract(path, dest):
    vol, _ = load_2mg(path)
    os.makedirs(dest, exist_ok=True)
    for rel, ent in walk(vol):
        out = os.path.join(dest, rel)
        os.makedirs(os.path.dirname(out) or dest, exist_ok=True)
        data = file_bytes(vol, ent)
        open(out, 'wb').write(data)
        print(f'{rel:20} type=${ent["type"]:02X} aux=${ent["aux"]:04X} {len(data)} bytes')


def catalog(path):
    vol, _ = load_2mg(path)
    for rel, ent in walk(vol):
        print(f'{rel:20} type=${ent["type"]:02X} aux=${ent["aux"]:04X} '
              f'eof={ent["eof"]} key={ent["key"]} st={ent["storage"]}')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: prodos2mg.py <image.2mg> [extract-dir]')
        sys.exit(1)
    if len(sys.argv) == 2:
        catalog(sys.argv[1])
    else:
        extract(sys.argv[1], sys.argv[2])
