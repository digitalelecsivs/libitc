library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;

entity No2_115_top is
	port (
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		--seg
		seg_led, seg_com : out u8r_t;

		-- key 3X3
		key_row : in unsigned(0 to 2);
		key_col : out unsigned(0 to 2);

		-- WS2812 RGB LED Pin
		D_out : out std_logic;

		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin

		--YGR LED
		led_y, led_g, led_r : out std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end No2_115_top;

architecture arch of No2_115_top is
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--WS2812
	signal ws_ena : std_logic;
	signal ws_busy : std_logic;
	signal ws_busy_f : std_logic;
	signal rgb_arr : l_px_arr_t(0 to 63) := (others => (others => '0'));

	-- 自動編碼模組輸出訊號
	signal decoded_rgb_arr : l_px_arr_t(0 to 63);

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	--timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	--lcd
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal font_mode : integer range 0 to 2 := 0;

	signal addr : l_addr_t;
	signal bg_color : l_px_t;
	signal text_color_array : l_px_arr_t(1 to 12) := (others => black);
	signal lcd_clear : std_logic;

	--user
	type system_state is (ST_IDLE, ST_INIT, ST_LOAD, ST_WAIT, ST_CONNECT, ST_DISTRIBUT, ST_QUERY);
	signal state : system_state;
	type ws_state_t is (show_red, show_green, show_blue, show_off, idle);
	signal ws_state : ws_state_t := show_red;

	signal ws_send_req : std_logic := '0';
	signal ID : integer := 0;
	signal OQ : integer := 0;
	signal SQ : integer := 0;
	signal ID01_n, ID02_n, ID01_p, ID02_p : integer;
	signal lcd_count : integer range 0 to 2;
begin
	-- WS2812 Driver Instance
	WS2812_inst : entity work.WS2812_ch(arch)
		generic map(
			led_num_max => 64
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			ena      => ws_ena,  --致能腳，'1'時致能
			busy     => ws_busy, --'1'表示工作中
			rgb_data => rgb_arr, --LED顏色陣列，0X"GGRRBB" 
			D_out    => D_out,   --串列輸出
			led_num  => 64
		);
	-- 點陣自動繪製元件實例化
	led_decoder_inst : entity work.led_matrix_decoder(arch)
		port map(
			qty_order01 => ID01_n,
			qty_order02 => ID02_n,
			rgb_arr     => decoded_rgb_arr
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
		generic map(
			common_anode => '0' --共陰極
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,  --腳位 a~g
			seg_com => seg_com,  --共同腳位
			data    => seg_data, --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot       --小數點 1 亮
		);
	key_inst : entity work.key_3X3(arch)
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
			ena   => timer_ena, --當ena='0', msec=0, ena='1',msec上數
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	edge_rx : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => open,
			falling => rx_done
		);
	edge_LCD : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);

	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => 3,
			text_data        => text_data,
			font_mode        => font_mode,
			addr             => addr,
			bg_color         => bg_color,
			text_color_array => text_color_array,
			clear            => lcd_clear,

			lcd_sclk  => lcd_sclk,
			lcd_mosi  => lcd_mosi,
			lcd_ss_n  => lcd_ss_n,
			lcd_dc    => lcd_dc,
			lcd_bl    => lcd_bl,
			lcd_rst_n => lcd_rst_n
		);

	-- 主狀態機
	process (clk, rst_n)

	begin
		if rst_n = '0' then
			state <= ST_IDLE;
			ws_state <= show_red;
			ws_ena <= '0';
			rgb_arr <= (others => (others => '0'));
			timer_ena <= '0';
			seg_data <= "        ";
			lcd_count <= 0;
			font_mode <= 0;
			font_start <= '0';
			lcd_clear <= '1';
			bg_color <= white;
			x <= - 5;
			y <= 0;
			text_data <= "            ";
			text_color_array <= (others => black);

			led_y <= '0';
			led_g <= '0';
			led_r <= '0';
		elsif rising_edge(clk) then
			if sw = "00000000" and pressed = '1' and key = 6 then
				state <= ST_INIT;
				ws_send_req <= '1';
				ws_state <= show_red;
				timer_ena <= '0';
			end if;

			if state /= ST_INIT and state /= ST_IDLE then
				case lcd_count is
					when 0 =>
						text_data <= " ID" & to_string(ID, 9, 10, 2) & "       ";
						font_start <= '1';
						x <= - 25;
						y <= 0;
						text_color_array(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 1;
						end if;
					when 1 =>
						text_data <= " OQ" & to_string(OQ, 9, 10, 2) & "       ";
						font_start <= '1';
						x <= - 25;
						y <= 50;
						text_color_array(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 2;
						end if;
					when 2 =>
						text_data <= " SQ" & to_string(SQ, 9, 10, 2) & "       ";
						font_start <= '1';
						x <= - 25;
						y <= 100;
						text_color_array(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 0;
						end if;
				end case;
			end if;
			case state is
				when ST_IDLE =>
					bg_color <= white;
					lcd_clear <= '1';

				when ST_INIT =>

					ID01_n <= 65;
					ID02_n <= 40;
					ID01_p <= 70;
					ID02_p <= 30;
					ID <= 0;
					OQ <= 0;
					SQ <= 0;
					seg_data <= "..WAIT..";
					led_y <= '1';
					timer_ena <= '1';

					-- 發送單次脈衝
					if ws_send_req = '1' and ws_busy = '0' then
						ws_ena <= '1';
						ws_send_req <= '0'; -- 觸發後立刻清除請求
					elsif ws_busy = '1' then
						ws_ena <= '0';
					end if;

					-- 狀態機控制
					case ws_state is
						when show_red =>
							rgb_arr <= (others => x"00FF00"); -- 紅色 (GRB)

							if msec >= 1000 then
								ws_state <= show_green;
								ws_send_req <= '1'; -- 轉態時立刻發出發送請求
							end if;

						when show_green =>
							rgb_arr <= (others => x"FF0000"); -- 綠色 (GRB)

							if msec >= 2000 then
								ws_state <= show_blue;
								ws_send_req <= '1'; -- 轉態時立刻發出發送請求
							end if;

						when show_blue =>
							rgb_arr <= (others => x"0000FF"); -- 藍色 (GRB)

							if msec >= 3000 then
								ws_state <= show_off;
								ws_send_req <= '1'; -- 轉態時發出熄滅請求
							end if;

						when show_off =>
							rgb_arr <= (others => x"000000"); -- 全滅

							timer_ena <= '0';
							ws_state <= idle;

						when idle =>
							state <= ST_LOAD; -- 進入下一階段
					end case;

				when ST_LOAD =>
					lcd_clear <= '0';
					seg_data <= '-' & to_string(ID01_p, 99, 10, 2) & "--" & to_string(ID02_p, 99, 10, 2) & '-';
						-- 直接使用解碼元件算好的燈號點陣陣列
						rgb_arr <= decoded_rgb_arr;

					-- 觸發 WS2812 傳送
					ws_send_req <= '1';

					led_g <= '1';
					state <= ST_WAIT;

				when ST_WAIT =>

					led_r <= '1';

				when ST_CONNECT =>

				when ST_DISTRIBUT =>

				when ST_QUERY =>

			end case;
		end if;
	end process;
end arch;
