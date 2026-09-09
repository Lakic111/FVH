// Stavka, drajver, monitor i agent za S01 (AXI4-Full, paketni prenos).
// Isti dvofazni upisni automat i redosled-po-VALID-u kao S00, uz vise
// beat-ova po burst-u; W kanal se zavrsava WLAST-om.
package ncc_axif_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;

  typedef enum { MEM_WRITE, MEM_READ } mem_rw_e;

  // --------------------------------------------------------------------------
  // Sekvencijalna stavka
  // --------------------------------------------------------------------------
  class ncc_mem_item extends uvm_sequence_item;

    rand region_e          region;
    rand bit [12:0]        word;      // indeks reci unutar regiona (addr[14:2])
    rand int unsigned      len;       // broj beat-ova = AWLEN + 1
    rand bit [31:0]        data[];    // len elemenata
    rand bit [3:0]         strb;
    rand mem_rw_e          rw;
    rand aw_w_order_e      order;
    rand int unsigned      gap;

    bit [1:0] resp;

    constraint c_len   { len inside {[1:256]};
                         data.size() == len; }

    constraint c_4k    { ((word * 4) % 4096) + (len * 4) <= 4096; }

    // Ogranicava se adresni prostor regiona (13 bita), ne dubina memorije --
    // razmak od TMP_WORDS reci mora ostati testabilan (aliasing, P2).
    constraint c_opseg { word + len <= 8192; }

    constraint c_order { order dist { ORDER_AW_FIRST := 2,
                                      ORDER_W_FIRST  := 2,
                                      ORDER_SIMUL    := 1 }; }
    constraint c_gap   { order == ORDER_SIMUL -> gap == 0;
                         order != ORDER_SIMUL -> gap inside {[1:4]}; }
    constraint c_strb  { soft strb == 4'hF; }

    `uvm_object_utils_begin(ncc_mem_item)
      `uvm_field_enum(region_e,     region, UVM_ALL_ON)
      `uvm_field_int (word,   UVM_ALL_ON)
      `uvm_field_int (len,    UVM_ALL_ON)
      `uvm_field_array_int(data, UVM_ALL_ON)
      `uvm_field_int (strb,   UVM_ALL_ON)
      `uvm_field_enum(mem_rw_e,     rw,     UVM_ALL_ON)
      `uvm_field_enum(aw_w_order_e, order,  UVM_ALL_ON)
      `uvm_field_int (gap,    UVM_ALL_ON)
      `uvm_field_int (resp,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ncc_mem_item");
      super.new(name);
    endfunction

    // Puna bajtska adresa: region u bitovima 16:15, rec u 14:2.
    function bit [S01_ADDR_W-1:0] puna_adresa();
      return {region, word, 2'b00};
    endfunction

  endclass : ncc_mem_item

  // --------------------------------------------------------------------------
  typedef uvm_sequencer #(ncc_mem_item) ncc_axif_sequencer;

  // --------------------------------------------------------------------------
  // Drajver
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Monitor
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Konfiguracija i agent
  // --------------------------------------------------------------------------
  class ncc_axif_agent_config extends uvm_object;
    `uvm_object_utils(ncc_axif_agent_config)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit [S01_ADDR_W-1:0]    base_addr = '0;
    function new(string name = "ncc_axif_agent_config");
      super.new(name);
    endfunction
  endclass : ncc_axif_agent_config

  class ncc_axif_agent extends uvm_agent;
    `uvm_component_utils(ncc_axif_agent)

    ncc_axif_agent_config cfg;
    ncc_axif_sequencer    sqr;
    ncc_axif_driver       drv;
    ncc_axif_monitor      mon;
    uvm_analysis_port #(ncc_mem_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(ncc_axif_agent_config)::get(this, "", "cfg", cfg))
        cfg = ncc_axif_agent_config::type_id::create("cfg");

      mon = ncc_axif_monitor::type_id::create("mon", this);
      if (cfg.is_active == UVM_ACTIVE) begin
        sqr = ncc_axif_sequencer::type_id::create("sqr", this);
        drv = ncc_axif_driver   ::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(ap);
      if (cfg.is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

  endclass : ncc_axif_agent

  // --------------------------------------------------------------------------
  // Sekvence
  // --------------------------------------------------------------------------
  class ncc_axif_base_seq extends uvm_sequence #(ncc_mem_item);
    `uvm_object_utils(ncc_axif_base_seq)

    function new(string name = "ncc_axif_base_seq");
      super.new(name);
    endfunction

    // Smer svakog argumenta naveden izricito (SV nasledjuje smer od prethodnog).
    task upisi_blok(input region_e r, input bit [12:0] w,
                    const ref bit [31:0] d[],
                    input aw_w_order_e o = ORDER_AW_FIRST,
                    input int unsigned g = 1);
      ncc_mem_item it = ncc_mem_item::type_id::create("it");
      bit ok;
      start_item(it);
      if (o == ORDER_SIMUL)
        ok = it.randomize() with { region == r; word == w; len == d.size();
                                   rw == MEM_WRITE; order == o; };
      else
        ok = it.randomize() with { region == r; word == w; len == d.size();
                                   rw == MEM_WRITE; order == o; gap == g; };
      if (!ok) `uvm_fatal("RAND", "randomizacija upisa u S01 nije uspela")
      foreach (d[i]) it.data[i] = d[i];
      finish_item(it);
    endtask

    task procitaj_blok(input region_e r, input bit [12:0] w,
                       input int unsigned n, ref bit [31:0] d[]);
      ncc_mem_item it = ncc_mem_item::type_id::create("it");
      start_item(it);
      if (!it.randomize() with { region == r; word == w; len == n;
                                 rw == MEM_READ; order == ORDER_AW_FIRST; })
        `uvm_fatal("RAND", "randomizacija citanja iz S01 nije uspela")
      finish_item(it);
      d = new[it.data.size()];
      foreach (it.data[i]) d[i] = it.data[i];
    endtask
  endclass : ncc_axif_base_seq

  // Upis bloka piksela i citanje istih vrednosti nazad, sva tri redosleda.
  class ncc_mem_blok_seq extends ncc_axif_base_seq;
    `uvm_object_utils(ncc_mem_blok_seq)

    int unsigned gresaka = 0;

    function new(string name = "ncc_mem_blok_seq");
      super.new(name);
    endfunction

    task proveri_blok(string opis, region_e r, bit [12:0] w, int unsigned n,
                      aw_w_order_e o);
      bit [31:0] poslato[], vraceno[];
      poslato = new[n];
      foreach (poslato[i]) poslato[i] = (w + i) & 32'hFF;

      upisi_blok(r, w, poslato, o);
      procitaj_blok(r, w, n, vraceno);

      if (vraceno.size() != n) begin
        `uvm_error("BLOK", $sformatf("%s: vraceno %0d beat-ova, ocekivano %0d",
                                     opis, vraceno.size(), n))
        gresaka++;
        return;
      end

      foreach (poslato[i]) begin
        bit [31:0] ocekivano = (r == REGION_RESULT) ? poslato[i]
                                                    : (poslato[i] & 32'hFF);
        if (vraceno[i] !== ocekivano) begin
          `uvm_error("BLOK", $sformatf(
            "%s (%s): rec %0d, ocekivano 0x%08x, dobijeno 0x%08x",
            opis, o.name(), w + i, ocekivano, vraceno[i]))
          gresaka++;
        end
      end

      if (gresaka == 0)
        `uvm_info("BLOK", $sformatf("%s (%s): %0d beat-ova, upisano jednako procitanom",
                                    opis, o.name(), n), UVM_LOW)
    endtask

    task body();
      proveri_blok("slika, 1 beat",   REGION_IMG,  13'd0,   1,  ORDER_AW_FIRST);
      proveri_blok("slika, 2 beata",  REGION_IMG,  13'd16,  2,  ORDER_W_FIRST);
      proveri_blok("slika, 3 beata",  REGION_IMG,  13'd32,  3,  ORDER_SIMUL);
      proveri_blok("slika, 16 beata", REGION_IMG,  13'd64,  16, ORDER_W_FIRST);
      proveri_blok("sablon, 8 beata", REGION_TMP,  13'd0,   8,  ORDER_AW_FIRST);
      proveri_blok("sablon, 16 beata",REGION_TMP,  13'd128, 16, ORDER_SIMUL);

      if (gresaka == 0)
        `uvm_info("BLOK", "svi blokovi: upisano jednako procitanom", UVM_LOW)
    endtask
  endclass : ncc_mem_blok_seq

endpackage : ncc_axif_pkg
