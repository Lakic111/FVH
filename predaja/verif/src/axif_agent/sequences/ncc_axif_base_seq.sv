// Osnovna S01 sekvenca: pomocni zadaci upisi_blok() i procitaj_blok().
class ncc_axif_base_seq extends uvm_sequence #(ncc_mem_item);
  `uvm_object_utils(ncc_axif_base_seq)

  function new(string name = "ncc_axif_base_seq");
    super.new(name);
  endfunction

  // Smer svakog argumenta naveden izricito (SV nasledjuje smer od prethodnog).
  task upisi_blok(input region_e r, input bit [12:0] w,
                  const ref bit [31:0] d[],
                  input aw_w_order_e o = ORDER_AW_FIRST,
                  input int unsigned g = 1);
    ncc_mem_item it = ncc_mem_item::type_id::create("it");
    bit ok;
    start_item(it);
    if (o == ORDER_SIMUL)
      ok = it.randomize() with { region == r; word == w; len == d.size();
                                 rw == MEM_WRITE; order == o; };
    else
      ok = it.randomize() with { region == r; word == w; len == d.size();
                                 rw == MEM_WRITE; order == o; gap == g; };
    if (!ok) `uvm_fatal("RAND", "randomizacija upisa u S01 nije uspela")
    foreach (d[i]) it.data[i] = d[i];
    finish_item(it);
  endtask

  task procitaj_blok(input region_e r, input bit [12:0] w,
                     input int unsigned n, ref bit [31:0] d[]);
    ncc_mem_item it = ncc_mem_item::type_id::create("it");
    start_item(it);
    if (!it.randomize() with { region == r; word == w; len == n;
                               rw == MEM_READ; order == ORDER_AW_FIRST; })
      `uvm_fatal("RAND", "randomizacija citanja iz S01 nije uspela")
    finish_item(it);
    d = new[it.data.size()];
    foreach (it.data[i]) d[i] = it.data[i];
  endtask
endclass : ncc_axif_base_seq
