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
# 第一題board_a 腳位分配
	# I/O裝置： 
	# 		SW、seg、lcd、tts、uart

	set_global_assignment -name DEVICE EP3C40Q240C8

	# SW_{1..8}
	set_location_assignment PIN_69 -to sw[0]
	set_location_assignment PIN_63 -to sw[1]
	set_location_assignment PIN_56 -to sw[2]
	set_location_assignment PIN_52 -to sw[3]
	set_location_assignment PIN_50 -to sw[4]
	set_location_assignment PIN_46 -to sw[5]
	set_location_assignment PIN_44 -to sw[6]
	set_location_assignment PIN_41 -to sw[7]

	# SEG{1,2}_{A..DOT}
	set_location_assignment PIN_230 -to seg_led[0]
	set_location_assignment PIN_224 -to seg_led[1]
	set_location_assignment PIN_221 -to seg_led[2]
	set_location_assignment PIN_218 -to seg_led[3]
	set_location_assignment PIN_216 -to seg_led[4]
	set_location_assignment PIN_207 -to seg_led[5]
	set_location_assignment PIN_202 -to seg_led[6]
	set_location_assignment PIN_200 -to seg_led[7]

	# SEG2_S{1..4}, SEG1_S{1..4}
	set_location_assignment PIN_9 -to seg_com[0]
	set_location_assignment PIN_18 -to seg_com[1]
	set_location_assignment PIN_22 -to seg_com[2]
	set_location_assignment PIN_38 -to seg_com[3]
	set_location_assignment PIN_6 -to seg_com[4]
	set_location_assignment PIN_13 -to seg_com[5]
	set_location_assignment PIN_21 -to seg_com[6]
	set_location_assignment PIN_37 -to seg_com[7]

	# LCD_{CLK,DAT,RES,DC,CS,BL}
	set_location_assignment PIN_166 -to lcd_sclk 
	set_location_assignment PIN_164 -to lcd_mosi
	set_location_assignment PIN_162 -to lcd_rst_n
	set_location_assignment PIN_161 -to lcd_dc 
	set_location_assignment PIN_160 -to lcd_ss_n
	set_location_assignment PIN_159 -to lcd_bl

	# tts 
	# SCL1, SDA1, MO{2..0}, RES
	set_location_assignment PIN_144 -to tts_scl
	set_location_assignment PIN_143 -to tts_sda
	set_location_assignment PIN_142 -to tts_mo[2]
	set_location_assignment PIN_139 -to tts_mo[1]
	set_location_assignment PIN_137 -to tts_mo[0]
	set_location_assignment PIN_135 -to tts_rst_n

	# Debug ports
	# pinlist 196 194 188 186 184 177 173 169
	#		  197 195 189 187 185 183 176 171     
	set_location_assignment PIN_196 -to dbg_a[0]
	set_location_assignment PIN_194 -to dbg_a[1]
	set_location_assignment PIN_188 -to dbg_a[2]
	set_location_assignment PIN_186 -to dbg_a[3]
	set_location_assignment PIN_197 -to dbg_b[0]
	set_location_assignment PIN_195 -to dbg_b[1]
	set_location_assignment PIN_189 -to dbg_b[2]
	set_location_assignment PIN_187 -to dbg_b[3]
	set_location_assignment PIN_185 -to dbg_b[4]
	set_location_assignment PIN_183 -to dbg_b[5]
	set_location_assignment PIN_176 -to dbg_b[6]
	set_location_assignment PIN_239 -to dbg_b[7]

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
