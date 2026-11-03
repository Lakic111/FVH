import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_common import Svg, Dokument

IZLAZ = "C:/Users/pc/Desktop/EOS/Dokumentacija_v2_uprosceno"
d = Dokument(IZLAZ, "EOS_dokumentacija_y25-g10")
C = lambda s: f"<code>{s}</code>"

naslovna = """<div class="cover">
  <div class="subj">Embedded operativni sistemi</div>
  <div class="rule"></div>
  <div class="title">Linux drajver i korisnička aplikacija za NCC akcelerator</div>
  <div class="sub">Druga verzija, usklađena sa vežbama</div>
  <div class="rule"></div>
  <div class="meta">Grupa: <b>y25-g10</b><br>Nastavak projekta sa predmeta Projektovanje složenih digitalnih sistema</div>
</div>"""

# ====================================================================== 1. uvod
d.h1("1. Uvod", first=True)
d.p(f"Predmet rada je Linux podrška za IP jezgro {C('ncc_accel')}: hardverski akcelerator normalizovane unakrsne "
    "korelacije (NCC), projektovan na predmetu Projektovanje složenih digitalnih sistema. Akcelerator se koristi za "
    "prepoznavanje šahovskih figura: slika table deli se na 64 polja, a svako zauzeto polje poredi se sa šablonima "
    "figura. Rezultat je pozicija u FEN zapisu.", noind=True)
d.p(f"U prethodnoj fazi sistem je radio kao bare-metal aplikacija u Vitis-u, koja registrima i memorijama "
    f"akceleratora pristupa direktno, funkcijama {C('Xil_Out32')} i {C('Xil_In32')}. Ovde se isti hardver, bez "
    "izmene bitstream-a, koristi iz Linux-a: kroz platformski drajver koji upravlja akceleratorom i korisničku "
    "aplikaciju koja preko drajvera obavlja isto prepoznavanje table.")
d.p(f"Ovo je druga verzija rešenja. Prva verzija koristila je mehanizme koji nisu obrađeni na vežbama "
    f"({C('ioctl')}, {C('devm_*')} funkcije, {C('mutex')}, prozivanje u kernelu) i imala je 18 fajlova. Nova "
    f"verzija koristi isključivo ono što je obrađeno na vežbama: komande preko {C('write')}, status preko "
    f"{C('read')}, podatke preko {C('mmap')}, i ima 6 fajlova.")
d.tabela("platforma", "Platforma i alati",
         ["Stavka", "Vrednost"],
         [["Ploča", f"Digilent Zybo Z7-10 (Zynq-7010, {C('xc7z010clg400-1')})"],
          ["Hardver", f"isti {C('ncc_system_wrapper.xsa')} kao u bare-metal rešenju: dve instance {C('ncc_accel')}"],
          ["Distribucija", "PetaLinux 2025.2"],
          ["Kernel", "linux-xlnx 6.12.40, ARM32"],
          ["Korenski fajl-sistem", "initrd (u radnoj memoriji)"],
          ["Konzola", "UART, 115200 bit/s"]])

# ====================================================================== 2. hardver
d.h1("2. Hardverski interfejs akceleratora")
d.p(f"Sistem ima dve nezavisne instance akceleratora. Svaka ima dva AXI interfejsa: AXI4-Lite (S00) za kontrolne "
    f"registre i AXI4-Full (S01) za memorije slike, šablona i rezultata (Tabela {d.sledeca_tabela()}).", noind=True)
d.tabela("adresna_mapa", "Adresna mapa instanci",
         ["Instanca", "S00 (registri)", "S01 (memorije)", "Linux uređaj"],
         [[C("ncc0"), f"{C('0x5000_0000')}, 4 KB", f"{C('0x5002_0000')}, 128 KB", C("/dev/ncc0")],
          [C("ncc1"), f"{C('0x5100_0000')}, 4 KB", f"{C('0x5102_0000')}, 128 KB", C("/dev/ncc1")]])
d.p(f"Adresna magistrala S00 široka je šest bita, pa su od prozora od 4 KB važeće samo adrese 0x00–0x3F. Drajver "
    f"koristi šest registara (Tabela {d.sledeca_tabela()}).")
d.tabela("registri", "Kontrolni registri (S00)",
         ["Adresa", "Registar", "Opis"],
         [[C("0x00"), C("IMG_W"), "širina slike, 1–90"],
          [C("0x04"), C("IMG_H"), "visina slike, 1–90"],
          [C("0x08"), C("TMP_W"), "širina šablona, 1–30"],
          [C("0x0C"), C("TMP_H"), "visina šablona, 1–30"],
          [C("0x30"), C("CTRL"), "upis 1 pokreće obradu i briše done"],
          [C("0x34"), C("STATUS"), "bit 0 = done (ostaje 1 do sledećeg starta), bit 1 = busy; samo čitanje"]],
         ["c", "c", ""])
d.tabela("memorija_s01", "Oblasti memorijskog prostora S01",
         ["Oblast", "Pomeraj", "Kapacitet", "Upotreba"],
         [["slika", C("+0x00000"), "8192 reči", "do 90×90 = 8100 piksela"],
          ["šablon", C("+0x08000"), "1024 reči", "do 30×30 = 900 piksela"],
          ["rezultat", C("+0x10000"), "8192 reči", "NCC² po poziciji prozora, samo za čitanje"]])
d.p(f"Jedan piksel zauzima jednu 32-bitnu reč, a ne jedan bajt. Rezultat je NCC² u formatu Q1.31, gde "
    f"{C('0x80000000')} predstavlja 1,0, odnosno savršeno poklapanje. Zato se rezultati porede kao neoznačeni "
    "brojevi: kao označen broj, najbolji mogući rezultat bio bi negativan. Akcelerator nema prekidni izlaz, pa se "
    f"kraj obrade prepoznaje samo po bitu {C('done')} u registru {C('STATUS')}.")
d.p("Iz verifikacije na predmetu FVH poznato je još jedno ponašanje koje softver mora da poštuje: upis u "
    f"{C('CTRL')} dok jezgro radi jezgro ignoriše, a magistrala ipak odgovara da je upis uspeo. Drajver zato pre "
    f"svake komande proverava bit {C('busy')}.")

# ====================================================================== 3. arhitektura
d.h1("3. Arhitektura rešenja")
n1 = d.sledeca_slika()
d.p(f"Rešenje ima tri sloja: korisničku aplikaciju, kernel drajver i hardver (slika {n1}). Svaka instanca "
    f"akceleratora je jedan uređaj u {C('/dev')}. Kontrolni i podatkovni put su razdvojeni:", noind=True)
d.ul([f"<b>kontrola</b> — tekstualne komande upisom u uređaj ({C('write')}), kao komande za LED u vežbi 9;",
      f"<b>status</b> — čitanjem uređaja ({C('read')}) dobija se tekst {C('done=1 busy=0')};",
      f"<b>podaci</b> — memorija S01 se mapira u adresni prostor aplikacije ({C('mmap')}), kao u vežbi 12, pa "
      "aplikacija sliku i šablon upisuje, a rezultate čita, kao običan niz."])
s = Svg(760, 452)
s.box(8, 8, 700, 92, [], fill="#f4f4f4")
s.text(18, 26, "korisnički prostor", bold=True)
s.box(150, 36, 440, 52, ["ncc-scan (app/main.c)", "skeniranje table, FEN"], bold_first=True)
s.box(8, 130, 700, 140, [], fill="#e9e9e9")
s.text(18, 148, "kernel", bold=True)
s.box(110, 160, 520, 96, [], fill="#ffffff")
s.box(124, 166, 150, 48, ["ncc_write()", "dims / start"], bold_first=True, size=10.5)
s.box(295, 166, 150, 48, ["ncc_read()", "done / busy"], bold_first=True, size=10.5)
s.box(466, 166, 150, 48, ["ncc_mmap()", "remap_pfn_range"], bold_first=True, size=10.5)
s.text(370, 240, "ncc_driver (driver/ncc_driver.c)", bold=True, anchor="middle")
s.box(8, 300, 700, 144, [], fill="#f4f4f4")
s.text(18, 318, "hardver (PL)", bold=True)
for ime, x in [("ncc0", 60), ("ncc1", 400)]:
    s.box(x, 326, 280, 108, [], fill="#ffffff")
    s.box(x + 14, 334, 110, 50, ["S00", "registri"], bold_first=True, size=10.5)
    s.box(x + 156, 334, 110, 50, ["S01", "slika, šablon, rezultat"], bold_first=True, size=10)
    s.text(x + 140, 420, f"{ime} : ncc_accel", bold=True, anchor="middle")
s.line([(199, 88), (199, 166)]); s.text(205, 124, "write()", size=10)
s.line([(370, 88), (370, 166)]); s.text(376, 124, "read()", size=10)
s.line([(541, 88), (541, 166)]); s.text(547, 124, "mmap()", size=10)
s.line([(370, 256), (129, 334)])
s.line([(370, 256), (469, 334)])
s.text(370, 288, "iowrite32 / ioread32 (S00)", size=10, anchor="middle", halo=True)
s.line([(590, 62), (730, 62), (730, 310), (271, 310), (271, 334)], dash=True)
s.line([(611, 310), (611, 334)], dash=True)
s.text(742, 190, "podaci kroz mapiranu memoriju (S01)", size=10, rot=90, anchor="middle")
d.slika(s, "arhitektura",
        "Arhitektura rešenja. Komande i status idu kroz drajver; podacima u S01 aplikacija pristupa direktno, kroz "
        "mapiranu memoriju (isprekidane linije), bez kopiranja kroz kernel.")
d.p(f"Fajlovi rešenja dati su u tabeli {d.sledeca_tabela()}.")
d.tabela("fajlovi", "Fajlovi rešenja",
         ["Fajl", "Sadržaj", "Linija"],
         [[C("driver/ncc_driver.c"), "platformski drajver za obe instance", "364"],
          [C("driver/Makefile"), "prevođenje modula (isti oblik kao u vežbi 9)", "22"],
          [C("app/main.c"), "aplikacija: rad sa drajverom, obrada slike, skeniranje table, FEN", "342"],
          [C("app/data.c"), "slika table 720×720 i 12 šablona u dve rezolucije (generisani podaci)", "33 194"],
          [C("app/data.h"), "deklaracije podataka", "11"],
          [C("app/Makefile"), "prevođenje aplikacije", "12"]],
         ["", "", "n"])

# ====================================================================== 4. drajver
d.h1("4. Platformski drajver")
d.p(f"Drajver je jedan kernel modul, {C('ncc_driver.ko')}, napisan po uzoru na drajvere iz vežbi 6, 7, 9 i 10. "
    f"Njegova struktura prikazana je na slici {d.sledeca_slika()}.", noind=True)
s = Svg(740, 420)
s.box(8, 8, 350, 404, [], fill="#f4f4f4")
s.text(183, 28, "ncc_init()  — učitavanje modula", bold=True, anchor="middle")
koraci = ["sema_init() za obe instance", "alloc_chrdev_region(): 2 minor broja",
          "class_create(\"ncc_class\")", "device_create(): /dev/ncc0 i /dev/ncc1",
          "cdev_alloc() + cdev_add()", "platform_driver_register()"]
for i, k in enumerate(koraci):
    y = 44 + i * 60
    s.box(30, y, 306, 38, [k], size=10.5)
    if i < len(koraci) - 1:
        s.line([(183, y + 38), (183, y + 60)])
s.box(382, 8, 350, 260, [], fill="#e9e9e9")
s.text(557, 28, "ncc_probe()  — za svaki čvor device tree-a", bold=True, anchor="middle")
koraci2 = ["platform_get_resource(): S00 i S01", "instanca po adresi S00 (ncc0 ili ncc1)",
           "kmalloc(struct ncc_info)", "request_mem_region(): S00 i S01", "ioremap(S00)"]
for i, k in enumerate(koraci2):
    y = 44 + i * 44
    s.box(404, y, 306, 30, [k], size=10.5)
    if i < len(koraci2) - 1:
        s.line([(557, y + 30), (557, y + 44)])
s.line([(336, 367), (360, 367), (360, 59), (404, 59)])
s.text(366, 210, "poziva", size=10, rot=90, anchor="middle")
s.box(382, 286, 350, 126, [], fill="#f4f4f4")
s.text(557, 306, "file operations", bold=True, anchor="middle")
s.box(404, 318, 148, 38, ["ncc_write()", "komande"], bold_first=True, size=10)
s.box(562, 318, 148, 38, ["ncc_read()", "status"], bold_first=True, size=10)
s.box(404, 364, 148, 38, ["ncc_mmap()", "memorija S01"], bold_first=True, size=10)
s.box(562, 364, 148, 38, ["ncc_open/close()", "bez dejstva"], bold_first=True, size=10)
d.slika(s, "struktura_drajvera", f"Struktura drajvera: {C('ncc_init()')} pravi uređaje i registruje platformski "
        f"drajver, kernel zatim poziva {C('ncc_probe()')} za obe instance iz device tree-a.")

d.h2("4.1. Učitavanje i uklanjanje modula")
d.p(f"{C('ncc_init()')} rezerviše dva broja uređaja ({C('alloc_chrdev_region')} sa dva minora), pravi klasu i dva "
    f"čvora, {C('/dev/ncc0')} i {C('/dev/ncc1')}, kao drajver sa više minor brojeva iz vežbe 6. Zatim pravi jedan "
    f"{C('cdev')} za oba minora i registruje platformski drajver. Ako neki korak ne uspe, prethodni se poništavaju "
    f"redom ({C('goto fail_N')}). {C('ncc_exit()')} radi isto obrnutim redom.", noind=True)
d.p(f"Dve stvari se razlikuju od vežbi zbog novijeg kernela (6.12 u PetaLinux-u 2025.2): {C('class_create()')} prima "
    f"samo ime klase (bez {C('THIS_MODULE')}), a funkcija {C('remove')} platformskog drajvera vraća {C('void')} "
    f"umesto {C('int')}.")
d.h2("4.2. Probe i remove")
d.p(f"Kernel poziva {C('ncc_probe()')} jednom za svaki čvor device tree-a sa {C('compatible = \"xlnx,ncc-accel-1.0\"')}. "
    f"Svaki čvor ima dva opsega: {C('reg[0]')} je S00, a {C('reg[1]')} je S01. Probe:", noind=True)
d.ul([f"čita oba opsega sa {C('platform_get_resource()')};",
      "određuje instancu po fizičkoj adresi S00 (0x5000_0000 je ncc0, 0x5100_0000 je ncc1), jer redosled poziva "
      "probe nije garantovan;",
      f"pravi strukturu {C('ncc_info')} sa {C('kmalloc')} i čuva adrese oba opsega;",
      f"rezerviše oba opsega sa {C('request_mem_region()')} i mapira S00 sa {C('ioremap()')}, kao u vežbama 9 i 11;",
      f"S01 se ne mapira u kernelu — mapira ga {C('ncc_mmap()')} direktno u adresni prostor aplikacije."])
d.p(f"{C('ncc_remove()')} oslobađa sve obrnutim redom: {C('iounmap')}, {C('release_mem_region')} za oba opsega i "
    f"{C('kfree')}.")
d.h2("4.3. Operacije nad uređajem")
d.p(f"Sve operacije dobijaju instancu iz minor broja otvorenog fajla, {C('MINOR(pfile->f_inode->i_rdev)')}, isto kao "
    f"drajver sa više minora iz vežbe 6 (Tabela {d.sledeca_tabela()}).", noind=True)
d.tabela("file_operations", "Operacije nad uređajem",
         ["Funkcija", "Šta radi"],
         [[C("ncc_write()"), f"prima komandu ({C('copy_from_user')}), proverava je i upisuje registre ({C('iowrite32')})"],
          [C("ncc_read()"), f"čita {C('STATUS')} ({C('ioread32')}) i vraća tekst {C('done=D busy=B')}; drugo čitanje istog otvorenog fajla vraća 0, pa radi i {C('cat')}"],
          [C("ncc_mmap()"), f"mapira 128 KB memorije S01 bez keša ({C('pgprot_noncached')}, {C('remap_pfn_range')})"],
          [C("ncc_open()"), "bez dejstva"],
          [C("ncc_close()"), "bez dejstva"]])
d.h2("4.4. Komande")
d.p(f"Komande su tekstualne, kao komande za LED u vežbi 9, pa se drajver može koristiti i iz shell-a "
    f"(Tabela {d.sledeca_tabela()}). Tekst se rastavlja sa {C('sscanf')}.", noind=True)
d.tabela("komande", "Komande drajvera",
         ["Komanda", "Dejstvo", "Greška"],
         [[C("dims IW IH TW TH"), f"upisuje dimenzije u {C('IMG_W')}, {C('IMG_H')}, {C('TMP_W')}, {C('TMP_H')}",
           f"{C('EINVAL')} ako je slika van 1–90, šablon van 1–30 ili šablon veći od slike"],
          [C("start"), f"upisuje 1 u {C('CTRL')}: pokreće obradu i briše done", "—"],
          ["(bilo koja, dok je busy = 1)", "ništa se ne upisuje", C("EBUSY")],
          ["(nepoznata komanda)", "ništa se ne upisuje", C("EINVAL")],
          [f"čitanje ({C('cat /dev/ncc0')})", f"vraća {C('done=1 busy=0')} ili sl.", "—"]])
d.p(f"Provera {C('busy')} je posledica nalaza N2 iz verifikacije: jezgro start dok radi ignoriše, a nove dimenzije "
    "bi promenile posao koji je u toku. Bez provere aplikacija bi dobila uspešan odgovor na komandu koja nije "
    "izvršena i pročitala bi rezultate prethodnog posla.")
d.h2("4.5. Sinhronizacija")
d.p(f"Komanda se izvršava pod semaforom svoje instance ({C('down_interruptible')} / {C('up')}, vežba 7). Tako dva "
    "procesa koja istovremeno šalju komande istom akceleratoru ne mogu da pomešaju upise četiri registra dimenzija. "
    f"{C('down_interruptible')} vraća grešku ako proces dobije signal dok čeka, pa se proces može prekinuti.",
    noind=True)
d.h2("4.6. Mapiranje memorije")
d.p(f"{C('ncc_mmap()')} dozvoljava mapiranje do 128 KB (ceo S01) i postavlja stranice kao nekeširane. S01 je "
    "memorija akceleratora iza AXI magistrale, a ne radna memorija: sa kešom bi upisi procesora mogli da ostanu u "
    "kešu i ne stignu do akceleratora, a čitanja bi mogla da vrate staru vrednost umesto rezultata. Za razliku od "
    f"vežbe 12, gde se mapira DMA bafer u radnoj memoriji ({C('dma_mmap_coherent')}), ovde se mapira memorija "
    f"uređaja, pa se koristi {C('remap_pfn_range')}.", noind=True)
d.h2("4.7. Veza sa vežbama")
d.tabela("veza_sa_vezbama", "Mehanizmi drajvera i vežbe u kojima su obrađeni",
         ["Mehanizam", "Vežba"],
         [[f"{C('alloc_chrdev_region')}, {C('class_create')}, {C('device_create')}, {C('cdev_alloc')}, {C('cdev_add')}", "5, 6"],
          [f"više minor brojeva, {C('MINOR(...)')}", "6"],
          [f"{C('read')} / {C('write')}, {C('copy_to_user')} / {C('copy_from_user')}, {C('sscanf')}", "6, 9"],
          [f"semafor: {C('sema_init')}, {C('down_interruptible')}, {C('up')}", "7"],
          [f"platformski drajver, {C('of_match_table')}, {C('platform_get_resource')}", "9, 10"],
          [f"{C('kmalloc')}, {C('request_mem_region')}, {C('ioremap')}, {C('ioread32')} / {C('iowrite32')}", "9, 10, 11"],
          [C("mmap"), "12"],
          ["PetaLinux, device tree, Linux na Zybo ploči", "11, 12"],
          ["aplikacija koja koristi uređaj kroz fajl u /dev", "3"]],
         ["", "c"])

# ====================================================================== 5. aplikacija
d.h1("5. Korisnička aplikacija")
n_alg = d.sledeca_slika()
d.p(f"Aplikacija {C('ncc-scan')} obrađuje istu tablu i iste šablone kao bare-metal rešenje: 64 polja od 90×90 "
    f"piksela i 12 šablona (šest belih i šest crnih figura). Algoritam za jedno polje prikazan je na slici {n_alg}.",
    noind=True)
s = Svg(740, 520)
kor = [("polje je prazno?", "srednja vrednost centra = piksel (10,10)", "#f2f2f2"),
       ("boja figure", "srednja vrednost centra > 140 → bela, inače crna", "#fff"),
       ("izdvajanje polja", "90×90 iz table 720×720 i umanjena verzija 45×45", "#fff"),
       ("grubi pregled", "6 šablona te boje na slici 45×45, po dva istovremeno na ncc0 i ncc1", "#f2f2f2"),
       ("izbor", "dva šablona sa najvećim rezultatom", "#fff"),
       ("fini pregled", "ta dva šablona na punoj slici 90×90, na ncc0 i ncc1", "#f2f2f2"),
       ("figura", "šablon sa većim rezultatom → slovo u FEN zapisu", "#fff")]
for i, (a, b, f) in enumerate(kor):
    y = 10 + i * 72
    s.box(170, y, 400, 50, [a, b], bold_first=True, size=11, fill=f)
    if i < len(kor) - 1:
        s.line([(370, y + 50), (370, y + 72)])
s.text(376, 76, "ne", size=10)
s.line([(570, 35), (650, 35)]); s.text(610, 29, "da", size=10, anchor="middle")
s.box(650, 15, 82, 40, ["sledeće", "polje"], size=10.5)
s.text(160, 274, "akcelerator", size=10, anchor="end", italic=True)
s.text(160, 418, "akcelerator", size=10, anchor="end", italic=True)
d.slika(s, "algoritam_polja", "Prepoznavanje figure na jednom polju table.")
n_tok = d.sledeca_slika()
d.p(f"Svaki par šablona obrađuje se funkcijom {C('run_pair()')}, čiji je tok prikazan na slici {n_tok}: šablon se "
    f"upisuje u mapiranu memoriju, dimenzije i start šalju se drajveru, aplikacija čeka kraj obrade i čita najveći "
    "rezultat iz mapirane memorije.")
s = Svg(740, 430)
xs = {"app": 110, "drv": 370, "hw": 630}
for k, ime in [("app", "aplikacija"), ("drv", "drajver"), ("hw", "akcelerator (S00 / S01)")]:
    s.box(xs[k] - 95, 8, 190, 32, [ime], bold_first=True, fill="#e9e9e9")
    s.raw(f'<line x1="{xs[k]}" y1="40" x2="{xs[k]}" y2="420" stroke="#888" stroke-width="1" stroke-dasharray="4,3"/>')
def poruka(y, a, b, t, dash=False):
    s.line([(xs[a], y), (xs[b], y)], dash=dash)
    s.text((xs[a] + xs[b]) / 2, y - 5, t, size=10, anchor="middle", halo=True)
poruka(70, "app", "hw", "upis šablona u mapiranu memoriju (S01)", dash=True)
poruka(112, "app", "drv", "write(\"dims 45 45 15 15\")")
poruka(140, "drv", "hw", "iowrite32 × 4 (S00)")
poruka(182, "app", "drv", "write(\"start\")")
poruka(210, "drv", "hw", "iowrite32(1, CTRL)")
s.box(20, 236, 700, 112, [], fill="none", dash=True)
s.text(30, 252, "ponavlja se dok nije done = 1 i busy = 0 (usleep(100) između)", size=10, italic=True, halo=True)
poruka(282, "app", "drv", "fopen + čitanje /dev/ncc0")
poruka(306, "drv", "hw", "ioread32(STATUS)")
poruka(334, "drv", "app", "\"done=0 busy=1\"")
poruka(388, "app", "hw", "čitanje mape rezultata iz mapirane memorije (S01)", dash=True)
d.slika(s, "tok_obrade", "Tok obrade jednog šablona na jednom akceleratoru. Isprekidane linije: direktan pristup "
        "memoriji S01 kroz mmap.")
d.p(f"Oba akceleratora se pokreću pre čekanja, pa rade istovremeno. Aplikacija uvek čeka oba, čak i kada jedan "
    "javi grešku, da sledeći par ne bi pisao u memoriju jezgra koje još radi. Funkcije aplikacije date su u "
    f"tabeli {d.sledeca_tabela()}.")
d.tabela("funkcije_aplikacije", f"Funkcije u {C('app/main.c')}",
         ["Funkcija", "Šta radi"],
         [[C("ncc_open()"), f"otvara {C('/dev/nccN')} i mapira 128 KB memorije S01"],
          [C("ncc_command()"), f"šalje tekstualnu komandu drajveru ({C('write')})"],
          [C("ncc_dims()"), f"pravi komandu {C('dims IW IH TW TH')}"],
          [C("ncc_wait()"), f"čita status ({C('fopen')} + {C('fscanf')}) dok nije done = 1 i busy = 0; najviše oko 2 s"],
          [C("write_pixels()"), "upisuje piksele (8 bita) kao 32-bitne reči u mapiranu memoriju"],
          [C("best_score()"), "najveći rezultat u mapi, poređenje kao neoznačeni broj"],
          [C("run_pair()"), "jedan ili dva šablona na ncc0 i ncc1 nad već upisanom slikom"],
          [C("downscale()"), "umanjenje slike 2× (prosek 2×2 piksela, sa zaokruživanjem)"],
          [C("center_mean()"), "srednja vrednost centralnih 31×31 piksela polja"],
          [C("is_empty()"), "da li je polje prazno"],
          [C("scan_square()"), f"ceo algoritam sa slike {n_alg} za jedno polje"],
          [C("make_fen()"), "tabla 8×8 u FEN zapis"],
          [C("main()"), "otvaranje uređaja, skeniranje 64 polja, ispis i poređenje FEN-a; vraća 1 ako se FEN ne poklapa"]])

# ====================================================================== 6. prevodjenje i pokretanje
d.h1("6. Prevođenje i pokretanje")
d.h2("6.1. Device tree")
d.p(f"PetaLinux iz {C('.xsa')} fajla sam generiše čvorove za obe instance, sa dva {C('reg')} opsega i bez "
    f"{C('interrupts')}, jer IP nema prekidni izlaz:", noind=True)
d.pre('ncc_accel@50000000 {\n    compatible = "xlnx,ncc-accel-1.0";\n'
      '    reg = <0x50000000 0x1000>, <0x50020000 0x20000>;\n};\n'
      'ncc_accel@51000000 {\n    compatible = "xlnx,ncc-accel-1.0";\n'
      '    reg = <0x51000000 0x1000>, <0x51020000 0x20000>;\n};')
d.h2("6.2. Drajver")
d.p(f"Modul se prevodi protiv istog kernela koji radi na ploči. U PetaLinux projektu to radi recept modula "
    f"{C('project-spec/meta-user/recipes-modules/ncc-accel/')}. PetaLinux ne dozvoljava donju crtu u imenu recepta, "
    f"pa se recept zove {C('ncc-accel')}, a {C('ncc_driver.c')} je u njemu sačuvan kao {C('ncc-accel.c')}; modul na "
    f"ploči se zato zove {C('ncc-accel.ko')}. Recept ga ugrađuje u rootfs, a kernel ga sam učitava pri pokretanju, jer "
    f"se {C('compatible')} iz drajvera poklapa sa čvorovima device tree-a. Aplikacija ide kroz recept "
    f"{C('recipes-apps/ncc-scan/')} sa fajlovima {C('main.c')}, {C('data.c')}, {C('data.h')} i {C('Makefile')}. "
    f"Posle {C('petalinux-build')} na SD karticu idu {C('BOOT.BIN')}, {C('boot.scr')} i {C('image.ub')}. Van "
    "PetaLinux-a:", noind=True)
d.pre("cd driver\nmake ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNELDIR=<kernel build dir>")
d.h2("6.3. Aplikacija")
d.pre("cd app\nmake CROSS_COMPILE=arm-linux-gnueabihf-")
d.h2("6.4. Provera na ploči")
d.p(f"Pošto su komande tekstualne, drajver se proverava iz shell-a, pre pokretanja aplikacije (Tabela "
    f"{d.sledeca_tabela()}). Čvorovi uređaja pripadaju korisniku root (prava {C('crw-------')}), pa se komande "
    f"pokreću sa {C('sudo')}; za upis kroz preusmeravanje to je {C('sudo sh -c')}.", noind=True)
n_shell = d.tabela("provera_na_ploci", "Provera drajvera iz shell-a",
         ["Komanda", "Očekivano"],
         [[C("dmesg | grep ncc_probe"), f"{C('ncc_probe: ncc0, S00 50000000, S01 50020000')} i isto za ncc1"],
          [C("ls -l /dev/ncc*"), f"{C('/dev/ncc0')} i {C('/dev/ncc1')}, major 244, minor 0 i 1"],
          [C("sudo cat /dev/ncc0"), C("done=X busy=0")],
          [C("sudo sh -c 'echo \"dims 90 90 25 15\" > /dev/ncc0'"), "bez greške"],
          [C("sudo sh -c 'echo \"start\" > /dev/ncc0'"), "bez greške"],
          [C("sudo cat /dev/ncc0"), C("done=1 busy=0")],
          [C("sudo sh -c 'echo \"dims 200 1 1 1\" > /dev/ncc0'"), f"greška {C('Invalid argument')}"],
          [C("sudo ncc-scan"), "FEN se poklapa sa očekivanim, izlazni kod 0"]])

# ====================================================================== 7. rezultati
d.h1("7. Rezultati")
d.p(f"Ispravnost aplikacije proverena je na računaru, pre prenosa na ploču: {C('main.c')} je preveden zajedno sa "
    f"softverskim modelom akceleratora umesto drajvera. Model prima iste komande ({C('dims')}, {C('start')}), "
    "računa NCC² istom aritmetikom kao hardver (isti model je u FVH okruženju bit-tačan prema RTL-u) i vraća status "
    f"{C('done=1 busy=0')}. Rezultat (Tabela {d.sledeca_tabela()}): svih 32 zauzetih polja prepoznato je tačno. "
    "Ispis je snimljen pre nego što su poruke u kodu prevedene na engleski; logika programa nije menjana, pa nova verzija ispisuje iste vrednosti, samo engleskim rečima.",
    noind=True)
d.pre("zauzetih polja: 32\nFEN:       rnbqkbnr/pp5p/4ppp1/2pp4/5P2/1P1BPN2/P1PPQ1PP/RNB1K2R\n"
      "ocekivano: rnbqkbnr/pp5p/4ppp1/2pp4/5P2/1P1BPN2/P1PPQ1PP/RNB1K2R\nRezultat se poklapa sa ocekivanom pozicijom.")
d.tabela("rezultati", "Rezultati provere",
         ["Provera", "Rezultat"],
         [["aplikacija sa softverskim modelom (računar, gcc -Wall)", '<span class="stanje-ok">FEN tačan, 32 / 32 polja</span>'],
          ["prevođenje drajvera i aplikacije (PetaLinux 2025.2, kernel 6.12)", '<span class="stanje-ok">bez greške</span>'],
          ["probe na ploči", '<span class="stanje-ok">obe instance, /dev/ncc0 i /dev/ncc1</span>'],
          [f"provera iz shell-a na ploči (Tabela {n_shell})", '<span class="stanje-ok">sve kako je očekivano</span>'],
          [f"{C('ncc-scan')} na ploči", '<span class="stanje-ok">FEN tačan, 32 / 32 polja, 1,803 s</span>']])
d.p("Ispis provere iz shell-a na ploči. Ispis je snimljen pre nego što su poruke u kodu prevedene na engleski; logika programa nije menjana, pa nova verzija ispisuje iste vrednosti, samo engleskim rečima.", noind=True)
d.pre("$ dmesg | grep ncc_probe\n"
      "ncc_probe: ncc0, S00 50000000, S01 50020000\n"
      "ncc_probe: ncc1, S00 51000000, S01 51020000\n"
      "$ sudo sh -c 'echo \"dims 90 90 25 15\" > /dev/ncc0'\n"
      "$ sudo sh -c 'echo \"start\" > /dev/ncc0'\n"
      "$ sudo cat /dev/ncc0\n"
      "done=1 busy=0\n"
      "$ sudo sh -c 'echo \"dims 200 1 1 1\" > /dev/ncc0'\n"
      "ncc0: dimenzije van opsega\n"
      "sh: line 1: echo: write error: Invalid argument")
d.p("Kraj ispisa aplikacije na ploči:", noind=True)
d.pre("$ sudo ncc-scan\n=== NCC akcelerator -- prepoznavanje pozicije ===\n"
      "(0,0) crna  r   NCC2 = 1.0000\n(0,1) crna  n   NCC2 = 0.7200\n...\n(7,7) bela  R   NCC2 = 0.7662\n\n"
      "zauzetih polja: 32\n"
      "FEN:       rnbqkbnr/pp5p/4ppp1/2pp4/5P2/1P1BPN2/P1PPQ1PP/RNB1K2R\n"
      "ocekivano: rnbqkbnr/pp5p/4ppp1/2pp4/5P2/1P1BPN2/P1PPQ1PP/RNB1K2R\n"
      "vreme: 1803.183 ms, od toga cekanje akceleratora 1607.496 ms\n"
      "Rezultat se poklapa sa ocekivanom pozicijom.")
d.p(f"Nova verzija prepoznaje celu tablu za 1,803 s, od čega 1,607 s (89%) aplikacija čeka akcelerator "
    f"(Tabela {d.sledeca_tabela()}). To je 103 ms (5,4%) brže od prve verzije sa {C('ioctl')} i samo 21 ms (1,2%) "
    "sporije od bare-metal rešenja. Razlika prema prvoj verziji je skoro cela u čekanju na akcelerator: tamo je "
    "drajver između dve provere statusa spavao 0,5–1,5 ms, a aplikacija čeka oko 128 puta po tabli, dok sada "
    "aplikacija čita status svakih 100 µs, pa kraj posla primeti ranije. Ostatak vremena (oko 0,2 s: upis slike i "
    "šablona u memoriju i čitanje rezultata kroz mmap) sličan je u sve tri verzije.")
d.tabela("vreme", "Vreme prepoznavanja cele table na ploči",
         ["", "Bare-metal (Vitis)", "Linux, prva verzija (ioctl)", "Linux, druga verzija"],
         [["Ukupno vreme", "1,782 s", "1,906 s", "<b>1,803 s</b>"],
          ["Čekanje na akcelerator", "1,555 s", "1,677 s", "<b>1,607 s</b>"],
          ["Ostalo (upis, čitanje, logika)", "0,227 s", "0,230 s", "<b>0,196 s</b>"],
          ["Prepoznata polja", "32 / 32", "32 / 32", "<b>32 / 32</b>"]],
         ["", "c", "c", "c"])

# ====================================================================== 8. zakljucak
d.h1("8. Zaključak")
d.p(f"Isti hardver koji je u PSDS-u radio kao bare-metal sistem, a u FVH-u verifikovan u simulaciji, koristi se iz "
    f"Linux-a kroz platformski drajver i korisničku aplikaciju. Drajver koristi samo mehanizme obrađene na vežbama: "
    f"tekstualne komande kroz {C('write')}, status kroz {C('read')}, memoriju akceleratora kroz {C('mmap')}, "
    f"semafor za sinhronizaciju i {C('kmalloc')} / {C('request_mem_region')} / {C('ioremap')} za resurse. Rešenje "
    "ima šest fajlova. Drajver odbija komande dok jezgro radi, što direktno sprečava grešku otkrivenu verifikacijom "
    "(nalaz N2).", noind=True)
d.p("Na Zybo ploči drajver prepoznaje obe instance akceleratora, komande iz shell-a rade kako je opisano, a "
    "aplikacija prepoznaje svih 32 figure i daje tačan FEN za 1,803 s, što je samo 1,2% sporije od bare-metal "
    "rešenja i 5,4% brže od prve Linux verzije.")

d.napravi("Linux drajver za NCC akcelerator - druga verzija", naslovna)
print("EOS gotovo:", d.n_sl, "slika,", d.n_tab, "tabela")
