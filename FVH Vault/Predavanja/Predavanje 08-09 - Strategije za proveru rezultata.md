---
tags: [fvh, predavanje]
---

# Predavanje 08-09 - Strategije za proveru rezultata

## Ključni koncepti

### 1. Tipovi provere rezultata (kada se vrši provera)
- Dve ose odluke prilikom planiranja testnog okruženja: **trenutak generisanja stimulusa** i **trenutak provere rezultata**. Za drugu osu postoje dve opcije:
  - **Provera u realnom vremenu (on-the-fly checking)** — okruženje proverava transakciju čim se ona završi na izlazu DUT-a.
  - **Provera na kraju testa (end-of-test checking)** — provera se vrši tek nakon što se test/simulacija završi, bilo unutar simulacionog okruženja (na kraju simulacije), bilo u posebnom post-analitičkom (post-processing) programu van simulatora.
- Postoje tri arhitekture self-checking okruženja, opisane u kombinaciji sa trenutkom provere:
  1. **Zlatni vektori** — tabela rezultata (result table) unapred puni parser test slučaja pre početka simulacije; komponenta za proveru poredi izlaz DUT-a sa tabelom (na svakom taktu ili na svakoj transakciji). Postoji i varijanta bez tabele rezultata — provera se vrši eksternim post-processing programom nakon što monitor sve zapiše u fajl.
  2. **Testno okruženje zasnovano na transakcijama** — nalik zlatnim vektorima, ali tabelu rezultata puni "u letu" (real-time) sama stimulus komponenta dok šalje transakcije DUT-u, umesto da je parser test slučaja unapred učita. Podržava i real-time i end-of-test (post-processing) varijantu provere.
  3. **Referentni model precizan na nivou takta (cycle-accurate)** — referentni model prima iste ulaze kao DUT i izračunava očekivane izlaze na nivou svakog takta; komponenta za proveru samo poredi DUT vs. referentni model izlaz-po-izlaz. Jednostavna provera, ali referentni model može biti složen; koristan kad plan zahteva proveru tačnog tajminga.
- **Prednosti provere u realnom vremenu**: lakše debagovanje (simulacija staje odmah pri grešci, ne na kraju), manja potrošnja memorije (očekivani podaci se ne čuvaju do kraja), brža simulacija.
- **Kada koristiti proveru na kraju testa**: rezultati ostaju u memoriji DUT-a do kraja testa; ograničen pristup signalima (hardverska akceleracija/emulacija); potrebna provera završnog stanja (redovi prazni i sl.); funkcije imaju sistemske aspekte (arbitraža, kašnjenje, performanse).

### 2. Debug
- Debug = pronalaženje i ispravljanje problema u DUT-u ili u testnom okruženju; merilo uspeha je brzina utvrđivanja uzroka greške.
- Izvor greške može biti u: **dizajnu, okruženju, specifikaciji ili alatima**. Posao verifikacionog inženjera je da razdvoji greške dizajna od grešaka sopstvenog okruženja pre prijave dizajnerskom timu (da ne izgubi kredibilitet lažnim prijavama).
- Osnovni tok debagovanja: krene se od tačke detektovane greške i prati se unazad ("zašto je test pao?") do izvora — kroz pitanja "da li su očekivani podaci tačni?" i "da li su ulazi tačni?".
- **Tačke posmatranja (observation points)** — balans između granularnosti provere i lakoće debagovanja:
  - Ekstrem 1: interne provere kroz ceo dizajn → previše prati implementaciju (ne nameru), teško se održava pri izmenama dizajna.
  - Ekstrem 2: "crna kutija" (samo izlazi) → tačka porekla greške je logički daleko od mesta posmatranja, sporo debagovanje.
  - Kompromis = **paradigma sive kutije**. Smernice: tačke posmatranja postaviti na arhitekturno definisane mehanizme (stabilne, manje održavanja), ravnomerno rasporediti kroz dizajn, koristiti ih kao dopunu (ne duplikat) postojećih tvrdnji (assertions) dizajnerskog tima.
- **Alati za debagovanje**: print (ispis)/logovanje (sa programiranim nivoima verbosity-ja da se izbegne prezasićenost log fajla), tvrdnje (assertions), pregled talasnih oblika (waveform viewer — standardni alat uz svaki simulator, koristan i dizajneru i verifikacionom inženjeru za uvid u interna stanja komponenti za proveru), pregled memorije.
- Debagovanje prethodno generisanih (statičkih) test slučajeva je brže od debagovanja dinamički generisanih (nasumičnih) — kod dinamičkog postoji vreme čekanja da se simulacija ponovo dovede do iste tačke greške.
- Dobra praksa: dodavati posebna polja u strukture podataka (transakcije) samo u svrhu praćenja unazad do izvora greške (traceability).

### 3. Strategije za ponovnu upotrebu (reuse)
- Analogno dizajnu ("kreiraj jednom, koristi na više mesta"), verifikacione komponente treba da budu ponovo upotrebljive — skraćuje trajanje projekta.
- **Horizontalna ponovna upotreba** — korišćenje iste verifikacione komponente više puta na ISTOM nivou hijerarhije (npr. isti stimulus/monitor za tri instance jedinice A/B/C na zajedničkoj magistrali).
- **Vertikalna ponovna upotreba** — korišćenje iste verifikacione komponente na VIŠIM nivoima hijerarhije (od nivoa jedinice do nivoa sistema/čipa) — ključno za simulaciju sistema, jer se iskorišćava već implementirano.
- Komponente ponovo upotrebljive i horizontalno i vertikalno = **ponovo upotrebljiv verifikacioni IP (reusable verification IP)**; može se i kupiti od dobavljača (VIP) — širom primenom dobavljača kvalitet i usklađenost sa standardima interfejsa raste.
- **Smernice za ponovnu upotrebu:**
  1. **Nezavisne komponente za stimulus** — stimulus komponenta ne sme komunicirati ni sa jednom drugom verifikacionom komponentom (npr. ne sme direktno slati transakcije tabeli rezultata ako se ta ista komponenta koristi na višem nivou gde tabela rezultata postaje nefunkcionalna).
  2. **Konfigurabilne log poruke.**
  3. **Dinamičko mapiranje signala u verifikacione komponente** — nazivi signala interfejsa (monitor/checker/stimulus veze) moraju biti konfigurabilni, inače horizontalna/vertikalna ponovna upotreba puca na problemu imenovanja (npr. signal "Net B" na nivou jedinice postaje "Net Top/B" na višem nivou).
  4. **Pakovanje verifikacionih komponenti** (kao samostalni paket/UVC).
  5. **Dokumentacija.**
- Primer iz predavanja (Calc2): originalno okruženje kršilo je pravilo nezavisnosti — stimulus komponenta je direktno komunicirala sa tabelom rezultata i monitorima izlaznih portova, što je onemogućavalo vertikalnu ponovnu upotrebu. Rešenje: uvedeni su dodatni **port monitori** (ulazni i izlazni) po portu koji prekidaju direktnu komunikaciju — stimulus komponenta postaje potpuno nezavisna, a tabela rezultata i checker se pune isključivo preko monitora.

## Kod / primeri
Ovo predavanje (pptx) je koncepcijsko/dijagramsko, bez SV koda — svi konkretni UVM kod-primeri (scoreboard, assert sintaksa, agent/env struktura) dati su u pratećim vežbama, vidi [[Vezba 09 - Hijerarhija UVM okruženja]] i [[Vezba 10 - Razvoj scoreboard komponente]].

## Primena na NCC akcelerator projekat

- **Trenutak provere**: za `ncc_accel` je prirodno koristiti **real-time proveru** (on-the-fly) — čim monitor detektuje `REG_STATUS.done_sticky` posle `REG_CTRL.start`, scoreboard odmah poredi pročitani rezultat iz `ADDR_RESULTS`/AXI-Full `+0x10000` regiona sa predictor-om. Ovo je pogodno jer je NCC izračunavanje jasno omeđena transakcija (start→busy→done), a real-time provera daje brže i lakše debagovanje FSM-a od 23 stanja kad nešto pukne (simulacija staje odmah, a ne tek posle dugog burst čitanja cele slike).
- Za scenarije gde treba proveriti **završno stanje** memorijskog podsistema (npr. da li su svi rezultati u `mem_subsystem` konzistentni nakon više uzastopnih NCC obračuna na oba `ncc_accel` core-a, ili da AXI CDMA red nije "zaglavljen"), koristiti proveru na kraju testa — ovo pokriva slučaj "ograničen pristup signalima" jer je DUT sintetizovan i pokreće se i u XSim i na realnom Zybo hardveru (gde live praćenje internog FSM stanja nije uvek dostupno).
- **Debug**: kad AXI write-path bug (W pre AW) ili neki drugi test padne, prvo pitanje je "greška u VHDL-u (ncc_core FSM, axi slave) ili u UVM okruženju (loš driver timing, loš referentni model)?" — pošto je VHDL kod fiksan i ne sme se menjati (build zahtev projekta), svaki neuspeh testa mora prvo biti dokazano izolovan na okruženje pre eventualne sumnje na hardver. Preporučeno: dodati trace polje (npr. `tr.id`, `tr.axi_burst_id`) u `axil_seq_item`/`axif_seq_item` transakcije radi praćenja od generisanja u sekvenci do provere u scoreboard-u.
- **Tačke posmatranja (siva kutija)**: pošto je VHDL izvor dat i ne menja se, ali RTL simulacija (XSim/Xcelium) ipak izlaže interne signale, korisno je postaviti dodatne monitor tačke na `busy`/`done_sticky` bit tranzicije unutar `ncc_core` FSM-a (23 stanja) radi bržeg debagovanja bez menjanja samog dizajna — čisto posmatranje signala kroz testbench hijerarhiju (force/probe), ne izmena VHDL-a.
- **Ponovna upotreba**: sistem ima **2× `ncc_accel`** — horizontalna ponovna upotreba znači da se isti `axil_agent`+`axif_agent`+monitor par instancira dvaput sa parametrizovanom baznom adresom. Da bi ovo radilo po smernicama predavanja, **stimulus komponenta (sequence/driver) mora biti nezavisna** — ne sme direktno pisati u scoreboard, već isključivo preko monitora (izbeći isti "Calc2 anti-pattern" gde je stimulus bio zakačen direktno na tabelu rezultata). Takođe, nazivi signala/portova u virtuelnom interfejsu (`axi_lite_if`, `axi_full_if`) moraju biti generički (parametrizovani instance imenom, npr. `ncc_if[0]`, `ncc_if[1]`) da bi se isto okruženje moglo vertikalno ponovo upotrebiti na nivou `ncc_system` (sa Zynq PS7 + CDMA + interconnect) bez prepravke agenta.
- **Post-processing / regresija (grading stavka 6-7)**: pošto se okruženje mora pokretati i u Vivado XSim i u Xcelium, korisno je da scoreboard izveštaj (`report_phase` sa brojem proverenih transakcija) bude alat-agnostičan (čist UVM `` `uvm_info ``/log), a eventualna post-analitička provera (npr. poređenje sa `ncc_kernel.cpp` C modelom generisanim fajlom) bude spoljni skript nezavisan od simulatora — u duhu "provera na kraju testa: postanalitički program" opisane u predavanju.
