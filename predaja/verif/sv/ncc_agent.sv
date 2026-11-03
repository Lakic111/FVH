// Agent -- the monitor is always built, the driver and sequencer only in active mode.
class ncc_agent extends uvm_agent;

   ncc_driver    drv;
   ncc_sequencer seqr;
   ncc_monitor   mon;
   ncc_config    cfg;

   `uvm_component_utils_begin(ncc_agent)
      `uvm_field_object(cfg, UVM_DEFAULT)
   `uvm_component_utils_end

   function new(string name = "ncc_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(ncc_config)::get(this, "", "ncc_config", cfg))
         `uvm_fatal("NOCONFIG", {"Config object must be set for: ", get_full_name(), ".cfg"})

      mon = ncc_monitor::type_id::create("mon", this);
      if (cfg.is_active == UVM_ACTIVE) begin
         drv  = ncc_driver::type_id::create("drv", this);
         seqr = ncc_sequencer::type_id::create("seqr", this);
      end
   endfunction : build_phase

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.is_active == UVM_ACTIVE)
         drv.seq_item_port.connect(seqr.seq_item_export);
   endfunction : connect_phase

endclass : ncc_agent
