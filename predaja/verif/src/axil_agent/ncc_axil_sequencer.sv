// Sekvencer za S00 (AXI4-Lite).
class ncc_axil_sequencer extends uvm_sequencer #(ncc_reg_item);
  `uvm_component_utils(ncc_axil_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ncc_axil_sequencer
