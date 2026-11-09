// AXI4-Lite interface: S00, the control registers (6-bit address).
`timescale 1ns/1ps

interface axil_if (input logic clk, input logic rstn);

   logic [5 : 0]  awaddr;
   logic [2 : 0]  awprot;
   logic          awvalid;
   logic          awready;
   logic [31 : 0] wdata;
   logic [3 : 0]  wstrb;
   logic          wvalid;
   logic          wready;
   logic [1 : 0]  bresp;
   logic          bvalid;
   logic          bready;
   logic [5 : 0]  araddr;
   logic [2 : 0]  arprot;
   logic          arvalid;
   logic          arready;
   logic [31 : 0] rdata;
   logic [1 : 0]  rresp;
   logic          rvalid;
   logic          rready;

endinterface : axil_if
