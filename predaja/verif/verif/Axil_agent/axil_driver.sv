// Driver -- drives S00, one transaction at a time.
// On a write the address (AW) and data (W) channels run in two threads, so the
// item selects which channel starts first (order) and how many cycles later the other one starts (gap).
class axil_driver extends uvm_driver #(axil_item);

   `uvm_component_utils(axil_driver)

   virtual interface axil_if vif;

   function new(string name = "axil_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction

   task run_phase(uvm_phase phase);
      reset_signals();
      @(posedge vif.rstn);
      @(posedge vif.clk);
      forever begin
         seq_item_port.get_next_item(req);
         if (req.rw == WRITE) write_reg(req);
         else                 read_reg(req);
         seq_item_port.item_done();
      end
   endtask : run_phase

   task reset_signals();
      vif.awvalid <= 0;
      vif.wvalid  <= 0;
      vif.bready  <= 0;
      vif.arvalid <= 0;
      vif.rready  <= 0;
      vif.awprot  <= 0;
      vif.arprot  <= 0;
   endtask : reset_signals

   // --- register write ---
   task write_reg(axil_item it);
      int unsigned aw_delay = 0;
      int unsigned w_delay  = 0;
      if (it.order == ORDER_AW_FIRST) w_delay  = it.gap;
      if (it.order == ORDER_W_FIRST)  aw_delay = it.gap;

      fork
         begin
            repeat (aw_delay) @(posedge vif.clk);
            vif.awaddr  <= it.addr;
            vif.awvalid <= 1;
            @(posedge vif.clk iff vif.awready === 1'b1);
            vif.awvalid <= 0;
         end
         begin
            repeat (w_delay) @(posedge vif.clk);
            vif.wdata  <= it.data;
            vif.wstrb  <= it.strb;
            vif.wvalid <= 1;
            @(posedge vif.clk iff vif.wready === 1'b1);
            vif.wvalid <= 0;
         end
      join

      vif.bready <= 1;
      @(posedge vif.clk iff vif.bvalid === 1'b1);
      it.resp = vif.bresp;
      vif.bready <= 0;
   endtask : write_reg

   // --- register read ---
   task read_reg(axil_item it);
      vif.araddr  <= it.addr;
      vif.arvalid <= 1;
      @(posedge vif.clk iff vif.arready === 1'b1);
      vif.arvalid <= 0;

      vif.rready <= 1;
      @(posedge vif.clk iff vif.rvalid === 1'b1);
      it.data = vif.rdata;
      it.resp = vif.rresp;
      vif.rready <= 0;
   endtask : read_reg

endclass : axil_driver
