// Sekvence. Sve rade nad istim sekvencerom: transakcija sama nosi
// informaciju da li ide na S00 (registri) ili na S01 (memorije).

// =========================================================================
// Osnovna sekvenca -- pomocni taskovi koje koriste ostale sekvence
// =========================================================================
class ncc_base_seq extends uvm_sequence #(ncc_item);

   `uvm_object_utils(ncc_base_seq)

   function new(string name = "ncc_base_seq");
      super.new(name);
   endfunction

   // Upis jednog registra na S00.
   task reg_upisi(bit [5 : 0] adresa, bit [31 : 0] podatak, order_e redosled = ORDER_AW_FIRST);
      ncc_item it;
      it = ncc_item::type_id::create("it");
      start_item(it);
      it.bus     = BUS_S00;
      it.rw      = UPIS;
      it.addr    = adresa;
      it.len     = 1;
      it.data    = new[1];
      it.data[0] = podatak;
      it.strb    = 4'hF;
      if (!it.randomize() with { order == redosled; })
         `uvm_fatal("SEQ", "randomizacija nije uspela")
      finish_item(it);
   endtask : reg_upisi

   // Citanje jednog registra sa S00.
   task reg_procitaj(bit [5 : 0] adresa, output bit [31 : 0] podatak);
      ncc_item it;
      it = ncc_item::type_id::create("it");
      start_item(it);
      it.bus  = BUS_S00;
      it.rw   = CITANJE;
      it.addr = adresa;
      it.len  = 1;
      if (!it.randomize())
         `uvm_fatal("SEQ", "randomizacija nije uspela")
      finish_item(it);
      podatak = it.data[0];
   endtask : reg_procitaj

   // Koliko reci sme da ide u jedan burst od reci 'rec': najvise 256 beat-ova
   // i bez prelaska granice od 4 KB (1024 reci).
   function int unsigned duzina_bursta(int unsigned rec, int unsigned ostalo);
      int unsigned k;
      k = ostalo;
      if (k > 256) k = 256;
      if (k > 1024 - (rec % 1024)) k = 1024 - (rec % 1024);
      return k;
   endfunction

   // Upis niza reci u oblast S01, pocev od reci 'rec'. Veci niz se deli na vise burst-ova.
   task mem_upisi(int oblast, int unsigned rec, bit [31 : 0] d[],
                  order_e redosled = ORDER_AW_FIRST, bit [3 : 0] strb = 4'hF);
      ncc_item it;
      int unsigned poz = 0;
      int unsigned k;
      while (poz < d.size()) begin
         k  = duzina_bursta(rec + poz, d.size() - poz);
         it = ncc_item::type_id::create("it");
         start_item(it);
         it.bus  = BUS_S01;
         it.rw   = UPIS;
         it.addr = oblast * 32768 + (rec + poz) * 4;
         it.len  = k;
         it.data = new[k];
         for (int i = 0; i < k; i++) it.data[i] = d[poz + i];
         it.strb = strb;
         if (!it.randomize() with { order == redosled; })
            `uvm_fatal("SEQ", "randomizacija nije uspela")
         finish_item(it);
         poz = poz + k;
      end
   endtask : mem_upisi

   // Citanje n reci iz oblasti S01, pocev od reci 'rec'.
   task mem_procitaj(int oblast, int unsigned rec, int unsigned n, output bit [31 : 0] d[]);
      ncc_item it;
      int unsigned poz = 0;
      int unsigned k;
      d = new[n];
      while (poz < n) begin
         k  = duzina_bursta(rec + poz, n - poz);
         it = ncc_item::type_id::create("it");
         start_item(it);
         it.bus  = BUS_S01;
         it.rw   = CITANJE;
         it.addr = oblast * 32768 + (rec + poz) * 4;
         it.len  = k;
         if (!it.randomize())
            `uvm_fatal("SEQ", "randomizacija nije uspela")
         finish_item(it);
         for (int i = 0; i < k; i++) d[poz + i] = it.data[i];
         poz = poz + k;
      end
   endtask : mem_procitaj

   // Cita STATUS dok jezgro ne zavrsi (done = 1 i busy = 0).
   task cekaj_done(output bit gotovo);
      bit [31 : 0] status;
      gotovo = 0;
      for (int i = 0; i < 200000; i++) begin
         reg_procitaj(REG_STATUS, status);
         if (status[0] == 1 && status[1] == 0) begin
            gotovo = 1;
            return;
         end
      end
      `uvm_error("SEQ", "jezgro nije zavrsilo -- done nije stigao")
   endtask : cekaj_done

   // Upis dimenzija, start, cekanje i citanje cele mape rezultata
   // (scoreboard je poredi sa referentnim modelom).
   task pokreni(int unsigned iw, int unsigned ih, int unsigned tw, int unsigned th);
      bit          gotovo;
      bit [31 : 0] rezultat[];
      reg_upisi(REG_IMG_W, iw, ORDER_AW_FIRST);
      reg_upisi(REG_IMG_H, ih, ORDER_W_FIRST);
      reg_upisi(REG_TMP_W, tw, ORDER_SIMUL);
      reg_upisi(REG_TMP_H, th, ORDER_AW_FIRST);
      reg_upisi(REG_CTRL, 1, ORDER_W_FIRST);
      cekaj_done(gotovo);
      if (gotovo)
         mem_procitaj(OBL_REZULTAT, 0, (iw - tw + 1) * (ih - th + 1), rezultat);
      `uvm_info("SEQ", $sformatf("skup %0dx%0d / %0dx%0d zavrsen", iw, ih, tw, th), UVM_LOW)
   endtask : pokreni

   // Slucajan redosled AW/W (za slucajni test).
   function order_e slucajan_redosled();
      case ($urandom_range(0, 2))
         0: return ORDER_AW_FIRST;
         1: return ORDER_W_FIRST;
         default: return ORDER_SIMUL;
      endcase
   endfunction

endclass : ncc_base_seq

// =========================================================================
// Smoke: mala slika 4x4 i sablon 2x2 sa jednim poznatim pikom.
// Sablon je jednak prozoru slike na (u=1, v=1), pa tu mora biti 0x80000000.
// =========================================================================
class ncc_smoke_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_smoke_seq)

   function new(string name = "ncc_smoke_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] slika[], sablon[], rezultat[];
      bit          gotovo;

      slika = new[16];
      slika[0]  =  10; slika[1]  = 200; slika[2]  =  30; slika[3]  =  90;
      slika[4]  = 250; slika[5]  =  20; slika[6]  = 140; slika[7]  =  60;
      slika[8]  =  70; slika[9]  = 180; slika[10] =  25; slika[11] = 210;
      slika[12] = 120; slika[13] =  40; slika[14] = 160; slika[15] =  80;
      mem_upisi(OBL_SLIKA, 0, slika, ORDER_AW_FIRST);

      sablon = new[4];
      sablon[0] =  20; sablon[1] = 140;
      sablon[2] = 180; sablon[3] =  25;
      mem_upisi(OBL_SABLON, 0, sablon, ORDER_W_FIRST);

      reg_upisi(REG_IMG_W, 4, ORDER_AW_FIRST);
      reg_upisi(REG_IMG_H, 4, ORDER_W_FIRST);
      reg_upisi(REG_TMP_W, 2, ORDER_SIMUL);
      reg_upisi(REG_TMP_H, 2, ORDER_AW_FIRST);
      reg_upisi(REG_CTRL, 1, ORDER_W_FIRST);

      cekaj_done(gotovo);
      if (!gotovo) return;

      mem_procitaj(OBL_REZULTAT, 0, 9, rezultat);
      foreach (rezultat[i])
         `uvm_info("SMOKE", $sformatf("rezultat[%0d] = 0x%08x", i, rezultat[i]), UVM_LOW)

      // pik na (1,1) = indeks 4; sve ostale vrednosti moraju biti manje
      if (rezultat[4] !== 32'h8000_0000)
         `uvm_error("SMOKE", $sformatf("na (1,1) ocekivano 0x80000000, dobijeno 0x%08x", rezultat[4]))
      foreach (rezultat[i])
         if (i != 4 && rezultat[i] >= rezultat[4])
            `uvm_error("SMOKE", $sformatf("rezultat[%0d] = 0x%08x nije manji od pika", i, rezultat[i]))
   endtask : body

endclass : ncc_smoke_seq

// =========================================================================
// Pokrivenost: usmereni slucajevi koji zatvaraju sve covergroup-e
// i proveravaju ponasanje memorija i kontrolnog registra.
// =========================================================================
class ncc_cov_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_cov_seq)

   function new(string name = "ncc_cov_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] slika[], sablon[], b[], procitano[], pre[], posle[];
      bit [31 : 0] status;
      bit          gotovo;
      int unsigned iw[19], tw[19];

      // --- upis 0 u CTRL ne sme da pokrene jezgro ---
      reg_upisi(REG_CTRL, 0, ORDER_SIMUL);
      reg_procitaj(REG_STATUS, status);
      if (status[1] == 1)
         `uvm_error("COV", "upis 0 u CTRL je pokrenuo jezgro")

      // --- slika (400 reci = burst od 256 + burst od 144) i sablon ---
      slika = new[400];
      foreach (slika[i]) slika[i] = (i * 37 + 11) % 256;
      mem_upisi(OBL_SLIKA, 0, slika, ORDER_W_FIRST);

      sablon = new[64];
      foreach (sablon[i]) sablon[i] = (i * 53 + 7) % 256;
      mem_upisi(OBL_SABLON, 0, sablon, ORDER_W_FIRST);
      mem_upisi(OBL_SABLON, 0, sablon, ORDER_SIMUL);
      mem_upisi(OBL_SABLON, 0, sablon, ORDER_AW_FIRST);

      // --- sablon se ponavlja na 1024 reci: rec 1024 je isto sto i rec 0 ---
      mem_procitaj(OBL_SABLON, TMP_RECI, 4, procitano);
      foreach (procitano[i])
         if (procitano[i] !== sablon[i])
            `uvm_error("COV", $sformatf("sablon rec %0d: ocekivano 0x%08x, dobijeno 0x%08x",
                                        TMP_RECI + i, sablon[i], procitano[i]))

      // --- slika pamti samo donjih 8 bita ---
      b = new[1];
      b[0] = 32'hABCD_EF5A;
      mem_upisi(OBL_SLIKA, 350, b, ORDER_AW_FIRST);
      mem_procitaj(OBL_SLIKA, 350, 1, procitano);
      if (procitano[0] !== 32'h0000_005A)
         `uvm_error("COV", $sformatf("slika: ocekivano 0x0000005a, dobijeno 0x%08x", procitano[0]))

      // --- duzine burst-a 1, 2, 3 i 16 ---
      b = new[1];  b[0] = 8'h11;                  mem_upisi(OBL_SLIKA, 300, b, ORDER_W_FIRST);
      b = new[2];  foreach (b[i]) b[i] = i + 1;   mem_upisi(OBL_SLIKA, 310, b, ORDER_SIMUL);
      b = new[3];  foreach (b[i]) b[i] = i + 1;   mem_upisi(OBL_SLIKA, 320, b, ORDER_AW_FIRST);
      b = new[16]; foreach (b[i]) b[i] = i + 1;   mem_upisi(OBL_SLIKA, 330, b, ORDER_W_FIRST);

      // --- WSTRB: upis se desava samo ako je bit 0 postavljen ---
      b = new[1];
      b[0] = 8'h5A; mem_upisi(OBL_SLIKA, 340, b, ORDER_AW_FIRST, 4'h1);
      b[0] = 8'h5B; mem_upisi(OBL_SLIKA, 341, b, ORDER_W_FIRST,  4'h3);
      b[0] = 8'h5C; mem_upisi(OBL_SLIKA, 342, b, ORDER_SIMUL,    4'h9);
      mem_procitaj(OBL_SLIKA, 343, 1, pre);
      b[0] = 8'hA5; mem_upisi(OBL_SLIKA, 343, b, ORDER_AW_FIRST, 4'hE);
      mem_procitaj(OBL_SLIKA, 343, 1, posle);
      if (posle[0] !== pre[0])
         `uvm_error("COV", "WSTRB = 0xE je promenio memoriju")

      // --- dimenzije: sve dozvoljene kombinacije bin-ova sirine ---
      iw = '{ 1, 20, 20, 20, 45, 45, 45, 45, 45, 60, 60, 60, 60, 60, 90, 90, 90, 90, 90 };
      tw = '{ 1,  1,  5, 15,  1,  5, 15, 20, 30,  1,  5, 15, 20, 30,  1,  5, 15, 20, 30 };
      foreach (iw[k]) pokreni(iw[k], 1, tw[k], 1);

      // --- i visine ---
      pokreni( 1, 45,  1, 15);
      pokreni( 1, 90,  1, 30);
      pokreni( 2, 60,  2, 20);
      pokreni(60,  2, 20,  2);

      // --- upis u CTRL dok jezgro radi (test T7) ---
      reg_upisi(REG_IMG_W, 20, ORDER_AW_FIRST);
      reg_upisi(REG_IMG_H, 20, ORDER_W_FIRST);
      reg_upisi(REG_TMP_W, 5, ORDER_SIMUL);
      reg_upisi(REG_TMP_H, 5, ORDER_AW_FIRST);
      reg_upisi(REG_CTRL, 1, ORDER_W_FIRST);
      reg_procitaj(REG_STATUS, status);
      if (status[1] == 0) `uvm_warning("COV", "jezgro vise nije zauzeto -- T7 nije pogodjen")
      reg_upisi(REG_CTRL, 0, ORDER_AW_FIRST);   // upis 0 dok radi
      reg_procitaj(REG_STATUS, status);
      if (status[1] == 0) `uvm_warning("COV", "jezgro vise nije zauzeto -- T7 nije pogodjen")
      reg_upisi(REG_CTRL, 1, ORDER_SIMUL);      // ponovni start dok radi -- jezgro ga ignorise
      cekaj_done(gotovo);

      // --- upis 0 u CTRL posle zavrsetka ne sme da obrise done ---
      reg_upisi(REG_CTRL, 0, ORDER_W_FIRST);
      reg_procitaj(REG_STATUS, status);
      if (status[0] == 0)
         `uvm_error("COV", "upis 0 u CTRL je obrisao done")

      // --- upis u oblast rezultata se zanemaruje, nemapirana oblast vraca nule ---
      b = new[2]; b[0] = 32'hDEAD; b[1] = 32'hBEEF;
      mem_upisi(OBL_REZULTAT, 0, b, ORDER_AW_FIRST);
      mem_upisi(OBL_REZULTAT, 2, b, ORDER_W_FIRST);
      mem_upisi(OBL_REZULTAT, 4, b, ORDER_SIMUL);
      mem_upisi(OBL_NEMAPIRANO, 0, b, ORDER_AW_FIRST);
      mem_upisi(OBL_NEMAPIRANO, 2, b, ORDER_W_FIRST);
      mem_upisi(OBL_NEMAPIRANO, 4, b, ORDER_SIMUL);
      mem_procitaj(OBL_NEMAPIRANO, 0, 2, procitano);
      foreach (procitano[i])
         if (procitano[i] !== 0)
            `uvm_error("COV", $sformatf("nemapirana oblast: ocekivano 0, dobijeno 0x%08x", procitano[i]))

      // mapa poslednjeg posla mora ostati ista (scoreboard poredi)
      mem_procitaj(OBL_REZULTAT, 0, 256, procitano);
   endtask : body

endclass : ncc_cov_seq

// =========================================================================
// Slucajna sekvenca: dimenzije, podaci i redosled kanala zavise od seed-a.
// =========================================================================
class ncc_random_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_random_seq)

   rand int unsigned iw, ih, tw, th;
   rand int unsigned br_citanja;

   constraint c_dim     { iw inside {[2:24]}; ih inside {[2:24]};
                          tw inside {[1:6]};  th inside {[1:6]};
                          tw <= iw; th <= ih; }
   constraint c_citanja { br_citanja inside {[3:8]}; }

   function new(string name = "ncc_random_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] slika[], sablon[], procitano[];
      int          oblast;

      if (!this.randomize())
         `uvm_fatal("RND", "randomizacija nije uspela")
      `uvm_info("RND", $sformatf("slika %0dx%0d, sablon %0dx%0d", iw, ih, tw, th), UVM_LOW)

      slika = new[iw * ih];
      foreach (slika[i]) slika[i] = $urandom_range(0, 255);
      mem_upisi(OBL_SLIKA, 0, slika, slucajan_redosled());

      sablon = new[tw * th];
      foreach (sablon[i]) sablon[i] = $urandom_range(0, 255);
      mem_upisi(OBL_SABLON, 0, sablon, slucajan_redosled());

      // slucajna citanja iz slike, sablona i nemapirane oblasti
      for (int i = 0; i < br_citanja; i++) begin
         case ($urandom_range(0, 2))
            0: oblast = OBL_SLIKA;
            1: oblast = OBL_SABLON;
            default: oblast = OBL_NEMAPIRANO;
         endcase
         mem_procitaj(oblast, $urandom_range(0, 1023), $urandom_range(1, 32), procitano);
      end

      // upisi u registre 0x10-0x2C koje jezgro ne koristi
      for (int i = 0; i < 4; i++)
         reg_upisi(16 + 4 * $urandom_range(0, 7), $urandom(), slucajan_redosled());

      pokreni(iw, ih, tw, th);
   endtask : body

endclass : ncc_random_seq
