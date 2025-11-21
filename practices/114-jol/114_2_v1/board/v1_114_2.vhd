library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity v1_114_2 is
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
end v1_114_2;

architecture arch of v1_114_2 is
	--state machine
	type state_t is (init, Main);
	signal mode_t : state_t := init;
	type state_m is (mode00, mode01, mode10, mode11);
	signal mode_m : state_m := mode00;
	type state_2 is (init, sel_client, IO_init, rxi_cls, rxi_data, rxi_check, rxi_save, lcd_change, IO_change, lcd_txt);
	signal mode_2 : state_2 := init;
	type state_3 is (init, ensure, del_sel, del_data, del_esc, dot_change, data_show, IO_change, lcd_txt);
	signal mode_3 : state_3 := init;
	type state_4 is (init, sel_client, txi_data, data_cls);
	signal mode_4 : state_4 := init;
	type state_tx is (idle, send);
	signal mode_tx : state_tx := idle;
	type state_dot is (init, move, change);
	signal mode_dot : state_dot := init;
	--pic signal
	signal l_addr : l_addr_t;
	signal n0_addr, n1_addr, n2_addr, n3_addr, n4_addr, n5_addr, n6_addr, n7_addr, n8_addr, n9_addr : l_addr_t;
	signal n0_data_i, n1_data_i, n2_data_i, n3_data_i, n4_data_i, n5_data_i, n6_data_i, n7_data_i, n8_data_i, n9_data_i : std_logic_vector(23 downto 0);
	signal n0_data, n1_data, n2_data, n3_data, n4_data, n5_data, n6_data, n7_data, n8_data, n9_data : l_px_t;
	signal R_addr, X_addr, O_addr, F_addr, T_addr, OF_addr : l_addr_t;
	signal R_data_i, X_data_i, O_data_i, F_data_i, T_data_i, OF_data_i : std_logic_vector(23 downto 0);
	signal R_data, X_data, O_data, F_data, T_data, OF_data : l_px_t;

	--type def
	type addr_array_t is array (integer range <>) of l_addr_t;
	type data_array_t is array (integer range <>) of l_px_t;
	type picture is array (integer range <>) of l_px_t;
	type l_coord_arr is array (0 to 11) of l_coord_t;
	type str_array is array (integer range <>) of string(1 to 8);
	--lcd
	signal x : integer range -127 to 127 := 0;
	signal y : integer range -159 to 159 := 0;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(32));
	signal text_size : integer range 1 to 12;
	signal text_color_array : l_px_arr_t(1 to 12) := (others => blue);
	signal bg_color : l_px_t;
	signal pic_data : l_px_t;
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
	signal msec : integer range 0 to 3000 := 0;

	--user signal
	signal client_num : integer range 0 to 7 := 0;
	signal data_buffer : string(1 to 8) := (others => character'val(32));
	signal data_set : str_array(0 to 7) := (others => (others => character'val(32)));
	signal data_len : i4_arr_t(0 to 7) := (others => 0);

	signal data_array : data_array_t(0 to 9) := (n0_data, n1_data, n2_data, n3_data, n4_data, n5_data, n6_data, n7_data, n8_data, n9_data);
	signal addr_array : addr_array_t(0 to 9) := (n0_addr, n1_addr, n2_addr, n3_addr, n4_addr, n5_addr, n6_addr, n7_addr, n8_addr, n9_addr);
	signal OF_num : integer range 0 to 7 := 0;
	signal have_rx : std_logic := '0';
	signal OF_flag : std_logic := '0';
	signal buz_flag : std_logic := '0';
	signal rgb_flag : std_logic := '0';
	signal data_num_o : integer range 0 to 9;
	signal map_coord : l_coord_arr := ((0, 0), (0, 32), (0, 64), (0, 96), (53, 0), (53, 32), (53, 64), (53, 96), (106, 0), (106, 32), (106, 64), (106, 96));
	signal dot_x : integer range 0 to 7;
	signal dot_y : integer range 0 to 7;
	signal temp_x : integer range 0 to 7;
	signal temp_y : integer range 0 to 7;
	signal txt_cnt : integer range 0 to 8;
begin
	-- Component -------------------------------------------------------------------------------------------------------------------------
	components : block begin
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
		lcd_mix_inst : entity work.lcd_mix(arch)--lcd => 控制圖片和文字的元件
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => x,                -- 文字x軸
				y                => y,                -- 文字y軸
				font_start       => font_start,       -- 文字更新(取正緣)
				font_busy        => font_busy_i,      -- 當畫面正在更新時，font_busy='1'
				text_size        => text_size,        -- 字體大小
				text_data        => text_data,        -- 文字資料
				addr             => l_addr,           -- 偵錯用 --可以用來貼圖
				text_color       => white,            -- 字體顏色(只能改單行)(若要使用需改gen_font.vhd(有註記))(若沒用到隨便填一顏色即可)
				bg_color         => bg_color,         -- 背景顏色
				text_color_array => text_color_array, -- 字體顏色(同一行依位元改變)(text_color_array:l_px_arr_t(1 to 12);)
				clear            => l_clear,          -- '1' 時清除
				lcd_sclk         => lcd_sclk,         -- 腳位
				lcd_mosi         => lcd_mosi,         -- 腳位
				lcd_ss_n         => lcd_ss_n,         -- 腳位
				lcd_dc           => lcd_dc,           -- 腳位
				lcd_bl           => lcd_bl,           -- 腳位
				lcd_rst_n        => lcd_rst_n,        -- 腳位
				con              => '0',              -- 選擇文字或圖片
				pic_data         => pic_data          -- 圖片資料
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
		mode_m <= mode00 when sw(6 to 7) = "00" else
			mode01 when sw(6 to 7) = "01" else
			mode10 when sw(6 to 7) = "10" else
			mode11 when sw(6 to 7) = "11"else mode00;
	end block Input_def;
	--  Picture  -------------------------------------------------------------------------------------------------------------------------
	Pictures : block begin--圖片的元件和設定
		aphR : entity work.R(syn)
			port map(
				address => std_logic_vector(to_unsigned(R_addr, 10)),
				clock   => clk,
				q       => R_data_i
			);
		R_data <= unsigned(R_data_i);
		aphX : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X_addr, 10)),
				clock   => clk,
				q       => X_data_i
			);
		X_data <= unsigned(X_data_i);
		aphO : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O_addr, 10)),
				clock   => clk,
				q       => O_data_i
			);
		O_data <= unsigned(O_data_i);
		aphF : entity work.F(syn)
			port map(
				address => std_logic_vector(to_unsigned(F_addr, 10)),
				clock   => clk,
				q       => F_data_i
			);
		F_data <= unsigned(F_data_i);
		OF1 : entity work.n1(syn)
			port map(
				address => std_logic_vector(to_unsigned(OF_addr, 10)),
				clock   => clk,
				q       => OF_data_i
			);
		OF_data <= unsigned(OF_data_i);
		Num0 : entity work.n0(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(0), 10)),
				clock   => clk,
				q       => n0_data_i
			);
		data_array(0) <= unsigned(n0_data_i);
		Num1 : entity work.n1(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(1), 10)),
				clock   => clk,
				q       => n1_data_i
			);
		data_array(1) <= unsigned(n1_data_i);
		Num2 : entity work.n2(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(2), 10)),
				clock   => clk,
				q       => n2_data_i
			);
		data_array(2) <= unsigned(n2_data_i);
		Num3 : entity work.n3(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(3), 10)),
				clock   => clk,
				q       => n3_data_i
			);
		data_array(3) <= unsigned(n3_data_i);
		Num4 : entity work.n4(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(4), 10)),
				clock   => clk,
				q       => n4_data_i
			);
		data_array(4) <= unsigned(n4_data_i);
		Num5 : entity work.n5(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(5), 10)),
				clock   => clk,
				q       => n5_data_i
			);
		data_array(5) <= unsigned(n5_data_i);
		Num6 : entity work.n6(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(6), 10)),
				clock   => clk,
				q       => n6_data_i
			);
		data_array(6) <= unsigned(n6_data_i);
		Num7 : entity work.n7(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(7), 10)),
				clock   => clk,
				q       => n7_data_i
			);
		data_array(7) <= unsigned(n7_data_i);
		Num8 : entity work.n8(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(8), 10)),
				clock   => clk,
				q       => n8_data_i
			);
		data_array(8) <= unsigned(n8_data_i);
		Num9 : entity work.n9(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(9), 10)),
				clock   => clk,
				q       => n9_data_i
			);
		data_array(9) <= unsigned(n9_data_i);
	end block Pictures;
	-- dbg & test ------------------------------------------------------------------------------------------------------------------------
	dbg_test : block

	begin
		dbg_a(0 to 3) <= not("1000") when mode_m = mode00 else
		not("0100") when mode_m = mode01 else
		not("0010") when mode_m = mode10 else
		not("0001") when mode_m = mode11 else not("0000");
		dbg_a(4 to 7) <= not("1000") when mode_3 = init else
		not("0100") when mode_3 = ensure else
		not("0010") when mode_3 = data_show else
		not("0001") when mode_3 = del_sel else not("0000");
		dbg_b(0 to 3) <= not(to_unsigned(data_len(client_num), 4));
		dbg_b(4 to 7) <= not(to_unsigned(data_len(dot_x), 4));
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
			variable OF_num : integer range 0 to 7 := 0;
			variable data_num : integer range 0 to 9 := 0;
			variable pic : picture(0 to 11);
		begin
			if rst_n = '0' then
				led_r <= '0';
				led_g <= '0';
				led_y <= '0';
				rgb <= (others => '0');
				OF_flag <= '0';
				rgb_flag <= '0';
				buz_flag <= '0';
				ena_tim <= '0';
				l_clear <= '1';
				bg_color <= white;
				seg_data <= "        ";
				data_g <= (others => (others => '0'));
				data_r <= (others => (others => '0'));
				data_buffer <= (others => character'val(32));
				data_set <= (others => (others => character'val(32)));
				data_len <= (others => 0);

				mode_t <= init;
				mode_2 <= init;
				mode_3 <= init;
				mode_dot <= move;
				-- mode_4 <= init;
			elsif rising_edge(clk) then
				case mode_t is
					when init =>
						ena_tim <= '1';
						led_r <= '0';
						led_g <= '0';
						led_y <= '0';
						rgb <= (others => '1' and rgb_flag);
						if (msec/500)mod 2 = 0 then
							rgb_flag <= '1';
						else
							rgb_flag <= '0';
						end if;
						if msec > 1000 then
							seg_data <= "        ";
						else
							seg_data <= ".READY. ";
						end if;
						if msec > 3000 then
							ena_tim <= '0';
							mode_t <= Main;
							mode_2 <= init;
							-- mode_3 <= init;
							-- mode_4 <= init;
						end if;
						l_clear <= '1';
						bg_color <= white;
						data_g <= (others => (others => '0'));
						data_r <= (others => (others => '0'));

					when Main =>
						case mode_m is
							when mode00 =>
								led_r <= '0';
								led_g <= '0';
								led_y <= '0';
								rgb <= (others => '0');
								seg_data <= "CLTX.000";
								l_clear <= '1';
								bg_color <= white;
								data_g <= (others => (others => '0'));
								data_r <= (others => (others => '0'));
								ena_tim <= '0';
							when mode01 =>
								case mode_2 is
									when init =>
										led_r <= '0';
										led_g <= '0';
										led_y <= '0';
										l_clear <= '1';
										bg_color <= white;
										rgb <= (others => '0');
										seg_data <= "        ";
										data_len <= (others => 0);
										data_set <= (others => (others => character'val(32)));
										if pressed = '1' then
											case key is
												when 15 =>
													buz_flag <= '1';
													ena_tim <= '1';
												when others => null;
											end case;
										end if;
										if buz_flag = '1' then
											buz <= '1';
											if msec > 500 then
												ena_tim <= '0';
												buz_flag <= '0';
												buz <= '0';
												mode_2 <= sel_client;
											end if;
										end if;
									when sel_client => --選擇client
										--顯示選擇了client
										seg_data <= "CLT" & character'val(client_num + 49) & ".00" & character'val(data_len(client_num) + 48);
										--client 編號
										client_num <= to_integer (sw (3 to 5));
										if pressed = '1' then
											case key is
												when 14 => --離開鍵
													mode_2 <= init;
												when 15 => --確認鍵
													mode_2 <= IO_init;
												when others => null;
											end case;
										end if;
										l_clear <= '1';-- 清除lcd
										bg_color <= white;
									when IO_init =>
										seg_data <= "CLT" & character'val(client_num + 49) & ".00" & character'val(data_len(client_num) + 48);
										data_g <= (others => (others => '1'));
										for i in 0 to 7 loop
											for j in 0 to 7 loop
												if j < data_len(i) then
													data_r(j)(i) <= '1';
												else
													data_r(j)(i) <= '0';
												end if;
											end loop;
										end loop;
										l_clear <= '1';
										bg_color <= pic(1);
										pic(0) := to_data(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										R_addr <= to_addr(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										pic(1) := to_data(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										ena_tim <= '1';
										if msec > 50 then
											ena_tim <= '1';
											mode_2 <= rxi_cls;
										end if;
									when rxi_cls => --接收rx_done => 清除data_buffer
										if rx_done = '1' then
											data_buffer <= (others => character'val(32));
											mode_2 <= rxi_data;--整理rx_data
										end if;
										if pressed = '1' then
											case key is
												when 14 => --離開鍵
													mode_2 <= sel_client;
												when others => null;
											end case;
										end if;

										--顯示RX
										l_clear <= '1';
										bg_color <= pic(1);
										pic(0) := to_data(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										R_addr <= to_addr(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										pic(1) := to_data(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
									when rxi_data => --整理rx_data
										data_buffer(1 to rx_len) <= rx_data(1 to rx_len); --暫存資料
										if rx_len <= 4 and rx_len >= 1 then
											if data_len(client_num) + rx_len <= 8 then --沒溢位
												OF_flag <= '0';--設旗標
												OF_num := 0;--設溢位位數
												data_len(client_num) <= data_len(client_num) + rx_len;--設定現在client的資料長度
												mode_2 <= rxi_save;-- 儲存資料
											elsif data_len(client_num) + rx_len > 8 then--有溢位
												OF_flag <= '1';--設旗標
												OF_num := data_len(client_num) + rx_len - 8;--設溢位位數
												data_len(client_num) <= 8;--設定現在client的資料長度
												mode_2 <= rxi_save; -- 儲存資料
											end if;
										else
											mode_2 <= rxi_cls;
										end if;
										--顯示RX
										l_clear <= '1';
										bg_color <= pic(1);
										pic(0) := to_data(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										R_addr <= to_addr(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										pic(1) := to_data(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
									when rxi_check =>
									when rxi_save => -- 儲存資料到data_set中
										if OF_flag = '1' then
											if rx_len <= 4 and rx_len >= 1 then
												for i in 1 to 4 loop
													if i <= rx_len - OF_num then
														data_set(client_num)(data_len(client_num) - (rx_len - OF_num) + i) <= data_buffer(i);
													end if;
												end loop;
											end if;
										elsif OF_flag = '0' then
											if rx_len <= 4 and rx_len >= 1 then
												for i in 1 to 4 loop
													if i <= rx_len then
														data_set(client_num)(data_len(client_num) - rx_len + i) <= data_buffer(i);
													end if;
												end loop;
											end if;
										end if;
										ena_tim <= '1';
										if msec > 50 then
											ena_tim <= '0';
											mode_2 <= IO_change;
										end if;

										l_clear <= '1';
										bg_color <= pic(1);
										pic(0) := to_data(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										R_addr <= to_addr(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										pic(1) := to_data(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
									when IO_change =>
										seg_data <= "CLT" & character'val(client_num + 49) & ".00" & character'val(data_len(client_num) + 48);
										data_g <= (others => (others => '1'));
										for i in 0 to 7 loop
											for j in 0 to 7 loop
												if j < data_len(i) then
													data_r(j)(i) <= '1';
												else
													data_r(j)(i) <= '0';
												end if;
											end loop;
										end loop;
										ena_tim <= '1';
										if msec > 50 then
											ena_tim <= '0';
											mode_2 <= lcd_change;
										end if;
									when lcd_change =>
										l_clear <= '1';
										bg_color <= pic(8);

										pic(0) := to_data(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										R_addr <= to_addr(l_paste(l_addr, white, R_data, map_coord(2), 32, 53));
										pic(1) := to_data(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, map_coord(3), 32, 53));
										pic(2) := to_data(l_paste(l_addr, pic(1), O_data, map_coord(9), 32, 53));
										O_addr <= to_addr(l_paste(l_addr, pic(1), O_data, map_coord(9), 32, 53));
										pic(3) := to_data(l_paste(l_addr, pic(2), F_data, map_coord(10), 32, 53));
										F_addr <= to_addr(l_paste(l_addr, pic(2), F_data, map_coord(10), 32, 53));

										if OF_flag = '1' then
											pic(4) := to_data(l_paste(l_addr, pic(3), OF_data, map_coord(11), 32, 53));
											OF_addr <= to_addr(l_paste(l_addr, pic(3), OF_data, map_coord(11), 32, 53));
										elsif OF_flag = '0' then
											pic(4) := pic(3);
										end if;

										for i in 1 to 4 loop
											if OF_flag <= '1' then

												data_num := character'pos(data_set(client_num)(data_len(client_num) - rx_len + OF_num + i));
												if i <= rx_len - OF_num then
													pic(4 + i) := to_data(l_paste(l_addr, pic(3 + i), data_array(data_num - 48), map_coord(3 + i), 32, 53));
													addr_array(data_num) <= to_addr(l_paste(l_addr, pic(3 + i), data_array(data_num), map_coord(3 + i), 32, 53));
												else
													pic(4 + i) := pic(3 + i);
												end if;
											elsif OF_flag <= '0' then
												data_num := character'pos(data_set(client_num)(data_len(client_num - 48) - rx_len + i));
												if i <= rx_len then
													pic(4 + i) := to_data(l_paste(l_addr, pic(3 + i), data_array(data_num), map_coord(3 + i), 32, 53));
													addr_array(data_num) <= to_addr(l_paste(l_addr, pic(3 + i), data_array(data_num), map_coord(3 + i), 32, 53));
												else
													pic(4 + i) := pic(3 + i);
												end if;
											end if;
										end loop;
										ena_tim <= '1';
										if msec > 2000 then
											ena_tim <= '0';
											l_clear <= '1';
											bg_color <= white;
											mode_2 <= lcd_txt;
										end if;
									when lcd_txt =>

										if msec >= 20 then
											ena_tim <= '0';
											l_clear <= '0';
											font_start <= '1';
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
										if txt_cnt = 8 then
											x <= 0;
											y <= 128;
											text_size <= 1;
											text_data(1 to 8) <= data_buffer;
											text_data(9 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if font_busy = '1' then
											font_start <= '0';
											if txt_cnt <= 8 then
												txt_cnt <= txt_cnt + 1;
											else
												txt_cnt <= 0;
											end if;
											ena_tim <= '1';
										end if;
										if pressed = '1' then
											case key is
												when 15 =>
													mode_2 <= IO_init;
												when others => null;
											end case;
										end if;
								end case;
							when mode10 =>
								case mode_3 is
									when init =>
										led_r <= '0';
										led_g <= '0';
										led_y <= '0';
										l_clear <= '1';
										bg_color <= white;
										rgb <= (others => '0');
										seg_data <= "        ";
										if pressed = '1' then
											case key is
												when 15 =>
													mode_3 <= ensure;
												when others => null;
											end case;
										end if;
									when ensure =>
										if pressed = '1' then
											case key is
												when 14 => mode_3 <= init;
												when 15 => mode_3 <= data_show;
													dot_x <= 7;
													dot_y <= 7;
													temp_x <= 7;
													temp_y <= 7;
													ena_tim <= '1';
												when others => null;
											end case;
										end if;
									when data_show =>
										data_g <= (others => (others => '1'));
										for i in 0 to 7 loop
											for j in 0 to 7 loop
												if j < data_len(i) then
													data_r(j)(i) <= '1';
												else
													data_r(j)(i) <= '0';
												end if;
											end loop;
										end loop;
										ena_tim <= '1';
										if msec > 50 then
											ena_tim <= '0';
											mode_3 <= del_sel;
											mode_dot <= init;
										end if;
									when del_sel =>
										case mode_dot is
											when init =>
												dot_x <= 7;
												dot_y <= 7;
												temp_x <= 7;
												temp_y <= 7;
												data_r(dot_y)(dot_x) <= '1';
												data_g(dot_y)(dot_x) <= '0';
												ena_tim <= '1';
												if msec > 50 then
													ena_tim <= '0';
													mode_dot <= move;
												end if;
											when move =>
												if pressed = '1' then
													case key is
														when 5 => -- 上 
															if dot_y < 7 then
																dot_y <= dot_y + 1;
															end if;
														when 8 => -- 左
															if dot_x > 0 then
																dot_x <= dot_x - 1;
															end if;
														when 9 => -- 下
															if dot_y > 0 then
																dot_y <= dot_y - 1;
															end if;
														when 10 => -- 右
															if dot_x < 7 then
																dot_x <= dot_x + 1;
															end if;
														when 14 => mode_3 <= del_esc;
														when 15 =>
															mode_3 <= del_data;
														when others => null;
													end case;
													mode_dot <= change;
													data_g <= (others => (others => '1'));
													for i in 0 to 7 loop
														for j in 0 to 7 loop
															if j < data_len(i) then
																data_r(j)(i) <= '1';
															else
																data_r(j)(i) <= '0';
															end if;
														end loop;
													end loop;
												end if;
											when change =>
												data_g(dot_y)(dot_x) <= '0';
												data_r(dot_y)(dot_x) <= '1';

												mode_dot <= move;
										end case;
										-- l_clear <= '0';
										-- if msec >= 20 then
										-- 	ena_tim <= '0';
										-- 	l_clear <= '0';
										-- 	font_start <= '1';
										-- end if;
										-- if txt_cnt = 0 then
										-- 	x <= 0;
										-- 	y <= 0;
										-- 	text_size <= 1;
										-- 	text_data(1 to 8) <= data_set(1);
										-- 	text_data(9 to 12) <= (others => character'val(32));
										-- end if;
										-- if font_busy = '1' then
										-- 	font_start <= '0';
										-- 	if txt_cnt <= 0 then
										-- 		txt_cnt <= txt_cnt + 1;
										-- 	else
										-- 		txt_cnt <= 0;
										-- 	end if;
										-- 	ena_tim <= '1';
										-- end if;
									when del_esc =>
										data_g(dot_y)(dot_x) <= '1';
										data_r(dot_y)(dot_x) <= '0';
										mode_3 <= ensure;
									when del_data =>
										for i in 1 to 7 loop
											if i >= dot_y then
												data_set(dot_x)(i) <= data_set(dot_x)(i + 1);
											end if;
										end loop;
										data_len(dot_x) <= data_len(dot_x) - 1;
										mode_3 <= data_show;
									when dot_change =>
									when IO_change =>
									when lcd_txt =>
								end case;
							when mode11 =>
								case mode_4 is
									when init =>
										seg_data <= "        ";
										data_r <= (others => (others => '0'));
										data_g <= (others => (others => '0'));
										ena_tim <= '1';
										if msec > 50 then
											ena_tim <= '0';
											mode_4 <= sel_client;
										end if;
									when sel_client =>
										client_num <= to_integer (sw (3 to 5));
										seg_data <= "CLT" & character'val(client_num + 49) & ".00" & character'val(data_len(client_num) + 48);
										if pressed = '1' then
											case key is
												when 15 =>
													mode_4 <= txi_data;
													mode_tx <= idle;
												when others => null;
											end case;
										end if;
										if msec >= 20 then
											ena_tim <= '0';
											l_clear <= '0';
											font_start <= '1';
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
									when txi_data =>
										case mode_tx is
											when idle =>
												if tx_busy = '0' then
													tx_data(1 to 8) <= data_set(client_num)(1 to 8);
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

									when data_cls =>
										data_set(client_num) <= (others => character'val(32));
										data_len(client_num) <= 0;
										mode_4 <= sel_client;
								end case;
						end case;
				end case;

			end if;
		end process;
	end block Main_Process;
end arch;
