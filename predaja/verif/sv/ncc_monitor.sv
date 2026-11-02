// Monitor -- na svaku uzlaznu ivicu takta gleda obe magistrale, sklapa
// transakcije i salje ih scoreboard-u. Ovde se prikuplja i pokrivenost.
//
// Upis je zavrsen kada se vidi odgovor (B kanal): tada su adresa i podatak
// vec stigli. Redosled AW/W se meri po taktu u kome je VALID prvi put postavljen.
class ncc_monitor extends uvm_monitor;

   `uvm_component_utils(ncc_monitor)

   virtual interface ncc_if vif;
   uvm_analysis_port #(ncc_item) item_collected_port;

   int ciklus = 0;

   // S00
   bit          s00_aw_bio, s00_w_bio;
   int          s00_aw_takt, s00_w_takt;
   bit [5 : 0]  s00_adresa, s00_ar_adresa;
   bit [31 : 0] s00_podatak;
   bit [3 : 0]  s00_strb;

   // S01
   bit          s01_aw_bio, s01_w_bio;
   int          s01_aw_takt, s01_w_takt;
   bit [16 : 0] s01_adresa, s01_ar_adresa;
   int unsigned s01_duzina, s01_ar_duzina;
   bit [3 : 0]  s01_strb;
   bit [31 : 0] w_reci[$];
   bit [31 : 0] r_reci[$];

   // --- polja za pokrivenost ---
   int unsigned img_w, img_h, tmp_w, tmp_h;  // poslednje upisane dimenzije
   bit          start;                       // bit 0 upisa u CTRL
   bit          busy, done;                  // iz poslednjeg citanja STATUS-a
   order_e      cov_order;
   int          cov_oblast;                  // 0..3 = oblasti S01, 4 = S00
   int unsigned cov_len;
   bit [3 : 0]  cov_strb;

   // Dimenzije slike i sablona u trenutku pokretanja jezgra.
   covergroup cg_dimenzije;
      option.per_instance = 1;
      cp_img_w : coverpoint img_w {
         bins min = {1}; bins ispod = {[2:44]}; bins coarse = {45};
         bins iznad = {[46:89]}; bins max = {90};
      }
      cp_img_h : coverpoint img_h {
         bins min = {1}; bins ispod = {[2:44]}; bins coarse = {45};
         bins iznad = {[46:89]}; bins max = {90};
      }
      cp_tmp_w : coverpoint tmp_w {
         bins min = {1}; bins ispod = {[2:14]}; bins coarse = {15};
         bins iznad = {[16:29]}; bins max = {30};
      }
      cp_tmp_h : coverpoint tmp_h {
         bins min = {1}; bins ispod = {[2:14]}; bins coarse = {15};
         bins iznad = {[16:29]}; bins max = {30};
      }
      // sablon ne sme biti veci od slike, pa ove kombinacije ne postoje
      x_img_tmp : cross cp_img_w, cp_tmp_w {
         ignore_bins nemoguce_min   = binsof(cp_img_w.min) && !binsof(cp_tmp_w.min);
         ignore_bins nemoguce_ispod = binsof(cp_img_w.ispod) &&
                                      (binsof(cp_tmp_w.iznad) || binsof(cp_tmp_w.max));
      }
   endgroup

   // Upis u CTRL u odnosu na stanje jezgra (start dok je jezgro zauzeto = test T7).
   covergroup cg_kontrola;
      option.per_instance = 1;
      cp_start : coverpoint start { bins ne = {0}; bins da = {1}; }
      cp_busy  : coverpoint busy  { bins ne = {0}; bins da = {1}; }
      cp_done  : coverpoint done  { bins ne = {0}; bins da = {1}; }
      x_start_busy : cross cp_start, cp_busy;
      x_start_done : cross cp_start, cp_done;
   endgroup

   // Svaki upis: redosled AW/W u svakoj oblasti, duzina burst-a, WSTRB.
   covergroup cg_axi;
      option.per_instance = 1;
      cp_order : coverpoint cov_order;
      cp_oblast : coverpoint cov_oblast {
         bins slika = {0}; bins sablon = {1}; bins rezultat = {2};
         bins nemapirano = {3}; bins s00 = {4};
      }
      x_order_oblast : cross cp_order, cp_oblast;
      cp_len : coverpoint cov_len {
         bins b1 = {1}; bins b2 = {2}; bins b3_15 = {[3:15]};
         bins b16_255 = {[16:255]}; bins b256 = {256};
      }
      cp_strb : coverpoint cov_strb {
         bins puna = {4'hF}; bins b1 = {4'h1}; bins b3 = {4'h3}; bins b9 = {4'h9};
         bins ostalo = default;
      }
   endgroup

   function new(string name = "ncc_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
      cg_dimenzije = new();
      cg_kontrola  = new();
      cg_axi       = new();
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ncc_if)::get(this, "", "ncc_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction

   task run_phase(uvm_phase phase);
      @(posedge vif.rstn);
      forever begin
         @(posedge vif.clk);
         ciklus++;
         prati_s00();
         prati_s01();
      end
   endtask : run_phase

   // Na osnovu taktova u kojima su AWVALID i WVALID postavljeni.
   function order_e redosled(int aw_takt, int w_takt);
      if (aw_takt < w_takt) return ORDER_AW_FIRST;
      if (aw_takt > w_takt) return ORDER_W_FIRST;
      return ORDER_SIMUL;
   endfunction

   // ---------------------------------------------------------------- S00
   function void prati_s00();
      ncc_item it;

      if (vif.s00_awvalid === 1'b1 && !s00_aw_bio) s00_aw_takt = ciklus;
      if (vif.s00_wvalid  === 1'b1 && !s00_w_bio)  s00_w_takt  = ciklus;
      s00_aw_bio = (vif.s00_awvalid === 1'b1);
      s00_w_bio  = (vif.s00_wvalid  === 1'b1);

      // Popravljeni S00 nikad ne podize awready i wready u istom taktu (AW/W bug).
      if (vif.s00_awready === 1'b1 && vif.s00_wready === 1'b1)
         `uvm_error("MON", "S00: awready i wready u istom taktu -- vratio se AW/W bug")

      if (vif.s00_awvalid === 1'b1 && vif.s00_awready === 1'b1)
         s00_adresa = vif.s00_awaddr;
      if (vif.s00_wvalid === 1'b1 && vif.s00_wready === 1'b1) begin
         s00_podatak = vif.s00_wdata;
         s00_strb    = vif.s00_wstrb;
      end

      if (vif.s00_bvalid === 1'b1 && vif.s00_bready === 1'b1) begin
         it = ncc_item::type_id::create("it");
         it.bus     = BUS_S00;
         it.rw      = UPIS;
         it.addr    = s00_adresa;
         it.len     = 1;
         it.data    = new[1];
         it.data[0] = s00_podatak;
         it.strb    = s00_strb;
         it.resp    = vif.s00_bresp;
         it.order   = redosled(s00_aw_takt, s00_w_takt);
         item_collected_port.write(it);

         cov_order  = it.order;
         cov_oblast = 4;
         cov_len    = 1;
         cov_strb   = it.strb;
         cg_axi.sample();

         if (it.addr == REG_IMG_W) img_w = it.data[0][7 : 0];
         if (it.addr == REG_IMG_H) img_h = it.data[0][7 : 0];
         if (it.addr == REG_TMP_W) tmp_w = it.data[0][7 : 0];
         if (it.addr == REG_TMP_H) tmp_h = it.data[0][7 : 0];
         if (it.addr == REG_CTRL) begin
            start = it.data[0][0];
            cg_kontrola.sample();
            if (start) cg_dimenzije.sample();
         end
      end

      if (vif.s00_arvalid === 1'b1 && vif.s00_arready === 1'b1)
         s00_ar_adresa = vif.s00_araddr;

      if (vif.s00_rvalid === 1'b1 && vif.s00_rready === 1'b1) begin
         it = ncc_item::type_id::create("it");
         it.bus     = BUS_S00;
         it.rw      = CITANJE;
         it.addr    = s00_ar_adresa;
         it.len     = 1;
         it.data    = new[1];
         it.data[0] = vif.s00_rdata;
         it.resp    = vif.s00_rresp;
         item_collected_port.write(it);

         if (it.addr == REG_STATUS) begin
            done = it.data[0][0];
            busy = it.data[0][1];
         end
      end
   endfunction : prati_s00

   // ---------------------------------------------------------------- S01
   function void prati_s01();
      ncc_item it;

      if (vif.s01_awvalid === 1'b1 && !s01_aw_bio) s01_aw_takt = ciklus;
      // za redosled je bitan samo prvi beat burst-a
      if (vif.s01_wvalid === 1'b1 && !s01_w_bio && w_reci.size() == 0) s01_w_takt = ciklus;
      s01_aw_bio = (vif.s01_awvalid === 1'b1);
      s01_w_bio  = (vif.s01_wvalid  === 1'b1);

      if (vif.s01_awready === 1'b1 && vif.s01_wready === 1'b1)
         `uvm_error("MON", "S01: awready i wready u istom taktu -- vratio se AW/W bug")

      if (vif.s01_awvalid === 1'b1 && vif.s01_awready === 1'b1) begin
         s01_adresa = vif.s01_awaddr;
         s01_duzina = vif.s01_awlen + 1;
      end
      if (vif.s01_wvalid === 1'b1 && vif.s01_wready === 1'b1) begin
         w_reci.push_back(vif.s01_wdata);
         s01_strb = vif.s01_wstrb;
      end

      if (vif.s01_bvalid === 1'b1 && vif.s01_bready === 1'b1) begin
         if (w_reci.size() != s01_duzina)
            `uvm_error("MON", $sformatf("S01: AWLEN trazi %0d beat-ova, stiglo %0d",
                                        s01_duzina, w_reci.size()))
         it = ncc_item::type_id::create("it");
         it.bus   = BUS_S01;
         it.rw    = UPIS;
         it.addr  = s01_adresa;
         it.len   = w_reci.size();
         it.data  = new[w_reci.size()];
         foreach (w_reci[i]) it.data[i] = w_reci[i];
         it.strb  = s01_strb;
         it.resp  = vif.s01_bresp;
         it.order = redosled(s01_aw_takt, s01_w_takt);
         w_reci.delete();
         item_collected_port.write(it);

         cov_order  = it.order;
         cov_oblast = it.addr[16 : 15];
         cov_len    = it.len;
         cov_strb   = it.strb;
         cg_axi.sample();
      end

      if (vif.s01_arvalid === 1'b1 && vif.s01_arready === 1'b1) begin
         s01_ar_adresa = vif.s01_araddr;
         s01_ar_duzina = vif.s01_arlen + 1;
      end

      if (vif.s01_rvalid === 1'b1 && vif.s01_rready === 1'b1) begin
         r_reci.push_back(vif.s01_rdata);
         if (vif.s01_rlast === 1'b1) begin
            if (r_reci.size() != s01_ar_duzina)
               `uvm_error("MON", $sformatf("S01: ARLEN trazi %0d beat-ova, stiglo %0d",
                                           s01_ar_duzina, r_reci.size()))
            it = ncc_item::type_id::create("it");
            it.bus  = BUS_S01;
            it.rw   = CITANJE;
            it.addr = s01_ar_adresa;
            it.len  = r_reci.size();
            it.data = new[r_reci.size()];
            foreach (r_reci[i]) it.data[i] = r_reci[i];
            it.resp = vif.s01_rresp;
            r_reci.delete();
            item_collected_port.write(it);
         end
      end
   endfunction : prati_s01

endclass : ncc_monitor
