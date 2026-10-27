# Load Quartus II Tcl Project package
package require ::quartus::project

# Load Quartus II Tcl Flow package
package require ::quartus::flow

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "libitc"]} {
		puts "Project libitc is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists libitc]} {
		project_open -revision libitc libitc
	} else {
		project_new -revision libitc libitc
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
	# Collect trash files
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

	# Speed up compilation
	set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT FAST
	set_global_assignment -name FITTER_EFFORT FAST_FIT
	set_global_assignment -name SYNTHESIS_EFFORT FAST
	set_global_assignment -name SMART_RECOMPILE ON
	set_global_assignment -name TIMEQUEST_MULTICORNER_ANALYSIS OFF
	# set_global_assignment -name SYNTH_TIMING_DRIVEN_SYNTHESIS OFF
	# set_global_assignment -name OPTIMIZE_POWER_DURING_SYNTHESIS OFF
	# set_global_assignment -name OPTIMIZE_HOLD_TIMING OFF
	# set_global_assignment -name OPTIMIZE_MULTI_CORNER_TIMING OFF
	# set_global_assignment -name OPTIMIZE_POWER_DURING_FITTING OFF
	# set_global_assignment -name OPTIMIZE_TIMING OFF
	# set_global_assignment -name OPTIMIZE_IOC_REGISTER_PLACEMENT_FOR_TIMING OFF
	# set_global_assignment -name OPTIMIZE_FOR_METASTABILITY OFF
	# set_global_assignment -name IO_PLACEMENT_OPTIMIZATION OFF
	# set_global_assignment -name FINAL_PLACEMENT_OPTIMIZATION NEVER
	# set_global_assignment -name ROUTER_TIMING_OPTIMIZATION_LEVEL MINIMUM
	# set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 0.000001
	# set_global_assignment -name ROUTER_EFFORT_MULTIPLIER 0.25

	# Disable unused pins
	set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

	# Source files
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
	
	
	# pkg
	set_global_assignment -name VHDL_FILE lib/pkg/itc.pkg.vhd
	set_global_assignment -name VHDL_FILE lib/pkg/lcd.pkg.vhd

	# bottom
	set_global_assignment -name VHDL_FILE lib/util/clk.vhd
	set_global_assignment -name VHDL_FILE lib/util/debounce.vhd
	set_global_assignment -name VHDL_FILE lib/util/edge.vhd
	set_global_assignment -name VHDL_FILE lib/util/pwm.vhd
	set_global_assignment -name VHDL_FILE lib/util/i2c.vhd
	set_global_assignment -name VHDL_FILE lib/util/timer.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart_txt.vhd

	# second
	set_global_assignment -name VHDL_FILE lib/font/Font.vhd
	set_global_assignment -name QIP_FILE lib/font/Font.qip
	# set_global_assignment -name VHDL_FILE lib/font/Font_numeric.vhd
	# set_global_assignment -name QIP_FILE lib/font/Font_numeric.qip
	set_global_assignment -name VHDL_FILE lib/font/Font_aph_num.vhd
	set_global_assignment -name QIP_FILE lib/font/Font_aph_num.qip
	set_global_assignment -name QIP_FILE lib/ip/framebuffer.qip

	set_global_assignment -name VHDL_FILE lib/dht.vhd
	set_global_assignment -name VHDL_FILE lib/dot.vhd
	set_global_assignment -name VHDL_FILE lib/key.vhd
	set_global_assignment -name VHDL_FILE lib/lcd.vhd
	set_global_assignment -name VHDL_FILE lib/mot.vhd
	set_global_assignment -name VHDL_FILE lib/rgb.vhd
	set_global_assignment -name VHDL_FILE lib/seg.vhd
	set_global_assignment -name VHDL_FILE lib/sw.vhd
	set_global_assignment -name VHDL_FILE lib/tsl.vhd
	set_global_assignment -name VHDL_FILE lib/tts.vhd
	set_global_assignment -name VHDL_FILE lib/WS2812B.vhd
	set_global_assignment -name VHDL_FILE lib/lcd_mix_intgr_aph.vhd
	set_global_assignment -name VHDL_FILE lib/lcd_mix.vhd
		# lcd_mix_inst : entity work.lcd_mix_intgr_aph(arch)

	# set_global_assignment -name VHDL_FILE lib/key_2x2_1.vhd

	
	set_global_assignment -name VHDL_FILE tests/WS2812_test1.vhd
	
	# set_global_assignment -name VHDL_FILE practices/114-jol/lcd/ox/O.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/lcd/ox/O.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/lcd/ox/X.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/lcd/ox/X.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/xilinx.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/xilinx.qip
	# src\itc114_2\board\v13_114_a.vhd
	# set_global_assignment -name VHDL_FILE C:/Users/user/Desktop/libitc/src/itc114_2/board/v13_114_a.vhd
	# set_global_assignment -name VHDL_FILE C:/Users/user/Desktop/libitc/practices/114-jol/test_0819.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/lcd/circle_cross_2.vhd

	set_global_assignment -name VHDL_FILE practices/311104/key_t.vhd
	# practices\114-jol\test_0819.vhd
	set_global_assignment -name TOP_LEVEL_ENTITY key_t
	# set_global_assignment -name TOP_LEVEL_ENTITY test_0819
	

	
	
	# Commit assignments
	export_assignments

	# Compile
	execute_flow -compile

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
