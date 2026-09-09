---
tags: [fvh, projekat, dokumentacija]
---

# Verifikacioni plan — NCC akcelerator (FVH korak 2)

Dokument koji se dodaje na postojeću PSDS dokumentaciju
(`PSDS_dokumentacija_y25-g10_Korak2-8.pdf`) kao novo poglavlje. Struktura po šablonu
iz [[Predavanje 03 - Plan verifikacije]] (Calc1 primer), popunjena za `ncc_accel`.

> **Svi brojevi u ovom dokumentu izvedeni su iz RTL-a**, ne iz sećanja — izvor je
> zamrznuta kopija u `verif/rtl/` (Sesija 0, 2026-09-05). Gde se RTL razlikuje od
> ranijih beleški, RTL je merodavan i razlika je izričito navedena.

## 1. Nivoi verifikacije

DUT (`ncc_core`, RTL) je već verifikovan u PSDS-u (golden 4×4/2×2 + realni podaci,
bit-tačno). FVH fokus je **IP nivo** — `ncc_accel` sa AXI4-Lite (S00) i AXI4-Full (S01)
interfejsom — i, ako vreme dozvoli, **integracioni nivo** (`ncc_system`: 2× `ncc_accel`
+ AXI interconnect).

## 2. Ugovor sa softverom — granice legalnog stimulusa

`ncc_core` u stanju `S_IDLE`, na `start='1'`, proverava četiri uslova VHDL tvrdnjama
sa `severity failure`:

| # | Uslov | Poruka pri kršenju |
|---|---|---|
| U1 | `1 ≤ img_w ≤ 90` i `1 ≤ img_h ≤ 90` | `img_w/img_h van opsega 1..90` |
| U2 | `1 ≤ tmp_w ≤ 30` i `1 ≤ tmp_h ≤ 30` | `tmp_w/tmp_h van opsega 1..30` |
| U3 | `tmp_w · tmp_h ≤ 900` | `tmp_w*tmp_h > MAX_TMP_PIX` |
| U4 | `tmp_w ≤ img_w` i `tmp_h ≤ img_h` | `sablon veci od slike` |

**Posledica za verifikaciju, i to obavezujuća:** `severity failure` **obara celu
simulaciju**, ne pojedinačni test. Zato:

- Ograničenja randomizacije (`ncc_reg_item`) **moraju** garantovati U1-U4. Slučajno
  generisana dimenzija van opsega ne daje FAIL nego ruši regresiju — što je gore,
  jer se izgubi i coverage svih ostalih testova u tom pokretanju.
- **Testiranje nelegalnih dimenzija je van obima** i to je svesna odluka, ne propust.
  Tvrdnje su simulaciona kapija; u sintezi nestaju, a u hardveru bi dale tiho odsecanje
  bita. Verifikuje se **poštovanje ugovora**, ne ponašanje pri kršenju.
- Registri su 32-bitni, ali se koristi samo `slv_regN(7 downto 0)` — gornja 24 bita se
  upisuju i čitaju, a jezgro ih ignoriše. To je legalan stimulus (ne krši U1-U4) i
  dobar kandidat za proveru „upisano == pročitano" nezavisno od rada jezgra.

Napomena: `img_w` je `dim_t` = `unsigned(7 downto 0)`, dakle 0..255 sa magistrale;
opseg 91..255 je fizički upisiv u registar, ali ga jezgro odbija tvrdnjom. Granica
nije u širini registra nego u ugovoru.

## 3. Mapa registara S00 (AXI4-Lite) — provereno u RTL-u

Adresna magistrala je **6 bita** (`C_S00_AXI_ADDR_WIDTH = 6`), `ADDR_LSB = 2`,
`OPT_MEM_ADDR_BITS = 3` → 16 registara na `0x00`-`0x3C`.

| Adresa | `slv_reg` | Registar | Ponašanje |
|---|---|---|---|
| 0x00 | 0 | REG_IMG_W | bitovi 7:0 → `img_w` |
| 0x04 | 1 | REG_IMG_H | bitovi 7:0 → `img_h` |
| 0x08 | 2 | REG_TMP_W | bitovi 7:0 → `tmp_w` |
| 0x0C | 3 | REG_TMP_H | bitovi 7:0 → `tmp_h` |
| 0x30 | 12 | REG_CTRL | upis sa `WDATA(0)='1'` → `start_pulse`, i `done_sticky ← 0` |
| 0x34 | 13 | REG_STATUS | bit0 = `done_sticky`, bit1 = `core_busy` (samo za čitanje) |

**Ispravka ranije beleške:** `CLAUDE.md` navodi `0x10 REG_IMG_ADDR`, `0x14 REG_TMP_ADDR`
i `0x40 ADDR_RESULTS`. Adresa `0x40` **ne postoji na S00** — magistrala je 6-bitna, pa
je najveća adresa `0x3F`. Rezultati se čitaju sa **S01, region 10** (`+0x10000`), ne sa
S00. Registri `0x10`/`0x14` postoje kao `slv_reg4/5`, ali ih `ncc_accel` ne vodi ni na
jedan port jezgra — praktično su neupotrebljeni scratch registri.

**Nalaz — start dok je busy nije zaštićen.** Uslov za `start_pulse` je
`wr_beat='1' and mem_logic="1100" and WDATA(0)='1'`, **bez provere `core_busy`**.
Upis u CTRL tokom rada jezgra dakle:
- generiše `start_pulse` koji `ncc_core` ignoriše (nije u `S_IDLE`), ali
- **obriše `done_sticky`**.

To je stvarno, neverifikovano ponašanje i prioritetna meta (vidi §5, T7).

## 4. Mapa memorije S01 (AXI4-Full) — provereno u RTL-u

Adresna magistrala je **17 bita** (128 KB). Dekodiranje u `mem_subsystem`:
`region = addr(16:15)`, `word = addr(14:2)` — **jedan piksel po 32-bitnoj reči**.

| Region | `addr(16:15)` | Offset | Memorija | Kapacitet | Pristup sa S01 |
|---|---|---|---|---|---|
| Slika | 00 | +0x00000 | `dp_bram` 8192×8 | 8100 od 8192 u upotrebi (90×90) | čitanje i upis |
| Šablon | 01 | +0x08000 | `dp_bram` 1024×8 | 900 od 1024 u upotrebi (30×30) | čitanje i upis |
| Rezultat | 10 | +0x10000 | `dp_bram` 8192×32 | 8100 u upotrebi | **samo čitanje** |
| — | 11 | +0x18000 | nemapirano | — | čita `0x00000000` |

Četiri ponašanja koja iz ovoga slede, a nijedno nije dosad verifikovano:

- **P1 — rezultat je read-only sa S01.** `result_mem` ima `wea => '0'`; upis u region 10
  se tiho ignoriše, a `BRESP` je i dalje `OKAY`. Test mora dokazati da se sadržaj ne menja.
- **P2 — šablon aliasira.** `templ_mem` koristi samo `word(9 downto 0)`, a `word` je
  13 bita. Adrese koje se razlikuju za 1024 reči (0x1000 bajtova) unutar regiona 01
  gađaju **istu** lokaciju. Očekivano ponašanje, ali mora biti zapisano kao takvo.
- **P3 — gornja 24 bita čitanja su nula** za regione 00 i 01
  (`mem_rdata_a <= x"000000" & doa`). Region 10 vraća punih 32 bita.
- **P4 — region 11 vraća nule**, ne `DECERR`.

Čitanje ima **latenciju od jednog takta** (`region_d` se registruje radi poravnanja sa
`dp_bram`); monitor S01 mora to uzeti u obzir pri rekonstrukciji transakcije.

## 5. Funkcije za verifikaciju i test matrica

Oznake: **D** = directed, **R** = constrained-random.

| # | Funkcija | Tip | Konkretan stimulus | Coverage cilj |
|---|---|---|---|---|
| T1 | Registarski upis/čitanje S00 | D+R | svih 6 korišćenih registara; R: nasumična vrednost, `addr ∈ {0x00,0x04,0x08,0x0C,0x30,0x34}` | svaka adresa bar jednom, upis i čitanje |
| T2 | Neupotrebljeni registri | R | `slv_reg4..11,14,15` — upis/čitanje | bin „scratch" pogođen |
| T3 | AW/W redosled S00 | D+R | 3 scenarija: `AW_FIRST`, `W_FIRST`, `SIMUL`; R sa `dist {AW_FIRST:=2, W_FIRST:=2, SIMUL:=1}` | cross redosled × region |
| T4 | AW/W redosled S01 | D+R | ista 3 scenarija | cross redosled × region |
| T5 | Burst S01 | D+R | dužine `AWLEN+1 ∈ {1, 2, 3, 16, 256}`, `INCR`; `WSTRB ∈ {F, 1, 3, 9}` | bins: 1, 2, 3-15, 16-255, 256 |
| T6 | Start/busy/done_sticky | D | 90×90 / 25×15; čitaj STATUS pre, tokom i posle | cross `start × busy` |
| T7 | **Start dok je busy** | D | pokreni 90×90, pa upiši CTRL.start=1 dok je `busy=1` | bin `start & busy` = 1 |
| T8 | NCC rezultat, golden | D | 90×90 / 25×15 → pik `0x80000000 @ (u=32, v=14)` iz `ncc_core_real_tb` | — |
| T9 | NCC rezultat, mali golden | D | 4×4 / 2×2, svih 9 pozicija iz `ncc_core_tb` | — |
| T10 | NCC rezultat, random | R | `img ∈ [8:90]²`, `tmp ∈ [2:30]²` uz U3 i U4 | bins dimenzija (§6) |
| T11 | Granični slučaj `tmp = img` | D | 30×30 / 30×30 → mapa rezultata je 1×1 | bin `res = 1×1` |
| T12 | Maksimalni šablon | D | 90×90 / 30×30 (`tmp_w·tmp_h = 900 = MAX_TMP_PIX`) | bin `tmp_pix = max` |
| T13 | Rezultat je read-only (P1) | D | upiši u `+0x10000`, pročitaj nazad | bin „upis u region 10" |
| T14 | Aliasing šablona (P2) | D | upiši na `+0x08000` i `+0x09000`, pročitaj oba | bin „templ alias" |
| T15 | Nemapirani region (P4) | D | čitaj `+0x18000` | bin „region 11" |

**Broj seed-ova u regresiji:** 20 po random testu (T1, T3, T4, T5, T10). Directed
testovi idu sa fiksnim seed-om jer im randomizacija ne menja stimulus.

**Trajanje:** T8 i T10 rade pun NCC proračun i traju **minutima** po pokretanju
(≈2,4 miliona taktova) — isto upozorenje stoji u `run_sim.tcl`. Regresija ih zato drži
u zasebnoj, sporoj listi; brza lista (T1-T7, T11, T13-T15) mora proći u sekundama.

## 6. Coverage plan — konkretni bins

Uzorkuje se **iz monitora**, nikad iz drajvera (inače se meri stimulus, ne DUT).

```
covergroup cg_dimenzije:
  img_w : bins {1, [2:44], 45, [46:89], 90}        // min, ispod, coarse, iznad, max
  img_h : isti raspored
  tmp_w : bins {1, [2:14], 15, [16:29], 30}        // min, ispod, coarse, iznad, max
  tmp_h : isti raspored
  cross img_w × tmp_w  uz ignore_bins (tmp_w > img_w)   // U4 ih čini nedostižnim

covergroup cg_kontrola:
  start  : bins {0, 1}
  busy   : bins {0, 1}
  done   : bins {0, 1}
  cross start × busy    // bin (1,1) je T7 -- kljucni
  cross start × done    // start brise done_sticky

covergroup cg_axi:
  redosled : bins {AW_FIRST, W_FIRST, SIMUL}
  region   : bins {S00, S01_slika, S01_sablon, S01_rezultat, S01_nemapirano}
  cross redosled × region     // 15 kombinacija -- centralni cilj plana
  burst_len : bins {1, 2, [3:15], [16:255], 256}
  wstrb     : bins {F, 1, 3, 9}
```

Cilj: **100 % na `cross redosled × region`** (to je meta popravljenog bug-a),
≥ 90 % ukupno. Sve što ostane nepokriveno mora imati zapisan razlog — nepokriven bin
bez objašnjenja se na odbrani čita kao propust, a ne kao odluka.

## 7. Arhitektura okruženja

```
ncc_test
  └─ ncc_env
       ├─ axil_agent (S00)         ├─ axif_agent (S01)
       │   ├─ sequencer            │   ├─ sequencer
       │   ├─ driver               │   ├─ driver
       │   └─ monitor ─┐           │   └─ monitor ─┐
       │               │           │               │
       ├─ scoreboard ◄─┴───────────┴───────────────┘
       │   (referentni model NCC², real-time provera preko done_sticky)
       └─ coverage collector (subscriber na oba monitora)
```

Blok dijagram za dokumentaciju crta se kao slika (`fig_verif_env.png`), po istom
postupku kao `fig1..fig5` u `02 Dokumentacija/_alat_docx/`.
Detaljna hijerarhija: [[Vezba 09 - Hijerarhija UVM okruženja]].

**Zahtev na drajver, izveden iz RTL-a (Sesija 0):** popravljeni S00 je strogo dvofazni
upisni automat — u stanju `Waddr` je `awready='1', wready='0'`, a u `Wdata` obrnuto.
Ta dva signala se **nikad ne dižu u istom taktu**. Drajver zato mora voditi AW, W i B
kao nezavisne niti i držati `WVALID` do `wready`; jedan spojeni handshake
(`wait awready && wready`) visi zauvek. To nije stilska preferenca nego uslov da
`W_FIRST` scenario uopšte prođe.

## 8. Strategija generisanja stimulusa

Directed testovi iz postojećih golden VHDL testbenchova čine regresionu osnovu
(Korak 6), a constrained-random sa `dist`-težinskim AW/W redosledom obezbeđuje da se
popravljeni bug testira redovno, ne slučajno. Ograničenja moraju kodirati U1-U4 iz §2.
Detalji: [[Vezba 04 - Randomizacija i ogranicenja u SystemVerilogu]],
[[Predavanje 06-07 - Strategije za generisanje stimulusa]].

## 9. Strategija provere rezultata

Real-time scoreboard okinut na `done_sticky`, referentni model (transakcioni NCC²
prediktor iz golden podataka / C kernela) + SVA protokolske tvrdnje za AXI handshake.
Uz njih idu i provere P1-P4 iz §4, koje ne zavise od NCC proračuna i zato mogu da rade
u brzoj listi. Detalji: [[Vezba 10 - Razvoj scoreboard komponente]],
[[Predavanje 08-09 - Strategije za proveru rezultata]].

## 10. Alati i okruženje

- SystemVerilog + **UVM 1.2** (uz Vivado, `data/system_verilog/uvm_1.2`, `-L uvm`)
- **Vivado XSim 2025.2** (`xvhdl -2008` → `xvlog -sv` → `xelab` → `xsim`) i
  **Cadence Xcelium** (`xrun`) — Xcelium na udaljenoj mašini
- `xvhdl -2008` je obavezan (`ncc_core` koristi `process (all)`)
- Isti `rtl.f` i `tb.f` za oba simulatora, relativne putanje —
  vidi [[Vezba 13 - Ponovna upotreba UVM komponenti i multi-simulator flow]]

## 11. Rizici

- ~~AXI mešoviti jezik (VHDL DUT + SV TB)~~ — **otklonjen u Sesiji 0**: `xelab`
  elaborira `ncc_accel` i SV testbench zajedno, upis i čitanje registra prolaze.
  Ostaje da se isto potvrdi na Xcelium-u (Korak 7).
- `severity failure` u `ncc_core` ruši celu simulaciju pri nelegalnim dimenzijama —
  ograničenja randomizacije su jedina zaštita (§2). Rizik je visok jer greška u
  ograničenju ne izgleda kao greška u ograničenju, nego kao pad regresije.
- Sistem-nivo (`ncc_system`, 2 instance + interconnect) je znatno teži od IP nivoa —
  tek posle stabilnog IP-nivo okruženja.
- Trajanje T8/T10 (minuti po pokretanju × 20 seed-ova) može učiniti regresiju
  nepraktičnom; zato podela na brzu i sporu listu (§5).
- DMA (CDMA) put je u dizajnu ali se ne koristi u aplikaciji — van obaveznog obima FVH.
