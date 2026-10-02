// Drajver za S01 (AXI4-Full, paketni prenos). Isti dvofazni upisni automat
// kao S00, uz vise beat-ova po burst-u; W kanal se zavrsava WLAST-om.
class ncc_axif_driver extends uvm_driver #(ncc_mem_item);
  `uvm_component_utils(ncc_axif_driver)

  virtual axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W),
                        .DATA_W(S01_DATA_W)) vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_full_if #(.ID_W(S01_ID_W),
                                              .ADDR_W(S01_ADDR_W),
                                              .DATA_W(S01_DATA_W)))
          ::get(this, "", "axif_vif", vif))
      `uvm_fatal("NOVIF", "axif_vif nije nadjen u uvm_config_db")
  endfunction

  task run_phase(uvm_phase phase);
    idle();
    wait (vif.rstn === 1'b1);
    @(vif.mst_cb);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.rw == MEM_WRITE) drive_write(req);
      else                     drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task idle();
    vif.mst_cb.awvalid  <= 1'b0;
    vif.mst_cb.wvalid   <= 1'b0;
    vif.mst_cb.wlast    <= 1'b0;
    vif.mst_cb.bready   <= 1'b0;
    vif.mst_cb.arvalid  <= 1'b0;
    vif.mst_cb.rready   <= 1'b0;
    vif.mst_cb.awid     <= '0;
    vif.mst_cb.awsize   <= 3'b010;   // 4 bajta po beat-u
    vif.mst_cb.awburst  <= 2'b01;    // INCR
    vif.mst_cb.awlock   <= 1'b0;
    vif.mst_cb.awcache  <= 4'b0000;
    vif.mst_cb.awprot   <= 3'b000;
    vif.mst_cb.awqos    <= 4'b0000;
    vif.mst_cb.awregion <= 4'b0000;
    vif.mst_cb.arid     <= '0;
    vif.mst_cb.arsize   <= 3'b010;
    vif.mst_cb.arburst  <= 2'b01;
    vif.mst_cb.arlock   <= 1'b0;
    vif.mst_cb.arcache  <= 4'b0000;
    vif.mst_cb.arprot   <= 3'b000;
    vif.mst_cb.arqos    <= 4'b0000;
    vif.mst_cb.arregion <= 4'b0000;
  endtask

  task drive_write(ncc_mem_item it);
    int unsigned aw_kasnjenje, w_kasnjenje;

    case (it.order)
      ORDER_AW_FIRST: begin aw_kasnjenje = 0;      w_kasnjenje = it.gap; end
      ORDER_W_FIRST:  begin aw_kasnjenje = it.gap; w_kasnjenje = 0;      end
      default:        begin aw_kasnjenje = 0;      w_kasnjenje = 0;      end
    endcase

    fork
      begin : kanal_aw
        repeat (aw_kasnjenje) @(vif.mst_cb);
        vif.mst_cb.awaddr  <= it.puna_adresa();
        vif.mst_cb.awlen   <= it.len - 1;
        vif.mst_cb.awvalid <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.awready !== 1'b1);
        vif.mst_cb.awvalid <= 1'b0;
      end

      begin : kanal_w
        repeat (w_kasnjenje) @(vif.mst_cb);
        for (int i = 0; i < it.len; i++) begin
          vif.mst_cb.wdata  <= it.data[i];
          vif.mst_cb.wstrb  <= it.strb;
          vif.mst_cb.wlast  <= (i == it.len - 1);
          vif.mst_cb.wvalid <= 1'b1;
          do @(vif.mst_cb); while (vif.mst_cb.wready !== 1'b1);
        end
        vif.mst_cb.wvalid <= 1'b0;
        vif.mst_cb.wlast  <= 1'b0;
      end

      begin : kanal_b
        vif.mst_cb.bready <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.bvalid !== 1'b1);
        it.resp = vif.mst_cb.bresp;
        vif.mst_cb.bready <= 1'b0;
      end
    join
  endtask

  task drive_read(ncc_mem_item it);
    int unsigned i = 0;
    it.data = new[it.len];
    fork
      begin : kanal_ar
        vif.mst_cb.araddr  <= it.puna_adresa();
        vif.mst_cb.arlen   <= it.len - 1;
        vif.mst_cb.arvalid <= 1'b1;
        do @(vif.mst_cb); while (vif.mst_cb.arready !== 1'b1);
        vif.mst_cb.arvalid <= 1'b0;
      end

      begin : kanal_r
        vif.mst_cb.rready <= 1'b1;
        while (i < it.len) begin
          @(vif.mst_cb);
          if (vif.mst_cb.rvalid === 1'b1) begin
            it.data[i] = vif.mst_cb.rdata;
            it.resp    = vif.mst_cb.rresp;
            i++;
          end
        end
        vif.mst_cb.rready <= 1'b0;
      end
    join
  endtask

endclass : ncc_axif_driver
