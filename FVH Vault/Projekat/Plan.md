---
tags: [fvh, projekat, plan]
---

# Plan implementacije — FVH verifikaciono okruženje za NCC akcelerator

Cilj: izgraditi SystemVerilog/UVM verifikaciono okruženje oko postojećeg,
nepromenjenog VHDL DUT-a `ncc_accel` (i po potrebi `ncc_system` na nivou integracije),
kroz FVH bodovne korake 2-7. Redosled je **obavezan** — ne preskakati korak.

DUT registri/interfejsi: vidi [[CLAUDE|FVH Vault/CLAUDE.md]] odeljak "DUT koji se
verifikuje". Postojeći VHDL testbenchovi (`ncc_core_tb`, `ncc_core_real_tb`,
`ncc_accel_tb`, `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb`,
`ncc_accel_s01_burst_wfirst_tb`) su izvor golden podataka i reference — **ne
prepisivati ih u SV, koristiti kao referentni model / expected-value izvor.**

---

## Korak 2 — Verifikacioni plan + struktura okruženja (uslov)

Šablon: [[Predavanje 03 - Plan verifikacije]] (ima kompletnu, instanciranu strukturu
za `ncc_accel`). Popuniti/dovršiti `Projekat/Verifikacioni plan.md` u ovom vault-u
(već je nacrt tamo) sa:

- Nivoi verifikacije: jezgro (`ncc_core`) je već verifikovano na RTL nivou u PSDS-u —
  FVH fokus je na **IP nivou** (AXI-Lite + AXI-Full interfejs) i po mogućstvu na
  **integraciji** (dva instance + interconnect), gray-box vidljivost `busy`/FSM stanja.
- Matrica funkcija-za-verifikaciju: iz registarske mape (start/status/dimenzije/adrese)
  + iz AXI protokolskih pravila (AW/W redosled, burst, uske/pogrešne dimenzije).
- Arhitektura okruženja (dijagram): dva agenta (AXI-Lite S00, AXI-Full S01) grupisana
  u `ncc_env`, sa scoreboard-om i coverage kolektorom — vidi [[Vezba 09 - Hijerarhija UVM okruženja]].
- Strategija: constrained-random + directed testovi za poznat bug (AW-pre-W hang).
- Alati: Vivado XSim + Xcelium (korak 7).

**Izlaz:** prošireni dokument (dodatak na `PSDS_dokumentacija_y25-g10_Korak2-8.pdf` ili
zaseban `.md`/`.pdf` u `02 Dokumentacija` stilu PSDS vault-a) sa verifikacionim planom
i blok dijagramom okruženja.

---

## Korak 3 — Osnovno UVM okruženje (50 bodova, tvrd uslov)

Redosled izgradnje (svaki oslanja se na prethodni — ne raditi paralelno prvi put):

1. **Interfejsi** (`axi_lite_if`, `axi_full_if`) — SV `interface` sa clocking blokovima,
   po uzoru na [[Vezba 02 - OOP aspekti SystemVerilog jezika]] (interface+package+driver
   mini-primer je skoro doslovan template).
2. **Sequence item** (`ncc_reg_item` za S00, `ncc_mem_item` za S01) — polja: adresa,
   podatak, `rw`, i za S01 dodatno `aw_first`/`w_first`/`simultaneous` bit za AXI
   ordering scenario. Randomizacija i ograničenja: [[Vezba 04 - Randomizacija i ogranicenja u SystemVerilogu]]
   (`dist` za težinsko biranje AW/W redosleda — vidi Korak 6 regresiju).
3. **Sequencer + Driver** po agentu — dva agenta (S00, S01). Model drajvera za S00
   (jednostavan, bidirekcioni non-pipelined) vs. S01 (burst, mora podržati pipeline/OOO
   redosled AW/W) — detalji u [[Vezba 06-07 - Sekvence i drajver]].
4. **Monitor** po agentu — pasivna FSM koja rekonstruiše AXI transakcije nezavisno od
   AW/W redosleda (red čekanja za AW), objavljuje preko `uvm_analysis_port` —
   [[Vezba 08 - Monitor]].
5. **Agent, config, environment** — `ncc_env` sadrži `axil_agent` + `axif_agent` +
   scoreboard (Korak 4) + coverage (Korak 5); `uvm_config_db` prosleđuje virtuelne
   interfejse odozgo (`ncc_test`) — [[Vezba 05 - Uvod u UVM metodologiju]],
   [[Vezba 09 - Hijerarhija UVM okruženja]]. Parametrizovati bazu adrese agenta da isti
   env pokrije oba `ncc_accel` instance u `ncc_system` (Korak 3 iz PSDS: 2× IP).
6. **Test + prva sekvenca** — minimalan smoke test: napiši sliku/šablon preko S01,
   pokreni preko S00 (CTRL.start), sačekaj `done_sticky`, pročitaj rezultat.
   Watchdog: `fork...join_any` + `disable fork` protiv poznatog hang bug-a
   ([[Vezba 03 - Niti u SystemVerilog jeziku]]).

**Izlaz:** okruženje koje se kompajlira i prolazi kroz bar jedan smoke test u XSim-u.

---

## Korak 4 — Scoreboard + automatska provera (15 bodova)

Vidi [[Vezba 10 - Razvoj scoreboard komponente]] i [[Predavanje 08-09 - Strategije za proveru rezultata]].

- **Referentni model**: transakcioni NCC² prediktor. Dva moguća izvora golden
  vrednosti: (a) poznati peak iz `ncc_core_real_tb` (0x80000000 @ (u=32,v=14) za
  90×90/25×15 test skup), (b) C model `src/hls/ncc_kernel.cpp` (već TDD-testiran,
  32/32 tačno) — pozvati ga kao DPI-C ili re-implementirati algoritam u SV kao čist
  bihevioralni model.
- **Real-time checking**: scoreboard prati `done_sticky` tranziciju (monitor S00) i
  odmah upoređuje sadržaj `ADDR_RESULTS`/+0x10000 regiona (monitor S01) sa predikcijom
  — brže debagovanje FSM-a nego end-of-test provera.
- Izbeći "Calc2 anti-pattern" (stimulus direktno žičan na scoreboard) — scoreboard
  sluša isključivo preko monitor analysis portova, radi horizontalne ponovne upotrebe
  za oba `ncc_accel` instance.
- Dodatna provera: SVA protokolske tvrdnje (AXI handshake, `busy`/`start` invarijante)
  iz [[Predavanje 04 dodatak - SystemVerilog Tvrdnje]] — ima gotov worked-example
  (I2C write checker) kao template za AXI write handshake + AW/W ordering guard.

**Izlaz:** scoreboard koji automatski PASS/FAIL svaki test, log jasno pokazuje
očekivano vs. dobijeno.

---

## Korak 5 — Coverage (15 bodova)

Vidi [[Vezba 11 - Prikupljanje pokrivenosti]] i [[Predavanje 10-11 - Pracenje toka verifikacije]].

Konkretni coverpoints (matrični model, odvojen od checking-a — sample-uje se iz
monitora, ne iz drajvera):

- `REG_IMG_W` / `REG_IMG_H` / `REG_TMP_W` / `REG_TMP_H` — bins: min, tipično (90/25 iz
  postojećih testova), max koji staje u 128 KB S01 region.
- Cross `REG_CTRL.start` × `REG_STATUS.busy` — hvata "start dok je busy" scenario.
- AW/W ordering (`aw_first`/`w_first`/`simultaneous`) × region (S00 kontrola vs. S01
  slika/šablon/rezultat) — **direktno cilja poznat i popravljen hang bug**, dokazuje da
  je regresija test zaista pokriva.
- Burst dužina na S01 (posebno duže od dva beata — to je granica koja je nekad
  zaglavljivala `axi_interconnect_0` u sistemskom kontekstu).

**Izlaz:** coverage report (Vivado `xcrg` ili Xcelium IMC) sa merljivim % i planom šta
nedostaje ako cilj nije 100%.

---

## Korak 6 — Regresija (10 bodova)

Vidi [[Vezba 12 - Regresija i proces debagovanja]].

- **Directed regresija** iz postojećih golden VHDL testbenchova: reprodukovati iste
  scenarije (golden 4×4/2×2, realni 90×90, burst, w-first) kao SV/UVM directed
  sekvence — regresija mora sadržavati test koji dokazano PADA na starom (pre-fix) RTL-u
  ponašanju (već postoji kao `ncc_accel_wfirst_tb`/`ncc_accel_s01_burst_wfirst_tb`
  koncept), da se dokaže da regresija zaista hvata taj bug.
- **Randomizovana regresija**: multi-seed run (`+UVM_TESTNAME` + seed po pokretanju),
  `dist`-težinski stimulus iz Koraka 3 da se AW/W hang scenario pojavljuje redovno, ne
  retko.
- Regresija mora raditi identično na oba simulatora (Korak 7) — isti filelist/test
  lista, samo drugi launch skript.

**Izlaz:** skripta (shell/Tcl/Makefile) koja pokreće N testova × M seed-ova i sažima
PASS/FAIL + coverage.

---

## Korak 7 — Vivado XSim + Xcelium (10 bodova)

Vidi [[Vezba 13 - Ponovna upotreba UVM komponenti i multi-simulator flow]].

- DUT je VHDL, testbench SV/UVM → **mešoviti jezik**, oba simulatora moraju eksplicitno
  elaborirati oba jezika zajedno.
- Vivado XSim: proširiti postojeći obrazac iz
  `C:\Users\pc\Desktop\PSDS\src\vhdl\script\run_sim.tcl` (koji već radi `xvhdl` →
  `xelab` → `xsim` za čisto-VHDL testbenchove) dodavanjem `xvlog -sv` koraka za SV/UVM
  fajlove, pa `xelab` sa oba skupa jedinica.
- Xcelium: `xrun` može analize+elaboraciju+simulaciju u jednom pozivu; koristiti isti
  pristup — jedan zajednički VHDL filelist i jedan SV/UVM filelist (ista lista i
  redosled kao `SVI_IZVORI` u `run_sim.tcl`), samo drugi launcher skript.
- Držati okruženje/testove potpuno simulator-agnostičnim (bez `$xil_` ili vendor-specific
  poziva u samom TB-u) da isti kod radi na oba bez grananja.

**Izlaz:** dva launch skripta (`run_sim_xsim.tcl` ili slično, `run_sim_xrun.sh`) koja
pokreću IDENTIČNU regresiju iz Koraka 6, sa istim PASS/FAIL ishodom.

---

## Redosled rada (checklist)

- [x] Korak 2: Verifikacioni plan dovršen i dodat u dokumentaciju
      (`FVH/Dokumentacija/FVH_verifikacioni_plan_y25-g10.pdf`, 2026-09-05)
- [x] Korak 3a: Interfejsi (`axi_lite_if`, `axi_full_if`) + `ncc_verif_pkg`, `tb_top`
      (2026-09-05; paket NIJE `ncc_pkg` — to ime već zauzima VHDL paket DUT-a)
- [x] Korak 3b: `ncc_reg_item` (S00) sa `order` poljem i `dist` raspodelom (2026-09-05)
- [x] Korak 3c: Sequencer + Driver za S00 i S01 (2026-09-05)
- [x] Korak 3d: Monitor za S00 i S01 (2026-09-05); redosled se meri po postavljanju
      VALID-a, ne po rukovanju
- [x] Korak 3e: oba agenta + config + `ncc_env` + virtuelni sekvencer (2026-09-05)
- [x] Korak 3f: `ncc_base_test` + `ncc_smoke_test`, prolazi u XSim-u (2026-09-05)
      ceo put: S01 -> S00 -> start -> done_sticky -> rezultat; pik 0x80000000 na (1,1)

**Korak 3 je zatvoren — prag za prolaz (50 bodova) je osvojen.**
- [x] Korak 4: Scoreboard (referentni model + provera na čitanju rezultata) + SVA
      tvrdnje u oba interfejsa (2026-09-05)
- [x] Korak 5: Coverage — 100%, spojeno preko tri pokretanja (2026-09-05);
      `./sim/coverage.sh` pravi `xcrg` izveštaj
- [x] Korak 6: Directed + randomizovana regresija, multi-seed (2026-09-05)
      `./sim/regress.sh` → 27 prošlo / 0 palo / 373 s, pokrivenost 100%
- [x] Korak 7: Isti testovi rade u Xcelium-u (2026-09-05)
      XSim 27/27 za 341 s, Xcelium 19.03 27/27 za 68 s, ista `regress.sh`

**Svih 7 koraka zatvoreno — 100/100.**
