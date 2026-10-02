#!/usr/bin/env bash
# Pogodnost za jedan test u XSim-u: elaboracija pa pokretanje.
#
#   ./sim/run_xsim.sh [ime_testa] [seed]     (podrazumevano: ncc_smoke_test 1)
#
# Za vise od jednog testa koristi ./sim/regress.sh.
set -u
SIM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TEST="${1:-ncc_smoke_test}"
SEED="${2:-1}"

bash "$SIM/build.sh" || exit 1

IZLAZ="$(bash "$SIM/run_one.sh" "$UVM_TEST" "$SEED")"
KOD=$?
echo "$IZLAZ"

if [ $KOD -eq 0 ]; then
  echo "=== REZULTAT: PASS ($UVM_TEST, seed $SEED) ==="
else
  echo "=== REZULTAT: FAIL ($UVM_TEST, seed $SEED) ==="
fi
echo "Log: result/run/${UVM_TEST}_s${SEED}.log"
exit $KOD
