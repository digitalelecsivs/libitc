library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test is
	port (
		clk : in std_logic
	);
end test;

architecture arch of test is
	signal aaa : std_logic;
begin
	process (clk)
	begin
		if aaa = '1' then
			aaa <= '0';
			
		end if;
	end process;
end arch;
