#!/usr/bin/env bash
# ============================================================================
# spakuj.sh -- pravi arhiv za prenos na Xcelium masinu.
#
#   ./sim/spakuj.sh [izlazni_fajl.tar.gz]
#
# Normalizuje prelome redova PA TEK ONDA pakuje.  To nije kozmetika:
#   * `.sh` sa CRLF na Linuxu daje `bad interpreter`
#   * `tb.f` sa CRLF daje imena fajlova sa CR na kraju -> "fajl ne postoji"
#   * VHDL i heks ucitavanje isto pucaju (upozorenje stoji i u PSDS cosim
#     skripti, `PSDS/src/cosim/run_cosim.sh`)
#
# Uredjivaci i alati na Windows-u vracaju CRLF pri svakom upisu, pa je jedino
# pouzdano mesto za proveru trenutak pakovanja -- ne "secam se da sam popravio".
# ============================================================================
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IZLAZ="${1:-$(dirname "$VERIF")/verif_za_xcelium.tar.gz}"

cd "$VERIF"

CR=$'\r'

prebroj_crlf() {
  local n=0 f
  while IFS= read -r f; do
    if LC_ALL=C grep -qU "$CR" "$f" 2>/dev/null; then n=$((n + 1)); fi
  done < <(find . -path ./result -prune -o -type f -print)
  echo "$n"
}

echo "=== normalizacija preloma redova ==="
PRE="$(prebroj_crlf)"

while IFS= read -r f; do
  sed -i "s/${CR}\$//" "$f"
done < <(find . -path ./result -prune -o -type f -print)

POSLE="$(prebroj_crlf)"
echo "  fajlova sa CRLF: $PRE -> $POSLE"
if [ "$POSLE" -ne 0 ]; then
  echo "FAIL: ostalo $POSLE fajlova sa CRLF"; exit 1
fi

echo "=== pakovanje ==="
rm -f "$IZLAZ"
cd "$(dirname "$VERIF")"
tar --exclude=result -czf "$IZLAZ" "$(basename "$VERIF")/"

BROJ="$(tar -tzf "$IZLAZ" | grep -vc '/$')"
echo "  $IZLAZ"
echo "  $(du -h "$IZLAZ" | cut -f1), $BROJ fajlova"
