// Upis bloka piksela i citanje istih vrednosti nazad, sva tri redosleda.
class ncc_mem_blok_seq extends ncc_axif_base_seq;
  `uvm_object_utils(ncc_mem_blok_seq)

  int unsigned gresaka = 0;

  function new(string name = "ncc_mem_blok_seq");
    super.new(name);
  endfunction

  task proveri_blok(string opis, region_e r, bit [12:0] w, int unsigned n,
                    aw_w_order_e o);
    bit [31:0] poslato[], vraceno[];
    poslato = new[n];
    foreach (poslato[i]) poslato[i] = (w + i) & 32'hFF;

    upisi_blok(r, w, poslato, o);
    procitaj_blok(r, w, n, vraceno);

    if (vraceno.size() != n) begin
      `uvm_error("BLOK", $sformatf("%s: vraceno %0d beat-ova, ocekivano %0d",
                                   opis, vraceno.size(), n))
      gresaka++;
      return;
    end

    foreach (poslato[i]) begin
      bit [31:0] ocekivano = (r == REGION_RESULT) ? poslato[i]
                                                  : (poslato[i] & 32'hFF);
      if (vraceno[i] !== ocekivano) begin
        `uvm_error("BLOK", $sformatf(
          "%s (%s): rec %0d, ocekivano 0x%08x, dobijeno 0x%08x",
          opis, o.name(), w + i, ocekivano, vraceno[i]))
        gresaka++;
      end
    end

    if (gresaka == 0)
      `uvm_info("BLOK", $sformatf("%s (%s): %0d beat-ova, upisano jednako procitanom",
                                  opis, o.name(), n), UVM_LOW)
  endtask

  task body();
    proveri_blok("slika, 1 beat",   REGION_IMG,  13'd0,   1,  ORDER_AW_FIRST);
    proveri_blok("slika, 2 beata",  REGION_IMG,  13'd16,  2,  ORDER_W_FIRST);
    proveri_blok("slika, 3 beata",  REGION_IMG,  13'd32,  3,  ORDER_SIMUL);
    proveri_blok("slika, 16 beata", REGION_IMG,  13'd64,  16, ORDER_W_FIRST);
    proveri_blok("sablon, 8 beata", REGION_TMP,  13'd0,   8,  ORDER_AW_FIRST);
    proveri_blok("sablon, 16 beata",REGION_TMP,  13'd128, 16, ORDER_SIMUL);

    if (gresaka == 0)
      `uvm_info("BLOK", "svi blokovi: upisano jednako procitanom", UVM_LOW)
  endtask
endclass : ncc_mem_blok_seq
