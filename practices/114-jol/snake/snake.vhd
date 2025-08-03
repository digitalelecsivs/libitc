library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;

entity snake is
	port (
		clk, rst_n                  : in std_logic;
		dot_red, dot_green, dot_com : out u8r_t;
		dbg_a                       : out std_logic_vector(0 to 5)
	);
end snake;

architecture arch of snake is
	signal data_map: u8r_arr_t;
	signal clk : std_logic;
begin
	clk_inst1: entity work.clk(arch)
	generic map (
		freq => 10
	)
	port map (
		clk_in => clk,
		rst_n => rst_n,
		clk_out => clk_out  
	);

end arch;