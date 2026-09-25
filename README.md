# SCUMM for the Apple IIGS

A SCUMM V2 interpreter written in 65816 assembly, running on a stock Apple IIGS.
It reads the original game files — *Maniac Mansion*, *Zak McKracken* — and plays them:
no conversion step, no pre-cooked data, nothing but the engine.

This is the same idea as ScummVM, on a machine from 1986.

**No game data is included here, and none ever will be.** You need your own copy of
the game. What this repository holds is the interpreter and the tools used to build
and debug it.

## Status

Playable. Maniac Mansion runs from the title screen into the mansion: rooms, walking
with pathfinding, actors with their costume animations, objects and their states,
the verb panel and the inventory, the sentence line, dialogue with the mouth moving,
scrolling rooms with the camera following, dark rooms with the flashlight, and saving
and loading through the game's own save screen.

Still missing: sound and music, and a few opcodes the game has not needed yet.
Zak McKracken has not been tried.

## Building

You need:

- **[Merlin32](https://brutaldeluxe.fr/products/crossdevtools/merlin/)** — the
  cross-assembler, from Brutal Deluxe
- **[Cadius](https://github.com/mach-kernel/cadius)** — to build the ProDOS disk image
- your own copy of the game's `.LFL` files, in a folder (default: `data/`)
- `src/fontdata.s` — see below

```sh
./build_scumm.sh /path/to/your/LFL/files
```

The result is `build/SCUMM.2mg`, a 1600 KB ProDOS image holding the interpreter and
the game's own files. It boots on a real IIGS (ROM01 and ROM03) and under
[GSplus](https://github.com/digarok/gsplus).

### The font

SCUMM V2 keeps no font in the `.LFL` files: on DOS it lives inside the game's
executable. `src/fontdata.s` is therefore game data, and it is not distributed here.

The layout, if you want to build it yourself: 128 characters, 8x8, one bit per pixel,
eight bytes each. In `MANIAC.EXE` the table starts at file offset `$108FD` and covers
the characters from 48 upwards (digits, letters, symbols); below 48 the same area is
x86 code, not a table, so punctuation has to come from somewhere else. The file is a
Merlin32 source with the label `FontData` followed by `hex` lines.

## The tools

Everything under `tools/` is Python, and none of it runs on the IIGS — it exists to
understand the data and to find mistakes in seconds instead of one disk at a time.

| | |
|---|---|
| `lfl.py` | reads the `.LFL` files: the index, the rooms, the resource tables |
| `room2.py` | decompresses a room's background |
| `obj2.py` | a room's objects: positions, verb tables, names |
| `cost2.py` | the costumes, that is the animated characters |
| `render2.py` | draws a room as the game would see it, to a PNG |
| `dis2.py` | a disassembler for V2 bytecode |
| `gs816.py` | a 65816 in Python: enough of a IIGS to run the interpreter |
| `gsrun.py` | fakes the toolbox and GS/OS on top of it |
| `prova.py` | drives the game inside that emulator — clicks, keys, screenshots |

The emulator is the reason this got anywhere. It boots the real interpreter, feeds it
the real game files, lets a test click on things and hands back the video memory as a
picture, so a bug can be reproduced and diagnosed without touching hardware.

```sh
python3 tools/dis2.py data S4          # disassemble global script 4
python3 tools/render2.py data 7 out.png
python3 tools/prova.py                 # play the intro, save a screenshot
```

## Notes on the source

`src/scumm.s` is one file, about ten thousand lines. The comments carry the reasoning,
including the mistakes: where a behaviour comes from a specific line of the game's own
bytecode, or from how the original engine does it, the comment says so. That is
deliberate — most of the hard bugs in a project like this are not in the assembly but
in a wrong idea about what the data means.

Labels and local symbols are still in Italian in places; the comments are not.

## Credits and licence

Written with Claude (Anthropic) for Michele Di Paola, who directs the port, tests every
build on real hardware and on GSplus, and found most of the bugs described in the
comments.

The file formats and the opcode table were worked out from
**[ScummVM](https://www.scummvm.org/)** and **scummvm-tools** (`descumm`), which are
GPL-2.0-or-later. This project follows: **GPL-2.0-or-later**. See `LICENSE`.

Maniac Mansion and Zak McKracken are © Lucasfilm Games. Nothing of theirs is in this
repository.
