library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_mix is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user
		x                : in integer range -127 to 127;
		y                : in integer range -159 to 159;
		font_start       : in std_logic;
		font_busy        : out std_logic;
		text_size        : in integer range 1 to 12;
		text_data        : in string(1 to 12);
		text_count       : out integer range 1 to 12;
		addr             : out l_addr_t;
		text_color       : in l_px_t;
		bg_color         : in l_px_t;
		text_color_array : in l_px_arr_t(1 to 12);
		clear            : in std_logic;
		con              : in std_logic;
		pic_addr         : out l_addr_t;
		pic_data         : in l_px_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end lcd_mix;

architecture arch of lcd_mix is
	signal color : l_px_t;
	signal wr_ena : std_logic;
	signal start_draw : std_logic;
	signal l_addr, l_addr_p : l_addr_t;
	signal l_data : l_px_t;
	-- signal wr_ena : std_logic;
	signal q : std_logic_vector(0 downto 0);
	type status_t is (idle, draw, clear_screen, draw_picture);
	signal status : status_t;
	signal p_count : integer range 0 to 20;
	signal data_y, data_x : integer range 0 to 20;
	signal lcd_x : integer range -5 to 127;
	signal lcd_y : integer range -5 to 159;
	signal first_px : l_addr_t;
	signal count : integer range 0 to 10;
	signal pixel_count_x, pixel_count_y : integer range 0 to 12;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal con_h, con_l : std_logic;

	--constant aa : l_px_arr_t(1 to 12) := (null, red, null, red, null, red, null, green, null, green, null, null); --單行顏色(12位元)
begin
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_start,
			rising  => start_draw,
			falling => open
		);
	edge_inst_con : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => con,
			rising  => con_h,
			falling => con_l
		);
	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n,
			brightness => 100,
			wr_ena     => wr_ena,
			addr       => l_addr,
			data       => l_data
		);
	Font_inst : entity work.Font(syn)
		port map(
			address => std_logic_vector(to_unsigned(l_addr_p, 15)),
			clock   => clk,
			q       => q
		);
	-- bongo_inst : entity work.bongo(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(l_addr, 15)),
	-- 		clock   => clk,
	-- 		q       => l_data_i
	-- 	);
	process (clk, rst_n)
	begin
		if con = '0' then
			if q = "1" or status = clear_screen then
				l_data <= bg_color;
			else
				l_data <= color; -- 若要改為使用單行顏色直接更改=>將color改成text_color即可
			end if;
		elsif con = '1' then
			l_data <= pic_data;
		end if;
		if rst_n = '0' then
			wr_ena <= '0';
			status <= clear_screen;
			count <= 0;
			data_x <= 0;
			data_y <= 0;
			addr <= 0;
			l_addr <= 0;
		elsif rising_edge(clk) then
			if con_h = '1' or con_l = '1' then
				l_addr <= 0;
				-- pic_addr <= 0;
			end if;
			-- if con = '0' then --文字
			if character'pos(text_data(count + 1)) = 87 then
				lcd_x <= 1;
			else
				lcd_x <= 0;
			end if;
			case status is
				when idle =>
					if start_draw = '1' and con = '0' and clear = '0' then
						p_count <= text_data'length;
						wr_ena <= '1';
						font_busy <= '1';
						lcd_x <= x;
						lcd_y <= y;
						status <= draw;
					elsif con = '1' and clear = '0' then
						wr_ena <= '1';
						font_busy <= '1';
						addr <= 0;
						status <= draw_picture;
					elsif clear = '1' then
						wr_ena <= '1';
						font_busy <= '1';
						addr <= 0;
						status <= clear_screen;
					else
						wr_ena <= '0';
						font_busy <= '0';
					end if;
				when draw =>
					if (clear = '1') then
						status <= clear_screen;
					elsif (pixel_count_x < text_size) then
						if pixel_count_y < text_size then
							pixel_count_y <= pixel_count_y + 1;
							-- if under_line='1' then
							-- 	l_addr <= data_x * text_size + pixel_count_x + x + 128 * (data_y+2 * text_size + pixel_count_y + y ) + (count * 11 * text_size);
							-- else
							l_addr <= data_x * text_size + pixel_count_x + x + 128 * (data_y * text_size + pixel_count_y + y) + (count * 10 * text_size);
							-- end if;
						else
							pixel_count_y <= 0;
							pixel_count_x <= pixel_count_x + 1;
						end if;
					else
						pixel_count_x <= 0;
						if data_x + 1 = 11 then
							data_x <= 0;
							if data_y + 1 = 20 then
								data_y <= 0;
								if count = text_data'length - 1 then
									status <= idle;
									count <= 0;
									data_x <= 0;
									data_y <= 0;
								else
									count <= count + 1;
								end if;
							else
								data_y <= data_y + 1;
							end if;
						else
							data_x <= data_x + 1;
						end if;
						color <= text_color_array(count + 1); -- 依位元改變對應顏色										
					end if;
					-- if ((data_x * text_size + text_count + x + (count * 10 * text_size)) > 127) or ((data_y * text_size + text_count + y) > 159) or ((data_y * text_size + text_count + y) < 0) or (data_x * text_size + text_count + x + (count * 10)) < 0 then
					if ((data_x * text_size + text_count + x + (count * 10 * text_size)) > 150) or ((data_y * text_size + text_count + y) > 159) or ((data_y * text_size + text_count + y) < 0) or (data_x * text_size + text_count + x + (count * 10)) < 0 then
						wr_ena <= '0';
					else
						wr_ena <= '1';
					end if;

				when clear_screen =>
					font_busy <= '1';
					if addr = addr'high then
						addr <= 0;
						font_busy <= '0';
						status <= idle;
					else
						addr <= addr + 1;
					end if;
					l_addr <= addr;
				when draw_picture =>
					l_addr <= addr;
					if addr < addr'high then
						if wr_ena = '0' then
							wr_ena <= '1';
						else
							font_busy <= '1';
							wr_ena <= '0';
							addr <= addr + 1;
						end if;
					else
						font_busy <= '0';
						wr_ena <= '0';
						status <= idle;
					end if;
				when others =>
					status <= idle;
			end case;
			-- elsif con = '1' then --圖片
			-- 	l_addr <= addr;
			-- 	if addr < l_px_cnt - 1 then
			-- 		if wr_ena = '0' then
			-- 			wr_ena <= '1';
			-- 		else
			-- 			font_busy <= '1';
			-- 			wr_ena <= '0';
			-- 			addr <= addr + 1;
			-- 		end if;
			-- 	else
			-- 		font_busy <= '0';
			-- 		wr_ena <= '0';
			-- 	end if;
			-- end if;
		end if;
	end process;
	l_addr_p <= 1056 * data_y + data_x + first_px;
	text_count <= count + 1;
	first_px <= 950 when (text_data(count + 1) = 'd') and (text_data(count + 2) = 'C') else (character'pos(text_data(count + 1)) - 32) * 10 + lcd_x;
	-- l_addr <= 128 * (data_y + y) + data_x + x - 2 + (count * 11) when status /= clear_screen else addr;
	--l_addr <= data_x * text_size + d + x + 128 * (data_y * text_size + d + y) + (count * 11);
end arch;
