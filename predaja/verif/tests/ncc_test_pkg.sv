// Svi testovi.
//
//   ncc_vif_test         virtuelni interfejsi stizu kroz uvm_config_db, DUT miruje
//   ncc_axil_smoke_test  S00: upis i citanje registara, sva tri AW/W redosleda
//   ncc_axil_agent_test  isto, ali kroz agenta, uz proveru sta je monitor video
//   ncc_axif_smoke_test  S01: paketni upis i citanje, duzine 1, 2, 3 i 16
//   ncc_smoke_test       ceo put: S01 -> S00 -> start -> done_sticky -> rezultat
package ncc_test_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_axil_pkg::*;
  import ncc_axif_pkg::*;
  import ncc_env_pkg::*;

  class ncc_vif_test extends uvm_test;
    `uvm_component_utils(ncc_vif_test)

    virtual axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W)) axil_vif;
    virtual axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W),
                          .DATA_W(S01_DATA_W))                      axif_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(virtual axi_lite_if #(.ADDR_W(S00_ADDR_W),
                                                .DATA_W(S00_DATA_W)))
            ::get(this, "", "axil_vif", axil_vif))
        `uvm_fatal("NOVIF", "axil_vif nije nadjen u uvm_config_db")

      if (!uvm_config_db#(virtual axi_full_if #(.ID_W(S01_ID_W),
                                                .ADDR_W(S01_ADDR_W),
                                                .DATA_W(S01_DATA_W)))
            ::get(this, "", "axif_vif", axif_vif))
        `uvm_fatal("NOVIF", "axif_vif nije nadjen u uvm_config_db")

      `uvm_info("VIF", "oba virtuelna interfejsa preuzeta iz uvm_config_db", UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      wait (axil_vif.rstn === 1'b1);
      `uvm_info("VIF", "reset otpusten, S00 vidljiv preko vif-a", UVM_LOW)

      wait (axif_vif.rstn === 1'b1);
      `uvm_info("VIF", "reset otpusten, S01 vidljiv preko vif-a", UVM_LOW)

      repeat (20) @(posedge axil_vif.clk);

      if (axil_vif.bvalid !== 1'b0 || axil_vif.rvalid !== 1'b0)
        `uvm_error("IDLE", $sformatf("S00 nije u mirovanju: bvalid=%0b rvalid=%0b",
                                     axil_vif.bvalid, axil_vif.rvalid))
      if (axif_vif.bvalid !== 1'b0 || axif_vif.rvalid !== 1'b0)
        `uvm_error("IDLE", $sformatf("S01 nije u mirovanju: bvalid=%0b rvalid=%0b",
                                     axif_vif.bvalid, axif_vif.rvalid))

      `uvm_info("VIF", "okruzenje se pokrece i uredno zavrsava bez transakcija", UVM_LOW)
      phase.drop_objection(this);
    endtask

  endclass : ncc_vif_test

  // --------------------------------------------------------------------------
  // Sekvencer i drajver se ovde grade rucno; agent dolazi u sledecem testu.
  // --------------------------------------------------------------------------
  class ncc_axil_smoke_test extends uvm_test;
    `uvm_component_utils(ncc_axil_smoke_test)

    ncc_axil_sequencer sqr;
    ncc_axil_driver    drv;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = ncc_axil_sequencer::type_id::create("sqr", this);
      drv = ncc_axil_driver   ::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_reg_rw_seq seq = ncc_reg_rw_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(sqr);
      phase.drop_objection(this);
    endtask

  endclass : ncc_axil_smoke_test

  // --------------------------------------------------------------------------
  // Potrosac transakcija koje monitor objavi (nije scoreboard).
  // --------------------------------------------------------------------------
  class ncc_mon_subscriber extends uvm_subscriber #(ncc_reg_item);
    `uvm_component_utils(ncc_mon_subscriber)

    int unsigned br_upisa   = 0;
    int unsigned br_citanja = 0;
    int unsigned br_redosleda[aw_w_order_e];

    function new(string name, uvm_component parent);
      super.new(name, parent);
      br_redosleda[ORDER_AW_FIRST] = 0;
      br_redosleda[ORDER_W_FIRST]  = 0;
      br_redosleda[ORDER_SIMUL]    = 0;
    endfunction

    function void write(ncc_reg_item t);
      if (t.rw == REG_WRITE) begin
        br_upisa++;
        br_redosleda[t.order]++;
        `uvm_info("SUB", $sformatf("monitor: upis  0x%02x = 0x%08x (%s)",
                                   t.addr, t.data, t.order.name()), UVM_LOW)
      end else begin
        br_citanja++;
        `uvm_info("SUB", $sformatf("monitor: citanje 0x%02x = 0x%08x",
                                   t.addr, t.data), UVM_LOW)
      end
    endfunction
  endclass : ncc_mon_subscriber

  // --------------------------------------------------------------------------
  // Isti stimulus kao ncc_axil_smoke_test, kroz agenta, uz proveru monitora.
  // --------------------------------------------------------------------------
  class ncc_axil_agent_test extends uvm_test;
    `uvm_component_utils(ncc_axil_agent_test)

    ncc_axil_agent      agent;
    ncc_mon_subscriber  sub;

    localparam int OCEKIVANO_UPISA   = 7;
    localparam int OCEKIVANO_CITANJA = 7;
    localparam int OCEKIVANO_AW_FIRST = 2;
    localparam int OCEKIVANO_W_FIRST  = 3;
    localparam int OCEKIVANO_SIMUL    = 2;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = ncc_axil_agent    ::type_id::create("agent", this);
      sub   = ncc_mon_subscriber::type_id::create("sub", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.ap.connect(sub.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_reg_rw_seq seq = ncc_reg_rw_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(agent.sqr);
      repeat (5) @(posedge agent.mon.vif.clk);
      phase.drop_objection(this);
    endtask

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);

      if (sub.br_upisa != OCEKIVANO_UPISA)
        `uvm_error("CHK", $sformatf("monitor je video %0d upisa, ocekivano %0d",
                                    sub.br_upisa, OCEKIVANO_UPISA))
      if (sub.br_citanja != OCEKIVANO_CITANJA)
        `uvm_error("CHK", $sformatf("monitor je video %0d citanja, ocekivano %0d",
                                    sub.br_citanja, OCEKIVANO_CITANJA))

      if (sub.br_redosleda[ORDER_AW_FIRST] != OCEKIVANO_AW_FIRST)
        `uvm_error("CHK", $sformatf("AW_FIRST: izmereno %0d, ocekivano %0d",
                                    sub.br_redosleda[ORDER_AW_FIRST], OCEKIVANO_AW_FIRST))
      if (sub.br_redosleda[ORDER_W_FIRST] != OCEKIVANO_W_FIRST)
        `uvm_error("CHK", $sformatf("W_FIRST: izmereno %0d, ocekivano %0d",
                                    sub.br_redosleda[ORDER_W_FIRST], OCEKIVANO_W_FIRST))
      if (sub.br_redosleda[ORDER_SIMUL] != OCEKIVANO_SIMUL)
        `uvm_error("CHK", $sformatf("SIMUL: izmereno %0d, ocekivano %0d",
                                    sub.br_redosleda[ORDER_SIMUL], OCEKIVANO_SIMUL))

      `uvm_info("CHK", $sformatf(
        "monitor: %0d upisa, %0d citanja; redosled AW_FIRST=%0d W_FIRST=%0d SIMUL=%0d",
        sub.br_upisa, sub.br_citanja,
        sub.br_redosleda[ORDER_AW_FIRST], sub.br_redosleda[ORDER_W_FIRST],
        sub.br_redosleda[ORDER_SIMUL]), UVM_LOW)
    endfunction

  endclass : ncc_axil_agent_test

  // --------------------------------------------------------------------------
  // S01 agent, paketni upis i citanje.
  // --------------------------------------------------------------------------
  class ncc_axif_smoke_test extends uvm_test;
    `uvm_component_utils(ncc_axif_smoke_test)

    ncc_axif_agent agent;

    int unsigned br_upisa   = 0;
    int unsigned br_citanja = 0;

    localparam int OCEKIVANO = 6;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = ncc_axif_agent::type_id::create("agent", this);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_mem_blok_seq seq = ncc_mem_blok_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(agent.sqr);
      repeat (5) @(posedge agent.mon.vif.clk);
      phase.drop_objection(this);
    endtask

  endclass : ncc_axif_smoke_test

  // --------------------------------------------------------------------------
  // Osnovni test sa punim okruzenjem. Zatvara Korak 3.
  // --------------------------------------------------------------------------
  class ncc_base_test extends uvm_test;
    `uvm_component_utils(ncc_base_test)

    ncc_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = ncc_env::type_id::create("env", this);
    endfunction

  endclass : ncc_base_test

  class ncc_smoke_test extends ncc_base_test;
    `uvm_component_utils(ncc_smoke_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_smoke_seq seq = ncc_smoke_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.vsqr);
      phase.drop_objection(this);
    endtask

  endclass : ncc_smoke_test

  // --------------------------------------------------------------------------
  // Korak 5: test namenjen pokrivenosti.
  // --------------------------------------------------------------------------
  class ncc_cov_test extends ncc_base_test;
    `uvm_component_utils(ncc_cov_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_cov_seq seq = ncc_cov_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.vsqr);
      phase.drop_objection(this);
    endtask

  endclass : ncc_cov_test

  // Spora lista: prelaz preko svih kombinacija bin-ova dimenzija.
  class ncc_dim_sweep_test extends ncc_base_test;
    `uvm_component_utils(ncc_dim_sweep_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_dim_sweep_seq seq = ncc_dim_sweep_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.vsqr);
      phase.drop_objection(this);
    endtask

  endclass : ncc_dim_sweep_test

  // Korak 6: slucajni test -- pobuda se menja sa seed-om.
  class ncc_random_test extends ncc_base_test;
    `uvm_component_utils(ncc_random_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ncc_random_seq seq = ncc_random_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.vsqr);
      phase.drop_objection(this);
    endtask

  endclass : ncc_random_test

endpackage : ncc_test_pkg
