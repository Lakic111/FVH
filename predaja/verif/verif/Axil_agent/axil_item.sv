// One S00 transaction: a write or a read of one register.
class axil_item extends uvm_sequence_item;

   rw_e         rw;
   bit [5 : 0]  addr;
   bit [31 : 0] data;
   bit [3 : 0]  strb;
   bit [1 : 0]  resp;

   rand order_e      order;
   rand int unsigned gap;     // how many clock cycles the second channel is delayed

   constraint c_order { order dist {ORDER_AW_FIRST := 2, ORDER_W_FIRST := 2, ORDER_SIMUL := 1}; }
   constraint c_gap   { order == ORDER_SIMUL -> gap == 0;
                        order != ORDER_SIMUL -> gap inside {[1:4]}; }

   `uvm_object_utils_begin(axil_item)
      `uvm_field_enum(rw_e, rw, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(strb, UVM_DEFAULT)
      `uvm_field_enum(order_e, order, UVM_DEFAULT)
      `uvm_field_int(gap, UVM_DEFAULT)
   `uvm_object_utils_end

   function new (string name = "axil_item");
      super.new(name);
   endfunction

endclass : axil_item
