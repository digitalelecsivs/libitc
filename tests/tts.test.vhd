library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic
	);
end tts_test;

architecture arch of tts_test is

	constant max_len : integer := 242;

	-- "給我一瓶酒/再給我一支菸/說走就走/我有的是時間/我不想在未來的日子裡/獨自哭著無法往前", 83
	-- txt(0 to 82) <= song;
	-- len <= 83;
	constant song : u8_arr_t(0 to 82) := (
		x"b5", x"b9", x"a7", x"da", x"a4", x"40", x"b2", x"7e", x"b0", x"73", x"2f", x"a6", x"41", x"b5", x"b9", x"a7",
		x"da", x"a4", x"40", x"a4", x"e4", x"b5", x"d2", x"2f", x"bb", x"a1", x"a8", x"ab", x"b4", x"4e", x"a8", x"ab",
		x"2f", x"a7", x"da", x"a6", x"b3", x"aa", x"ba", x"ac", x"4f", x"ae", x"c9", x"b6", x"a1", x"2f", x"a7", x"da",
		x"a4", x"a3", x"b7", x"51", x"a6", x"62", x"a5", x"bc", x"a8", x"d3", x"aa", x"ba", x"a4", x"e9", x"a4", x"6c",
		x"b8", x"cc", x"2f", x"bf", x"57", x"a6", x"db", x"ad", x"fa", x"b5", x"db", x"b5", x"4c", x"aa", x"6b", x"a9",
		x"b9", x"ab", x"65"
	);

	-- "聽講，露西時常做運動，身體健康精神好，露西！哩洗那欸加你搞，身體健康精神好，規律運動不可少，沒事常做健康操，全身
	-- 運動功效好，喂，同學，歸勒百欸穩懂安抓來安白，杯題阿哇的有擘吼哩哉，咖嘛北鼻當賊來，麼地有135，麼地有246，西
	-- 哉金裡嗨，搭給當賊來。", 242
	-- txt(0 to 241) <= what;
	-- len <= 242;
	constant what : u8_arr_t(0 to 241) := (
		x"c5", x"a5", x"c1", x"bf", x"a1", x"41", x"c5", x"53", x"a6", x"e8", x"ae", x"c9", x"b1", x"60", x"b0", x"b5",
		x"b9", x"42", x"b0", x"ca", x"a1", x"41", x"a8", x"ad", x"c5", x"e9", x"b0", x"b7", x"b1", x"64", x"ba", x"eb",
		x"af", x"ab", x"a6", x"6e", x"a1", x"41", x"c5", x"53", x"a6", x"e8", x"a1", x"49", x"ad", x"f9", x"ac", x"7e",
		x"a8", x"ba", x"d5", x"d9", x"a5", x"5b", x"a7", x"41", x"b7", x"64", x"a1", x"41", x"a8", x"ad", x"c5", x"e9",
		x"b0", x"b7", x"b1", x"64", x"ba", x"eb", x"af", x"ab", x"a6", x"6e", x"a1", x"41", x"b3", x"57", x"ab", x"df",
		x"b9", x"42", x"b0", x"ca", x"a4", x"a3", x"a5", x"69", x"a4", x"d6", x"a1", x"41", x"a8", x"53", x"a8", x"c6",
		x"b1", x"60", x"b0", x"b5", x"b0", x"b7", x"b1", x"64", x"be", x"de", x"a1", x"41", x"a5", x"fe", x"a8", x"ad",
		x"b9", x"42", x"b0", x"ca", x"a5", x"5c", x"ae", x"c4", x"a6", x"6e", x"a1", x"41", x"b3", x"de", x"a1", x"41",
		x"a6", x"50", x"be", x"c7", x"a1", x"41", x"c2", x"6b", x"b0", x"c7", x"a6", x"ca", x"d5", x"d9", x"c3", x"ad",
		x"c0", x"b4", x"a6", x"77", x"a7", x"ec", x"a8", x"d3", x"a6", x"77", x"a5", x"d5", x"a1", x"41", x"aa", x"4d",
		x"c3", x"44", x"aa", x"fc", x"ab", x"7a", x"aa", x"ba", x"a6", x"b3", x"c0", x"bc", x"a7", x"71", x"ad", x"f9",
		x"ab", x"76", x"a1", x"41", x"a9", x"40", x"b9", x"c0", x"a5", x"5f", x"bb", x"f3", x"b7", x"ed", x"b8", x"e9",
		x"a8", x"d3", x"a1", x"41", x"bb", x"f2", x"a6", x"61", x"a6", x"b3", x"31", x"33", x"35", x"a1", x"41", x"bb",
		x"f2", x"a6", x"61", x"a6", x"b3", x"32", x"34", x"36", x"a1", x"41", x"a6", x"e8", x"ab", x"76", x"aa", x"f7",
		x"b8", x"cc", x"b6", x"d9", x"a1", x"41", x"b7", x"66", x"b5", x"b9", x"b7", x"ed", x"b8", x"e9", x"a8", x"d3",
		x"a1", x"43"
	);

	-- "啊", 2
	-- txt(0 to 1) <= ah;
	-- len <= 2;
	constant ah : u8_arr_t(0 to 6) := (
		tts_set_vol,x"f0",tts_play_file, x"27",x"0f",x"00",x"01"
	);

	constant datasheet_example : u8_arr_t(0 to 58) := (
		x"b5", x"be", x"ad", x"b5", x"ac", x"ec", x"a7", x"de", x"31", x"37", x"38", x"42", x"b4", x"fa", x"b8", x"d5", -- 翔音科技178b測試
		x"86", x"e0", -- volume = 0xe0
		x"83", x"14", -- speed = 120%
		x"b5", x"be", x"ad", x"b5", x"ac", x"ec", x"a7", x"de", x"31", x"37", x"38", x"42", x"b4", x"fa", x"b8", x"d5", -- 翔音科技178b測試
		x"83", x"00", -- speed = 100%
		x"b5", x"a5", x"ab", x"dd", x"a4", x"51", x"ac", x"ed", x"c4", x"c1", -- 等待十秒鐘
		x"87", x"00", x"00", x"03", x"e8", -- delay 1000ms
		x"ae", x"c9", x"b6", x"a1", x"a8", x"ec" -- 時間到
	);

	signal ena : std_logic;
	signal busy : std_logic;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;

	signal pressed : std_logic;
	signal key, key_pressed : i4_t;

	type state_t is (idle, send, stop);
	signal state : state_t;

begin

	tts_inst: entity work.tts(arch)
		generic map (
			txt_len_max => max_len
		)
		port map (
			clk => clk,
			rst_n => rst_n,
			tts_scl => tts_scl,
			tts_sda => tts_sda,
			tts_mo => tts_mo,
			tts_rst_n => tts_rst_n,
			ena => ena,
			busy => busy,
			txt => txt,
			txt_len => len
		);

	key_inst: entity work.key(arch)
		port map (
			clk => clk,
			rst_n => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key => key
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			state <= idle;
			ena <= '0';
		elsif rising_edge(clk) then
			-- default values
			ena <= '0';

			case state is
				when idle =>
					if pressed = '1' then
						key_pressed <= key;
						state <= send;
					end if;

				when send =>
					ena <= '1'; -- toggle enable
					case key_pressed is
						when 0 =>
							txt(0 to 82) <= song;
							len <= 83;

						when 1 =>
							txt(0 to 241) <= what;
							len <= 242;

						when 2 =>
							txt(0 to 6) <= ah;
							len <= 7 ;

						when 3 =>
							txt(0 to 58) <= datasheet_example;
							len <= 59;

						when others => 
							ena <= '0'; -- cancel enable
							state <= idle;
					end case;

					if busy = '1' then -- enable confirmed
						ena <= '0'; -- reset enable
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
