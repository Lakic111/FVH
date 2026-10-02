// Drajver za S00 (AXI4-Lite). AW, W i B se vode kao nezavisne niti --
// popravljeni S00 nikad ne dize awready i wready u istom taktu.
class ncc_axil_driver extends uvm_driver #(ncc_reg_item);
  `uvm_component_utils(ncc_axil_driver)

  virtual axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W)) vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_lite_if #(.ADDR_W(S00_ADDR_W),
                                              .DATA_W(S00_DATA_W)))
          ::get(this, "", "axil_vif", vif))
      `uvm_fatal("NOVIF", "axil_vif nije nadjen u uvm_config_db")
  endfunction

  task run_phase(uvm_phase phase);
    idle();
    wait (vif.rstn === 1'b1);
    @(vif.mst_cb);

    forever begin
      seq_item_port.get_next_item(req);
      if (req.rw == REG_WRITE) drive_write(req);
      else                     drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task idle();
    vif.mst_cb.awvalid <= 1'b0;
    vif.mst_cb.wvalid  <= 1'b0;
    vif.mst_cb.bready  <= 1'b0;
    vif.mst_cb.arvalid <= 1'b0;
    vif.mst_cb.rready  <= 1'b0;
    vif.mst_cb.awprot  <= 3'b000;
    vif.mst_cb.arprot  <= 3'b000;
  endtask

  // --- upis ---------------------------------------------------------------
  task drive_write(ncc_reg_item it);
    int unsigned aw_kasnjenje, w_kasnjenje;

    case (it.order)
      ORDER_AW_FIRST: begin aw_kasnjenje = 0;      w_kasnjenje = it.gap; end
      ORDER_W_FIRST:  begin aw_kasnjenje = it.gap; w_kasnjenje = 0;      end
      default:        begin aw_kasnjenje = 0;      w_kasnjenje = 0;      end
    endcase

    fork
      begin : kanal_aw
        repeat (aw_kasnjenje) @(vif.mst_cb);
        vif.mst_cb.awaddr  <= it.addr;
        vif.mst_cb.awvalid <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.awready !== 1'b1);
        vif.mst_cb.awvalid <= 1'b0;
      end

      begin : kanal_w
        repeat (w_kasnjenje) @(vif.mst_cb);
        vif.mst_cb.wdata  <= it.data;
        vif.mst_cb.wstrb  <= it.strb;
        vif.mst_cb.wvalid <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.wready !== 1'b1);
        vif.mst_cb.wvalid <= 1'b0;
      end

      begin : kanal_b
        vif.mst_cb.bready <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.bvalid !== 1'b1);
        it.resp = vif.mst_cb.bresp;
        vif.mst_cb.bready <= 1'b0;
      end
    join
  endtask

  // --- citanje ------------------------------------------------------------
  task drive_read(ncc_reg_item it);
    fork
      begin : kanal_ar
        vif.mst_cb.araddr  <= it.addr;
        vif.mst_cb.arvalid <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.arready !== 1'b1);
        vif.mst_cb.arvalid <= 1'b0;
      end

      begin : kanal_r
        vif.mst_cb.rready <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.rvalid !== 1'b1);
        it.data = vif.mst_cb.rdata;
        it.resp = vif.mst_cb.rresp;
        vif.mst_cb.rready <= 1'b0;
      end
    join
  endtask

endclass : ncc_axil_driver
