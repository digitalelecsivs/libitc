library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity wifi2 is
	port (
		uart_rx                                                 : in std_logic;  -- receive pin
		uart_tx                                                 : out std_logic; -- transmit pin
		dbg_a                                                   : out std_logic_vector(0 to 7);
		key_row                                                 : in u4r_t;
		key_col                                                 : out u4r_t;
		dot_red, dot_green, dot_com                             : out u8r_t;
		seg_led, seg_com                                        : out u8r_t;
		buz                                                     : out std_logic; --'1' 叫  '0' 不叫
		clk, rst_n                                              : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic

	);
end wifi2;

architecture arch of wifi2 is
	-- signal tx_ena, tx_busy, rx_busy, rx_rise, rx_err, rx_down : std_logic;
	-- signal tx_data, rx_data : string(1 to 8);
	--seg
	signal seg_data : string(1 to 8) := (others => '1');
	signal dot : u8r_t := (others => '0');

	--lcd 
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

	-- signal tx_len : integer range tx_data'range;
	-- signal rx_len : integer range rx_data'range;
	--uart

	signal rx_start, rx_done, tx_mode, tx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_ena_e : std_logic;
	signal tx_data, rx_data : string(1 to 60);
	signal tx_len, rx_len : integer range 1 to 60;

	signal buz_ena, buz_flag : std_logic;
	signal buz_busy, buz_done : std_logic;

	signal data_g, data_r : u8r_arr_t(0 to 7);

	signal pressed, pressed_i : std_logic;
	signal key : i4_t;
begin
	uart_txt : entity work.uart_txt(arch)
		generic map(
			txt_len_max => 60,
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
			tx_ena  => tx_ena,  -- initiate transmission
			tx_busy => tx_busy, -- transmission in progress
			tx_data => tx_data, -- data to transmit
			tx_len  => tx_len,
			tx_mode => tx_mode,
			rx_busy => rx_busy, -- data reception in progress
			rx_data => rx_data, -- data received
			rx_len  => rx_len
		);
	process (clk, rst_n)
	begin
		if rising_edge(clk) then
			if rst_n = '0' then
				seg_data <= "11111111";
				buz <= '0';
			else
				font_start <= '1';
				if tx_done = '1' then
					tx_ena <= '0';
				end if;
				if draw_done = '1' then
					font_start <= '0';
				end if;

				bg_color <= white;
				if pressed = '1' and key = 0 then
					tx_ena <= '1';
					tx_data(1 to 3) <= "+++";
					tx_len <= 3;
				end if;
				if pressed = '1' and key = 1 then
					tx_ena <= '1';
					tx_data(1 to 12) <= "AT+CIPSTATUS";
					tx_len <= 12;
				end if;
			end if;
			if rx_done = '1' then
				seg_data <= rx_data(1 to 8);
				text_data <= rx_data(45 to 56);
			end if;

		end if;
	end process;

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,  --腳位 a~g
			seg_com => seg_com,  --共同腳位
			data    => seg_data, --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot       --小數點 1 亮
		);
	edge_LCD : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => font_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,      --正緣 '1'觸發
			falling => draw_done  --負緣 open=開路
		);

	-- uart_inst : entity work.uart_txt(arch)
	-- 	generic map(
	-- 		baud        => 115200,
	-- 		txt_len_max => 8
	-- 	)
	-- 	port map(
	-- 		clk     => clk,
	-- 		rst_n   => rst_n,
	-- 		uart_rx => uart_rx, --腳位
	-- 		uart_tx => open,    --uart_tx, --腳位
	-- 		tx_ena  => tx_ena,  --enable '1' 動作
	-- 		tx_busy => tx_busy, --tx資料傳送時tx_busy='1'
	-- 		tx_data => tx_data, --硬體要傳送的資料
	-- 		tx_len  => tx_len,
	-- 		rx_busy => rx_busy, --rx資料傳送時rx_busy='1'
	-- 		-- rx_err  => rx_err,  --檢測錯誤
	-- 		rx_len  => rx_len,
	-- 		rx_data => rx_data --由軟體接收到的資料
	-- 	);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => pressed_i, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,   --正緣 '1'觸發
			falling => open       --負緣 open=開路
		);
	edge_wifi : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => rx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => rx_done  --負緣 open=開路
		);

	edge_tx : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => tx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => tx_done  --負緣 open=開路
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
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
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
end arch;
