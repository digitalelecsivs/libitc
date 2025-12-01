library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity pic_paste is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end pic_paste;

architecture arch of pic_paste is
	signal l_addr : l_addr_t;
	signal msi_addr, n0_addr : l_addr_t;
	signal msi_data_i, n0_data_i : std_logic_vector(23 downto 0);
	signal msi_data, n0_data : l_px_t;
	signal x : integer range -127 to 127 := 30;
	signal y : integer range -159 to 159 := 30;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(20));
	signal bg_color : l_px_t;
	signal text_size : integer range 1 to 12;
	signal font_mode : integer range 0 to 2;
	type state is (pic1, pic2);
	signal mode : state := pic1;

	--timer
	signal msec : integer range 0 to 500;
	signal ena_tim : std_logic;
	--keyboard
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : i4_t;
	signal key_times : integer range 0 to 12;
	signal pos_x : integer range -127 to 127 := 30;
	signal pos_y : integer range -159 to 159 := 30;
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
				clk        => clk,
				rst_n      => rst_n,
				x          => x,
				y          => y,
				font_start => font_start,
				font_busy  => font_busy_i,
				text_size  => text_size,
				text_data  => text_data,
				font_mode  => font_mode,
				addr       => l_addr,
				bg_color   => bg_color,
				text_color_array => (others => blue),
				clear      => l_clear,
				lcd_sclk   => lcd_sclk,
				lcd_mosi   => lcd_mosi,
				lcd_ss_n   => lcd_ss_n,
				lcd_dc     => lcd_dc,
				lcd_bl     => lcd_bl,
				lcd_rst_n  => lcd_rst_n
			);
	end block Components;
	msi_icon_inst : entity work.msi_icon(syn)
		port map(
			address => std_logic_vector(to_unsigned(msi_addr, 15)),
			clock   => clk,
			q       => msi_data_i
		);
	msi_data <= unsigned(msi_data_i);
	num0 : entity work.n0(syn)
		port map(
			address => std_logic_vector(to_unsigned(n0_addr, 10)),
			clock   => clk,
			q       => n0_data_i
		);
	n0_data <= unsigned(n0_data_i);

	Main_process : block begin
		process (clk, rst_n)
			variable pic : l_px_arr_t(0 to 5);
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
				case mode is
					when pic1 =>
						l_clear <= '1';
						bg_color <= pic(0);

						pic(0) := to_data(l_paste(l_addr, msi_data, l_map(n0_data, white, msi_data), (pos_x, pos_y), 32, 32));
						msi_addr <= to_addr(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
						n0_addr <= to_addr(l_paste(l_addr, msi_data, n0_data, (pos_x, pos_y), 32, 32));

						if pressed = '1' then
							case key is
								when 5 =>
									pos_x <= pos_x - 10;
								when 8 =>
									pos_y <= pos_y - 10;
								when 9 =>
									pos_x <= pos_x + 10;
								when 10 =>
									pos_y <= pos_y + 10;
								when others => null;

							end case;
						end if;
					when pic2 =>

				end case;
			end if;
		end process;
	end block Main_process;
end arch;
