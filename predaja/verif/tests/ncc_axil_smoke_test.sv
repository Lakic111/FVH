// S00: upis i citanje registara, sva tri AW/W redosleda.
// Sekvencer i drajver se ovde grade rucno; agent dolazi u sledecem testu.
class ncc_axil_smoke_test extends uvm_test;
  `uvm_component_utils(ncc_axil_smoke_test)

  ncc_axil_sequencer sqr;
  ncc_axil_driver    drv;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = ncc_axil_sequencer::type_id::create("sqr", this);
    drv = ncc_axil_driver   ::type_id::create("drv", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

  task run_phase(uvm_phase phase);
    ncc_reg_rw_seq seq = ncc_reg_rw_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(sqr);
    phase.drop_objection(this);
  endtask

endclass : ncc_axil_smoke_test
