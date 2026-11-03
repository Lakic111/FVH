#!/bin/bash
# Regresija: prevodjenje jednom, pa test_smoke, test_cov i test_random sa N seed-ova.
#
#   ./regresija.sh             Vivado XSim, 20 seed-ova
#   ./regresija.sh 5           Vivado XSim, 5 seed-ova
#   SIM=xrun ./regresija.sh    Cadence Xcelium
#
# Vivado se trazi u VIVADO (direktorijum bin/), npr.
#   VIVADO=/tools/Xilinx/Vivado/2025.2/bin ./regresija.sh
# Rezultati: result/log/ (log svakog testa), result/izvestaj/ (pokrivenost,
# XSim preko xcrg, Xcelium preko imc).

cd "$(dirname "$0")"
SIM=${SIM:-xsim}
SEEDS=${1:-20}
VIVADO=${VIVADO:-/c/AMDDesignTools/2025.2/Vivado/bin}

# Na Windows-u su Vivado alati .bat fajlovi.
EXT=""
if [ -f "$VIVADO/xsim.bat" ]; then EXT=".bat"; fi

rm -rf result
mkdir -p result/log
cd result
VHD=$(grep '\.vhd$' ../run.f | sed 's|^|../|')
SV=$(grep '\.sv$' ../run.f | sed 's|^|../|')

# ---------------------------------------------------------------- prevodjenje
echo "=== prevodjenje ($SIM) ==="
if [ "$SIM" = "xsim" ]; then
   "$VIVADO/xvhdl$EXT" -2008 $VHD                > log/build.log 2>&1 &&
   "$VIVADO/xvlog$EXT" -sv -L uvm -i ../sv $SV   >> log/build.log 2>&1 &&
   "$VIVADO/xelab$EXT" -L uvm -timescale 1ns/1ps -debug off ncc_top -s ncc_top >> log/build.log 2>&1
else
   # Xilinx S01 sablon u nultom trenutku racuna integer van opsega; Cadence to
   # prijavljuje kao gresku, XSim ne. Spusta se na upozorenje.
   printf 'set rangecnst_severity_level warning\nrun\nexit\n' > xrun.tcl
   # -v200x: VHDL-2008, -relax: S00 koristi agregat nad opsegom iz generika
   xrun -64bit -elaborate -v200x -relax -uvm -timescale 1ns/1ps \
        -coverage functional -covoverwrite -top ncc_top -incdir ../sv \
        $VHD $SV -l log/build.log > /dev/null 2>&1
fi
if [ $? -ne 0 ]; then
   echo "prevodjenje nije uspelo, vidi result/log/build.log"
   exit 1
fi

# ---------------------------------------------------------------- jedan test
PROSLO=0
PALO=0
pokreni() {
   local test=$1 seed=$2
   local log="log/${test}_s${seed}.log"
   if [ "$SIM" = "xsim" ]; then
      # opcije idu kroz fajl jer .bat na Windows-u lomi argument sa '='
      echo "-testplusarg UVM_TESTNAME=$test -sv_seed $seed -cov_db_dir cov -cov_db_name ${test}_s${seed}" > opcije.txt
      "$VIVADO/xsim$EXT" ncc_top -R -f opcije.txt > "$log" 2>&1
   else
      xrun -R +UVM_TESTNAME=$test -svseed $seed -input xrun.tcl \
           -covtest ${test}_s${seed} -l "$log" > /dev/null 2>&1
   fi
   if grep -q "UVM_ERROR :    0" "$log" && grep -q "UVM_FATAL :    0" "$log" \
      && ! grep -qE "^Failure|\*E," "$log"; then
      echo "  PASS  $test  seed $seed"
      PROSLO=$((PROSLO + 1))
   else
      echo "  FAIL  $test  seed $seed   (vidi result/$log)"
      PALO=$((PALO + 1))
   fi
}

echo "=== testovi ==="
POCETAK=$SECONDS
pokreni test_smoke 1
pokreni test_cov 1
for s in $(seq 1 $SEEDS); do
   pokreni test_random $s
done
echo "=== ukupno: $PROSLO proslo, $PALO palo, $((SECONDS - POCETAK)) s ==="

# ---------------------------------------------------------------- pokrivenost
if [ "$SIM" = "xsim" ]; then
   "$VIVADO/xcrg$EXT" -dir cov -report_format text -report_dir izvestaj > log/xcrg.log 2>&1
   echo "=== pokrivenost ==="
   grep -m1 "Coverage Score" izvestaj/functionalCoverageReport/xcrg_func_cov_report.txt
   grep -E "^ +ncc_pkg::ncc_monitor::cg_" izvestaj/functionalCoverageReport/xcrg_func_cov_report.txt \
      | awk -F',' '{ gsub(/ /, "", $1); gsub(/ /, "", $2); printf "  %-36s %s%%\n", $1, $2 }'
else
   # Xcelium: baze svih pokretanja su u cov_work/scope/<test>_s<seed>,
   # imc ih spaja u jednu (sve) i pise tekstualni izvestaj.
   mkdir -p izvestaj
   printf '%s\n' \
      'merge cov_work/scope/* -overwrite -out sve' \
      'load -run sve' \
      'report -summary -metrics covergroup -out izvestaj/pokrivenost_ukupno.txt' \
      'report -detail -metrics covergroup -all -out izvestaj/pokrivenost_detalji.txt' \
      'exit' > imc.tcl
   echo "=== pokrivenost ==="
   if which imc > /dev/null 2>&1; then
      imc -exec imc.tcl > log/imc.log 2>&1
      cat izvestaj/pokrivenost_ukupno.txt
   else
      echo "  imc nije instaliran; baze su u result/cov_work/scope/"
   fi
fi

[ $PALO -eq 0 ]
