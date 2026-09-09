---
tags: [fvh, vezba]
---

# Vežba 06-07 — Rad sa sekvencama i razvoj drajvera

Izvor: `vezba6-1.pdf` (obuhvata vežbe 6 i 7) + kod iz `dodatno/vezba6_7.zip` (calc_if, calc_sequencer, calc_driver, calc_seq_item, calc_base_seq, calc_simple_seq, test_base, test_simple, test_simple_2, calc_verif_top).

## Ključni koncepti

- **Sequence item** (`uvm_sequence_item`) — transakcija/stimulus. Polja se dele na: kontrolna (tip transfera, veličina), payload (podaci nad kojima se izvršava operacija), konfiguraciona (ponašanje pri greškama), polja za analizu (npr. vreme). Sva polja koja učestvuju u randomizaciji su `rand`, registruju se preko `` `uvm_object_utils_begin/end`` i `` `uvm_field_* `` makroa (omogućava `print/copy/compare`).
- **Sequence** (`uvm_sequence#(SEQ_ITEM)`) — objekat (nije komponenta), sadrži logiku generisanja stimulusa u `body()` tasku. `pre_body()`/`post_body()` se koriste za podizanje/spuštanje `objection`-a (`phase.raise_objection`/`drop_objection`), i to samo ako je sekvenca pokrenuta kao *default* sekvenca (`starting_phase != null`). Bazna sekvenca deklariše sekvencer makroom `` `uvm_declare_p_sequencer(TIP_SEKVENCERA)``.
- **Generisanje transakcije — 5 koraka**: 1) `create()` (factory), 2) `start_item(req)` (blokirajuće, čeka sekvencer), 3) `req.randomize()` (opciono, uz inline ograničenja), 4) `finish_item(req)` (blokirajuće, čeka da drajver završi — `start_item`/`finish_item` ne troše simulaciono vreme), 5) opciono `get_response()`.
- **Makroi**: `` `uvm_do(req) `` (kreiranje+randomizacija+slanje u jednom pozivu), `` `uvm_do_with(req, {constraint}) `` (isto, uz inline ograničenje, npr. `req.data == 16'h5A5A`). "UVM Cookbook" preporučuje ručno pisanje 5 koraka umesto makroa radi kontrole, ali makroi su česti u praksi.
- **Kontrola broja transakcija**: `rand int unsigned num_of_tr; constraint {num_of_tr inside {[1:100]};}` pa `repeat(num_of_tr) `uvm_do(req);`. Sekvence se mogu ugnježđavati (`uvm_do(sub_seq)`).
- **Pokretanje sekvence**: eksplicitno iz testa preko `seq.start(seqr)` (preporučeno, daje kontrolu nad tajmingom), ili implicitno kao *default sequence* preko `uvm_config_db#(uvm_object_wrapper)::set(this, "seqr.main_phase", "default_sequence", seq_type::type_id::get())`.
- **Sekvencer** (`uvm_sequencer#(SEQ_ITEM)`) — arbitrira između više sekvenci; u praksi se retko modifikuje, samo se parametrizuje ili `typedef`-uje.
- **Drajver** (`uvm_driver#(REQ,RSP)`) — aktivna komponenta, jedina koja pristupa `virtual interface`-u (dobija ga preko `uvm_config_db` u `connect_phase`, uz `` `uvm_fatal("NOIF", ...) `` ako nije setovan). Prevodi transakciju u pin-nivo signale.
- **Drajver–sekvencer API**: `get_next_item(req)` (blokira, dohvata sledeći REQ), `try_next_item(req)` (neblokirajuće), `item_done()` (obavezno posle `get_next_item`/`try_next_item`, može poneti RSP), `peek()`/`get()`/`put()` (alternativni get/put mehanizam, obrađen u Vežbi 8). Standardni `run_phase`/`main_phase` obrazac drajvera: `forever begin seq_item_port.get_next_item(req); drive_tr(); seq_item_port.item_done(); end`.
- **4 modela drajvera** (UVM Cookbook, "Driver/Use Models"): Unidirectional Non-Pipelined (jednosmeran, npr. PCM), Bidirectional Non-Pipelined (zahtev pa odgovor, jedna transakcija odjednom, npr. APB), Pipelined (zahtevi i odgovori se preklapaju, npr. AHB), Out-of-Order Pipelined (odgovori ne prate redosled zahteva, potreban red za praćenje odgovora, npr. AXI burst transferi).
- **Mehanizam završetka testa**: `objection` (`raise_objection`/`drop_objection`) — svaka faza koja troši vreme čeka da se svi podignuti prigovori spuste. Kontrola iz testa (`main_phase`: `raise_objection` → `seq.start(seqr)` → `drop_objection`) ili iz sekvence (`pre_body`/`post_body`). `uvm_test_done.set_drain_time(this, 200ns)` dodaje toleranciju posle poslednjeg `drop_objection` (za slučaj da se test još nešto naknadno pokrene).
- **Organizacija fajlova**: svaki direktorijum ima svoj SystemVerilog `package` koji `` `include``-uje sve fajlove iz tog direktorijuma (osim top fajla) i `import`-uje pakete iz drugih direktorijuma koje koristi. Redosled `include`/`import` je bitan (npr. `test_pkg` mora prvo `import`-ovati `agent_pkg`/`seq_pkg` pre `include test_base.sv`, jer `test_base` instancira drajver/sekvencer). Za Xcelium se koristi `.f` fajl sa `-uvmhome`, `-sv +incdir+...`, listom DUT/verif fajlova; za Vivado se svi fajlovi (dizajn + verif paketi + top) dodaju u projekat sa "Simulation only" flag-om na verif fajlovima.

## Kod / primeri

```systemverilog
// calc_seq_item.sv — bazni sequence item (skelet iz materijala)
class calc_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(calc_seq_item)
  `uvm_object_utils_end
  function new (string name = "calc_seq_item");
    super.new(name);
  endfunction
endclass
```
Ovaj skelet u NCC projektu treba proširiti poljima kao `bit[31:0] addr`, `bit[31:0] wdata`, `bit is_write`, `bit aw_first` (za W/AW ordering) itd.

```systemverilog
// calc_base_seq.sv — objection u pre_body/post_body
virtual task pre_body();
  uvm_phase phase = get_starting_phase();
  if (phase != null)
    phase.raise_objection(this, {"Running sequence '", get_full_name(), "'"});
endtask
```
Isti obrazac se koristi za AXI-Lite start-sekvencu na `ncc_accel`.

```systemverilog
// primer uvm_do_with (iz PDF-a vežbe)
`uvm_do_with(req, { req.data == 16'h5A5A; })
```
Direktan analog: `` `uvm_do_with(req, { req.addr == ADDR_REG_CTRL; req.wdata[0] == 1; }) `` za pisanje start bita.

## Primena na NCC akcelerator projekat

- **calc_seq_item → axi_lite_item / axi_full_item**: dva odvojena tipa `sequence_item`-a, jedan za AXI4-Lite (S00, registri REG_IMG_W/H, REG_TMP_W/H, REG_IMG_ADDR, REG_TMP_ADDR, REG_CTRL, REG_STATUS, ADDR_RESULTS), drugi za AXI4-Full (S01, memorijski prostor 128KB: image @+0x00000, template @+0x08000, results @+0x10000). Polja: `bit[31:0] addr`, `bit[31:0] wdata`, `bit is_write`, `bit[3:0] wstrb`, i za S01 dodatno `int burst_len` za burst transfere.
- **Sekvence za AXI-Lite konfiguraciju**: `ncc_config_seq` koja preko `` `uvm_do_with `` piše REG_IMG_W/H i REG_TMP_W/H sa randomizovanim, ali *legalnim* dimenzijama (constraint npr. `img_w inside {[8:640]}`, `tmp_w <= img_w` itd. — na osnovu poznatih ograničenja NCC datapatha), zatim REG_IMG_ADDR/REG_TMP_ADDR, pa REG_CTRL sa bit0=1 (start pulse).
- **Directed test za poznati HW bug (AW/W ordering)**: pošto je poznato da je AXI write hendlovanje na S00 i S01 ranije "vešalo" DUT kad W stigne pre AW, napraviti tri varijante sekvence preko polja `aw_first` u sequence item-u ili preko tri odvojene sekvence (`seq_aw_first`, `seq_w_first`, `seq_simultaneous`), koje u `body()` tasku eksplicitno kontrolišu redosled slanja AW/W kanala u drajveru (drajver treba da ume da ih razdvoji — model "Pipelined"/"Out of Order" iz Sekcije 5.1, jer AXI generalno nije striktno Bidirectional Non-Pipelined). Ovo je odličan kandidat za directed regression test koji dokumentuje fiksovani bug.
- **Kontrola broja transakcija za regresiju**: `rand int num_of_starts; constraint {num_of_starts inside {[1:5]};}` u sekvenci koja više puta pokreće ceo NCC ciklus (write config → pulse start → poll REG_STATUS.busy/done_sticky → read ADDR_RESULTS) — direktan analog `calc_simple_seq` sa `repeat(num_of_tr) `uvm_do(req);` iz vežbe.
- **Drajver model za S00 (AXI4-Lite)**: koristiti Bidirectional Non-Pipelined model (kao APB primer iz materijala) jer AXI-Lite praktično ne pajplajnuje — jedan write/read handshake u toku.
- **Drajver model za S01 (AXI4-Full, burst)**: koristiti Pipelined ili Out-of-Order model, pošto postoje burst testbench-evi (`ncc_accel_burst_tb`, `ncc_accel_s01_burst_wfirst_tb`) koji sugerišu da S01 podržava burst transfere preko `axi_interconnect`-a — drajver treba internim redom (queue) da prati koji AR/AW je u letu.
- **Objection/drain time**: pošto `ncc_core` FSM ima 23 stanja i sadrži `seq_divider` (sekvencijalni delilac, višetaktna operacija), test mora koristiti `set_drain_time` (npr. 500ns-1us u zavisnosti od takta 90.909 MHz) da obezbedi da se poslednji NCC² proračun završi pre nego što se test prevremeno završi — analogno `#100ns` čekanju u `test_simple` iz materijala, samo realističnije skalirano na trajanje FSM-a i `seq_divider`-a.
- **test_base za NCC**: po uzoru na `test_base extends uvm_test` (koji instancira `calc_driver drv; calc_sequencer seqr;` i u `connect_phase` radi `drv.seq_item_port.connect(seqr.seq_item_export)`), napraviti `ncc_test_base` koji instancira dva agenta (AXI-Lite agent i AXI-Full agent) — jer NCC ima dva odvojena AXI slave interfejsa koja treba nezavisno stimulisati/pratiti.

[[Vezba 08 - Monitor]] | [[Predavanje 06-07 - Strategije za generisanje stimulusa]]
