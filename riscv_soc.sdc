# 50 MHz clock on the DE1-SoC board.
create_clock -name clk -period 20.000 [get_ports {clk}]
