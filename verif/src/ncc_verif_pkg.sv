// ============================================================================
// ncc_verif_pkg.sv -- zajednicki parametri verifikacionog okruzenja.
//
// NAZIV: paket se NE zove `ncc_pkg`, iako bi to bilo prirodnije.  DUT vec ima
// VHDL paket `work.ncc_pkg` (rtl/ncc_pkg.vhd), a u mesovitoj elaboraciji oba
// zavrsavaju u istoj biblioteci `work` -- isto ime bi bio sudar.
//
// Svaka konstanta ovde izvedena je iz RTL-a i navedena u poglavljima 2-4
// priloga `FVH_verifikacioni_plan_y25-g10.pdf`.  Nijedan magican broj ne sme
// kasnije da se pojavi u testovima.
// ============================================================================
package ncc_verif_pkg;

  // --- sirine magistrala (generici entiteta ncc_accel) ----------------------
  parameter int S00_ADDR_W = 6;    // C_S00_AXI_ADDR_WIDTH -- max adresa 0x3F
  parameter int S00_DATA_W = 32;
  parameter int S01_ID_W   = 1;    // C_S01_AXI_ID_WIDTH
  parameter int S01_ADDR_W = 17;   // C_S01_AXI_ADDR_WIDTH -- 128 KB
  parameter int S01_DATA_W = 32;

  // --- kontrolni registri, S00 ---------------------------------------------
  // Adresa 0x40 NE postoji: magistrala je 6-bitna.  Mapa rezultata je na S01,
  // region 10 (vidi S01_RESULT_BASE nize).
  parameter bit [S00_ADDR_W-1:0] REG_IMG_W  = 6'h00;  // slv_reg0,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_IMG_H  = 6'h04;  // slv_reg1,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_TMP_W  = 6'h08;  // slv_reg2,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_TMP_H  = 6'h0C;  // slv_reg3,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_CTRL   = 6'h30;  // slv_reg12, upis bit0 = start
  parameter bit [S00_ADDR_W-1:0] REG_STATUS = 6'h34;  // slv_reg13, samo citanje

  parameter int CTRL_START_BIT   = 0;
  parameter int STATUS_DONE_BIT  = 0;  // done_sticky
  parameter int STATUS_BUSY_BIT  = 1;  // core_busy

  // Registri koje ncc_accel ne vodi ni na jedan port jezgra (test T2).
  // 0x10 i 0x14 su u ranijim beleskama imenovani kao REG_IMG_ADDR/REG_TMP_ADDR,
  // ali u RTL-u nemaju nikakvo dejstvo.
  parameter bit [S00_ADDR_W-1:0] REG_SCRATCH[8] = '{
    6'h10, 6'h14, 6'h18, 6'h1C, 6'h20, 6'h24, 6'h28, 6'h2C
  };

  // --- memorijski prostor, S01 ---------------------------------------------
  // region = addr[16:15], word = addr[14:2].  Jedan piksel po 32-bitnoj reci.
  typedef enum bit [1:0] {
    REGION_IMG    = 2'b00,
    REGION_TMP    = 2'b01,
    REGION_RESULT = 2'b10,   // samo citanje: wea porta A je trajno '0'
    REGION_NONE   = 2'b11    // nemapirano: vraca nule, ne DECERR
  } region_e;

  parameter bit [S01_ADDR_W-1:0] S01_IMG_BASE    = 17'h00000;
  parameter bit [S01_ADDR_W-1:0] S01_TMP_BASE    = 17'h08000;
  parameter bit [S01_ADDR_W-1:0] S01_RESULT_BASE = 17'h10000;
  parameter bit [S01_ADDR_W-1:0] S01_NONE_BASE   = 17'h18000;

  // Dubina memorija (dp_bram ADDR_W).  Sablon koristi samo word[9:0] od 13 bita,
  // pa se adrese na razmaku od TMP_WORDS reci preklapaju (aliasing, test T14).
  parameter int IMG_WORDS    = 8192;   // 2**13
  parameter int TMP_WORDS    = 1024;   // 2**10  <-- izvor aliasinga
  parameter int RESULT_WORDS = 8192;   // 2**13

  // --- ugovor sa softverom (tvrdnje u ncc_core, severity failure) ----------
  // Krsenje NE obara test nego CELU simulaciju.  Ogranicenja randomizacije
  // moraju ovo garantovati -- vidi poglavlje 2 priloga.
  parameter int MAX_IMG_W   = 90;
  parameter int MAX_IMG_H   = 90;
  parameter int MAX_TMP_W   = 30;
  parameter int MAX_TMP_H   = 30;
  parameter int MAX_TMP_PIX = 900;   // MAX_TMP_W * MAX_TMP_H

  // --- redosled kanala AW i W ----------------------------------------------
  // Sredisnja meta plana.  Popravljeni S00 nikada ne drzi awready i wready u
  // istom taktu, pa drajver mora voditi kanale kao nezavisne niti.
  typedef enum {
    ORDER_AW_FIRST,
    ORDER_W_FIRST,
    ORDER_SIMUL
  } aw_w_order_e;

endpackage : ncc_verif_pkg
