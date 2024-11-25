library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity test113_2 is
	port (

		--system
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		--led(r g y)
		led_r, led_g, led_y : out std_logic;

		-- rgb
		rgb : out std_logic_vector(0 to 2);

		--seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--8*8 dot led
		dot_red, dot_green, dot_com : out u8r_t;

		--buzzer
		buz : out std_logic; --'1' 叫  '0' 不叫

		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin

		--mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end test113_2;

architecture arch of test113_2 is
	-- --buz
	-- signal buz_ena, buz_flag : std_logic;
	-- signal buz_busy, buz_done : std_logic;
	-- signal buz_ena : std_logic;
	-- signal buz_timer : i32_t;
	-- signal buz_mode : std_logic; --0 => 0.5s 1 => 1s

	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--8x8
	signal data_g, data_r : u8r_arr_t(0 to 7) := (others => x"00");

	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	--timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	-- mot
	signal mot_dir : std_logic;
	signal mot_speed : integer range 0 to 100;

	--lcd
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal l_addr : l_addr_t;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal bg_color : l_px_t;
	signal lcd_con : std_logic;
	signal pic_addr : l_addr_t;
	signal pic_data : l_px_t;
	constant lcd_color1 : l_px_arr_t(1 to 4) := (white, black, black, red);
	constant lcd_color2 : l_px_arr_t(1 to 4) := (white, black, black, black);
	signal pic_addr_sivs, pic_addr_feed : l_addr_t;
	signal pic_data_sivs, pic_data_feed : l_px_t;
	signal pic_data_o, feed_data_o : std_logic_vector(0 to 23);
	--user
	type system_state is (reset, waiting, provide, selling, buying);
	signal state : system_state;
	signal fodder : integer := 100;
	signal money : integer := 500;
	signal egg : integer;
	signal fodder_number : integer range 0 to 9999 := 0;
	signal egg_number : integer range 0 to 999 := 0;
	signal digit : std_logic := '0';
	type sell_coord is array(0 to 2) of integer range 0 to 7;
	signal sell_x : integer range 0 to 7 := 6;
	signal sell_y : integer range 0 to 7 := 6;
	signal buy_x, buy_y : integer range 0 to 7;
	signal buy_enable : unsigned(0 to 3) := "1111";
	signal lcd_count : integer range 0 to 3;
	signal price : integer range 0 to 99 := 10;
	signal reset_count : integer range 0 to 2;
	type pro_state is (green, red, check, green_flash, orange_flash, red_flash);
	type sel_state is (timing_reset, red, sell, ending);
	type buy_state is (red, play, random, ending);
	signal provide_state : pro_state;
	signal sell_state : sel_state;
	signal buying_state : buy_state;
	signal password : string(1 to 6);
	signal count : integer range 0 to 50;
	signal pass : u8_arr_t(0 to 5) := (x"31", x"30", x"00", x"00", x"00", x"00");--rx's data
	signal pass_str : string(1 to 6);--software pass
	signal random1 : integer range 0 to 2;
	signal random2 : integer range 0 to 2;
	signal point : integer range 0 to 99;
	signal profit : integer;
	constant random_x : sell_coord := (0, 3, 6);
	constant random_y : sell_coord := (0, 3, 6);
	constant all_black : l_px_arr_t(1 to 12) := (black, black, black, black, black, black, black, black, black, black, black, black);
	constant all_white : l_px_arr_t(1 to 12) := (white, white, white, white, white, white, white, white, white, white, white, white);
begin
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
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx, --腳位
			uart_tx => uart_tx, --腳位
			tx_ena  => tx_ena,  --enable '1' 動作
			tx_busy => tx_busy, --tx資料傳送時tx_busy='1'
			tx_data => tx_data, --硬體要傳送的資料
			rx_busy => rx_busy, --rx資料傳送時rx_busy='1'
			rx_err  => rx_err,  --檢測錯誤
			rx_data => rx_data  --由軟體接收到的資料
		);
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
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,   --腳位
			key_col => key_col,   --腳位
			pressed => pressed_i, --pressed='1' 代表按住
			key     => key        --key=0 代表按下 key 1	key=1 代表按下 key 2...........
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => pressed_i, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,   --正緣 '1'觸發
			falling => open       --負緣 open=開路
		);
	edge_rx : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => rx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => rx_done  --負緣 open=開路
		);
	edge_LCD : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => font_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,      --正緣 '1'觸發
			falling => draw_done  --負緣 open=開路
		);
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => mot_dir,
			speed   => mot_speed
		);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => 1,
			text_data        => text_data,
			text_count       => open,
			addr             => l_addr,
			text_color       => green,
			bg_color         => bg_color,
			text_color_array => text_color,
			clear            => lcd_clear,
			con              => lcd_con,
			pic_addr         => pic_addr,
			pic_data         => pic_data,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
		);
	sivs : entity work.Logo_SIVS(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr_sivs, 13)),
			clock   => clk,
			q       => pic_data_o
		);
	feed : entity work.FEED(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr_feed, 12)),
			clock   => clk,
			q       => feed_data_o
		);
	process (clk, rst_n)
		variable number : integer := 0;
	begin
		pic_data_sivs <= unsigned(pic_data_o);
		pic_data_feed <= unsigned(feed_data_o);

		if rst_n = '0' or (pressed = '1' and key = 7) then
			lcd_con <= '0';
			state <= reset;
			timer_ena <= '0';
			buy_enable <= "1111";
			seg_data <= "        ";
			lcd_clear <= '1';
			bg_color <= white;
			reset_count <= 0;
		elsif rising_edge(clk) then
			case state is
				when reset =>
					seg_data <= "88888888";
					dot <= "11111111";
					timer_ena <= '1';
					fodder <= 200;
					money <= 500;
					egg <= 50;
					lcd_clear <= '1';
					if msec < 1000 then--1
						bg_color <= red;
						rgb <= "100";
						led_r <= '1';
						led_g <= '0';
						led_y <= '0';
						data_g <= (others => x"FF");
						data_r <= (others => x"00");
					elsif msec < 2000 then--2
						bg_color <= green;
						rgb <= "010";
						led_r <= '1';
						led_g <= '1';
						led_y <= '0';
						data_g <= (others => x"00");
						data_r <= (others => x"FF");
					elsif msec < 3000 then--3
						bg_color <= blue;
						rgb <= "001";
						led_r <= '1';
						led_g <= '1';
						led_y <= '1';
						data_g <= (others => x"FF");
						data_r <= (others => x"FF");
					elsif msec < 4000 then--4
						bg_color <= to_data(l_paste(l_addr, black, red, (0, 0), 128, 56));
						rgb <= "100";
						led_r <= '1';
						led_g <= '0';
						led_y <= '0';
						data_g <= (others => x"FF");
						data_r <= (others => x"00");
					elsif msec < 5000 then--5
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, black, red, (0, 0), 128, 56)), green, (56, 0), 128, 56));
						rgb <= "010";
						led_r <= '1';
						led_g <= '1';
						led_y <= '0';
						data_g <= (others => x"00");
						data_r <= (others => x"FF");
					elsif msec < 6000 then--6
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, black, red, (0, 0), 128, 56)), green, (56, 0), 128, 56)), blue, (112, 0), 128, 56));
						rgb <= "001";
						led_r <= '1';
						led_g <= '1';
						led_y <= '1';
						data_g <= (others => x"FF");
						data_r <= (others => x"FF");
					elsif msec < 7000 then--7
						bg_color <= to_data(l_paste(l_addr, black, red, (0, 0), 42, 160));
						rgb <= "100";
						led_r <= '1';
						led_g <= '0';
						led_y <= '0';
						data_g <= (others => x"FF");
						data_r <= (others => x"00");
					elsif msec < 8000 then--8
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, black, red, (0, 0), 42, 160)), green, (0, 42), 42, 160));
						rgb <= "010";
						led_r <= '1';
						led_g <= '1';
						led_y <= '0';
						data_g <= (others => x"00");
						data_r <= (others => x"FF");
					elsif msec < 9000 then--9
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, black, red, (0, 0), 42, 160)), green, (0, 42), 42, 160)), blue, (0, 84), 42, 160));
						rgb <= "001";
						led_r <= '1';
						led_g <= '1';
						led_y <= '1';
						data_g <= (others => x"FF");
						data_r <= (others => x"FF");
					elsif msec > 9000 then
						state <= waiting;
						reset_count <= 0;
						timer_ena <= '0';
					end if;
				when waiting =>
					led_r <= '0';
					led_g <= '0';
					led_y <= '0';
					rgb <= "111";
					dot <= "00000000";
					lcd_clear <= '1';
					data_r <= (X"3C", X"5A", X"A5", X"81", X"A5", X"A5", X"42", X"3C");
					data_g <= (X"3C", X"5A", X"A5", X"81", X"A5", X"A5", X"42", X"3C");
					seg_data <= "        ";
					fodder_number <= 5;
					egg_number <= 0;
					if pressed_i = '1' and key = 14 then
						if sw(0 to 2) /= "100" and sw(0 to 2) /= "010" and sw(0 to 2) /= "001" then
							timer_ena <= '1';
							text_color <= (others => black);
							if msec > 20 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " FEED" & to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " MONEY" & to_string(money, 9999, 10, 4) & "  ";
										font_start <= '1';
										x <= 10;
										y <= 80;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										text_data <= " EGG" & to_string(egg, 9999, 10, 4) & "    ";
										font_start <= '1';
										x <= 10;
										y <= 120;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 3;
										end if;
									when 3 =>
										lcd_clear <= '0';
										text_data <= " FUNC:HOLD" & "  ";
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
								end case;
							else
								lcd_clear <= '1';
								bg_color <= white;
							end if;
						end if;
					else
						if sw(0 to 2) /= "100" and sw(0 to 2) /= "010" and sw(0 to 2) /= "001" then
							timer_ena <= '0';
							lcd_clear <= '1';
							bg_color <= l_paste_txt(l_addr, to_data(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70)), " FUNC:HOLD", (10, 40), black);
							pic_addr_sivs <= to_addr(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70));
						else
							text_color <= (others => black);
							case sw(0 to 2) is
								when "100" =>
									timer_ena <= '1';
									if msec > 100 then
										data_g <= (X"00", X"06", X"03", X"FF", X"FF", X"03", X"06", X"00");
										data_r <= (others => x"00");
										lcd_clear <= '0';
										text_data <= " FUNC:FEED  ";
										x <= 10;
										y <= 10;
										text_color <= all_black;
										font_start <= '1';
										if draw_done = '1' then
											font_start <= '0';
										end if;
										led_r <= '1';
										led_g <= '0';
										led_y <= '0';
										rgb <= "100";
									else
										lcd_clear <= '1';
										bg_color <= white;
										font_start <= '0';
									end if;
								when "010" =>
									timer_ena <= '1';
									if msec > 100 then
										data_g <= (X"28", X"FE", X"2A", X"2A", X"FE", X"A8", X"FE", X"28");
										data_r <= (others => x"00");
										lcd_clear <= '0';
										text_data <= " FUNC:SELL  ";
										x <= 10;
										y <= 10;
										text_color <= all_black;
										font_start <= '1';
										if draw_done = '1' then
											font_start <= '0';
										end if;
										led_r <= '0';
										led_g <= '1';
										led_y <= '0';
										rgb <= "010";
									else
										lcd_clear <= '1';
										bg_color <= white;
										font_start <= '0';
									end if;
								when "001" =>
									timer_ena <= '1';
									if msec > 100 then
										data_g <= (X"00", X"60", X"C0", X"FF", X"FF", X"C0", X"60", X"00");
										data_r <= (others => x"00");
										lcd_clear <= '0';
										text_data <= " FUNC:BUY   ";
										x <= 10;
										y <= 10;
										text_color <= all_black;
										font_start <= '1';
										if draw_done = '1' then
											font_start <= '0';
										end if;
										led_r <= '0';
										led_g <= '0';
										led_y <= '1';
										rgb <= "001";
									else
										lcd_clear <= '1';
										bg_color <= white;
										font_start <= '0';
									end if;
								when others => null;
							end case;
						end if;
					end if;
					if pressed = '1' and key = 14 then
						case sw(0 to 2) is
							when "100" =>
								state <= provide;
								provide_state <= red;
								timer_ena <= '0';
							when "010" =>
								state <= selling;
								sell_state <= timing_reset;
								timer_ena <= '0';
								price <= 10;
								pass(1) <= x"30";
								pass(0) <= x"31";
							when "001" =>
								state <= buying;
								buying_state <= red;
								timer_ena <= '0';
							when others => null;
						end case;
					end if;
				when provide =>
					led_r <= '1';
					led_g <= '0';
					led_y <= '0';
					rgb <= "100";
					seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
					case provide_state is
						when green => null;
						when red =>
							timer_ena <= '1';
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
							if msec > 100 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " NUM:" & to_string(fodder_number, 9999, 10, 4) & "   "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
										bg_color <= white;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " FUNC:FEED" & "  ";
										text_color <= (others => white);
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
									when 2 =>
										lcd_count <= 0;
									when 3 =>
										lcd_count <= 0;
								end case;
							else
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
								lcd_clear <= '1';
							end if;
							if pressed = '1' and key = 12 then
								provide_state <= green;
								state <= waiting;
								timer_ena <= '0';
							end if;
							data_r <= (X"00", X"06", X"03", X"FF", X"FF", X"03", X"06", X"00");
							data_g <= (X"00", X"06", X"03", X"FF", X"FF", X"03", X"06", X"00");
							if pressed = '1' and key < 11 and key /= 7 then
								case key is
									when 0 => number := 7;
									when 1 => number := 8;
									when 2 => number := 9;
									when 3 => number := 0;
									when 4 => number := 4;
									when 5 => number := 5;
									when 6 => number := 6;
									when 8 => number := 1;
									when 9 => number := 2;
									when 10 => number := 3;
									when others => null;
								end case;
								if fodder_number = 0 then
									fodder_number <= number;
								elsif fodder_number > 0 and fodder_number < 10 then
									fodder_number <= fodder_number * 10 + number;
								elsif fodder_number > 9 and fodder_number < 100 then
									fodder_number <= fodder_number * 10 + number;
								elsif fodder_number > 99 and fodder_number < 1000 then
									fodder_number <= fodder_number * 10 + number;
								elsif fodder_number > 999 then
									fodder_number <= (fodder_number mod 1000) * 10 + number;
								end if;
							elsif pressed = '1' and key = 13 then
								fodder_number <= 5;
							elsif pressed = '1' and key = 14 then
								if fodder_number <= fodder and fodder_number /= 0 then
									provide_state <= green_flash;
									timer_ena <= '0';
								end if;
							end if;
						when green_flash =>
							data_r <= (others => x"00");
							data_g <= (X"10", X"08", X"04", X"7E", X"FF", X"40", X"20", X"10");
							lcd_clear <= '1';
							bg_color <= l_paste_txt(l_addr, l_paste_txt(l_addr, l_paste_txt(l_addr, to_data(l_paste(l_addr, white, black, (0, 0), 128, 80)), " FUNC:FEED", (10, 10), white), " NUM:" & to_string(fodder_number, 9999, 10, 4) & "  ", (40, 10), white), "c o n n e c t . . .", (120, 10), black);
							if msec = 0 then
								timer_ena <= '1';
							end if;
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
							if msec > 100 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " NUM:" & to_string(fodder_number, 9999, 10, 4) & "   "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => white);
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " FUNC:FEED" & "  ";
										text_color <= (others => white);
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										if msec mod 1000 < 300 then
											text_data <= "connect." & "    ";
										elsif msec mod 1000 < 600 then
											text_data <= "connect.." & "   ";
										elsif msec mod 1000 <= 1000 then
											text_data <= "connect..." & "  ";
										end if;
										text_color <= (others => black);
										font_start <= '1';
										x <= 10;
										y <= 80;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
										bg_color <= white;
									when 3 =>
										lcd_count <= 0;
								end case;
							else
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
								lcd_clear <= '1';
							end if;

							if rx_done = '1' then --接收軟體資料
								if to_integer(rx_data) = 13 then
									count <= 0;
									provide_state <= check;
									timer_ena <= '0';
								else
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;
							pass_str <= to_string(to_integer(pass(0)) - 48, 9, 10, 1) & to_string(to_integer(pass(1)) - 48, 9, 10, 1) & to_string(to_integer(pass(2)) - 48, 9, 10, 1) & to_string(to_integer(pass(3)) - 48, 9, 10, 1) & to_string(to_integer(pass(4)) - 48, 9, 10, 1) & to_string(to_integer(pass(5)) - 48, 9, 10, 1);
						when check => --check password true or not
							if pass_str = "912932" then
								provide_state <= orange_flash;
								fodder <= fodder - fodder_number + (fodder_number mod 5);
								egg <= egg + fodder_number/5;
							else
								provide_state <= red_flash;
							end if;
						when orange_flash =>
							data_g <= (X"10", X"08", X"04", X"7E", X"FF", X"40", X"20", X"10");
							data_r <= (X"10", X"08", X"04", X"7E", X"FF", X"40", X"20", X"10");
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
							timer_ena <= '1';
							if msec > 300 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " NUM:" & to_string(fodder_number, 9999, 10, 4) & "   "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => white);
										x <= 10;
										y <= 40;
										bg_color <= black;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " FUNC:FEED" & "  ";
										text_color <= (others => white);
										font_start <= '1';
										bg_color <= black;
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										text_data <= "    PASS    ";
										text_color <= (others => black);
										font_start <= '1';
										x <= 10;
										y <= 80;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
										bg_color <= white;
									when 3 =>
										lcd_count <= 0;
								end case;
							else
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
								lcd_clear <= '1';
							end if;
							if msec > 2000 then
								timer_ena <= '0';
								fodder_number <= 0;
								state <= waiting;
							end if;
						when red_flash =>
							data_g <= (others => x"00");
							data_r <= (X"10", X"08", X"04", X"7E", X"FF", X"40", X"20", X"10");
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
							timer_ena <= '1';
							if msec > 300 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " NUM:" & to_string(fodder_number, 9999, 10, 4) & "   "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => white);
										bg_color <= black;
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " FUNC:FEED" & "  ";
										text_color <= (others => white);
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										text_data <= "    FAIL    ";
										text_color <= (others => black);
										font_start <= '1';
										x <= 10;
										y <= 80;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
										bg_color <= white;
									when 3 =>
										lcd_count <= 0;
								end case;
							else
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 80));
								lcd_clear <= '1';
							end if;
							if msec > 2000 then
								timer_ena <= '0';
								fodder_number <= 0;
								state <= waiting;
							end if;
					end case;
				when selling =>
					led_r <= '0';
					led_g <= '1';
					led_y <= '0';
					rgb <= "010";
					seg_data <= to_string(egg, 999, 10, 3) & "   " & to_string(price, 99, 10, 2);

					case sell_state is
						when timing_reset =>
							if msec = 0 then
								sell_state <= red;
							else
								timer_ena <= '0';
							end if;
						when red =>
							timer_ena <= '1';

							data_g <= (X"28", X"FE", X"2A", X"2A", X"FE", X"A8", X"FE", X"28");
							data_r <= (X"28", X"FE", X"2A", X"2A", X"FE", X"A8", X"FE", X"28");
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
							if msec > 100 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= "  $" & to_string(price, 99, 10, 2) & "/EGG   "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => red);
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
										bg_color <= white;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " FUNC:SELL" & "  ";
										text_color <= (others => white);
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
									when 2 =>
										lcd_count <= 0;
									when 3 =>
										lcd_count <= 0;
								end case;
							else
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
								lcd_clear <= '1';
							end if;
							if rx_done = '1'then
								if to_integer(rx_data) = 13 then
									count <= 0;
									if count = 1 then
										pass(1) <= pass(0);
										pass(0) <= x"30";
									end if;
								else
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;
							price <= (to_integer(pass(0)) - 48) * 10 + to_integer(pass(1)) - 48;

							if pressed = '1' and key = 14 then
								sell_state <= sell;
								timer_ena <= '0';
							end if;
							if pressed = '1' and key = 12 then
								state <= waiting;
								timer_ena <= '0';
							end if;
						when sell =>
							bg_color <= white;
							timer_ena <= '1';
							if msec > 100 then
								bg_color <= l_paste_txt(l_addr, to_data(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70)), " FUNC:HOLD", (10, 40), black);
								pic_addr_sivs <= to_addr(l_paste(l_addr, white, pic_data_sivs, (90, 30), 70, 70));
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " NUM:" & to_string(egg_number, 999, 10, 3) & "    "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										if egg_number > egg then
											text_data <= "NOT ENOUGH  ";
										else
											profit <= egg_number * price;
											text_data <= " $NT" & to_string(price * egg_number, 9999, 10, 4) & "    "; --& to_string(fodder, 9999, 10, 4) & "   ";
										end if;
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 60;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_count <= 3;
									when 3 =>
										lcd_clear <= '0';
										text_data <= " FUNC:SELL" & "  ";
										text_color <= (others => black);
										font_start <= '1';
										x <= 10;
										y <= 10;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
								end case;
							else
								lcd_clear <= '1';
								bg_color <= l_paste_txt(l_addr, to_data(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70)), " FUNC:HOLD", (10, 40), black);
								pic_addr_sivs <= to_addr(l_paste(l_addr, white, pic_data_sivs, (90, 30), 70, 70));
							end if;
							if pressed = '1' and key < 11 and key /= 7 then
								case key is
									when 0 => number := 7;
									when 1 => number := 8;
									when 2 => number := 9;
									when 3 => number := 0;
									when 4 => number := 4;
									when 5 => number := 5;
									when 6 => number := 6;
									when 8 => number := 1;
									when 9 => number := 2;
									when 10 => number := 3;
									when others => null;
								end case;
								if egg_number = 0 then
									egg_number <= number;
								elsif egg_number > 0 and egg_number < 10 then
									egg_number <= egg_number * 10 + number;
								elsif egg_number > 9 and egg_number < 100 then
									egg_number <= egg_number * 10 + number;
								elsif egg_number > 99 then
									egg_number <= (egg_number mod 100) * 10 + number;
								end if;
							elsif pressed = '1' and key = 13 then
								egg_number <= 0;
							elsif pressed = '1' and key = 14 then
								if egg_number <= egg then
									sell_state <= ending;
									timer_ena <= '0';
									egg <= egg - egg_number;
									money <= money + (egg_number * price);
								end if;
							end if;
						when ending =>
							timer_ena <= '1';
							case lcd_count is
								when 0 =>
									lcd_clear <= '0';
									text_data <= " NUM:" & to_string(egg_number, 999, 10, 3) & "    "; --& to_string(fodder, 9999, 10, 4) & "   ";
									font_start <= '1';
									text_color <= (others => black);
									x <= 10;
									y <= 40;
									if draw_done = '1' then
										font_start <= '0';
										lcd_count <= 1;
									end if;
								when 1 =>
									lcd_clear <= '0';
									text_data <= " $NT" & to_string(profit, 9999, 10, 4) & "    "; --& to_string(fodder, 9999, 10, 4) & "   ";
									font_start <= '1';
									text_color <= (others => red);
									x <= 10;
									y <= 60;
									if draw_done = '1' then
										font_start <= '0';
										lcd_count <= 2;
									end if;
								when 2 =>
									lcd_count <= 3;
								when 3 =>
									lcd_clear <= '0';
									text_data <= " FUNC:SELL" & "  ";
									text_color <= (others => black);
									font_start <= '1';
									x <= 10;
									y <= 10;
									if draw_done = '1' then
										font_start <= '0';
										lcd_count <= 0;
									end if;
							end case;
							if msec > 2000 then
								state <= waiting;
								timer_ena <= '0';
							end if;
					end case;
				when buying =>
					led_r <= '0';
					led_g <= '0';
					led_y <= '1';
					rgb <= "001";
					case buying_state is
						when red =>
							data_r <= (X"00", X"60", X"C0", X"FF", X"FF", X"C0", X"60", X"00");
							data_g <= (X"00", X"60", X"C0", X"FF", X"FF", X"C0", X"60", X"00");
							point <= 0;
							lcd_clear <= '0';
							text_data <= " FUNC:BUY   ";
							x <= 10;
							y <= 10;
							text_color <= all_black;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
							end if;
							timer_ena <= '1';
							if msec > 2000 then
								timer_ena <= '0';
								buying_state <= play;
							end if;
						when play =>
							seg_data <= "TIME  " & to_string(20 - msec/1000, 99, 10, 2);
							bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
							if msec > 300 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " PTS:" & to_string(point, 99, 10, 2) & "     "; --& to_string(fodder, 9999, 10, 4) & "   ";
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 40;
										bg_color <= white;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= " MONEY:" & to_string(money, 9999, 10, 4) & " ";
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 80;
										bg_color <= white;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										text_data <= " FEED:" & to_string(fodder, 9999, 10, 4) & "  ";
										font_start <= '1';
										text_color <= (others => black);
										x <= 10;
										y <= 120;
										bg_color <= white;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 3;
										end if;
									when 3 =>
										lcd_clear <= '0';
										text_data <= " FUNC:BUY" & "   ";
										text_color <= (others => white);
										font_start <= '1';
										x <= 10;
										y <= 10;
										bg_color <= black;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
								end case;
							else
								lcd_clear <= '1';
								bg_color <= to_data(l_paste(l_addr, white, black, (0, 0), 128, 40));
							end if;
							timer_ena <= '1';
							data_g <= (others => x"00");
							data_r <= (others => x"00");
							data_g(buy_y)(buy_x) <= '1';
							data_g(sell_y)(sell_x) <= buy_enable(0);
							data_r(sell_y)(sell_x) <= buy_enable(0);
							if buy_x = sell_x and buy_y = sell_y then
								data_g(sell_y)(sell_x) <= '1';
								data_r(sell_y)(sell_x) <= '0';
								buying_state <= random;
								if msec < 10000 then
									if money >= 100 and buy_enable(0) = '1' then
										money <= money - 100;
										fodder <= fodder + 50;
										buy_enable(0) <= '0';
									end if;
								elsif msec > 10000 and msec < 20000 then
									if money >= 50 and buy_enable(0) = '1' then
										money <= money - 50;
										fodder <= fodder + 50;
										buy_enable(0) <= '0';
									end if;
								end if;
							end if;
							if pressed = '1' and key = 1 and buy_y /= 7 then
								buy_y <= buy_y + 1;
							end if;
							if pressed = '1' and key = 4 and buy_x /= 0 then
								buy_x <= buy_x - 1;
							end if;
							if pressed = '1' and key = 6 and buy_x /= 7 then
								buy_x <= buy_x + 1;
							end if;
							if pressed = '1' and key = 9 and buy_y /= 0 then
								buy_y <= buy_y - 1;
							end if;
							random2 <= random2 + 2;
							random1 <= random1 + 1;

							if msec >= 20000 then
								if msec > 20500 then
									data_g <= (others => x"00");
									data_r <= (others => x"00");
									buying_state <= ending;
									timer_ena <= '0';
								else
									lcd_clear <= '1';
									bg_color <= white;
								end if;
							end if;
						when random =>
							sell_x <= random_x(random1);
							sell_y <= random_y(random2);
							buy_enable(0) <= '1';
							point <= point + 1;
							buying_state <= play;
						when ending =>
							data_g <= (others => x"00");
							data_r <= (others => x"00");
							buy_x <= 0;
							buy_y <= 0;
							sell_x <= 6;
							sell_y <= 6;
							bg_color <= white;
							lcd_clear <= '0';
							text_data <= " FUNC:BUY   ";
							x <= 10;
							y <= 10;
							text_color <= all_black;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
							end if;
							led_r <= '0';
							led_g <= '0';
							led_y <= '1';
							rgb <= "001";
							timer_ena <= '1';
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							if msec >= 5000 then
								state <= waiting;
							end if;
					end case;
			end case;
		end if;
	end process;

end arch;
