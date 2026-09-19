# Filelist SystemVerilog/UVM izvora verifikacionog okruzenja.
# Redosled je obavezan: paket -> interfejsi -> testovi -> top.
# Putanje relativne u odnosu na verif/ (vidi rtl.f).
#
# src/tb_mixed_probe.sv je namerno izostavljen: odradio je svoje u Sesiji 0
# (dokaz da XSim elaborira VHDL i SV zajedno) i zamenjen je sa src/tb_top.sv.
# Fajl je zadrzan kao zapis tog dokaza.

src/ncc_verif_pkg.sv
src/axi_lite_if.sv
src/axi_full_if.sv
src/ncc_axil_pkg.sv
src/ncc_axif_pkg.sv
src/ncc_ref_pkg.sv
src/ncc_env_pkg.sv
tests/ncc_test_pkg.sv
src/tb_top.sv
