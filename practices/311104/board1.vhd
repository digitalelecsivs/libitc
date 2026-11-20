library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity key_uart_tx_top is
	port (
		clk, rst_n : in std_logic;
		-- 3x3 矩陣按鍵
		key_row : in unsigned(0 to 2);
		key_col : out unsigned(0 to 2);
		-- UART 序列傳輸
		uart_rx : in std_logic;
		uart_tx : out std_logic
	);
end key_uart_tx_top;

architecture arch of key_uart_tx_top is

	constant C_TXT_LEN : integer := 16;
	constant C_BAUD    : integer := 9_600;

	-- 3x3 鍵盤信號
	signal key_pressed : std_logic;
	signal key_rise    : std_logic;
	signal key_val     : integer range 0 to 9;

	-- uart_txt 介面信號
	signal tx_ena  : std_logic := '0';
	signal tx_busy : std_logic;
	signal tx_data : string(1 to C_TXT_LEN) := (others => ' ');
	signal tx_len  : integer range 1 to C_TXT_LEN := 1;

	type state_t is (s_idle, s_start, s_done);
	signal state : state_t := s_idle;

begin

	-- 3x3 鍵盤掃描元件
	key_inst : entity work.key_3x3(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => key_pressed,
			key     => key_val
		);

	-- 捕捉按鍵按下的瞬間（上升緣）
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => key_pressed,
			rising  => key_rise,
			falling => open
		);

	-- UART 文字通訊模組（tx_mode => '0' 會自動前後包覆 STX 與 ETX 封包）
	uart_inst : entity work.uart_txt(arch)
		generic map(
			txt_len_max => C_TXT_LEN,
			baud        => C_BAUD
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => uart_tx,
			tx_ena  => tx_ena,
			tx_busy => tx_busy,
			tx_data => tx_data,
			tx_len  => tx_len,
			rx_busy => open,
			rx_data => open,
			tx_mode => '0',
			rx_len  => open
		);

	-- 按鍵觸發與傳送狀態機：抓到按鍵後轉成字元並透過 UART 發送
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			state <= s_idle;
			tx_ena <= '0';
			tx_data <= (others => ' ');
			tx_len <= 1;
		elsif rising_edge(clk) then
			case state is

				when s_idle =>
					tx_ena <= '0';
					if key_rise = '1' then
						-- 將 key 數值（0~8）轉為對應的 ASCII 字元 ('0'~'8')
						tx_data <= character'val(48 + key_val) & "               "; 
						tx_len <= 1;
						tx_ena <= '1';
						state <= s_start;
					end if;

				when s_start =>
					tx_ena <= '0';
					if tx_busy = '1' then
						state <= s_done;
					end if;

				when s_done =>
					if tx_busy = '0' then
						state <= s_idle;
					end if;

			end case;
		end if;
	end process;

end arch;