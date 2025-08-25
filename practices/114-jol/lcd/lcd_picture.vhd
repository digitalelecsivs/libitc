library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_picture is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end lcd_picture;

architecture arch of lcd_picture is
	signal l_addr : l_addr_t;
	signal msi_addr, X_addr : l_addr_t;
	signal msi_data_i, X_data_i : std_logic_vector(23 downto 0);
	signal msi_data, X_data : l_px_t;
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
	type state is (pic_mode1, pic_mode2, txt_mode);
	signal mode : state := pic_mode1;
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
	msi : entity work.msi_icon(syn)
		port map(
			address => std_logic_vector(to_unsigned(msi_addr, 15)),
			clock   => clk,
			q       => msi_data_i
		);
	msi_data <= unsigned(msi_data_i);
	X_icon : entity work.X2(syn)
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
			ena_tim <= '1';
		elsif rising_edge(clk) then
			case mode is
				when pic_mode1 =>
					-- ena_tim <= '1';
					l_clear <= '1';
					bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160)), X_data, (30, 30), 32, 32));
					msi_addr <= to_addr(l_paste(l_addr, to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160)), msi_data, (0, 0), 128, 160));
					X_addr <= to_addr(l_paste(l_addr, to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160)), x_data, (0, 0), 128, 160));
					-- if msec>1000 then
					-- 	mode <= pic_mode2;
					-- 	ena_tim <= '0';
					-- end if; 

					if pressed = '1' then
						case key is
							when 15 => mode <= pic_mode2;
							when others => null;
						end case;
					end if;
				when pic_mode2 =>
					l_clear <= '1';
					bg_color <= to_data(l_paste(l_addr, red, X_data, (10, 10), 32, 32));
					X_addr <= to_addr(l_paste(l_addr, red, X_data, (10, 10), 32, 32));
					if pressed = '1' then
						case key is
							when 15 => mode <= txt_mode;
							when others => null;
						end case;
					end if;
				when txt_mode =>

					text_data <= "text_data   ";
					l_clear <= '1';
					bg_color <= l_paste_txt(l_addr, to_data(l_paste(l_addr, red, msi_data, (0, 0), 128, 160)), "text_data", (45, 30), green);
					msi_addr <= to_addr(l_paste(l_addr, red, msi_data, (0, 0), 128, 160));
					if font_busy = '1' then
						font_start <= '0';
					end if;
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
