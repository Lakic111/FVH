#!/usr/bin/env bash
# Analiza i elaboracija, jednom -- snimak koristi run_one.sh / regress.sh.
#
#   ./sim/build.sh [top_modul]     (podrazumevano: tb_top)
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VERIF"

XILINX_BIN="${XILINX_BIN:-/c/AMDDesignTools/2025.2/Vivado/bin}"
XVHDL="$XILINX_BIN/xvhdl.bat"; XVLOG="$XILINX_BIN/xvlog.bat"
XELAB="$XILINX_BIN/xelab.bat"

TOP="${1:-tb_top}"
BUILD="result/build"

citaj_f() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$'; }
mapfile -t RTL < <(citaj_f rtl.f)
mapfile -t TB  < <(citaj_f tb.f)

RTL_ABS=(); for f in "${RTL[@]}"; do RTL_ABS+=("$VERIF/$f"); done
TB_ABS=();  for f in "${TB[@]}";  do TB_ABS+=("$VERIF/$f");  done

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$BUILD"

echo "=== xvhdl (VHDL-2008) ==="
"$XVHDL" -2008 "${RTL_ABS[@]}" > xvhdl.out 2>&1 \
  || { echo "FAIL: analiza VHDL-a pala"; tail -20 xvhdl.out; exit 1; }

echo "=== xvlog (SystemVerilog) ==="
"$XVLOG" -sv -L uvm "${TB_ABS[@]}" > xvlog.out 2>&1 \
  || { echo "FAIL: analiza SV-a pala"; tail -30 xvlog.out; exit 1; }

echo "=== xelab (mesovita elaboracija) ==="
"$XELAB" -L uvm -timescale 1ns/1ps -debug off "$TOP" -s "sim_$TOP" > xelab.out 2>&1 \
  || { echo "FAIL: elaboracija pala"; tail -30 xelab.out; exit 1; }

echo "=== snimak sim_$TOP spreman u $BUILD ==="
