library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity wifi is
	port (
		wifi_rx : in std_logic;  -- receive pin
		wifi_tx : out std_logic; -- transmit pin
		dbg_a   : out std_logic_vector(0 to 7);
		key_row : in u2r_t;
		key_col : out u2r_t;

		clk, rst_n : in std_logic
	);
end wifi;

architecture arch of wifi is
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_down, tx_start : std_logic;
	signal tx_data, rx_data : u8_t;
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

begin
	dbg_a(0) <= not tx_ena;
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			tx_data <= x"ff";
		end if;
		if pressed = '1' then
			tx_ena <= '1';
		end if;
		-- if tx_start = '1'then
		-- 	tx_ena <= '0';
		-- end if;
		if tx_down = '1' then
			tx_ena <= '0';
		end if;
	end process;
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 115200
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => wifi_rx,  --腳位
			uart_tx => wifi_tx,  --腳位
			tx_ena  => tx_start, --enable '1' 動作
			tx_busy => tx_busy,  --tx資料傳送時tx_busy='1'
			tx_data => tx_data,  --硬體要傳送的資料
			rx_busy => rx_busy,  --rx資料傳送時rx_busy='1'
			rx_err  => rx_err,   --檢測錯誤
			rx_data => rx_data   --由軟體接收到的資料
		);
	key_inst : entity work.key_2x2_1(arch)
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
	edge_wifi_busy : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => tx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => tx_down  --負緣 open=開路
		);
	edge_wifi : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => tx_ena,   --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => tx_start, --正緣 '1'觸發
			falling => open      --負緣 open=開路
		);
end arch;
