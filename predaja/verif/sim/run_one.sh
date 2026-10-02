#!/usr/bin/env bash
# Pokrece JEDAN test u XSim-u nad vec izgradjenim snimkom (build.sh).
#
#   ./sim/run_one.sh <ime_testa> [seed] [top_modul]
#
# Ispisuje jednu liniju PASS/FAIL, izlazni kod 0/1.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

XSIM="$(nadji_vivado_alat xsim)" || exit 1

UVM_TEST="${1:?ime testa je obavezno}"
SEED="${2:-1}"
TOP="${3:-tb_top}"

BUILD="$VERIF/result/build"
[ -d "$BUILD/xsim.dir/sim_$TOP" ] || { echo "FAIL: nema snimka -- pokreni ./sim/build.sh"; exit 1; }

mkdir -p "$VERIF/result/run"
LOG="$VERIF/result/run/${UVM_TEST}_s${SEED}.log"

cd "$BUILD"
rm -rf "xsim.covdb/sim_$TOP"
pokreni_alat "$XSIM" "sim_$TOP" -R -testplusarg "UVM_TESTNAME=$UVM_TEST" -sv_seed "$SEED" > "$LOG" 2>&1

# Baza pokrivenosti svakog pokretanja cuva se pod svojim imenom (spaja coverage.sh).
if [ -d "xsim.covdb/sim_$TOP" ]; then
  ZAJ="$VERIF/result/cov/xsim.covdb"
  mkdir -p "$ZAJ"
  rm -rf "$ZAJ/${UVM_TEST}_s${SEED}"
  cp -r "xsim.covdb/sim_$TOP" "$ZAJ/${UVM_TEST}_s${SEED}"
fi

if ! grep -q 'UVM Report Summary' "$LOG"; then
  echo "FAIL  ${UVM_TEST} seed ${SEED}  (simulacija nije pokrenuta, vidi $LOG)"; exit 1
fi
if grep -qE 'FAIL|UVM_ERROR :[[:space:]]*[1-9]|UVM_FATAL :[[:space:]]*[1-9]|^Error:' "$LOG"; then
  RAZLOG="$(grep -m1 -E 'UVM_ERROR C|UVM_FATAL C|^Error:' "$LOG" | cut -c1-90)"
  echo "FAIL  ${UVM_TEST} seed ${SEED}  ${RAZLOG}"; exit 1
fi
echo "PASS  ${UVM_TEST} seed ${SEED}"
