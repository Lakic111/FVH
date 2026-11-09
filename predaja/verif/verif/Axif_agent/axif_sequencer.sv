// Sequencer -- passes S01 transactions from the sequences to the driver.
class axif_sequencer extends uvm_sequencer #(axif_item);

   `uvm_component_utils(axif_sequencer)

   function new(string name = "axif_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction

endclass : axif_sequencer
