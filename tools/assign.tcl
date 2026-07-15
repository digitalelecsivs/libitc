# Load Quartus II Tcl Project package
package require ::quartus::project

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
	set_global_assignment -name FAMILY "Cyclone III"
	
	set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"

	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_145 -to rst_n
# 第二題board_a 腳位分配
	# I/O裝置： 
	# 		SW、keyboard、seg、dot、lcd、buzzer、led_rgy、rgb_led、uart

	set_global_assignment -name DEVICE EP3C16Q240C8
	
	
	set_location_assignment PIN_127 -to D_out
	
	set_location_assignment PIN_131 -to dbg_a[0]
	set_location_assignment PIN_132 -to dbg_a[1]
	set_location_assignment PIN_133 -to dbg_a[2]
	set_location_assignment PIN_134 -to dbg_a[3]
	set_location_assignment PIN_135 -to dbg_a[4]
	set_location_assignment PIN_137 -to dbg_a[5]
	set_location_assignment PIN_139 -to dbg_a[6]
	set_location_assignment PIN_142 -to dbg_a[7]

	set_location_assignment PIN_146 -to dbg_b[0]
	set_location_assignment PIN_147 -to dbg_b[1]
	set_location_assignment PIN_148 -to dbg_b[2]
	set_location_assignment PIN_159 -to dbg_b[3]

	set_location_assignment PIN_101 -to sw[0]
	set_location_assignment PIN_103 -to sw[1]
	set_location_assignment PIN_107 -to sw[2]
	set_location_assignment PIN_109 -to sw[3]
	set_location_assignment PIN_111 -to sw[4]
	set_location_assignment PIN_113 -to sw[5]
	set_location_assignment PIN_117 -to sw[6]
	set_location_assignment PIN_119 -to sw[7]
	set_location_assignment PIN_126 -to button
	# set_location_assignment PIN_126 -to ena
	# set_location_assignment PIN_128 -to busy 		
	# set_instance_assignment -name CURRENT_STRENGTH_NEW 4MA -to PWM
    # set_instance_assignment -name SLEW_RATE 0 -to PWM
	# Commit assignments
	export_assignments
	# Close project
	if {$need_to_close_project} {
		project_close
	}
}