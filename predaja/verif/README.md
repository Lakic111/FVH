# FVH — UVM verifikaciono okruženje za `ncc_accel`

DUT je VHDL IP `ncc_accel` (AXI4-Lite S00 za kontrolne registre i AXI4-Full S01
za memorije). Okruženje je napisano u SystemVerilog/UVM-u i pokreće se u
**Vivado XSim-u** ili u **Cadence Xcelium-u** istim skriptama.

## Struktura

```
verif/
├── rtl/                      VHDL izvori DUT-a (zamrznuta kopija)
├── rtl.f                     spisak VHDL izvora
├── tb.f                      spisak SV izvora i +incdir+ direktorijuma
├── src/
│   ├── ncc_verif_pkg.sv      zajednički parametri (adrese, širine, ograničenja)
│   ├── interfaces/           axi_lite_if.sv, axi_full_if.sv (uz SVA tvrdnje)
│   ├── axil_agent/           S00 agent — ncc_axil_pkg.sv uključuje:
│   │   ├── ncc_reg_item.sv            sekvencijalna stavka
│   │   ├── ncc_axil_sequencer.sv      sekvencer
│   │   ├── ncc_axil_driver.sv         drajver
│   │   ├── ncc_axil_monitor.sv        monitor
│   │   ├── ncc_axil_agent_config.sv   konfiguracija
│   │   ├── ncc_axil_agent.sv          agent
│   │   └── sequences/                 ncc_axil_base_seq.sv, ncc_reg_rw_seq.sv
│   ├── axif_agent/           S01 agent — ncc_axif_pkg.sv, isti raspored kao S00
│   ├── ref_model/            ncc_ref_pkg.sv — referentni model NCC² (bit-tačan)
│   ├── env/                  ncc_env_pkg.sv uključuje:
│   │   ├── ncc_scoreboard.sv
│   │   ├── ncc_coverage.sv
│   │   ├── ncc_virtual_sequencer.sv
│   │   └── ncc_env.sv
│   └── sequences/            ncc_seq_pkg.sv — virtuelne sekvence (smoke, cov,
│                             dim_sweep, random), svaka u svom fajlu
├── tests/                    ncc_test_pkg.sv + jedan fajl po testu
├── tb/tb_top.sv              takt, reset, DUT, virtuelni interfejsi
└── sim/                      skripte za pokretanje (vidi dole)
```

Svaka klasa je u svom fajlu. Paket (`*_pkg.sv`) samo uvozi zavisnosti i
`` `include ``-uje svoje klase, zato su direktorijumi paketa navedeni u `tb.f`
kao `+incdir+`.

## Pokretanje

Skripte se pokreću iz bilo kog direktorijuma. Na Linuxu rade u bash-u, a na
Windows-u u Git Bash-u. Nijedna putanja nije zakucana: sve se računa u odnosu
na `verif/`, a alati se traže u okruženju.

### Vivado XSim

Vivado se pronalazi automatski, ovim redom:

1. `XILINX_BIN`, ručno zadat `bin/` direktorijum;
2. `XILINX_VIVADO`, koji postavlja Vivado `settings64.sh`;
3. `PATH`;
4. uobičajene instalacije (`/tools/Xilinx`, `/opt/Xilinx`, `C:/Xilinx`,
   `C:/AMDDesignTools`), i to najnovija verzija.

```bash
source /putanja/do/Vivado/settings64.sh     # preporučeno na Linuxu

./sim/run_xsim.sh                            # elaboracija + ncc_smoke_test
./sim/run_xsim.sh ncc_random_test 7          # drugi test, seed 7

./sim/regress.sh                             # cela regresija: 7 testova + 20 seed-ova
./sim/regress.sh brza                        # samo brza lista (5 testova)
SEEDS=5 ./sim/regress.sh                     # manje seed-ova za slučajni test
./sim/coverage.sh                            # izveštaj pokrivenosti (xcrg), posle regresije
```

### Cadence Xcelium

`xrun` mora biti u `PATH`-u (na fakultetskoj mašini: `. amsgo`) ili zadat kroz
`XRUN=/putanja/do/xrun`.

```bash
SIM=xrun ./sim/regress.sh                    # ista regresija, isti testovi
./sim/build_xrun.sh && ./sim/run_one_xrun.sh ncc_smoke_test 1
COV=0 SIM=xrun ./sim/regress.sh              # bez pokrivenosti (ako nema licence)
```

Bez izvršnog bita (na primer posle raspakivanja zip-a) skripta se pokreće sa
`bash sim/regress.sh`.

### Skripte

| Skripta | Šta radi |
|---|---|
| `sim/common.sh` | zajedničke funkcije: koren `verif/`, čitanje filelist-a, pronalaženje Vivado alata |
| `sim/build.sh` | XSim: `xvhdl -2008` → `xvlog -sv -L uvm` → `xelab`, jednom za sve testove |
| `sim/run_one.sh <test> [seed]` | XSim: jedan test nad gotovim snimkom, ispisuje PASS/FAIL |
| `sim/run_xsim.sh [test] [seed]` | `build.sh` + `run_one.sh` |
| `sim/regress.sh [sve\|brza\|spora]` | cela regresija; `SIM=xsim\|xrun`, `SEEDS=N` |
| `sim/coverage.sh [text\|html]` | spaja baze pokrivenosti svih pokretanja (`xcrg`) |
| `sim/build_xrun.sh`, `sim/run_one_xrun.sh` | Xcelium parnjaci `build.sh` i `run_one.sh` |
| `sim/xrun_run.tcl` | Xcelium: TRRANGEC u Xilinx AXI šablonu spušta na upozorenje |

Izlazi se upisuju u `result/` (logovi u `result/run/`, pokrivenost u `result/cov/`).

## Testovi

| Test | Šta dokazuje |
|---|---|
| `ncc_vif_test` | virtuelni interfejsi stižu kroz `uvm_config_db`, DUT miruje |
| `ncc_axil_smoke_test` | S00 upis/čitanje, sva tri AW/W redosleda |
| `ncc_axil_agent_test` | monitor rekonstruiše ono što je drajver poslao |
| `ncc_axif_smoke_test` | S01 paketni prenos, dužine 1, 2, 3 i 16 |
| `ncc_smoke_test` | ceo put kroz jezgro + scoreboard |
| `ncc_cov_test` | brza lista za pokrivenost |
| `ncc_dim_sweep_test` | sve kombinacije bin-ova dimenzija (spora lista) |
| `ncc_random_test` | slučajna pobuda, menja se sa seed-om |

Testovi su poređani od najmanjeg ka najvećem, pa prvi koji padne pokazuje gde je
problem: ako padne već `ncc_vif_test`, greška je u elaboraciji ili povezivanju,
a ne u verifikacionom kodu.

Očekivani ishod regresije na oba simulatora: **27 prošlo, 0 palo**, a
funkcionalna pokrivenost posle spajanja svih baza je **100%**.
