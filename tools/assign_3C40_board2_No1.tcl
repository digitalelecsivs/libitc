######################################################################
### 115學年度數位電子術科參考試題     試題名稱：資訊顯示與座標控制系統  ###
### 試題一 	實作方塊2 	晶片 : EP3C40Q240C8N                        ###
### 請不要在這裡修改成其他板子的設定，請直接COPY到assign.tcl並覆蓋     ###
### 115.10.19  by chaosoyu										  ###
######################################################################

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
	# board_1 40Q
	set_global_assignment -name FAMILY "Cyclone III"
	set_global_assignment -name DEVICE EP3C40Q240C8
	set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
	# 將未使用的腳位強制設為「輸入高阻態」，防止被 FPGA 內部主動接地短路
	set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED WITH WEAK PULL-UP"

	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_145 -to rst_n

	# # BUZZER
	set_location_assignment PIN_226 -to buz

	# # LED_{R,G,Y}
	set_location_assignment PIN_81 -to led_r
	set_location_assignment PIN_78 -to led_g
	set_location_assignment PIN_73 -to led_y

	# WS2812B
	set_location_assignment PIN_84 -to D_out

	# ADS1115
	set_location_assignment PIN_95 -to js_scl
	set_location_assignment PIN_94 -to js_sda
	set_location_assignment PIN_99 -to js_sw
	set_location_assignment PIN_98 -to js_alrt

	# 1. 開啟開漏極輸出 (Open-Drain Output)
	#set_instance_assignment -name AUTO_OPEN_DRAIN_PINS ON -to js_scl
	#set_instance_assignment -name AUTO_OPEN_DRAIN_PINS ON -to js_sda

	# 2. 開啟內部弱上拉電阻 (Weak Pull-Up Resistor)
	set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to js_scl
	set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to js_sda

	# 3. 指定 3.3V I/O 電平標準 (確保準位匹配)
	#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to js_scl
	#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to js_sda

	# SEG{1,2}_{A..DOT}
	set_location_assignment PIN_230 -to seg_led[0]
	set_location_assignment PIN_224 -to seg_led[1]
	set_location_assignment PIN_221 -to seg_led[2]
	set_location_assignment PIN_218 -to seg_led[3]
	set_location_assignment PIN_216 -to seg_led[4]
	set_location_assignment PIN_207 -to seg_led[5]
	set_location_assignment PIN_202 -to seg_led[6]
	set_location_assignment PIN_200 -to seg_led[7]

	# # SW_{1..8}
	set_location_assignment PIN_9 -to sw[0]
	set_location_assignment PIN_18 -to sw[1]
	set_location_assignment PIN_22 -to sw[2]
	set_location_assignment PIN_38 -to sw[3]
	set_location_assignment PIN_37 -to sw[4]
	set_location_assignment PIN_21 -to sw[5]
	set_location_assignment PIN_13 -to sw[6]
	set_location_assignment PIN_6 -to sw[7]
 
	# PB_ROW & COL
	set_location_assignment PIN_70 -to PB_row[0]
	set_location_assignment PIN_76 -to PB_row[1]
	set_location_assignment PIN_80 -to PB_col[0]
	set_location_assignment PIN_82 -to PB_col[1]

	#board2 3C40 no used
	# KEY_row{0..2}
	#set_location_assignment PIN_45 -to key_row[0]
	#set_location_assignment PIN_49 -to key_row[1]
	#set_location_assignment PIN_51 -to key_row[2]
	# KEY_col{0..2}
	#set_location_assignment PIN_55 -to key_col[0]
	#set_location_assignment PIN_57 -to key_col[1]
	#set_location_assignment PIN_68 -to key_col[2]

	# SEG2_S{1..4}, SEG1_S{1..4}
	set_location_assignment PIN_69 -to seg_com[0]
	set_location_assignment PIN_63 -to seg_com[1]
	set_location_assignment PIN_56 -to seg_com[2]
	set_location_assignment PIN_52 -to seg_com[3]
	set_location_assignment PIN_50 -to seg_com[4]
	set_location_assignment PIN_46 -to seg_com[5]
	set_location_assignment PIN_44 -to seg_com[6]
	set_location_assignment PIN_41 -to seg_com[7]

	
	# LCD_{CLK,DAT,RES,DC,CS,BL}
	#1
	set_location_assignment PIN_166 -to lcd_sclk 
	set_location_assignment PIN_164 -to lcd_mosi
	set_location_assignment PIN_162 -to lcd_rst_n
	set_location_assignment PIN_161 -to lcd_dc 
	set_location_assignment PIN_160 -to lcd_ss_n
	set_location_assignment PIN_159 -to lcd_bl
	# DATA
	#set_location_assignment PIN_146 -to dht_data
	
	# # PWM{1..2}, IN{1,2,3,4}

	#set_location_assignment PIN_132 -to mot_ena[1]
	#set_location_assignment PIN_131 -to mot_ena[0]
	#set_location_assignment PIN_128 -to mot_ch[2]
	#set_location_assignment PIN_127 -to mot_ch[3]
	#set_location_assignment PIN_126 -to mot_ch[0]
	#set_location_assignment PIN_118 -to mot_ch[1]
	
	# Debug ports
	# pinlist 196 194 188 186 184 177 173 169
	#		  197 195 189 187 185 183 176 171     
	set_location_assignment PIN_196 -to dbg_a[0]
	set_location_assignment PIN_194 -to dbg_a[1]
	set_location_assignment PIN_188 -to dbg_a[2]
	set_location_assignment PIN_186 -to dbg_a[3]
	set_location_assignment PIN_184 -to dbg_a[4]
	set_location_assignment PIN_177 -to dbg_a[5]
	set_location_assignment PIN_173 -to dbg_a[6]
	set_location_assignment PIN_169 -to dbg_a[7]
	set_location_assignment PIN_197 -to dbg_b[0]
	set_location_assignment PIN_195 -to dbg_b[1]
	set_location_assignment PIN_189 -to dbg_b[2]
	set_location_assignment PIN_187 -to dbg_b[3]
	set_location_assignment PIN_185 -to dbg_b[4]
	set_location_assignment PIN_183 -to dbg_b[5]
	set_location_assignment PIN_176 -to dbg_b[6]
	set_location_assignment PIN_171 -to dbg_b[7]
	
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