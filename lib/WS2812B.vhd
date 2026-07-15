library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity WS2812B is
	generic (
		led_num_max : integer := 8
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		--sys
		ena      : in std_logic;
		busy     : out std_logic;
		rgb_data : in l_px_arr_t(0 to led_num_max - 1);
		D_out    : out std_logic;
		dbg_a    : out std_logic_vector(7 downto 0);
		led_num  : in integer range 0 to led_num_max
	);
end WS2812B;

architecture arch of WS2812B is
	type state_t is (idle, reset, Bit_HI, Bit_LO, next_bit, next_led);
	signal mode_t : state_t := idle;
	--sys
	signal start : std_logic;
	signal bit_cnt : integer range 0 to 24 := 0;
	signal led_cnt : integer range 0 to led_num_max := 0;
	--cnt
	signal T0_H : integer range 0 to 20 := 20;
	signal T0_L : integer range 0 to 40 := 40;
	signal T1_H : integer range 0 to 40 := 40;
	signal T1_L : integer range 0 to 20 := 20;
	signal srst : integer range 0 to 3000 := 0;
	signal clk_cnt : integer range 0 to 3000 := 0;
begin
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
	dbg_test : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				dbg_a(5 downto 1) <= (others => '0');
			elsif rising_edge(clk) then
				case mode_t is
					when idle => null;
					when reset => dbg_a(1) <= '1';
					when Bit_HI => dbg_a(2) <= '1';
					when Bit_LO => dbg_a(3) <= '1';
					when next_bit => dbg_a(4) <= '1';
					when next_led => dbg_a(5) <= '1';
				end case;
			end if;
		end process;
		dbg_a(0) <= '0' when mode_t = idle else '1';
		dbg_a(6) <= '0' when busy = '1' else '1';
	end block dbg_test;

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
							clk_cnt <= 0;
							D_out <= '0';
							bit_cnt <= 0;
							led_cnt <= 0;
						end if;
					when reset =>
						busy <= '1';
						D_out <= '0';
						if clk_cnt < srst'high then
							clk_cnt <= clk_cnt + 1;
						else
							clk_cnt <= 0;
							bit_cnt <= 0;
							mode_t <= Bit_HI;
						end if;
					when Bit_HI =>
						busy <= '1';
						D_out <= '1';
						if rgb_data(led_cnt)(bit_cnt) = '0' then
							if clk_cnt < T0_H'high then
								clk_cnt <= clk_cnt + 1;
							else
								clk_cnt <= 0;
								mode_t <= Bit_LO;
							end if;
						elsif rgb_data(led_cnt)(bit_cnt) = '1' then
							if clk_cnt < T1_H'high then
								clk_cnt <= clk_cnt + 1;
							else
								clk_cnt <= 0;
								mode_t <= Bit_LO;
							end if;
						end if;
					when Bit_LO =>
						busy <= '1';
						D_out <= '0';
						if rgb_data(led_cnt)(bit_cnt) = '0' then
							if clk_cnt < T0_L'high then
								clk_cnt <= clk_cnt + 1;
							else
								clk_cnt <= 0;
								mode_t <= next_bit;
							end if;
						elsif rgb_data(led_cnt)(bit_cnt) = '1' then
							if clk_cnt < T1_L'high then
								clk_cnt <= clk_cnt + 1;
							else
								clk_cnt <= 0;
								mode_t <= next_bit;
							end if;
						end if;
					when next_bit =>
						D_out <= '0';
						if bit_cnt < 23 then
							bit_cnt <= bit_cnt + 1;
							mode_t <= Bit_HI;
							busy <= '1';
							clk_cnt <= 0;
						else
							mode_t <= next_led;
						end if;
					when next_led =>
						D_out <= '0';
						if led_cnt < led_num - 1 then
							led_cnt <= led_cnt + 1;
							mode_t <= Bit_HI;
							busy <= '1';
							clk_cnt <= 0;
							bit_cnt <= 0;
						else
							busy <= '0';
							led_cnt <= 0;
							mode_t <= idle;
						end if;
				end case;
			end if;
		end process;
	end block Main_Process;
end arch;
