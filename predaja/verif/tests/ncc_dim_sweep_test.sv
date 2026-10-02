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
