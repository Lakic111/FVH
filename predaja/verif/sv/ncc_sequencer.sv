// Sequencer -- passes transactions from the sequences to the driver.
class ncc_sequencer extends uvm_sequencer #(ncc_item);

   `uvm_component_utils(ncc_sequencer)

   function new(string name = "ncc_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction

endclass : ncc_sequencer
