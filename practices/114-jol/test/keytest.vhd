library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity keytest is
	port (
		clk     : in std_logic;
		rst_n   : in std_logic;
		key_row : in u4r_t;
		key_col : out u4r_t;
		dbg_a   : out u4r_t
	);
end keytest;

architecture arch of keytest is
	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal clk1000 : std_logic;
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk1000,
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
	process (clk) begin
		if rst_n = '0' then
			dbg_a <= "0000";
		elsif rising_edge(clk) then
			if pressed = '1' then
				case key is
					when 0 => dbg_a <= not "0000";
					when 1 => dbg_a <= not "0001";
					when 2 => dbg_a <= not "0010";
					when 3 => dbg_a <= not "0011";
					when 4 => dbg_a <= not "0100";
					when 5 => dbg_a <= not "0101";
					when 6 => dbg_a <= not "0110";
					when 7 => dbg_a <= not "0111";
					when 8 => dbg_a <= not "1000";
					when 9 => dbg_a <= not "1001";
					when 10 => dbg_a <= not "1010";
					when 11 => dbg_a <= not "1011";
					when 12 => dbg_a <= not "1100";
					when 13 => dbg_a <= not "1101";
					when 14 => dbg_a <= not "1110";
					when 15 => dbg_a <= not "1111";
				end case;
			end if;
		end if;
	end process;

end arch;
