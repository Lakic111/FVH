---
tags: [fvh, predavanje]
---

# Predavanje 04 dodatak - SystemVerilog Assertions (SVA)

## Ključni koncepti

- **Šta je tvrdnja (assertion)**: provera specifikacije dizajna koja nikad ne sme biti prekršena; kad se prekrši, treba prikazati grešku. SVA je specijalizovan jezik za jednostavno modelovanje sekvencijalnih vremenskih provera — mnogo lakše nego u čistom Verilogu/VHDL-u. Prednosti: lakše pisanje, veća produktivnost, lakše debagovanje, funkcionalna pokrivenost (assertion coverage), brža simulacija (formalni alati mogu koristiti iste tvrdnje).

**Osnovne logičke tvrdnje (Immediate assertions)**
- Ne zavise od takta, prate tok simulacije, koriste se samo u proceduralnom kodu (npr. `always_comb`). Proveravaju se svaki put kad se promeni vrednost promenljive u izrazu.

**Konkurentne tvrdnje (Concurrent assertions)**
- Taktovane: `[clocking_event] [disable iff (rst)] property`. Primer: `a1: assert property (@(posedge clk) disable iff (rst) a |-> nexttime[2] b);`
- Mogu biti u `always`/`initial` procedurama, ili samostalno (static) van svake procedure — u tom slučaju postoji implicitni spoljašnji `always` operator (tvrdnja se prati na svakom taktu kontinuirano).
- `initial` procedura proverava tvrdnju samo jednom (npr. stanje na prvom taktu); `always`-stil prati konkurentno na svakom taktu.

**Osnovna svojstva (properties)** — jezgro konkurentnih tvrdnji, vremenska formula tačna/netačna na datom tragu (trace), grade se rekurzivno:
- **Boolean svojstvo** — u `initial` proceduri se evaluira samo jednom (koristan obrazac za proveru stanja na startu); van toga bi se bezuslovno evaluiralo na svakom taktu.
- **`nexttime p`** — tačno u taktu i ako je p tačno u taktu i+1; skraćenica `nexttime[n]` za n koraka unapred.
- **`until` vs `until_with`** — razlika je da li levi izraz mora važiti i u taktu kad desni postane tačan:
  - `b until !c` (non-overlapping): `b` mora biti 1 do (ne uključujući) takt kad `!c` postane tačno.
  - `b until_with !c` (overlapping): `b` mora biti 1 uključujući i takt kad `c` padne na 0.
- **`always p`** — tačno u taktu i ako je p tačno u svim taktovima j ≥ i.
- **`s_eventually p`** — tačno u taktu i ako je p tačno u nekom (bilo kom budućem) taktu j ≥ i — koristi se npr. za "reset će se kad-tad deaktivirati".
- **Logički operatori nad svojstvima**: `not` (negacija), `and` (konjunkcija), `or` (disjunkcija).

**Sekvence (sequences)**
- Sekvenca definiše niz vrednosti kroz vreme; nema vrednost istinitosti, ima početnu tačku i tačke podudaranja (match). Taktovane su (nasleđuju takt od svojstva ako nije eksplicitno navedeno).
- `a ##[1:2] b` — a praćeno sa b u 1 ili 2 takta. `##m` — kašnjenje od m taktova. `##0` — spajanje sekvenci bez razmaka (preklapajuća konkatenacija).
- **Implikacija sufiksa (suffix implication)**: sekvenca `s` (pretpostavka/antecedent) implicira svojstvo `p` (posledica/consequent).
  - `s |-> p` (overlapping) — posledica se proverava u istom taktu kad se sekvenca s završava.
  - `s |=> p` (nonoverlapping) — posledica se proverava u sledećem taktu.
  - Ugnježdene implikacije: pretpostavka mora biti sekvenca, ne svojstvo (`start |-> ##2 send` nije validna pretpostavka jer je `property`, ne `sequence`).
- **Uzastopno ponavljanje**: `s[*n]` — sekvenca s tačno n puta uzastopno. Opseg: `s[*m:n]` (konačno), `s[*n:$]` (beskonačno, $ = "beskonačan broj"). Prečice: `s[*]` = `s[0:$]`, `s[+]` = `s[1:$]`.
- **Go-to ponavljanje**: `e[->1]` — uslov e mora se desiti prvi put; `e[->n]` skraćenica za `(!e[*] ##1 e)[*n]`; podržava i opsege `e[->m:n]`.
- **Neuzastopno ponavljanje**: `e[=n]` — slično go-to ponavljanju, ali poslednje pojavljivanje ne mora biti na kraju sekvence (uslov ostvaren n puta, ne nužno tačno na granici).

**Funkcije i taskovi**
- Funkcije za bit-vektore: rade nad jednim argumentom (bit-vektorom); `$countbits` prima i dodatnu listu kontrolnih vrednosti za poklapanje. `$isunknown(vec)` vraća 1 ako bilo koji bit ima vrednost x ili z — korisno za proveru "svi bitovi podataka moraju biti poznati kad je read aktivan".
- Funkcije uzorkovanih vrednosti: `$past(signal)` — vraća vrednost signala iz prethodnog takta; `$rose`/`$fell` — detekcija rastuće/opadajuće ivice signala (bool na osnovu prethodnog i trenutnog sample-a).

**Parametrizacija tvrdnji**
- Tvrdnje (properties/sequences) mogu imati formalne argumente, čineći ih generičkim za upotrebu sa različitim stvarnim argumentima. Podržano povezivanje po poziciji ili po imenu, sa podrazumevanim vrednostima.

**I2C primer (praktičan end-to-end primer iz predavanja)**
- Kompletna `property p_i2c_write` koja korak-po-korak (koristeći `$fell`, `$rose`, uzastopna i go-to ponavljanja, `##[1:10]` kašnjenja) prati ceo I2C write protokol: START uslov → 7-bitna adresa → R/W bit i provera opsega adrese → ACK od slave-a → 8 bita podataka → NACK od master-a → STOP uslov. Demonstrira kako se realan multi-fazni protokol enkodira kao jedna sekvenca/property sa `$display` debug ispisima u svakom koraku i `assert property (...) else $error(...)`.

## Kod / primeri

```systemverilog
a1: assert property (@(posedge clk) disable iff (rst) a |-> nexttime[2] b);
```
Taktovana konkurentna tvrdnja: ako je `a` tačno, `b` mora biti tačno dva takta kasnije; deaktivirana tokom reseta.

```systemverilog
// Implikacija sufiksa - overlapping vs nonoverlapping
rdy_check:  assert property (@(posedge clk) rdy |-> !rst);        // isti takt
done_check: assert property (@(posedge clk) sent |=> done);       // sledeći takt
```

```systemverilog
sequence check_rd_adr;
  ((rd_addr == $past(rd_addr)+1) && read) [*0:$] ##1 $fell(read);
endsequence
sequence read_cycle;
  ($rose(read) && reset_);
endsequence
property burst_check;
  @(posedge clk) read_cycle |-> check_rd_adr;
endproperty
```
Provera burst čitanja: `rd_addr` se mora uvećavati za 1 svaki takt dok `read` ne padne — koristi `$past` za poređenje sa prethodnom vrednošću, `[*0:$]` za proizvoljan broj ponavljanja.

```systemverilog
property p_i2c_write;
  logic [6:0] addr = 7'b0;
  logic [7:0] data = 8'b0;
  @(posedge sys_clk) ($fell(sda) && scl) |=>
    (##[1:10] ($rose(scl), addr = {addr[5:0], sda}))[*7]
    ##[1:10] $rose(scl) ##0 (sda == 1'b0 && addr >= 7'h0A && addr <= 7'h0F)
    ##[1:10] $rose(scl) ##0 (sda == 1'b0)                      // slave ACK
    ##[1:10] ($rose(scl), data = {data[6:0], sda}))[*8]
    ##[1:10] $rose(scl) ##0 (sda == 1'b1)                       // master NACK
    ##[1:100] ($rose(sda) && scl);                              // STOP
endproperty
assert property (p_i2c_write) else $error("I2C Write Violation!");
```
Kompletan multi-fazni protokolski checker izgrađen kompozicijom sekvenci — obrazac direktno primenljiv na AXI protokol.

## Primena na NCC akcelerator projekat

SVA tvrdnje su prirodan dodatak UVM monitoru i **direktno adresiraju poznati fiksirani hardverski bug** (AW-pre-W vs W-pre-AW hang na S00 i S01) — koriste se kao "living specification" u monitoru/interfejsu, komplementarno sa UVM scoreboard-om (FVH korak 4):

- **Protokolska provera AXI-Lite (S00) redosleda AW/W**: analogno I2C primeru, napisati `property` koja prati `awvalid`/`awready`/`wvalid`/`wready` i proverava da transakcija završi (bready/bvalid handshake) bez obzira na redosled AW/W — npr. `s_eventually (awvalid && awready)` i `s_eventually (wvalid && wready)` unutar razumnog vremenskog prozora, kao regresiona zaštita da se stari bug (hang kad W stigne pre AW) ne vrati.
- **`REG_STATUS` protokol provera**: `property busy_before_done; @(posedge clk) disable iff (!resetn) $rose(start) |=> busy[*1:$] ##1 done_sticky; endproperty` — proverava da nakon postavljanja `REG_CTRL.start` bita sledi `busy=1` neko vreme pa onda `done_sticky=1`, sprečavajući lažno "trenutno gotovo" ponašanje FSM-a (23 stanja u `ncc_core.vhd`).
- **Provera da se novi `start` ne prihvata dok je `busy` aktivan**: `property no_start_while_busy; @(posedge clk) busy |-> !start; endproperty` — direktno testira DUT ograničenje "ne prima se nova komanda dok je operacija u toku" nagoveštenu specifikacijom registra.
- **AXI-Full (S01) burst provera**: koristeći `$past` i uzastopno ponavljanje (`[*n]`) po uzoru na `check_rd_adr` primer iz predavanja — proveriti da adresa raste monotono tokom burst upisa slike/šablona (analogno postojećim `ncc_accel_burst_tb`/`ncc_accel_s01_burst_wfirst_tb` VHDL testbenčevima, ali kao SVA umesto proceduralnog VHDL koda).
- **`$isunknown` provera**: primeniti na `out_data`/rezultat magistralu kad je `done_sticky=1` — svi bitovi rezultata moraju biti poznati (0/1), korisno za hvatanje X-propagacije iz `seq_divider`-a u `ncc_core.vhd`.
- **Parametrizacija**: napisati generičku `property` za AXI handshake (validan/ready par) sa formalnim argumentima (signal names) i primeniti je i na S00 i na S01 interfejs bez dupliranja koda — svaki AXI kanal (AW, W, B, AR, R) ima isti handshake obrazac.
- Ove tvrdnje se ubacuju u `ncc_if` interfejs ili u poseban `ncc_assertions` modul bind-ovan na DUT, i rade u oba simulatora (Xcelium i XSim) bez izmene — što ih čini korisnim i za FVH korak 7 (dvostruka simulacija) jer verifikuju da se isto ponašanje reprodukuje u oba alata.

Vidi i [[Predavanje 04 - Kreiranje verifikacionog okruzenja]] (odeljak 2.9 pominje logičke tvrdnje kao jedan od dva verifikaciona aspekta HDL-a) i [[Vezba 05 - Uvod u UVM metodologiju]] za mesto monitora/assertion-a u UVM hijerarhiji.
