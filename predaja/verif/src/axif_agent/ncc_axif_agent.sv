// S01 agent: sekvencer, drajver i monitor (pasivan rezim: samo monitor).
class ncc_axif_agent extends uvm_agent;
  `uvm_component_utils(ncc_axif_agent)

  ncc_axif_agent_config cfg;
  ncc_axif_sequencer    sqr;
  ncc_axif_driver       drv;
  ncc_axif_monitor      mon;
  uvm_analysis_port #(ncc_mem_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ncc_axif_agent_config)::get(this, "", "cfg", cfg))
      cfg = ncc_axif_agent_config::type_id::create("cfg");

    mon = ncc_axif_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sqr = ncc_axif_sequencer::type_id::create("sqr", this);
      drv = ncc_axif_driver   ::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(ap);
    if (cfg.is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass : ncc_axif_agent
