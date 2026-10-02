// Paket virtuelnih sekvenci (rade nad ncc_virtual_sequencer-om iz ncc_env_pkg).
package ncc_seq_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_axil_pkg::*;
  import ncc_axif_pkg::*;
  import ncc_env_pkg::*;

  `include "ncc_virtual_base_seq.sv"
  `include "ncc_smoke_seq.sv"
  `include "ncc_cov_seq.sv"
  `include "ncc_dim_sweep_seq.sv"
  `include "ncc_random_seq.sv"

endpackage : ncc_seq_pkg
