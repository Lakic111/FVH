---
tags: [fvh, predavanje]
---

# Predavanje 10-11 - Praćenje toka verifikacije

## Ključni koncepti
- Centralno pitanje verifikacionog tima: "Kada je verifikacija završena?" Iscrpna (exhaustive) simulacija nije izvodljiva čak ni za trivijalne dizajne - primer: 16-bitni sabirač bi zahtevao 4 milijarde ciklusa, ~50 dana pri 1000 ciklusa/s.
- **Verifikaciona pokrivenost** je mera prostora stanja koji je simulacija obuhvatila; cilj analize pokrivenosti nije da dokaže potpunost (nedostižno), već da ubedi tim da je izvršena *dovoljna* verifikacija prema definisanim kriterijumima kvaliteta. Pokrivenost ne meri kvalitet/robusnost provera (checking) - samo obuhvat.
- Dve komplementarne oblasti pokrivenosti: **pokrivenost verifikacionih testova** (koliko dobro stimulus pokriva specifikaciju dizajna) i **pokrivenost implementacije** (koliko dobro stimulus aktivira/testira konkretnu implementaciju specifikacije u datom dizajnu).
- Analiza pokrivenosti treba da bude definisana kao zadatak maksimizacije verovatnoće izazivanja i detekcije grešaka uz minimalne troškove (vreme, rad, resursi) - broj pronađenih skrivenih grešaka je prava mera kvaliteta analize pokrivenosti, ne sam procenat pokrivenosti.

### Strukturna (kodna) pokrivenost
- Implicitna, automatski generisana iz HDL koda - ne zahteva poseban kod ni pristup. Tipovi:
  - **Toggle coverage** - koliko puta je svaki signal/leč promenio logičku vrednost; jednostavno ali generiše ogromnu količinu podataka bez funkcionalnog značaja; napredniji alati prate i tranzicije ka/od X i Z.
  - **Line coverage** - koje linije HDL koda su izvršene; lako razumljivo ali bez semantičkog uvida.
  - **Statement (expression) coverage** - precizniji od line coverage jer jedan izraz može zauzimati više linija i obrnuto.
  - **Branch (conditional) coverage** - da li su grane uslovnih konstrukcija (if/case/while/for/repeat/forever) izvršene i kao tačne i kao netačne.
  - **Path coverage** - precizniji od branch coverage; prati kombinacije uzastopnih odluka kao izvršne putanje (branch coverage može pokazati da su sve grane pokrivene, a path coverage otkriti da jedna kombinacija puteva nikad nije izvršena).
  - **Condition (expression) coverage** - da li je svaki operand Bulovog izraza evaluiran i kao true i kao false; stroža varijanta je **exclusive condition coverage** (kontrolišući član - jedini uzrok rezultata izraza).
  - **FSM coverage** - state coverage (da li je svako stanje posećeno), arc coverage (da li su svi prelazi između susednih stanja viđeni), sequential/transition coverage (nizovi prelaza date dužine).
  - Napomena: novije verzije Vivada ne podržavaju analizu strukturne pokrivenosti - potreban je drugi alat (npr. Xcelium).

### Funkcionalna pokrivenost
- Eksplicitna, ne postoji automatizovan način kreiranja modela - mora poteći od iskustva dizajnera/verifikacionog inženjera koji poznaju semantiku dizajna i delove sklone greškama.
- Funkcionalni zahtevi se nameću na ulaze, izlaze i njihove međusobne odnose. Stepen do kog model pokrivenosti obuhvata stvarne zahteve naziva se **verodostojnost (fidelity)** modela.
- **Koraci u dizajnu modela funkcionalne pokrivenosti**:
  1. Opisati semantiku modela (priča na prirodnom jeziku - šta se modeluje).
  2. Definisati **atribute** (događaje pokrivenosti) i njihove moguće vrednosti - najbolje kroz brainstorming sesiju sa inženjerima i dizajnerima.
  3. Specificirati **odnose (relacije)** među atributima i **vreme korelacije** (trenutak kad više atributa učestvuje zajedno u logici odlučivanja uređaja).
- Pravila za vreme uzorkovanja atributa: ne uzorkovati češće nego što se vrednost ažurira; ne uzorkovati češće nego frekvencija interakcije sa drugim atributima (inverzna vrednost vremena korelacije).
- **Tri strukture odnosa atributa**:
  - **Matrični model** - svaki atribut je dimenzija matrice, tačka = kombinacija vrednosti svih atributa; najmanje napora za implementaciju zbog simetrije, ali eksplodira za veliki broj kombinacija (preporuka: koristiti dok je < ~1000 tačaka i malo nevažećih kombinacija; iznad ~100.000 tačaka ili mnogo nevažećih kombinacija - preći na hijerarhijski/hibridni).
  - **Hijerarhijski model** - obrnuto stablo, primarni kontrolni atribut u korenu, svaki niži nivo dodaje atribut; više napora za dizajn (moraju se nabrojati specifični odnosi), ali precizno modeluje neregularne odnose i značajno smanjuje veličinu modela.
  - **Hibridni model** - kombinacija matričnih podregiona (regularni delovi) i hijerarhijskih regiona (neregularni delovi); napor uporediv sa hijerarhijskim.
- **Detaljan dizajn (mapiranje na okruženje)** - tri pitanja: šta se uzorkuje (mapiranje polja/signala/registara na atribute), gde se uzorkuje (koja komponenta u okruženju), kada se uzorkuje i korelira (koji događaj).
- **Uzorkovanje atributa preko monitora**:
  - Ulazni atributi - monitor na primarnim ulazima uređaja, uzorkuje u validnim vremenskim trenucima definisanim specifikacijom; monitor NE sme preuzimati podatke direktno iz generatora stimulusa (ugrožava mogućnost ponovne upotrebe monitora na sledećem nivou hijerarhije verifikacije).
  - Izlazni atributi - monitor na primarnim izlazima uređaja.
  - Interni atributi - monitor na unutrašnjim signalima/registrima DUV-a; ovi signali nisu formalno specificirani pa uzorkovanje treba minimizirati i uskladiti sa timom za dizajn (definisati fiksni "verifikacioni interfejs" skup signala koji se retko menja, tretira se kao zamrznut eksterni interfejs).
  - Poseban "Coverage" blok (odvojen od generičkog "Monitor" bloka koji služi i za checking) je isključivo odgovoran za beleženje funkcionalne pokrivenosti.
- Analiza sakupljenih podataka: **izveštaj o statusu** (trenutni snapshot ukupno zabeleženih događaja) i **izveštaj o napretku** (kriva rastućeg zbira događaja tokom vremena simulacije, tipično asimptotska - rani događaji se lako dostižu, kasniji zahtevaju sve više truda/podešavanja stimulusa).

## Kod / primeri
Primer modela pokrivenosti za "Calc1" dizajn (matrični model, dva atributa: port {1,2,3,4} × tip komande {No-op, Add, Subtract, Shift left, Shift right, Illegal}) - sve kombinacije su legalne pa je matrični model prirodan izbor; vreme uzorkovanja i korelacije = period sistemskog takta. Cilj: pokriti sve ćelije ukrštenog proizvoda = dokaz da je drajver generisao svaku komandu (uključujući ilegalnu) bar jednom na svakom portu.

Primer hijerarhijskog modela: 3 atributa A (4 vrednosti), B (3 vrednosti), C (4 vrednosti) definišu ukupno 10 tačaka (ne 4×3×4=48) jer relacije nisu potpuno permutovane - trojka (An,Bm,Ck) definiše tačku, npr. p7 = (A2,B0,C2).

## Primena na NCC akcelerator projekat
Ovo predavanje je primarni izvor za tačke 5 (Coverage, 15 poena) i 6 (Regresija, 10 poena) iz kriterijuma ocenjivanja FVH projekta.

**Model funkcionalne pokrivenosti za NCC treba definisati kroz iste tri komponente:**
- **Atributi (ulaz)**: REG_IMG_W, REG_IMG_H, REG_TMP_W, REG_TMP_H (vrednosti: min, tipične za šahovsku tablu/polje, max koji staje u 128KB region na S01), REG_IMG_ADDR/REG_TMP_ADDR (poravnanje/opseg unutar 0x00000-0x08000-0x10000), REG_CTRL.bit0 (start impuls dok je busy=0 vs busy=1), redosled AW/W tranzakcija na S00 i S01 (poznat fiksiran hardverski bug - odličan atribut za directed + regresioni coverage).
- **Atributi (izlaz)**: REG_STATUS.bit0 (done_sticky) tranzicije, REG_STATUS.bit1 (busy) tranzicije, vrednosti pročitane sa ADDR_RESULTS.
- **Atributi (interni, opciono)**: stanje FSM-a u `ncc_core.vhd` (23 stanja) i status `seq_divider`-a - ako se odluči da se prati, treba definisati kao "zamrznut verifikacioni interfejs" u dogovoru sa (već završenim) PSDS dizajnom.
- **Odnosi**: matrični model je prirodan za par (REG_IMG_W/H opseg) × (REG_TMP_W/H opseg) - male dimenzije, sve kombinacije legalne/ilegalne su interesantne. Cross AW/W-redosled × registar/memorijski region (S00 vs S01, image/template/results) je takođe matrični, malog obima. Za FSM state/arc coverage prirodnije je koristiti alatom generisanu FSM coverage (strukturna pokrivenost), ne ručni model.
- **Mesto uzorkovanja**: AXI-Lite monitor (na S00 interfejsu, ulazni atributi = upisi u registre) i AXI-Full monitor (na S01, ulazni/izlazni atributi = burst pristupi memoriji) - odvojeni "Coverage" collector blokovi od monitora koji rade checking, po preporuci sa slajdova. Monitor NE sme čitati iz sequence/driver-a direktno, radi ponovne upotrebljivosti (npr. isti monitor može poslužiti i na nivou sistema `ncc_system` sa 2× `ncc_accel`).
- **Vreme uzorkovanja**: na kraju svake AXI transakcije (sample() eksplicitno iz monitora), ne na svaki takt - u skladu sa preporukom da se ne uzorkuje češće nego što se vrednost ažuruje.
- **Regresija**: koristiti postojeće golden VHDL testbench-ove (`ncc_core_tb`, `ncc_core_real_tb`, `ncc_accel_tb`, `ncc_accel_burst_tb`, `ncc_accel_wfirst_tb`, `ncc_accel_s01_burst_wfirst_tb`) kao osnovu za regresioni skup i/ili referentni model scoreboard-a; puštati sa nasumičnim seed-ovima (detalji u [[Vezba 12 - Regresija i proces debagovanja]]) i pratiti krivu napretka pokrivenosti (izveštaj o napretku) da se identifikuje kada dodatni testovi prestaju da otkrivaju nove bin-ove/greške - to je argument za "dovoljnu" (ne iscrpnu) verifikaciju u dokumentaciji plana verifikacije.
- **Dvostruko izvršavanje (Vivado XSim + Xcelium)**: strukturnu pokrivenost raditi u Xcelium-u (Vivado je ne podržava u novijim verzijama), a funkcionalni coverage model paralelno prikupljati i prikazivati preko `xcrg` u Vivadu (vidi [[Vezba 11 - Prikupljanje pokrivenosti]]) i odgovarajućim IMC/urg alatom u Xcelium-u, radi ispunjenja stavke 7 iz kriterijuma ocenjivanja.

Vidi i [[Vezba 11 - Prikupljanje pokrivenosti]] i [[Vezba 12 - Regresija i proces debagovanja]].
