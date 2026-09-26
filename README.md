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

The Amiga release works too, from files taken off its own floppies with
`tools/adf.py`: same index, byte-identical bytecode, and the same picture decoder
reads its rooms. Its room files are half again as large, which is all the engine
needed to be told.

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

If you would rather see the game's own lettering, `tools/font_mm.py` finds it inside
the game's program — whichever machine your copy came from:

```sh
python3 tools/font_mm.py /path/to/MANIAC.EXE > src/fontdata.s   # DOS
python3 tools/font_mm.py /path/to/Maniac     > src/fontdata.s   # Amiga
```

It does not know any offsets. A font drawn in an 8x8 cell leaves room under the
letters and after them, so almost every capital has an empty last row and clear low
bits, and none is blank; machine code has no such habit. Sliding that test over the
file finds the table wherever it is. On the DOS executable it lands at `$108FD`,
starting at character 48; on the Amiga program at `$1890C`, starting at 32 — which
is why the Amiga copy also has its punctuation, where the DOS one has x86 code below
48 and borrows those characters from the drawn font.

The Amiga program is the file called `Maniac` on the first floppy; `tools/adf.py`
gets it off the disk image.

`src/fontdata.s` takes precedence over the drawn font when it exists, and
`.gitignore` keeps it out of the repository. The table in the executable starts at
file offset `$108FD` and begins at character 48, the digit zero; below that the same
area is x86 code rather than glyphs, so the script fills the space and the
punctuation from the drawn font. Either way the format is the same: 128 characters,
eight bytes each, one byte per row, leftmost pixel in bit 7.

## The screen

The picture is built in a buffer the size of a room, one byte for every
two pixels, and the visible window is moved onto the screen a row at a time
with `MVN`, the 65816's block move: seven cycles a byte, one instruction a
row. The copy loop it replaced spent sixteen of its twenty-nine cycles per
two bytes on advancing indices and comparing.

A block move stays inside one bank, though, where a long pointer carries
into the next by itself, and the Memory Manager puts the sixty-thousand-byte
room buffer wherever it likes: the last rows of a wide room fall on the
other side. So the address is worked out in full every row, the source bank
goes into the instruction, and the one row that would run off the end is
copied the old way.

### What the machine said about shadowing

The obvious next step looked like the PEI slam: draw everything in bank
`$01` with shadowing off, then let the shadow hardware carry it to `$E1`
by writing each changed page over itself with `PEI` - six cycles for two
bytes, against the twenty-nine of a copy loop.

It was built, and measured on the machine rather than argued about. Twenty
passes over the room window, in sixtieths of a second:

| | | cycles/byte |
|---|---|---|
| `MVN` into bank `$01` | 74 | 8.4 |
| the slam onto `$E1` | 53 | 6.0 |
| `MVN` straight onto `$E1` | 113 | 12.9 |
| the old copy loop onto `$E1` | 155 | 17.7 |

8.4 + 6.0 against 12.9: **the slam loses**. It pays when the same area is
written several times between two slams, and this engine writes it once -
the room is composed in its own buffer and the window goes across in one
pass. So the drawing goes straight onto `$E1`, and the slam is in the
history of this repository rather than in the code.

The emulator learned shadowing and the `$C002`-`$C005` switches for that
experiment, and kept them: they cost nothing and the next person to wonder
about this can try it without building the model again.

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
| `font_mm.py` | finds the game's own font inside its program, whichever release |
| `adf.py` | reads files out of an Amiga floppy image, for the Amiga release |

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
