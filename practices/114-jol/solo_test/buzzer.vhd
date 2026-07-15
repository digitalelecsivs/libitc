library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
entity buzzer is
	generic (
		msec_max : integer := 3000
	);

	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		tim   : in integer range 0 to msec_max;
		ena   : in std_logic;
		buz   : out std_logic;
		busy  : out std_logic;
		led   : out unsigned(0 to 2)
	);
end buzzer;

architecture arch of buzzer is
	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 10000 := 0;

	signal ena_e : std_logic;
	signal buz_tim : integer range 0 to 3000;
	type state is (idle, play, stop);
	signal mode : state := idle;
	signal trigger_i, trigger : std_logic;
begin

	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => '1',
			load  => 0,
			msec  => msec
		);
	edge_ena : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ena,
			rising  => ena_e,
			falling => open
		);
	led <= "100" when mode = idle else
		"010" when mode = play else
		"001" when mode = stop else "000";
	process (clk, rst_n) begin
		if rst_n = '0' then
			mode <= idle;
			busy <= '0';
			buz <= '0';
		elsif rising_edge(clk) then
			case mode is
				when idle =>
					if ena = '1' then
						mode <= play;
					else
						busy <= '0';
						buz <= '0';
					end if;
				when play =>
					if ena = '1' then
						busy <= '1';
						buz <= '1';
						mode <= stop;
					else
						busy <= '0';
						buz <= '0';
						mode <= idle;
					end if;

				when stop =>
					ena_tim <= '1';
					if msec > tim   then
						ena_tim <= '0';
						buz <= '0';
						busy <= '0';
						mode <= idle;
					end if;

			end case;

		end if;
	end process;
end arch;
