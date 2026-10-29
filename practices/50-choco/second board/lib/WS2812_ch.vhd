--WS2812B串列LED模組驅動程式
--WS2812B是一串LED組成的模組，每顆LED資料由DIN進入，由DOUT輸出，依次串列傳送到下一顆。
--本實驗的模組由64顆WS2812組成，每一顆含RGB三顏色，每個顏色用8位元表示，共24位元。
--功能：將LED顏色資料編碼成NRZ送出
--		ena => 致能腳/input
--		busy => 工作中/output
--		rgb_data => LED顏色資料陣列/input
--		D_out => 串列NRZ訊號/output
--		led_num => LED數量/input
--115.10.14   by chaosoyu
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity WS2812_ch is
	generic (
		led_num_max : integer := 64
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- sys
		ena      : in std_logic;
		busy     : out std_logic;
		rgb_data : in l_px_arr_t(0 to led_num_max - 1); --g7 . . g0, r7 . . r0, b7 . . b0, total 24bits for each LED
		D_out    : out std_logic;
		--dbg_a    : out std_logic_vector(7 downto 0);
		led_num : in integer range 0 to led_num_max
	);
end WS2812_ch;

architecture arch of WS2812_ch is
	type state_t is (idle, reset, Bit_HI, Bit_LO);
	signal mode_t : state_t := idle;

	-- Control signals
	signal start : std_logic;
	signal bit_cnt : integer range 0 to 23 := 0;
	signal led_cnt : integer range 0 to led_num_max := 0;
	signal clk_cnt : integer range 0 to 20000 := 0;

	-- 50MHz Clock (1 cycle = 20ns) timing parameters
	constant C_T0H : integer := (400 * (sys_clk_freq / 1_000_000)) / 1_000; -- 400ns
	constant C_T0L : integer := (840 * (sys_clk_freq / 1_000_000)) / 1_000; -- 840ns
	constant C_T1H : integer := (800 * (sys_clk_freq / 1_000_000)) / 1_000; -- 800ns
	constant C_T1L : integer := (440 * (sys_clk_freq / 1_000_000)) / 1_000; -- 440ns
	constant C_RST : integer := (280 * (sys_clk_freq / 1_000_000)); -- 280us (Safe reset duration for all WS2812B variants)

	signal target_hi_cnt : integer range 0 to 63 := 0;
	signal target_lo_cnt : integer range 0 to 63 := 0;
	signal current_bit : std_logic;

begin

	-- Edge detection block
	components : block begin
		edge_inst1 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => ena,
				rising  => start,
				falling => open
			);
	end block components;

	-- Extract active bit (MSB First: 23 down to 0)
	current_bit <= rgb_data(led_cnt)(23 - bit_cnt);

	-- Dynamic cycle targets based on bit value
	target_hi_cnt <= C_T1H when current_bit = '1' else C_T0H;
	target_lo_cnt <= C_T1L when current_bit = '1' else C_T0L;

	-- Main state machine
	Main_Process : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				busy <= '0';
				D_out <= '0';
				mode_t <= idle;
				clk_cnt <= 0;
				bit_cnt <= 0;
				led_cnt <= 0;
			elsif rising_edge(clk) then
				case mode_t is

					when idle =>
						busy <= '0';
						D_out <= '0';
						if start = '1' then
							mode_t <= reset;
							busy <= '1';
							clk_cnt <= 0;
							bit_cnt <= 0;
							led_cnt <= 0;
						end if;

					when reset =>
						busy <= '1';
						D_out <= '0';
						if clk_cnt < C_RST - 1 then
							clk_cnt <= clk_cnt + 1;
						else
							clk_cnt <= 0;
							mode_t <= Bit_HI;
						end if;

					when Bit_HI =>
						busy <= '1';
						D_out <= '1';
						if clk_cnt < target_hi_cnt - 1 then
							clk_cnt <= clk_cnt + 1;
						else
							clk_cnt <= 0;
							mode_t <= Bit_LO;
						end if;

					when Bit_LO =>
						busy <= '1';
						D_out <= '0';
						if clk_cnt < target_lo_cnt - 1 then
							clk_cnt <= clk_cnt + 1;
						else
							clk_cnt <= 0;
							if bit_cnt < 23 then
								bit_cnt <= bit_cnt + 1;
								mode_t <= Bit_HI;
							else
								bit_cnt <= 0;
								if led_cnt < led_num - 1 then
									led_cnt <= led_cnt + 1;
									mode_t <= Bit_HI;
								else
									led_cnt <= 0;
									mode_t <= idle;
									busy <= '0';
								end if;
							end if;
						end if;

				end case;
			end if;
		end process;
	end block Main_Process;

	-- Debug output
	--dbg_test : block begin
	--	process (clk, rst_n) begin
	--		if rst_n = '0' then
	--			dbg_a <= (others => '0');
	--		elsif rising_edge(clk) then
	--			dbg_a(5 downto 1) <= (others => '0'); -- reset debug bits
	--			case mode_t is
	--				when idle => dbg_a(0) <= '0';
	--				when reset => dbg_a(1) <= '1';
	--					dbg_a(0) <= '1';
	--				when Bit_HI => dbg_a(2) <= '1';
	--					dbg_a(0) <= '1';
	--				when Bit_LO => dbg_a(3) <= '1';
	--					dbg_a(0) <= '1';
	--			end case;
	--			dbg_a(6) <= not busy;
	--		end if;
	--	end process;
	--end block dbg_test;
end arch;
