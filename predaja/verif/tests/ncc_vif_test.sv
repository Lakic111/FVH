// Virtuelni interfejsi stizu kroz uvm_config_db, DUT miruje.
class ncc_vif_test extends uvm_test;
  `uvm_component_utils(ncc_vif_test)

  virtual axi_lite_if #(.ADDR_W(S00_ADDR_W), .DATA_W(S00_DATA_W)) axil_vif;
  virtual axi_full_if #(.ID_W(S01_ID_W), .ADDR_W(S01_ADDR_W),
                        .DATA_W(S01_DATA_W))                      axif_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi_lite_if #(.ADDR_W(S00_ADDR_W),
                                              .DATA_W(S00_DATA_W)))
          ::get(this, "", "axil_vif", axil_vif))
      `uvm_fatal("NOVIF", "axil_vif nije nadjen u uvm_config_db")

    if (!uvm_config_db#(virtual axi_full_if #(.ID_W(S01_ID_W),
                                              .ADDR_W(S01_ADDR_W),
                                              .DATA_W(S01_DATA_W)))
          ::get(this, "", "axif_vif", axif_vif))
      `uvm_fatal("NOVIF", "axif_vif nije nadjen u uvm_config_db")

    `uvm_info("VIF", "oba virtuelna interfejsa preuzeta iz uvm_config_db", UVM_LOW)
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    wait (axil_vif.rstn === 1'b1);
    `uvm_info("VIF", "reset otpusten, S00 vidljiv preko vif-a", UVM_LOW)

    wait (axif_vif.rstn === 1'b1);
    `uvm_info("VIF", "reset otpusten, S01 vidljiv preko vif-a", UVM_LOW)

    repeat (20) @(posedge axil_vif.clk);

    if (axil_vif.bvalid !== 1'b0 || axil_vif.rvalid !== 1'b0)
      `uvm_error("IDLE", $sformatf("S00 nije u mirovanju: bvalid=%0b rvalid=%0b",
                                   axil_vif.bvalid, axil_vif.rvalid))
    if (axif_vif.bvalid !== 1'b0 || axif_vif.rvalid !== 1'b0)
      `uvm_error("IDLE", $sformatf("S01 nije u mirovanju: bvalid=%0b rvalid=%0b",
                                   axif_vif.bvalid, axif_vif.rvalid))

    `uvm_info("VIF", "okruzenje se pokrece i uredno zavrsava bez transakcija", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass : ncc_vif_test
