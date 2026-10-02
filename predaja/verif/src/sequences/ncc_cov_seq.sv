// Sekvenca za pokrivenost (Korak 5).
class ncc_cov_seq extends ncc_virtual_base_seq;
  `uvm_object_utils(ncc_cov_seq)

  localparam int SLIKA_RECI  = 400;
  localparam int SABLON_RECI = 30;
  localparam time CUVAR = 5ms;

  function new(string name = "ncc_cov_seq");
    super.new(name);
  endfunction

  // dok_je_busy: procita STATUS pa jos jednom upise CTRL.start (test T7).
  task pokreni_skup(int unsigned iw, int unsigned ih,
                    int unsigned tw, int unsigned th,
                    bit dok_je_busy = 1'b0);
    bit [31:0] status;
    bit gotovo = 1'b0;

    reg_upisi(REG_IMG_W, iw, ORDER_AW_FIRST);
    reg_upisi(REG_IMG_H, ih, ORDER_W_FIRST);
    reg_upisi(REG_TMP_W, tw, ORDER_SIMUL);
    reg_upisi(REG_TMP_H, th, ORDER_AW_FIRST);
    reg_upisi(REG_CTRL,  32'h1, ORDER_W_FIRST);

    if (dok_je_busy) begin
      reg_procitaj(REG_STATUS, status);
      if (!status[STATUS_BUSY_BIT])
        `uvm_warning("COVSEQ", "jezgro vise nije busy -- T7 nije pogodjen")
      reg_upisi(REG_CTRL, 32'h1, ORDER_SIMUL);
    end

    fork
      begin : cekanje
        forever begin
          reg_procitaj(REG_STATUS, status);
          if (status[STATUS_DONE_BIT]) begin gotovo = 1'b1; break; end
        end
      end
      begin : cuvar
        #CUVAR;
        `uvm_error("COVSEQ", $sformatf("skup %0dx%0d / %0dx%0d nije zavrsio",
                                       iw, ih, tw, th))
      end
    join_any
    disable fork;

    if (gotovo)
      `uvm_info("COVSEQ", $sformatf("skup %0dx%0d / %0dx%0d zavrsen%s",
                iw, ih, tw, th, dok_je_busy ? " (uz ponovni start dok je busy)" : ""),
                UVM_LOW)
  endtask

  task body();
    bit [31:0] slika[], sablon[], odbaci[];

    // --- podaci --------------------------------------------------------------
    slika = new[256];
    foreach (slika[i]) slika[i] = (i * 37 + 11) & 32'hFF;
    mem_upisi(REGION_IMG, 13'd0, slika, ORDER_AW_FIRST);

    slika = new[SLIKA_RECI - 256];
    foreach (slika[i]) slika[i] = ((i + 256) * 37 + 11) & 32'hFF;
    mem_upisi(REGION_IMG, 13'd256, slika, ORDER_W_FIRST);

    sablon = new[SABLON_RECI];
    foreach (sablon[i]) sablon[i] = (i * 53 + 7) & 32'hFF;
    mem_upisi(REGION_TMP, 13'd0, sablon, ORDER_SIMUL);
    mem_upisi(REGION_TMP, 13'd0, sablon, ORDER_W_FIRST);

    // --- duzine burst-a: 1, 2, 3-15, 16-255 -----------------------------------
    begin
      bit [31:0] b[];
      b = new[1];  b[0] = 32'h11;                  mem_upisi(REGION_IMG, 13'd300, b, ORDER_W_FIRST);
      b = new[2];  foreach (b[i]) b[i] = i + 1;    mem_upisi(REGION_IMG, 13'd310, b, ORDER_SIMUL);
      b = new[3];  foreach (b[i]) b[i] = i + 1;    mem_upisi(REGION_IMG, 13'd320, b, ORDER_AW_FIRST);
      b = new[16]; foreach (b[i]) b[i] = i + 1;    mem_upisi(REGION_IMG, 13'd330, b, ORDER_W_FIRST);
    end

    // --- wstrb ---------------------------------------------------------------
    begin
      bit [31:0] b[], pre_upisa[], posle[];
      b = new[1];

      b[0] = 32'h5A; mem_upisi(REGION_IMG, 13'd340, b, ORDER_AW_FIRST, 4'h1);
      b[0] = 32'h5B; mem_upisi(REGION_IMG, 13'd341, b, ORDER_W_FIRST,  4'h3);
      b[0] = 32'h5C; mem_upisi(REGION_IMG, 13'd342, b, ORDER_SIMUL,    4'h9);

      mem_procitaj(REGION_IMG, 13'd343, 1, pre_upisa);
      b[0] = 32'hA5; mem_upisi(REGION_IMG, 13'd343, b, ORDER_AW_FIRST, 4'hE);
      mem_procitaj(REGION_IMG, 13'd343, 1, posle);
      if (posle[0] !== pre_upisa[0])
        `uvm_error("COVSEQ", $sformatf(
          "WSTRB=0xE je ipak upisao: pre 0x%08x, posle 0x%08x",
          pre_upisa[0], posle[0]))
      else
        `uvm_info("COVSEQ", "WSTRB(0)=0 ne menja memoriju, kako RTL i propisuje",
                  UVM_LOW)
    end

    // --- regioni koji se inace ne diraju, u sva tri redosleda -----------------
    begin
      bit [31:0] b[];
      b = new[2]; b[0] = 32'hDEAD; b[1] = 32'hBEEF;
      mem_upisi(REGION_RESULT, 13'd0, b, ORDER_AW_FIRST);
      mem_upisi(REGION_RESULT, 13'd2, b, ORDER_W_FIRST);
      mem_upisi(REGION_RESULT, 13'd4, b, ORDER_SIMUL);
      mem_upisi(REGION_NONE, 13'd0, b, ORDER_AW_FIRST);
      mem_upisi(REGION_NONE, 13'd2, b, ORDER_W_FIRST);
      mem_upisi(REGION_NONE, 13'd4, b, ORDER_SIMUL);
      mem_procitaj(REGION_NONE, 13'd0, 2, odbaci);
      foreach (odbaci[i])
        if (odbaci[i] !== 32'h0)
          `uvm_error("COVSEQ", $sformatf(
            "nemapirani region: ocekivano 0x00000000, dobijeno 0x%08x", odbaci[i]))
      mem_procitaj(REGION_TMP, 13'(TMP_WORDS), 4, odbaci);   // aliasing, T14
    end

    // --- skupovi dimenzija -----------------------------------------------------
    pokreni_skup( 1,  1,  1,  1);
    pokreni_skup(20, 20,  5,  5);
    pokreni_skup(45,  1, 15,  1);
    pokreni_skup( 1, 45,  1, 15);
    pokreni_skup(90,  1, 30,  1);
    pokreni_skup( 1, 90,  1, 30);
    pokreni_skup(60,  2, 20,  2, 1'b1);
    pokreni_skup( 2, 60,  2, 20);

    mem_procitaj(REGION_RESULT, 13'd0, 8, odbaci);
  endtask

endclass : ncc_cov_seq
