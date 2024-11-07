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
	signal pic_addr_sivs : l_addr_t;
	signal pic_data_sivs : l_px_t;
	signal pic_data_o : std_logic_vector(0 to 23);
	--user
	type system_state is (reset, waiting, provide, selling, buying);
	signal state : system_state;
	signal fodder : integer := 100;
	signal money : integer := 500;
	signal egg : integer;
	signal fodder_number : integer := 0;
	signal digit : std_logic := '0';
	type sell_coord is array(0 to 3) of integer range 0 to 7;
	signal sell_x : sell_coord := (6, 0, 0, 0);
	signal sell_y : sell_coord := (1, 0, 0, 0);
	signal buy_x, buy_y : integer range 0 to 7;
	signal buy_enable : unsigned(0 to 3) := "1111";
	signal lcd_count : integer range 0 to 3;
	signal price : integer range 0 to 9;
	signal reset_count : integer range 0 to 2;
	type pro_state is (green, red, green_flash, orange_flash, red_flash);
	signal provide_state : pro_state;
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
	process (clk, rst_n)
		variable number : integer := 0;
	begin
		pic_data_sivs <= unsigned(pic_data_o);
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
					fodder <= 100;
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
					elsif msec > 10000 then
						state <= waiting;
						reset_count <= 0;
						timer_ena <= '0';
					end if;

				when waiting =>
					dot <= "00000000";
					led_r <= '0';
					led_g <= '0';
					led_y <= '0';
					rgb <= "111";
					data_r <= (X"3C", X"5A", X"A5", X"81", X"A5", X"A5", X"42", X"3C");
					data_g <= (X"3C", X"5A", X"A5", X"81", X"A5", X"A5", X"42", X"3C");
					lcd_clear <= '1';
					seg_data <= "        ";
					if pressed_i = '1' and key = 14 then
						lcd_clear <= '1';
						bg_color <= white;
						if pressed = '1' and key = 14 then
							case sw(0 to 2) is
								when "100" =>
									state <= provide;
								when "010" =>
									state <= selling;
								when "001" =>
									state <= buying;
								when others => null;
							end case;
						end if;
						if pressed_i = '1' and key = 14 and sw /= "100" and sw /= "010" and sw /= "001" then
							timer_ena <= '1';
							if msec > 20 then
								case lcd_count is
									when 0 =>
										lcd_clear <= '0';
										text_data <= " FEED" & to_string(fodder, 999, 10, 4) & "   ";
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
										text_data <= " EGG" & to_string(egg, 999, 10, 3) & "     ";
										font_start <= '1';
										x <= 10;
										y <= 120;
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 3;
										end if;
									when 3 =>
										lcd_clear <= '0';
										x <= 10;
										y <= 40;
										text_data <= " FUNC:HOLD" & "  ";
										font_start <= '1';
										if draw_done = '1' then
											font_start <= '0';
											lcd_count <= 3;
										end if;
										lcd_count <= 0;
								end case;
							end if;
						end if;
					else
						timer_ena <= '0';
						lcd_clear <= '1';
						bg_color <= l_paste_txt(l_addr, to_data(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70)), "FUNC:HOLD", (10, 40), black);
						pic_addr_sivs <= to_addr(l_paste(l_addr, white, pic_data_sivs, (80, 30), 70, 70));
					end if;
				when provide =>
					rgb <= "100";
					led_r <= '1';
					led_g <= '0';
					led_y <= '0';
					case provide_state is
						when green =>
						when red =>
						when green_flash =>
						when orange_flash =>
						when orange_flash =>
					end case;
					seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
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
						if fodder_number > 0 then
							fodder_number <= (fodder_number mod 10) * 10 + number;
						else
							fodder_number <= number;
						end if;
					end if;
					if pressed = '1' and key = 14 then
						if fodder_number = 0 then
							state <= waiting;
						elsif fodder >= fodder_number then
							fodder <= fodder - fodder_number;
							egg <= fodder_number * 4;
							fodder_number <= 0;
						else
							fodder_number <= 0;
						end if;

					end if;
				when selling =>
					led_r <= '0';
					led_g <= '1';
					led_y <= '0';
					lcd_clear <= '0';
					if rx_done = '1' and to_integer(rx_data) /= 13 then
						price <= to_integer(rx_data);
					end if;
					if pressed = '1' and key = 14 then
						money <= money + egg * price;
						egg <= 0;
						price <= 0;
						state <= waiting;
					end if;

					if pressed = '1' and key = 14 then
						state <= waiting;
					end if;
				when buying =>
					led_r <= '0';
					led_g <= '0';
					led_y <= '1';
					seg_data <= to_string(fodder, 9999, 10, 4) & to_string(money, 9999, 10, 4);
					data_g <= (others => x"00");
					data_r <= (others => x"00");
					data_g(buy_y)(buy_x) <= '1';
					data_g(sell_y(0))(sell_x(0)) <= buy_enable(0);
					data_r(sell_y(0))(sell_x(0)) <= buy_enable(0);
					if buy_x = sell_x(0) and buy_y = sell_y(0) then
						data_g(sell_y(0))(sell_x(0)) <= '1';
						data_r(sell_y(0))(sell_x(0)) <= '0';
						if money >= 100 and buy_enable(0) = '1' then
							money <= money - 100;
							fodder <= fodder + 50;
							buy_enable(0) <= '0';
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
					if pressed = '1' and key = 14 then
						state <= waiting;
						buy_x <= 0;
						buy_y <= 0;
						data_g <= (others => x"00");
						data_r <= (others => x"00");
						buy_enable <= "1111";
					end if;
			end case;
		end if;
	end process;

end arch;
