library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;

entity pwm_mot is
	port (
		clk, rst_n : in std_logic; -- system clock
		rgb        : out std_logic_vector(0 to 2);
		sw         : in u8r_t;
		mot_ch     : out u2r_t;
		mot_ena    : out u2r_t
	);
end pwm_mot;

architecture arch of pwm_mot is
	signal duty : integer range 0 to 100;
	signal pwm : std_logic;
	signal clk_cnt : std_logic;
	signal UD_flag : std_logic;
	signal pwm_3 : std_logic_vector(0 to 2);
begin
	clk_inst1 : entity work.clk(arch)
		generic map(
			freq => 100
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_cnt
		);

	pwm_inst : entity work.pwm(arch)
		generic map(
			pwm_freq => 1000
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => duty,
			pwm_out => pwm
		);
	process (clk_cnt, rst_n) begin
		if (rising_edge(clk_cnt)) then
			if (UD_flag = '1') then
				duty <= duty + 1;
				if (duty = 99) then
					UD_flag <= '0';
				end if;
			elsif (UD_flag = '0') then
				duty <= duty - 1;
				if (duty = 1) then
					UD_flag <= '1';
				end if;
			end if;
		end if;
	end process;
	pwm_3 <= pwm & pwm & pwm;
	mot_ena<=pwm&pwm;
	mot_ch<="11";
	with sw(0 to 2) select
	rgb <= pwm_3 and"111" when "111",
		pwm_3 and"100" when"100",
		pwm_3 and"010" when"010",
		pwm_3 and"001" when"001",
		pwm_3 and"110" when"110",
		pwm_3 and"011" when"011",
		pwm_3 and"101" when"101",
		pwm_3 and"000" when"000", "000" when others;
end arch;
