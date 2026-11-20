----------------------------------------------------------------------------
--115學年度數位電子術科參考試題一     ***試題名稱：資訊顯示與座標控制系統 ***
--實作方塊二  :  EP3C40Q240C8N    
--115.10.18 by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity Board2_115_top is
	port (
		-- System Pins
		clk   : in std_logic; -- PIN_149
		rst_n : in std_logic; -- PIN_145

		-- SW (for S0/S1)
		sw : in u8r_t;

		-- WS2812 RGB LED Pin
		D_out : out std_logic; -- PIN_84

		-- ADS1115 (Joystick ADC) Pins
		js_scl : inout std_logic; -- PIN_95
		js_sda : inout std_logic; -- PIN_94

		-- Joystick Switch Pin
		js_sw : in std_logic; -- PIN_99

		-- 2x2 Keypad Pins
		PB_row : in u2r_t;  -- PIN_70, PIN_76
		PB_col : out u2r_t; -- PIN_80, PIN_82

		-- LCD 實體腳位
		lcd_sclk  : out std_logic;
		lcd_mosi  : out std_logic;
		lcd_ss_n  : out std_logic;
		lcd_dc    : out std_logic;
		lcd_bl    : out std_logic;
		lcd_rst_n : out std_logic;

		-- uart 接收 (接收 key_uart_tx_top 傳送之 STX/ETX 封包)
		uart_rx : in std_logic;

		-- 七段顯示器 Pins
		seg_led : out u8r_t; -- PIN_230, 224, 221, 218, 216, 207, 202, 200
		seg_com : out u8r_t  -- PIN_69, 63, 56, 52, 50, 46, 44, 41
	);
end Board2_115_top;

architecture arch of Board2_115_top is

	constant C_TXT_LEN : integer := 16;

	signal lcd_line : integer range 0 to 2 := 0;

	-- 定義字串型別
	subtype string_12 is string(1 to 12);

	-- 定義字串陣列型別
	type st_arr_t is array (0 to 8) of string_12;

	-- 宣告並初始化字串陣列常數
	constant MSG_TABLE : st_arr_t := (
		0 => "ABCD        ",
		1 => "EFGH        ",
		2 => "IJKL        ",
		3 => "MNOP        ",
		4 => "QRST        ",
		5 => "UVWX        ",
		6 => "YZ          ",
		7 => "ABCD        ",
		8 => "EFGH        "
	);

	-- 模式 00：LCD 上顯示的座標與文字指標（[0,0] ~ [8,8] 循環）
	signal x : integer range 0 to 8 := 0;
	signal y : integer range 0 to 8 := 0;
	signal i : integer range 0 to 6 := 0;

	type state_m2_t is (
		ST_WAIT_START,
		ST_RGB_SCAN,
		ST_JOYSTICK_CTRL
	);
	signal state_m2 : state_m2_t := ST_WAIT_START;

	-- timer 與同步計時
	signal one_sec_tick : std_logic;
	signal clk_1s       : std_logic;
	signal timer_ena    : std_logic;
	signal sec_cnt      : integer range 0 to sys_clk_freq - 1 := 0;
	signal lcd_started  : std_logic := '0';

	-- 模式 11 專用狀態（固定 ABCD + 搖桿控制 2x2 方塊座標 [X,Y]）
	signal m3_active          : std_logic := '0';
	signal box_x_m3           : integer range 1 to 7 := 4;
	signal box_y_m3           : integer range 1 to 7 := 4;
	signal lcd_x_m3           : integer range 0 to 7 := 4;
	signal lcd_y_m3           : integer range 0 to 7 := 4;
	signal joystick_locked_m3 : std_logic := '0';
	signal js_move_cnt_m3     : integer range 0 to sys_clk_freq := 0;

	-- push button and joystick
	signal key_pressed      : std_logic;
	signal key_code         : i4_t;
	signal pb_pressed_edge  : std_logic;
	signal pb1_trig         : std_logic;

	signal js_sw_debounced : std_logic;
	signal js_sw_pressed   : std_logic;
	signal js_sw_edge      : std_logic;

	-- 單位：毫秒，搖桿冷卻延遲 250 毫秒
	constant COOL_DOWN_TICKS : integer := (sys_clk_freq / 1000) * 250;

	-- 0.1s (100 ms) : sys_clk_freq / 10
	-- 0.5s (500 ms) : sys_clk_freq / 2
	-- 1s (1000 ms) : sys_clk_freq
	-- 2s (2000 ms) : sys_clk_freq * 2
	-- 3s (3000 ms) : sys_clk_freq * 3


	
	-- 搖桿 ADC 閾值常數定義
	constant JS_Y_UP_TH    : u16_t := x"1000";
	constant JS_Y_DOWN_TH  : u16_t := x"5000";
	constant JS_X_LEFT_TH  : u16_t := x"1000";
	constant JS_X_RIGHT_TH : u16_t := x"4500";
	constant JS_MIN_TH     : u16_t := x"000A";

	-- 時脈脈衝與 ADS1115 訊號
	signal clk_0p3s  : std_logic;
	signal scan_tick : std_logic;

	signal x_raw      : u16_t;
	signal y_raw      : u16_t;
	signal data_valid : std_logic;

	signal joystick_locked : std_logic := '0';
	signal js_move_cnt     : integer range 0 to sys_clk_freq := 0;

	-- WS2812 與七段顯示器
	signal ws_ena   : std_logic := '0';
	signal ws_busy  : std_logic;
	signal rgb_arr  : l_px_arr_t(0 to 63) := (others => (others => '0'));
	signal seg_data : string(1 to 8) := "        ";

	-- WS2812 座標定義（模式 10：X 為水平欄位 1..8，Y 為垂直列數 1..8）
	signal scan_x : integer range 1 to 8 := 3;
	signal scan_y : integer range 1 to 8 := 1;

	signal box_x : integer range 1 to 7 := 4;
	signal box_y : integer range 1 to 7 := 4;

	-- LCD 內部控制與 lcd_mix 連接訊號
	signal x_s                : integer range -127 to 127 := -5;
	signal y_s                : integer range -159 to 159 := 0;
	signal font_start_s       : std_logic := '0';
	signal font_busy_s        : std_logic;
	signal draw_done          : std_logic;

	signal text_size_s        : integer range 1 to 12 := 2;
	signal text_data_s        : string(1 to 12) := "            ";
	signal font_mode_s        : integer range 0 to 2 := 0;
	signal addr_s             : l_addr_t;
	signal bg_color_s         : l_px_t := white;
	signal text_color_array_s : l_px_arr_t(1 to 12) := (others => black);
	signal clear_s            : std_logic := '0';

	-- uart_txt 接收介面訊號
	signal txt_rx_busy : std_logic;
	signal txt_rx_data : string(1 to C_TXT_LEN) := (others => ' ');
	signal txt_rx_len  : integer range 0 to C_TXT_LEN := 0;
	signal rx_done     : std_logic;
	signal rx_key      : integer range 0 to 9 := 0;

	-- 亮度控制訊號（PB2 提高一級、PB3 降低一級）
	signal bright_level : integer range 1 to 8 := 4; -- 預設第 4 級（1..8）
	signal bright_val   : u8r_t := x"40";

begin

	----------------------------------------------------------------------------
	-- 1. 實例化 lcd_mix 模組
	----------------------------------------------------------------------------
	u_lcd_mix : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x_s,
			y                => y_s,
			font_start       => font_start_s,
			font_busy        => font_busy_s,
			text_size        => text_size_s,
			text_data        => text_data_s,
			font_mode        => font_mode_s,
			addr             => addr_s,
			bg_color         => bg_color_s,
			text_color_array => text_color_array_s,
			clear            => clear_s,

			lcd_sclk  => lcd_sclk,
			lcd_mosi  => lcd_mosi,
			lcd_ss_n  => lcd_ss_n,
			lcd_dc    => lcd_dc,
			lcd_bl    => lcd_bl,
			lcd_rst_n => lcd_rst_n
		);

	----------------------------------------------------------------------------
	-- 2. 邊緣偵測模組 (抓取 font_busy 下降緣產生 draw_done)
	----------------------------------------------------------------------------
	edge_LCD : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy_s,
			rising  => open,
			falling => draw_done
		);

	u_seg : entity work.seg(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => (others => '0')
		);

	key_inst : entity work.key_2x2_1(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => PB_row,
			key_col => PB_col,
			pressed => key_pressed,
			key     => key_code
		);

	key_edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => key_pressed,
			rising  => pb_pressed_edge,
			falling => open
		);

	-- PB1 按下正緣觸發
	pb1_trig <= '1' when (pb_pressed_edge = '1' and key_code = 1) else '0';

	js_sw_pressed <= not js_sw;

	js_sw_debounce : entity work.debounce(arch)
		generic map(stable_time => 10)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => js_sw_pressed,
			sig_out => js_sw_debounced
		);

	js_sw_edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => js_sw_debounced,
			rising  => js_sw_edge,
			falling => open
		);

	clk_0p3s_inst : entity work.clk(arch)
		generic map(freq => 3)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_0p3s
		);

	scan_tick_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_0p3s,
			rising  => scan_tick,
			falling => open
		);

	clk_1s_inst : entity work.clk(arch)
		generic map(freq => 1)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1s
		);

	one_sec_tick_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1s,
			rising  => one_sec_tick,
			falling => open
		);

	ads_inst : entity work.ads_js_ctrl(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			scl        => js_scl,
			sda        => js_sda,
			x_raw      => x_raw,
			y_raw      => y_raw,
			data_valid => data_valid
		);

	ws2812_inst : entity work.WS2812_ch(arch)
		generic map(led_num_max => 64)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			ena      => ws_ena,
			busy     => ws_busy,
			rgb_data => rgb_arr,
			D_out    => D_out,
			led_num  => 64
		);

	----------------------------------------------------------------------------
	-- 3. UART 文字接收模組 (接收 stx ... etx 封包)
	----------------------------------------------------------------------------
	uart_txt_inst : entity work.uart_txt(arch)
		generic map(
			txt_len_max => C_TXT_LEN,
			baud        => 115200
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => open,
			tx_ena  => '0',
			tx_busy => open,
			tx_data => (others => ' '),
			tx_len  => 1,
			rx_busy => txt_rx_busy,
			rx_data => txt_rx_data,
			rx_len  => txt_rx_len
		);

	-- 偵測 txt_rx_busy 下降緣，代表收到完整一筆 stx...etx 封包
	rx_done_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => txt_rx_busy,
			rising  => open,
			falling => rx_done
		);

	process (clk, rst_n)
	begin
		if rst_n = '0' then
			ws_ena <= '0';
		elsif rising_edge(clk) then
			if ws_busy = '0' then
				ws_ena <= '1';
			else
				ws_ena <= '0';
			end if;
		end if;
	end process;

	process (clk, rst_n)
	begin
		if rst_n = '0' then
			state_m2 <= ST_WAIT_START;
			scan_x <= 3;
			scan_y <= 1;
			box_x <= 4;
			box_y <= 4;
			joystick_locked <= '0';
			js_move_cnt <= 0;

			m3_active <= '0';
			box_x_m3 <= 4;
			box_y_m3 <= 4;
			lcd_x_m3 <= 4;
			lcd_y_m3 <= 4;
			joystick_locked_m3 <= '0';
			js_move_cnt_m3 <= 0;

			lcd_line <= 0;
			font_mode_s <= 0;
			clear_s <= '0';
			font_start_s <= '0';
			x_s <= -5;
			y_s <= 0;
			text_data_s <= "            ";
			text_color_array_s <= (others => black);
			x <= 0;
			y <= 0;
			i <= 0;
			timer_ena <= '0';
			sec_cnt <= 0;
			lcd_started <= '0';
			rx_key <= 0;
			seg_data <= "        ";
		elsif rising_edge(clk) then
			-- 預設清除單脈衝控制訊號
			clear_s <= '0';

			-- 跨模式皆持續接收並更新 rx_key（避免切到其他模式時漏掉封包）
			if rx_done = '1' and txt_rx_len >= 1 then
				if txt_rx_data(1) >= '0' and txt_rx_data(1) <= '9' then
					rx_key <= character'pos(txt_rx_data(1)) - character'pos('0');
				end if;
			end if;

			-- mode switch => 00 (m0)(128 x 160 TFT LCD) 模式
			--             => 01 (m1)(七段顯示器及 Wi-Fi 傳輸測試) 模式
			--             => 10 (m2)(8x8 RGB LED 與搖桿測試) 模式
			--             => 11 (m3)(整合型測試：固定 ABCD + 2x2 方塊座標 [X,Y] + 七段顯示器) 模式
			case sw(6 to 7) is
				when "00" =>
					if pb1_trig = '1' then
						-- 按下 PB1：重置目前模式（m0 TFT LCD）功能並清屏
						timer_ena <= '0';
						lcd_started <= '0';
						sec_cnt <= 0;
						lcd_line <= 0;
						font_start_s <= '0';
						x_s <= -5;
						y_s <= 0;
						text_data_s <= "            ";
						text_color_array_s <= (others => black);
						x <= 0;
						y <= 0;
						i <= 0;
						clear_s <= '1';

					elsif pb_pressed_edge = '1' and key_code = 0 then
						-- 按下 PB0：立刻從 [0,0] 與 i = 0 ("ABCD") 開始顯示
						timer_ena <= '1';
						lcd_started <= '1';
						sec_cnt <= 0;
						lcd_line <= 0;
						font_start_s <= '0';
						x_s <= -5;
						y_s <= 0;
						text_data_s <= MSG_TABLE(0);
						text_color_array_s <= (others => black);
						x <= 0;
						y <= 0;
						i <= 0;
						clear_s <= '0';
					end if;

					if timer_ena = '1' and clear_s = '0' then
						if sec_cnt >= sys_clk_freq - 1 then
							sec_cnt <= 0;

							if lcd_started = '0' then
								lcd_started <= '1';
							else
								-- 字串索引循環 0 ~ 6
								if i = 6 then
									i <= 0;
								else
									i <= i + 1;
								end if;

								-- 座標 [0,0] ~ [8,8] 循環
								if x = 8 and y = 8 then
									x <= 0;
									y <= 0;
								elsif y = 8 then
									y <= 0;
									if x <= 8 then
										x <= x + 1;
									else
										x <= 0;
									end if;
								else
									y <= y + 1;
								end if;
							end if;

							lcd_line <= 0;
						else
							sec_cnt <= sec_cnt + 1;
						end if;

						case lcd_line is
							when 0 =>
								text_data_s <= MSG_TABLE(i);
								text_size_s <= 3;
								x_s <= 0;
								y_s <= 10;
								text_color_array_s(1 to 12) <= (others => red);

								if font_busy_s = '0' and draw_done = '0' then
									font_start_s <= '1';
								end if;

								if font_busy_s = '1' then
									font_start_s <= '0';
								end if;

								if draw_done = '1' then
									font_start_s <= '0';
									lcd_line <= 1;
								end if;

							when 1 =>
								text_data_s <= "[" & to_string(x, 9, 10, 1) & "," & to_string(y, 9, 10, 1) & "]       ";
								text_size_s <= 2;
								x_s <= 10;
								y_s <= 80;
								text_color_array_s(1 to 12) <= (others => blue);

								if font_busy_s = '0' and draw_done = '0' then
									font_start_s <= '1';
								end if;

								if font_busy_s = '1' then
									font_start_s <= '0';
								end if;

								if draw_done = '1' then
									font_start_s <= '0';
									lcd_line <= 2;
								end if;

							when 2 =>
								font_start_s <= '0';

							when others =>
								lcd_line <= 0;
						end case;
					end if;

				when "01" =>
					if pb1_trig = '1' then
						-- 按下 PB1：重置目前模式（m1 七段顯示器數值）功能
						rx_key <= 0;
						seg_data <= "Inf.  00";
					else
						seg_data <= "Inf.  " & to_string(rx_key, rx_key'high, 10, 2);
					end if;

				when "10" =>
					if pb1_trig = '1' then
						-- 按下 PB1：重置目前模式（m2 RGB 掃描與搖桿控制）功能
						state_m2 <= ST_WAIT_START;
						scan_x <= 3;
						scan_y <= 1;
						box_x <= 4;
						box_y <= 4;
						joystick_locked <= '0';
						js_move_cnt <= 0;
					else
						case state_m2 is
							when ST_WAIT_START =>
								if pb_pressed_edge = '1' and key_code = 0 then
									scan_x <= 3;
									scan_y <= 1;
									state_m2 <= ST_RGB_SCAN;
								end if;

							when ST_RGB_SCAN =>
								if scan_tick = '1' then
									if scan_x < 8 then
										scan_x <= scan_x + 1;
									else
										scan_x <= 3;
										if scan_y < 8 then
											scan_y <= scan_y + 1;
										else
											box_x <= 4;
											box_y <= 4;
											joystick_locked <= '0';
											state_m2 <= ST_JOYSTICK_CTRL;
										end if;
									end if;
								end if;

							when ST_JOYSTICK_CTRL =>
								if js_sw_edge = '1' then
									joystick_locked <= '1';
								end if;

								if joystick_locked = '0' then
									if js_move_cnt < COOL_DOWN_TICKS then
										js_move_cnt <= js_move_cnt + 1;
									else
										if y_raw > JS_MIN_TH and y_raw < JS_Y_UP_TH and box_y < 7 then
											box_y <= box_y + 1;
											js_move_cnt <= 0;
										elsif y_raw > JS_Y_DOWN_TH and box_y > 1 then
											box_y <= box_y - 1;
											js_move_cnt <= 0;
										elsif x_raw > JS_MIN_TH and x_raw < JS_X_LEFT_TH and box_x < 7 then
											box_x <= box_x + 1;
											js_move_cnt <= 0;
										elsif x_raw > JS_X_RIGHT_TH and box_x > 1 then
											box_x <= box_x - 1;
											js_move_cnt <= 0;
										end if;
									end if;
								end if;
						end case;
					end if;

				when "11" =>
					if pb1_trig = '1' then
						-- 按下 PB1：重置目前模式（m3 整合型測試）功能並清屏
						m3_active <= '0';
						box_x_m3 <= 4;
						box_y_m3 <= 4;
						lcd_x_m3 <= 4;
						lcd_y_m3 <= 4;
						joystick_locked_m3 <= '0';
						js_move_cnt_m3 <= 0;
						lcd_line <= 0;
						font_start_s <= '0';
						rx_key <= 0;
						seg_data <= "Inf.  00";
						clear_s <= '1';
					else
						-- 保留模式 01 七段顯示器接收顯示功能
						seg_data <= "Inf.  " & to_string(rx_key, rx_key'high, 10, 2);

						if pb_pressed_edge = '1' and key_code = 0 then
							-- 按下 PB0：啟動整合顯示，上方固定顯示 "ABCD"，下方顯示 2x2 方塊座標 [X,Y]
							m3_active <= '1';
							box_x_m3 <= 4;
							box_y_m3 <= 4;
							lcd_x_m3 <= 4;
							lcd_y_m3 <= 4;
							joystick_locked_m3 <= '0';
							js_move_cnt_m3 <= 0;
							lcd_line <= 0;
							font_start_s <= '0';
							clear_s <= '0';
						end if;

						if m3_active = '1' and clear_s = '0' then
							-- 按下搖桿開關：2x2 方塊固定在原地並鎖定，LCD 顯示 [0,0]
							if js_sw_edge = '1' then
								joystick_locked_m3 <= '1';
								lcd_x_m3 <= 0;
								lcd_y_m3 <= 0;
								if lcd_line = 2 then
									lcd_line <= 1;
								end if;
							end if;

							if joystick_locked_m3 = '0' then
								if js_move_cnt_m3 < COOL_DOWN_TICKS then
									js_move_cnt_m3 <= js_move_cnt_m3 + 1;
								else
									if y_raw > JS_MIN_TH and y_raw < JS_Y_UP_TH and box_y_m3 < 7 then
										box_y_m3 <= box_y_m3 + 1;
										lcd_y_m3 <= box_y_m3 + 1;
										lcd_x_m3 <= box_x_m3;
										js_move_cnt_m3 <= 0;
										if lcd_line = 2 then
											lcd_line <= 1;
										end if;
									elsif y_raw > JS_Y_DOWN_TH and box_y_m3 > 1 then
										box_y_m3 <= box_y_m3 - 1;
										lcd_y_m3 <= box_y_m3 - 1;
										lcd_x_m3 <= box_x_m3;
										js_move_cnt_m3 <= 0;
										if lcd_line = 2 then
											lcd_line <= 1;
										end if;
									elsif x_raw > JS_MIN_TH and x_raw < JS_X_LEFT_TH and box_x_m3 < 7 then
										box_x_m3 <= box_x_m3 + 1;
										lcd_x_m3 <= box_x_m3 + 1;
										lcd_y_m3 <= box_y_m3;
										js_move_cnt_m3 <= 0;
										if lcd_line = 2 then
											lcd_line <= 1;
										end if;
									elsif x_raw > JS_X_RIGHT_TH and box_x_m3 > 1 then
										box_x_m3 <= box_x_m3 - 1;
										lcd_x_m3 <= box_x_m3 - 1;
										lcd_y_m3 <= box_y_m3;
										js_move_cnt_m3 <= 0;
										if lcd_line = 2 then
											lcd_line <= 1;
										end if;
									end if;
								end if;
							end if;

							-- LCD 繪製：第 0 行固定顯示 "ABCD"，第 1 行顯示 [X,Y]
							case lcd_line is
								when 0 =>
									text_data_s <= MSG_TABLE(0);
									text_size_s <= 3;
									x_s <= 0;
									y_s <= 10;
									text_color_array_s(1 to 12) <= (others => red);

									if font_busy_s = '0' and draw_done = '0' then
										font_start_s <= '1';
									end if;

									if font_busy_s = '1' then
										font_start_s <= '0';
									end if;

									if draw_done = '1' then
										font_start_s <= '0';
										lcd_line <= 1;
									end if;

								when 1 =>
									text_data_s <= "[" & to_string(lcd_x_m3, 7, 10, 1) & "," & to_string(lcd_y_m3, 7, 10, 1) & "]       ";
									text_size_s <= 2;
									x_s <= 10;
									y_s <= 80;
									text_color_array_s(1 to 12) <= (others => blue);

									if font_busy_s = '0' and draw_done = '0' then
										font_start_s <= '1';
									end if;

									if font_busy_s = '1' then
										font_start_s <= '0';
									end if;

									if draw_done = '1' then
										font_start_s <= '0';
										lcd_line <= 2;
									end if;

								when 2 =>
									font_start_s <= '0';

								when others =>
									lcd_line <= 0;
							end case;
						end if;
					end if;
			end case;
		end if;
	end process;

	-- WS2812 8x8 座標系統（X 為水平欄 1..8，Y 為垂直列 1..8，idx = (Y - 1) * 8 + (X - 1)）
	process (sw, state_m2, m3_active, scan_x, scan_y, box_x, box_y, box_x_m3, box_y_m3, bright_val)
		variable idx : integer;
	begin
		for k in 0 to 63 loop
			rgb_arr(k) <= x"000000";
		end loop;

		if sw(6 to 7) = "10" then
			case state_m2 is
				when ST_WAIT_START =>
					null;

				when ST_RGB_SCAN =>
					idx := (scan_y - 1) * 8 + (scan_x - 1);
					if idx >= 0 and idx < 64 then
						rgb_arr(idx) <= x"00" & bright_val & x"00";
					end if;

					if scan_x - 1 >= 1 then
						idx := (scan_y - 1) * 8 + (scan_x - 2);
						if idx >= 0 and idx < 64 then
							rgb_arr(idx) <= bright_val & x"0000";
						end if;
					end if;

					if scan_x - 2 >= 1 then
						idx := (scan_y - 1) * 8 + (scan_x - 3);
						if idx >= 0 and idx < 64 then
							rgb_arr(idx) <= x"0000" & bright_val;
						end if;
					end if;

				when ST_JOYSTICK_CTRL =>
					for dy in 0 to 1 loop
						for dx in 0 to 1 loop
							idx := (box_y + dy - 1) * 8 + (box_x + dx - 1);
							if idx >= 0 and idx < 64 then
								rgb_arr(idx) <= x"00" & bright_val & x"00";
							end if;
						end loop;
					end loop;
			end case;
		elsif sw(6 to 7) = "11" and m3_active = '1' then
			for dy in 0 to 1 loop
				for dx in 0 to 1 loop
					idx := (box_y_m3 + dy - 1) * 8 + (box_x_m3 + dx - 1);
					if idx >= 0 and idx < 64 then
						rgb_arr(idx) <= x"00" & bright_val & x"00";
					end if;
				end loop;
			end loop;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- 亮度調整 Process：PB2（key_code = 2）提高一級、PB3（key_code = 3）降低一級
	----------------------------------------------------------------------------
	proc_brightness : process (clk, rst_n)
	begin
		if rst_n = '0' then
			bright_level <= 4;
		elsif rising_edge(clk) then
			if pb_pressed_edge = '1' then
				if key_code = 2 then
					-- PB2：亮度提高一級（上限 8）
					if bright_level < 8 then
						bright_level <= bright_level + 1;
					end if;
				elsif key_code = 3 then
					-- PB3：亮度降低一級（下限 1）
					if bright_level > 1 then
						bright_level <= bright_level - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- 將亮度等級（1..8）轉為 u8r_t 亮度數值
	process (bright_level)
	begin
		case bright_level is
			when 1      => bright_val <= x"08";
			when 2      => bright_val <= x"10";
			when 3      => bright_val <= x"20";
			when 4      => bright_val <= x"40";
			when 5      => bright_val <= x"60";
			when 6      => bright_val <= x"80";
			when 7      => bright_val <= x"C0";
			when others => bright_val <= x"FF";
		end case;
	end process;

end arch;