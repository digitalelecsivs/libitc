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
	type state_t is (idle, anim, sure, ws_work);
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

	-- 搖桿訊號
	signal x_raw, y_raw : u16_t;
	signal x_val, y_val : integer range 0 to 65535 := 0;

	constant C_FLIP_X : boolean := false;
	constant C_FLIP_Y : boolean := false;

	constant C_HOME_X : integer := 0;
	constant C_HOME_Y : integer := 0;
	constant C_CENTER_X : integer := 3;
	constant C_CENTER_Y : integer := 3;
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
	signal rst_pb : std_logic; -- 外部重置 + PB1（不含模式切換）

	type bri_tbl_t is array (0 to 4) of integer range 0 to 255;
	constant C_BRI_TBL : bri_tbl_t := (8, 32, 80, 160, 255);
	constant C_BRI_MAX : integer := 4;
	constant C_BRI_INIT : integer := 2;
	signal bri_idx : integer range 0 to 4 := C_BRI_INIT;
	signal bri_val : std_logic_vector(7 downto 0);
	signal bri_mask : l_px_t;

	-- UART 接收（模式 01）
	signal rx_busy_s : std_logic;
	signal rx_data_s : string(1 to 16);
	signal rx_len_s : integer range 1 to 16;
	signal rx_done : std_logic;
	signal rx_num : integer range 0 to 8 := 0;
	signal rx_got : std_logic := '0';
	constant C_TX_DUMMY : string(1 to 16) := (others => ' ');

	-- 七段顯示器極性
	constant C_SEG_INVERT : boolean := false;
	constant C_COM_ON : std_logic := '0';
	constant C_COM_OFF : std_logic := '1';
	constant C_REVERSE : boolean := false;
	constant C_SCAN_DIV : integer := 50_000;

	subtype seg_t is std_logic_vector(7 downto 0);
	constant C_BLANK : seg_t := "00000000";
	constant C_I : seg_t := "00110000";
	constant C_N : seg_t := "01010100";
	constant C_F : seg_t := "01110001";
	constant C_DOT : seg_t := "10000000";
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
	type lcd_state_t is (l_idle, clr_wait, l1_start, l1_wait, l2_start, l2_wait, wait_ref);
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

	type grp_t is array (0 to 6) of string(1 to 4);
	constant C_GRP : grp_t := ("ABCD", "EFGH", "IJKL", "MNOP",
	"QRST", "UVWX", "YZ  ");
	signal seq_idx : integer range 0 to 6 := 0;
	signal coord_x : integer range 0 to 1 := 0;
	signal coord_y : integer range 1 to 8 := 1;

	constant C_SCR_W : integer := 128;
	constant C_CHAR_W : integer := 12;
	constant C_X1 : integer := (C_SCR_W - (4 * C_CHAR_W)) / 2 - 18;
	constant C_X2 : integer := (C_SCR_W - (7 * C_CHAR_W)) / 2 - 18;
	constant C_Y1 : integer := 18;
	constant C_Y2 : integer := 72;

	constant C_RED : l_px_t := X"FF0000";
	constant C_BLUE : l_px_t := X"0000FF";

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

	-- 將 SW7 當作最低位元 (LSB)，SW6 當作最高位元 (MSB)
	mode_sel <= sw_d(6) & sw_d(7);
	rst_i <= rst_n and (not pb1_trig) and (not mode_chg);
	rst_pb <= rst_n and (not pb1_trig);

	home_x <= C_CENTER_X when mode_sel = "10" else C_HOME_X;
	home_y <= C_CENTER_Y when mode_sel = "10" else C_HOME_Y;

	led_en <= '1' when (mode_sel = "10") or (mode_sel = "11" and test_on = '1') else '0';
	ref_period <= C_SEC_PERIOD when mode_sel = "00" else C_REFRESH_PERIOD;

	components : block begin
		-- 針對 sw(7 downto 6) 進行消彈跳處理
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

	-- UART 接收處理：支援接收 0~8 的按鍵編號
	uart_rx_proc : process (clk, rst_pb)
		variable c : character;
	begin
		if rst_pb = '0' then
			rx_num <= 0;
			rx_got <= '0';
		elsif rising_edge(clk) then
			if rx_done = '1' then
				c := rx_data_s(rx_len_s);
				if c >= '0' and c <= '8' then
					rx_num <= character'pos(c) - 48;
					rx_got <= '1';
				end if;
			end if;
		end if;
	end process;

	-- 七段顯示器緩衝區：維持反向順序排列
	seg_buf_proc : process (clk, rst_pb)
	begin
		if rst_pb = '0' then
			disp <= (others => C_BLANK);
		elsif rising_edge(clk) then
			if (mode_sel = "01" or mode_sel = "11") and rx_got = '1' then
				disp(7) <= C_NUM(rx_num);
				disp(6) <= C_0;
				disp(5) <= C_BLANK;
				disp(4) <= C_BLANK;
				disp(3) <= C_DOT;
				disp(2) <= C_F;
				disp(1) <= C_N;
				disp(0) <= C_I;
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
	end process;

	bri_val <= std_logic_vector(to_unsigned(C_BRI_TBL(bri_idx), 8));
	bri_mask <= l_px_t(std_logic_vector'(bri_val & bri_val & bri_val));

	timer_process : process (clk, rst_n) begin
		if rst_n = '0' then
			timer_cnt <= 0;
			move_tick <= '0';
			anim_cnt <= 0;
			anim_tick <= '0';
			ref_cnt <= 0;
			refresh_tick <= '0';
		elsif rising_edge(clk) then
			move_tick <= '0';
			if timer_cnt < C_MOVE_PERIOD - 1 then
				timer_cnt <= timer_cnt + 1;
			else
				timer_cnt <= 0;
				move_tick <= '1';
			end if;

			anim_tick <= '0';
			if anim_cnt < C_ANIM_PERIOD - 1 then
				anim_cnt <= anim_cnt + 1;
			else
				anim_cnt <= 0;
				anim_tick <= '1';
			end if;

			refresh_tick <= '0';
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
				ws_ena <= '0';
				pos_x := C_HOME_X;
				pos_y := C_HOME_Y;
				pos_x_s <= C_HOME_X;
				pos_y_s <= C_HOME_Y;
				init_pend <= '1';
				test_on <= '0';
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
				led_num <= C_LED_MAX;

				if init_pend = '1' then
					pos_x := home_x;
					pos_y := home_y;
					init_pend <= '0';
				end if;

				if pb0_trig = '1' then
					test_on <= '1';
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

					when idle =>
						ws_ena <= '0';
						if js_sw_fall = '1' and led_en = '1' then
							if mode_sel = "11" then
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

					when anim =>
						ws_ena <= '0';
						if anim_tick = '1' then
							for i in 0 to C_LED_MAX - 1 loop
								curr_x := i mod 8;
								curr_y := i / 8;

								if curr_x = b_x and curr_y = b_y then
									rgb_data(i) <= apply_bri(C_DOT_B, bri_mask);
								elsif curr_x = r_x and curr_y = r_y then
									rgb_data(i) <= apply_bri(C_DOT_R, bri_mask);
								elsif curr_x = g_x and curr_y = g_y then
									rgb_data(i) <= apply_bri(C_DOT_G, bri_mask);
								else
									rgb_data(i) <= X"000000";
								end if;
							end loop;

							if anim_step < 48 then
								if g_x = 7 then
									b_x <= 0;
									b_y <= b_y + 1;
									r_x <= 1;
									r_y <= r_y + 1;
									g_x <= 2;
									g_y <= g_y + 1;
								else
									b_x <= b_x + 1;
									r_x <= r_x + 1;
									g_x <= g_x + 1;
								end if;

								anim_step <= anim_step + 1;
								mode_t <= sure;
								pos_x := home_x;
								pos_y := home_y;
							else
								pos_x := home_x;
								pos_y := home_y;

								start_x := home_x;
								end_x := home_x + 1;
								start_y := home_y;
								end_y := home_y + 1;
								for i in 0 to C_LED_MAX - 1 loop
									curr_x := i mod 8;
									curr_y := i / 8;

									if curr_x >= start_x and curr_x <= end_x and
										curr_y >= start_y and curr_y <= end_y then
										rgb_data(i) <= apply_bri(C_BLOCK_COLOR, bri_mask);
									else
										rgb_data(i) <= X"000000";
									end if;
								end loop;

								ws_ena <= '1';
								mode_t <= sure;
							end if;
						end if;

					when sure =>
						ws_ena <= '1';
						if ws_busy = '1' then
							mode_t <= ws_work;
						end if;

					when ws_work =>
						ws_ena <= '0';
						if ws_busy_f = '1' then
							if anim_step = 48 then
								anim_step <= 0;
								anim_done <= '1';
								mode_t <= idle;
							elsif anim_step > 0 then
								mode_t <= anim;
							else
								mode_t <= idle;
							end if;
						end if;

				end case;

				pos_x_s <= pos_x;
				pos_y_s <= pos_y;
			end if;
		end process;
	end block Main_Process;

	-- TFT LCD 顯示狀態機
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
			coord_x <= 0;
			coord_y <= 1;
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
					if (pb0_trig = '1' and (mode_sel = "00" or mode_sel = "11")) or (mode_sel = "01" and rx_got = '1') then
						seq_idx <= 0;
						coord_x <= 0;
						coord_y <= 1;
						dly_cnt <= 0;
						lcd_state <= clr_wait;
					end if;

				when clr_wait =>
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
						elsif mode_sel = "01" then
							text_data_buf <= "UART RX     ";
						else
							text_data_buf <= "ABCD        ";
						end if;
						for i in 1 to 12 loop
							text_color_arr(i) <= C_RED;
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
						if mode_sel = "01" then
							text_data_buf <= "KEY: " & character'val(48 + rx_num) & "      ";
						else
							text_data_buf <= "[" & px_char & "," & py_char & "]" & "       ";
						end if;
						for i in 1 to 12 loop
							text_color_arr(i) <= C_BLUE;
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
					if refresh_tick = '1' or (mode_sel = "01" and rx_done = '1') then
						if mode_sel = "00" then
							if coord_y < 8 then
								coord_y <= coord_y + 1;
							else
								coord_y <= 1;
								coord_x <= 1 - coord_x;
							end if;
							if seq_idx = 6 then
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
