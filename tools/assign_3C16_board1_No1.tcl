######################################################################
### 115學年度數位電子術科參考試題     試題名稱：資訊顯示與座標控制系統  ###
### 試題一 	實作方塊1 	晶片 : EP3C16Q240C8N                        ###
### 請不要在這裡修改成其他板子的設定，請直接COPY到assign.tcl並覆蓋     ###
### 115.10.19  by chaosoyu										  ###
######################################################################

# Load Quartus II Tcl Project package
package require ::quartus::project

#set project_name "test_1"
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
	set_global_assignment -name DEVICE EP3C16Q240C8
	set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"

	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_145 -to rst_n
	
	# KEY_row{0.2}
	set_location_assignment PIN_49 -to key_row[0]
	set_location_assignment PIN_51 -to key_row[1]
	set_location_assignment PIN_55 -to key_row[2]

	# KEY_col{0..2}
	set_location_assignment PIN_57 -to key_col[0]
	set_location_assignment PIN_64 -to key_col[1]
	set_location_assignment PIN_68 -to key_col[2]

	# Debug ports
	set_location_assignment PIN_168 -to dbg_a[0]
	set_location_assignment PIN_171 -to dbg_a[1]
	set_location_assignment PIN_174 -to dbg_a[2]
	set_location_assignment PIN_176 -to dbg_a[3]
	set_location_assignment PIN_181 -to dbg_a[4]
	set_location_assignment PIN_183 -to dbg_a[5]
	set_location_assignment PIN_185 -to dbg_a[6]
	set_location_assignment PIN_187 -to dbg_a[7]
	

	# # UART_{TX,RX} (green, white)
	set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to uart_tx
	set_location_assignment PIN_231 -to uart_rx
	set_location_assignment PIN_232 -to uart_tx

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
