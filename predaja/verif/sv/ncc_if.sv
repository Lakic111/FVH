// Interface to the DUT: both accelerator buses.
//   S00 - AXI4-Lite, control registers (6-bit address)
//   S01 - AXI4-Full, image, template and result memories (17-bit address)
`timescale 1ns/1ps

interface ncc_if (input logic clk, input logic rstn);

   // ---------------- S00 (AXI4-Lite) ----------------
   logic [5 : 0]  s00_awaddr;
   logic [2 : 0]  s00_awprot;
   logic          s00_awvalid;
   logic          s00_awready;
   logic [31 : 0] s00_wdata;
   logic [3 : 0]  s00_wstrb;
   logic          s00_wvalid;
   logic          s00_wready;
   logic [1 : 0]  s00_bresp;
   logic          s00_bvalid;
   logic          s00_bready;
   logic [5 : 0]  s00_araddr;
   logic [2 : 0]  s00_arprot;
   logic          s00_arvalid;
   logic          s00_arready;
   logic [31 : 0] s00_rdata;
   logic [1 : 0]  s00_rresp;
   logic          s00_rvalid;
   logic          s00_rready;

   // ---------------- S01 (AXI4-Full) ----------------
   logic [0 : 0]  s01_awid;
   logic [16 : 0] s01_awaddr;
   logic [7 : 0]  s01_awlen;
   logic [2 : 0]  s01_awsize;
   logic [1 : 0]  s01_awburst;
   logic          s01_awlock;
   logic [3 : 0]  s01_awcache;
   logic [2 : 0]  s01_awprot;
   logic [3 : 0]  s01_awqos;
   logic [3 : 0]  s01_awregion;
   logic          s01_awvalid;
   logic          s01_awready;
   logic [31 : 0] s01_wdata;
   logic [3 : 0]  s01_wstrb;
   logic          s01_wlast;
   logic          s01_wvalid;
   logic          s01_wready;
   logic [0 : 0]  s01_bid;
   logic [1 : 0]  s01_bresp;
   logic          s01_bvalid;
   logic          s01_bready;
   logic [0 : 0]  s01_arid;
   logic [16 : 0] s01_araddr;
   logic [7 : 0]  s01_arlen;
   logic [2 : 0]  s01_arsize;
   logic [1 : 0]  s01_arburst;
   logic          s01_arlock;
   logic [3 : 0]  s01_arcache;
   logic [2 : 0]  s01_arprot;
   logic [3 : 0]  s01_arqos;
   logic [3 : 0]  s01_arregion;
   logic          s01_arvalid;
   logic          s01_arready;
   logic [0 : 0]  s01_rid;
   logic [31 : 0] s01_rdata;
   logic [1 : 0]  s01_rresp;
   logic          s01_rlast;
   logic          s01_rvalid;
   logic          s01_rready;

endinterface : ncc_if
