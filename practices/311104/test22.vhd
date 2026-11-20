library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity test is
	port (
		clk              : in std_logic;
		rst_n            : in std_logic;
		db_row           : in u2r_t;
		db_col           : out u2r_t;
		sw               : in u8r_t;
		seg_led, seg_com : out u8r_t; -- 7段顯示器
		dbg_a            : out u8r_t;
		dbg_b            : out u8r_t
	);
end test;

architecture arch of test is
	-- 鍵盤相關訊號
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : i4_t;
	signal seg_data : string(1 to 8) := (others => ' ');
begin

	-- 1. 7段顯示器元件執行個體
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '1' -- 若畫面不亮可改為 '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0')
		);

	-- 2. 2x2 矩陣按鍵元件
	key_inst : entity work.key_2x2_1
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => db_row,
			key_col => db_col,
			pressed => pressed_i,
			key     => key
		);

	-- 3. 邊緣檢測
	key_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);

	-- 4. 主控制行程
	process (clk, rst_n) begin
		if rst_n = '0' then
			dbg_a <= (others => '1');
			dbg_b <= (others => '1');
			seg_data <= (others => ' ');
		elsif rising_edge(clk) then
			if pressed = '1' then
				dbg_a(0 to 2) <= not (to_unsigned(key, 3));
				dbg_b <= sw;
				-- 修正：將寬度從 2 改為 1，確保總長度剛好等於 8 個字元
				seg_data <= seg_data(2 to 8) & to_string(key, key'high, 10, 1);
			end if;
		end if;
	end process;

end arch;
