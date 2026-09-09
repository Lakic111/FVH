---
tags: [fvh, vezba]
---

# Vežba 08 — Razvoj monitora

Izvor: `vezba8-1.pdf` + kod iz `dodatno/vezba8-1.zip` (calc_monitor.sv, ostatak identičan skeletu iz vežbe 6/7 — calc_if, calc_sequencer, calc_driver, calc_seq_item, sekvence, testovi).

## Ključni koncepti

- **TLM (Transaction Level Modeling)**: UVM koristi TLM-1/TLM-2.0 interfejse (poreklo iz SystemC-a) za komunikaciju na nivou transakcija umesto signala — omogućava izolaciju komponenti (promene u okruženju ne utiču na komponentu dok interfejs ostaje isti) i laku ponovnu upotrebu/zamenu komponenti.
- **Tipična TLM topologija**: monitor je *izvor* (jedan-ka-više / one-to-many broadcast) transakcija ka scoreboard-u, coverage collector-u itd.
- **`uvm_analysis_port#(T)`** — neblokirajući broadcast port; sadrži jednu funkciju `write(T t)` čiju implementaciju daje komponenta primalac. Deklariše se, kreira u konstruktoru (`ap = new("ap", this)`), poziva se `ap.write(t)` u monitoru. Povezivanje: `mon.ap.connect(sb.ap)` u `connect_phase` roditeljske komponente (agent/env); moguće je povezati isti port na više primalaca: `mon.ap.connect(sb1.ap); mon.ap.connect(sb2.ap);`.
- **`uvm_analysis_imp`** — implementacija write funkcije na strani primaoca (npr. scoreboard nasleđuje `uvm_scoreboard` i sadrži `uvm_analysis_imp#(trans, scbd) ap`). Kada jedna komponenta treba da prima transakcije iz više izvora, koristi se makro `` `uvm_analysis_imp_decl(_ime) `` koji generiše zaseban `uvm_analysis_imp<ime>` tip i odgovarajuću `write<ime>()` funkciju (npr. `` `uvm_analysis_imp_decl(_in)`` i `` `uvm_analysis_imp_decl(_out)`` → `write_in()`/`write_out()`), čime se jasno razdvaja koji `write` odgovara kom portu (`mon1.ap.connect(sb.port_in); mon2.ap.connect(sb.port_out);`).
- **Monitor — struktura**: pasivna komponenta (`extends uvm_monitor`), sadrži `virtual interface` (preuzet u `connect_phase` preko `uvm_config_db`, uz `` `uvm_fatal("NOVIF", ...) `` ako nije setovan), `uvm_analysis_port#(seq_item) item_collected_port`, i kontrolna polja `bit checks_enable = 1; bit coverage_enable = 1;` (registrovana preko `` `uvm_field_int``) da bi se moglo selektivno isključiti čekiranje/coverage radi brzine simulacije (kontroliše se preko `uvm_config_db#(int)::set(this, "*.monitor", "checks_enable", 0)`).
- **Monitor — funkcionalnost**: monitor mora poznavati protokol (implementira ga kao FSM koja prati signale preko virtuelnog interfejsa u `run`/`main_phase` beskonačnoj petlji), detektuje transakciju, popunjava objekat transakcije i šalje ga preko `item_collected_port.write(...)`. Dva načina da se izbegne "prebrisavanje" vrednosti u narednoj iteraciji petlje: (1) kreirati **novi objekat** svaki prolaz petlje, (2) koristiti isti objekat ali **klonirati pre write-a** (`$cast(trans_clone, trans_collected.clone()); item_collected_port.write(trans_clone);`).
- **Razlika drajver vs. monitor**: monitor je uvek pasivan (samo posmatra signale, nikad ih ne generiše) — ovo mora ostati striktno odvojeno čak i kad se logika delimično preklapa s drajverom.
- **Implementacija čekera — immediate assertions**: preporučeni način pisanja čekera u monitoru je proceduralni kod sa `assert` naredbama (immediate, ne concurrent — concurrent assertion-i su van obima kursa). Sintaksa: `label: assert(expression) pass_block; else fail_block;`. Dobra praksa: labela (prefiks/sufiks `asrt`) i `` `uvm_error `` poruka u `fail` bloku koja objašnjava šta nije prošlo:
```systemverilog
asrt_a_eq_b : assert (A == B)
  `uvm_info(get_type_name(), "Check succesfull: A == B", UVM_HIGH)
else
  `uvm_error(get_type_name(), $sformatf("Observed A and B mismatch: A = %0d, B = %0d", A, B))
```
- **Zadatak iz materijala**: implementirati monitor za "Calc1" dizajn (analogija zadatku koji student sada radi za NCC).

## Kod / primeri

```systemverilog
// Main faza APB monitora (obrazac primenjiv na AXI-Lite/AXI-Full monitor)
task main_phase(uvm_phase phase);
  apb_transfer trans_collected, trans_clone;
  trans_collected = apb_transfer::type_id::create("trans_collected");
  forever begin
    @(posedge vif.pclock iff (vif.psel != 0));
    trans_collected.addr = vif.paddr;
    case (vif.prwd)
      1'b0 : trans_collected.direction = APB_READ;
      1'b1 : trans_collected.direction = APB_WRITE;
    endcase
    @(posedge vif.pclock);
    if (trans_collected.direction == APB_READ)  trans_collected.data = vif.prdata;
    if (trans_collected.direction == APB_WRITE) trans_collected.data = vif.pwdata;
    @(posedge vif.pclock);
    if (trans_collected.direction == APB_READ) begin
      if (vif.pready != 1'b1) @(posedge vif.pclock);
      trans_collected.data = vif.prdata;
    end
    $cast(trans_clone, trans_collected.clone());
    item_collected_port.write(trans_clone);
  end
endtask
```
Ovo je direktan predložak za AXI4-Lite monitor na S00: umesto `psel/prwd/pwdata/prdata/pready`, prati se `AWVALID/AWREADY/WVALID/WREADY/ARVALID/RVALID` FSM na `ncc_accel_slave_lite_v1_0_S00_AXI`.

## Primena na NCC akcelerator projekat

- **Dva odvojena monitora**: `ncc_axi_lite_monitor` (prati S00 — sekvencu AW/W/B ili AR/R kanala, dekodira adresu u simbolička imena registara REG_IMG_W/REG_IMG_H/.../REG_CTRL/REG_STATUS/ADDR_RESULTS) i `ncc_axi_full_monitor` (prati S01 — burst čitanja/pisanja u regione image @0x00000/template @0x08000/results @0x10000, uz praćenje `AWLEN`/`ARLEN` za burst dužinu).
- **FSM u monitoru mora modelovati AXI handshake** (VALID/READY na svakom kanalu) analogno APB primeru — čeka `@(posedge ACLK iff (AWVALID && AWREADY))` za snimanje adrese pisanja, pa odvojeno `@(posedge ACLK iff (WVALID && WREADY))` za podatak, jer S00/S01 imaju upravo poznati bug kad W stigne pre AW — monitor treba da bude sposoban da ispravno poveže W sa odgovarajućim AW nezavisno od redosleda (koristiti privremeni red/FIFO za nezavršene AW dok WVALID ne stigne, umesto pretpostavke da AW uvek prethodi W).
- **checks_enable za self-checking na nivou monitora**: implementirati immediate assertion koja proverava da je `REG_STATUS.busy` postavljen nakon writa u REG_CTRL.start i da `done_sticky` ostaje 1 dok se eksplicitno ne pročita/resetuje (ako HW tako radi) — npr. `asrt_busy_after_start: assert(status_busy_seen_within_N_cycles) else `uvm_error(...)`.
- **Coverage hook (za Vežbu o pokrivenosti, buduća)**: `item_collected_port` iz oba monitora se šalje i ka scoreboard-u i ka coverage collector-u (broadcast, one-to-many) — npr. pokrivenost kombinacija (img_w, img_h, tmp_w, tmp_h) upisanih u registre, i pokrivenost AW/W ordering scenarija (aw_first/w_first/simultaneous) kao coverpoint.
- **Analiza konkretnog HW bug regresiono**: monitor na S01 mora eksplicitno detektovati i prijaviti (assert + `uvm_error`) slučaj da transakcija "visi" (npr. AWVALID visok N ciklusa bez AWREADY) — to je upravo simptom fiksovanog buga, pa monitor postaje watchdog za regresiju protiv ponovne pojave tog bug-a.
- **Analogija sa `ncc_core_tb`/`ncc_accel_tb` VHDL testbench-evima**: pošto ti testbench-evi već sadrže "zlatne" (golden) referentne vrednosti (npr. `ncc_core_real_tb` sa očekivanim pikom za 90x90 sliku), monitor na rezultatskom regionu (results @0x10000 na S01, ili čitanje preko ADDR_RESULTS na S00) treba da prosledi pročitane rezultate scoreboard-u koji ih poredi sa istim golden vrednostima — čime se VHDL referentni testbench-evi ponovo koriste kao izvor očekivanih podataka za UVM scoreboard, umesto da se ručno preračunavaju.

[[Vezba 06-07 - Sekvence i drajver]] | [[Predavanje 06-07 - Strategije za generisanje stimulusa]]
