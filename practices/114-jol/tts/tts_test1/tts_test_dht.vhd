library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;
entity tts_test1 is
	port (
		clk, rst_n       : in std_logic;
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- key
		key_start		 : in std_logic;
		-- dht
		dht_data		 : inout std_logic; 
		dbg_a   : out u8r_t

	);
end tts_test1;

architecture arch of tts_test1 is
	constant max_len : integer := 34;

	signal ena : std_logic;
	signal busy : std_logic;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal init_n : Integer range 0 to 3:=0;
	--key
	signal pressed, pressed_i : std_logic;

	type state_t is (init ,idle, play, stop);
	signal state : state_t:=init;
	--timer
	signal ena_tim: std_logic;
	signal msec: integer range 0 to 1000:=0;
	-- "�y�����դ@", 10
	-- tts_data(0 to 9) <= test1;
	-- tts_len <= 10;
	constant test1 : u8_arr_t(0 to 9) := (
		x"bb", x"79", x"ad", x"b5", x"b4", x"fa", x"b8", x"d5", x"a4", x"40"
	);
	--DHT11
	signal temp_int, hum_int : integer range 0 to 99;
	constant temp : u8_arr_t(0 to 5) := (
	x"b7", x"c5", x"ab", x"d7", x"ac", x"b0");
begin
	timer_inst: entity work.timer(arch)
	port map (
		clk => clk,
		rst_n => rst_n,
		ena => ena_tim,
		load => 0,
		msec => msec
	);
	key_edge: entity work.edge(arch)
		port map (
			clk =>clk,
			rst_n => rst_n,
			sig_in => not key_start,
			rising => pressed,
			falling => open
		);
	tts_inst : entity work.tts(arch)
		generic map(
			txt_len_max => max_len
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			tts_scl   => tts_scl,
			tts_sda   => tts_sda,
			tts_mo    => tts_mo,
			tts_rst_n => tts_rst_n,
			ena       => ena,
			busy      => busy,
			txt       => txt,
			txt_len   => len
		);
	dht_inst : entity work.dht(arch)
			port map(
				clk      => clk,
				rst_n    => rst_n,
				dht_data => dht_data,
				temp_int => temp_int,
				temp_dec => open,
				hum_int  => hum_int,
				hum_dec  => open
			);
	process (rst_n, clk)
	begin
		if rst_n = '0' then
			state <= init;
			ena <= '0';
		elsif rising_edge(clk) then
			dbg_a(0)<=busy;
			dbg_a(1)<=ena;
			if state = idle then
				dbg_a(2)<='0';
				dbg_a(3)<='1';
				dbg_a(4)<='1';
			elsif state = play then
				dbg_a(2)<='1';
				dbg_a(3)<='0';
				dbg_a(4)<='1';
			elsif state=stop then
				dbg_a(2)<='1';
				dbg_a(3)<='1';
				dbg_a(4)<='0';
			end if;
			ena <= '0';
			case state is
				when init =>
					ena_tim<='1';
					if msec >300 then 
						state <=idle;
						init_n<=0;
						ena_tim<='0';
					end if; 
					
				when idle =>
					txt(0 to 11) <=temp(0 to 5) & to_big(temp_int) ;
					if pressed = '1' then
						state <= play;
					end if;
				when play =>
					ena <= '1';
					--txt(0 to 9) <= test1;
					len <= 12;
					
					if busy = '1' then 
						ena <= '0'; 
						state <= stop;
					end if;
				when stop =>
					if busy = '0' then
						state <= idle;
					end if;
				end case;
		end if;
	end process;
end arch;
