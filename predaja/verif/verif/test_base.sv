// Base test: builds the environment and the configuration of each agent. The others only start a sequence.
class test_base extends uvm_test;

   ncc_env    env;
   ncc_config cfg_axil;
   ncc_config cfg_axif;

   `uvm_component_utils(test_base)

   function new(string name = "test_base", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg_axil = ncc_config::type_id::create("cfg_axil");
      cfg_axif = ncc_config::type_id::create("cfg_axif");
      uvm_config_db#(ncc_config)::set(this, "env", "axil_config", cfg_axil);
      uvm_config_db#(ncc_config)::set(this, "env", "axif_config", cfg_axif);
      env = ncc_env::type_id::create("env", this);
   endfunction : build_phase

   function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_top.print_topology();
   endfunction : end_of_elaboration_phase

endclass : test_base
