----------------------------------------------------------------------------
--用於測試ads1115與joystick收到訊號的x、y軸數值(16進制)
--x軸數值顯示於右方4位數，y軸數值顯示於左方4位數。
--測試結果：joystick向右=>x=0x"53dd"，向左x=0x"0036", 置中x=0x"34d6"。
--				   向上=>y=0x"0036"，向下y=0x"6798", 置中y=0x"3396"。
--115.10.18   by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all; -- 已包含 to_string 函式

entity js_num is
	port (
		clk     : in std_logic;
		rst_n   : in std_logic;
		js_scl  : inout std_logic;
		js_sda  : inout std_logic;
		seg_led : out u8r_t;
		seg_com : out u8r_t
	);
end js_num;

architecture arch of js_num is

	-- 宣告 ADS1115 搖桿控制器元件
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

	-- 內部訊號
	signal x_raw, y_raw : u16_t;
	signal x_latest, y_latest : u16_t := (others => '0');
	signal x_disp, y_disp : u16_t := (others => '0');
	signal data_valid : std_logic;
	signal data_valid_r : std_logic := '0';
	signal seg_data : string(1 to 8);

	-- 降頻計時器 (500ms，每秒更新 2 次)
	constant UPDATE_LIMIT : integer := sys_clk_freq / 2;
	signal update_cnt : integer range 0 to UPDATE_LIMIT := 0;

begin
	-- 0. 實體化七段顯示器模組
	u_seg : entity work.seg(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0')
		);

	-- 1. 實體化搖桿控制器
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
	-- 2. 實體化edge
	key_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => data_valid,
			rising  => data_valid_r,
			falling => open
		);
	-- 3. 上升沿觸發鎖存最新 ADC 數據
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			x_latest <= (others => '0');
			y_latest <= (others => '0');
		elsif rising_edge(clk) then
			if data_valid_r = '1' then
				x_latest <= x_raw;
				y_latest <= y_raw;
			end if;
		end if;
	end process;

	-- 4. 每 500ms 將數據更新至顯示暫存器
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			update_cnt <= 0;
			x_disp <= (others => '0');
			y_disp <= (others => '0');
		elsif rising_edge(clk) then
			if update_cnt >= UPDATE_LIMIT - 1 then
				update_cnt <= 0;
				x_disp <= x_latest;
				y_disp <= y_latest;
			else
				update_cnt <= update_cnt + 1;
			end if;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- 5. 使用套件內建的 to_string 轉 Hex 字串
	-- to_string(num => 數值(integer), num_max => 最大值, base => 16, length => 4)
	----------------------------------------------------------------------------
	-- 左 4 位 (1..4) 顯示 Y 軸
	seg_data(1 to 4) <= to_string(to_integer(y_disp), 16#FFFF#, 16, 4);

	-- 右 4 位 (5..8) 顯示 X 軸
	seg_data(5 to 8) <= to_string(to_integer(x_disp), 16#FFFF#, 16, 4);

end arch;
