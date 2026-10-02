// Osnovni test sa punim okruzenjem -- roditelj svih testova ispod.
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
