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
