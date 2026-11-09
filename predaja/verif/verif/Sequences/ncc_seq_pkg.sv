// Sequences: one write and one read sequence for each agent, and the
// sequences that combine them into a whole job on the accelerator.
package ncc_seq_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import configurations_pkg::*;
   import axil_agent_pkg::*;
   import axif_agent_pkg::*;

   `include "axil_write_seq.sv"
   `include "axil_read_seq.sv"
   `include "axif_base_seq.sv"
   `include "axif_write_seq.sv"
   `include "axif_read_seq.sv"
   `include "ncc_base_seq.sv"
   `include "ncc_smoke_seq.sv"
   `include "ncc_cov_seq.sv"
   `include "ncc_random_seq.sv"

endpackage : ncc_seq_pkg
