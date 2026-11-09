// Runs on the S00 sequencer: write of one register.
class axil_write_seq extends uvm_sequence #(axil_item);

   `uvm_object_utils(axil_write_seq)

   bit [5 : 0]  addr;
   bit [31 : 0] data;
   order_e      ord = ORDER_AW_FIRST;

   function new(string name = "axil_write_seq");
      super.new(name);
   endfunction

   task body();
      axil_item it;
      it = axil_item::type_id::create("it");
      start_item(it);
      it.rw   = WRITE;
      it.addr = addr;
      it.data = data;
      it.strb = 4'hF;
      if (!it.randomize() with { order == ord; })
         `uvm_fatal("SEQ", "randomization failed")
      finish_item(it);
   endtask : body

endclass : axil_write_seq
