library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity keytest is
	port (
		clk              : in std_logic;
		rst_n            : in std_logic;
		key_row          : in u4r_t;
		key_col          : out u4r_t;
		sw               : in u8r_t;
		seg_led, seg_com : out u8r_t; -- seg
		dbg_a            : out u8r_t;
		dbg_b            : out u8r_t
	);
end keytest;

architecture arch of keytest is
	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal seg_data : string(1 to 8) := (others => ' ');
begin
	seg_inst : entity work.seg(arch)--8bit七段顯示器元件
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0')
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
	key_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	process (clk) begin
		if rst_n = '0' then
		elsif rising_edge(clk) then
			if pressed = '1' then
				dbg_a(0 to 3) <= not (to_unsigned(key, 4));
				dbg_b <= sw;
				seg_data <= seg_data(3 to 8) & to_string(key, key'high, 10, 2);
			end if;

		end if;
	end process;

end arch;
