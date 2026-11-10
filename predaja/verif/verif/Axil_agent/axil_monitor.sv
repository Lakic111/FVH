// Monitor -- on every rising clock edge it watches S00, builds transactions and
// sends them to the scoreboard. Coverage of the registers is collected here too.
//
// A write is complete when the response (B channel) is seen: by then the address
// and the data have arrived. The AW/W order is measured by the cycle in which VALID was first raised.
class axil_monitor extends uvm_monitor;

   `uvm_component_utils(axil_monitor)

   virtual interface axil_if vif;
   uvm_analysis_port #(axil_item) item_collected_port;

   int cycle = 0;

   bit          aw_prev, w_prev;
   int          aw_cycle, w_cycle;
   bit [5 : 0]  wr_addr, rd_addr;
   bit [31 : 0] wr_data;
   bit [3 : 0]  wr_strb;

   // --- coverage fields ---
   int unsigned img_w, img_h, tmp_w, tmp_h;  // last written dimensions
   bit          start;                       // bit 0 of the CTRL write
   bit          busy, done;                  // from the last STATUS read
   order_e      cov_order;

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

   // Every register write: AW/W order.
   covergroup cg_axil;
      option.per_instance = 1;
      cp_order : coverpoint cov_order;
   endgroup

   function new(string name = "axil_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
      cg_dims = new();
      cg_ctrl = new();
      cg_axil = new();
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_if", vif))
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
      axil_item it;

      if (vif.awvalid === 1'b1 && !aw_prev) aw_cycle = cycle;
      if (vif.wvalid  === 1'b1 && !w_prev)  w_cycle  = cycle;
      aw_prev = (vif.awvalid === 1'b1);
      w_prev  = (vif.wvalid  === 1'b1);

      if (vif.awvalid === 1'b1 && vif.awready === 1'b1)
         wr_addr = vif.awaddr;
      if (vif.wvalid === 1'b1 && vif.wready === 1'b1) begin
         wr_data = vif.wdata;
         wr_strb = vif.wstrb;
      end

      if (vif.bvalid === 1'b1 && vif.bready === 1'b1) begin
         it = axil_item::type_id::create("it");
         it.rw    = WRITE;
         it.addr  = wr_addr;
         it.data  = wr_data;
         it.strb  = wr_strb;
         it.resp  = vif.bresp;
         it.order = get_order();
         item_collected_port.write(it);

         cov_order = it.order;
         cg_axil.sample();

         if (it.addr == REG_IMG_W) img_w = it.data[7 : 0];
         if (it.addr == REG_IMG_H) img_h = it.data[7 : 0];
         if (it.addr == REG_TMP_W) tmp_w = it.data[7 : 0];
         if (it.addr == REG_TMP_H) tmp_h = it.data[7 : 0];
         if (it.addr == REG_CTRL) begin
            start = it.data[0];
            cg_ctrl.sample();
            if (start) cg_dims.sample();
         end
      end

      if (vif.arvalid === 1'b1 && vif.arready === 1'b1)
         rd_addr = vif.araddr;

      if (vif.rvalid === 1'b1 && vif.rready === 1'b1) begin
         it = axil_item::type_id::create("it");
         it.rw   = READ;
         it.addr = rd_addr;
         it.data = vif.rdata;
         it.resp = vif.rresp;
         item_collected_port.write(it);

         if (it.addr == REG_STATUS) begin
            done = it.data[0];
            busy = it.data[1];
         end
      end
   endfunction : collect

endclass : axil_monitor
