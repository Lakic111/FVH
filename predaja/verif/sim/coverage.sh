#!/usr/bin/env bash
# Spaja baze pokrivenosti svih pokretanja i pravi izvestaj (xcrg).
#
#   ./sim/coverage.sh [text|html]
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XILINX_BIN="${XILINX_BIN:-/c/AMDDesignTools/2025.2/Vivado/bin}"
FORMAT="${1:-text}"

COV="$VERIF/result/cov"
if [ ! -d "$COV/xsim.covdb" ]; then
  echo "FAIL: nema baza u $COV/xsim.covdb -- prvo pokreni testove"; exit 1
fi

cd "$COV"

: > baze.txt
BROJ=0
for d in xsim.covdb/*/; do
  ime="$(basename "$d")"
  [ "$ime" = "xcrg_mergedDB" ] && continue
  echo "./xsim.covdb/$ime" >> baze.txt
  BROJ=$((BROJ + 1))
done

if [ "$BROJ" -eq 0 ]; then
  echo "FAIL: spisak baza je prazan"; exit 1
fi

echo "=== baze u spajanju ($BROJ) ==="
sed 's|^\./xsim.covdb/|  |' baze.txt

rm -rf izvestaj
"$XILINX_BIN/xcrg.bat" -file baze.txt -report_format "$FORMAT" \
  -report_dir ./izvestaj > xcrg_run.log 2>&1

IZV="./izvestaj/functionalCoverageReport/xcrg_func_cov_report.txt"
if [ ! -f "$IZV" ]; then
  echo "FAIL: xcrg nije napravio izvestaj -- vidi $COV/xcrg_run.log"
  tail -5 xcrg_run.log
  exit 1
fi

if [ "$FORMAT" = "text" ]; then
  echo "=== ukupno ==="
  grep -E "Coverage Score" "$IZV" | head -1
  echo "=== po grupama ==="
  awk -F',' '/^ *ncc_env_pkg::ncc_coverage::cg_/ {
               gsub(/ /,"",$1); gsub(/ /,"",$2);
               printf "  %-42s %s%%\n", $1, $2 }' "$IZV" | sort -u
  echo "=== tacke ispod 100% ==="
  awk -F',' '/^ *(cp_|x_)[a-z_]+ +,/ {
               gsub(/ /,"",$1); gsub(/ /,"",$6);
               if ($3 ~ /Hit/) next;
               if ($6+0 < 100) printf "  %-16s pokriveno %s od %s = %s%%\n",$1,$5,$3,$6 }' \
      "$IZV" | sort -u
  echo "  (prazno znaci: sve tacke su 100%)"
fi
echo "Ceo izvestaj: $COV/izvestaj/functionalCoverageReport/"
