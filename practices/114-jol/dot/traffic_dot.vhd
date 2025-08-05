library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--adjust for test other function
use work.itc.all;

entity traffic_dot is
	port (
		-- sys
		clk, rst_n                  : in std_logic;
		dot_red, dot_green, dot_com : out u8r_t;
		seg_led, seg_com            : out u8r_t;
		dbg_a                       : out std_logic_vector(0 to 5)
	);
end traffic_dot;
--type u8r_arr_t is array (integer range <>) of u8r_t;

architecture arch of traffic_dot is
	type u8r_arr_t2 is array(0 to 14)of u8r_arr_t(0 to 7);
	constant data_r : u8r_arr_t2 := (	-- 3 Dimensions array data_r[15][8][8]
		(X"22", X"22", X"14", X"08", X"34", X"18", X"20", X"20"),
		(X"12", X"12", X"14", X"08", X"10", X"18", X"20", X"20"),
		(X"14", X"14", X"04", X"08", X"14", X"18", X"20", X"20"),
		(X"10", X"14", X"0C", X"08", X"14", X"18", X"20", X"20"),
		(X"10", X"10", X"08", X"08", X"10", X"10", X"20", X"20"),
		(X"30", X"10", X"20", X"10", X"10", X"10", X"20", X"20"),
		(X"04", X"34", X"08", X"18", X"38", X"18", X"20", X"20"),
		(X"10", X"10", X"08", X"08", X"10", X"10", X"20", X"20"),
		(X"21", X"22", X"14", X"08", X"10", X"18", X"20", X"20"),
		(X"14", X"14", X"04", X"08", X"14", X"18", X"20", X"20"),
		(X"30", X"10", X"20", X"10", X"10", X"10", X"20", X"20"),
		(X"04", X"34", X"08", X"18", X"38", X"18", X"20", X"20"),
		(X"14", X"14", X"2A", X"1C", X"08", X"1C", X"1C", X"1C"), --red
		(X"81", X"42", X"24", X"18", X"18", X"24", X"42",X"81"), --yellow
		(X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00") --nothing
	);
	signal counter : integer range 0 to 31;
	signal dot_cnt : integer range 0 to 11;
	signal dot_data_r, dot_data_g : u8r_arr_t(0 to 7);
	signal clk_cnt : std_logic;
	signal clk_dot : std_logic;
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
	clk_inst2 : entity work.clk(arch)
		generic map(
			freq => 8
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_dot
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

	process (clk_dot, rst_n) begin
		if (rising_edge(clk_dot)) then
			if (mode = greenlight) then
				dot_cnt <= (dot_cnt + 1) mod 12;
				case dot_cnt is
					when 0 =>
						dot_data_g <= data_r(0);
					when 1 =>
						dot_data_g <= data_r(1);
					when 2 =>
						dot_data_g <= data_r(2);
					when 3 =>
						dot_data_g <= data_r(3);
					when 4 =>
						dot_data_g <= data_r(4);
					when 5 =>
						dot_data_g <= data_r(5);
					when 6 =>
						dot_data_g <= data_r(6);
					when 7 =>
						dot_data_g <= data_r(7);
					when 8 =>
						dot_data_g <= data_r(8);
					when 9 =>
						dot_data_g <= data_r(9);
					when 10 =>
						dot_data_g <= data_r(10);
					when 11 =>
						dot_data_g <= data_r(11);
					when others => null;
				end case;
				dot_data_r <= data_r(14);
			elsif (mode = redlight) then
				dot_cnt <= 0;
				dot_data_g <= data_r(14);
				dot_data_r <= data_r(12);
			else
				dot_cnt <= 0;
				dot_data_g <= data_r(13);
				dot_data_r <= data_r(13);
			end if;
		end if;
	end process;
	dbg_a <= "010100" when mode = greenlight else
		"100010"when mode = redlight else
		"010001"when mode = yellowlight1 else
		"001010"when mode = yellowlight2 else (others => '0');
end arch;
