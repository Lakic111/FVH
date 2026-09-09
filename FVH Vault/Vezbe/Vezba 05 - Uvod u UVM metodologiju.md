---
tags: [fvh, vezba]
---

# Vežba 05 - Uvod u UVM metodologiju razvoja verifikacionih okruženja

## Ključni koncepti

- **UVM (Universal Verification Methodology)** — standardizovana SystemVerilog biblioteka (Accellera), bazirana na OVM/eRM, aktuelna verzija 1.2 (2014). Glavna ideja: **UVC (Universal Verification Component)** — komponente sa jednakom strukturom (monitor, drajver, sekvencer) koje se lako ponovo koriste.
- **Tipična struktura testbenča** (hijerarhija `has-a`):
  - `top` (modul) → instancira `test`
  - `test` → sadrži `sequences` i `config`, instancira `environment`
  - `environment` (env) → sadrži jedan ili više `agent`-a, `scoreboard`, `coverage collector`
  - `agent` → `sequencer` + `driver` + `monitor` (aktivan agent instancira sva tri; pasivan samo `monitor`)
  - `sequencer` — generator stimulusa, šalje transakcije (`sequence_item`) drajveru na osnovu sekvenci
  - `driver` — aktivna komponenta, pretvara transakcije u signale na DUT interfejsu (semplovanje, protokol)
  - `monitor` — pasivna komponenta, samo posmatra signale, prikuplja podatke/coverage, šalje dalje (npr. scoreboard-u)
  - `scoreboard` — vrši proveru na osnovu podataka iz monitora
- **UVM klasna hijerarhija**: sve nasleđuje `uvm_object`. `uvm_component` (nasleđuje `uvm_report_object`) je bazna klasa za `uvm_driver`, `uvm_sequencer`, `uvm_monitor`, `uvm_agent`, `uvm_scoreboard`, `uvm_env`, `uvm_test`. `uvm_sequence_item`/`uvm_sequence` nasleđuju direktno `uvm_object`.
- **UVM faze** — tri grupe:
  - *build* faze: `build` (instanciranje/config), `connect` (povezivanje TLM portova), `end_of_elaboration`, `start_of_simulation`
  - *run-time* faze (`task`, mogu trajati simulaciono vreme): `pre_reset...reset...post_reset`, `pre_configure...configure...post_configure`, `pre_main`, **`main`** (glavna faza — generisanje stimulusa, provera), `post_main`, `pre_shutdown...shutdown...post_shutdown`. Umesto svih pod-faza, moguće koristiti samo objedinjenu `run` fazu.
  - *cleanup* faze: `extract`, `check`, `report`, `final`
  - Dve najčešće korišćene: `build_phase` (function) i `main_phase`/`run_phase` (task, jer troši simulaciono vreme).
- **UVM factory** — design pattern za zamenu klase izvedenom klasom bez izmene ostatka koda (`factory override`, obrađeno u kasnijim vežbama). Registracija makroima: `` `uvm_component_utils(<name>) ``, `` `uvm_component_param_utils ``, `` `uvm_object_utils ``, `` `uvm_object_param_utils ``. Konstruktori moraju imati podrazumevane vrednosti argumenata (component: `name="...", parent=null`; object: `name="..."`). Kreiranje kroz `type_id::create(...)` umesto `new` da factory može da radi override.
- **UVM poruke** — umesto `$display`/`$error`: `` `uvm_info(id, msg, verbosity) ``, `` `uvm_warning(id, msg) ``, `` `uvm_error(id, msg) `` (broji se, prekida simulaciju posle max broja), `` `uvm_fatal(id, msg) `` (odmah prekida). **Verbosity** nivoi: `UVM_NONE`(0) < `UVM_LOW`(100) < `UVM_MEDIUM`(200, podrazumevano) < `UVM_HIGH`(300) < `UVM_FULL`(400) < `UVM_DEBUG`(500).
- **Virtuelni interfejs (`virtual interface`)** — omogućava da se interfejs (signal-i ka DUT-u) prosledi kao pokazivač kroz klase/komponente koje nisu deo statičke hijerarhije modula. Ključna reč `virtual` u deklaraciji tipa.
- **`uvm_config_db`** — hijerarhijski, tipiziran konfiguracioni mehanizam. `uvm_config_db#(T)::set(uvm_component cntxt, string inst_name, string field_name, T value)` i `::get(...)` (get vraća 1 ako je uspešno). Standardni način prosleđivanja virtuelnog interfejsa iz top modula u test/komponente: `set(null, "*", "calc_if", vif)` u top-u, `get(null, "*", "calc_if", vif)` u testu.
- **`run_test(<test_name>)`** u top modulu pokreće UVM faze; ime testa se može zadati i preko komandne linije `+UVM_TESTNAME=<ime>` (bez potrebe za rekompajliranjem — preporučeni pristup u praksi).
- **Simulacija — Xcelium**: `xrun -uvm +$UVM_HOME -access +rwc top.sv`; korisne opcije `+UVM_TESTNAME=`, `+UVM_VERBOSITY=`, `+UVM_MAX_QUIT_COUNT=` (broj `uvm_error`-a pre prekida — bitno za regresiju).
- **Simulacija — Vivado/XSim**: od v2019.2 podržava UVM; potrebno u Settings → Simulation dodati `-L uvm` i u `xelab`/`xvlog more options`, ili preko `.tcl`: `set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} ...`. UVM varijable (`UVM_TESTNAME`, `UVM_VERBOSITY`) se prosleđuju preko `xsim.simulate.xsim.more_options` kao `-testplusarg UVM_TESTNAME=... -testplusarg UVM_VERBOSITY=...`.

## Kod / primeri

Primer DUT-a za vežbe (Calc1 — kalkulator sa 4 nezavisna porta, komande add/subtract/shift, overflow/underflow detekcija) je model za razumevanje kako se gradi okruženje.

```systemverilog
interface calc_if (input clk, logic [6:0] rst);
   logic [31:0] out_data1, out_data2, out_data3, out_data4;
   logic [1:0]  out_resp1, out_resp2, out_resp3, out_resp4;
   logic [3:0]  req1_cmd_in;
   logic [31:0] req1_data_in;
   // ... isti obrazac za portove 2-4
endinterface
```
Interfejs objedinjuje sve signale DUT-a na jednom mestu (poređenje sa zasebnim portovima u top modulu).

```systemverilog
class test_simple extends uvm_test;
   `uvm_component_utils(test_simple)
   virtual interface calc_if vif;

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual calc_if)::get(null, "*", "calc_if", vif))
        `uvm_fatal("NOVIF",{"virtual interface must be set:",get_full_name(),".vif"})
   endfunction

   task main_phase(uvm_phase phase);
      super.main_phase(phase);
      phase.raise_objection(this);
      vif.req1_cmd_in = 4'b0001;
      vif.req1_data_in = 32'h0001;
      @(posedge vif.clk);
      // ...
      phase.drop_objection(this);
   endtask
endclass
```
Minimalni `uvm_test` skelet — preuzima vif iz config_db, direktno postavlja signale (u pravom UVM okruženju ovo bi radio drajver, ovde je pojednostavljeno radi objašnjenja koncepta).

```systemverilog
module calc_verif_top;
   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import calc_test_pkg::*;
   calc_if calc_vif(clk, rst);
   calc_top DUT(.c_clk(clk), .reset(rst), /* ... */);
   initial begin
      uvm_config_db#(virtual calc_if)::set(null, "*", "calc_if", calc_vif);
      run_test("test_simple");
   end
endmodule
```
Top modul: instancira interfejs i DUT, ubacuje vif u config_db, pokreće test.

`.f` fajl (`v5_run.f`) sadrži listu izvornih fajlova, uvmhome putanju i opcije za `xrun` — koristan obrazac za kompajliranje u Xcelium.

## Primena na NCC akcelerator projekat

Ovo je **centralno gradivo za FVH korak 3** (test/environment/config/sequencer/driver/sequence/monitor, 50 poena, prag prolaza) i temelj za korak 2 (plan verifikacije i struktura okruženja u dokumentaciji):

- **`ncc_if` interfejs** treba da obuhvati sve AXI4-Lite (S00, kontrolni registri) i AXI4-Full (S01, memorije) signale `ncc_accel.vhd` top wrappera, plus `clk`/`resetn` — po uzoru na `calc_if.sv`. Realno, imaćete dva interfejsa (ili jedan sa oba skupa signala) jer S00 i S01 imaju različite AXI profile (Lite vs Full sa burst-ovima).
- **Dva agenta u environment-u**: jedan za AXI-Lite (upravljanje REG_IMG_W/H, REG_TMP_W/H, REG_IMG_ADDR/TMP_ADDR, REG_CTRL.start, čitanje REG_STATUS), drugi za AXI-Full (upis slike na +0x00000, šablona na +0x08000, čitanje rezultata sa +0x10000) — svaki sa svojim `sequencer`/`driver`/`monitor`, po UVM konvenciji iz ove vežbe.
- **`ncc_test` klasa** (analogno `test_simple`) preuzima virtuelni interfejs kroz `uvm_config_db` u `build_phase`, pokreće sekvence u `main_phase`/`run_phase` (npr. sekvenca: upiši dimenzije → upiši sliku/šablon preko AXI-Full → postavi `start` bit preko AXI-Lite → čekaj `busy`/`done_sticky` u REG_STATUS → pročitaj rezultat sa ADDR_RESULTS ili S01 +0x10000).
- **Konfiguracioni objekat (`ncc_config`)** treba da nosi informaciju: da li se koristi 1 ili 2 instance `ncc_accel` (sistem ima 2×), koje su bazne adrese svake instance u adresnom prostoru Zynq PS7, da li je agent aktivan/pasivan.
- **Xcelium i XSim pokretanje** — direktno primenjivo na FVH korak 7 (10 poena): koristiti isti `.f` obrazac (`v5_run.f`) za listu VHDL DUT fajlova (`ncc_pkg.vhd`, `ncc_core.vhd`, `dp_bram.vhd`, `mem_subsystem.vhd`, oba AXI slave fajla, `ncc_accel.vhd`) + SV verif fajlova za Xcelium, i paralelno podesiti Vivado projekat sa `-L uvm` opcijama za XSim.
- Postojeći VHDL testbenchevi (`ncc_core_tb`, `ncc_accel_tb`, `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb`) su odličan izvor referentnih vrednosti/zlatnih rezultata za scoreboard (vežba 6+), a `ncc_accel_wfirst_tb`/`ncc_accel_s01_burst_wfirst_tb` direktno pokrivaju poznati AW/W redosled bug — te scenarije vredi preneti kao usmerene (directed) UVM sekvence pored randomizovanih.

Vidi i [[Vezba 04 - Randomizacija i ogranicenja u SystemVerilogu]] (transakcije koje sekvenceri generišu) i [[Predavanje 04 - Kreiranje verifikacionog okruzenja]] (širi kontekst HDL vs. HVL testbenčeva).
