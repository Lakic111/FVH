#!/usr/bin/env bash
# ============================================================================
# regress.sh -- cela regresija jednom komandom.
#
#   ./sim/regress.sh [sve|brza|spora]      (podrazumevano: sve)
#   SEEDS=5 ./sim/regress.sh               (broj seed-ova za slucajni test)
#   SIM=xrun ./sim/regress.sh              (Cadence Xcelium umesto Vivado XSim)
#
# Lista testova, redosled i provera PASS/FAIL su ISTI za oba simulatora -- menja
# se samo koji par skripti se poziva.  To je i smisao Koraka 7: ako se regresija
# razlikuje po simulatoru, ne dokazuje prenosivost nego samo da postoje dve.
#
# Elaboracija se radi JEDNOM (build.sh), pa se svi testovi puste nad istim
# snimkom.  Na kraju se ispisuje tabela PASS/FAIL i spojena pokrivenost.
#
# Podela na brzu i sporu listu je namerna: brza mora da prodje u nekoliko
# desetina sekundi, da bi se pokretala posle svake izmene.  Testovi koji rade
# pun proracun idu u sporu.
# ============================================================================
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VERIF"

REZIM="${1:-sve}"
SEEDS="${SEEDS:-20}"
SIM="${SIM:-xsim}"

case "$SIM" in
  xsim) BUILD_SH="./sim/build.sh";      RUN_SH="./sim/run_one.sh" ;;
  xrun) BUILD_SH="./sim/build_xrun.sh"; RUN_SH="./sim/run_one_xrun.sh" ;;
  *)    echo "FAIL: nepoznat simulator '$SIM' (ocekivano xsim ili xrun)"; exit 1 ;;
esac

BRZI=(ncc_vif_test ncc_axil_smoke_test ncc_axil_agent_test
      ncc_axif_smoke_test ncc_smoke_test)
SPORI=(ncc_cov_test ncc_dim_sweep_test)

echo "############################################################"
echo "# FVH regresija -- simulator: $SIM, rezim: $REZIM, seed-ova: $SEEDS"
echo "# $(date '+%Y-%m-%d %H:%M:%S')"
echo "############################################################"

# Stara pokrivenost se brise: spajanje starih baza sa novim kodom daje broj koji
# ne odgovara nijednom stvarnom pokretanju.
rm -rf result/cov result/run

"$BUILD_SH" > result_build.tmp 2>&1 || { cat result_build.tmp; rm -f result_build.tmp; exit 1; }
rm -f result_build.tmp
echo "elaboracija: gotova"
echo

PROSLI=0; PALI=0; PALA_LISTA=()
POCETAK=$SECONDS

pusti() {
  local test="$1" seed="$2" t0=$SECONDS
  local izlaz
  izlaz="$("$RUN_SH" "$test" "$seed")"
  local kod=$?
  printf "  %-28s seed %-3s %5ds  %s\n" "$test" "$seed" "$((SECONDS - t0))" \
         "$(echo "$izlaz" | awk '{print $1}')"
  if [ $kod -eq 0 ]; then
    PROSLI=$((PROSLI + 1))
  else
    PALI=$((PALI + 1)); PALA_LISTA+=("$izlaz")
  fi
}

if [ "$REZIM" = "sve" ] || [ "$REZIM" = "brza" ]; then
  echo "--- brza lista ---"
  for t in "${BRZI[@]}"; do pusti "$t" 1; done
  echo
fi

if [ "$REZIM" = "sve" ] || [ "$REZIM" = "spora" ]; then
  echo "--- spora lista ---"
  for t in "${SPORI[@]}"; do pusti "$t" 1; done
  echo
  echo "--- slucajna lista ($SEEDS seed-ova) ---"
  for s in $(seq 1 "$SEEDS"); do pusti ncc_random_test "$s"; done
  echo
fi

TRAJANJE=$((SECONDS - POCETAK))

echo "############################################################"
if [ "$PALI" -gt 0 ]; then
  echo "# PALI TESTOVI:"
  for r in "${PALA_LISTA[@]}"; do echo "#   $r"; done
fi
printf "# UKUPNO: %d prosli, %d pali, %d s\n" "$PROSLI" "$PALI" "$TRAJANJE"
echo "############################################################"
echo

# Pokrivenost: XSim ide preko xcrg, Xcelium preko imc.  Spajanje baza je
# alat-specificno, pa se ovde grana -- sve ostalo je zajednicko.
if [ "$SIM" = "xsim" ]; then
  ./sim/coverage.sh text
else
  echo "=== pokrivenost (Xcelium) ==="
  echo "  Baze su u result/build_xrun/cov_work/.  Izvestaj:"
  echo "    imc -exec <skripta>   ili   imc -gui"
  echo "  (spajanje po -covtest imenima: <test>_s<seed>)"
fi

[ "$PALI" -eq 0 ] || exit 1
