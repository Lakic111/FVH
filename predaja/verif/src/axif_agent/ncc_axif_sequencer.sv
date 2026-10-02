// Sekvencer za S01 (AXI4-Full).
class ncc_axif_sequencer extends uvm_sequencer #(ncc_mem_item);
  `uvm_component_utils(ncc_axif_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ncc_axif_sequencer
