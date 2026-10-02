// Slucajna sekvenca (Korak 6).
class ncc_random_seq extends ncc_virtual_base_seq;
  `uvm_object_utils(ncc_random_seq)

  rand int unsigned iw, ih, tw, th;
  rand int unsigned br_burstova;

  constraint c_ugovor {
    iw inside {[2:24]};  ih inside {[2:24]};      // U1: 1..90
    tw inside {[1:6]};   th inside {[1:6]};       // U2: 1..30
    tw * th <= MAX_TMP_PIX;                       // U3
    tw <= iw;  th <= ih;                          // U4
  }
  constraint c_burstovi { br_burstova inside {[3:8]}; }

  localparam time CUVAR = 5ms;

  function new(string name = "ncc_random_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] slika[], sablon[], odbaci[];
    bit [31:0] status;
    bit gotovo = 1'b0;

    if (!this.randomize())
      `uvm_fatal("RAND", "randomizacija slucajne sekvence nije uspela")

    `uvm_info("RND", $sformatf("skup %0dx%0d / %0dx%0d, %0d dodatnih burstova",
                               iw, ih, tw, th, br_burstova), UVM_LOW)

    // --- podaci -------------------------------------------------------------
    slika = new[iw * ih];
    foreach (slika[i]) slika[i] = $urandom_range(0, 255);
    mem_upisi_deljeno(REGION_IMG, 13'd0, slika,
                      aw_w_order_e'($urandom_range(0, 2)));

    sablon = new[tw * th];
    foreach (sablon[i]) sablon[i] = $urandom_range(0, 255);
    mem_upisi_deljeno(REGION_TMP, 13'd0, sablon,
                      aw_w_order_e'($urandom_range(0, 2)));

    // --- slucajni burstovi po svim regionima --------------------------------
    for (int b = 0; b < br_burstova; b++) begin
      ncc_mem_item it = ncc_mem_item::type_id::create("rnd");
      start_item(it, -1, p_sequencer.axif_sqr);
      if (!it.randomize() with {
            rw == MEM_READ;
            len inside {[1:32]};
            region inside {REGION_IMG, REGION_TMP, REGION_NONE};
            word inside {[0:1023]};
          })
        `uvm_fatal("RAND", "randomizacija slucajnog bursta nije uspela")
      finish_item(it);
    end

    // --- slucajni upisi u registre koje jezgro ne koristi -------------------
    for (int r = 0; r < 4; r++) begin
      int unsigned k = $urandom_range(0, 7);
      bit [31:0] v = $urandom();
      reg_upisi(REG_SCRATCH[k], v, aw_w_order_e'($urandom_range(0, 2)));
    end

    // --- pokretanje i provera -------------------------------------------------
    reg_upisi(REG_IMG_W, iw, aw_w_order_e'($urandom_range(0, 2)));
    reg_upisi(REG_IMG_H, ih, aw_w_order_e'($urandom_range(0, 2)));
    reg_upisi(REG_TMP_W, tw, aw_w_order_e'($urandom_range(0, 2)));
    reg_upisi(REG_TMP_H, th, aw_w_order_e'($urandom_range(0, 2)));
    reg_upisi(REG_CTRL,  32'h1, aw_w_order_e'($urandom_range(0, 2)));

    fork
      begin : cekanje
        forever begin
          reg_procitaj(REG_STATUS, status);
          if (status[STATUS_DONE_BIT]) begin gotovo = 1'b1; break; end
        end
      end
      begin : cuvar
        #CUVAR;
        `uvm_error("RND", $sformatf("skup %0dx%0d / %0dx%0d nije zavrsio",
                                    iw, ih, tw, th))
      end
    join_any
    disable fork;

    if (!gotovo) return;

    mem_procitaj_deljeno(REGION_RESULT, 13'd0,
                         (iw - tw + 1) * (ih - th + 1), odbaci);
    `uvm_info("RND", $sformatf("mapa %0d vrednosti provere na scoreboard-u",
                               odbaci.size()), UVM_LOW)
  endtask

endclass : ncc_random_seq
