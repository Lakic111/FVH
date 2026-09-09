#!/usr/bin/env bash
# Pogodnost za jedan test: elaboracija pa pokretanje (omotac oko build.sh/run_one.sh).
#
#   ./sim/run_xsim.sh [top_modul] [ime_testa] [seed]
#
# Za vise od jednog testa koristi ./sim/regress.sh.
set -u

SIM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOP="${1:-tb_top}"
UVM_TEST="${2:-ncc_smoke_test}"
SEED="${3:-1}"

"$SIM/build.sh" "$TOP" || exit 1

IZLAZ="$("$SIM/run_one.sh" "$UVM_TEST" "$SEED" "$TOP")"
KOD=$?
echo "$IZLAZ"

if [ $KOD -eq 0 ]; then
  echo "=== REZULTAT: PASS ($UVM_TEST, seed $SEED) ==="
else
  echo "=== REZULTAT: FAIL ($UVM_TEST, seed $SEED) ==="
fi
echo "Log: result/run/${UVM_TEST}_s${SEED}.log"
exit $KOD
