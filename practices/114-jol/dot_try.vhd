library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--adjust for test other function
use work.itc.all;

entity dot_try is
	port (
		-- sys
		clk, rst_n : in std_logic;

		dot_red, dot_green, dot_com : out u8r_t;

		dbg_a : out std_logic_vector(0 to 5)
	);
end dot_try;

architecture arch of dot_try is
	signal counter : integer range 0 to 31;
	signal dot_data_r, dot_data_g : u8r_arr_t(0 to 7);
	signal x_pos, y_pos : integer range 0 to 7;
	signal clk_cnt : std_logic;
	signal clk_pos : std_logic;
	type state is (redlight, greenlight, yellowlight1, yellowlight2);
	signal mode : state := greenlight;
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
			data_r    => dot_data_r,
			data_g    => dot_data_g
		);

	-- clk_inst1 : entity work.clk(arch)
	-- 	generic map(
	-- 		freq => 8
	-- 	)
	-- 	port map(
	-- 		clk_in  => clk,
	-- 		rst_n   => rst_n,
	-- 		clk_out => clk_pos
	-- 	);
	clk_inst2 : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_cnt
		);

	process (clk_cnt, rst_n)begin
		if (rst_n = '0') then
			counter <= 0;
			mode <= greenlight;
		elsif (rising_edge(clk_cnt)) then
			counter <= counter + 1;
			if (counter = 31) then
				mode <= greenlight;
			elsif (counter = 11) then
				mode <= yellowlight1;
			elsif (counter = 15) then
				mode <= redlight;
			elsif (counter = 27) then
				mode <= yellowlight1;
			end if;
		end if;
	end process;
	dot_data_r <= (X"14", X"14", X"2A", X"1C", X"08", X"1C", X"1C", X"1C") when mode = redlight else
		(X"00", X"7E", X"02", X"02", X"3C", X"40", X"40", X"7E") when mode = yellowlight1 or mode = yellowlight2 else (others => (others => '0'));
	dot_data_g <= (X"00", X"22", X"14", X"08", X"34", X"18", X"20", X"20") when mode = greenlight else
		(X"00", X"7E", X"02", X"02", X"3C", X"40", X"40", X"7E") when mode = yellowlight1 or mode = yellowlight2 else (others => (others => '0'));
	dbg_a <= "010100" when mode = greenlight else
		"100010"when mode = redlight else
		"010001"when mode = yellowlight1 else
		"001010"when mode = yellowlight2 else (others => '0');
end arch;
