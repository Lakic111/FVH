# FVH — UVM verifikaciono okruženje za `ncc_accel`

DUT je VHDL IP `ncc_accel`: AXI4-Lite S00 (kontrolni registri) i AXI4-Full S01
(memorije slike, šablona i rezultata). Okruženje radi u Vivado XSim-u i u Cadence Xcelium-u.

## Fajlovi

```
verif/
├── rtl/                 VHDL izvori DUT-a (ne menjaju se)
├── sv/
│   ├── ncc_if.sv          interfejs sa signalima obe magistrale
│   ├── ncc_pkg.sv         konstante, tipovi i `include svih klasa
│   ├── ncc_item.sv        transakcija (S00 ili S01, upis ili čitanje)
│   ├── ncc_config.sv      konfiguracija agenta (is_active)
│   ├── ncc_sequencer.sv   sekvencer
│   ├── ncc_driver.sv      drajver za obe magistrale
│   ├── ncc_monitor.sv     monitor + pokrivenost (3 covergroup-e)
│   ├── ncc_agent.sv       agent
│   ├── ncc_scoreboard.sv  scoreboard + referentni model NCC²
│   ├── ncc_env.sv         okruženje (agent + scoreboard)
│   ├── ncc_sequences.sv   osnovna, smoke, cov i random sekvenca
│   ├── ncc_tests.sv       test_base, test_smoke, test_cov, test_random
│   └── ncc_top.sv         takt, reset, DUT, run_test()
├── run.f                spisak izvornih fajlova
└── regresija.sh         prevođenje, svi testovi i izveštaj pokrivenosti
```

Jedan agent vozi obe magistrale: polje `bus` u transakciji kaže da li ide na S00 ili S01,
pa sekvenca na istom sekvenceru meša upise u registre i memoriju.

## Testovi

| Test | Šta radi |
|---|---|
| `test_smoke` | slika 4×4, šablon 2×2, pik `0x80000000` mora biti na (1,1) |
| `test_cov` | usmereni slučajevi: sve dimenzije, dužine burst-a, WSTRB, sve oblasti S01 u sva tri redosleda AW/W, upis u CTRL dok jezgro radi |
| `test_random` | slučajne dimenzije i podaci, menja se sa seed-om |

Scoreboard poredi svaki pročitani rezultat sa referentnim modelom.

## Pokretanje

```bash
./regresija.sh             # Vivado XSim: test_smoke, test_cov, test_random x 20 seed-ova
./regresija.sh 5           # 5 seed-ova
SIM=xrun ./regresija.sh    # Cadence Xcelium (xrun mora biti u PATH-u)
```

Putanja do Vivada se zadaje sa `VIVADO=<Vivado>/bin`; ako nije zadata, koristi se
`C:/AMDDesignTools/2025.2/Vivado/bin`. Logovi idu u `result/log/`, izveštaj
pokrivenosti u `result/izvestaj/`.

Rezultat na XSim-u: 22 prošla, 0 palo, pokrivenost 100%.
