#!/usr/bin/env bash
# Elaboracija u Cadence Xcelium-u. Parnjak build.sh-a.
#
#   ./sim/build_xrun.sh [top_modul]
#
# Preduslov: Cadence okruzenje ucitano tako da je xrun u PATH-u
# (na fakultetskoj masini: `. amsgo`), ili XRUN=/putanja/do/xrun.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

XRUN="${XRUN:-xrun}"
command -v "$XRUN" > /dev/null 2>&1 || {
  echo "GRESKA: '$XRUN' nije pronadjen -- ucitaj Cadence okruzenje ili postavi XRUN=/putanja/do/xrun"
  exit 1
}

TOP="${1:-tb_top}"
BUILD="$VERIF/result/build_xrun"

# COV=0 iskljucuje pokrivenost (trazi zasebnu licencu).
COV="${COV:-1}"
if [ "$COV" = "1" ]; then
  COV_ARG=(-coverage functional -covoverwrite)
else
  COV_ARG=()
  echo "NAPOMENA: pokrivenost iskljucena (COV=0)"
fi

ucitaj_filelist rtl.f; RTL=("${IZVORI[@]}"); IZVORI=()
ucitaj_filelist tb.f;  TB=("${IZVORI[@]}")

INC_ARG=()
for d in "${INCDIRS[@]}"; do INC_ARG+=(-incdir "$d"); done

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$BUILD"

# -v200x: VHDL-2008. -relax: potrebno za S00 (agregat sa opsegom iz generika).
# -uvm: UVM koji dolazi uz Xcelium (ako verzija ne odgovara, dodati -uvmhome).
"$XRUN" -64bit -elaborate \
  -v200x -relax \
  -uvm \
  -timescale 1ns/1ps \
  ${COV_ARG[@]+"${COV_ARG[@]}"} \
  -top "$TOP" \
  "${INC_ARG[@]}" \
  "${RTL[@]}" "${TB[@]}" \
  -l xrun_elab.log

KOD=$?
if [ $KOD -ne 0 ]; then
  echo "FAIL: elaboracija u Xcelium-u pala -- vidi result/build_xrun/xrun_elab.log"
  exit 1
fi
echo "=== snimak spreman u result/build_xrun ==="
