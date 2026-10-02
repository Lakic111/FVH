// Kolektor pokrivenosti -- zaseban od scoreboard-a, vezan na iste monitore.
//
// busy/done_sticky su bitovi registra STATUS, vidljivi samo kroz citanje;
// ukrstanje start x busy se zato uzorkuje na upis u REG_CTRL, sa vrednoscu
// busy iz poslednjeg procitanog statusa.
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
