// Okruzenje: oba agenta, virtuelni sekvencer, scoreboard i coverage.
class ncc_env extends uvm_env;
  `uvm_component_utils(ncc_env)

  ncc_axil_agent        axil_agent;
  ncc_axif_agent        axif_agent;
  ncc_virtual_sequencer vsqr;
  ncc_scoreboard        sb;
  ncc_coverage          cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axil_agent = ncc_axil_agent       ::type_id::create("axil_agent", this);
    axif_agent = ncc_axif_agent       ::type_id::create("axif_agent", this);
    vsqr       = ncc_virtual_sequencer::type_id::create("vsqr", this);
    sb         = ncc_scoreboard       ::type_id::create("sb", this);
    cov        = ncc_coverage         ::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vsqr.axil_sqr = axil_agent.sqr;
    vsqr.axif_sqr = axif_agent.sqr;
    // Scoreboard i coverage se vezuju na portove AGENATA (monitore), nikad drajvere.
    axil_agent.ap.connect(sb.reg_imp);
    axif_agent.ap.connect(sb.mem_imp);
    axil_agent.ap.connect(cov.reg_imp);
    axif_agent.ap.connect(cov.mem_imp);
  endfunction

endclass : ncc_env
