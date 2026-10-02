// Paket testova -- svaki test je u svom fajlu.
package ncc_test_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_axil_pkg::*;
  import ncc_axif_pkg::*;
  import ncc_env_pkg::*;
  import ncc_seq_pkg::*;

  `include "ncc_vif_test.sv"
  `include "ncc_axil_smoke_test.sv"
  `include "ncc_mon_subscriber.sv"
  `include "ncc_axil_agent_test.sv"
  `include "ncc_axif_smoke_test.sv"
  `include "ncc_base_test.sv"
  `include "ncc_smoke_test.sv"
  `include "ncc_cov_test.sv"
  `include "ncc_dim_sweep_test.sv"
  `include "ncc_random_test.sv"

endpackage : ncc_test_pkg
