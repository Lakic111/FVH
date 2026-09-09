---
tags: [fvh, vezba]
---

# Vežba 2 - Objektno orijentisani aspekti SystemVerilog jezika

## Ključni koncepti

- **Nizovi**: fiksne veličine (`int example[8]` ili `[0:7]`), *packed* (`bit [7:0] x` — kontinualan niz bita, ponaša se i kao jedna vrednost) vs *unpacked* (`bit x[8]` — svaki element zaseban, moguće kombinovati packed+unpacked dimenzije, npr. `bit [2:0][7:0] mix[4]`).
- **Dinamički nizovi** (`int dyn[]`) — veličina se određuje u runtime-u pozivom `new[N]`; metode `size()`, `delete()`.
- **Asocijativni nizovi** (`int arr[tip_indeksa]` ili `arr[*]`) — sparse lookup tabela, indeks proizvoljnog tipa (int, string, klasa). Metode: `num()`, `exists()`, `delete()`, `first()/last()/next()/prev()`. Idealno za retko popunjene adresne prostore (npr. memorijski model).
- **Redovi (queue)** `tip niz[$]` — kombinacija dinamičkog niza i povezane liste: brz pristup po indeksu I brzo dodavanje/uklanjanje na krajevima. Ključne metode: `push_front/back()`, `pop_front/back()`, `insert(idx,val)`, `delete(idx)`. **Ovo je standardna struktura za driver/monitor/scoreboard fifo-e** u verifikacionim okruženjima.
- Generičke **metode nad nizovima/redovima**: lokacijske (`find`, `find_index`, `min`, `max`, `unique` — zahtevaju `with()` klauzu za predikat), uređivačke (`sort`, `rsort`, `reverse`, `shuffle`), redukcione (`sum`, `product`, `and`, `or`, `xor`).
- **Kastovanje**: statički (`int'(2.5+2.3)`, compile-time, bez provere granica) vs dinamički `$cast(dest, src)` (runtime provera validnosti; kao funkcija vraća 0/1, kao task diže runtime error pri neuspehu).
- **OOP terminologija**: Class (tip), Object (instanca), Handle (pokazivač na objekat — nema aritmetiku kao C pointer), Property (polje), Method (funkcija/task u klasi). Objekat se kreira isključivo pozivom `new()`.
- **Konstruktor** (`function new(...)`) — jedan po klasi (za razliku od C++ preopterećivanja), podržava default argumente.
- **Static** polja/metode — deljeni po svim instancama klase; statične metode ne mogu pristupati ne-statičkim poljima niti biti virtualne.
- **Enkapsulacija**: `public` (default), `local` (kao C++ `private`), `protected`. U verifikacionim okruženjima se enkapsulacija retko strogo koristi — polja su najčešće `public` radi lakšeg debagovanja i pristupa iz testova.
- **Nasleđivanje** (`extends`), redefinisanje metoda (override), `super.metoda()` za poziv roditeljske implementacije, `super.new(...)` mora biti prva linija child konstruktora ako parent konstruktor ima argumente.
- **Interfejs** (`interface ... endinterface`) — objedinjuje sve signale/portove koji povezuju DUT i testbench na jednom mestu; instancira se jednom u top modulu, a handle se prosleđuje svim komponentama (driver, monitor...) kojima je potreban pristup DUT signalima.
- **Package** — grupiše klase/tipove/funkcije korišćene na više mesta; pristup preko `::` (scope resolution) ili `import pkg::*`.

## Kod / primeri

Kompletan mini-testbench iz priloženog materijala (`vezba2`), koji već ima strukturu tipičnu za UVM-stil okruženje (transaction/driver/interface/package/top), samo bez `uvm_*` baznih klasa:

**Transakcija sa nasleđivanjem** (`v2_tr.sv`):
```systemverilog
class transaction;
   bit [1:0] addr; bit [7:0] data_i;
   function void display_transaction();
      $display("\taddr = %0h\n\tdata_i = %0h", addr, data_i);
   endfunction
endclass

class newTransaction extends transaction;
   bit [7:0] data_o; bit rw; bit en;
   function void display_transaction();
      super.display_transaction();
      $display("\tdata_o=%0h rw=%0h en=%0h", data_o, rw, en);
   endfunction
endclass
```

**Interfejs** (`v2_memory_if.sv`) i **driver** koji koristi `virtual interface` handle (`v2_driver.sv`):
```systemverilog
interface memory_if(input clk, input rst);
   logic [1:0] addr; logic rw, en;
   logic [7:0] data_i, data_o;
endinterface

class driver;
   virtual memory_if mem_if;
   function new(virtual memory_if mem_if); this.mem_if = mem_if; endfunction
   task drive_transaction(newTransaction tr);
      @(posedge mem_if.clk);
      mem_if.addr <= tr.addr; mem_if.data_i <= tr.data_i;
      mem_if.en <= tr.en;     mem_if.rw <= tr.rw;
   endtask
endclass
```

**Package** grupiše klase (`v2_memory_pkg.sv`):
```systemverilog
package memory_pkg;
 `include "v2_tr.sv"
 `include "v2_driver.sv"
endpackage
```

**Top** povezuje interfejs, DUT i driver preko `import`:
```systemverilog
module top;
   import memory_pkg::*;
   memory_if mem_if(clk, rst);
   memory DUT (.clk(clk), .rst(rst), .addr_i(mem_if.addr), ...);
   driver drv = new(mem_if);
   initial drv.run();
endmodule
```

Red (queue) operacije, korisno za FIFO modele buffera:
```systemverilog
int q1[$] = {2, 4, 8};
q1 = {q1, 10};        // push_back ekvivalent
q1 = {3, q1};          // push_front ekvivalent
q2.push_back(10); q2.push_front(3); q2.insert(idx, 5);
y = q2.pop_front();
```

## Primena na NCC akcelerator projekat

- Ovaj primer je gotovo doslovan template za buduće UVM komponente: `transaction`/`newTransaction` → **`ncc_seq_item`** (transakcija sa poljima `addr`, `data`, `rw` — mapirano na AXI-Lite registre 0x00-0x40 ili AXI-Full memorijski prostor); `memory_if` → **`axi_lite_if`** i **`axi_full_if`** (dva odvojena interfejsa jer DUT ima dve zasebne AXI magistrale — S00 Lite kontrolni i S01 Full memorijski); `driver` → **`ncc_driver`** koji na `drive_transaction` generiše AXI write/read handshake (AW/W/B ili AR/R kanali) umesto prostog `@(posedge clk)`.
- **Nasleđivanje** treba iskoristiti za dva tipa transakcija: `ncc_lite_transaction` (upis/čitanje kontrolnih registara REG_IMG_W...REG_CTRL) i `ncc_full_transaction` (burst upis/čitanje slika/šablona/rezultata na offsetima 0x00000/0x08000/0x10000), obe naslеđene iz zajedničke `ncc_base_transaction` — analogno `transaction`→`newTransaction` primeru.
- **Redovi (queue)** su prirodna struktura za: (1) monitor koji hvata AXI transakcije sa oba interfejsa i stavlja ih u red za scoreboard (`push_back`), (2) scoreboard koji čuva očekivane rezultate NCC² proračuna dok čeka da se pojave na AXI-Full rezultat regionu (0x10000), (3) model interne memorije `mem_subsystem.vhd` (image/template/rezultati) za self-checking poređenje.
- **Asocijativni niz** pogodan je za model registara AXI-Lite (indeksiran adresom, npr. `bit[31:0] reg_model[bit[7:0]]`) koji prati očekivano stanje REG_STATUS (bit0=done_sticky, bit1=busy) i proverava ga nakon svakog `start` (bit0 u REG_CTRL).
- `interface`+`package` kombinacija direktno odgovara UVM `agent`/`env` strukturi: jedan `package` (`ncc_pkg_tb.sv`) grupiše sve `ncc_*` klase (driver, monitor, sequencer, scoreboard, environment, test), a dva zasebna SV interfejsa (`axi_lite_if`, `axi_full_if`) instanciraju se jednom u top-level testbenchu i prosleđuju kroz config/virtual sequencer svim agentima — ovo direktno rešava zahtev "osnovne komponente: driver(i), sequencer(i), monitor" iz specifikacije ocenjivanja.
- Poznati bag (AW pre W vs W pre AW hang na oba AXI slave-a) je idealan kandidat za directed test izgrađen upravo pomoću drivera koji eksplicitno kontroliše redosled slanja AW/W (ili AR/R) transakcija — slično kako `drive_transaction` ovde eksplicitno diktira redosled `addr`/`data_i`/`en`/`rw` na interfejsu.
