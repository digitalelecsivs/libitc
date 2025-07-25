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
		seg_led, seg_com            : out u8r_t;
		dbg_a                       : out std_logic_vector(0 to 5)
	);
end dot_try;

architecture arch of dot_try is
	signal counter : integer range 0 to 31;
	signal dot_data_r, dot_data_g : u8r_arr_t(0 to 7);
	signal x_pos, y_pos : integer range 0 to 7;
	signal clk_cnt : std_logic;
	signal clk_pos : std_logic;
	signal light : integer range 0 to 12 := 12;
	signal num : integer range 0 to 99_999_999 := 0;
	signal seg_com_t : u8r_t;
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
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com_t,
			data    => to_string(num, num'high, 10, 8),
			dot => (others => '0')
		);
	clk_inst1 : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_cnt
		);

	process (clk_cnt, rst_n)
	begin
		if (rst_n = '0') then
			counter <= 0;
			mode <= greenlight;
			light <= 12;
		elsif (rising_edge(clk_cnt)) then
			counter <= counter + 1;
			case mode is
				when yellowlight2 =>
					if counter = 31 then
						light <= 12;
						mode <= greenlight;
					end if;
				when greenlight =>
					if counter = 11 then
						mode <= yellowlight1;
					end if;
				when yellowlight1 =>
					if counter = 15 then
						light <= 12;
						mode <= redlight;
					end if;
				when redlight =>
					if counter = 27 then
						mode <= yellowlight2;
					end if;
			end case;
			if (mode = greenlight or mode = redlight) and light /= 0 then
				light <= light - 1;
			end if;
		end if;
	end process;
	num <= light when mode = greenlight else
		light * (10 ** 6) when mode = redlight else 0;
	seg_com <= seg_com_t when seg_com_t = "10000000" or seg_com_t = "01000000" or seg_com_t = "00000010" or seg_com_t = "00000001" else "00000000";
	dot_data_r <= (X"14", X"14", X"2A", X"1C", X"08", X"1C", X"1C", X"1C") when mode = redlight else
		(X"20", X"20", X"20", X"3C", X"22", X"22", X"22", X"3C") when mode = yellowlight1 or mode = yellowlight2 else (others => (others => '0'));
	dot_data_g <= (X"44", X"44", X"38", X"08", X"38", X"50", X"20", X"20") when mode = greenlight else
		(X"20", X"20", X"20", X"3C", X"22", X"22", X"22", X"3C") when mode = yellowlight1 or mode = yellowlight2 else (others => (others => '0'));
	dbg_a <= "010100" when mode = greenlight else
		"100010"when mode = redlight else
		"010001"when mode = yellowlight1 else
		"001010"when mode = yellowlight2 else (others => '0');
end arch;
