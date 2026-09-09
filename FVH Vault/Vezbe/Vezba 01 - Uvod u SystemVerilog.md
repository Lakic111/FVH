---
tags: [fvh, vezba]
---

# Vežba 1 - Uvod u SystemVerilog

## Ključni koncepti

- SystemVerilog je nadogradnja Verilog-2001 jezika, prvi industrijski **HDVL** (Hardware and Verification Language) — kombinuje VHDL/Verilog hardversku sintaksu sa C/C++ objektno-orijentisanim mehanizmima, randomizacijom i funkcionalnom pokrivenošću (coverage).
- **Modul** u SV objedinjuje VHDL-ovski par `entity`/`architecture`. Portovi (`input`/`output`/`inout`) se navode direktno u zaglavlju modula.
- **Continuous assignment** (`assign`) odgovara VHDL `concurrent assignment` (`<=` sa `when/else`); uslovni `?:` operator zamenjuje `when...else`.
- Četiri vrste **procesnih (`always`) blokova**, svaki sa jasnom semantikom (za razliku od VHDL-ovog univerzalnog `process`):
  - `always` — generalni, npr. za generisanje takta (`always #10 clk = ~clk;`)
  - `always_ff @(posedge clk iff cond)` — sekvencijalna logika; `iff` dodatno filtrira uslov na ivici
  - `always_comb` — kombinaciona logika, implicitna lista osetljivosti
  - `always_latch` — modelovanje lečeva
  - Dodatno: `initial` (izvršava se jednom na početku simulacije) i `final` (jednom na kraju) — testbench ekvivalent VHDL `process` sa `wait` na kraju.
- **Kašnjenja**: `#5ns` (vremensko), `@(clk)` ili `@(posedge clk)` (čekanje na događaj/ivicu — edge-sensitive), `wait(x==5)` (čekanje na uslov, ekvivalent VHDL `wait until`).
- **Tipovi podataka**: `bit`/`logic` (2 vs 4 stanja: 0,1,X,Z). `logic` zamenjuje `reg` (izbegava zabunu da `reg` uvek znači registar) — preporučeni tip za signale koji se dodeljuju u proceduralnim blokovima. 2-state tipovi (`bit`, `int`) su brži i koriste 50% manje memorije — koriste se gde god je moguće (npr. brojači, kontrolna logika testbenča bez potrebe za X/Z).
- **Operatori jednakosti**: logička (`==`/`!=`, X/Z→0 u rezultatu ako je operand `bit`) vs case jednakost (`===`/`!==`, uzima u obzir X i Z tačno).
- **Sistemski pozivi**: `$display`/`$write` (ispis, formatni specifikatori `%0d`, `%0h`, `%0t`...), `$error`/`$warning`/`$fatal` (prijava grešaka), `$time`, `$finish`.
- Kompajliranje/simulacija radi se **Xcelium Simulator**-om (Cadence) preko `xrun` alata koji objedinjuje mapiranje biblioteka, kompajliranje, elaboraciju, simulaciju i debug u jednoj komandi. `-gui` otvara SimVision waveform/debug prozore; `-access +rwc` omogućava čitanje/pisanje/povezivanje internih signala za debug.
- `.f` fajl (build file / filelist) navodi izvorne fajlove i xrun opcije koje se prosleđuju alatu — osnova za kasnije regresione skripte.

## Kod / primeri

Primer iz priloženog materijala (`v1_counter.sv`, `v1_simple_tb.sv`) — brojač i minimalni testbench:

```systemverilog
module counter
  (input clk, input rst, input ce_i, input up_i,
   output logic [3:0] q_o);
  logic [3:0] count;
  always_ff @(posedge clk) begin
    if (rst) count <= 4'b0000;
    else if (ce_i) count <= up_i ? count + 1'b1 : count - 1'b1;
  end
  assign q_o = count;
endmodule
```

Testbench sa DUT instancom, `initial` blokovima za stimulus/timeout, `always` za takt, `final` za ispis, i funkcijom za poređenje (rani, ručni oblik onoga što će kasnije postati scoreboard/checker):

```systemverilog
module simple_tb;
  logic clk, rst, ce, up;
  logic [3:0] data;
  counter cnt_inst (clk, rst, ce, up, data);

  function void compare_values(logic [3:0] expected, logic [3:0] received);
    if (expected !== received)
      $error("Error: expected %0h, received %0h", expected, received);
    else
      $display("Successful comparison at %0t: %0h", $time, expected);
  endfunction

  initial begin clk<=0; rst<=1; up<=0; ce<=1; #50ns rst<=0; end
  always #5ns clk <= ~clk;
  initial begin repeat(3) @(posedge clk iff !rst); compare_values('he, data); end
  initial begin #500ns; $finish; end
endmodule
```

Build/simulacija komanda (`v1_build_file.f` sadrži fajlove + opcije):
```
xrun v1_counter.sv v1_simple_tb.sv -gui -access +rwc
```

## Primena na NCC akcelerator projekat

- DUT `ncc_accel` je pisan u **VHDL-u** (entity/architecture, `process`) — testbench okruženje za FVH se piše u **SystemVerilog-u**, pa treba mešoviti (mixed-language) build: SV testbench instancira VHDL top modul `ncc_accel` isto kao u primeru `counter cnt_inst(...)` — samo se portovi moraju ručno mapirati na VHDL generic/port imena (npr. AXI signali `S00_AXI_*`, `S01_AXI_*`, `clk`, `rst_n`).
- Ekvivalent `always #5ns clk <= ~clk;` generiše se sistemski takt: za NCC sistem to je 90.909 MHz (perioda ≈ 11 ns), a AXI zahteva i generisanje `aresetn` niskoaktivnog reseta na početku.
- Prvi, najjednostavniji "smoke test" nivoa iz `simple_tb.sv` direktno se preslikava na **prvi sanity test AXI-Lite kontrolnog interfejsa** `ncc_accel`: upiši `REG_IMG_W` (0x00), pročitaj nazad, uporedi (`compare_values`-stil provera) — pre nego što se gradi bilo kakav UVM sloj.
- Build filelist (`.f` fajl) postaje osnova za **regresioni skript** (zahtev 6 iz bodovanja): jedan `.f` fajl nabraja sve VHDL izvore DUT-a (`ncc_pkg.vhd`, `ncc_core.vhd`, `dp_bram.vhd`, `mem_subsystem.vhd`, oba AXI slave-a, `ncc_accel.vhd`) i sve SV testbench fajlove; `xrun -f build.f` pokreće i na Xcelium-u, a paralelno treba obezbediti i XSim varijantu (zahtev 7).
- `-access +rwc` opcija je korisna za rani debug FSM-a u `ncc_core.vhd` (23 stanja) — omogućava direktno posmatranje internih signala FSM-a u waveform prozoru dok se validira ponašanje `seq_divider`-a i NCC² datapath-a.
