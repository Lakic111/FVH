# Zajednicko za sve skripte u sim/ (ukljucuje se sa `source`, ne pokrece se).
#
#   VERIF                 apsolutna putanja do verif/ (odakle god da je skripta pozvana)
#   ucitaj_filelist F     cita rtl.f / tb.f; puni nizove IZVORI i INCDIRS
#   nadji_vivado_alat A   putanja do Vivado alata A (xvlog, xelab, xsim, xcrg, ...)
#   pokreni_alat A ARG..  pokrece alat, i na Linuxu i na Windows-u (Git Bash)
#
# Vivado se trazi ovim redom:
#   1. $XILINX_BIN               -- rucno zadat bin/ direktorijum
#   2. $XILINX_VIVADO/bin        -- postavlja ga Vivado settings64.sh / settings64.bat
#   3. PATH                      -- npr. posle `source <Vivado>/settings64.sh`
#   4. uobicajene instalacije    -- /tools/Xilinx, /opt/Xilinx, C:/Xilinx, C:/AMDDesignTools
# Prva lokacija na kojoj alat postoji pobedjuje; nijedna putanja nije zakucana.

VERIF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IZVORI=()
INCDIRS=()

# Prazne linije i linije sa # se preskacu; +incdir+DIR ide u INCDIRS.
# Putanje u filelist-u su relativne u odnosu na verif/ i ovde postaju apsolutne,
# jer se alati pokrecu iz result/build*.  CR na kraju linije se odbacuje, pa
# filelist ostaje citljiv i ako je prosao kroz Windows uredjivac.
ucitaj_filelist() {
  local linija
  while IFS= read -r linija || [ -n "$linija" ]; do
    linija="${linija%$'\r'}"
    linija="$(echo "$linija" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    case "$linija" in
      ''|'#'*)    ;;
      +incdir+*)  INCDIRS+=("$VERIF/${linija#+incdir+}") ;;
      *)          IZVORI+=("$VERIF/$linija") ;;
    esac
  done < "$VERIF/$1"
}

_vivado_kandidati() {
  [ -n "${XILINX_BIN:-}" ]     && echo "$XILINX_BIN"
  [ -n "${XILINX_VIVADO:-}" ]  && echo "$XILINX_VIVADO/bin"
  local d
  d="$(dirname "$(command -v xvlog 2>/dev/null || command -v xvlog.bat 2>/dev/null || echo .)")"
  [ "$d" != "." ] && echo "$d"
  # Najnovija verzija na uobicajenim mestima (stari i novi AMD raspored).
  ls -d /tools/Xilinx/Vivado/*/bin /tools/Xilinx/*/Vivado/bin \
        /opt/Xilinx/Vivado/*/bin   /opt/Xilinx/*/Vivado/bin \
        "$HOME"/Xilinx/Vivado/*/bin \
        /c/Xilinx/Vivado/*/bin     /c/Xilinx/*/Vivado/bin \
        /c/AMDDesignTools/*/Vivado/bin 2>/dev/null | sort -V -r
}

nadji_vivado_alat() {
  local ime="$1" d
  # .bat ima prednost: Windows instalacija nosi i Linux omotace bez ekstenzije,
  # koji pod Git Bash-om pogresno prosledjuju argumente.  Na Linuxu .bat ne postoji.
  while IFS= read -r d; do
    [ -f "$d/$ime.bat" ] && { echo "$d/$ime.bat"; return 0; }
    [ -f "$d/$ime" ]     && { echo "$d/$ime";     return 0; }
  done < <(_vivado_kandidati)
  echo "GRESKA: Vivado alat '$ime' nije pronadjen." >&2
  echo "  Pokreni 'source <Vivado>/settings64.sh' ili postavi" >&2
  echo "  XILINX_VIVADO=/putanja/do/Vivado (direktorijum koji sadrzi bin/)." >&2
  return 1
}

# Na Linuxu se alat pokrece direktno.  Na Windows-u su Vivado alati .bat fajlovi,
# a cmd.exe deli argumente na '=' (npr. -testplusarg UVM_TESTNAME=...); takav
# poziv ide kroz cmd.exe kao jedan niz, sa argumentom koji sadrzi '=' pod
# navodnicima.  Vivado ne dozvoljava razmake u putanji instalacije, pa putanja
# do alata ne treba navodnike.
pokreni_alat() {
  local alat="$1"; shift
  local a cmd jednako=0
  case "$alat" in
    *.bat) for a in "$@"; do case "$a" in *=*) jednako=1 ;; esac; done ;;
  esac
  if [ "$jednako" -eq 0 ]; then
    "$alat" "$@"
    return
  fi
  cmd="$(cygpath -w "$alat")"
  for a in "$@"; do
    case "$a" in
      *=*|*' '*) cmd="$cmd \"$a\"" ;;
      *)         cmd="$cmd $a" ;;
    esac
  done
  MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "$cmd"
}
