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

SRC="${1:-data}"
MERLIN32="${MERLIN32:-merlin32}"
CADIUS="${CADIUS:-cadius}"

# The font. src/font_orig.s is the one drawn for this project and is in
# the repository, so a fresh clone builds and runs. If you would rather
# have the game's own, tools/font_mm.py lifts it out of MANIAC.EXE into
# src/fontdata.s, and that takes precedence.
if [ ! -f src/fontdata.s ]; then
  echo "==> font: the one drawn for this project"
  cp src/font_orig.s src/fontdata.s
else
  echo "==> font: src/fontdata.s"
fi

mkdir -p build

echo "==> 65816 assembly"
"$MERLIN32" -V src/scumm.s

echo "==> disk"
rm -rf stage build/SCUMM.2mg
mkdir -p stage/MM
cp src/SCUMM stage/
for f in "$SRC"/[0-9][0-9].LFL; do
  n=$(basename "$f" .LFL)
  cp "$f" "stage/MM/L$n.LFL"
done

echo "SCUMM=Type(B3),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)" \
  > stage/_FileInformation.txt
for f in stage/MM/L??.LFL; do
  echo "$(basename "$f")=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)"
done > stage/MM/_FileInformation.txt

"$CADIUS" CREATEVOLUME build/SCUMM.2mg SCUMM 1600KB >/dev/null
"$CADIUS" ADDFOLDER build/SCUMM.2mg /SCUMM/ ./stage >/dev/null
"$CADIUS" CATALOG build/SCUMM.2mg | tail -3

echo
echo "Done: build/SCUMM.2mg"
