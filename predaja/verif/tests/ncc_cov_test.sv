// Korak 5: test namenjen pokrivenosti.
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
