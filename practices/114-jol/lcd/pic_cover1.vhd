library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity pic_cover1 is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end pic_cover1;

architecture arch of pic_cover1 is
	signal l_addr : l_addr_t;
	signal x : integer range -127 to 127 := 30;
	signal y : integer range -159 to 159 := 30;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(20));
	signal bg_color : l_px_t;
	--unknown sig
	signal pic_data : l_px_t;
	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 1000 := 0;
	--state machine
	type state is (pic_1, pic0, pic1, pic2, pic3, pic4, pic5, pic6, pic7, pic8, pic9, pic10, pic11, pic12, pic13, pic14);
	signal mode : state := pic_1;
	--type
	type picture is array (0 to 14) of l_px_t;

	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
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

	--------------------------------------------------------------------------------
	process (clk, rst_n)
		variable pic : picture;
	begin
		if rst_n = '0' then
			l_clear <= '1';
			ena_tim <= '0';
		elsif rising_edge(clk) then
			case mode is
				when pic_1 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						bg_color <= black;
					else
						bg_color <= white;
					end if;
					if pressed = '1' then
						case key is
							when 14 => mode <= pic14;
							when 15 => mode <= pic0;
							when others => null;
						end case;
					end if;
				when pic0 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					bg_color <= pic(0);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic_1;
							when 15 => mode <= pic1;
							when others => null;
						end case;
					end if;
				when pic1 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					bg_color <= pic(1);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic0;
							when 15 => mode <= pic2;
							when others => null;
						end case;
					end if;
				when pic2 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					bg_color <= pic(2);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic1;
							when 15 => mode <= pic3;
							when others => null;
						end case;
					end if;
				when pic3 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					bg_color <= pic(3);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic2;
							when 15 => mode <= pic4;
							when others => null;
						end case;
					end if;
				when pic4 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					bg_color <= pic(4);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic3;
							when 15 => mode <= pic5;
							when others => null;
						end case;
					end if;
				when pic5 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					bg_color <= pic(5);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic4;
							when 15 => mode <= pic6;
							when others => null;
						end case;
					end if;
				when pic6 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);

					bg_color <= pic(6);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic5;
							when 15 => mode <= pic7;
							when others => null;
						end case;
					end if;

				when pic7 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);

					bg_color <= pic(7);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic6;
							when 15 => mode <= pic8;
							when others => null;
						end case;
					end if;
				when pic8 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);

					bg_color <= pic(8);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic7;
							when 15 => mode <= pic9;
							when others => null;
						end case;
					end if;
				when pic9 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);

					bg_color <= pic(9);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic8;
							when 15 => mode <= pic10;
							when others => null;
						end case;
					end if;
				when pic10 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);
					pic(10) := pic(9);
					bg_color <= pic(10);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic9;
							when 15 => mode <= pic11;
							when others => null;
						end case;
					end if;
				when pic11 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);
					pic(10) := pic(9);
					pic(11) := pic(10);
					bg_color <= pic(11);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic10;
							when 15 => mode <= pic12;
							when others => null;
						end case;
					end if;
				when pic12 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);
					pic(10) := pic(9);
					pic(11) := pic(10);
					pic(12) := pic(11);
					bg_color <= pic(12);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic11;
							when 15 => mode <= pic13;
							when others => null;
						end case;
					end if;
				when pic13 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);
					pic(10) := pic(9);
					pic(11) := pic(10);
					pic(12) := pic(11);
					pic(13) := pic(12);
					bg_color <= pic(13);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic12;
							when 15 => mode <= pic14;
							when others => null;
						end case;
					end if;
				when pic14 =>
					l_clear <= '1';
					if l_addr mod 16 > 7 then
						pic(0) := black;
					else
						pic(0) := white;
					end if;
					pic(1) := pic(0);
					pic(2) := pic(1);
					pic(3) := pic(2);
					pic(4) := pic(3);
					pic(5) := pic(4);
					pic(6) := pic(5);
					pic(7) := pic(6);
					pic(8) := pic(7);
					pic(9) := pic(8);
					pic(10) := pic(9);
					pic(11) := pic(10);
					pic(12) := pic(11);
					pic(13) := pic(12);
					pic(14) := pic(13);
					bg_color <= pic(14);
					if pressed = '1' then
						case key is
							when 14 => mode <= pic13;
							when 15 => mode <= pic_1;
							when others => null;
						end case;
					end if;
				when others => null;
			end case;
		end if;
	end process;
end arch;
