// Top: 100 MHz clock, reset, interface, DUT and test start.
`timescale 1ns/1ps

module ncc_top;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import ncc_pkg::*;

   logic clk;
   logic rstn;

   ncc_if vif (clk, rstn);

   ncc_accel dut (
      .s00_axi_aclk     (clk),
      .s00_axi_aresetn  (rstn),
      .s00_axi_awaddr   (vif.s00_awaddr),
      .s00_axi_awprot   (vif.s00_awprot),
      .s00_axi_awvalid  (vif.s00_awvalid),
      .s00_axi_awready  (vif.s00_awready),
      .s00_axi_wdata    (vif.s00_wdata),
      .s00_axi_wstrb    (vif.s00_wstrb),
      .s00_axi_wvalid   (vif.s00_wvalid),
      .s00_axi_wready   (vif.s00_wready),
      .s00_axi_bresp    (vif.s00_bresp),
      .s00_axi_bvalid   (vif.s00_bvalid),
      .s00_axi_bready   (vif.s00_bready),
      .s00_axi_araddr   (vif.s00_araddr),
      .s00_axi_arprot   (vif.s00_arprot),
      .s00_axi_arvalid  (vif.s00_arvalid),
      .s00_axi_arready  (vif.s00_arready),
      .s00_axi_rdata    (vif.s00_rdata),
      .s00_axi_rresp    (vif.s00_rresp),
      .s00_axi_rvalid   (vif.s00_rvalid),
      .s00_axi_rready   (vif.s00_rready),

      .s01_axi_aclk     (clk),
      .s01_axi_aresetn  (rstn),
      .s01_axi_awid     (vif.s01_awid),
      .s01_axi_awaddr   (vif.s01_awaddr),
      .s01_axi_awlen    (vif.s01_awlen),
      .s01_axi_awsize   (vif.s01_awsize),
      .s01_axi_awburst  (vif.s01_awburst),
      .s01_axi_awlock   (vif.s01_awlock),
      .s01_axi_awcache  (vif.s01_awcache),
      .s01_axi_awprot   (vif.s01_awprot),
      .s01_axi_awqos    (vif.s01_awqos),
      .s01_axi_awregion (vif.s01_awregion),
      .s01_axi_awvalid  (vif.s01_awvalid),
      .s01_axi_awready  (vif.s01_awready),
      .s01_axi_wdata    (vif.s01_wdata),
      .s01_axi_wstrb    (vif.s01_wstrb),
      .s01_axi_wlast    (vif.s01_wlast),
      .s01_axi_wvalid   (vif.s01_wvalid),
      .s01_axi_wready   (vif.s01_wready),
      .s01_axi_bid      (vif.s01_bid),
      .s01_axi_bresp    (vif.s01_bresp),
      .s01_axi_bvalid   (vif.s01_bvalid),
      .s01_axi_bready   (vif.s01_bready),
      .s01_axi_arid     (vif.s01_arid),
      .s01_axi_araddr   (vif.s01_araddr),
      .s01_axi_arlen    (vif.s01_arlen),
      .s01_axi_arsize   (vif.s01_arsize),
      .s01_axi_arburst  (vif.s01_arburst),
      .s01_axi_arlock   (vif.s01_arlock),
      .s01_axi_arcache  (vif.s01_arcache),
      .s01_axi_arprot   (vif.s01_arprot),
      .s01_axi_arqos    (vif.s01_arqos),
      .s01_axi_arregion (vif.s01_arregion),
      .s01_axi_arvalid  (vif.s01_arvalid),
      .s01_axi_arready  (vif.s01_arready),
      .s01_axi_rid      (vif.s01_rid),
      .s01_axi_rdata    (vif.s01_rdata),
      .s01_axi_rresp    (vif.s01_rresp),
      .s01_axi_rlast    (vif.s01_rlast),
      .s01_axi_rvalid   (vif.s01_rvalid),
      .s01_axi_rready   (vif.s01_rready)
   );

   initial begin
      uvm_config_db#(virtual ncc_if)::set(null, "*", "ncc_if", vif);
      run_test();
   end

   // clock and reset (reset lasts 10 clock cycles)
   initial begin
      clk  <= 0;
      rstn <= 0;
      #100 rstn <= 1;
   end

   always #5 clk = ~clk;

   // watchdog in case the simulation hangs
   initial begin
      #50ms;
      `uvm_fatal("TOP", "simulation did not finish in time")
   end

endmodule : ncc_top
