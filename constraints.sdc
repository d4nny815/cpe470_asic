puts "\[INFO\]: Creating Clocks"
create_clock [get_ports CLK_200MHz] -name CLK_200MHz -period 5
set_propagated_clock CLK_200MHz
create_clock [get_ports axi_clk] -name axi_clk -period 10
set_propagated_clock axi_clk
create_clock [get_ports vga_clk] -name vga_clk -period 40
set_propagated_clock vga_clk

set_clock_groups -asynchronous -group [get_clocks {CLK_200MHz, axi_clk vga_clk}]