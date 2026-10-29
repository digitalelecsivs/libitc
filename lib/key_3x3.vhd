--115學年度起改新的競賽電路板，原本的key.vhd(4x4)已經不適用，改寫成key_3x3.vhd
--115.10.12  by chaosoyu
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
entity key_3x3 is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- key
		key_row : in unsigned(0 to 2);
		key_col : out unsigned(0 to 2);
		-- user logic
		pressed : out std_logic;
		key     : out integer range 0 to 9 --- 0~8 for 9 keys, 9 for no key pressed
	);
end key_3x3;

architecture arch of key_3x3 is

	signal clk_scan : std_logic;
	signal pressed_i : std_logic; -- not debounced pressed flag

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_scan
		);

	-- scan through columns
	process (clk_scan, rst_n)
		variable curr_cycle_pressed : std_logic;
		variable column : integer range 0 to 2;
	begin
		if rst_n = '0' then
			pressed_i <= '0';
			curr_cycle_pressed := '0';
			column := 0;
		elsif rising_edge(clk_scan) then
			if reduce(key_row, "and") = '0' then -- key_row has zeros (some key is pressed)
				key <= index_of(key_row, '0') * 3 + column;
				curr_cycle_pressed := '1'; -- remeber a button is pressed this cycle
			end if;

			if column = column'high then
				column := 0;
				pressed_i <= curr_cycle_pressed; -- update pressed flag
				curr_cycle_pressed := '0'; -- reset for next cycle
			else
				column := column + 1;
			end if;

			key_col <= "011" ror column; -- cycle '0' between columns
		end if;
	end process;

	debounce_inst : entity work.debounce(arch)
		generic map(
			stable_time => 10
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			sig_out => pressed
		);

end arch;
