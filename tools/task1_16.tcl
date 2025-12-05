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

	# System
	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_145 -to rst_n
# 第一題board_b 腳位分配
	# I/O裝置： 
	# 		keyboard、uart
	
	set_global_assignment -name DEVICE EP3C16Q240C8

	# pinlist 39 43 45 49 , 51 55 57 68
	# KEY_COL{1..4} 
	set_location_assignment PIN_51 -to key_row[0] 
	set_location_assignment PIN_49 -to key_row[1]
	set_location_assignment PIN_45 -to key_row[2]
	set_location_assignment PIN_43 -to key_row[3]
	# KEY_ROW{1..4}
	set_location_assignment PIN_68 -to key_col[0]
	set_location_assignment PIN_64 -to key_col[1]
	set_location_assignment PIN_57 -to key_col[2]
	set_location_assignment PIN_55 -to key_col[3]
	# I/O版上的絲印是反的 The silkscreen on I/O board is reversed 

	# Debug Port
	set_location_assignment PIN_168 -to dbg_a[0]
	set_location_assignment PIN_171 -to dbg_a[1]
	set_location_assignment PIN_174 -to dbg_a[2]
	set_location_assignment PIN_176 -to dbg_a[3]
	
	# # UART_{TX,RX} (green, white)
	set_location_assignment PIN_231 -to uart_rx
	set_location_assignment PIN_232 -to uart_tx
	# Commit assignments
	export_assignments
	# Close project
	if {$need_to_close_project} {
		project_close
	}
}