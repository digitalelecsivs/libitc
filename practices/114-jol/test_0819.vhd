library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

use work.itc_lcd.all;

entity test_0819 is
	port (
		clk, rst_n                                              : in std_logic;
		seg_led, seg_com                                        : out u8r_t; -- seg
		key_row                                                 : in u4r_t;  --key
		key_col                                                 : out u4r_t;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic -- lcd
	);
end test_0819;

architecture arch of test_0819 is
	signal pressed_i : std_logic := '0';
	signal pressed : std_logic := '0';
	signal key : integer range 0 to 15;
	signal seg_data : string(1 to 8) := (others => ' ');

	signal seg_cnt : integer range 0 to 100000;
	signal f_i : std_logic := '0';
	signal f : std_logic := '0';
	signal key_temp : integer range 0 to 15;
	signal x_addr : l_addr_t;
	signal x_data : l_px_t;
	signal x_data_i : std_logic_vector(23 downto 0);

	signal ena_tim : std_logic := '0';
	signal msec : integer range 0 to 5000 := 0;
	--lcd
	signal l_addr : l_addr_t;
	signal x : integer range -127 to 127 := 0;
	signal y : integer range -159 to 159 := 0;
	signal font_start, font_busy, font_busy_i, l_clear : std_logic;
	signal text_data : string(1 to 12) := (others => character'val(32));
	signal text_size : integer range 1 to 12;
	signal text_color_array : l_px_arr_t(1 to 12) := (others => blue);
	signal bg_color : l_px_t;
	signal font_mode : integer range 0 to 2 := 0;

begin
	components : block begin
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
		seg_inst : entity work.seg(arch)--8bit七段顯示器元件
			port map(
				clk     => clk,
				rst_n   => rst_n,
				seg_led => seg_led,
				seg_com => seg_com,
				data    => seg_data,
				dot => (others => '0')
			);
		clk_inst : entity work.clk(arch)
			generic map(
				freq => 1
			)
			port map(
				clk_in  => clk,
				rst_n   => rst_n,
				clk_out => f_i
			);
		edge_inst : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => f_i,
				rising  => f,
				falling => open
			);
		lcd_mix_inst : entity work.lcd_mix_intgr_aph(arch)
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
		timer_inst : entity work.timer(arch)--計時器
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena_tim,
				load  => 0,
				msec  => msec
			);
	end block components;

	xilinx_pic : entity work.xilinx(syn)
		port map(
			address => std_logic_vector(to_unsigned(x_addr, 15)),
			clock   => clk,
			q       => x_data_i
		);
	x_data <= unsigned(x_data_i);

	Main_Process : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				-- seg_data <= (others => ' ');
				--lcd
				l_clear <= '1';
				bg_color <= white;
				-- txt_cnt <= 0;
				ena_tim <= '1';
			elsif rising_edge(clk) then
				if msec > 1000 then
					l_clear <= '1';
					bg_color <= to_data(l_paste(l_addr, white, x_data, (0, 0), 128, 160));
					x_addr <= to_addr(l_paste(l_addr, white, x_data, (0, 0), 128, 160));
				end if;

				if f = '1' then
					if seg_cnt = seg_cnt'high then
						seg_cnt <= 0;
					else
						seg_cnt <= seg_cnt + 1;
					end if;
				end if;
				if pressed = '1' then
					key_temp <= key;
				end if;
			end if;
		end process;
		seg_data <= to_string(key_temp, key_temp'high, 10, 2) & to_string(seg_cnt, seg_cnt'high, 10, 6);
	end block Main_Process;
end arch;
