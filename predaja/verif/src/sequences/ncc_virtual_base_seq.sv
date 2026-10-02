// Osnova virtuelnih sekvenci: upis/citanje registara i blokova preko oba sekvencera.
class ncc_virtual_base_seq extends uvm_sequence;
  `uvm_object_utils(ncc_virtual_base_seq)
  `uvm_declare_p_sequencer(ncc_virtual_sequencer)

  function new(string name = "ncc_virtual_base_seq");
    super.new(name);
  endfunction

  task reg_upisi(bit [S00_ADDR_W-1:0] a, bit [S00_DATA_W-1:0] d,
                 aw_w_order_e o = ORDER_AW_FIRST);
    ncc_reg_item it = ncc_reg_item::type_id::create("reg_w");
    bit ok;
    start_item(it, -1, p_sequencer.axil_sqr);
    if (o == ORDER_SIMUL)
      ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE; order == o; };
    else
      ok = it.randomize() with { addr == a; data == d; rw == REG_WRITE;
                                 order == o; gap == 1; };
    if (!ok) `uvm_fatal("RAND", "randomizacija upisa u registar nije uspela")
    finish_item(it);
  endtask

  task reg_procitaj(bit [S00_ADDR_W-1:0] a, output bit [S00_DATA_W-1:0] d);
    ncc_reg_item it = ncc_reg_item::type_id::create("reg_r");
    start_item(it, -1, p_sequencer.axil_sqr);
    if (!it.randomize() with { addr == a; rw == REG_READ; })
      `uvm_fatal("RAND", "randomizacija citanja registra nije uspela")
    finish_item(it);
    d = it.data;
  endtask

  task mem_upisi(input region_e r, input bit [12:0] w,
                 const ref bit [31:0] d[],
                 input aw_w_order_e o = ORDER_AW_FIRST,
                 input bit [3:0] st = 4'hF);
    ncc_mem_item it = ncc_mem_item::type_id::create("mem_w");
    bit ok;
    start_item(it, -1, p_sequencer.axif_sqr);
    if (o == ORDER_SIMUL)
      ok = it.randomize() with { region == r; word == w; len == d.size();
                                 rw == MEM_WRITE; order == o; strb == st; };
    else
      ok = it.randomize() with { region == r; word == w; len == d.size();
                                 rw == MEM_WRITE; order == o; gap == 1;
                                 strb == st; };
    if (!ok) `uvm_fatal("RAND", "randomizacija upisa u memoriju nije uspela")
    foreach (d[i]) it.data[i] = d[i];
    finish_item(it);
  endtask

  task mem_procitaj(input region_e r, input bit [12:0] w, input int unsigned n,
                    ref bit [31:0] d[]);
    ncc_mem_item it = ncc_mem_item::type_id::create("mem_r");
    start_item(it, -1, p_sequencer.axif_sqr);
    if (!it.randomize() with { region == r; word == w; len == n;
                               rw == MEM_READ; order == ORDER_AW_FIRST; })
      `uvm_fatal("RAND", "randomizacija citanja memorije nije uspela")
    finish_item(it);
    d = new[it.data.size()];
    foreach (it.data[i]) d[i] = it.data[i];
  endtask

  // --- veliki blokovi ------------------------------------------------------
  // AXI dozvoljava najvise 256 beat-ova po burst-u i zabranjuje prelazak
  // granice od 4 KB -- veci blok se deli.
  function automatic int unsigned komad(int unsigned w, int unsigned ostalo);
    int unsigned do_granice = 1024 - (w % 1024);
    int unsigned k = 256;
    if (ostalo     < k) k = ostalo;
    if (do_granice < k) k = do_granice;
    return k;
  endfunction

  task mem_upisi_deljeno(input region_e r, input bit [12:0] w,
                         const ref bit [31:0] d[],
                         input aw_w_order_e o = ORDER_AW_FIRST,
                         input bit [3:0] st = 4'hF);
    int unsigned poz = 0;
    while (poz < d.size()) begin
      int unsigned k = komad(w + poz, d.size() - poz);
      bit [31:0] deo[];
      deo = new[k];
      for (int i = 0; i < k; i++) deo[i] = d[poz + i];
      mem_upisi(r, 13'(w + poz), deo, o, st);
      poz += k;
    end
  endtask

  task mem_procitaj_deljeno(input region_e r, input bit [12:0] w,
                            input int unsigned n, ref bit [31:0] d[]);
    int unsigned poz = 0;
    d = new[n];
    while (poz < n) begin
      int unsigned k = komad(w + poz, n - poz);
      bit [31:0] deo[];
      mem_procitaj(r, 13'(w + poz), k, deo);
      for (int i = 0; i < k; i++) d[poz + i] = deo[i];
      poz += k;
    end
  endtask

endclass : ncc_virtual_base_seq
