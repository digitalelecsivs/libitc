library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity circle_cross_1 is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end circle_cross_1;

architecture arch of circle_cross_1 is
	signal l_addr : l_addr_t;
	signal O1_addr, O2_addr, O3_addr, O4_addr, O5_addr, O6_addr, O7_addr, O8_addr, O9_addr : l_addr_t;
	signal X1_addr, X2_addr, X3_addr, X4_addr, X5_addr, X6_addr, X7_addr, X8_addr, X9_addr : l_addr_t;
	signal O1_data_i, O2_data_i, O3_data_i, O4_data_i, O5_data_i, O6_data_i, O7_data_i, O8_data_i, O9_data_i : std_logic_vector(23 downto 0);
	signal X1_data_i, X2_data_i, X3_data_i, X4_data_i, X5_data_i, X6_data_i, X7_data_i, X8_data_i, X9_data_i : std_logic_vector(23 downto 0);
	signal O1_data, O2_data, O3_data, O4_data, O5_data, O6_data, O7_data, O8_data, O9_data : l_px_t;
	signal X1_data, X2_data, X3_data, X4_data, X5_data, X6_data, X7_data, X8_data, X9_data : l_px_t;
	signal x : integer range -127 to 127 := 30;
	signal y : integer range -159 to 159 := 30;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(20));
	signal bg_color : l_px_t;
	--unknown sig
	signal pic_data : l_px_t;
	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 3000 := 0;
	--state machine
	type state is (init, game_mode, result_mode);
	signal mode : state := game_mode;
	--type
	type picture is array (0 to 10) of l_px_t;
	signal pic : picture;
	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	--signal
	signal player : std_logic := '0';--0:O 1:X
	signal mapPlace : std_logic_vector(0 to 8) := (others => '0');
	signal O_placed : std_logic_vector(0 to 8) := (others => '0');
	signal X_placed : std_logic_vector(0 to 8) := (others => '0');
	signal X_win : std_logic := '0';
	signal O_win : std_logic := '0';
	signal place_coord : l_coord_t := (0, 0);
	signal map_used : std_logic_vector(0 to 8) := (others => '0');
	type l_coord_arr is array (0 to 8) of l_coord_t;
	signal map_coord : l_coord_arr := ((3, 3), (3, 47), (3, 91), (47, 3), (47, 47), (47, 91), (91, 3), (91, 47), (91, 91));
	signal placed : integer range 0 to 9 := 0;
	type WinorNot is array (1 to 8) of std_logic_vector(0 to 2);
	signal O_list : WinorNot;
	signal X_list : WinorNot;
begin
	components : block begin
		lcd_edge : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy_i,
				rising  => open,
				falling => font_busy
			);
		timer_inst : entity work.timer(arch)
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
		key_edge : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => open
			);
		lcd_mix_inst : entity work.lcd_mix(arch)
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => x,                                                            -- 文字x軸
				y                => y,                                                            -- 文字y軸
				font_start       => font_start,                                                   -- 文字更新(取正緣)
				font_busy        => font_busy_i,                                                  -- 當畫面正在更新時，font_busy='1'
				text_size        => 1,                                                            -- 字體大小
				text_data        => text_data,                                                    -- 文字資料
				addr             => l_addr,                                                       -- 偵錯用 --可以用來貼圖
				text_color       => red,                                                          -- 字體顏色(只能改單行)(若要使用需改gen_font.vhd(有註記))(若沒用到隨便填一顏色即可)
				bg_color         => bg_color,                                                     -- 背景顏色
				text_color_array => (red, red, red, red, red, red, red, red, red, red, red, red), -- 字體顏色(同一行依位元改變)(text_color_array:l_px_arr_t(1 to 12);)
				clear            => l_clear,                                                      -- '1' 時清除
				lcd_sclk         => lcd_sclk,                                                     -- 腳位
				lcd_mosi         => lcd_mosi,                                                     -- 腳位
				lcd_ss_n         => lcd_ss_n,                                                     -- 腳位
				lcd_dc           => lcd_dc,                                                       -- 腳位
				lcd_bl           => lcd_bl,                                                       -- 腳位
				lcd_rst_n        => lcd_rst_n,                                                    -- 腳位
				con              => '0',                                                          -- 選擇文字或圖片
				pic_data         => pic_data                                                      -- 圖片資料
			);
	end block components;
	-- < Picture > -------------------------------------------------------------
	Pictures : block begin

		O1 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O1_addr, 10)),
				clock   => clk,
				q       => O1_data_i
			);
		O1_data <= unsigned(O1_data_i);
		O2 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O2_addr, 10)),
				clock   => clk,
				q       => O2_data_i
			);
		O2_data <= unsigned(O2_data_i);
		O3 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O3_addr, 10)),
				clock   => clk,
				q       => O3_data_i
			);
		O3_data <= unsigned(O3_data_i);
		O4 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O4_addr, 10)),
				clock   => clk,
				q       => O4_data_i
			);
		O4_data <= unsigned(O4_data_i);
		O5 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O5_addr, 10)),
				clock   => clk,
				q       => O5_data_i
			);
		O5_data <= unsigned(O5_data_i);
		O6 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O6_addr, 10)),
				clock   => clk,
				q       => O6_data_i
			);
		O6_data <= unsigned(O6_data_i);
		O7 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O7_addr, 10)),
				clock   => clk,
				q       => O7_data_i
			);
		O7_data <= unsigned(O7_data_i);
		O8 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O8_addr, 10)),
				clock   => clk,
				q       => O8_data_i
			);
		O8_data <= unsigned(O8_data_i);
		O9 : entity work.O(syn)
			port map(
				address => std_logic_vector(to_unsigned(O9_addr, 10)),
				clock   => clk,
				q       => O9_data_i
			);
		O9_data <= unsigned(O9_data_i);
		X1 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X1_addr, 10)),
				clock   => clk,
				q       => X1_data_i
			);
		X1_data <= unsigned(X1_data_i);
		X2 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X2_addr, 10)),
				clock   => clk,
				q       => X2_data_i
			);
		X2_data <= unsigned(X2_data_i);
		X3 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X3_addr, 10)),
				clock   => clk,
				q       => X3_data_i
			);
		X3_data <= unsigned(X3_data_i);
		X4 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X4_addr, 10)),
				clock   => clk,
				q       => X4_data_i
			);
		X4_data <= unsigned(X4_data_i);
		X5 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X5_addr, 10)),
				clock   => clk,
				q       => X5_data_i
			);
		X5_data <= unsigned(X5_data_i);
		X6 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X6_addr, 10)),
				clock   => clk,
				q       => X6_data_i
			);
		X6_data <= unsigned(X6_data_i);
		X7 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X7_addr, 10)),
				clock   => clk,
				q       => X7_data_i
			);
		X7_data <= unsigned(X7_data_i);
		X8 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X8_addr, 10)),
				clock   => clk,
				q       => X8_data_i
			);
		X8_data <= unsigned(X8_data_i);
		X9 : entity work.X(syn)
			port map(
				address => std_logic_vector(to_unsigned(X9_addr, 10)),
				clock   => clk,
				q       => X9_data_i
			);
		X9_data <= unsigned(X9_data_i);

	end block Pictures;
	--------------------------------------------------------------------------------
	OandX_placed_list : block begin
		O_list <= (
		O_placed(0) & O_placed(1) & O_placed(2),
		O_placed(0) & O_placed(4) & O_placed(8),
		O_placed(0) & O_placed(3) & O_placed(6),
		O_placed(1) & O_placed(4) & O_placed(7),
		O_placed(2) & O_placed(4) & O_placed(6),
		O_placed(2) & O_placed(5) & O_placed(8),
		O_placed(3) & O_placed(4) & O_placed(5),
		O_placed(6) & O_placed(7) & O_placed(8)
		);
		X_list <= (
		X_placed(0) & X_placed(1) & X_placed(2),
		X_placed(0) & X_placed(4) & X_placed(8),
		X_placed(0) & X_placed(3) & X_placed(6),
		X_placed(1) & X_placed(4) & X_placed(7),
		X_placed(2) & X_placed(4) & X_placed(6),
		X_placed(2) & X_placed(5) & X_placed(8),
		X_placed(3) & X_placed(4) & X_placed(5),
		X_placed(6) & X_placed(7) & X_placed(8)
		);
	end block OandX_placed_list;
	O_win <= '1' when placed >= 5 and(O_list(1) = "111" or O_list(2) = "111"or O_list(3) = "111"or O_list(4) = "111"
	or O_list(5) = "111"or O_list(6) = "111"or O_list(7) = "111"or O_list(8) = "111")else '0';
	X_win <= '1' when placed >= 5 and(X_list(1) = "111" or X_list(2) = "111"or X_list(3) = "111"or X_list(4) = "111"
	or X_list(5) = "111"or X_list(6) = "111"or X_list(7) = "111"or X_list(8) = "111")else '0';

	Main_Process : block begin
		process (clk, rst_n)
		begin
			if rst_n = '0' then
				l_clear <= '1';
				mode <= init;
				map_used <= (others => '0');
				player <= '0';
				pic <= (others => white);
				placed <= 0;
				mapPlace <= (others => '0');
				O_placed <= (others => '0');
				X_placed <= (others => '0');
				ena_tim <= '0';
				elsif rising_edge(clk) then
				case mode is
					when init =>
						l_clear <= '1';
						map_used <= (others => '0');
						player <= '0';
						pic <= (others => white);
						placed <= 0;
						mapPlace <= (others => '0');
						O_placed <= (others => '0');
						X_placed <= (others => '0');
						ena_tim <= '1';
						if msec > 400 then
							mode <= game_mode;
							ena_tim <= '0';
						end if;
					when game_mode =>

						l_clear <= '1';
						bg_color <= pic(10);

						-- place_coord <= to_coord(l_addr);
						-- if (place_coord(0) >= 40 and place_coord(0) < 44) or (place_coord(0) >= 84 and place_coord(0) < 88) then
						-- 	pic(0) <= black;
						-- 	elsif ((place_coord(1) >= 40 and place_coord(1) < 44) or (place_coord(1) >= 84 and place_coord(1) < 88)) and place_coord(0) < 128 then
						-- 	pic(0) <= black;
						-- 	else
						-- 	pic(0) <= white;
						-- end if;
						pic(0) <= white;
						if map_used(0) = '1'then
							if mapPlace(0) = '0' then
								pic(1) <= to_data(l_paste(l_addr, pic(0), O1_data, map_coord(0), 32, 32));
								O1_addr <= to_addr(l_paste(l_addr, pic(0), O1_data, map_coord(0), 32, 32));
							else
								pic(1) <= to_data(l_paste(l_addr, pic(0), X1_data, map_coord(0), 32, 32));
								X1_addr <= to_addr(l_paste(l_addr, pic(0), X1_data, map_coord(0), 32, 32));
							end if;
						else
							pic(1) <= pic(0);
						end if;
						if map_used(1) = '1'then
							if mapPlace(1) = '0' then
								pic(2) <= to_data(l_paste(l_addr, pic(1), O2_data, map_coord(1), 32, 32));
								O2_addr <= to_addr(l_paste(l_addr, pic(1), O2_data, map_coord(1), 32, 32));
							else
								pic(2) <= to_data(l_paste(l_addr, pic(1), X2_data, map_coord(1), 32, 32));
								X2_addr <= to_addr(l_paste(l_addr, pic(1), X2_data, map_coord(1), 32, 32));
							end if;
						else
							pic(2) <= pic(1);
						end if;
						if map_used(2) = '1'then
							if mapPlace(2) = '0' then
								pic(3) <= to_data(l_paste(l_addr, pic(2), O3_data, map_coord(2), 32, 32));
								O3_addr <= to_addr(l_paste(l_addr, pic(2), O3_data, map_coord(2), 32, 32));
							else
								pic(3) <= to_data(l_paste(l_addr, pic(2), X3_data, map_coord(2), 32, 32));
								X3_addr <= to_addr(l_paste(l_addr, pic(2), X3_data, map_coord(2), 32, 32));
							end if;
						else
							pic(3) <= pic(2);
						end if;
						if map_used(3) = '1'then
							if mapPlace(3) = '0' then
								pic(4) <= to_data(l_paste(l_addr, pic(3), O4_data, map_coord(3), 32, 32));
								O4_addr <= to_addr(l_paste(l_addr, pic(3), O4_data, map_coord(3), 32, 32));
							else
								pic(4) <= to_data(l_paste(l_addr, pic(3), X4_data, map_coord(3), 32, 32));
								X4_addr <= to_addr(l_paste(l_addr, pic(3), X4_data, map_coord(3), 32, 32));
							end if;
						else
							pic(4) <= pic(3);
						end if;
						if map_used(4) = '1'then
							if mapPlace(4) = '0' then
								pic(5) <= to_data(l_paste(l_addr, pic(4), O5_data, map_coord(4), 32, 32));
								O5_addr <= to_addr(l_paste(l_addr, pic(4), O5_data, map_coord(4), 32, 32));
							else
								pic(5) <= to_data(l_paste(l_addr, pic(4), X5_data, map_coord(4), 32, 32));
								X5_addr <= to_addr(l_paste(l_addr, pic(4), X5_data, map_coord(4), 32, 32));
							end if;
						else
							pic(5) <= pic(4);
						end if;
						if map_used(5) = '1'then
							if mapPlace(5) = '0' then
								pic(6) <= to_data(l_paste(l_addr, pic(5), O6_data, map_coord(5), 32, 32));
								O6_addr <= to_addr(l_paste(l_addr, pic(5), O6_data, map_coord(5), 32, 32));
							else
								pic(6) <= to_data(l_paste(l_addr, pic(5), X6_data, map_coord(5), 32, 32));
								X6_addr <= to_addr(l_paste(l_addr, pic(5), X6_data, map_coord(5), 32, 32));
							end if;
						else
							pic(6) <= pic(5);
						end if;
						if map_used(6) = '1'then
							if mapPlace(6) = '0' then
								pic(7) <= to_data(l_paste(l_addr, pic(6), O7_data, map_coord(6), 32, 32));
								O7_addr <= to_addr(l_paste(l_addr, pic(6), O7_data, map_coord(6), 32, 32));
							else
								pic(7) <= to_data(l_paste(l_addr, pic(6), X7_data, map_coord(6), 32, 32));
								X7_addr <= to_addr(l_paste(l_addr, pic(6), X7_data, map_coord(6), 32, 32));
							end if;
						else
							pic(7) <= pic(6);
						end if;
						if map_used(7) = '1'then
							if mapPlace(7) = '0' then
								pic(8) <= to_data(l_paste(l_addr, pic(7), O8_data, map_coord(7), 32, 32));
								O8_addr <= to_addr(l_paste(l_addr, pic(7), O8_data, map_coord(7), 32, 32));
							else
								pic(8) <= to_data(l_paste(l_addr, pic(7), X8_data, map_coord(7), 32, 32));
								X8_addr <= to_addr(l_paste(l_addr, pic(7), X8_data, map_coord(7), 32, 32));
							end if;
						else
							pic(8) <= pic(7);
						end if;
						if map_used(8) = '1'then
							if mapPlace(8) = '0' then
								pic(9) <= to_data(l_paste(l_addr, pic(8), O9_data, map_coord(8), 32, 32));
								O9_addr <= to_addr(l_paste(l_addr, pic(8), O9_data, map_coord(8), 32, 32));
							else
								pic(9) <= to_data(l_paste(l_addr, pic(8), X9_data, map_coord(8), 32, 32));
								X9_addr <= to_addr(l_paste(l_addr, pic(8), X9_data, map_coord(8), 32, 32));
							end if;
						else
							pic(9) <= pic(8);
						end if;
						--< Key board >------------------------------------------------------------------------------
						if pressed = '1' then
							case key is
								when 0 =>
									if map_used(0) = '0' then
										placed <= placed + 1;
										map_used(0) <= '1';
										if player = '0' then
											mapPlace(0) <= '0';
											player <= '1';
											O_placed(0) <= '1';
										else
											mapPlace(0) <= '1';
											player <= '0';
											X_placed(0) <= '1';
										end if;
									end if;
								when 1 =>
									if map_used(1) = '0' then
										placed <= placed + 1;
										map_used(1) <= '1';
										if player = '0' then
											mapPlace(1) <= '0';
											player <= '1';
											O_placed(1) <= '1';
										else
											mapPlace(1) <= '1';
											player <= '0';
											X_placed(1) <= '1';
										end if;
									end if;
								when 2 =>
									if map_used(2) = '0' then
										placed <= placed + 1;
										map_used(2) <= '1';
										if player = '0' then
											mapPlace(2) <= '0';
											player <= '1';
											O_placed(2) <= '1';
										else
											mapPlace(2) <= '1';
											player <= '0';
											X_placed(2) <= '1';
										end if;
									end if;
								when 4 =>
									if map_used(3) = '0' then
										placed <= placed + 1;
										map_used(3) <= '1';
										if player = '0' then
											mapPlace(3) <= '0';
											player <= '1';
											O_placed(3) <= '1';
										else
											mapPlace(3) <= '1';
											player <= '0';
											X_placed(3) <= '1';
										end if;
									end if;
								when 5 =>
									if map_used(4) = '0' then
										placed <= placed + 1;
										map_used(4) <= '1';
										if player = '0' then
											mapPlace(4) <= '0';
											player <= '1';
											O_placed(4) <= '1';
										else
											mapPlace(4) <= '1';
											player <= '0';
											X_placed(4) <= '1';
										end if;
									end if;
								when 6 =>
									if map_used(5) = '0' then
										placed <= placed + 1;
										map_used(5) <= '1';
										if player = '0' then
											mapPlace(5) <= '0';
											player <= '1';
											O_placed(5) <= '1';
										else
											mapPlace(5) <= '1';
											player <= '0';
											X_placed(5) <= '1';

										end if;
									end if;
								when 8 =>
									if map_used(6) = '0' then
										placed <= placed + 1;
										map_used(6) <= '1';
										if player = '0' then
											mapPlace(6) <= '0';
											player <= '1';
											O_placed(6) <= '1';
										else
											mapPlace(6) <= '1';
											player <= '0';
											X_placed(6) <= '1';
										end if;
									end if;
								when 9 =>
									if map_used(7) = '0' then
										placed <= placed + 1;
										map_used(7) <= '1';
										if player = '0' then
											mapPlace(7) <= '0';
											player <= '1';
											O_placed(7) <= '1';
										else
											mapPlace(7) <= '1';
											player <= '0';
											X_placed(7) <= '1';
										end if;
									end if;
								when 10 =>
									if map_used(8) = '0' then
										placed <= placed + 1;
										map_used(8) <= '1';
										if player = '0' then
											mapPlace(8) <= '0';
											player <= '1';
											O_placed(8) <= '1';
										else
											mapPlace(8) <= '1';
											player <= '0';
											X_placed(8) <= '1';
										end if;
									end if;

								when others => null;
							end case;
						end if;
						if O_win = '1' or X_win = '1' or placed = 9 then
							mode <= result_mode;
							ena_tim <= '0';
						else
							pic(10) <= pic(9);
						end if;
					when result_mode =>
						l_clear <= '1';
						bg_color <= pic(10);
						if map_used(0) = '1'then
							if mapPlace(0) = '0' then
								pic(1) <= to_data(l_paste(l_addr, pic(0), O1_data, map_coord(0), 32, 32));
								O1_addr <= to_addr(l_paste(l_addr, pic(0), O1_data, map_coord(0), 32, 32));
							else
								pic(1) <= to_data(l_paste(l_addr, pic(0), X1_data, map_coord(0), 32, 32));
								X1_addr <= to_addr(l_paste(l_addr, pic(0), X1_data, map_coord(0), 32, 32));
							end if;
						else
							pic(1) <= pic(0);
						end if;
						if map_used(1) = '1'then
							if mapPlace(1) = '0' then
								pic(2) <= to_data(l_paste(l_addr, pic(1), O2_data, map_coord(1), 32, 32));
								O2_addr <= to_addr(l_paste(l_addr, pic(1), O2_data, map_coord(1), 32, 32));
							else
								pic(2) <= to_data(l_paste(l_addr, pic(1), X2_data, map_coord(1), 32, 32));
								X2_addr <= to_addr(l_paste(l_addr, pic(1), X2_data, map_coord(1), 32, 32));
							end if;
						else
							pic(2) <= pic(1);
						end if;
						if map_used(2) = '1'then
							if mapPlace(2) = '0' then
								pic(3) <= to_data(l_paste(l_addr, pic(2), O3_data, map_coord(2), 32, 32));
								O3_addr <= to_addr(l_paste(l_addr, pic(2), O3_data, map_coord(2), 32, 32));
							else
								pic(3) <= to_data(l_paste(l_addr, pic(2), X3_data, map_coord(2), 32, 32));
								X3_addr <= to_addr(l_paste(l_addr, pic(2), X3_data, map_coord(2), 32, 32));
							end if;
						else
							pic(3) <= pic(2);
						end if;
						if map_used(3) = '1'then
							if mapPlace(3) = '0' then
								pic(4) <= to_data(l_paste(l_addr, pic(3), O4_data, map_coord(3), 32, 32));
								O4_addr <= to_addr(l_paste(l_addr, pic(3), O4_data, map_coord(3), 32, 32));
							else
								pic(4) <= to_data(l_paste(l_addr, pic(3), X4_data, map_coord(3), 32, 32));
								X4_addr <= to_addr(l_paste(l_addr, pic(3), X4_data, map_coord(3), 32, 32));
							end if;
						else
							pic(4) <= pic(3);
						end if;
						if map_used(4) = '1'then
							if mapPlace(4) = '0' then
								pic(5) <= to_data(l_paste(l_addr, pic(4), O5_data, map_coord(4), 32, 32));
								O5_addr <= to_addr(l_paste(l_addr, pic(4), O5_data, map_coord(4), 32, 32));
							else
								pic(5) <= to_data(l_paste(l_addr, pic(4), X5_data, map_coord(4), 32, 32));
								X5_addr <= to_addr(l_paste(l_addr, pic(4), X5_data, map_coord(4), 32, 32));
							end if;
						else
							pic(5) <= pic(4);
						end if;
						if map_used(5) = '1'then
							if mapPlace(5) = '0' then
								pic(6) <= to_data(l_paste(l_addr, pic(5), O6_data, map_coord(5), 32, 32));
								O6_addr <= to_addr(l_paste(l_addr, pic(5), O6_data, map_coord(5), 32, 32));
							else
								pic(6) <= to_data(l_paste(l_addr, pic(5), X6_data, map_coord(5), 32, 32));
								X6_addr <= to_addr(l_paste(l_addr, pic(5), X6_data, map_coord(5), 32, 32));
							end if;
						else
							pic(6) <= pic(5);
						end if;
						if map_used(6) = '1'then
							if mapPlace(6) = '0' then
								pic(7) <= to_data(l_paste(l_addr, pic(6), O7_data, map_coord(6), 32, 32));
								O7_addr <= to_addr(l_paste(l_addr, pic(6), O7_data, map_coord(6), 32, 32));
							else
								pic(7) <= to_data(l_paste(l_addr, pic(6), X7_data, map_coord(6), 32, 32));
								X7_addr <= to_addr(l_paste(l_addr, pic(6), X7_data, map_coord(6), 32, 32));
							end if;
						else
							pic(7) <= pic(6);
						end if;
						if map_used(7) = '1'then
							if mapPlace(7) = '0' then
								pic(8) <= to_data(l_paste(l_addr, pic(7), O8_data, map_coord(7), 32, 32));
								O8_addr <= to_addr(l_paste(l_addr, pic(7), O8_data, map_coord(7), 32, 32));
							else
								pic(8) <= to_data(l_paste(l_addr, pic(7), X8_data, map_coord(7), 32, 32));
								X8_addr <= to_addr(l_paste(l_addr, pic(7), X8_data, map_coord(7), 32, 32));
							end if;
						else
							pic(8) <= pic(7);
						end if;
						if map_used(8) = '1'then
							if mapPlace(8) = '0' then
								pic(9) <= to_data(l_paste(l_addr, pic(8), O9_data, map_coord(8), 32, 32));
								O9_addr <= to_addr(l_paste(l_addr, pic(8), O9_data, map_coord(8), 32, 32));
							else
								pic(9) <= to_data(l_paste(l_addr, pic(8), X9_data, map_coord(8), 32, 32));
								X9_addr <= to_addr(l_paste(l_addr, pic(8), X9_data, map_coord(8), 32, 32));
							end if;
						else
							pic(9) <= pic(8);
						end if;
						if O_win = '1' and X_win = '0'then
							pic(10) <= l_paste_txt(l_addr, to_data(l_paste(l_addr, red, pic(9), (0, 0), 128, 160)), " Circle win", (140, 50), red);
						elsif X_win = '1' and O_win = '0' then
							pic(10) <= l_paste_txt(l_addr, to_data(l_paste(l_addr, red, pic(9), (0, 0), 128, 160)), " Cross win", (140, 50), blue);
						elsif placed = 9 and O_win = '0' and X_win = '0' then
							pic(10) <= l_paste_txt(l_addr, to_data(l_paste(l_addr, red, pic(9), (0, 0), 128, 160)), " Tie", (140, 50), green);
						else
							pic(10) <= pic(9);
						end if;

						ena_tim <= '1';
						if msec >= 2000 then
							l_clear <= '1';
							map_used <= (others => '0');
							player <= '0';
							pic <= (others => white);
							placed <= 0;
							mapPlace <= (others => '0');
							O_placed <= (others => '0');
							X_placed <= (others => '0');
							mode <= init;
							ena_tim <= '0';
						end if;
				end case;
			end if;
		end process;
	end block Main_Process;
end arch;
--bg_color<= l_paste_txt(l_addr, to_data(l_paste(l_addr, red, msi_data, (0, 0), 128, 160)), "text_data", (45, 30), green);
