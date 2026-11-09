// AXI4-Full interface: S01, the image, template and result memories (17-bit address).
`timescale 1ns/1ps

interface axif_if (input logic clk, input logic rstn);

   logic [0 : 0]  awid;
   logic [16 : 0] awaddr;
   logic [7 : 0]  awlen;
   logic [2 : 0]  awsize;
   logic [1 : 0]  awburst;
   logic          awlock;
   logic [3 : 0]  awcache;
   logic [2 : 0]  awprot;
   logic [3 : 0]  awqos;
   logic [3 : 0]  awregion;
   logic          awvalid;
   logic          awready;
   logic [31 : 0] wdata;
   logic [3 : 0]  wstrb;
   logic          wlast;
   logic          wvalid;
   logic          wready;
   logic [0 : 0]  bid;
   logic [1 : 0]  bresp;
   logic          bvalid;
   logic          bready;
   logic [0 : 0]  arid;
   logic [16 : 0] araddr;
   logic [7 : 0]  arlen;
   logic [2 : 0]  arsize;
   logic [1 : 0]  arburst;
   logic          arlock;
   logic [3 : 0]  arcache;
   logic [2 : 0]  arprot;
   logic [3 : 0]  arqos;
   logic [3 : 0]  arregion;
   logic          arvalid;
   logic          arready;
   logic [0 : 0]  rid;
   logic [31 : 0] rdata;
   logic [1 : 0]  rresp;
   logic          rlast;
   logic          rvalid;
   logic          rready;

endinterface : axif_if
