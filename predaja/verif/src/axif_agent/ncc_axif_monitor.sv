// Monitor za S01 -- pasivan, sklapa burst-ove i meri redosled AW/W.
class ncc_axif_monitor extends uvm_monitor;
  `uvm_component_utils(ncc_axif_monitor)

  virtual axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W),
                        .DATA_W(S01_DATA_W)) vif;
  uvm_analysis_port #(ncc_mem_item) ap;

  typedef struct { bit [S01_ADDR_W-1:0] addr; int unsigned len; time t; } adr_zapis_t;

  protected adr_zapis_t aw_q[$];
  protected adr_zapis_t ar_q[$];
  protected bit [31:0]  w_buf[$];
  protected bit [3:0]   w_strb_buf[$];
  protected time        w_t;
  protected bit [31:0]  r_buf[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
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
        aw_q.push_back('{addr: vif.mon_cb.awaddr,
                         len:  vif.mon_cb.awlen + 1,
                         t:    t_postavljen});
    end
  endtask

  // Trenutak postavljanja se pamti samo za PRVI beat -- odredjuje redosled.
  task prati_w();
    bit prethodni = 1'b0;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.wvalid === 1'b1 && !prethodni && w_buf.size() == 0)
        w_t = $time;
      prethodni = (vif.mon_cb.wvalid === 1'b1);
      if (vif.mon_cb.wvalid === 1'b1 && vif.mon_cb.wready === 1'b1) begin
        w_buf.push_back(vif.mon_cb.wdata);
        w_strb_buf.push_back(vif.mon_cb.wstrb);
      end
    end
  endtask

  task prati_b();
    ncc_mem_item it;
    adr_zapis_t  aw;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1) begin
        if (aw_q.size() == 0) begin
          `uvm_error("MON", "odgovor B bez AW -- prekrsen AXI protokol")
          continue;
        end
        aw = aw_q.pop_front();
        if (w_buf.size() != aw.len) begin
          `uvm_error("MON", $sformatf(
            "burst na 0x%05x: AWLEN trazi %0d beat-ova, vidjeno %0d",
            aw.addr, aw.len, w_buf.size()))
        end

        it = ncc_mem_item::type_id::create("mon_upis");
        it.region = region_e'(aw.addr[16:15]);
        it.word   = aw.addr[14:2];
        it.len    = w_buf.size();
        it.data   = new[w_buf.size()];
        foreach (w_buf[i]) it.data[i] = w_buf[i];
        it.rw     = MEM_WRITE;
        it.resp   = vif.mon_cb.bresp;
        it.strb   = w_strb_buf.size() ? w_strb_buf[0] : 4'hF;
        foreach (w_strb_buf[i])
          if (w_strb_buf[i] !== it.strb)
            `uvm_warning("MON", $sformatf(
              "burst na 0x%05x ima razlicit WSTRB po beat-ovima (beat %0d)",
              aw.addr, i))
        it.order  = (aw.t < w_t) ? ORDER_AW_FIRST :
                    (aw.t > w_t) ? ORDER_W_FIRST  : ORDER_SIMUL;
        w_buf.delete();
        w_strb_buf.delete();

        `uvm_info("MON", $sformatf("upis  %s rec %0d, %0d beat-ova (%s)",
                                   it.region.name(), it.word, it.len,
                                   it.order.name()), UVM_HIGH)
        ap.write(it);
      end
    end
  endtask

  task prati_ar();
    time t_postavljen = 0;
    bit  prethodni    = 1'b0;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.arvalid === 1'b1 && !prethodni) t_postavljen = $time;
      prethodni = (vif.mon_cb.arvalid === 1'b1);
      if (vif.mon_cb.arvalid === 1'b1 && vif.mon_cb.arready === 1'b1)
        ar_q.push_back('{addr: vif.mon_cb.araddr,
                         len:  vif.mon_cb.arlen + 1,
                         t:    t_postavljen});
    end
  endtask

  task prati_r();
    ncc_mem_item it;
    adr_zapis_t  ar;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rvalid === 1'b1 && vif.mon_cb.rready === 1'b1) begin
        r_buf.push_back(vif.mon_cb.rdata);
        if (vif.mon_cb.rlast === 1'b1) begin
          if (ar_q.size() == 0) begin
            `uvm_error("MON", "podatak R bez AR -- prekrsen AXI protokol")
            r_buf.delete();
            continue;
          end
          ar = ar_q.pop_front();

          it = ncc_mem_item::type_id::create("mon_citanje");
          it.region = region_e'(ar.addr[16:15]);
          it.word   = ar.addr[14:2];
          it.len    = r_buf.size();
          it.data   = new[r_buf.size()];
          foreach (r_buf[i]) it.data[i] = r_buf[i];
          it.rw     = MEM_READ;
          it.resp   = vif.mon_cb.rresp;
          it.order  = ORDER_AW_FIRST;
          r_buf.delete();

          `uvm_info("MON", $sformatf("citanje %s rec %0d, %0d beat-ova",
                                     it.region.name(), it.word, it.len), UVM_HIGH)
          ap.write(it);
        end
      end
    end
  endtask

endclass : ncc_axif_monitor
