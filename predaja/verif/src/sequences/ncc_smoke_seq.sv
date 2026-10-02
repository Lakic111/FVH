// Smoke sekvenca -- ceo put kroz DUT (S01 -> S00 -> start -> done_sticky -> rezultat).
class ncc_smoke_seq extends ncc_virtual_base_seq;
  `uvm_object_utils(ncc_smoke_seq)

  localparam int IMG_W = 4;
  localparam int IMG_H = 4;
  localparam int TMP_W = 2;
  localparam int TMP_H = 2;
  localparam int RES_W = IMG_W - TMP_W + 1;   // 3
  localparam int RES_H = IMG_H - TMP_H + 1;   // 3

  localparam time CUVAR = 500us;

  int unsigned gresaka   = 0;
  bit          video_busy = 1'b0;

  function new(string name = "ncc_smoke_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] slika[], sablon[], rezultat[];
    bit [31:0] status;
    bit        gotovo = 1'b0;

    // --- 1. slika i sablon preko S01 ---------------------------------------
    // Skup ima tacno jedan pik: sablon je doslovno prozor na (u=1, v=1).
    slika = new[IMG_W * IMG_H];
    slika[0]  =  10; slika[1]  = 200; slika[2]  =  30; slika[3]  =  90;
    slika[4]  = 250; slika[5]  =  20; slika[6]  = 140; slika[7]  =  60;
    slika[8]  =  70; slika[9]  = 180; slika[10] =  25; slika[11] = 210;
    slika[12] = 120; slika[13] =  40; slika[14] = 160; slika[15] =  80;
    mem_upisi(REGION_IMG, 13'd0, slika, ORDER_AW_FIRST);

    sablon = new[TMP_W * TMP_H];
    sablon[0] =  20; sablon[1] = 140;
    sablon[2] = 180; sablon[3] =  25;
    mem_upisi(REGION_TMP, 13'd0, sablon, ORDER_W_FIRST);

    `uvm_info("SMOKE", "slika i sablon upisani u S01", UVM_LOW)

    // --- 2. dimenzije preko S00 --------------------------------------------
    reg_upisi(REG_IMG_W, IMG_W, ORDER_AW_FIRST);
    reg_upisi(REG_IMG_H, IMG_H, ORDER_W_FIRST);
    reg_upisi(REG_TMP_W, TMP_W, ORDER_SIMUL);
    reg_upisi(REG_TMP_H, TMP_H, ORDER_AW_FIRST);

    // --- 3. pokretanje -------------------------------------------------------
    reg_upisi(REG_CTRL, 32'h1, ORDER_W_FIRST);
    `uvm_info("SMOKE", "CTRL.start postavljen", UVM_LOW)

    // --- 4. cekanje na done_sticky, sa nadzornim brojacem -------------------
    fork
      begin : cekanje
        forever begin
          reg_procitaj(REG_STATUS, status);
          if (status[STATUS_BUSY_BIT]) video_busy = 1'b1;
          if (status[STATUS_DONE_BIT]) begin
            gotovo = 1'b1;
            break;
          end
        end
      end
      begin : cuvar
        #CUVAR;
        `uvm_error("SMOKE", $sformatf(
          "done_sticky nije stigao za %0t -- DUT visi ili ne racuna", CUVAR))
        gresaka++;
      end
    join_any
    disable fork;

    if (!gotovo) return;
    `uvm_info("SMOKE", "done_sticky postavljen", UVM_LOW)

    if (!video_busy)
      `uvm_warning("SMOKE", "busy nije uhvacen nijednim citanjem statusa")

    // --- 5. rezultat sa S01 -------------------------------------------------
    mem_procitaj(REGION_RESULT, 13'd0, RES_W * RES_H, rezultat);

    foreach (rezultat[i]) begin
      if (^rezultat[i] === 1'bx) begin
        `uvm_error("SMOKE", $sformatf("rezultat[%0d] sadrzi X: 0x%08x", i, rezultat[i]))
        gresaka++;
      end
      `uvm_info("SMOKE", $sformatf("rezultat[%0d] (u=%0d, v=%0d) = 0x%08x",
                                   i, i % RES_W, i / RES_W, rezultat[i]), UVM_LOW)
    end

    // Puna provera svih devet vrednosti je Korak 4 (scoreboard).
    begin
      int unsigned pik = 1 * RES_W + 1;
      if (rezultat[pik] !== 32'h8000_0000) begin
        `uvm_error("SMOKE", $sformatf(
          "na (1,1) sablon je jednak prozoru: ocekivano 0x80000000, dobijeno 0x%08x",
          rezultat[pik]))
        gresaka++;
      end
      foreach (rezultat[i])
        if (i != pik && rezultat[i] >= rezultat[pik]) begin
          `uvm_error("SMOKE", $sformatf(
            "rezultat[%0d] = 0x%08x nije manji od pika 0x%08x -- mapa je ravna",
            i, rezultat[i], rezultat[pik]))
          gresaka++;
        end
    end

    if (gresaka == 0)
      `uvm_info("SMOKE", "ceo put kroz DUT prosao: S01 -> S00 -> start -> done -> rezultat",
                UVM_LOW)
  endtask

endclass : ncc_smoke_seq
