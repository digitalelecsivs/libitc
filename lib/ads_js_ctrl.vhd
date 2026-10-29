--ads1115控制器 (修復通道交叉顯示版) 最終版
--x_raw : x軸的數值
--y_raw : y軸的數值
--data_valid : '1'為資料有效，'0'為無效
--dbg_b : 送出狀態值，作為除錯用，正式使用時可以移去。
--115.10.18   by chaosoyu
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity ads_js_ctrl is
	port (
		clk        : in std_logic;
		rst_n      : in std_logic;
		scl        : inout std_logic;
		sda        : inout std_logic;
		x_raw      : out u16_t;
		y_raw      : out u16_t;
		data_valid : out std_logic
		--dbg_b      : out std_logic_vector(7 downto 0)
	);
end ads_js_ctrl;

architecture arch of ads_js_ctrl is

	component i2c is
		generic (
			bus_freq : integer := 100_000
		);
		port (
			clk, rst_n : in std_logic;
			scl, sda   : inout std_logic;
			ena        : in std_logic;
			busy       : out std_logic;
			cmd        : in u8_t;
			data_in    : in u8_t;
			data_out   : out u8_t
		);
	end component;

	signal i2c_ena : std_logic := '0';
	signal i2c_busy : std_logic;
	signal i2c_cmd : u8_t;
	signal i2c_data_in : u8_t;
	signal i2c_data_out : u8_t;

	type state_t is (
		ST_IDLE,
		ST_RESET_WAIT,
		ST_CFG_START,
		ST_CFG_PTR_WAIT_H,
		ST_CFG_PTR_WAIT_L,
		ST_CFG_MSB_WAIT_H,
		ST_CFG_MSB_WAIT_L,
		ST_CFG_LSB_WAIT_H,
		ST_CFG_LSB_WAIT_L,
		ST_WAIT_CONV,
		ST_PTR_START,
		ST_PTR_WAIT_H,
		ST_PTR_WAIT_L,
		ST_READ_PRELOAD,
		ST_READ_START,
		ST_READ_MSB_WAIT_H,
		ST_READ_MSB_WAIT_L,
		ST_READ_LSB_WAIT_H,
		ST_READ_LSB_WAIT_L,
		ST_UPDATE_DATA,
		ST_SWITCH_CH
	);
	signal state : state_t := ST_IDLE;

	constant ADDR_W : u8_t := x"90";
	constant ADDR_R : u8_t := x"91";

	signal channel : std_logic := '0'; -- 0: X軸 (A0), 1: Y軸 (A1)
	signal msb_buf : u8_t := (others => '0');
	signal lsb_buf : u8_t := (others => '0');

	signal timer_cnt : integer := 0;
	signal idle_cnt : integer range 0 to 15 := 0;

begin

	i2c_inst : i2c
	generic map(
		bus_freq => 100_000
	)
	port map(
		clk      => clk,
		rst_n    => rst_n,
		scl      => scl,
		sda      => sda,
		ena      => i2c_ena,
		busy     => i2c_busy,
		cmd      => i2c_cmd,
		data_in  => i2c_data_in,
		data_out => i2c_data_out
	);

	process (clk, rst_n)
	begin
		if rst_n = '0' then
			state <= ST_IDLE;
			i2c_ena <= '0';
			channel <= '0';
			data_valid <= '0';
			x_raw <= (others => '0');
			y_raw <= (others => '0');
			timer_cnt <= 0;
			idle_cnt <= 0;

		elsif rising_edge(clk) then

			case state is

				when ST_IDLE =>
					timer_cnt <= 0;
					i2c_ena <= '0';
					idle_cnt <= 0;
					data_valid <= '0';
					if i2c_busy = '0' then
						state <= ST_RESET_WAIT;
					end if;

				when ST_RESET_WAIT =>
					i2c_ena <= '0';
					if idle_cnt = 15 then
						state <= ST_CFG_START;
					else
						idle_cnt <= idle_cnt + 1;
					end if;

				when ST_CFG_START =>
					i2c_cmd <= ADDR_W;
					i2c_data_in <= x"01"; -- Pointer Config
					i2c_ena <= '1';
					state <= ST_CFG_PTR_WAIT_H;

				when ST_CFG_PTR_WAIT_H =>
					if i2c_busy = '1' then
						state <= ST_CFG_PTR_WAIT_L;
					end if;

				when ST_CFG_PTR_WAIT_L =>
					if i2c_busy = '0' then
						if channel = '0' then
							i2c_data_in <= x"C2"; -- A0 (X軸)
						else
							i2c_data_in <= x"D2"; -- A1 (Y軸)
						end if;
						state <= ST_CFG_MSB_WAIT_H;
					end if;

				when ST_CFG_MSB_WAIT_H =>
					if i2c_busy = '1' then
						state <= ST_CFG_MSB_WAIT_L;
					end if;

				when ST_CFG_MSB_WAIT_L =>
					if i2c_busy = '0' then
						i2c_data_in <= x"83";
						state <= ST_CFG_LSB_WAIT_H;
					end if;

				when ST_CFG_LSB_WAIT_H =>
					if i2c_busy = '1' then
						i2c_ena <= '0';
						state <= ST_CFG_LSB_WAIT_L;
					end if;

				when ST_CFG_LSB_WAIT_L =>
					if i2c_busy = '0' then
						timer_cnt <= 0;
						state <= ST_WAIT_CONV;
					end if;

					-- 等待 ADC 轉換 (確保滿 15ms 以上，徹底消除多工器切換的殘留舊資料)
				when ST_WAIT_CONV =>
					if timer_cnt >= (sys_clk_freq / 60) then -- 延遲約 16.6ms
						timer_cnt <= 0;
						state <= ST_PTR_START;
					else
						timer_cnt <= timer_cnt + 1;
					end if;

				when ST_PTR_START =>
					if i2c_busy = '0' then
						i2c_cmd <= ADDR_W;
						i2c_data_in <= x"00"; -- Pointer Conversion Register
						i2c_ena <= '1';
						state <= ST_PTR_WAIT_H;
					end if;

				when ST_PTR_WAIT_H =>
					if i2c_busy = '1' then
						i2c_ena <= '0';
						state <= ST_PTR_WAIT_L;
					end if;

				when ST_PTR_WAIT_L =>
					if i2c_busy = '0' then
						state <= ST_READ_PRELOAD;
					end if;

				when ST_READ_PRELOAD =>
					i2c_cmd <= ADDR_R;
					i2c_ena <= '0';
					if i2c_busy = '0' then
						state <= ST_READ_START;
					end if;

				when ST_READ_START =>
					i2c_ena <= '1';
					state <= ST_READ_MSB_WAIT_H;

				when ST_READ_MSB_WAIT_H =>
					if i2c_busy = '1' then
						state <= ST_READ_MSB_WAIT_L;
					end if;

				when ST_READ_MSB_WAIT_L =>
					if i2c_busy = '0' then
						msb_buf <= i2c_data_out;
						state <= ST_READ_LSB_WAIT_H;
					end if;

				when ST_READ_LSB_WAIT_H =>
					if i2c_busy = '1' then
						i2c_ena <= '0';
						state <= ST_READ_LSB_WAIT_L;
					end if;

				when ST_READ_LSB_WAIT_L =>
					if i2c_busy = '0' then
						lsb_buf <= i2c_data_out;
						state <= ST_UPDATE_DATA;
					end if;

					----------------------------------------------------------------
					-- 修復重點：精確將資料寫入各自通道，不混用 data_valid
					----------------------------------------------------------------
				when ST_UPDATE_DATA =>
					if channel = '0' then
						x_raw <= msb_buf & lsb_buf; -- 確定更新 X 軸
					else
						y_raw <= msb_buf & lsb_buf; -- 確定更新 Y 軸
						data_valid <= '1'; -- 當完整輪詢完 X 與 Y 後才發送 valid
					end if;
					state <= ST_SWITCH_CH;

				when ST_SWITCH_CH =>
					data_valid <= '0';
					channel <= not channel; -- 切換通道
					state <= ST_IDLE;

				when others =>
					state <= ST_IDLE;

			end case;
		end if;
	end process;

	--dbg_b <= x"01" when state = ST_IDLE else x"0F";

end arch;
