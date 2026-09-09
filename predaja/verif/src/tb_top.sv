// Vrh verifikacionog okruzenja: takt, reset, DUT, virtuelni interfejsi.
`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_test_pkg::*;

  localparam realtime CLK_PERIOD = 10ns;   // 100 MHz, kao na ploci

  logic clk  = 1'b0;
  logic rstn = 1'b0;

  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    rstn = 1'b0;
    repeat (10) @(posedge clk);
    rstn = 1'b1;
  end

  axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W))
    axil_if (.clk(clk), .rstn(rstn));

  axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W), .DATA_W(S01_DATA_W))
    axif_if (.clk(clk), .rstn(rstn));

  // --- DUT ------------------------------------------------------------------
  ncc_accel dut (
    .s00_axi_aclk    (clk),
    .s00_axi_aresetn (rstn),
    .s00_axi_awaddr  (axil_if.awaddr),
    .s00_axi_awprot  (axil_if.awprot),
    .s00_axi_awvalid (axil_if.awvalid),
    .s00_axi_awready (axil_if.awready),
    .s00_axi_wdata   (axil_if.wdata),
    .s00_axi_wstrb   (axil_if.wstrb),
    .s00_axi_wvalid  (axil_if.wvalid),
    .s00_axi_wready  (axil_if.wready),
    .s00_axi_bresp   (axil_if.bresp),
    .s00_axi_bvalid  (axil_if.bvalid),
    .s00_axi_bready  (axil_if.bready),
    .s00_axi_araddr  (axil_if.araddr),
    .s00_axi_arprot  (axil_if.arprot),
    .s00_axi_arvalid (axil_if.arvalid),
    .s00_axi_arready (axil_if.arready),
    .s00_axi_rdata   (axil_if.rdata),
    .s00_axi_rresp   (axil_if.rresp),
    .s00_axi_rvalid  (axil_if.rvalid),
    .s00_axi_rready  (axil_if.rready),

    .s01_axi_aclk    (clk),
    .s01_axi_aresetn (rstn),
    .s01_axi_awid    (axif_if.awid),
    .s01_axi_awaddr  (axif_if.awaddr),
    .s01_axi_awlen   (axif_if.awlen),
    .s01_axi_awsize  (axif_if.awsize),
    .s01_axi_awburst (axif_if.awburst),
    .s01_axi_awlock  (axif_if.awlock),
    .s01_axi_awcache (axif_if.awcache),
    .s01_axi_awprot  (axif_if.awprot),
    .s01_axi_awqos   (axif_if.awqos),
    .s01_axi_awregion(axif_if.awregion),
    .s01_axi_awvalid (axif_if.awvalid),
    .s01_axi_awready (axif_if.awready),
    .s01_axi_wdata   (axif_if.wdata),
    .s01_axi_wstrb   (axif_if.wstrb),
    .s01_axi_wlast   (axif_if.wlast),
    .s01_axi_wvalid  (axif_if.wvalid),
    .s01_axi_wready  (axif_if.wready),
    .s01_axi_bid     (axif_if.bid),
    .s01_axi_bresp   (axif_if.bresp),
    .s01_axi_bvalid  (axif_if.bvalid),
    .s01_axi_bready  (axif_if.bready),
    .s01_axi_arid    (axif_if.arid),
    .s01_axi_araddr  (axif_if.araddr),
    .s01_axi_arlen   (axif_if.arlen),
    .s01_axi_arsize  (axif_if.arsize),
    .s01_axi_arburst (axif_if.arburst),
    .s01_axi_arlock  (axif_if.arlock),
    .s01_axi_arcache (axif_if.arcache),
    .s01_axi_arprot  (axif_if.arprot),
    .s01_axi_arqos   (axif_if.arqos),
    .s01_axi_arregion(axif_if.arregion),
    .s01_axi_arvalid (axif_if.arvalid),
    .s01_axi_arready (axif_if.arready),
    .s01_axi_rid     (axif_if.rid),
    .s01_axi_rdata   (axif_if.rdata),
    .s01_axi_rresp   (axif_if.rresp),
    .s01_axi_rlast   (axif_if.rlast),
    .s01_axi_rvalid  (axif_if.rvalid),
    .s01_axi_rready  (axif_if.rready)
  );

  initial begin
    uvm_config_db#(virtual axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W)))
      ::set(null, "*", "axil_vif", axil_if);
    uvm_config_db#(virtual axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W),
                                         .DATA_W(S01_DATA_W)))
      ::set(null, "*", "axif_vif", axif_if);
    run_test();
  end

  // Nadzorni brojac: testovi T8/T10 rade pun proracun (~2,4 M taktova).
  initial begin
    #50ms;
    `uvm_fatal("WATCHDOG", "simulacija nije zavrsila na vreme")
  end

endmodule : tb_top
