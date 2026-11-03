// Monitor -- on every rising clock edge it watches both buses, builds
// transactions and sends them to the scoreboard. Coverage is collected here too.
//
// A write is complete when the response (B channel) is seen: by then the address
// and the data have arrived. The AW/W order is measured by the cycle in which VALID was first raised.
class ncc_monitor extends uvm_monitor;

   `uvm_component_utils(ncc_monitor)

   virtual interface ncc_if vif;
   uvm_analysis_port #(ncc_item) item_collected_port;

   int cycle = 0;

   // S00
   bit          s00_aw_prev, s00_w_prev;
   int          s00_aw_cycle, s00_w_cycle;
   bit [5 : 0]  s00_addr, s00_ar_addr;
   bit [31 : 0] s00_data;
   bit [3 : 0]  s00_strb;

   // S01
   bit          s01_aw_prev, s01_w_prev;
   int          s01_aw_cycle, s01_w_cycle;
   bit [16 : 0] s01_addr, s01_ar_addr;
   int unsigned s01_len, s01_ar_len;
   bit [3 : 0]  s01_strb;
   bit [31 : 0] w_words[$];
   bit [31 : 0] r_words[$];

   // --- coverage fields ---
   int unsigned img_w, img_h, tmp_w, tmp_h;  // last written dimensions
   bit          start;                       // bit 0 of the CTRL write
   bit          busy, done;                  // from the last STATUS read
   order_e      cov_order;
   int          cov_region;                  // 0..3 = S01 regions, 4 = S00
   int unsigned cov_len;
   bit [3 : 0]  cov_strb;

   // Image and template dimensions at the moment the core is started.
   covergroup cg_dims;
      option.per_instance = 1;
      cp_img_w : coverpoint img_w {
         bins min = {1}; bins below = {[2:44]}; bins coarse = {45};
         bins above = {[46:89]}; bins max = {90};
      }
      cp_img_h : coverpoint img_h {
         bins min = {1}; bins below = {[2:44]}; bins coarse = {45};
         bins above = {[46:89]}; bins max = {90};
      }
      cp_tmp_w : coverpoint tmp_w {
         bins min = {1}; bins below = {[2:14]}; bins coarse = {15};
         bins above = {[16:29]}; bins max = {30};
      }
      cp_tmp_h : coverpoint tmp_h {
         bins min = {1}; bins below = {[2:14]}; bins coarse = {15};
         bins above = {[16:29]}; bins max = {30};
      }
      // the template cannot be larger than the image, so these combinations do not exist
      x_img_tmp : cross cp_img_w, cp_tmp_w {
         ignore_bins impossible_min   = binsof(cp_img_w.min) && !binsof(cp_tmp_w.min);
         ignore_bins impossible_below = binsof(cp_img_w.below) &&
                                        (binsof(cp_tmp_w.above) || binsof(cp_tmp_w.max));
      }
   endgroup

   // CTRL write against the core state (start while the core is busy = test T7).
   covergroup cg_ctrl;
      option.per_instance = 1;
      cp_start : coverpoint start { bins no = {0}; bins yes = {1}; }
      cp_busy  : coverpoint busy  { bins no = {0}; bins yes = {1}; }
      cp_done  : coverpoint done  { bins no = {0}; bins yes = {1}; }
      x_start_busy : cross cp_start, cp_busy;
      x_start_done : cross cp_start, cp_done;
   endgroup

   // Every write: AW/W order in every region, burst length, WSTRB.
   covergroup cg_axi;
      option.per_instance = 1;
      cp_order : coverpoint cov_order;
      cp_region : coverpoint cov_region {
         bins image = {0}; bins template = {1}; bins result = {2};
         bins unmapped = {3}; bins s00 = {4};
      }
      x_order_region : cross cp_order, cp_region;
      cp_len : coverpoint cov_len {
         bins b1 = {1}; bins b2 = {2}; bins b3_15 = {[3:15]};
         bins b16_255 = {[16:255]}; bins b256 = {256};
      }
      cp_strb : coverpoint cov_strb {
         bins full = {4'hF}; bins b1 = {4'h1}; bins b3 = {4'h3}; bins b9 = {4'h9};
         bins other = default;
      }
   endgroup

   function new(string name = "ncc_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
      cg_dims = new();
      cg_ctrl = new();
      cg_axi  = new();
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
         cycle++;
         collect_s00();
         collect_s01();
      end
   endtask : run_phase

   // Based on the cycles in which AWVALID and WVALID were raised.
   function order_e get_order(int aw_cycle, int w_cycle);
      if (aw_cycle < w_cycle) return ORDER_AW_FIRST;
      if (aw_cycle > w_cycle) return ORDER_W_FIRST;
      return ORDER_SIMUL;
   endfunction

   // ---------------------------------------------------------------- S00
   function void collect_s00();
      ncc_item it;

      if (vif.s00_awvalid === 1'b1 && !s00_aw_prev) s00_aw_cycle = cycle;
      if (vif.s00_wvalid  === 1'b1 && !s00_w_prev)  s00_w_cycle  = cycle;
      s00_aw_prev = (vif.s00_awvalid === 1'b1);
      s00_w_prev  = (vif.s00_wvalid  === 1'b1);

      // The fixed S00 never raises awready and wready in the same cycle (AW/W bug).
      if (vif.s00_awready === 1'b1 && vif.s00_wready === 1'b1)
         `uvm_error("MON", "S00: awready and wready in the same cycle -- the AW/W bug is back")

      if (vif.s00_awvalid === 1'b1 && vif.s00_awready === 1'b1)
         s00_addr = vif.s00_awaddr;
      if (vif.s00_wvalid === 1'b1 && vif.s00_wready === 1'b1) begin
         s00_data = vif.s00_wdata;
         s00_strb = vif.s00_wstrb;
      end

      if (vif.s00_bvalid === 1'b1 && vif.s00_bready === 1'b1) begin
         it = ncc_item::type_id::create("it");
         it.bus     = BUS_S00;
         it.rw      = WRITE;
         it.addr    = s00_addr;
         it.len     = 1;
         it.data    = new[1];
         it.data[0] = s00_data;
         it.strb    = s00_strb;
         it.resp    = vif.s00_bresp;
         it.order   = get_order(s00_aw_cycle, s00_w_cycle);
         item_collected_port.write(it);

         cov_order  = it.order;
         cov_region = 4;
         cov_len    = 1;
         cov_strb   = it.strb;
         cg_axi.sample();

         if (it.addr == REG_IMG_W) img_w = it.data[0][7 : 0];
         if (it.addr == REG_IMG_H) img_h = it.data[0][7 : 0];
         if (it.addr == REG_TMP_W) tmp_w = it.data[0][7 : 0];
         if (it.addr == REG_TMP_H) tmp_h = it.data[0][7 : 0];
         if (it.addr == REG_CTRL) begin
            start = it.data[0][0];
            cg_ctrl.sample();
            if (start) cg_dims.sample();
         end
      end

      if (vif.s00_arvalid === 1'b1 && vif.s00_arready === 1'b1)
         s00_ar_addr = vif.s00_araddr;

      if (vif.s00_rvalid === 1'b1 && vif.s00_rready === 1'b1) begin
         it = ncc_item::type_id::create("it");
         it.bus     = BUS_S00;
         it.rw      = READ;
         it.addr    = s00_ar_addr;
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
   endfunction : collect_s00

   // ---------------------------------------------------------------- S01
   function void collect_s01();
      ncc_item it;

      if (vif.s01_awvalid === 1'b1 && !s01_aw_prev) s01_aw_cycle = cycle;
      // only the first beat of the burst matters for the order
      if (vif.s01_wvalid === 1'b1 && !s01_w_prev && w_words.size() == 0) s01_w_cycle = cycle;
      s01_aw_prev = (vif.s01_awvalid === 1'b1);
      s01_w_prev  = (vif.s01_wvalid  === 1'b1);

      if (vif.s01_awready === 1'b1 && vif.s01_wready === 1'b1)
         `uvm_error("MON", "S01: awready and wready in the same cycle -- the AW/W bug is back")

      if (vif.s01_awvalid === 1'b1 && vif.s01_awready === 1'b1) begin
         s01_addr = vif.s01_awaddr;
         s01_len  = vif.s01_awlen + 1;
      end
      if (vif.s01_wvalid === 1'b1 && vif.s01_wready === 1'b1) begin
         w_words.push_back(vif.s01_wdata);
         s01_strb = vif.s01_wstrb;
      end

      if (vif.s01_bvalid === 1'b1 && vif.s01_bready === 1'b1) begin
         if (w_words.size() != s01_len)
            `uvm_error("MON", $sformatf("S01: AWLEN asks for %0d beats, %0d arrived",
                                        s01_len, w_words.size()))
         it = ncc_item::type_id::create("it");
         it.bus   = BUS_S01;
         it.rw    = WRITE;
         it.addr  = s01_addr;
         it.len   = w_words.size();
         it.data  = new[w_words.size()];
         foreach (w_words[i]) it.data[i] = w_words[i];
         it.strb  = s01_strb;
         it.resp  = vif.s01_bresp;
         it.order = get_order(s01_aw_cycle, s01_w_cycle);
         w_words.delete();
         item_collected_port.write(it);

         cov_order  = it.order;
         cov_region = it.addr[16 : 15];
         cov_len    = it.len;
         cov_strb   = it.strb;
         cg_axi.sample();
      end

      if (vif.s01_arvalid === 1'b1 && vif.s01_arready === 1'b1) begin
         s01_ar_addr = vif.s01_araddr;
         s01_ar_len  = vif.s01_arlen + 1;
      end

      if (vif.s01_rvalid === 1'b1 && vif.s01_rready === 1'b1) begin
         r_words.push_back(vif.s01_rdata);
         if (vif.s01_rlast === 1'b1) begin
            if (r_words.size() != s01_ar_len)
               `uvm_error("MON", $sformatf("S01: ARLEN asks for %0d beats, %0d arrived",
                                           s01_ar_len, r_words.size()))
            it = ncc_item::type_id::create("it");
            it.bus  = BUS_S01;
            it.rw   = READ;
            it.addr = s01_ar_addr;
            it.len  = r_words.size();
            it.data = new[r_words.size()];
            foreach (r_words[i]) it.data[i] = r_words[i];
            it.resp = vif.s01_rresp;
            r_words.delete();
            item_collected_port.write(it);
         end
      end
   endfunction : collect_s01

endclass : ncc_monitor
