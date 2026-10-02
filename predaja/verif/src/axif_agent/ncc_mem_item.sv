// Sekvencijalna stavka za S01 (AXI4-Full): jedan paketni upis ili citanje.
class ncc_mem_item extends uvm_sequence_item;

  rand region_e          region;
  rand bit [12:0]        word;      // indeks reci unutar regiona (addr[14:2])
  rand int unsigned      len;       // broj beat-ova = AWLEN + 1
  rand bit [31:0]        data[];    // len elemenata
  rand bit [3:0]         strb;
  rand mem_rw_e          rw;
  rand aw_w_order_e      order;
  rand int unsigned      gap;

  bit [1:0] resp;

  constraint c_len   { len inside {[1:256]};
                       data.size() == len; }

  constraint c_4k    { ((word * 4) % 4096) + (len * 4) <= 4096; }

  // Ogranicava se adresni prostor regiona (13 bita), ne dubina memorije --
  // razmak od TMP_WORDS reci mora ostati testabilan (aliasing, P2).
  constraint c_opseg { word + len <= 8192; }

  constraint c_order { order dist { ORDER_AW_FIRST := 2,
                                    ORDER_W_FIRST  := 2,
                                    ORDER_SIMUL    := 1 }; }
  constraint c_gap   { order == ORDER_SIMUL -> gap == 0;
                       order != ORDER_SIMUL -> gap inside {[1:4]}; }
  constraint c_strb  { soft strb == 4'hF; }

  `uvm_object_utils_begin(ncc_mem_item)
    `uvm_field_enum(region_e,     region, UVM_ALL_ON)
    `uvm_field_int (word,   UVM_ALL_ON)
    `uvm_field_int (len,    UVM_ALL_ON)
    `uvm_field_array_int(data, UVM_ALL_ON)
    `uvm_field_int (strb,   UVM_ALL_ON)
    `uvm_field_enum(mem_rw_e,     rw,     UVM_ALL_ON)
    `uvm_field_enum(aw_w_order_e, order,  UVM_ALL_ON)
    `uvm_field_int (gap,    UVM_ALL_ON)
    `uvm_field_int (resp,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "ncc_mem_item");
    super.new(name);
  endfunction

  // Puna bajtska adresa: region u bitovima 16:15, rec u 14:2.
  function bit [S01_ADDR_W-1:0] puna_adresa();
    return {region, word, 2'b00};
  endfunction

endclass : ncc_mem_item
