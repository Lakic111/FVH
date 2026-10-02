// Konfiguracija S01 agenta.
class ncc_axif_agent_config extends uvm_object;
  `uvm_object_utils(ncc_axif_agent_config)
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit [S01_ADDR_W-1:0]    base_addr = '0;
  function new(string name = "ncc_axif_agent_config");
    super.new(name);
  endfunction
endclass : ncc_axif_agent_config
