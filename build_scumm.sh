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

# Where things are on this particular machine goes in build.local.sh,
# which git ignores: MERLIN32, MERLIN_LIB, CADIUS, ZAK, AMIGA_2MG, DISK.
# Nothing in this file names a path outside the repository, so a fresh
# clone builds anywhere the tools are on PATH.
[ -f "$ROOT/build.local.sh" ] && . "$ROOT/build.local.sh"

SRC="${1:-data}"
MERLIN32="${MERLIN32:-merlin32}"
MERLIN_BIN="$(command -v "$MERLIN32" || echo "$MERLIN32")"
MERLIN_HOME="$(cd "$(dirname "$MERLIN_BIN")" 2>/dev/null && pwd || echo .)"
CADIUS="${CADIUS:-cadius}"
# Merlin32 1.2 wants the macro folder as an argument and treats a CR in
# *.Macs.s as part of the opcode, so MAC never matches on the toolkit
# files as shipped: give it a Unix-LF copy. Merlin32 1.1 takes no such
# argument and ships no Library, so the whole step is skipped there.
MACRO_DIR=""
MERLIN_LIB="${MERLIN_LIB:-$MERLIN_HOME/Library}"
if [ -d "$MERLIN_LIB" ]; then
  MACRO_DIR="$ROOT/macros"
  mkdir -p "$MACRO_DIR/4"
  python3 - "$MERLIN_LIB" "$MACRO_DIR" <<'MACPY'
import sys
from pathlib import Path
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
for p in src.glob('*.Macs.s'):
    (dst / p.name).write_bytes(p.read_bytes().replace(b'\r\n', b'\n').replace(b'\r', b'\n'))
MACPY
  for m in Util Locator Mem Misc Event Qd Sound QdAux Window Menu Ctl Line Dialog Std List; do
    [ -f "$MACRO_DIR/${m}.Macs.s" ] && cp "$MACRO_DIR/${m}.Macs.s" "$MACRO_DIR/4/${m}.Macs"
  done
fi

if [ ! -f src/fontdata.s ]; then
  echo "==> font: the one drawn for this project"
  cp src/font_orig.s src/fontdata.s
else
  echo "==> font: src/fontdata.s"
fi

DISK="${DISK:-$ROOT/build/SCUMM.2mg}"
# Save games are SAVE0..SAVE9 next to the LFL files (MM/ or ZAK/).
# CREATEVOLUME wipes the volume, so pull them off first and put them back.
KEEP_SAVES="$ROOT/keep_saves"
preserve_saves() {
  local img="$1"
  [ -f "$img" ] || return 0
  command -v "$CADIUS" >/dev/null 2>&1 || return 0
  mkdir -p "$KEEP_SAVES/MM" "$KEEP_SAVES/ZAK"
  local tmp="$ROOT/.save_extract"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  echo "==> keep saves from $(basename "$img")"
  local g slot
  for g in MM ZAK; do
    for slot in 0 1 2 3 4 5 6 7 8 9; do
      rm -rf "$tmp"/*
      if "$CADIUS" EXTRACTFILE "$img" "/SCUMM/$g/SAVE$slot" "$tmp" >/dev/null 2>&1; then
        # Cadius names the file SAVE0#xxxxxx; keep a plain SAVE0 for staging.
        local f
        f=$(find "$tmp" -maxdepth 1 -type f \( -name "SAVE$slot" -o -name "SAVE$slot#*" \) | head -1)
        if [ -n "$f" ]; then
          cp "$f" "$KEEP_SAVES/$g/SAVE$slot"
          echo "    $g/SAVE$slot"
        fi
      fi
    done
  done
  rm -rf "$tmp"
}

echo "==> 65816 assembly"
# Merlin32 v1.2: merlin32 [-V] <macro_folder> <source>
if [ -n "$MACRO_DIR" ]; then
  "$MERLIN32" -V "$MACRO_DIR" "$ROOT/src/scumm.s"
else
  "$MERLIN32" -V "$ROOT/src/scumm.s"
fi

preserve_saves "$DISK"

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

if [ -n "$ZAK" ] && [ -d "$ZAK" ]; then
  echo "==> Zak: $ZAK"
  mkdir -p stage/ZAK
  for f in "$ZAK"/*; do
    n=$(basename "$f")
    [[ "$n" =~ ^L?([0-9][0-9])\.[Ll][Ff][Ll]$ ]] || continue
    cp "$f" "stage/ZAK/L${BASH_REMATCH[1]}.LFL"
  done
  # Costume 31 cel +104 side hat: clear the colour-1 bar under the brim
  # (blob over the glasses stems). Staged LFL only.
  echo "==> Zak: punch costume 31 hat stem-blob"
  python3 "$ROOT/tools/patch_zak_arm.py" stage/ZAK "$ZAK"
fi

echo "==> Amiga SFX (no music), GSFX banks"
rm -f stage/MM/SFX stage/MM/SFXI stage/MM/SFX[0-9]
if [ -n "$AMIGA_2MG" ] && [ -f "$AMIGA_2MG" ]; then
  python3 "$ROOT/tools/sfx_amiga.py" --from-2mg "$AMIGA_2MG" stage/MM/SFX
else
  echo "   no Amiga disk (set AMIGA_2MG in build.local.sh) — SFX omitted"
fi

echo "==> music omitted (SFX only)"
rm -f stage/MM/MUSI stage/MM/MUS0 stage/MM/MUSQ

if [ -f "$ROOT/icons/SCUMM" ]; then
  echo "==> Finder icon"
  mkdir -p stage/Icons
  cp "$ROOT/icons/SCUMM" stage/Icons/SCUMM
  echo "SCUMM=Type(CA),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)" \
    > stage/Icons/_FileInformation.txt
fi

# Put saved games back into the staged folders (MM and/or ZAK).
restored=0
for g in MM ZAK; do
  [ -d "$KEEP_SAVES/$g" ] || continue
  [ -d "stage/$g" ] || continue
  shopt -s nullglob
  for f in "$KEEP_SAVES/$g"/SAVE[0-9]; do
    cp "$f" "stage/$g/"
    restored=$((restored + 1))
  done
  shopt -u nullglob
done
if [ "$restored" -gt 0 ]; then
  echo "==> restore $restored save(s) onto the new disk"
fi

echo "SCUMM=Type(B3),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)" \
  > stage/_FileInformation.txt
for f in stage/MM/L??.LFL stage/MM/SFX* stage/MM/MUS* stage/MM/SAVE[0-9]; do
  [ -f "$f" ] || continue
  echo "$(basename "$f")=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)"
done > stage/MM/_FileInformation.txt
if [ -d stage/ZAK ]; then
  for f in stage/ZAK/L??.LFL stage/ZAK/SAVE[0-9]; do
    [ -f "$f" ] || continue
    echo "$(basename "$f")=Type(06),AuxType(0000),VersionCreate(70),MinVersion(BE),Access(E3)"
  done > stage/ZAK/_FileInformation.txt
fi

if command -v "$CADIUS" >/dev/null 2>&1; then
  "$CADIUS" CREATEVOLUME build/SCUMM.2mg SCUMM 3200KB >/dev/null
  "$CADIUS" CREATEVOLUME "$DISK" SCUMM 3200KB >/dev/null
  "$CADIUS" ADDFOLDER "$DISK" /SCUMM/ ./stage >/dev/null
  # Same contents in build/ so a GS that mounts that image is not empty.
  "$CADIUS" ADDFOLDER build/SCUMM.2mg /SCUMM/ ./stage >/dev/null
  "$CADIUS" CATALOG "$DISK" | tail -3
else
  echo "==> cadius not in PATH, packing with tools/make_2mg.py"
  python3 tools/make_2mg.py "$DISK" stage
fi

echo
echo "Done: $DISK"