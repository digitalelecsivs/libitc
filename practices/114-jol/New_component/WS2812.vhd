library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
-- subtype l_px_t is unsigned(l_depth - 1 downto 0);
-- 	type l_px_arr_t is array (integer range <>) of l_px_t;
entity WS2812 is
	generic (
		led_num_max : integer := 8
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		--
		ena      : in std_logic;
		busy     : out std_logic;
		rgb_data : in l_px_arr_t(0 to led_num_max - 1);
		D_out    : out std_logic;
		dbg_a    : out std_logic_vector(7 downto 0);
		led_num  : in integer range 0 to led_num_max
	);
end WS2812;

architecture arch of WS2812 is
	type state_t is (idle, reset, read, Bit_HI, Bit_LO, next_bit, next_led);
	signal mode_t : state_t := idle;
	-- type state_s is (HI, LO);
	-- signal mode_s : state_s := HI;

	--sys
	signal start : std_logic;
	signal bit_cnt : integer range 0 to 24 := 0;
	signal ena_d : std_logic;
	-- signal cnt : integer range 0 to 3 := 0;
	--flag
	-- signal timer_ena : std_logic := '1';

	signal led_cnt : integer range 0 to led_num_max := 0;

	signal T0_H : integer range 0 to 20 := 20;
	signal T0_L : integer range 0 to 40 := 40;
	signal T1_H : integer range 0 to 40 := 40;
	signal T1_L : integer range 0 to 20 := 20;
	signal srst : integer range 0 to 3000 := 0;
	signal clk_cnt : integer range 0 to 3000 := 0;
	-- signal data : unsigned(0 to 23) := (others => '0');
begin
	components : block begin
		-- debounce_inst : entity work.debounce(arch)
		-- 	generic map(
		-- 		stable_time => 10
		-- 	)
		-- 	port map(
		-- 		clk     => clk,
		-- 		rst_n   => rst_n,
		-- 		sig_in  => ena,
		-- 		sig_out => ena_d
		-- 	);

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
				dbg_a(7 downto 1) <= (others => '0');
			elsif rising_edge(clk) then
				case mode_t is
					when idle => null;
					when reset => dbg_a(1) <= '1';
					when read => dbg_a(2) <= '1';
					when Bit_HI => dbg_a(3) <= '1';
					when Bit_LO => dbg_a(4) <= '1';
					when next_bit => dbg_a(5) <= '1';
					when next_led => dbg_a(6) <= '1';
				end case;
			end if;
		end process;
		dbg_a(0) <= '0' when mode_t = idle else '1';
	end block dbg_test;

	Main_Process : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				busy <= '0';
				D_out <= '0';
				mode_t <= idle;
				clk_cnt <= 0;
				bit_cnt <= 0;
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
						D_out <= '0';
						if clk_cnt < srst'high then
							clk_cnt <= clk_cnt + 1;
						else
							clk_cnt <= 0;
							mode_t <= read;
							bit_cnt <= 0;
						end if;

					when read =>
						busy <= '1';
						D_out <= '0';
						-- data <= rgb_data();
						-- 模組好像怪怪的，顏色順序：BRG
						-- case cnt is--to_unsigned ( integer , 24 )
						-- 	when 0 => data <= x"ff0000";--B
						-- 	when 1 => data <= x"00ff00";--R
						-- 	when 2 => data <= x"0000ff";--G
						-- 	when 3 => data <= x"000000";
						-- end case;

						mode_t <= Bit_HI;
						clk_cnt <= 0;
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
						if bit_cnt = 23 then
							mode_t <= next_led;
							busy <= '0';
						else
							mode_t <= Bit_HI;
							clk_cnt <= 0;
							bit_cnt <= bit_cnt + 1;
							busy <= '1';
						end if;
					when next_led =>
						D_out <= '0';
						if led_cnt < led_num - 1 then
							led_cnt <= led_cnt + 1;
							mode_t <= read;
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
