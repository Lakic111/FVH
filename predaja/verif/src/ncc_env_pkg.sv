// Okruzenje, scoreboard, coverage, virtuelni sekvencer i sekvence.
package ncc_env_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ncc_verif_pkg::*;
  import ncc_axil_pkg::*;
  import ncc_axif_pkg::*;
  import ncc_ref_pkg::*;

  `uvm_analysis_imp_decl(_reg)
  `uvm_analysis_imp_decl(_mem)

  // --------------------------------------------------------------------------
  // Scoreboard -- slusa iskljucivo monitore, senka memorije nastaje iz onoga
  // sto je vidjeno na magistrali.
  //
  // Tok:
  //   1. upisi u S01 regione slike i sablona pune senku
  //   2. upisi u registre dimenzija pamte konfiguraciju
  //   3. upis u REG_CTRL sa bitom 0 pokrece racunanje predikcije
  //   4. citanja iz S01 regiona rezultata porede se sa predikcijom
  // --------------------------------------------------------------------------
  class ncc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ncc_scoreboard)

    uvm_analysis_imp_reg #(ncc_reg_item, ncc_scoreboard) reg_imp;
    uvm_analysis_imp_mem #(ncc_mem_item, ncc_scoreboard) mem_imp;

    protected bit [7:0]  senka_slika[int];
    protected bit [7:0]  senka_sablon[int];
    protected bit [31:0] predikcija[int];

    protected int unsigned img_w, img_h, tmp_w, tmp_h;
    protected bit          ima_predikciju = 1'b0;
    protected bit          video_done     = 1'b0;

    int unsigned br_poredjenja = 0;
    int unsigned br_gresaka    = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      reg_imp = new("reg_imp", this);
      mem_imp = new("mem_imp", this);
    endfunction

    // --- ulaz sa S00 ---------------------------------------------------------
    function void write_reg(ncc_reg_item t);
      if (t.rw == REG_WRITE) begin
        case (t.addr)
          REG_IMG_W: img_w = t.data[7:0];
          REG_IMG_H: img_h = t.data[7:0];
          REG_TMP_W: tmp_w = t.data[7:0];
          REG_TMP_H: tmp_h = t.data[7:0];
          REG_CTRL:  if (t.data[CTRL_START_BIT]) pokreni();
          default: ;
        endcase
      end else if (t.addr == REG_STATUS && t.data[STATUS_DONE_BIT]) begin
        video_done = 1'b1;
      end
    endfunction

    // --- ulaz sa S01 ---------------------------------------------------------
    function void write_mem(ncc_mem_item t);
      if (t.rw == MEM_WRITE) begin
        // RTL: mem_we_o <= wr_beat and WSTRB(0) -- upis sa spustenim bitom 0
        // ne menja memoriju, pa ni senka ne sme.
        if (!t.strb[0]) return;

        case (t.region)
          REGION_IMG: foreach (t.data[i]) senka_slika [t.word + i] = t.data[i][7:0];
          REGION_TMP: foreach (t.data[i])
                        senka_sablon[(t.word + i) % TMP_WORDS] = t.data[i][7:0];
          REGION_RESULT: ;   // samo citanje (P1) -- upis se tiho zanemaruje
          default: ;
        endcase
      end else if (t.region == REGION_RESULT) begin
        uporedi(t);
      end
    endfunction

    // --- predikcija ----------------------------------------------------------
    protected function void pokreni();
      bit [7:0]  slika[], sablon[];
      bit [31:0] mapa[];

      if (img_w == 0 || img_h == 0 || tmp_w == 0 || tmp_h == 0) begin
        `uvm_warning("SB", "pokretanje pre nego sto su sve dimenzije upisane")
        return;
      end

      slika  = new[img_w * img_h];
      sablon = new[tmp_w * tmp_h];
      foreach (slika[i])  slika[i]  = senka_slika.exists(i)  ? senka_slika[i]  : 8'h00;
      foreach (sablon[i]) sablon[i] = senka_sablon.exists(i) ? senka_sablon[i] : 8'h00;

      ncc_predikcija(img_w, img_h, tmp_w, tmp_h, slika, sablon, mapa);

      predikcija.delete();
      foreach (mapa[i]) predikcija[i] = mapa[i];
      ima_predikciju = 1'b1;
      video_done     = 1'b0;

      `uvm_info("SB", $sformatf(
        "predikcija spremna: slika %0dx%0d, sablon %0dx%0d, mapa %0d vrednosti",
        img_w, img_h, tmp_w, tmp_h, mapa.size()), UVM_LOW)
    endfunction

    // --- poredjenje ----------------------------------------------------------
    protected function void uporedi(ncc_mem_item t);
      if (!ima_predikciju) begin
        `uvm_warning("SB", "citanje rezultata pre nego sto je jezgro pokrenuto")
        return;
      end
      if (!video_done)
        `uvm_warning("SB", "rezultat se cita, a done_sticky jos nije vidjen")

      foreach (t.data[i]) begin
        int unsigned idx = t.word + i;
        bit [31:0] ocekivano;

        if (!predikcija.exists(idx)) continue;

        ocekivano = predikcija[idx];
        br_poredjenja++;

        if (t.data[i] !== ocekivano) begin
          br_gresaka++;
          `uvm_error("SB", $sformatf(
            "rezultat[%0d] (u=%0d, v=%0d): ocekivano 0x%08x, dobijeno 0x%08x",
            idx, idx % (img_w - tmp_w + 1), idx / (img_w - tmp_w + 1),
            ocekivano, t.data[i]))
        end else begin
          `uvm_info("SB", $sformatf("rezultat[%0d] = 0x%08x, slaze se",
                                    idx, t.data[i]), UVM_HIGH)
        end
      end
    endfunction

    // --- zavrsna provera -----------------------------------------------------
    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (br_poredjenja == 0)
        `uvm_error("SB", "scoreboard nije izvrsio nijedno poredjenje")
      else
        `uvm_info("SB", $sformatf("%0d poredjenja, %0d neslaganja",
                                  br_poredjenja, br_gresaka), UVM_LOW)
    endfunction

  endclass : ncc_scoreboard

  `uvm_analysis_imp_decl(_covreg)
  `uvm_analysis_imp_decl(_covmem)

  typedef enum { COV_S00, COV_S01_IMG, COV_S01_TMP, COV_S01_RES, COV_S01_NONE }
    cov_region_e;

  // --------------------------------------------------------------------------
  // Kolektor pokrivenosti -- zaseban od scoreboard-a, vezan na iste monitore.
  //
  // busy/done_sticky su bitovi registra STATUS, vidljivi samo kroz citanje;
  // ukrstanje start x busy se zato uzorkuje na upis u REG_CTRL, sa vrednoscu
  // busy iz poslednjeg procitanog statusa.
  // --------------------------------------------------------------------------
  class ncc_coverage extends uvm_component;
    `uvm_component_utils(ncc_coverage)

    uvm_analysis_imp_covreg #(ncc_reg_item, ncc_coverage) reg_imp;
    uvm_analysis_imp_covmem #(ncc_mem_item, ncc_coverage) mem_imp;

    protected int unsigned img_w, img_h, tmp_w, tmp_h;
    protected bit          zadnji_busy = 1'b0;
    protected bit          zadnji_done = 1'b0;

    // --- dimenzije -----------------------------------------------------------
    covergroup cg_dimenzije with function sample(
        int unsigned iw, int unsigned ih, int unsigned tw, int unsigned th);
      option.per_instance = 1;

      cp_img_w: coverpoint iw {
        bins min    = {1};
        bins ispod  = {[2:44]};
        bins coarse = {45};
        bins iznad  = {[46:89]};
        bins max    = {90};
      }
      cp_img_h: coverpoint ih {
        bins min = {1}; bins ispod = {[2:44]}; bins coarse = {45};
        bins iznad = {[46:89]}; bins max = {90};
      }
      cp_tmp_w: coverpoint tw {
        bins min = {1}; bins ispod = {[2:14]}; bins coarse = {15};
        bins iznad = {[16:29]}; bins max = {30};
      }
      cp_tmp_h: coverpoint th {
        bins min = {1}; bins ispod = {[2:14]}; bins coarse = {15};
        bins iznad = {[16:29]}; bins max = {30};
      }

      // U4 (tmp <= img) cini kombinacije velikog sablona sa malom slikom nedostiznim.
      x_img_tmp: cross cp_img_w, cp_tmp_w {
        ignore_bins nemoguce_min =
          binsof(cp_img_w.min) && !binsof(cp_tmp_w.min);
        ignore_bins nemoguce_ispod =
          binsof(cp_img_w.ispod) && (binsof(cp_tmp_w.iznad) || binsof(cp_tmp_w.max));
      }
    endgroup

    // --- kontrola ------------------------------------------------------------
    covergroup cg_kontrola with function sample(bit start, bit busy, bit done);
      option.per_instance = 1;

      cp_start: coverpoint start { bins ne = {0}; bins da = {1}; }
      cp_busy:  coverpoint busy  { bins ne = {0}; bins da = {1}; }
      cp_done:  coverpoint done  { bins ne = {0}; bins da = {1}; }

      // (start=1, busy=1) je test T7: pokretanje dok jezgro radi (nije zasticeno u RTL-u).
      x_start_busy: cross cp_start, cp_busy;
      x_start_done: cross cp_start, cp_done;
    endgroup

    // --- AXI -----------------------------------------------------------------
    covergroup cg_axi with function sample(
        aw_w_order_e ord, cov_region_e reg_o, int unsigned blen, bit [3:0] strb);
      option.per_instance = 1;

      cp_order:  coverpoint ord;
      cp_region: coverpoint reg_o;

      // Sredisnji cilj plana: AW/W bug proveren u svakom regionu.
      x_order_region: cross cp_order, cp_region;

      cp_len: coverpoint blen {
        bins b1      = {1};
        bins b2      = {2};
        bins b3_15   = {[3:15]};
        bins b16_255 = {[16:255]};
        bins b256    = {256};
      }
      cp_strb: coverpoint strb {
        bins puna = {4'hF};
        bins b1   = {4'h1};
        bins b3   = {4'h3};
        bins b9   = {4'h9};
        bins ostalo = default;
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      reg_imp     = new("reg_imp", this);
      mem_imp     = new("mem_imp", this);
      cg_dimenzije = new();
      cg_kontrola  = new();
      cg_axi       = new();
    endfunction

    function void write_covreg(ncc_reg_item t);
      if (t.rw == REG_WRITE) begin
        case (t.addr)
          REG_IMG_W: img_w = t.data[7:0];
          REG_IMG_H: img_h = t.data[7:0];
          REG_TMP_W: tmp_w = t.data[7:0];
          REG_TMP_H: tmp_h = t.data[7:0];
          REG_CTRL: begin
            cg_dimenzije.sample(img_w, img_h, tmp_w, tmp_h);
            cg_kontrola.sample(t.data[CTRL_START_BIT], zadnji_busy, zadnji_done);
          end
          default: ;
        endcase
        cg_axi.sample(t.order, COV_S00, 1, t.strb);
      end else begin
        if (t.addr == REG_STATUS) begin
          zadnji_busy = t.data[STATUS_BUSY_BIT];
          zadnji_done = t.data[STATUS_DONE_BIT];
          cg_kontrola.sample(1'b0, zadnji_busy, zadnji_done);
        end
      end
    endfunction

    function void write_covmem(ncc_mem_item t);
      cov_region_e r;
      case (t.region)
        REGION_IMG:    r = COV_S01_IMG;
        REGION_TMP:    r = COV_S01_TMP;
        REGION_RESULT: r = COV_S01_RES;
        default:       r = COV_S01_NONE;
      endcase
      if (t.rw == MEM_WRITE)
        cg_axi.sample(t.order, r, t.len, t.strb);
      else
        cg_axi.sample(t.order, r, t.len, 4'hF);
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("COV", $sformatf(
        "pokrivenost: dimenzije %.1f%%, kontrola %.1f%%, AXI %.1f%%, ukupno %.1f%%",
        cg_dimenzije.get_coverage(), cg_kontrola.get_coverage(),
        cg_axi.get_coverage(),
        (cg_dimenzije.get_coverage() + cg_kontrola.get_coverage()
         + cg_axi.get_coverage()) / 3.0), UVM_LOW)
    endfunction

  endclass : ncc_coverage

  // --------------------------------------------------------------------------
  // Virtuelni sekvencer -- drzi pokazivace na oba stvarna sekvencera.
  // --------------------------------------------------------------------------
  class ncc_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(ncc_virtual_sequencer)

    ncc_axil_sequencer axil_sqr;
    ncc_axif_sequencer axif_sqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass : ncc_virtual_sequencer

  // --------------------------------------------------------------------------
  // Okruzenje
  // --------------------------------------------------------------------------
  class ncc_env extends uvm_env;
    `uvm_component_utils(ncc_env)

    ncc_axil_agent        axil_agent;
    ncc_axif_agent        axif_agent;
    ncc_virtual_sequencer vsqr;
    ncc_scoreboard        sb;
    ncc_coverage          cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      axil_agent = ncc_axil_agent       ::type_id::create("axil_agent", this);
      axif_agent = ncc_axif_agent       ::type_id::create("axif_agent", this);
      vsqr       = ncc_virtual_sequencer::type_id::create("vsqr", this);
      sb         = ncc_scoreboard       ::type_id::create("sb", this);
      cov        = ncc_coverage         ::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      vsqr.axil_sqr = axil_agent.sqr;
      vsqr.axif_sqr = axif_agent.sqr;
      // Scoreboard i coverage se vezuju na portove AGENATA (monitore), nikad drajvere.
      axil_agent.ap.connect(sb.reg_imp);
      axif_agent.ap.connect(sb.mem_imp);
      axil_agent.ap.connect(cov.reg_imp);
      axif_agent.ap.connect(cov.mem_imp);
    endfunction

  endclass : ncc_env

  // --------------------------------------------------------------------------
  // Osnova virtuelnih sekvenci
  // --------------------------------------------------------------------------
  class ncc_virtual_base_seq extends uvm_sequence;
    `uvm_object_utils(ncc_virtual_base_seq)
    `uvm_declare_p_sequencer(ncc_virtual_sequencer)

    function new(string name = "ncc_virtual_base_seq");
      super.new(name);
    endfunction

    task reg_upisi(bit [S00_ADDR_W-1:0] a, bit [S00_DATA_W-1:0] d,
                   aw_w_order_e o = ORDER_AW_FIRST);
      ncc_reg_item it = ncc_reg_item::type_id::create("reg_w");
      bit ok;
      start_item(it, -1, p_sequencer.axil_sqr);
      if (o == ORDER_SIMUL)
        ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE; order == o; };
      else
        ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                   order == o; gap == 1; };
      if (!ok) `uvm_fatal("RAND", "randomizacija upisa u registar nije uspela")
      finish_item(it);
    endtask

    task reg_procitaj(bit [S00_ADDR_W-1:0] a, output bit [S00_DATA_W-1:0] d);
      ncc_reg_item it = ncc_reg_item::type_id::create("reg_r");
      start_item(it, -1, p_sequencer.axil_sqr);
      if (!it.randomize() with { addr == a; rw == REG_READ; })
        `uvm_fatal("RAND", "randomizacija citanja registra nije uspela")
      finish_item(it);
      d = it.data;
    endtask

    task mem_upisi(input region_e r, input bit [12:0] w,
                   const ref bit [31:0] d[],
                   input aw_w_order_e o = ORDER_AW_FIRST,
                   input bit [3:0] st = 4'hF);
      ncc_mem_item it = ncc_mem_item::type_id::create("mem_w");
      bit ok;
      start_item(it, -1, p_sequencer.axif_sqr);
      if (o == ORDER_SIMUL)
        ok = it.randomize() with { region == r; word == w; len == d.size();
                                   rw == MEM_WRITE; order == o; strb == st; };
      else
        ok = it.randomize() with { region == r; word == w; len == d.size();
                                   rw == MEM_WRITE; order == o; gap == 1;
                                   strb == st; };
      if (!ok) `uvm_fatal("RAND", "randomizacija upisa u memoriju nije uspela")
      foreach (d[i]) it.data[i] = d[i];
      finish_item(it);
    endtask

    task mem_procitaj(input region_e r, input bit [12:0] w, input int unsigned n,
                      ref bit [31:0] d[]);
      ncc_mem_item it = ncc_mem_item::type_id::create("mem_r");
      start_item(it, -1, p_sequencer.axif_sqr);
      if (!it.randomize() with { region == r; word == w; len == n;
                                 rw == MEM_READ; order == ORDER_AW_FIRST; })
        `uvm_fatal("RAND", "randomizacija citanja memorije nije uspela")
      finish_item(it);
      d = new[it.data.size()];
      foreach (it.data[i]) d[i] = it.data[i];
    endtask

    // --- veliki blokovi ------------------------------------------------------
    // AXI dozvoljava najvise 256 beat-ova po burst-u i zabranjuje prelazak
    // granice od 4 KB -- veci blok se deli.
    function automatic int unsigned komad(int unsigned w, int unsigned ostalo);
      int unsigned do_granice = 1024 - (w % 1024);
      int unsigned k = 256;
      if (ostalo     < k) k = ostalo;
      if (do_granice < k) k = do_granice;
      return k;
    endfunction

    task mem_upisi_deljeno(input region_e r, input bit [12:0] w,
                           const ref bit [31:0] d[],
                           input aw_w_order_e o = ORDER_AW_FIRST,
                           input bit [3:0] st = 4'hF);
      int unsigned poz = 0;
      while (poz < d.size()) begin
        int unsigned k = komad(w + poz, d.size() - poz);
        bit [31:0] deo[];
        deo = new[k];
        for (int i = 0; i < k; i++) deo[i] = d[poz + i];
        mem_upisi(r, 13'(w + poz), deo, o, st);
        poz += k;
      end
    endtask

    task mem_procitaj_deljeno(input region_e r, input bit [12:0] w,
                              input int unsigned n, ref bit [31:0] d[]);
      int unsigned poz = 0;
      d = new[n];
      while (poz < n) begin
        int unsigned k = komad(w + poz, n - poz);
        bit [31:0] deo[];
        mem_procitaj(r, 13'(w + poz), k, deo);
        for (int i = 0; i < k; i++) d[poz + i] = deo[i];
        poz += k;
      end
    endtask

  endclass : ncc_virtual_base_seq

  // --------------------------------------------------------------------------
  // Smoke sekvenca -- ceo put kroz DUT.
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Sekvenca za pokrivenost (Korak 5).
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Prelaz preko svih legalnih kombinacija bin-ova dimenzija (Korak 5, spora lista).
  // --------------------------------------------------------------------------
  class ncc_dim_sweep_seq extends ncc_cov_seq;
    `uvm_object_utils(ncc_dim_sweep_seq)

    function new(string name = "ncc_dim_sweep_seq");
      super.new(name);
    endfunction

    task body();
      bit [31:0] slika[], sablon[], odbaci[];
      int unsigned iw[19] = '{ 1,
                              20, 20, 20,
                              45, 45, 45, 45, 45,
                              60, 60, 60, 60, 60,
                              90, 90, 90, 90, 90 };
      int unsigned tw[19] = '{ 1,
                               1,  5, 15,
                               1,  5, 15, 20, 30,
                               1,  5, 15, 20, 30,
                               1,  5, 15, 20, 30 };

      slika = new[256];
      foreach (slika[i]) slika[i] = (i * 37 + 11) & 32'hFF;
      mem_upisi(REGION_IMG, 13'd0, slika, ORDER_AW_FIRST);

      sablon = new[SABLON_RECI];
      foreach (sablon[i]) sablon[i] = (i * 53 + 7) & 32'hFF;
      mem_upisi(REGION_TMP, 13'd0, sablon, ORDER_AW_FIRST);

      foreach (iw[k]) pokreni_skup(iw[k], 1, tw[k], 1);

      mem_procitaj(REGION_RESULT, 13'd0, 8, odbaci);
    endtask

  endclass : ncc_dim_sweep_seq

  // --------------------------------------------------------------------------
  // Slucajna sekvenca (Korak 6).
  // --------------------------------------------------------------------------
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

endpackage : ncc_env_pkg
