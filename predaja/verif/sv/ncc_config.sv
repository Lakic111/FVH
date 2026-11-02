// Konfiguracija agenta.
class ncc_config extends uvm_object;

   uvm_active_passive_enum is_active = UVM_ACTIVE;

   `uvm_object_utils_begin(ncc_config)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
   `uvm_object_utils_end

   function new(string name = "ncc_config");
      super.new(name);
   endfunction

endclass : ncc_config
