---
tags: [fvh, projekat, plan-rada]
---

# Plan rada — FVH projekat (redosled sesija)

`Plan.md` kaže **šta** se gradi po koracima 2-7. Ovaj dokument kaže **kojim redom
sedati za računar**, šta je isporuka svake sesije i kada se sesija sme zatvoriti.

Pravilo bodovanja (`Prilozi/Bodovanje...pdf`): koraci se rade **strogo redom**,
koraci 1-3 su uslov za prolaz (50 bodova), 4-7 nose +15/+15/+10/+10.
Korak 1 je gotov (PSDS, 90/100).

**Definicija završenog koraka:** simulacija se pokreće jednom komandom i sama javlja
PASS/FAIL. Ništa se ne proglašava gotovim na osnovu "kompajlira se".

---

## Sesija 0 — Temelji repozitorijuma (0,5-1 h)

Ovo nije bodovano, ali sve posle zavisi od toga.

1. Napraviti radni direktorijum verifikacije, npr. `C:\Users\pc\Desktop\FVH\verif\`:
   ```
   verif/
   ├── rtl.f            ← filelist VHDL izvora DUT-a (redosled kao SVI_IZVORI)
   ├── tb.f             ← filelist SV/UVM fajlova
   ├── src/             ← interfejsi, agenti, env, testovi
   ├── tests/
   ├── sim/             ← run_xsim.tcl, run_xrun.sh, logovi
   └── result/
   ```
2. **Zaključati koja kopija DUT-a je zvanična.** Na Desktopu postoje `PSDS\src\vhdl`,
   `PSDS_Projekat_MOJ`, `PSDS_Projekat_PROFESOR`, `NCC_Akcelerator` — putanja iz
   `CLAUDE.md` (`PSDS_Projekat\ip_repo\...`) više ne postoji. Izabrati jednu
   (predlog: `PSDS_Projekat_MOJ`), zapisati je u `Napredak.md`, i `rtl.f` graditi
   samo iz nje. DUT se ne dira.
3. Prekopirati redosled izvora iz `PSDS_Projekat_MOJ\src\script\run_sim.tcl`
   (`SVI_IZVORI`) u `rtl.f` — taj redosled je već dokazan u XSim-u.
4. **Provera mešovitog jezika odmah, ne na kraju** (rizik iz verifikacionog plana):
   `xvlog -sv` + `xelab` na trivijalnom SV modulu koji instancira `ncc_accel` →
   dokaz da VHDL+SV elaborira zajedno u XSim-u. Xcelium je obezbeđen na udaljenoj
   mašini, pa se ne proverava ovde — ali zbog njega **sve putanje u `rtl.f`/`tb.f`
   moraju biti relativne**, da se `verif/` prenese na remote bez ijedne izmene.

**Isporuka:** prazna struktura + `rtl.f` + jedan uspešan `xelab` mešovitog jezika.

---

## Sesija 1 — Korak 2: verifikacioni plan (1-2 h)

Nacrt već postoji (`Verifikacioni plan.md`) i pokriva svih 9 poglavlja.

1. Dopuniti test matricu konkretnim brojevima (koje dimenzije, koje burst dužine,
   koliko seed-ova).
2. Nacrtati blok dijagram okruženja kao sliku (ne ASCII) — ide u dokumentaciju.
3. Uklopiti kao novo poglavlje u PSDS dokumentaciju
   (`PSDS_dokumentacija_y25-g10_Korak2-8.pdf`) ili kao zaseban prilog istog stila.

**Isporuka:** PDF poglavlje "Verifikacioni plan i struktura verifikacionog okruženja".
**Korak 2 je time zatvoren.**

---

## Sesije 2-6 — Korak 3: osnovno UVM okruženje (50 bodova)

Najveći blok. Ide u pet sesija, svaka se zatvara nečim što se **pokreće**.

### Sesija 2 — Interfejsi + paket (2-3 h)
- `axi_lite_if` (S00) i `axi_full_if` (S01), clocking blokovi, modporti.
- `ncc_pkg.sv`: adrese registara kao parametri (0x00-0x40), S01 offseti
  (`+0x00000/+0x08000/+0x10000`) — nijedan magičan broj ne sme kasnije u testove.
- Top `tb_top.sv`: takt, reset, instanca `ncc_accel`, `uvm_config_db::set` za oba vif.
- **Isporuka:** `xelab` prolazi, simulacija se pokrene i uredno završi bez ijedne
  transakcije.

### Sesija 3 — Sequence item-i + driver S00 (2-3 h)
- `ncc_reg_item`: `addr`, `data`, `rw`, `order` (`AW_FIRST`/`W_FIRST`/`SIMUL`).
- `ncc_axil_driver` koji poštuje `order` polje — bez toga korak 5 i 6 nemaju metu.
- **Isporuka:** direktna sekvenca upiše `REG_IMG_W` i pročita nazad ispravnu vrednost
  (privremena provera `$display`/`assert`, scoreboard tek u koraku 4).

### Sesija 4 — Monitor S00 + agent (2 h)
- Pasivni monitor koji rekonstruiše transakciju **nezavisno od AW/W redosleda**
  (red čekanja za AW), `uvm_analysis_port`.
- `ncc_axil_agent` (sequencer + driver + monitor) + `agent_config` sa bazom adrese.
- **Isporuka:** monitor loguje istu transakciju koju je driver poslao.

### Sesija 5 — S01 agent (burst) (3-4 h)
- Isti sloj za AXI4-Full: `ncc_mem_item` (burst dužina, `wstrb`, `order`), driver sa
  podrškom za više beat-ova, monitor sa istim AW/W redom čekanja.
- **Isporuka:** upis bloka piksela u S01 `+0x00000` i čitanje nazad istih vrednosti.

### Sesija 6 — env + test + smoke (2-3 h)
- `ncc_env` (oba agenta), `ncc_base_test`, `ncc_smoke_seq`:
  slika+šablon preko S01 → dimenzije preko S00 → `CTRL.start=1` → čekaj
  `STATUS.done_sticky` → pročitaj rezultat sa `+0x10000`.
- **Watchdog obavezan**: `fork ... join_any` + `disable fork` — poznati hang bug bi
  inače obesio regresiju umesto da je oborio.
- **Isporuka:** `run_xsim` pokreće smoke test, UVM report javlja 0 grešaka.
  **Korak 3 zatvoren — prag za prolaz je time osvojen.**

---

## Sesija 7 — Korak 4: scoreboard + SVA (3-4 h, +15)

- Referentni model NCC²: bihevioralni SV model (mala slika) uz proveru na
  **golden vrednostima iz postojećih VHDL TB-ova** — `ncc_core_tb` (4×4/2×2, svih 9
  tačaka) i `ncc_core_real_tb` (pik `0x80000000 @ (32,14)` za 90×90/25×15).
- Scoreboard sluša **samo monitore** (bez žice od stimulusa), okida na `done_sticky`,
  poredi ceo rezultat region.
- SVA tvrdnje uz DUT: AXI handshake (`AWVALID` drži do `AWREADY`), `busy`/`start`
  invarijanta, `done_sticky` se ne spušta sam.
- **Isporuka:** namerno pokvarena očekivana vrednost obara test → dokaz da provera
  stvarno radi. Zatim vratiti.

---

## Sesija 8 — Korak 5: coverage (2-3 h, +15)

- `covergroup` u zasebnom subscriber-u na oba monitora (ne u drajveru).
- Bins po planu: dimenzije (min/tipično 90×90 i 25×15/max u 128 KB), cross
  `start × busy`, cross `order × region`, burst dužina (1, 2, >2, max).
- **Isporuka:** `xcrg` report + kratak zapis u `Napredak.md` šta nije pokriveno i zašto.

---

## Sesija 9 — Korak 6: regresija (2-3 h, +10)

- Directed lista: preslikati scenarije iz `ncc_accel_wfirst_tb`,
  `ncc_accel_s01_burst_wfirst_tb`, `ncc_accel_burst_tb`, `ncc_accel_tb` u UVM testove.
- Random lista: `+UVM_TESTNAME` × N seed-ova, `dist`-težinski `order` da W-first
  scenario pada redovno.
- Runner skripta po uzoru na `run_sim.tcl` (ista logika: hvata FAIL u izlazu, sabira
  PASS/FAIL tabelu na kraju) — ne izmišljati novi mehanizam.
- **Isporuka:** jedna komanda → tabela N testova × M seed-ova + ukupan coverage.

---

## Sesija 10 — Korak 7: Xcelium (2-4 h, +10)

- Xcelium radi na udaljenoj mašini — prvo prebaciti ceo `verif/` tamo (relativne
  putanje iz Sesije 0 čine ovo trivijalnim) i proveriti UVM verziju (`xrun -uvmhome`).
- `run_xrun.sh`: isti `rtl.f` + `tb.f`, `xrun -uvm` sa `-v93`/mešovitim jezikom.
- Očistiti sve što je vendor-specifično iz TB koda ako se pojavi.
- **Isporuka:** identična regresija, identičan PASS/FAIL na oba simulatora, dva loga
  jedan pored drugog u dokumentaciji.

---

## Sesija 11 — Odbrana (1-2 h)

- Dopuniti dokumentaciju rezultatima koraka 3-7 (coverage %, regresiona tabela).
- Pripremiti demo: jedna komanda po simulatoru, uživo.
- Pripremiti odgovor na "gde je bio bug i kako ga vaše okruženje hvata" — AW/W
  ordering je centralna nit celog plana i najverovatnije pitanje na odbrani.

---

## Ukupna procena

| Blok | Sesije | Sati | Bodovi |
|---|---|---|---|
| Temelji + korak 2 | 0-1 | 2-3 | uslov |
| Korak 3 | 2-6 | 11-15 | 50 |
| Korak 4 | 7 | 3-4 | +15 |
| Korak 5 | 8 | 2-3 | +15 |
| Korak 6 | 9 | 2-3 | +10 |
| Korak 7 | 10 | 2-4 | +10 |
| Odbrana | 11 | 1-2 | — |
| **Ukupno** | | **~25-34 h** | **100** |

## Pravila rada

1. Ne preskakati korak — bodovanje to izričito traži i asistent proverava redosled.
2. Svaka sesija se zatvara pokrenutom simulacijom, ne napisanim fajlom.
3. `Napredak.md` se ažurira na kraju svake sesije (šta je gotovo, šta je sledeće).
4. DUT (VHDL) se ne menja. Ako verifikacija nađe pravu grešku — zapisati je, ne
   ćutke popraviti.
5. Xcelium je na udaljenoj mašini — kod se piše simulator-agnostično i sa
   relativnim putanjama, da prenos na remote u Sesiji 10 bude samo kopiranje.
