library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity test113_2 is
	port (
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
	--buz
	signal buz_ena, buz_flag : std_logic;
	signal buz_busy, buz_done : std_logic;

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
	--user
	type system_state is (reset, waiting, provide, selling, buying);
	signal state : system_state;
	type feeding_state is (feed, day, guess, enough, notenough, waiting);
	type buying_state is (move, enough, notenough);
	type selling_state is (sell, finish, waiting);
	signal sell_state : selling_state;
	signal feed_state : feeding_state;
	signal buy_state : buying_state;
	signal fodder : integer := 100;
	signal money : integer := 500;
	signal egg : integer;
	signal fodder_number : integer := 0;
	signal digit : std_logic := '0';
	type sell_coord is array(0 to 4) of integer range 0 to 7;
	signal sell_x : sell_coord := (2, 6, 1, 3, 6);
	signal sell_y : sell_coord := (1, 6, 3, 5, 2);
	signal buy_x : integer range 0 to 7 := 1;
	signal buy_y : integer range 0 to 7 := 6;
	signal buy_enable : unsigned(0 to 4) := "11111";
	signal lcd_count : integer range 0 to 3;
	signal price : integer range 0 to 9;
	signal flag : std_logic;
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
			text_size        => 2,
			text_data        => text_data,
			text_count       => open,
			addr             => open,
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
	process (clk, rst_n)
		variable number : integer := 0;
		variable day_number : integer := 0;
	begin
		if rst_n = '0' or (pressed = '1' and key = 3) then
			lcd_con <= '0';
			state <= reset;
			timer_ena <= '0';
			buy_enable <= "11111";
			seg_data <= "        ";
			lcd_clear <= '1';
			bg_color <= white;
		elsif rising_edge(clk) then
			if pressed = '1' and key = 12 then
				state <= waiting;
			end if;
			if state /= reset then
				case lcd_count is
					when 0 =>
						text_data <= " EGG        ";
						font_start <= '1';
						x <= - 5;
						y <= 0;
						text_color(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 1;
						end if;
					when 1 =>
						text_data <= " " & to_string(egg, 999, 10, 2) & "  " & to_string(price, 9, 10, 1) & "      ";
						font_start <= '1';
						x <= - 5;
						y <= 40;
						text_color(1 to 6) <= (black, black, black, black, black, red);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 2;
						end if;
					when 2 =>
						text_data <= "            ";
						font_start <= '1';
						x <= - 5;
						y <= 80;
						text_color(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 3;
						end if;
					when 3 =>
						if sw(2) = '0' then
							text_data <= "    S0      ";
						else
							text_data <= "    S1      ";
						end if;
						font_start <= '1';
						x <= - 5;
						y <= 120;
						text_color(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 0;
						end if;
				end case;
			end if;
			case state is
				when reset =>
					data_g <= (others => x"00");
					data_r <= (others => x"00");
					timer_ena <= '1';
					fodder <= 40;
					money <= 500;
					seg_data <= "        ";
					egg <= 0;
					bg_color <= white;
					lcd_clear <= '1';
					rgb <= "000";
					if msec < 1000 then
						led_r <= '1';
						led_g <= '0';
						led_y <= '0';
					elsif msec < 2000 then
						led_r <= '0';
						led_g <= '1';
						led_y <= '0';
					elsif msec < 3000 then
						led_r <= '0';
						led_g <= '0';
						led_y <= '1';
					elsif msec > 3000 then
						led_r <= '0';
						led_g <= '0';
						led_y <= '0';
						timer_ena <= '0';
						state <= waiting;
					end if;
				when waiting =>
					mot_speed <= 0;
					data_g <= (x"00", x"7e", x"42", x"42", x"42", x"42", x"7E", x"00");
					data_r <= (others => x"00");
					timer_ena <= '1';

					if msec mod 1500 < 500 then
						rgb <= "100";
					elsif msec mod 1500 < 1000 then
						rgb <= "010";
					elsif msec mod 1500 < 1500 then
						rgb <= "001";
					end if;
					lcd_clear <= '0';
					seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
					if pressed = '1' and key = 11 then
						case sw(0 to 1) is
							when "10" =>
								state <= provide;
								feed_state <= feed;
								timer_ena <= '0';
								fodder_number <= 0;
								day_number := 0;
								flag <= '0';
							when "01" =>
								state <= buying;
								buy_state <= move;
								timer_ena <= '0';
							when others => null;
						end case;
					end if;
				when provide =>
					case feed_state is
						when feed =>

							if pressed = '1' and key < 14 and key /= 3 then
								case key is
									when 0 => number := 1;
									when 1 => number := 2;
									when 2 => number := 3;
									when 3 => number := 0;
									when 4 => number := 4;
									when 5 => number := 5;
									when 6 => number := 6;
									when 7 => number := 0;
									when 8 => number := 7;
									when 9 => number := 8;
									when 10 => number := 9;
									when 13 => number := 0;
									when others => null;
								end case;
								fodder_number <= number;
							end if;
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(fodder_number, 9999, 10, 4);
							data_g <= (others => x"00");
							data_r <= (x"F8", x"F0", x"F0", x"F8", x"9C", x"0E", x"07", x"02");
							if pressed = '1' and key = 11 then
								feed_state <= day;
								number := 0;
							end if;
						when day =>
							if pressed = '1' and key < 14 and key /= 3 then
								case key is
									when 0 => number := 1;
									when 1 => number := 2;
									when 2 => number := 3;
									when 3 => number := 0;
									when 4 => number := 4;
									when 5 => number := 5;
									when 6 => number := 6;
									when 7 => number := 0;
									when 8 => number := 7;
									when 9 => number := 8;
									when 10 => number := 9;
									when 13 => number := 0;
									when others => null;
								end case;
								day_number := number;
							end if;
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(day_number, 9999, 10, 4);
							data_g <= (others => x"00");
							data_r <= (x"F8", x"F0", x"F0", x"F8", x"9C", x"0E", x"07", x"02");
							if pressed = '1' and key = 11 then
								feed_state <= guess;
							end if;
						when guess =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(day_number * fodder_number, 9999, 10, 4);
							if pressed = '1' and key = 11 then
								if day_number * fodder_number <= fodder then
									feed_state <= enough;
									fodder <= fodder - day_number * fodder_number;
									egg <= egg + 2 * day_number * fodder_number;
								else
									feed_state <= notenough;
								end if;
							end if;
						when notenough =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(day_number * fodder_number, 9999, 10, 4);
							timer_ena <= '1';
							if msec < 1000 then
								buz <= '1';
								led_r <= '1';
							else
								buz <= '0';
								led_r <= '0';
							end if;
							if pressed = '1' and key = 11 then
								state <= waiting;
							end if;
						when enough =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(day_number * fodder_number, 9999, 10, 4);
							feed_state <= waiting;
						when waiting =>
							buz <= '0';
							timer_ena <= '1';
							if msec < 1000 then
								led_g <= '1';
							else
								led_g <= '0';
							end if;
							if pressed = '1' and key = 11 then
								state <= selling;
								sell_state <= sell;
							end if;
					end case;
				when selling =>
					case sell_state is
						when sell =>
							if sw(2) = '0' then
								seg_data <= to_string(egg * price, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							else
								seg_data <= to_string(3 * egg * price, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							end if;
							if flag = '1' then
								seg_data <= "    " & to_string(money, 9999, 10, 4);
							end if;
							data_g <= (x"24", x"24", x"FE", x"25", x"7E", x"A4", x"7F", x"24");
							data_r <= (x"24", x"24", x"FE", x"25", x"7E", x"A4", x"7F", x"24");
							lcd_clear <= '0';
							if rx_done = '1' and to_integer(rx_data) /= 13 then
								price <= to_integer(rx_data);
							end if;
							if pressed = '1' and key = 11 then
								if sw(2) = '0' then
									money <= money + egg * price;
								else
									money <= money + 3 * egg * price;
								end if;
								egg <= 0;
								price <= 0;
								sell_state <= finish;
							end if;
						when finish =>
							seg_data <= "    " & to_string(money, 9999, 10, 4);
							if pressed = '1' and key = 11 then
								state <= waiting;
							end if;
						when waiting =>
					end case;
				when buying =>
					case buy_state is
						when move =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							data_g <= (others => x"00");
							data_r <= (others => x"00");
							data_g(buy_y)(buy_x) <= '1';
							for i in 0 to 4 loop
								if i > 1 then
									data_g(sell_y(i))(sell_x(i)) <= buy_enable(i);
									data_r(sell_y(i))(sell_x(i)) <= buy_enable(i);
									if buy_x = sell_x(i) and buy_y = sell_y(i) then
										data_g(sell_y(i))(sell_x(i)) <= '1';
										data_r(sell_y(i))(sell_x(i)) <= '0';
										if money >= 300 and buy_enable(i) = '1' then
											buy_state <= enough;
											fodder <= fodder + 50;
											buy_enable(i) <= '0';
											money <= money - 300;
										else
											buy_state <= notenough;
											timer_ena <= '0';
										end if;
									end if;
								else
									data_g(sell_y(i))(sell_x(i)) <= '0';
									data_r(sell_y(i))(sell_x(i)) <= buy_enable(i);
									if buy_x = sell_x(i) and buy_y = sell_y(i) then
										data_g(sell_y(i))(sell_x(i)) <= '1';
										data_r(sell_y(i))(sell_x(i)) <= '0';
										if money >= 500 and buy_enable(i) = '1' then
											buy_state <= enough;
											fodder <= fodder + 100;
											buy_enable(i) <= '0';
											money <= money - 500;
										else
											buy_state <= notenough;
											timer_ena <= '0';
										end if;
									end if;
								end if;
							end loop;
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
						when enough =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							mot_speed <= 70;
							if pressed = '1' and key = 11 then
								state <= waiting;
								buy_x <= 1;
								buy_y <= 6;
								data_g <= (others => x"00");
								data_r <= (others => x"00");
								buy_enable <= "11111";
							end if;
						when notenough =>
							seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
							timer_ena <= '1';
							if msec < 1000 then
								buz <= '1';
							else
								buz <= '0';
							end if;
							if pressed = '1' and key = 11 then
								buz <= '0';
								state <= waiting;
								buy_x <= 1;
								buy_y <= 6;
								data_g <= (others => x"00");
								data_r <= (others => x"00");
								buy_enable <= "11111";
							end if;
					end case;
			end case;
		end if;
	end process;
end arch;
