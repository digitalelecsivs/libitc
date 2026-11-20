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
		-- UART
		uart_tx : out std_logic;
		-- 除錯腳
		dbg_a : out std_logic_vector(7 downto 0)
	);
end key_uart_tx_top;

architecture arch of key_uart_tx_top is

	-- true：不靠鍵盤，每秒自動送 0~8（用來單獨測試 UART）；false：按鍵觸發
	constant C_TEST_AUTO : boolean := false;

	constant C_TXT_LEN : integer := 16;
	constant C_BAUD    : integer := 115200;
	constant C_PAD     : string(1 to 15) := (others => ' '); -- 補滿 16 個字元用

	-- 3x3 鍵盤
	signal key_pressed : std_logic;
	signal key_rise    : std_logic;
	signal key_val     : integer range 0 to 9;

	-- 自動測試
	signal test_cnt  : integer range 0 to 49_999_999 := 0;
	signal test_tick : std_logic := '0';
	signal test_val  : integer range 0 to 8 := 0;

	-- 觸發來源與要送的鍵號
	signal send_req : std_logic;
	signal send_val : integer range 0 to 9;

	-- uart_txt 介面
	signal uart_tx_s : std_logic;
	signal tx_ena    : std_logic := '0';
	signal tx_busy   : std_logic;
	signal tx_data   : string(1 to C_TXT_LEN) := (others => ' ');
	signal tx_len    : integer range 1 to C_TXT_LEN := 1;

	-- 傳送狀態機
	type state_t is (s_idle, s_start, s_done);
	signal state : state_t := s_idle;
	signal sent_toggle : std_logic := '0'; -- 每傳完一筆就翻轉，方便觀察

begin

	-- 3x3 鍵盤元件
	key_inst : entity work.key_3x3(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => key_pressed,
			key     => key_val
		);

	-- 按下瞬間（上升緣）
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => key_pressed,
			rising  => key_rise,
			falling => open
		);

	-- UART 文字元件：自動於資料前後加上 stx / etx 封包
	uart_inst : entity work.uart_txt(arch)
		generic map(
			txt_len_max => C_TXT_LEN,
			baud        => C_BAUD
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => '1', -- 僅發送，接收腳拉高維持 idle
			uart_tx => uart_tx_s,
			tx_ena  => tx_ena,
			tx_busy => tx_busy,
			tx_data => tx_data,
			tx_len  => tx_len,
			rx_busy => open,
			rx_data => open,
			rx_len  => open
		);

	uart_tx <= uart_tx_s;

	-- 每秒一次的測試觸發，鍵號從 0 輪到 8
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			test_cnt <= 0;
			test_tick <= '0';
			test_val <= 0;
		elsif rising_edge(clk) then
			test_tick <= '0';
			if test_cnt = 49_999_999 then
				test_cnt <= 0;
				test_tick <= '1';
				if test_val = 8 then
					test_val <= 0;
				else
					test_val <= test_val + 1;
				end if;
			else
				test_cnt <= test_cnt + 1;
			end if;
		end if;
	end process;

	-- 觸發來源：測試模式用計時，正常模式用按鍵
	send_req <= test_tick when C_TEST_AUTO else key_rise;
	send_val <= test_val  when C_TEST_AUTO else key_val;

	-- 傳送：組好 1 個字元（'0'~'8'），拉高 tx_ena 一個時脈，等傳完才接受下一次
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			state <= s_idle;
			tx_ena <= '0';
			tx_data <= (others => ' ');
			tx_len <= 1;
			sent_toggle <= '0';
		elsif rising_edge(clk) then
			case state is

				when s_idle =>
					tx_ena <= '0';
					if send_req = '1' and send_val <= 8 then
						tx_data <= character'val(48 + send_val) & C_PAD; -- 1 + 15 = 16
						tx_len <= 1;
						tx_ena <= '1';
						state <= s_start;
					end if;

				when s_start =>
					tx_ena <= '0';
					if tx_busy = '1' then -- uart_txt 開始傳送
						state <= s_done;
					end if;

				when s_done =>
					if tx_busy = '0' then -- 傳送完畢
						sent_toggle <= not sent_toggle;
						state <= s_idle;
					end if;

			end case;
		end if;
	end process;

	-- 除錯輸出
	dbg_a(3 downto 0) <= std_logic_vector(to_unsigned(key_val, 4)); -- 鍵盤編號
	dbg_a(4) <= key_pressed;  -- 有按鍵（消抖後）
	dbg_a(5) <= tx_busy;      -- 傳送中
	dbg_a(6) <= sent_toggle;  -- 每傳完一筆就翻轉
	dbg_a(7) <= uart_tx_s;    -- UART 傳送腳的鏡像

end arch;