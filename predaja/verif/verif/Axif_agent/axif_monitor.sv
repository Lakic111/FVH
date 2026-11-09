// Monitor -- on every rising clock edge it watches S01, builds transactions and
// sends them to the scoreboard. Coverage of the memory writes is collected here too.
//
// A write is complete when the response (B channel) is seen: by then the address
// and the data have arrived. The AW/W order is measured by the cycle in which VALID was first raised.
class axif_monitor extends uvm_monitor;

   `uvm_component_utils(axif_monitor)

   virtual interface axif_if vif;
   uvm_analysis_port #(axif_item) item_collected_port;

   int cycle = 0;

   bit          aw_prev, w_prev;
   int          aw_cycle, w_cycle;
   bit [16 : 0] wr_addr, rd_addr;
   int unsigned wr_len, rd_len;
   bit [3 : 0]  wr_strb;
   bit [31 : 0] w_words[$];
   bit [31 : 0] r_words[$];

   // --- coverage fields ---
   order_e      cov_order;
   int          cov_region;                  // 0..3 = S01 regions
   int unsigned cov_len;
   bit [3 : 0]  cov_strb;

   // Every write: AW/W order in every region, burst length, WSTRB.
   covergroup cg_axif;
      option.per_instance = 1;
      cp_order : coverpoint cov_order;
      cp_region : coverpoint cov_region {
         bins image = {0}; bins template = {1}; bins result = {2}; bins unmapped = {3};
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

   function new(string name = "axif_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
      cg_axif = new();
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axif_if)::get(this, "", "axif_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction

   task run_phase(uvm_phase phase);
      @(posedge vif.rstn);
      forever begin
         @(posedge vif.clk);
         cycle++;
         collect();
      end
   endtask : run_phase

   // Based on the cycles in which AWVALID and WVALID were raised.
   function order_e get_order();
      if (aw_cycle < w_cycle) return ORDER_AW_FIRST;
      if (aw_cycle > w_cycle) return ORDER_W_FIRST;
      return ORDER_SIMUL;
   endfunction

   function void collect();
      axif_item it;

      if (vif.awvalid === 1'b1 && !aw_prev) aw_cycle = cycle;
      // only the first beat of the burst matters for the order
      if (vif.wvalid === 1'b1 && !w_prev && w_words.size() == 0) w_cycle = cycle;
      aw_prev = (vif.awvalid === 1'b1);
      w_prev  = (vif.wvalid  === 1'b1);

      if (vif.awready === 1'b1 && vif.wready === 1'b1)
         `uvm_error("MON", "S01: awready and wready in the same cycle -- the AW/W bug is back")

      if (vif.awvalid === 1'b1 && vif.awready === 1'b1) begin
         wr_addr = vif.awaddr;
         wr_len  = vif.awlen + 1;
      end
      if (vif.wvalid === 1'b1 && vif.wready === 1'b1) begin
         w_words.push_back(vif.wdata);
         wr_strb = vif.wstrb;
      end

      if (vif.bvalid === 1'b1 && vif.bready === 1'b1) begin
         if (w_words.size() != wr_len)
            `uvm_error("MON", $sformatf("S01: AWLEN asks for %0d beats, %0d arrived",
                                        wr_len, w_words.size()))
         it = axif_item::type_id::create("it");
         it.rw    = WRITE;
         it.addr  = wr_addr;
         it.len   = w_words.size();
         it.data  = new[w_words.size()];
         foreach (w_words[i]) it.data[i] = w_words[i];
         it.strb  = wr_strb;
         it.resp  = vif.bresp;
         it.order = get_order();
         w_words.delete();
         item_collected_port.write(it);

         cov_order  = it.order;
         cov_region = it.addr[16 : 15];
         cov_len    = it.len;
         cov_strb   = it.strb;
         cg_axif.sample();
      end

      if (vif.arvalid === 1'b1 && vif.arready === 1'b1) begin
         rd_addr = vif.araddr;
         rd_len  = vif.arlen + 1;
      end

      if (vif.rvalid === 1'b1 && vif.rready === 1'b1) begin
         r_words.push_back(vif.rdata);
         if (vif.rlast === 1'b1) begin
            if (r_words.size() != rd_len)
               `uvm_error("MON", $sformatf("S01: ARLEN asks for %0d beats, %0d arrived",
                                           rd_len, r_words.size()))
            it = axif_item::type_id::create("it");
            it.rw   = READ;
            it.addr = rd_addr;
            it.len  = r_words.size();
            it.data = new[r_words.size()];
            foreach (r_words[i]) it.data[i] = r_words[i];
            it.resp = vif.rresp;
            r_words.delete();
            item_collected_port.write(it);
         end
      end
   endfunction : collect

endclass : axif_monitor
