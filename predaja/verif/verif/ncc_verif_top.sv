// Top: 100 MHz clock, reset, one interface per bus, DUT and test start.
`timescale 1ns/1ps

module ncc_verif_top;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import ncc_test_pkg::*;

   logic clk;
   logic rstn;

   axil_if vif_axil (clk, rstn);
   axif_if vif_axif (clk, rstn);

   ncc_accel dut (
      .s00_axi_aclk     (clk),
      .s00_axi_aresetn  (rstn),
      .s00_axi_awaddr   (vif_axil.awaddr),
      .s00_axi_awprot   (vif_axil.awprot),
      .s00_axi_awvalid  (vif_axil.awvalid),
      .s00_axi_awready  (vif_axil.awready),
      .s00_axi_wdata    (vif_axil.wdata),
      .s00_axi_wstrb    (vif_axil.wstrb),
      .s00_axi_wvalid   (vif_axil.wvalid),
      .s00_axi_wready   (vif_axil.wready),
      .s00_axi_bresp    (vif_axil.bresp),
      .s00_axi_bvalid   (vif_axil.bvalid),
      .s00_axi_bready   (vif_axil.bready),
      .s00_axi_araddr   (vif_axil.araddr),
      .s00_axi_arprot   (vif_axil.arprot),
      .s00_axi_arvalid  (vif_axil.arvalid),
      .s00_axi_arready  (vif_axil.arready),
      .s00_axi_rdata    (vif_axil.rdata),
      .s00_axi_rresp    (vif_axil.rresp),
      .s00_axi_rvalid   (vif_axil.rvalid),
      .s00_axi_rready   (vif_axil.rready),

      .s01_axi_aclk     (clk),
      .s01_axi_aresetn  (rstn),
      .s01_axi_awid     (vif_axif.awid),
      .s01_axi_awaddr   (vif_axif.awaddr),
      .s01_axi_awlen    (vif_axif.awlen),
      .s01_axi_awsize   (vif_axif.awsize),
      .s01_axi_awburst  (vif_axif.awburst),
      .s01_axi_awlock   (vif_axif.awlock),
      .s01_axi_awcache  (vif_axif.awcache),
      .s01_axi_awprot   (vif_axif.awprot),
      .s01_axi_awqos    (vif_axif.awqos),
      .s01_axi_awregion (vif_axif.awregion),
      .s01_axi_awvalid  (vif_axif.awvalid),
      .s01_axi_awready  (vif_axif.awready),
      .s01_axi_wdata    (vif_axif.wdata),
      .s01_axi_wstrb    (vif_axif.wstrb),
      .s01_axi_wlast    (vif_axif.wlast),
      .s01_axi_wvalid   (vif_axif.wvalid),
      .s01_axi_wready   (vif_axif.wready),
      .s01_axi_bid      (vif_axif.bid),
      .s01_axi_bresp    (vif_axif.bresp),
      .s01_axi_bvalid   (vif_axif.bvalid),
      .s01_axi_bready   (vif_axif.bready),
      .s01_axi_arid     (vif_axif.arid),
      .s01_axi_araddr   (vif_axif.araddr),
      .s01_axi_arlen    (vif_axif.arlen),
      .s01_axi_arsize   (vif_axif.arsize),
      .s01_axi_arburst  (vif_axif.arburst),
      .s01_axi_arlock   (vif_axif.arlock),
      .s01_axi_arcache  (vif_axif.arcache),
      .s01_axi_arprot   (vif_axif.arprot),
      .s01_axi_arqos    (vif_axif.arqos),
      .s01_axi_arregion (vif_axif.arregion),
      .s01_axi_arvalid  (vif_axif.arvalid),
      .s01_axi_arready  (vif_axif.arready),
      .s01_axi_rid      (vif_axif.rid),
      .s01_axi_rdata    (vif_axif.rdata),
      .s01_axi_rresp    (vif_axif.rresp),
      .s01_axi_rlast    (vif_axif.rlast),
      .s01_axi_rvalid   (vif_axif.rvalid),
      .s01_axi_rready   (vif_axif.rready)
   );

   initial begin
      uvm_config_db#(virtual axil_if)::set(null, "uvm_test_top.env", "axil_if", vif_axil);
      uvm_config_db#(virtual axif_if)::set(null, "uvm_test_top.env", "axif_if", vif_axif);
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

endmodule : ncc_verif_top
