#!/bin/bash
# Regression: build once, then test_smoke, test_cov and test_random with N seeds.
#
#   ./regression.sh             Vivado XSim, 20 seeds
#   ./regression.sh 5           Vivado XSim, 5 seeds
#   SIM=xrun ./regression.sh    Cadence Xcelium
#
# Vivado is taken from VIVADO (its bin/ directory), e.g.
#   VIVADO=/tools/Xilinx/Vivado/2025.2/bin ./regression.sh
# Results: result/log/ (log of every test), result/report/ (coverage).

cd "$(dirname "$0")"
SIM=${SIM:-xsim}
SEEDS=${1:-20}
VIVADO=${VIVADO:-/c/AMDDesignTools/2025.2/Vivado/bin}

# On Windows the Vivado tools are .bat files.
EXT=""
if [ -f "$VIVADO/xsim.bat" ]; then EXT=".bat"; fi

rm -rf result
mkdir -p result/log
cd result
VHD=$(grep '\.vhd$' ../run.f | sed 's|^|../|')
SV=$(grep '\.sv$' ../run.f | sed 's|^|../|')

# ---------------------------------------------------------------- build
echo "=== build ($SIM) ==="
if [ "$SIM" = "xsim" ]; then
   "$VIVADO/xvhdl$EXT" -2008 $VHD                > log/build.log 2>&1 &&
   "$VIVADO/xvlog$EXT" -sv -L uvm -i ../sv $SV   >> log/build.log 2>&1 &&
   "$VIVADO/xelab$EXT" -L uvm -timescale 1ns/1ps -debug off ncc_top -s ncc_top >> log/build.log 2>&1
else
   # At time zero the Xilinx S01 template computes an out-of-range integer; Cadence
   # reports it as an error, XSim does not. It is lowered to a warning.
   printf 'set rangecnst_severity_level warning\nrun\nexit\n' > xrun.tcl
   # -v200x: VHDL-2008, -relax: S00 uses an aggregate over a range computed from a generic
   xrun -64bit -elaborate -v200x -relax -uvm -timescale 1ns/1ps \
        -coverage functional -covoverwrite -top ncc_top -incdir ../sv \
        $VHD $SV -l log/build.log > /dev/null 2>&1
fi
if [ $? -ne 0 ]; then
   echo "build failed, see result/log/build.log"
   exit 1
fi

# ---------------------------------------------------------------- one test
PASSED=0
FAILED=0
run_test() {
   local test=$1 seed=$2
   local log="log/${test}_s${seed}.log"
   if [ "$SIM" = "xsim" ]; then
      # options go through a file because a .bat on Windows splits an argument containing '='
      echo "-testplusarg UVM_TESTNAME=$test -sv_seed $seed -cov_db_dir cov -cov_db_name ${test}_s${seed}" > options.txt
      "$VIVADO/xsim$EXT" ncc_top -R -f options.txt > "$log" 2>&1
   else
      xrun -R +UVM_TESTNAME=$test -svseed $seed -input xrun.tcl \
           -covtest ${test}_s${seed} -l "$log" > /dev/null 2>&1
   fi
   if grep -q "UVM_ERROR :    0" "$log" && grep -q "UVM_FATAL :    0" "$log" \
      && ! grep -qE "^Failure|\*E," "$log"; then
      echo "  PASS  $test  seed $seed"
      PASSED=$((PASSED + 1))
   else
      echo "  FAIL  $test  seed $seed   (see result/$log)"
      FAILED=$((FAILED + 1))
   fi
}

echo "=== tests ==="
START=$SECONDS
run_test test_smoke 1
run_test test_cov 1
for s in $(seq 1 $SEEDS); do
   run_test test_random $s
done
echo "=== total: $PASSED passed, $FAILED failed, $((SECONDS - START)) s ==="

# ---------------------------------------------------------------- coverage
# As in exercise 11: xcrg merges the databases of all runs and writes a report,
# html (open dashboard.html) and text (the total percentage is printed here).
# Xcelium databases stay in result/cov_work/ (the imc tool is not installed).
if [ "$SIM" = "xsim" ]; then
   "$VIVADO/xcrg$EXT" -report_format html -dir cov -report_dir report >  log/xcrg.log 2>&1
   "$VIVADO/xcrg$EXT" -report_format text -dir cov -report_dir report >> log/xcrg.log 2>&1
   echo "=== coverage ==="
   grep -m1 "Coverage Score" report/functionalCoverageReport/xcrg_func_cov_report.txt
   echo "  report: result/report/functionalCoverageReport/dashboard.html"
fi

[ $FAILED -eq 0 ]
