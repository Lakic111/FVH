// ============================================================================
// ncc_ref_pkg.sv -- referentni model NCC^2, bihevioralni, u cistom SystemVerilogu.
//
// Model je izveden IZ RTL-a (`rtl/ncc_core.vhd`, stanja S_CALC_MEAN, S_L_U_E,
// S_L_YX_*, S_NCC_SQ, S_NCC_DIV), a ne iz udzbenicke formule.  Razlog: provera
// mora biti bit-tacna, a bit-tacnost zavisi od celobrojnog zaokruzivanja i od
// odsecanja sirina, kojih u formuli nema.
//
// Preslikane su i sledece pojedinosti, jer svaka menja rezultat:
//   * srednje vrednosti se racunaju kao (suma + count/2) / count -- celobrojno
//     deljenje sa zaokruzivanjem, pa se odsecaju na 8 bita
//   * akumulatori su 27 bita sa znakom i 26 bita bez znaka -- prekoracenje se
//     odseca, ne saturira
//   * num_sq i den_prod se odsecaju na 52 bita
//   * ako je bilo koja varijansa nula, rezultat je 0 (a ne deljenje nulom)
//   * NCC^2 = (num_sq << 31) / den_prod, u 83 bita, pa odsecanje na 32
//
// Bez DPI-a: sve radi u cistom SV-u, pa se isti model prenosi na Xcelium bez
// dodatnog koraka prevodjenja (Korak 7).
// ============================================================================
package ncc_ref_pkg;

  import ncc_verif_pkg::*;

  // Racuna mapu rezultata za dati skup.  Ulazi su vrednosti piksela (0..255)
  // u redosledu po vrstama; izlaz je mapa velicine res_w * res_h.
  function automatic void ncc_predikcija(
      input  int unsigned img_w, img_h, tmp_w, tmp_h,
      input  bit [7:0]    slika[],
      input  bit [7:0]    sablon[],
      output bit [31:0]   rezultat[]
  );
    int unsigned count = tmp_w * tmp_h;
    int unsigned res_w = img_w - tmp_w + 1;
    int unsigned res_h = img_h - tmp_h + 1;

    int unsigned sum_t = 0;
    bit [7:0]    t_mean;

    rezultat = new[res_w * res_h];

    foreach (sablon[i]) sum_t += sablon[i];
    // resize(dm_quot, 8) u RTL-u -- odsecanje na osam bita, ne saturacija
    t_mean = 8'(( sum_t + (count / 2) ) / count);

    for (int unsigned v = 0; v < res_h; v++) begin
      for (int unsigned u = 0; u < res_w; u++) begin
        int unsigned      sum_f = 0;
        bit [7:0]         f_bar;
        bit signed [26:0] sum_num   = '0;
        bit [25:0]        sum_den_f = '0;
        bit [25:0]        sum_den_t = '0;
        bit [51:0]        num_sq, den_prod;
        bit [82:0]        deljenik, kolicnik;

        for (int unsigned y = 0; y < tmp_h; y++)
          for (int unsigned x = 0; x < tmp_w; x++)
            sum_f += slika[(v + y) * img_w + (u + x)];

        f_bar = 8'(( sum_f + (count / 2) ) / count);

        for (int unsigned y = 0; y < tmp_h; y++) begin
          for (int unsigned x = 0; x < tmp_w; x++) begin
            bit signed [8:0]  df = 9'(slika [(v + y) * img_w + (u + x)]) - 9'(f_bar);
            bit signed [8:0]  dt = 9'(sablon[ y      * tmp_w +  x     ]) - 9'(t_mean);

            // Proizvodi se racunaju u OZNACENE medjupromenljive, pa tek onda
            // sabiraju.  Da se pisalo `sum_den_f += df * df`, kontekst dodele
            // (sum_den_f je bez znaka) ucinio bi i mnozenje neoznacenim, pa bi
            // df = -71 uslo kao 441 i sve vrednosti bi bile pogresne.  RTL radi
            // `unsigned(resize(df_reg * df_reg, 26))` -- prvo oznaceno mnozenje,
            // pa tek onda pretvaranje u neoznaceno.
            bit signed [17:0] p_num = df * dt;
            bit signed [17:0] p_ff  = df * df;
            bit signed [17:0] p_tt  = dt * dt;

            sum_num   += p_num;              // 27 bita sa znakom
            sum_den_f += 26'(p_ff);          // p_ff i p_tt su uvek >= 0
            sum_den_t += 26'(p_tt);
          end
        end

        // RTL: `if sum_den_f = 0 or sum_den_t = 0` -> rezultat 0.  Bez ove grane
        // delilac bi bio nula i kolicnik bi bio same jedinice.
        if (sum_den_f == 0 || sum_den_t == 0) begin
          rezultat[v * res_w + u] = 32'h0000_0000;
          continue;
        end

        num_sq   = sum_num * sum_num;        // odsecanje na 52 bita
        den_prod = sum_den_f * sum_den_t;    // odsecanje na 52 bita

        deljenik = 83'(num_sq) << 31;
        kolicnik = deljenik / 83'(den_prod);

        rezultat[v * res_w + u] = kolicnik[31:0];
      end
    end
  endfunction

endpackage : ncc_ref_pkg
