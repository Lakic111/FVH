// Driver -- drives both buses, one transaction at a time.
// On a write the address (AW) and data (W) channels run in two threads, so the
// item selects which channel starts first (order) and how many cycles later the other one starts (gap).
class ncc_driver extends uvm_driver #(ncc_item);

   `uvm_component_utils(ncc_driver)

   virtual interface ncc_if vif;

   function new(string name = "ncc_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ncc_if)::get(this, "", "ncc_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction

   task run_phase(uvm_phase phase);
      reset_signals();
      @(posedge vif.rstn);
      @(posedge vif.clk);
      forever begin
         seq_item_port.get_next_item(req);
         if (req.bus == BUS_S00 && req.rw == WRITE)    s00_write(req);
         if (req.bus == BUS_S00 && req.rw == READ) s00_read(req);
         if (req.bus == BUS_S01 && req.rw == WRITE)    s01_write(req);
         if (req.bus == BUS_S01 && req.rw == READ) s01_read(req);
         seq_item_port.item_done();
      end
   endtask : run_phase

   task reset_signals();
      vif.s00_awvalid <= 0;
      vif.s00_wvalid  <= 0;
      vif.s00_bready  <= 0;
      vif.s00_arvalid <= 0;
      vif.s00_rready  <= 0;
      vif.s00_awprot  <= 0;
      vif.s00_arprot  <= 0;

      vif.s01_awvalid  <= 0;
      vif.s01_wvalid   <= 0;
      vif.s01_wlast    <= 0;
      vif.s01_bready   <= 0;
      vif.s01_arvalid  <= 0;
      vif.s01_rready   <= 0;
      // fixed fields: ID 0, 4 bytes per beat, INCR burst
      vif.s01_awid     <= 0;
      vif.s01_awsize   <= 3'b010;
      vif.s01_awburst  <= 2'b01;
      vif.s01_awlock   <= 0;
      vif.s01_awcache  <= 0;
      vif.s01_awprot   <= 0;
      vif.s01_awqos    <= 0;
      vif.s01_awregion <= 0;
      vif.s01_arid     <= 0;
      vif.s01_arsize   <= 3'b010;
      vif.s01_arburst  <= 2'b01;
      vif.s01_arlock   <= 0;
      vif.s01_arcache  <= 0;
      vif.s01_arprot   <= 0;
      vif.s01_arqos    <= 0;
      vif.s01_arregion <= 0;
   endtask : reset_signals

   // --- S00, register write ---
   task s00_write(ncc_item it);
      int unsigned aw_delay = 0;
      int unsigned w_delay  = 0;
      if (it.order == ORDER_AW_FIRST) w_delay  = it.gap;
      if (it.order == ORDER_W_FIRST)  aw_delay = it.gap;

      fork
         begin
            repeat (aw_delay) @(posedge vif.clk);
            vif.s00_awaddr  <= it.addr[5 : 0];
            vif.s00_awvalid <= 1;
            @(posedge vif.clk iff vif.s00_awready === 1'b1);
            vif.s00_awvalid <= 0;
         end
         begin
            repeat (w_delay) @(posedge vif.clk);
            vif.s00_wdata  <= it.data[0];
            vif.s00_wstrb  <= it.strb;
            vif.s00_wvalid <= 1;
            @(posedge vif.clk iff vif.s00_wready === 1'b1);
            vif.s00_wvalid <= 0;
         end
      join

      vif.s00_bready <= 1;
      @(posedge vif.clk iff vif.s00_bvalid === 1'b1);
      it.resp = vif.s00_bresp;
      vif.s00_bready <= 0;
   endtask : s00_write

   // --- S00, register read ---
   task s00_read(ncc_item it);
      vif.s00_araddr  <= it.addr[5 : 0];
      vif.s00_arvalid <= 1;
      @(posedge vif.clk iff vif.s00_arready === 1'b1);
      vif.s00_arvalid <= 0;

      vif.s00_rready <= 1;
      @(posedge vif.clk iff vif.s00_rvalid === 1'b1);
      it.data    = new[1];
      it.data[0] = vif.s00_rdata;
      it.resp    = vif.s00_rresp;
      vif.s00_rready <= 0;
   endtask : s00_read

   // --- S01, write of one burst (len words) ---
   task s01_write(ncc_item it);
      int unsigned aw_delay = 0;
      int unsigned w_delay  = 0;
      if (it.order == ORDER_AW_FIRST) w_delay  = it.gap;
      if (it.order == ORDER_W_FIRST)  aw_delay = it.gap;

      fork
         begin
            repeat (aw_delay) @(posedge vif.clk);
            vif.s01_awaddr  <= it.addr;
            vif.s01_awlen   <= it.len - 1;
            vif.s01_awvalid <= 1;
            @(posedge vif.clk iff vif.s01_awready === 1'b1);
            vif.s01_awvalid <= 0;
         end
         begin
            repeat (w_delay) @(posedge vif.clk);
            for (int i = 0; i < it.len; i++) begin
               vif.s01_wdata  <= it.data[i];
               vif.s01_wstrb  <= it.strb;
               vif.s01_wlast  <= (i == it.len - 1);
               vif.s01_wvalid <= 1;
               @(posedge vif.clk iff vif.s01_wready === 1'b1);
            end
            vif.s01_wvalid <= 0;
            vif.s01_wlast  <= 0;
         end
      join

      vif.s01_bready <= 1;
      @(posedge vif.clk iff vif.s01_bvalid === 1'b1);
      it.resp = vif.s01_bresp;
      vif.s01_bready <= 0;
   endtask : s01_write

   // --- S01, read of one burst ---
   task s01_read(ncc_item it);
      vif.s01_araddr  <= it.addr;
      vif.s01_arlen   <= it.len - 1;
      vif.s01_arvalid <= 1;
      @(posedge vif.clk iff vif.s01_arready === 1'b1);
      vif.s01_arvalid <= 0;

      it.data = new[it.len];
      vif.s01_rready <= 1;
      for (int i = 0; i < it.len; i++) begin
         @(posedge vif.clk iff vif.s01_rvalid === 1'b1);
         it.data[i] = vif.s01_rdata;
         it.resp    = vif.s01_rresp;
      end
      vif.s01_rready <= 0;
   endtask : s01_read

endclass : ncc_driver
