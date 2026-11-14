// Random sequence: dimensions, data and channel order depend on the seed.
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

      run_job(iw, ih, tw, th);
   endtask : body

endclass : ncc_random_seq
