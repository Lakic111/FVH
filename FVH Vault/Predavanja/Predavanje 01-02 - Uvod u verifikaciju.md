---
tags: [fvh, predavanje]
---

# Predavanje I-II - Uvod u verifikaciju

## Ključni koncepti

### Zašto verifikacija i koliko je skupa
- Funkcionalna verifikacija rešava dva fundamentalna izazova: (1) **eksploziju prostora stanja** (broj mogućih stanja/tranzicija dizajna raste eksponencijalno — ilustrovano primerom sa 10^32 provera i ~10^19 godina simulacije za trivijalan STB daljinski), (2) **detekciju nekorektnog ponašanja** (razlikovanje ispravne od neispravne tranzicije).
- Rešenje eksplozije prostora stanja: **hijerarhijska dekompozicija** — verifikuj manje blokove nezavisno pre sastavljanja u celinu.
- **Cena neotkrivenog bug-a raste eksponencijalno kroz vreme**: jeftino ako se nađe rano (dizajner ispravi HDL), skupo na nivou sistemskih testova (re-fabrikacija hardvera, kašnjenje "time-to-market"), najskuplje ako ga otkrije klijent (garancija + reputacioni rizik).
- Tri ograničenja koja se balansiraju: **raspored, troškovi, kvalitet** — poboljšanje jednog tipično pogoršava druga dva; poboljšanje verifikacione produktivnosti pomera "krivu otkrića bagova" ranije, poboljšavajući sve tri istovremeno.

### Verifikacioni ciklus (kružni tok)
Funkcionalna specifikacija → Verifikacioni plan → Razvoj okruženja (paralelno sa HDL implementacijom) → Debagovanje HDL-a i okruženja (povratna sprega) → Regresija (povratna sprega) → Fabrikacija ("tape-out") → Debagovanje fabrikovanog hardvera → Analiza propusta (escape analysis, povratna informacija nazad na početak ciklusa za buduće projekte).
- **Regresija** postoji iz dva razloga: (1) randomizovana okruženja svaki put generišu druge scenarije, (2) nakon svake ispravke mora se ponovo proveriti da fix nije pokvario nešto drugo. Koristi se farma radnih stanica za paralelno pokretanje regresionih testova.
- **Analiza propusta (escape analysis)**: kad se bag nađe na hardveru, tim mora da ga *reprodukuje u simulaciji* pre nego što tvrdi da je ispravka korektna — inače fix ostaje neproveren protiv originalnog uzroka.

### Verifikaciona hijerarhija (6 tipičnih nivoa)
1. **Dizajner (makro)** nivo — najniži, često "smoke test" koji sam dizajner pravi; interfejsi nestabilni, česte izmene.
2. **Jedinica (Unit)** — spaja više makro-blokova (ALU, DMA, FPU, keš), stabilniji interfejsi → moguć randomizovan stimulus + autonomna provera.
3. **Jezgro (Core)** — ponovo upotrebljiva jedinica sa stabilnom specifikacijom; verifikacija skupa ali se retko ponavlja jednom kad je jezgro verifikovano.
4. **Čip** — više jedinica, dobro definisane granice interfejsa; fokus na proveru povezanosti i poštovanje protokola.
5. **Ploča i sistem** — fokus na interakciju komponenti, ne na internu funkcionalnost pojedinačnog čipa (pretpostavka: pod-komponente su već verifikovane).
6. **Ko-verifikacija hardvera i softvera**.
- Pravilo izbora nivoa: **uvek biraj najniži nivo koji u potpunosti sadrži ciljanu funkcionalnost**; **kontrolabilnost i opservabilnost** opadaju kako se penje na više nivoe hijerarhije (obrnuto proporcionalno stopi detekcije grešaka) — zato je dobra praksa preći na viši nivo tek kad stopa detekcije bagova na trenutnom nivou počne da opada.

### Strategija verifikacije: pobuda i provera ("jin i jang")
- Dva nezavisna ali istovremeno neophodna zadatka: (1) pobuđivanje dizajna svim relevantnim ulaznim scenarijima (kontrolabilnost), (2) prepoznavanje kada se desila greška (opservabilnost). Neuspeh bilo kog od dva ruši ceo proces.
- Principi pobuđivanja: grupisati signale po logičkoj funkciji, ciljati **granične slučajeve** (corner cases), **temporalno zavisne** (višeciklusne) stimuluse — najteže za generisanje, ali najproduktivnije za otkrivanje bagova; primer sa steka: upisi kad je stek pun, istovremeno čitanje+reset, sve kombinacije `pop_buff`.
- **Provera ne sme re-implementirati algoritam dizajna** — verifikacioni inženjer mora uvek polaziti od pretpostavke da je implementacija pogrešna; ako checker kopira dizajnerovu logiku, deljena greška ostaje neotkrivena jer se rezultati "slažu" na pogrešan način (primer: next_read/next_write pokazivači kopirani iz dizajna vs nezavisna implementacija povezanom listom + brojačem).
- Četiri izvora za komponente provere: ulazi/izlazi dizajna, kontekst dizajna, mikroarhitekturna pravila, arhitektura dizajna.
- **Tri postulata simulacije**: (1) najviši kvalitet stimulus komponenti, (2) najviši kvalitet komponenti provere, (3) pravilan trenutak prelaska na sledeći nivo hijerarhije.

### Osnovno testno okruženje (testbench) — komponente
Testbench je **zatvoren sistem** (top level nema portove) koji predstavlja ceo "univerzum" DUV-a. Komponente:
- **Stimulus komponenta** — deli se na **inicijatore** (aktivno šalju stimulus/komande ka DUV-u) i **odzivnike** (pasivno reaguju na zahteve DUV-a, "slave" ponašanje — npr. mimikuju memoriju koja odgovara samo na zahtev). Stimulus treba da testira i van granica realnog okruženja da bi maksimalno "stresirao" DUV i otkrio corner case-ove.
- **Monitor** — nadgleda izlaze (protokol usklađenost), ulaze (za coverage), interne signale; prijavljuje greške protokola i hrani coverage/scoreboard.
- **Komponenta za proveru (checker)** — poredi očekivane vs stvarne izlaze; prilikom neslaganja upisuje debug informacije (očekivano, dobijeno, kontekst).
- **Tabela rezultata (scoreboard)** — privremeno skladišti podatke potrebne checker-u; sadrži **referentni model** (ili u sebi, ili u checker-u) koji translira ulazne podatke u očekivane izlazne. Referentni model mora biti konzistentno pozicioniran (uvek na istom mestu arhitekture) kroz ceo projekat.
- **DUV/DUT** — u centru okruženja; nivo apstrakcije HDL koda (RTL, gate, transistor, bihevioralni) je nezavisan od nivoa verifikacione hijerarhije.

### Tačke opservacije: crna / bela / siva kutija
- **Crna kutija** — verifikacija samo kroz spoljne interfejse; prednost: nezavisnost od implementacije, referentni model ostaje čist; mana: nema kontrolnih/opservacionih tačaka unutar DUV-a.
- **Bela kutija** — pun pristup internim signalima; greška se detektuje direktno na izvoru; mana: veliki teret održavanja koda usklađenog sa internim promenama DUV-a.
- **Siva kutija** — kombinacija; najčešće korišćen pristup u praksi, jer je predviđanje izlaza gotovo nemoguće bez posmatranja bar nekih internih signala (npr. interni brojači koje treba "preskočiti" na vrednost blizu granice da bi se testiralo prekoračenje bez čekanja miliona ciklusa).

### Testna okruženja i strategije testiranja
- **Deterministička** (test case) okruženja — ciljana funkcionalnost unapred definisana, koristi se rano u ciklusu za osnovnu funkcionalnost.
- **Self-checking** okruženja — provera nezavisna od primenjenog stimulusa, omogućava automatizaciju. Tri tipa:
  1. **Zlatni vektori** — unapred poznat skup ulaz/izlaz parova upisan u tabelu rezultata pre simulacije; jednostavno, ali skupo za kreiranje/održavanje.
  2. **Referentni model** — računa očekivane izlaze u runtime-u na osnovu ulaznog stimulusa (tipično "cycle accurate"); precizniji ali skuplji za razvoj/održavanje (mora pratiti tačan tajming DUV-a, slično beloj kutiji, ali bez pristupa internim tačkama opservacije).
  3. **Okruženje bazirano na transakcijama** — za DUV-ove sa jasno definisanim transakcijama (npr. IO protokoli tipa Ethernet/PCI); tabela rezultata vodi evidenciju "u letu" transakcija, komponenta provere šalje upit sa ID-jem transakcije i poredi.

## Kod / primeri

Ovo predavanje je konceptualno (bez koda); primeri su ilustrativni scenariji (STB daljinski, keš kontroler, stek sa clean_stack bagom).

## Primena na NCC akcelerator projekat

- **Verifikaciona hijerarhija za NCC**: prirodan izbor je jedan nivo — **top-level `ncc_accel`** (analogno "čip" nivou) — jer je specifikacija (AXI-Lite registar mapa + AXI-Full memorijska mapa) definisana upravo na tom interfejsu. Opciono, nivo **jedinice** za `ncc_core.vhd` (FSM + `seq_divider` + NCC² datapath) ako se želi deeper white/gray-box test FSM-a sa 23 stanja — ali ovo zahteva dodatnu specifikaciju internih signala FSM-a koje PSDS dokumentacija verovatno ne sadrži eksplicitno, pa treba proveriti kroz `ncc_core_tb`/`ncc_core_real_tb`.
- **Pobuda**: inicijatori = AXI-Lite/AXI-Full master transakcije (upis registara, upis slike/šablona, čitanje rezultata); NCC nema "odzivnik" ulogu jer je slave na oba AXI interfejsa (CPU je master) — pa je ovo čisto inicijator-orijentisano okruženje. Granični slučajevi za pobudu: AW-pre-W / W-pre-AW / simultano (poznati fiksirani bug), `start` bit tokom `busy`, minimalna/maksimalna dimenzija slike-šablona (`REG_IMG_W/H`, `REG_TMP_W/H`), adrese van dozvoljenog opsega (0x00000/0x08000/0x10000 granice 128KB regiona).
- **Provera ne sme re-implementirati** NCC² algoritam identično kao `ncc_core.vhd` — referentni model treba pisati kao nezavisan softverski (npr. u SV koristeći realne aritmetičke operacije ili čak eksterni C model) NCC² proračun nad istim ulaznim slikama/šablonima, korišćenjem `ncc_core_real_tb` očekivane peak vrednosti kao referentne tačke provere ("zlatni vektor" za prvu iteraciju), a kasnije prelazak na pun referentni model za randomizovane testove.
- **Tabela rezultata (scoreboard)** čuva: (1) trenutne konfigurisane vrednosti registara (dimenzije, adrese) upisane preko AXI-Lite, (2) sliku/šablon upisane preko AXI-Full, (3) na `start` triger računa očekivani NCC² rezultat softverski i čeka `done_sticky`, zatim čita rezultat region (0x10000) preko AXI-Full i poredi.
- **Siva kutija** je realističan izbor: crna kutija (samo AXI interfejsi) dovoljna je za funkcionalnu proveru krajnjeg rezultata, ali posmatranje internog `busy`/FSM stanja (bela/siva) je neophodno za: (a) detekciju da FSM zaista prolazi kroz svih 23 stanja (coverage), (b) watchdog/timeout logiku, (c) ciljano testiranje `seq_divider` graničnih slučajeva (npr. deljenje nulom ili malim brojem piksela u šablonu).
- **Zlatni vektori vs referentni model**: za prvu (deterministic, directed) fazu testiranja koristiti zlatne vektore iz postojećih VHDL testbench-eva (`ncc_core_tb` 4x4/2x2, `ncc_core_real_tb` 90x90 realna slika) — ovo direktno zadovoljava deo zahteva 4 (scoreboard + automatska provera) uz minimalan dodatni rad; za kasniju regresiju/randomizaciju (zahtev 6) razviti pun softverski referentni model NCC² formule kako bi se automatski proveravao proizvoljan par slika/šablon.
- Escape-analysis princip direktno se primenjuje na već poznati AXI write-order bug: čak i pošto je "fiksiran" u RTL-u, verifikacioni plan treba da eksplicitno navede directed regresioni test koji reprodukuje originalni scenario (AW-pre-W hang) kako bi se garantovalo da fix ostaje ispravan kroz buduće izmene DUT-a.

Povezano: [[Predavanje 03 - Plan verifikacije]]
