#!/usr/bin/env bash
# Jedan test u Xcelium-u nad vec elaboriranim snimkom (build_xrun.sh).
#
#   ./sim/run_one_xrun.sh <ime_testa> [seed]
#
# Ispisuje jednu liniju PASS/FAIL, izlazni kod 0/1.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

XRUN="${XRUN:-xrun}"

UVM_TEST="${1:?ime testa je obavezno}"
SEED="${2:-1}"

BUILD="$VERIF/result/build_xrun"
[ -d "$BUILD" ] || { echo "FAIL: nema snimka -- pokreni ./sim/build_xrun.sh"; exit 1; }

COV="${COV:-1}"
if [ "$COV" = "1" ]; then
  COV_ARG=(-covtest "${UVM_TEST}_s${SEED}")
else
  COV_ARG=()
fi

mkdir -p "$VERIF/result/run_xrun"
LOG="$VERIF/result/run_xrun/${UVM_TEST}_s${SEED}.log"

cd "$BUILD"
# -input xrun_run.tcl: bez toga Cadence zaustavlja simulaciju na trenutku 0
# (TRRANGEC u Xilinx AXI4-Full sablonu, vidi xrun_run.tcl).
"$XRUN" -R \
  +UVM_TESTNAME="$UVM_TEST" \
  -svseed "$SEED" \
  -input "$VERIF/sim/xrun_run.tcl" \
  ${COV_ARG[@]+"${COV_ARG[@]}"} \
  -l "$LOG" > /dev/null 2>&1

if ! grep -q 'UVM Report Summary' "$LOG"; then
  echo "FAIL  ${UVM_TEST} seed ${SEED}  (simulacija nije pokrenuta, vidi $LOG)"; exit 1
fi
if grep -qE 'FAIL|UVM_ERROR :[[:space:]]*[1-9]|UVM_FATAL :[[:space:]]*[1-9]|^Error|\*E,' "$LOG"; then
  RAZLOG="$(grep -m1 -E 'UVM_ERROR |UVM_FATAL |^Error|\*E,' "$LOG" | cut -c1-90)"
  echo "FAIL  ${UVM_TEST} seed ${SEED}  ${RAZLOG}"; exit 1
fi
echo "PASS  ${UVM_TEST} seed ${SEED}"
