library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

-- 模組名稱：lcd_mix (Advanced Numeric Display)
-- 移除了 text_size
entity lcd_mix is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user
		x                : in integer range -127 to 127; -- 字串 X 起始座標
		y                : in integer range -159 to 159; -- 字串 Y 起始座標
		font_start       : in std_logic;                 -- 開始繪製文字
		font_busy        : out std_logic;                -- 繪製中
		text_data        : in string(1 to 12);           -- 要顯示的字串
		addr             : out l_addr_t;                 -- VRAM 位址 (用於圖片模式)
		bg_color         : in l_px_t;                    -- 背景色 (或圖片資料)
		text_color_array : in l_px_arr_t(1 to 12);       -- 每個字元的顏色
		clear            : in std_logic;                 -- '1'=圖片/清除, '0'=文字
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
	signal q : std_logic_vector(0 downto 0);

	type status_t is (idle, draw, clear_screen);
	signal status : status_t;
	-- 更新的計數器範圍以匹配 32x53 字模
	signal data_y : integer range 0 to 52; -- 0 to 52 (共 53 列)
	signal data_x : integer range 0 to 31; -- 0 to 31 (共 32 行)

	signal first_px : l_addr_t;
	signal count : integer range 0 to 11; -- 0 to 11 (共 12 個字元)

	-- 新增：錯誤處理訊號
	-- 當字元不是 '0'-'9' 時，此訊號為 '1'
	signal is_invisible : std_logic;

begin
	-- 'font_start' 的邊緣偵測器
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_start,
			rising  => start_draw,
			falling => open
		);

	-- LCD 底層驅動
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

	-- 實體化您的 Font_Numeric ROM (16960 x 1 bit)
	Font_Numeric_inst : entity work.Font_numeric(syn)
		port map(
			address => std_logic_vector(to_unsigned(l_addr_p, 15)),
			clock   => clk,
			q       => q
		);

	process (clk, rst_n)
		-- 變數：用於在單一時脈週期內計算 VRAM 位址和裁剪
		variable X_pos_v : integer;
		variable Y_pos_v : integer;
	begin
		-- 像素混合器
		-- *** 已更新：加入了 is_invisible 邏輯 ***
		-- 如果 (q=1) OR (正在清除) OR (字元為非數字)
		-- 則輸出背景色
		if q = "1" or status = clear_screen or is_invisible = '1' then
			l_data <= bg_color;
		else
			l_data <= color;
		end if;

		if rst_n = '0' then
			wr_ena <= '0';
			status <= clear_screen;
			count <= 0;
			data_x <= 0;
			data_y <= 0;
			addr <= 0;
			l_addr <= 0;
			font_busy <= '0';
			color <= (others => '0');

		elsif rising_edge(clk) then
			case status is
				when idle =>
					font_busy <= '0';
					wr_ena <= '0';
					if start_draw = '1' and clear = '0' then
						font_busy <= '1';
						status <= draw;
						-- 重置所有計數器
						count <= 0;
						data_x <= 0;
						data_y <= 0;
						-- 取得第一個字元的顏色
						color <= text_color_array(1);

					elsif clear = '1' then
						wr_ena <= '1';
						font_busy <= '1';
						addr <= 0;
						status <= clear_screen;
					end if;

				when draw =>
					if (clear = '1') then
						status <= clear_screen;
						font_busy <= '0';
						wr_ena <= '0';
					else
						-- 1. 計算 VRAM 位址和顏色
						-- (字元間距已改為 32)
						X_pos_v := data_x + x + (count * 40);
						Y_pos_v := data_y + y;

						-- 簡化的 VRAM 位址公式 (已移除 text_size)
						l_addr <= X_pos_v + 128 * Y_pos_v;
						color <= text_color_array(count + 1);

						-- 2. 裁剪邏輯
						if (X_pos_v > 127) or (Y_pos_v > 159) or (Y_pos_v < 0) or (X_pos_v < 0) then
							wr_ena <= '0';
						else
							wr_ena <= '1';
						end if;

						-- 3. 更新計數器 (3 層迴圈)
						if data_x + 1 = 32 then -- L3: 迴圈 32 次 (0 to 31)
							data_x <= 0;
							if data_y + 1 = 53 then -- L2: 迴圈 53 次 (0 to 52)
								data_y <= 0;
								if count = 11 then -- L1: 已跑完 12 個字元
									status <= idle;
									count <= 0;
									wr_ena <= '0';
									font_busy <= '0';
								else
									count <= count + 1; -- L1: 推進
								end if;
							else
								data_y <= data_y + 1; -- L2: 推進
							end if;
						else
							data_x <= data_x + 1; -- L3: 推進
						end if;
					end if;

				when clear_screen =>
					font_busy <= '1';
					wr_ena <= '1';
					if addr = addr'high then
						addr <= 0;
						font_busy <= '0';
						status <= idle;
						wr_ena <= '0';
					else
						addr <= addr + 1;
					end if;
					l_addr <= addr;

				when others =>
					status <= idle;
			end case;
		end if;
	end process;

	-- ROM 位址公式：Row-Major 佈局
	-- (10 個數字 * 32 像素寬 = 320 像素的 "大橫排" 寬度)
	l_addr_p <= 320 * data_y + data_x + first_px;

	-- 字元偏移公式：
	-- (ASCII '0' 是 48)
	-- 0 -> (48-48)*32 = 0
	-- 1 -> (49-48)*32 = 32
	-- ...
	-- 9 -> (57-48)*32 = 288
	first_px <= 95 when character'pos(text_data(count + 1)) - 48 = 3 else (character'pos(text_data(count + 1)) - 48) * 32;

	-- *** 新增：錯誤處理邏輯 ***
	-- 檢查當前 'count' 指向的字元
	-- ASCII '0' = 48
	-- ASCII '9' = 57
	is_invisible <= '1' when (character'pos(text_data(count + 1)) < 48) or (character'pos(text_data(count + 1)) > 57) else
		'0';

end arch;
