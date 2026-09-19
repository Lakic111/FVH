#!/usr/bin/env bash
# ============================================================================
# build_xrun.sh -- elaboracija u Cadence Xcelium-u.  Parnjak build.sh-a.
#
#   ./sim/build_xrun.sh [top_modul]
#
# PREDUSLOV:  . amsgo        (SA TACKOM -- source, ne ./amsgo)
# Bez toga alati nisu u PATH-u.  Isto vazi i za `xmsc_run` u PSDS mesovitoj
# simulaciji, odakle je ovo preuzeto (`PSDS/src/cosim/run_cosim.sh`).
#
# NAPOMENA O PROVERI: ovaj lanac NIJE pokrenut lokalno -- Xcelium postoji samo
# na udaljenoj masini.  `-v200x` je POTVRDJEN iz PSDS cosim skripte (koristi
# `-xmvhdl_args,-v200x` za isti `ncc_core.vhd`).  Ostale zastavice su birane po
# dokumentaciji i oznacene sa PROVERITI.
#
# Filelistovi se citaju OVDE, a fajlovi se prosledjuju u komandnoj liniji.
# Namerno se ne koristi `xrun -f rtl.f`: nas format filelista koristi '#' za
# komentare, a Cadence -f fajlovi to ne tumace isto.
# ============================================================================
set -u

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VERIF"

XRUN="${XRUN:-xrun}"
TOP="${1:-tb_top}"
BUILD="result/build_xrun"

# COV=0 iskljucuje prikupljanje pokrivenosti.  Ona trazi zasebnu licencu i
# najverovatnije je jedino sto moze da padne pri prvom pokretanju, a nije
# potrebna da bi se dokazalo da testovi prolaze.  Prvo pokretanje na novoj
# masini zato ide sa COV=0 -- najmanje nepoznanica odjednom.
COV="${COV:-1}"
if [ "$COV" = "1" ]; then
  COV_ARG=(-coverage functional -covoverwrite)
else
  COV_ARG=()
  echo "NAPOMENA: pokrivenost iskljucena (COV=0)"
fi

citaj_f() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$'; }
mapfile -t RTL < <(citaj_f rtl.f)
mapfile -t TB  < <(citaj_f tb.f)

RTL_ABS=(); for f in "${RTL[@]}"; do RTL_ABS+=("$VERIF/$f"); done
TB_ABS=();  for f in "${TB[@]}";  do TB_ABS+=("$VERIF/$f");  done

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$BUILD"

# Ostatak radne biblioteke od ranijeg prevodjenja daje
#   *F,CUSCMU: More than one unit matches.
# Isto upozorenje stoji i u PSDS cosim skripti.  Brisanje je bezbedno: ceo
# sadrzaj nastaje iz izvornih fajlova.
rm -rf xcelium.d INCA_libs *.log *.history

# -v200x   : VHDL-2008.  ncc_core koristi `process (all)`, sto VHDL-93 ne zna.
#            POTVRDJENO: PSDS cosim koristi -v200x za isti ncc_core.vhd.
# -relax   : popusta LRM pravila koja Cadence primenjuje strozije od Vivada.
#            OBAVEZNO: bez njega S00 slave ne prolazi -- agregat
#            `status_reg <= (0 => done_sticky, 1 => core_busy, others => '0')`
#            daje *E,AGNLSC, jer sirina dolazi iz generika pa opseg nije
#            locally static.  (Druga greska iste vrste, `case (mem_logic)`,
#            resena je izmenom deklaracije -- vidi Napredak.md, Korak 7.)
# -uvm     : UVM koji dolazi uz Xcelium.
#            PROVERITI: ako verzija ne odgovara, dodati -uvmhome <putanja>.
# -timescale: obavezno, isto kao u XSim-u -- UVM paket nema svoj timescale.
# -coverage functional: prikupljanje pokrivenosti; izvestaj se pravi alatom imc.
#            Trazi zasebnu licencu -- iskljucuje se sa COV=0.
"$XRUN" -64bit -elaborate \
  -v200x -relax \
  -uvm \
  -timescale 1ns/1ps \
  "${COV_ARG[@]}" \
  -top "$TOP" \
  "${RTL_ABS[@]}" "${TB_ABS[@]}" \
  -l xrun_elab.log

KOD=$?
if [ $KOD -ne 0 ]; then
  echo "FAIL: elaboracija u Xcelium-u pala -- vidi $BUILD/xrun_elab.log"
  exit 1
fi
echo "=== snimak spreman u $BUILD ==="
