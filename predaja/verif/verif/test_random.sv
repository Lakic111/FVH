// Random dimensions and data (run with many seeds).
class test_random extends test_base;

   `uvm_component_utils(test_random)

   ncc_random_seq seq;

   function new(string name = "test_random", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      seq = ncc_random_seq::type_id::create("seq");
      seq.axil_seqr = env.axil_agt.seqr;
      seq.axif_seqr = env.axif_agt.seqr;
      phase.raise_objection(this);
      seq.start(env.axil_agt.seqr);
      #100ns;
      phase.drop_objection(this);
   endtask : run_phase

endclass : test_random
