library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity v13_114_A is
	port (
		-- sys
		clk   : in std_logic;
		rst_n : in std_logic;

		led_r, led_g, led_y                                     : out std_logic;
		rgb                                                     : out std_logic_vector(0 to 2);
		buz                                                     : out std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic; -- lcd
		seg_led, seg_com                                        : out u8r_t;     -- seg
		sw                                                      : in u8r_t;      -- sw
		dot_red, dot_green, dot_com                             : out u8r_t;     -- dot
		key_row                                                 : in u4r_t;      --key
		key_col                                                 : out u4r_t;
		uart_rx                                                 : in std_logic;  -- uart    receive pin
		uart_tx                                                 : out std_logic; -- 		transmit pin

		dbg_b : out u8r_t; -- dbg
		dbg_a : out u8r_t
	);
end v13_114_A;

architecture arch of v13_114_A is
	--state machine
	type state_t is (init, Main);--總狀態機
	type state_m is (mode00, mode01, mode10, mode11);--第一層=>總狀態機的Main
	type state_1 is (init, rxi_connect, ready);--第一層=>總狀態機的init
	type state_2 is (init, sel_client, IO_init, rxi_cls, rxi_data, rxi_check, rxi_save, lcd_change, IO_change, lcd_txt);--第二層=>mode01
	type state_3 is (init, ensure, del_sel, del_data, del_esc, dot_change, data_dot_init, IO_change, lcd_txt);--第二層=>mode10
	type state_4 is (init, sel_client, txi_data, data_cls, waiting);--第二層=>mode11
	type state_tx is (idle, send);--傳輸data的狀態機
	type state_dot is (init, move, dot_state, change);--刪除資料的資料處理流程的狀態機
	signal mode_t : state_t := init;
	signal mode_m : state_m := mode00;
	signal mode_1 : state_1 := init;
	signal mode_2 : state_2 := init;
	signal mode_3 : state_3 := init;
	signal mode_4 : state_4 := init;
	signal mode_tx : state_tx := idle;
	signal mode_dot : state_dot := init;

	--pic signal
	signal l_addr : l_addr_t;

	--type def
	type picture is array (integer range <>) of l_px_t;
	type l_coord_arr is array (0 to 11) of l_coord_t;
	type str_array is array (integer range <>) of string(1 to 8);
	type txt_array is array (integer range <>) of string(1 to 4);

	--lcd
	signal x : integer range -127 to 127 := 0;
	signal y : integer range -159 to 159 := 0;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(32));
	signal text_size : integer range 1 to 12;
	signal text_color_array : l_px_arr_t(1 to 12) := (others => black);
	signal bg_color : l_px_t;
	signal font_mode : integer range 0 to 2;
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--8*8 dot led
	signal data_g, data_r : u8r_arr_t(0 to 7);

	--key board
	signal pressed_i : std_logic := '0';
	signal pressed : std_logic := '0';
	signal key : integer range 0 to 15;

	--uart
	signal rx_start, rx_done, tx_mode : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_ena_e : std_logic;
	signal tx_data, rx_data : string(1 to 12);
	signal tx_len, rx_len : integer range 1 to 12;

	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 5000 := 0;
	signal ena_tim1 : std_logic := '1';
	signal msec1 : integer range 0 to 5000 := 0;

	--user signal
	signal client_num : integer range 0 to 7 := 0;
	signal data_buffer : string(1 to 8) := (others => character'val(32));
	-- signal data_set : str_array(0 to 7) := (others => (others => character'val(32)));
	signal data_len : i4_arr_t(0 to 7) := (others => 0);
	signal orange_dot_next : std_logic := '0'; -- 0:沒有資料 1:有資料 --下一個點 
	signal orange_dot : std_logic := '0'; -- 0:沒有資料 1:有資料 --現在的點

	signal sw_d : std_logic_vector(0 to 1);
	signal init_flag : std_logic := '0';
	signal OF_flag : std_logic := '0';
	signal buz_flag : std_logic := '0';
	signal rgb_flag : std_logic := '0';
	signal connect_flag : std_logic := '0';
	signal msec_flag : std_logic := '0';
	signal dot_flag : std_logic := '0';
	signal init00_flag : std_logic := '0';
	signal clear_flag : std_logic := '0';
	signal blink_flag : std_logic := '0';

	signal dot_x : integer range 0 to 7;
	signal dot_y : integer range 0 to 7;
	-- signal temp_x : integer range 0 to 7;
	-- signal temp_y : integer range 0 to 7;
	signal txt_cnt : integer range 0 to 8 := 0;
	signal map_coord : l_coord_arr := ((10, 0), (10, 32), (10, 64), (10, 96), (63, 0), (63, 32), (63, 64), (63, 96), (116, 0), (116, 32), (116, 64), (116, 96));
	signal txt_RX : string(1 to 4) := " RX ";
	signal txt_TX : string(1 to 4) := " TX ";
	signal txt_OF : string(1 to 4) := "OF  ";
	-- signal txt_OF1 : string(1 to 4) := "OF1";
	signal txt_OK : string(1 to 4) := "OK  ";
	-- signal del_cnt : integer range 0 to 8;
	-- signal cnt_i : integer range 0 to 8;
	-- signal cnt_j : integer range 0 to 8;

begin
	-- Component -------------------------------------------------------------------------------------------------------------------------
	components : block begin
		debounce2 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(6),  -- input signal to be debounced
				sig_out => sw_d(0) -- debounced signal
			);
		debounce1 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(7),  -- input signal to be debounced
				sig_out => sw_d(1) -- debounced signal
			);
		dot_inst : entity work.dot(arch)
			generic map(
				common_anode => '0'
			)
			port map(
				clk       => clk,
				rst_n     => rst_n,
				dot_red   => dot_red,   --腳位
				dot_green => dot_green, --腳位
				dot_com   => dot_com,   --腳位
				data_r    => data_r,    --紅色資料
				data_g    => data_g     --綠色資料
			);
		seg_inst : entity work.seg(arch)--8bit七段顯示器元件
			port map(
				clk     => clk,
				rst_n   => rst_n,
				seg_led => seg_led,
				seg_com => seg_com,
				data    => seg_data,
				dot => (others => '0')
			);
		timer_inst : entity work.timer(arch)--計時器
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena_tim,
				load  => 0,
				msec  => msec
			);
		timer1_inst : entity work.timer(arch)--計時器
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena_tim1,
				load  => 0,
				msec  => msec1
			);
		key_inst : entity work.key(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				key_row => key_row,
				key_col => key_col,
				pressed => pressed_i,
				key     => key
			);
		edge_key : entity work.edge(arch)--微分出只有一個ck的keyboard trigger
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => open
			);
		lcd_mix_inst : entity work.lcd_mix_intgr_aph(arch)
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => x,
				y                => y,
				font_start       => font_start,
				font_busy        => font_busy_i,
				text_size        => text_size,
				text_data        => text_data,
				font_mode        => font_mode,
				addr             => l_addr,
				bg_color         => bg_color,
				text_color_array => text_color_array,
				clear            => l_clear,
				lcd_sclk         => lcd_sclk,
				lcd_mosi         => lcd_mosi,
				lcd_ss_n         => lcd_ss_n,
				lcd_dc           => lcd_dc,
				lcd_bl           => lcd_bl,
				lcd_rst_n        => lcd_rst_n
			);
		edge_font : entity work.edge(arch)--lcd 文字更新的busy旗標-- 抓結束的ck，讓font_start重置
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy_i,
				rising  => open,
				falling => font_busy
			);
		uart_txt : entity work.uart_txt(arch)--uart傳輸，wifi連接用
			generic map(
				txt_len_max => 12,
				baud        => 115200 -- data link baud rate in bits/second
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- uart
				uart_rx => uart_rx, -- receive pin
				uart_tx => uart_tx, -- transmit pin
				-- user logic
				tx_ena  => tx_ena_e, -- initiate transmission
				tx_busy => tx_busy,  -- transmission in progress
				tx_data => tx_data,  -- data to transmit
				tx_len  => tx_len,
				tx_mode => tx_mode,
				rx_busy => rx_busy, -- data reception in progress
				rx_data => rx_data, -- data received
				rx_len  => rx_len
			);
		edge_tx : entity work.edge(arch)--tx_ena_e => rising_edge(tx_ena)-- tx_ena_e to uart_txt，uart_txt的ena設計是一個ck的trigger
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => tx_ena,
				rising  => tx_ena_e,
				falling => open
			);
		edge_rx : entity work.edge(arch)--rx_done => falling_edge(rx_busy)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => rx_busy,
				rising  => open,
				falling => rx_done
			);
	end block components;
	-- INPUT def -------------------------------------------------------------------------------------------------------------------------
	Input_def : block begin--指撥開關的輸入設定
		process (clk, rst_n) begin
			if rst_n = '0' then
			elsif rising_edge(clk) then
			end if;
		end process;
		mode_m <= mode00 when sw(6 to 7) = "00" else
			mode01 when sw(6 to 7) = "01" else
			mode10 when sw(6 to 7) = "10" else
			mode11 when sw(6 to 7) = "11"else mode00;
	end block Input_def;

	-- dbg & test ------------------------------------------------------------------------------------------------------------------------
	dbg_test : block begin
		dbg_a(0 to 3) <= not("1000") when mode_2 = init else
		not("0100") when mode_2 = sel_client else
		not("0010") when mode_2 = IO_init else
		not("0001") when mode_2 = rxi_cls else not("0000");
		dbg_a(4 to 7) <= not("1000") when mode_2 = rxi_data else
		not("0100") when mode_2 = rxi_save else
		not("0010") when mode_2 = lcd_change else
		not("0001") when mode_2 = lcd_txt else not("0000");
		dbg_b(0 to 3) <= not("1000") when mode_3 = init else
		not("0100") when mode_3 = ensure else
		not("0010") when mode_3 = del_sel else
		not("0001") when mode_3 = del_data else not("0000");
		-- dbg_b(4 to 7) <= not(to_unsigned(data_len(dot_x), 4));
		--not(rgb_flag & buz_flag & OF_flag & '0');
	end block dbg_test;
	-- Main Process ----------------------------------------------------------------------------------------------------------------------
	Main_Process : block
		-- 接收資料的資料結構
		-- signal client_num : integer range 0 to 7 := 0;
		-- signal data_buffer : string(1 to 8) := (others => character'val(32));
		-- signal data_set : str_array(1 to 8) := (others => (others => character'val(32)));
		-- signal data_len : i4_arr_t(0 to 7) := (others => 0);
		-- signal  OF_num : integer range 0 to 7 := 0;
		-- signal OF_flag : std_logic := '0';
		-- signal buz_flag : std_logic := '0';
		-- signal rgb_flag : std_logic := '0';
	begin
		process (clk, rst_n)
			variable OF_num : integer range 0 to 7 := 0;--檢查溢位數量
			variable data_num : integer range 0 to 9 := 0;--作為圖片的引數(index)
			variable pic : picture(0 to 11);
			variable cnt_i : integer range 0 to 8;
			variable cnt_j : integer range 0 to 8;
			variable cnt_k : integer range 0 to 8;
			variable data_set : str_array(0 to 7) := ("1       ", "        ", "11      ", "11111   ", "111     ", "1       ", "111111  ", "111     ");
			variable data_state : u8r_arr_t(0 to 7) := (others => (others => '0'));
			variable data_del : u8r_arr_t(0 to 7) := (others => (others => '0'));
			variable red_dot : u8r_arr_t(0 to 7);
			variable changed : u8_t := (others => '0');
			variable del_cnt : integer range 0 to 8;
			-- variable str_temp : string(0 to 0) := (others => character'val(32));
			variable temp_x : integer range 0 to 7;
			variable temp_y : integer range 0 to 7;
			variable dot_x : integer range 0 to 7;
			variable dot_y : integer range 0 to 7;
		begin
			if rst_n = '0' then
				--led & buz
				led_r <= '0';
				led_g <= '0';
				led_y <= '0';
				rgb <= (others => '0');

				--seg
				seg_data <= "        ";

				--lcd
				l_clear <= '1';
				bg_color <= white;
				txt_cnt <= 0;

				--dot
				data_g <= (others => (others => '0'));
				data_r <= (others => (others => '0'));
				dot_x := 7;
				dot_y := 7;
				temp_x := 7;
				temp_y := 7;

				--data struct
				client_num <= 0;
				data_buffer <= (others => character'val(32));
				data_set := ("1       ", "        ", "11      ", "11111   ", "111     ", "1       ", "111111  ", "111     ");
				data_len <= (others => 0);
				OF_num := 0;
				data_num := 0;

				--uart
				tx_ena <= '0';

				--flag
				OF_flag <= '0';
				rgb_flag <= '0';
				buz_flag <= '0';
				connect_flag <= '0';
				msec_flag <= '0';
				blink_flag <= '0';

				--timer
				ena_tim <= '0';

				--state machine
				mode_t <= init;
				mode_1 <= init;
				mode_2 <= init;
				mode_3 <= init;
				mode_4 <= init;
				mode_tx <= idle;
				mode_dot <= init;
			elsif rising_edge(clk) then
				case mode_t is
					when init =>
						--IO_init
						led_r <= '0';
						led_g <= '0';
						led_y <= '0';
						seg_data <= "        ";
						l_clear <= '1';
						bg_color <= white;
						data_g <= (others => (others => '0'));
						data_r <= (others => (others => '0'));
						mode_t <= Main;
						--在初始化時，要求的IO變化
					when Main =>
						case sw_d is
							when "00" =>
								case mode_1 is
									when init =>
										led_r <= '0';
										led_g <= '0';
										led_y <= '0';
										init00_flag <= '0';
										rgb <= (others => '0');
										seg_data <= "        ";
										l_clear <= '1';
										bg_color <= white;
										data_g <= (others => (others => '0'));
										data_r <= (others => (others => '0'));
										if rx_done = '1' then
											mode_1 <= rxi_connect;
										end if;
										ena_tim <= '0';
									when rxi_connect =>
										if rx_data(1 to 7) = "connect" then
											connect_flag <= '1';
											mode_1 <= ready;
											ena_tim <= '1';
										else
											connect_flag <= '0';
											mode_1 <= init;
											ena_tim <= '0';
										end if;

									when ready =>
										if msec < 2000 and init00_flag = '0' then
											rgb(0) <= ('1' and rgb_flag);
											rgb(1) <= '0';
											rgb(2) <= ('1' and rgb_flag);
											if (msec/500)mod 2 = 0 then
												rgb_flag <= '1';
											else
												rgb_flag <= '0';
											end if;
										else
											ena_tim <= '0';
											init00_flag <= '1';
											data_g <= (others => (others => '1'));
											data_r <= (others => (others => '0'));
											l_clear <= '1';
											bg_color <= black;
											seg_data <= "CLT0.000";
											mode_t <= Main;
											-- mode_1 <= init;
											mode_2 <= init;
											mode_3 <= init;
											mode_4 <= init;
										end if;
								end case;
							when "01" =>
								case mode_2 is
									when init =>
										--I/O init
										led_r <= '0';
										led_g <= '0';
										led_y <= '0';
										l_clear <= '1';
										bg_color <= white;
										rgb <= (others => '0');
										seg_data <= "        ";
										data_g <= (others => (others => '0'));
										data_r <= (others => (others => '0'));
										clear_flag <= '0';
										ena_tim <= '1';
										if msec >= 30 then
											mode_2 <= sel_client;
											ena_tim <= '0';
										end if;
										-- if pressed = '1' then
										-- 	case key is
										-- 		when 12 =>
										-- 			
										-- 			mode_2 <= sel_client;
										-- 			ena_tim <= '0';
										-- 		when others => null;
										-- 	end case;
										-- end if;
										-- if buz_flag = '1' then
										-- 	buz <= '1';
										-- 	ena_tim <= '1';
										-- 	if msec > 500 then
										-- 		ena_tim <= '0';
										-- 		buz_flag <= '0';
										-- 		buz <= '0';
										-- 		mode_2 <= sel_client;
										-- 	end if;
										-- end if;
									when sel_client => --選擇client
										--顯示選擇了client
										--client 編號

										client_num <= to_integer (sw (3 to 5));
										if pressed = '1' then
											case key is
												when 14 => --離開鍵
													mode_2 <= init;
												when 12 =>
													rgb(2) <= ('1');
													clear_flag <= '0';
													seg_data <= "CLT" & character'val(client_num + 48) & ".000";-- & character'val(rx_len + 48);
													-- when 15 => --確認鍵
													mode_2 <= IO_init;
												when others => null;
											end case;
										end if;
										l_clear <= '1';-- 清除lcd
										bg_color <= white;
										cnt_i := 0;
										cnt_j := 0;
									when IO_init =>
										seg_data <= "CLT" & character'val(client_num + 48) & ".000";-- & character'val(rx_len + 48);
										data_g <= (others => (others => '1'));
										if data_set(cnt_i)(cnt_j) = '1' then
											data_state(cnt_j - 1)(cnt_i) := '1';
										else
											data_state(cnt_j - 1)(cnt_i) := '0';
										end if;
										if cnt_j < 7 then
											cnt_j := cnt_j + 1;
										else
											cnt_j := 0;
											if cnt_i < 7 then
												cnt_i := cnt_i + 1;
											else
												cnt_i := 0;
												cnt_j := 0;
												mode_2 <= rxi_cls;
												data_buffer <= (others => character'val(32));
											end if;
										end if;
										data_r <= data_state;
									when rxi_cls => --接收rx_done => 清除data_buffer --等待接收
										if rx_done = '1' then
											data_buffer <= (others => character'val(32));
											mode_2 <= rxi_data;--整理rx_data
											clear_flag <= '1';
										end if;
										if pressed = '1' then
											case key is
												when 14 => --離開鍵
													mode_2 <= sel_client;
													data_buffer <= (others => character'val(32));
												when others => null;
											end case;
										end if;
										--顯示RX
										if clear_flag = '1' then
											if msec > 20 then
												l_clear <= '0';
												font_mode <= 2;
												font_start <= '1';
											end if;
											if txt_cnt = 0 then
												x <= 0;
												y <= 53 * 0;
												text_data(1 to 4) <= txt_RX;
											end if;
											if txt_cnt = 1 then
												x <= 0;
												y <= 53 * 1;
												if OF_flag = '0' then
													if rx_len = 1 then
														text_data(1 to rx_len) <= data_buffer(1 to rx_len);
														text_data(2 to 4) <= (others => character'val(32));
													end if;
													if rx_len = 2 then
														text_data(1 to rx_len) <= data_buffer(1 to rx_len);
														text_data(3 to 4) <= (others => character'val(32));
													end if;
													if rx_len = 3 then
														text_data(1 to rx_len) <= data_buffer(1 to rx_len);
														text_data(4) <= ' ';
													end if;
													if rx_len = 4 then
														text_data(1 to rx_len) <= data_buffer(1 to rx_len);
													end if;
													if rx_len = 5 then
														text_data(1 to rx_len) <= data_buffer(1 to rx_len);
													end if;
												elsif OF_flag = '1' then
													if (rx_len - OF_num) = 1 then
														text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
														text_data(2 to 4) <= (others => character'val(32));
													end if;
													if (rx_len - OF_num) = 2 then
														text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
														text_data(3 to 4) <= (others => character'val(32));
													end if;
													if (rx_len - OF_num) = 3 then
														text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
														text_data(4) <= ' ';
													end if;
													if (rx_len - OF_num) = 4 then
														text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
													end if;
													if (rx_len - OF_num) = 5 then
														text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
													end if;
												end if;
												font_start <= '1';
											end if;
											if txt_cnt = 2 then
												x <= 0;
												y <= 53 * 2;
												text_data(1 to 4) <= "OF" & character'val(of_num + 48) & ' ';
												-- if OF_flag = '1' then
												-- 	text_data(1 to 4) <= " OF1";
												-- elsif OF_flag = '0' then
												-- end if;
												font_start <= '1';
											end if;
											if font_busy = '1' then
												font_start <= '0';
												if txt_cnt <= 2 then
													txt_cnt <= txt_cnt + 1;
												else
													txt_cnt <= 0;
												end if;
												ena_tim <= '1';
											end if;
										elsif clear_flag = '0' then
											ena_tim <= '1';
											if msec >= 20 then
												ena_tim <= '0';
												l_clear <= '0';
												font_start <= '1';
												font_mode <= 2;
											end if;
											if txt_cnt = 0 then
												x <= 0;
												y <= 0;
												text_data(1 to 4) <= "    ";
												text_data(5 to 12) <= (others => character'val(32));
											end if;
											if txt_cnt = 1 then
												x <= 0;
												y <= 53 * 1;
												text_data(1 to 4) <= "    ";
												text_data(5 to 12) <= (others => character'val(32));
											end if;
											if txt_cnt = 2 then
												x <= 0;
												y <= 53 * 2;
												text_data(1 to 4) <= "    ";
												text_data(5 to 12) <= (others => character'val(32));
											end if;
											if font_busy = '1' then
												font_start <= '0';
												if txt_cnt <= 2 then
													txt_cnt <= txt_cnt + 1;
												else
													txt_cnt <= 0;
												end if;
												ena_tim <= '1';
											end if;
										end if;
									when rxi_data => --整理rx_data
										data_buffer(1 to rx_len) <= rx_data(1 to rx_len); --暫存資料
										if rx_len <= 5 and rx_len >= 1 then
											if data_len(client_num) + rx_len <= 8 then --沒溢位
												OF_flag <= '0'; --設旗標
												OF_num := 0; --設溢位位數
												data_len(client_num) <= data_len(client_num) + rx_len;--設定現在client的資料長度
												mode_2 <= rxi_save; --儲存資料
											elsif data_len(client_num) + rx_len > 8 then--有溢位
												OF_flag <= '1'; --設旗標
												OF_num := data_len(client_num) + rx_len - 8;--設溢位位數
												data_len(client_num) <= 8;--設定現在client的資料長度
												mode_2 <= rxi_save; --儲存資料
											end if;
										else
											mode_2 <= rxi_cls;
										end if;
									when rxi_check =>
									when rxi_save => -- 儲存資料到data_set中
										if OF_flag = '1' then
											if rx_len <= 5 and rx_len >= 1 then
												if cnt_i < (rx_len - OF_num) then
													data_set(client_num)(data_len(client_num) - ((rx_len - OF_num)) + cnt_i + 1) := data_buffer(cnt_i + 1);
												end if;
											end if;
										elsif OF_flag = '0' then
											if rx_len <= 5 and rx_len >= 1 then
												if cnt_i < rx_len then
													data_set(client_num)(data_len(client_num) - rx_len + cnt_i + 1) := data_buffer(cnt_i + 1);
												end if;
											end if;
										end if;
										if cnt_i < 5 then
											cnt_i := cnt_i + 1;
										else
											cnt_i := 0;
											cnt_j := 0;
											mode_2 <= IO_change;
										end if;

									when IO_change =>
										seg_data <= "CLT" & character'val(client_num + 48) & ".00" & character'val(rx_len + 48);
										data_g <= (others => (others => '1'));
										if data_set(cnt_i)(cnt_j) /= ' ' then
											data_state(cnt_j - 1)(cnt_i) := '1';
										else
											data_state(cnt_j - 1)(cnt_i) := '0';
										end if;
										if cnt_j < 7 then
											cnt_j := cnt_j + 1;
										else
											cnt_j := 0;
											if cnt_i < 7 then
												cnt_i := cnt_i + 1;
											else
												cnt_i := 0;
												cnt_j := 0;
												msec_flag <= '1';
												mode_2 <= lcd_change;
											end if;
										end if;
										data_r <= data_state;
									when lcd_change =>
										if msec_flag = '1' then
											ena_tim <= '1';
											msec_flag <= '0';
										end if;
										if msec > 20 then
											l_clear <= '0';
											font_mode <= 2;
											font_start <= '1';
										end if;
										if txt_cnt = 0 then
											x <= 0;
											y <= 53 * 0;
											text_data(1 to 4) <= txt_RX;
										end if;
										if txt_cnt = 1 then
											x <= 0;
											y <= 53 * 1;
											if OF_flag = '0' then
												if rx_len = 1 then
													text_data(1 to rx_len) <= data_buffer(1 to rx_len);
													text_data(2 to 4) <= (others => character'val(32));
												end if;
												if rx_len = 2 then
													text_data(1 to rx_len) <= data_buffer(1 to rx_len);
													text_data(3 to 4) <= (others => character'val(32));
												end if;
												if rx_len = 3 then
													text_data(1 to rx_len) <= data_buffer(1 to rx_len);
													text_data(4) <= ' ';
												end if;
												if rx_len = 4 then
													text_data(1 to rx_len) <= data_buffer(1 to rx_len);
												end if;
												if rx_len = 5 then
													text_data(1 to rx_len) <= data_buffer(1 to rx_len);
												end if;
											elsif OF_flag = '1' then
												if (rx_len - OF_num) = 1 then
													text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
													text_data(2 to 4) <= (others => character'val(32));
												end if;
												if (rx_len - OF_num) = 2 then
													text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
													text_data(3 to 4) <= (others => character'val(32));
												end if;
												if (rx_len - OF_num) = 3 then
													text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
													text_data(4) <= ' ';
												end if;
												if (rx_len - OF_num) = 4 then
													text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
												end if;
												if (rx_len - OF_num) = 5 then
													text_data(1 to (rx_len - OF_num)) <= data_buffer(1 to (rx_len - OF_num));
												end if;
											end if;
											font_start <= '1';
										end if;
										if txt_cnt = 2 then
											x <= 0;
											y <= 53 * 2;
											text_data(1 to 4) <= "OF" & character'val(of_num + 48) & ' ';
											-- if OF_flag = '1' then
											-- 	text_data(1 to 4) <= " OF1";
											-- elsif OF_flag = '0' then
											-- end if;
											font_start <= '1';
										end if;
										if font_busy = '1' then
											font_start <= '0';
											if txt_cnt <= 2 then
												txt_cnt <= txt_cnt + 1;
											else
												txt_cnt <= 0;
											end if;
											ena_tim <= '1';
										end if;
										if pressed = '1' then
											if key = 15 then
												mode_2 <= rxi_cls;
												msec_flag <= '1';
												ena_tim <= '0';
											end if;
										end if;
										-- ena_tim <= '1';
										-- if msec > 1000 then
										-- 	ena_tim <= '0';
										-- 	-- l_clear <= '1';
										-- 	-- bg_color <= white;
										-- 	mode_2 <= rxi_cls;
										-- 	msec_flag <= '1';
										-- end if;
									when lcd_txt =>
										-- 	if msec_flag = '1' then
										-- 		ena_tim <= '1';
										-- 		msec_flag <= '0';
										-- 	end if;
										-- 	if msec >= 20 then
										-- 		ena_tim <= '0';
										-- 		l_clear <= '0';
										-- 		font_start <= '1';
										-- 		font_mode <= 0;
										-- 	end if;
										-- 	if txt_cnt = 0 then
										-- 		x <= 0;
										-- 		y <= 0;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(0);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 	end if;
										-- 	if txt_cnt = 1 then
										-- 		x <= 0;
										-- 		y <= 16;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(1);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 2 then
										-- 		x <= 0;
										-- 		y <= 32;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(2);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 3 then
										-- 		x <= 0;
										-- 		y <= 48;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(3);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 4 then
										-- 		x <= 0;
										-- 		y <= 64;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(4);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 5 then
										-- 		x <= 0;
										-- 		y <= 80;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(5);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 6 then
										-- 		x <= 0;
										-- 		y <= 96;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(6);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 7 then
										-- 		x <= 0;
										-- 		y <= 112;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_set(7);
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if txt_cnt = 8 then
										-- 		x <= 0;
										-- 		y <= 128;
										-- 		text_size <= 1;
										-- 		text_data(1 to 8) <= data_buffer;
										-- 		text_data(9 to 12) <= (others => character'val(32));
										-- 		font_start <= '1';
										-- 	end if;
										-- 	if font_busy = '1' then
										-- 		font_start <= '0';
										-- 		if txt_cnt <= 8 then
										-- 			txt_cnt <= txt_cnt + 1;
										-- 		else
										-- 			txt_cnt <= 0;
										-- 		end if;
										-- 		ena_tim <= '1';
										-- 	end if;
										-- 	if pressed = '1' then
										-- 		case key is
										-- 			when 15 =>
										-- 				mode_2 <= IO_init;
										-- 			when others => null;
										-- 		end case;
										-- 	end if;
										-- when others => null;
								end case;
							when "10" =>
								if (msec1/500)mod 2 = 0 then
									blink_flag <= '0';
								elsif (msec1/500)mod 2 = 1 then
									blink_flag <= '1';
								end if;
								case mode_3 is
									when init =>
										-- led_r <= '0';
										-- led_g <= '0';
										-- led_y <= '0';

										-- data_g <= (others => (others => '0'));
										-- data_r <= (others => (others => '0'));
										-- l_clear <= '1';
										-- bg_color <= white;
										-- seg_data <= "        ";
										ena_tim1 <= '1';
										if pressed = '1' then
											case key is
												when 12 =>
													rgb(1 to 2) <= (others => '0');
													rgb(0) <= '1';
													mode_3 <= ensure;
												when others => null;
											end case;
										end if;
										if buz_flag = '1' then
											buz <= '1';
											ena_tim <= '1';
											if msec > 500 then
												ena_tim <= '0';
												buz_flag <= '0';
												buz <= '0';
												mode_3 <= ensure;
											end if;
										end if;
									when ensure =>
										--當按下確認鍵後會進到ensure，在按下清除建會進到刪除模式
										--會先洗一遍dot，就不會再洗
										--直到下次進到ensure
										if pressed = '1' then
											case key is
													-- when 14 => mode_3 <= init;
												when 14 => mode_3 <= data_dot_init;
													dot_x := 7;
													dot_y := 7;
													temp_x := 7;
													temp_y := 7;
												when others => null;
											end case;
										end if;
										l_clear <= '1';
										bg_color <= white;
										seg_data <= "        ";
										data_g <= (others => (others => '1'));--把現在的data_set的狀態顯示出來
										if data_set(cnt_i)(cnt_j) = ' ' or data_set(cnt_i)(cnt_j) = '0'then
											data_state(cnt_j - 1)(cnt_i) := '0';
										else
											data_state(cnt_j - 1)(cnt_i) := '1';
										end if;
										if cnt_j < 7 then
											cnt_j := cnt_j + 1;
										else
											cnt_j := 0;
											if cnt_i < 7 then
												cnt_i := cnt_i + 1;
											else
												cnt_i := 0;
												cnt_j := 0;
											end if;
										end if;
										data_r <= data_state;
									when data_dot_init =>
										data_g <= (others => (others => '1'));--把現在的data_set的狀態顯示出來
										if data_set(cnt_i)(cnt_j) /= ' ' then
											data_state(cnt_j - 1)(cnt_i) := '1';
										else
											data_state(cnt_j - 1)(cnt_i) := '0';
										end if;
										if cnt_j < 7 then
											cnt_j := cnt_j + 1;
										else
											cnt_j := 0;
											if cnt_i < 7 then
												cnt_i := cnt_i + 1;
											else
												cnt_i := 0;
												cnt_j := 0;
												mode_3 <= del_sel;
												mode_dot <= init;
											end if;
										end if;
										data_r <= data_state;
										del_cnt := 0;
										changed := (others => '0');
										data_del := (others => (others => '0'));

									when del_sel =>
										case mode_dot is
											when init =>
												--初始化紅點
												dot_x := 7;
												dot_y := 7;
												temp_x := 7;
												temp_y := 7;
												--紀錄現在紅點的狀態(有資料or無資料)
												-- if data_r(dot_y)(dot_x) = '1' then
												-- 	orange_dot <= '1';
												-- elsif data_r(dot_y)(dot_x) = '0' then
												-- 	orange_dot <= '0';
												-- end if;
												red_dot := (others => (others => '0'));
												--移動
												ena_tim <= '1';
												if msec > 100 then
													ena_tim <= '0';
													mode_dot <= move;
													red_dot(dot_y)(dot_x) := '1';
													-- data_r(dot_y)(dot_x) <= '1';
													-- data_g(dot_y)(dot_x) <= '0';
												end if;
											when move =>
												if pressed = '1' then
													case key is
														when 1 => -- 上 
															if dot_y < 7 then
																dot_y := dot_y + 1;
																-- mode_dot <= dot_state;
																red_dot(temp_y)(temp_x) := '0';
																red_dot(dot_y)(dot_x) := '1';
																temp_x := dot_x;
																temp_y := dot_y;
															end if;
														when 4 => -- 左
															if dot_x > 0 then
																dot_x := dot_x - 1;
																-- mode_dot <= dot_state;
																red_dot(temp_y)(temp_x) := '0';
																red_dot(dot_y)(dot_x) := '1';
																temp_x := dot_x;
																temp_y := dot_y;
															end if;
														when 9 => -- 下
															if dot_y > 0 then
																dot_y := dot_y - 1;
																-- mode_dot <= dot_state;
																red_dot(temp_y)(temp_x) := '0';
																red_dot(dot_y)(dot_x) := '1';
																temp_x := dot_x;
																temp_y := dot_y;
															end if;
														when 6 => -- 右
															if dot_x < 7 then
																dot_x := dot_x + 1;
																-- mode_dot <= dot_state;
																red_dot(temp_y)(temp_x) := '0';
																red_dot(dot_y)(dot_x) := '1';
																temp_x := dot_x;
																temp_y := dot_y;
															end if;
														when 13 => mode_3 <= del_esc;
															-- cnt_i := 7;
															-- cnt_j := 7;
														when 12 =>
															buz_flag <= '1';
															ena_tim <= '0';
														when others => null;
													end case;
												end if;
												if blink_flag = '1' then
													if data_state(cnt_j)(cnt_i) = '1' or red_dot(cnt_j)(cnt_i) = '1' then
														data_r(cnt_j)(cnt_i) <= '1';
													else
														data_r(cnt_j)(cnt_i) <= '0';
													end if;

													if red_dot(cnt_j)(cnt_i) = '1' then
														data_g(cnt_j)(cnt_i) <= '0';
													else
														data_g(cnt_j)(cnt_i) <= '1';
													end if;
												elsif blink_flag = '0' then
													if data_state(cnt_j)(cnt_i) = '1'then
														data_r(cnt_j)(cnt_i) <= '1';
													else
														data_r(cnt_j)(cnt_i) <= '0';
													end if;
													data_g <= (others => (others => '1'));

												end if;
												if cnt_j < 7 then
													cnt_j := cnt_j + 1;
												else
													cnt_j := 0;
													if cnt_i < 7 then
														cnt_i := cnt_i + 1;
													else
														cnt_i := 0;
														cnt_j := 0;
													end if;
												end if;

												if buz_flag = '1' then
													buz <= '1';
													ena_tim <= '1';
													if msec > 1000 then
														ena_tim <= '0';
														buz_flag <= '0';
														buz <= '0';
														mode_3 <= del_data;
													end if;
												end if;
											when dot_state =>
												-- --紀錄下一個點的狀態(有資料or無資料)
												-- if data_r(dot_y)(dot_x) = '1' and data_g(dot_y)(dot_x) = '1' then
												-- 	orange_dot_next <= '1';
												-- elsif data_r(dot_y)(dot_x) = '0' and data_g(dot_y)(dot_x) = '1' then
												-- 	orange_dot_next <= '0';
												-- end if;
												-- ena_tim <= '1';
												-- if msec > 10 then
												-- 	ena_tim <= '0';
												mode_dot <= change;
												red_dot(dot_y)(dot_x) := '1';
												-- end if;
											when change =>
												-- --改變下一個點
												-- data_g(dot_y)(dot_x) <= '0';
												-- data_r(dot_y)(dot_x) <= '1';
												-- --恢復上一個點
												-- data_g(temp_y)(temp_x) <= '1';
												-- if orange_dot = '1' then
												-- 	data_r(temp_y)(temp_x) <= '1';
												-- elsif orange_dot = '0' then
												-- 	data_r(temp_y)(temp_x) <= '0';
												-- end if;
												-- --把下一個點的狀態記成現在的點的狀態
												-- orange_dot <= orange_dot_next;
												red_dot(temp_y)(temp_x) := '0';
												red_dot(dot_y)(dot_x) := '1';
												temp_x := dot_x;
												temp_y := dot_y;
												-- red_dot := (others => (others => '0'));

												-- if data_state(cnt_j)(cnt_i) = '1' or red_dot(cnt_j)(cnt_i) = '1' then
												-- 	data_r(cnt_j)(cnt_i) <= '1';
												-- else
												-- 	data_r(cnt_j)(cnt_i) <= '0';
												-- end if;

												-- if red_dot(cnt_j)(cnt_i) = '1' then
												-- 	data_g(cnt_j)(cnt_i) <= '0';
												-- else
												-- 	data_g(cnt_j)(cnt_i) <= '1';
												-- end if;

												-- if cnt_j < 7 then
												-- 	cnt_j := cnt_j + 1;
												-- else
												-- 	cnt_j := 0;
												-- 	if cnt_i < 7 then
												-- 		cnt_i := cnt_i + 1;
												-- 	else
												-- 		cnt_i := 0;
												-- 		cnt_j := 0;
												-- 		mode_dot <= move;
												-- 	end if;
												-- end if;

										end case;
									when del_esc =>
										-- if data_del(cnt_j)(cnt_i) = '1' then
										-- 	data_del(cnt_j)(cnt_i) := '0';
										-- 	for i in 1 to 8 loop
										-- 		if i = 8 then --最後一位補空格
										-- 			data_set(cnt_i)(i) := ' ';
										-- 		elsif i > cnt_j and i < 8 then--從後往前補資料
										-- 			data_set(cnt_i)(i) := data_set(cnt_i)(i + 1);

										-- 		end if;
										-- 	end loop;
										-- end if;

										-- if cnt_j > 0 then
										-- 	cnt_j := cnt_j - 1;
										-- else
										-- 	cnt_j := 7;
										-- 	if cnt_i > 0 then
										-- 		cnt_i := cnt_i - 1;
										-- 	else
										-- 		cnt_i := 7;
										-- 		cnt_j := 7;
										mode_3 <= ensure;
										mode_dot <= init;
										-- 	end if;
										-- end if;
									when del_data =>
										if data_set(dot_x)(dot_y + 1) /= ' ' then
											data_set(dot_x)(dot_y + 1) := '0';
											data_state(dot_y)(dot_x) := '0';

											data_del(dot_y)(dot_x) := '1';
											mode_dot <= move;
											mode_3 <= del_sel;
											-- del_cnt := del_cnt + 1;
											-- changed(dot_x) := '1';
										else
											mode_dot <= move;
											mode_3 <= del_sel;
										end if;

										-- if orange_dot = '1' then --現在(dot_y,dot_x)的點如果有資料	
										-- 	-- if cnt_i >= dot_y and cnt_i < 7 then--從後往前補資料
										-- 	-- 	data_set(dot_x)(cnt_i + 1) <= data_set(dot_x)(cnt_i + 2);

										-- 	-- elsif cnt_i = 7 then --最後一位補空格
										-- 	-- 	data_set(dot_x)(cnt_i + 1) <= ' ';
										-- 	-- end if;

										-- 	-- if cnt_i < 7 then
										-- 	-- 	cnt_i := cnt_i + 1;
										-- 	-- else
										-- 	-- 	cnt_i := 0;
										-- 	-- 	data_len(dot_x) <= data_len(dot_x) - 1;--長度-1
										-- 	-- 	orange_dot <= '0';--狀態改變=> 當再次移開時會變綠色
										-- 	-- 	mode_dot <= move;
										-- 	-- 	mode_3 <= del_sel;
										-- 	-- end if;
										-- 	-- for i in 1 to 8 loop
										-- 	-- 	if i = 8 then --最後一位補空格
										-- 	-- 		data_set(dot_x)(i) <= ' ';
										-- 	-- 	elsif i > dot_y and i < 8 then--從後往前補資料
										-- 	-- 		data_set(dot_x)(i) <= data_set(dot_x)(i + 1);
										-- 	-- 	end if;
										-- 	-- end loop;
										-- 	-- data_len(dot_x) <= data_len(dot_x) - 1;--長度-1
										-- 	-- orange_dot <= '0';--狀態改變=> 當再次移開時會變綠色
										-- 	-- mode_dot <= move;
										-- 	-- mode_3 <= del_sel;

										-- elsif orange_dot = '0' then--如果沒有資料 =>甚麼都不做回歸原地del_sel狀態
										-- 	mode_dot <= move;
										-- 	mode_3 <= del_sel;
										-- end if;
									when dot_change =>
									when IO_change =>
									when lcd_txt =>
								end case;
							when "11" =>
								case mode_4 is
									when init =>
										--I/O init
										seg_data <= "        ";
										data_r <= (others => (others => '0'));
										data_g <= (others => (others => '0'));
										l_clear <= '1';
										bg_color <= white;
										ena_tim <= '1';
										if msec > 20 then
											ena_tim <= '0';
											mode_4 <= sel_client;
										end if;
									when sel_client => --選擇client
										data_r <= (others => (others => '0'));
										data_g <= (others => (others => '0'));
										client_num <= to_integer (sw (3 to 5));
										seg_data <= "CLT" & character'val(client_num + 48) & ".00" & character'val(rx_len + 48);
										if data_len(client_num) > 0 then
											if pressed = '1' then
												case key is
													when 12 =>
														mode_4 <= txi_data;
														mode_tx <= idle;
													when others => null;
												end case;
											end if;
										end if;
										ena_tim <= '1';
										if msec >= 20 then
											ena_tim <= '0';
											l_clear <= '0';
											font_start <= '1';
											font_mode <= 0;
										end if;
										if txt_cnt = 0 then
											x <= 0;
											y <= 0;
											text_size <= 1;
											text_data(1 to 8) <= data_set(0);
											text_data(9 to 12) <= (others => character'val(32));
										end if;
										if txt_cnt = 1 then
											x <= 0;
											y <= 16;
											text_size <= 1;
											text_data(1 to 8) <= data_set(1);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 2 then
											x <= 0;
											y <= 32;
											text_size <= 1;
											text_data(1 to 8) <= data_set(2);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 3 then
											x <= 0;
											y <= 48;
											text_size <= 1;
											text_data(1 to 8) <= data_set(3);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 4 then
											x <= 0;
											y <= 64;
											text_size <= 1;
											text_data(1 to 8) <= data_set(4);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 5 then
											x <= 0;
											y <= 80;
											text_size <= 1;
											text_data(1 to 8) <= data_set(5);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 6 then
											x <= 0;
											y <= 96;
											text_size <= 1;
											text_data(1 to 8) <= data_set(6);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 7 then
											x <= 0;
											y <= 112;
											text_size <= 1;
											text_data(1 to 8) <= data_set(7);
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if font_busy = '1' then
											font_start <= '0';
											if txt_cnt <= 7 then
												txt_cnt <= txt_cnt + 1;
											else
												txt_cnt <= 0;
											end if;
											ena_tim <= '1';
										end if;
									when txi_data => --傳資料的狀態機
										case mode_tx is
											when idle =>
												if tx_busy = '0' then
													tx_data(1) <= data_set(client_num)(8);
													tx_data(2) <= data_set(client_num)(7);
													tx_data(3) <= data_set(client_num)(6);
													tx_data(4) <= data_set(client_num)(5);
													tx_data(5) <= data_set(client_num)(4);
													tx_data(6) <= data_set(client_num)(3);
													tx_data(7) <= data_set(client_num)(2);
													tx_data(8) <= data_set(client_num)(1);
													tx_len <= 8;
													tx_mode <= '0';
													tx_ena <= '1';
													mode_tx <= send;
												else
													tx_ena <= '0';
													mode_tx <= idle;
												end if;

											when send =>
												tx_ena <= '0';
												if tx_busy = '0' then
													mode_tx <= idle;
													mode_4 <= data_cls;
												end if;
										end case;

									when data_cls => --當資料傳完後，對應client的data_set清空，長度歸零
										data_set(client_num) := (others => character'val(32));
										data_len(client_num) <= 0;
										mode_4 <= waiting;
									when waiting => --顯示 TX OK
										seg_data <= "CLT" & character'val(client_num + 48) & ".00" & character'val(rx_len + 48);
										l_clear <= '0';
										bg_color <= white;
										font_mode <= 2;
										if msec_flag = '1' then
											ena_tim <= '1';
											msec_flag <= '0';
										end if;
										if msec > 20 then
											l_clear <= '0';
											font_mode <= 2;
											font_start <= '1';
										end if;
										if txt_cnt = 0 then
											x <= 0;
											y <= 53 * 0;
											text_data(1 to 4) <= txt_TX;
										end if;
										if txt_cnt = 1 then
											x <= 0;
											y <= 53 * 1;
											text_data(1 to 4) <= "    ";
											font_start <= '1';
										end if;
										if txt_cnt = 2 then
											x <= 0;
											y <= 53 * 2;
											text_data(1 to 4) <= txt_OK;
											font_start <= '1';
										end if;

										if font_busy = '1' then
											font_start <= '0';
											if txt_cnt <= 2 then
												txt_cnt <= txt_cnt + 1;
											else
												txt_cnt <= 0;
											end if;
											ena_tim <= '1';
										end if;
										if pressed = '1' then
											case key is
												when 15 =>
													mode_4 <= init;
													mode_tx <= idle;
												when others => null;
											end case;
										end if;
								end case;
						end case;
				end case;
			end if;
		end process;
	end block Main_Process;
end arch;
