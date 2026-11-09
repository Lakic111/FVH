// Base of the S01 sequences: a larger array of words is split into bursts.
class axif_base_seq extends uvm_sequence #(axif_item);

   `uvm_object_utils(axif_base_seq)

   int          region;
   int unsigned word;

   function new(string name = "axif_base_seq");
      super.new(name);
   endfunction

   // How many words may go into one burst starting at word 'w': at most 256 beats
   // and without crossing a 4 KB boundary (1024 words).
   function int unsigned burst_len(int unsigned w, int unsigned remaining);
      int unsigned k;
      k = remaining;
      if (k > 256) k = 256;
      if (k > 1024 - (w % 1024)) k = 1024 - (w % 1024);
      return k;
   endfunction

endclass : axif_base_seq
