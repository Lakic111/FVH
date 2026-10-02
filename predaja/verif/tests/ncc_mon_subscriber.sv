// Potrosac transakcija koje monitor objavi (nije scoreboard).
class ncc_mon_subscriber extends uvm_subscriber #(ncc_reg_item);
  `uvm_component_utils(ncc_mon_subscriber)

  int unsigned br_upisa   = 0;
  int unsigned br_citanja = 0;
  int unsigned br_redosleda[aw_w_order_e];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    br_redosleda[ORDER_AW_FIRST] = 0;
    br_redosleda[ORDER_W_FIRST]  = 0;
    br_redosleda[ORDER_SIMUL]    = 0;
  endfunction

  function void write(ncc_reg_item t);
    if (t.rw == REG_WRITE) begin
      br_upisa++;
      br_redosleda[t.order]++;
      `uvm_info("SUB", $sformatf("monitor: upis  0x%02x = 0x%08x (%s)",
                                 t.addr, t.data, t.order.name()), UVM_LOW)
    end else begin
      br_citanja++;
      `uvm_info("SUB", $sformatf("monitor: citanje 0x%02x = 0x%08x",
                                 t.addr, t.data), UVM_LOW)
    end
  endfunction
endclass : ncc_mon_subscriber
