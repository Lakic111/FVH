// Testovi. test_base pravi okruzenje i konfiguraciju, ostali samo pokrecu sekvencu.
//   test_smoke  -- ceo put kroz DUT na malom primeru sa poznatim rezultatom
//   test_cov    -- usmereni slucajevi za pokrivenost i ponasanje memorija
//   test_random -- slucajne dimenzije i podaci (pokrece se sa vise seed-ova)

class test_base extends uvm_test;

   ncc_env    env;
   ncc_config cfg;

   `uvm_component_utils(test_base)

   function new(string name = "test_base", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = ncc_config::type_id::create("cfg");
      uvm_config_db#(ncc_config)::set(this, "*", "ncc_config", cfg);
      env = ncc_env::type_id::create("env", this);
   endfunction : build_phase

   function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_top.print_topology();
   endfunction : end_of_elaboration_phase

endclass : test_base


class test_smoke extends test_base;

   `uvm_component_utils(test_smoke)

   ncc_smoke_seq seq;

   function new(string name = "test_smoke", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      seq = ncc_smoke_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      #100ns;
      phase.drop_objection(this);
   endtask : run_phase

endclass : test_smoke


class test_cov extends test_base;

   `uvm_component_utils(test_cov)

   ncc_cov_seq seq;

   function new(string name = "test_cov", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      seq = ncc_cov_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      #100ns;
      phase.drop_objection(this);
   endtask : run_phase

endclass : test_cov


class test_random extends test_base;

   `uvm_component_utils(test_random)

   ncc_random_seq seq;

   function new(string name = "test_random", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   task run_phase(uvm_phase phase);
      seq = ncc_random_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      #100ns;
      phase.drop_objection(this);
   endtask : run_phase

endclass : test_random
