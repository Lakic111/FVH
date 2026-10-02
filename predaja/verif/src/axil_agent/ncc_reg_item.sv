// Sekvencijalna stavka za S00 (AXI4-Lite): jedan upis ili citanje registra.
class ncc_reg_item extends uvm_sequence_item;

  rand bit [S00_ADDR_W-1:0] addr;
  rand bit [S00_DATA_W-1:0] data;   // kod citanja: drajver upisuje procitano
  rand reg_rw_e             rw;
  rand aw_w_order_e         order;
  rand bit [3:0]            strb;
  rand int unsigned         gap;    // taktova izmedju pokretanja dva kanala

  bit [1:0] resp;                   // BRESP / RRESP, popunjava drajver

  constraint c_order  { order dist { ORDER_AW_FIRST := 2,
                                     ORDER_W_FIRST  := 2,
                                     ORDER_SIMUL    := 1 }; }

  constraint c_gap    { order == ORDER_SIMUL -> gap == 0;
                        order != ORDER_SIMUL -> gap inside {[1:4]}; }

  constraint c_strb   { strb == 4'hF; }

  // Meko: dozvoljava i scratch adresu (test T2) bez pada randomizacije.
  constraint c_addr   { soft addr inside { REG_IMG_W, REG_IMG_H, REG_TMP_W,
                                           REG_TMP_H, REG_CTRL, REG_STATUS }; }

  constraint c_status { addr == REG_STATUS -> rw == REG_READ; }

  `uvm_object_utils_begin(ncc_reg_item)
    `uvm_field_int (addr,  UVM_ALL_ON)
    `uvm_field_int (data,  UVM_ALL_ON)
    `uvm_field_enum(reg_rw_e,     rw,    UVM_ALL_ON)
    `uvm_field_enum(aw_w_order_e, order, UVM_ALL_ON)
    `uvm_field_int (strb,  UVM_ALL_ON)
    `uvm_field_int (gap,   UVM_ALL_ON)
    `uvm_field_int (resp,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "ncc_reg_item");
    super.new(name);
  endfunction

endclass : ncc_reg_item
