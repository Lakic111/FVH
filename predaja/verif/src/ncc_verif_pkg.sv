// Zajednicki parametri verifikacionog okruzenja, izvedeni iz RTL-a.
package ncc_verif_pkg;

  // --- sirine magistrala (generici entiteta ncc_accel) ----------------------
  parameter int S00_ADDR_W = 6;    // C_S00_AXI_ADDR_WIDTH -- max adresa 0x3F
  parameter int S00_DATA_W = 32;
  parameter int S01_ID_W   = 1;    // C_S01_AXI_ID_WIDTH
  parameter int S01_ADDR_W = 17;   // C_S01_AXI_ADDR_WIDTH -- 128 KB
  parameter int S01_DATA_W = 32;

  // --- kontrolni registri, S00 ---------------------------------------------
  parameter bit [S00_ADDR_W-1:0] REG_IMG_W  = 6'h00;  // slv_reg0,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_IMG_H  = 6'h04;  // slv_reg1,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_TMP_W  = 6'h08;  // slv_reg2,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_TMP_H  = 6'h0C;  // slv_reg3,  bitovi 7:0
  parameter bit [S00_ADDR_W-1:0] REG_CTRL   = 6'h30;  // slv_reg12, upis bit0 = start
  parameter bit [S00_ADDR_W-1:0] REG_STATUS = 6'h34;  // slv_reg13, samo citanje

  parameter int CTRL_START_BIT   = 0;
  parameter int STATUS_DONE_BIT  = 0;  // done_sticky
  parameter int STATUS_BUSY_BIT  = 1;  // core_busy

  // Registri bez dejstva u jezgru (test T2).
  parameter bit [S00_ADDR_W-1:0] REG_SCRATCH[8] = '{
    6'h10, 6'h14, 6'h18, 6'h1C, 6'h20, 6'h24, 6'h28, 6'h2C
  };

  // --- memorijski prostor, S01 ---------------------------------------------
  // region = addr[16:15], word = addr[14:2].
  typedef enum bit [1:0] {
    REGION_IMG    = 2'b00,
    REGION_TMP    = 2'b01,
    REGION_RESULT = 2'b10,   // samo citanje
    REGION_NONE   = 2'b11    // nemapirano
  } region_e;

  parameter bit [S01_ADDR_W-1:0] S01_IMG_BASE    = 17'h00000;
  parameter bit [S01_ADDR_W-1:0] S01_TMP_BASE    = 17'h08000;
  parameter bit [S01_ADDR_W-1:0] S01_RESULT_BASE = 17'h10000;
  parameter bit [S01_ADDR_W-1:0] S01_NONE_BASE   = 17'h18000;

  parameter int IMG_WORDS    = 8192;   // 2**13
  parameter int TMP_WORDS    = 1024;   // 2**10 -- izvor aliasinga (P2)
  parameter int RESULT_WORDS = 8192;   // 2**13

  // --- ugovor sa softverom (tvrdnje u ncc_core, severity failure) ----------
  parameter int MAX_IMG_W   = 90;
  parameter int MAX_IMG_H   = 90;
  parameter int MAX_TMP_W   = 30;
  parameter int MAX_TMP_H   = 30;
  parameter int MAX_TMP_PIX = 900;

  // --- redosled kanala AW i W ----------------------------------------------
  typedef enum {
    ORDER_AW_FIRST,
    ORDER_W_FIRST,
    ORDER_SIMUL
  } aw_w_order_e;

endpackage : ncc_verif_pkg
