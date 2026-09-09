---
tags: [fvh, predavanje]
---

# Predavanje 06-07 — Strategije za generisanje stimulusa

Izvor: `dodatno/Predavanje-6-7-Strategije-za-generisanje-stimulusa(1).pptx` (58 slajdova, primer Calc2), + kod primera `dodatno/sv_stimulus_deterministic.zip` i `dodatno/tb_random_on_the_fly.zip` (deterministički vs. nasumični on-the-fly testbench za isti Calc2 DUT).

## Ključni koncepti

- **Dve ose izbora pri planiranju generisanja stimulusa**:
  1. **Deterministički naspram nasumičnog** — deterministički test kreira specifičan, unapred poznat scenario (može imati randomizovane pojedinačne parametre); nasumičan test koristi pseudoslučajne brojeve i raspodele verovatnoće za odluke o stimulusu.
  2. **Prethodno generisani (pre-generated) naspram dinamički generisanih (on-the-fly) test slučajeva** — prvi postoji kompletan pre pokretanja simulacije (stimulus + očekivani rezultati), drugi se kreira ciklus-po-ciklus tokom same simulacije, sa ugrađenom inteligencijom generisanja u stimulus komponentu.
  - Ukrštanjem ove dve ose dobijaju se **4 paradigme**: deterministički pre-generisan, deterministički on-the-fly (sa nasumičnošću u podacima), nasumičan pre-generisan (test-case generator kao poseban alat), nasumičan on-the-fly (constraint-uri se rešavaju tokom simulacije).
- **Opšti algoritam stimulus komponente** (primenjuje se na početku svakog ciklusa, bez obzira na paradigmu): (1) provera globalnih promena okruženja (npr. reset), (2) nastavak stimulusa započetog u prethodnim ciklusima, (3) provera da li DUV može primiti novi stimulus i, ako može, iniciranje na osnovu izabrane paradigme.
- **Seed (početna vrednost) i ponovljivost**: dinamički nasumični testovi nemaju unapred sačuvan test slučaj — ponovljivost se obezbeđuje čuvanjem *seed*-a + fajla za kontrolu nasumičnosti (randomization control file), ne celog test slučaja. Tri metoda dodele seed-ova po komponenti:
  - **Metod 1** — ista seed vrednost direktno za sve komponente → komponente postaju sinhronizovane/harmonične (neželjeno, ograničava interesantne scenarije).
  - **Metod 2** — izvedeni seed-ovi (npr. sukcesivni pozivi istog PRNG-a) → komponente generišu sličan, samo pomeren niz brojeva (i dalje korelisane).
  - **Metod 3** (preporučen) — drugi, nezavisan generator nasumičnih brojeva: prvi PRNG dodeljuje različite seed-ove po komponenti, drugi PRNG donosi dinamičke odluke o usmeravanju — komponente postaju stvarno nezavisne.
- **Razrešavanje ograničenja (constraint solving)** — trostepeni proces: (1) razumevanje međuzavisnosti promenljivih (usko povezane / slabo povezane / nepovezane), (2) prioritizacija promenljivih (redosled dodele vrednosti — određuje ga namena testa, odnos između grupa promenljivih, odnos unutar grupe), (3) analiza posledica (traženje *overconstrained* grupa — prazan prostor stanja, ili nenamerno preusko ograničenog prostora stanja). Redosled dodele vrednosti promenljivama je ključna odluka verifikacionog inženjera — pogrešan redosled nepotrebno sužava stimulus.
- **Tehnike pokrivenosti u nasumičnim okruženjima** — analiza posledica ograničenja nije nepogrešiva, pa se coverage koristi u runtime-u da otkrije neočekivane praznine u matrici kombinacija promenljivih i da usmeri podešavanje generisanja stimulusa.
- **Izazivanje retkih događaja (corner cases)** — verifikacija namerno čini da se retki/neuobičajeni događaji dešavaju češće nego u normalnom radu, jer se tu kriju teški bugovi. Tri pravca napora: pokušaj direktnog izazivanja specijalnih slučajeva, analiza podataka o pokrivenosti, automatizovana promena kontrole nasumičnosti.
- **Grey-box pristup i test na nivou paketa** (Calc2 primer): generisanje stimulusa na najvišem interfejsu, deo verifikacionog koda ipak "viri" u unutrašnjost DUV-a (npr. praćenje internih redova/queue-ova) kad je to potrebno za scoreboard.

## Kod / primeri

Iz `sv_stimulus_deterministic.zip` (`stimulus/deterministic_from_file/stim.sv`) — deterministički, pre-generisani stimulus, čitan iz fajla `stimulus.dat`:
```systemverilog
fd = $fopen("stimulus.dat", "r");
while (!$feof(fd)) begin
  code = $fgets(line, fd);
  par_num = $sscanf(line, "%s %s %d %h %h %h", cmd, port, delay, tag, op1, op2);
  ...
  packet pckt = new();
  code = pckt.randomize();          // samo invalid-flag se randomizuje
  pckt.port = port.atoi();
  pckt.req_data1_in = op1;          // ostatak dolazi direktno iz fajla — determinizam
  ...
  all_commands[{port,"_", delay_str}] = pckt;   // indeksirano po port+delay za brz lookup u get_next()
end
```
`get_next(clk_cnt)` zatim u svakom ciklusu proverava asocijativni niz `all_commands` po ključu `{port, delay}` i vraća paket ako postoji zakazana komanda za taj takt — kompletan test slučaj je unapred poznat, samo se "reprodukuje" tempom simulacije.

Iz `tb_random_on_the_fly.zip` (`random_on_the_fly/packet.sv`) — nasumičan, on-the-fly stimulus sa constraint-ima:
```systemverilog
class req_packet;
  rand bit invalid;
  rand bit[3:0] req_cmd_in;
  rand logic[31:0] req_data1_in, req_data2_in;
  rand bit ov_uv;
  rand int delay;

  constraint invalid_c { invalid dist {1'b0 := 90, 1'b1 := 10}; }
  constraint cmd_c { if(invalid == 0)
                        req_cmd_in dist {1:=30, 2:=25, 5:=20, 6:=15};
                     else
                        req_cmd_in dist {[3:4]:=10, [7:15]:=10}; }
  constraint slvbfr_c { solve invalid before req_cmd_in; }        // redosled rešavanja!
  constraint ov_c { ((req_cmd_in==4'b0001) && ov_uv) -> req_data2_in > 32'hFFFFFFFF - req_data1_in;
                     solve ov_uv before req_data2_in; }
  constraint delay_c { delay dist {0:=30, 1:=25, 2:=20, 3:=15, 4:=5, 5:=5}; }
endclass
```
`random_stim.sv` implementira FSM po portu (`READY`/`DELAY`/`SENDING`) unutar `get_next(clk_cnt)` — svaki ciklus randomizuje novi paket na slobodnom portu i eventualno čeka `pckts[port].delay` taktova pre slanja, čime se realizuje dinamičko (on-the-fly), a ne unapred generisano, odlučivanje.

`scoreboard.sv` (asocijativni niz `req_packet requests[string]`, ključ `"port_tag"`) i `checker.sv` (`output_checker::check()` čita iz mailbox-a `output_mbx`, po tagu pronalazi originalni zahtev preko `scb.get_request()`, izračunava očekivani rezultat i poredi sa `rsp.out_data`) demonstriraju **self-checking mehanizam** direktno analogan UVM scoreboard-u iz Vežbe 8, samo bez UVM klasa (mailbox umesto `uvm_analysis_imp`).

## Primena na NCC akcelerator projekat

- **Plan verifikacije NCC-a treba da eksplicitno navede poziciju na obe ose**: rane simulacije (dimenzije slike/šablona fiksne, poznate iz PSDS golden testbench-eva poput `ncc_core_tb` sa 4x4/2x2) = deterministički pre-generisani test → zatim deterministički on-the-fly (npr. fiksna sekvenca registara ali randomizovan sadržaj slike) → na kraju potpuno nasumično on-the-fly okruženje za regione registara i AXI tajming (grey-box, jer se prati i interno `busy`/`done_sticky` stanje FSM-a).
- **Constraint solving direktno primenjiv na NCC registre**: `constraint dim_c { img_w inside {[TMP_MIN_W:MAX_W]}; tmp_w inside {[TMP_MIN_W:img_w]}; img_h inside {[TMP_MIN_H:MAX_H]}; tmp_h inside {[TMP_MIN_H:img_h]}; solve img_w before tmp_w; solve img_h before tmp_h; }` — analogno `solve invalid before req_cmd_in` iz `packet.sv`, dimenzije template-a moraju biti ograničene *posle* što je poznata dimenzija slike (usko povezane promenljive), inače se generišu ilegalne kombinacije koje FSM od `ncc_core` (23 stanja) nikad ne bi trebalo da primi.
- **`dist` konstrukcija za distribuciju AW/W ordering scenarija**: `constraint aw_w_order_c { order dist {AW_FIRST:=45, W_FIRST:=45, SIMULTANEOUS:=10}; }` u sequence item-u za AXI write na S00/S01 — direktno preslikavanje `cmd_c`/`invalid_c` distribucija iz `packet.sv`, sa ciljem da se poznati fiksovani bug (W pre AW) redovno okida u regresiji, a ne samo povremeno kao slučajan nusprodukt potpuno ravnomerne randomizacije.
- **Dva odvojena PRNG seed-a (Metod 3)**: koristiti jedan seed za AXI-Lite agent (konfiguracija/kontrola) i drugi, nezavisan, za AXI-Full agent (image/template/results memorija) — sprečava da promena seed-a testa "pomeri" oba agenta na korelisan način (Metod 2 problem), što bi maskiralo interesantne kombinacije tajminga između config writes i memory bursts.
- **Reproducibilnost bug-ova**: pošto je AXI W/AW hang bug već fiksovan u HW-u, regresija ga mora povremeno ponovo okinuti — čuvanje `seed` + randomization control file (analogno slajdovima 44-48) za svaki test koji otkrije regresiju je obavezno radi debug-a (isti zahtev kao "ponovljivost" sa predavanja).
- **Scoreboard/checker po uzoru na `tb_random_on_the_fly`**: `output_checker`/`scoreboard` par (asocijativni niz zahteva indeksiran po tagu/adresi + mailbox/analysis port za pristigle odgovore) direktno se preslikava na NCC scoreboard koji čuva poslednji upisan (img_w,img_h,tmp_w,tmp_h,img_addr,tmp_addr) skup registara po pokretanju i poredi očekivani NCC² rezultat (izračunat referentno ili preuzet iz `ncc_core_real_tb` golden vrednosti) sa vrednošću pročitanom sa `ADDR_RESULTS`/results regiona na S01.
- **Corner-case/rare-event kampanja specifično za NCC**: forsirati retke vremenske kombinacije — start pulse dok je `busy=1` (treba da bude ignorisan ili odbijen), čitanje `ADDR_RESULTS` pre `done_sticky=1` (treba da vrati stare/nevalidne podatke ili blokira), simultani pristupi S00 i S01 tokom aktivnog izračunavanja na oba `ncc_accel` IP jezgra u `ncc_system` (dva instancirana akceleratora na istom `axi_interconnect`-u) — ovo su NCC-specifični ekvivalenti "izazivanja retkih događaja" sa predavanja.

[[Vezba 06-07 - Sekvence i drajver]] | [[Vezba 08 - Monitor]]
