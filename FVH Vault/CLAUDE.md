# FVH OS — Claude Context File

Obsidian vault posvećen predmetu **Funkcionalna verifikacija hardvera (FVH)** —
konkretno projektu izgradnje SystemVerilog/UVM verifikacionog okruženja oko
**NCC akceleratora** (projekat sa predmeta PSDS, već završen i funkcionalan na ploči).

Poseban vault od PSDS vault-a (`C:\Users\pc\Desktop\PSDS\PSDS Vault\`) — taj pokriva
projektovanje i implementaciju DUT-a, ovaj pokriva **verifikaciju** istog DUT-a. Kod
DUT-a se **ne dira** iz ovog vault-a bez pitanja.

## Ko sam ja i moja svrha

Student sam, apsolvent, peta godina elektrotehnike. PSDS projekat (NCC akcelerator za
prepoznavanje šahovskih figura, Zynq-7010/Zybo, VHDL) je završen — koraci 1-9, 90/100
bodova. Sada FVH traži da se oko istog DUT-a izgradi UVM verifikaciono okruženje u
SystemVerilogu, sa scoreboard-om, coverage-om, regresijom, i dvostrukom simulacijom
(Vivado XSim + Cadence Xcelium).

## Claude-ova svrha na ovom nivou

- Praćenje napretka kroz 7 koraka bodovanja FVH projekta (vidi `Prilozi/`)
- Sažetak svake vežbe i predavanja, sa direktnom vezom na NCC DUT (`Vezbe/`, `Predavanja/`)
- Konkretan plan implementacije verifikacionog okruženja (`Projekat/Plan.md`)
- Odluke i status (`Projekat/Napredak.md`)

Glavna direktiva: koraci bodovanja MORAJU ići redom (2→7, korak 1 je već ispunjen).
Ako sesija luta van trenutnog koraka: "Koji korak trenutno radimo — je li prethodni
zaista završen?"

## DUT koji se verifikuje — brzi pregled

IP jezgro `ncc_accel` (VHDL). **Zvanicni izvor: `C:\Users\pc\Desktop\PSDS_Projekat_MOJ\src\vhdl\`**
(izabrano u Sesiji 0 -- vidi `Projekat/Napredak.md`; `PSDS_Projekat_PROFESOR` je
bajt-identican, `NCC_Akcelerator` je starija verzija). Verifikacija radi nad
zamrznutom kopijom u `C:\Users\pc\Desktop\FVH\verif\rtl\` -- DUT se ne menja:

- **AXI4-Lite slave (S00)** — kontrolni registri (adrese 0x00-0x40, vidi tabelu ispod)
- **AXI4-Full slave (S01)** — memorisano mapirane interne memorije (slika/šablon/rezultati, 128 KB region)
- `ncc_core.vhd` — FSM (23 stanja) + `seq_divider`, NCC² proračun
- Postojeći **VHDL testbenchovi** (`ncc_core_tb`, `ncc_core_real_tb`, `ncc_accel_tb`,
  `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb`, `ncc_accel_s01_burst_wfirst_tb`) su
  izvor **golden podataka** za scoreboard referentni model
- **Poznat i popravljen bug**: AXI upisni put (S00 i S01) je visio kada `W` stigne
  pre `AW` — odličan kandidat za directed test + coverage bin + SVA protokolsku tvrdnju

| Adresa | Registar | Opis |
|---|---|---|
| 0x00 | REG_IMG_W | Širina slike/segmenta |
| 0x04 | REG_IMG_H | Visina slike/segmenta |
| 0x08 | REG_TMP_W | Širina šablona |
| 0x0C | REG_TMP_H | Visina šablona |
| 0x10, 0x14 | (neupotrebljeni) | `slv_reg4/5` — ranije zvani REG_IMG_ADDR/REG_TMP_ADDR, ali ih `ncc_accel` ne vodi ni na jedan port jezgra |
| 0x30 | REG_CTRL | bit0 = start; upis briše `done_sticky`, **nema provere `busy`** |
| 0x34 | REG_STATUS | bit0 = done_sticky, bit1 = busy (samo čitanje) |

Adresa **0x40 ne postoji** — S00 magistrala je 6-bitna (max 0x3F). Mapa rezultata se
čita sa **S01, region 10** (`+0x10000`). Provereno u RTL-u 2026-09-05; detalji u
`Dokumentacija/FVH_verifikacioni_plan_y25-g10.pdf`, poglavlja 3 i 4.

S01 raspored (offset od baze 128 KB regiona): slika `+0x00000`, šablon `+0x08000`,
rezultat `+0x10000`, jedan piksel po 32-bitnoj reči.

## FVH bodovanje (7 koraka, `Prilozi/Bodovanje-projekta...pdf`)

| # | Korak | Bodovi | Status |
|---|---|---|---|
| 1 | Završen PSDS projekat | — | ✅ ZAVRŠENO |
| 2 | Verifikacioni plan + struktura okruženja (dokumentacija) | (uslov) | ✅ ZAVRŠENO |
| 3 | Osnovno okruženje: test, environment, config, sequencer, driver, sequence, monitor | 50 | ✅ ZAVRŠENO |
| 4 | Scoreboard + automatska provera rezultata | 15 | ✅ ZAVRŠENO |
| 5 | Coverage | 15 | ✅ ZAVRŠENO (100%) |
| 6 | Regresioni testovi | 10 | ✅ ZAVRŠENO (27/27) |
| 7 | Simulacija u Vivado XSim I Xcelium | 10 | ✅ ZAVRŠENO (27/27 na oba) |

**Za prolaz treba 50 bodova** — koraci 2-3 su tvrd uslov, 4-7 nose dodatne bodove.

## Folder struktura

```
FVH Vault/
├── CLAUDE.md                  ← Ovde si
├── Vezbe/                     ← Sažetak svake vežbe (1-13), sa "Primena na NCC" odeljkom
├── Predavanja/                ← Sažetak teorijskih predavanja, isto uparen sa DUT-om
├── Projekat/
│   ├── Plan.md                 ← Plan implementacije po FVH koracima 2-7
│   ├── Plan rada.md            ← Redosled sesija, isporuke i procena vremena
│   ├── Verifikacioni plan.md   ← Nacrt dokumenta za korak 2
│   └── Napredak.md             ← Status/odluke, ažurira se usput
└── Prilozi/                   ← PDF pravilnika i slična dokumentacija
```

## Vežbe i predavanja — indeks po temi

- **Osnove SV**: [[Vezba 01 - Uvod u SystemVerilog]], [[Vezba 02 - OOP aspekti SystemVerilog jezika]], [[Vezba 03 - Niti u SystemVerilog jeziku]]
- **Randomizacija i UVM osnove**: [[Vezba 04 - Randomizacija i ogranicenja u SystemVerilogu]], [[Vezba 05 - Uvod u UVM metodologiju]]
- **Sequence/driver/monitor**: [[Vezba 06-07 - Sekvence i drajver]], [[Vezba 08 - Monitor]]
- **Environment/scoreboard**: [[Vezba 09 - Hijerarhija UVM okruženja]], [[Vezba 10 - Razvoj scoreboard komponente]]
- **Coverage/regresija**: [[Vezba 11 - Prikupljanje pokrivenosti]], [[Vezba 12 - Regresija i proces debagovanja]]
- **Multi-simulator/reuse**: [[Vezba 13 - Ponovna upotreba UVM komponenti i multi-simulator flow]]
- **Teorija**: [[Predavanje 01-02 - Uvod u verifikaciju]], [[Predavanje 03 - Plan verifikacije]], [[Predavanje 04 - Kreiranje verifikacionog okruzenja]], [[Predavanje 04 dodatak - SystemVerilog Tvrdnje]], [[Predavanje 06-07 - Strategije za generisanje stimulusa]], [[Predavanje 08-09 - Strategije za proveru rezultata]], [[Predavanje 10-11 - Pracenje toka verifikacije]]

Detaljan plan implementacije: `Projekat/Plan.md`.
