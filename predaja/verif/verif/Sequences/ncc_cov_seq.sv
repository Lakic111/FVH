// Coverage: directed cases that close all covergroups and check
// the behaviour of the memories and of the control register.
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
