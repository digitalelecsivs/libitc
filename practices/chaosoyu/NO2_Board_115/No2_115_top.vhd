----------------------------------------------------------------------------
--115學年度數位電子術科參考試題二     ***試題名稱：限量商品產銷管理系統 ***
--實作方塊  :  EP3C40Q240C8N    
--115.11.07 by chaosoyu
----------------------------------------------------------------------------
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

		-- seg
		seg_led, seg_com : out u8r_t;

		-- key 3X3
		key_row : in unsigned(0 to 2);
		key_col : out unsigned(0 to 2);

		-- WS2812 RGB LED Pin
		D_out : out std_logic;

		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin

		-- YGR LED
		led_y, led_g, led_r : out std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end No2_115_top;

architecture arch of No2_115_top is

	-- seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	-- WS2812
	signal ws_ena : std_logic := '0';
	signal ws_busy : std_logic;
	signal rgb_arr : l_px_arr_t(0 to 63) := (others => (others => '0'));
	signal decoded_rgb_arr : l_px_arr_t(0 to 63);

	-- ws2812傳送請求
	signal ws_send_req : std_logic := '0';

	-- key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	-- uart_txt 相關訊號 (長度設為 28，足以容納 "ID0102OQ00650040SQ#xx$xxxx\r\n")
	constant UART_TXT_LEN : integer := 28;
	signal uart_tx_ena : std_logic := '0';
	signal uart_tx_busy : std_logic;
	signal uart_tx_data : string(1 to UART_TXT_LEN) := (others => ' ');
	signal uart_tx_len : integer range 1 to UART_TXT_LEN := 18;
	signal uart_rx_busy : std_logic;
	signal uart_rx_data : string(1 to UART_TXT_LEN);
	signal uart_rx_len : integer range 1 to UART_TXT_LEN;

	-- uart_rx_busy 的下降緣檢測訊號
	signal uart_rx_done : std_logic;

	-- timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	-- lcd 採用lcd_mix.vhd， 有font_mode
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal font_mode : integer range 0 to 2 := 0;
	signal addr : l_addr_t;
	signal bg_color : l_px_t;
	signal text_color_array : l_px_arr_t(1 to 12) := (others => black);
	signal lcd_clear : std_logic;

	-- user
	type system_state is (ST_IDLE, ST_INIT, ST_LOAD, ST_WAIT, ST_CONNECT, ST_CONNECT_TRIG, ST_CONNECT_WAIT, ST_DISTRIBUTE, ST_QUERY, ST_QUERY_TRIG, ST_QUERY_WAIT);
	signal state : system_state := ST_IDLE;
	type ws_state_t is (show_red, show_green, show_blue, show_off, idle);
	signal ws_state : ws_state_t := show_red;

	-- 訂單id，訂單數量，訂單配額
	signal ID : integer := 0;
	signal OQ : integer := 0;
	signal SQ : integer := 0;

	--訂單數量、出價金額
	signal ID01_n, ID02_n, ID01_p, ID02_p : integer;

	-- lcd輪播行數
	signal lcd_count : integer range 0 to 2 := 0;

	-- 供貨數量配置 (SQ) 相關變數
	signal SQ01_val, SQ02_val : integer range 0 to 99 := 0; -- 已儲存之配額
	signal edit_sq : integer range 0 to 99 := 0; -- 編輯中之臨時配額
	signal current_edit_id : integer range 0 to 2 := 0; -- 當前編輯的 ID

	-- 配額查詢運算變數
	signal query_target : integer range 1 to 2 := 1;
	signal total_pay : integer range 0 to 9999 := 0;

	-- 每秒閃爍
	signal blink_on : std_logic := '1';

begin

	-- 除錯用，觀測uart接收信號，有接收信號led會閃
	led_r <= not uart_rx;

	-- 8x8 LED 自動繪製模組
	led_decoder_inst : entity work.led_matrix_decoder(arch)
		port map(
			qty_order01 => ID01_n,
			qty_order02 => ID02_n,
			sq_order01  => SQ01_val,
			sq_order02  => SQ02_val,
			current_id  => current_edit_id,
			blink_on    => blink_on,
			rgb_arr     => decoded_rgb_arr
		);

	-- 實例化WS2812驅動模組
	WS2812_inst : entity work.WS2812_ch(arch)
		generic map(
			led_num_max => 64
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			ena      => ws_ena,
			busy     => ws_busy,
			rgb_data => rgb_arr,
			D_out    => D_out,
			led_num  => 64
		);

	-- 改用 uart_txt 元件傳送接收字串
	uart_txt_inst : entity work.uart_txt(arch)
		generic map(
			txt_len_max => UART_TXT_LEN,
			baud        => 115200   --9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => uart_tx,
			tx_ena  => uart_tx_ena,
			tx_busy => uart_tx_busy,
			tx_data => uart_tx_data,
			tx_len  => uart_tx_len,
			rx_busy => uart_rx_busy,
			rx_data => uart_rx_data,
			rx_len  => uart_rx_len
		);

	-- 實例化 edge 檢測模組
	edge_rx_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => uart_rx_busy,
			rising  => open,
			falling => uart_rx_done -- 接收完成時脈衝高 1 個 clk
		);

	--實例化七段顯示模組
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => dot
		);

	--實例化3X3鍵盤
	key_inst : entity work.key_3X3(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);

	--實例化計時器
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => load,
			msec  => msec
		);

	--實例化除頻器
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1 -- 1HZ
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => blink_on
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);

	--實例化邊緣模組，draw_done高態表字型顯示完成
	edge_LCD : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);

	--實例化lcd模組，採3倍放大字型
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
			ws_send_req <= '0';
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
			--led_r <= '0';

			ID01_n <= 65;
			ID02_n <= 40;
			ID01_p <= 70;
			ID02_p <= 30;
			ID <= 0;
			OQ <= 0;
			SQ <= 0;

			SQ01_val <= 0;
			SQ02_val <= 0;
			edit_sq <= 0;
			current_edit_id <= 0;

			uart_tx_ena <= '0';
			query_target <= 1;

		elsif rising_edge(clk) then

			------------------------------------------------------------------
			-- UART 接收解碼：以 uart_rx_done 鎖存並觸發
			------------------------------------------------------------------
			if uart_rx_done = '1' and uart_tx_busy = '0' then
				--除錯用，只要收完一筆封包，立刻將 uart_rx_data 前 4 字元顯示在七段顯示器
				--seg_data <= uart_rx_data(1 to 8);

				--判斷是否為 9901 
				if uart_rx_data(1 to 4) = "9901" then
					query_target <= 1;
					state <= ST_QUERY;
					--判斷是否為 9902
				elsif uart_rx_data(1 to 4) = "9902" then
					query_target <= 2;
					state <= ST_QUERY;
				end if;
			end if;

			-- 按下 Key 6 且 SW 為 0000_0000 觸發初始化
			if sw = "00000000" and pressed = '1' and key = 6 then
				state <= ST_INIT;
				ws_send_req <= '1';
				ws_state <= show_red;
				timer_ena <= '0';
				current_edit_id <= 0;
			end if;

			-- 按下 Key 8 且 SW 為 0001_0000 觸發連線測試
			if sw = "00010000" and pressed = '1' and key = 8 then
				state <= ST_CONNECT;
			end if;

			-- 按下 Key 6 且 SW 為 0100_xxxx 配置模式
			if sw(0 to 3) = "0100" and pressed = '1' and key = 6 then
				state <= ST_DISTRIBUTE;

				if sw(4 to 7) = "0001" then
					current_edit_id <= 1;
					edit_sq <= SQ01_val;
				elsif sw(4 to 7) = "0010" then
					current_edit_id <= 2;
					edit_sq <= SQ02_val;
				end if;
			end if;

			-- LCD 繪圖輪播機制 ST_INIT、ST_IDLE不輪播
			if state /= ST_INIT and state /= ST_IDLE then
				case lcd_count is
					when 0 =>
						if state = ST_DISTRIBUTE then
							text_data <= " ID" & to_string(current_edit_id, 99, 10, 2) & "       ";
						else
							text_data <= " ID" & to_string(ID, 99, 10, 2) & "       ";
						end if;
						font_start <= '1';
						x <= - 25;
						y <= 0;
						text_color_array(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 1;
						end if;

					when 1 =>
						if state = ST_DISTRIBUTE then
							if current_edit_id = 1 then
								text_data <= " OQ" & to_string(ID01_n, 99, 10, 2) & "       ";
							else
								text_data <= " OQ" & to_string(ID02_n, 99, 10, 2) & "       ";
							end if;
						else
							text_data <= " OQ" & to_string(OQ, 99, 10, 2) & "       ";
						end if;
						font_start <= '1';
						x <= - 25;
						y <= 50;
						text_color_array(1 to 12) <= (others => black);
						if draw_done = '1' then
							font_start <= '0';
							lcd_count <= 2;
						end if;

					when 2 =>
						if SQ < 0 then
							text_data <= " SQ  " & "       ";
						else
							text_data <= " SQ" & to_string(SQ, 99, 10, 2) & "       ";
						end if;
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

			-- WS2812 傳送控制 ws_send_req請求傳送，1個clk立刻拉低，ws_ena會慢1個clk，更穩定
			if ws_send_req = '1' and ws_busy = '0' then
				ws_ena <= '1';
				ws_send_req <= '0';
			elsif ws_busy = '1' then
				ws_ena <= '0';
			end if;

			--------------------------------------------------------------------------------
			-- 主狀態機邏輯
			--------------------------------------------------------------------------------
			case state is
				when ST_IDLE =>
					bg_color <= white;
					lcd_clear <= '1';
					ws_send_req <= '1';

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

					case ws_state is
						when show_red =>
							rgb_arr <= (others => x"00FF00");
							if msec >= 1000 then
								ws_state <= show_green;
								ws_send_req <= '1';
							end if;

						when show_green =>
							rgb_arr <= (others => x"FF0000");
							if msec >= 2000 then
								ws_state <= show_blue;
								ws_send_req <= '1';
							end if;

						when show_blue =>
							rgb_arr <= (others => x"0000FF");
							if msec >= 3000 then
								ws_state <= show_off;
								ws_send_req <= '1';
							end if;

						when show_off =>
							rgb_arr <= (others => x"000000");
							timer_ena <= '0';
							ws_state <= idle;

						when idle =>
							state <= ST_LOAD;
					end case;

				when ST_LOAD =>
					lcd_clear <= '0';
					seg_data <= '-' & to_string(ID01_p, 99, 10, 2) & "--" & to_string(ID02_p, 99, 10, 2) & '-';
						rgb_arr <= decoded_rgb_arr;
					ws_send_req <= '1';
					led_g <= '1';
					state <= ST_WAIT;

				when ST_WAIT =>
					--led_r <= '1';
					rgb_arr <= decoded_rgb_arr;
				when ST_CONNECT =>
					--步驟 1: 先送data到uart 
					uart_tx_len <= 18;
					uart_tx_data(1 to 18) <= "ID0102OQ" &
					to_string(ID01_n, 99, 10, 4) &
					to_string(ID02_n, 99, 10, 4) &
					CR & LF;
					uart_tx_data(19 to 28) <= (others => ' ');

					-- 跳到下一個狀態才發送 Enable（給予 uart_tx_data 1 個 Clock 的完全穩定時間）
					state <= ST_CONNECT_TRIG;

				when ST_CONNECT_TRIG =>
					-- 步驟 2: 資料已 100% 穩定，發送 1 個 Clock 的 Enable 脈衝
					uart_tx_ena <= '1';
					state <= ST_CONNECT_WAIT;

				when ST_CONNECT_WAIT =>
					-- 步驟 3: 自動拉低 Enable，並等待傳送完畢
					uart_tx_ena <= '0';
					if uart_tx_busy = '0' then
						state <= ST_WAIT;
					end if;

				when ST_DISTRIBUTE =>

					--配置SQ時爍閃數字
					if blink_on = '1' then
						SQ <= edit_sq; --亮
					else
						SQ <= - 1; --暗
					end if;

					if current_edit_id = 1 then
						seg_data <= to_string(ID01_p, 9999, 10, 4) & "TS80";
					else
						seg_data <= to_string(ID02_p, 9999, 10, 4) & "TS80";
					end if;

					--使用8X8自動繪製模組
					rgb_arr <= decoded_rgb_arr; --送資料
					ws_send_req <= '1'; --致能請求

					if pressed = '1' then --先斷判有按鍵按下
						case key is
							when 0 => --KEY0 +10
								if current_edit_id = 1 then
									if (edit_sq + 10 <= ID01_n) and ((edit_sq + 10 + SQ02_val) <= 80) then
										edit_sq <= edit_sq + 10;
									end if;
								elsif current_edit_id = 2 then
									if (edit_sq + 10 <= ID02_n) and ((edit_sq + 10 + SQ01_val) <= 80) then
										edit_sq <= edit_sq + 10;
									end if;
								end if;

							when 3 => --KEY3 -10
								if edit_sq >= 10 then
									edit_sq <= edit_sq - 10;
								end if;

							when 2 => --KEY2 +1
								if current_edit_id = 1 then
									if (edit_sq + 1 <= ID01_n) and ((edit_sq + 1 + SQ02_val) <= 80) then
										edit_sq <= edit_sq + 1;
									end if;
								elsif current_edit_id = 2 then
									if (edit_sq + 1 <= ID02_n) and ((edit_sq + 1 + SQ01_val) <= 80) then
										edit_sq <= edit_sq + 1;
									end if;
								end if;

							when 5 => --KEY5 -1
								if edit_sq >= 1 then
									edit_sq <= edit_sq - 1;
								end if;

							when 8 => --KEY8 確認
								if current_edit_id = 1 then
									SQ01_val <= edit_sq;
								elsif current_edit_id = 2 then
									SQ02_val <= edit_sq;
								end if;

								current_edit_id <= 0;
								ws_send_req <= '1';
								state <= ST_WAIT;

							when others => null;
						end case;
					end if;

				when ST_QUERY =>

					-- 步驟 1: 先組合字串資料（此時 Enable 保持 '0'）
					uart_tx_len <= 28;
					if query_target = 1 then
						uart_tx_data <= "ID9901OQ" &
							to_string(ID01_n, 99, 10, 4) &
							to_string(ID01_p, 99, 10, 4) &
							"SQ#" &
							to_string(SQ01_val, 99, 10, 2) &
							"$" &
							to_string(SQ01_val * ID01_p, 9999, 10, 4) &
							CR & LF;
					else
						uart_tx_data <= "ID9902OQ" &
							to_string(ID02_n, 99, 10, 4) &
							to_string(ID02_p, 99, 10, 4) &
							"SQ#" &
							to_string(SQ02_val, 99, 10, 2) &
							"$" &
							to_string(SQ02_val * ID02_p, 9999, 10, 4) &
							CR & LF;
					end if;

					-- 跳到下一個狀態才發送 Enable（給予 uart_tx_data 1 個 Clock 的完全穩定時間）
					state <= ST_QUERY_TRIG;

				when ST_QUERY_TRIG =>
					-- 步驟 2: 資料已 100% 穩定，發送 1 個 Clock 的 Enable 脈衝
					uart_tx_ena <= '1';
					state <= ST_QUERY_WAIT;

				when ST_QUERY_WAIT =>
					-- 步驟 3: 自動拉低 Enable，並等待傳送完畢
					uart_tx_ena <= '0';
					if uart_tx_busy = '0' then
						state <= ST_WAIT;
					end if;

			end case;
		end if;
	end process;

end arch;
