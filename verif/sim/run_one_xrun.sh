#!/usr/bin/env bash
# ============================================================================
# run_one_xrun.sh -- jedan test u Xcelium-u nad vec elaboriranim snimkom.
#
#   ./sim/run_one_xrun.sh <ime_testa> [seed] [top_modul]
#
# Ispisuje istu liniju kao run_one.sh (PASS/FAIL + ime + seed), pa `regress.sh`
# radi sa oba simulatora bez ijedne izmene u logici.
#
# Na Linux-u nema zaobilaznice sa cmd.exe koja je potrebna na Windows-u:
# plusarg se prosledjuje neposredno.
#
# `-input sim/xrun_run.tcl` je OBAVEZAN: bez njega Cadence zaustavlja svaku
# simulaciju u trenutku 0 zbog TRRANGEC violacije u Xilinx AXI4-Full sablonu.
# Objasnjenje je u samoj tcl skripti.
# ============================================================================
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XRUN="${XRUN:-xrun}"

UVM_TEST="${1:?ime testa je obavezno}"
SEED="${2:-1}"
TOP="${3:-tb_top}"

BUILD="$VERIF/result/build_xrun"

# Mora se poklapati sa onim sto je zadato pri elaboraciji (build_xrun.sh).
COV="${COV:-1}"
if [ "$COV" = "1" ]; then
  COV_ARG=(-covtest "${1}_s${2:-1}")
else
  COV_ARG=()
fi
[ -d "$BUILD" ] || { echo "FAIL: nema snimka -- pokreni ./sim/build_xrun.sh"; exit 1; }

mkdir -p "$VERIF/result/run_xrun"
LOG="$VERIF/result/run_xrun/${UVM_TEST}_s${SEED}.log"

cd "$BUILD"
"$XRUN" -R \
  +UVM_TESTNAME="$UVM_TEST" \
  -svseed "$SEED" \
  -input "$VERIF/sim/xrun_run.tcl" \
  "${COV_ARG[@]}" \
  -l "$LOG" > /dev/null 2>&1

# Ista dvosmerna provera kao u XSim lancu: prvo DOKAZ da je simulacija istekla,
# pa tek onda trazenje gresaka.  Bez pozitivne provere se "nema gresaka" ne
# razlikuje od "nije se ni pokrenulo".
if ! grep -q 'UVM Report Summary' "$LOG"; then
  echo "FAIL  ${UVM_TEST} seed ${SEED}  (simulacija nije pokrenuta)"; exit 1
fi
if grep -qE 'FAIL|UVM_ERROR :[[:space:]]*[1-9]|UVM_FATAL :[[:space:]]*[1-9]|^Error|\*E,' "$LOG"; then
  RAZLOG="$(grep -m1 -E 'UVM_ERROR |UVM_FATAL |^Error|\*E,' "$LOG" | cut -c1-90)"
  echo "FAIL  ${UVM_TEST} seed ${SEED}  ${RAZLOG}"; exit 1
fi
echo "PASS  ${UVM_TEST} seed ${SEED}"
