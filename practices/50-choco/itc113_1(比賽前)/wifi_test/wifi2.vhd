library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity wifi2 is
	port (
		uart_rx                     : in std_logic;  -- receive pin
		uart_tx                     : out std_logic; -- transmit pin
		dbg_a                       : out std_logic_vector(0 to 7);
		key_row                     : in u4r_t;
		key_col                     : out u4r_t;
		dot_red, dot_green, dot_com : out u8r_t;
		seg_led, seg_com            : out u8r_t;
		buz                         : out std_logic; --'1' 叫  '0' 不叫
		clk, rst_n                  : in std_logic
	);
end wifi2;

architecture arch of wifi2 is
	-- signal tx_ena, tx_busy, rx_busy, rx_rise, rx_err, rx_down : std_logic;
	-- signal tx_data, rx_data : string(1 to 8);
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--seg
	signal seg_data : string(1 to 8) := (others => '1');
	signal dot : u8r_t := (others => '0');

	-- signal tx_len : integer range tx_data'range;
	-- signal rx_len : integer range rx_data'range;

	signal buz_ena, buz_flag : std_logic;
	signal buz_busy, buz_done : std_logic;

	signal data_g, data_r : u8r_arr_t(0 to 7);

begin
	--uart_tx <= uart_rx;
	process (clk, rst_n)
	begin
		if rising_edge(clk) then
			if rst_n = '0' then
				seg_data <= "11111111";
				buz <= '0';
			else
				tx_ena <= '1';
				tx_data <= "11111111";
				if rx_done = '1' then
					data_r(0) <= rx_data;
				end if;
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
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 115200
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
end arch;
