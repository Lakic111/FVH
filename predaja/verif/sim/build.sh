#!/usr/bin/env bash
# Analiza i elaboracija u Vivado XSim-u, jednom -- snimak koriste run_one.sh i regress.sh.
#
#   ./sim/build.sh [top_modul]     (podrazumevano: tb_top)
#
# Radi iz bilo kog direktorijuma, na Linuxu i na Windows-u (Git Bash).
# Vivado se trazi automatski, vidi sim/common.sh.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

XVHDL="$(nadji_vivado_alat xvhdl)" || exit 1
XVLOG="$(nadji_vivado_alat xvlog)" || exit 1
XELAB="$(nadji_vivado_alat xelab)" || exit 1

TOP="${1:-tb_top}"
BUILD="$VERIF/result/build"

ucitaj_filelist rtl.f; RTL=("${IZVORI[@]}"); IZVORI=()
ucitaj_filelist tb.f;  TB=("${IZVORI[@]}")

INC_ARG=()
for d in "${INCDIRS[@]}"; do INC_ARG+=(-i "$d"); done

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$BUILD"

echo "=== Vivado: $(dirname "$XVLOG") ==="

echo "=== xvhdl (VHDL-2008) ==="
pokreni_alat "$XVHDL" -2008 "${RTL[@]}" > xvhdl.out 2>&1 \
  || { echo "FAIL: analiza VHDL-a pala"; tail -20 xvhdl.out; exit 1; }

echo "=== xvlog (SystemVerilog) ==="
pokreni_alat "$XVLOG" -sv -L uvm "${INC_ARG[@]}" "${TB[@]}" > xvlog.out 2>&1 \
  || { echo "FAIL: analiza SV-a pala"; tail -30 xvlog.out; exit 1; }

echo "=== xelab (mesovita elaboracija) ==="
pokreni_alat "$XELAB" -L uvm -timescale 1ns/1ps -debug off "$TOP" -s "sim_$TOP" > xelab.out 2>&1 \
  || { echo "FAIL: elaboracija pala"; tail -30 xelab.out; exit 1; }

echo "=== snimak sim_$TOP spreman u result/build ==="
