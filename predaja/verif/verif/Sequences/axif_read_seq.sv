// Runs on the S01 sequencer: read of n words from a region, starting at word 'word'.
class axif_read_seq extends axif_base_seq;

   `uvm_object_utils(axif_read_seq)

   int unsigned n;
   bit [31 : 0] d[];   // the words that were read

   function new(string name = "axif_read_seq");
      super.new(name);
   endfunction

   task body();
      axif_item it;
      int unsigned pos = 0;
      int unsigned k;
      d = new[n];
      while (pos < n) begin
         k  = burst_len(word + pos, n - pos);
         it = axif_item::type_id::create("it");
         start_item(it);
         it.rw   = READ;
         it.addr = region * 32768 + (word + pos) * 4;
         it.len  = k;
         finish_item(it);
         for (int i = 0; i < k; i++) d[pos + i] = it.data[i];
         pos = pos + k;
      end
   endtask : body

endclass : axif_read_seq
