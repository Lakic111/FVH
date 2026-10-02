// Paket S00 agenta (AXI4-Lite, kontrolni registri).
package ncc_axil_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;

  typedef enum { REG_WRITE, REG_READ } reg_rw_e;

  `include "ncc_reg_item.sv"
  `include "ncc_axil_sequencer.sv"
  `include "ncc_axil_driver.sv"
  `include "ncc_axil_monitor.sv"
  `include "ncc_axil_agent_config.sv"
  `include "ncc_axil_agent.sv"
  `include "sequences/ncc_axil_base_seq.sv"
  `include "sequences/ncc_reg_rw_seq.sv"

endpackage : ncc_axil_pkg
