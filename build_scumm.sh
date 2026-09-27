#!/bin/bash
# build_scumm.sh - builds the disk for the SCUMM interpreter on the IIGS.
#
# Usage:  ./build_scumm.sh [folder holding the .LFL files]
#
# What lands on the disk is the interpreter plus the game's own original
# files, renamed L00.LFL...L53.LFL because ProDOS wants a name to start
# with a letter. Nothing else: no pre-converted rooms, the IIGS does the
# decompression itself.
set -e
cd "$(dirname "$0")"
ROOT="$PWD"

SRC="${1:-data}"
MERLIN32="${MERLIN32:-/Users/Michele/EMU/IIGS/Merlin32/Merlin32}"
MERLIN_HOME="$(cd "$(dirname "$MERLIN32")" && pwd)"
CADIUS="${CADIUS:-$ROOT/tools/bin/cadius}"
# Merlin32 1.2 treats CR in *.Macs.s as part of the opcode, so MAC never
# matches. Give it a Unix-LF copy of the toolkit macros.
MACRO_DIR="$ROOT/macros"
mkdir -p "$MACRO_DIR"
python3 - "$MERLIN_HOME/Library" "$MACRO_DIR" <<'PY'
import sys
from pathlib import Path
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
for p in src.glob('*.Macs.s'):
    (dst / p.name).write_bytes(p.read_bytes().replace(b'\r\n', b'\n').replace(b'\r', b'\n'))
PY

if [ ! -f src/fontdata.s ]; then
  echo "==> font: the one drawn for this project"
  cp src/font_orig.s src/fontdata.s
else
  echo "==> font: src/fontdata.s"
fi

mkdir -p build

echo "==> 65816 assembly"
# Merlin32 v1.2: merlin32 [-V] <macro_folder> <source>
"$MERLIN32" -V "$MACRO_DIR" "$ROOT/src/scumm.s"

echo "==> disk"
rm -rf stage build/SCUMM.2mg
mkdir -p stage/MM
cp src/SCUMM stage/
shopt -s nullglob
for f in "$SRC"/[0-9][0-9].LFL "$SRC"/L[0-9][0-9].LFL; do
  n=$(basename "$f" .LFL)
  n=${n#L}
  cp "$f" "stage/MM/L$n.LFL"
done
shopt -u nullglob

if ! ls stage/MM/L??.LFL >/dev/null 2>&1; then
  echo "No .LFL files in $SRC" >&2
  exit 1
fi

echo "==> Amiga SFX (no music), GSFX banks"
AMIGA_2MG="${AMIGA_2MG:-$ROOT/../altri SCUMM/SCUMM-AMIGA.2mg}"
rm -f stage/MM/SFX stage/MM/SFXI stage/MM/SFX[0-9]
if [ -f "$AMIGA_2MG" ]; then
  python3 "$ROOT/tools/sfx_amiga.py" --from-2mg "$AMIGA_2MG" stage/MM/SFX
else
  echo "No Amiga disk at $AMIGA_2MG — SFX omitted"
fi

echo "==> music omitted (SFX only)"
rm -f stage/MM/MUSI stage/MM/MUS0 stage/MM/MUSQ

echo "==> Finder icon"
mkdir -p stage/Icons
cp "$ROOT/icons/SCUMM" stage/Icons/SCUMM
echo "SCUMM=Type(CA),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)" \
  > stage/Icons/_FileInformation.txt

echo "SCUMM=Type(B3),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)" \
  > stage/_FileInformation.txt
for f in stage/MM/L??.LFL stage/MM/SFX* stage/MM/MUS*; do
  [ -f "$f" ] || continue
  echo "$(basename "$f")=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)"
done > stage/MM/_FileInformation.txt

if command -v "$CADIUS" >/dev/null 2>&1; then
  "$CADIUS" CREATEVOLUME build/SCUMM.2mg SCUMM 1600KB >/dev/null
  "$CADIUS" ADDFOLDER build/SCUMM.2mg /SCUMM/ ./stage >/dev/null
  "$CADIUS" CATALOG build/SCUMM.2mg | tail -3
else
  echo "==> cadius not in PATH, packing with tools/make_2mg.py"
  python3 tools/make_2mg.py build/SCUMM.2mg stage
fi

echo
echo "Done: build/SCUMM.2mg"
