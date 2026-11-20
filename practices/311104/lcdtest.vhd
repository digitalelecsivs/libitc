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
		js_scl  : inout std_logic;
		js_sda  : inout std_logic;
		key_row : in unsigned(0 to 2);
		key_col : out unsigned(0 to 2)
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
	signal text_data : string(1 to 12) := (others => character'val(32)); -- 20
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
	signal key : integer range 0 to 2 ** 3 + 1;
	signal key_times : integer range 0 to 12;
	signal pos_x : integer range -127 to 127 := 50;
	signal pos_y : integer range -159 to 159 := 30;

--------------------------------------------------------------------------------

	signal x_raw, y_raw : u16_t;
	signal x_latest, y_latest : u16_t := (others => '0');
	signal x_disp, y_disp : u16_t := (others => '0');
	signal data_valid : std_logic;
	signal data_valid_r : std_logic := '0';

	-- 降頻計時器 (500ms，每秒更新 2 次)
	constant UPDATE_LIMIT : integer := sys_clk_freq / 2;
	signal update_cnt : integer range 0 to UPDATE_LIMIT := 0;

--------------------------------------------------------------------------------
	component ads_js_ctrl is
		port (
			clk        : in std_logic;
			rst_n      : in std_logic;
			scl        : inout std_logic;
			sda        : inout std_logic;
			x_raw      : out u16_t;
			y_raw      : out u16_t;
			data_valid : out std_logic
		);
	end component;

begin
	u_ads : ads_js_ctrl
	port map(
		clk        => clk,
		rst_n      => rst_n,
		scl        => js_scl,
		sda        => js_sda,
		x_raw      => x_raw,
		y_raw      => y_raw,
		data_valid => data_valid
	);
	Components : block begin
		edge_inst1 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy_i,
				rising  => open,
				falling => font_busy
			);
	
		-- key_inst : entity work.key(arch)
		-- 	port map(
		-- 		clk     => clk,
		-- 		rst_n   => rst_n,
		-- 		key_row => key_row,
		-- 		key_col => key_col,
		-- 		pressed => pressed_i,
		-- 		key     => key
		-- 	);

		key_inst : entity work.key_3x3(arch)
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
	Bird1 : entity work.ii(syn)
		port map(
			address => std_logic_vector(to_unsigned(msi_addr, 12)),
			clock   => clk,
			q       => msi_data_i
		);
	msi_data <= unsigned(msi_data_i);
	Bird2 : entity work.bb(syn)
		port map(
			address => std_logic_vector(to_unsigned(n0_addr, 12)),
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

						pic(0) := to_data(l_paste(l_addr, white, n0_data, (pos_x, pos_y), 64, 64));
						n0_addr <= to_addr(l_paste(l_addr, white, n0_data, (pos_x, pos_y), 64, 64));
						if pressed = '1' then
							case key is
								when 0 =>
									if pos_y <= - 3 or pos_x <= - 5 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x - 10;
										pos_y <= pos_y - 10;
									end if;
								when 1 =>
									if pos_x <= - 5 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x - 10;
									end if;
								when 2 =>
									if pos_y >= 65 or pos_x <= - 5 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x - 10;
										pos_y <= pos_y + 10;
									end if;
								when 3 =>
									if pos_y <= - 3 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_y <= pos_y - 10;
									end if;
								when 4 =>
									pos_x <= 50;
									pos_y <= 30;
								when 5 =>
									if pos_y >= 65 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_y <= pos_y + 10;
									end if;
								when 6 =>
									if pos_y <= - 3 or pos_x >= 95 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x + 10;
										pos_y <= pos_y - 10;
									end if;
								when 7 =>
									if pos_x >= 95 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x + 10;
									end if;
								when 8 =>
									if pos_x >= 95 or pos_y >= 65 then
										pos_x <= pos_x;
										pos_y <= pos_y;
									else
										pos_x <= pos_x + 10;
										pos_y <= pos_y + 10;
									end if;
								when others => null;
							end case;
						end if;
					when pic2 =>
				end case;
			end if;
		end process;
	end block Main_process;
end arch;
