library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;

entity led_matrix_decoder is
	port (
		qty_order01 : in integer range 0 to 99; -- 訂單 01 OQ
		qty_order02 : in integer range 0 to 99; -- 訂單 02 OQ
		sq_order01  : in integer range 0 to 99; -- 訂單 01 SQ
		sq_order02  : in integer range 0 to 99; -- 訂單 02 SQ
		current_id  : in integer range 0 to 2;  -- 當前編輯 ID (1: 訂單01, 2: 訂單02, 0: 一般)
		blink_on    : in std_logic;             -- 閃爍訊號 (1: 亮, 0: 暗)
		rgb_arr     : out l_px_arr_t(0 to 63)   -- 輸出給 WS2812 的陣列
	);
end led_matrix_decoder;

architecture arch of led_matrix_decoder is
	constant COLOR_OFF : l_px_t := x"000000";
	constant COLOR_RED : l_px_t := x"00FF00";
	constant COLOR_GREEN : l_px_t := x"FF0000";

	-- 輔助程序：將傳入的參數型別改為 variable，並使用 variable 賦值 (:=)
	procedure draw_col(
		variable arr : inout l_px_arr_t(0 to 63);
		col_offset   : in integer;
		val          : in integer
	) is
		variable tens, ones : integer;
		variable idx : integer;
	begin
		tens := val / 10;
		ones := val rem 10;

		-- [十位數] 點亮紅色 LED
		for r in 0 to 7 loop
			if r < tens then
				idx := r * 8 + col_offset;
				arr(idx) := COLOR_RED; -- 注意：Variable 使用 := 賦值
			end if;
		end loop;

		-- [個位數] 若不為零，加亮 1 顆綠色 LED
		if ones /= 0 and tens < 8 then
			idx := tens * 8 + col_offset;
			arr(idx) := COLOR_GREEN; -- 注意：Variable 使用 := 賦值
		end if;
	end procedure;

begin
	process (qty_order01, qty_order02, sq_order01, sq_order02, current_id, blink_on)
		variable temp_arr : l_px_arr_t(0 to 63);
	begin
		temp_arr := (others => COLOR_OFF);

		------------------------------------------------------------------
		-- 1. 繪製 SQ 配額行 (恆亮)
		-- 訂單 01 SQ 映射於第 2 行 (offset 6)
		-- 訂單 02 SQ 映射於第 5 行 (offset 3)
		------------------------------------------------------------------
		draw_col(temp_arr, 6, sq_order01);
		draw_col(temp_arr, 3, sq_order02);

		------------------------------------------------------------------
		-- 2. 繪製 OQ 訂購數量行 (編輯狀態下該 OQ 行隨 blink_on 閃爍)
		-- 訂單 01 OQ 映射於第 1 行 (offset 7)
		-- 訂單 02 OQ 映射於第 4 行 (offset 4)
		------------------------------------------------------------------
		if current_id /= 1 or blink_on = '1' then
			draw_col(temp_arr, 7, qty_order01);
		end if;

		if current_id /= 2 or blink_on = '1' then
			draw_col(temp_arr, 4, qty_order02);
		end if;

		rgb_arr <= temp_arr;
	end process;
end arch;
