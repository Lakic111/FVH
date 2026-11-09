// Base of the sequences that use both buses. The test gives it the handles of both
// sequencers, and each step is started on the one it belongs to.
// Each step waits for the previous one, so the order write -> start -> wait -> read is kept.
class ncc_base_seq extends uvm_sequence;

   `uvm_object_utils(ncc_base_seq)

   axil_sequencer axil_seqr;
   axif_sequencer axif_seqr;

   function new(string name = "ncc_base_seq");
      super.new(name);
   endfunction

   // Write one S00 register.
   task reg_write(bit [5 : 0] addr, bit [31 : 0] data, order_e ord = ORDER_AW_FIRST);
      axil_write_seq s;
      s = axil_write_seq::type_id::create("s");
      s.addr = addr;
      s.data = data;
      s.ord  = ord;
      s.start(axil_seqr);
   endtask : reg_write

   // Read one S00 register.
   task reg_read(bit [5 : 0] addr, output bit [31 : 0] data);
      axil_read_seq s;
      s = axil_read_seq::type_id::create("s");
      s.addr = addr;
      s.start(axil_seqr);
      data = s.data;
   endtask : reg_read

   // Write an array of words to an S01 region, starting at word 'word'.
   task mem_write(int region, int unsigned word, bit [31 : 0] d[],
                  order_e ord = ORDER_AW_FIRST, bit [3 : 0] strb = 4'hF);
      axif_write_seq s;
      s = axif_write_seq::type_id::create("s");
      s.region = region;
      s.word   = word;
      s.d      = d;
      s.ord    = ord;
      s.strb   = strb;
      s.start(axif_seqr);
   endtask : mem_write

   // Read n words from an S01 region, starting at word 'word'.
   task mem_read(int region, int unsigned word, int unsigned n, output bit [31 : 0] d[]);
      axif_read_seq s;
      s = axif_read_seq::type_id::create("s");
      s.region = region;
      s.word   = word;
      s.n      = n;
      s.start(axif_seqr);
      d = s.d;
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
