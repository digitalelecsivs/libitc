library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity map1 is
	port (

		clk   : in std_logic; -- sys
		rst_n : in std_logic;

		key_row : in u4r_t;--key
		key_col : out u4r_t;

		dot_red, dot_green, dot_com : out u8r_t; --8*8 dot led
		dbg_b                       : out u8r_t; -- dbg
		dbg_a                       : out u4r_t
	);
end map1;

architecture arch of map1 is
	type state is (init, change);
	signal mode : state := init;
	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 3000 := 0;

	--key board
	signal pressed_i : std_logic := '0';
	signal pressed : std_logic := '0';
	signal key : integer range 0 to 15;

	--8*8 dot
	signal data_g, data_r : u8r_arr_t(0 to 7);
	signal x : integer range 0 to 7;
	signal y : integer range 0 to 7;
	signal temp_x : integer range 0 to 7;
	signal temp_y : integer range 0 to 7;

begin

	-- Component -------------------------------------------------------------------------------------------------------------------------
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,   --腳位
			dot_green => dot_green, --腳位
			dot_com   => dot_com,   --腳位
			data_r    => data_r,    --紅色資料
			data_g    => data_g     --綠色資料
		);
	timer_inst : entity work.timer(arch)--計時器
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => ena_tim,
			load  => 0,
			msec  => msec
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);
	edge_key : entity work.edge(arch)--微分出只有一個ck的keyboard trigger
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	-- Main Process ---------------------------------------------------------------------------------------------------------------------

	process (clk, rst_n)

	begin
		if rst_n = '0' then
			x <= 0;
			y <= 0;
			data_r <= (others => (others => '0'));
		elsif rising_edge(clk) then
			case mode is
				when init =>
					if pressed = '1' then
						case key is
							when 5 =>
								y <= y + 1;
							when 8 =>
								x <= x - 1;
							when 9 =>
								y <= y - 1;
							when 10 =>
								x <= x + 1;
							when others => null;
						end case;
						mode <= change;
					end if;
				when change =>
					data_r(temp_y)(temp_x) <= '0';
					temp_x <= x;
					temp_y <= y;
					data_r(y)(x) <= '1';
					mode <= init;
			end case;

		end if;
	end process;

end arch;
