// Direktna sekvenca: upis pa citanje istog registra, u sva tri redosleda.
class ncc_reg_rw_seq extends ncc_axil_base_seq;
  `uvm_object_utils(ncc_reg_rw_seq)

  int unsigned gresaka = 0;

  function new(string name = "ncc_reg_rw_seq");
    super.new(name);
  endfunction

  task proveri(string opis, bit [S00_ADDR_W-1:0] a,
               bit [S00_DATA_W-1:0] ocekivano, aw_w_order_e o);
    bit [S00_DATA_W-1:0] procitano;
    upisi(a, ocekivano, o);
    procitaj(a, procitano);
    if (procitano !== ocekivano) begin
      `uvm_error("RW", $sformatf("%s (%s): adresa 0x%02x, ocekivano 0x%08x, dobijeno 0x%08x",
                                 opis, o.name(), a, ocekivano, procitano))
      gresaka++;
    end else begin
      `uvm_info("RW", $sformatf("%s (%s): adresa 0x%02x = 0x%08x",
                                opis, o.name(), a, procitano), UVM_LOW)
    end
  endtask

  task body();
    proveri("REG_IMG_W", REG_IMG_W, 32'd90, ORDER_AW_FIRST);
    proveri("REG_IMG_W", REG_IMG_W, 32'd45, ORDER_W_FIRST);
    proveri("REG_IMG_W", REG_IMG_W, 32'd30, ORDER_SIMUL);

    proveri("REG_IMG_H", REG_IMG_H, 32'd90, ORDER_W_FIRST);
    proveri("REG_TMP_W", REG_TMP_W, 32'd25, ORDER_SIMUL);
    proveri("REG_TMP_H", REG_TMP_H, 32'd15, ORDER_AW_FIRST);

    proveri("REG_IMG_W puna rec", REG_IMG_W, 32'hDEAD_BE5A, ORDER_W_FIRST);

    if (gresaka == 0)
      `uvm_info("RW", "svi registri: upisano jednako procitanom, sva tri redosleda", UVM_LOW)
  endtask
endclass : ncc_reg_rw_seq
