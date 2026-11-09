// AXI4-Full agent (S01): item, sequencer, driver, monitor, agent.
package axif_agent_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import configurations_pkg::*;

   `include "axif_item.sv"
   `include "axif_sequencer.sv"
   `include "axif_driver.sv"
   `include "axif_monitor.sv"
   `include "axif_agent.sv"

endpackage : axif_agent_pkg
