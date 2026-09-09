#!/usr/bin/env bash
# Elaboracija u Cadence Xcelium-u. Parnjak build.sh-a.
#
#   ./sim/build_xrun.sh [top_modul]
#
# Preduslov: . amsgo   (sa tackom -- source, ne ./amsgo)
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VERIF"

XRUN="${XRUN:-xrun}"
TOP="${1:-tb_top}"
BUILD="result/build_xrun"

# COV=0 iskljucuje pokrivenost (trazi zasebnu licencu).
COV="${COV:-1}"
if [ "$COV" = "1" ]; then
  COV_ARG=(-coverage functional -covoverwrite)
else
  COV_ARG=()
  echo "NAPOMENA: pokrivenost iskljucena (COV=0)"
fi

citaj_f() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$'; }
mapfile -t RTL < <(citaj_f rtl.f)
mapfile -t TB  < <(citaj_f tb.f)

RTL_ABS=(); for f in "${RTL[@]}"; do RTL_ABS+=("$VERIF/$f"); done
TB_ABS=();  for f in "${TB[@]}";  do TB_ABS+=("$VERIF/$f");  done

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$BUILD"

rm -rf xcelium.d INCA_libs *.log *.history

# -v200x: VHDL-2008. -relax: potrebno za S00 (agregat sa opsegom iz generika).
# -uvm: UVM koji dolazi uz Xcelium (ako verzija ne odgovara, dodati -uvmhome).
"$XRUN" -64bit -elaborate \
  -v200x -relax \
  -uvm \
  -timescale 1ns/1ps \
  "${COV_ARG[@]}" \
  -top "$TOP" \
  "${RTL_ABS[@]}" "${TB_ABS[@]}" \
  -l xrun_elab.log

KOD=$?
if [ $KOD -ne 0 ]; then
  echo "FAIL: elaboracija u Xcelium-u pala -- vidi $BUILD/xrun_elab.log"
  exit 1
fi
echo "=== snimak spreman u $BUILD ==="
