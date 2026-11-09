// Environment: one agent per bus and the scoreboard. Each monitor goes to its own scoreboard port.
class ncc_env extends uvm_env;

   axil_agent     axil_agt;
   axif_agent     axif_agt;
   ncc_scoreboard scbd;
   ncc_config     cfg_axil;
   ncc_config     cfg_axif;
   virtual interface axil_if vif_axil;
   virtual interface axif_if vif_axif;

   `uvm_component_utils(ncc_env)

   function new(string name = "ncc_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_if", vif_axil))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif_axil"})
      if (!uvm_config_db#(virtual axif_if)::get(this, "", "axif_if", vif_axif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif_axif"})
      if (!uvm_config_db#(ncc_config)::get(this, "", "axil_config", cfg_axil))
         `uvm_fatal("NOCONFIG", {"Config object must be set for: ", get_full_name(), ".cfg_axil"})
      if (!uvm_config_db#(ncc_config)::get(this, "", "axif_config", cfg_axif))
         `uvm_fatal("NOCONFIG", {"Config object must be set for: ", get_full_name(), ".cfg_axif"})

      uvm_config_db#(virtual axil_if)::set(this, "axil_agt", "axil_if", vif_axil);
      uvm_config_db#(virtual axif_if)::set(this, "axif_agt", "axif_if", vif_axif);
      uvm_config_db#(ncc_config)::set(this, "axil_agt", "axil_config", cfg_axil);
      uvm_config_db#(ncc_config)::set(this, "axif_agt", "axif_config", cfg_axif);

      axil_agt = axil_agent::type_id::create("axil_agt", this);
      axif_agt = axif_agent::type_id::create("axif_agt", this);
      scbd     = ncc_scoreboard::type_id::create("scbd", this);
   endfunction : build_phase

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      axil_agt.mon.item_collected_port.connect(scbd.port_axil);
      axif_agt.mon.item_collected_port.connect(scbd.port_axif);
   endfunction : connect_phase

endclass : ncc_env
