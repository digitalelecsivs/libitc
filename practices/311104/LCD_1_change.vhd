library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity js_ws2812_top is
	port (
		clk, rst_n : in std_logic;
		sw         : in std_logic_vector(7 downto 0); -- 模式選擇，sw(7) 為最低位元
		js_scl     : inout std_logic;
		js_sda     : inout std_logic;
		js_sw      : in std_logic; -- 搖桿按鈕輸入（僅在模式 11 時負責鎖定與解鎖）
		-- 2x2 矩陣按鍵 PB0~PB3
		pb_row : in u2r_t;
		pb_col : out u2r_t;
		D_out  : out std_logic;
		-- UART（模式 01：接收前一塊板子傳來的 3x3 鍵盤編號）
		uart_rx : in std_logic;
		uart_tx : out std_logic;
		-- 七段顯示器
		seg_led : out std_logic_vector(7 downto 0); -- DP G F E D C B A
		seg_com : out std_logic_vector(7 downto 0); -- 位數選擇
		-- TFT LCD 實體腳位
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end js_ws2812_top;

architecture arch of js_ws2812_top is
	type state_t is (idle, anim, anim_hold, sure, ws_work);
	signal mode_t : state_t := idle;

	signal sw_d : std_logic_vector(7 downto 0) := (others => '0');
	signal js_sw_d : std_logic := '1';
	signal js_sw_fall : std_logic;
	signal ws_ena : std_logic := '0';
	signal ws_busy : std_logic;
	signal ws_busy_f : std_logic;

	constant C_LED_MAX : integer := 64;
	signal led_num : integer range 0 to C_LED_MAX;
	signal rgb_data : l_px_arr_t(0 to C_LED_MAX - 1);

	signal mode_sel : std_logic_vector(1 downto 0);
	signal mode_prev : std_logic_vector(1 downto 0) := "00";
	signal mode_chg : std_logic := '0';
	signal led_en : std_logic;

	-- 全域啟動致能訊號（由 PB0 觸發後保持為 '1'）
	signal run_en : std_logic := '0';

	-- 5 秒開機動畫計時器
	signal anim_timer : integer range 0 to 250_000_000 := 0;

	-- 搖桿訊號
	signal x_raw, y_raw : u16_t;
	signal x_val, y_val : integer range 0 to 65535 := 0;

	constant C_FLIP_X : boolean := false;
	constant C_FLIP_Y : boolean := false;

	constant C_HOME_X : integer := 0;
	constant C_HOME_Y : integer := 0;
	signal home_x : integer range 0 to 7 := C_HOME_X;
	signal home_y : integer range 0 to 7 := C_HOME_Y;
	signal init_pend : std_logic := '1';

	constant C_MOVE_PERIOD : integer := 2_500_000;
	signal timer_cnt : integer range 0 to C_MOVE_PERIOD := 0;
	signal move_tick : std_logic := '0';

	constant C_ANIM_PERIOD : integer := 3_000_000;
	signal anim_cnt : integer range 0 to C_ANIM_PERIOD := 0;
	signal anim_tick : std_logic := '0';
	signal anim_step : integer range 0 to 63 := 0;

	signal b_x : integer range 0 to 7 := 0;
	signal b_y : integer range 0 to 7 := 0;
	signal r_x : integer range 0 to 7 := 1;
	signal r_y : integer range 0 to 7 := 0;
	signal g_x : integer range 0 to 7 := 2;
	signal g_y : integer range 0 to 7 := 0;

	signal pos_x_s : integer range 0 to 7 := C_HOME_X;
	signal pos_y_s : integer range 0 to 7 := C_HOME_Y;

	signal test_on : std_logic := '0';
	signal anim_done : std_logic := '0';
	signal locked : std_logic := '0';

	-- 2x2 按鍵
	signal key_pressed : std_logic;
	signal key_val : i4_t;
	signal key_edge : std_logic;
	constant C_KEY_PB0 : integer := 0;
	constant C_KEY_PB1 : integer := 1;
	constant C_KEY_PB2 : integer := 2;
	constant C_KEY_PB3 : integer := 3;
	signal pb0_trig, pb1_trig, pb2_trig, pb3_trig : std_logic := '0';

	signal rst_i : std_logic;

	type bri_tbl_t is array (0 to 4) of integer range 0 to 255;
	constant C_BRI_TBL : bri_tbl_t := (8, 32, 80, 160, 255);
	constant C_BRI_MAX : integer := 4;
	constant C_BRI_INIT : integer := 2;
	signal bri_idx : integer range 0 to 4 := C_BRI_INIT;
	signal bri_val : std_logic_vector(7 downto 0);
	signal bri_mask : l_px_t;

	-- UART 接收（模式 01）與閃爍控制
	signal rx_busy_s : std_logic;
	signal rx_data_s : string(1 to 16);
	signal rx_len_s : integer range 1 to 16;
	signal rx_done : std_logic;
	signal rx_num : integer range 0 to 8 := 0;
	signal rx_got : std_logic := '0';
	signal show_saved_val : std_logic := '0';

	-- 閃爍/儲存
	signal is_flashing : std_logic := '0';
	signal flash_cnt : integer range 0 to 50_000_000 := 0;
	signal flash_toggle : std_logic := '0';
	signal store_step : integer range 0 to 4 := 0; -- 0:等待第1組, 1:第1組閃爍中, 2:等待第2組, 3:第2組閃爍中, 4:兩組存滿
	constant C_TX_DUMMY : string(1 to 16) := (others => ' ');

	-- 七段顯示器極性 0-1-2-3-4-5-6-7
	constant C_SEG_INVERT : boolean := false;
	constant C_COM_ON : std_logic := '0';
	constant C_COM_OFF : std_logic := '1';
	constant C_REVERSE : boolean := false;
	constant C_SCAN_DIV : integer := 50_000;

	subtype seg_t is std_logic_vector(7 downto 0);
	constant C_BLANK : seg_t := "00000000";
	constant C_C : seg_t := "00111001";
	constant C_o : seg_t := "01011100";
	constant C_r : seg_t := "11010000";
	constant C_1_dot : seg_t := "10000110";
	constant C_2_dot : seg_t := "11011011";
	constant C_0 : seg_t := "00111111";
	constant C_1 : seg_t := "00000110";
	constant C_2 : seg_t := "01011011";
	constant C_3 : seg_t := "01001111";
	constant C_4 : seg_t := "01100110";
	constant C_5 : seg_t := "01101101";
	constant C_6 : seg_t := "01111101";
	constant C_7 : seg_t := "00000111";
	constant C_8 : seg_t := "01111111";
	type num_t is array (0 to 8) of seg_t;
	constant C_NUM : num_t := (C_0, C_1, C_2, C_3, C_4, C_5, C_6, C_7, C_8);

	type disp_t is array (0 to 7) of seg_t;
	signal disp : disp_t := (others => C_BLANK);
	signal digit : integer range 0 to 7 := 0;
	signal digit_phy : integer range 0 to 7;

	-- LCD 顯示控制
	type lcd_state_t is (l_idle, clr_watch, l1_start, l1_wait, l2_start, l2_wait, wait_ref);
	signal lcd_state : lcd_state_t := l_idle;

	constant C_REFRESH_PERIOD : integer := 5_000_000;
	constant C_SEC_PERIOD : integer := 50_000_000;
	signal ref_period : integer range 0 to C_SEC_PERIOD := C_REFRESH_PERIOD;
	signal ref_cnt : integer range 0 to C_SEC_PERIOD := 0;
	signal refresh_tick : std_logic := '0';

	signal dly_cnt : integer range 0 to 65535 := 0;
	signal font_start : std_logic := '0';
	signal font_busy : std_logic;
	signal clear_screen : std_logic := '1';
	signal font_mode_sel : integer range 0 to 2 := 0;
	signal busy_seen : std_logic := '0';

	signal text_data_buf : string(1 to 12) := "            ";
	signal text_color_arr : l_px_arr_t(1 to 12);
	signal mix_x : integer range -127 to 127 := 0;
	signal mix_y : integer range -159 to 159 := 0;

	type grp_t is array (0 to 25) of string(1 to 4);
	constant C_GRP : grp_t := (
		"A___", "_B__", "__C_", "___D",
		"E___", "_F__", "__G_", "___H",
		"I___", "_J__", "__K_", "___L",
		"M___", "_N__", "__O_", "___P",
		"Q___", "_R__", "__S_", "___T",
		"U___", "_V__", "__W_", "___X",
		"Y_  ", "_Z  "
	);
	signal seq_idx : integer range 0 to 25 := 0;
	signal coord_x : integer range 1 to 8 := 8;
	signal coord_y : integer range 1 to 8 := 8;

	-- 01 指撥
	signal bin_in_H : std_logic_vector(2 downto 0);
	signal bin_in_L : std_logic_vector(2 downto 0);
	signal dec_H : integer range 0 to 255;
	signal dec_L : integer range 0 to 255;
	signal saved1_dec_H : integer range 0 to 255 := 1; -- 預設 1 (X軸)
	signal saved1_dec_L : integer range 0 to 255 := 1; -- 預設 1 (Y軸)
	signal saved2_dec_H : integer range 0 to 255 := 1; -- 預設 1 (X軸)
	signal saved2_dec_L : integer range 0 to 255 := 1; -- 預設 1 (Y軸)

	constant C_SCR_W : integer := 128;
	constant C_CHAR_W : integer := 12;
	constant C_X1 : integer := (C_SCR_W - (4 * C_CHAR_W)) / 2 - 18;
	constant C_X2 : integer := (C_SCR_W - (7 * C_CHAR_W)) / 2 - 18;
	constant C_Y1 : integer := 18;
	constant C_Y2 : integer := 72;

	constant C_RED : l_px_t := X"FF0000";
	constant C_GREEN : l_px_t := X"00FF00";
	constant C_BLUE : l_px_t := X"0000FF";
	constant C_YELLOW : l_px_t := X"FFFF00";
	constant C_CYAN : l_px_t := X"00FFFF";
	constant C_WHITE : l_px_t := X"FFFFFF";

	constant C_BLOCK_COLOR : l_px_t := X"00FF00";
	constant C_DOT_B : l_px_t := X"0000FF";
	constant C_DOT_R : l_px_t := X"FF0000";
	constant C_DOT_G : l_px_t := X"00FF00";

	function apply_bri(c : l_px_t; m : l_px_t) return l_px_t is
	begin
		return l_px_t(std_logic_vector(c) and std_logic_vector(m));
	end function;

	component debounce is
		generic (stable_time : integer := 10);
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			sig_out    : out std_logic
		);
	end component;

	component ads_js_ctrl is
		port (
			clk        : in std_logic;
			rst_n      : in std_logic;
			scl        : inout std_logic;
			sda        : inout std_logic;
			x_raw      : out u16_t;
			y_raw      : out u16_t;
			data_valid : out std_logic
		);
	end component;

	component WS2812_ch is
		generic (led_num_max : integer := C_LED_MAX);
		port (
			clk, rst_n : in std_logic;
			ena        : in std_logic;
			busy       : out std_logic;
			rgb_data   : in l_px_arr_t(0 to led_num_max - 1);
			D_out      : out std_logic;
			led_num    : in integer range 0 to led_num_max
		);
	end component;

	component edge is
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			rising     : out std_logic;
			falling    : out std_logic
		);
	end component;

begin

	-- 模式選擇使用防彈跳後的 sw_d(6) 與 sw_d(7)
	mode_sel <= sw_d(6) & sw_d(7);
	-- 指撥開關 sw(0) ~ sw(5) 直接讀取（不經防彈跳）
	bin_in_H <= sw(0) & sw(1) & sw(2);
	bin_in_L <= sw(3) & sw(4) & sw(5);

	rst_i <= rst_n and (not pb1_trig) and (not mode_chg);

	-- 模式 10 的初始位置對應 saved1（saved1_dec_H 為 X 軸，saved1_dec_L 為 Y 軸）
	home_x <= (saved1_dec_H - 1) when mode_sel = "10" else C_HOME_X;
	home_y <= (saved1_dec_L - 1) when mode_sel = "10" else C_HOME_Y;

	led_en <= '1' when run_en = '1' and ((mode_sel = "10") or (mode_sel = "11")) else '0';
	ref_period <= C_SEC_PERIOD when mode_sel = "00" else C_REFRESH_PERIOD;

	mode_chg_proc : process (clk, rst_n)
	begin
		if rst_n = '0' then
			mode_prev <= "00";
			mode_chg <= '0';
		elsif rising_edge(clk) then
			mode_prev <= mode_sel;
			if mode_sel /= mode_prev then
				mode_chg <= '1';
			else
				mode_chg <= '0';
			end if;
		end if;
	end process;

	run_ctrl_proc : process (clk, rst_i)
	begin
		if rst_i = '0' then
			run_en <= '0';
		elsif rising_edge(clk) then
			if pb0_trig = '1' then
				run_en <= '1';
			end if;
		end if;
	end process;

	components : block begin
		-- 僅對模式選擇開關 sw(6) ~ sw(7) 進行防彈跳
		gen_sw_debounce : for i in 6 to 7 generate
			sw_deb : debounce
			generic map(stable_time => 100)
			port map(clk => clk, rst_n => rst_n, sig_in => sw(i), sig_out => sw_d(i));
		end generate gen_sw_debounce;

		js_sw_deb : debounce
		generic map(stable_time => 100)
		port map(clk => clk, rst_n => rst_n, sig_in => js_sw, sig_out => js_sw_d);

		edge_js_sw : edge
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => js_sw_d,
			rising  => open,
			falling => js_sw_fall
		);

		ads_inst : ads_js_ctrl
		port map(
			clk        => clk,
			rst_n      => rst_n,
			scl        => js_scl,
			sda        => js_sda,
			x_raw      => x_raw,
			y_raw      => y_raw,
			data_valid => open
		);

		WS2812_inst : WS2812_ch
		generic map(led_num_max => C_LED_MAX)
		port map(clk => clk, rst_n => rst_n, ena => ws_ena, busy => ws_busy, rgb_data => rgb_data, D_out => D_out, led_num => led_num);

		edge_busy : edge
		port map(clk => clk, rst_n => rst_n, sig_in => ws_busy, rising => open, falling => ws_busy_f);

		key_2x2_inst : entity work.key_2x2_1
			port map(
				clk     => clk,
				rst_n   => rst_n,
				key_row => pb_row,
				key_col => pb_col,
				pressed => key_pressed,
				key     => key_val
			);

		edge_key : edge
		port map(clk => clk, rst_n => rst_n, sig_in => key_pressed, rising => key_edge, falling => open);

		uart_inst : entity work.uart_txt(arch)
			generic map(
				txt_len_max => 16,
				baud        => 115200
			)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				uart_rx => uart_rx,
				uart_tx => uart_tx,
				tx_ena  => '0',
				tx_busy => open,
				tx_data => C_TX_DUMMY,
				tx_len  => 1,
				rx_busy => rx_busy_s,
				rx_data => rx_data_s,
				tx_mode => '0',
				rx_len  => rx_len_s
			);

		edge_rx : edge
		port map(clk => clk, rst_n => rst_n, sig_in => rx_busy_s, rising => open, falling => rx_done);

		lcd_mix_inst : entity work.lcd_mix
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => mix_x,
				y                => mix_y,
				font_start       => font_start,
				font_busy        => font_busy,
				text_size        => 2,
				text_data        => text_data_buf,
				font_mode        => font_mode_sel,
				addr             => open,
				bg_color         => X"FFFFFF",
				text_color_array => text_color_arr,
				clear            => clear_screen,
				lcd_sclk         => lcd_sclk,
				lcd_mosi         => lcd_mosi,
				lcd_ss_n         => lcd_ss_n,
				lcd_dc           => lcd_dc,
				lcd_bl           => lcd_bl,
				lcd_rst_n        => lcd_rst_n
			);
	end block components;

	x_val <= to_integer(unsigned(x_raw));
	y_val <= to_integer(unsigned(y_raw));

	key_dec : process (clk, rst_n)
	begin
		if rst_n = '0' then
			pb0_trig <= '0';
			pb1_trig <= '0';
			pb2_trig <= '0';
			pb3_trig <= '0';
		elsif rising_edge(clk) then
			pb0_trig <= '0';
			pb1_trig <= '0';
			pb2_trig <= '0';
			pb3_trig <= '0';
			if key_edge = '1' then
				if key_val = C_KEY_PB0 then
					pb0_trig <= '1';
				elsif key_val = C_KEY_PB1 then
					pb1_trig <= '1';
				elsif key_val = C_KEY_PB2 then
					pb2_trig <= '1';
				elsif key_val = C_KEY_PB3 then
					pb3_trig <= '1';
				end if;
			end if;
		end if;
	end process;

	uart_rx_proc : process (clk, rst_i)
		variable c : character;
	begin
		if rst_i = '0' then
			rx_num <= 0;
			rx_got <= '0';
			show_saved_val <= '0';
		elsif rising_edge(clk) then
			rx_got <= '0';
			if rx_done = '1' and run_en = '1' then
				c := rx_data_s(rx_len_s);
				if c >= '0' and c <= '8' then
					rx_num <= character'pos(c) - 48;
					rx_got <= '1';
					if c = '8' then
						show_saved_val <= '1';
					elsif c >= '0' and c <= '5' then
						show_saved_val <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	flash_store_proc : process (clk, rst_i)
		variable c : character;
	begin
		if rst_i = '0' then
			is_flashing <= '0';
			flash_cnt <= 0;
			flash_toggle <= '0';
			store_step <= 0;
			-- 重置時預設值為 1
			saved1_dec_H <= 1;
			saved1_dec_L <= 1;
			saved2_dec_H <= 1;
			saved2_dec_L <= 1;
		elsif rising_edge(clk) then
			if is_flashing = '1' then
				if flash_cnt < 50_000_000 - 1 then
					flash_cnt <= flash_cnt + 1;
					-- 每隔 0.25 秒切換一次閃爍狀態 (12,500,000 個時脈)
					if flash_cnt mod 12_500_000 = 0 then
						flash_toggle <= not flash_toggle;
					end if;
				else
					-- 1 秒時間到
					is_flashing <= '0';
					flash_cnt <= 0;
					if store_step = 1 then
						saved1_dec_H <= dec_H; -- saved1 X軸
						saved1_dec_L <= dec_L; -- saved1 Y軸
						store_step <= 2; -- 第一組已存好
					elsif store_step = 3 then
						saved2_dec_H <= dec_H; -- saved2 X軸
						saved2_dec_L <= dec_L; -- saved2 Y軸
						store_step <= 4; -- 兩組皆存滿
					end if;
				end if;
			else
				-- 偵測 UART 是否接收到 key6（字元 '6'）
				if rx_done = '1' and run_en = '1' then
					c := rx_data_s(rx_len_s);
					if c = '6' then
						-- 0：準備存第一組
						if store_step = 0 then
							is_flashing <= '1';
							flash_cnt <= 0;
							flash_toggle <= '0';
							store_step <= 1; -- 進入第一組閃爍中
						-- 2：準備存第二組
						elsif store_step = 2 then
							is_flashing <= '1';
							flash_cnt <= 0;
							flash_toggle <= '0';
							store_step <= 3; -- 進入第二組閃爍中
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	seg_buf_proc : process (clk, rst_i)
	begin
		if rst_i = '0' then
			disp <= (others => C_BLANK);
		elsif rising_edge(clk) then
			dec_H <= to_integer(unsigned(bin_in_H)) + 1;
			dec_L <= to_integer(unsigned(bin_in_L)) + 1;
			if run_en = '1' and mode_sel = "01" then
				if is_flashing = '1' then
					-- 閃爍期間：disp(7) 與 disp(5) 依據 flash_toggle 進行閃爍
					if flash_toggle = '1' then
						disp(7) <= C_NUM(dec_L);
						disp(5) <= C_NUM(dec_H);
					else
						disp(7) <= C_BLANK;
						disp(5) <= C_BLANK;
					end if;
					disp(6) <= C_BLANK;
					disp(4) <= C_BLANK;
					disp(3) <= C_r;
					disp(2) <= C_o;
					disp(1) <= C_o;
					disp(0) <= C_C;
				elsif show_saved_val = '1' then
					-- 按下 key8 時顯示兩組儲存的數值
					disp(7) <= C_NUM(saved2_dec_L);
					disp(6) <= C_NUM(saved2_dec_H);
					disp(5) <= C_2_dot;
					disp(4) <= C_C;
					disp(3) <= C_NUM(saved1_dec_L);
					disp(2) <= C_NUM(saved1_dec_H);
					disp(1) <= C_1_dot;
					disp(0) <= C_C;
				else
					-- 正常即時顯示當前指撥開關數值
					disp(7) <= C_NUM(dec_L);
					disp(6) <= C_BLANK;
					disp(5) <= C_NUM(dec_H);
					disp(4) <= C_BLANK;
					disp(3) <= C_r;
					disp(2) <= C_o;
					disp(1) <= C_o;
					disp(0) <= C_C;
				end if;
			else
				disp <= (others => C_BLANK);
			end if;
		end if;
	end process;

	seg_scan_proc : process (clk, rst_n)
		variable cnt : integer range 0 to C_SCAN_DIV - 1 := 0;
	begin
		if rst_n = '0' then
			cnt := 0;
			digit <= 0;
		elsif rising_edge(clk) then
			if cnt = C_SCAN_DIV - 1 then
				cnt := 0;
				if digit = 7 then
					digit <= 0;
				else
					digit <= digit + 1;
				end if;
			else
				cnt := cnt + 1;
			end if;
		end if;
	end process;

	digit_phy <= (7 - digit) when C_REVERSE else digit;
	seg_led <= (not disp(digit)) when C_SEG_INVERT else disp(digit);

	gen_com : for i in 0 to 7 generate
		seg_com(i) <= C_COM_ON when digit_phy = i else C_COM_OFF;
	end generate gen_com;

	bri_process : process (clk, rst_i)
	begin
		if rst_i = '0' then
			bri_idx <= C_BRI_INIT;
		elsif rising_edge(clk) then
			if run_en = '1' then
				if pb2_trig = '1' then
					if bri_idx < C_BRI_MAX then
						bri_idx <= bri_idx + 1;
					end if;
				elsif pb3_trig = '1' then
					if bri_idx > 0 then
						bri_idx <= bri_idx - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	bri_val <= std_logic_vector(to_unsigned(C_BRI_TBL(bri_idx), 8));
	bri_mask <= l_px_t(std_logic_vector'(bri_val & bri_val & bri_val));

	timer_process : process (clk, rst_i) begin
		if rst_i = '0' then
			timer_cnt <= 0;
			move_tick <= '0';
			anim_cnt <= 0;
			anim_tick <= '0';
			ref_cnt <= 0;
			refresh_tick <= '0';
		elsif rising_edge(clk) then
			move_tick <= '0';
			anim_tick <= '0';
			refresh_tick <= '0';

			if run_en = '1' then
				if timer_cnt < C_MOVE_PERIOD - 1 then
					timer_cnt <= timer_cnt + 1;
				else
					timer_cnt <= 0;
					move_tick <= '1';
				end if;

				if anim_cnt < C_ANIM_PERIOD - 1 then
					anim_cnt <= anim_cnt + 1;
				else
					anim_cnt <= 0;
					anim_tick <= '1';
				end if;

				if lcd_state = wait_ref then
					if ref_cnt < ref_period - 1 then
						ref_cnt <= ref_cnt + 1;
					else
						ref_cnt <= 0;
						refresh_tick <= '1';
					end if;
				else
					ref_cnt <= 0;
				end if;
			end if;
		end if;
	end process;

	Main_Process : block begin
		process (clk, rst_i)
			variable curr_x : integer range 0 to C_LED_MAX;
			variable curr_y : integer range 0 to 7;
			variable start_x, end_x, start_y, end_y : integer;
			variable pos_x : integer range 0 to 7 := C_HOME_X;
			variable pos_y : integer range 0 to 7 := C_HOME_Y;
			variable dx, dy : integer range -1 to 1;
		begin
			if rst_i = '0' then
				mode_t <= idle;
				ws_ena <= '1';
				pos_x := C_HOME_X;
				pos_y := C_HOME_Y;
				pos_x_s <= C_HOME_X;
				pos_y_s <= C_HOME_Y;
				init_pend <= '1';
				anim_done <= '0';
				locked <= '0';
				anim_step <= 0;
				b_x <= 0;
				b_y <= 0;
				r_x <= 1;
				r_y <= 0;
				g_x <= 2;
				g_y <= 0;
				led_num <= C_LED_MAX;
				for i in 0 to C_LED_MAX - 1 loop
					rgb_data(i) <= (others => '0');
				end loop;
			elsif rising_edge(clk) then
				if pb1_trig = '1' then
					ws_ena <= '1';
					for i in 0 to C_LED_MAX - 1 loop
						rgb_data(i) <= (others => '0');
					end loop;
				end if;

				if run_en = '1' then
					led_num <= C_LED_MAX;

					if init_pend = '1' then
						pos_x := home_x;
						pos_y := home_y;
						init_pend <= '0';
					end if;

					if mode_sel = "10" and anim_done = '0' and mode_t = idle then
						anim_step <= 0;
						b_x <= 0;
						b_y <= 0;
						r_x <= 1;
						r_y <= 0;
						g_x <= 2;
						g_y <= 0;
						mode_t <= anim;
					end if;

					case mode_t is

						when idle => -- 搖桿控制方塊移動
							ws_ena <= '0';
							if js_sw_fall = '1' and led_en = '1' then
								if mode_sel = "11" or mode_sel = "10" then
									locked <= not locked;
								end if;
							elsif move_tick = '1' then
								mode_t <= sure;

								if led_en = '1' and locked = '0' then
									dx := 0;
									dy := 0;
									if x_val > 18000 then
										dx := - 1;
									elsif x_val < 9000 then
										dx := 1;
									end if;
									if y_val < 9000 then
										dy := 1;
									elsif y_val > 18000 then
										dy := - 1;
									end if;
									if C_FLIP_X then
										dx := - dx;
									end if;
									if C_FLIP_Y then
										dy := - dy;
									end if;

									if dx < 0 and pos_x > 0 then
										pos_x := pos_x - 1;
									elsif dx > 0 and pos_x < 6 then
										pos_x := pos_x + 1;
									end if;
									if dy < 0 and pos_y > 0 then
										pos_y := pos_y - 1;
									elsif dy > 0 and pos_y < 6 then
										pos_y := pos_y + 1;
									end if;
								end if;

								start_x := pos_x;
								start_y := pos_y;
								end_x := start_x + 1;
								end_y := start_y + 1;

								for i in 0 to C_LED_MAX - 1 loop
									curr_x := i mod 8;
									curr_y := i / 8;

									if led_en = '1' and
										curr_x >= start_x and curr_x <= end_x and
										curr_y >= start_y and curr_y <= end_y then
										rgb_data(i) <= apply_bri(C_BLOCK_COLOR, bri_mask);
									else
										rgb_data(i) <= X"000000";
									end if;
								end loop;
							end if;

						when anim => -- 步驟 1：準備 saved1 與 saved2 兩個藍色點並觸發傳輸
							ws_ena <= '0';
							for i in 0 to C_LED_MAX - 1 loop
								curr_x := i mod 8;
								curr_y := i / 8;

								if (curr_x = saved1_dec_H - 1 and curr_y = saved1_dec_L - 1) or
								   (curr_x = saved2_dec_H - 1 and curr_y = saved2_dec_L - 1) then
									rgb_data(i) <= C_DOT_B; -- 點亮兩個藍色點
								else
									rgb_data(i) <= X"000000"; -- 其餘全暗
								end if;
							end loop;

							ws_ena <= '1';  -- 啟動傳輸
							mode_t <= sure; -- 進入傳輸確認狀態

						when anim_hold => -- 步驟 3：資料發送完後，維持亮燈並計時 5 秒
							ws_ena <= '0';
							if anim_timer < 250_000_000 - 1 then
								anim_timer <= anim_timer + 1;
								mode_t <= anim_hold;
							else
								anim_timer <= 0;
								anim_done <= '1'; -- 標記開機動畫完成
								mode_t <= idle;   -- 切回搖桿控制
							end if;

						when sure =>
							ws_ena <= '1';
							if ws_busy = '1' then
								mode_t <= ws_work;
							end if;

						when ws_work =>
							ws_ena <= '0';
							if ws_busy_f = '1' then
								if anim_done = '0' then
									mode_t <= anim_hold; -- 開機動畫傳輸結束
								else
									mode_t <= idle;      -- 正常搖桿移動傳輸結束+>idle
								end if;
							end if;

					end case;

					pos_x_s <= pos_x;
					pos_y_s <= pos_y;
				else
					ws_ena <= '0';
					mode_t <= idle;
					for i in 0 to C_LED_MAX - 1 loop
						rgb_data(i) <= (others => '0');
					end loop;
				end if;
			end if;
		end process;
	end block Main_Process;

	-- LCD 顯示狀態機（模式 01 時不動作）
	lcd_process : process (clk, rst_i)
		variable px_char, py_char : character;
	begin
		if rst_i = '0' then
			lcd_state <= l_idle;
			clear_screen <= '1';
			font_start <= '0';
			busy_seen <= '0';
			dly_cnt <= 0;
			seq_idx <= 0;
			coord_x <= 8;
			coord_y <= 8;
		elsif rising_edge(clk) then
			font_start <= '0';

			if mode_sel = "00" then
				px_char := character'val(48 + coord_x);
				py_char := character'val(48 + coord_y);
			elsif locked = '1' then
				px_char := '0';
				py_char := '0';
			else
				px_char := character'val(48 + pos_x_s + 1);
				py_char := character'val(48 + pos_y_s + 1);
			end if;

			case lcd_state is
				when l_idle =>
					clear_screen <= '1';
					if run_en = '1' then
						-- 模式 01 時沒有使用LCD，LCD 保持不動作
						if (mode_sel = "00" or mode_sel = "11" or mode_sel = "10") then
							seq_idx <= 0;
							coord_x <= 8;
							coord_y <= 8;
							dly_cnt <= 0;
							lcd_state <= clr_watch;
						end if;
					end if;

				when clr_watch =>
					clear_screen <= '0';
					if dly_cnt < 50000 then
						dly_cnt <= dly_cnt + 1;
					elsif font_busy = '0' then
						lcd_state <= l1_start;
					end if;

				when l1_start =>
					if font_busy = '0' then
						if mode_sel = "00" then
							text_data_buf <= C_GRP(seq_idx) & "        ";
						else
							text_data_buf <= "ABCD        ";
						end if;
						for i in 1 to 12 loop
							text_color_arr(i) <= C_YELLOW;
						end loop;
						mix_x <= C_X1;
						mix_y <= C_Y1;
						font_mode_sel <= 0;
						font_start <= '1';
						busy_seen <= '0';
						lcd_state <= l1_wait;
					end if;

				when l1_wait =>
					if font_busy = '1' then
						busy_seen <= '1';
					elsif busy_seen = '1' then
						lcd_state <= l2_start;
					end if;

				when l2_start =>
					if font_busy = '0' then
						text_data_buf <= "[" & px_char & "," & py_char & "]" & "       ";
						for i in 1 to 12 loop
							text_color_arr(i) <= C_RED;
						end loop;
						mix_x <= C_X2;
						mix_y <= C_Y2;
						font_mode_sel <= 0;
						font_start <= '1';
						busy_seen <= '0';
						lcd_state <= l2_wait;
					end if;

				when l2_wait =>
					if font_busy = '1' then
						busy_seen <= '1';
					elsif busy_seen = '1' then
						lcd_state <= wait_ref;
					end if;

				when wait_ref =>
					if refresh_tick = '1' then
						if mode_sel = "00" then
							if coord_y >= 1 then
								if coord_y <= 1 then
									if coord_x <= 1 then
										coord_x <= 8;
										coord_y <= 8;
									else
										coord_x <= coord_x - 1;
										coord_y <= 8;
									end if;
								else
									coord_y <= coord_y - 1;
								end if;
							else
								coord_y <= 8;
							end if;
							if seq_idx = 25 then
								seq_idx <= 0;
							else
								seq_idx <= seq_idx + 1;
							end if;
						end if;
						lcd_state <= l1_start;
					end if;

			end case;
		end if;
	end process;

end arch;