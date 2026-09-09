---
tags: [fvh, vezba]
---

# Vežba 13 - Ponovna upotreba UVM komponenti (APB/I2C UVC, reset agent) i pokretanje u više simulatora

## Ključni koncepti

- Tema vežbe je **reuse (ponovna upotreba koda)**: dati su gotovi, protokolski-nezavisni UVC-i (Universal Verification Component) za **APB** i **I2C**, plus samostalan **reset agent**. Cilj je da se ove komponente "utaknu" u bilo koje UVM okruženje bez prepravljanja internog koda — samo kroz `uvm_config_db` konfiguraciju.
- Svaki UVC ima standardnu UVM strukturu:
  - `*_pkg.sv` — paket koji `` `include ``-uje sve fajlove i sadrži parametre (npr. `ADDR_WIDTH`, `SLV_NUM` kod APB-a — do 15 slave-ova preko `psel` indeksa).
  - `*_if.sv` — SV interfejs sa DUT signalima (uključen izvan paketa, na kraju `apb_pkg.sv` fajla).
  - `*_transaction.sv`, `*_types.sv` — item i tipovi/enumi.
  - `*_config.sv` (top-level) + `master/*_config.sv`, `slave/*_config.sv` — hijerarhija konfiguracionih objekata (agent je `UVM_ACTIVE`/`UVM_PASSIVE`, adresni opsezi, itd.).
  - `master/` i `slave/` poddirektorijumi: svaki ima svoj `agent`, `driver`, `monitor`, `sequencer`, i `sequences/` sa bibliotekom sekvenci (`*_seq_lib.sv`, `*_base_seq.sv`, konkretne sekvence poput `read_all_seq`, `write_all_seq`, `read_after_write_seq`).
  - `env` (`apb_env.sv`) instancira i master i slave agente.
- **Reset agent** (`reset_agent/sv/`) — samostalna, ponovo upotrebljiva komponenta za generisanje reset signala **nasumičnog trajanja**. Konfigurabilan preko `reset_config`: `active_high` (aktivan visok/nizak nivo), `value_at_0` (vrednost na početku simulacije), `is_active` (UVM_ACTIVE/PASSIVE), `has_checks`, `has_coverage`. Aktivan agent kreira sequencer+driver; monitor se kreira uvek.
- Test top modul (`apb_test_top.sv` / `i2c_test_top.sv`) je klasičan UVM testbench top: instancira DUT i virtuelni interfejs, generiše clock/reset proceduralno (`initial`/`always #5`), postavlja virtuelni interfejs u `uvm_config_db` (`set(null,"uvm_test_top.*","apb_if", apb_vif)`) i zove `run_test()`.
- Zadaci vežbe (pisanje novih testova, spajanje dva slave agenta preko `psel`, scoreboard sa TLM konekcijom na monitore, dodavanje reset agenta u postojeći env) — sve su to obrasci direktno primenljivi na bilo koji AXI-Lite/AXI-Full UVC.
- **Simulator flow u materijalima**: jedini dat skript za pokretanje je `sim/run.do` — to je **ModelSim/QuestaSim `.do` skripta** (`vlib`, `vlog -sv +incdir+...`, `vsim ... -novopt +UVM_TESTNAME=... -sv_seed random`), **ne** Vivado XSim i **ne** Xcelium. Materijali dakle ne pokazuju eksplicitno Xcelium (`xrun`/`xmvlog`/`xmelab`/`xmsim`) ni Vivado (`xvlog`/`xelab`/`xsim`) invokaciju — student mora sam preneti isti compile/elab/run obrazac (fajl-liste, `+incdir`, `+UVM_TESTNAME`) na ta dva alata.
- PDF (vezba13.pdf) je čisto zadatak-orijentisan (bez multi-simulator uputstva) — fokus je na strukturi UVC-a i pisanju testova/scoreboard-a, ne na alatnom lancu.

## Kod / primeri

`apb_uvc/sim/run.do` (QuestaSim primer kompajliranja/pokretanja — obrazac za prenošenje na Vivado/Xcelium):
```tcl
vlib work
vlog -sv +incdir+$env(UVM_HOME) +incdir+../sv +incdir+../examples +incdir+../examples/tests \
    ../sv/apb_pkg.sv ../examples/apb_test_top.sv
vsim apb_test_top -novopt +UVM_TESTNAME=apb_test_simple -sv_seed random
```

`apb_test_top.sv` — tipičan SV top koji povezuje DUT i UVC preko virtuelnog interfejsa i config_db:
```systemverilog
apb_if apb_vif(clock, reset);
dut #(...) dut_inst (.paddr(apb_vif.paddr), ...);
initial begin
    uvm_config_db#(virtual apb_if)::set(null,"uvm_test_top.*","apb_if", apb_vif);
    run_test();
end
```

`reset_config.sv` — primer konfiguracionog objekta ponovo upotrebljive komponente:
```systemverilog
bit active_high = 1;
uvm_active_passive_enum is_active = UVM_ACTIVE;
bit has_checks = 1;
bit has_coverage = 1;
```

Postojeći PSDS `run_sim.tcl` (`C:\Users\pc\Desktop\PSDS\src\vhdl\script\novo_pakovanje\run_sim.tcl`) već poziva Vivado alate direktno kao eksterne procese:
```tcl
exec xvhdl -2008 {*}$lista
exec xelab -debug off $ime -s sim_$ime
exec xsim sim_$ime -R
```

## Primena na NCC akcelerator projekat

- **Ovo je jedini materijal iz kursa koji direktno cilja zahtev 7 (10 poena: XSim + Xcelium)**, ali pošto dati `run.do` koristi QuestaSim, treba ga tretirati kao **šablon toka** (compile → elaborate → run, sa `+incdir` i `+UVM_TESTNAME`), a ne kao gotov recept za Vivado/Xcelium. Konkretan plan:
  1. **Vivado XSim** — nastaviti na već postojećem obrascu iz `C:\Users\pc\Desktop\PSDS\src\vhdl\script\novo_pakovanje\run_sim.tcl`, koji već poziva `xvhdl -2008` / `xelab` / `xsim` kao eksterne alate za VHDL testbenchove. Za budući SV/UVM testbench treba dodati **mešoviti VHDL+SV flow**:
     - `xvhdl -2008 ncc_pkg.vhd ncc_core.vhd dp_bram.vhd mem_subsystem.vhd ncc_accel_slave_lite_v1_0_S00_AXI.vhd ncc_accel_slave_full_v1_0_S01_AXI.vhd ncc_accel.vhd` (DUT ostaje VHDL, ne dira se — po specifikaciji projekta).
     - `xvlog -sv -L uvm +incdir+$UVM_HOME/src <sv fajlovi UVC-a i test top-a>` za SystemVerilog/UVM stranu (analogno `vlog -sv +incdir+...` iz `run.do`).
     - `xelab -debug typical -L uvm <top> -s sim_<test>` — Xelab automatski povezuje VHDL i SV bibliteke ako su obe analizirane u istom `work` direktorijumu (mešovita elaboracija je podržana u XSim-u).
     - `xsim sim_<test> -testplusarg UVM_TESTNAME=<ime> -R`.
  2. **Xcelium** — analogan tok sa Cadence alatima: `xmvlog`/`xrun -incdir` za analizu SV, `xrun -mixgen`/`-uvmhome` za mešoviti VHDL/SV projekat, ili jednim pozivom `xrun -sv -uvm -access +rwc <svi .vhd i .sv fajlovi> -top <top>`. Ključna razlika od Vivado toka: Xcelium `xrun` može odraditi analyze+elaborate+simulate u jednoj komandi, dok Vivado zahteva tri odvojena poziva (`xvhdl`/`xvlog` → `xelab` → `xsim`). Obavezno testirati `+UVM_TESTNAME=` prosleđivanje identično kao u `run.do` primeru (`vsim ... +UVM_TESTNAME=apb_test_simple`), pošto će isti mehanizam (plusarg) raditi u sva tri simulatora.
  3. **Mešovito-jezičko upozorenje**: DUT (`ncc_accel`, `ncc_core`, AXI-Lite/AXI-Full slave-ovi) je VHDL, a budući testbench (agent za AXI4-Lite konfiguraciju registara REG_CTRL/REG_STATUS, agent za AXI4-Full pristup memoriji na +0x00000/+0x08000/+0x10000) biće SystemVerilog/UVM — i XSim i Xcelium podržavaju VHDL–SV mixed-language simulaciju, ali oba zahtevaju da se VHDL analizira VHDL alatom (`xvhdl` / Xcelium ekvivalent) pre elaboracije zajedno sa SV, i da top-level modul (koji instancira VHDL DUT unutar SV testbencha, po uzoru na `apb_test_top.sv`/`dut.sv` iz vežbe) bude ispravno prepoznat kao mešoviti dizajn.
  - Sledeći korak strukture UVC-a iz vežbe se direktno preslikava na **AXI4-Lite UVC za registre `ncc_accel`** (agent analogan `apb_master_agent` — sekvence za upis `REG_IMG_W/H`, `REG_TMP_W/H`, `REG_IMG_ADDR`, `REG_TMP_ADDR`, pisanje bita `start` u `REG_CTRL` (0x30), polling `REG_STATUS` (0x34, bit0=done_sticky, bit1=busy)) i na **AXI4-Full UVC za memorije** (upis slike na +0x00000, template na +0x08000, čitanje rezultata sa +0x10000) — obe sekvence bi trebalo strukturirati kao `*_seq_lib.sv` biblioteke po uzoru na `apb_master_seq_lib.sv`.
  - **Reset agent iz vežbe je direktno upotrebljiv bez izmena** za resetovanje `ncc_accel` DUT-a nasumičnog trajanja tokom regresije (npr. reset usred FSM stanja od 23 moguća, da se proveri robustnost `seq_divider`-a i FSM-a) — samo ga instancirati u env-u i povezati `reset_if` na `s00_axi_aresetn`/`s01_axi_aresetn` DUT-a.
  - Fajl-liste (`.f` fajlovi) nisu date u materijalima — student treba sam napraviti `filelist.f` sa svim VHDL izvorima (redosled bitan: `ncc_pkg.vhd` prvi, zatim `dp_bram.vhd`, `mem_subsystem.vhd`, `ncc_core.vhd`, pa AXI slave-ovi, pa `ncc_accel.vhd` — isti redosled kao u `SVI_IZVORI` listi u postojećem `run_sim.tcl`) i posebnu listu SV/UVM fajlova, da bi se ista lista mogla proslediti i `xvlog`/`xelab` (Vivado) i `xrun` (Xcelium) pozivima — ovo je ključno za "isti TB, dva simulatora" zahtev.

