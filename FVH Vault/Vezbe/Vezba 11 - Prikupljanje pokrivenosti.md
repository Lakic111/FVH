---
tags: [fvh, vezba]
---

# Vežba 11 - Prikupljanje pokrivenosti

## Ključni koncepti
- Dve osnovne coverage metrike: **strukturna (code coverage)** - implicitna, automatski se kreira iz RTL-a (toggle, line, statement, block, branch, expression, FSM coverage); i **funkcionalna (functional coverage)** - eksplicitna, mora je ručno definisati verifikacioni inženjer.
- 100% strukturne pokrivenosti ne dokazuje ispravnost - može postojati aktivirana linija sa greškom čiji efekat nije propagiran do provere, ili neverifikovana funkcionalnost koja uopšte nije ni implementirana.
- U SystemVerilogu se funkcionalna pokrivenost implementira kroz dve konstrukcije: **cover groups** (uzorkovanje vrednosti promenljivih/izraza u trenutku) i **cover properties** (temporalne osobine, npr. handshake req→ack) - kurs se fokusira na cover groups.
- `covergroup ... endgroup` je tip (kao klasa), instancira se pozivom `new()` - čest propust je zaboraviti `new()`, tada se grupa tiho ne pojavljuje u izveštaju (nema greške).
- U UVM okruženju se covergroup-ovi obično kreiraju unutar monitora, scoreboard-a ili posebnih coverage collector komponenti - na odgovarajućem hijerarhijskom nivou.
- **Trigerovanje** uzorkovanja: ili vezano za `@(event)` u definiciji grupe, ili eksplicitnim pozivom `cg.sample()` u bilo kom trenutku (npr. iz monitora na kraju transakcije).
- **Coverpoint** = promenljiva/izraz čije se vrednosti prate kroz **bin**-ove. Automatski (implicitni) bin-ovi: SystemVerilog kreira 2^N bin-ova za N-bitni izraz do granice `auto_bin_max` (podrazumevano 64), preko toga ravnomerno grupiše opsege - loše za analizu, zato se preporučuju **eksplicitni bin-ovi** sa imenima i opsezima (`bins low = {0,50}; bins high = {151,255};`).
- `ignore_bins` - vrednosti koje se ne broje u pokrivenost (nikad se ne mogu desiti). `illegal_bins` - vrednosti koje NE smeju da se dese; ako se dese, alat prijavljuje grešku (iako je bolje takve provere raditi u monitoru/scoreboard-u).
- **Cross coverage** (`cross cp1, cp2`) - pokrivenost kombinacija dve ili više coverpoint promenljivih (npr. adresa × read/write). Broj automatskih bin-ova = N×M, brzo eksplodira → koristiti `binsof(...) intersect {...}` da ograničiš na relevantne kombinacije, uz `ignore_bins`.
- Opcije grupe: `option.per_instance = 1` (čuva podatke po instanci, bez ovoga QuestaSim/većina alata ne prikazuje pojedinačne bin-ove), `option.goal` (podrazumevano 90), `option.at_least` (min broj pogodaka da se bin smatra pokrivenim), `option.weight`, `option.auto_bin_max`.
- U Vivadu se coverage izveštaj generiše `xcrg` alatom (Xilinx Coverage Report Generator) posle simulacije: `xcrg -report_format html -dir xsim -report_dir <putanja>`, generiše `dashboard.html` sa pregledom svih cover grupa i procentom pokrivenosti. Napomena: novije verzije Vivada ne podržavaju analizu strukturalne pokrivenosti - za nju treba drugi alat (npr. Xcelium).

## Kod / primeri
```systemverilog
covergroup memory @ (posedge en);
   option.per_instance = 1;
   address : coverpoint addr {
      bins low  = {0,50};
      bins med  = {51,150};
      bins high = {151,255};
   }
   parity : coverpoint par {
      bins even = {0};
      bins odd  = {1};
   }
   read_write : coverpoint rw {
      bins read  = {0};
      bins write = {1};
   }
endgroup
memory mem = new();
```
Grupa se okida na `posedge en` (trenutak kada je transakcija validna), tri coverpointa prate opseg adrese, paritet i tip pristupa.

```systemverilog
cx_addr_dir : cross cp_address, cp_dir {
   bins read_addr  = binsof(cp_dir) intersect {0};
   bins write_addr = binsof(cp_dir) intersect {1};
}
```
`intersect` ograničava eksploziju cross bin-ova na relevantne kombinacije.

xcrg poziv iz .tcl konzole:
```
xcrg -report_format html -dir <putanja do xsim direktorijuma> -report_dir <putanja do izveštaja>
```

## Primena na NCC akcelerator projekat
Coverage collector (ili monitor) na AXI-Lite S00 treba covergroup nad transakcijama upisa u registre, sa coverpoint-ima koji prate stvarne granice ovog dizajna:
- **REG_IMG_W / REG_IMG_H / REG_TMP_W / REG_TMP_H** (0x00-0x0C): bin-ovi za minimalnu, tipičnu i maksimalnu veličinu slike/šablona koju `ncc_core` FSM podržava (npr. 1, tipična dimenzija šahovske table/polja, i granična vrednost koja stane u 128KB BRAM region), plus `illegal_bins` za dimenzije koje bi prepunile memorijski prostor (image @ +0x00000..0x08000, template @ +0x08000..0x10000).
- **REG_CTRL bit0 (start)** cross **REG_STATUS bit1 (busy)**: coverpoint koji hvata da li je `start` upisan dok je `busy=1` (write-while-busy) vs `busy=0` - ovo je direktno testiranje da FSM ignoriše/ne remeti tekuću operaciju.
- **REG_STATUS bit0 (done_sticky)**: coverpoint na tranzicije `0→1` (kraj obrade) i na to da li je sticky bit ostao `1` posle sledećeg `start` dok se eksplicitno ne pročita/resetuje - bitno za FSM sa 23 stanja u `ncc_core.vhd`.
- **AW/W redosled na AXI-Lite S00 i AXI-Full S01**: coverpoint `{AW_first, W_first, simultaneous}` za svaki write kanal - poznati fiksirani hardverski bug (hang kad W stigne pre AW) je odličan cross coverage cilj: cross ovog coverpointa sa registrom koji se upisuje (S00) odnosno regionom memorije (S01: image/template/results).
- **Burst dužine na S01** (AXI4-Full, 128KB region): coverpoint na `AxLEN` vrednosti korišćene u postojećim testbench-ovima (`ncc_accel_burst_tb`, `ncc_accel_s01_burst_wfirst_tb`) - bin-ovi za single-beat, kratke i maksimalne burst-ove, cross sa regionom (image/template/results, offset +0x00000/+0x08000/+0x10000).
- FSM coverage (state/arc) nad 23 stanja `ncc_core` FSM-a i `seq_divider` (deljenje u NCC formuli) - state coverage da su sva stanja posećena, arc coverage za tranzicije oko `busy`/`done` granica.
- Cilj: covergroup treba da postoji na monitoru/scoreboard komponenti u FVH okruženju (AXI-Lite monitor za registre, AXI-Full monitor za memorijski pristup), `option.per_instance=1` da se vide pojedinačni bin-ovi u xcrg izveštaju, jer postoje 2× `ncc_accel` instance u `ncc_system`.

Vidi i [[Vezba 12 - Regresija i proces debagovanja]] i [[Predavanje 10-11 - Pracenje toka verifikacije]].
