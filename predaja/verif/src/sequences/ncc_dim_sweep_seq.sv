// Prelaz preko svih legalnih kombinacija bin-ova dimenzija (Korak 5, spora lista).
class ncc_dim_sweep_seq extends ncc_cov_seq;
  `uvm_object_utils(ncc_dim_sweep_seq)

  function new(string name = "ncc_dim_sweep_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] slika[], sablon[], odbaci[];
    int unsigned iw[19] = '{ 1,
                            20, 20, 20,
                            45, 45, 45, 45, 45,
                            60, 60, 60, 60, 60,
                            90, 90, 90, 90, 90 };
    int unsigned tw[19] = '{ 1,
                             1,  5, 15,
                             1,  5, 15, 20, 30,
                             1,  5, 15, 20, 30,
                             1,  5, 15, 20, 30 };

    slika = new[256];
    foreach (slika[i]) slika[i] = (i * 37 + 11) & 32'hFF;
    mem_upisi(REGION_IMG, 13'd0, slika, ORDER_AW_FIRST);

    sablon = new[SABLON_RECI];
    foreach (sablon[i]) sablon[i] = (i * 53 + 7) & 32'hFF;
    mem_upisi(REGION_TMP, 13'd0, sablon, ORDER_AW_FIRST);

    foreach (iw[k]) pokreni_skup(iw[k], 1, tw[k], 1);

    mem_procitaj(REGION_RESULT, 13'd0, 8, odbaci);
  endtask

endclass : ncc_dim_sweep_seq
