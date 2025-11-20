library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity sw_test is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- user logic
		dbg_a : out u8r_t
	);
end sw_test;

architecture arch of sw_test is

	signal sw_i : u8r_t;

begin

	dbg_a<=sw;

end arch;
