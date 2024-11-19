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
	set_global_assignment -name TOP_LEVEL_ENTITY test113_2

	# Unit tests
	# set_global_assignment -name VHDL_FILE practices/50-choco/mot_test/mot_test.vhd
	set_global_assignment -name VHDL_FILE practices/50-choco/113_2_11_19/test113_2.vhd
	set_global_assignment -name VHDL_FILE practices/50-choco/113_2_11_19/price.vhd
	set_global_assignment -name QIP_FILE practices/50-choco/113_2_11_19/price.qip
	set_global_assignment -name VHDL_FILE practices/50-choco/113_2_11_19/FEED.vhd
	set_global_assignment -name QIP_FILE practices/50-choco/113_2_11_19/FEED.qip
	set_global_assignment -name VHDL_FILE practices/50-choco/113_2_11_19/egg.vhd
	set_global_assignment -name QIP_FILE practices/50-choco/113_2_11_19/egg.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_2/Logo_SIVS.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_2/Logo_SIVS.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_2/FEED.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_2/FEED.qip
			
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/test113_1.vhd
	# set_global_assignment -name VHDL_FILE practices/30-dora/tts_Jay/ser/tts_stop.vhd
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/diamond.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/diamond.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/circle.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/circle.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/hexagon.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/hexagon.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/octagon.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/octagon.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/rectangle.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/rectangle.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/rectangle_y.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/rectangle_y.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/square.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/square.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/triangle.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/triangle.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/triangle_r.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/triangle_r.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/heart.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/heart.qip
	
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/wifi.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/wifi.qip

	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/triangle_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/triangle_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/square_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/square_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/diamond_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/diamond_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/circle_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/circle_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/hexagon_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/hexagon_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/octagon_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/octagon_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/rectangle_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/rectangle_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/triangle_s_r.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/triangle_s_r.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_18/pic/heart_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_18/pic/heart_s.qip


	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/test113_1.vhd
	# set_global_assignment -name VHDL_FILE practices/30-dora/tts_Jay/ser/tts_stop.vhd
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/diamond.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/diamond.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/circle.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/circle.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/square.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/square.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/triangle.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/triangle.qip

	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/heart.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/heart.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/parallelogram.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/parallelogram.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/Q.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/Q.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/star.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/star.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/X.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/X.qip

	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/wifi1.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/wifi1.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/wifi2.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/wifi2.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/wifi3.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/wifi3.qip	
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/wifi4.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/wifi4.qip


	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/line1.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/line1.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/line2.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/line2.qip

	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/triangle_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/triangle_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/square_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/square_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/diamond_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/diamond_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/circle_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/circle_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/heart_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/heart_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/parallelogram_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/parallelogram_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/Q_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/Q_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/star_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/star_s.qip
	# set_global_assignment -name VHDL_FILE practices/50-choco/113_1_11_15/pic/X_s.vhd
	# set_global_assignment -name QIP_FILE practices/50-choco/113_1_11_15/pic/X_s.qip



	# set_global_assignment -name VHDL_FILE src/itc112_2/itc112_2.vhd

	# set_global_assignment -name VHDL_FILE src/itc112_1/pic/tri/tri_red7.vhd
	# set_global_assignment -name QIP_FILE src/itc112_1/pic/tri/tri_red7.qip
	# set_global_assignment -name VHDL_FILE src/itc112_1/pic/shape_1/shape_1.vhd
	# set_global_assignment -name QIP_FILE src/itc112_1/pic/shape_1/shape_1.qip
	# set_global_assignment -name VHDL_FILE src/itc112_1/pic/shape_2/shape_2.vhd
	# set_global_assignment -name QIP_FILE src/itc112_1/pic/shape_2/shape_2.qip

	# set_global_assignment -name VHDL_FILE src/itc112_1/itc112_1.vhd

  	# set_global_assignment -name VHDL_FILE practices/30-dora/tts_Jay/ser/tts_stop.vhd

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
