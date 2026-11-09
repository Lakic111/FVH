// Directed cases for coverage and memory behaviour.
class test_cov extends test_base;

   `uvm_component_utils(test_cov)

   ncc_cov_seq seq;

   function new(string name = "test_cov", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      seq = ncc_cov_seq::type_id::create("seq");
      seq.axil_seqr = env.axil_agt.seqr;
      seq.axif_seqr = env.axif_agt.seqr;
      phase.raise_objection(this);
      seq.start(env.axil_agt.seqr);
      #100ns;
      phase.drop_objection(this);
   endtask : run_phase

endclass : test_cov
