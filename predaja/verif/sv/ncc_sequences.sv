// Sequences. All of them run on the same sequencer: the transaction itself
// says whether it goes to S00 (registers) or to S01 (memories).

// =========================================================================
// Base sequence -- helper tasks used by the other sequences
// =========================================================================
class ncc_base_seq extends uvm_sequence #(ncc_item);

   `uvm_object_utils(ncc_base_seq)

   function new(string name = "ncc_base_seq");
      super.new(name);
   endfunction

   // Write one S00 register.
   task reg_write(bit [5 : 0] addr, bit [31 : 0] data, order_e ord = ORDER_AW_FIRST);
      ncc_item it;
      it = ncc_item::type_id::create("it");
      start_item(it);
      it.bus     = BUS_S00;
      it.rw      = WRITE;
      it.addr    = addr;
      it.len     = 1;
      it.data    = new[1];
      it.data[0] = data;
      it.strb    = 4'hF;
      if (!it.randomize() with { order == ord; })
         `uvm_fatal("SEQ", "randomization failed")
      finish_item(it);
   endtask : reg_write

   // Read one S00 register.
   task reg_read(bit [5 : 0] addr, output bit [31 : 0] data);
      ncc_item it;
      it = ncc_item::type_id::create("it");
      start_item(it);
      it.bus  = BUS_S00;
      it.rw   = READ;
      it.addr = addr;
      it.len  = 1;
      if (!it.randomize())
         `uvm_fatal("SEQ", "randomization failed")
      finish_item(it);
      data = it.data[0];
   endtask : reg_read

   // How many words may go into one burst starting at word 'word': at most 256 beats
   // and without crossing a 4 KB boundary (1024 words).
   function int unsigned burst_len(int unsigned word, int unsigned remaining);
      int unsigned k;
      k = remaining;
      if (k > 256) k = 256;
      if (k > 1024 - (word % 1024)) k = 1024 - (word % 1024);
      return k;
   endfunction

   // Write an array of words to an S01 region, starting at word 'word'. A larger array is split into bursts.
   task mem_write(int region, int unsigned word, bit [31 : 0] d[],
                  order_e ord = ORDER_AW_FIRST, bit [3 : 0] strb = 4'hF);
      ncc_item it;
      int unsigned pos = 0;
      int unsigned k;
      while (pos < d.size()) begin
         k  = burst_len(word + pos, d.size() - pos);
         it = ncc_item::type_id::create("it");
         start_item(it);
         it.bus  = BUS_S01;
         it.rw   = WRITE;
         it.addr = region * 32768 + (word + pos) * 4;
         it.len  = k;
         it.data = new[k];
         for (int i = 0; i < k; i++) it.data[i] = d[pos + i];
         it.strb = strb;
         if (!it.randomize() with { order == ord; })
            `uvm_fatal("SEQ", "randomization failed")
         finish_item(it);
         pos = pos + k;
      end
   endtask : mem_write

   // Read n words from an S01 region, starting at word 'word'.
   task mem_read(int region, int unsigned word, int unsigned n, output bit [31 : 0] d[]);
      ncc_item it;
      int unsigned pos = 0;
      int unsigned k;
      d = new[n];
      while (pos < n) begin
         k  = burst_len(word + pos, n - pos);
         it = ncc_item::type_id::create("it");
         start_item(it);
         it.bus  = BUS_S01;
         it.rw   = READ;
         it.addr = region * 32768 + (word + pos) * 4;
         it.len  = k;
         if (!it.randomize())
            `uvm_fatal("SEQ", "randomization failed")
         finish_item(it);
         for (int i = 0; i < k; i++) d[pos + i] = it.data[i];
         pos = pos + k;
      end
   endtask : mem_read

   // Read STATUS until the core finishes (done = 1 and busy = 0).
   task wait_done(output bit ok);
      bit [31 : 0] status;
      ok = 0;
      for (int i = 0; i < 200000; i++) begin
         reg_read(REG_STATUS, status);
         if (status[0] == 1 && status[1] == 0) begin
            ok = 1;
            return;
         end
      end
      `uvm_error("SEQ", "the core did not finish -- done never arrived")
   endtask : wait_done

   // Write the dimensions, start, wait and read the whole result map
   // (the scoreboard compares it with the reference model).
   task run_job(int unsigned iw, int unsigned ih, int unsigned tw, int unsigned th);
      bit          ok;
      bit [31 : 0] res[];
      reg_write(REG_IMG_W, iw, ORDER_AW_FIRST);
      reg_write(REG_IMG_H, ih, ORDER_W_FIRST);
      reg_write(REG_TMP_W, tw, ORDER_SIMUL);
      reg_write(REG_TMP_H, th, ORDER_AW_FIRST);
      reg_write(REG_CTRL, 1, ORDER_W_FIRST);
      wait_done(ok);
      if (ok)
         mem_read(REGION_RESULT, 0, (iw - tw + 1) * (ih - th + 1), res);
      `uvm_info("SEQ", $sformatf("job %0dx%0d / %0dx%0d done", iw, ih, tw, th), UVM_LOW)
   endtask : run_job

   // Random AW/W order (for the random test).
   function order_e random_order();
      case ($urandom_range(0, 2))
         0: return ORDER_AW_FIRST;
         1: return ORDER_W_FIRST;
         default: return ORDER_SIMUL;
      endcase
   endfunction

endclass : ncc_base_seq

// =========================================================================
// Smoke: a small 4x4 image and a 2x2 template with one known peak.
// The template equals the image window at (u=1, v=1), so the result there must be 0x80000000.
// =========================================================================
class ncc_smoke_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_smoke_seq)

   function new(string name = "ncc_smoke_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] img[], tmp[], res[];
      bit          ok;

      img = new[16];
      img[0]  =  10; img[1]  = 200; img[2]  =  30; img[3]  =  90;
      img[4]  = 250; img[5]  =  20; img[6]  = 140; img[7]  =  60;
      img[8]  =  70; img[9]  = 180; img[10] =  25; img[11] = 210;
      img[12] = 120; img[13] =  40; img[14] = 160; img[15] =  80;
      mem_write(REGION_IMAGE, 0, img, ORDER_AW_FIRST);

      tmp = new[4];
      tmp[0] =  20; tmp[1] = 140;
      tmp[2] = 180; tmp[3] =  25;
      mem_write(REGION_TEMPLATE, 0, tmp, ORDER_W_FIRST);

      reg_write(REG_IMG_W, 4, ORDER_AW_FIRST);
      reg_write(REG_IMG_H, 4, ORDER_W_FIRST);
      reg_write(REG_TMP_W, 2, ORDER_SIMUL);
      reg_write(REG_TMP_H, 2, ORDER_AW_FIRST);
      reg_write(REG_CTRL, 1, ORDER_W_FIRST);

      wait_done(ok);
      if (!ok) return;

      mem_read(REGION_RESULT, 0, 9, res);
      foreach (res[i])
         `uvm_info("SMOKE", $sformatf("result[%0d] = 0x%08x", i, res[i]), UVM_LOW)

      // peak at (1,1) = index 4; all other values must be smaller
      if (res[4] !== 32'h8000_0000)
         `uvm_error("SMOKE", $sformatf("at (1,1) expected 0x80000000, got 0x%08x", res[4]))
      foreach (res[i])
         if (i != 4 && res[i] >= res[4])
            `uvm_error("SMOKE", $sformatf("result[%0d] = 0x%08x is not smaller than the peak", i, res[i]))
   endtask : body

endclass : ncc_smoke_seq

// =========================================================================
// Coverage: directed cases that close all covergroups and check
// the behaviour of the memories and of the control register.
// =========================================================================
class ncc_cov_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_cov_seq)

   function new(string name = "ncc_cov_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] img[], tmp[], b[], rd[], old_val[], new_val[];
      bit [31 : 0] status;
      bit          ok;
      int unsigned iw[19], tw[19];

      // --- writing 0 to CTRL must not start the core ---
      reg_write(REG_CTRL, 0, ORDER_SIMUL);
      reg_read(REG_STATUS, status);
      if (status[1] == 1)
         `uvm_error("COV", "writing 0 to CTRL started the core")

      // --- image (400 words = burst of 256 + burst of 144) and template ---
      img = new[400];
      foreach (img[i]) img[i] = (i * 37 + 11) % 256;
      mem_write(REGION_IMAGE, 0, img, ORDER_W_FIRST);

      tmp = new[64];
      foreach (tmp[i]) tmp[i] = (i * 53 + 7) % 256;
      mem_write(REGION_TEMPLATE, 0, tmp, ORDER_W_FIRST);
      mem_write(REGION_TEMPLATE, 0, tmp, ORDER_SIMUL);
      mem_write(REGION_TEMPLATE, 0, tmp, ORDER_AW_FIRST);

      // --- the template repeats every 1024 words: word 1024 is the same as word 0 ---
      mem_read(REGION_TEMPLATE, TMP_WORDS, 4, rd);
      foreach (rd[i])
         if (rd[i] !== tmp[i])
            `uvm_error("COV", $sformatf("template word %0d: expected 0x%08x, got 0x%08x",
                                        TMP_WORDS + i, tmp[i], rd[i]))

      // --- the image keeps only the lower 8 bits ---
      b = new[1];
      b[0] = 32'hABCD_EF5A;
      mem_write(REGION_IMAGE, 350, b, ORDER_AW_FIRST);
      mem_read(REGION_IMAGE, 350, 1, rd);
      if (rd[0] !== 32'h0000_005A)
         `uvm_error("COV", $sformatf("image: expected 0x0000005a, got 0x%08x", rd[0]))

      // --- burst lengths 1, 2, 3 and 16 ---
      b = new[1];  b[0] = 8'h11;                  mem_write(REGION_IMAGE, 300, b, ORDER_W_FIRST);
      b = new[2];  foreach (b[i]) b[i] = i + 1;   mem_write(REGION_IMAGE, 310, b, ORDER_SIMUL);
      b = new[3];  foreach (b[i]) b[i] = i + 1;   mem_write(REGION_IMAGE, 320, b, ORDER_AW_FIRST);
      b = new[16]; foreach (b[i]) b[i] = i + 1;   mem_write(REGION_IMAGE, 330, b, ORDER_W_FIRST);

      // --- WSTRB: the write happens only when bit 0 is set ---
      b = new[1];
      b[0] = 8'h5A; mem_write(REGION_IMAGE, 340, b, ORDER_AW_FIRST, 4'h1);
      b[0] = 8'h5B; mem_write(REGION_IMAGE, 341, b, ORDER_W_FIRST,  4'h3);
      b[0] = 8'h5C; mem_write(REGION_IMAGE, 342, b, ORDER_SIMUL,    4'h9);
      mem_read(REGION_IMAGE, 343, 1, old_val);
      b[0] = 8'hA5; mem_write(REGION_IMAGE, 343, b, ORDER_AW_FIRST, 4'hE);
      mem_read(REGION_IMAGE, 343, 1, new_val);
      if (new_val[0] !== old_val[0])
         `uvm_error("COV", "WSTRB = 0xE changed the memory")

      // --- dimensions: all allowed combinations of the width bins ---
      iw = '{ 1, 20, 20, 20, 45, 45, 45, 45, 45, 60, 60, 60, 60, 60, 90, 90, 90, 90, 90 };
      tw = '{ 1,  1,  5, 15,  1,  5, 15, 20, 30,  1,  5, 15, 20, 30,  1,  5, 15, 20, 30 };
      foreach (iw[k]) run_job(iw[k], 1, tw[k], 1);

      // --- and the heights ---
      run_job( 1, 45,  1, 15);
      run_job( 1, 90,  1, 30);
      run_job( 2, 60,  2, 20);
      run_job(60,  2, 20,  2);

      // --- CTRL write while the core is running (test T7) ---
      reg_write(REG_IMG_W, 20, ORDER_AW_FIRST);
      reg_write(REG_IMG_H, 20, ORDER_W_FIRST);
      reg_write(REG_TMP_W, 5, ORDER_SIMUL);
      reg_write(REG_TMP_H, 5, ORDER_AW_FIRST);
      reg_write(REG_CTRL, 1, ORDER_W_FIRST);
      reg_read(REG_STATUS, status);
      if (status[1] == 0) `uvm_warning("COV", "the core is no longer busy -- T7 was missed")
      reg_write(REG_CTRL, 0, ORDER_AW_FIRST);   // write 0 while running
      reg_read(REG_STATUS, status);
      if (status[1] == 0) `uvm_warning("COV", "the core is no longer busy -- T7 was missed")
      reg_write(REG_CTRL, 1, ORDER_SIMUL);      // start again while running -- the core ignores it
      wait_done(ok);

      // --- writing 0 to CTRL after the job must not clear done ---
      reg_write(REG_CTRL, 0, ORDER_W_FIRST);
      reg_read(REG_STATUS, status);
      if (status[0] == 0)
         `uvm_error("COV", "writing 0 to CTRL cleared done")

      // --- a write to the result region is ignored, the unmapped region returns zeros ---
      b = new[2]; b[0] = 32'hDEAD; b[1] = 32'hBEEF;
      mem_write(REGION_RESULT, 0, b, ORDER_AW_FIRST);
      mem_write(REGION_RESULT, 2, b, ORDER_W_FIRST);
      mem_write(REGION_RESULT, 4, b, ORDER_SIMUL);
      mem_write(REGION_UNMAPPED, 0, b, ORDER_AW_FIRST);
      mem_write(REGION_UNMAPPED, 2, b, ORDER_W_FIRST);
      mem_write(REGION_UNMAPPED, 4, b, ORDER_SIMUL);
      mem_read(REGION_UNMAPPED, 0, 2, rd);
      foreach (rd[i])
         if (rd[i] !== 0)
            `uvm_error("COV", $sformatf("unmapped region: expected 0, got 0x%08x", rd[i]))

      // the map of the last job must stay the same (the scoreboard compares it)
      mem_read(REGION_RESULT, 0, 256, rd);
   endtask : body

endclass : ncc_cov_seq

// =========================================================================
// Random sequence: dimensions, data and channel order depend on the seed.
// =========================================================================
class ncc_random_seq extends ncc_base_seq;

   `uvm_object_utils(ncc_random_seq)

   rand int unsigned iw, ih, tw, th;
   rand int unsigned num_reads;

   constraint c_dim   { iw inside {[2:24]}; ih inside {[2:24]};
                        tw inside {[1:6]};  th inside {[1:6]};
                        tw <= iw; th <= ih; }
   constraint c_reads { num_reads inside {[3:8]}; }

   function new(string name = "ncc_random_seq");
      super.new(name);
   endfunction

   task body();
      bit [31 : 0] img[], tmp[], rd[];
      int          region;

      if (!this.randomize())
         `uvm_fatal("RND", "randomization failed")
      `uvm_info("RND", $sformatf("image %0dx%0d, template %0dx%0d", iw, ih, tw, th), UVM_LOW)

      img = new[iw * ih];
      foreach (img[i]) img[i] = $urandom_range(0, 255);
      mem_write(REGION_IMAGE, 0, img, random_order());

      tmp = new[tw * th];
      foreach (tmp[i]) tmp[i] = $urandom_range(0, 255);
      mem_write(REGION_TEMPLATE, 0, tmp, random_order());

      // random reads from the image, the template and the unmapped region
      for (int i = 0; i < num_reads; i++) begin
         case ($urandom_range(0, 2))
            0: region = REGION_IMAGE;
            1: region = REGION_TEMPLATE;
            default: region = REGION_UNMAPPED;
         endcase
         mem_read(region, $urandom_range(0, 1023), $urandom_range(1, 32), rd);
      end

      // writes to registers 0x10-0x2C that the core does not use
      for (int i = 0; i < 4; i++)
         reg_write(16 + 4 * $urandom_range(0, 7), $urandom(), random_order());

      run_job(iw, ih, tw, th);
   endtask : body

endclass : ncc_random_seq
