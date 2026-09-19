#!/usr/bin/env bash
# ============================================================================
# run_xsim.sh -- pogodnost za jedan test: elaboracija pa pokretanje.
#
#   ./sim/run_xsim.sh [top_modul] [ime_testa] [seed]
#
# Ovo je samo omotac oko build.sh i run_one.sh.  Ranije je imao sopstveni lanac
# poziva alata, sto je znacilo dve kopije iste logike koje bi se vremenom
# razisle -- sada postoji jedan izvor istine po koraku.
#
# Za vise od jednog testa koristi ./sim/regress.sh: on elaborira JEDNOM i
# pusta celu listu nad istim snimkom.
# ============================================================================
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
