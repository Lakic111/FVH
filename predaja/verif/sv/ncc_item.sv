// Jedna transakcija na S00 ili S01: upis ili citanje.
//   S00: addr = adresa registra, data ima jednu rec
//   S01: addr = bajtska adresa, data ima len reci (jedan burst)
class ncc_item extends uvm_sequence_item;

   bus_e        bus;
   rw_e         rw;
   bit [16 : 0] addr;
   int unsigned len;
   bit [31 : 0] data[];
   bit [3 : 0]  strb;
   bit [1 : 0]  resp;

   rand order_e      order;
   rand int unsigned gap;     // koliko taktova kasni drugi kanal

   constraint c_order { order dist {ORDER_AW_FIRST := 2, ORDER_W_FIRST := 2, ORDER_SIMUL := 1}; }
   constraint c_gap   { order == ORDER_SIMUL -> gap == 0;
                        order != ORDER_SIMUL -> gap inside {[1:4]}; }

   `uvm_object_utils_begin(ncc_item)
      `uvm_field_enum(bus_e, bus, UVM_DEFAULT)
      `uvm_field_enum(rw_e, rw, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(len, UVM_DEFAULT)
      `uvm_field_array_int(data, UVM_DEFAULT)
      `uvm_field_int(strb, UVM_DEFAULT)
      `uvm_field_enum(order_e, order, UVM_DEFAULT)
      `uvm_field_int(gap, UVM_DEFAULT)
   `uvm_object_utils_end

   function new (string name = "ncc_item");
      super.new(name);
   endfunction

endclass : ncc_item
