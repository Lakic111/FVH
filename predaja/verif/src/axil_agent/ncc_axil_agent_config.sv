// Konfiguracija S00 agenta.
class ncc_axil_agent_config extends uvm_object;
  `uvm_object_utils(ncc_axil_agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit [S00_ADDR_W-1:0]    base_addr = '0;
  string                  vif_name  = "axil_vif";

  function new(string name = "ncc_axil_agent_config");
    super.new(name);
  endfunction
endclass : ncc_axil_agent_config
