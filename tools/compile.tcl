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
	set_global_assignment -name TOP_LEVEL_ENTITY v1_114_2
	

	# Unit tests
	# 第二題
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/board/v1_114_2.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/board/v1_114_2.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/test/buzzer.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/lcd/circle_cross_1.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/dot/game.vhd

	set_global_assignment -name MIF_FILE practices/114-jol/114_2_v1/pic/font.mif
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n0.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n0.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n1.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n1.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n2.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n2.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n3.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n3.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n4.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n4.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n5.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n5.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n6.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n6.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n7.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n7.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n8.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n8.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/n9.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/n9.vhd

	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/F.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/F.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/O.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/O.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/R.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/R.vhd
	set_global_assignment -name QIP_FILE practices/114-jol/114_2_v1/pic1/X.qip
	set_global_assignment -name VHDL_FILE practices/114-jol/114_2_v1/pic1/X.vhd

	# 第一題
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/board_1/v1_114_1_a.vhd
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/board_2/v1_114_1_b.vhd

	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n1.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n1.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n2.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n2.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n3.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n3.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n4.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n4.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n5.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n5.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n6.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n6.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n7.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n7.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n8.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n8.vhd
	# set_global_assignment -name QIP_FILE practices/114-jol/114_1_v1/pic/n9.qip
	# set_global_assignment -name VHDL_FILE practices/114-jol/114_1_v1/pic/n9.vhd

	## Components
	set_global_assignment -name VHDL_FILE lib/lcd_mix.vhd
	set_global_assignment -name VHDL_FILE lib/font/Font.vhd
	set_global_assignment -name QIP_FILE lib/font/Font.qip
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
	set_global_assignment -name VHDL_FILE lib/pkg/itc.pkg.vhd
	set_global_assignment -name VHDL_FILE lib/pkg/lcd.pkg.vhd
	set_global_assignment -name VHDL_FILE lib/util/clk.vhd
	set_global_assignment -name VHDL_FILE lib/util/debounce.vhd
	set_global_assignment -name VHDL_FILE lib/util/edge.vhd
	set_global_assignment -name VHDL_FILE lib/util/pwm.vhd
	set_global_assignment -name VHDL_FILE lib/util/i2c.vhd
	set_global_assignment -name VHDL_FILE lib/util/timer.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart_txt.vhd
	set_global_assignment -name QIP_FILE lib/ip/framebuffer.qip
	set_global_assignment -name VHDL_FILE lib/key_2x2_1.vhd
	# Commit assignments
	export_assignments

	# Compile
	execute_flow -compile

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
