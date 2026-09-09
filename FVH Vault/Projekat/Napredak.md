---
tags: [fvh, projekat, status]
---

# Napredak — FVH projekat

> **Zadnje ažuriranje:** 2026-09-05

## Status

- ✅ **Korak 1** (PSDS projekat završen) — potvrđeno, 90/100 bodova, ploča radi,
  FEN tačan 32/32, 1.782 ms.
- ✅ **Vault izgrađen** (2026-08-30): 13 vežbi + 7 predavanja sažeto sa direktnom
  primenom na `ncc_accel`, plan implementacije po FVH koracima 2-7 napisan
  (`Plan.md`), nacrt verifikacionog plana napisan (`Verifikacioni plan.md`).
- ✅ **Korak 2** (verifikacioni plan u dokumentaciji, 2026-09-05) — gotov kao zaseban
  prilog u stilu PSDS dokumentacije:
  `FVH/Dokumentacija/FVH_verifikacioni_plan_y25-g10.pdf` (12 strana, 11 poglavlja,
  5 tabela, blok dijagram okruženja kao Slika 1). Izvor je `.html` u istom folderu,
  koristi isti CSS kao `PSDS_dokumentacija_y25-g10_Korak2-8.html`; PDF se generiše sa
  `chrome --headless --print-to-pdf`. Nacrt u `Verifikacioni plan.md` je proširen
  stvarnim brojevima iz RTL-a i služi kao radna verzija.
- ✅ **Sesija 0** (temelji repozitorijuma, 2026-09-05) — `verif/` napravljen,
  `rtl.f`/`tb.f` napisani sa relativnim putanjama, `sim/run_xsim.sh` pokreće ceo
  lanac jednom komandom, mešoviti jezik VHDL+SV **dokazan u XSim-u**
  (`tb_mixed_probe`: upis i čitanje `REG_IMG_W` = 0x5A, PASS).
- 🔄 **Korak 3** u toku. Sesija 2 gotova (2026-09-05): `ncc_verif_pkg.sv`,
  `axi_lite_if.sv`, `axi_full_if.sv`, `tb_top.sv` i skela `ncc_vif_test`.
  `./sim/run_xsim.sh` → PASS: oba virtuelna interfejsa stižu kroz `uvm_config_db`,
  reset se otpušta, DUT miruje, 0 grešaka. `tb_mixed_probe.sv` izbačen iz `tb.f`.
- 🔄 Sesija 3 gotova (2026-09-05): `ncc_axil_pkg.sv` — `ncc_reg_item`,
  `ncc_axil_sequencer`, `ncc_axil_driver`, `ncc_axil_base_seq`, `ncc_reg_rw_seq`;
  test `ncc_axil_smoke_test`.
  `./sim/run_xsim.sh tb_top ncc_axil_smoke_test` → PASS: 7 provera upis-pa-čitanje
  nad 4 registra, **u sva tri redosleda** (AW_FIRST, W_FIRST, SIMUL), 0 grešaka.
  Provereno i da provera ume da padne: kvarenje upisnog puta u drajveru
  (`wdata ^ 1`) obara svih 7 provera i skripta javi FAIL.
- 🔄 Sesija 4 gotova (2026-09-05): `ncc_axil_monitor`, `ncc_axil_agent_config`,
  `ncc_axil_agent`; test `ncc_axil_agent_test` sa `ncc_mon_subscriber`.
  → PASS: monitor rekonstruisao svih 14 transakcija (7 upisa + 7 čitanja) i
  **izmerio redosled sa magistrale** — AW_FIRST=2, W_FIRST=3, SIMUL=2, tačno kako
  je sekvenca zadala. Agent podržava i pasivan režim (bez sekvencera i drajvera).
- 🔄 Sesija 5 gotova (2026-09-05): `ncc_axif_pkg.sv` — `ncc_mem_item`,
  `ncc_axif_driver` (paketni prenos), `ncc_axif_monitor`, `ncc_axif_agent_config`,
  `ncc_axif_agent`, `ncc_mem_blok_seq`; test `ncc_axif_smoke_test`.
  → PASS: 6 paketnih upisa i čitanja, dužine 1, 2, 3 i 16 beat-ova, regioni slike i
  šablona, sva tri redosleda. Negativni test (`wdata ^ 1`) daje 46 grešaka i FAIL.
  `tb_top` više ne vozi nijednu magistralu — oba drajvera drže svoju.
- ✅ **Korak 3 ZAVRŠEN** (2026-09-05). Sesija 6: `ncc_env_pkg.sv` — `ncc_env`,
  `ncc_virtual_sequencer`, `ncc_virtual_base_seq`, `ncc_smoke_seq`; testovi
  `ncc_base_test` i `ncc_smoke_test`.
  → PASS: ceo put kroz DUT — slika i šablon preko S01, dimenzije preko S00,
  `CTRL.start`, čekanje na `done_sticky` (11,7 µs), čitanje mape rezultata sa
  `+0x10000`. Pik `0x80000000` tačno na (u=1, v=1), gde je šablon jednak prozoru;
  svih ostalih osam pozicija strogo manje.
  **Time je osvojen prag za prolaz (50 bodova).**
- ✅ **Korak 4 ZAVRŠEN** (2026-09-05, +15). `ncc_ref_pkg.sv` — bihevioralni
  referentni model NCC² izveden iz RTL-a, bit-tačan, bez DPI-a. `ncc_scoreboard`
  u `ncc_env_pkg.sv` sluša oba monitora, gradi senku memorija iz onoga što je
  viđeno na magistrali, računa predikciju na upis u `REG_CTRL` i poredi je sa
  čitanjima regiona rezultata.
  → PASS: 9 poređenja, 0 neslaganja, bit-tačno.
  SVA tvrdnje dodate u oba interfejsa: stabilnost VALID/payload do READY na svim
  kanalima, `BVALID` tek posle `WLAST`, i invarijanta `!(awready && wready)` koja
  čuva da se AW/W bug ne vrati.
- ✅ **Korak 5 ZAVRŠEN** (2026-09-05, +15). `ncc_coverage` u `ncc_env_pkg.sv` —
  zaseban subscriber na oba monitora, tri covergroup-e: `cg_dimenzije`,
  `cg_kontrola` (`start × busy`, `start × done`), `cg_axi`
  (`redosled × region`, dužina burst-a, `wstrb`).
  Testovi `ncc_cov_test` (brza lista) i `ncc_dim_sweep_test` (spora, 19
  kombinacija bin-ova dimenzija).
  → **100% funkcionalne pokrivenosti**, spojeno preko tri pokretanja
  (`./sim/coverage.sh`), sve tačke i sva tri ukrštanja. Izveštaj: `xcrg`, u
  `verif/result/cov/izvestaj/functionalCoverageReport/`.
  Cilj iz plana (100% na `redosled × region`, ≥90% ukupno) je premašen.
- ✅ **Korak 6 ZAVRŠEN** (2026-09-05, +10). Regresija jednom komandom:
  `./sim/regress.sh [sve|brza|spora]`, uz `SEEDS=N`.
  Skripte: `build.sh` (elaboracija jednom), `run_one.sh` (jedan test+seed),
  `regress.sh` (lista + tabela), `coverage.sh` (spajanje baza + `xcrg`).
  → **27 prošlo, 0 palo, 373 s**; pokrivenost **100%** spojena preko 23 baze.
  Sastav: brza lista 5 testova (3 s svaki), spora 2 (44 s i 48 s),
  slučajna `ncc_random_test` × 20 seed-ova.
- ✅ **Korak 7 ZAVRŠEN** (2026-09-05, +10). Ista regresija prošla na **oba
  simulatora**, sa identičnim ishodom:

  | | Vivado XSim | Cadence Xcelium 19.03 |
  |---|---|---|
  | Testovi | 27 prošlo, 0 palo | 27 prošlo, 0 palo |
  | Trajanje | 341 s | 68 s |
  | Elaboracija | `xvhdl -2008` + `xvlog -sv` + `xelab` | `xrun -elaborate -v200x -relax -uvm` |
  | UVM | 1.2 (uz Vivado) | CDNS-1.1d (uz Xcelium) |

  `regress.sh` prima `SIM=xsim|xrun`; **lista testova, redosled i provera
  PASS/FAIL su isti** — grana se samo koji par skripti se poziva.

  Tri stvari su bile potrebne da bi Xcelium prošao, i sve tri su nalaz Koraka 7:

  | Greška | Uzrok | Rešenje | Dira DUT? |
  |---|---|---|---|
  | `*E,AGNLSC` | agregat `status_reg <= (0 => …, 1 => …, others => '0')` nad opsegom iz generika | `xrun -relax` | ne |
  | `*E,CSODAS` | `case (mem_logic)` nad ne-locally-static podtipom | jedan red u deklaraciji | da, u kopiji |
  | `*E,TRRANGEC` | `aw/ar_wrap_size` su `integer` bez početne vrednosti → `integer'left` u nultom delta-koraku → `to_unsigned(-2^31, 17)` | `set rangecnst_severity_level warning` (`sim/xrun_run.tcl`) | ne |

  Sve tri potiču iz Xilinx AXI šablona, koji se oslanja na to da simulator
  progleda kroz prste u nultom trenutku i kod ne-statičkih podtipova. Vivado
  progleda, Cadence ne. **Ništa od toga se ne vidi bez druge simulacije** — to je
  najkonkretniji odgovor na pitanje šta je dvostruka simulacija donela.

## Odluke

- Fokus IP nivoa (`ncc_accel`) pre integracionog (`ncc_system`) — jednostavnije, i
  dovoljno za sve obavezne bodove (2-7 ne traže eksplicitno sistemski nivo).
- Poznat i popravljen AXI AW/W-ordering bug (iz PSDS BUGS.md) je centralna nit kroz
  ceo verifikacioni plan — directed test, coverage cross i SVA tvrdnja svi ga ciljaju,
  jer je to najkonkretniji, već-dokazan "interesting corner case" ovog DUT-a.
- Golden podaci ne dupliraju se ručno — referentni model za scoreboard uzima vrednosti
  iz postojećih VHDL testbenchova (`ncc_core_real_tb` peak `0x80000000 @ (32,14)`) i/ili
  poziva C kernel (`src/hls/ncc_kernel.cpp`) radije nego da se NCC² algoritam prepisuje
  treći put.

- Xcelium (korak 7) je dostupan na udaljenoj mašini, ne lokalno — lokalno je samo
  Vivado XSim. Zato: relativne putanje u filelistovima i simulator-agnostičan TB kod,
  da se `verif/` prenese na remote bez izmena.

## Okruženje za simulaciju (potvrđeno 2026-09-05)

- Vivado **2025.2** u `C:/AMDDesignTools/2025.2/Vivado/` (NE `C:/Xilinx/`), alati
  nisu u PATH-u — `run_xsim.sh` ih zove punom putanjom preko `XILINX_BIN`.
- **UVM 1.2** je uz Vivado (`data/system_verilog/uvm_1.2`), precompiled kao `-L uvm`.
  Zastavicu `-L uvm` traže i `xvlog` i `xelab`.
- XSim javlja `UVM/COMP/NAMECHECK ... requires DPI` — bezopasno, ali ako scoreboard
  (Korak 4) pozove C kernel preko DPI-C, treba `xsc` + `-dpiheader`.
- `xvhdl -2008` je **obavezan** — `ncc_core` koristi `process (all)`.

## Nalazi iz Koraka 7

**Xcelium 19.03 je odbio dve VHDL konstrukcije koje XSim prima.** Ceo SV/UVM kod se
preveo sa 0 grešaka iz prve — okruženje je prenosivo. Zapelo je na DUT-u, u
`ncc_accel_slave_lite_v1_0_S00_AXI.vhd`. Oba puta isti koren: `ADDR_LSB` se računa
iz generika, pa podtipovi nisu *locally static*, a Cadence to strogo primenjuje.

| Greška | Linija | Konstrukcija | Rešenje |
|---|---|---|---|
| `AGNLSC` | 195 | `status_reg <= (0 => …, 1 => …, others => '0')` | `xrun -relax` |
| `CSODAS` | 305 | `case (mem_logic) is` | izmena deklaracije |

- `-relax` rešava prvu, drugu ne. Za drugu je promenjen **jedan red** u zamrznutoj
  kopiji `verif/rtl/`:
  `std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB)` →
  `std_logic_vector(OPT_MEM_ADDR_BITS downto 0)`. Ista širina (4 bita);
  `mem_logic` se koristi na tri mesta i nijedno ga ne indeksira apsolutno, pa su
  dodela isečka, poređenje sa `"1100"` i `case` svi pozicioni.
- **PSDS izvor NIJE menjan** — odluka je da se ne ponavlja sinteza i provera na
  ploči. Verifikaciona kopija se time razlikuje za taj jedan red.
- **Ekvivalentnost je izmerena, ne pretpostavljena.** Puna regresija pre i posle
  izmene: 27/27 oba puta, pokrivenost 100% oba puta, i svih 27 logova
  **bajt-identično** za svaku ispisanu vrednost (scoreboard poređenja, mape
  rezultata, transakcije monitora, svih 20 seed-ova). Osnova: `result/pre.log`,
  posle: `result/post.log`.
- Rečenica za dokumentaciju je spremna: dvostruka simulacija je otkrila mesto gde
  se DUT oslanja na blagost jednog alata; ispravku primeniti pri sledećem pakovanju
  IP jezgra.

## Nalazi iz Koraka 6

- **Regresija je odmah našla pravu grešku u pobudi.** Šest od dvadeset seed-ova je
  palo sa `UVM_FATAL` na 95 ns. Uzrok: slika od `iw*ih` piksela slala se kao
  **jedan** burst, a AXI dozvoljava najviše 256 beat-ova. Svih šest palih imalo je
  `iw*ih > 256` (288, 273, 324, 483, 414, 528), svi prošli ispod. Dodati su
  `mem_upisi_deljeno` i `mem_procitaj_deljeno` koji poštuju i granicu od 256
  beat-ova i granicu od 4 KB. To je tačno ono zbog čega se pušta više seed-ova:
  jedan seed (koji je slučajno bio mali) je prolazio danima.

- **Elaboracija se radi jednom za celu regresiju.** `sim/build.sh` pravi snimak,
  `sim/run_one.sh` ga koristi. Merenje: pokretanje bez ponovne elaboracije traje
  3,7 s (`ncc_smoke_test`) odnosno 15 s (`ncc_random_test`), naspram ~30 s ranije.
  Za 27 pokretanja to je razlika između minuta i pola sata.
- **`run_xsim.sh` je sveden na omotač** oko `build.sh` i `run_one.sh`. Ranije je
  imao sopstveni lanac poziva alata — dve kopije iste logike koje bi se razišle.
- **Ograničenja koja opisuju „uobičajeno" moraju biti meka.** `c_addr` je tvrdo
  dozvoljavalo samo šest korišćenih registara, pa je upis u scratch registar
  (legalan stimulus, test T2) rušio randomizaciju. Sada `soft`. Isto važi za
  `c_strb`.
- **Nasumična čitanja regiona rezultata pre pokretanja** daju osnovano upozorenje
  scoreboard-a („nema šta da se poredi"). Upozorenje bez uzroka je šum koji
  kasnije sakrije pravo, pa taj region nije u skupu za nasumična čitanja.
- Podela na brzu i sporu listu je merljiva: brza lista sama daje 56% pokrivenosti,
  puna 100%. Brza je tu da se pokreće posle svake izmene, ne da meri pokrivenost.

## Nalazi iz Koraka 5

- **Ograničenje `c_opseg` je brkalo dubinu memorije sa veličinom regiona.** Region
  šablona zauzima 8192 reči adresnog prostora, a memorija je duboka 1024 — višak
  adresa se preklapa, i to je upravo aliasing P2. Staro ograničenje
  (`word + len <= TMP_WORDS`) činilo je test T14 **nemogućim po konstrukciji**.
  Pouka: ograničenja pobude opisuju magistralu, ne unutrašnjost DUT-a.
- **DUT poštuje `WSTRB(0)`**: `mem_we_o <= wr_beat and S_AXI_WSTRB(0)`. Upis sa
  spuštenim bitom 0 ne menja memoriju. Provereno testom (upis 0xA5 sa `WSTRB=0xE`
  ne menja sadržaj).
- **Scoreboard i monitor moraju se menjati zajedno.** Kad sam dodao poštovanje
  `strb` u scoreboard, S01 monitor ga još nije prikupljao — stavka je nosila
  `strb = 0`, svaki upis se preskakao i senka je ostala prazna. Rezultat: lažno
  neslaganje na svim vrednostima. Model koji čita polje koje monitor ne puni je
  tiha rupa.
- **Bin-ovi za velike dimenzije ne traže velike površine.** Skup 90×1 / 30×1 je
  potpuno legalan po U1–U4, gađa `cp_img_w.max` i `cp_tmp_w.max`, a računa 61
  prozor umesto 3721. Time ceo coverage test ostaje u brzoj listi.
- **Pokrivenost jednog testa ne znači ništa.** Meri se ukupna, preko liste. Baze
  se kopiraju u `result/cov/xsim.covdb/<test>_s<seed>` i spajaju sa
  `./sim/coverage.sh`. Zastavica `-cov_db_dir` na `xsim`-u ne daje ništa (izgleda
  da je traži i `xelab`), pa se baza kopira posle pokretanja.

## Nalazi iz Koraka 4

- **Referentni model je pao na SV zamci, i scoreboard ga je uhvatio.**
  `sum_den_f += df*df` sa `sum_den_f` bez znaka čini i **množenje neoznačenim** —
  kontekst dodele određuje označenost operanada. Zato je `df = -71` ušlo kao `441`
  i sve vrednosti su bile pogrešne. RTL radi `unsigned(resize(df*df, 26))`, tj.
  prvo označeno množenje pa pretvaranje. Rešenje: proizvodi idu u označene
  međupromenljive, pa se tek onda sabiraju.
- **Greška je nađena jer postoji nezavisno sidro.** Na (1,1) je šablon jednak
  prozoru, pa `df == dt` i rezultat mora biti tačno `2^31`. DUT je to davao, model
  nije — što je odmah pokazalo na kojoj je strani greška. Bez takvog sidra bi se
  moglo poverovati da DUT greši.
- **Model je izveden iz RTL-a, ne iz formule.** Bit-tačnost zavisi od celobrojnog
  zaokruživanja `(suma + count/2)/count`, odsecanja srednjih vrednosti na 8 bita,
  27/26-bitnih akumulatora, odsecanja na 52 bita i grane „varijansa je nula →
  rezultat 0". Ničega od toga nema u udžbeničkoj formuli.
- **Bez DPI-a.** Model je čist SystemVerilog, pa se prenosi na Xcelium bez dodatnog
  koraka prevođenja (Korak 7). XSim ionako radi sa `UVM_NO_DPI`.
- **SVA tvrdnje stoje u interfejsima, ne u testbenču**, pa važe u svakom testu — i
  u onima koji o njima ne znaju ništa. Tvrdnja `!(awready && wready)` je popravka
  AW/W buga pretočena u izvršni oblik: ako se ikad oba dignu, bug se vratio.
- **Neuspeh tvrdnje ne broji se kao `UVM_ERROR`.** XSim ga ispisuje kao `Error: ...`,
  pa ga hvata `^Error:` grana u `run_xsim.sh`. Da te grane nema, tvrdnje bi opalile
  a test bi i dalje prošao.

## Nalazi iz Sesije 6

- **Smoke test sa pogrešnim podacima izgleda kao da radi.** Prvi pokušaj je koristio
  linearni gradijent (piksel = `i*16`) i dobio `0x80000000` na **svih devet** pozicija.
  To nije greška DUT-a — NCC je invarijantan na dodavanje konstante, a svaki prozor
  takve slike jeste šablon uvećan za konstantu. Ali takav skup **ne razlikuje ispravan
  DUT od onog koji uvek vraća istu vrednost**. Pravilo: smoke podaci moraju davati
  raznolik odgovor, inače test prolazi bez ikakve informativne vrednosti.
- Novi skup ima tačno jedan pik: šablon je doslovno prozor na (u=1, v=1). Provera je
  zato moguća **bez referentnog modela** — na (1,1) mora stajati tačno `0x80000000`
  i nijedna druga pozicija ne sme biti veća. Puna provera svih devet vrednosti je
  Korak 4.
- Virtuelna sekvenca šalje stavke sa `start_item(it, -1, ciljni_sekvencer)`, pa nisu
  potrebne zasebne podsekvence po agentu.
- Čekanje na `done_sticky` ide kroz `fork ... join_any` + `disable fork` sa čuvarem
  od 500 µs. Test koji visi ne daje nikakvu informaciju; test koji padne daje.

## Nalazi iz Sesije 5

- **S01 ima isti dvofazni upisni automat kao S00** (`Waddr` → `Wdata`), sa istom
  popravkom. Razlika je samo što `wready` ostaje `'1'` kroz ceo burst, do `WLAST`-a.
  Zato je drajver S01 strukturno isti kao S00, uz petlju po beat-ovima.
- **Redosled se meri po PRVOM beat-u** W kanala. Kasniji beat-ovi ne govore ništa o
  odnosu prema AW-u.
- **`ref` argument „curi" na sve naredne argumente** u SystemVerilogu — smer se
  nasleđuje od prethodnog. Posle `ref bit [31:0] d[]` i `o` i `g` su postali `ref`,
  pa prosleđivanje konstante `ORDER_AW_FIRST` nije prošlo elaboraciju. Rešenje:
  navesti `input` izričito na svakom argumentu posle `ref`.
- **Regioni slike i šablona vraćaju samo donjih 8 bita** (P3 iz plana) — provera
  mora očekivati `podatak & 0xFF`, inače pada bez razloga. Region rezultata vraća
  punih 32 bita.

## Nalazi iz Sesije 4

- **Redosled se MERI po trenutku postavljanja `VALID`-a, ne po rukovanju.** Ovo je
  najvažniji nalaz sesije. Slave nikad ne diže `wready` pre nego što prihvati AW, pa
  rukovanje na W kanalu *uvek* dolazi posle rukovanja na AW kanalu — ma kojim redom
  ih je master postavio. Monitor koji meri po rukovanju prijavi
  `AW_FIRST=7, W_FIRST=0, SIMUL=0` i scenario koji je meta celog plana postaje
  nevidljiv. Izmereno, pa vraćeno. Isto važi i za monitor S01 (Sesija 5).
- Transakcija se sklapa na rukovanju **kanala B**, jer su tada po AXI pravilima i
  adresa i podatak sigurno viđeni, bez obzira na redosled. Redovi čekanja za AW i W
  su zato dovoljni — nije potrebna nikakva pretpostavka o redosledu.
- Monitor uzorkuje isključivo kroz `mon_cb`. Kroz `mst_cb` bi gledao pobudu umesto
  magistrale i coverage bi merio sam sebe.

## Nalazi iz Sesije 3

- **AW/W redosled je potvrđen na živom DUT-u.** Sva tri scenarija prolaze sa
  drajverom koji vodi AW, W i B kao nezavisne niti (`fork...join`). `W_FIRST` traje
  duže jer slave ne diže `wready` dok ne prihvati AW — to je očekivano i mora tako.
- **Polje `order` pomera samo trenutak kretanja niti**, ne i redosled završavanja.
  Pokušaj da se redosled iznudi sekvencijalnim čekanjem vraća bug iz Sesije 0.
- **Zamka u ograničenjima:** `c_gap` traži `gap == 0` za `ORDER_SIMUL`. Pomoćni
  zadatak `upisi()` je nametao `gap = 1` i randomizacija je pala (UVM_FATAL, jasno).
  Zato `upisi()` prepušta `gap` ograničenju kad je redosled istovremen.
- **`proveri()` se ne može oboriti menjanjem očekivane vrednosti**, jer upisuje i
  čita istu vrednost — provera je smislena samo ako je put kroz DUT pokvaren. Zato
  je negativni test rađen kvarenjem drajvera, ne očekivanja. Isto važi za svaku
  buduću „upisano == pročitano" proveru.
- **Jedan signal, jedan gospodar:** `tb_top` više ne inicijalizuje S00 signale —
  od Sesije 3 ih drži drajver kroz clocking blok. S01 se i dalje drži iz `tb_top`
  dok njegov drajver ne stigne (Sesija 5).

## Nalazi iz Sesije 2 (alatni, ne projektni)

Tri zamke u lancu XSim + UVM na Windows-u. Sve tri su rešene u `sim/run_xsim.sh`;
zapisane su jer bi se inače ponovile na svakoj novoj mašini:

- **`xelab -timescale 1ns/1ps` je obavezan.** UVM paket uz Vivado nema svoj
  `timescale`, a testbenč ga ima → `XSIM 43-4099` i elaboracija pada. Xcelium traži
  isto (`xrun -timescale 1ns/1ps`).
- **`-testplusarg UVM_TESTNAME=x` puca kroz `xsim.bat`.** `cmd` deli argument na
  znaku `=`, pa xsim ispiše svoj help (`Expected a switch but found n`). Rešenje:
  ceo poziv ide kao jedan navodnicima zaštićen niz kroz `cmd.exe /c`, uz
  `MSYS2_ARG_CONV_EXCL='*'`. Na Linux/Xcelium mašini ovoga nema.
- **SV paket se ne sme zvati `ncc_pkg`** — DUT već ima VHDL paket tog imena, a u
  mešovitoj elaboraciji oba idu u biblioteku `work`. Zato `ncc_verif_pkg`.

Uz to: skripta je dopunjena **pozitivnom** proverom (traži `UVM Report Summary` u
logu). Bez nje je prijavila PASS za pokretanje u kome xsim nije ni krenuo — negativna
provera sama po sebi ne razlikuje „nema grešaka“ od „nema simulacije“.

## Nalazi iz Koraka 2 (analiza RTL-a)

Ovo su ponašanja izvedena iz koda, a ne iz ranijih beleški. Svako je pretočeno u test
u matrici (poglavlje 7 priloga):

- **Ugovor sa softverom.** `ncc_core` pri `start` proverava četiri uslova tvrdnjama sa
  `severity failure`: `1..90` za sliku, `1..30` za šablon, `tmp_w*tmp_h <= 900`,
  `tmp <= img`. Kršenje **obara celu simulaciju**, ne pojedinačni test — ograničenja
  randomizacije moraju ih garantovati. Testiranje nelegalnih dimenzija je svesno van obima.
- **Adresa 0x40 ne postoji.** S00 magistrala je 6-bitna (max 0x3F). Mapa rezultata je na
  S01, region 10 (`+0x10000`). `CLAUDE.md` je grešio; ispravljeno u prilogu.
  Registri 0x10/0x14 (`slv_reg4/5`) nisu vezani ni na jedan port jezgra.
- **Start dok je busy nije zaštićen.** Uslov za `start_pulse` nema proveru `busy`, pa
  upis u CTRL tokom rada briše `done_sticky` a impuls se gubi. Test T7.
- **Region rezultata je read-only sa S01** (`wea => '0'`), ali `BRESP` ostaje `OKAY`. Test T13.
- **Šablon aliasira** — koristi samo `word(9:0)` od 13 bita, pa se adrese na razmaku od
  1024 reči preklapaju. Test T14.
- **Region 11 je nemapiran** i vraća nule, ne `DECERR`. Test T15.
- Čitanje sa S01 ima **latenciju jednog takta** (`region_d`) — monitor to mora uračunati.

## Nalazi iz Sesije 0

- **Zvanična kopija DUT-a: `PSDS_Projekat_MOJ/src/vhdl/`.** Provereno bajt po bajt:
  `PSDS_Projekat_MOJ` i `PSDS_Projekat_PROFESOR` su identični za svih 7 VHDL fajlova;
  `NCC_Akcelerator` je starija verzija i otpada. Unutar `PSDS_Projekat_MOJ` postoje
  dve kopije (`src/vhdl/` i `ip_repo/ncc_accel_1_0/src/`) koje se razlikuju **samo u
  komentarima** — bira se `src/vhdl/` jer na nju pokazuje `SRC` u `run_sim.tcl`.
- **DUT je kopiran u `verif/rtl/` kao zamrznuti snapshot** umesto da `rtl.f` pokazuje
  na `../../PSDS_Projekat_MOJ`. Razlog: Sesija 10 prenosi `verif/` na udaljenu mašinu
  gde `PSDS_Projekat_MOJ` ne postoji. Kopija je čitanje, DUT se i dalje ne menja.
- **S00 je strogo dvofazni upisni automat** (`Waddr`: awready=1/wready=0 →
  `Wdata`: awready=0/wready=1). `awready` i `wready` se **nikad ne dižu u istom
  taktu** — to je sama popravka AW/W bug-a. Posledice:
  - Drajver iz Sesije 3 mora voditi AW, W i B kao **nezavisne niti** (`fork...join`).
    Čekanje na `awready && wready` visi zauvek — prvi `tb_mixed_probe` je tako i pao.
  - `W_FIRST` scenario prolazi **samo** ako master drži `WVALID` do `wready`.
    To je konkretan zahtev na `ncc_axil_driver`, ne opcija.
  - Isto ponašanje treba proveriti i na S01 pre pisanja burst drajvera (Sesija 5).

## Sledeći korak

Sesija 6 (Korak 3f): `ncc_env` sa oba agenta, `ncc_base_test` i `ncc_smoke_seq`.

Puna smoke sekvenca: slika i šablon preko S01 → dimenzije preko S00 →
`CTRL.start=1` → čekaj `STATUS.done_sticky` → pročitaj rezultat sa `+0x10000`.
Watchdog je obavezan (`fork...join_any` + `disable fork`) — poznati hang bi inače
obesio regresiju umesto da je oborio.

Ograničenja dimenzija moraju poštovati U1-U4 iz poglavlja 2 priloga; kršenje ruši
celu simulaciju, ne samo test. **Time se zatvara Korak 3 i osvaja prag za prolaz.**
