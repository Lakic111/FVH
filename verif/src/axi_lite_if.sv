// ============================================================================
// axi_lite_if.sv -- interfejs za AXI4-Lite slave S00 (kontrolni registri).
//
// Tri clocking bloka, ne dva:
//   mst_cb  -- drajver: vozi master signale, uzorkuje slave odgovore
//   mon_cb  -- monitor: sve ulazno, pasivno
//   (modport `dut` je bez clocking bloka -- DUT je VHDL i vezuje se na gole zice)
//
// Zasto monitor ima svoj clocking blok: da bi uzorkovao ISTE vrednosti koje je
// DUT video, nezavisno od toga sta drajver upravo vozi.  Deljenje mst_cb
// izmedju drajvera i monitora dalo bi monitoru pogled na pobudu umesto na
// magistralu, sto je tacno greska koju plan izbegava (poglavlje 8 priloga).
// ============================================================================
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

  // 1step uzorkuje neposredno pre ivice takta -- vrednost koju vidi i DUT.
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

  // ==========================================================================
  // Protokolske tvrdnje (SVA)
  //
  // Stoje u interfejsu, ne u testbencu, pa vaze u SVAKOM testu -- i u onima
  // koji o njima ne znaju nista.  To je i smisao: greska u rukovanju prijavljuje
  // se u trenutku nastanka, bez obzira ko je pobuduje.
  //
  // `disable iff (!rstn)` je obavezan: tokom reseta signali nisu ni definisani.
  // ==========================================================================

  // --- master ne sme povuci VALID pre nego sto stigne READY -----------------
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

  // --- slave ne sme povuci VALID pre nego sto master prihvati ---------------
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

  // --- invarijanta ovog DUT-a, ne opsteg AXI protokola ----------------------
  //
  // Popravljeni upisni automat je strogo dvofazan: awready u stanju Waddr,
  // wready u stanju Wdata.  Ako se ikada oba dignu u istom taktu, znaci da se
  // vratilo staro ponasanje u kome je W mogao biti prihvacen pre AW -- upravo
  // bug koji ovo okruzenje cuva da se ne vrati.
  property p_nikad_oba_ready;
    @(posedge clk) disable iff (!rstn) !(awready && wready);
  endproperty
  a_nikad_oba_ready: assert property (p_nikad_oba_ready)
    else $error("AXI-Lite S00: awready i wready istovremeno -- vratio se AW/W bug");

endinterface : axi_lite_if
