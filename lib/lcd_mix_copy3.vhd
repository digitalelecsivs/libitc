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
		x                : in integer range -127 to 127; --圖片或文字的起始位置 --x
		y                : in integer range -159 to 159; --圖片或文字的起始位置 --y
		font_start       : in std_logic;                 --使文字開始刷新的sig --font_start
		font_busy        : out std_logic;                --lcd的忙碌線 --font_busy_i
		text_size        : in integer range 1 to 12;     --選擇字型大小 --text_size
		text_data        : in string(1 to 12);           --文字資料 --text_data 
		font_sel		 : in integer range 1 to 2;		 --字模選擇
		addr             : out l_addr_t; --現在lcd掃描到的位置 --l_addr
		text_color       : in l_px_t;	--
		bg_color         : in l_px_t; --背景顏色或圖片資料
		text_color_array : in l_px_arr_t(1 to 12);
		clear            : in std_logic; -- 模式控制: '0'=文字, '1'=圖片/清除
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic-- 實際輸出實體化的腳位
	);
end lcd_mix;

architecture arch of lcd_mix is
	signal color : l_px_t;
	signal wr_ena : std_logic;
	signal start_draw : std_logic;
	signal l_addr, l_addr_p : l_addr_t;
	signal l_data : l_px_t;
	signal q : std_logic_vector(0 downto 0);

	-- 狀態機： 'draw_picture' 狀態已被移除
	type status_t is (idle, draw_txt_txt, clear_screen);
	signal status : status_t;

	signal p_count : integer range 0 to 20;
	signal data_y, data_x : integer range 0 to 20;
	signal lcd_x : integer range -5 to 127;
	signal lcd_y : integer range -5 to 159;
	signal first_px : l_addr_t;
	signal count : integer range 0 to 10;
	signal pixel_count_x, pixel_count_y : integer range 0 to 12;
	signal l_data_i : std_logic_vector(23 downto 0);

begin
	
	edge_inst : entity work.edge(arch)-- 'font_start' 的邊緣偵測器
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_start,
			rising  => start_draw,
			falling => open
		); 
	lcd_inst : entity work.lcd(arch)-- LCD 底層驅動
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

	Font_inst : entity work.Font(syn)-- 字型 ROM
		port map(
			address => std_logic_vector(to_unsigned(l_addr_p, 15)),
			clock   => clk,
			q       => q
		);
	process (clk, rst_n)
	begin
		-- 像素混合器： 'con' 邏輯已移除並簡化
		-- 'status = clear_screen' 時，會強制 l_data <= bg_color
		-- 這現在同時處理「清除畫面」和「顯示圖片」
		if q = "1" or status = clear_screen then
			l_data <= bg_color;
		else
			l_data <= color; -- 若要改為使用單行顏色直接更改=>將color改成text_color即可
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

			if character'pos(text_data(count + 1)) = 87 then
				lcd_x <= 1;
			else
				lcd_x <= 0;
			end if;

			case status is
				when idle =>
					if start_draw = '1' and clear = '0' then
						p_count <= text_data'length;
						wr_ena <= '1';
						font_busy <= '1';
						lcd_x <= x;
						lcd_y <= y;
						status <= draw_txt;
					elsif clear = '1' then
						wr_ena <= '1';
						font_busy <= '1';
						addr <= 0;
						status <= clear_screen;
					else
						wr_ena <= '0';
						font_busy <= '0';
					end if;

				when draw_txt =>

					if (clear = '1') then
						status <= clear_screen;
					elsif (pixel_count_x < text_size) then
						if pixel_count_y < text_size then
							pixel_count_y <= pixel_count_y + 1;
							l_addr <= data_x * text_size + pixel_count_x + x + 128 * (data_y * text_size + pixel_count_y + y) + (count * 10 * text_size);
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

					-- 裁剪 (Clipping) 邏輯 (保留)
					if ((data_x * text_size + pixel_count_x + x + (count * 10 * text_size)) > 127) or
						((data_y * text_size + pixel_count_y + y) > 159) or
						((data_y * text_size + pixel_count_y + y) < 0) or
						((data_x * text_size + pixel_count_x + x + (count * 10 * text_size)) < 0) then
						wr_ena <= '0';
					else
						wr_ena <= '1';
					end if;

				when clear_screen =>
					-- 此狀態現在用於「清除」或「顯示圖片」
					-- 它會掃描整個 VRAM，addr 會從 0 跑到 addr'high
					font_busy <= '1';
					if addr = addr'high then
						addr <= 0;
						font_busy <= '0';
						status <= idle;
					else
						addr <= addr + 1;
					end if;
					l_addr <= addr;

					-- 'draw_picture' 狀態已移除

				when others =>
					status <= idle;
			end case;
		end if;
	end process;

	l_addr_p <= 1056 * data_y + data_x + first_px;
	first_px <= 950 when (text_data(count + 1) = 'd') and (text_data(count + 2) = 'C') else (character'pos(text_data(count + 1)) - 32) * 10 + lcd_x;

end arch;
