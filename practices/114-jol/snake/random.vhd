library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
entity random is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		dbg_b : out u8r_t
	);
end random;

architecture arch of random is
	signal lfsr : u8r_arr_t := (X"23", X"32", X"02", X"00", X"00", X"00", X"00", X"00"); -- 初始值不可全 0
	signal clk_out : std_logic;
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 10
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_out
		);
	process (clk_out, rst_n)
	begin
		if rst_n = '0' then
			lfsr <= (X"23", X"32", X"02", X"00", X"00", X"00", X"00", X"00");
		elsif rising_edge(clk_out) then
			-- 使用 x^8 + x^6 + x^5 + x^4 + 1 的多項式
			-- lfsr <= (lfsr(1), (lfsr(2)xor lfsr(7)), (lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3)), lfsr(4), lfsr(5), lfsr(6), (lfsr(3) xor not lfsr(2) xor lfsr(1)), (lfsr(1) xor lfsr(0)));
		end if;
	end process;

	dbg_b <= lfsr;
end arch;
