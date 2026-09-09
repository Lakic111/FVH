---
tags: [fvh, vezba]
---

# Vežba 04 - Randomizacija i ograničenja (constraints) u SystemVerilogu

## Ključni koncepti

- **Ugrađene random funkcije**: `$urandom(seed)` (32-bit unsigned, stabilan za threadove, preporučen umesto `$random`), `$urandom_range(maxval, minval=0)`.
- **`rand` vs `randc`**: `rand` polja su uniformno raspoređena; `randc` (random-cyclic) prolazi kroz sve vrednosti opsega bez ponavljanja (permutacija), max širina 16 bita — koristan za npr. testiranje svih adresa registra bez ponavljanja pre nego što se sekvenca "resetuje".
- **`randomize()`** metoda nad objektom klase — randomizuje sva `rand`/`randc` polja; `randomize(polje1, polje2)` randomizuje samo navedena polja; **uvek proveravati povratnu vrednost** (`assert(obj.randomize())`), jer randomizacija može propasti (konfliktna ograničenja).
- **`pre_randomize()` / `post_randomize()`** — virtuelne metode koje se automatski pozivaju pre/posle `randomize()`; korisne za log/debug ili post-processing izračunatih polja.
- **`std::randomize()`** — randomizacija promenljivih van klase (scope-based), sa `with {}` ograničenjima; korisna kad ne želimo posebnu klasu samo za randomizaciju par lokalnih promenljivih.
- **`constraint` blokovi** — imenovani, nasledivi/redefinisivi članovi klase:
  - `inside {...}` — pripadnost skupu/opsegu vrednosti (uniformna verovatnoća svake vrednosti u skupu); `!(x inside {...})` za isključivanje opsega.
  - `dist` operator — težinska distribucija; `:=` dodeljuje težinu **svakoj** vrednosti u opsegu, `:/` **deli** težinu na broj elemenata u opsegu. Bitno za modelovanje realnih raspodela (npr. 90% validnih, 10% ivičnih vrednosti).
  - Uslovna ograničenja: implikacija `->` i `if..else` blok unutar `constraint`.
  - Iterativna ograničenja: `foreach` + `.size()` metoda za nizove/queue-ove (npr. ograničiti dužinu i svaki element posebno).
  - `with { }` in-line ograničenja pri pojedinačnom pozivu `randomize()`, dodatna na već postojeća class-level ograničenja; `local::` scope resolution operator kad se ime polja poklapa sa spoljnim identifikatorom.
  - **`solve ... before ...`** — kontroliše redosled rešavanja promenljivih i time menja *verovatnoću* odabira (ne prostor rešenja) — bitno kod implikacionih ograničenja gde bez `solve-before` neke kombinacije postaju praktično nedostižne (npr. verovatnoća 1/(2^32+1) umesto očekivanih 50%).
- **Kontrola random moda**: `constraint_mode(0/1)` uključuje/isključuje pojedinačno ograničenje ili sva (poziva se i nad objektom i nad `obj.ime_ogranicenja`); `rand_mode(0/1)` analogno za aktivnost `rand`/`randc` polja.
- **Provera zadovoljenosti bez randomizacije**: `randomize(null)` — tretira sva polja kao `nonrandom`, samo proverava da li trenutne vrednosti zadovoljavaju ograničenja (korisno posle ručne izmene polja).
- **Česte greške**: korišćenje više relacionih operatora u jednom izrazu (`5 < a < b` ≠ `5 < a; a < b`), `signed` wrap-around efekti, scope kolizije imena (rešava se sa `local::`).
- **Seed kontrola u simulatoru**: Xcelium — `xrun ... -svseed <broj|random>`; Vivado/XSim — u `xsim.simulate.xsim.more_options` upisati `-sv_seed <broj>`. Isti seed => reproduktibilna sekvenca (ključno za debug i regresiju); random seed treba uvek logovati.

## Kod / primeri

```systemverilog
class transaction;
  rand bit [1:0] addr;
  rand bit [7:0] data;
  constraint data_range { data > 'ha5; }
  constraint addr_range { addr == 0; }
endclass
```
Osnovna klasa sa poljima i ograničenjima — obrazac za sve buduće `sequence_item`/transaction klase u UVM okruženju.

```systemverilog
class implikacija;
  rand bit ctrl;
  rand bit [31:0] data;
  constraint c_impl {ctrl -> (data == 0);}
endclass

class sa_redosledom;
  rand bit ctrl;
  rand bit [31:0] data;
  constraint c_impl {ctrl -> (data == 0);}
  constraint c_red {solve ctrl before data;}
endclass
```
Bez `solve-before`, verovatnoća `ctrl==1` je praktično nula (1/(2^32+1)); sa njim je ~50% — direktno primenjivo na testiranje AXI `start` bita naspram loše konfiguracije.

```systemverilog
tr.constraint_mode(0);       // isključi sva ograničenja (namerno slanje pogrešne transakcije)
tr.data_range.constraint_mode(1); // ponovo uključi samo jedno
```

Zadatak iz vežbe (Sudoku rešavač koristeći isključivo `rand` polja + `constraint` bez proceduralnog algoritma) ilustruje snagu constraint solvera: `box[9][9]` polje, `constraint`-i za red/kolonu/kvadrat/unos, rešenje dobijeno pozivom `randomize()`.

## Primena na NCC akcelerator projekat

Ovo je osnova za sve stimulus/sequence klase u FVH koraku 3 (test/env/config/sekvencer/drajver/sekvenca/monitor, 50 poena) i za regresiju (korak 6, 10 poena):

- **Transaction/sequence_item klasa za AXI-Lite pristup** (`ncc_accel_slave_lite_v1_0_S00_AXI`): polja `rand bit [31:0] addr`, `rand bit [31:0] wdata`, `rand bit rw`. Constraint `addr inside {12'h00, 12'h04, 12'h08, 12'h0C, 12'h10, 12'h14, 12'h30, 12'h34, 12'h40}` da se generišu samo validne adrese registara (REG_IMG_W...ADDR_RESULTS), a odvojen negativni test sa `constraint_mode(0)` za namerno slanje neispravne adrese (provera da li AXI vraća SLVERR ili se DUT čudno ponaša).
- **Randomizacija dimenzija slike/šablona**: `rand bit [15:0] img_w, img_h, tmp_w, tmp_h;` sa `constraint dim_c { img_w inside {[1:90]}; tmp_w <= img_w; ... }` — realan opseg za 90x90 sliku i manje šablone (kao u `ncc_core_real_tb`).
- **`dist` operator za AW/W redosled**: ključni scenario iz DUT briefinga (AW-first, W-first, simultano na S00 i S01) modeluje se kao `rand bit [1:0] order; constraint order_c { order dist {0:=40, 1:=40, 2:=20}; }` — 40% AW-first, 40% W-first, 20% simultano — direktno target-uje popravljeni hardverski bug.
- **`randc` za obilazak svih pozicija rezultata** (results memorija na S01 +0x10000) bez ponavljanja tokom jednog regresionog prolaza.
- **`solve...before`** koristiti kad `REG_CTRL.start` zavisi od validnosti prethodno postavljenih registara — osigurati da se prvo generišu validne dimenzije/adrese, pa tek onda `start` bit.
- **Seed management**: u Xcelium (`xrun -svseed <seed>`) i XSim (`-sv_seed <seed>` u `xsim.simulate.xsim.more_options`) — ovo je direktan zahtev FVH koraka 7 (pokretanje simulacije u oba simulatora, 10 poena); loguj korišćeni seed u svakom regresionom testu radi reprodukcije padova.

Vidi i [[Vezba 05 - Uvod u UVM metodologiju]] i [[Predavanje 04 - Kreiranje verifikacionog okruzenja]] za strukturu okruženja u koju ove randomizovane transakcije ulaze.
