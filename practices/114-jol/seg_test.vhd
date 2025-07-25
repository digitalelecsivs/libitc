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
		sw : in u8r_t;
		-- seg
		seg_led, seg_com : out u8r_t
	);
end seg_test;

architecture arch of seg_test is

	signal clocks : u8r_t;
	signal clk_cnt : std_logic;
	signal base : integer range 1 to 16;
	signal cnt : integer range 0 to 99_999_999 := 0;
	signal cnt1 : integer range 0 to 9 := 0;
begin

	clk_gen : for i in 0 to 7 generate
		clk_inst : entity work.clk(arch)
			generic map(
				freq => 10 ** i
			)
			port map(
				clk_in  => clk,
				rst_n   => rst_n,
				clk_out => clocks(i)
			);
	end generate clk_gen;

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => to_string(cnt, cnt'high, base, 8),
			dot => (others => '0')
		);
	base <= 8;
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
	clk_cnt <= clocks(0);
	process (clk_cnt, rst_n) begin
		if rst_n = '0' then
			cnt <= 0;
		elsif rising_edge(clk_cnt) then
			if cnt1 = cnt1'high then
				cnt1 <= 0;
			end if;
			cnt1 <= cnt1 + 1;
			if cnt1 = 0 then
				cnt <= 00_000_000;
			elsif cnt1 = 1 then
				cnt <= 11_111_111;
			elsif cnt1 = 2 then
				cnt <= 22_222_222;
			elsif cnt1 = 3 then
				cnt <= 33_333_333;
			elsif cnt1 = 4 then
				cnt <= 44_444_444;
			elsif cnt1 = 5 then
				cnt <= 55_555_555;
			elsif cnt1 = 6 then
				cnt <= 66_666_666;
			elsif cnt1 = 7 then
				cnt <= 77_777_777;
			elsif cnt1 = 8 then
				cnt <= 88_888_888;
			elsif cnt1 = 9 then
				cnt <= 99_999_999;
			end if;
		end if;
	end process;

end arch;
