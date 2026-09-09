---
tags: [fvh, vezba]
---

# Vezba 10 - Razvoj scoreboard komponente

## Ključni koncepti

- **Podela verifikacionih okruženja po načinu provere rezultata:**
  - **"Zlatni vektori"** ("golden vectors") — unapred definisan skup parova (ulazna komponenta, očekivani izlaz), učitan iz datoteke pre simulacije. Testbench uzima jedan po jedan vektor, dovodi ulaz, poredi izlaz DUT-a sa očekivanim. Nedostatak: ručno kreiranje skupa vektora je sporo i podložno greškama.
  - **Referentni modeli** — model DUT-a napisan na visokom nivou apstrakcije unutar testbench-a; obrađuje isti ulazni stimulus paralelno sa DUT-om, izlazi se porede. Dve podvrste:
    - **Transakcioni ("transaction level") referentni modeli** — modeluju ponašanje do nivoa transakcije (rezultat obrade), ignorišu tajming/broj taktova. Ovo je dominantan pristup u UVM-u i obično se implementira unutar **scoreboard**-a (naziva se i **predictor**).
    - **Referentni modeli precizni na nivou ciklusa ("cycle accurate")** — modeluju ponašanje do svakog takta; korisni kad plan zahteva proveru tačnog tajminga izlaza. Upozorenje iz predavanja: referentni model NE SME slepo replicirati implementaciju samog dizajna (inače gubi vrednost kao nezavisna provera).
- **Scoreboard** (`uvm_scoreboard`) — komponenta u `uvm_environment` koja radi predikciju i evaluaciju; NIJE direktno povezana sa DUT-om (nema pristup interfejsu), sve dobija preko TLM konekcija sa monitorima. Dobra praksa: razdvojiti **predictor** (referentni model) od **evaluator**-a (poređenje/izveštavanje) radi fleksibilnosti i ponovne upotrebe (vidi `Slika 1` iz vežbe).
- **Struktura scoreboard-a:**
  - Nasleđuje `uvm_scoreboard`.
  - Prima transakcije preko `uvm_analysis_imp#(TR_TYPE, scoreboard_type) item_collected_imp` — `write()` metoda se automatski poziva kad monitor uradi `analysis_port.write(tr)`.
  - Za više ulaznih TLM konekcija (npr. jedan monitor za poslate, jedan za primljene transakcije) koristi se `` `uvm_analysis_imp_decl(_suffix) `` makro koji generiše zasebne `write_<suffix>()` metode (`uvm_analysis_imp_1#(...)`, `uvm_analysis_imp_2#(...)`).
  - Povezivanje sa monitorima se radi u `environment` klasi: `agent1.mon1.item_collected_port.connect(scbd.port_1);`
- **Provere (checks)** — implementiraju se preko `assert` (immediate assertion) naredbi umesto `if/else`:
  ```
  assertion_label : assert (expression)
    // pass block
  else
    // fail block (uvm_error/uvm_info)
  ```
  Labela na `assert` omogućava direktnu vezu sa redom u verifikacionom planu (dokumentacija + trasabilnost).
- **Verifikacioni plan** — kreira se na osnovu funkcionalne specifikacije, sadrži: nivoe verifikacije, funkcionalnosti za proveru, opis testova/metoda, plan za coverage, test scenarije, alate, rizike, resurse, raspored. Svaka funkcionalnost u planu mora imati implementiran ček (assert) ili test koji je pokriva — veza se dokumentuje tabelom (Group / Feature / Description / Checker type / Checker name / Test / Pass-Fail).

## Kod / primeri

```systemverilog
class calc_scoreboard extends uvm_scoreboard;
  bit checks_enable = 1;
  bit coverage_enable = 1;
  uvm_analysis_imp#(calc_seq_item, calc_scoreboard) item_collected_imp;
  int num_of_tr;
  `uvm_component_utils_begin(calc_scoreboard)
    `uvm_field_int(checks_enable, UVM_DEFAULT)
    `uvm_field_int(coverage_enable, UVM_DEFAULT)
  `uvm_component_utils_end

  function new(string name = "calc_scoreboard", uvm_component parent = null);
    super.new(name,parent);
    item_collected_imp = new("item_collected_imp", this);
  endfunction

  function void write(calc_seq_item tr);
    calc_seq_item tr_clone;
    $cast(tr_clone, tr.clone());
    if (checks_enable) begin
      // do actual checking here
      // ++num_of_tr;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Calc scoreboard examined: %0d transactions", num_of_tr), UVM_LOW);
  endfunction
endclass
```
Osnovni skelet: `write()` je jedina ulazna tačka za transakcije, `report_phase` daje sumarni izveštaj na kraju testa (broj proverenih transakcija — koristan pokazatelj da scoreboard uopšte "radi", tj. da nije 0 zbog loše konekcije).

```systemverilog
// dve nezavisne TLM konekcije (npr. "expected" i "actual" tok)
`uvm_analysis_imp_decl(_rcvd_pkt)
`uvm_analysis_imp_decl(_sent_pkt)
class Scoreboard extends uvm_scoreboard;
  Packet exp_que[$];
  uvm_analysis_imp_rcvd_pkt#(Packet,Scoreboard) Rcvr2Sb_port;
  uvm_analysis_imp_sent_pkt#(Packet,Scoreboard) Drvr2Sb_port;

  function void write_rcvd_pkt(input Packet pkt);
    Packet exp_pkt;
    asrt_exp_queue_not_empty : assert (exp_que.size()) begin
      exp_pkt = exp_que.pop_front();
      asrt_pkt_compare : assert (pkt.compare(exp_pkt))
        `uvm_info(get_type_name(), "Sent packet and received packet matched", UVM_MEDIUM);
      else
        `uvm_error(get_type_name(), "Sent packet and received packet mismatched");
    end
    else
      `uvm_error(get_type_name(), "No more packets to in the queue to compare");
  endfunction : write_rcvd_pkt

  function void write_sent_pkt(input Packet pkt);
    exp_que.push_back(pkt);
  endfunction
endclass
```
Ovo je referentni obrazac **queue-based scoreboard-a**: "sent" strana puni red očekivanih paketa (predictor), "rcvd" strana pop-uje i poredi (evaluator) — direktno primenjivo na out-of-order ili FIFO tipa provere.

## Primena na NCC akcelerator projekat

**Scoreboard za `ncc_accel`** treba dizajnirati kao transakcioni (transaction-level) referentni model + end-of-test/real-time poređenje, sa dva ulazna TLM porta (analogno `Rcvr2Sb_port`/`Drvr2Sb_port` iz primera):

1. **Predictor (referentni model)** — implementira C/C++ ili SystemVerilog model NCC² algoritma. Postoji već gotov zlatni model u `C:\Users\pc\Desktop\PSDS\src\hls\ncc_kernel.cpp` (HLS kernel korišćen u prethodnom kursu) i dodatno u VHDL testbench-evima:
   - `ncc_core_tb` — mali golden 4x4/2x2 slučaj, dobar za smoke-test scoreboard logike.
   - `ncc_core_real_tb` — realna 90x90 slika, sa poznatim očekivanim rezultatom **peak NCC² = 0x80000000** na poznatoj poziciji (u,v) — ovo je idealan "zlatni vektor" (golden vector po terminologiji iz vežbe) za directed test scoreboard-a bez potrebe za punim C referentnim modelom.
   - Pošto je NCC² transakciona operacija (jedan poziv "start" → jedan skup rezultata, bez potrebe modelovanja svakog takta FSM-a od 23 stanja), transakcioni referentni model je dovoljan — cycle-accurate model FSM-a NIJE potreban za funkcionalnu proveru rezultata (samo bi ga bespotrebno komplikovao, kršeći pravilo "ne repliciraj implementaciju dizajna").

2. **TLM konekcije scoreboard-a** (koristeći `uvm_analysis_imp_decl`):
   - `write_stim(axil_stim_tr)` / `write_mem_stim(axif_mem_tr)` — od `axil_monitor`-a i `axif_monitor`-a (vežba 9), scoreboard hvata upisane img/tmp dimenzije (REG_IMG_W/H, REG_TMP_W/H) i sadržaj memorije (upisane piksele preko AXI-Full), gradi ulaz za predictor.
   - `write_result(axif_result_tr)` — od istog `axif_monitor`-a, kad testbench pročita rezultate iz `+0x10000` regiona (`ADDR_RESULTS` na AXI-Lite daje bazu, stvarni podaci su na AXI-Full), scoreboard poziva predictor da izračuna očekivan NCC² i **poredi** (assert) sa observirano pročitanim rezultatom.
   - Trigering poređenja se dešava kad monitor detektuje `REG_STATUS.done_sticky == 1` (real-time provera, po uzoru na "provera u realnom vremenu" iz predavanja — čim transakcija (jedan NCC obračun) završi, odmah se poredi, bez čekanja kraja test case-a).

3. **Konkretne assert provere** (mapirane na verifikacioni plan, kolona "Checker name"):
   ```systemverilog
   asrt_ncc_peak_match : assert (result_read == exp_ncc_value)
     `uvm_info(get_type_name(), "NCC rezultat se poklapa sa referentnim modelom", UVM_MEDIUM)
   else
     `uvm_error(get_type_name(), $sformatf("NCC mismatch: exp=%0h obs=%0h @ addr=%0h", exp_ncc_value, result_read, addr));
   ```
   - `asrt_status_busy_done_consistency` — busy=0 mora povlačiti done_sticky pre čitanja rezultata (status register FSM konzistentnost).
   - `asrt_axi_ordering_no_hang` — regresija za poznati fiksovan bug (W pre AW na S00/S01): scoreboard/monitor beleži da transakcija završava u ograničenom broju taktova bez hang-a.

4. **Verifikacioni plan** (Vežba 10, poglavlje 3) treba popuniti tabelom tipa Group/Feature/Checker za NCC projekat, npr: Grupa "osnovna funkcionalnost" → Feature "NCC izračunavanje 90x90" → Checker `asrt_ncc_peak_match` → Test `test_ncc_real_image` → status Pass/Fail — ovo direktno pokriva FVH zahtev za dokumentovan verifikacioni plan povezan sa proverama u kodu (grading stavka 2 i 4).
