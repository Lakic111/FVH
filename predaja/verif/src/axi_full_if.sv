// Interfejs za AXI4-Full slave S01 (slika / sablon / rezultat).
`timescale 1ns/1ps

interface axi_full_if #(
  parameter int ID_W   = 1,
  parameter int ADDR_W = 17,
  parameter int DATA_W = 32
) (
  input logic clk,
  input logic rstn
);

  // --- kanal adrese upisa ---------------------------------------------------
  logic [ID_W-1:0]     awid;
  logic [ADDR_W-1:0]   awaddr;
  logic [7:0]          awlen;
  logic [2:0]          awsize;
  logic [1:0]          awburst;
  logic                awlock;
  logic [3:0]          awcache;
  logic [2:0]          awprot;
  logic [3:0]          awqos;
  logic [3:0]          awregion;
  logic                awvalid;
  logic                awready;

  // --- kanal podataka upisa -------------------------------------------------
  logic [DATA_W-1:0]   wdata;
  logic [DATA_W/8-1:0] wstrb;
  logic                wlast;
  logic                wvalid;
  logic                wready;

  // --- kanal odgovora -------------------------------------------------------
  logic [ID_W-1:0]     bid;
  logic [1:0]          bresp;
  logic                bvalid;
  logic                bready;

  // --- kanal adrese citanja -------------------------------------------------
  logic [ID_W-1:0]     arid;
  logic [ADDR_W-1:0]   araddr;
  logic [7:0]          arlen;
  logic [2:0]          arsize;
  logic [1:0]          arburst;
  logic                arlock;
  logic [3:0]          arcache;
  logic [2:0]          arprot;
  logic [3:0]          arqos;
  logic [3:0]          arregion;
  logic                arvalid;
  logic                arready;

  // --- kanal podataka citanja -----------------------------------------------
  logic [ID_W-1:0]     rid;
  logic [DATA_W-1:0]   rdata;
  logic [1:0]          rresp;
  logic                rlast;
  logic                rvalid;
  logic                rready;

  clocking mst_cb @(posedge clk);
    default input #1step output #1ns;
    output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
           awqos, awregion, awvalid,
           wdata, wstrb, wlast, wvalid,
           bready,
           arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
           arqos, arregion, arvalid,
           rready;
    input  awready, wready, bid, bresp, bvalid, arready,
           rid, rdata, rresp, rlast, rvalid;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
          awqos, awregion, awvalid, awready,
          wdata, wstrb, wlast, wvalid, wready,
          bid, bresp, bvalid, bready,
          arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
          arqos, arregion, arvalid, arready,
          rid, rdata, rresp, rlast, rvalid, rready;
  endclocking

  modport mst (clocking mst_cb, input clk, input rstn);
  modport mon (clocking mon_cb, input clk, input rstn);

  // --- protokolske tvrdnje (SVA) --------------------------------------------
  property p_aw_drzi;
    @(posedge clk) disable iff (!rstn)
      awvalid && !awready |=> awvalid && $stable(awaddr) && $stable(awlen);
  endproperty
  a_aw_drzi: assert property (p_aw_drzi)
    else $error("AXI-Full S01: AWVALID, AWADDR ili AWLEN promenjen pre AWREADY");

  property p_w_drzi;
    @(posedge clk) disable iff (!rstn)
      wvalid && !wready |=> wvalid && $stable(wdata) && $stable(wlast);
  endproperty
  a_w_drzi: assert property (p_w_drzi)
    else $error("AXI-Full S01: WVALID, WDATA ili WLAST promenjen pre WREADY");

  property p_ar_drzi;
    @(posedge clk) disable iff (!rstn)
      arvalid && !arready |=> arvalid && $stable(araddr) && $stable(arlen);
  endproperty
  a_ar_drzi: assert property (p_ar_drzi)
    else $error("AXI-Full S01: ARVALID, ARADDR ili ARLEN promenjen pre ARREADY");

  property p_b_drzi;
    @(posedge clk) disable iff (!rstn) bvalid && !bready |=> bvalid;
  endproperty
  a_b_drzi: assert property (p_b_drzi)
    else $error("AXI-Full S01: BVALID povucen pre BREADY");

  property p_r_drzi;
    @(posedge clk) disable iff (!rstn)
      rvalid && !rready |=> rvalid && $stable(rdata) && $stable(rlast);
  endproperty
  a_r_drzi: assert property (p_r_drzi)
    else $error("AXI-Full S01: RVALID, RDATA ili RLAST promenjen pre RREADY");

  property p_nikad_oba_ready;
    @(posedge clk) disable iff (!rstn) !(awready && wready);
  endproperty
  a_nikad_oba_ready: assert property (p_nikad_oba_ready)
    else $error("AXI-Full S01: awready i wready istovremeno -- vratio se AW/W bug");

  property p_b_posle_wlast;
    @(posedge clk) disable iff (!rstn)
      $rose(bvalid) |-> $past(wvalid && wready && wlast, 1);
  endproperty
  a_b_posle_wlast: assert property (p_b_posle_wlast)
    else $error("AXI-Full S01: BVALID pre nego sto je primljen WLAST");

endinterface : axi_full_if
