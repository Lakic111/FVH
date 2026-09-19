# Prenos na Xcelium mašinu (FVH Korak 7)

Ovaj folder je samodovoljan: 26 fajlova, ~300 KB, bez ijedne apsolutne putanje u
`rtl.f`, `tb.f` ili izvornom kodu. Prenosi se ceo, bez izmena.

```
scp -r verif/ korisnik@masina:~/fvh/
```

`result/` se ne prenosi — to su izlazi pokretanja.

---

## Šta je već potvrđeno, a šta nije

| | XSim (lokalno) | Xcelium (udaljena mašina) |
|---|---|---|
| Elaboracija mešovitog jezika | ✅ radi | ⬜ nije pokrenuto |
| Svih 7 testova | ✅ 27 prošlo / 0 palo | ⬜ nije pokrenuto |
| Pokrivenost | ✅ 100% | ⬜ nije pokrenuto |

**Skripte za Xcelium (`build_xrun.sh`, `run_one_xrun.sh`) nisu pokrenute** — taj
simulator lokalno ne postoji. Zastavice su birane po dokumentaciji i po tome šta
je XSim tražio za isti kod. Tri mesta su najverovatnija za doradu i označena su
komentarom `PROVERITI` u `sim/build_xrun.sh`:

1. ~~`-v200x`~~ — **potvrđeno**, ne treba dirati. PSDS mešovita simulacija
   koristi `-xmvhdl_args,-v200x` za isti `ncc_core.vhd`.
2. **`-uvm`** — UVM koji dolazi uz Xcelium. Ako verzija ne odgovara, dodati
   `-uvmhome <putanja do CDNS-1.2>`.
3. **`-coverage functional`** — traži zasebnu licencu. Ako je nema, izbaciti tu
   i `-covoverwrite` zastavicu; testovi i dalje rade, samo bez pokrivenosti.

Sve ostalo — spisak izvornih fajlova, njihov redosled, top modul, imena testova,
provera PASS/FAIL — identično je XSim lancu koji radi.

**Prelomi redova su LF**, ne CRLF. To nije kozmetika: `.sh` sa CRLF na Linuxu
daje `bad interpreter`, a `tb.f` sa CRLF daje imena fajlova sa CR na kraju, pa
"fajl ne postoji". Isto upozorenje stoji i u `PSDS/src/cosim/run_cosim.sh`.

Arhiv se pravi skriptom koja normalizuje prelome PRE pakovanja:

```bash
./sim/spakuj.sh            # na Windows strani, pre prenosa
```

Ako je arhiv ipak prosao kroz Windows uredjivac, na Linux strani:

```bash
dos2unix $(find . -type f)                     # ako dos2unix postoji
find . -type f -exec sed -i "s/$(printf '\r')\$//" {} +   # ako ne postoji
```

Radna biblioteka se briše pre svake elaboracije (`xcelium.d`, `INCA_libs`) —
ostatak od ranijeg prevođenja daje `*F,CUSCMU: More than one unit matches`.

---

## Pokretanje

**Prvo `. amsgo`** — sa tačkom, tj. `source`. Bez toga alati nisu u `PATH`-u.
(Isto važi i za `xmsc_run` u PSDS mešovitoj simulaciji.)

```bash
. amsgo
which xrun          # mora nešto vratiti
```

Ako `xrun` nema, a `xmsc_run` ima, instalacija jeste Xcelium pa je `xrun` u
istom folderu:

```bash
ls $(dirname $(which xmsc_run)) | grep -i '^xrun'
XRUN=$(dirname $(which xmsc_run))/xrun ./sim/build_xrun.sh
```

```bash
cd verif
./sim/build_xrun.sh                       # elaboracija, jednom
./sim/run_one_xrun.sh ncc_smoke_test 1    # jedan test

SIM=xrun ./sim/regress.sh brza            # brza lista (5 testova)
SIM=xrun ./sim/regress.sh sve             # cela regresija, 27 pokretanja
SEEDS=5 SIM=xrun ./sim/regress.sh sve     # manje seed-ova
```

`regress.sh` koristi **istu** listu testova, isti redosled i istu proveru
PASS/FAIL za oba simulatora — grana se samo na to koji par skripti poziva. Ako se
regresija razlikuje po simulatoru, ne dokazuje prenosivost nego samo da postoje
dve različite regresije.

---

## Očekivani ishod

Isti kao na XSim-u:

```
--- brza lista ---
  ncc_vif_test                 seed 1   PASS
  ncc_axil_smoke_test          seed 1   PASS
  ncc_axil_agent_test          seed 1   PASS
  ncc_axif_smoke_test          seed 1   PASS
  ncc_smoke_test               seed 1   PASS
--- spora lista ---
  ncc_cov_test                 seed 1   PASS
  ncc_dim_sweep_test           seed 1   PASS
--- slucajna lista (20 seed-ova) ---
  ncc_random_test              seed 1..20   PASS
# UKUPNO: 27 prosli, 0 pali
```

Za dokumentaciju treba **dva loga jedan pored drugog** — XSim i Xcelium, sa istom
tabelom. XSim log je u `result/regresija.log`.

---

## Pokrivenost na Xcelium-u

Baze nastaju po pokretanju, imenovane preko `-covtest <test>_s<seed>`. Izveštaj se
pravi alatom `imc` (ne `xcrg`, to je Vivado alat):

```bash
imc -gui                     # interaktivno
imc -exec spoji.tcl          # ili skriptom
```

Cilj je isti kao na XSim-u: 100% na sve tri covergroup-e, spojeno preko cele liste.

---

## Ako nešto pukne

Prvo pitanje je **da li je magistrala ili jezgro**. Testovi su namerno poređani od
najmanjeg ka najvećem, pa odgovor daje prvi koji padne:

| Test | Šta dokazuje |
|---|---|
| `ncc_vif_test` | virtuelni interfejsi stižu, DUT miruje |
| `ncc_axil_smoke_test` | S00 upis/čitanje, sva tri AW/W redosleda |
| `ncc_axil_agent_test` | monitor rekonstruiše ono što je drajver poslao |
| `ncc_axif_smoke_test` | S01 paketni prenos, dužine 1, 2, 3, 16 |
| `ncc_smoke_test` | ceo put kroz jezgro + scoreboard |

Ako padne već `ncc_vif_test`, problem je u elaboraciji ili povezivanju, ne u
verifikacionom kodu.
