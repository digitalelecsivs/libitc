library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test is
	port (
		
	);
end test;

architecture arch of test is
	
begin
	clk_inst: entity work.clk(arch)
	generic map (
		freq => 1000
	)
	port map (
		clk_in => clk,
		rst_n => rst_n,
		clk_out => clk1000
	);

	
end arch;