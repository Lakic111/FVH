// Driver -- drives S01, one burst at a time.
// On a write the address (AW) and data (W) channels run in two threads, so the
// item selects which channel starts first (order) and how many cycles later the other one starts (gap).
class axif_driver extends uvm_driver #(axif_item);

   `uvm_component_utils(axif_driver)

   virtual interface axif_if vif;

   function new(string name = "axif_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axif_if)::get(this, "", "axif_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction

   task run_phase(uvm_phase phase);
      reset_signals();
      @(posedge vif.rstn);
      @(posedge vif.clk);
      forever begin
         seq_item_port.get_next_item(req);
         if (req.rw == WRITE) write_burst(req);
         else                 read_burst(req);
         seq_item_port.item_done();
      end
   endtask : run_phase

   task reset_signals();
      vif.awvalid  <= 0;
      vif.wvalid   <= 0;
      vif.wlast    <= 0;
      vif.bready   <= 0;
      vif.arvalid  <= 0;
      vif.rready   <= 0;
      // fixed fields: ID 0, 4 bytes per beat, INCR burst
      vif.awid     <= 0;
      vif.awsize   <= 3'b010;
      vif.awburst  <= 2'b01;
      vif.awlock   <= 0;
      vif.awcache  <= 0;
      vif.awprot   <= 0;
      vif.awqos    <= 0;
      vif.awregion <= 0;
      vif.arid     <= 0;
      vif.arsize   <= 3'b010;
      vif.arburst  <= 2'b01;
      vif.arlock   <= 0;
      vif.arcache  <= 0;
      vif.arprot   <= 0;
      vif.arqos    <= 0;
      vif.arregion <= 0;
   endtask : reset_signals

   // --- write of one burst (len words) ---
   task write_burst(axif_item it);
      int unsigned aw_delay = 0;
      int unsigned w_delay  = 0;
      if (it.order == ORDER_AW_FIRST) w_delay  = it.gap;
      if (it.order == ORDER_W_FIRST)  aw_delay = it.gap;

      fork
         begin
            repeat (aw_delay) @(posedge vif.clk);
            vif.awaddr  <= it.addr;
            vif.awlen   <= it.len - 1;
            vif.awvalid <= 1;
            @(posedge vif.clk iff vif.awready === 1'b1);
            vif.awvalid <= 0;
         end
         begin
            repeat (w_delay) @(posedge vif.clk);
            for (int i = 0; i < it.len; i++) begin
               vif.wdata  <= it.data[i];
               vif.wstrb  <= it.strb;
               vif.wlast  <= (i == it.len - 1);
               vif.wvalid <= 1;
               @(posedge vif.clk iff vif.wready === 1'b1);
            end
            vif.wvalid <= 0;
            vif.wlast  <= 0;
         end
      join

      vif.bready <= 1;
      @(posedge vif.clk iff vif.bvalid === 1'b1);
      it.resp = vif.bresp;
      vif.bready <= 0;
   endtask : write_burst

   // --- read of one burst ---
   task read_burst(axif_item it);
      vif.araddr  <= it.addr;
      vif.arlen   <= it.len - 1;
      vif.arvalid <= 1;
      @(posedge vif.clk iff vif.arready === 1'b1);
      vif.arvalid <= 0;

      it.data = new[it.len];
      vif.rready <= 1;
      for (int i = 0; i < it.len; i++) begin
         @(posedge vif.clk iff vif.rvalid === 1'b1);
         it.data[i] = vif.rdata;
         it.resp    = vif.rresp;
      end
      vif.rready <= 0;
   endtask : read_burst

endclass : axif_driver
