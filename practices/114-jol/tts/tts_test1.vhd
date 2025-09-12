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
		key_row : in u4r_t;
		key_col : out u4r_t;
		dbg_a                                                   : out u8r_t

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
	signal key : i4_t;
	signal key_pressed  : i4_t;
	type state_t is (idle, play, stop);
	signal state : state_t:= idle;
	--timer
	signal ena_tim: std_logic:='0';
	signal msec: integer range 0 to 1000:=0;
	-- "語音測試一", 10
	-- tts_data(0 to 9) <= test1;
	-- tts_len <= 10;
	constant test1 : u8_arr_t(0 to 9) := (
		x"bb", x"79", x"ad", x"b5", x"b4", x"fa", x"b8", x"d5", x"a4", x"40"
	);

	-- "語音測試二", 10
	-- tts_data(0 to 9) <= test2;
	-- tts_len <= 10;
	constant test2 : u8_arr_t(0 to 9) := (
		x"bb", x"79", x"ad", x"b5", x"b4", x"fa", x"b8", x"d5", x"a4", x"47"
	);

	-- "語音測試三", 10
	-- tts_data(0 to 9) <= test3;
	-- tts_len <= 10;
	constant test3 : u8_arr_t(0 to 9) := (
		x"bb", x"79", x"ad", x"b5", x"b4", x"fa", x"b8", x"d5", x"a4", x"54"
	);

	--2001.wav (你睡了之後)
	constant music1 : u8_arr_t(0 to 4) := (tts_play_file, x"07", x"d1", x"00", X"01");	

	-- "劉恩瑋，沒有正備取國手，不要回來了", 34
	-- tts_data(0 to 33) <= lorry;
	-- tts_len <= 34;
	constant lorry : u8_arr_t(0 to 33) := (
		x"B0", x"AA", x"A6", x"74", x"BF", x"41", x"a1", x"41", x"a8", x"53", x"a6", x"b3", x"a5", x"bf", x"b3", x"c6",
		x"a8", x"fa", x"b0", x"ea", x"a4", x"e2", x"a1", x"41", x"a4", x"a3", x"ad", x"6e", x"a6", x"5e", x"a8", x"d3",
		x"a4", x"46"
	);

	-- "你電電", 6
	-- tts_data(0 to 5) <= shut;
	-- tts_len <= 6;
	constant shut : u8_arr_t(0 to 5) := (
		x"a7", x"41", x"b9", x"71", x"b9", x"71"
	);

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
			sig_in => pressed_i,
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
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);
	process (rst_n, clk)
	begin
		if rst_n = '0' then
			state <= idle;
			ena <= '0';
		elsif rising_edge(clk) then
			dbg_a(4)<=busy;
			dbg_a(5)<=ena;
			if state = idle then
				dbg_a(0)<='0';
				dbg_a(1)<='1';
				dbg_a(2)<='1';
			elsif state = play then
				dbg_a(0)<='1';
				dbg_a(1)<='0';
				dbg_a(2)<='1';
			elsif state=stop then
				dbg_a(0)<='1';
				dbg_a(1)<='1';
				dbg_a(2)<='0';
			end if;
			ena <= '0';
			case state is
				when idle =>
					if pressed = '1' then
						key_pressed <= key;
						state <= play;
						dbg_a(7)<=not dbg_a(7);
					end if;
				when play =>
					
					case key_pressed is
						when 0 =>
							ena <= '1';
							txt(0 to 5) <= shut;
							len <= 6;
						when 1 =>
							ena <= '1';
							txt(0 to 4) <= music1;
							len <= 5;
						when 2 =>
							ena <= '1';
							txt(0 to 33) <= lorry;
							len <= 34;
						when 15 =>
							ena <= '1';	
							txt(0 to 1) <=tts_instant_soft_reset;
							len<=2;
						when others => 
							ena <= '0'; 
							state <= idle;
					end case;
					if busy = '1' then 
						ena <= '0'; 
						key_pressed <= 5;
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
