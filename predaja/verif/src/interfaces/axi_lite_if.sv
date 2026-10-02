// Interfejs za AXI4-Lite slave S00 (kontrolni registri).
`timescale 1ns/1ps

interface axi_lite_if #(
  parameter int ADDR_W = 6,
  parameter int DATA_W = 32
) (
  input logic clk,
  input logic rstn
);

  logic [ADDR_W-1:0]   awaddr;
  logic [2:0]          awprot;
  logic                awvalid;
  logic                awready;

  logic [DATA_W-1:0]   wdata;
  logic [DATA_W/8-1:0] wstrb;
  logic                wvalid;
  logic                wready;

  logic [1:0]          bresp;
  logic                bvalid;
  logic                bready;

  logic [ADDR_W-1:0]   araddr;
  logic [2:0]          arprot;
  logic                arvalid;
  logic                arready;

  logic [DATA_W-1:0]   rdata;
  logic [1:0]          rresp;
  logic                rvalid;
  logic                rready;

  // mst_cb -- drajver; mon_cb -- monitor, nezavisan od pobude
  clocking mst_cb @(posedge clk);
    default input #1step output #1ns;
    output awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready,
           araddr, arprot, arvalid, rready;
    input  awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input awaddr, awprot, awvalid, awready,
          wdata, wstrb, wvalid, wready,
          bresp, bvalid, bready,
          araddr, arprot, arvalid, arready,
          rdata, rresp, rvalid, rready;
  endclocking

  modport mst (clocking mst_cb, input clk, input rstn);
  modport mon (clocking mon_cb, input clk, input rstn);

  // --- protokolske tvrdnje (SVA) --------------------------------------------
  property p_aw_drzi;
    @(posedge clk) disable iff (!rstn)
      awvalid && !awready |=> awvalid && $stable(awaddr);
  endproperty
  a_aw_drzi: assert property (p_aw_drzi)
    else $error("AXI-Lite S00: AWVALID ili AWADDR promenjen pre AWREADY");

  property p_w_drzi;
    @(posedge clk) disable iff (!rstn)
      wvalid && !wready |=> wvalid && $stable(wdata) && $stable(wstrb);
  endproperty
  a_w_drzi: assert property (p_w_drzi)
    else $error("AXI-Lite S00: WVALID ili WDATA promenjen pre WREADY");

  property p_ar_drzi;
    @(posedge clk) disable iff (!rstn)
      arvalid && !arready |=> arvalid && $stable(araddr);
  endproperty
  a_ar_drzi: assert property (p_ar_drzi)
    else $error("AXI-Lite S00: ARVALID ili ARADDR promenjen pre ARREADY");

  property p_b_drzi;
    @(posedge clk) disable iff (!rstn)
      bvalid && !bready |=> bvalid;
  endproperty
  a_b_drzi: assert property (p_b_drzi)
    else $error("AXI-Lite S00: BVALID povucen pre BREADY");

  property p_r_drzi;
    @(posedge clk) disable iff (!rstn)
      rvalid && !rready |=> rvalid && $stable(rdata);
  endproperty
  a_r_drzi: assert property (p_r_drzi)
    else $error("AXI-Lite S00: RVALID ili RDATA promenjen pre RREADY");

  // Cuva popravku AW/W buga: awready i wready se ne smeju dici istovremeno.
  property p_nikad_oba_ready;
    @(posedge clk) disable iff (!rstn) !(awready && wready);
  endproperty
  a_nikad_oba_ready: assert property (p_nikad_oba_ready)
    else $error("AXI-Lite S00: awready i wready istovremeno -- vratio se AW/W bug");

endinterface : axi_lite_if
