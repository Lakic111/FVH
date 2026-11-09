// Scoreboard -- receives only what the two monitors saw on the buses.
//   1. writes to the image and template regions fill a copy of the memory (shadow)
//   2. writes to the dimension registers store the configuration
//   3. writing 1 to CTRL computes the expected result map (reference model)
//   4. every read of the result region is compared with the expected map
`uvm_analysis_imp_decl(_axil)
`uvm_analysis_imp_decl(_axif)

class ncc_scoreboard extends uvm_scoreboard;

   uvm_analysis_imp_axil #(axil_item, ncc_scoreboard) port_axil;
   uvm_analysis_imp_axif #(axif_item, ncc_scoreboard) port_axif;

   bit [7 : 0]  shadow_img[int];
   bit [7 : 0]  shadow_tmp[int];
   bit [31 : 0] expected[int];

   int unsigned img_w, img_h, tmp_w, tmp_h;
   bit          has_prediction = 0;
   bit          seen_done = 0;
   bit          last_busy = 0;

   int unsigned num_compared = 0;
   int unsigned num_errors = 0;

   `uvm_component_utils(ncc_scoreboard)

   function new(string name = "ncc_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      port_axil = new("port_axil", this);
      port_axif = new("port_axif", this);
   endfunction

   // Transaction from the S00 monitor.
   function void write_axil(axil_item t);
      if (t.rw == WRITE) begin
         if (t.addr == REG_IMG_W) img_w = t.data[7 : 0];
         if (t.addr == REG_IMG_H) img_h = t.data[7 : 0];
         if (t.addr == REG_TMP_W) tmp_w = t.data[7 : 0];
         if (t.addr == REG_TMP_H) tmp_h = t.data[7 : 0];
         if (t.addr == REG_CTRL && t.data[0] == 1) begin
            // the core ignores start while it is running (finding N2), so there is no new prediction
            if (last_busy)
               `uvm_info("SB", "start while the core is busy -- the core ignores it", UVM_LOW)
            else
               predict();
         end
      end
      else if (t.addr == REG_STATUS) begin
         last_busy = t.data[1];
         if (t.data[0] == 1) seen_done = 1;
      end
   endfunction : write_axil

   // Transaction from the S01 monitor.
   function void write_axif(axif_item t);
      int region, word;

      region = t.addr[16 : 15];
      word   = t.addr[14 : 2];
      if (t.rw == WRITE) begin
         // the RTL writes only when WSTRB(0) = 1
         if (t.strb[0] == 0) return;
         if (region == REGION_IMAGE)
            foreach (t.data[i]) shadow_img[word + i] = t.data[i][7 : 0];
         if (region == REGION_TEMPLATE)
            foreach (t.data[i]) shadow_tmp[(word + i) % TMP_WORDS] = t.data[i][7 : 0];
         // a write to the result region is ignored (the region is read only)
      end
      else if (region == REGION_RESULT) begin
         compare(t, word);
      end
   endfunction : write_axif

   // Core start: expected map from the shadow memory and the current dimensions.
   function void predict();
      bit [7 : 0]  img[], tmp[];
      bit [31 : 0] res_map[];

      if (img_w == 0 || img_h == 0 || tmp_w == 0 || tmp_h == 0) begin
         `uvm_warning("SB", "start before all dimensions were written")
         return;
      end

      img = new[img_w * img_h];
      tmp = new[tmp_w * tmp_h];
      foreach (img[i])
         if (shadow_img.exists(i)) img[i] = shadow_img[i]; else img[i] = 0;
      foreach (tmp[i])
         if (shadow_tmp.exists(i)) tmp[i] = shadow_tmp[i]; else tmp[i] = 0;

      ncc_model(img, tmp, res_map);

      expected.delete();
      foreach (res_map[i]) expected[i] = res_map[i];
      has_prediction = 1;
      seen_done = 0;
      `uvm_info("SB", $sformatf("prediction: image %0dx%0d, template %0dx%0d, %0d results",
                                img_w, img_h, tmp_w, tmp_h, res_map.size()), UVM_LOW)
   endfunction : predict

   // NCC^2 reference model -- the same computation as ncc_core.vhd, result in Q1.31.
   function void ncc_model(bit [7 : 0] img[], bit [7 : 0] tmp[], output bit [31 : 0] res_map[]);
      int unsigned n, res_w, res_h, sum_t, sum_f;
      int          t_mean, f_mean, p, df, dt;
      int          sum_num, sum_den_f, sum_den_t;
      longint      num, num_sq, den_prod;
      bit [82 : 0] dividend, divisor, quotient;

      n     = tmp_w * tmp_h;
      res_w = img_w - tmp_w + 1;
      res_h = img_h - tmp_h + 1;
      res_map = new[res_w * res_h];

      // template mean, rounded
      sum_t = 0;
      foreach (tmp[i]) sum_t = sum_t + tmp[i];
      t_mean = (sum_t + n / 2) / n;

      for (int v = 0; v < res_h; v++) begin
         for (int u = 0; u < res_w; u++) begin
            // mean of the image window at (u, v)
            sum_f = 0;
            for (int y = 0; y < tmp_h; y++)
               for (int x = 0; x < tmp_w; x++)
                  sum_f = sum_f + img[(v + y) * img_w + (u + x)];
            f_mean = (sum_f + n / 2) / n;

            sum_num   = 0;
            sum_den_f = 0;
            sum_den_t = 0;
            for (int y = 0; y < tmp_h; y++) begin
               for (int x = 0; x < tmp_w; x++) begin
                  p  = img[(v + y) * img_w + (u + x)];
                  df = p - f_mean;
                  p  = tmp[y * tmp_w + x];
                  dt = p - t_mean;
                  sum_num   = sum_num   + df * dt;
                  sum_den_f = sum_den_f + df * df;
                  sum_den_t = sum_den_t + dt * dt;
               end
            end

            if (sum_den_f == 0 || sum_den_t == 0) begin
               res_map[v * res_w + u] = 0;
            end
            else begin
               // NCC^2 = num^2 / (den_f * den_t), shifted by 31 bits (Q1.31)
               num      = sum_num;
               num_sq   = num * num;
               den_prod = sum_den_f;
               den_prod = den_prod * sum_den_t;
               dividend = num_sq;
               dividend = dividend << 31;
               divisor  = den_prod;
               quotient = dividend / divisor;
               res_map[v * res_w + u] = quotient[31 : 0];
            end
         end
      end
   endfunction : ncc_model

   function void compare(axif_item t, int word);
      if (!has_prediction) begin
         `uvm_warning("SB", "result read before the core was started")
         return;
      end
      if (!seen_done)
         `uvm_warning("SB", "result is read, but done has not been seen yet")

      foreach (t.data[i]) begin
         if (expected.exists(word + i)) begin
            num_compared++;
            if (t.data[i] !== expected[word + i]) begin
               num_errors++;
               `uvm_error("SB", $sformatf("result[%0d]: expected 0x%08x, got 0x%08x",
                                          word + i, expected[word + i], t.data[i]))
            end
         end
      end
   endfunction : compare

   function void report_phase(uvm_phase phase);
      if (num_compared == 0)
         `uvm_error("SB", "the scoreboard did not compare a single result")
      else
         `uvm_info("SB", $sformatf("%0d compared, %0d errors", num_compared, num_errors), UVM_LOW)
   endfunction : report_phase

endclass : ncc_scoreboard
