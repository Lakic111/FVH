# FVH — UVM verifikaciono okruženje za `ncc_accel`

DUT je VHDL IP `ncc_accel`: AXI4-Lite S00 (kontrolni registri) i AXI4-Full S01
(memorije slike, šablona i rezultata). Okruženje radi u Vivado XSim-u i u Cadence Xcelium-u.

## Fajlovi

```
├── dut/                       VHDL izvori DUT-a (ne menjaju se)
├── verif/
│   ├── axil_if.sv, axif_if.sv   po jedan interfejs za S00 i S01
│   ├── Configurations/          ncc_config (is_active), konstante i tipovi
│   ├── Axil_agent/              S00: item, sequencer, driver, monitor, agent
│   ├── Axif_agent/              S01: item, sequencer, driver, monitor, agent
│   ├── Sequences/               write/read sekvence za svaki agent; smoke, cov, random
│   ├── ncc_scoreboard.sv        dva ulaza (port_axil, port_axif) + referentni model NCC²
│   ├── ncc_env.sv               oba agenta i scoreboard
│   ├── test_base.sv, test_smoke.sv, test_cov.sv, test_random.sv
│   ├── ncc_test_pkg.sv
│   └── ncc_verif_top.sv         takt, reset, interfejsi, DUT, run_test()
├── run.f                      spisak izvornih fajlova
└── regression.sh              prevođenje, svi testovi i izveštaj pokrivenosti
```

Svaka magistrala ima svoj agent. Pošto jedan posao prelazi preko obe magistrale,
`ncc_base_seq` dobija oba sekvencera i redom pokreće korake (upis, start, čekanje,
čitanje) na sekvenceru magistrale kojoj pripadaju.

## Testovi

| Test | Šta radi |
|---|---|
| `test_smoke` | slika 4×4, šablon 2×2, pik `0x80000000` mora biti na (1,1) |
| `test_cov` | usmereni slučajevi: sve dimenzije, dužine burst-a, WSTRB, sve oblasti S01 u sva tri redosleda AW/W, upis u CTRL dok jezgro radi |
| `test_random` | slučajne dimenzije i podaci, menja se sa seed-om |

## Pokretanje

```bash
./regression.sh             # Vivado XSim: test_smoke, test_cov, test_random x 20 seed-ova
./regression.sh 5           # 5 seed-ova
SIM=xrun ./regression.sh    # Cadence Xcelium (xrun mora biti u PATH-u)
```

Putanja do Vivada se zadaje sa `VIVADO=<Vivado>/bin`; ako nije zadata, koristi se
`C:/AMDDesignTools/2025.2/Vivado/bin`. Logovi idu u `result/log/`, izveštaj
pokrivenosti u `result/report/`.

Rezultat: 22 prošla, 0 palo, u XSim-u i u Xcelium-u; funkcionalna pokrivenost 100%.
