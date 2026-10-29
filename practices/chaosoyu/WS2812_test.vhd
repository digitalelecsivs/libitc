----------------------------------------------------------------------------
--WS2812跑馬燈
--測試WS2812_ch.vhd模組功能
--測試程式功能：產生跑馬燈，LED由第一顆亮100ms後熄滅，依順序第二顆、第三顆，直到最後
--一顆，再回到第一顆周而復始。
--最多可以設定64顆LED，只要改C_LED_MAX即可。
--LED的顏色可以更改：SW(0) => B, SW(1) => R, SW(2) => G, 可混色。
--LED的數量可以更改：SW(6 to 7) => "11" C_LED_MAX, "01" 減半， "10"再減半，"00" 再減半
--115.10.14   by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity WS2812_test is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- 
		sw    : in std_logic_vector(7 downto 0);
		D_out : out std_logic
	);
end WS2812_test;

architecture arch of WS2812_test is
	type state_t is (idle, sure, work);
	signal mode_t : state_t := idle;

	-- System signals
	signal sw_d : std_logic_vector(7 downto 0) := (others => '0');
	signal ws_ena : std_logic := '0';
	signal ws_busy : std_logic;
	signal ws_busy_f : std_logic;

	constant C_LED_MAX : integer := 64;
	signal led_num : integer range 0 to C_LED_MAX;
	signal rgb_data : l_px_arr_t(0 to C_LED_MAX - 1);

	-- 50MHz Clock 下，100ms 移位一次 (50,000,000 / 10 = 5,000,000 cycles)
	constant C_SHIFT_PERIOD : integer := 5_000_000;
	signal timer_cnt : integer range 0 to C_SHIFT_PERIOD := 0;
	signal auto_tick : std_logic := '0';

	-- 跑馬燈位置計數器 (0 to 7)
	signal shift_cnt : integer range 0 to C_LED_MAX - 1 := 0;

	-- 跑馬燈顏色選定 (預設白光，可用 sw(2 downto 0) 調整 RGB)
	signal active_color : l_px_t;

	component debounce is
		generic (
			stable_time : integer := 10
		);
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			sig_out    : out std_logic
		);
	end component;

	component WS2812_ch is
		generic (
			led_num_max : integer := C_LED_MAX
		);
		port (
			clk, rst_n : in std_logic;
			ena        : in std_logic;
			busy       : out std_logic;
			rgb_data   : in l_px_arr_t(0 to led_num_max - 1);
			D_out      : out std_logic;
			--dbg_a      : out std_logic_vector(7 downto 0);
			led_num : in integer range 0 to led_num_max
		);
	end component;

	component edge is
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			rising     : out std_logic;
			falling    : out std_logic
		);
	end component;

begin

	---------------------------------------------------------------------------
	-- 硬體元件元件化
	---------------------------------------------------------------------------
	components : block begin
		-- Debounce for 8 switches
		gen_sw_debounce : for i in 0 to 7 generate
			sw_deb : debounce
			generic map(stable_time => 100)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => sw(i),
				sig_out => sw_d(i)
			);
		end generate gen_sw_debounce;

		-- WS2812 Driver Instance
		WS2812_inst : WS2812_ch
		generic map(
			led_num_max => C_LED_MAX
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			ena      => ws_ena,
			busy     => ws_busy,
			rgb_data => rgb_data,
			D_out    => D_out,
			led_num  => led_num
		);

		-- Edge Detector for WS2812 Busy (Falling Edge)
		edge_busy : edge
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ws_busy,
			rising  => open,
			falling => ws_busy_f
		);
	end block components;

	---------------------------------------------------------------------------
	-- 定時產生器：每 100ms 產生一次 auto_tick 觸發跑馬燈步進
	---------------------------------------------------------------------------
	timer_process : process (clk, rst_n) begin
		if rst_n = '0' then
			timer_cnt <= 0;
			auto_tick <= '0';
		elsif rising_edge(clk) then
			auto_tick <= '0';
			if timer_cnt < C_SHIFT_PERIOD - 1 then
				timer_cnt <= timer_cnt + 1;
			else
				timer_cnt <= 0;
				auto_tick <= '1'; -- 產生 1 cycle 高電位觸發訊號
			end if;
		end if;
	end process;

	---------------------------------------------------------------------------
	-- 顏色設置：SW(2)=綠, SW(1)=紅, SW(0)=藍
	---------------------------------------------------------------------------
	active_color <= (sw_d(2) & "0000000" & sw_d(1) & "0000000" & sw_d(0) & "0000000")
		when (sw_d(2 downto 0) /= "000") else X"00FF00"; -- 若無開關觸發則預設為紅光

	---------------------------------------------------------------------------
	-- 主控狀態機 (Main Process)
	---------------------------------------------------------------------------
	Main_Process : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				mode_t <= idle;
				ws_ena <= '0';
				shift_cnt <= 0;
				led_num <= C_LED_MAX;
				for i in 0 to C_LED_MAX - 1 loop
					rgb_data(i) <= (others => '0');
				end loop;
			elsif rising_edge(clk) then
				case mode_t is

					when idle =>
						ws_ena <= '0';

						-- 當定時計數器時間到 (100ms) 時自動啟動一輪繪製
						if auto_tick = '1' then
							mode_t <= sure;

							-- 設定總顆數 (由 SW(7 downto 6) 控制)
							case sw_d(7 downto 6) is
								when "00" => led_num <= C_LED_MAX/8;
								when "01" => led_num <= C_LED_MAX/4;
								when "10" => led_num <= C_LED_MAX/2;
								when others => led_num <= C_LED_MAX;
							end case;

							-- 更新跑馬燈位置 (0 ~ led_num - 1 循環移動)
							if shift_cnt < led_num - 1 then
								shift_cnt <= shift_cnt + 1;
							else
								shift_cnt <= 0;
							end if;

							-- 生成跑馬燈顏色陣列：僅當前 shift_cnt 位置亮起顏色
							for i in 0 to C_LED_MAX - 1 loop
								if i = shift_cnt then
									rgb_data(i) <= active_color;
								else
									rgb_data(i) <= X"000000"; -- 其餘全滅
								end if;
							end loop;

						end if;

					when sure =>
						ws_ena <= '1';

						-- 等待驅動晶片響應 busy 高電位後切換至 work
						if ws_busy = '1' then
							mode_t <= work;
						end if;

					when work =>
						ws_ena <= '0';

						-- 等待 WS2812 傳輸完成 (busy 下降緣) 後返回 idle 等待下一次 auto_tick
						if ws_busy_f = '1' then
							mode_t <= idle;
						end if;

				end case;
			end if;
		end process;
	end block Main_Process;

end arch;
