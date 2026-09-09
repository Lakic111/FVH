---
tags: [fvh, vezba]
---

# Vežba 12 - Regresija i proces debagovanja

## Ključni koncepti
- **Debug UVM okruženja** olakšan je ugrađenim UVM Command Line Processor opcijama (prosleđuju se preko `+opcija` pri pokretanju simulatora):
  - `+UVM_CONFIG_DB_TRACE` - ispisuje kada je konfiguracija postavljena (`set`) i preuzeta (`get`) preko `uvm_config_db`; korisno kad `get` ne pronađe vrednost jer je `set` uradjen na pogrešnom putu/nivou hijerarhije.
  - `+UVM_PHASE_TRACE` - ispisuje početak/kraj svake UVM faze (build, connect, run...).
  - `+UVM_OBJECTION_TRACE` - prati podizanje/spuštanje objection-a (`raise_objection`/`drop_objection`) i broj aktivnih objection-a - ključno za debug simulacija koje se ne završavaju ili se završavaju prerano.
  - `+UVM_VERBOSITY` - kontroliše nivo detaljnosti ispisa (`UVM_NONE/LOW/MEDIUM/HIGH/FULL/DEBUG`).
  - `+UVM_MAX_QUIT_COUNT=<N>` - simulacija se prekida kada broj `uvm_error` poruka dostigne N (podrazumevano -1 = nikad).
- Debug funkcije koje se pozivaju iz `end_of_elaboration_phase`: `print_topology()` (ispis hijerarhije komponenti), `debug_connected_to(level, max_level)` (mapa komponenti povezanih na TLM port), `debug_provided_to(level, max_level)` (mapa komponenti povezanih na TLM imp).
- **Regresija** = ponovno puštanje svih (ili odabranih) postojećih testova nakon svake promene dizajna ili verifikacionog okruženja, sa nasumičnim seed-ovima random generatora, da se potvrdi da nove izmene nisu unele regresije (nove greške) i da se i dalje postiže ciljna pokrivenost.
- Efikasnost regresije se poboljšava: (1) odabirom optimalnog/minimalnog skupa testova koji i dalje zadovoljava ciljnu pokrivenost, i (2) paralelnim puštanjem više testova.
- Praktični parametri za regresiju: nizak `UVM_VERBOSITY` (fajlovi se analiziraju samo kad test prijavi grešku - tada se ponovo pušta isti test/seed sa detaljnijim ispisom) i `UVM_MAX_QUIT_COUNT` da se ne troši vreme nakon što je broj grešaka dovoljan.
- Pokretanje sa nasumičnim seed-om u Cadence Xcelium (`irun`): `irun top_module.sv -svseed random`; za masovno puštanje testova se izostavlja `-gui` (headless/batch mod).
- Model pokrivenosti mora omogućiti praćenje stanja verifikacije kroz regresiju - posle svake pronađene greške treba ponovo pustiti regresiju da se potvrdi da izmena (dizajna ili okruženja) nije unela nove greške.

## Kod / primeri
Česte greške (gotchas) u SV/UVM okruženjima, iz vežbe i `v12_gotchas_examples.sv`:
```systemverilog
// Nedostatak eksplicitnog objection lifecycle-a i fork/join_any/disable fork
task run_phase(uvm_phase phase);
   phase.raise_objection(this);
   fork
      generate_random_events();
      display_tr();
   join_any;
   disable fork;
   phase.drop_objection(this);
endtask
```
Bez `raise_objection`/`drop_objection` simulacija se prekida prevremeno (uobičajena greška kod debug-ovanja "test se odmah završi").

```systemverilog
constraint addr_data_constraint {
   addr == 5;
   5 < data < 10;
}
```
Primer korektnog jednog-operatora-po-izrazu ograničenja (`5 < data < 10` je zapravo `(5<data)<10`, treba `5 < data && data < 10` - tabela grešaka u vežbi 12 to eksplicitno pokriva).

Ostale tipične greške iz tabele u vežbi:
- `signed` tipovi (`byte` je -128..127, ne 0..255) - koristiti `bit`/eksplicitne opsege za neoznačene vrednosti.
- Level-sensitive `wait(e1.triggered)` u petlji stvara zero-delay petlju; ispravno je `@(e1);`.
- `always @(a || b)` je osetljivo na *rezultat* izraza a ne na promenu bilo kog signala; treba `always @(a or b)`.
- `handle` vs objekat: dva handle-a mogu pokazivati na isti objekat (`t2 = t1;`), promena kroz jedan menja i drugi.
- `assert(x.randomize());` - uvek proveriti da li je randomizacija uspela (može failovati zbog konfliktnih ograničenja).

Regresija - Xcelium pokretanje sa random seed-om:
```
irun top_module.sv -svseed random
```

## Primena na NCC akcelerator projekat
- **Objection lifecycle**: test za NCC mora podizati objection dok traje ceo NCC ciklus (upis registara → `start` → čekanje `busy=0`/`done_sticky=1` → čitanje rezultata sa `ADDR_RESULTS`), inače će se simulacija prekinuti pre nego što FSM (23 stanja + `seq_divider`) završi obradu - realan rizik s obzirom da `seq_divider` (sekvencijalno deljenje) traje više ciklusa.
- **+UVM_OBJECTION_TRACE** i **+UVM_CONFIG_DB_TRACE** su prvi alati za debug kada test visi (hang) - direktno relevantno jer je poznat HW bug da AXI write hangs kad W stigne pre AW; trag objection-a pokazuje da li je test zaglavljen čekajući `busy`/`done` koji nikad ne stiže zbog takvog hang-a.
- **Regresija za NCC treba da uključi (kao skup testova sa nasumičnim seed-ovima)**:
  1. Directed testovi za poznati fix (AW-first / W-first / simultaneous na S00 i S01) - ovo su i dalje vredni regresioni testovi jer proveravaju da fix ne regresira.
  2. Nasumične kombinacije REG_IMG_W/H i REG_TMP_W/H (uključujući granične vrednosti: min, max koji staje u 128KB memorijski region, van-opsega vrednosti koje bi trebalo tretirati kao ilegalne).
  3. start-while-busy testovi (upis REG_CTRL dok je busy=1).
  4. Burst varijacije na S01 (single-beat do max burst) preko cele memorije (image/template/results regioni).
  5. Regresija na oba postojeća golden VHDL testbench-a kao referenca za očekivano ponašanje: `ncc_core_tb`, `ncc_core_real_tb`, `ncc_accel_tb`, `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb`, `ncc_accel_s01_burst_wfirst_tb` - njihovi stimulus/expected-output parovi mogu poslužiti kao osnova za scoreboard reference model ili directed sequence-e u UVM okruženju.
- Za zahtev "obe simulacije" (Vivado XSim i Xcelium - [[Predavanje 10-11 - Pracenje toka verifikacije]] pominje xcrg samo za Vivado dashboard izveštaj) - regresiju treba organizovati kao skriptu koja poziva oba simulatora sa istim seed-ovima/testovima i upoređuje pass/fail i coverage izveštaje (xcrg za Vivado, IMC/urg-ekvivalent za Xcelium), radi ispunjenja stavke "pokrenuto i u Vivado XSim i u Xcelium" iz kriterijuma ocenjivanja.
- Nizak `UVM_VERBOSITY` + `UVM_MAX_QUIT_COUNT` preporučeni su za brzu regresiju velikog broja seed-ova; kad test na NCC-u prijavi grešku (npr. scoreboard detektuje pogrešan rezultat korelacije), ponovo pustiti isti seed sa `UVM_HIGH`/`UVM_FULL` za detaljan debug.

Vidi i [[Vezba 11 - Prikupljanje pokrivenosti]] i [[Predavanje 10-11 - Pracenje toka verifikacije]].
