# Spusta TRRANGEC (range constraint violation) sa greske na upozorenje.
#
# Uzrok: u Xilinx AXI4-Full sablonu (S01_AXI.vhd) su aw_wrap_size/ar_wrap_size
# tipa integer bez pocetne vrednosti, pa u nultom delta-koraku racunaju
# to_unsigned(-2147483648, ...), sto je van opsega. Sledeci delta-korak vec
# postavlja ispravnu vrednost. Put se koristi samo za WRAP burst, a ovo
# okruzenje vozi iskljucivo INCR -- taj put se nikad ne izvrsava.
# Vivado XSim ovo isto racuna ali ne prijavljuje; Cadence je stroziji.
# Podesavanje simulatora, ne izmena DUT-a.
set rangecnst_severity_level warning

run
exit
