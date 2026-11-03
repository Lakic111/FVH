import os, re, glob, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_common import Svg, Dokument
SNIMCI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "snimci")

IZLAZ = "C:/Users/pc/Desktop/FVH/Dokumentacija/v2_uprosceno"
LOGOVI = "C:/Users/pc/Desktop/FVH/predaja/verif/result/log"
d = Dokument(IZLAZ, "FVH_dokumentacija_y25-g10")
C = lambda s: f"<code>{s}</code>"

# ====================================================================== podaci iz regresije
def iz_loga(f):
    s = open(f, encoding="utf-8", errors="replace").read()
    t = re.search(r"\$finish called at time : ([0-9.]+) ns", s)
    p = re.search(r"(\d+) compared, (\d+) errors", s)
    dm = re.search(r"image (\d+)x(\d+), template (\d+)x(\d+)", s)
    ok = ("UVM_ERROR :    0" in s) and ("UVM_FATAL :    0" in s)
    pokretanja = len(re.findall(r"\[SB\] prediction:", s))
    return dict(t=float(t.group(1)) / 1000 if t else 0, por=int(p.group(1)) if p else 0,
                gr=int(p.group(2)) if p else -1, dim=dm.groups() if dm else None, ok=ok, pok=pokretanja)

rez = {}
for f in glob.glob(LOGOVI + "/test_*_s*.log"):
    rez[os.path.basename(f)[:-4]] = iz_loga(f)
assert len(rez) == 22, len(rez)
ukupno_por = sum(r["por"] for r in rez.values())

# ====================================================================== naslovna
naslovna = """<div class="cover">
  <div class="subj">Funkcionalna verifikacija hardvera</div>
  <div class="rule"></div>
  <div class="title">Verifikacija NCC akceleratora: UVM okruženje, pokrivenost i regresija</div>
  <div class="sub">Druga verzija okruženja, usklađena sa vežbama</div>
  <div class="rule"></div>
  <div class="meta">Grupa: <b>y25-g10</b><br>Prilog uz dokumentaciju predmeta Projektovanje složenih digitalnih sistema</div>
</div>"""

# ====================================================================== 1. uvod
d.h1("1. Uvod", first=True)
d.p(f"Predmet verifikacije je IP jezgro {C('ncc_accel')}: hardverski akcelerator normalizovane unakrsne "
    "korelacije (NCC), projektovan u okviru predmeta Projektovanje složenih digitalnih sistema za prepoznavanje "
    "šahovskih figura. Jezgro je opisano u VHDL-u. Ovaj dokument opisuje verifikaciono okruženje napisano u "
    "SystemVerilog-u po UVM metodologiji, koje se pokreće u Vivado XSim-u i u Cadence Xcelium-u.", noind=True)
d.p(f"Verifikacija je na <b>IP nivou</b>: DUT je {C('ncc_accel')} sa oba magistralna interfejsa, AXI4-Lite (S00) "
    "za kontrolne registre i AXI4-Full (S01) za memorije slike, šablona i rezultata. To je ista konfiguracija koja "
    "se integriše u sistem na ploči. Računsko jezgro {0} je ranije provereno na nivou RTL-a, pa je ovde težište na "
    "tome da DUT ispravno radi kada se pobuđuje preko magistrala, kao što ga koristi procesor.".format(C("ncc_core")))
d.p("Ovo je druga verzija okruženja. Prva verzija koristila je konstrukcije koje nisu obrađene na vežbama "
    "(SVA tvrdnje, clocking blokove, virtuelni sekvencer i drugo) i bila je raspoređena u oko šezdeset fajlova. "
    "Nova verzija koristi isključivo elemente obrađene na vežbama 1–13 i ima 13 SystemVerilog fajlova. Cilj "
    "verifikacije, DUT i plan pokrivenosti su isti; promenjena je samo implementacija okruženja.")
d.tabela("platforma", "Platforma i alati",
         ["Stavka", "Vrednost"],
         [["DUT", f"{C('ncc_accel')} (VHDL-2008), zamrznuta kopija u {C('rtl/')}"],
          ["Jezik okruženja", "SystemVerilog, UVM 1.2"],
          ["Simulator 1", "Vivado XSim 2025.2 (UVM 1.2 uz Vivado)"],
          ["Simulator 2", "Cadence Xcelium 19.03 (UVM uz Xcelium)"],
          ["Takt u simulaciji", "100 MHz (perioda 10 ns)"],
          ["Pokretanje", f"{C('./regression.sh')}, za oba simulatora"]])

# ====================================================================== 2. DUT
d.h1("2. Uređaj koji se verifikuje")
d.p(f"Akcelerator računa mapu NCC² između slike (do 90×90 piksela) i šablona (do 30×30 piksela). Procesor "
    f"upisuje sliku i šablon u memorije preko S01, dimenzije u registre preko S00, pokreće obradu upisom u "
    f"{C('CTRL')} i čeka da bit {C('done')} u registru {C('STATUS')} postane 1. Mapa rezultata se zatim čita sa S01.",
    noind=True)
d.h2("2.1. Kontrolni registri (S00)")
d.p("Adresna magistrala S00 je široka šest bita, pa su važeće samo adrese 0x00–0x3F. Okruženje koristi šest registara "
    f"(Tabela {d.sledeca_tabela()}).")
d.tabela("registri_s00", "Kontrolni registri na S00",
         ["Adresa", "Registar", "Opis"],
         [[C("0x00"), C("IMG_W"), "širina slike, bitovi 7:0"],
          [C("0x04"), C("IMG_H"), "visina slike, bitovi 7:0"],
          [C("0x08"), C("TMP_W"), "širina šablona, bitovi 7:0"],
          [C("0x0C"), C("TMP_H"), "visina šablona, bitovi 7:0"],
          [C("0x10–0x2C"), "—", "registri bez dejstva u jezgru: upis pa čitanje vraća upisano"],
          [C("0x30"), C("CTRL"), "upis sa bitom 0 = 1 pokreće obradu i briše done"],
          [C("0x34"), C("STATUS"), "bit 0 = done (ostaje 1 do sledećeg starta), bit 1 = busy; samo čitanje"]],
         ["c", "c", ""])
d.h2("2.2. Memorijski prostor (S01)")
d.p(f"S01 ima 17-bitnu adresu (128 KB). Bitovi 16:15 biraju oblast, a bitovi 14:2 reč unutar oblasti. Jedan piksel "
    f"zauzima jednu 32-bitnu reč (Tabela {d.sledeca_tabela()}).")
d.tabela("oblasti_s01", "Oblasti memorijskog prostora S01",
         ["Oblast", "Pomeraj", "Ponašanje"],
         [["slika", C("+0x00000"), "8192 reči; pamti se samo donjih 8 bita podatka"],
          ["šablon", C("+0x08000"), "dekoder koristi 10 bita adrese, pa se sadržaj ponavlja na svakih 1024 reči"],
          ["rezultat", C("+0x10000"), "NCC² u formatu Q1.31; samo čitanje, upis se zanemaruje uz odgovor OKAY"],
          ["nemapirano", C("+0x18000"), "čitanje vraća nule, upis nema efekta"]])
d.h2("2.3. Dozvoljeni ulazi")
d.p(f"Jezgro podržava sliku od 1×1 do 90×90 i šablon od 1×1 do 30×30, pri čemu šablon ne sme biti veći od slike. "
    f"Za veće vrednosti {C('ncc_core.vhd')} prekida simulaciju (VHDL assert sa nivoom failure). Sve sekvence u "
    "okruženju zato generišu samo dozvoljene dimenzije. Mapa rezultata ima (širina slike − širina šablona + 1) × "
    "(visina slike − visina šablona + 1) vrednosti, red po red.")

# ====================================================================== 3. struktura
d.h1("3. Struktura okruženja")
n_ok = d.sledeca_slika()
d.p(f"Struktura okruženja prikazana je na slici {n_ok}. Okruženje ima <b>jedan agent koji vozi obe magistrale</b>. "
    f"Transakcija ({C('ncc_item')}) sama nosi informaciju da li ide na S00 ili na S01, pa jedna sekvenca na jednom "
    "sekvenceru može redom da upiše sliku u memoriju, dimenzije u registre, pokrene jezgro i pročita rezultat. "
    "Zbog toga nije potreban virtuelni sekvencer, a test pokreće sekvencu direktno na sekvenceru agenta, kao u "
    "vežbama 6–10.", noind=True)

s = Svg(760, 500)
s.box(8, 8, 744, 484, [], fill="#fafafa")
s.text(18, 26, "ncc_top (modul)", bold=True)
s.box(24, 36, 486, 446, [], fill="#ffffff")
s.text(34, 54, "uvm_test_top : test_smoke | test_cov | test_random", bold=True)
s.box(84, 66, 232, 40, ["sekvenca: ncc_smoke_seq,", "ncc_cov_seq, ncc_random_seq"], dash=True, size=10.5)
s.box(40, 120, 454, 350, [], fill="#f4f4f4")
s.text(50, 138, "env : ncc_env", bold=True)
s.box(56, 148, 276, 300, [], fill="#e9e9e9")
s.text(66, 166, "agent : ncc_agent", bold=True, size=10.5)
s.text(322, 166, "cfg : ncc_config", size=10.5, anchor="end")
s.box(84, 178, 220, 44, ["seqr : ncc_sequencer"])
s.box(84, 262, 220, 44, ["drv : ncc_driver"])
s.box(84, 342, 220, 62, ["mon : ncc_monitor", "cg_dims, cg_ctrl, cg_axi"], bold_first=True)
s.box(350, 342, 136, 62, ["scbd : ncc_scoreboard", "referentni model", "ncc_model()"], bold_first=True, size=10.5)
s.line([(194, 106), (194, 178)]); s.text(200, 132, "start()", size=10)
s.line([(194, 222), (194, 262)]); s.text(200, 246, "seq_item_port", size=10)
s.line([(304, 284), (548, 284)]); s.text(410, 278, "postavlja signale", size=10, anchor="middle")
s.line([(548, 425), (194, 425), (194, 404)]); s.text(410, 419, "uzorkuje signale", size=10, anchor="middle")
s.line([(304, 373), (350, 373)]); s.text(327, 362, "TLM", size=9.5, anchor="middle")
s.box(548, 150, 40, 300, [], fill="#dcdcdc")
s.text(572, 300, "ncc_if (virtuelni interfejs)", size=11, anchor="middle", rot=-90)
s.box(610, 150, 130, 300, [], fill="#f0f0f0")
s.text(675, 168, "dut : ncc_accel", bold=True, anchor="middle")
s.box(622, 182, 106, 70, ["S00", "AXI4-Lite", "registri"], bold_first=True)
s.box(622, 268, 106, 48, ["ncc_core"])
s.box(622, 332, 106, 100, ["S01", "AXI4-Full", "slika, šablon,", "rezultat"], bold_first=True)
s.line([(588, 217), (622, 217)], back=True)
s.line([(588, 382), (622, 382)], back=True)
d.slika(s, "struktura_okruzenja",
        "Struktura verifikacionog okruženja. Drajver pobuđuje obe magistrale DUT-a preko interfejsa "
        f"{C('ncc_if')}; monitor uzorkuje iste signale, sakuplja pokrivenost i šalje transakcije scoreboard-u.")

d.p(f"Svaka klasa je u svom fajlu, a paket {C('ncc_pkg')} ih uključuje direktivom {C('`include')}, isto kao "
    f"paketi u vežbama 9 i 10. Spisak fajlova dat je u tabeli {d.sledeca_tabela()}.")
d.tabela("fajlovi", "Fajlovi okruženja",
         ["Fajl", "Sadržaj", "Linija"],
         [[C("sv/ncc_if.sv"), "interfejs sa signalima S00 i S01", "70"],
          [C("sv/ncc_pkg.sv"), "konstante (adrese registara, oblasti S01), tipovi, uključivanje klasa", "40"],
          [C("sv/ncc_item.sv"), "transakcija: jedan upis ili čitanje na S00 ili S01", "36"],
          [C("sv/ncc_config.sv"), "konfiguracija agenta (aktivan/pasivan)", "14"],
          [C("sv/ncc_sequencer.sv"), "sekvencer", "10"],
          [C("sv/ncc_driver.sv"), "drajver za obe magistrale", "168"],
          [C("sv/ncc_monitor.sv"), "monitor i tri covergroup-e", "269"],
          [C("sv/ncc_agent.sv"), "agent: drajver, sekvencer, monitor", "35"],
          [C("sv/ncc_scoreboard.sv"), "scoreboard i referentni model NCC²", "185"],
          [C("sv/ncc_env.sv"), "okruženje: agent i scoreboard", "24"],
          [C("sv/ncc_sequences.sv"), "osnovna, smoke, cov i random sekvenca", "364"],
          [C("sv/ncc_tests.sv"), "test_base i tri testa", "92"],
          [C("sv/ncc_top.sv"), "takt, reset, DUT, pokretanje testa", "101"],
          [C("run.f"), "spisak izvornih fajlova za oba simulatora", "10"],
          [C("regression.sh"), "prevođenje, svi testovi, izveštaj pokrivenosti", "92"]],
         ["", "", "n"])
d.p(f"Tabela {d.sledeca_tabela()} pokazuje odakle potiče svaka konstrukcija koja se koristi u okruženju. Nijedna "
    "konstrukcija nije van gradiva vežbi.")
d.tabela("konstrukcije_vezbe", "Konstrukcije u okruženju i vežbe u kojima su obrađene",
         ["Konstrukcija", "Gde se koristi", "Vežba"],
         [[f"{C('interface')}, {C('@(posedge vif.clk iff ...)')}, {C('<=')}", "interfejs, drajver, monitor", "5, 6, 8, 13"],
          [f"{C('uvm_sequence_item')}, {C('uvm_field_*')}", "transakcija, konfiguracija", "6, 9"],
          [f"{C('uvm_sequencer')}, {C('uvm_driver')}, {C('get_next_item')}/{C('item_done')}", "sekvencer, drajver", "6, 7"],
          [f"{C('uvm_monitor')}, {C('uvm_analysis_port')}", "monitor", "8"],
          [f"{C('uvm_agent')}, {C('is_active')}, {C('uvm_config_db')}", "agent, test, top", "9"],
          [f"{C('uvm_scoreboard')}, {C('uvm_analysis_imp')}, {C('report_phase')}", "scoreboard", "8, 10"],
          [f"{C('covergroup')}, {C('coverpoint')}, {C('bins')}, {C('cross')}, {C('ignore_bins')}, {C('sample()')}", "monitor", "11, 13"],
          [f"{C('rand')}, {C('constraint')}, {C('dist')}, {C('inside')}, {C('->')}, {C('randomize() with')}", "transakcija, sekvence", "4"],
          [f"{C('fork')} / {C('join')}", "drajver: kanali AW i W upisa", "3"],
          [f"dinamički nizovi, redovi {C('[$]')}, asocijativni nizovi", "monitor, scoreboard, sekvence", "2"],
          [f"{C('start_item')}/{C('finish_item')}, {C('raise_objection')}", "sekvence, testovi", "6"],
          [f"{C('$urandom_range')}, {C('-sv_seed')}/{C('-svseed')}, regresija", "random sekvenca, regression.sh", "12"],
          [f"{C('xcrg')} izveštaj pokrivenosti", "regression.sh", "11"]],
         ["", "", "c"])

# ====================================================================== 4. komponente
d.h1("4. Komponente okruženja")
d.h2("4.1. Interfejs")
d.p(f"{C('ncc_if')} sadrži sve signale obe magistrale, sa fiksnim širinama: 6-bitna adresa za S00 i 17-bitna za S01. "
    "Interfejs ne sadrži nikakvu logiku, isto kao interfejsi u vežbama. Instancira se u modulu "
    f"{C('ncc_top')}, povezuje sa portovima DUT-a i prosleđuje komponentama preko {C('uvm_config_db')} pod imenom "
    f"{C('\"ncc_if\"')}.", noind=True)
d.h2("4.2. Transakcija")
d.p(f"{C('ncc_item')} opisuje jedan prenos (Tabela {d.sledeca_tabela()}). Polja {C('order')} i {C('gap')} su "
    "slučajna i biraju redosled kanala pri upisu; ostala polja postavlja sekvenca.", noind=True)
d.tabela("polja_transakcije", f"Polja transakcije {C('ncc_item')}",
         ["Polje", "Tip", "Značenje"],
         [[C("bus"), C("bus_e"), f"{C('BUS_S00')} ili {C('BUS_S01')}"],
          [C("rw"), C("rw_e"), f"{C('WRITE')} ili {C('READ')}"],
          [C("addr"), C("bit [16:0]"), "S00: adresa registra; S01: bajtska adresa (oblast·0x8000 + reč·4)"],
          [C("len"), C("int unsigned"), "broj reči (beat-ova); za S00 uvek 1"],
          [C("data"), C("bit [31:0] data[]"), "podaci: za upis ih zadaje sekvenca, za čitanje ih popunjava drajver"],
          [C("strb"), C("bit [3:0]"), "WSTRB pri upisu"],
          [C("resp"), C("bit [1:0]"), "BRESP ili RRESP, popunjava drajver/monitor"],
          [C("order"), C("rand order_e"), f"{C('ORDER_AW_FIRST')} : {C('ORDER_W_FIRST')} : {C('ORDER_SIMUL')} = 2 : 2 : 1"],
          [C("gap"), C("rand int unsigned"), "kašnjenje drugog kanala u taktovima: 0 za SIMUL, inače 1–4"]])
d.p("Ograničenja su napisana kao u vežbi 4:")
d.pre("constraint c_order { order dist {ORDER_AW_FIRST := 2, ORDER_W_FIRST := 2, ORDER_SIMUL := 1}; }\n"
      "constraint c_gap   { order == ORDER_SIMUL -> gap == 0;\n"
      "                     order != ORDER_SIMUL -> gap inside {[1:4]}; }")
d.h2("4.3. Konfiguracija i sekvencer")
d.p(f"{C('ncc_config')} ima jedno polje, {C('is_active')}. Test pravi konfiguraciju i postavlja je u "
    f"{C('uvm_config_db')}; agent je preuzima i, ako je aktivan, pravi drajver i sekvencer. U pasivnom režimu agent "
    f"ima samo monitor. {C('ncc_sequencer')} je običan {C('uvm_sequencer #(ncc_item)')}.", noind=True)
d.h2("4.4. Drajver")
d.p(f"Drajver uzima transakcije jednu po jednu ({C('get_next_item')} / {C('item_done')}) i, prema poljima "
    f"{C('bus')} i {C('rw')}, poziva jedan od četiri taska: upis i čitanje na S00, upis i čitanje burst-a na S01. "
    f"Signali se postavljaju neblokirajućom dodelom, a na odgovor se čeka sa {C('@(posedge vif.clk iff ...)')}, kao "
    "u APB drajveru iz vežbe 13.", noind=True)
n_red = d.sledeca_slika()
d.p(f"Kod upisa, adresni kanal (AW) i podatkovni kanal (W) rade u dve niti unutar {C('fork ... join')}. Nit koja "
    f"kreće druga čeka {C('gap')} taktova. Tako se dobijaju tri redosleda (slika {n_red}): AW pre W, W pre AW i oba "
    "istovremeno. Redosled je važan jer je raniji S00 visio kada podatak (W) stigne pre adrese (AW); zato je provera "
    "sva tri redosleda u svakoj oblasti centralni cilj plana pokrivenosti.")
s = Svg(720, 300)
x0, cw = 170, 50
def talas(sv, y, nivoi, ime):
    sv.text(20, y + 14, ime, size=11)
    pts = []
    for i, nv in enumerate(nivoi):
        yy = y + (2 if nv else 20)
        pts += [(x0 + i * cw, yy), (x0 + (i + 1) * cw, yy)]
    sv.line(pts, arrow=False, sw=1.4)
def takt(sv, y):
    sv.text(20, y + 14, "clk", size=11)
    pts = []
    for i in range(10):
        pts += [(x0 + i * cw, y + 20), (x0 + i * cw, y + 2), (x0 + i * cw + cw / 2, y + 2),
                (x0 + i * cw + cw / 2, y + 20), (x0 + (i + 1) * cw, y + 20)]
    sv.line(pts, arrow=False, sw=1)
takt(s, 10)
red = [("ORDER_AW_FIRST (gap = 2)", [0,1,1,1,0,0,0,0,0,0], [0,0,0,1,1,1,0,0,0,0]),
       ("ORDER_W_FIRST (gap = 2)",  [0,0,0,1,1,1,0,0,0,0], [0,1,1,1,0,0,0,0,0,0]),
       ("ORDER_SIMUL (gap = 0)",    [0,1,1,1,1,0,0,0,0,0], [0,1,1,1,1,0,0,0,0,0])]
y = 50
for ime, aw, w in red:
    s.text(20, y + 4, ime, size=11, bold=True)
    talas(s, y + 10, aw, "AWVALID")
    talas(s, y + 38, w, "WVALID")
    y += 82
for i in range(11):
    s.raw(f'<line x1="{x0 + i * cw}" y1="34" x2="{x0 + i * cw}" y2="290" stroke="#ccc" stroke-width="0.6"/>')
d.slika(s, "redosled_aw_w",
        f"Tri redosleda postavljanja AWVALID i WVALID pri upisu. Nit koja kreće druga kasni {C('gap')} taktova; "
        "signal se spušta posle rukovanja (READY).")
d.p("Čitanje je jednostavnije: postavlja se ARVALID, posle rukovanja RREADY, i prima se jedna reč (S00) ili "
    f"{C('len')} reči (S01). Na S01 se uvek koristi INCR burst sa 4 bajta po beat-u; ostala polja kanala (ID, "
    "CACHE, PROT, QOS) su nule.")
d.h2("4.5. Monitor i pokrivenost")
d.p(f"Monitor na svaku uzlaznu ivicu takta poziva dve funkcije, {C('collect_s00()')} i {C('collect_s01()')}, koje "
    "gledaju signale interfejsa i sklapaju transakcije:", noind=True)
d.ul([f"upis je završen kada se vidi rukovanje na kanalu odgovora (B): tada su adresa i podatak već primljeni; na "
      "S01 podaci svih beat-ova skupljaju se u red i porede sa dužinom iz AWLEN;",
      f"čitanje sa S00 je završeno rukovanjem na kanalu R, a na S01 beat-om sa RLAST;",
      f"redosled AW/W meri se po taktu u kome je VALID prvi put postavljen (brojač {C('cycle')});",
      f"svaka sklopljena transakcija šalje se kroz {C('item_collected_port')} scoreboard-u."])
d.p(f"Monitor proverava i jedno pravilo protokola: popravljeni DUT nikada ne podiže AWREADY i WREADY u istom taktu. "
    f"Ako se to desi, prijavljuje {C('uvm_error')} sa porukom da se vratio AW/W bug. Ova provera je napisana kao "
    f"običan {C('if')}, bez tvrdnji (assert), koje nisu u gradivu.")
n_pok = d.sledeca_tabela()
d.p(f"Pokrivenost se prikuplja u samom monitoru, kao u APB monitoru iz vežbe 13. Tri covergroup-e opisane su u "
    f"tabeli {n_pok}. Uzorkuju se pozivom {C('sample()')} u trenutku kada je odgovarajuća transakcija sklopljena:")
d.ul([f"{C('cg_axi')} — na svaki završen upis (S00 i S01);",
      f"{C('cg_ctrl')} — na svaki upis u {C('CTRL')}, sa vrednostima busy i done iz poslednjeg pročitanog STATUS-a;",
      f"{C('cg_dims')} — na svaki upis 1 u {C('CTRL')}, sa poslednjim upisanim dimenzijama."])
d.tabela("plan_pokrivenosti", "Plan pokrivenosti",
         ["Covergroup", "Tačka / ukrštanje", "Bin-ovi", "Šta se proverava"],
         [[C("cg_dims"), C("cp_img_w"), "1 | 2–44 | 45 | 46–89 | 90", "širina slike, uz granice i vrednost 45 (umanjena slika polja)"],
          ["", C("cp_img_h"), "isto kao širina", "visina slike"],
          ["", C("cp_tmp_w"), "1 | 2–14 | 15 | 16–29 | 30", "širina šablona"],
          ["", C("cp_tmp_h"), "isto kao širina", "visina šablona"],
          ["", C("x_img_tmp"), "19 (od 25; 6 nemogućih isključeno)", "kombinacije širine slike i šablona; šablon ≤ slika"],
          ([C("cg_ctrl"), C("cp_start"), "0 | 1", "upis 0 ili 1 u CTRL"], "sep"),
          ["", C("cp_busy"), "0 | 1", "jezgro zauzeto u trenutku upisa"],
          ["", C("cp_done"), "0 | 1", "done postavljen u trenutku upisa"],
          ["", C("x_start_busy"), "4", "uključujući start dok jezgro radi (test T7)"],
          ["", C("x_start_done"), "4", "uključujući upis 0 posle završenog posla"],
          ([C("cg_axi"), C("cp_order"), "AW_FIRST | W_FIRST | SIMUL", "redosled kanala"], "sep"),
          ["", C("cp_region"), "s00 | image | template | result | unmapped", "odredište upisa"],
          ["", C("x_order_region"), "15", "<b>sva tri redosleda u svakoj oblasti</b> — centralni cilj plana"],
          ["", C("cp_len"), "1 | 2 | 3–15 | 16–255 | 256", "dužina burst-a, uz najduži dozvoljeni (256)"],
          ["", C("cp_strb"), "full (F) | 1 | 3 | 9 | other", "WSTRB, uključujući upis bez bita 0"]])
d.p(f"Ukrštanje {C('x_img_tmp')} isključuje kombinacije koje ne mogu da se pojave jer šablon ne sme biti veći od "
    f"slike, pomoću {C('ignore_bins')} i {C('binsof')} (vežba 11):")
d.pre("x_img_tmp : cross cp_img_w, cp_tmp_w {\n"
      "   ignore_bins impossible_min   = binsof(cp_img_w.min) && !binsof(cp_tmp_w.min);\n"
      "   ignore_bins impossible_below = binsof(cp_img_w.below) &&\n"
      "                                  (binsof(cp_tmp_w.above) || binsof(cp_tmp_w.max));\n"
      "}")
d.h2("4.6. Agent i okruženje")
d.p(f"{C('ncc_agent')} pravi monitor uvek, a drajver i sekvencer samo u aktivnom režimu, i povezuje "
    f"{C('drv.seq_item_port')} sa {C('seqr.seq_item_export')}. {C('ncc_env')} pravi agent i scoreboard i povezuje "
    f"{C('agent.mon.item_collected_port')} sa {C('scbd.item_collected_imp')}. Struktura je ista kao u vežbi 10.",
    noind=True)
d.h2("4.7. Scoreboard i referentni model")
n_sb = d.sledeca_slika()
d.p(f"Scoreboard dobija isključivo transakcije koje je monitor video na magistralama (slika {n_sb}). Od njih gradi "
    "sopstvenu kopiju memorije slike i šablona (senku), pamti dimenzije, pri pokretanju jezgra računa očekivanu mapu "
    "rezultata i svako čitanje oblasti rezultata poredi sa njom.", noind=True)
s = Svg(720, 380)
s.box(260, 10, 200, 36, ["transakcija iz monitora"], fill="#e9e9e9")
s.line([(360, 46), (360, 66)])
s.box(300, 66, 120, 30, ["S00 ili S01?"])
s.line([(300, 81), (170, 81), (170, 110)]); s.text(230, 75, "S00", size=10, anchor="middle")
s.line([(420, 81), (550, 81), (550, 110)]); s.text(490, 75, "S01", size=10, anchor="middle")
s.box(40, 110, 260, 44, ["upis u IMG_W, IMG_H, TMP_W, TMP_H", "→ zapamti dimenzije"])
s.box(40, 166, 260, 44, ["čitanje STATUS", "→ zapamti busy i done"])
s.box(40, 222, 260, 56, ["upis 1 u CTRL", "jezgro zauzeto → zanemari (jezgro ignoriše)", "inače → predict()"])
s.box(40, 300, 260, 56, ["predict(): ncc_model(senka, dimenzije)", "→ očekivana mapa rezultata"], fill="#f2f2f2")
s.line([(170, 278), (170, 300)])
s.box(420, 110, 260, 56, ["upis u sliku ili šablon", "(samo ako je WSTRB[0] = 1)", "→ senka memorije"])
s.box(420, 190, 260, 44, ["upis u oblast rezultata", "→ zanemaruje se (samo čitanje)"])
s.box(420, 258, 260, 56, ["čitanje oblasti rezultata", "→ compare(): svaka reč sa očekivanom"])
s.box(470, 334, 160, 30, ["greška ili poklapanje"], fill="#f2f2f2")
s.line([(550, 314), (550, 334)])
s.line([(420, 138), (360, 138), (360, 328), (300, 328)], dash=True)
s.text(366, 230, "senka", size=10)
s.line([(300, 349), (470, 349)], dash=True)
s.text(385, 343, "očekivana mapa", size=10, anchor="middle")
d.slika(s, "tok_scoreboarda",
        "Obrada transakcija u scoreboard-u. Isprekidane linije: senka memorije ulazi u referentni model, a "
        "očekivana mapa u poređenje.")
d.p(f"Referentni model, funkcija {C('ncc_model()')}, računa isto što i {C('ncc_core.vhd')}. Za svaki položaj prozora "
    "(u, v) računa se srednja vrednost prozora slike f̄ i šablona t̄ (celobrojno, sa zaokruživanjem: "
    "(zbir + n/2) / n), pa")
d.html('<div class="formula">NCC²(u,v) = <span class="frac"><span class="num">'
       '( Σ (f − f̄)(t − t̄) )²</span><span class="den">Σ (f − f̄)² · Σ (t − t̄)²</span></span>'
       ' · 2<sup>31</sup></div>')
d.p(f"Rezultat je u formatu Q1.31: {C('0x80000000')} znači 1,0, odnosno savršeno poklapanje. Ako je jedan od "
    f"imenilaca nula (ravan prozor ili ravan šablon), rezultat je 0. Zbirovi se računaju u {C('int')}, kvadrat "
    f"brojioca i proizvod imenilaca u {C('longint')}, a deljenje sa pomeranjem za 31 bit u 83-bitnom vektoru, "
    "jer međurezultat ne staje u 64 bita. Model je bit-tačan: u celoj regresiji nijedno od "
    f"{ukupno_por} poređenja nije dalo razliku.")
d.p(f"Scoreboard zna i za jedno ponašanje DUT-a otkriveno tokom verifikacije: upis u {C('CTRL')} dok jezgro radi "
    "jezgro ignoriše (nalaz N2, poglavlje 10). Zato se u tom slučaju nova predikcija ne računa. Na kraju simulacije, "
    f"u {C('report_phase')}, scoreboard prijavljuje grešku ako nije uporedio nijedan rezultat; time se sprečava da "
    "test prođe samo zato što ništa nije provereno.")
d.h2("4.8. Vrh okruženja")
d.p(f"Modul {C('ncc_top')} generiše takt od 100 MHz i reset aktivan na nuli u trajanju od 10 taktova, instancira "
    f"interfejs i DUT, postavlja virtuelni interfejs u {C('uvm_config_db')} i poziva {C('run_test()')}. Ime testa "
    f"bira se argumentom {C('+UVM_TESTNAME')}. Ako simulacija ne završi za 50 ms simulacionog vremena, prekida se sa "
    f"{C('uvm_fatal')}.", noind=True)

# ====================================================================== 5. sekvence i testovi
d.h1("5. Sekvence i testovi")
d.h2("5.1. Osnovna sekvenca")
d.p(f"{C('ncc_base_seq')} sadrži pomoćne taskove koje koriste ostale sekvence (Tabela {d.sledeca_tabela()}).",
    noind=True)
d.tabela("osnovna_sekvenca", f"Pomoćni taskovi osnovne sekvence {C('ncc_base_seq')}",
         ["Task / funkcija", "Šta radi"],
         [[C("reg_write(addr, data, ord)"), "upis jednog registra na S00, sa zadatim redosledom AW/W"],
          [C("reg_read(addr, data)"), "čitanje jednog registra sa S00"],
          [C("mem_write(region, word, d[], ord, strb)"), "upis niza reči na S01; veći niz deli na burst-ove"],
          [C("mem_read(region, word, n, d[])"), "čitanje n reči sa S01, takođe podeljeno na burst-ove"],
          [C("burst_len(word, remaining)"), "najviše 256 beat-ova i bez prelaska granice od 4 KB (1024 reči)"],
          [C("wait_done(ok)"), "čita STATUS dok nije done = 1 i busy = 0; posle 200 000 čitanja javlja grešku"],
          [C("run_job(iw, ih, tw, th)"), "upis dimenzija, start, čekanje i čitanje cele mape rezultata"],
          [C("random_order()"), "slučajan redosled AW/W za random sekvencu"]])
d.p(f"Deljenje na burst-ove je posledica pravila AXI4: burst ima najviše 256 beat-ova i ne sme preći granicu od 4 KB. "
    "Slika od 400 piksela tako ide kao jedan burst od 256 i jedan od 144 reči.")
n_tok = d.sledeca_slika()
d.p(f"Svaki posao akceleratora u sekvencama ima isti tok, prikazan na slici {n_tok}.")
s = Svg(740, 170)
koraci = [("1. slika i šablon", "upis na S01"), ("2. dimenzije", "upis 4 registra (S00)"),
          ("3. start", "upis 1 u CTRL (S00)"), ("4. čekanje", "čitanje STATUS (S00)"),
          ("5. rezultat", "čitanje mape (S01)")]
for i, (a, b) in enumerate(koraci):
    x = 8 + i * 146
    s.box(x, 40, 128, 56, [a, b], bold_first=True, size=10.5, fill="#f2f2f2" if i % 2 == 0 else "#fff")
    if i < 4:
        s.line([(x + 128, 68), (x + 146, 68)])
s.line([(510, 96), (510, 120), (574, 120), (574, 96)])
s.text(542, 136, "dok nije done = 1 i busy = 0", size=10, anchor="middle")
s.text(370, 24, "sve transakcije idu kroz isti sekvencer i drajver", size=10.5, anchor="middle", italic=True)
s.text(658, 160, "scoreboard poredi", size=10, anchor="middle", italic=True)
d.slika(s, "tok_posla", "Tok jednog posla akceleratora u sekvencama.")
d.h2("5.2. Testovi")
d.p(f"Testovi nasleđuju {C('test_base')}, koji pravi konfiguraciju i okruženje i štampa topologiju. Svaki test u "
    f"{C('run_phase')} podiže objection, pokreće svoju sekvencu na {C('env.agent.seqr')} i spušta objection "
    f"(Tabela {d.sledeca_tabela()}).", noind=True)
d.tabela("testovi", "Testovi",
         ["Test", "Sekvenca", "Šta proverava"],
         [[C("test_smoke"), C("ncc_smoke_seq"), "ceo put kroz DUT na slici 4×4 i šablonu 2×2; šablon je jednak prozoru "
           "na (1,1), pa tu mora biti tačno 0x80000000, a svih ostalih 8 vrednosti manje"],
          [C("test_cov"), C("ncc_cov_seq"), "usmereni slučajevi koji zatvaraju ceo plan pokrivenosti i proveravaju "
           f"ponašanje memorija i registra CTRL (Tabela {d.sledeca_tabela() + 1}); 24 posla akceleratora"],
          [C("test_random"), C("ncc_random_seq"), "slučajne dimenzije (slika 2–24, šablon 1–6), slučajni podaci, "
           "slučajni redosled kanala, slučajna čitanja i upisi u nekorišćene registre; menja se sa seed-om"]])
d.h2("5.3. Usmereni slučajevi u test_cov")
d.p(f"Pored pokrivenosti, {C('ncc_cov_seq')} proverava i konkretna ponašanja DUT-a. Te provere su u samoj sekvenci, "
    f"jer porede pročitano sa onim što je sekvenca nameravala da upiše (Tabela {d.sledeca_tabela()}).", noind=True)
n_prov = d.tabela("provere_test_cov", f"Provere u {C('test_cov')}",
         ["Slučaj", "Očekivano ponašanje", "Nalaz"],
         [["upis 0 u CTRL pre ikakvog posla", "jezgro se ne pokreće (busy = 0)", "N2"],
          ["čitanje šablona na reči 1024", "isto kao reči 0–3 (ponavljanje na 1024 reči)", "N3"],
          [f"upis {C('0xABCDEF5A')} u sliku", f"čitanje vraća {C('0x0000005A')}", "N3"],
          ["upis sa WSTRB = 0xE", "memorija se ne menja", "N3"],
          ["burst-ovi dužine 1, 2, 3, 16, 144 i 256", "scoreboard poredi rezultate posla nad tim podacima", "N4"],
          ["19 kombinacija širina + 4 kombinacije visina", "scoreboard poredi celu mapu svakog posla", "—"],
          ["upis 0, pa ponovo 1 u CTRL dok jezgro radi (T7)", "jezgro ignoriše oba upisa; rezultat je od prvog starta", "N2"],
          ["upis 0 u CTRL posle završenog posla", "done ostaje 1", "N2"],
          ["upis u oblast rezultata, sva tri redosleda", "mapa poslednjeg posla ostaje ista", "N3"],
          ["upis i čitanje nemapirane oblasti", "čitanje vraća nule", "N3"]],
         ["", "", "c"])

# ====================================================================== 6. pokrivenost
d.h1("6. Funkcionalna pokrivenost")
d.p(f"Posle pune regresije, baze pokrivenosti svih 22 pokretanja spajaju se alatom {C('xcrg')}. Ukupna "
    "funkcionalna pokrivenost je <b>100%</b>: sve tri covergroup-e, sve tačke i sva tri ukrštanja "
    f"(Tabela {d.sledeca_tabela()}). Cilj iz verifikacionog plana bio je 100% na ukrštanju redosled × oblast i "
    "najmanje 90% ukupno.", noind=True)
d.tabela("pokrivenost_tacke", "Pokrivenost po tačkama (spojeno preko cele regresije)",
         ["Covergroup", "Tačka / ukrštanje", "Pokriveno bin-ova", "%"],
         [[C("cg_dims"), C("cp_img_w") + ", " + C("cp_img_h"), "5 / 5, 5 / 5", "100"],
          ["", C("cp_tmp_w") + ", " + C("cp_tmp_h"), "5 / 5, 5 / 5", "100"],
          ["", C("x_img_tmp"), "19 / 19", "100"],
          ([C("cg_ctrl"), C("cp_start") + ", " + C("cp_busy") + ", " + C("cp_done"), "2 / 2 svaka", "100"], "sep"),
          ["", C("x_start_busy") + ", " + C("x_start_done"), "4 / 4, 4 / 4", "100"],
          ([C("cg_axi"), C("cp_order"), "3 / 3", "100"], "sep"),
          ["", C("cp_region"), "5 / 5", "100"],
          ["", C("x_order_region"), "15 / 15", "100"],
          ["", C("cp_len"), "5 / 5", "100"],
          ["", C("cp_strb"), "4 / 4", "100"]],
         ["", "", "c", "n"])
d.p(f"Izveštaj se pravi kao u vežbi 11: {C('xcrg -report_format html -dir cov -report_dir report')}. Alat učitava "
    f"baze svih 22 pokretanja iz direktorijuma {C('cov')} (svaki test upisuje svoju bazu pod imenom "
    f"{C('&lt;test&gt;_s&lt;seed&gt;')}) i od njih pravi jedan spojeni izveštaj, zato na početnoj strani piše „Number of Tests: 1”. "
    f"Početna strana izveštaja ({C('dashboard.html')}) prikazana je na slici {d.sledeca_slika()}, a spisak covergroup-a "
    f"na slici {d.sledeca_slika() + 1}. Klikom na ime covergroup-e otvara se stanje svake tačke i svakog bin-a.")
n_cov_sl = d.sledeca_slika()
d.slika_fajl(os.path.join(SNIMCI, "xcrg_dashboard.png"), "xcrg_dashboard",
             f"Početna strana izveštaja {C('xcrg')} posle cele regresije (Vivado XSim 2025.2).", "85%")
d.slika_fajl(os.path.join(SNIMCI, "xcrg_groups.png"), "xcrg_groups",
             "Pokrivenost po covergroup-ama: sve tri na 100%.")
d.p(f"Tabela {d.sledeca_tabela()} pokazuje koliko pokrivenosti daje svaka grupa testova sama. Usmereni test "
    f"{C('test_cov')} sam zatvara ceo plan. Slučajni test pokriva manje, jer su dimenzije namerno ograničene na male "
    "vrednosti da simulacija bude brza; njegova uloga je da sa različitim podacima i redosledima proveri da se DUT i "
    "referentni model slažu.")
d.tabela("pokrivenost_po_testu", "Pokrivenost po grupi testova",
         ["Grupa", "Pokretanja", "cg_dims", "cg_ctrl", "cg_axi", "Ukupno"],
         [[C("test_smoke"), "1", "17,1%", "40,0%", "55,7%", "37,6%"],
          [C("test_random"), "20", "26,1%", "40,0%", "69,0%", "45,0%"],
          [C("test_cov"), "1", "100%", "100%", "100%", "100%"],
          (["<b>cela regresija</b>", "22", "100%", "100%", "100%", "<b>100%</b>"], "sep")],
         ["", "n", "n", "n", "n", "n"])

# ====================================================================== 7. regresija
d.h1("7. Regresija")
n_reg = d.sledeca_slika()
d.p(f"Regresija se pokreće jednom komandom, {C('./regression.sh')} (slika {n_reg}). Skripta prevodi DUT i okruženje "
    "jednom, pokreće test_smoke i test_cov sa seed-om 1 i test_random sa seed-ovima 1–N (podrazumevano 20), za svaki "
    "test proverava log i na kraju spaja pokrivenost. Test je prošao ako u izveštaju UVM-a nema nijedne greške "
    f"({C('UVM_ERROR')}) ni fatalne greške ({C('UVM_FATAL')}) i ako VHDL nije prekinuo simulaciju.", noind=True)
s = Svg(740, 200)
s.box(8, 20, 110, 50, ["run.f", "spisak fajlova"], bold_first=True, size=10.5)
s.box(140, 20, 180, 50, ["prevođenje", "xvhdl + xvlog + xelab", "ili xrun -elaborate"], bold_first=True, size=10.5)
s.box(342, 20, 120, 50, ["test_smoke", "seed 1"], bold_first=True, size=10.5)
s.box(484, 20, 120, 50, ["test_cov", "seed 1"], bold_first=True, size=10.5)
s.box(626, 20, 106, 50, ["test_random", "seed 1 … N"], bold_first=True, size=10.5)
for a, b in [(118, 140), (320, 342), (462, 484), (604, 626)]:
    s.line([(a, 45), (b, 45)])
s.line([(679, 70), (679, 110), (560, 110)])
s.box(380, 92, 180, 40, ["provera loga", "UVM_ERROR = 0, UVM_FATAL = 0"], bold_first=True, size=10.5)
s.line([(380, 112), (330, 112)])
s.box(150, 92, 180, 40, ["xcrg", "spajanje baza pokrivenosti"], bold_first=True, size=10.5)
s.line([(150, 112), (118, 112), (118, 150)])
s.box(40, 150, 300, 40, ["result/log/  —  log svakog testa", "result/report/  —  izveštaj pokrivenosti"], size=10.5)
d.slika(s, "tok_regresije", f"Tok skripte {C('regression.sh')}.")
d.p(f"Rezultati regresije na Vivado XSim-u dati su u tabeli {d.sledeca_tabela()}. Prošlo je <b>22 od 22</b> "
    f"pokretanja, sa ukupno {ukupno_por} poređenja rezultata i nijednom greškom. Cela regresija, sa prevođenjem i "
    "izveštajem pokrivenosti, traje oko 113 s.")
redovi = []
def red_rez(ime, seed):
    r = rez[f"{ime}_s{seed}"]
    if ime == "test_cov":
        dim = f"24 posla (Tabela {n_prov})"
    elif r["dim"]:
        a, b, c, e = r["dim"]
        dim = f"{a}×{b} / {c}×{e}"
    else:
        dim = "—"
    return [C(ime), str(seed), dim, str(r["por"]), f"{r['t']:.1f}".replace(".", ","),
            '<span class="stanje-ok">PASS</span>' if r["ok"] and r["gr"] == 0 else "FAIL"]
redovi.append(red_rez("test_smoke", 1))
redovi.append(red_rez("test_cov", 1))
for sd in range(1, 21):
    redovi.append(red_rez("test_random", sd))
d.tabela("rezultati_regresije", "Rezultati regresije (Vivado XSim 2025.2)",
         ["Test", "Seed", "Slika / šablon", "Poređenja", "Sim. vreme [µs]", "Ishod"],
         redovi, ["", "c", "c", "n", "n", "c"])

# ====================================================================== 8. provera okruzenja
d.h1("8. Provera samog okruženja")
d.p("Test koji prolazi dokazuje nešto samo ako bi pao kada je DUT neispravan. Zato je okruženje provereno i namernim "
    f"unošenjem greške, u kopiji izvornih fajlova (Tabela {d.sledeca_tabela()}).", noind=True)
d.tabela("negativna_provera", "Namerno unete greške",
         ["Izmena", "Gde", "Rezultat"],
         [[f"zaokruživanje srednje vrednosti šablona izbačeno ({C('count / 2')} → 0)", C("rtl/ncc_core.vhd"),
           "test_cov: 307 grešaka od 1250 poređenja; test_random: 156/176 i 140/140 grešaka — <b>scoreboard hvata grešku u DUT-u</b>"],
          [f"svaki podatak upisa na S01 izmenjen ({C('wdata ^ 1')})", C("sv/ncc_driver.sv"),
           "test_cov pada (provere u sekvenci); scoreboard ne prijavljuje grešku"]])
d.p("Drugi slučaj je očekivan i važan za razumevanje okruženja. Greška je u pobudi, a ne u DUT-u: monitor na "
    "magistrali vidi izmenjen podatak, scoreboard gradi senku memorije od onoga što je video i predviđa rezultat za "
    "te podatke, a DUT za iste podatke daje isti rezultat. Scoreboard proverava da DUT ispravno obrađuje ono što mu "
    f"je stvarno poslato; da je poslato ono što je sekvenca nameravala, proveravaju poređenja u sekvenci {C('test_cov')}.")

# ====================================================================== 9. dva simulatora
d.h1("9. Dvostruka simulacija: XSim i Xcelium")
d.p(f"Ista lista fajlova ({C('run.f')}), isti testovi i ista provera loga koriste se na oba simulatora; skripta se "
    f"razlikuje samo po komandama za prevođenje i pokretanje (Tabela {d.sledeca_tabela()}).", noind=True)
d.tabela("dva_simulatora", "Pokretanje na dva simulatora",
         ["", "Vivado XSim 2025.2", "Cadence Xcelium 19.03"],
         [["Prevođenje", f"{C('xvhdl -2008')}, {C('xvlog -sv -L uvm')}, {C('xelab')}", f"{C('xrun -elaborate -v200x -relax -uvm')}"],
          ["Pokretanje testa", f"{C('xsim -R')} sa {C('-testplusarg UVM_TESTNAME=…')} i {C('-sv_seed')}", f"{C('xrun -R +UVM_TESTNAME=…')} sa {C('-svseed')}"],
          ["Pokrivenost", f"{C('-cov_db_name')}, izveštaj alatom {C('xcrg')} (vežba 11)", f"{C('-coverage functional')}, {C('-covtest')}; baze u {C('cov_work/')}"],
          ["Komanda", C("./regression.sh"), C("SIM=xrun ./regression.sh")],
          ["Rezultat nove verzije", '<span class="stanje-ok">22 / 22 PASS</span>', '<span class="stanje-ok">22 / 22 PASS</span>'],
          ["Trajanje regresije", "oko 113 s", "55 s"],
          ["Poređenja rezultata", str(ukupno_por), "3925"],
          ["Izveštaj pokrivenosti", f"100% (slike {n_cov_sl} i {n_cov_sl + 1})", f"nije napravljen: alat {C('imc')} nije instaliran na mašini"]])
d.p(f"Ishod je isti na oba simulatora: svih 22 pokretanja prolazi, bez ijedne greške scoreboard-a (slika "
    f"{d.sledeca_slika()}). Broj poređenja nije isti jer {C('test_random')} sa istim seed-om ne dobija iste slučajne "
    "vrednosti na dva simulatora: svaki simulator ima svoj generator slučajnih brojeva, pa isti seed daje druge "
    f"dimenzije slike i šablona. Testovi {C('test_smoke')} i {C('test_cov')} ne zavise od seed-a. Pokrivenost se u "
    f"Xcelium-u prikuplja ({C('-coverage functional')}, baze su u {C('cov_work/scope/')}), ali se izveštaj od njih "
    f"pravi Cadence alatom {C('imc')}, koji na fakultetskoj mašini nije instaliran; zato je izveštaj pokrivenosti "
    "napravljen u Vivado-u.")
d.slika_fajl(os.path.join(SNIMCI, "xcelium_regresija.png"), "xcelium_regresija",
             f"Ispis regresije na Cadence Xcelium 19.03. Snimljen je pre nego što su imena i poruke u kodu "
             "prevedeni na engleski (tada se skripta zvala regresija.sh); logika okruženja nije menjana.", "70%")
d.p("Na Windows-u su Vivado alati .bat fajlovi, koji argument oblika ime=vrednost dele na dva argumenta. Zato skripta "
    f"opcije za {C('xsim')} upisuje u fajl i prosleđuje ih sa {C('-f')}.")
d.p(f"Prva verzija okruženja prošla je na oba simulatora sa istim ishodom. Tada su pronađene tri razlike između alata, "
    f"sve u VHDL-u DUT-a ({C('ncc_accel_slave_lite_v1_0_S00_AXI.vhd')} i S01 šablon), ne u SystemVerilog kodu "
    f"(Tabela {d.sledeca_tabela()}). Rešenja su ugrađena u {C('regression.sh')} i u kopiju RTL-a, pa važe i za novu verziju.")
d.tabela("razlike_simulatora", "Razlike između XSim-a i Xcelium-a (nalaz N5)",
         ["Greška u Xcelium-u", "Uzrok", "Rešenje", "Dira DUT?"],
         [[C("*E,AGNLSC"), f"agregat {C('(0 => …, others => \"0\")')} nad opsegom izračunatim iz generika", C("xrun -relax"), "ne"],
          [C("*E,CSODAS"), f"{C('case')} nad podtipom koji nije lokalno statičan", "deklaracija promenjena u jednom redu, ista širina", "samo kopija u rtl/"],
          [C("*E,TRRANGEC"), "integer bez početne vrednosti u nultom delta-koraku S01 šablona", C("set rangecnst_severity_level warning"), "ne"]],
         ["", "", "", "c"])

# ====================================================================== 10. nalazi
d.h1("10. Nalazi verifikacije")
d.p(f"Tokom verifikacije utvrđeno je pet nalaza (Tabela {d.sledeca_tabela()}). Nijedan nije greška u računu "
    "jezgra; to su ponašanja interfejsa koja softver mora da poštuje i razlike između alata.", noind=True)
d.tabela("nalazi", "Nalazi verifikacije",
         ["#", "Nalaz", "Kako je proveren"],
         [["N1", f"Registarska mapa: najveća adresa na S00 je 0x3F; rezultati se čitaju samo sa S01 (+0x10000). "
                 f"Registri 0x10–0x2C pamte upisanu vrednost, ali je jezgro ne koristi.", "random test upisuje u 0x10–0x2C; rezultati se uvek čitaju sa S01"],
          ["N2", f"Upis 1 u CTRL dok jezgro radi se tiho ignoriše: S00 generiše start, ali ga jezgro prihvata samo "
                 f"kada nije zauzeto. Odgovor na upis je OKAY, pa softver ne zna da novi posao nije počeo. "
                 f"{C('done')} je u tom trenutku već 0 (obrisan prvim startom). Upis 0 u CTRL ne pokreće jezgro i ne briše done.",
                 "test_cov (T7), ukrštanja x_start_busy i x_start_done"],
          ["N3", "Ponašanje S01: oblast rezultata je samo za čitanje (upis se zanemaruje uz OKAY), šablon se ponavlja na "
                 "1024 reči, slika pamti samo 8 bita, nemapirana oblast vraća nule umesto greške (DECERR).", "test_cov"],
          ["N4", "Burst duži od 256 beat-ova nije dozvoljen po AXI4; prva verzija pobude slala je celu sliku kao jedan "
                 "burst i regresija je to otkrila. Sekvence sada dele prenos na 256 beat-ova i granicu od 4 KB.", "cp_len, bin b256"],
          ["N5", f"Xcelium strože od XSim-a primenjuje pravila VHDL-a o lokalno statičnim podtipovima (Tabela {d.n_tab}).", "dvostruka simulacija"]],
         ["c", "", ""])
d.p("Nalaz N2 ima direktnu posledicu na Linux drajver (predmet EOS): drajver pre komande start proverava bit busy i "
    "odbija komandu greškom EBUSY, umesto da je pošalje jezgru koje bi je ignorisalo.")

# ====================================================================== 11. zakljucak
d.h1("11. Zaključak")
d.p(f"Verifikacija {C('ncc_accel')} zatvorena je na IP nivou. Okruženje ima jedan agent za obe magistrale, scoreboard sa "
    "bit-tačnim referentnim modelom i tri covergroup-e u monitoru, i koristi isključivo konstrukcije obrađene na "
    f"vežbama. Regresija na Vivado XSim-u daje 22 od 22 prolaza i 100% funkcionalne pokrivenosti, uz {ukupno_por} "
    "poređenja rezultata bez ijedne razlike. Namerno uneta greška u DUT otkrivena je u tri od pet pokretanja, sa "
    "stotinama prijavljenih neslaganja, čime je pokazano da okruženje zaista proverava rezultat.", noind=True)
d.p("Verifikacija je dala i pet nalaza o ponašanju interfejsa i alata (poglavlje 10), od kojih je jedan (N2) uticao na "
    "dizajn Linux drajvera. Ista regresija na Cadence Xcelium-u 19.03 daje isti ishod: 22 od 22 prolaza, bez "
    "ijedne greške scoreboard-a.")

# ====================================================================== prilog
d.h1("Prilog A. Pokretanje")
d.pre("cd verif\n"
      "./regression.sh                 # XSim: test_smoke, test_cov, test_random x 20\n"
      "./regression.sh 5               # 5 seed-ova za test_random\n"
      "SIM=xrun ./regression.sh        # Cadence Xcelium (xrun u PATH-u)\n"
      "VIVADO=/tools/Xilinx/Vivado/2025.2/bin ./regression.sh   # druga putanja do Vivada")
d.p("Ispis skripte za XSim:", noind=True)
d.pre("=== build (xsim) ===\n=== tests ===\n  PASS  test_smoke  seed 1\n  PASS  test_cov  seed 1\n"
      "  PASS  test_random  seed 1\n  ...\n  PASS  test_random  seed 20\n"
      "=== total: 22 passed, 0 failed, 114 s ===\n=== coverage ===\n   Coverage Score            :, 100\n"
      "  report: result/report/functionalCoverageReport/dashboard.html")
d.p(f"Ispis skripte za Xcelium ({C('SIM=xrun ./regression.sh')}) prikazan je na slici {d.n_sl}; deo za pokrivenost "
    "se tada ne ispisuje.", noind=True)

d.napravi("Verifikacija NCC akceleratora - druga verzija", naslovna)
print("FVH gotovo:", d.n_sl, "slika,", d.n_tab, "tabela")
