---
tags: [fvh, predavanje]
---

# Predavanje III - Plan verifikacije

## Ključni koncepti

### Uloga i priroda dokumenta
- Verifikacioni plan je **odlučujući faktor za uspeh** celog procesa — definiše i *šta* se radi i *kako* se radi; svi naredni koraci verifikacionog ciklusa se baziraju na njemu.
- To je **"živ" dokument** — podložan izmenama, za njega je zadužen ceo dizajn+verifikacioni tim.
- **Funkcionalna specifikacija** je izvor za plan — kada je nejasna/dvosmislena, neslaganja između tima za dizajn i tima za verifikaciju se rešavaju kroz konsultaciju sa arhitektom sistema (specifikacija je "zakon", ali ako je dvosmislena, mora se razjasniti i eksplicitno dokumentovati tumačenje).

### Sadržaj verifikacionog plana — sekcije
**Tehničke sekcije** (strategija i konstrukcija okruženja):
1. **Opis hijerarhijskih nivoa verifikacije** — odluka koji nivoi (dizajner/unit/core/chip/...) se koriste; zavisi od (a) kompleksnosti pojedinačnih komponenti, (b) postojanja jasno definisanih/stabilnih interfejsa. Za svaki odabrani nivo pravi se zaseban pod-plan.
2. **Funkcije koje se verifikuju** — lista sa referencom na tačku specifikacije, podeljena na: **kritične funkcije** ("linija koja se ne sme preći" — neuspeh = uređaj "mrtav"), **sekundarne funkcije** (performanse, buduće verzije, funkcije premestive u softver), **funkcije koje se ne verifikuju na trenutnom nivou** (već pokrivene na nižem nivou, ili nisu primenjive na trenutnom nivou).
3. **Test scenariji / matrica test slučajeva** — lista svih test scenarija sa oznakom, opisom, referencom na funkciju i coverage stavku; mora se definisati **pre** kreiranja okruženja, da se ne bi propustio bitan test. Uzima u obzir: konfiguracije, varijacije podataka, atribute podataka, interesantne sekvence po ulaznom portu, uslove grešaka (error conditions), **granične slučajeve (corner cases — zaslužuju zasebnu sekciju)**.
4. **Specifični testovi i metode: okruženje** — više pod-tačaka:
   - **Tip verifikacije** (crna/bela/siva kutija) + blok dijagram "univerzuma" DUV-a.
   - **Strategija verifikacije**: deterministička vs randomizovana (random-based) vs formalna. Kriterijum: jednostavan dizajn skromne funkcionalnosti → deterministički testovi; kompleksna funkcionalnost gde je nemoguće predvideti sve permutacije ulaza → randomizacija; mali ali kompleksni blokovi → formalna verifikacija. Odluka random vs formal zavisi prevashodno od **veličine** komponente.
   - **Randomizacija**: nekontrolisana randomizacija je beskorisna (promašuje interesantne slučajeve i/ili prijavljuje lažne bagove); potrebna je **kontrolisana i ograničena** randomizacija, uz mogućnost potpunog isključivanja po potrebi; **mikro-modovi** omogućavaju umetanje determinističkih sekvenci unutar randomizovanog okruženja.
   - **Nivo apstrakcije**: bit-nivo (dizajner nivo, jednostavni blokovi) → paket/sekvenca nivo (unit/chip nivo — standard) → program/algoritam nivo (retko ispod sistemskog nivoa).
   - **Provera**: strategija zavisi od tipa kutije + strategije stimulusa + nivoa apstrakcije; determinizam → zlatni vektori, randomizacija → referentni model ili provera bazirana na transakcijama. Dokumentuje se i šta se prati globalno vs lokalno (monitor komponente).
5. **Zahtevi u vezi pokrivenosti (coverage)** — pokrivenost je "kontrola kvaliteta" *verifikacionog okruženja* (dok samo okruženje vrši kontrolu kvaliteta DUV-a). Ciljevi: sve vrste komandi/transakcija pokrivene, širok opseg vrednosti podataka, podržan višestruki konkurentni legalni stimulus, namerno injektovane greške (za proveru da checker zaista hvata greške). Dobra praksa: pratiti i % izvršenog koda komponenti provere (neizvršena provera = nedostatak u stimulusu ili planu).

**Sekcije vezane za vođenje projekta**:
6. **Potrebni alati** — simulatori (event-based za unit, cycle-accurate za chip), formalni alati, assertion alati, debageri, emulacija/akceleracija hardver, HVL jezici, biblioteke. Loše predviđanje alata = rizik po raspored i budžet.
7. **Rizici i zavisnosti** — rizici vezani za nove alate (kašnjenje isporuke, integracija, edukacija — plan B: backup alat ili rani test prihvatljivosti), zavisnost od HDL isporuka (dizajn tim isporučuje HDL inkrementalno — osnovna funkcionalnost prva, kompleksnija kasnije; verifikacioni tim mora planirati aktivnosti oko toga), zavisnost od odvojenog verif. tima/IP dobavljača, "zamrzavanje arhitekture" (architecture closure) — specifikacija retko finalna pre starta verifikacije.
8. **Zahtevi za resursima** — ljudski (referentni model zahteva više ljudi ali precizniji je; transakciono-bazirana provera manje resursa; niži nivoi hijerarhije → više okruženja, manje resursa po okruženju; tipično 1 inženjer za stimulus + 1 za proveru po jedinici), računarski (broj CPU/licenci u zavisnosti od trajanja testa × broj testova; kompromis: duži testovi pokrivaju više ali teže se debaguju — više kraćih testova je često bolje).
9. **Detalji rasporeda** — raspored na visokom nivou prvo (isporuka specifikacije → tape-out), zatim detalji po nivou hijerarhije: razvoj okruženja, debug HDL-a, regresija. Ključna stavka: **prva HDL isporuka** verifikacionom timu (sadrži osnovnu funkcionalnost); paralelizam (verifikacija radi na osnovnim funkcijama dok dizajneri rade na kompleksnim) skraćuje raspored ali zahteva da dizajneri balansiraju novi razvoj i ispravke bagova. Pravilo: pređi na sledeći nivo hijerarhije kad stopa detekcije bagova na trenutnom počne da opada.

### Ilustrativni primer: Calc1
Predavanje demonstrira ceo plan na jednostavnom DUT-u: 4-portni kalkulator (ADD/SUB/shift), po jedna komanda po portu istovremeno, first-come-first-served obrada, dve interne ALU (arith i shift), specifikacija na nivou top-level interfejsa. Zaključci primenjeni na Calc1:
- Samo **top-level (najviši) hijerarhijski nivo** je opravdan, jer specifikacija opisuje samo interfejs na tom nivou (unit-level bi zahtevao dodatnu specifikaciju ALU/prioritization bloka).
- Funkcije podeljene u tabele: osnovne, kompleksnije scenario, generički testovi/provere.
- **Tip verifikacije**: siva kutija — dodatne interne provere (npr. red bloka za prioritizaciju) ubrzavaju pronalazak grešaka i pokrivaju fer raspodelu komandi (stavka "2.2").
- **Strategija**: deterministička (formal bi imao problem sa 32-bit ALU rezultatima; puna randomizacija nepotrebna za ovako mali broj potrebnih test slučajeva).
- **Nivo apstrakcije**: paketni nivo (brže kodiranje test slučajeva); okruženje mora prevesti komandu u bit-kod, pobuditi ulaze, sačekati validan odgovor pre sledeće komande na isti port, voditi računa o reset/clock logici.
- **Alati**: samo jedan simulator + waveform viewer + infrastruktura za opis test slučajeva — nema značajnih rizika za ovako jednostavan dizajn.
- **Resursi/raspored**: jedan verifikacioni inženjer, jedna radna stanica, ~1 radni dan uz postojeću infrastrukturu.
- Blok dijagram okruženja: **Parser** (tekst→paket) → **Inicijator** (paket→bit-nivo na portu, i prosleđuje komandu **Tabeli rezultata**) → DUT → **Komponenta provere** (uzima očekivani odgovor od tabele rezultata, poredi sa stvarnim, raportira grešku sa očekivanim/dobijenim podacima ako se ne poklapaju).

## Kod / primeri

Nema koda — predavanje je isključivo metodološko/dokumentaciono (struktura plana + Calc1 tabele/vremenski dijagrami test slučajeva, npr. test 1.1.1: port=1, cmd=ADD(0001b), op1=0005h, op2=0008h → result=000Dh).

## Primena na NCC akcelerator projekat

Ovo predavanje daje direktan template za dokument koji FVH zahteva ("proširiti PSDS dokumentaciju planom verifikacije i opštom strukturom okruženja"). Konkretna razrada za `ncc_accel`, po sekcijama iz predavanja:

1. **Hijerarhijski nivoi**: analogno Calc1 — specifikacija (registar mapa + memorijska mapa) postoji samo na top-level `ncc_accel` interfejsu, pa je **top-level jedini obavezan nivo**. Opciono, dodati "unit" nivo za `ncc_core.vhd` ako se odluči da FSM/`seq_divider` treba nezavisnu proveru (zahteva dodatnu internu specifikaciju stanja FSM-a).
2. **Funkcije koje se verifikuju** (predlog liste, sa referencama na registre iz DUT briefinga): kritične — konfigurisanje REG_IMG_W/H, REG_TMP_W/H, REG_IMG_ADDR/REG_TMP_ADDR, `start` (REG_CTRL bit0), `done_sticky`/`busy` (REG_STATUS bit0/bit1), tačnost NCC² rezultata na ADDR_RESULTS, AXI-Full pristup image/template/results regionima (0x00000/0x08000/0x10000); sekundarne — performanse (broj ciklusa do `done`), rad sa dva paralelna `ncc_accel` core-a u sistemu; van obuhvata trenutnog nivoa — AXI CDMA putanja (trenutno neiskorišćena od strane app SW, pa van scope-a FVH projekta osim ako se eksplicitno doda).
3. **Matrica test slučajeva** (predlog, uz granične slučajeve kao posebna sekcija): osnovni upis/čitanje svakog registra; pun tok upis-slika→upis-šablon→start→poll-status→čitanje-rezultata; granični slučajevi — AW-pre-W / W-pre-AW / simultano na S00 i na S01 (poznati fiksirani bug — obavezan regresioni test), `start` dok je `busy`=1, minimalne/maksimalne dimenzije slike i šablona, adrese na granici 128KB AXI-Full regiona, čitanje rezultata pre `done`.
4. **Okruženje**: tip kutije = siva (AXI crno-kutijski interfejs + interni `busy`/FSM state za coverage i watchdog); strategija = deterministička za osnovne registarske testove (rani fokus), randomizovana (dimenzije slike/šablona, adrese, redosled AXI kanala) za regresiju (zahtev 6 iz bodovanja); nivo apstrakcije = transakcija/paket (AXI transakcija kao osnovna jedinica, ne bit-nivo signal); provera = referentni model (softverski NCC² proračun) za randomizovane testove + zlatni vektori iz `ncc_core_tb`/`ncc_core_real_tb` za rane directed testove.
5. **Coverage ciljevi**: sve AXI-Lite registre pokrivene upisom/čitanjem, sve kombinacije AW/W redosleda, opseg dimenzija slike/šablona (mali/veliki/granični), oba `ncc_accel` core-a u sistemu, % pokrivenosti scoreboard/checker koda.
6. **Alati**: XSim (Vivado simulator) I Xcelium (oba obavezna po zahtevu 7) + waveform viewer; SV/UVM-stil infrastruktura razvijena u vežbama 1-3 (interfejsi, klase, mailbox/queue za scoreboard).
7. **Rizici/zavisnosti**: DUT (VHDL) se ne sme menjati — verifikacija mora raditi oko postojećeg poznatog buga umesto da ga "sredi"; zavisnost od mešovite VHDL/SV simulacije (proveriti podršku oba simulatora za mixed-language pre nego što se gradi kompleksan UVM sloj); jedan verifikacioni inženjer (student) → ograničeni resursi, pa prioritet ide na osnovne UVM komponente (50 bodova) pre coverage/regresije.
8. **Raspored**: prva "HDL isporuka" je zapravo odmah dostupna (PSDS gotov, DUT fiksiran) — što pojednostavljuje raspored u odnosu na tipičan projekat (nema paralelnog čekanja na dizajnere); fokus rasporeda ide na inkrementalni razvoj: prvo osnovne komponente (test/env/driver/sequencer/monitor), zatim scoreboard, zatim coverage, zatim regresija, na kraju XSim+Xcelium paritet.
9. **Blok dijagram okruženja** (Calc1-stil, adaptirano): Sequencer (generiše `ncc_seq_item` — lite ili full transakcije, deterministički ili randomizovano) → Driver (prevodi u AXI signal-nivo handshake na `axi_lite_if`/`axi_full_if`) → DUT (`ncc_accel`) → Monitor (hvata AXI transakcije + interni `busy`/FSM state) → Scoreboard (referentni NCC² model + poređenje sa pročitanim rezultatom, prijava greške sa očekivano/dobijeno).

Povezano: [[Predavanje 01-02 - Uvod u verifikaciju]]
