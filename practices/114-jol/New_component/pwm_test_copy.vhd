library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity PWM_TEST is

	port (
		-- system
		clk, rst_n : in std_logic;
		--
		SW  : in std_logic;
		PWM : out std_logic

	);
end PWM_TEST;

architecture arch of PWM_TEST is
	-- type state_t is (idle, RED_color, GRE_color, BLE_color);
	-- signal mode_t : state_t := RED_color;
	-- type state_s is (HI, LO);
	-- signal mode_s : state_s := HI;
	signal cnt : integer range 0 to 59 := 0;
	-- signal PWM_k : integer range 0 to 4 := 0;
	signal up_bound : integer range 0 to 59 := 30;
	signal cnt_sw : std_logic;
	signal sw_d : std_logic;
	signal sw_edge : std_logic;
begin
	debounce_inst : entity work.debounce(arch)
		generic map(
			stable_time => 20
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => SW,
			sig_out => sw_d
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => sw_d,
			rising  => open,
			falling => sw_edge
		);
	process (clk, rst_n) begin
		if rst_n = '0' then
			cnt <= 0;
		elsif rising_edge(clk) then
			if cnt < cnt'high then
				cnt <= cnt + 1;
			else cnt <= 0;
			end if;
		end if;
	end process;

	process (clk, rst_n) begin
		if rst_n = '0' then
			PWM <= '0';
		elsif rising_edge(clk) then
			if cnt >= up_bound then
				PWM <= '0';
			elsif cnt < up_bound then
				PWM <= '1';
			end if;
		end if;
	end process;
	process (clk, rst_n) begin
		if rst_n = '0' then
			up_bound <= 0;
		elsif rising_edge(clk) then
			if sw_edge = '1' then
				if up_bound < up_bound'high then
					up_bound <= up_bound + 1;
				else up_bound <= 0;
				end if;
			end if;
		end if;
	end process;

end arch;
