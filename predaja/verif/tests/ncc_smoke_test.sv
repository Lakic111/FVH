// Ceo put: S01 -> S00 -> start -> done_sticky -> rezultat.
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
