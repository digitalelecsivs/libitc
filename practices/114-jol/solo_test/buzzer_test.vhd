library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
entity buzzer_test is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		--key
		key_row : in u4r_t;
		key_col : out u4r_t;
		--buzzer
		buz : out std_logic; --'1' 叫  '0' 不叫
		--led(r g y)
		dbg_a : out u8r_t;
		dbg_b : out u8r_t
	);
end buzzer_test;

architecture arch of buzzer_test is
	--buz
	signal buz_ena : std_logic;
	signal buz_busy : std_logic;
	signal tim : integer range 0 to 10000;
	--key
	signal pressed, pressed_i : std_logic;
	signal key : integer range 0 to 15;
	--timer
	signal ena_tim : std_logic := '1';
	signal msec : integer range 0 to 4000 := 0;
	type state is (idle, play, waiting,init);
	signal mode : state := idle;
	signal trigger_i, trigger : std_logic;
begin

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	buzzer_inst : entity work.buzzer(arch)
		generic map(
			msec_max => 10000
		)
		port map(
			clk   => clk,
			rst_n => rst_n,
			tim   => tim,
			ena   => buz_ena, --enable '1' 動作 --rising_edge
			buz   => buz,     --腳位
			busy  => buz_busy, --發聲時busy='1'
			led =>  dbg_b(4 to 6)
		);
	dbg_a(0 to 3) <= not ("1000") when mode = idle else
	not ("0100") when mode = play else
	not ("0010") when mode = waiting else not ("0000");
	dbg_b(0 to 3) <= to_unsigned(key,4);
	dbg_a(4 to 7) <= not (buz_busy & buz_ena & "00");
	process (clk, rst_n) begin
		if rst_n = '0' then
			buz_ena <= '0';
			tim <= 0;
			mode <= idle;
		elsif rising_edge(clk) then
			case mode is
				when init =>
					buz_ena <= '0';
					tim <= 0;
					mode <= idle;
				when idle =>
					if pressed_i = '1' then
						tim <= 2000;
						buz_ena <= '1';
					else
						buz_ena <= '0';
						tim <= 0;
						mode <= init;
					end if;
					if buz_busy = '1' then
						buz_ena <= '1';
						mode <= waiting;
					end if;
				when play =>
					
				when waiting =>
					if buz_busy = '0' then
						buz_ena <= '0';
						tim <= 0;
						mode <= init;
					end if;
			end case;
		end if;
	end process;
end arch;
