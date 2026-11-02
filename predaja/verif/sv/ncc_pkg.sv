// Paket verifikacionog okruzenja: konstante, tipovi i sve klase.
package ncc_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"

   // --- registri na S00 ---
   parameter bit [5 : 0] REG_IMG_W  = 6'h00;
   parameter bit [5 : 0] REG_IMG_H  = 6'h04;
   parameter bit [5 : 0] REG_TMP_W  = 6'h08;
   parameter bit [5 : 0] REG_TMP_H  = 6'h0C;
   parameter bit [5 : 0] REG_CTRL   = 6'h30;   // bit 0 = start
   parameter bit [5 : 0] REG_STATUS = 6'h34;   // bit 0 = done, bit 1 = busy

   // --- oblasti na S01: adresa[16:15] je oblast, adresa[14:2] je rec ---
   parameter int OBL_SLIKA      = 0;   // +0x00000
   parameter int OBL_SABLON     = 1;   // +0x08000
   parameter int OBL_REZULTAT   = 2;   // +0x10000, samo citanje
   parameter int OBL_NEMAPIRANO = 3;   // +0x18000

   // Dekoder sablona koristi samo 10 bita adrese, pa se sablon ponavlja na 1024 reci.
   parameter int TMP_RECI = 1024;

   typedef enum {BUS_S00, BUS_S01} bus_e;
   typedef enum {UPIS, CITANJE} rw_e;
   // Redosled kojim drajver postavlja AWVALID i WVALID pri upisu.
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
