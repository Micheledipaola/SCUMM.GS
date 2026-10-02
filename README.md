# SCUMMv2 for the Apple IIGS

A SCUMM V2 interpreter written in 65816 assembly, running on a stock Apple IIGS.
It reads the original game files — *Maniac Mansion*, *Zak McKracken* — and plays them:
no conversion step, no pre-cooked data, nothing but the engine.

This is the same idea as ScummVM, on a machine from 1986.

**No game data is included here, and none ever will be.** You need your own copy of
the game. What this repository holds is the interpreter and the tools used to build
and debug it.

## Status

**Maniac Mansion**, the DOS release, is playable from the title screen into the
mansion: rooms,
walking with pathfinding, actors with their costume animations, objects and
their states, the verb panel and the inventory, the sentence line, dialogue
with the mouth moving, scrolling rooms with the camera following, dark rooms
with the flashlight, Amiga sound effects (no music), and saving and loading
through the game's own save screen.

The Amiga release works too, from files taken off its own floppies with
`tools/adf.py`: same index, byte-identical bytecode, and the same picture
decoder reads its rooms. Its room files are half again as large, which is all
the engine needed to be told. Sound comes from those Amiga samples, packed for
the IIGS DOC; the music tracks in the same files are skipped.

ESC skips a cutscene when the script allowed it, Q asks before quitting, Space
pauses, Apple-8 asks before restarting. The boot dialog picks which game to
load when both are on the disk.

**Zak McKracken**, the DOS release — V2, the one sold as enhanced — is the current
focus and runs on the same interpreter. It is being tested extensively. The game is selected when the index has 155 global scripts
(`IsZak`); Zak-only behaviour stays behind that flag so Maniac is not disturbed.

What works on Zak today, beyond the shared V2 core:

- Intro, office, dream (room 49), living room and the early game path
- ESC in Zak can clear delays / stop walks and skip the office cutscene where
  the scripts allow it (Maniac ESC is still jump-to-override only)
- Costumes up to 8K per slot — needed for Melissa's TV hood (costume 3, limb
  L6) which a 4K limit truncated
- TV “LIVE” broadcast: Melissa (and Annie) stay inside the glass; soft mask and
  room-relative placement; when Melissa turns while talking, the hood is kept
  (talk overwrites `ActFrame`, so the turn path re-applies chore 8 from L6's
  `CostFrm`)
- Dream flying hat (costume 31): side-view glasses stems visible without the
  black under-brim blob; front view keeps the full fake nose. The staged LFL
  punches the side-hat bar; runtime `HatClip` / per-pixel skip covers the rest
- Actor palette quirks (Zak's black suit, costume 31 glasses black, aliens)
- Room-49 object draw order / colour-8 so the pointing body does not wipe the arm
- Apartment doorway (room 3): the character is cut by the door frame on the way
  down the stairs, and walks out into the street
- Credits verb lines long enough for Zak's text; hover highlight on those lines
- D-key debug line for Zak: room and actors (`id:cost@x,ye…f…`)
- A string's codes four to six stand for what a variable holds — a number, a
  verb's name, the name of an object or a character — so the phone company's
  bill reads "You owe $1138" and not "You owe $"

Still open on Zak: music (only Amiga SFX banks are packed), further room and
costume polish as playthrough finds them, and anything that would need a
global engine change without an `IsZak` guard. Later SCUMM games — Monkey Island
and on — are a different engine, V5, and will most likely not even load.

A few opcodes neither game has needed yet are still stubs.

## Building

You need:

- **[Merlin32](https://brutaldeluxe.fr/products/crossdevtools/merlin/)** — the
  cross-assembler, from Brutal Deluxe
- **[Cadius](https://github.com/mach-kernel/cadius)** — to build the ProDOS disk image
- your own copy of the game's `.LFL` files, in a folder (default: `data/`)
- optionally Zak enhanced LFL files: set `ZAK` to that folder (the build
  script defaults to a local ZakEnh path when `ZAK` is unset)
- optionally an Amiga Maniac disk image, so the build can pack SFX
  (`AMIGA_2MG`, default `../altri SCUMM/SCUMM-AMIGA.2mg` next to this repo)

```sh
./build_scumm.sh /path/to/your/LFL/files
# or, with Maniac in data/ and Zak next to the repo:
./build_scumm.sh data
```

The result is `../SCUMM.2mg` (next to this repo, where GSplus loads it), a
3200 KB ProDOS image holding the interpreter, Maniac as `MM/L00.LFL` …, Zak as
`ZAK/L00.LFL` … when `ZAK` was found, and if the Amiga image was present the
SFX banks (`MM/SFXI`, `MM/SFX0` …). It boots on a real IIGS (ROM01 and ROM03)
and under [GSplus](https://github.com/digarok/gsplus). Cold-quit the emulator
before relaunching after a rebuild, or it keeps the old binary in RAM.

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
page of bank `$01` SHR memory and `PEI` rewrites that page onto itself so
the shadow hardware copies it to `$E1`.

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

## Characters, and what the background hides

A V2 room carries one more plane after its picture: one bit per pixel, saying
which background pixels are drawn in front of the characters. Each walk box
names whether the box it describes uses that plane, so a character standing
behind the bakery counter is cut against it and one standing in the street is
not.

Getting that right in Zak's street took two goes, and the first one was wrong.

A V2 costume is drawn one strip to the right of the square the scripts walk to,
and two strips when the character looks left. ScummVM does the same in
`Actor_v2::prepareDrawActorCostume`, and says plainly that it does not know why
either. The engine had that offset, three workarounds had been piled on top of
it over time, and taking the offset out made the apartment doorway look right —
so out it came, and the workarounds with it.

That was treating the symptom. What had been wrong was the workarounds; the
strip belongs. The case that settled it is the baker in room 3: script 39 parks
him at x 18 and leaves him there two seconds before he walks to his window, and
the bakery's wall mask starts at room x 141. Without the strip his left arm
lands at 136 and five columns of him stick out beside the window, before and
after the scene. With it he spans 144..164 and the wall covers him.

The lesson is about the proof rather than the pixel. Left and right are the same
drawing mirrored, so their two x ranges must be symmetric about the anchor —
and they are, with the strip and without it. That test catches a *difference*
between the two sides and nothing else; a constant added to both leaves the
symmetry untouched, and the strip is exactly such a constant. The test was
sound and the conclusion drawn from it was not.

A costume's limbs are the other thing the original is careful about. Lighting a
chore changes only the limbs that chore names, and the rest carry on with what
they were doing. Turning is only a turn, and standing still only puts the
standing pose back: neither clears anything. The limbs are cleared at one
moment, coming on stage, which is the original's init frame. Getting that wrong
shows either way — clear too much and the Caponian clerk loses the disguise the
game lights once with `animateActor 24`, clear too little and he keeps the hat
into the aliens' room.

## What a frame costs

Composing a room means putting the decoded background back, drawing every lit
object on top of it, rebuilding the mask plane, and then drawing the characters.
It is what has to happen when the room changes or the lights do. It was also
what happened every time any object changed state, because an object that goes
out must stop hiding people, and the mask was rebuilt by decoding the whole
room's plane again.

In the aliens' room, where screens and buttons animate continuously, that was
measured at **78.6%** of all the time the interpreter spent: 34.6% copying the
51200 bytes of the picture back, 30.9% running the mask's run-length stream
again, for one button lighting up.

Two changes. The room's own mask is decoded once and kept, so rebuilding it is a
block move rather than a decode. And an object that changes state now has its own
rectangle put back — the clean mask for that square, then the masks of the lit
objects that touch it — instead of the whole room.

The test for that is an equality, not an eye: for every object in a room, the
incremental update must leave the mask plane and the picture byte-for-byte
identical to what a full compose produces. 115 objects across both games, no
difference. Measured in passes through the main loop for the same work:

| | before | after |
|---|---|---|
| Zak, aliens' room | 17 | 102 |
| Zak, room 3 doorway | 9 | 1128 |

The second number is larger because that room was also recomposing itself on
every pass through the main loop, which was one of the workarounds above.

### Drawing a costume two columns at a time

Once the room stopped recomposing itself, what was left at the top of a frame
was the characters. In the aliens' room with four of them redrawn on every pass,
`PaintCel` was 75% of the frame and its masked inner loop alone 53%.

Neighbouring screen columns share a byte, and painting them a pixel at a time
cost a read, a mask, an or and a write for each nibble. The two columns of a cel
cannot be decoded side by side — one run of the file can end in one column and
carry on into the next — so each is decoded on its own into a list of runs, and
the two lists are then merged. Wherever a run of one overlaps a run of the other
the byte is the same all the way down, which leaves the inner loop with nothing
to do but store it.

Three things carry most of the gain. The sixteen colours of the file are
remapped and dimmed once per character instead of once per run. The row loops
keep the row offset in an index register and the accumulator eight bits wide
from end to end, with the two pointers already aimed at the pair of columns. And
the clipping is settled once for the whole cel, so the merge never asks about it.

| aliens' room, four characters redrawn every pass | before | after |
|---|---|---|
| `PaintCel` | 1,010,000 cycles a frame | 723,000 |
| the whole frame | 478 ms | 378 ms |

The old path is still there, for the two cels that need a decision per pixel —
the flying hat and the television glass — and as the thing to measure against: a
harness draws every cel both ways in the same run and compares the buffer. 1,300
cels across both games come out identical to the byte, and Maniac's frames hash
the same as before the change.

Text is clamped at the last column as well. A glyph written at column 40 lands on
the next scanline's SHR control bytes and paints red stripes across the panel, so
`DrawChar` refuses rather than trusting every caller to count.

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
| `patch_zak_arm.py` | staged-only punch of Zak costume 31 side-hat blob pixels |

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

Zak-only paths go through `IsZak` (or a script only Zak runs). Do not “try it
on Maniac” as a side effect of a Zak fix until there is an explicit MM pass.

## Credits and licence

Written with Claude and Grok for Michele Di Paola, who directs the port, tests
every build on real hardware and on emulator (GSplus), and found most of the bugs
described in the comments.

The file formats and the opcode table were worked out from
**[ScummVM](https://www.scummvm.org/)** and **scummvm-tools** (`descumm`), which are
GPL-2.0-or-later. This project follows: **GPL-2.0-or-later**. See `LICENSE`.

Maniac Mansion and Zak McKracken are © Lucasfilm Games. Nothing of theirs is in this
repository.
