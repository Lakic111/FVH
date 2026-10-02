// Referentni model NCC^2, bihevioralni SV, izveden iz RTL-a (bit-tacan).
package ncc_ref_pkg;

  import ncc_verif_pkg::*;

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

            // Proizvodi u oznacenim medjupromenljivama pre sabiranja (vidi RTL).
            bit signed [17:0] p_num = df * dt;
            bit signed [17:0] p_ff  = df * df;
            bit signed [17:0] p_tt  = dt * dt;

            sum_num   += p_num;
            sum_den_f += 26'(p_ff);
            sum_den_t += 26'(p_tt);
          end
        end

        if (sum_den_f == 0 || sum_den_t == 0) begin
          rezultat[v * res_w + u] = 32'h0000_0000;
          continue;
        end

        num_sq   = sum_num * sum_num;
        den_prod = sum_den_f * sum_den_t;

        deljenik = 83'(num_sq) << 31;
        kolicnik = deljenik / 83'(den_prod);

        rezultat[v * res_w + u] = kolicnik[31:0];
      end
    end
  endfunction

endpackage : ncc_ref_pkg
