// Sekvencijalna stavka, drajver, monitor, agent i sekvence za S00 (AXI4-Lite).
// AW, W i B su nezavisni kanali -- popravljeni S00 nikad ne dize awready i
// wready u istom taktu, pa drajver mora voditi kanale kao nezavisne niti.
package ncc_axil_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;

  typedef enum { REG_WRITE, REG_READ } reg_rw_e;

  // --------------------------------------------------------------------------
  // Sekvencijalna stavka
  // --------------------------------------------------------------------------
  class ncc_reg_item extends uvm_sequence_item;

    rand bit [S00_ADDR_W-1:0] addr;
    rand bit [S00_DATA_W-1:0] data;   // kod citanja: drajver upisuje procitano
    rand reg_rw_e             rw;
    rand aw_w_order_e         order;
    rand bit [3:0]            strb;
    rand int unsigned         gap;    // taktova izmedju pokretanja dva kanala

    bit [1:0] resp;                   // BRESP / RRESP, popunjava drajver

    constraint c_order  { order dist { ORDER_AW_FIRST := 2,
                                       ORDER_W_FIRST  := 2,
                                       ORDER_SIMUL    := 1 }; }

    constraint c_gap    { order == ORDER_SIMUL -> gap == 0;
                          order != ORDER_SIMUL -> gap inside {[1:4]}; }

    constraint c_strb   { strb == 4'hF; }

    // Meko: dozvoljava i scratch adresu (test T2) bez pada randomizacije.
    constraint c_addr   { soft addr inside { REG_IMG_W, REG_IMG_H, REG_TMP_W,
                                             REG_TMP_H, REG_CTRL, REG_STATUS }; }

    constraint c_status { addr == REG_STATUS -> rw == REG_READ; }

    `uvm_object_utils_begin(ncc_reg_item)
      `uvm_field_int (addr,  UVM_ALL_ON)
      `uvm_field_int (data,  UVM_ALL_ON)
      `uvm_field_enum(reg_rw_e,     rw,    UVM_ALL_ON)
      `uvm_field_enum(aw_w_order_e, order, UVM_ALL_ON)
      `uvm_field_int (strb,  UVM_ALL_ON)
      `uvm_field_int (gap,   UVM_ALL_ON)
      `uvm_field_int (resp,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ncc_reg_item");
      super.new(name);
    endfunction

  endclass : ncc_reg_item

  // --------------------------------------------------------------------------
  typedef uvm_sequencer #(ncc_reg_item) ncc_axil_sequencer;

  // --------------------------------------------------------------------------
  // Drajver
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Monitor -- pasivan, uzorkuje iskljucivo kroz mon_cb; redosled se meri po
  // postavljanju VALID-a, ne po rukovanju (rukovanje na W uvek dolazi posle AW).
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Konfiguracija agenta
  // --------------------------------------------------------------------------
  class ncc_axil_agent_config extends uvm_object;
    `uvm_object_utils(ncc_axil_agent_config)

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit [S00_ADDR_W-1:0]    base_addr = '0;
    string                  vif_name  = "axil_vif";

    function new(string name = "ncc_axil_agent_config");
      super.new(name);
    endfunction
  endclass : ncc_axil_agent_config

  // --------------------------------------------------------------------------
  // Agent
  // --------------------------------------------------------------------------
  class ncc_axil_agent extends uvm_agent;
    `uvm_component_utils(ncc_axil_agent)

    ncc_axil_agent_config cfg;
    ncc_axil_sequencer    sqr;
    ncc_axil_driver       drv;
    ncc_axil_monitor      mon;

    uvm_analysis_port #(ncc_reg_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(ncc_axil_agent_config)::get(this, "", "cfg", cfg)) begin
        cfg = ncc_axil_agent_config::type_id::create("cfg");
        `uvm_info("CFG", "nema konfiguracije u bazi, koristi se podrazumevana (UVM_ACTIVE)",
                  UVM_LOW)
      end

      mon = ncc_axil_monitor::type_id::create("mon", this);

      if (cfg.is_active == UVM_ACTIVE) begin
        sqr = ncc_axil_sequencer::type_id::create("sqr", this);
        drv = ncc_axil_driver   ::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(ap);
      if (cfg.is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

  endclass : ncc_axil_agent

  // --------------------------------------------------------------------------
  // Sekvence
  // --------------------------------------------------------------------------
  class ncc_axil_base_seq extends uvm_sequence #(ncc_reg_item);
    `uvm_object_utils(ncc_axil_base_seq)

    function new(string name = "ncc_axil_base_seq");
      super.new(name);
    endfunction

    task upisi(bit [S00_ADDR_W-1:0] a, bit [S00_DATA_W-1:0] d,
               aw_w_order_e o = ORDER_AW_FIRST, int unsigned g = 1);
      ncc_reg_item it = ncc_reg_item::type_id::create("it");
      bit ok;
      start_item(it);
      if (o == ORDER_SIMUL)
        ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                   order == o; };
      else
        ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                   order == o; gap == g; };
      if (!ok) `uvm_fatal("RAND", "randomizacija upisa nije uspela")
      finish_item(it);
    endtask

    task procitaj(bit [S00_ADDR_W-1:0] a, output bit [S00_DATA_W-1:0] d);
      ncc_reg_item it = ncc_reg_item::type_id::create("it");
      start_item(it);
      if (!it.randomize() with { addr == a; rw == REG_READ; })
        `uvm_fatal("RAND", "randomizacija citanja nije uspela")
      finish_item(it);
      d = it.data;
    endtask
  endclass : ncc_axil_base_seq

  // Direktna sekvenca: upis pa citanje istog registra, u sva tri redosleda.
  class ncc_reg_rw_seq extends ncc_axil_base_seq;
    `uvm_object_utils(ncc_reg_rw_seq)

    int unsigned gresaka = 0;

    function new(string name = "ncc_reg_rw_seq");
      super.new(name);
    endfunction

    task proveri(string opis, bit [S00_ADDR_W-1:0] a,
                 bit [S00_DATA_W-1:0] ocekivano, aw_w_order_e o);
      bit [S00_DATA_W-1:0] procitano;
      upisi(a, ocekivano, o);
      procitaj(a, procitano);
      if (procitano !== ocekivano) begin
        `uvm_error("RW", $sformatf("%s (%s): adresa 0x%02x, ocekivano 0x%08x, dobijeno 0x%08x",
                                   opis, o.name(), a, ocekivano, procitano))
        gresaka++;
      end else begin
        `uvm_info("RW", $sformatf("%s (%s): adresa 0x%02x = 0x%08x",
                                  opis, o.name(), a, procitano), UVM_LOW)
      end
    endtask

    task body();
      proveri("REG_IMG_W", REG_IMG_W, 32'd90, ORDER_AW_FIRST);
      proveri("REG_IMG_W", REG_IMG_W, 32'd45, ORDER_W_FIRST);
      proveri("REG_IMG_W", REG_IMG_W, 32'd30, ORDER_SIMUL);

      proveri("REG_IMG_H", REG_IMG_H, 32'd90, ORDER_W_FIRST);
      proveri("REG_TMP_W", REG_TMP_W, 32'd25, ORDER_SIMUL);
      proveri("REG_TMP_H", REG_TMP_H, 32'd15, ORDER_AW_FIRST);

      proveri("REG_IMG_W puna rec", REG_IMG_W, 32'hDEAD_BE5A, ORDER_W_FIRST);

      if (gresaka == 0)
        `uvm_info("RW", "svi registri: upisano jednako procitanom, sva tri redosleda", UVM_LOW)
    endtask
  endclass : ncc_reg_rw_seq

endpackage : ncc_axil_pkg
