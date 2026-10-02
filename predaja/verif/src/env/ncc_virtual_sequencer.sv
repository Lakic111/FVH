// Virtuelni sekvencer -- drzi pokazivace na oba stvarna sekvencera.
class ncc_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(ncc_virtual_sequencer)

  ncc_axil_sequencer axil_sqr;
  ncc_axif_sequencer axif_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : ncc_virtual_sequencer
