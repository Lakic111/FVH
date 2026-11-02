// Scoreboard -- dobija samo ono sto je monitor video na magistralama.
//   1. upisi u oblasti slike i sablona pune kopiju memorije (senku)
//   2. upisi u registre dimenzija pamte konfiguraciju
//   3. upis 1 u CTRL racuna ocekivanu mapu rezultata (referentni model)
//   4. svako citanje oblasti rezultata poredi se sa ocekivanom mapom
class ncc_scoreboard extends uvm_scoreboard;

   uvm_analysis_imp #(ncc_item, ncc_scoreboard) item_collected_imp;

   bit [7 : 0]  senka_slika[int];
   bit [7 : 0]  senka_sablon[int];
   bit [31 : 0] ocekivano[int];

   int unsigned img_w, img_h, tmp_w, tmp_h;
   bit          ima_predikciju = 0;
   bit          video_done = 0;
   bit          zadnji_busy = 0;

   int unsigned br_poredjenja = 0;
   int unsigned br_gresaka = 0;

   `uvm_component_utils(ncc_scoreboard)

   function new(string name = "ncc_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      item_collected_imp = new("item_collected_imp", this);
   endfunction

   function void write(ncc_item t);
      int oblast, rec;

      if (t.bus == BUS_S00) begin
         if (t.rw == UPIS) begin
            if (t.addr == REG_IMG_W) img_w = t.data[0][7 : 0];
            if (t.addr == REG_IMG_H) img_h = t.data[0][7 : 0];
            if (t.addr == REG_TMP_W) tmp_w = t.data[0][7 : 0];
            if (t.addr == REG_TMP_H) tmp_h = t.data[0][7 : 0];
            if (t.addr == REG_CTRL && t.data[0][0] == 1) begin
               // jezgro ignorise start dok radi (nalaz 2.2), pa nema ni nove predikcije
               if (zadnji_busy)
                  `uvm_info("SB", "start dok je jezgro zauzeto -- jezgro ga ignorise", UVM_LOW)
               else
                  pokreni();
            end
         end
         else if (t.addr == REG_STATUS) begin
            zadnji_busy = t.data[0][1];
            if (t.data[0][0] == 1) video_done = 1;
         end
         return;
      end

      // S01
      oblast = t.addr[16 : 15];
      rec    = t.addr[14 : 2];
      if (t.rw == UPIS) begin
         // RTL upisuje samo ako je WSTRB(0) = 1
         if (t.strb[0] == 0) return;
         if (oblast == OBL_SLIKA)
            foreach (t.data[i]) senka_slika[rec + i] = t.data[i][7 : 0];
         if (oblast == OBL_SABLON)
            foreach (t.data[i]) senka_sablon[(rec + i) % TMP_RECI] = t.data[i][7 : 0];
         // upis u oblast rezultata se zanemaruje (oblast je samo za citanje)
      end
      else if (oblast == OBL_REZULTAT) begin
         uporedi(t, rec);
      end
   endfunction : write

   // Pokretanje jezgra: ocekivana mapa iz senke i trenutnih dimenzija.
   function void pokreni();
      bit [7 : 0]  slika[], sablon[];
      bit [31 : 0] mapa[];

      if (img_w == 0 || img_h == 0 || tmp_w == 0 || tmp_h == 0) begin
         `uvm_warning("SB", "start pre nego sto su upisane sve dimenzije")
         return;
      end

      slika  = new[img_w * img_h];
      sablon = new[tmp_w * tmp_h];
      foreach (slika[i])
         if (senka_slika.exists(i)) slika[i] = senka_slika[i]; else slika[i] = 0;
      foreach (sablon[i])
         if (senka_sablon.exists(i)) sablon[i] = senka_sablon[i]; else sablon[i] = 0;

      ncc_model(slika, sablon, mapa);

      ocekivano.delete();
      foreach (mapa[i]) ocekivano[i] = mapa[i];
      ima_predikciju = 1;
      video_done = 0;
      `uvm_info("SB", $sformatf("predikcija: slika %0dx%0d, sablon %0dx%0d, %0d rezultata",
                                img_w, img_h, tmp_w, tmp_h, mapa.size()), UVM_LOW)
   endfunction : pokreni

   // Referentni model NCC^2 -- isti racun kao ncc_core.vhd, rezultat u Q1.31.
   function void ncc_model(bit [7 : 0] slika[], bit [7 : 0] sablon[], output bit [31 : 0] mapa[]);
      int unsigned br, res_w, res_h, sum_t, sum_f;
      int          t_sr, f_sr, p, df, dt;
      int          sum_num, sum_den_f, sum_den_t;
      longint      num, num_sq, den_prod;
      bit [82 : 0] deljenik, delilac, kolicnik;

      br    = tmp_w * tmp_h;
      res_w = img_w - tmp_w + 1;
      res_h = img_h - tmp_h + 1;
      mapa  = new[res_w * res_h];

      // srednja vrednost sablona, zaokruzena
      sum_t = 0;
      foreach (sablon[i]) sum_t = sum_t + sablon[i];
      t_sr = (sum_t + br / 2) / br;

      for (int v = 0; v < res_h; v++) begin
         for (int u = 0; u < res_w; u++) begin
            // srednja vrednost prozora slike na (u, v)
            sum_f = 0;
            for (int y = 0; y < tmp_h; y++)
               for (int x = 0; x < tmp_w; x++)
                  sum_f = sum_f + slika[(v + y) * img_w + (u + x)];
            f_sr = (sum_f + br / 2) / br;

            sum_num   = 0;
            sum_den_f = 0;
            sum_den_t = 0;
            for (int y = 0; y < tmp_h; y++) begin
               for (int x = 0; x < tmp_w; x++) begin
                  p  = slika[(v + y) * img_w + (u + x)];
                  df = p - f_sr;
                  p  = sablon[y * tmp_w + x];
                  dt = p - t_sr;
                  sum_num   = sum_num   + df * dt;
                  sum_den_f = sum_den_f + df * df;
                  sum_den_t = sum_den_t + dt * dt;
               end
            end

            if (sum_den_f == 0 || sum_den_t == 0) begin
               mapa[v * res_w + u] = 0;
            end
            else begin
               // NCC^2 = num^2 / (den_f * den_t), pomereno za 31 bit (Q1.31)
               num      = sum_num;
               num_sq   = num * num;
               den_prod = sum_den_f;
               den_prod = den_prod * sum_den_t;
               deljenik = num_sq;
               deljenik = deljenik << 31;
               delilac  = den_prod;
               kolicnik = deljenik / delilac;
               mapa[v * res_w + u] = kolicnik[31 : 0];
            end
         end
      end
   endfunction : ncc_model

   function void uporedi(ncc_item t, int rec);
      if (!ima_predikciju) begin
         `uvm_warning("SB", "citanje rezultata pre pokretanja jezgra")
         return;
      end
      if (!video_done)
         `uvm_warning("SB", "rezultat se cita, a done jos nije vidjen")

      foreach (t.data[i]) begin
         if (ocekivano.exists(rec + i)) begin
            br_poredjenja++;
            if (t.data[i] !== ocekivano[rec + i]) begin
               br_gresaka++;
               `uvm_error("SB", $sformatf("rezultat[%0d]: ocekivano 0x%08x, dobijeno 0x%08x",
                                          rec + i, ocekivano[rec + i], t.data[i]))
            end
         end
      end
   endfunction : uporedi

   function void report_phase(uvm_phase phase);
      if (br_poredjenja == 0)
         `uvm_error("SB", "scoreboard nije uporedio nijedan rezultat")
      else
         `uvm_info("SB", $sformatf("%0d poredjenja, %0d gresaka", br_poredjenja, br_gresaka), UVM_LOW)
   endfunction : report_phase

endclass : ncc_scoreboard
