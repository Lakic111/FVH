// Paket okruzenja: scoreboard, coverage, virtuelni sekvencer i env.
package ncc_env_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_axil_pkg::*;
  import ncc_axif_pkg::*;
  import ncc_ref_pkg::*;

  // Dva ulaza u scoreboard i dva u coverage traze razlicite write metode.
  `uvm_analysis_imp_decl(_reg)
  `uvm_analysis_imp_decl(_mem)
  `uvm_analysis_imp_decl(_covreg)
  `uvm_analysis_imp_decl(_covmem)

  typedef enum { COV_S00, COV_S01_IMG, COV_S01_TMP, COV_S01_RES, COV_S01_NONE }
    cov_region_e;

  `include "ncc_scoreboard.sv"
  `include "ncc_coverage.sv"
  `include "ncc_virtual_sequencer.sv"
  `include "ncc_env.sv"

endpackage : ncc_env_pkg
