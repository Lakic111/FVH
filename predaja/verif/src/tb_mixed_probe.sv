// Provera mesovitog jezika (VHDL DUT + SV TB): upis/citanje REG_IMG_W.
// Zamenjen sa tb_top.sv, zadrzan kao istorijski zapis.
`timescale 1ns/1ps

module tb_mixed_probe;

  localparam int unsigned S00_AW = 6;   // C_S00_AXI_ADDR_WIDTH
  localparam int unsigned S01_AW = 17;  // C_S01_AXI_ADDR_WIDTH
  localparam logic [S00_AW-1:0] REG_IMG_W = 6'h00;
  localparam logic [31:0]       TEST_VAL  = 32'd90;

  logic clk = 1'b0;
  logic rstn = 1'b0;
  always #5ns clk = ~clk;                              // 100 MHz

  // --- S00 (AXI4-Lite) ------------------------------------------------------
  logic [S00_AW-1:0] awaddr;  logic awvalid;  logic awready;
  logic [31:0]       wdata;   logic wvalid;   logic wready;  logic [3:0] wstrb;
  logic [1:0]        bresp;   logic bvalid;   logic bready;
  logic [S00_AW-1:0] araddr;  logic arvalid;  logic arready;
  logic [31:0]       rdata;   logic [1:0] rresp; logic rvalid; logic rready;

  // --- S01 (AXI4-Full) -- miruje, samo mora biti vezan -----------------------
  logic s01_awvalid = 1'b0, s01_wvalid = 1'b0, s01_bready = 1'b0;
  logic s01_arvalid = 1'b0, s01_rready = 1'b0, s01_wlast = 1'b0;
  logic s01_awready, s01_wready, s01_bvalid, s01_arready, s01_rvalid, s01_rlast;

  ncc_accel dut (
    // S00 -- AXI4-Lite
    .s00_axi_aclk    (clk),      .s00_axi_aresetn (rstn),
    .s00_axi_awaddr  (awaddr),   .s00_axi_awprot  (3'b000),
    .s00_axi_awvalid (awvalid),  .s00_axi_awready (awready),
    .s00_axi_wdata   (wdata),    .s00_axi_wstrb   (wstrb),
    .s00_axi_wvalid  (wvalid),   .s00_axi_wready  (wready),
    .s00_axi_bresp   (bresp),    .s00_axi_bvalid  (bvalid),
    .s00_axi_bready  (bready),
    .s00_axi_araddr  (araddr),   .s00_axi_arprot  (3'b000),
    .s00_axi_arvalid (arvalid),  .s00_axi_arready (arready),
    .s00_axi_rdata   (rdata),    .s00_axi_rresp   (rresp),
    .s00_axi_rvalid  (rvalid),   .s00_axi_rready  (rready),

    // S01 -- AXI4-Full, neaktivan
    .s01_axi_aclk    (clk),      .s01_axi_aresetn (rstn),
    .s01_axi_awid    (1'b0),     .s01_axi_awaddr  ({S01_AW{1'b0}}),
    .s01_axi_awlen   (8'd0),     .s01_axi_awsize  (3'b010),
    .s01_axi_awburst (2'b01),    .s01_axi_awlock  (1'b0),
    .s01_axi_awcache (4'b0000),  .s01_axi_awprot  (3'b000),
    .s01_axi_awqos   (4'b0000),  .s01_axi_awregion(4'b0000),
    .s01_axi_awvalid (s01_awvalid), .s01_axi_awready (s01_awready),
    .s01_axi_wdata   (32'd0),    .s01_axi_wstrb   (4'hF),
    .s01_axi_wlast   (s01_wlast),.s01_axi_wvalid  (s01_wvalid),
    .s01_axi_wready  (s01_wready),
    .s01_axi_bid     (),         .s01_axi_bresp   (),
    .s01_axi_bvalid  (s01_bvalid), .s01_axi_bready (s01_bready),
    .s01_axi_arid    (1'b0),     .s01_axi_araddr  ({S01_AW{1'b0}}),
    .s01_axi_arlen   (8'd0),     .s01_axi_arsize  (3'b010),
    .s01_axi_arburst (2'b01),    .s01_axi_arlock  (1'b0),
    .s01_axi_arcache (4'b0000),  .s01_axi_arprot  (3'b000),
    .s01_axi_arqos   (4'b0000),  .s01_axi_arregion(4'b0000),
    .s01_axi_arvalid (s01_arvalid), .s01_axi_arready (s01_arready),
    .s01_axi_rid     (),         .s01_axi_rdata   (),
    .s01_axi_rresp   (),         .s01_axi_rlast   (s01_rlast),
    .s01_axi_rvalid  (s01_rvalid), .s01_axi_rready (s01_rready)
  );

  // AW, W i B su nezavisni kanali (dvofazni upisni automat DUT-a).
  task automatic axil_write(input logic [S00_AW-1:0] a, input logic [31:0] d);
    fork
      begin : aw_kanal
        @(posedge clk);
        awaddr <= a; awvalid <= 1'b1;
        do @(posedge clk); while (!awready);
        awvalid <= 1'b0;
      end
      begin : w_kanal
        @(posedge clk);
        wdata <= d; wstrb <= 4'hF; wvalid <= 1'b1;
        do @(posedge clk); while (!wready);
        wvalid <= 1'b0;
      end
      begin : b_kanal
        @(posedge clk);
        bready <= 1'b1;
        do @(posedge clk); while (!bvalid);
        bready <= 1'b0;
      end
    join
  endtask

  task automatic axil_read(input logic [S00_AW-1:0] a, output logic [31:0] d);
    @(posedge clk);
    araddr <= a; arvalid <= 1'b1; rready <= 1'b1;
    do @(posedge clk); while (!arready);
    arvalid <= 1'b0;
    do @(posedge clk); while (!rvalid);
    d = rdata;
    rready <= 1'b0;
  endtask

  logic [31:0] citano;
  int unsigned greske = 0;

  initial begin
    awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
    awaddr  = '0; araddr = '0; wdata = '0; wstrb = '0;

    repeat (10) @(posedge clk);
    rstn = 1'b1;
    repeat (5) @(posedge clk);

    axil_write(REG_IMG_W, TEST_VAL);
    axil_read (REG_IMG_W, citano);

    if (citano !== TEST_VAL) begin
      $display("FAIL: REG_IMG_W ocekivano 0x%08x, dobijeno 0x%08x", TEST_VAL, citano);
      greske++;
    end else begin
      $display("OK: REG_IMG_W upisano i procitano 0x%08x", citano);
    end

    if (greske == 0) $display("PASS: mesoviti jezik VHDL+SV radi u XSim-u");
    else             $display("FAIL: %0d gresaka", greske);
    $finish;
  end

  initial begin
    #50us;
    $display("FAIL: watchdog -- simulacija nije zavrsila na vreme");
    $finish;
  end

endmodule
