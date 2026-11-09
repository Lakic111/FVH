// Agent -- the monitor is always built, the driver and sequencer only in active mode.
class axif_agent extends uvm_agent;

   axif_driver    drv;
   axif_sequencer seqr;
   axif_monitor   mon;
   virtual interface axif_if vif;
   ncc_config     cfg;

   `uvm_component_utils_begin(axif_agent)
      `uvm_field_object(cfg, UVM_DEFAULT)
   `uvm_component_utils_end

   function new(string name = "axif_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axif_if)::get(this, "", "axif_if", vif))
         `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
      if (!uvm_config_db#(ncc_config)::get(this, "", "axif_config", cfg))
         `uvm_fatal("NOCONFIG", {"Config object must be set for: ", get_full_name(), ".cfg"})

      uvm_config_db#(virtual axif_if)::set(this, "*", "axif_if", vif);

      mon = axif_monitor::type_id::create("mon", this);
      if (cfg.is_active == UVM_ACTIVE) begin
         drv  = axif_driver::type_id::create("drv", this);
         seqr = axif_sequencer::type_id::create("seqr", this);
      end
   endfunction : build_phase

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.is_active == UVM_ACTIVE)
         drv.seq_item_port.connect(seqr.seq_item_export);
   endfunction : connect_phase

endclass : axif_agent
