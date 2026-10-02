// Scoreboard -- slusa iskljucivo monitore, senka memorije nastaje iz onoga
// sto je vidjeno na magistrali.
//
// Tok:
//   1. upisi u S01 regione slike i sablona pune senku
//   2. upisi u registre dimenzija pamte konfiguraciju
//   3. upis u REG_CTRL sa bitom 0 pokrece racunanje predikcije
//   4. citanja iz S01 regiona rezultata porede se sa predikcijom
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
