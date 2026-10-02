// Isti stimulus kao ncc_axil_smoke_test, kroz agenta, uz proveru monitora.
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
