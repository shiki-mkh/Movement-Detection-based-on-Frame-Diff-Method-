create_clock -name altera_reserved_clk -period 100.000 -waveform {0 50} altera_reserved_clk
create_clock -name clk -period 20 -waveform {0 10} clk
create_clock -name cam_pclk -period 10 -waveform {0 5} cam_pclk


#derive_clocks -period 1.0

#derive_pll_clocks -create_base_clocks -use_net_name

#report_clocks -name auto_generated_clocks

# I2C生成时钟约束 
#create_generated_clock \
    -name ctrl_clk \
    -source [get_pins {u_i2c_ctrl|clk}] \
    -divide_by 24 \
    -master_clock clk_vga \
    [get_pins{u_i2c_ctrl|ctrl_clk} ]
	 



set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 