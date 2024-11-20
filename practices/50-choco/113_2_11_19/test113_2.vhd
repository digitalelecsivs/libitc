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
	signal l_addr : l_addr_t;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal bg_color : l_px_t;
	signal lcd_con : std_logic;
	-- signal pic_addr : l_addr_t;
	-- signal pic_data : l_px_t;
	constant lcd_color1 : l_px_arr_t(1 to 4) := (white, black, black, red);
	constant lcd_color2 : l_px_arr_t(1 to 4) := (white, black, black, black);

	--user
	type system_state is (reset, waiting, provide, selling, buying);
	signal state : system_state;
	signal fodder : integer := 100;
	signal money : integer := 500;
	signal egg : integer;
	signal fodder_number, egg_number : integer := 0;
	signal digit : std_logic := '0';
	type sell_coord is array(0 to 4) of integer range 0 to 7;
	signal sell_x : sell_coord := (6, 5, 2, 7, 3);
	signal sell_y : sell_coord := (1, 7, 2, 4, 3);
	signal buy_x, buy_y : integer range 0 to 7;
	signal buy_enable : unsigned(0 to 4) := "11111";
	signal lcd_count : integer range 0 to 3;
	signal price : integer range 0 to 9;
	signal clk5, clk_e5 : std_logic;
	type a is array(0 to 2) of l_px_t;
	signal pic_data : a;
	type b is array(0 to 2) of l_addr_t;
	signal pic_addr : b;
	type c is array(0 to 2) of std_logic_vector(0 to 23);
	signal pic_data_o : c;
	signal pass : u8_arr_t(0 to 5) := (x"31", x"30", x"00", x"00", x"00", x"00");--rx's data
	signal pass_str : string(1 to 6);--software pass
	signal count : integer range 0 to 50;
	type sell_state is (waiting, check, success, fail, sell);
	signal selling_state : sell_state;
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 5 --頻率
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk5 --輸出
		);
	edge_e1 : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => clk5,   --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => clk_e5, --正緣 '1'觸發
			falling => open    --負緣 open=開路
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
			pic_addr         => open,
			pic_data         => pic_data(0),
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
		);
	feed : entity work.FEED(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(0), 10)),
			clock   => clk,
			q       => pic_data_o(0)
		);
	egg_pic : entity work.egg(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(2), 10)),
			clock   => clk,
			q       => pic_data_o(2)
		);
	money_pic : entity work.price(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr(1), 10)),
			clock   => clk,
			q       => pic_data_o(1)
		);
	process (clk, rst_n)
		variable number : integer := 0;
	begin
		pic_data(0) <= unsigned(pic_data_o(0));
		pic_data(1) <= unsigned(pic_data_o(1));
		pic_data(2) <= unsigned(pic_data_o(2));
		if rst_n = '0' or (pressed = '1' and key = 3) then
			lcd_con <= '0';

			state <= reset;
			timer_ena <= '0';
			buy_enable <= "11111";
			seg_data <= "        ";
			lcd_clear <= '1';
			bg_color <= white;
			x <= 0;
			y <= 0;
		elsif rising_edge(clk) then
			case state is
				when reset =>
					led_r <= '0';
					led_g <= '0';
					led_y <= '0';
					if msec = 0 then
						timer_ena <= '1';
					end if;
					fodder <= 100;
					money <= 500;
					egg <= 0;
					lcd_clear <= '1';
					if msec < 1500 then
						bg_color <= to_data(l_paste(l_addr, white, blue, (y, x), 128, 10));
						x <= 0;
						if clk_e5 = '1' then
							y <= y + 20;
						end if;
						mot_speed <= 30;
					elsif msec < 3000 then
						bg_color <= to_data(l_paste(l_addr, white, blue, (y, x), 10, 160));
						y <= 0;
						if clk_e5 = '1' then
							x <= x + 20;
						end if;
						mot_speed <= 50;
					else
						timer_ena <= '0';
						state <= waiting;
					end if;
					if msec mod 1000 < 300 then
						data_g <= (others => x"FF");
						data_r <= (others => x"00");
					elsif msec mod 1000 < 600 then
						data_r <= (others => x"FF");
						data_g <= (others => x"00");
					elsif msec mod 1000 < 900 then
						data_r <= (others => x"FF");
						data_g <= (others => x"FF");
					end if;
					-- rgb <= "111";
					-- if msec < 500 then
					-- 	rgb <= "000";
					-- elsif msec < 1000 then
					-- 	rgb <= "100";
					-- elsif msec < 2000 then
					-- 	rgb <= "110";
					-- elsif msec < 3000 then
					-- 	rgb <= "111";
					-- elsif msec > 4000 then
					-- 	rgb <= "000";
					-- 	timer_ena <= '0';
					-- 	state <= waiting;
					-- end if;
				when waiting =>

					mot_speed <= 0;
					-- seg_data <= "HOLD    ";
					seg_data <= to_string(msec, 9999, 10, 8);
					lcd_clear <= '1';
					if msec = 0 then
						timer_ena <= '1';
					end if;
					if msec < 200 then
						lcd_clear <= '1';
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, pic_data(2), (90, 10), 32, 32)), pic_data(1), (50, 10), 32, 32)), pic_data(0), (10, 10), 32, 32));
						pic_addr(0) <= to_addr(l_paste(l_addr, white, pic_data(0), (10, 10), 32, 32));
						pic_addr(1) <= to_addr(l_paste(l_addr, white, pic_data(1), (50, 10), 32, 32));
						pic_addr(2) <= to_addr(l_paste(l_addr, white, pic_data(2), (100, 10), 32, 32));
					else
						bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, pic_data(2), (90, 10), 32, 32)), pic_data(1), (50, 10), 32, 32)), pic_data(0), (10, 10), 32, 32));
						pic_addr(0) <= to_addr(l_paste(l_addr, white, pic_data(0), (10, 10), 32, 32));
						pic_addr(1) <= to_addr(l_paste(l_addr, white, pic_data(1), (50, 10), 32, 32));
						pic_addr(2) <= to_addr(l_paste(l_addr, white, pic_data(2), (100, 10), 32, 32));
						text_color <= (others => black);
						case lcd_count is
							when 0 =>
								lcd_clear <= '0';
								text_data <= to_string(fodder, 9999, 10, 4) & "        ";
								font_start <= '1';
								x <= 70;
								y <= 40;
								if draw_done = '1' then
									font_start <= '0';
									lcd_count <= 1;
								end if;
							when 1 =>
								lcd_clear <= '0';
								text_data <= to_string(money, 9999, 10, 4) & "        ";
								font_start <= '1';
								x <= 70;
								y <= 80;
								if draw_done = '1' then
									font_start <= '0';
									lcd_count <= 2;
								end if;
							when 2 =>
								lcd_clear <= '0';
								text_data <= to_string(egg, 9999, 10, 4) & "        ";
								font_start <= '1';
								x <= 70;
								y <= 135;
								if draw_done = '1' then
									font_start <= '0';
									lcd_count <= 0;
								end if;
							when 3 =>
						end case;
					end if;
					if sw(0 to 2) = "100" then
						data_g <= (X"40", X"40", X"40", X"7E", X"40", X"40", X"7E", X"00");
						data_r <= (X"40", X"40", X"40", X"7E", X"40", X"40", X"7E", X"00");
					elsif sw(0 to 2) = "010" then
						data_g <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
						data_r <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
					elsif sw(0 to 2) = "001" then
						data_g <= (X"00", X"10", X"20", X"7F", X"FF", X"60", X"20", X"10");
						data_r <= (X"00", X"10", X"20", X"7F", X"FF", X"60", X"20", X"10");
					else
						data_g <= (others => x"00");
						data_r <= (others => x"00");
					end if;
					seg_data <= "HOLD    ";
					if pressed = '1' and key = 7 then
						case sw(0 to 2) is
							when "100" =>
								state <= provide;
								timer_ena <= '0';
							when "010" =>
								state <= selling;
								timer_ena <= '0';
								selling_state <= waiting;
							when "001" =>
								state <= buying;
								timer_ena <= '0';
							when others => null;
						end case;
					end if;
				when provide =>
					seg_data <= "FEED" & to_string(fodder_number, 9999, 10, 4);
					if fodder_number < 100 then
						data_g <= (x"ff", x"ff", x"00", x"00", x"00", x"00", x"00", x"00");
						data_r <= (x"ff", x"ff", x"00", x"00", x"00", x"00", x"00", x"00");
					elsif fodder_number < 300 then
						data_g <= (x"ff", x"ff", x"7E", x"7E", x"00", x"00", x"00", x"00");
						data_r <= (x"ff", x"ff", x"7E", x"7E", x"00", x"00", x"00", x"00");
					elsif fodder_number < 500 then
						data_g <= (x"ff", x"ff", x"7E", x"7E", x"3C", x"3C", x"00", x"00");
						data_r <= (x"ff", x"ff", x"7E", x"7E", x"3C", x"3C", x"00", x"00");
					elsif fodder_number >= 500 then
						data_g <= (x"ff", x"ff", x"7E", x"7E", x"3C", x"3C", x"18", x"18");
						data_r <= (x"ff", x"ff", x"7E", x"7E", x"3C", x"3C", x"18", x"18");
					end if;
					if rx_done = '1' or pass(0 to 3) = (x"77", x"77", x"77", x"77") then--接收軟體資料
						if to_integer(rx_data) = 13 then
							count <= 0;
							case count is
								when 0 => fodder_number <= 0;
								when 1 => fodder_number <= to_integer(pass(0)) - 48;
								when 2 => fodder_number <= (to_integer(pass(0)) - 48) * 10 + (to_integer(pass(1)) - 48);
								when 3 => fodder_number <= (to_integer(pass(0)) - 48) * 100 + (to_integer(pass(1)) - 48) * 10 + (to_integer(pass(2)) - 48);
								when 4 => fodder_number <= (to_integer(pass(0)) - 48) * 1000 + (to_integer(pass(1)) - 48) * 100 + (to_integer(pass(2)) - 48) * 10 + (to_integer(pass(3)) - 48);
								when others => null;
							end case;
						elsif pass(0 to 3) /= (x"77", x"77", x"77", x"77") then
							pass(count) <= rx_data;
							count <= count + 1;
						end if;
						if pass(0 to 3) = (x"77", x"77", x"77", x"77") then
							if fodder_number <= fodder then
								timer_ena <= '1';
								pass <= (others => x"00");
							else
								pass <= (others => x"00");
								fodder_number <= 0;
							end if;
						end if;

					end if;

					if msec /= 0 then
						mot_speed <= 50;
						if msec > 1000 then
							timer_ena <= '0';
							state <= waiting;
							fodder <= fodder - fodder_number;
							egg <= egg + fodder_number * 4;
							fodder_number <= 0;
						end if;
					else
						mot_speed <= 0;
					end if;
					if pressed = '1' and key = 14 then
						state <= waiting;
						timer_ena <= '0';
					end if;
					-- if pressed = '1' and key = 14 then
					-- 	if fodder_number = 0 then
					-- 		state <= waiting;
					-- 	elsif fodder >= fodder_number then
					-- 		fodder <= fodder - fodder_number;
					-- 		egg <= fodder_number * 4;
					-- 		fodder_number <= 0;
					-- 	else
					-- 		fodder_number <= 0;
					-- 	end if;
					-- end if;
				when selling =>
					case selling_state is
						when waiting =>
							if msec = 0 then
								timer_ena <= '1';
							end if;
							if msec < 200 then
								lcd_clear <= '1';
								bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, pic_data(2), (90, 10), 32, 32)), pic_data(1), (50, 10), 32, 32)), pic_data(0), (10, 10), 32, 32));
								pic_addr(0) <= to_addr(l_paste(l_addr, white, pic_data(0), (10, 10), 32, 32));
								pic_addr(1) <= to_addr(l_paste(l_addr, white, pic_data(1), (50, 10), 32, 32));
								pic_addr(2) <= to_addr(l_paste(l_addr, white, pic_data(2), (100, 10), 32, 32));
							else
								bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, pic_data(2), (90, 10), 32, 32)), pic_data(1), (50, 10), 32, 32)), pic_data(0), (10, 10), 32, 32));
								pic_addr(0) <= to_addr(l_paste(l_addr, white, pic_data(0), (10, 10), 32, 32));
								pic_addr(1) <= to_addr(l_paste(l_addr, white, pic_data(1), (50, 10), 32, 32));
								pic_addr(2) <= to_addr(l_paste(l_addr, white, pic_data(2), (100, 10), 32, 32));
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= to_string(fodder, 9999, 10, 4) & "        ";
										font_start <= '1';
										x <= 70;
										y <= 40;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										lcd_clear <= '0';
										text_data <= to_string(money, 9999, 10, 4) & "        ";
										font_start <= '1';
										x <= 70;
										y <= 80;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										lcd_clear <= '0';
										text_data <= to_string(egg, 9999, 10, 4) & "        ";
										font_start <= '1';
										x <= 70;
										y <= 135;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
									when 3 =>
								end case;
							end if;
							seg_data <= "ID CHECK";
							data_g <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
							data_r <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
							if pressed = '1' and key < 11 and key /= 3 then
								case key is
									when 0 => pass(count) <= x"31";
										count <= count + 1;
									when 1 => pass(count) <= x"32";
										count <= count + 1;

									when 2 => pass(count) <= x"33";
										count <= count + 1;

									when 4 => pass(count) <= x"34";
										count <= count + 1;

									when 5 => pass(count) <= x"35";
										count <= count + 1;

									when 6 => pass(count) <= x"36";
										count <= count + 1;

									when 8 => pass(count) <= x"37";
										count <= count + 1;

									when 9 => pass(count) <= x"38";
										count <= count + 1;

									when 10 => pass(count) <= x"39";
										count <= count + 1;
									when 13 => pass(count) <= x"30";
										count <= count + 1;
									when others => null;
								end case;
							end if;
							-- if rx_done = '1' then --接收軟體資料
							-- 	if to_integer(rx_data) = 13 then
							-- 		count <= 0;
							-- 		timer_ena <= '0';
							-- 		selling_state <= check;
							-- 	else
							-- 		pass(count) <= rx_data;
							-- 		count <= count + 1;
							-- 	end if;
							-- end if;
							pass_str <= to_string(to_integer(pass(0)) - 48, 9, 10, 1) & to_string(to_integer(pass(1)) - 48, 9, 10, 1) & to_string(to_integer(pass(2)) - 48, 9, 10, 1) & to_string(to_integer(pass(3)) - 48, 9, 10, 1) & to_string(to_integer(pass(4)) - 48, 9, 10, 1) & to_string(to_integer(pass(5)) - 48, 9, 10, 1);
							if pressed = '1' and key = 7 then
								count <= 0;
								timer_ena <= '0';
								selling_state <= check;
							end if;
							if pressed = '1' and key = 14 then
								state <= waiting;
								timer_ena <= '0';
							end if;
						when check =>
							if pass_str = "147852" then
								timer_ena <= '0';
								selling_state <= success;
							else
								selling_state <= fail;
							end if;
						when success =>
							data_g <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
							data_r <= (others => x"00");
							seg_data <= "success ";
							if msec = 0 then
								timer_ena <= '1';
							end if;
							if msec > 1000 then
								selling_state <= sell;
								timer_ena <= '0';
							end if;
						when fail =>
							data_r <= (X"00", X"08", X"04", X"FE", X"FF", X"06", X"04", X"08");
							data_g <= (others => x"00");
							seg_data <= "fail    ";
							if msec = 0 then
								timer_ena <= '1';
							end if;
							if msec > 1000 then
								selling_state <= waiting;
								state <= waiting;
								timer_ena <= '0';
							end if;
						when sell =>
							if msec = 0 then
								timer_ena <= '1';
							end if;
							if msec mod 1000 < 300 then
								seg_data <= "trade.  ";
							elsif msec mod 1000 < 600 then
								seg_data <= "trade.. ";
							elsif msec mod 1000 < 900 then
								seg_data <= "trade...";
							end if;
							if msec < 200 then
								lcd_clear <= '1';
								bg_color <= white;
							else
								lcd_clear <= '0';
								case lcd_count is
									when 0 =>
										text_data <= to_string(egg, 9999, 10, 4) & "        ";
										font_start <= '1';
										x <= 10;
										y <= 40;
										text_color(1 to 4) <= (black, black, black, black);
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 1;
										end if;
									when 1 =>
										text_data <= to_string(10, 9999, 10, 4) & "        ";
										font_start <= '1';
										x <= 10;
										y <= 80;
										text_color(1 to 4) <= (red, red, red, red);
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 2;
										end if;
									when 2 =>
										if egg_number <= egg then
											text_data <= to_string(egg_number, 9999, 10, 4) & "        ";
											x <= 10;
											y <= 120;
											text_color(1 to 4) <= (red, red, red, red);
										else
											text_data <= "NOT ENOUGH  ";
											x <= 10;
											y <= 120;
											text_color <= (others => black);
										end if;
										font_start <= '1';

										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 0;
										end if;
									when 3 =>
								end case;
								if rx_done = '1' or pass(0 to 3) = (x"77", x"77", x"77", x"77") then--接收軟體資料
									if to_integer(rx_data) = 13 then
										count <= 0;
										case count is
											when 0 => egg_number <= 0;
											when 1 => egg_number <= to_integer(pass(0)) - 48;
											when 2 => egg_number <= (to_integer(pass(0)) - 48) * 10 + (to_integer(pass(1)) - 48);
											when 3 => egg_number <= (to_integer(pass(0)) - 48) * 100 + (to_integer(pass(1)) - 48) * 10 + (to_integer(pass(2)) - 48);
											when 4 => egg_number <= (to_integer(pass(0)) - 48) * 1000 + (to_integer(pass(1)) - 48) * 100 + (to_integer(pass(2)) - 48) * 10 + (to_integer(pass(3)) - 48);
											when others => null;
										end case;
									elsif pass(0 to 3) /= (x"77", x"77", x"77", x"77") then
										pass(count) <= rx_data;
										count <= count + 1;
									end if;
									if pass(0 to 3) = (x"77", x"77", x"77", x"77") then
										if egg_number <= egg then
											state <= waiting;
											timer_ena <= '0';
											pass <= (others => x"00");
											egg <= egg - egg_number;
											money <= money + egg_number * 10;
										else
											null;
										end if;
									end if;

								end if;
							end if;
					end case;
					if pressed = '1' and key = 15 then
						state <= waiting;
						timer_ena <= '0';
					end if;
				when buying =>
					led_r <= '0';
					led_g <= '0';
					led_y <= '1';
					seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
					data_g <= (others => x"00");
					data_r <= (others => x"00");
					bg_color <= to_data(l_paste(l_addr, to_data(l_paste(l_addr, to_data(l_paste(l_addr, white, pic_data(2), (90, 10), 32, 32)), pic_data(1), (50, 10), 32, 32)), pic_data(0), (10, 10), 32, 32));
					pic_addr(0) <= to_addr(l_paste(l_addr, white, pic_data(0), (10, 10), 32, 32));
					pic_addr(1) <= to_addr(l_paste(l_addr, white, pic_data(1), (50, 10), 32, 32));
					pic_addr(2) <= to_addr(l_paste(l_addr, white, pic_data(2), (100, 10), 32, 32));
					case lcd_count is
						when 0 =>
							lcd_clear <= '0';
							text_data <= to_string(fodder, 9999, 10, 4) & "        ";
							font_start <= '1';
							x <= 70;
							y <= 40;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 1 =>
							lcd_clear <= '0';
							text_data <= to_string(money, 9999, 10, 4) & "        ";
							font_start <= '1';
							x <= 70;
							y <= 80;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							lcd_clear <= '0';
							text_data <= to_string(egg, 9999, 10, 4) & "        ";
							font_start <= '1';
							x <= 70;
							y <= 135;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 0;
							end if;
						when 3 =>
					end case;
					data_g(buy_y)(buy_x) <= '1';
					for i in 0 to 4 loop
						if i > 3 then
							data_g(sell_y(i))(sell_x(i)) <= buy_enable(i);
							data_r(sell_y(i))(sell_x(i)) <= buy_enable(i);
						else
							data_g(sell_y(i))(sell_x(i)) <= '0';
							data_r(sell_y(i))(sell_x(i)) <= buy_enable(i);
						end if;
						if buy_x = sell_x(i) and buy_y = sell_y(i) then
							data_g(sell_y(i))(sell_x(i)) <= '1';
							data_r(sell_y(i))(sell_x(i)) <= '0';
							if money >= 100 and buy_enable(i) = '1' then
								if i > 3 then
									money <= money - 100;
									fodder <= fodder + 100;
									buy_enable(i) <= '0';
								else
									money <= money - 100;
									fodder <= fodder + 50;
									buy_enable(i) <= '0';
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
					if pressed = '1' and (key = 15 or key = 7) then
						state <= waiting;
						buy_x <= 0;
						buy_y <= 0;
						data_g <= (others => x"00");
						data_r <= (others => x"00");
						buy_enable <= "11111";
					end if;
			end case;
		end if;

	end process;
end arch;
