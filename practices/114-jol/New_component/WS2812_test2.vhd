library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity WS2812_test2 is
	port (
		-- system
		clk, rst_n : in std_logic;
		--
		button : in std_logic;
		D_out  : out std_logic;
		dbg_a  : out std_logic_vector(7 downto 0);
		dbg_b  : out std_logic_vector(3 downto 0)
	);
end WS2812_test2;

architecture arch of WS2812_test2 is
	type state_t is (idle, sure, work, stay);
	signal mode_t : state_t := idle;
	-- type state_s is (HI, LO);
	-- signal mode_s : state_s := HI;
	--sys
	signal timer_ena : std_logic;
	signal sw_d : std_logic_vector(7 downto 0) := (others => '0');
	signal but_d : std_logic;
	signal but_r : std_logic;
	signal ws_ena : std_logic;
	signal ws_busy : std_logic;
	signal ws_busy_f : std_logic;
	signal led_num_max : integer range 0 to 64 := 8;
	signal led_num : integer range 0 to led_num_max := 8;
	signal rgb_data : l_px_arr_t(0 to led_num_max - 1) := (x"0f0000", x"000f00", x"00000f", x"0f0f0f", x"ffff00", x"ff00ff", x"00ffff", x"ffffff");
	signal msec : integer range 0 to 1000;

	component debounce is
		generic (
			stable_time : integer := 10
		);
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			sig_out    : out std_logic
		);
	end component;
	component WS2812B is
		generic (
			led_num_max : integer := 8
		);
		port (
			clk, rst_n : in std_logic;
			ena        : in std_logic;
			busy       : out std_logic;
			rgb_data   : in l_px_arr_t(0 to led_num_max - 1);
			D_out      : out std_logic;
			dbg_a      : out std_logic_vector(7 downto 0);
			led_num    : in integer range 0 to led_num_max
		);
	end component;
	component edge is
		port (
			clk, rst_n : in std_logic;
			sig_in     : in std_logic;
			rising     : out std_logic;
			falling    : out std_logic
		);
	end component;
	component timer is
		port (
			clk, rst_n : in std_logic;
			ena        : in std_logic;
			load       : in i32_t;
			msec       : out i32_t
		);
	end component;
begin
	components : block begin
		timer_inst : timer
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => 0,
			msec  => msec
		);
		debounce_inst9 : debounce
		generic map(
			stable_time => 10
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => button,
			sig_out => but_d
		);
		WS2812_inst : WS2812B
		generic map(
			led_num_max => 8
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			ena      => ws_ena,   --in
			busy     => ws_busy,  --out
			rgb_data => rgb_data, --in
			D_out    => D_out,    --out
			dbg_a    => dbg_a,    --out
			led_num  => led_num
		);
		edge_inst1 : edge
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => but_d,
			rising  => but_r,
			falling => open
		);
		edge_inst : edge
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ws_busy,
			rising  => open,
			falling => ws_busy_f
		);
	end block components;

	dbg_test : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				dbg_b(3 downto 1) <= (others => '0');
			elsif rising_edge(clk) then
				case mode_t is
					when idle => null;
					when sure => dbg_b(1) <= '1';
					when work => dbg_b(2) <= '1';
					when stay => dbg_b(3) <= '1';
				end case;
			end if;
		end process;
		dbg_b(0) <= '0' when mode_t = idle else '1';
	end block dbg_test;

	Main_Process : block begin
		process (clk, rst_n) begin
			if rst_n = '0' then
			elsif rising_edge(clk) then
				case mode_t is
					when idle =>
						ws_ena <= '0';
						if but_r = '1' then
							mode_t <= sure;
						end if;
					when sure =>
						ws_ena <= '1';
						rgb_data <= rgb_data(1 to 7) & rgb_data(0);
						mode_t <= work;
						-- if but_r = '1' then
						-- 	mode_t <= idle;
						-- end if;
					when work =>
						ws_ena <= '0';
						if ws_busy_f = '1' then
							mode_t <= stay;
							timer_ena <= '1';
						end if;
						-- if but_r = '1' then
						-- 	mode_t <= idle;
						-- end if;
					when stay =>
						if msec > 100 then
							mode_t <= sure;
							timer_ena <= '0';
						end if;
						if but_r = '1' then
							mode_t <= idle;
						end if;
				end case;
			end if;

		end process;
	end block Main_Process;

end arch;
