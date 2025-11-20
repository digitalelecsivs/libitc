library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;
entity tts_test is
	port (
		clk, rst_n       : in std_logic;
		
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		key_row          : in u4r_t;
		key_col          : out u4r_t;
		
		dbg_a                                                   : out u8r_t;
		dbg_b:in std_logic
	);
end tts_test;

architecture arch of tts_test is
	constant max_len : integer := 34;

	signal tts_ena : std_logic;
	signal tts_busy : std_logic;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal txt_len : integer range 0 to max_len;
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key,key_t : i4_t;

	type state is (idle, play, stop);
	signal mode : state:=idle;
	--0123，456789
	constant num : u8_arr_t(0 to 11) := (
	x"30",x"31", x"32", x"33",x"A1",x"41", x"34", x"35", x"36", x"37", x"38", x"39"
	);
	-- "語音測試一", 10
	-- tts_data(0 to 9) <= test1;
	-- tts_len <= 10;
	constant test1 : u8_arr_t(0 to 9) := (
	x"bb", x"79", x"ad", x"b5", x"b4", x"fa", x"b8", x"d5", x"a4", x"40"
	);
begin
	tts_rst_n <= rst_n;
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
			ena       => tts_ena,
			busy      => tts_busy,
			txt       => txt,
			txt_len   => txt_len
		);
	key_inst: entity work.key(arch)
		port map (
			clk => clk,
			rst_n => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key => key_t
		);
	edge_key: entity work.edge(arch)
		port map (
			clk => clk,
			rst_n => rst_n,
			sig_in => pressed_i,
			rising => pressed,
			falling => open
		);
	process (rst_n, clk) begin
		if rst_n = '0' then
			mode <= idle;
			tts_ena <= '0';
		elsif rising_edge(clk) then
			if mode = idle then
				dbg_a(0)<='0';
				dbg_a(1)<='1';
				dbg_a(2)<='1';
			elsif mode = play then
				dbg_a(0)<='1';
				dbg_a(1)<='0';
				dbg_a(2)<='1';
			elsif mode = stop then
				dbg_a(0)<='1';
				dbg_a(1)<='1';
				dbg_a(2)<='0';
			end if;
			if tts_busy ='1' then 
				dbg_a(3) <= not dbg_a(3);
			end if;
			case mode is
				when idle =>
					if pressed = '1' then
						key <= key_t;
						mode <= play;
					end if;
				when play =>
					case key is
						when 0 =>
							txt(0 to 9) <= test1;
							txt_len <= 10;
							tts_ena <= '1';
						when 1 =>
							txt(0 to 11) <= num;
							txt_len <= 12;
							tts_ena <= '1';
						when others => 
							tts_ena <= '0'; 
							mode <= idle;
					end case;
					if tts_busy = '1' then 
						mode <= stop;
					end if;
				when stop =>
					if tts_busy = '0' then
						tts_ena <= '0';
						mode <= idle;
					end if;
				end case;
		end if;
	end process;
end arch;
