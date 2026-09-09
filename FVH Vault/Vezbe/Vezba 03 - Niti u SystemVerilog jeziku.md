---
tags: [fvh, vezba]
---

# Vežba 3 - Thread-ovi u SystemVerilog jeziku

## Ključni koncepti

- Testbench je kompleksna struktura sa više komponenti koje moraju raditi paralelno (driver generiše, monitor prati, scoreboard proverava istovremeno) — to se postiže **nitima (threads)**. U literaturi/LRM-u se termini "thread" i "proces" često koriste naizmenično.
- **`fork...join`** — svaka naredba (ili `begin...end` blok) unutar `fork` je zasebna nit koja se izvršava paralelno; nastavak nakon `join` čeka da **sve** child niti završe.
- **`fork...join_any`** — nastavak čim završi **bar jedna** nit (ostale nastavljaju u pozadini).
- **`fork...join_none`** — nastavak **odmah**, bez čekanja ijedne child niti (nit se pokreće asinhrono).
- **`wait fork`** — blokira dok se ne završe *sve* child niti pokrenute unutar tekuće niti (koristno nakon `join_any`/`join_none` kad naknadno treba sinhronizacija).
- **`disable fork`** — nasilno terminira sve child niti (i njihove eventualne unučad-niti) tekuće niti; koristi se za "kill" pending monitora/timeout niti kada test završi ranije.
- **Inter-procesna komunikacija**:
  - **Događaji (events)**: `event e1;` , trigeruje se `->e1`, čeka se `@(e1)` (edge-sensitive, "hvata" samo zero-delay trigere u istom trenutku) ili `wait(e1.triggered())` (level-sensitive, hvata trigere koji su se već desili u tom simulacionom koraku — pouzdanije za sinhronizaciju nezavisnih niti).
  - **Semafori** — ekskluzivni pristup deljenom resursu preko "ključeva": `new(num_of_keys)`, `get(n)` (blokira dok ne dobije ključeve), `put(n)`, `try_get(n)` (neblokirajuća varijanta). Model za zaštitu deljenog resursa (npr. deljeni fajl za log, deljena memorija u referentnom modelu) između paralelnih niti.
  - **Mailbox** — FIFO za slanje poruka/objekata između niti (analogija poštanskog sandučeta): `new(bound)` (0 = neograničen kapacitet), `put()`/`get()` (blokirajuće), `try_put()`/`try_get()` (neblokirajuće), `peek()` (čita bez uklanjanja), `num()`. Podrazumevano netipiziran, ali se preporučuje parametrizacija (`mailbox #(tip)`) da bi se izbegle greške tipa. **Ovo je standardni mehanizam za prosleđivanje transakcija između driver/monitor/scoreboard niti u testbenchu.**
- Klasična zamka: petlja `for (int i=0;...) fork ... join_none` — svaka iteracija kreira novu nit koja referencira `i`; treba biti pažljiv sa vremenom kada se `i` čita unutar niti (race condition/closures u SV petljama — tema zadatka u materijalu).
- Reset-svesnost testbench komponenti: drajver/monitor moraju detektovati aktivan reset i suzdržati se od slanja transakcija dok je reset aktivan — praktični zadatak vežbe.

## Kod / primeri

`fork/join` vs `join_any` vs `join_none` (iz `v3_fork_examples.sv` / materijala vežbe) — pokazuje razliku u trenutku nastavka glavne niti:
```systemverilog
fork
   #15 $display("1st example at %0t", $time);
   #5  $display("2nd example at %0t", $time);
   begin #10 $display("3rd/4th example at %0t", $time); end
join       // čeka SVE -> nastavak na t=15
// zamena za join_any -> nastavak na t=5 (najbrža nit)
// zamena za join_none -> nastavak odmah na t=0
```

`disable fork` posle `join_any` — ubija preostale (nezavršene) niti:
```systemverilog
fork
   forever begin @(a); $display("Observed change in a"); end
   @(negedge b);
join_any
disable fork;   // ubija forever petlju koja i dalje čeka na @(a)
```

Mailbox za komunikaciju driver→scoreboard stila:
```systemverilog
mailbox mbox = new();  // neograničen kapacitet
// nit A:
mbox.put(transaction_object);
// nit B:
mbox.get(received_transaction);
```

Semafor za zaštitu deljenog resursa:
```systemverilog
semaphore sem = new(1);
task access();
   sem.get(); // ... kritična sekcija ... sem.put();
endtask
```

## Primena na NCC akcelerator projekat

- Testbench za `ncc_accel` mora paralelno voditi: (1) generisanje AXI-Lite kontrolnih transakcija (upis registara, `start`), (2) generisanje AXI-Full burst transakcija (upis slike/šablona pre starta, čitanje rezultata posle), (3) monitor koji prati `done_sticky`/`busy` bit u REG_STATUS, (4) monitor koji prati AXI protokol handshake na oba interfejsa. Ovo je prirodan `fork...join_none` raspored pokrenut iz `run_phase` svake komponente (agent driver, agent monitor, itd.) — direktna primena `fork..join_none` konstrukcije iz ove vežbe.
- **Čekanje na `done`** je klasičan slučaj za `wait(status_reg.triggered())` ili polling petlju sa `@(posedge clk)` uz `iff` — treba koristiti level-sensitive pristup (`wait()`/event `triggered()`) jer se `done_sticky` bit može postaviti između dva takta monitor-petlje, a edge-sensitive `@(event)` bi mogao promašiti trigger ako monitor nije tačno "slušao" u tom trenutku — direktno relevantno jer FSM u `ncc_core.vhd` ima 23 stanja i kompleksan tajming završetka.
- **Mailbox** je prirodan kanal između monitor komponente (koja hvata AXI transakcije na S00/S01) i scoreboard-a: monitor radi `mbox.put(observed_txn)` za svaku uočenu AXI transakciju, scoreboard radi `mbox.get()` i poredi sa očekivanim NCC² rezultatom (referentni softverski model korelacije, portovan iz `ncc_core_real_tb` zlatnih podataka).
- **Semafor** je koristan ako se dva `ncc_accel` core-a (sistem ima 2 instance u `ncc_system` block design-u) dele zajednički resurs u testbenchu (npr. isti softverski referentni model ili isti log fajl) — sprečava race condition kada oba core-a rade paralelno.
- **`disable fork`** treba iskoristiti u sekvenci koja implementira timeout watchdog: pokreni `fork` sa (a) čekanjem na `done_sticky` i (b) `#TIMEOUT` brojačem u `join_any`, pa `disable fork` da ubiješ preostalu nit — direktna zaštita od poznatog AXI write-hang bug-a (AW pre W / W pre AW), gde bi bez watchdog-a simulacija zaglavila zauvek na loše uređenoj AW/W sekvenci.
- Zadatak iz materijala (modifikovati drajver/monitor da budu osetljivi na reset i ne šalju transakcije dok je reset aktivan) direktno se primenjuje na `aresetn` AXI reset signal `ncc_accel` DUT-a — driver i monitor moraju proveravati `aresetn` pre svakog handshake-a.
