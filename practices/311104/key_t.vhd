----------------------------------------------------------------------------
--測試七段顯示器與按鍵與DIP SW
--(1)使用seg_ch.vhd元件時，只能固定顯示0~9的數字，按任一鍵即顯示，由左而右。
--(2)使用seg.vhd元件時，可顯示鍵盤數字01、02 一直到08，由左而右串聯顯示。
--	 顯示的數字由鍵盤數字決定，2X2鍵盤0~3，按鍵0顯示0，按鍵1顯示1，按鍵2顯示2，按鍵3顯示3。
--   3X3鍵盤0~8，按鍵0顯示0，按鍵1顯示1，按鍵2顯示2，按鍵3顯示3，按鍵4顯示4，按鍵5顯示5，按鍵6顯示6，按鍵7顯示7，按鍵8顯示8。
--(3)dbg_a(0 to 7)顯示key值，dbg_b(0 to 7)顯示SW值，按鍵按下時才更新。
--115.10.12  by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity key_t is
	port (
		clk              : in std_logic;
		rst_n            : in std_logic;
		key_row          : in unsigned(0 to 2);
		key_col          : out unsigned(0 to 2);
		sw               : in u8r_t;
		seg_led, seg_com : out u8r_t; -- seg
		dbg_a            : out u8r_t;
		dbg_b            : out u8r_t
	);
end key_t;

architecture arch of key_t is
	-- key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 9;
	signal seg_data : string(1 to 8) := (others => ' ');
begin
	seg_inst : entity work.seg(arch) -- 8bit七段顯示器元件
		generic map(
			common_anode => '0' -- 在這裡明確指明為共陰極 '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0') -- '0'小數點不亮 , '1'亮
		);

	key_inst : entity work.key_3x3(arch)
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

	process (clk, rst_n) begin
		if rst_n = '0' then
			dbg_a <= (others => '1');
			dbg_b <= (others => '1');
			seg_data <= (others => ' ');
		elsif rising_edge(clk) then
			if pressed = '1' then
				dbg_a(0 to 2) <= not (to_unsigned(key, 3));
				dbg_b <= sw;
				seg_data <= seg_data(2 to 8) & to_string(key, key'high, 10, 1);
			end if;
		end if;
	end process;

end arch;
