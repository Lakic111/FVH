// Verification environment package: constants, types and all classes.
package ncc_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"

   // --- S00 registers ---
   parameter bit [5 : 0] REG_IMG_W  = 6'h00;
   parameter bit [5 : 0] REG_IMG_H  = 6'h04;
   parameter bit [5 : 0] REG_TMP_W  = 6'h08;
   parameter bit [5 : 0] REG_TMP_H  = 6'h0C;
   parameter bit [5 : 0] REG_CTRL   = 6'h30;   // bit 0 = start
   parameter bit [5 : 0] REG_STATUS = 6'h34;   // bit 0 = done, bit 1 = busy

   // --- S01 regions: address[16:15] is the region, address[14:2] is the word ---
   parameter int REGION_IMAGE    = 0;   // +0x00000
   parameter int REGION_TEMPLATE = 1;   // +0x08000
   parameter int REGION_RESULT   = 2;   // +0x10000, read only
   parameter int REGION_UNMAPPED = 3;   // +0x18000

   // The template decoder uses only 10 address bits, so the template repeats every 1024 words.
   parameter int TMP_WORDS = 1024;

   typedef enum {BUS_S00, BUS_S01} bus_e;
   typedef enum {WRITE, READ} rw_e;
   // Order in which the driver raises AWVALID and WVALID on a write.
   typedef enum {ORDER_AW_FIRST, ORDER_W_FIRST, ORDER_SIMUL} order_e;

   `include "ncc_item.sv"
   `include "ncc_config.sv"
   `include "ncc_sequencer.sv"
   `include "ncc_driver.sv"
   `include "ncc_monitor.sv"
   `include "ncc_agent.sv"
   `include "ncc_scoreboard.sv"
   `include "ncc_env.sv"
   `include "ncc_sequences.sv"
   `include "ncc_tests.sv"

endpackage : ncc_pkg
