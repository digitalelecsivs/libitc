library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity txt_lcd_mix_font_num is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end txt_lcd_mix_font_num;

architecture arch of txt_lcd_mix_font_num is
	signal l_addr, msi_addr : l_addr_t;
	signal l_data : l_px_t;
	signal msi_data_i : std_logic_vector(23 downto 0);
	signal msi_data : l_px_t;
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_mode : integer range 0 to 2;
	signal text_size : integer range 1 to 12;
	signal bg_color : l_px_t;
	-- signal 

	type state is (font_1, font_2, font_3, init);
	signal mode : state := font_1;
	signal font_start, font_busy_i, l_clear : std_logic;
	signal font_busy : std_logic;
	signal pic_data : l_px_t;
	signal msec : integer range 0 to 500;
	signal ena_tim : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(32));
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : i4_t;
	type str_array is array(integer range <>) of string(1 to 8);
	signal data_set : str_array(0 to 7) := ("abcdefgh", "01234567", "ABCDEFGH", "00000000", "98765432", "00000000", "00000000", "00000000");
	signal txt_cnt : integer range 0 to 15;
	signal trigger_i : std_logic;
	signal trigger : std_logic;
	signal cnt : integer range 0 to 999 := 0;
	signal mode_state : std_logic_vector(0 to 2);
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 10
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => trigger_i
		);
	edge_trig : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => trigger_i,
			rising  => trigger,
			falling => open
		);
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
			text_size        => text_size,
			text_data        => text_data,
			font_mode        => font_mode,
			addr             => l_addr,
			bg_color         => bg_color,
			text_color_array => (others => blue),
			clear            => l_clear,

			lcd_sclk  => lcd_sclk,
			lcd_mosi  => lcd_mosi,
			lcd_ss_n  => lcd_ss_n,
			lcd_dc    => lcd_dc,
			lcd_bl    => lcd_bl,
			lcd_rst_n => lcd_rst_n
		);
	Num1 : entity work.msi_icon(syn)
		port map(
			address => std_logic_vector(to_unsigned(msi_addr, 15)),
			clock   => clk,
			q       => msi_data_i
		);
	msi_data <= unsigned(msi_data_i);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			font_start <= '0';
			x <= 0;
			y <= 0;
			l_clear <= '1';
			bg_color <= white;
			ena_tim <= '1';
			text_data <= (others => character'val(32));
			cnt <= 0;
		elsif rising_edge(clk) then
			if trigger = '1' then
				if cnt = cnt'high then
					cnt <= 0;
				else
					cnt <= cnt + 1;
				end if;
			end if;
			case mode is
				when init =>
					l_clear <= '1';
					bg_color <= white;
					ena_tim <= '1';
					if msec > 50 then
						ena_tim <= '0';
						if mode_state = "100" then
							mode <= font_2;
						elsif mode_state = "010" then
							mode <= font_3;
						elsif mode_state = "001" then
							mode <= font_1;
						end if;
					end if;
				when font_1 =>
					font_mode <= 0;
					if msec >= 20 then
						ena_tim <= '0';
						l_clear <= '0';
						font_start <= '1';
					end if;
					-- bg_color <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
					-- msi_addr <= to_addr(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
					for i in 0 to 4 loop
						if i >= 0 and i < 2 then
							if txt_cnt = i then
								x <= 0;
								y <= 16 * i;
								text_data(1 to 3) <= to_string(cnt, cnt'high, 10, 3);
								text_data(4 to 12) <= (others => character'val(32));
								text_size <= 1;
								font_start <= '1';
							end if;
						elsif i <= 2 and i < 3 then
							if txt_cnt = i then
								x <= 0;
								y <= 32 * i - 16 * 2;
								text_data(1 to 3) <= to_string(cnt, cnt'high, 10, 3);
								text_data(4 to 12) <= (others => character'val(32));

								text_size <= 2;
								font_start <= '1';
							end if;
						elsif i <= 3 and i < 5 then
							if txt_cnt = i then
								x <= 0;
								y <= 64 * i - 32 * 3 - 16 * 2;
								text_data(1 to 3) <= to_string(cnt, cnt'high, 10, 3);
								text_data(4 to 12) <= (others => character'val(32));

								text_size <= 3;
								font_start <= '1';
							end if;

						end if;
					end loop;

					if font_busy = '1' then
						font_start <= '0';
						if txt_cnt <= 4 then
							txt_cnt <= txt_cnt + 1;
						else
							txt_cnt <= 0;
						end if;
						ena_tim <= '1';
					end if;
					if pressed = '1' then
						mode_state <= "100";
						mode <= init;
					end if;
				when font_2 =>
					font_mode <= 1;
					if msec >= 20 then
						ena_tim <= '0';
						l_clear <= '0';
						font_start <= '1';
					end if;
					-- bg_color <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
					-- msi_addr <= to_addr(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));

					for i in 0 to 2 loop
						if txt_cnt = i then
							x <= 8;
							y <= 53 * i;
							text_data(1 to 3) <= to_string(cnt, cnt'high, 10, 3);
							font_start <= '1';
						end if;
					end loop;

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
						mode_state <= "010";
						mode <= init;
					end if;
				when font_3 =>
					font_mode <= 2;
					if msec >= 20 then
						ena_tim <= '0';
						l_clear <= '0';
						font_start <= '1';
					end if;
					bg_color <= to_data(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));
					msi_addr <= to_addr(l_paste(l_addr, white, msi_data, (0, 0), 128, 160));

					for i in 0 to 2 loop
						if txt_cnt = i then
							x <= 0;
							y <= 53 * i;
							text_data(1 to 4) <= to_string(cnt, cnt'high, 10, 4);
							font_start <= '1';
						end if;
					end loop;

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
						mode_state <= "001";
						mode <= init;
					end if;
			end case;

		end if;
	end process;
end arch;
