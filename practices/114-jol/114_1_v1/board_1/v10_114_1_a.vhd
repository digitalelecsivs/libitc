library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity v10_114_1_a is
	port (

		clk   : in std_logic; -- sys
		rst_n : in std_logic;

		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic; -- lcd
		seg_led, seg_com                                        : out u8r_t;     -- seg
		sw                                                      : in u8r_t;      -- sw
		tts_scl, tts_sda                                        : inout std_logic;
		tts_mo                                                  : in unsigned(2 downto 0);
		tts_rst_n                                               : out std_logic;
		uart_rx                                                 : in std_logic;  -- uart    receive pin
		uart_tx                                                 : out std_logic; -- 		transmit pin
		dbg_b                                                   : out u8r_t;     -- dbg
		dbg_a                                                   : out u4r_t
	);
end v10_114_1_a;

architecture arch of v10_114_1_a is
	--state machine
	type state_t is (mode00, mode01, mode10, mode11, enable_mode);
	type state_1 is (init, init_mode, txt_mode, set_mode, ensure);
	type state_2 is (init, sel_mode, set_mode);
	type state_3 is (init, init_mode, set_mode, UP_mode, DN_mode);
	type state_4 is (init, init_mode, set_mode, UP_mode, DN_mode, tts_mode);
	type state_tts is (idle, play, stop);
	signal mode_t : state_t := enable_mode;
	signal mode_1 : state_1 := init;
	signal mode_2 : state_2 := init;
	signal mode_3 : state_3 := init;
	signal mode_4 : state_4 := init;
	signal mode_tts : state_tts := idle;

	--lcd
	signal x : integer range -127 to 127 := 0; --1
	signal y : integer range -159 to 159 := 0; --2
	signal font_start : std_logic := '0'; --3
	signal font_busy_i : std_logic := '0'; --4
	signal text_size : integer range 1 to 12; --5
	signal text_data : string(1 to 12) := (others => character'val(32)); --6
	signal font_mode : integer range 0 to 2; --7
	signal l_addr : l_addr_t; --8
	signal bg_color : l_px_t; --9
	signal text_color_array : l_px_arr_t(1 to 12) := (others => blue); --10
	signal l_clear : std_logic := '1'; --11

	signal font_busy : std_logic := '0';
	signal txt_cnt : integer range 0 to 3; --lcd輸出的文本行數
	--tts
	constant max_len : integer := 34;
	signal tts_ena : std_logic := '0';
	signal tts_busy : std_logic;
	signal tts_txt : u8_arr_t(0 to max_len - 1) := (others => x"00");
	signal txt_len : integer range 0 to max_len := 0;

	--timer
	signal ena_tim : std_logic := '0';
	signal msec : integer range 0 to 5000 := 0;

	--key board
	signal pressed_sig_i : std_logic := '0';
	signal pressed_sig : std_logic := '0';
	signal pressed_i : std_logic := '0';
	signal pressed : std_logic := '0';
	signal pressed_f : std_logic := '0';
	signal key : integer range 0 to 15;

	--uart
	signal rx_start, rx_done, tx_mode : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_ena_e : std_logic;
	signal tx_data, rx_data : string(1 to 12);
	signal tx_len, rx_len : integer range 1 to 12;

	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--type def
	type picture is array (0 to 10) of l_px_t;
	type l_coord_arr is array (0 to 8) of l_coord_t;
	type cnt_arr is array (0 to 2) of integer range 0 to 999;

	--flag
	signal fin_pro_flag : std_logic := '0'; --程序完成語音旗標
	signal tts_said : std_logic := '0'; --在mode_4用sw檢查的mode選擇，有沒有講過"modeXX" "modeYY" "modeZZ"：0:沒講過 1:有講過
	signal tts_mode_flag : std_logic := '0'; --tts要講的話的旗標
	signal tts_pressed_flag : std_logic := '0'; --tts要講的話的旗標
	signal init_fin_flag : std_logic := '0'; --mode3、mode的lcd初始化旗標

	-- signal trig_flag : std_logic := '0'; --當要做讓計數器直接計到最大值 

	--user signal
	signal sw_d : std_logic_vector(0 to 7); --sw(0 to 7)=> 0 to 7 --輸入的sw做debounced

	signal m_sel : integer range 0 to 3; --模式x,y,z的選擇線
	signal trigger_i : std_logic := '0'; --計數器的trigger(未微分)
	signal trigger : std_logic := '0'; --計數器的trigger(微分)
	signal key_state : unsigned(1 to 9) := (others => '0');--mode00中數字數是否顯示的旗標

	--計數旗標 & 暫存器 
	-- signal cnt_tim : std_logic := '0'; --CNT:0 TIM: 1 
	-- signal up_dn : std_logic := '0'; --UP:0 DN: 1 
	-- signal st_cd : std_logic := '0'; --ST:0 CD: 1 
	-- signal tim_min : integer range 0 to 99;
	-- signal tim_sec : integer range 0 to 99;
	-- signal cnt_max : integer range 0 to 999;
	-- signal step : integer range 0 to 9;

	--pic signal
	type data_arr is array(integer range <>) of l_px_t;
	type addr_arr is array(integer range <>) of l_addr_t;
	signal n1_addr, n2_addr, n3_addr, n4_addr, n5_addr, n6_addr, n7_addr, n8_addr, n9_addr : l_addr_t;
	signal n1_data_i, n2_data_i, n3_data_i, n4_data_i, n5_data_i, n6_data_i, n7_data_i, n8_data_i, n9_data_i : std_logic_vector(23 downto 0);
	signal n1_data, n2_data, n3_data, n4_data, n5_data, n6_data, n7_data, n8_data, n9_data : l_px_t;
	signal map_coord : l_coord_arr := ((0, 0), (0, 43), (0, 85), (53, 0), (53, 43), (53, 85), (106, 0), (106, 43), (106, 85));
	signal data_array : data_arr(0 to 8) := (n1_data, n2_data, n3_data, n4_data, n5_data, n6_data, n7_data, n8_data, n9_data);
	signal addr_array : addr_arr(0 to 8) := (n1_addr, n2_addr, n3_addr, n4_addr, n5_addr, n6_addr, n7_addr, n8_addr, n9_addr);

	--系統連線成功
	constant link_success : u8_arr_t(0 to 11) := (x"A8", x"74", x"B2", x"CE", x"B3", x"73", x"BD", x"75", x"A6", x"A8", x"A5", x"5C");
	--選擇XX
	constant sel_XX : u8_arr_t(0 to 5) := (x"BF", x"EF", x"BE", x"DC", x"58", x"58");
	--選擇YY
	constant sel_YY : u8_arr_t(0 to 5) := (x"BF", x"EF", x"BE", x"DC", x"59", x"59");
	--選擇ZZ
	constant sel_ZZ : u8_arr_t(0 to 5) := (x"BF", x"EF", x"BE", x"DC", x"5A", x"5A");
	--計數C為
	constant cnt_cis : u8_arr_t(0 to 6) := (x"AD", x"70", x"BC", x"C6", x"43", x"AC", x"B0");
	--計數L為
	constant cnt_lis : u8_arr_t(0 to 6) := (x"AD", x"70", x"BC", x"C6", x"4C", x"AC", x"B0");
	--程序完成
	constant pro_finish : u8_arr_t(0 to 7) := (x"B5", x"7B", x"A7", x"C7", x"A7", x"B9", x"A6", x"A8");
begin
	-- Component -------------------------------------------------------------------------------------------------------------------------
	components : block begin
		debounce0 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(0),  -- input signal to be debounced
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
				sig_in  => sw(1),  -- input signal to be debounced
				sig_out => sw_d(1) -- debounced signal
			);
		debounce2 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(2),  -- input signal to be debounced
				sig_out => sw_d(2) -- debounced signal
			);
		debounce3 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(3),  -- input signal to be debounced
				sig_out => sw_d(3) -- debounced signal
			);
		debounce4 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(4),  -- input signal to be debounced
				sig_out => sw_d(4) -- debounced signal
			);
		debounce5 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(5),  -- input signal to be debounced
				sig_out => sw_d(5) -- debounced signal
			);
		debounce6 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(6),  -- input signal to be debounced
				sig_out => sw_d(6) -- debounced signal
			);
		debounce7 : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				-- system
				clk   => clk,
				rst_n => rst_n,
				-- user logic
				sig_in  => sw(7),  -- input signal to be debounced
				sig_out => sw_d(7) -- debounced signal
			);
		tts_rst_n <= rst_n;
		tts_inst : entity work.tts(arch)
			generic map(
				txt_len_max => max_len
			)
			port map(
				clk       => clk,
				rst_n     => rst_n,
				tts_scl   => tts_scl,
				tts_sda   => tts_sda,
				tts_mo    => tts_mo,
				tts_rst_n => tts_rst_n,
				ena       => tts_ena,
				busy      => tts_busy,
				txt       => tts_txt,
				txt_len   => txt_len
			);
		clk_trigger : entity work.clk(arch)--mode10和mode11計數器trigger的ck產生器
			generic map(
				freq => 10
			)
			port map(
				clk_in  => clk,
				rst_n   => rst_n,
				clk_out => trigger_i
			);
		edge_trigger : entity work.edge(arch)--mode10和mode11計數器trigger微分
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => trigger_i,
				rising  => trigger,
				falling => open
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
		edge_key_sig : entity work.edge(arch)--整理Board_2的keyboard訊號
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_sig_i,
				rising  => pressed_sig,
				falling => open
			);
		edge_key : entity work.edge(arch)--微分出只有一個ck的keyboard trigger
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => pressed_f
			);
		lcd_mix_inst : entity work.lcd_mix(arch)
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => x,
				y                => y,
				font_start       => font_start,
				font_busy        => font_busy_i,
				text_size        => text_size,
				text_data        => text_data,
				font_mode        => 0,
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
	--  Picture  -------------------------------------------------------------------------------------------------------------------------
	Pictures : block begin--圖片的元件和設定
		Num1 : entity work.n1(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(0), 12)),
				clock   => clk,
				q       => n1_data_i
			);
		data_array(0) <= unsigned(n1_data_i);
		Num2 : entity work.n2(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(1), 12)),
				clock   => clk,
				q       => n2_data_i
			);
		data_array(1) <= unsigned(n2_data_i);
		Num3 : entity work.n3(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(2), 12)),
				clock   => clk,
				q       => n3_data_i
			);
		data_array(2) <= unsigned(n3_data_i);
		Num4 : entity work.n4(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(3), 12)),
				clock   => clk,
				q       => n4_data_i
			);
		data_array(3) <= unsigned(n4_data_i);
		Num5 : entity work.n5(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(4), 12)),
				clock   => clk,
				q       => n5_data_i
			);
		data_array(4) <= unsigned(n5_data_i);
		Num6 : entity work.n6(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(5), 12)),
				clock   => clk,
				q       => n6_data_i
			);
		data_array(5) <= unsigned(n6_data_i);
		Num7 : entity work.n7(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(6), 12)),
				clock   => clk,
				q       => n7_data_i
			);
		data_array(6) <= unsigned(n7_data_i);
		Num8 : entity work.n8(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(7), 12)),
				clock   => clk,
				q       => n8_data_i
			);
		data_array(7) <= unsigned(n8_data_i);
		Num9 : entity work.n9(syn)
			port map(
				address => std_logic_vector(to_unsigned(addr_array(8), 12)),
				clock   => clk,
				q       => n9_data_i
			);
		data_array(8) <= unsigned(n9_data_i);
	end block Pictures;
	-- Key wifi --------------------------------------------------------------------------------------------------------------------------
	key_block : block begin--wifi keyboard的訊號整合
		process (clk, rst_n)
		begin
			if rst_n = '0' then
				dbg_a <= not "0000";
				tx_ena <= '0';
			elsif rising_edge(clk) then
				tx_ena <= '0';
				if mode_t /= enable_mode then
					if rx_done = '1' then
						pressed_sig_i <= '1';
						dbg_a <= not (to_unsigned (key, 4));
						case rx_data(1 to 2) is
							when "00" => key <= 0;
							when "01" => key <= 1;
							when "02" => key <= 2;
							when "03" => key <= 3;
							when "04" => key <= 4;
							when "05" => key <= 5;
							when "06" => key <= 6;
							when "07" => key <= 7;
							when "08" => key <= 8;
							when "09" => key <= 9;
							when "10" => key <= 10;
							when "11" => key <= 11;
							when "12" => key <= 12;
							when "13" => key <= 13;
							when "14" => key <= 14;
							when "15" => key <= 15;
							when others => key <= 0;
						end case;
					else
						pressed_sig_i <= '0';
					end if;
					if pressed_sig = '1' then
						pressed_i <= not pressed_i;
					end if;
				else pressed_i <= '0';
					key <= 0;
				end if;
			end if;
		end process;

	end block key_block;
	-- INPUT def -------------------------------------------------------------------------------------------------------------------------
	Input_def : block begin--指撥開關的輸入設定
		mode_t <= enable_mode when sw_d(5) = '0' else
			mode00 when sw_d(6 to 7) = "00" else
			mode01 when sw_d(6 to 7) = "01" else
			mode10 when sw_d(6 to 7) = "10" else
			mode11 when sw_d(6 to 7) = "11";
	end block Input_def;
	-- dbg & test ------------------------------------------------------------------------------------------------------------------------
	-- dbg_test : block
	-- 	signal pressed_check : std_logic := '0';
	-- 	signal rx_done_sig : std_logic;
	-- begin
	-- 	process (clk, rst_n) begin
	-- 		if rst_n = '0' then
	-- 		elsif rising_edge(clk) then
	-- 			if pressed = '1' then
	-- 				pressed_check <= not pressed_check;
	-- 			end if;
	-- 			case mode_4 is
	-- 				when init_mode => dbg_b(0 to 3) <= not("100" & pressed_i);
	-- 				when set_mode => dbg_b(0 to 3) <= not("010" & pressed_i);
	-- 				when tts_mode => dbg_b(0 to 3) <= not("001" & pressed_i);
	-- 				when init => dbg_b(0 to 3) <= not("111" & pressed_i);

	-- 			end case;
	-- 			case mode_tts is
	-- 				when idle => dbg_b(4 to 7) <= not("100" & pressed_check);
	-- 				when play => dbg_b(4 to 7) <= not("010" & pressed_check);
	-- 				when stop => dbg_b(4 to 7) <= not("001" & pressed_check);
	-- 			end case;
	-- 		end if;
	-- 	end process;
	-- end block dbg_test;
	-- Main Process ----------------------------------------------------------------------------------------------------------------------
	Main_Process : block begin
		process (clk, rst_n)
			variable cnt_c : cnt_arr;
			variable cnt_l : cnt_arr;
			variable pic : picture;
		begin
			-- type state_1 is (init, init_mode, txt_mode, set_mode, ensure);
			-- type state_2 is (init, sel_mode, set_mode);
			-- type state_3 is (init, init_mode, set_mode, UP_mode, DN_mode);
			-- type state_4 is (init, init_mode, set_mode, UP_mode, DN_mode, tts_mode);
			-- type state_tts is (idle, play, stop);
			if rst_n = '0' then

			elsif rising_edge(clk) then
				case mode_t is
					when mode00 =>
						case mode_1 is
							when init =>
								key_state <= (others => '0');

								l_clear <= '0';
								font_start <= '0';
								text_data <= (others => character'val(32));
								txt_cnt <= 0;
								mode_1 <= init_mode;
								ena_tim <= '1';
							when init_mode =>
								l_clear <= '1';
								bg_color <= pic(8);
								if pressed = '1' then
									if key >= 1 and key <= 9 then
										key_state(key) <= not key_state(key);
									end if;
									case key is
										when 11 => mode_1 <= init;
										when 12 =>
											if key_state = "000000000" then

												mode_1 <= txt_mode;
											end if;
										when others => null;
									end case;
								end if;
								for i in 0 to 8 loop
									if i = 0 then
										if key_state(i + 1) = '0' then
											pic(i) := white;
										elsif key_state(i + 1) = '1' then
											pic(i) := to_data(l_paste(l_addr, white, data_array(i), map_coord(i), 42, 53));
											addr_array(i) <= to_addr(l_paste(l_addr, white, data_array(i), map_coord(i), 42, 53));
										end if;
									elsif i > 0 then
										if key_state(i + 1) = '0' then
											pic(i) := pic(i - 1);
										elsif key_state(i + 1) = '1' then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), data_array(i), map_coord(i), 42, 53));
											addr_array(i) <= to_addr(l_paste(l_addr, pic(i - 1), data_array(i), map_coord(i), 42, 53));
										end if;
									end if;
								end loop;
							when txt_mode =>
								if pressed = '1' then
									case key is
										when 11 => mode_1 <= init;
										when 14 => text_color_array <= (others => red);
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
									text_data(1 to 7) <= "CPLD ID";
									text_data(8 to 12) <= (others => character'val(32));
								end if;
								if txt_cnt = 1 then
									x <= 0;
									y <= 40;
									text_size <= 1;
									text_data(1 to 4) <= "MODE";
									text_data(5 to 12) <= (others => character'val(32));
									font_start <= '1';
								end if;
								if txt_cnt = 2 then
									x <= 0;
									y <= 80;
									text_size <= 1;
									text_data(1 to 7) <= "trieso:";
									text_data(8 to 12) <= (others => character'val(32));
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
							when set_mode =>
							when ensure =>
						end case;
					when mode01 =>
						case mode_2 is
							when init =>
								ena_tim <= '1';
								seg_data <= (others => character'val(32));

								--重置其他I/O 			
								l_clear <= '1';
								bg_color <= white;
								mode_2 <= sel_mode;
							when sel_mode =>
								case sw_d(2 to 4) is
									when "001" => seg_data <= "MoDE1.XX";
									when "010" => seg_data <= "MoDE2.YY";
									when "100" => seg_data <= "MoDE3.ZZ";
									when "000" => seg_data <= "SET.    ";
										mode_2 <= set_mode;
									when others => seg_data <= (others => character'val(32));
								end case;
								if pressed = '1' then
									case key is
										when 11 => mode_2 <= init;
										when others => seg_data <= (others => character'val(32));
									end case;
								end if;
							when set_mode =>
								if sw_d(2 to 4) /= "000" then
									mode_2 <= sel_mode;
									seg_data <= "        ";
								end if;
								if sw_d(1) = '1' then
									seg_data(1 to 4) <= "SET.";
									if pressed = '1' then
										seg_data(5 to 8) <= to_string(key, key'high, 10, 4);
									end if;
								else seg_data <= "SET.    ";
								end if;

						end case;
					when mode10 =>
						case mode_3 is
							when init =>
								ena_tim <= '1';
								txt_cnt <= 0;
								x <= 0;
								y <= 5;
								l_clear <= '1';
								bg_color <= white;
								font_start <= '0';
								text_size <= 1;
								text_data <= (others => character'val(32));
								text_color_array <= (others => blue);
								seg_data <= (others => character'val(32));
								init_fin_flag <= '0';
								cnt_c := (others => 0);
								cnt_l := (others => 0);
								mode_3 <= init_mode;
							when init_mode =>
								if msec >= 20 then
									ena_tim <= '0';
									l_clear <= '0';
									font_start <= '1';
								end if;
								if txt_cnt = 0 then
									x <= 0;
									y <= 0;
									text_size <= 1;
									text_data(1 to 7) <= "MODE:  ";
									text_data(8 to 12) <= (others => character'val(32));
								end if;
								if txt_cnt = 1 then
									x <= 0;
									y <= 32;
									text_size <= 1;
									text_data(1 to 7) <= "C  :000";
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
								end if;
								if txt_cnt = 2 then
									x <= 0;
									y <= 64;
									text_size <= 1;
									text_data(1 to 7) <= "L  : 00";
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
									init_fin_flag <= '1';
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
								if init_fin_flag = '1' then
									ena_tim <= '1';
									mode_3 <= set_mode;
								end if;
							when set_mode =>
								case sw_d(2 to 4) is
									when "001" => seg_data <= "MoDE1.XX";
										m_sel <= 0;
									when "010" => seg_data <= "MoDE2.YY";
										m_sel <= 1;
									when "100" => seg_data <= "MoDE3.ZZ";
										m_sel <= 2;
									when others => seg_data <= (others => character'val(32));
										m_sel <= 3;
								end case;
								if pressed = '1' then
									case key is
										when 11 => mode_3 <= init;
										when others =>
									end case;
								end if;
								if pressed_i = '1' then
									case key is
										when 14 =>
											if m_sel /= 3 then
												cnt_c(m_sel) := 0;
												cnt_l(m_sel) := 0;
											end if;
										when 15 =>
											if trigger = '1' and m_sel /= 3 then
												if cnt_c(m_sel) + 1 < cnt_c(m_sel)'high then
													cnt_c(m_sel) := cnt_c(m_sel) + 1;
													cnt_l(m_sel) := cnt_c(m_sel)/30;
												else
													cnt_c(m_sel) := 0;
													cnt_l(m_sel) := 0;
												end if;
											end if;
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
									text_data(1 to 5) <= "MODE:";
									case sw_d(2 to 4) is
										when "001" => text_data(6 to 7) <= "XX";
										when "010" => text_data(6 to 7) <= "YY";
										when "100" => text_data(6 to 7) <= "ZZ";
										when others => text_data(6 to 7) <= "  ";
									end case;
									text_data(8 to 12) <= (others => character'val(32));
								end if;
								if txt_cnt = 1 then
									x <= 0;
									y <= 32;
									text_size <= 1;
									text_data(1 to 4) <= "C  :";
									if m_sel /= 3 then
										text_data(5 to 7) <= to_string(cnt_c(m_sel), cnt_c(m_sel)'high, 10, 3);
									else text_data(5 to 7) <= "000";
									end if;
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
								end if;
								if txt_cnt = 2 then
									x <= 0;
									y <= 64;
									text_size <= 1;
									text_data(1 to 5) <= "L  : ";
									if m_sel /= 3 then
										text_data(6 to 7) <= to_string(cnt_l(m_sel), cnt_l(m_sel)'high, 10, 2);
									else text_data(6 to 7) <= "00";
									end if;
									text_data(8 to 12) <= (others => character'val(32));
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
							when UP_mode => null;
							when DN_mode => null;
						end case;
					when mode11 =>
						case mode_4 is
							when init =>
								mode_tts <= idle;
								ena_tim <= '1';
								txt_cnt <= 0;
								x <= 0;
								y <= 5;
								tts_ena <= '0';
								l_clear <= '1';
								bg_color <= white;
								font_start <= '0';
								text_size <= 1;
								text_data <= (others => character'val(32));
								text_color_array <= (others => blue);
								seg_data <= (others => character'val(32));
								init_fin_flag <= '0';
								tts_mode_flag <= '0';
								tts_pressed_flag <= '0';
								tts_said <= '0';
								cnt_c := (others => 0);
								cnt_l := (others => 0);
								mode_4 <= init_mode;
								fin_pro_flag <= '0';
							when init_mode =>
								if msec >= 20 then
									ena_tim <= '0';
									l_clear <= '0';
									font_start <= '1';
								end if;
								if txt_cnt = 0 then
									x <= 0;
									y <= 0;
									text_size <= 1;
									text_data(1 to 7) <= "MODE:  ";
									text_data(8 to 12) <= (others => character'val(32));
								end if;
								if txt_cnt = 1 then
									x <= 0;
									y <= 32;
									text_size <= 1;
									text_data(1 to 7) <= "C  :000";
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
								end if;
								if txt_cnt = 2 then
									x <= 0;
									y <= 64;
									text_size <= 1;
									text_data(1 to 7) <= "L  : 00";
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
									init_fin_flag <= '1';
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
								case mode_tts is
									when idle =>
										if init_fin_flag = '1' then
											mode_tts <= play;
										end if;
									when play =>
										tts_txt(0 to 11) <= link_success;
										txt_len <= 12;
										tts_ena <= '1';
										if tts_busy = '1' then
											mode_tts <= stop;
										end if;
									when stop =>
										if tts_busy = '0' then
											tts_ena <= '0';
											mode_tts <= idle;
											ena_tim <= '1';
											init_fin_flag <= '0';
											mode_4 <= set_mode;
										end if;
								end case;
							when set_mode =>
								case sw_d(2 to 4) is
									when "001" => seg_data <= "MoDE1.XX";
										m_sel <= 0;
										if tts_said <= '0' then
											tts_mode_flag <= '1';
											tts_pressed_flag <= '0';
											mode_4 <= tts_mode;
											mode_tts <= idle;
										end if;
									when "010" => seg_data <= "MoDE2.YY";
										m_sel <= 1;
										if tts_said <= '0' then
											tts_mode_flag <= '1';
											tts_pressed_flag <= '0';
											mode_4 <= tts_mode;
											mode_tts <= idle;
										end if;
									when "100" => seg_data <= "MoDE3.ZZ";
										m_sel <= 2;
										if tts_said <= '0' then
											tts_mode_flag <= '1';
											tts_pressed_flag <= '0';
											mode_4 <= tts_mode;
											mode_tts <= idle;
										end if;
									when others => seg_data <= (others => character'val(32));
										m_sel <= 3;
										tts_mode_flag <= '0';
										tts_pressed_flag <= '0';
										mode_tts <= idle;
										tts_said <= '0';
								end case;
								if pressed = '1' then
									case key is
										when 11 =>
											mode_4 <= tts_mode;
											fin_pro_flag <= '1';
										when others => null;
									end case;
								end if;
								if pressed_i = '1' then
									case key is
										when 14 =>
											if m_sel /= 3 then
												cnt_c(m_sel) := 0;
												cnt_l(m_sel) := 0;
											end if;
										when 15 =>
											if trigger = '1' and m_sel /= 3 then
												if cnt_c(m_sel) + 1 < cnt_c(m_sel)'high then
													cnt_c(m_sel) := cnt_c(m_sel) + 1;
													cnt_l(m_sel) := cnt_c(m_sel)/30;
												else
													cnt_c(m_sel) := 0;
													cnt_l(m_sel) := 0;
												end if;
											end if;
										when others => null;
									end case;
								end if;
								if pressed_f = '1' and m_sel /= 3 then
									case key is
										when 15 =>
											tts_mode_flag <= '0';
											tts_pressed_flag <= '1';
											mode_4 <= tts_mode;
											mode_tts <= idle;
											tts_said <= '0';
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
									text_data(1 to 5) <= "MODE:";
									case sw_d(2 to 4) is
										when "001" => text_data(6 to 7) <= "XX";
										when "010" => text_data(6 to 7) <= "YY";
										when "100" => text_data(6 to 7) <= "ZZ";
										when others => text_data(6 to 7) <= "  ";
									end case;
									text_data(8 to 12) <= (others => character'val(32));
								end if;
								if txt_cnt = 1 then
									x <= 0;
									y <= 32;
									text_size <= 1;
									text_data(1 to 4) <= "C  :";
									if m_sel /= 3 then
										text_data(5 to 7) <= to_string(cnt_c(m_sel), cnt_c(m_sel)'high, 10, 3);
									else text_data(5 to 7) <= "000";
									end if;
									text_data(8 to 12) <= (others => character'val(32));
									font_start <= '1';
								end if;
								if txt_cnt = 2 then
									x <= 0;
									y <= 64;
									text_size <= 1;
									text_data(1 to 5) <= "L  : ";
									if m_sel /= 3 then
										text_data(6 to 7) <= to_string(cnt_l(m_sel), cnt_l(m_sel)'high, 10, 2);
									else text_data(6 to 7) <= "00";
									end if;
									text_data(8 to 12) <= (others => character'val(32));
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
							when tts_mode =>
								case mode_tts is
									when idle =>
										if fin_pro_flag = '1' then
											mode_tts <= play;
										elsif tts_said = '0' and tts_mode_flag = '1'then
											mode_tts <= play;
										elsif tts_pressed_flag = '1'then
											mode_tts <= play;
										else mode_4 <= set_mode;
										end if;
									when play =>
										if fin_pro_flag = '1' then
											tts_txt(0 to 7) <= pro_finish;
											txt_len <= 8;
											tts_ena <= '1';
										elsif tts_mode_flag = '1' and tts_pressed_flag = '0' then
											case m_sel is
												when 0 => tts_txt(0 to 5) <= sel_XX;
												when 1 => tts_txt(0 to 5) <= sel_YY;
												when 2 => tts_txt(0 to 5) <= sel_ZZ;
												when 3 => null;
											end case;
											txt_len <= 6;
											tts_ena <= '1';
										elsif tts_mode_flag = '0' and tts_pressed_flag = '1' then
											tts_txt(0 to 27) <= cnt_cis & to_big(cnt_c(m_sel)) & cnt_lis & to_big(cnt_l(m_sel));
											txt_len <= 28;
											tts_ena <= '1';
										end if;
										if tts_busy = '1' then
											mode_tts <= stop;
											ena_tim <= '1';
										end if;
									when stop =>
										if msec >= 20 then
											ena_tim <= '0';
											l_clear <= '0';
											font_start <= '1';
										end if;
										if txt_cnt = 0 then
											x <= 0;
											y <= 0;
											text_size <= 1;
											text_data(1 to 5) <= "MODE:";
											case sw_d(2 to 4) is
												when "001" => text_data(6 to 7) <= "XX";
												when "010" => text_data(6 to 7) <= "YY";
												when "100" => text_data(6 to 7) <= "ZZ";
												when others => text_data(6 to 7) <= "  ";
											end case;
											text_data(8 to 12) <= (others => character'val(32));
										end if;
										if txt_cnt = 1 then
											x <= 0;
											y <= 32;
											text_size <= 1;
											text_data(1 to 4) <= "C  :";
											if m_sel /= 3 then
												text_data(5 to 7) <= to_string(cnt_c(m_sel), cnt_c(m_sel)'high, 10, 3);
											else text_data(5 to 7) <= "000";
											end if;
											text_data(8 to 12) <= (others => character'val(32));
											font_start <= '1';
										end if;
										if txt_cnt = 2 then
											x <= 0;
											y <= 64;
											text_size <= 1;
											text_data(1 to 5) <= "L  : ";
											if m_sel /= 3 then
												text_data(6 to 7) <= to_string(cnt_l(m_sel), cnt_l(m_sel)'high, 10, 2);
											else text_data(6 to 7) <= "00";
											end if;
											text_data(8 to 12) <= (others => character'val(32));
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
										if tts_busy = '0' then
											tts_ena <= '0';
											mode_tts <= idle;
											ena_tim <= '1';
											tts_mode_flag <= '0';
											tts_pressed_flag <= '0';
											tts_said <= '1';
											init_fin_flag <= '0';
											if fin_pro_flag = '1' then
												mode_4 <= init;
											end if;
										end if;
								end case;
							when UP_mode => null;
							when DN_mode => null;
						end case;
					when enable_mode =>
						case sw_d(6 to 7) is
							when"00" => mode_1 <= init;
								--lcd
								l_clear <= '1';
								bg_color <= white;
								text_data <= (others => character'val(32));
								--seg
								seg_data <= (others => character'val(32));
								--user
								key_state <= (others => '0');
								txt_cnt <= 0;
								ena_tim <= '0';
								text_color_array <= (others => blue);

							when"01" => mode_2 <= init;
								--lcd
								l_clear <= '1';
								bg_color <= white;
								text_data <= (others => character'val(32));
								--seg
								seg_data <= (others => character'val(32));
								--user
								txt_cnt <= 0;
								ena_tim <= '0';

							when"10" => mode_3 <= init;
								ena_tim <= '1';
								txt_cnt <= 0;
								x <= 0;
								y <= 5;
								l_clear <= '1';
								bg_color <= white;
								font_start <= '0';
								text_size <= 1;
								text_data <= (others => character'val(32));
								text_color_array <= (others => blue);
								seg_data <= (others => character'val(32));
								init_fin_flag <= '0';
								cnt_c := (others => 0);
								cnt_l := (others => 0);
							when"11" => mode_4 <= init;
								mode_tts <= idle;
								ena_tim <= '1';
								txt_cnt <= 0;
								x <= 0;
								y <= 5;
								tts_ena <= '0';
								l_clear <= '1';
								bg_color <= white;
								font_start <= '0';
								text_size <= 1;
								text_data <= (others => character'val(32));
								text_color_array <= (others => blue);
								seg_data <= (others => character'val(32));
								init_fin_flag <= '0';
								tts_mode_flag <= '0';
								tts_pressed_flag <= '0';
								tts_said <= '0';
								cnt_c := (others => 0);
								cnt_l := (others => 0);
								fin_pro_flag <= '0';
						end case;
				end case;

			end if;
		end process;
	end block Main_Process;
end arch;
