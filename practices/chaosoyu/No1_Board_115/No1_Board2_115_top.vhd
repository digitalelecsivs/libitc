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

		-- 七段顯示器 Pins
		seg_led : out u8r_t; -- PIN_230, 224, 221, 218, 216, 207, 202, 200
		seg_com : out u8r_t  -- PIN_69, 63, 56, 52, 50, 46, 44, 41
	);
end Board2_115_top;

architecture arch of Board2_115_top is

	signal lcd_line : integer range 0 to 2 := 0;

	--定義字串型別
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
	-- 定義lcd上顯示的座標與文字指標
	signal x : integer range 0 to 8 := 0;
	signal y : integer range 0 to 8 := 1;
	signal i : integer range 0 to 6 := 0;

	type state_m2_t is (
		ST_WAIT_START,
		ST_RGB_SCAN,
		ST_JOYSTICK_CTRL
	);
	signal state_m2 : state_m2_t := ST_WAIT_START;

	--timer
	signal one_sec_tick : std_logic;
	signal clk_1s : std_logic;
	signal timer_ena : std_logic;

	-- push button and joystick
	signal key_pressed : std_logic;
	signal key_code : i4_t;
	signal pb0_pressed_edge : std_logic;

	signal js_sw_debounced : std_logic;
	signal js_sw_pressed : std_logic;
	signal js_sw_edge : std_logic;

	-- unit: ms, 250ms second delay for joystick Cooldown
	constant COOL_DOWN_TICKS : integer := (sys_clk_freq / 1000) * 250;

	-- 搖桿 ADC 閾值常數定義 (採用 16 進位數值，對應你的測試結果)
	-- Y 軸閾值：置中約 0x3396 (13206)
	constant JS_Y_UP_TH : u16_t := x"1000"; -- 十進位 4096 (向上推門檻，y_raw < JS_Y_UP_TH)
	constant JS_Y_DOWN_TH : u16_t := x"5000"; -- 十進位 20480 (向下推門檻，y_raw > JS_Y_DOWN_TH)

	-- X 軸閾值：置中約 0x34d6 (13526)
	constant JS_X_LEFT_TH : u16_t := x"1000"; -- 十進位 4096 (向左推門檻，x_raw < JS_X_LEFT_TH)
	constant JS_X_RIGHT_TH : u16_t := x"4500"; -- 十進位 17664 (向右推門檻，x_raw > JS_X_RIGHT_TH)

	-- 最低雜訊門檻 (避免 0x0000 全零異常)
	constant JS_MIN_TH : u16_t := x"000A"; -- 十進位 10

	-- 時脈脈衝與 ADS1115 訊號 (x_raw, y_raw 改為 u16_t)
	signal clk_0p3s : std_logic;
	signal scan_tick : std_logic;

	signal x_raw : u16_t;
	signal y_raw : u16_t;
	signal data_valid : std_logic;

	signal joystick_locked : std_logic := '0';
	signal js_move_cnt : integer range 0 to sys_clk_freq := 0;

	-- WS2812 與七段顯示器
	signal ws_ena : std_logic := '0';
	signal ws_busy : std_logic;
	signal rgb_arr : l_px_arr_t(0 to 63) := (others => (others => '0'));
	signal seg_data : string(1 to 8);

	-- WS2812 座標定義
	signal scan_r_row : integer range 1 to 8 := 1;
	signal scan_r_col : integer range 1 to 8 := 3;

	signal box_r : integer range 1 to 7 := 4;
	signal box_c : integer range 1 to 7 := 4;

	-- LCD 內部控制與 lcd_mix 連接訊號
	signal x_s : integer range -127 to 127 := - 5;
	signal y_s : integer range -159 to 159 := 0;
	signal font_start_s : std_logic := '0';
	signal font_busy_s : std_logic;
	signal draw_done : std_logic; -- 由 edge 模組產生的完成脈衝

	signal text_size_s : integer range 1 to 12 := 2;
	signal text_data_s : string(1 to 12) := "            ";
	signal font_mode_s : integer range 0 to 2 := 0;
	signal addr_s : l_addr_t;
	signal bg_color_s : l_px_t := white; -- 背景色可依需求調整 (如 white 或 black)
	signal text_color_array_s : l_px_arr_t(1 to 12) := (others => black);
	signal clear_s : std_logic := '0';

	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal uart_rx, uart_tx, rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	signal rx_key : integer range 0 to 9;
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
			sig_in  => font_busy_s, -- 監視 lcd_mix 的 busy 腳位
			rising  => open,
			falling => draw_done -- font_busy 由 '1' 變 '0' 時產生 1 個 Clock 週期的脈衝
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
			dot => (others => '0')
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
			rising  => pb0_pressed_edge,
			falling => open
		);

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

	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx, --腳位
			uart_tx => uart_tx, --腳位
			tx_ena  => tx_ena,  --enable '1' 動作
			tx_busy => tx_busy, --tx資料傳送時tx_busy='1'
			tx_data => tx_data, --硬體要傳送的資料 
			rx_busy => rx_busy, --rx資料傳送時rx_busy='1'
			rx_err  => rx_err,  --檢測錯誤
			rx_data => rx_data  --由軟體接收到的資料 
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
			scan_r_row <= 1;
			scan_r_col <= 3;
			box_r <= 4;
			box_c <= 4;
			joystick_locked <= '0';
			js_move_cnt <= 0;
			lcd_line <= 0;
			font_mode_s <= 0;
			clear_s <= '0';
			font_start_s <= '0';
			x_s <= - 5;
			y_s <= 0;
			text_data_s <= "            ";
			text_color_array_s <= (others => black);
			x <= 0;
			y <= 1;
			i <= 0;
			timer_ena <= '0';
		elsif rising_edge(clk) then
			--mode switch 	=> 00 (m0)(128 × 160 TFT LCD)模式
			--     			=> 01 (m1)(七段顯示器及 Wi-Fi 傳輸測試)模式
			--     			=> 10 (m2)(8×8 RGB LED 與搖桿測試)模式
			--     			=> 11 (m3)(整合型測試)模式
			case sw(6 to 7) is
				when "00" =>
					-- 1. 按下 PB0 啟動測試並重置狀態
					if pb0_pressed_edge = '1' and key_code = 0 then
						lcd_line <= 0;
						font_start_s <= '0';
						x_s <= - 5;
						y_s <= 0;
						text_data_s <= "            ";
						text_color_array_s <= (others => black);
						x <= 0;
						y <= 1;
						i <= 0;
						-- 啟動計時器旗標
						timer_ena <= '1';
					end if;

					-- 2. 每 1 秒脈衝觸發：更新字串索引 (i) 與座標 (x, y)
					if timer_ena = '1' and one_sec_tick = '1' then
						-- 更新英文字串索引 (0 -> 1 -> 2 -> ... -> 6 -> 0)
						if i = 6 then
							i <= 0;
						else
							i <= i + 1;
						end if;

						-- 更新座標邏輯 [x, y]
						if y >= 8 then
							y <= 1; -- Y 滿 8 重置為 1
							x <= x + 1; -- X 進位 +1
						else
							y <= y + 1; -- Y 遞增
						end if;

						-- 每秒更新時，重新從繪製第 0 行 (英文) 開始
						lcd_line <= 0;
					end if;
					if timer_ena = '1' then
						-- LCD 繪製狀態機
						case lcd_line is
							when 0 =>
								-- 顯示英文字 (MSG_TABLE(0)="ABCD", MSG_TABLE(1)="EFGH", ..., MSG_TABLE(6)="YZ")
								text_data_s <= MSG_TABLE(i);
								font_start_s <= '1';
								text_size_s <= 3;
								x_s <= 0;
								y_s <= 10;
								text_color_array_s(1 to 12) <= (others => red);

								if draw_done = '1' then
									font_start_s <= '0';
									lcd_line <= 1; -- 英文字畫完，切換去畫座標
								end if;

							when 1 =>
								-- 顯示座標 [x,y]
								text_data_s <= "[" & to_string(x, 9, 10, 1) & "," & to_string(y, 9, 10, 1) & "]       ";
								font_start_s <= '1';
								text_size_s <= 2;
								x_s <= 10;
								y_s <= 80;
								text_color_array_s(1 to 12) <= (others => blue);

								if draw_done = '1' then
									font_start_s <= '0';
									lcd_line <= 2; -- 繪製完成，進入等待狀態（等 1 秒脈衝再繪製下一張畫面）
								end if;

							when 2 =>
								-- 等待狀態：兩行都繪製完成後在此等待，不做任何動作
								font_start_s <= '0';

							when others =>
								lcd_line <= 0;
						end case;
					end if;
				when "01" =>
					--enter into m1
					if rx_done = '1' then
						rx_key <= to_integer(rx_data);
					end if;
					seg_data <= "inf.  " & to_string(rx_key, rx_key'high, 10, 2);
				when "10" =>
					--enter into m2
					case state_m2 is

						when ST_WAIT_START =>
							if pb0_pressed_edge = '1' and key_code = 0 then
								scan_r_row <= 1;
								scan_r_col <= 3;
								state_m2 <= ST_RGB_SCAN;
							end if;

						when ST_RGB_SCAN =>
							if scan_tick = '1' then
								if scan_r_col < 8 then
									scan_r_col <= scan_r_col + 1;
								else
									scan_r_col <= 3;
									if scan_r_row < 8 then
										scan_r_row <= scan_r_row + 1;
									else
										box_r <= 4;
										box_c <= 4;
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
									-- 1. 向上推 (y_raw 介於 10 ~ 4096)
									if y_raw > JS_MIN_TH and y_raw < JS_Y_UP_TH and box_r < 7 then
										box_r <= box_r + 1;
										js_move_cnt <= 0;

										-- 2. 向下推 (y_raw > 20480)
									elsif y_raw > JS_Y_DOWN_TH and box_r > 1 then
										box_r <= box_r - 1;
										js_move_cnt <= 0;

										-- 3. 向左推 (x_raw 介於 10 ~ 4096)
									elsif x_raw > JS_MIN_TH and x_raw < JS_X_LEFT_TH and box_c < 7 then
										box_c <= box_c + 1;
										js_move_cnt <= 0;

										-- 4. 向右推 (x_raw > 17664)
									elsif x_raw > JS_X_RIGHT_TH and box_c > 1 then
										box_c <= box_c - 1;
										js_move_cnt <= 0;
									end if;
								end if;
							end if;

					end case;
				when "11" =>
					--enter into m3
			end case;

		end if;
	end process;

	process (state_m2, scan_r_row, scan_r_col, box_r, box_c)
		variable idx : integer;
	begin
		for i in 0 to 63 loop
			rgb_arr(i) <= x"000000";
		end loop;

		case state_m2 is

			when ST_WAIT_START =>
				null;

			when ST_RGB_SCAN =>
				idx := (scan_r_row - 1) * 8 + (scan_r_col - 1);
				if idx >= 0 and idx < 64 then
					rgb_arr(idx) <= x"001000";
				end if;

				if scan_r_col - 1 >= 1 then
					idx := (scan_r_row - 1) * 8 + (scan_r_col - 2);
					if idx >= 0 and idx < 64 then
						rgb_arr(idx) <= x"100000";
					end if;
				end if;

				if scan_r_col - 2 >= 1 then
					idx := (scan_r_row - 1) * 8 + (scan_r_col - 3);
					if idx >= 0 and idx < 64 then
						rgb_arr(idx) <= x"000010";
					end if;
				end if;

			when ST_JOYSTICK_CTRL =>
				for dr in 0 to 1 loop
					for dc in 0 to 1 loop
						idx := (box_r + dr - 1) * 8 + (box_c + dc - 1);
						if idx >= 0 and idx < 64 then
							rgb_arr(idx) <= x"002000";
						end if;
					end loop;
				end loop;

		end case;
	end process;

	----------------------------------------------------------------------------
	-- 七段顯示器轉換輸出 (轉為 std_logic_vector 搭配 to_hstring)
	----------------------------------------------------------------------------
	--seg_data(1 to 4) <= to_string(to_integer(y_raw), 16#FFFF#, 16, 4);
	--seg_data(5 to 8) <= to_string(to_integer(x_raw), 16#FFFF#, 16, 4);

end arch;
