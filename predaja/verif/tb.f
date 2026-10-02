# Filelist SV/UVM izvora. Putanje su relativne u odnosu na verif/.
# Redosled: zajednicki paket -> interfejsi -> agenti -> ref. model -> env ->
# sekvence -> testovi -> top.  Klase su u zasebnim fajlovima i ulaze u svoj
# paket preko `include, zato su direktorijumi paketa navedeni kao +incdir+.

+incdir+src/axil_agent
+incdir+src/axif_agent
+incdir+src/env
+incdir+src/sequences
+incdir+tests

src/ncc_verif_pkg.sv
src/interfaces/axi_lite_if.sv
src/interfaces/axi_full_if.sv
src/axil_agent/ncc_axil_pkg.sv
src/axif_agent/ncc_axif_pkg.sv
src/ref_model/ncc_ref_pkg.sv
src/env/ncc_env_pkg.sv
src/sequences/ncc_seq_pkg.sv
tests/ncc_test_pkg.sv
tb/tb_top.sv
