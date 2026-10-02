// Paket S01 agenta (AXI4-Full, memorije slike/sablona/rezultata).
package ncc_axif_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;

  typedef enum { MEM_WRITE, MEM_READ } mem_rw_e;

  `include "ncc_mem_item.sv"
  `include "ncc_axif_sequencer.sv"
  `include "ncc_axif_driver.sv"
  `include "ncc_axif_monitor.sv"
  `include "ncc_axif_agent_config.sv"
  `include "ncc_axif_agent.sv"
  `include "sequences/ncc_axif_base_seq.sv"
  `include "sequences/ncc_mem_blok_seq.sv"

endpackage : ncc_axif_pkg
