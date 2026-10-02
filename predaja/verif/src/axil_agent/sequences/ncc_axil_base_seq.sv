// Osnovna S00 sekvenca: pomocni zadaci upisi() i procitaj().
class ncc_axil_base_seq extends uvm_sequence #(ncc_reg_item);
  `uvm_object_utils(ncc_axil_base_seq)

  function new(string name = "ncc_axil_base_seq");
    super.new(name);
  endfunction

  task upisi(bit [S00_ADDR_W-1:0] a, bit [S00_DATA_W-1:0] d,
             aw_w_order_e o = ORDER_AW_FIRST, int unsigned g = 1);
    ncc_reg_item it = ncc_reg_item::type_id::create("it");
    bit ok;
    start_item(it);
    if (o == ORDER_SIMUL)
      ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                 order == o; };
    else
      ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                 order == o; gap == g; };
    if (!ok) `uvm_fatal("RAND", "randomizacija upisa nije uspela")
    finish_item(it);
  endtask

  task procitaj(bit [S00_ADDR_W-1:0] a, output bit [S00_DATA_W-1:0] d);
    ncc_reg_item it = ncc_reg_item::type_id::create("it");
    start_item(it);
    if (!it.randomize() with { addr == a; rw == REG_READ; })
      `uvm_fatal("RAND", "randomizacija citanja nije uspela")
    finish_item(it);
    d = it.data;
  endtask
endclass : ncc_axil_base_seq
