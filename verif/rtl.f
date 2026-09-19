# Filelist VHDL izvora DUT-a (ncc_accel).
# Redosled je preuzet iz SVI_IZVORI u PSDS_Projekat_MOJ/src/script/run_sim.tcl --
# taj redosled je dokazan u XSim-u, ne menjati ga.
#
# Fajlovi u rtl/ su ZAMRZNUTA KOPIJA iz PSDS_Projekat_MOJ/src/vhdl/ (2026-09-05).
# DUT se ne menja odavde. Ako se original promeni, kopija se osvezava svesno.
#
# Putanje su relativne u odnosu na verif/ da bi se ceo folder preneo na
# udaljenu masinu (Xcelium, korak 7) bez ijedne izmene.
#
# VHDL-2008 je OBAVEZAN -- ncc_core koristi `process (all)`.

rtl/ncc_pkg.vhd
rtl/dp_bram.vhd
rtl/mem_subsystem.vhd
rtl/ncc_core.vhd
rtl/ncc_accel_slave_lite_v1_0_S00_AXI.vhd
rtl/ncc_accel_slave_full_v1_0_S01_AXI.vhd
rtl/ncc_accel.vhd
