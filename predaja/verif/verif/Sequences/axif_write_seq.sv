// Runs on the S01 sequencer: write of an array of words to a region, starting at word 'word'.
class axif_write_seq extends axif_base_seq;

   `uvm_object_utils(axif_write_seq)

   bit [31 : 0] d[];
   order_e      ord  = ORDER_AW_FIRST;
   bit [3 : 0]  strb = 4'hF;

   function new(string name = "axif_write_seq");
      super.new(name);
   endfunction

   task body();
      axif_item it;
      int unsigned pos = 0;
      int unsigned k;
      while (pos < d.size()) begin
         k  = burst_len(word + pos, d.size() - pos);
         it = axif_item::type_id::create("it");
         start_item(it);
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
   endtask : body

endclass : axif_write_seq
