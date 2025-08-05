library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot_try is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- dot
		dot_red, dot_green, dot_com : out u8r_t;
		-- sw 
		sw : in u8r_t
	);
end dot_try;

architecture arch of dot_try is

	signal data_r, data_g : u8r_arr_t(0 to 7);

	signal x_pos : integer range 0 to 7 := 0;
	signal y_pos : integer range 0 to 7 := 7;
	signal clk_pos : std_logic;

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
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_pos
		);

	process (clk_pos, rst_n) begin
		if rst_n = '0' then
			x_pos <= 0;
			y_pos <= 7;
		elsif rising_edge(clk_pos) then
			data_g <= (others => (others => '0'));
			if x_pos = x_pos'high then
				x_pos <= 0;
				if y_pos = y_pos'low then
					y_pos <= 7;
				else
					y_pos <= y_pos - 1;
				end if;
			else
				x_pos <= x_pos + 1;
			end if;
			data_g(y_pos)(x_pos) <= '1';
			-- data_r <= (others => (others => '0'));
			-- data_g <= (others => (others => '0'));

			-- if sw(0) = '1' then
			-- 	data_g(y_pos)(x_pos) <= '1';
			-- end if;

			-- if sw(1) = '1' then
			-- 	data_r(y_pos)(x_pos) <= '1';
			-- end if;
		end if;
	end process;

end arch;
