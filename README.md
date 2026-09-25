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

```sh
./build_scumm.sh /path/to/your/LFL/files
```

The result is `build/SCUMM.2mg`, a 1600 KB ProDOS image holding the interpreter and
the game's own files. It boots on a real IIGS (ROM01 and ROM03) and under
[GSplus](https://github.com/digarok/gsplus).

### The font

SCUMM V2 keeps no font in the `.LFL` files: on DOS it lives inside the game's
executable, which makes it game data like everything else.

So this repository carries a font drawn for the project instead — 5x7 shapes in an
8x8 cell, `src/font_orig.s`, written by `tools/font_orig.py`, which is where the
letters are actually designed (one string of ones and zeros per row, easy to read
and to change). The build uses it automatically, so a fresh clone runs.

If you would rather see the game's own lettering, `tools/font_mm.py` lifts it out of
your `MANIAC.EXE`:

```sh
python3 tools/font_mm.py /path/to/MANIAC.EXE > src/fontdata.s
```

`src/fontdata.s` takes precedence over the drawn font when it exists, and
`.gitignore` keeps it out of the repository. The table in the executable starts at
file offset `$108FD` and begins at character 48, the digit zero; below that the same
area is x86 code rather than glyphs, so the script fills the space and the
punctuation from the drawn font. Either way the format is the same: 128 characters,
eight bytes each, one byte per row, leftmost pixel in bit 7.

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
| `font_orig.py` | the font drawn for this project, and where it is designed |
| `font_mm.py` | lifts the game's own font out of `MANIAC.EXE` instead |

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
