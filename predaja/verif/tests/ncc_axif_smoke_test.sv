// S01 agent, paketni upis i citanje (duzine 1, 2, 3 i 16).
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
