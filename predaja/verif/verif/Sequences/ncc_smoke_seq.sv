// Smoke: a small 4x4 image and a 2x2 template with one known peak.
// The template equals the image window at (u=1, v=1), so the result there must be 0x80000000.
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
