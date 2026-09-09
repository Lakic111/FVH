---
tags: [fvh, vezba]
---

# Vezba 09 - Hijerarhija UVM verifikacionog okruženja

## Ključni koncepti

- **`uvm_agent`** grupiše tri standardne komponente — `driver`, `sequencer`, `monitor` — preko TLM konekcija, plus opcioni konfiguracioni objekat (`*_config`). Agent radi u dva režima, kontrolisano poljem `is_active` tipa `uvm_active_passive_enum` (`UVM_ACTIVE` / `UVM_PASSIVE`):
  - **Aktivni agent** — u `build_phase` kreira i `driver` i `sequencer` (pored `monitor`-a), u `connect_phase` spaja `drv.seq_item_port` na `seqr.seq_item_export`. Koristi se kad agent generiše stimulus na DUT.
  - **Pasivni agent** — kreira samo `monitor`. Koristi se kad je agent samo posmatrač (npr. deo šireg okruženja gde stimulus dolazi odnekud drugde), pri čemu monitor mora biti potpuno nezavisan od drajvera.
- **Konfiguracija preko `uvm_config_db`** — konfiguracioni objekat (npr. `calc_config extends uvm_object`, sa `is_active` poljem markiranim `` `uvm_field_enum ``) se kreira na višem nivou hijerarhije (test), postavlja u bazu (`uvm_config_db#(calc_config)::set(this, "*", "calc_config", cfg)`) i preuzima u `build_phase` svake podkomponente (`get(...)`, uz `` `uvm_fatal("NOCONFIG", ...) `` ako nije postavljen). Isti mehanizam se koristi za virtuelni interfejs (`virtual calc_if vif`).
- **Hijerarhija `uvm_env`** — dva nivoa:
  - **Blok nivo** (`environment` klasa nasleđuje `uvm_env`) — grupiše sve agente za ponovnu upotrebu (npr. master/slave agenti za neki protokol), sadrži svoju konfiguracionu klasu, izlaže parametre umesto da korisnik mora znati unutrašnju strukturu. Ovakve komponente se zovu **UVC** (UVM Verification Component) — klasičan primer ponovne upotrebe (npr. AXI, UART, SPI UVC).
  - **Top-level okruženje** — najviši nivo, obično instanciran direktno u `test`-u; sadrži env, ali i komponente koje se ne ponavljaju po instanci: **scoreboard**, globalni monitori, prikupljači pokrivenosti (coverage collector), globalna konfiguracija.
- Test klasa (`uvm_test`) je vrh hijerarhije: bira konfiguraciju, kreira `env`, pokreće sekvence preko `sequencer`-a.
- **Factory override** — UVM factory je `lookup` tabela; `<type>::type_id::create(<name>, <parent>)` prolazi kroz factory umesto direktnog `new()`. Dve funkcije za zamenu:
  - `set_type_override(<substitute>::get_type(), replace=1)` — menja SVE instance datog tipa (i buduće kreacije) drugim tipom (nasleđenim).
  - `set_inst_override(<substitute>::get_type(), <path_string>)` — menja samo JEDNU instancu na tačno određenoj putanji u hijerarhiji (npr. `"uvm_test_top.env.agent"`).
  - Radi i za komponente (`uvm_component`) i za objekte (`uvm_object`, npr. sequence item-e) — mehanizam identičan, zasnovan na polimorfizmu (izvedeni tip mora naslediti originalni).

## Kod / primeri

```systemverilog
// calc_agent — aktivni/pasivni agent, kreiranje po is_active flagu
function void build_phase(uvm_phase phase);
  mon = calc_monitor::type_id::create("mon", this);
  if (cfg.is_active == UVM_ACTIVE) begin
    drv  = calc_driver::type_id::create("drv", this);
    seqr = calc_sequencer::type_id::create("seqr", this);
  end
endfunction
```
Monitor se kreira uvek; driver/sequencer samo u aktivnom režimu — ovo je obrazac koji vredi ponoviti u svakom agentu.

```systemverilog
// Factory override primer (iz vezbe) — zamena tipa A sa A_ovr svuda u env-u
A::type_id::set_type_override(A_ovr::get_type(), 1);
B::type_id::set_type_override(B_ovr::get_type(), 1);
```
Ovo se poziva u `test::build_phase` PRE `env::type_id::create`, tako da svaka naredna `create` poziv unutar env-a vraća override-ovan tip bez izmene koda env-a.

```systemverilog
// alternativa "default sequence" preko config_db (umesto ručnog start() u testu)
uvm_config_db#(uvm_object_wrapper)::set(this,
    "seqr.main_phase", "default_sequence", calc_simple_seq::type_id::get());
```

## Primena na NCC akcelerator projekat

Projekat ima **dva nezavisna spoljna interfejsa** DUT-a `ncc_accel` (AXI4-Lite S00 za kontrolne registre, AXI4-Full S01 za memorije), pa prirodna dekompozicija na agente je:

- **`axil_agent`** (aktivni) — drajvira write/read transakcije na AXI-Lite: piše `REG_IMG_W/H`, `REG_TMP_W/H`, `REG_IMG_ADDR`, `REG_TMP_ADDR`, `REG_CTRL` (start bit), čita `REG_STATUS` (busy/done_sticky) i `ADDR_RESULTS`. Sequencer generiše sekvence "konfiguriši pa startuj" i directed testove za poznati bug (AW/W ordering — `W` pre `AW`, `AW` pre `W`, simultano).
- **`axif_agent`** (aktivni) — piše sliku i template u odgovarajuće offsete (image @ +0x00000, template @ +0x08000) i čita rezultate iz +0x10000 regiona preko burst transakcija (koristeći postojeće VHDL testbench-eve `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb` kao referencu za scenarije).
- Oba agenta se grupišu u jedan **`ncc_env` (uvm_env)** koji dodatno sadrži **scoreboard** i **coverage collector** — po uzoru na `Slika 3` iz vezbe (APB+SPI agent + scoreboard + coverage u jednom env-u, DUT sa strane).
- Pošto sistem ima **2× `ncc_accel`** (dva IP core-a na istom AXI interconnect-u), horizontalna ponovna upotreba iz ove vežbe je direktno primenjiva: isti `axil_agent`/`axif_agent` par se instancira dvaput (`inst0`, `inst1`) sa različitim baznim adresama preko konfiguracionog objekta (`ncc_config` sa poljem `base_addr`), umesto pisanja dva puta istog koda.
- **Factory override** je koristan za bug-regresione testove: npr. override `axil_driver` sa `axil_driver_w_first` koji namerno šalje `W` pre `AW` da se testira fiksovani corner case, bez diranja ostatka okruženja (`set_inst_override` ciljano na taj agent).
- Test klasa treba da postavi `is_active = UVM_ACTIVE` za oba agenta u normalnim testovima, ali `UVM_PASSIVE` za scenarije gde se AXI transakcije injektuju direktno kroz Vivado XSim debug/monitor bez drajvovanja (npr. reuse istog monitora za hardversku validaciju na Zybo ploči).
