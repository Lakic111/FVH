// Okruzenje: agent i scoreboard, monitor je vezan na scoreboard.
class ncc_env extends uvm_env;

   ncc_agent      agent;
   ncc_scoreboard scbd;

   `uvm_component_utils(ncc_env)

   function new(string name = "ncc_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = ncc_agent::type_id::create("agent", this);
      scbd  = ncc_scoreboard::type_id::create("scbd", this);
   endfunction : build_phase

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.item_collected_port.connect(scbd.item_collected_imp);
   endfunction : connect_phase

endclass : ncc_env
