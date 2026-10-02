// Monitor za S00 -- pasivan, uzorkuje iskljucivo kroz mon_cb; redosled se meri po
// postavljanju VALID-a, ne po rukovanju (rukovanje na W uvek dolazi posle AW).
class ncc_axil_monitor extends uvm_monitor;
  `uvm_component_utils(ncc_axil_monitor)

  virtual axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W)) vif;
  uvm_analysis_port #(ncc_reg_item) ap;

  typedef struct { bit [S00_ADDR_W-1:0] addr; time t; } aw_zapis_t;
  typedef struct { bit [S00_DATA_W-1:0] data; bit [3:0] strb; time t; } w_zapis_t;

  protected aw_zapis_t aw_q[$];
  protected w_zapis_t  w_q[$];
  protected aw_zapis_t ar_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_lite_if #(.ADDR_W(S00_ADDR_W),
                                              .DATA_W(S00_DATA_W)))
          ::get(this, "", "axil_vif", vif))
      `uvm_fatal("NOVIF", "axil_vif nije nadjen u uvm_config_db")
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.rstn === 1'b1);
    fork
      prati_aw();
      prati_w();
      prati_b();
      prati_ar();
      prati_r();
    join
  endtask

  task prati_aw();
    time t_postavljen = 0;
    bit  prethodni    = 1'b0;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.awvalid === 1'b1 && !prethodni) t_postavljen = $time;
      prethodni = (vif.mon_cb.awvalid === 1'b1);
      if (vif.mon_cb.awvalid === 1'b1 && vif.mon_cb.awready === 1'b1)
        aw_q.push_back('{addr: vif.mon_cb.awaddr, t: t_postavljen});
    end
  endtask

  task prati_w();
    time t_postavljen = 0;
    bit  prethodni    = 1'b0;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.wvalid === 1'b1 && !prethodni) t_postavljen = $time;
      prethodni = (vif.mon_cb.wvalid === 1'b1);
      if (vif.mon_cb.wvalid === 1'b1 && vif.mon_cb.wready === 1'b1)
        w_q.push_back('{data: vif.mon_cb.wdata, strb: vif.mon_cb.wstrb,
                        t: t_postavljen});
    end
  endtask

  // Sklapanje upisa na rukovanju kanala B, gde su adresa i podatak zajemceni.
  task prati_b();
    ncc_reg_item it;
    aw_zapis_t aw;
    w_zapis_t  w;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1) begin
        if (aw_q.size() == 0 || w_q.size() == 0) begin
          `uvm_error("MON", $sformatf(
            "odgovor B bez para AW/W (aw_q=%0d w_q=%0d) -- prekrsen AXI protokol",
            aw_q.size(), w_q.size()))
          continue;
        end
        aw = aw_q.pop_front();
        w  = w_q.pop_front();

        it = ncc_reg_item::type_id::create("mon_upis");
        it.addr = aw.addr;
        it.data = w.data;
        it.strb = w.strb;
        it.rw   = REG_WRITE;
        it.resp = vif.mon_cb.bresp;
        it.order = (aw.t <  w.t) ? ORDER_AW_FIRST :
                   (aw.t >  w.t) ? ORDER_W_FIRST  : ORDER_SIMUL;
        it.gap  = 0;

        `uvm_info("MON", $sformatf("upis  adresa 0x%02x = 0x%08x (%s)",
                                   it.addr, it.data, it.order.name()), UVM_HIGH)
        ap.write(it);
      end
    end
  endtask

  task prati_ar();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.arvalid === 1'b1 && vif.mon_cb.arready === 1'b1)
        ar_q.push_back('{addr: vif.mon_cb.araddr, t: $time});
    end
  endtask

  task prati_r();
    ncc_reg_item it;
    aw_zapis_t ar;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rvalid === 1'b1 && vif.mon_cb.rready === 1'b1) begin
        if (ar_q.size() == 0) begin
          `uvm_error("MON", "podatak R bez prethodnog AR -- prekrsen AXI protokol")
          continue;
        end
        ar = ar_q.pop_front();

        it = ncc_reg_item::type_id::create("mon_citanje");
        it.addr  = ar.addr;
        it.data  = vif.mon_cb.rdata;
        it.rw    = REG_READ;
        it.resp  = vif.mon_cb.rresp;
        it.order = ORDER_AW_FIRST;   // citanje nema W kanal
        it.strb  = 4'h0;
        it.gap   = 0;

        `uvm_info("MON", $sformatf("citanje adresa 0x%02x = 0x%08x",
                                   it.addr, it.data), UVM_HIGH)
        ap.write(it);
      end
    end
  endtask

endclass : ncc_axil_monitor
