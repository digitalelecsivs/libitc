-- BCD counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity seg_test is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- sw
		-- seg
		seg_led, seg_com : out u8r_t
	);
end seg_test;

architecture arch of seg_test is

	signal clock : std_logic;
	signal clk_cnt : std_logic;

	signal cnt : integer range 0 to (2 ** 7 - 1) := 65;

	signal seg : string(1 to 8);
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clock
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg,
			dot => (others => '0')
		);

	-- with to_integer(reverse(sw(0 to 1))) select base <=
	-- 2 when 0,
	-- 8 when 1,
	-- 10 when 2,
	-- 16 when others; -- 3

	--	clk_cnt <= clocks(to_integer(reverse(sw(5 to 7))));
	-- clk_cnt <= clocks(1) when sw(5 to 7) = "000" else
	-- 	clocks(2) when sw(5 to 7) = "001" else
	-- 	clocks(3) when sw(5 to 7) = "010" else
	-- 	clocks(4) when sw(5 to 7) = "100" else clocks(5);
	-- clk_cnt <= clocks(1) when sw(5 to 7) = "000" else clocks(5);
	clk_cnt <= clock;
	process (clk_cnt, rst_n) begin
		if rst_n = '0' then
			cnt <= 65;
		elsif rising_edge(clk_cnt) then
			if cnt = cnt'high then
				cnt <= 65;
			end if;
			cnt <= cnt + 1;
			seg(8) <= Character'val(cnt);
			
			-- seg(1) <= to_string(cnt, cnt'high,2, 1);
			seg(1 to 7) <= seg(2 to 8);
		end if;
	end process;
end arch;
