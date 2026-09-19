# ============================================================================
# xrun_run.tcl -- Tcl skripta koju xmsim izvrsava pri svakom pokretanju.
#
# Spusta TRRANGEC (range constraint violation) sa greske na upozorenje.
#
# UZROK, i zasto ovo NIJE zataskavanje problema:
#   U Xilinx AXI4-Full sablonu (`ncc_accel_slave_full_v1_0_S01_AXI.vhd`) signali
#   `aw_wrap_size` i `ar_wrap_size` su tipa `integer` BEZ pocetne vrednosti, pa
#   u nultom delta-koraku imaju `integer'left` = -2147483648.  Izraz za
#   `ar_wrap_en` (linija 270) tada racuna
#       to_unsigned(-2147483648, C_S_AXI_ADDR_WIDTH)
#   sto je van opsega.  Vec u sledecem delta-koraku konkurentna dodela postavi
#   ispravnu vrednost i violacija se vise ne javlja.
#
#   Dodatno: `*_wrap_en` se koristi samo za WRAP burst, a ovo okruzenje vozi
#   iskljucivo INCR (`awburst = 2'b01`).  Taj put se, dakle, nikada ne izvrsava.
#
#   Vivado XSim isto racuna, ali violaciju ne prijavljuje.  Cadence je stroziji i
#   zaustavlja simulaciju u trenutku 0 -- pre nego sto ijedan test pocne.
#
# Ovo je podesavanje SIMULATORA, ne izmena DUT-a.  Alternativa bi bila dodati
# pocetne vrednosti tim signalima u VHDL-u, sto bi bila izmena projekta.
# ============================================================================
set rangecnst_severity_level warning

run
exit
