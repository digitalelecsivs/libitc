----------------------------------------------------------------------------
-- 接收端：透過 4 條並列線接收板子一的 3x3 鍵盤數字
-- 僅保留七段顯示器 (seg.vhd) 進行串聯滾動顯示
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity js_seg_rx_top is
	port (
		clk, rst_n : in std_logic;
		
		-- 4 條並列接收線（直接接收板子一的 4-bit 按鍵編號）
		rx_data    : in std_logic_vector(3 downto 0); 
		
		-- 七段顯示器輸出（使用實驗室標準 seg.vhd）
		seg_led, seg_com : out u8r_t
	);
end js_seg_rx_top;

architecture arch of js_seg_rx_top is

	-- 接收信號
	signal rx_num        : integer range 0 to 8 := 0; 
	signal rx_data_prev  : std_logic_vector(3 downto 0) := (others => '0');

	-- 七段顯示器字串緩衝（8位數串聯顯示）
	signal seg_data      : string(1 to 8) := "        ";

begin

	-- 1. 七段顯示器元件例化 (seg.vhd)
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '0' -- 共陰極 '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => (others => '0') -- 小數點預設不亮
		);

	-- 2. 偵測 4 條並列線數值改變來接收資料，並更新七段顯示器串聯緩衝
	parallel_rx_proc : process (clk, rst_n)
		variable val : integer;
	begin
		if rst_n = '0' then
			rx_num <= 0;
			rx_data_prev <= (others => '0');
			seg_data <= "        ";
		elsif rising_edge(clk) then
			rx_data_prev <= rx_data;

			-- 當 4 條並列線數值改變時讀取按鍵
			if rx_data /= rx_data_prev then
				val := to_integer(unsigned(rx_data));
				if val >= 0 and val <= 8 then
					rx_num <= val;
					-- 將新按鍵串聯推入七段顯示器顯示 (由左而右滾動)
					seg_data <= seg_data(2 to 8) & character'val(48 + val);
				end if;
			end if;
		end if;
	end process;

end arch;