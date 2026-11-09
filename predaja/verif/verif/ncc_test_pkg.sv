// Scoreboard, environment and tests.
package ncc_test_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import configurations_pkg::*;
   import axil_agent_pkg::*;
   import axif_agent_pkg::*;
   import ncc_seq_pkg::*;

   `include "ncc_scoreboard.sv"
   `include "ncc_env.sv"
   `include "test_base.sv"
   `include "test_smoke.sv"
   `include "test_cov.sv"
   `include "test_random.sv"

endpackage : ncc_test_pkg
