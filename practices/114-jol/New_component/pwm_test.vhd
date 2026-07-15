library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity PWM_TEST is

	port (
		-- system
		clk, rst_n : in std_logic;
		--
		PWM : out std_logic
	--for 示波器檢查
	);
end PWM_TEST;

architecture arch of PWM_TEST is
	type state_t is (idle, RED_color, GRE_color, BLE_color);
	signal mode_t : state_t := RED_color;
	type state_s is (HI, LO);
	signal mode_s : state_s := HI;
	signal cnt : integer range 0 to 59 := 0;
	signal hi_bound : integer range 0 to 59 := 20;
	signal lo_bound : integer range 0 to 59 := 40;
	signal sw_d : std_logic;
	signal sw_edge : std_logic;
	signal flag_state : std_logic;
	signal flag_r : std_logic;
	signal flag_f : std_logic;
begin
	edge_inst2 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => flag_state,
			rising  => flag_r,
			falling => flag_f
		);
	process (clk, rst_n) begin
		if rst_n = '0' then
			cnt <= 0;
		elsif rising_edge(clk) then
			if cnt < cnt'high then
				cnt <= cnt + 1;
			else cnt <= 0;
				flag_state <= not flag_state;
			end if;
		end if;
	end process;

	process (clk, rst_n) begin
		if rst_n = '0' then
			PWM <= '0';
		elsif rising_edge(clk) then
			
			case mode_s is
				when HI =>
					if cnt >= hi_bound then
						PWM <= '0';
					elsif cnt < hi_bound then
						PWM <= '1';
					end if;
					if flag_r = '1' then
						mode_s <= LO;
					end if;
				when LO =>
					if cnt >= lo_bound then
						PWM <= '0';
					elsif cnt < lo_bound then
						PWM <= '1';
					end if;
					if flag_f = '1' then
						mode_s <= HI;
					end if;
			end case;
		end if;
	end process;
	

end arch;
