---
tags: [fvh, predavanje]
---

# Predavanje 04 - Kreiranje verifikacionog okruženja

## Ključni koncepti

**1. HDL jezici i simulatori**
- HDL (VHDL, Verilog) služi i za opis DUT-a (design entry) i, kroz proširene konstrukcije, za pisanje testnog okruženja (stimulus + provera). IEEE standardi: VHDL 1076, Verilog 1364.
- Četiri dimenzije modelovanja: vremenska, apstrakcija podataka, funkcionalna, strukturna. VHDL naginje višim nivoima apstrakcije (korisnički tipovi, function overloading, records); Verilog ima ugrađen koncept `event` bez direktnog VHDL ekvivalenta (u VHDL-u se događaj modeluje kao promena vrednosti signala).
- Verifikacioni aspekti HDL-a: (a) logičke tvrdnje (assertions) i (b) HDL funkcionalnosti za testna okruženja — predavanje se fokusira na (b).

**2. HDL testna okruženja**
- Testno okruženje ima dva osnovna zadatka: generisanje stimulusa (drajveri) i provera interfejsa/unutrašnjeg stanja.
- Deljenje na najmanje dve particije (stimulus/provera) omogućava ponovnu upotrebu — npr. kad se dva verifikovana bloka integrišu u veći DUV, drajver jednog bloka može biti zamenjen susednim realnim delom dizajna, dok komponente za proveru ostaju.
- HDL kod testnog okruženja ne mora poštovati sintetizabilna ograničenja — koristi apstraktne tipove, zapise, višedimenzione nizove, file I/O, taskove, fork/join, dinamičku alokaciju (npr. za tabelu rezultata).
- Alternativa čistom HDL testbenču: programski jezik opšte namene preko API-ja simulatora (PLI/VPI/DPI stil), ili viši HVL.

**3. Simulacija vođena događajima (event-driven)**
- Model = mreža međusobno povezanih blokova, povezanih signalima/kanalima. Blok se aktivira kad se na njegovom ulazu pojavi događaj (promena signala).
- Centralna struktura: **time wheel** (kružna povezana lista) — svaki unos pokazuje na "to-do listu" zakazanih aktivnosti za dato simulaciono vreme; `current_model_time` pokazuje na trenutnu poziciju. Omogućava simulatoru da preskoči vremenske intervale bez zakazanih događaja.
- Dva ključna principa: evaluiraj ponašanje samo u trenucima sa zakazanim događajima, i samo za blokove/signale sa zakazanim događajima.
- Performanse zavise od granularnosti modela — previše krupni blokovi uzrokuju česta ponavljanja zakazivanja (povratne sprege), previše sitni (primitivni) blokovi uvećavaju broj aktivnosti zakazivanja; optimum je negde između.

**4. Simulacija na nivou takta (cycle-based)**
- Specijalizovana tehnika, brža od event-driven, ali ograničena na **sinhroni dizajn** (jasna podela na elemente sa stanjem — flip-flopovi/leč kola — i kombinacionu logiku bez povratnih sprega unutar sebe).
- Model se pretvara u **DAG** (usmereni aciklični graf) slojevitim uređivanjem (levelize) kombinacione logike počev od elemenata sa stanjem/ulaza. Nema potrebe za zakazivanjem — redosled evaluacije je unapred poznat iz pozicije u grafu.
- Ne modeluje vremenska kašnjenja signala (zero-delay), strogo ograničava sekvencijalne konstrukcije i ne podržava većinu naprednih HDL funkcionalnosti za testno okruženje — koristi se kad je brzina prioritet i dizajn potpuno sinhron.

**5. Kompromis brzina/preciznost**
- Viši nivo apstrakcije modela → brža simulacija (manje detalja za obradu). RTL simulacija je znatno brža od timing-aware simulacije na nivou logičkih kola (razlike faktora 5-10x u vremenu izvršavanja i veličini modela).

**6. HDL kao alat za testno okruženje — praktični obrasci**
- Standardna struktura: DUV instanca + monitor instanca + stimulus (stim) instanca + centralni `clk_gen` proces.
- Komponenta generatora čita test vektore iz datoteke (`Load_Patterns`/`$readmemh`) u niz, prosleđuje ih redom komponenti za stimulus; zaustavlja simulaciju kad ponestane obrazaca (`report ... severity failure` / `$finish`).
- **Parametrizacija**: izdvajanje ključnih parametara (npr. naziv datoteke sa test primerom) iz koda u konfiguraciju — omogućava skup testova (test case bucket) bez rekompajliranja.
- **Debug izlazi**: `report`/`write` (VHDL), `$monitor`/`$fmonitor` (Verilog) za ispis promena signala; trace datoteke ako ih simulator podržava.
- **Randomizacija (HDL nivo)**: Verilog ima `$random()`; VHDL nema ugrađenu podršku (rešava se preko paketa). Seed upravljanje je ključno za reproduktivnost — kod runtime randomizacije, seed treba centralizovano evidentirati i postavljati radi debagovanja i regresije.

**7. HVL (Hardware Verification Languages) — jezici visokog nivoa za verifikaciju**
- **SystemVerilog** — dominantan u industriji, objedinjuje HDL i HVL funkcije (dizajn + verifikacija), nativna podrška za assertions i OOP.
- **UVM** — biblioteka klasa u SystemVerilogu, industrijski standard za testna okruženja (Intel, Qualcomm, NVIDIA i sl.).
- **SystemC** — sistemski nivo, brzi referentni modeli; UVM-SystemC za balans performansi/preciznosti.
- **Python (cocotb)** — sve popularnija alternativa, brza izrada prototipova, integracija sa AI/ML alatima za generisanje testova.
- **e (Specman)** — pionir randomizacije, danas uglavnom legacy.
- Karakteristike svakog HVL-a: nezavisnost od simulatora (portabilnost), potpuna vidljivost svih objekata HDL modela (čitanje/upis signala, registara, nizova), mogućnosti programskih jezika visokog nivoa (kompleksni tipovi, OOP, modularnost).
- Napredne funkcionalnosti HVL-a: vremenski izrazi (temporal expressions — jezgro assertion-a), **constrained random generation** (generisanje uz ograničenja — realni interfejsi ne dozvoljavaju potpuno slobodnu randomizaciju, postoje zavisnosti vrednosti unutar istog trenutka i kroz vreme), **coverage collection** (ugrađeni mehanizmi za merenje pokrivenosti funkcionalnosti).

**8. Ostali alati** (istorijski/dopunski)
- Skript jezici (Perl, TCL, Python) — interpretirano izvršavanje, slabo tipizirani, snažna obrada teksta, ali 5-10x sporiji od kompajliranih jezika — ograničena upotreba kao primarni alat testnog okruženja.
- Editori talasnih oblika (waveform editors) — grafička specifikacija ponašanja; ograničeni na male blokove jer grafički prikaz teško prati složeniju specifikaciju (održavanje zahteva mnogo truda).

## Kod / primeri

```vhdl
-- VHDL: instanciranje DUV + monitor + stim + clk_gen u testbench-u
stimulus: entity work.stim(beh) port map (clk => clk_s, cmd_vld_o => cmd_vld_s, ...);
monitor: entity work.mon(beh) port map (clk => clk_s, rsp_vld_i => rsp_vld_s, ...);
cache_unit: entity work.cache(rtl) port map (clk => clk_s, cmd_vld_i => cmd_vld_s, ...);
clk_gen: process
begin
    clk_s <= '0', '1' after cycle_time_c/2;
    wait for cycle_time_c;
end process;
```
Standardni obrazac: DUV + monitor + stim komponente povezane preko signala, centralni proces generiše takt.

```vhdl
-- Komponenta generatora: učitava test vektore iz fajla
read_patterns: process
begin
    Load_Patterns("cache.patterns", patterns_s);
    wait;
end process;
```
Fajl sa test primerom se učitava jednom na početku; svaki novi test primer = nova datoteka bez izmene koda (parametrizacija).

## Primena na NCC akcelerator projekat

Ovo predavanje daje **teorijsku osnovu za FVH korak 2** (dokumentacija: plan verifikacije + opšta struktura okruženja) i motivaciju za korak 3 (implementacija UVM-stil okruženja):

- **Izbor simulacione tehnike**: NCC akcelerator (`ncc_core.vhd` FSM sa 23 stanja, `seq_divider`) NIJE čisto sinhroni dizajn u smislu pogodnom za cycle-based simulaciju bez ograničenja — koristiti standardnu event-driven simulaciju (i Xcelium i XSim su event-driven po defaultu), što je ionako obavezno za FVH korak 7.
- **Struktura testbenča** direktno mapira na NCC sistem: DUV = `ncc_accel` (ili `ncc_system` sa dva instancirana `ncc_accel`-a + `axi_interconnect`); monitor prati AXI-Lite i AXI-Full signale (S00/S01); stim/drajver generiše AXI transakcije (upis registara, upis slike/šablona, čitanje rezultata); `clk_gen` generiše takt na 90.909 MHz (frekvencija sistema iz PSDS projekta).
- **Ponovna upotreba postojećih VHDL testbenčeva kao referentnih modela**: `ncc_core_tb` (zlatni podaci 4x4/2x2) i `ncc_core_real_tb` (realna 90x90 slika, očekivani peak rezultat) daju **golden reference vrednosti** za scoreboard (FVH korak 4) — ne treba ih menjati, ali njihove test vektore/očekivane rezultate vredi izvući u UVM sekvence i scoreboard proveru.
- **Parametrizacija test primera** (princip iz predavanja: izdvoji parametre od koda) — direktno primenjivo: dimenzije slike/šablona, adrese u AXI-Full memoriji, i sami test vektori treba da budu konfigurabilni kroz `config` objekat i sekvence, a ne hardkodirani u testu — omogućava regresioni skup (korak 6) bez prepisivanja koda za svaki scenario.
- **HVL izbor**: SystemVerilog + UVM stil (test/env/config/sequencer/driver/sequence/monitor) je tačno ono što FVH korak 3 zahteva — ovo predavanje objašnjava *zašto* (portabilnost između Xcelium i XSim — FVH korak 7 — plus constrained-random generation za AW/W redosled bug i coverage collection za korak 5).
- **Debug/log praksa**: koristiti `uvm_info`/`$display` stil ispisa za praćenje AXI transakcija (adresa, podatak, cmd) — posebno korisno pri debagovanju poznatog AW/W hang bug-a jer omogućava brzu vizuelnu potvrdu redosleda signala u talasnom obliku ili logu.

Vidi i [[Vezba 05 - Uvod u UVM metodologiju]] za konkretnu UVM implementaciju ovih koncepata, [[Vezba 04 - Randomizacija i ogranicenja u SystemVerilogu]] za constrained-random generisanje stimulusa, i [[Predavanje 04 dodatak - SystemVerilog Tvrdnje]] za formalizaciju logičkih tvrdnji pomenutih u odeljku 2.9.
