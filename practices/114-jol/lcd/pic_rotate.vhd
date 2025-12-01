library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity pic_rotate is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end pic_rotate;

architecture arch of pic_rotate is
	signal l_addr : l_addr_t;
	signal msi_addr, n9_addr : l_addr_t;
	signal msi_data_i, n9_data_i : std_logic_vector(23 downto 0);
	signal msi_data, n9_data : l_px_t;
	signal x : integer range -127 to 127 := 30;
	signal y : integer range -159 to 159 := 30;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(20));
	signal bg_color : l_px_t;
	--unknown sig
	signal pic_data : l_px_t;
	--timer
	signal msec : integer range 0 to 500;
	signal ena_tim : std_logic;
	--keyboard
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : i4_t;
	signal key_times : integer range 0 to 12;
begin
	Components : block begin
		edge_inst1 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy_i,
				rising  => open,
				falling => font_busy
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
		edge_inst2 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => open
			);
		timer_inst : entity work.timer(arch)
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena_tim,
				load  => 0,
				msec  => msec
			);
		lcd_mix_inst : entity work.lcd_mix(arch)
			port map(
				clk              => clk,
				rst_n            => rst_n,
				x                => x,
				y                => y,
				font_start       => font_start,
				font_busy        => font_busy_i,
				text_size        => 1,
				text_data        => text_data,
				addr             => l_addr,
				text_color       => green,
				bg_color         => bg_color,
				text_color_array => (red, red, red, red, red, red, red, red, red, red, red, red),
				clear            => l_clear,
				lcd_sclk         => lcd_sclk,
				lcd_mosi         => lcd_mosi,
				lcd_ss_n         => lcd_ss_n,
				lcd_dc           => lcd_dc,
				lcd_bl           => lcd_bl,
				lcd_rst_n        => lcd_rst_n

			);
	end block Components;
	Num9 : entity work.big9(syn)
		port map(
			address => std_logic_vector(to_unsigned(n9_addr, 14)),
			clock   => clk,
			q       => n9_data_i
		);
	n9_data <= unsigned(n9_data_i);
	msi_icon_inst : entity work.msi_icon(syn)
		port map(
			address => std_logic_vector(to_unsigned(msi_addr, 15)),
			clock   => clk,
			q       => msi_data_i
		);
	msi_data <= unsigned(msi_data_i);
	Main_process : block begin
		process (clk, rst_n)
		begin
			if rst_n = '0' then
				font_start <= '0';
				x <= 0;
				y <= 0;
				l_clear <= '1';
				-- bg_color <= white;
				key_times <= 0;
				text_data <= (others => character'val(32));
			elsif rising_edge(clk) then

				case key is
					when 8 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_mirror(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 0, 128, 128);
					when 9 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_mirror(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 1, 128, 128);
					when 10 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_mirror(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 2, 128, 128);
					when 11 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_mirror(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 3, 128, 128);
					when 12 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_rotate(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 0, 128, 128);
					when 13 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_rotate(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 1, 128, 128);

					when 14 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_rotate(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 2, 128, 128);

					when 15 =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_rotate(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 3, 128, 128);
					when others =>
						bg_color <= to_data(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128));
						n9_addr <= l_rotate(to_addr(l_paste(l_addr, blue, l_map(n9_data, black, magenta), (0, 0), 128, 128)), 0, 128, 128);

				end case;

			end if;
		end process;
	end block Main_process;
end arch;
