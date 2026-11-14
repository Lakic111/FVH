// Runs on the S00 sequencer: read of one register.
class axil_read_seq extends uvm_sequence #(axil_item);

   `uvm_object_utils(axil_read_seq)

   bit [5 : 0]  addr;
   bit [31 : 0] data;   // the value that was read

   function new(string name = "axil_read_seq");
      super.new(name);
   endfunction

   task body();
      axil_item it;
      it = axil_item::type_id::create("it");
      start_item(it);
      it.rw   = READ;
      it.addr = addr;
      finish_item(it);
      data = it.data;
   endtask : body

endclass : axil_read_seq
