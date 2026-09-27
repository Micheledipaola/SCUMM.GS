# SCUMMv2 for the Apple IIGS

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
scrolling rooms with the camera following, dark rooms with the flashlight, Amiga
sound effects (no music), and saving and loading through the game's own save screen.

The Amiga release works too, from files taken off its own floppies with
`tools/adf.py`: same index, byte-identical bytecode, and the same picture decoder
reads its rooms. Its room files are half again as large, which is all the engine
needed to be told. Sound comes from those Amiga samples, packed for the IIGS DOC;
the music tracks in the same files are skipped.

ESC skips a cutscene when the script allowed it, Q asks before quitting, Space
pauses, Apple-8 asks before restarting.

A few opcodes the game has not needed yet are still stubs. Zak McKracken (use DOSv2 
aka enhanced!) uses the same V2 files but has not been tested extensively yet; 
anyway it runs and shows the game; later SCUMM games (ie Monkey Island) are a 
different engine (v5).

## Building

You need:

- **[Merlin32](https://brutaldeluxe.fr/products/crossdevtools/merlin/)** — the
  cross-assembler, from Brutal Deluxe
- **[Cadius](https://github.com/mach-kernel/cadius)** — to build the ProDOS disk image
- your own copy of the game's `.LFL` files, in a folder (default: `data/`)
- optionally an Amiga Maniac disk image, so the build can pack SFX
  (`AMIGA_2MG`, default `../altri SCUMM/SCUMM-AMIGA.2mg` next to this repo)

```sh
./build_scumm.sh /path/to/your/LFL/files
```

The result is `build/SCUMM.2mg`, a 1600 KB ProDOS image holding the interpreter,
the game's own files (as `MM/L00.LFL` …), and if the Amiga image was found the
SFX banks (`MM/SFXI`, `MM/SFX0` …). It boots on a real IIGS (ROM01 and ROM03)
and under [GSplus](https://github.com/digarok/gsplus).

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

### Shadowing and PEI slamming

The PEI slam is six cycles for two bytes: stack and direct page sit on a 
page of bank `$01` SHR memory and `PEI` rewrites that page onto itself 
so the shadow hardware copies it to `$E1`.

It has **not** been timed on a real IIGS for this engine. Emulator numbers
for a *second* copy of an already-built buffer were:

| | cycles/byte |
|---|---|
| `MVN` into bank `$01` | 8.4 |
| the slam onto `$E1` | 6.0 |
| `MVN` straight onto `$E1` | 12.9 |

`8.4 + 6.0` vs `12.9`: a slam *after* a blit into `$01` loses. This engine
composes the room in a Memory Manager buffer (up to 960×128, which does not
fit in the 32K shadow window `$2000–$9FFF`) and presents once with `MVN`
onto `$E1`. The slam would win only if the visible 320×128 window were
*drawn* in bank `$01` with shadowing off, then slammed — not if it is an
extra hop. That layout fights scrolling (the full room has to stay in the
heap) and has not been tried on hardware yet. `gs816.py` still models
`$C035` and `$C002–$C005` so a hardware test can be wired without guessing
the MMU.

What *was* worth doing here, independent of the slam: V2 RLE is column
runs, so the decoder now writes a whole run before fetching the next byte;
costume pixels walk `Pitch` instead of recomputing `RowOff` every pixel;
erasing an actor copies with `MVN` when the row stays in one bank.

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
| `sfx_amiga.py` | packs Amiga V2 sound effects into GSFX banks for the IIGS (no music) |

The emulator is the reason this got anywhere. It boots the real interpreter, feeds it
the real game files, lets a test click on things and hands back the video memory as a
picture, so a bug can be reproduced and diagnosed without touching hardware.

```sh
python3 tools/dis2.py data S4          # disassemble global script 4
python3 tools/render2.py data 7 out.png
python3 tools/prova.py                 # play the intro, save a screenshot
```

## Notes on the source

`src/scumm.s` is one file. The comments carry the reasoning,
including the mistakes: where a behaviour comes from a specific line of the game's own
bytecode, or from how the original engine does it, the comment says so. That is
deliberate — most of the hard bugs in a project like this are not in the assembly but
in a wrong idea about what the data means.

Labels and local symbols are still in Italian in places; the comments are not.

A handful of sound timings (the intro comet, the Start beep, door clicks) are
tuned to Maniac Mansion's objects and scripts, not to a generic V2 table.

## Credits and licence

Written with Claude and Grok for Michele Di Paola, who directs the port, tests every
build on real hardware and on emulator (GSplus), and found most of the bugs described in the
comments.

The file formats and the opcode table were worked out from
**[ScummVM](https://www.scummvm.org/)** and **scummvm-tools** (`descumm`), which are
GPL-2.0-or-later. This project follows: **GPL-2.0-or-later**. See `LICENSE`.

Maniac Mansion and Zak McKracken are © Lucasfilm Games. Nothing of theirs is in this
repository.
