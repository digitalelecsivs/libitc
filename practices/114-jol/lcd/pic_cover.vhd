library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity pic_cover is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end pic_cover;

architecture arch of pic_cover is
	signal l_addr : l_addr_t;
	signal O_addr, X_addr, msi_addr : l_addr_t;
	signal O_data_i, X_data_i, msi_data_i : std_logic_vector(23 downto 0);
	signal O_data, X_data, msi_data : l_px_t;
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
	type state is (pic_mode1, pic_mode2, pic_mode3, pic_mode4, pic_mode5, pic_mode6, pic_mode7, pic_mode8, pic_mode9, pic_mode10, pic_mode11);
	signal mode : state := pic_mode1;
	--type
	type picture is array (0 to 10) of l_px_t;
	signal pic : picture;
	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
begin
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
	-- < Picture > -------------------------------------------------------------
	-- msi : entity work.msi_icon(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(msi_addr, 15)),
	-- 		clock   => clk,
	-- 		q       => msi_data_i
	-- 	);
	-- msi_data <= white;
	msi_data <= red;--unsigned(msi_data_i);
	O : entity work.O(syn)
		port map(
			address => std_logic_vector(to_unsigned(O_addr, 10)),
			clock   => clk,
			q       => O_data_i
		);
	O_data <= unsigned(O_data_i);
	X1 : entity work.X(syn)
		port map(
			address => std_logic_vector(to_unsigned(X_addr, 10)),
			clock   => clk,
			q       => X_data_i
		);
	X_data <= unsigned(X_data_i);

	--------------------------------------------------------------------------------
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			l_clear <= '1';
			ena_tim <= '0';
		elsif rising_edge(clk) then
			-- bg_color <= pic(2);
			case mode is
				when pic_mode1 =>
					bg_color <= pic(0);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
					--_addr <= to_addr(l_paste(l_addr, white, msi_data, (0, 0), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode2;
							when others => null;
						end case;
					end if;
				when pic_mode2 =>
					bg_color <= pic(0);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode3;
							when others => null;
						end case;
					end if;
				when pic_mode3 =>
					bg_color <= pic(0);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, red, O_data, (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, red, O_data, (0, 0), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode4;
							when others => null;
						end case;
					end if;
				when pic_mode4 =>
					bg_color <= pic(0);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, l_map(O_data, white, red), (0, 0), 128, 160));
					O_addr <= to_addr(l_paste(l_addr, white, l_map(O_data, white, red), (0, 0), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode5;
							when others => null;
						end case;
					end if;
				when pic_mode5 =>
					bg_color <= pic(1);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, pic(0), X_data, (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, pic(0), X_data, (0, 32), 32, 32));

					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode6;
							when others => null;
						end case;
					end if;
				when pic_mode6 =>
					bg_color <= pic(2);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, pic(0), O_data, (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, pic(0), O_data, (0, 0), 32, 32));
					pic(2) <= to_data(l_paste(l_addr, pic(1), X_data, (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, pic(1), X_data, (0, 32), 32, 32));

					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode7;
							when others => null;
						end case;
					end if;
				when pic_mode7 =>
					bg_color <= pic(2);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, pic(0), l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, pic(0), l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					pic(2) <= to_data(l_paste(l_addr, pic(1), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, pic(1), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode8;
							when others => null;
						end case;
					end if;
				when pic_mode8 =>
					bg_color <= pic(2);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					pic(2) <= to_data(l_paste(l_addr, white, l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, white, l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode9;
							when others => null;
						end case;
					end if;
				when pic_mode9 =>
					bg_color <= pic(2);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					pic(2) <= to_data(l_paste(l_addr, pic(1), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, pic(1), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode10;
							when others => null;
						end case;
					end if;
				when pic_mode10 =>
					bg_color <= pic(2);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, white, l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					pic(2) <= to_data(l_paste(l_addr, pic(0), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, pic(0), l_map(X_data, white, pic(1)), (0, 32), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode11;
							when others => null;
						end case;
					end if;
				when pic_mode11 =>
					bg_color <= pic(1);
					l_clear <= '1';
					pic(0) <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 182, 160));
					-- O_addr <= to_addr(l_paste(l_addr, white, O_data, (0, 0), 32, 32));
					pic(1) <= to_data(l_paste(l_addr, pic(0), l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					O_addr <= to_addr(l_paste(l_addr, pic(0), l_map(O_data, white, pic(0)), (0, 0), 32, 32));
					-- pic(2) <= to_data(l_paste(l_addr, white, l_map(X_data,white,pic(1)), (0, 32), 32, 32));
					-- X_addr <= to_addr(l_paste(l_addr, white, l_map(X_data,white,pic(1)), (0, 32), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode1;
							when others => null;
						end case;
					end if;
			end case;
		end if;
	end process;
end arch;
