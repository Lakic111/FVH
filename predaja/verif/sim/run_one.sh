#!/usr/bin/env bash
# Pokrece JEDAN test nad vec izgradjenim snimkom (build.sh).
#
#   ./sim/run_one.sh <ime_testa> [seed] [top_modul]
#
# Ispisuje jednu liniju PASS/FAIL, izlazni kod 0/1.
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XILINX_BIN="${XILINX_BIN:-/c/AMDDesignTools/2025.2/Vivado/bin}"
XSIM="$XILINX_BIN/xsim.bat"

UVM_TEST="${1:?ime testa je obavezno}"
SEED="${2:-1}"
TOP="${3:-tb_top}"

BUILD="$VERIF/result/build"
[ -d "$BUILD/xsim.dir/sim_$TOP" ] || { echo "FAIL: nema snimka -- pokreni ./sim/build.sh"; exit 1; }

mkdir -p "$VERIF/result/run"
LOG="$VERIF/result/run/${UVM_TEST}_s${SEED}.log"

cd "$BUILD"

# Windows: cmd deli argument na '=', pa ceo poziv ide kao jedan zasticen niz.
XSIM_WIN="$(cygpath -w "$XSIM")"
Q='"'
CMD="$XSIM_WIN sim_$TOP -R -testplusarg ${Q}UVM_TESTNAME=${UVM_TEST}${Q} -sv_seed $SEED"
MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "$CMD" > "$LOG" 2>&1

if [ -d "xsim.covdb/sim_$TOP" ]; then
  ZAJ="$VERIF/result/cov/xsim.covdb"
  mkdir -p "$ZAJ"
  rm -rf "$ZAJ/${UVM_TEST}_s${SEED}"
  cp -r "xsim.covdb/sim_$TOP" "$ZAJ/${UVM_TEST}_s${SEED}"
fi

if ! grep -q 'UVM Report Summary' "$LOG"; then
  echo "FAIL  ${UVM_TEST} seed ${SEED}  (simulacija nije pokrenuta)"; exit 1
fi
if grep -qE 'FAIL|UVM_ERROR :[[:space:]]*[1-9]|UVM_FATAL :[[:space:]]*[1-9]|^Error:' "$LOG"; then
  RAZLOG="$(grep -m1 -E 'UVM_ERROR C|UVM_FATAL C|^Error:' "$LOG" | cut -c1-90)"
  echo "FAIL  ${UVM_TEST} seed ${SEED}  ${RAZLOG}"; exit 1
fi
echo "PASS  ${UVM_TEST} seed ${SEED}"
