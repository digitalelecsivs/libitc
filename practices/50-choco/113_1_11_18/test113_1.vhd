library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;

entity test113_1 is
	port (
		clk, rst_n : in std_logic;
		--seg
		seg_led, seg_com : out u8r_t;

		--sw
		sw : in u8r_t;

		-- key
		key_row : in u2r_t;
		key_col : out u2r_t;

		--8*8 dot led
		dot_red, dot_green, dot_com : out u8r_t;

		-- tts
		tts_scl, tts_sda                                        : inout std_logic;
		tts_mo                                                  : in unsigned(2 downto 0);
		dbg_a                                                   : out u8r_t;
		tts_rst_n                                               : out std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;

		--uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end test113_1;

architecture arch of test113_1 is
	--8*8 dot led
	signal data_g, data_r : u8r_arr_t(0 to 7);

	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--tts
	signal tts_ena, tts_reset : std_logic;
	signal busy : std_logic;
	constant max_len : integer := 36;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal tts_done : std_logic;
	type tts_mode_t is (idle, play, waiting, stop);
	signal tts_mode : tts_mode_t;
	signal tts_data : string(1 to 12);
	signal seg_flag : std_logic;

	-- "圖形往上方移動", 14
	constant way_u : u8_arr_t(0 to 13) := (x"b9", x"cf", x"a7", x"ce", x"a9", x"b9", x"a4", x"57", x"a4", x"e8", x"b2", x"be", x"b0", x"ca");
	-- "圖形往下方移動", 14
	constant way_d : u8_arr_t(0 to 13) := (x"b9", x"cf", x"a7", x"ce", x"a9", x"b9", x"a4", x"55", x"a4", x"e8", x"b2", x"be", x"b0", x"ca");
	-- "圖形往右方移動", 14
	constant way_r : u8_arr_t(0 to 13) := (x"b9", x"cf", x"a7", x"ce", x"a9", x"b9", x"a5", x"6b", x"a4", x"e8", x"b2", x"be", x"b0", x"ca");
	-- "圖形往左方移動", 14
	constant way_l : u8_arr_t(0 to 13) := (x"b9", x"cf", x"a7", x"ce", x"a9", x"b9", x"a5", x"aa", x"a4", x"e8", x"b2", x"be", x"b0", x"ca");
	-- "實心幾何圖形產生"
	constant pic_gene : u8_arr_t(0 to 15) := (x"b9", x"ea", x"a4", x"df", x"b4", x"58", x"a6", x"f3", x"b9", x"cf", x"a7", x"ce", x"b2", x"a3", x"a5", x"cd");

	-- "配對圖形為六邊形", 16
	constant pic1 : u8_arr_t(0 to 15) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"a4", x"bb", x"c3", x"e4", x"a7", x"ce");
	-- "配對圖形為圓形", 14
	constant pic2 : u8_arr_t(0 to 13) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"b6", x"ea", x"a7", x"ce");
	-- "配對圖形為正方形", 16
	constant pic3 : u8_arr_t(0 to 15) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"a5", x"bf", x"a4", x"e8", x"a7", x"ce");
	-- "配對圖形為三角形", 16
	constant pic4 : u8_arr_t(0 to 15) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"a4", x"54", x"a8", x"a4", x"a7", x"ce");
	-- "配對圖形為稜形", 14
	constant pic5 : u8_arr_t(0 to 13) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"b8", x"57", x"a7", x"ce");
	-- "配對圖形為長方形", 16
	constant pic6 : u8_arr_t(0 to 15) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"aa", x"f8", x"a4", x"e8", x"a7", x"ce");
	-- "配對圖形為倒三角形", 16
	constant pic7 : u8_arr_t(0 to 17) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"ad", x"cb", x"a4", x"54", x"a8", x"a4", x"a7", x"ce");
	-- "配對圖形為八邊形", 16
	constant pic8 : u8_arr_t(0 to 15) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"a4", x"4b", x"c3", x"e4", x"a7", x"ce");

	-- "配對圖形為愛心", 14
	constant pic9 : u8_arr_t(0 to 13) := (x"b0", x"74", x"b9", x"ef", x"b9", x"cf", x"a7", x"ce", x"ac", x"b0", x"b7", x"52", x"a4", x"df");
	-- "配對成功", 8
	constant succeed : u8_arr_t(0 to 7) := (x"b0", x"74", x"b9", x"ef", x"a6", x"a8", x"a5", x"5c");
	-- "配對失敗", 8
	constant fail : u8_arr_t(0 to 7) := (x"b0", x"74", x"b9", x"ef", x"a5", x"a2", x"b1", x"d1");

	-- "無線連接成功", 12
	constant wifisucc : u8_arr_t(0 to 11) := (x"b5", x"4c", x"bd", x"75", x"b3", x"73", x"b1", x"b5", x"a6", x"a8", x"a5", x"5c");
	-- "無線連接失敗", 12
	constant wififail : u8_arr_t(0 to 11) := (x"b5", x"4c", x"bd", x"75", x"b3", x"73", x"b1", x"b5", x"a5", x"a2", x"b1", x"d1");

	-- "正在配對一號圖形"
	constant picture1 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"40", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對二號圖形"
	constant picture2 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"47", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對三號圖形 "
	constant picture3 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"54", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對四號圖形 "
	constant picture4 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a5", x"7c", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對五號圖形 "
	constant picture5 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"ad", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對六號圖形 "
	constant picture6 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"bb", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對七號圖形 "
	constant picture7 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"43", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	-- "正在配對八號圖形 "
	constant picture8 : u8_arr_t(0 to 15) := (x"a5", x"bf", x"a6", x"62", x"b0", x"74", x"b9", x"ef", x"a4", x"4b", x"b8", x"b9", x"b9", x"cf", x"a7", x"ce");

	--lcd_draw
	signal bg_color, text_color, data_1 : l_px_t;
	signal addr : l_addr_t;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal LCD_RESET : std_logic := '1';
	signal draw_done : std_logic;
	signal l_addr : l_addr_t;
	signal x, y : integer range 0 to 159;
	signal text_data : string(1 to 12) := "            ";
	signal text_color_array : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);

	type a is array(0 to 15) of std_logic_vector(0 to 23);
	signal pic_data_o : a;
	signal pics_data_o : a;
	signal wifi_data_o : a;
	signal red_data_o : a;
	type b is array(0 to 15) of l_px_t;
	signal pic_data : b;
	signal pics_data : b;
	signal wifi_data : b;

	type c is array(0 to 15) of l_addr_t;
	signal pic_addr : c;
	signal pics_addr : c;
	signal wifi_addr : c;

	type d is array(0 to 3) of std_logic_vector(0 to 23);
	signal line_data_o : d;
	type e is array(0 to 3) of l_px_t;
	signal line_data : e;
	type f is array(0 to 3) of l_addr_t;
	signal line_addr : f;
	--uart

	signal rx_start, rx_done, tx_mode : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_ena_e : std_logic;
	signal tx_data, rx_data : string(1 to 12);
	signal tx_len, rx_len : integer range 1 to 12;
	--timer
	signal msec, load, game_time : i32_t;
	signal timer_ena, timer_reset : std_logic;
	signal end_time : i32_t;
	--user
	type l_px_t_array is array (0 to 10) of l_px_t;
	type l_px_t_array_line is array (0 to 3) of l_px_t;

	type state is (start, print, move, check, reset, moving);
	signal state1 : state;
	signal state2 : state;
	signal state3 : state;
	signal sw_d : std_logic_vector(0 to 1);
	signal sel : integer range 0 to 8;
	type angle_array is array(0 to 8) of integer range 0 to 3;
	type color_array is array(0 to 8) of integer range 0 to 2;
	signal pic_color : color_array := (0, 0, 0, 0, 0, 0, 0, 0, 0);
	signal angle00 : angle_array;
	signal angle : integer range 0 to 3;
	type inter is array (0 to 8) of l_coord_t;
	type inter_l is array (0 to 3) of l_coord_t;
	type ANGLE_ID is array(0 to 7) of std_logic_vector(0 to 3);
	type reset_w is (start, cutdown, check, waiting, reset, connect, cleaning, ending);
	signal r_state11, r_state10 : reset_w;
	signal P_S : integer range 0 to 8 := 3;
	signal PIC_STATE : std_logic_vector(0 to 8) := "111111111";
	signal PIC_8 : std_logic;
	type pic_number_array is array(0 to 8) of integer range 0 to 9;
	signal pic_number : pic_number_array := (others => 0);
	signal pic_count : integer range 1 to 8;
	constant coord : inter := ((6, 0), (6, 40), (6, 85), (65, 0), (65, 40), (65, 85), (125, 0), (125, 40), (125, 85));
	constant font_coord : inter := ((18, 18), (18, 60), (18, 102), (77, 18), (77, 60), (77, 102), (136, 18), (136, 60), (136, 102));
	constant PIC_ANGLE : ANGLE_ID := ("1010", "1111", "1111", "1000", "1010", "1010", "1000", "1111");
	constant coord_line : inter_l := ((50, 0), (110, 0), (0, 42), (0, 84));
	constant gray : l_px_t := x"FFFFFF";
	signal tts_c : integer range 0 to 6;
	signal flag1, flag2 : std_logic;
	type random_array is array(0 to 8) of integer range 0 to 8;
	signal random : random_array := (0, 1, 2, 3, 4, 5, 6, 7, 8);
	signal random_r : random_array;
	signal index : integer range 0 to 9;
	signal random1 : integer range 0 to 7;
	signal random2 : integer range 0 to 7;
	signal wifi_count : integer range 1 to 3;
	signal clk1, clk_e1 : std_logic;
	signal fin_count : integer range 0 to 5;
	type pic_a is array(0 to 8) of integer range 0 to 8;
	signal red_array : pic_a := (0, 0, 0, 0, 1, 0, 0, 0, 0);
	signal success_flag, gene_flag : std_logic;
begin
	pic_data(0) <= unsigned(pic_data_o(0));
	pic_data(1) <= unsigned(pic_data_o(1));
	pic_data(2) <= unsigned(pic_data_o(2));
	pic_data(3) <= unsigned(pic_data_o(3));
	pic_data(4) <= unsigned(pic_data_o(4));
	pic_data(5) <= unsigned(pic_data_o(5));
	pic_data(6) <= unsigned(pic_data_o(6));
	pic_data(7) <= unsigned(pic_data_o(7));
	pic_data(8) <= unsigned(pic_data_o(8));
	pic_data(9) <= unsigned(pic_data_o(9));
	line_data(0) <= unsigned(line_data_o(0));
	line_data(1) <= unsigned(line_data_o(1));
	line_data(2) <= unsigned(line_data_o(2));
	line_data(3) <= unsigned(line_data_o(3));
	pics_data(0) <= unsigned(pics_data_o(0));
	pics_data(1) <= unsigned(pics_data_o(1));
	pics_data(2) <= unsigned(pics_data_o(2));
	pics_data(3) <= unsigned(pics_data_o(3));
	pics_data(4) <= unsigned(pics_data_o(4));
	pics_data(5) <= unsigned(pics_data_o(5));
	pics_data(6) <= unsigned(pics_data_o(6));
	pics_data(7) <= unsigned(pics_data_o(7));
	pics_data(8) <= unsigned(pics_data_o(8));
	wifi_data(0) <= unsigned(wifi_data_o(0));
	wifi_data(1) <= unsigned(wifi_data_o(1));
	wifi_data(2) <= unsigned(wifi_data_o(2));
	wifi_data(3) <= unsigned(wifi_data_o(3));

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,  --腳位 a~g
			seg_com => seg_com,  --共同腳位
			data    => seg_data, --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot       --小數點 1 亮
			--輸入資料ex: b"01000000" = x"70"
			--seg_deg 度C
		);
	debounce1 : entity work.debounce(arch)
		generic map(
			stable_time => 10 -- time sig_in must remain stable in ms
		)
		port map(
			-- system
			clk   => clk,
			rst_n => rst_n,
			-- user logic
			sig_in  => sw(7),  -- input signal to be debounced
			sig_out => sw_d(1) -- debounced signal
		);
	debounce2 : entity work.debounce(arch)
		generic map(
			stable_time => 10 -- time sig_in must remain stable in ms
		)
		port map(
			-- system
			clk   => clk,
			rst_n => rst_n,
			-- user logic
			sig_in  => sw(6),  -- input signal to be debounced
			sig_out => sw_d(0) -- debounced signal
		);
	key_inst : entity work.key_2x2_1(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,   --腳位
			key_col => key_col,   --腳位
			pressed => pressed_i, --pressed='1' 代表按住
			key     => key        --key=0 代表按下 key 1	key=1 代表按下 key 2...........
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => pressed_i, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,   --正緣 '1'觸發
			falling => open       --負緣 open=開路
		);
	edge_tx : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => tx_ena,   --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => tx_ena_e, --正緣 '1'觸發
			falling => open      --負緣 open=開路
		);
	edge1_inst : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => rx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => rx_done  --負緣 open=開路
		);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n and LCD_RESET,
			x                => x,                -- 文字x軸
			y                => y,                -- 文字y軸
			font_start       => font_start,       -- 文字更新(取正緣)
			font_busy        => font_busy,        -- 當畫面正在更新時，font_busy='1'
			text_size        => 1,                -- 字體大小
			text_data        => text_data,        -- 文字資料
			addr             => l_addr,           -- 偵錯用
			text_color       => text_color,       -- 字體顏色(只能改單行)(若要使用需改gen_font.vhd(有註記))(若沒用到隨便填一顏色即可)
			bg_color         => bg_color,         -- 背景顏色
			text_color_array => text_color_array, -- 字體顏色(同一行依位元改變)(text_color_array:l_px_arr_t(1 to 12);)
			clear            => '1',              -- '1' 時清除
			lcd_sclk         => lcd_sclk,         -- 腳位
			lcd_mosi         => lcd_mosi,         -- 腳位
			lcd_ss_n         => lcd_ss_n,         -- 腳位
			lcd_dc           => lcd_dc,           -- 腳位
			lcd_bl           => lcd_bl,           -- 腳位
			lcd_rst_n        => lcd_rst_n,        -- 腳位
			con              => '0',              -- 選擇文字或圖片
			pic_addr         => open,             -- 圖片addr
			pic_data         => data_1            -- 圖片資料
		);
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,   --腳位
			dot_green => dot_green, --腳位
			dot_com   => dot_com,   --腳位
			data_r    => data_r,    --紅色資料
			data_g    => data_g     --綠色資料
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1 --頻率
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1 --輸出
		);
	edge_clk_1hz_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk1,
			rising  => open,
			falling => clk_e1
		);
	-- tts_inst : entity work.tts(arch)
	-- 	generic map(
	-- 		txt_len_max => max_len
	-- 	)
	-- 	port map(
	-- 		clk       => clk,
	-- 		rst_n     => rst_n,
	-- 		tts_scl   => tts_scl,   --腳位
	-- 		tts_sda   => tts_sda,   --腳位
	-- 		tts_mo    => tts_mo,    --腳位
	-- 		tts_rst_n => tts_rst_n, --腳位
	-- 		ena       => tts_ena,   --enable 1致能
	-- 		busy      => busy,      --播報時busy='1'
	-- 		txt       => txt,       --data(編碼產生=>tool=>tts.py=>compile=>輸入數目=>輸入名字=>輸入播報內容)
	-- 		txt_len   => len        --
	-- 	);
	tts_stop_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => max_len
		)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			tts_scl    => tts_scl,
			tts_sda    => tts_sda,
			tts_mo     => tts_mo,
			tts_rst_n  => tts_rst_n,
			ena        => tts_ena,
			busy       => busy,
			stop_speak => open,
			txt        => txt,
			txt_len    => len
		);
	uart_txt : entity work.uart_txt(arch)
		generic map(
			txt_len_max => 12,
			baud        => 115200 -- data link baud rate in bits/second
		)
		port map(
			-- system
			clk   => clk,
			rst_n => rst_n,
			-- uart
			uart_rx => uart_rx, -- receive pin
			uart_tx => uart_tx, -- transmit pin
			-- user logic
			tx_ena  => tx_ena_e, -- initiate transmission
			tx_busy => tx_busy,  -- transmission in progress
			tx_data => tx_data,  -- data to transmit
			tx_len  => tx_len,
			tx_mode => tx_mode,
			rx_busy => rx_busy, -- data reception in progress
			rx_data => rx_data, -- data received
			rx_len  => rx_len
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);
	timer_game : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_reset, --當ena='0', msec=load
			load  => load,        --起始值
			msec  => game_time    --毫秒數
		);
	hexagon : entity work.hexagon(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(0), 10)),
			clock   => clk,
			q       => pic_data_o(0)
		);
	circle : entity work.circle(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(1), 10)),
			clock   => clk,
			q       => pic_data_o(1)
		);
	square : entity work.square(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(2), 10)),
			clock   => clk,
			q       => pic_data_o(2)
		);
	triangle : entity work.triangle(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(3), 10)),
			clock   => clk,
			q       => pic_data_o(3)
		);
	diamond : entity work.diamond(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(4), 10)),
			clock   => clk,
			q       => pic_data_o(4)
		);
	rectangle : entity work.rectangle(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(5), 10)),
			clock   => clk,
			q       => pic_data_o(5)
		);
	triangle_r : entity work.triangle_r(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(6), 10)),
			clock   => clk,
			q       => pic_data_o(6)
		);
	octagon : entity work.octagon(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(7), 10)),
			clock   => clk,
			q       => pic_data_o(7)
		);
	heart : entity work.heart(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(8), 10)),
			clock   => clk,
			q       => pic_data_o(8)
		);
	wifi : entity work.wifi(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(9), 10)),
			clock   => clk,
			q       => pic_data_o(9)
		);
	hexagon_s : entity work.hexagon_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(0), 10)),
			clock   => clk,
			q       => pics_data_o(0)
		);
	circle_s : entity work.circle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(1), 10)),
			clock   => clk,
			q       => pics_data_o(1)
		);
	square_s : entity work.square_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(2), 10)),
			clock   => clk,
			q       => pics_data_o(2)
		);
	triangle_s : entity work.triangle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(3), 10)),
			clock   => clk,
			q       => pics_data_o(3)
		);

	diamond_s : entity work.diamond_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(4), 10)),
			clock   => clk,
			q       => pics_data_o(4)
		);
	rectangle_s : entity work.rectangle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(5), 10)),
			clock   => clk,
			q       => pics_data_o(5)
		);
	triangle_s_r : entity work.triangle_s_r(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(6), 10)),
			clock   => clk,
			q       => pics_data_o(6)
		);
	octagon_s : entity work.octagon_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(7), 10)),
			clock   => clk,
			q       => pics_data_o(7)
		);
	heart_s : entity work.heart_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(pics_addr(8), 10)),
			clock   => clk,
			q       => pics_data_o(8)
		);
	process (clk, rst_n)
		variable pic : l_px_t_array;
		variable red_p : l_px_t_array;
		variable line : l_px_t_array_line;
		variable font : b;

	begin
		if rising_edge(clk) then
			if rst_n = '0' then
				state1 <= start;
				state2 <= start;
				state3 <= start;
				r_state11 <= start;
				r_state10 <= start;
				tts_mode <= idle;
				LCD_RESET <= '1';
				seg_data <= "        ";
			else
				random1 <= random1 + 1;
				random2 <= random2 + 3;
				random(random1) <= random(random2);
				random(random2) <= random(random1);
				-- random1 <= random1 + 1;
				-- random2 <= random2 + 3;
				-- random(random1) <= random(random2);
				-- random(random2) <= random(random1);

				case sw_d is
					when "00" =>
						r_state11 <= start;
						r_state10 <= start;
						state2 <= start;
						state3 <= start;
						LCD_RESET <= '1';
						case state1 is
							when start =>
								fin_count <= 0;
								wifi_count <= 1;
								seg_data <= "        ";
								angle00 <= (others => 0);
								pic_color <= (0, 0, 0, 0, 0, 0, 0, 0, 0);
								red_array <= (0, 0, 0, 0, 1, 0, 0, 0, 0);
								timer_ena <= '0';
								sel <= 4;
								if pressed = '1' and key = 0 then
									state1 <= print;
									lcd_clear <= '1';
								end if;
							when print =>
								seg_data <= "RESET   ";
								lcd_clear <= '1';
								timer_ena <= '1';
								--	constant coord : inter := ((6, 0), (6, 40), (6, 85), (65, 0), (65, 42), (65, 85), (125, 0), (125, 40), (125, 85));
								-- 								  0		  1   		2 		3		4			5		6			7			8
								for i in 0 to 3 loop
									if i < 2 then
										if i = 0 then
											line(i) := to_data(l_paste(l_addr, gray, blue, coord_line(i), 128, 2));
										else
											line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 128, 2));
										end if;
									else
										line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 2, 160));
									end if;
								end loop;
								if msec > 300 then
									bg_color <= l_map(pic(0), gray, line(3));
									pic(0) := to_data(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
									pic_addr(0) <= to_addr(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
								end if;
								if msec > 600 then
									bg_color <= l_map(pic(1), gray, line(3));
									pic(1) := to_data(l_paste(l_addr, pic(0), pic_data(3), coord(3), 32, 32));
									pic_addr(3) <= to_addr(l_paste(l_addr, pic(0), pic_data(3), coord(3), 32, 32));
								end if;
								if msec > 900 then
									bg_color <= l_map(pic(2), gray, line(3));

									pic(2) := to_data(l_paste(l_addr, pic(1), pic_data(6), coord(6), 32, 32));
									pic_addr(6) <= to_addr(l_paste(l_addr, pic(1), pic_data(6), coord(6), 32, 32));
								end if;
								if msec > 1200 then
									bg_color <= l_map(pic(3), gray, line(3));
									pic(3) := to_data(l_paste(l_addr, pic(2), pic_data(7), coord(7), 32, 32));
									pic_addr(7) <= to_addr(l_paste(l_addr, pic(2), pic_data(7), coord(7), 32, 32));
								end if;
								if msec > 1500 then
									bg_color <= l_map(pic(4), gray, line(3));
									pic(4) := to_data(l_paste(l_addr, pic(3), pic_data(8), coord(8), 32, 32));
									pic_addr(8) <= to_addr(l_paste(l_addr, pic(3), pic_data(8), coord(8), 32, 32));
								end if;
								if msec > 1800 then
									bg_color <= l_map(pic(5), gray, line(3));
									pic(5) := to_data(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
									pic_addr(5) <= to_addr(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
								end if;
								if msec > 2100 then
									bg_color <= l_map(pic(6), gray, line(3));
									pic(6) := to_data(l_paste(l_addr, pic(5), pic_data(2), coord(2), 32, 32));
									pic_addr(2) <= to_addr(l_paste(l_addr, pic(5), pic_data(2), coord(2), 32, 32));
								end if;
								if msec > 2400 then
									bg_color <= l_map(pic(7), gray, line(3));
									pic(7) := to_data(l_paste(l_addr, pic(6), pic_data(1), coord(1), 32, 32));
									pic_addr(1) <= to_addr(l_paste(l_addr, pic(6), pic_data(1), coord(1), 32, 32));
								end if;
								if msec > 2700 then
									bg_color <= l_map(pic(8), gray, line(3));
									pic(8) := to_data(l_paste(l_addr, pic(7), pics_data(4), coord(4), 32, 32));
									if pic(8) /= white then
										pic(8) := to_data(l_paste(l_addr, pic(7), red, coord(4), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), white, coord(4), 32, 32));
									end if;
									pics_addr(4) <= to_addr(l_paste(l_addr, pic(7), pics_data(4), coord(4), 32, 32));
								end if;
								if msec > 3000 then
									timer_ena <= '0';
									state1 <= moving;
								end if;
							when reset =>
							when check =>
							when moving =>
								red_array(sel) <= 1;

								if red_p(8) = white then
									bg_color <= pic(8);
								else
									bg_color <= red_p(8);
								end if;

								if pressed = '1' and key = 2 then
									seg_flag <= '0';
									if pic_color(sel) = 2 then
										pic_color(sel) <= 0;
										seg_data <= "color R ";
									else
										pic_color(sel) <= pic_color(sel) + 1;
										if pic_color(sel) = 1 then
											seg_data <= "color B ";
										else
											seg_data <= "color G ";
										end if;
									end if;
								end if;
								for i in 0 to 3 loop
									if i < 2 then
										if i = 0 then
											line(i) := to_data(l_paste(l_addr, gray, blue, coord_line(i), 128, 2));
										else
											line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 128, 2));
										end if;
									else
										line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 2, 160));
									end if;
								end loop;
								for i in 0 to 8 loop
									if red_array(i) = 1 then
										if i = 0 then
											if pics_data(i) /= white then
												case pic_color(i) is
													when 0 => red_p(i) := to_data(l_paste(l_addr, line(3), red, coord(i), 32, 32));
													when 1 => red_p(i) := to_data(l_paste(l_addr, line(3), green, coord(i), 32, 32));
													when 2 => red_p(i) := to_data(l_paste(l_addr, line(3), blue, coord(i), 32, 32));
												end case;
											else
												red_p(i) := to_data(l_paste(l_addr, line(3), white, coord(i), 32, 32));
											end if;
											pics_addr(i) <= l_rotate(to_addr(l_paste(l_addr, line(3), l_map(pics_data(i), white, gray), coord(i), 32, 32)), angle00(i), 32, 32);
										else
											if pics_data(i) /= white then
												case pic_color(i) is
													when 0 => red_p(i) := to_data(l_paste(l_addr, red_p(i - 1), red, coord(i), 32, 32));
													when 1 => red_p(i) := to_data(l_paste(l_addr, red_p(i - 1), green, coord(i), 32, 32));
													when 2 => red_p(i) := to_data(l_paste(l_addr, red_p(i - 1), blue, coord(i), 32, 32));
												end case;
											else
												red_p(i) := to_data(l_paste(l_addr, red_p(i - 1), white, coord(i), 32, 32));
											end if;
											pics_addr(i) <= l_rotate(to_addr(l_paste(l_addr, red_p(i - 1), l_map(pics_data(i), white, gray), coord(i), 32, 32)), angle00(i), 32, 32);
										end if;
										for i in 0 to 8 loop
											if red_array(i) = 0 then
												if i = 0 then
													pic(i) := to_data(l_paste(l_addr, line(3), pic_data(i), coord(i), 32, 32));
													pic_addr(i) <= to_addr(l_paste(l_addr, line(3), pic_data(i), coord(i), 32, 32));
												else
													pic(i) := to_data(l_paste(l_addr, pic(i - 1), pic_data(i), coord(i), 32, 32));
													pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), pic_data(i), coord(i), 32, 32));
												end if;
											else
												if i = 0 then
													pic(i) := line(3);
												else
													pic(i) := pic(i - 1);
												end if;
											end if;
										end loop;
									else
										if i = 0 then
											red_p(i) := line(3);
										else
											red_p(i) := red_p(i - 1);
										end if;
									end if;
								end loop;
								if pressed = '1' and key = 3 then
									red_array <= (0, 0, 0, 0, 1, 0, 0, 0, 0);
									pic_color <= (others => 0);
									sel <= 4;
								end if;
								if pressed = '1' and key = 1 then
									angle00(sel) <= angle00(sel) + 1;
								end if;
								if rx_done = '1' then
									seg_flag <= '1';
									case rx_data(1 to 8) is
										when "00000000" =>
											if sel > 2 then
												sel <= sel - 3;
											end if;
										when "10000000" =>
											if sel < 6 then
												sel <= sel + 3;
											end if;
										when "20000000" =>
											if sel /= 0 and sel /= 3 and sel /= 6 then
												sel <= sel - 1;
											end if;
										when "30000000" =>
											if sel /= 2 and sel /= 5 and sel /= 8 then
												sel <= sel + 1;
											end if;
										when others => null;
									end case;
								end if;
							when others => null;
						end case;
					when "01" =>
						r_state11 <= start;
						r_state10 <= start;
						state1 <= start;
						state3 <= start;
						case state2 is
							when start =>
								LCD_RESET <= '0';
								seg_data <= "        ";
								if pressed = '1' and key = 0 then
									seg_data <= "START!  ";
									state2 <= move;
								end if;
							when move =>
								if rx_done = '1' then
									case rx_data(1 to 8) is
										when "00000000" =>
											seg_data <= "CMD:UP! ";
										when "10000000" =>
											seg_data <= "CMD:DW! ";
										when "20000000" =>
											seg_data <= "CMD:LT! ";
										when "30000000" =>
											seg_data <= "CMD:RT! ";
										when others => null;
									end case;
								end if;
							when others => null;
						end case;

					when "10" =>
						for i in 0 to 3 loop
							if i < 2 then
								if i = 0 then
									line(i) := to_data(l_paste(l_addr, gray, blue, coord_line(i), 128, 2));
								else
									line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 128, 2));
								end if;
							else
								line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 2, 160));
							end if;
						end loop;
						state1 <= start;
						state2 <= start;
						r_state11 <= start;
						tx_ena <= '0';
						case r_state10 is
							when start => --reset
								random_r <= random;
								timer_reset <= '0';
								tx_mode <= '1';
								timer_ena <= '0';
								PIC_8 <= '1';
								index <= 0;
								pic_count <= 1;
								sel <= 4;
								PIC_STATE <= "000000000";
								seg_data <= "        ";
								r_state10 <= r_state10;
								if pressed = '1' and key = 0 then
									r_state10 <= cutdown;
								end if;
								LCD_RESET <= '0';
							when cutdown =>
								timer_ena <= '1';
								tx_ena <= '1';
								tx_data(1 to 3) <= "+++";
								tx_len <= 3;
								r_state10 <= reset;
								LCD_RESET <= '1';
							when reset =>
								tx_ena <= '0';
								if msec > 2000 then
									tx_data(1 to 8) <= "AT+RST" & CR & LF;
									tx_len <= 8;
									r_state10 <= check;
									timer_ena <= '0';
									tx_ena <= '1';
								end if;
								bg_color <= l_map(pic(8), gray, line(3));
								for i in 0 to 7 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
										wifi_addr(2) <= to_addr(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
									end if;
								end loop;
							when check =>
								timer_ena <= '1';
								tx_ena <= '0';
								if msec > 4000 then
									tx_data(1 to 8) <= "11111111";
									tx_len <= 8;
									tx_mode <= '0';
									tx_ena <= not tx_ena;
									if rx_done = '1' then
										if rx_data(1 to 8) = "success1" then
											r_state10 <= waiting;
											tx_ena <= '0';
											timer_ena <= '0';
										end if;
									elsif msec > 7000 then
										timer_ena <= '0';
										r_state10 <= start;
									end if;
								end if;
								bg_color <= l_map(pic(7), gray, line(3));
								for i in 0 to 7 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
										wifi_addr(2) <= to_addr(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
									end if;
								end loop;
							when waiting =>
								bg_color <= l_map(pic(8), gray, line(3));
								for i in 0 to 8 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(pic_data(9), white, gray), coord(4), 32, 32));
										pic_addr(9) <= to_addr(l_paste(l_addr, pic(7), l_map(pic_data(9), white, gray), coord(4), 32, 32));
									end if;
								end loop;
								if pressed = '1' and key = 1 then
									r_state10 <= cleaning;
									timer_ena <= '0';
									random_r <= random;
								end if;
							when cleaning =>
								timer_ena <= '1';
								if msec > 100 then
									bg_color <= l_map(pic(0), gray, line(3));
									pic(0) := to_data(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
									pic_addr(0) <= to_addr(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
								end if;
								if msec > 200 then
									bg_color <= l_map(pic(1), gray, line(3));
									pic(1) := to_data(l_paste(l_addr, pic(0), pic_data(1), coord(1), 32, 32));
									pic_addr(1) <= to_addr(l_paste(l_addr, pic(0), pic_data(1), coord(1), 32, 32));
								end if;
								if msec > 300 then
									bg_color <= l_map(pic(2), gray, line(3));
									pic(2) := to_data(l_paste(l_addr, pic(1), pic_data(2), coord(2), 32, 32));
									pic_addr(2) <= to_addr(l_paste(l_addr, pic(1), pic_data(2), coord(2), 32, 32));
								end if;
								if msec > 400 then
									bg_color <= l_map(pic(3), gray, line(3));
									pic(3) := to_data(l_paste(l_addr, pic(2), pic_data(3), coord(3), 32, 32));
									pic_addr(3) <= to_addr(l_paste(l_addr, pic(2), pic_data(3), coord(3), 32, 32));
								end if;
								if msec > 500 then
									bg_color <= l_map(pic(4), gray, line(3));
									pic(4) := to_data(l_paste(l_addr, pic(3), pic_data(4), coord(4), 32, 32));
									pic_addr(4) <= to_addr(l_paste(l_addr, pic(3), pic_data(4), coord(4), 32, 32));
								end if;
								if msec > 600 then
									bg_color <= l_map(pic(5), gray, line(3));
									pic(5) := to_data(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
									pic_addr(5) <= to_addr(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
								end if;
								if msec > 700 then
									bg_color <= l_map(pic(6), gray, line(3));
									pic(6) := to_data(l_paste(l_addr, pic(5), pic_data(6), coord(6), 32, 32));
									pic_addr(6) <= to_addr(l_paste(l_addr, pic(5), pic_data(6), coord(6), 32, 32));
								end if;
								if msec > 800 then
									bg_color <= l_map(pic(7), gray, line(3));
									pic(7) := to_data(l_paste(l_addr, pic(6), pic_data(7), coord(7), 32, 32));
									pic_addr(7) <= to_addr(l_paste(l_addr, pic(6), pic_data(7), coord(7), 32, 32));
								end if;
								if msec > 900 then
									bg_color <= l_map(pic(8), gray, line(3));
									pic(8) := to_data(l_paste(l_addr, pic(7), pic_data(8), coord(8), 32, 32));
									pic_addr(8) <= to_addr(l_paste(l_addr, pic(7), pic_data(8), coord(8), 32, 32));
								end if;
								if msec > 1000 then
									r_state10 <= ending;
								end if;
							when ending =>
								bg_color <= l_map(line(3), white, pic(10));
								pic(10) := to_data(l_paste(l_addr, pic(8), pics_data(P_S), coord(sel), 32, 32));
								pics_addr(P_S) <= to_addr(l_paste(l_addr, pic(8), pics_data(P_S), coord(sel), 32, 32));
								if index < 9 then
									P_S <= random_r(index);
								else
									pic(10) := pic(8);
									bg_color <= l_map(line(3), white, pic(10));
								end if;
								if pressed = '1' and key = 3 then
									if sel = P_S then
										sel <= 4;
										index <= index + 1;
										PIC_STATE(sel) <= '1';
									end if;
								end if;
								for i in 0 to 8 loop
									if PIC_STATE(i) = '1' then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data((0)), white, gray), coord(0), 32, 32));
											pic_addr((0)) <= to_addr(l_paste(l_addr, gray, l_map(pic_data((0)), white, gray), coord(0), 32, 32));
										else
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data((i)), white, gray), coord(i), 32, 32));
											pic_addr((i)) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data((i)), white, gray), coord(i), 32, 32));
										end if;
									else
										if i = 0 then
											pic(i) := gray;
										else
											pic(i) := pic(i - 1);
										end if;
									end if;
								end loop;
								if rx_done = '1' then
									case rx_data(1 to 8) is
										when "00000000" =>
											if sel > 2 then
												sel <= sel - 3;
												seg_data(1 to 4) <= "    ";
											else
												tts_mode <= idle;
											end if;
										when "10000000" =>
											if sel < 6 then
												sel <= sel + 3;
												seg_data(1 to 4) <= "    ";
											else
												tts_mode <= idle;
											end if;
										when "20000000" =>
											if sel /= 0 and sel /= 3 and sel /= 6 then
												sel <= sel - 1;
											else
												tts_mode <= idle;
											end if;
										when "30000000" =>
											if sel /= 2 and sel /= 5 and sel /= 8 then
												sel <= sel + 1;
											else
												tts_mode <= idle;
											end if;
										when others => null;
									end case;
								end if;
							when others => null;
						end case;
					when "11" =>
						dbg_a(0) <= busy;
						dbg_a(1) <= tts_ena;
						if tts_mode = idle then
							dbg_a(2) <= '0';
							dbg_a(3) <= '1';
							dbg_a(4) <= '1';
						elsif tts_mode = play then
							dbg_a(2) <= '1';
							dbg_a(3) <= '0';
							dbg_a(4) <= '1';
						elsif tts_mode = stop then
							dbg_a(2) <= '1';
							dbg_a(3) <= '1';
							dbg_a(4) <= '0';
						end if;
						case tts_mode is
							when idle =>
								if rx_done = '1' then
									tts_mode <= play;
									tts_data <= rx_data;
								end if;
								if success_flag = '1' then
									tts_data(1 to 8) <= "pic_gene";
									tts_mode <= play;
									success_flag <= '0';
								end if;
								if gene_flag = '1' then
									tts_data(1 to 8) <= "playpic" & to_string(P_S + 1, 9, 10, 1);
									tts_mode <= play;
									gene_flag <= '0';
								end if;
							when play =>
								case tts_data(1 to 8) is
									when "00000000" =>
										txt(0 to 13) <= way_u;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "10000000" =>
										txt(0 to 13) <= way_d;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "20000000" =>
										txt(0 to 13) <= way_l;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "30000000" =>
										txt(0 to 13) <= way_r;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "piccheck" =>
										txt(0 to 7) <= succeed;
										len <= 8;
										tts_ena <= '1';
										tts_mode <= waiting;
										success_flag <= '1';
									when "playfail" =>
										txt(0 to 7) <= fail;
										len <= 8;
										tts_ena <= '1';
										tts_mode <= waiting;
									when"pic_gene" =>
										txt(0 to 15) <= pic_gene;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
										gene_flag <= '1';
									when "wifisucc" =>
										txt(0 to 11) <= wifisucc;
										len <= 12;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "wififail" =>
										txt(0 to 11) <= wififail;
										len <= 12;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic1" =>
										txt(0 to 15) <= pic1;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic2" =>
										txt(0 to 13) <= pic2;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic3" =>
										txt(0 to 15) <= pic3;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic4" =>
										txt(0 to 15) <= pic4;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic5" =>
										txt(0 to 13) <= pic5;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic6" =>
										txt(0 to 15) <= pic6;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic7" =>
										txt(0 to 17) <= pic7;
										len <= 18;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic8" =>
										txt(0 to 15) <= pic8;
										len <= 16;
										tts_ena <= '1';
										tts_mode <= waiting;
									when "playpic9" =>
										txt(0 to 13) <= pic9;
										len <= 14;
										tts_ena <= '1';
										tts_mode <= waiting;

									when "ttsreset" =>
										txt(0 to 1) <= tts_instant_soft_reset;
										len <= 2;
										tts_mode <= waiting;
										tts_reset <= '0';
										tts_ena <= '1';
									when others => tts_mode <= idle;
								end case;
							when waiting =>
								if busy = '1' then
									tts_mode <= stop;
								end if;
							when stop =>
								tts_ena <= '0';
								tts_reset <= '0';
								if busy = '0' then
									tts_mode <= idle;
								end if;
						end case;
						for i in 0 to 3 loop
							if i < 2 then
								if i = 0 then
									line(i) := to_data(l_paste(l_addr, gray, blue, coord_line(i), 128, 2));
								else
									line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 128, 2));
								end if;
							else
								line(i) := to_data(l_paste(l_addr, line(i - 1), blue, coord_line(i), 2, 160));
							end if;
						end loop;
						state1 <= start;
						state2 <= start;
						r_state10 <= start;
						tx_ena <= '0';
						case r_state11 is
							when start => --reset
								random_r <= random;
								timer_reset <= '0';
								tx_mode <= '1';
								timer_ena <= '0';
								PIC_8 <= '1';
								pic_count <= 1;
								sel <= 4;
								index <= 0;
								PIC_STATE <= "000000000";
								seg_data <= "        ";
								r_state11 <= r_state11;
								if pressed = '1' and key = 0 then
									r_state11 <= cutdown;
								end if;
								LCD_RESET <= '0';
							when cutdown =>
								timer_ena <= '1';
								tx_ena <= '1';
								tx_data(1 to 3) <= "+++";
								tx_len <= 3;
								r_state11 <= reset;
								LCD_RESET <= '1';
							when reset =>
								tx_ena <= '0';
								if msec > 2000 then
									tx_data(1 to 8) <= "AT+RST" & CR & LF;
									tx_len <= 8;
									r_state11 <= check;
									timer_ena <= '0';
									tx_ena <= '1';
								end if;
								bg_color <= l_map(pic(8), gray, line(3));
								for i in 0 to 7 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
										wifi_addr(2) <= to_addr(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
									end if;
								end loop;
							when check =>
								timer_ena <= '1';
								tx_ena <= '0';
								if msec > 4000 then
									tx_data(1 to 8) <= "11111111";
									tx_len <= 8;
									tx_mode <= '0';
									tx_ena <= not tx_ena;
									if rx_done = '1' then
										if rx_data(1 to 8) = "success1" then
											r_state11 <= waiting;
											tx_ena <= '0';
											timer_ena <= '0';
											tts_data(1 to 8) <= "wifisucc";
											tts_mode <= play;
										end if;
									elsif msec > 7000 then
										timer_ena <= '0';
										r_state11 <= start;
										tts_data(1 to 8) <= "wififali";
										tts_mode <= play;
									end if;
								end if;
								bg_color <= l_map(pic(7), gray, line(3));
								for i in 0 to 7 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
										wifi_addr(2) <= to_addr(l_paste(l_addr, pic(7), l_map(wifi_data(2), white, gray), coord(4), 32, 32));
									end if;
								end loop;
							when waiting =>
								bg_color <= l_map(pic(8), gray, line(3));
								for i in 0 to 8 loop
									if i <= 3 then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
											pic_addr(0) <= to_addr(l_paste(l_addr, gray, l_map(pic_data(0), white, gray), coord(0), 32, 32));
										end if;
										if i > 0 then
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
											pic_addr(i) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i), white, gray), coord(i), 32, 32));
										end if;
									elsif i >= 4 and i <= 7 then
										pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
										pic_addr(i + 1) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data(i + 1), white, gray), coord(i + 1), 32, 32));
									else
										pic(8) := to_data(l_paste(l_addr, pic(7), l_map(pic_data(9), white, gray), coord(4), 32, 32));
										pic_addr(9) <= to_addr(l_paste(l_addr, pic(7), l_map(pic_data(9), white, gray), coord(4), 32, 32));
									end if;
								end loop;
								if pressed = '1' and key = 1 then
									r_state11 <= cleaning;
									timer_ena <= '0';
									random_r <= random;

								end if;
							when cleaning =>
								timer_ena <= '1';
								if msec > 100 then
									bg_color <= l_map(pic(0), gray, line(3));
									pic(0) := to_data(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
									pic_addr(0) <= to_addr(l_paste(l_addr, line(3), pic_data(0), coord(0), 32, 32));
								end if;
								if msec > 200 then
									bg_color <= l_map(pic(1), gray, line(3));
									pic(1) := to_data(l_paste(l_addr, pic(0), pic_data(1), coord(1), 32, 32));
									pic_addr(1) <= to_addr(l_paste(l_addr, pic(0), pic_data(1), coord(1), 32, 32));
								end if;
								if msec > 300 then
									bg_color <= l_map(pic(2), gray, line(3));
									pic(2) := to_data(l_paste(l_addr, pic(1), pic_data(2), coord(2), 32, 32));
									pic_addr(2) <= to_addr(l_paste(l_addr, pic(1), pic_data(2), coord(2), 32, 32));
								end if;
								if msec > 400 then
									bg_color <= l_map(pic(3), gray, line(3));
									pic(3) := to_data(l_paste(l_addr, pic(2), pic_data(3), coord(3), 32, 32));
									pic_addr(3) <= to_addr(l_paste(l_addr, pic(2), pic_data(3), coord(3), 32, 32));
								end if;
								if msec > 500 then
									bg_color <= l_map(pic(4), gray, line(3));
									pic(4) := to_data(l_paste(l_addr, pic(3), pic_data(4), coord(4), 32, 32));
									pic_addr(4) <= to_addr(l_paste(l_addr, pic(3), pic_data(4), coord(4), 32, 32));
								end if;
								if msec > 600 then
									bg_color <= l_map(pic(5), gray, line(3));
									pic(5) := to_data(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
									pic_addr(5) <= to_addr(l_paste(l_addr, pic(4), pic_data(5), coord(5), 32, 32));
								end if;
								if msec > 700 then
									bg_color <= l_map(pic(6), gray, line(3));
									pic(6) := to_data(l_paste(l_addr, pic(5), pic_data(6), coord(6), 32, 32));
									pic_addr(6) <= to_addr(l_paste(l_addr, pic(5), pic_data(6), coord(6), 32, 32));
								end if;
								if msec > 800 then
									bg_color <= l_map(pic(7), gray, line(3));
									pic(7) := to_data(l_paste(l_addr, pic(6), pic_data(7), coord(7), 32, 32));
									pic_addr(7) <= to_addr(l_paste(l_addr, pic(6), pic_data(7), coord(7), 32, 32));
								end if;
								if msec > 900 then
									bg_color <= l_map(pic(8), gray, line(3));
									pic(8) := to_data(l_paste(l_addr, pic(7), pic_data(8), coord(8), 32, 32));
									pic_addr(8) <= to_addr(l_paste(l_addr, pic(7), pic_data(8), coord(8), 32, 32));
								end if;
								if msec > 1000 then
									r_state11 <= ending;
									tts_data(1 to 8) <= "pic_gene";
									tts_mode <= play;
								end if;
							when ending =>
								bg_color <= l_map(line(3), white, pic(10));
								if index < 9 then
									P_S <= random_r(index);
								else
									pic(10) := pic(8);
								end if;
								pic(10) := to_data(l_paste(l_addr, pic(8), pics_data(P_S), coord(sel), 32, 32));
								pics_addr(P_S) <= to_addr(l_paste(l_addr, pic(8), pics_data(P_S), coord(sel), 32, 32));
								if pressed = '1' and key = 3 then
									if sel = P_S then
										sel <= 4;
										index <= index + 1;
										tts_data (1 to 8) <= "piccheck";
										tts_mode <= play;
										PIC_STATE(sel) <= '1';
									else
										tts_data(1 to 8) <= "playfail";
										tts_mode <= play;
									end if;
								end if;
								for i in 0 to 8 loop
									if PIC_STATE(i) = '1' then
										if i = 0 then
											pic(0) := to_data(l_paste(l_addr, gray, l_map(pic_data((0)), white, gray), coord(0), 32, 32));
											pic_addr((0)) <= to_addr(l_paste(l_addr, gray, l_map(pic_data((0)), white, gray), coord(0), 32, 32));
										else
											pic(i) := to_data(l_paste(l_addr, pic(i - 1), l_map(pic_data((i)), white, gray), coord(i), 32, 32));
											pic_addr((i)) <= to_addr(l_paste(l_addr, pic(i - 1), l_map(pic_data((i)), white, gray), coord(i), 32, 32));
										end if;
									else
										if i = 0 then
											pic(i) := gray;
										else
											pic(i) := pic(i - 1);
										end if;
									end if;
								end loop;
								if rx_done = '1' then
									case rx_data(1 to 8) is
										when "00000000" =>
											if sel > 2 then
												sel <= sel - 3;
												seg_data(1 to 4) <= "    ";
											else
												tts_mode <= idle;
											end if;
										when "10000000" =>
											if sel < 6 then
												sel <= sel + 3;
												seg_data(1 to 4) <= "    ";
											else
												tts_mode <= idle;
											end if;
										when "20000000" =>
											if sel /= 0 and sel /= 3 and sel /= 6 then
												sel <= sel - 1;
											else
												tts_mode <= idle;
											end if;
										when "30000000" =>
											if sel /= 2 and sel /= 5 and sel /= 8 then
												sel <= sel + 1;
											else
												tts_mode <= idle;
											end if;
										when others => null;
									end case;
								end if;
							when others => null;
						end case;
				end case;
			end if;
		end if;
	end process;
end arch;
