library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot_try is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- dot
		dot_red, dot_green, dot_com : out u8r_t
		-- sw 
		-- sw : in u8r_t
	);
end dot_try;

architecture arch of dot_try is

	signal data_r, data_g : u8r_arr_t(0 to 7);
	signal trigger_i : std_logic;
	signal trigger : std_logic;
	signal dot_y, dot_x : integer range 0 to 7 := 0;
	signal temp_y, temp_x : integer range 0 to 7 := 0;
begin

	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,
			dot_green => dot_green,
			dot_com   => dot_com,
			data_r    => data_r,
			data_g    => data_g
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 5
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => trigger_i
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => trigger_i,
			rising  => trigger,
			falling => open
		);

	process (clk, rst_n) begin
		if rst_n = '0' then

		elsif rising_edge(clk) then

			data_g <= (others => (others => '1'));
			
			if trigger = '1' then
				temp_x <= dot_x;
				temp_y <= dot_y;
				if dot_x = 7 then
					dot_y <= dot_y + 1;
					dot_x <= 0;
				else
					dot_x <= dot_x + 1;
				end if;
				data_r(dot_y)(dot_x) <= '1';
				data_r(temp_y)(temp_x) <= '0';
			end if;
		end if;
	end process;

end arch;
