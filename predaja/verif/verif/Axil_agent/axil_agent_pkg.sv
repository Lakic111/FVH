// AXI4-Lite agent (S00): item, sequencer, driver, monitor, agent.
package axil_agent_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import configurations_pkg::*;

   `include "axil_item.sv"
   `include "axil_sequencer.sv"
   `include "axil_driver.sv"
   `include "axil_monitor.sv"
   `include "axil_agent.sv"

endpackage : axil_agent_pkg
